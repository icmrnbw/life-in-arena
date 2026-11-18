extends HeroKit
## Chronomancer: time control. She keeps 4 s of her own history (position + HP) for Rewind.
## Time Bolt (slow; slowed foes take more), Stasis Field, Rewind, Time Stop (damage to stopped foes is held, then lands x1.25).

const TIME := Color(0.95, 0.85, 0.5)
const BLUE := Color(0.5, 0.75, 1.0)
const HISTORY := 4.0
const REWIND_BACK := 3.0
const HELD_MULT := 1.25

var history: Array = []      # [time, pos, hp], oldest first
var sample_t := 0.0
var fields: Array = []       # {pos, r, t, tick, fx}
var stopped := {}            # Enemy -> {"t": s, "held": dmg, "fx": mark}


## Every hit she deals goes through here: on a time-stopped foe it is held instead of dealt.
func hit(e: Unit, amount: float, tag: String, opts := {}) -> float:
	if stopped.has(e):
		stopped[e]["held"] += amount
		return 0.0
	var o := opts.duplicate()
	if not o.has("color"):
		o["color"] = TIME
	return run.damage(e, amount, hero, tag, "magic", o)


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0:
			var n := run.nearest_enemy(hero.pos, 11.0)
			for b in run.boss_units:
				if b.alive and run._flat(b.pos - hero.pos).length() < 11.0:
					n = b
			if n:
				return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
		1:
			var c := run.best_cluster(hero.pos, 10.0, 3.5)
			if not c.is_empty():
				return {"point": c["pos"]}
	return {"point": hero.pos + hero.facing * 5.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			var d := aim_dir(aim)
			hero.face(d)
			var t := run.nearest_enemy(hero.pos + d * 4.0, 6.0)
			var dmg := 60.0 + 45.0 * rank(0) + 1.2 * hero.int_v
			run.fire_projectile("time_bolt", hero.pos + Vector3(0, 1.3, 0), null, d, 20.0, 0.0, 0, hero, "Time Bolt",
				{"dtype": "magic", "color": TIME, "life": 0.6, "hit_r": 0.01})
			# resolved instantly along the line so the slow and the bonus are exact
			var a := hero.pos
			var b := a + d * DB.SKILLS["time_bolt"]["range"]
			var first: Unit = null
			var bd := 1e9
			for e in enemies_on_line(a, b, 1.2):
				var dd := run._flat(e.pos - a).length()
				if dd < bd:
					bd = dd
					first = e
			if first == null:
				first = t
			if first != null:
				var slowed := first.slow_t > 0.0 or stopped.has(first)
				run.fx("hit", {"pos": first.pos + Vector3(0, 1.0, 0), "color": TIME})
				hit(first, dmg * (1.3 if slowed else 1.0), "Time Bolt", {"crit": slowed})
				if first.alive:
					first.apply_slow(0.5, 2.0)
			Audio.play("orb")
			return true
		1:
			var p := clamp_point(aim.get("point", hero.pos + hero.facing * 6.0), DB.SKILLS["stasis_field"]["range"])
			var r: float = DB.SKILLS["stasis_field"]["radius"]
			fields.append({"pos": p, "r": r, "t": 5.0, "tick": 0.0, "fx": run.fx("zone", {"pos": p, "radius": r, "duration": 5.0, "color": BLUE})})
			return true
		2:
			_rewind()
			return true
		3:
			var dur: float = [2.5, 3.0, 3.5][clampi(rank(3) - 1, 0, 2)]
			run.fx("ring_burst", {"pos": hero.pos, "radius": 10.0, "color": TIME})
			for e in run.enemies_in_radius(hero.pos, DB.SKILLS["time_stop"]["range"]):
				var t2 := dur * (0.35 if e.is_boss else 1.0)
				e.stun_t = maxf(e.stun_t, t2)
				e.knock = Vector3.ZERO
				e.pull_t = 0.0
				if stopped.has(e):
					stopped[e]["t"] = maxf(stopped[e]["t"], t2)
				else:
					stopped[e] = {"t": t2, "held": 0.0, "fx": run.fx("mark", {"target": e.node, "pos": e.pos, "color": TIME})}
			run.toast("Time Stop!", TIME)
			run.shake(0.2)
			return true
	return false


func _rewind() -> void:
	var want := run.run_time - REWIND_BACK
	var snap: Array = history[0] if not history.is_empty() else [run.run_time, hero.pos, hero.hp]
	for h in history:
		if h[0] <= want:
			snap = h
	run.fx("teleport", {"pos": hero.pos, "color": TIME})
	var old := hero.pos
	hero.pos = run.resolve_pos(hero, snap[1], hero.pos)
	if hero.node and is_instance_valid(hero.node):
		hero.node.position = hero.pos
	run.fx("slip_trail", {"from": old, "to": hero.pos, "color": TIME})
	if snap[2] > hero.hp:
		run.heal_unit(hero, snap[2] - hero.hp)
	hero.cds[0] = 0.0
	hero.pull_t = 0.0
	hero.knock = Vector3.ZERO
	run.fx("teleport", {"pos": hero.pos, "color": TIME})
	Audio.play("teleport")


func _release(e: Unit, s: Dictionary) -> void:
	run.fx_stop(s["fx"])
	if e.alive and s["held"] > 0.0:
		run.fx("shatter", {"pos": e.pos, "color": TIME})
		run.damage(e, s["held"] * HELD_MULT, hero, "Time Stop", "magic", {"crit": true, "color": TIME})


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel:
		return false
	if stopped.has(target):
		stopped[target]["held"] += dmg
		run.fx("hit", {"pos": target.pos + Vector3(0, 1.0, 0), "color": TIME})
		return true
	run.fire_projectile("time_bolt", hero.pos + Vector3(0, 1.3, 0), target, Vector3.ZERO, 18.0, dmg, 0, hero, "Chrono Bolt",
		{"dtype": "magic", "attack": true, "crit": crit, "color": TIME})
	return true


func tick(dt: float) -> void:
	sample_t -= dt
	if sample_t <= 0.0:
		sample_t = 0.1
		history.append([run.run_time, hero.pos, hero.hp])
		while not history.is_empty() and history[0][0] < run.run_time - HISTORY:
			history.pop_front()
	if not fields.is_empty():
		var keep := []
		for f in fields:
			f["t"] -= dt
			f["tick"] -= dt
			var inside := run.enemies_in_radius(f["pos"], f["r"])
			for e in inside:
				e.apply_slow(0.6, 0.3)
				e.atk_cd = maxf(e.atk_cd, 0.0) + dt * 0.5   # their swings come half as often
			if f["tick"] <= 0.0:
				f["tick"] = 0.5
				var dps := 25.0 + 18.0 * rank(1) + 0.5 * hero.int_v
				for e in inside:
					hit(e, dps * 0.5, "Stasis Field", {"color": BLUE})
			if f["t"] <= 0.0:
				run.fx_stop(f["fx"])
			else:
				keep.append(f)
		fields = keep
	if not stopped.is_empty():
		for e in stopped.keys():
			var s: Dictionary = stopped[e]
			s["t"] -= dt
			if s["t"] <= 0.0 or not e.alive:
				stopped.erase(e)
				_release(e, s)


func _clear() -> void:
	for f in fields:
		run.fx_stop(f["fx"])
	fields.clear()
	for e in stopped.keys():
		run.fx_stop(stopped[e]["fx"])
	stopped.clear()


func on_wave_end() -> void:
	_clear()


func on_teleport(_p: Vector3) -> void:
	_clear()
	history.clear()


func hud_meter() -> Dictionary:
	var held := 0.0
	for e in stopped:
		held += stopped[e]["held"]
	if not stopped.is_empty():
		return {"type": "bar", "label": "Held %d" % int(held * HELD_MULT), "value": 1.0, "max": 1.0, "color": TIME}
	return {}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			return run.nearest_enemy(hero.pos, 11.0) != null
		1:
			var c := run.best_cluster(hero.pos, 10.0, 3.5)
			return not c.is_empty() and int(c["count"]) >= 3
		2:
			if history.is_empty():
				return false
			var old: Array = history[0]
			return hero.hp < hero.max_hp * 0.4 and old[2] > hero.hp + hero.max_hp * 0.15
		3:
			return run.count_enemies(hero.pos, 8.0) >= 6 or (run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 10.0) != null)
	return false
