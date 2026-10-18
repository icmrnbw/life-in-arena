extends HeroKit
## Gunsmith: long-range rifle with a 6-round magazine and a reload when it runs dry.
## Hot Reload (incendiary rounds when reloading on an empty/last bullet), Scattershot, Mortar, Deadeye.

const BLUE := Color(0.45, 0.78, 1.0)
const FIRE := Color(1.0, 0.55, 0.2)
const MAG := 8
const RELOAD_TIME := 1.5

var ammo := MAG
var reload_t := 0.0
var hot := 0               # incendiary rounds left
var shells: Array = []     # {pos, t, fx}
var deadeye := {}          # {targets: [], t}


func hot_bonus() -> float:
	return [0.35, 0.45, 0.55, 0.65][clampi(rank(0) - 1, 0, 3)]


func reloading() -> bool:
	return reload_t > 0.0


func _reload_now(perfect: bool) -> void:
	ammo = MAG
	reload_t = 0.0
	if perfect:
		hot = MAG
		run.toast("Incendiary rounds!", FIRE)
	run.fx("hit", {"pos": hero.pos + Vector3(0, 1.3, 0), "color": FIRE if perfect else BLUE})


func blocked(slot: int) -> bool:
	return slot == 1 and ammo <= 0


func can_cast(slot: int) -> bool:
	match slot:
		1:
			if ammo <= 0:
				run.toast("Empty! Reload first", BLUE)
				return false
		3:
			if not deadeye.is_empty():
				return false
			return run.nearest_enemy(hero.pos, 16.0) != null
	return true


