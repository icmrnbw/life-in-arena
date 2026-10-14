extends HeroKit
## Ashwarden: Ember Totem, Ash Wall, Tether Pull, Foundry Heart.

var totems: Array = []
var foundry_t := 0.0
var foundry_fx: Node = null


func max_totems() -> int:
	var r := rank(0)
	if r >= 4:
		return 4
	if r >= 3:
		return 3
	return 2


func totem_dmg() -> float:
	return 16.0 + 13.0 * rank(0) + 0.45 * hero.str_v


func empowered() -> bool:
	return foundry_t > 0.0


func wall_mult() -> float:
	return 2.0 if empowered() else 1.0


func empower_heal() -> float:
	if not empowered():
		return 0.0
	return [0.15, 0.22, 0.30][clampi(rank(3) - 1, 0, 2)]


func wall_length() -> float:
	return 5.0 + 1.5 * maxi(1, rank(1))


func aim_spec(slot: int) -> Dictionary:
	var s := super.aim_spec(slot)
	if slot == 1:
		s["length"] = wall_length()
	if slot == 2:
		s["radius"] = DB.SKILLS["tether_pull"]["radius_r"][clampi(rank(2) - 1, 0, 3)]
	return s


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0:
			var near := run.nearest_enemy(hero.pos, 14.0)
			if near:
				var d := run._flat(near.pos - hero.pos)
				var dist := d.length()
				var p := hero.pos + d.normalized() * minf(3.0, dist * 0.5)
				return {"point": p, "dir": d.normalized()}
			return {"point": hero.pos + hero.facing * 2.0, "dir": hero.facing}
		1:
			var c := run.best_cluster(hero.pos, 14.0, 4.0)
			if not c.is_empty():
				var d2: Vector3 = run._flat(c["pos"] - hero.pos)
				var dist2 := d2.length()
				var p2 := hero.pos + d2.normalized() * clampf(dist2 * 0.55, 2.5, 6.0)
				return {"point": p2, "dir": d2.normalized()}
			return {"point": hero.pos + hero.facing * 4.0, "dir": hero.facing}
		2:
			var rad: float = aim_spec(2)["radius"]
			var c2 := run.best_cluster(hero.pos, 11.0, rad)
			if not c2.is_empty():
				return {"point": c2["pos"], "dir": run._flat(c2["pos"] - hero.pos).normalized()}
			return {}
	return {"point": hero.pos, "dir": hero.facing}


func can_cast(slot: int) -> bool:
	if slot == 2:
		return true
	return true


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			return _cast_totem(aim)
		1:
			return _cast_wall(aim)
		2:
			return _cast_pull(aim)
		3:
			return _cast_foundry()
	return false


func _cast_totem(aim: Dictionary) -> bool:
	var p := clamp_point(aim.get("point", hero.pos + hero.facing * 2.0), DB.SKILLS["ember_totem"]["range"])
	var t := run.spawn_summon("ember_totem", p)
	t.max_hp = 160.0 + 70.0 * rank(0) + 5.0 * hero.str_v
	t.hp = t.max_hp
	t.armor = 4.0
	t.lifetime = 30.0
	t.no_push = true
	t.atk_cd = 0.3
	t.atk_time = 0.8
	t.atk_range = 9.0
	totems.append(t)
	run.fx("brood_hatch", {"pos": p})
	_prune_totems()
	while _alive_totems().size() > max_totems():
		var old: Unit = _alive_totems()[0]
		run.remove_ally(old)
		_prune_totems()
	return true


func _alive_totems() -> Array:
	var out := []
	for t in totems:
		if t.alive:
			out.append(t)
	return out


func _prune_totems() -> void:
	totems = _alive_totems()


func _cast_wall(aim: Dictionary) -> bool:
	var center := clamp_point(aim.get("point", hero.pos + hero.facing * 4.0), DB.SKILLS["ash_wall"]["range"])
	var d := run._flat(center - hero.pos)
	if d.length() < 0.3:
		d = aim_dir(aim)
	d = d.normalized()
	var perp := Vector3(-d.z, 0, d.x)
	var half := wall_length() * 0.5
	var a := center - perp * half
	var b := center + perp * half
	var dur := 5.0 + 1.5 * rank(1)
	var dps := 30.0 + 24.0 * rank(1) + 0.6 * hero.str_v
	run.add_wall(a, b, dur, dps, hero, "Ash Wall")
	run.shake(0.15)
	return true


