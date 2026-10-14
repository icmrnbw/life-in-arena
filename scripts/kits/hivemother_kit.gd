extends HeroKit
## Hivemother: Brood, Rally Pheromone, Volatile Sacrifice, Queen's Carapace. Broodlings are allied units.

var brood: Array = []
var rally_pos := Vector3.ZERO
var rally_t := 0.0
var rally_fx: Node = null
var carapace_t := 0.0
var carapace_fx: Node = null


func cap() -> int:
	return [0, 4, 6, 8, 10][clampi(rank(0), 0, 4)]


func alive_brood() -> Array:
	var out := []
	for b in brood:
		if b.alive:
			out.append(b)
	return out


func brood_count() -> int:
	var n := 0
	for b in brood:
		if b.alive:
			n += 1
	return n


func rally_as() -> float:
	return [0.0, 0.30, 0.45, 0.60, 0.75][clampi(rank(1), 0, 4)]


func can_cast(slot: int) -> bool:
	match slot:
		0:
			if brood_count() >= cap():
				run.toast("Brood is at full size (%d)" % cap(), Art.palette.get("dim", Color.GRAY))
				return false
		1:
			return brood_count() > 0 or true
		2:
			if brood_count() == 0:
				run.toast("No broodlings to sacrifice", Art.palette.get("dim", Color.GRAY))
				return false
		3:
			if brood_count() == 0:
				run.toast("Need broodlings for the carapace", Art.palette.get("dim", Color.GRAY))
				return false
	return true


