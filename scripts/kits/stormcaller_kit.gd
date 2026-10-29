extends HeroKit
## Stormcaller: chain damage that grows per jump, so packs feed it. Every foe a chain hits adds Static (0-100);
## at full Static the next Chain Lightning overloads. Chain Lightning, Ball Lightning, Storm Step, Thunderstorm.

const BOLT := Color(0.7, 0.85, 1.0)
const VIOLET := Color(0.75, 0.55, 1.0)
const JUMP_R := 5.0

var static_v := 0.0
var balls: Array = []        # {pos, dir, t, tick, fx}
var storm_t := 0.0
var storm_tick := 0.0
var storm_fx: Node = null
var step := {}               # {from, to, t, dur}


func add_static(v: float) -> void:
	static_v = minf(100.0, static_v + v)


## Strike `first`, then jump to the nearest unhit foe up to `jumps` times, `grow` more damage per jump.
func chain(first: Unit, from: Vector3, dmg: float, jumps: int, grow: float, tag: String, static_per := 0.0) -> int:
	var hit := {}
	var cur: Unit = first
	var a := from
	var d := dmg
	var n := 0
	while cur != null and n <= jumps:
		hit[cur] = true
		run.fx_timed("beam", {"from": a, "to": cur.pos + Vector3(0, 1.0, 0), "width": 0.22, "color": BOLT}, 0.16)
		run.damage(cur, d, hero, tag, "magic", {"color": BOLT})
		add_static(static_per)
		a = cur.pos + Vector3(0, 1.0, 0)
		n += 1
		d *= 1.0 + grow
		var nxt: Unit = null
		var bd := JUMP_R
		for e in run.enemies_in_radius(cur.pos, JUMP_R):
			if hit.has(e):
				continue
			var dd := run._flat(e.pos - cur.pos).length()
			if dd < bd:
				bd = dd
				nxt = e
		cur = nxt
	return n


func _first_target(d: Vector3) -> Unit:
	var best: Unit = null
	var bs := 1e9
	for e in run.enemies_in_radius(hero.pos, DB.SKILLS["chain_lightning"]["range"]):
		var off := run._flat(e.pos - hero.pos)
		var along := off.normalized().dot(d) if off.length() > 0.05 else 1.0
		if along < 0.3:
			continue
		var s := off.length() * (2.0 - along)
		if s < bs:
			bs = s
			best = e
	return best