func smart_aim(slot: int) -> Dictionary:
	match slot:
		1:
			var c := run.best_cluster(hero.pos, 6.0, 2.5)
			if not c.is_empty():
				return {"dir": run._flat(c["pos"] - hero.pos).normalized(), "point": c["pos"]}
			var n := run.nearest_enemy(hero.pos, 8.0)
			if n:
				return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
		2:
			var c2 := run.best_cluster(hero.pos, 14.0, 3.2)
			if not c2.is_empty() and run._flat(c2["pos"] - hero.pos).length() >= 4.0:
				return {"point": c2["pos"]}
			var n2 := run.nearest_enemy(hero.pos, 14.0)
			if n2:
				var d := run._flat(n2.pos - hero.pos)
				return {"point": hero.pos + d.normalized() * maxf(4.0, d.length())}
	return {"point": hero.pos + hero.facing * 6.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			_reload_now(ammo <= 1)
			return true
		1:
			return _scatter(aim)
		2:
			return _mortar(aim)
		3:
			return _deadeye()
	return false


func _shot_opts(crit: bool) -> Dictionary:
	var o := {"dtype": "phys", "attack": true, "crit": crit, "color": FIRE if hot > 0 else BLUE}
	return o


func _scatter(aim: Dictionary) -> bool:
	var d := aim_dir(aim)
	hero.face(d)
	var pellets := 2 * ammo
	ammo = 0
	reload_t = RELOAD_TIME
	var dmg := (14.0 + 9.0 * rank(1) + 0.3 * hero.agi_v) * (1.0 + (hot_bonus() if hot > 0 else 0.0))
	run.fx("cone", {"pos": hero.pos, "dir": d, "range": 6.5, "angle": 50.0, "color": BLUE})
	var from := hero.pos + Vector3(0, 1.2, 0) + d * 0.6
	for i in pellets:
		var a := run.rng.randf_range(-0.42, 0.42)
		var pd := d.rotated(Vector3.UP, a)
		run.fire_projectile("bullet", from, null, pd, 30.0, dmg, 0, hero, "Scattershot",
			{"dtype": "phys", "color": BLUE, "life": 0.24, "hit_r": 0.5})
	for e in enemies_in_cone(hero.pos, d, 5.0, 50.0):
		shove(e, e.pos - hero.pos, 7.0)
	hot = 0
	run.shake(0.18)
	Audio.play("slam")
	return true


func _mortar(aim: Dictionary) -> bool:
	var p := clamp_point(aim.get("point", hero.pos + hero.facing * 8.0), DB.SKILLS["mortar"]["range"])
	var off := run._flat(p - hero.pos)
	if off.length() < 4.0:
		p = run.resolve_pos(hero, hero.pos + (off.normalized() if off.length() > 0.1 else hero.facing) * 4.0, hero.pos)
	var rad: float = DB.SKILLS["mortar"]["radius"]
	shells.append({"pos": p, "t": 1.0, "fx": run.fx("telegraph_circle", {"pos": p, "radius": rad, "duration": 1.0, "color": BLUE})})
	run.fx("hit", {"pos": hero.pos + Vector3(0, 1.8, 0), "color": FIRE})
	return true


func _deadeye() -> bool:
	var n: int = [4, 5, 6][clampi(rank(3) - 1, 0, 2)]
	var cands := run.enemies_in_radius(hero.pos, 16.0)
	cands.sort_custom(func(a, b):
		if a.is_boss != b.is_boss:
			return a.is_boss
		return a.hp > b.hp)
	var targets := []
	for e in cands:
		if targets.size() >= n:
			break
		targets.append(e)
		e.mark_fx = run.fx("mark", {"target": e.node, "pos": e.pos, "color": BLUE})
	deadeye = {"targets": targets, "t": 0.8, "next": 0.0}
	return true


func _fire_deadeye(e: Unit) -> void:
	if e.mark_fx != null:
		run.fx_stop(e.mark_fx)
		e.mark_fx = null
	if not e.alive:
		return
	var dmg := (180.0 + 120.0 * rank(3) + 2.0 * hero.agi_v) * (1.5 if e.is_boss else 1.0)
	var a := hero.pos + Vector3(0, 1.3, 0)
	run.fx_timed("beam", {"from": a, "to": e.pos + Vector3(0, 1.0, 0), "width": 0.18, "duration": 0.18, "color": BLUE}, 0.18)
	run.damage(e, dmg, hero, "Deadeye", "phys", {"crit": true, "color": BLUE})
	hero.face(e.pos - hero.pos)
	hero.set_state("attack")
	run.shake(0.1)


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel:
		return false
	if reloading() or ammo <= 0:
		return true
	ammo -= 1
	var d := dmg
	var opts := _shot_opts(crit)
	if hot > 0:
		d *= 1.0 + hot_bonus()
		hot -= 1
	run.fire_projectile("bullet", hero.pos + Vector3(0, 1.3, 0), target, Vector3.ZERO, 34.0, d, 0, hero, "Rifle", opts)
	if opts["color"] == FIRE:
		target.burn_dps = maxf(target.burn_dps, 10.0 + 0.4 * hero.agi_v)
		target.burn_t = 3.0
		target.burn_src = hero
	if ammo <= 0:
		reload_t = RELOAD_TIME
	Audio.play("hit")
	return true


func can_attack() -> bool:
	return not reloading() and ammo > 0 and deadeye.is_empty()


func tick(dt: float) -> void:
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			_reload_now(false)
	if not shells.is_empty():
		var keep := []
		var rad: float = DB.SKILLS["mortar"]["radius"]
		for s in shells:
			s["t"] -= dt
			if s["t"] <= 0.0:
				run.fx("explosion", {"pos": s["pos"], "radius": rad})
				var dmg := 80.0 + 55.0 * rank(2) + 1.0 * hero.agi_v
				for e in run.enemies_in_radius(s["pos"], rad):
					run.damage(e, dmg, hero, "Mortar", "magic", {"color": FIRE})
					if e.alive:
						e.apply_slow(0.4, 2.0)
				run.shake(0.25)
				Audio.play("slam")
			else:
				keep.append(s)
		shells = keep
	if not deadeye.is_empty():
		deadeye["t"] -= dt
		if deadeye["t"] <= 0.0:
			deadeye["next"] -= dt
			if deadeye["next"] <= 0.0:
				var ts: Array = deadeye["targets"]
				if ts.is_empty():
					deadeye = {}
					_reload_now(false)
				else:
					deadeye["next"] = 0.12
					_fire_deadeye(ts.pop_front())


func on_wave_end() -> void:
	for s in shells:
		run.fx_stop(s["fx"])
	shells.clear()
	if not deadeye.is_empty():
		for e in deadeye["targets"]:
			if e.mark_fx != null:
				run.fx_stop(e.mark_fx)
				e.mark_fx = null
	deadeye = {}
	ammo = MAG
	reload_t = 0.0


func hud_meter() -> Dictionary:
	if reloading():
		return {"type": "bar", "label": "Reloading", "value": 1.0 - reload_t / RELOAD_TIME, "max": 1.0, "color": Color(0.6, 0.6, 0.65)}
	return {"type": "bar", "label": ("Ammo %d / %d" % [ammo, MAG]) + ("  hot" if hot > 0 else ""), "value": float(ammo), "max": float(MAG),
		"color": FIRE if hot > 0 else BLUE}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			return ammo <= 1 and run.nearest_enemy(hero.pos, 14.0) != null
		1:
			var c := run.best_cluster(hero.pos, 6.0, 2.5)
			return ammo >= 3 and not c.is_empty() and (int(c["count"]) >= 3 or run.count_enemies(hero.pos, 3.0) >= 2)
		2:
			var c2 := run.best_cluster(hero.pos, 14.0, 3.2)
			return not c2.is_empty() and int(c2["count"]) >= 3 and run._flat(c2["pos"] - hero.pos).length() >= 4.0
		3:
			return run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 16.0) != null or run.count_enemies(hero.pos, 16.0) >= 6
	return false
