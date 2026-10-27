extends HeroKit
## Skyspear: the spear is a thing in the world. Hurl it and it stays planted where it lands; until it comes back
## she fights with fists (short, quick, weak). Recall flies every planted spear back through the pack,
## Vault leaps (to the spear if it is out), Skyfall rains extra spears that Recall also pulls home.

const SKY := Color(0.55, 0.85, 1.0)
const BRONZE := Color(1.0, 0.75, 0.4)
const SPEAR_REACH := 2.8
const FIST_REACH := 1.5
const SPEED := 26.0

var spear := {}              # the main spear while out: {pos, fx} (in flight: {from, to, t, dur, hit})
var flying: Array = []       # spears in the air: {from, to, t, dur, hit: {}, main, back}
var planted: Array = []      # extra Skyfall spears: {pos, t, fx}
var volley: Array = []       # Skyfall spears still to land: {pos, t, fx}
var leap := {}               # {from, to, t, dur}


func in_hand() -> bool:
	return spear.is_empty() and not _main_flying()


func _main_flying() -> bool:
	for f in flying:
		if f["main"]:
			return true
	return false


func attack_speed_mult() -> float:
	return 1.0 if in_hand() else 1.45


func damage_mult() -> float:
	return 1.0 if in_hand() else 0.55


func _sync_reach() -> void:
	var r := SPEAR_REACH if in_hand() else FIST_REACH
	if absf(hero.base_range - r) > 0.01:
		hero.set_base_range(r)


func can_cast(slot: int) -> bool:
	match slot:
		0:
			if not in_hand():
				run.toast("Your spear is out: Recall it", SKY)
				return false
		2:
			return leap.is_empty()
	return true


