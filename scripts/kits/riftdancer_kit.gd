extends HeroKit
## Riftdancer: Flow meter, Slip (charges), Shatter Mark, Afterimage, Rift Cascade.

var flow := 0.0
var last_skill := -1
var last_skill_t := 0.0
var slip_charges := 2
var slip_recharge := 0.0
var dash := {}            # {from, to, t, dur, hit: {}}
var cascade_queue: Array = []
var cascade_t := 0.0
var cascade_reset_used := false
var cascade_full_flow := false
var decoy: Unit = null


func max_charges() -> int:
	return 3 if rank(0) >= 4 else 2


func damage_mult() -> float:
	return 1.0 + flow * 0.005


func cd_rate() -> float:
	return 1.0 + flow * 0.008


func speed_mult() -> float:
	return 1.0 + flow * 0.001


func on_rank_up(slot: int) -> void:
	if slot == 0:
		if rank(0) == 1:
			slip_charges = 2
		elif rank(0) == 4:
			slip_charges = mini(slip_charges + 1, 3)


func add_flow(v: float) -> void:
	flow = clampf(flow + v, 0.0, 100.0)


func free_cast(slot: int) -> bool:
	return slot == 2 and decoy != null and decoy.alive


func skill_label(slot: int) -> String:
	if slot == 2 and decoy != null and decoy.alive:
		return "SWAP"
	return ""


func is_ready(slot: int) -> bool:
	if slot == 0:
		return slip_charges > 0 and dash.is_empty()
	if slot == 3 and not cascade_queue.is_empty():
		return false
	return hero.cds[slot] <= 0.0


func start_cooldown(slot: int) -> void:
	if slot == 0:
		slip_charges -= 1
		if slip_recharge <= 0.0:
			slip_recharge = hero.skill_cd(0)
		return
	super.start_cooldown(slot)


func charges(slot: int) -> int:
	if slot == 0 and rank(0) > 0:
		return slip_charges
	return -1


func cd_frac(slot: int) -> float:
	if slot == 0:
		if slip_charges > 0:
			return 0.0
		return clampf(slip_recharge / maxf(0.1, hero.skill_cd(0)), 0.0, 1.0)
	return super.cd_frac(slot)


func cd_left(slot: int) -> float:
	if slot == 0:
		return 0.0 if slip_charges > 0 else slip_recharge
	return super.cd_left(slot)


func can_cast(slot: int) -> bool:
	if slot == 1:
		return _marked().size() > 0
	if slot == 3:
		return run.nearest_enemy(hero.pos, DB.SKILLS["rift_cascade"]["range"]) != null
	return true


func _marked() -> Array:
	var out := []
	for e in run.enemies:
		if e.alive and e.is_marked() and run._flat(e.pos - hero.pos).length() <= 16.0:
			out.append(e)
	return out


