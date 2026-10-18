extends HeroKit
## Snarewright: Snare Trap (charges), Blast Charge, Tripwire, Killing Field.
## Snared foes (caught by a trap or wire) take +25% damage from the Snarewright.

const OLIVE := Color(0.8, 0.85, 0.3)

var traps: Array = []        # Unit (kind "snare_trap"), with meta "arm"
var charges_n := 2
var recharge := 0.0
var blasts: Array = []       # {pos, t, fx}
var wires: Array = []        # {a, b, t, fx, hit: {}}
var field_t := 0.0
var snared := {}             # Enemy -> seconds left


func max_charges() -> int:
	return 3 if rank(0) >= 3 else 2


func max_traps() -> int:
	return 3 + maxi(1, rank(0))


func trap_dmg() -> float:
	return 50.0 + 40.0 * rank(0) + 0.8 * hero.agi_v


func is_snared(e: Unit) -> bool:
	return snared.has(e)


func snare(e: Unit, t := 4.0) -> void:
	if e.alive:
		snared[e] = maxf(snared.get(e, 0.0), t)


func hit(e: Unit, amount: float, tag: String, dtype := "phys", opts := {}) -> float:
	var a := amount * (1.25 if is_snared(e) else 1.0)
	var o := opts.duplicate()
	if not o.has("color"):
		o["color"] = OLIVE
	return run.damage(e, a, hero, tag, dtype, o)


func on_rank_up(slot: int) -> void:
	if slot == 0:
		if rank(0) == 1:
			charges_n = 2
		elif rank(0) == 3:
			charges_n = mini(charges_n + 1, 3)


func is_ready(slot: int) -> bool:
	if slot == 0:
		return charges_n > 0
	return hero.cds[slot] <= 0.0


func start_cooldown(slot: int) -> void:
	if slot == 0:
		charges_n -= 1
		if recharge <= 0.0:
			recharge = hero.skill_cd(0)
		return
	super.start_cooldown(slot)


func charges(slot: int) -> int:
	if slot == 0 and rank(0) > 0:
		return charges_n
	return -1


func cd_frac(slot: int) -> float:
	if slot == 0:
		return 0.0 if charges_n > 0 else clampf(recharge / maxf(0.1, hero.skill_cd(0)), 0.0, 1.0)
	return super.cd_frac(slot)


func cd_left(slot: int) -> float:
	if slot == 0:
		return 0.0 if charges_n > 0 else recharge
	return super.cd_left(slot)


## Where the pack will be in a moment: a bit in front of the nearest group, on the way to the hero.
func _ahead_point(max_r: float) -> Vector3:
	var c := run.best_cluster(hero.pos, max_r + 4.0, 3.0)
	var target := hero.pos + hero.facing * 4.0
	if not c.is_empty():
		target = c["pos"]
	else:
		var n := run.nearest_enemy(hero.pos, 16.0)
		if n:
			target = n.pos
	var to := run._flat(target - hero.pos)
	var d := to.length()
	return hero.pos + to.normalized() * clampf(d * 0.55, 1.5, max_r) if d > 0.1 else target


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0:
			var p := _ahead_point(8.0)
			return {"point": p, "dir": run._flat(p - hero.pos).normalized()}
		1, 3:
			var c := run.best_cluster(hero.pos, 10.0, 3.5)
			if not c.is_empty():
				return {"point": c["pos"], "dir": run._flat(c["pos"] - hero.pos).normalized()}
		2:
			var p2 := _ahead_point(6.0)
			return {"point": p2, "dir": run._flat(p2 - hero.pos).normalized()}
	return {"point": hero.pos + hero.facing * 4.0, "dir": hero.facing}


func aim_spec(slot: int) -> Dictionary:
	var s := super.aim_spec(slot)
	if slot == 2:
		s["length"] = wire_len()
	return s


func wire_len() -> float:
	return 6.0 + 1.0 * maxi(1, rank(2))


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			return _place_trap(clamp_point(aim.get("point", hero.pos), DB.SKILLS["snare_trap"]["range"]), 0.6)
		1:
			return _blast(aim)
		2:
			return _wire(aim)
		3:
			return _field(aim)
	return false