func can_cast(slot: int) -> bool:
	if slot == 0 and run.nearest_enemy(hero.pos, DB.SKILLS["chain_lightning"]["range"]) == null:
		run.toast("No foe in reach", BOLT)
		return false
	return step.is_empty()


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0, 1:
			var c := run.best_cluster(hero.pos, 9.0 if slot == 0 else 12.0, 3.0)
			if not c.is_empty():
				return {"dir": run._flat(c["pos"] - hero.pos).normalized(), "point": c["pos"]}
			var n := run.nearest_enemy(hero.pos, 12.0)
			if n:
				return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
		2:
			var c2 := run.best_cluster(hero.pos, 7.0, 2.5)
			if not c2.is_empty():
				return {"point": c2["pos"]}
			# no pack: step away from the nearest foe
			var n2 := run.nearest_enemy(hero.pos, 6.0)
			if n2:
				return {"point": hero.pos + run._flat(hero.pos - n2.pos).normalized() * 6.0}
	return {"point": hero.pos + hero.facing * 5.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			var d := aim_dir(aim)
			var t := _first_target(d)
			if t == null:
				t = run.nearest_enemy(hero.pos, DB.SKILLS["chain_lightning"]["range"])
			if t == null:
				return false
			hero.face(t.pos - hero.pos)
			var jumps: int = 3 + rank(0)
			var dmg := 40.0 + 25.0 * rank(0) + 0.8 * hero.int_v
			var over := static_v >= 100.0
			if over:
				jumps *= 2
				dmg *= 1.5
				static_v = 0.0
				run.toast("Overload!", VIOLET)
			chain(t, hero.pos + Vector3(0, 1.4, 0), dmg, jumps, 0.08, "Chain Lightning", 0.0 if over else 7.0)
			Audio.play("beam")
			return true
		1:
			var d2 := aim_dir(aim)
			hero.face(d2)
			var p := hero.pos + d2 * 0.8
			balls.append({"pos": p, "dir": d2, "t": 2.4, "tick": 0.0,
				"fx": run.fx("buff_aura", {"pos": p + Vector3(0, 1.0, 0), "radius": 0.9, "color": BOLT})})
			Audio.play("orb")
			return true
		2:
			var p2 := clamp_point(aim.get("point", hero.pos + hero.facing * 5.0), DB.SKILLS["storm_step"]["range"])
			step = {"from": hero.pos, "to": p2, "t": 0.0, "dur": 0.15}
			run.fx("teleport", {"pos": hero.pos, "color": BOLT})
			return true
		3:
			storm_t = 8.0
			storm_tick = 0.0
			if storm_fx == null:
				storm_fx = run.fx("buff_aura", {"target": hero.node, "pos": hero.pos, "radius": 1.6, "color": VIOLET})
			run.toast("Thunderstorm!", VIOLET)
			return true
	return false


func override_motion(dt: float) -> bool:
	if step.is_empty():
		return false
	step["t"] += dt
	var k := clampf(step["t"] / step["dur"], 0.0, 1.0)
	hero.pos = run.resolve_pos(hero, step["from"].lerp(step["to"], k), hero.pos)
	if k >= 1.0:
		var a: Vector3 = step["from"]
		run.fx_timed("beam", {"from": a + Vector3(0, 1.0, 0), "to": hero.pos + Vector3(0, 1.0, 0), "width": 0.6, "color": BOLT}, 0.25)
		var dmg := 50.0 + 35.0 * rank(2) + 0.9 * hero.int_v
		var hitset := {}
		for e in enemies_on_line(a, hero.pos, 1.6):
			hitset[e] = true
			run.damage(e, dmg, hero, "Storm Step", "magic", {"color": BOLT})
			add_static(5.0)
		var r: float = DB.SKILLS["storm_step"]["radius"]
		run.fx("ring_burst", {"pos": hero.pos, "radius": r, "color": BOLT})
		for e in run.enemies_in_radius(hero.pos, r):
			if not hitset.has(e):
				run.damage(e, dmg * 0.6, hero, "Storm Step", "magic", {"color": BOLT})
			if e.alive:
				stun(e, 0.8)
		step = {}
		Audio.play("beam")
	return true


func override_motion_active() -> bool:
	return not step.is_empty()


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel:
		return false
	hero.face(target.pos - hero.pos)
	run.fx("hit", {"pos": target.pos + Vector3(0, 1.0, 0), "color": BOLT})
	run.fx_timed("beam", {"from": hero.pos + Vector3(0, 1.4, 0), "to": target.pos + Vector3(0, 1.0, 0), "width": 0.15, "color": BOLT}, 0.12)
	run.damage(target, dmg, hero, "Spark", "magic", {"attack": true, "crit": crit, "color": BOLT})
	on_attack_hit(target)
	# the spark jumps once more
	var n := run.nearest_enemy(target.pos, JUMP_R)
	if n == target:
		n = null
		for e in run.enemies_in_radius(target.pos, JUMP_R):
			if e != target:
				n = e
				break
	if n != null:
		run.fx_timed("beam", {"from": target.pos + Vector3(0, 1.0, 0), "to": n.pos + Vector3(0, 1.0, 0), "width": 0.12, "color": BOLT}, 0.12)
		run.damage(n, dmg * 0.5, hero, "Spark", "magic", {"color": BOLT})
	add_static(2.0)
	return true


func tick(dt: float) -> void:
	if hero.in_camp:
		static_v = maxf(0.0, static_v - 10.0 * dt)
	if not balls.is_empty():
		var keep := []
		for b in balls:
			b["t"] -= dt
			b["pos"] = run.resolve_pos(hero, b["pos"] + b["dir"] * 5.0 * dt, b["pos"])
			run.fx_params(b["fx"], {"pos": b["pos"] + Vector3(0, 1.0, 0)})
			b["tick"] -= dt
			if b["tick"] <= 0.0:
				b["tick"] = 0.35
				var z := 20.0 + 14.0 * rank(1) + 0.4 * hero.int_v
				for e in run.enemies_in_radius(b["pos"], 2.5):
					run.fx_timed("beam", {"from": b["pos"] + Vector3(0, 1.0, 0), "to": e.pos + Vector3(0, 1.0, 0), "width": 0.12, "color": BOLT}, 0.1)
					run.damage(e, z, hero, "Ball Lightning", "magic", {"color": BOLT})
					add_static(1.0)
			if b["t"] <= 0.0:
				run.fx_stop(b["fx"])
				run.fx("explosion", {"pos": b["pos"], "radius": 2.5, "color": BOLT})
				for e in run.enemies_in_radius(b["pos"], 2.5):
					run.damage(e, 60.0 + 40.0 * rank(1) + 1.0 * hero.int_v, hero, "Ball Lightning", "magic", {"color": BOLT})
			else:
				keep.append(b)
		balls = keep
	if storm_t > 0.0:
		storm_t -= dt
		storm_tick -= dt
		if storm_tick <= 0.0:
			storm_tick = 0.5
			var cands := run.enemies_in_radius(hero.pos, 11.0)
			if not cands.is_empty():
				var t: Unit = cands[run.rng.randi() % cands.size()]
				run.fx("hit", {"pos": t.pos + Vector3(0, 0.5, 0), "color": VIOLET})
				chain(t, t.pos + Vector3(0, 8.0, 0), 45.0 + 35.0 * rank(3) + 0.8 * hero.int_v, 2, 0.0, "Thunderstorm", 2.0)
		if storm_t <= 0.0 and storm_fx != null:
			run.fx_stop(storm_fx)
			storm_fx = null


func _clear() -> void:
	for b in balls:
		run.fx_stop(b["fx"])
	balls.clear()
	storm_t = 0.0
	if storm_fx != null:
		run.fx_stop(storm_fx)
		storm_fx = null
	step = {}


func on_wave_end() -> void:
	_clear()


func on_teleport(_p: Vector3) -> void:
	_clear()


func hud_meter() -> Dictionary:
	return {"type": "bar", "label": L.f("Static %d", [int(static_v)]) + ("  " + L.t("OVERLOAD") if static_v >= 100.0 else ""), "value": static_v, "max": 100.0,
		"color": VIOLET if static_v >= 100.0 else BOLT}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			return run.nearest_enemy(hero.pos, 9.0) != null and (run.count_enemies(hero.pos, 12.0) >= 2 or run.boss_units.size() > 0)
		1:
			var c := run.best_cluster(hero.pos, 12.0, 3.0)
			return not c.is_empty() and int(c["count"]) >= 3
		2:
			return run.count_enemies(hero.pos, 2.5) >= 3 or (hero.hp < hero.max_hp * 0.4 and run.count_enemies(hero.pos, 3.0) >= 1)
		3:
			return run.count_enemies(hero.pos, 11.0) >= 6 or (run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 11.0) != null)
	return false