func smart_aim(slot: int) -> Dictionary:
	if slot == 0:
		# dash toward the densest nearby group, preferring unmarked enemies
		var c := run.best_cluster(hero.pos, 8.0, 3.0)
		if not c.is_empty():
			var d: Vector3 = run._flat(c["pos"] - hero.pos)
			if d.length() > 0.3:
				return {"dir": d.normalized(), "point": c["pos"]}
		var n := run.nearest_enemy(hero.pos, 10.0)
		if n:
			var d2 := run._flat(n.pos - hero.pos).normalized()
			return {"dir": d2, "point": n.pos}
		var mv := Vector3(hero.move_input.x, 0, hero.move_input.y)
		if mv.length() > 0.2:
			return {"dir": mv.normalized(), "point": hero.pos + mv.normalized() * 6.0}
		return {"dir": hero.facing, "point": hero.pos + hero.facing * 6.0}
	return {"point": hero.pos, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	var ok := false
	match slot:
		0:
			ok = _cast_slip(aim)
		1:
			ok = _cast_shatter()
		2:
			ok = _cast_afterimage()
		3:
			ok = _cast_cascade()
	if ok:
		if slot != last_skill or last_skill_t <= 0.0:
			add_flow(15.0)
		else:
			add_flow(6.0)
		last_skill = slot
		last_skill_t = 4.0
	return ok


func _cast_slip(aim: Dictionary) -> bool:
	var d := aim_dir(aim)
	var from := hero.pos
	var to := run.resolve_pos(hero, from + d * DB.SKILLS["slip"]["range"], from)
	# don't dash through pillars: stop at the first pillar contact
	for i in range(1, 14):
		var p := from + (to - from) * (i / 13.0)
		var hit := false
		for pl in DB.PILLARS:
			if Vector2(p.x - pl.x, p.z - pl.z).length() < DB.PILLAR_R + hero.radius:
				hit = true
		if hit:
			to = from + (to - from) * ((i - 1) / 13.0)
			break
	dash = {"from": from, "to": to, "t": 0.0, "dur": 0.16, "hit": {}}
	hero.invuln_t = maxf(hero.invuln_t, 0.22)
	hero.face(d)
	run.fx("slip_trail", {"from": from, "to": to})
	return true


func override_motion(dt: float) -> bool:
	if not cascade_queue.is_empty() or cascade_t > 0.0:
		_tick_cascade(dt)
		return true
	if dash.is_empty():
		return false
	dash["t"] += dt
	var k: float = clampf(dash["t"] / dash["dur"], 0.0, 1.0)
	var prev := hero.pos
	hero.pos = (dash["from"] as Vector3).lerp(dash["to"], k)
	# damage along the path
	var dmg := (30.0 + 28.0 * rank(0) + 0.55 * hero.agi_v) * damage_mult()
	for e in run.enemies:
		if not e.alive or e.untargetable or dash["hit"].has(e):
			continue
		var c := Run.seg_closest(e.pos, prev, hero.pos)
		if run._flat(e.pos - c).length() <= e.radius + 0.8:
			dash["hit"][e] = true
			run.damage(e, dmg, hero, "Slip", "phys", {"color": Color(0.6, 0.9, 1.0)})
			if e.alive:
				_mark(e)
	if k >= 1.0:
		dash = {}
	return true


func _mark(e: Unit) -> void:
	if not e.is_marked():
		e.mark_fx = run.fx("mark", {"target": e.node, "pos": e.pos})
	e.mark_t = 8.0


func _cast_shatter() -> bool:
	var marks := _marked()
	if marks.is_empty():
		return false
	var per := (45.0 + 35.0 * rank(1) + 0.65 * hero.agi_v) * (1.0 + flow / 100.0)
	# each extra mark adds a little to every detonation
	per *= 1.0 + 0.04 * mini(marks.size() - 1, 10)
	for e in marks:
		var p: Vector3 = e.pos
		e.clear_mark()
		run.fx("shatter", {"pos": p})
		run.damage(e, per, hero, "Shatter Mark", "magic", {"color": Color(0.7, 0.85, 1.0), "crit": true})
		for o in run.enemies_in_radius(p, 2.2):
			if o != e:
				run.damage(o, per * 0.4, hero, "Shatter Mark", "magic")
	run.shake(0.2 + 0.03 * marks.size())
	return true


func _cast_afterimage() -> bool:
	if decoy != null and decoy.alive:
		# swap places
		var a := hero.pos
		var b := decoy.pos
		run.fx("teleport", {"pos": a})
		run.fx("teleport", {"pos": b})
		hero.pos = b
		decoy.pos = a
		decoy.sync_visual()
		hero.invuln_t = maxf(hero.invuln_t, 0.3)
		add_flow(10.0)
		return true
	decoy = run.spawn_summon("afterimage", hero.pos)
	decoy.max_hp = hero.max_hp * 0.35
	decoy.hp = decoy.max_hp
	decoy.armor = hero.armor
	decoy.lifetime = 6.0
	decoy.facing = hero.facing
	var taunt_t: float = 2.0 + 0.5 * rank(2)
	for e in run.enemies_in_radius(hero.pos, 8.0):
		if e.is_boss:
			e.taunt_target = decoy
			e.taunt_t = taunt_t * 0.5
		else:
			e.taunt_target = decoy
			e.taunt_t = taunt_t
	return true


func _cast_cascade() -> bool:
	var n: int = [6, 8, 10][clampi(rank(3) - 1, 0, 2)]
	var rng_r: float = DB.SKILLS["rift_cascade"]["range"]
	var cands := []
	for e in run.enemies:
		if e.alive and not e.untargetable and run._flat(e.pos - hero.pos).length() <= rng_r:
			cands.append(e)
	if cands.is_empty():
		return false
	var hp_ref := hero.pos
	cands.sort_custom(func(a, b):
		var am: int = 0 if a.is_marked() else 1
		var bm: int = 0 if b.is_marked() else 1
		if am != bm:
			return am < bm
		return run._flat(a.pos - hp_ref).length() < run._flat(b.pos - hp_ref).length())
	cascade_queue = []
	var i := 0
	while cascade_queue.size() < n and cands.size() > 0:
		cascade_queue.append(cands[i % cands.size()])
		i += 1
		if i >= cands.size() and cands.size() < 3:
			break
		if i >= n:
			break
	cascade_t = 0.0
	cascade_full_flow = flow >= 99.0
	hero.invuln_t = maxf(hero.invuln_t, 0.15 * cascade_queue.size() + 0.3)
	return true


func _tick_cascade(dt: float) -> void:
	cascade_t -= dt
	if cascade_t > 0.0:
		return
	if cascade_queue.is_empty():
		cascade_t = 0.0
		return
	var e: Unit = cascade_queue.pop_front()
	cascade_t = 0.13
	if e == null or not e.alive:
		return
	var off := run._flat(hero.pos - e.pos)
	if off.length() < 0.1:
		off = Vector3(1, 0, 0)
	var dest := e.pos + off.normalized() * (e.radius + hero.radius + 0.2)
	run.fx("slip_trail", {"from": hero.pos, "to": dest})
	hero.pos = run.resolve_pos(hero, dest, hero.pos)
	hero.face(e.pos - hero.pos)
	hero.set_state("attack")
	var dmg := (90.0 + 70.0 * rank(3) + 1.0 * hero.agi_v) * damage_mult()
	if e.is_marked():
		dmg *= 1.25
		e.clear_mark()
	run.fx("rift_strike", {"pos": e.pos})
	run.damage(e, dmg, hero, "Rift Cascade", "phys", {"crit": true, "color": Color(0.75, 0.6, 1.0)})
	run.shake(0.12)


func after_cast(slot: int) -> void:
	if slot == 3:
		if cascade_full_flow and not cascade_reset_used:
			hero.cds[3] = 0.0
			cascade_reset_used = true
			flow = 50.0
			run.toast("Full Flow: Cascade ready again!", Color(0.7, 0.9, 1.0))
		else:
			cascade_reset_used = false


func on_attack_hit(_t: Unit) -> void:
	add_flow(3.0)


func tick(dt: float) -> void:
	if last_skill_t > 0.0:
		last_skill_t -= dt
	if hero.moving and not hero.in_camp:
		add_flow(7.0 * dt)
	elif hero.still_t > 0.6:
		add_flow(-14.0 * dt)
	if hero.in_camp:
		add_flow(-5.0 * dt)
	# slip charges
	if rank(0) > 0 and slip_charges < max_charges():
		slip_recharge -= dt * cd_rate()
		if slip_recharge <= 0.0:
			slip_charges += 1
			slip_recharge = hero.skill_cd(0) if slip_charges < max_charges() else 0.0
	if decoy != null and not decoy.alive:
		decoy = null


func on_wave_end() -> void:
	if decoy != null and decoy.alive:
		run.remove_ally(decoy, false)
	decoy = null
	dash = {}
	cascade_queue.clear()


func on_wave_start() -> void:
	flow = maxf(flow, 20.0)


func hud_meter() -> Dictionary:
	return {"type": "flow", "value": flow, "max": 100.0}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			if slip_charges <= 0:
				return false
			var n := run.nearest_enemy(hero.pos, 7.0)
			if n == null:
				return false
			return slip_charges >= 2 or run.count_enemies(hero.pos, 7.0) >= 3 or n.is_boss
		1:
			var m := _marked()
			if m.size() >= 3:
				return true
			for e in m:
				if e.is_boss or e.hp < e.max_hp * 0.4:
					return true
			return m.size() >= 1 and slip_charges == 0
		2:
			if decoy != null and decoy.alive:
				return hero.hp < hero.max_hp * 0.35 and run.count_enemies(hero.pos, 4.0) >= 3 and run.count_enemies(decoy.pos, 3.0) < 2
			return run.count_enemies(hero.pos, 6.0) >= 5 or (hero.hp < hero.max_hp * 0.5 and run.count_enemies(hero.pos, 5.0) >= 2) or (run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 6.0) != null and run.nearest_enemy(hero.pos, 6.0).is_boss)
		3:
			if run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 12.0) != null:
				return true
			return run.count_enemies(hero.pos, 12.0) >= 5
	return false