func _place_trap(p: Vector3, arm: float) -> bool:
	var t := run.spawn_summon("snare_trap", p)
	t.targetable = false
	t.collides = false
	t.no_push = true
	t.max_hp = 1.0
	t.hp = 1.0
	t.lifetime = 45.0
	t.set_meta("arm", arm)
	traps.append(t)
	traps = alive_of(traps)
	while traps.size() > max_traps():
		run.remove_ally(traps[0], false)
		traps = alive_of(traps)
	return true


func _snap(t: Unit, free := false) -> void:
	if not t.alive:
		return
	run.fx("trap_snap", {"pos": t.pos})
	var dmg := trap_dmg() * (1.0 if not free else 0.8)
	var root := 1.2 + 0.2 * rank(0)
	var first := true
	for e in run.enemies_in_radius(t.pos, 1.6):
		var near: bool = run._flat(e.pos - t.pos).length() <= e.radius + 1.0
		hit(e, dmg if (first or near) else dmg * 0.4, "Snare Trap")
		if e.alive and (first or near):
			stun(e, root)
			snare(e)
		first = false
	run.remove_ally(t, false)
	Audio.play("hit")


func _blast(aim: Dictionary) -> bool:
	var p := clamp_point(aim.get("point", hero.pos + hero.facing * 5.0), DB.SKILLS["blast_charge"]["range"])
	var rad: float = DB.SKILLS["blast_charge"]["radius"]
	var node := run.spawn_summon("blast_charge", p)
	node.targetable = false
	node.collides = false
	node.no_push = true
	node.lifetime = 3.0
	blasts.append({"pos": p, "t": 2.0, "node": node,
		"fx": run.fx("telegraph_circle", {"pos": p, "radius": rad, "duration": 2.0, "color": OLIVE})})
	return true


func _explode(b: Dictionary) -> void:
	var p: Vector3 = b["pos"]
	var rad: float = DB.SKILLS["blast_charge"]["radius"]
	run.fx("explosion", {"pos": p, "radius": rad})
	run.shake(0.3)
	var dmg := 90.0 + 60.0 * rank(1) + 1.1 * hero.agi_v
	for e in run.enemies_in_radius(p, rad):
		hit(e, dmg, "Blast Charge", "magic", {"color": Color(1.0, 0.6, 0.2)})
		if e.alive:
			shove(e, e.pos - p, 12.0)
	for t in alive_of(traps):
		if run._flat(t.pos - p).length() <= rad + 0.5:
			_snap(t, true)
	if b.get("node") != null and b["node"].alive:
		run.remove_ally(b["node"], false)
	Audio.play("slam")


func _wire(aim: Dictionary) -> bool:
	var center := clamp_point(aim.get("point", hero.pos + hero.facing * 4.0), DB.SKILLS["tripwire"]["range"])
	var d := run._flat(center - hero.pos)
	if d.length() < 0.3:
		d = aim_dir(aim)
	d = d.normalized()
	var perp := Vector3(-d.z, 0, d.x)
	var half := wire_len() * 0.5
	var a := run.resolve_pos(hero, center - perp * half, center)
	var b := run.resolve_pos(hero, center + perp * half, center)
	var f := run.fx("beam", {"from": a + Vector3(0, 0.45, 0), "to": b + Vector3(0, 0.45, 0), "width": 0.12, "duration": 8.0, "color": OLIVE})
	wires.append({"a": a, "b": b, "t": 8.0, "fx": f, "hit": {}})
	return true


