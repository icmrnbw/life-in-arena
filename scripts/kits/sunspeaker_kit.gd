extends HeroKit
## Sunspeaker: Radiance (0-100) builds while standing still and powers every skill; moving drains it.
## Sunbeam (channel), Solar Flare, Sanctum, Dawn Lance.

const SUN := Color(1.0, 0.88, 0.45)

var radiance := 0.0
var beam := {}            # {dir, t, tick, fx}
var flares: Array = []    # {pos, t, fx}
var sanctum := {}         # {pos, r, t, fx}
var lance := {}           # {dir, t, fx}


func rad_mult() -> float:
	return 1.0 + radiance * 0.006


func channeling() -> bool:
	return not beam.is_empty() or not lance.is_empty()


func in_sanctum() -> bool:
	return not sanctum.is_empty() and run._flat(hero.pos - sanctum["pos"]).length() <= sanctum["r"]


func can_attack() -> bool:
	return not channeling()


## Flare and Sanctum can be woven into a Sunbeam (Dawn Lance replaces it); the Dawn Lance wind-up allows only Sanctum.
func can_cast(slot: int) -> bool:
	if not lance.is_empty():
		return slot == 2
	if slot == 0 and not beam.is_empty():
		return false
	return true


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0, 3:
			var c := run.best_cluster(hero.pos, 11.0 if slot == 0 else 20.0, 2.0)
			if not c.is_empty():
				return {"dir": run._flat(c["pos"] - hero.pos).normalized(), "point": c["pos"]}
			var n := run.nearest_enemy(hero.pos, 16.0)
			if n:
				return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
		1:
			var c2 := run.best_cluster(hero.pos, 12.0, 3.0)
			if not c2.is_empty():
				return {"point": c2["pos"]}
	return {"point": hero.pos + hero.facing * 5.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			var d := aim_dir(aim)
			hero.face(d)
			var a := hero.pos + Vector3(0, 1.3, 0)
			beam = {"dir": d, "t": 3.0, "tick": 0.0,
				"fx": run.fx("beam", {"from": a, "to": a + d * DB.SKILLS["sunbeam"]["range"], "width": 1.0, "color": SUN})}
			Audio.play("beam")
			return true
		1:
			var p := clamp_point(aim.get("point", hero.pos + hero.facing * 6.0), DB.SKILLS["solar_flare"]["range"])
			flares.append({"pos": p, "t": 0.6, "fx": run.fx("telegraph_circle", {"pos": p, "radius": 3.0, "duration": 0.6, "color": SUN})})
			return true
		2:
			if not sanctum.is_empty():
				run.fx_stop(sanctum["fx"])
			var r: float = DB.SKILLS["sanctum"]["radius"]
			sanctum = {"pos": hero.pos, "r": r, "t": 6.0, "fx": run.fx("zone", {"pos": hero.pos, "radius": r, "duration": 6.0, "color": SUN})}
			run.fx("ring_burst", {"pos": hero.pos, "radius": r, "color": SUN})
			return true
		3:
			_end_beam()
			var d2 := aim_dir(aim)
			hero.face(d2)
			var len: float = DB.SKILLS["dawn_lance"]["range"]
			lance = {"dir": d2, "t": 1.2,
				"fx": run.fx("telegraph_line", {"from": hero.pos, "to": hero.pos + d2 * len, "width": 3.0, "duration": 1.2})}
			return true
	return false


func _end_beam() -> void:
	if beam.is_empty():
		return
	run.fx_stop(beam["fx"])
	beam = {}


func _fire_lance() -> void:
	var d: Vector3 = lance["dir"]
	var len: float = DB.SKILLS["dawn_lance"]["range"]
	var a := hero.pos
	var b := hero.pos + d * len
	var spent := radiance
	var dmg := (300.0 + 200.0 * rank(3) + 3.0 * hero.int_v) * (0.6 + spent / 100.0)
	run.fx_timed("beam", {"from": a + Vector3(0, 1.3, 0), "to": b + Vector3(0, 1.3, 0), "width": 3.0, "color": SUN}, 0.5)
	run.fx("ring_burst", {"pos": hero.pos, "radius": 2.5, "color": SUN})
	for e in enemies_on_line(a, b, 3.0):
		run.damage(e, dmg, hero, "Dawn Lance", "magic", {"crit": true, "color": SUN})
	radiance = 0.0
	run.shake(0.45)
	Audio.play("beam")


## Channels root the Sunspeaker; pushing the stick ends a Sunbeam (not the Dawn Lance wind-up).
func override_motion(_dt: float) -> bool:
	if not lance.is_empty():
		return true
	if not beam.is_empty():
		if hero.move_input.length() > 0.5:
			_end_beam()
			return false
		return true
	return false


func _tick_beam(dt: float) -> void:
	beam["t"] -= dt
	if beam["t"] <= 0.0:
		_end_beam()
		return
	# slowly turn toward the densest group in front
	var c := run.best_cluster(hero.pos, 12.0, 2.0)
	if not c.is_empty():
		var want := run._flat(c["pos"] - hero.pos).normalized()
		var cur: Vector3 = beam["dir"]
		var ang := cur.signed_angle_to(want, Vector3.UP)
		beam["dir"] = cur.rotated(Vector3.UP, clampf(ang, -1.3 * dt, 1.3 * dt)).normalized()
	var d: Vector3 = beam["dir"]
	hero.face(d)
	var a := hero.pos
	var len: float = DB.SKILLS["sunbeam"]["range"]
	var b := a + d * len
	run.fx_params(beam["fx"], {"from": a + Vector3(0, 1.3, 0), "to": b + Vector3(0, 1.3, 0), "width": 0.8 + radiance * 0.006})
	beam["tick"] -= dt
	if beam["tick"] <= 0.0:
		beam["tick"] = 0.2
		var dps := (45.0 + 35.0 * rank(0) + 0.8 * hero.int_v) * rad_mult()
		for e in enemies_on_line(a, b, 1.4):
			run.damage(e, dps * 0.2, hero, "Sunbeam", "magic", {"color": SUN})


func tick(dt: float) -> void:
	# Radiance
	var still := channeling() or hero.still_t > 0.25
	if hero.in_camp:
		radiance = maxf(0.0, radiance - 10.0 * dt)
	elif still:
		radiance = minf(100.0, radiance + 16.0 * dt * (2.0 if in_sanctum() else 1.0))
	else:
		radiance = maxf(0.0, radiance - 22.0 * dt)
	if not beam.is_empty():
		_tick_beam(dt)
	if not lance.is_empty():
		lance["t"] -= dt
		if lance["t"] <= 0.0:
			_fire_lance()
			lance = {}
	if not flares.is_empty():
		var keep := []
		for f in flares:
			f["t"] -= dt
			if f["t"] <= 0.0:
				run.fx("explosion", {"pos": f["pos"], "radius": 3.0, "color": SUN})
				var dmg := (70.0 + 50.0 * rank(1) + 1.0 * hero.int_v) * rad_mult()
				for e in run.enemies_in_radius(f["pos"], 3.0):
					run.damage(e, dmg, hero, "Solar Flare", "magic", {"color": SUN})
				run.shake(0.18)
			else:
				keep.append(f)
		flares = keep
	if not sanctum.is_empty():
		sanctum["t"] -= dt
		if in_sanctum():
			run.heal_unit(hero, hero.max_hp * (0.01 + 0.004 * rank(2)) * dt, false)
		for e in run.enemies_in_radius(sanctum["pos"], sanctum["r"]):
			e.apply_slow(0.25 + 0.05 * rank(2), 0.3)
		if sanctum["t"] <= 0.0:
			run.fx_stop(sanctum["fx"])
			sanctum = {}


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel:
		return false
	var opts := {"dtype": "phys", "attack": true, "crit": crit, "color": SUN}
	run.fire_projectile("hero_bolt", hero.pos + Vector3(0, 1.3, 0), target, Vector3.ZERO, 18.0, dmg * (1.0 + radiance * 0.003), 0, hero, "Sun Bolt", opts)
	return true


func on_teleport(_p: Vector3) -> void:
	_end_beam()
	if not lance.is_empty():
		run.fx_stop(lance["fx"])
	lance = {}


func on_wave_end() -> void:
	_end_beam()
	if not lance.is_empty():
		run.fx_stop(lance["fx"])
	lance = {}
	for f in flares:
		run.fx_stop(f["fx"])
	flares.clear()
	if not sanctum.is_empty():
		run.fx_stop(sanctum["fx"])
	sanctum = {}


func on_wave_start() -> void:
	radiance = maxf(radiance, 25.0)


func hud_meter() -> Dictionary:
	return {"type": "bar", "label": "Radiance %d" % int(radiance), "value": radiance, "max": 100.0, "color": SUN}


func bot_wants(slot: int) -> bool:
	if channeling():
		return false
	match slot:
		0:
			var c := run.best_cluster(hero.pos, 11.0, 2.0)
			return not c.is_empty() and run.count_enemies(hero.pos, 3.0) == 0
		1:
			var c2 := run.best_cluster(hero.pos, 12.0, 3.0)
			return not c2.is_empty() and (int(c2["count"]) >= 2 or run.boss_units.size() > 0 or run.count_enemies(hero.pos, 30.0) <= 4)
		2:
			return run.count_enemies(hero.pos, 10.0) >= 3 or hero.hp < hero.max_hp * 0.6
		3:
			return radiance >= 60.0 and (run.count_enemies(hero.pos, 20.0) >= 6 or (run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 18.0) != null))
	return false


func override_motion_active() -> bool:
	return channeling()
