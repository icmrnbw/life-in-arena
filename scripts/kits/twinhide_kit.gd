extends HeroKit
## Twinhide: two forms with their own Q/W. Spirit (ranged caster): Spirit Lance, Moonwell.
## Beast (melee, tougher, faster swings): Rend, Pounce. E: Shift (twin-skill reset if used right after a skill). R: Twin Fury.

const VIOLET := Color(0.78, 0.45, 1.0)
const SPIRIT_SKILLS := ["spirit_lance", "moonwell"]
const BEAST_SKILLS := ["rend", "pounce"]

var form := "spirit"
var other_cds := [0.0, 0.0]     # cooldowns of the other form's Q/W
var last_skill := -1
var last_skill_t := 0.0
var fury_t := 0.0
var fury_fx: Node = null
var lances: Array = []          # {pos, dir, left, hit: {}, node, dmg}
var wells: Array = []           # {pos, r, t, fx}
var leap := {}                  # {from, to, t, dur}


func beast() -> bool:
	return form == "beast"


func power() -> float:
	return 0.5 * (hero.agi_v + hero.int_v)


func attack_speed_mult() -> float:
	return 1.35 if beast() or fury_t > 0.0 else 1.0


func speed_mult() -> float:
	return 1.12 if beast() else 1.0


func incoming_damage(a: float, _src: Unit) -> float:
	return a * (0.78 if beast() or fury_t > 0.0 else 1.0)


func free_cast(slot: int) -> bool:
	return slot == 2 and fury_t > 0.0 and rank(2) > 0 and leap.is_empty()


func is_ready(slot: int) -> bool:
	if slot == 2 and not leap.is_empty():
		return false
	return super.is_ready(slot)


func can_cast(slot: int) -> bool:
	if slot == 1 and beast() and not leap.is_empty():
		return false
	return true


func skill_label(slot: int) -> String:
	if slot == 2:
		return "BEAST" if not beast() else "SPIRIT"
	return ""


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0:
			if beast():
				var n := run.nearest_enemy(hero.pos, 5.0)
				if n:
					return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
			else:
				var c := run.best_cluster(hero.pos, 11.0, 1.5)
				if not c.is_empty():
					return {"dir": run._flat(c["pos"] - hero.pos).normalized(), "point": c["pos"]}
				var n2 := run.nearest_enemy(hero.pos, 13.0)
				if n2:
					return {"dir": run._flat(n2.pos - hero.pos).normalized(), "point": n2.pos}
		1:
			if beast():
				var c2 := run.best_cluster(hero.pos, 8.0, 2.5)
				if not c2.is_empty():
					return {"point": c2["pos"]}
			else:
				return {"point": hero.pos + hero.facing * 0.5}
	return {"point": hero.pos + hero.facing * 3.0, "dir": hero.facing}


func aim_spec(slot: int) -> Dictionary:
	if slot == 1 and not beast():
		return {"type": "circle", "range": 9.0, "radius": 3.0}
	return super.aim_spec(slot)


func cast(slot: int, aim: Dictionary) -> bool:
	var ok := false
	match slot:
		0:
			ok = _rend(aim) if beast() else _lance(aim)
		1:
			ok = _pounce(aim) if beast() else _well(aim)
		2:
			ok = _shift()
		3:
			ok = _fury()
	if ok and slot <= 1:
		last_skill = slot
		last_skill_t = 2.0
	return ok


# ---------------------------------------------------------------- spirit form
func _lance(aim: Dictionary) -> bool:
	var d := aim_dir(aim)
	hero.face(d)
	var node: Node3D = null
	if Art.has_method("create_projectile"):
		node = Art.create_projectile("spirit_lance")
		if node:
			run.units_root.add_child(node)
	lances.append({"pos": hero.pos + d * 0.6, "dir": d, "left": DB.SKILLS["spirit_lance"]["range"], "hit": {}, "node": node,
		"dmg": 50.0 + 38.0 * rank(0) + 0.8 * power()})
	return true


func _well(aim: Dictionary) -> bool:
	var p := clamp_point(aim.get("point", hero.pos), 9.0)
	var f := run.fx("zone", {"pos": p, "radius": 3.0, "duration": 5.0, "color": Color(0.7, 0.6, 1.0)})
	wells.append({"pos": p, "r": 3.0, "t": 5.0, "fx": f})
	return true