func _field(aim: Dictionary) -> bool:
	var p := clamp_point(aim.get("point", hero.pos + hero.facing * 5.0), DB.SKILLS["killing_field"]["range"])
	var n: int = [6, 8, 10][clampi(rank(3) - 1, 0, 2)]
	var rad: float = DB.SKILLS["killing_field"]["radius"]
	run.fx("ring_burst", {"pos": p, "radius": rad, "color": OLIVE})
	for i in n:
		var ang := TAU * i / n
		var q := run.resolve_pos(hero, p + Vector3(cos(ang), 0, sin(ang)) * rad, p)
		# killing field traps don't count against the normal trap limit
		var t := run.spawn_summon("snare_trap", q)
		t.targetable = false
		t.collides = false
		t.no_push = true
		t.lifetime = 20.0
		t.set_meta("arm", 0.0)
		t.set_meta("field", true)
		traps.push_front(t)
	field_t = 8.0
	return true


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	var mult := 1.0
	if field_t > 0.0 and is_snared(target):
		mult = 2.0
	var opts := {"dtype": "phys", "attack": true, "crit": crit, "color": OLIVE}
	if is_snared(target):
		mult *= 1.25
	run.fire_projectile("crossbow_bolt", hero.pos + Vector3(0, 1.2, 0), target, Vector3.ZERO, 24.0, dmg * mult, 0, hero, "Bolt", opts)
	Audio.play("hit")
	return true


func tick(dt: float) -> void:
	if field_t > 0.0:
		field_t -= dt
	if rank(0) > 0 and charges_n < max_charges():
		recharge -= dt
		if recharge <= 0.0:
			charges_n += 1
			recharge = hero.skill_cd(0) if charges_n < max_charges() else 0.0
	for e in snared.keys():
		snared[e] -= dt
		if snared[e] <= 0.0 or not e.alive:
			snared.erase(e)
	# traps
	var any_dead := false
	for t in traps:
		if not t.alive:
			any_dead = true
			continue
		var arm: float = t.get_meta("arm", 0.0)
		if arm > 0.0:
			t.set_meta("arm", arm - dt)
			continue
		for e in run.enemies:
			if e.alive and not e.untargetable and run._flat(e.pos - t.pos).length() <= e.radius + 0.75:
				_snap(t)
				any_dead = true
				break
	if any_dead:
		traps = alive_of(traps)
	# charges
	if not blasts.is_empty():
		var keep := []
		for b in blasts:
			b["t"] -= dt
			if b["t"] <= 0.0:
				_explode(b)
			else:
				keep.append(b)
		blasts = keep
	# wires
	if not wires.is_empty():
		var keep2 := []
		var dmg := 30.0 + 20.0 * rank(2) + 0.4 * hero.agi_v
		for w in wires:
			w["t"] -= dt
			for e in enemies_on_line(w["a"], w["b"], 1.0):
				if w["hit"].has(e):
					continue
				w["hit"][e] = true
				hit(e, dmg, "Tripwire")
				if e.alive:
					e.apply_slow(0.5, 2.0)
					snare(e)
			if w["t"] <= 0.0:
				run.fx_stop(w["fx"])
			else:
				keep2.append(w)
		wires = keep2


func on_wave_end() -> void:
	for t in traps:
		run.remove_ally(t, false)
	traps.clear()
	for b in blasts:
		run.fx_stop(b["fx"])
		if b.get("node") != null and b["node"].alive:
			run.remove_ally(b["node"], false)
	blasts.clear()
	for w in wires:
		run.fx_stop(w["fx"])
	wires.clear()
	snared.clear()
	field_t = 0.0


func hud_meter() -> Dictionary:
	var n := 0
	for t in traps:
		if t.alive and not t.get_meta("field", false):
			n += 1
	return {"type": "count", "label": "Traps %d / %d" % [n, max_traps()]}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			return charges_n > 0 and run.nearest_enemy(hero.pos, 12.0) != null
		1:
			var c := run.best_cluster(hero.pos, 10.0, 3.5)
			return not c.is_empty() and (int(c["count"]) >= 3 or run.boss_units.size() > 0)
		2:
			return run.count_enemies(hero.pos, 10.0) >= 4
		3:
			var c2 := run.best_cluster(hero.pos, 10.0, 4.0)
			return not c2.is_empty() and (int(c2["count"]) >= 5 or (run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 10.0) != null))
	return false