func blocked(slot: int) -> bool:
	return slot == 0 and not in_hand()


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0:
			var c := run.best_cluster(hero.pos, 10.0, 1.6)
			if not c.is_empty():
				return {"dir": run._flat(c["pos"] - hero.pos).normalized(), "point": c["pos"]}
			var n := run.nearest_enemy(hero.pos, 11.0)
			if n:
				return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
		2:
			if not spear.is_empty():
				return {"point": spear["pos"]}
			var c2 := run.best_cluster(hero.pos, 9.0, 2.5)
			if not c2.is_empty():
				return {"point": c2["pos"]}
		3:
			var c3 := run.best_cluster(hero.pos, 11.0, 4.0)
			if not c3.is_empty():
				return {"point": c3["pos"]}
	return {"point": hero.pos + hero.facing * 5.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			var d := aim_dir(aim)
			hero.face(d)
			var to := run.resolve_pos(hero, hero.pos + d * DB.SKILLS["hurl_spear"]["range"], hero.pos)
			to = stop_at_pillars(hero.pos, to)
			_throw(hero.pos, to, true, false)
			hero.set_state("attack", true)
			Audio.play("slash")
			_sync_reach()
			return true
		1:
			# spears still flying out turn round in mid-air
			for f in flying:
				if not f["back"]:
					var at: Vector3 = f["from"].lerp(f["to"], clampf(f["t"] / f["dur"], 0.0, 1.0))
					run.fx_stop(f["fx"])
					f["from"] = at
					f["back"] = true
					f["t"] = 0.0
					f["dur"] = maxf(0.08, run._flat(hero.pos - at).length() / SPEED)
					f["hit"] = {}
					f["fx"] = run.fx("slip_trail", {"from": at + Vector3(0, 1.0, 0), "to": hero.pos + Vector3(0, 1.0, 0), "color": SKY})
			var any := not spear.is_empty() or not planted.is_empty() or not flying.is_empty()
			if not any:
				_spin()
				return true
			if not spear.is_empty():
				_throw(spear["pos"], hero.pos, true, true)
				run.fx_stop(spear["fx"])
				spear = {}
			for s in planted:
				_throw(s["pos"], hero.pos, false, true)
				run.fx_stop(s["fx"])
			planted.clear()
			Audio.play("slash")
			return true
		2:
			var p: Vector3 = spear["pos"] if not spear.is_empty() else clamp_point(aim.get("point", hero.pos + hero.facing * 5.0), DB.SKILLS["vault"]["range"])
			leap = {"from": hero.pos, "to": p, "t": 0.0, "dur": 0.4}
			hero.face(p - hero.pos)
			return true
		3:
			var c := clamp_point(aim.get("point", hero.pos + hero.facing * 6.0), DB.SKILLS["skyfall"]["range"])
			var n: int = [6, 8, 10][clampi(rank(3) - 1, 0, 2)]
			var r: float = DB.SKILLS["skyfall"]["radius"]
			run.fx("telegraph_circle", {"pos": c, "radius": r, "duration": 1.5, "color": SKY})
			for i in n:
				var a := run.rng.randf() * TAU
				var q := run.resolve_pos(hero, c + Vector3(cos(a), 0, sin(a)) * sqrt(run.rng.randf()) * (r - 0.4), c)
				volley.append({"pos": q, "t": 0.4 + 1.1 * float(i) / n})
			hero.set_state("cast", true)
			return true
	return false


func _throw(from: Vector3, to: Vector3, main: bool, back: bool) -> void:
	var dur := maxf(0.08, run._flat(to - from).length() / SPEED)
	var f := {"from": from, "to": to, "t": 0.0, "dur": dur, "hit": {}, "main": main, "back": back}
	f["fx"] = run.fx("slip_trail", {"from": from + Vector3(0, 1.0, 0), "to": to + Vector3(0, 1.0, 0), "color": SKY})
	flying.append(f)


func _spin() -> void:
	var dmg := 45.0 + 30.0 * rank(1) + 0.8 * hero.agi_v
	run.fx("cone", {"pos": hero.pos, "dir": hero.facing, "range": 3.2, "angle": 359.0, "color": SKY})
	for e in run.enemies_in_radius(hero.pos, 3.2):
		run.damage(e, dmg, hero, "Spear Spin", "phys", {"color": SKY})
		if e.alive:
			shove(e, e.pos - hero.pos, 5.0)
	hero.set_state("attack", true)
	Audio.play("slash")


func _land_spear(f: Dictionary) -> void:
	if f["back"]:
		# back in her hand
		run.fx("hit", {"pos": hero.pos + Vector3(0, 1.3, 0), "color": SKY})
		return
	spear = {"pos": f["to"], "fx": run.fx("rally_marker", {"pos": f["to"], "duration": 0.0, "color": SKY})}


func _tick_flying(dt: float) -> void:
	var keep := []
	for f in flying:
		f["t"] += dt
		# a returning spear homes on wherever she is now
		if f["back"]:
			f["to"] = hero.pos
		var k := clampf(f["t"] / f["dur"], 0.0, 1.0)
		var a: Vector3 = f["from"].lerp(f["to"], maxf(0.0, k - dt / f["dur"]))
		var b: Vector3 = f["from"].lerp(f["to"], k)
		var dmg := (55.0 + 40.0 * rank(0) + 1.3 * hero.agi_v) if not f["back"] else (40.0 + 30.0 * rank(1) + 1.0 * hero.agi_v)
		if not f["main"]:
			dmg *= 0.6
		for e in enemies_on_line(a, b, 1.4):
			if f["hit"].has(e):
				continue
			f["hit"][e] = true
			run.damage(e, dmg, hero, "Recall" if f["back"] else "Hurl Spear", "phys", {"color": SKY})
			if e.alive and f["back"]:
				# dragged along toward her
				var to := run._flat(hero.pos - e.pos)
				if to.length() > 1.6:
					e.pull_to = e.pos + to.normalized() * minf(3.5, to.length() - 1.2)
					e.pull_t = 0.25 if not e.is_boss else 0.0
		if k >= 1.0:
			run.fx_stop(f["fx"])
			if f["main"]:
				_land_spear(f)
		else:
			keep.append(f)
	flying = keep


func override_motion(dt: float) -> bool:
	if leap.is_empty():
		return false
	leap["t"] += dt
	var k := clampf(leap["t"] / leap["dur"], 0.0, 1.0)
	var p: Vector3 = leap["from"].lerp(leap["to"], k)
	hero.pos = run.resolve_pos(hero, p, hero.pos)
	if hero.node and is_instance_valid(hero.node):
		hero.node.position.y = sin(k * PI) * 1.6
	if k >= 1.0:
		_land_leap()
	return true


func override_motion_active() -> bool:
	return not leap.is_empty()


func _land_leap() -> void:
	leap = {}
	if hero.node and is_instance_valid(hero.node):
		hero.node.position.y = 0.0
	var r: float = DB.SKILLS["vault"]["radius"]
	if not spear.is_empty() and run._flat(spear["pos"] - hero.pos).length() < 1.6:
		run.fx_stop(spear["fx"])
		spear = {}
	run.fx("slam", {"pos": hero.pos, "radius": r, "color": SKY})
	var dmg := 60.0 + 45.0 * rank(2) + 1.0 * hero.agi_v
	for e in run.enemies_in_radius(hero.pos, r):
		run.damage(e, dmg, hero, "Vault", "phys", {"color": SKY})
		if e.alive:
			stun(e, 1.0)
	run.shake(0.25)
	Audio.play("slam")


func tick(dt: float) -> void:
	if not flying.is_empty():
		_tick_flying(dt)
	if not volley.is_empty():
		var keep := []
		for v in volley:
			v["t"] -= dt
			if v["t"] <= 0.0:
				var dmg := 50.0 + 35.0 * rank(3) + 0.9 * hero.agi_v
				run.fx("hit", {"pos": v["pos"] + Vector3(0, 0.4, 0), "color": SKY})
				for e in run.enemies_in_radius(v["pos"], 1.4):
					run.damage(e, dmg, hero, "Skyfall", "phys", {"color": SKY})
					if e.alive:
						e.apply_slow(0.3, 1.5)
				planted.append({"pos": v["pos"], "t": 8.0, "fx": run.fx("rally_marker", {"pos": v["pos"], "duration": 0.0, "color": BRONZE})})
			else:
				keep.append(v)
		volley = keep
	if not planted.is_empty():
		var keep2 := []
		for s in planted:
			s["t"] -= dt
			if s["t"] <= 0.0:
				run.fx_stop(s["fx"])
			else:
				keep2.append(s)
		planted = keep2
	_sync_reach()


func basic_attack(target: Unit, _dmg: float, _crit: bool) -> bool:
	if not (target is Barrel) and in_hand():
		run.fx("hit", {"pos": target.pos + Vector3(0, 1.0, 0), "color": SKY})
	return false


func _clear() -> void:
	for f in flying:
		run.fx_stop(f["fx"])
	flying.clear()
	if not spear.is_empty():
		run.fx_stop(spear["fx"])
	spear = {}
	for s in planted:
		run.fx_stop(s["fx"])
	planted.clear()
	volley.clear()
	if not leap.is_empty():
		leap = {}
		if hero.node and is_instance_valid(hero.node):
			hero.node.position.y = 0.0
	_sync_reach()


func on_wave_end() -> void:
	_clear()


func on_teleport(_p: Vector3) -> void:
	_clear()


func hud_meter() -> Dictionary:
	if in_hand():
		return {"type": "bar", "label": "Spear in hand", "value": 1.0, "max": 1.0, "color": SKY}
	return {"type": "bar", "label": "Fists! Recall the spear", "value": 0.0, "max": 1.0, "color": BRONZE}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			var c := run.best_cluster(hero.pos, 10.0, 1.6)
			# a straggler the bot cannot walk to (barrels, the wall) still gets a spear
			return in_hand() and not c.is_empty() and (int(c["count"]) >= 2 or run.boss_units.size() > 0 or run.count_enemies(hero.pos, 40.0) <= 2)
		1:
			if spear.is_empty() and planted.is_empty():
				return run.count_enemies(hero.pos, 3.2) >= 3
			return true
		2:
			return not spear.is_empty() and run._flat(spear["pos"] - hero.pos).length() > 3.0 and hero.hp > hero.max_hp * 0.5
		3:
			var c3 := run.best_cluster(hero.pos, 11.0, 4.0)
			return not c3.is_empty() and (int(c3["count"]) >= 5 or run.boss_units.size() > 0)
	return false