# ---------------------------------------------------------------- beast form
func _rend(aim: Dictionary) -> bool:
	var d := aim_dir(aim)
	hero.face(d)
	run.fx("cone", {"pos": hero.pos, "dir": d, "range": 3.2, "angle": 140.0, "color": VIOLET})
	var dmg := 45.0 + 34.0 * rank(0) + 0.75 * power()
	var total := 0.0
	for e in enemies_in_cone(hero.pos, d, 3.2, 140.0):
		total += run.damage(e, dmg, hero, "Rend", "phys", {"color": VIOLET})
	run.heal_unit(hero, total * 0.25, false)
	run.shake(0.1)
	return true


func _pounce(aim: Dictionary) -> bool:
	var to := clamp_point(aim.get("point", hero.pos + hero.facing * 5.0), DB.SKILLS["pounce"]["range"])
	to = stop_at_pillars(hero.pos, to)
	leap = {"from": hero.pos, "to": to, "t": 0.0, "dur": 0.32}
	hero.invuln_t = maxf(hero.invuln_t, 0.35)
	hero.face(to - hero.pos)
	return true


func _land() -> void:
	var p := hero.pos
	run.fx("ring_burst", {"pos": p, "radius": 2.5, "color": VIOLET})
	run.shake(0.2)
	var dmg := 40.0 + 35.0 * rank(1) + 0.7 * power()
	for e in run.enemies_in_radius(p, 2.5):
		run.damage(e, dmg, hero, "Pounce", "phys", {"color": VIOLET})
		if e.alive:
			stun(e, 0.8)


func override_motion(dt: float) -> bool:
	if leap.is_empty():
		return false
	leap["t"] += dt
	var k: float = clampf(leap["t"] / leap["dur"], 0.0, 1.0)
	hero.pos = (leap["from"] as Vector3).lerp(leap["to"], k)
	if hero.node and is_instance_valid(hero.node):
		hero.node.position.y = sin(k * PI) * 1.4
	if k >= 1.0:
		leap = {}
		if hero.node and is_instance_valid(hero.node):
			hero.node.position.y = 0.0
		_land()
	return true


# ---------------------------------------------------------------- shift / fury
func _shift() -> bool:
	var to_beast := not beast()
	# keep each form's own cooldowns
	var mine := [hero.cds[0], hero.cds[1]]
	hero.cds[0] = other_cds[0]
	hero.cds[1] = other_cds[1]
	other_cds = mine
	form = "beast" if to_beast else "spirit"
	var ids: Array = BEAST_SKILLS if to_beast else SPIRIT_SKILLS
	hero.skill_ids[0] = ids[0]
	hero.skill_ids[1] = ids[1]
	if last_skill_t > 0.0 and last_skill >= 0:
		hero.cds[last_skill] = 0.0
		run.toast("Twin ready!", VIOLET)
		last_skill_t = 0.0
	hero.set_base_range(2.2 if to_beast else float(hero.data["range"]))
	_swap_visual()
	# shift burst
	var mult := 2.0 if fury_t > 0.0 else 1.0
	var r := 3.0
	var dmg := (30.0 + 25.0 * maxi(1, rank(2)) + 0.4 * power()) * mult
	run.fx("form_shift", {"pos": hero.pos})
	run.fx("ring_burst", {"pos": hero.pos, "radius": r, "color": VIOLET})
	for e in run.enemies_in_radius(hero.pos, r):
		run.damage(e, dmg, hero, "Shift", "magic", {"color": VIOLET})
		if not e.alive:
			continue
		if to_beast:
			e.apply_slow(0.4, 2.0)
		else:
			shove(e, e.pos - hero.pos, 11.0)
	if not to_beast:
		hero.shield = maxf(hero.shield, (40.0 + 30.0 * maxi(1, rank(2))) * mult)
	return true


func _swap_visual() -> void:
	var old := hero.node
	var nv := run.make_visual("twinhide_beast" if beast() else "twinhide")
	nv.position = hero.pos
	if old and is_instance_valid(old):
		nv.rotation = old.rotation
		old.queue_free()
	hero.setup_visual(nv)
	hero.radius = clampf(hero.radius, 0.35, 0.8)
	hero.vis_state = ""
	hero.set_state("idle", true)
	if fury_fx != null:
		run.fx_stop(fury_fx)
		fury_fx = run.fx("buff_aura", {"target": hero.node, "duration": fury_t, "pos": hero.pos, "color": VIOLET})