func _cast_pull(aim: Dictionary) -> bool:
	var rad: float = aim_spec(2)["radius"]
	var p := clamp_point(aim.get("point", hero.pos + hero.facing * 5.0), DB.SKILLS["tether_pull"]["range"])
	run.fx("tether_pull", {"pos": p, "radius": rad, "from": hero.pos})
	var dmg := 35.0 + 30.0 * rank(2) + 0.6 * hero.str_v
	for e in run.enemies_in_radius(p, rad):
		run.damage(e, dmg, hero, "Tether Pull", "magic", {"color": Art.palette.get("ember", Color.ORANGE)})
		if not e.alive:
			continue
		e.apply_slow(0.4, 2.5)
		var dir := run._flat(e.pos - hero.pos)
		if dir.length() < 0.1:
			dir = hero.facing
		var dest: Vector3 = hero.pos + dir.normalized() * (hero.radius + e.radius + 0.6 + run.rng.randf() * 1.2)
		if e.is_boss:
			# bosses are too heavy to drag all the way: half the distance
			dest = e.pos.lerp(dest, 0.5)
		e.pull_to = dest
		e.pull_t = 0.35
	return true


func _cast_foundry() -> bool:
	var dur: float = [10.0, 12.0, 14.0][clampi(rank(3) - 1, 0, 2)]
	foundry_t = dur
	run.fx_stop(foundry_fx)
	foundry_fx = run.fx("foundry_aura", {"target": hero.node, "duration": dur, "pos": hero.pos})
	run.fx("level_up", {"pos": hero.pos})
	run.shake(0.2)
	return true


func tick(dt: float) -> void:
	if foundry_t > 0.0:
		foundry_t -= dt
		if foundry_t <= 0.0:
			run.fx_stop(foundry_fx)
			foundry_fx = null
	for t in totems:
		if not t.alive:
			continue
		if empowered():
			t.atk_cd -= dt   # tick_status already counts down once; empowered totems fire twice as fast
		if t.atk_cd <= 0.0:
			var target := run.nearest_enemy(t.pos, t.atk_range)
			if target:
				t.atk_cd = t.atk_time
				t.face(target.pos - t.pos)
				t.set_state("attack")
				var opts := {"dtype": "magic", "color": Art.palette.get("ember", Color.ORANGE)}
				var heal := empower_heal()
				if heal > 0.0:
					opts["heal_hero_frac"] = heal
				var dmg := totem_dmg() * (1.5 if empowered() else 1.0)
				run.fire_projectile("fire_bolt", t.pos + Vector3(0, 1.4, 0), target, Vector3.ZERO, 17.0, dmg, 0, hero, "Ember Totem", opts)
			else:
				t.atk_cd = 0.2
	if totems.size() > 0 and not totems[0].alive:
		_prune_totems()


func on_wave_end() -> void:
	for t in totems:
		run.remove_ally(t, false)
	totems.clear()
	foundry_t = 0.0
	run.fx_stop(foundry_fx)
	foundry_fx = null


func on_teleport(_p: Vector3) -> void:
	pass


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			var near := run.nearest_enemy(hero.pos, 11.0)
			if near == null:
				return false
			if _alive_totems().size() < max_totems():
				return true
			# refresh an old totem that is far behind
			var far := true
			for t in _alive_totems():
				if run._flat(t.pos - hero.pos).length() < 10.0:
					far = false
			return far
		1:
			if run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 9.0) != null:
				return true
			return run.count_enemies(hero.pos, 9.0) >= 4
		2:
			var c := run.best_cluster(hero.pos, 11.0, 4.0)
			return not c.is_empty() and int(c["count"]) >= 3
		3:
			if run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 12.0) != null:
				return true
			return run.count_enemies(hero.pos, 10.0) >= 8 or (hero.hp < hero.max_hp * 0.45 and run.count_enemies(hero.pos, 8.0) >= 3)
	return false