func smart_aim(slot: int) -> Dictionary:
	if slot == 1:
		var c := run.best_cluster(hero.pos, 14.0, 3.5)
		if not c.is_empty():
			return {"point": c["pos"], "dir": run._flat(c["pos"] - hero.pos).normalized()}
		var n := run.nearest_enemy(hero.pos, 16.0)
		if n:
			return {"point": n.pos, "dir": run._flat(n.pos - hero.pos).normalized()}
		return {"point": hero.pos + hero.facing * 5.0, "dir": hero.facing}
	return {"point": hero.pos, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			return _hatch(2)
		1:
			return _rally(aim)
		2:
			return _sacrifice()
		3:
			return _carapace()
	return false


func _hatch(n: int) -> bool:
	var made := 0
	for i in n:
		if brood_count() >= cap():
			break
		var ang := run.rng.randf() * TAU
		var p := hero.pos + Vector3(cos(ang), 0, sin(ang)) * 1.4
		p = run.resolve_pos(hero, p, hero.pos)
		var b := run.spawn_summon("broodling", p)
		b.radius = clampf(b.radius, 0.25, 0.5)
		b.max_hp = 75.0 + 35.0 * rank(0) + 7.0 * hero.level
		b.hp = b.max_hp
		b.armor = 1.0 + hero.level * 0.2
		b.atk_dmg = 7.0 + 4.5 * rank(0) + 0.38 * hero.int_v
		b.atk_time = 1.0
		b.atk_range = 0.9
		b.base_speed = 6.4
		brood.append(b)
		run.fx("brood_hatch", {"pos": p})
		made += 1
	return made > 0


func _rally(aim: Dictionary) -> bool:
	rally_pos = clamp_point(aim.get("point", hero.pos + hero.facing * 6.0), DB.SKILLS["rally_pheromone"]["range"])
	rally_t = 3.0 + 1.0 * rank(1)
	run.fx_stop(rally_fx)
	rally_fx = run.fx("rally_marker", {"pos": rally_pos, "duration": rally_t})
	return true


func _sacrifice() -> bool:
	var n := 2 + rank(2)
	var bs := alive_brood()
	# prefer broodlings that are touching enemies, then the ones nearest to the mother
	var scored := []
	for b in bs:
		var s := float(run.count_enemies(b.pos, 3.0)) * 10.0 - run._flat(b.pos - hero.pos).length() * 0.1
		scored.append([s, b])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var dmg := 55.0 + 42.0 * rank(2) + 0.9 * hero.int_v
	var used := 0
	for pair in scored:
		if used >= n:
			break
		var b: Unit = pair[1]
		var p := b.pos
		run.fx("sacrifice_explosion", {"pos": p, "radius": 3.0})
		for e in run.enemies_in_radius(p, 3.0):
			run.damage(e, dmg, hero, "Volatile Sacrifice", "magic", {"color": Color(0.7, 1.0, 0.4)})
		run.remove_ally(b, false)
		used += 1
	hero.mana = minf(hero.max_mana, hero.mana + 15.0 * used)
	run.shake(0.15 + 0.05 * used)
	brood = alive_brood()
	return used > 0


func _carapace() -> bool:
	var bs := alive_brood()
	bs.sort_custom(func(a, b): return run._flat(a.pos - hero.pos).length() < run._flat(b.pos - hero.pos).length())
	var per: float = [130.0, 185.0, 240.0][clampi(rank(3) - 1, 0, 2)] + 3.0 * hero.int_v
	var used := 0
	for b in bs:
		if used >= 6:
			break
		if run._flat(b.pos - hero.pos).length() > 14.0:
			continue
		run.fx("slip_trail", {"from": b.pos, "to": hero.pos})
		run.remove_ally(b, false)
		used += 1
	if used == 0:
		return false
	hero.shield += per * used
	carapace_t = [10.0, 12.0, 14.0][clampi(rank(3) - 1, 0, 2)]
	run.fx_stop(carapace_fx)
	carapace_fx = run.fx("carapace", {"target": hero.node, "duration": carapace_t, "pos": hero.pos})
	brood = alive_brood()
	return true


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	var from := hero.pos + Vector3(0, 1.2, 0)
	var opts := {"dtype": "phys", "attack": true, "spit_mark": true, "crit": crit, "color": Color(0.6, 1.0, 0.4)}
	if carapace_t > 0.0:
		var base := run._flat(target.pos - hero.pos).normalized()
		for a in [-0.35, 0.0, 0.35]:
			var d := base.rotated(Vector3.UP, a)
			var o := opts.duplicate()
			o["hit_r"] = 0.6
			o["life"] = 0.9
			run.fire_projectile("spit", from, null, d, 16.0, dmg * 1.2, 0, hero, "Spit", o)
	else:
		run.fire_projectile("spit", from, target, Vector3.ZERO, 16.0, dmg, 0, hero, "Spit", opts)
	return true


func tick(dt: float) -> void:
	if rally_t > 0.0:
		rally_t -= dt
		if rally_t <= 0.0:
			run.fx_stop(rally_fx)
			rally_fx = null
	if carapace_t > 0.0:
		carapace_t -= dt
		if carapace_t <= 0.0 or hero.shield <= 0.0:
			carapace_t = 0.0
			hero.shield = 0.0
			run.fx_stop(carapace_fx)
			carapace_fx = null
	var bs := alive_brood()
	if bs.size() != brood.size():
		brood = bs
	var i := 0
	for b in bs:
		_tick_broodling(b, dt, i, bs.size())
		i += 1


func _tick_broodling(b: Unit, dt: float, idx: int, total: int) -> void:
	if b.stun_t > 0.0:
		return
	if run.forced_motion(b, dt):
		return
	var anchor := hero.pos
	var leash := 9.0
	var as_mult := 1.0
	if rally_t > 0.0:
		anchor = rally_pos
		leash = 5.0
		as_mult = 1.0 + rally_as()
	# retarget
	b.retarget_t -= dt
	if b.retarget_t <= 0.0 or b.target == null or not b.target.alive or b.target.untargetable:
		b.retarget_t = 0.3
		b.target = _pick_target(b, anchor, leash)
	var t: Unit = b.target
	if b.atk_wind > 0.0:
		b.atk_wind -= dt
		if b.atk_wind <= 0.0 and t != null and t.alive and b.edge_dist(t) <= b.atk_range + 0.6:
			run.damage(t, b.atk_dmg, hero, "Brood", "phys")
		return
	if t != null:
		var d := b.edge_dist(t)
		if d > b.atk_range:
			var dir := run.steer_dir(b, t.pos)
			run.move_unit(b, dir * b.base_speed * (1.25 if rally_t > 0.0 else 1.0) * dt)
			b.face(dir)
			b.set_state("run")
		else:
			b.face(t.pos - b.pos)
			if b.atk_cd <= 0.0:
				b.atk_cd = b.atk_time / as_mult
				b.atk_wind = 0.18
				b.set_state("attack")
			else:
				b.set_state("idle")
		return
	# follow formation around the anchor
	var ang := TAU * float(idx) / maxf(1.0, float(total)) + run.run_time * 0.15
	var slot := anchor + Vector3(cos(ang), 0, sin(ang)) * (1.8 + 0.12 * total)
	if rally_t <= 0.0:
		slot += hero.facing * 0.8
	var to := run._flat(slot - b.pos)
	if to.length() > 0.4:
		var spd := b.base_speed * clampf(to.length() / 2.0, 0.4, 1.3)
		var dir2 := run.steer_dir(b, slot)
		run.move_unit(b, dir2 * spd * dt)
		b.face(dir2)
		b.set_state("run")
	else:
		b.set_state("idle")


func _pick_target(b: Unit, anchor: Vector3, leash: float) -> Unit:
	var best: Unit = null
	var bs := 1e9
	for e in run.enemies:
		if not e.alive or e.untargetable:
			continue
		var da := run._flat(e.pos - anchor).length()
		if da > leash + e.radius:
			continue
		var db := run._flat(e.pos - b.pos).length()
		var score := db
		if e.spit_mark_t > 0.0:
			score -= 6.0
		if e.taunt_target == b:
			score -= 2.0
		if score < bs:
			bs = score
			best = e
	return best


func on_teleport(p: Vector3) -> void:
	for b in alive_brood():
		var ang := run.rng.randf() * TAU
		b.pos = p + Vector3(cos(ang), 0, sin(ang)) * 1.6
		b.pos = run.resolve_pos(b, b.pos, p)
		b.target = null
		b.pull_t = 0.0
		b.knock = Vector3.ZERO
		if b.node and is_instance_valid(b.node):
			b.node.position = b.pos
	rally_t = 0.0
	run.fx_stop(rally_fx)
	rally_fx = null


func on_wave_end() -> void:
	carapace_t = 0.0
	hero.shield = 0.0
	run.fx_stop(carapace_fx)
	carapace_fx = null
	# broodlings heal up between waves
	for b in alive_brood():
		b.hp = b.max_hp


func on_rank_up(slot: int) -> void:
	if slot == 0:
		for b in alive_brood():
			var mh := 75.0 + 35.0 * rank(0) + 7.0 * hero.level
			b.hp += mh - b.max_hp
			b.max_hp = mh
			b.atk_dmg = 7.0 + 4.5 * rank(0) + 0.38 * hero.int_v


func hud_meter() -> Dictionary:
	return {"type": "brood", "count": brood_count(), "cap": cap()}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			return brood_count() < cap()
		1:
			if brood_count() < 3:
				return false
			var c := run.best_cluster(hero.pos, 14.0, 3.5)
			return not c.is_empty() and (int(c["count"]) >= 4 or run.boss_units.size() > 0)
		2:
			var touching := 0
			for b in alive_brood():
				if run.count_enemies(b.pos, 3.0) >= 2:
					touching += 1
			if touching >= 2 and brood_count() >= cap() - 1:
				return true
			return touching >= 1 and hero.hp < hero.max_hp * 0.4
		3:
			if brood_count() < 3:
				return false
			return hero.hp < hero.max_hp * 0.55 and run.count_enemies(hero.pos, 7.0) >= 2 or (run.boss_units.size() > 0 and brood_count() >= 5 and hero.hp < hero.max_hp * 0.8)
	return false