func _fury() -> bool:
	fury_t = [10.0, 12.0, 14.0][clampi(rank(3) - 1, 0, 2)]
	run.fx_stop(fury_fx)
	fury_fx = run.fx("buff_aura", {"target": hero.node, "duration": fury_t, "pos": hero.pos, "color": VIOLET})
	run.fx("form_shift", {"pos": hero.pos})
	hero.cds[2] = 0.0
	return true


func after_cast(slot: int) -> void:
	if slot == 2 and fury_t > 0.0:
		hero.cds[2] = 0.0


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if beast() or target is Barrel:
		return false
	var opts := {"dtype": "phys", "attack": true, "crit": crit, "color": VIOLET}
	run.fire_projectile("hero_bolt", hero.pos + Vector3(0, 1.3, 0), target, Vector3.ZERO, 18.0, dmg, 0, hero, "Spirit Bolt", opts)
	return true


func tick(dt: float) -> void:
	if last_skill_t > 0.0:
		last_skill_t -= dt
	for i in 2:
		if other_cds[i] > 0.0:
			other_cds[i] = maxf(0.0, other_cds[i] - dt)
	if fury_t > 0.0:
		fury_t -= dt
		if fury_t <= 0.0:
			run.fx_stop(fury_fx)
			fury_fx = null
	if not lances.is_empty():
		var keep := []
		for l in lances:
			var step: float = minf(32.0 * dt, l["left"])
			var a: Vector3 = l["pos"]
			var b: Vector3 = a + l["dir"] * step
			l["pos"] = b
			l["left"] -= step
			for e in enemies_on_line(a, b, 1.4):
				if l["hit"].has(e):
					continue
				l["hit"][e] = true
				run.damage(e, l["dmg"], hero, "Spirit Lance", "magic", {"color": VIOLET})
				run.fx("hit", {"pos": e.pos + Vector3(0, 1.0, 0), "color": VIOLET})
			var stop := run.arena.blocks_shot(b)
			var n: Node3D = l["node"]
			if n and is_instance_valid(n):
				n.position = b + Vector3(0, 1.2, 0)
				n.rotation.y = atan2(-l["dir"].x, -l["dir"].z)
			if stop or l["left"] <= 0.0:
				if n and is_instance_valid(n):
					n.queue_free()
			else:
				keep.append(l)
		lances = keep
	if not wells.is_empty():
		var keep2 := []
		var hps := 12.0 + 8.0 * rank(1) + 0.3 * power()
		for w in wells:
			w["t"] -= dt
			if run._flat(hero.pos - w["pos"]).length() <= w["r"]:
				run.heal_unit(hero, hps * dt, false)
			for e in run.enemies_in_radius(w["pos"], w["r"]):
				e.apply_slow(0.35, 0.3)
			if w["t"] <= 0.0:
				run.fx_stop(w["fx"])
			else:
				keep2.append(w)
		wells = keep2


func on_teleport(_p: Vector3) -> void:
	leap = {}
	if hero.node and is_instance_valid(hero.node):
		hero.node.position.y = 0.0


func on_wave_end() -> void:
	for l in lances:
		if l["node"] and is_instance_valid(l["node"]):
			l["node"].queue_free()
	lances.clear()
	for w in wells:
		run.fx_stop(w["fx"])
	wells.clear()
	fury_t = 0.0
	run.fx_stop(fury_fx)
	fury_fx = null


func hud_meter() -> Dictionary:
	return {"type": "count", "label": "Beast form" if beast() else "Spirit form", "color": VIOLET}


func bot_profile() -> Dictionary:
	if beast():
		return {"crowd": 4, "retreat": 0.3, "orbit": 0.4}
	return super.bot_profile()


func bot_wants(slot: int) -> bool:
	var near := run.count_enemies(hero.pos, 4.0)
	match slot:
		0:
			if beast():
				return near >= 1
			var c := run.best_cluster(hero.pos, 11.0, 1.5)
			return not c.is_empty()
		1:
			if beast():
				var c2 := run.best_cluster(hero.pos, 8.0, 2.5)
				return not c2.is_empty() and int(c2["count"]) >= 2
			return hero.hp < hero.max_hp * 0.7 and run.count_enemies(hero.pos, 8.0) >= 1
		2:
			# beast up close, spirit at range; shift right after a skill for the twin reset
			if beast():
				return near == 0 and run.count_enemies(hero.pos, 9.0) >= 1 or hero.hp < hero.max_hp * 0.3
			return near >= 3 or (last_skill_t > 0.0 and near >= 1)
		3:
			return run.count_enemies(hero.pos, 8.0) >= 5 or (run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 8.0) != null)
	return false
