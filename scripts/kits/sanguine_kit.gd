extends HeroKit
## Sanguine: no mana. Skills cost HP; damage heals back. Bloodlust: the lower his HP, the harder he hits.
## Crimson Cleave, Blood Rush, Hemorrhage, Undying Pact.

const BLOOD := Color(0.95, 0.18, 0.25)

var bleeds := {}          # Enemy -> {"t": s, "dps": d, "tick": s}
var pact_t := 0.0
var pact_fx: Node = null
var rush := {}            # {from, to, t, dur, hit: {}}


func missing_frac() -> float:
	return clampf(1.0 - hero.hp / maxf(1.0, hero.max_hp), 0.0, 1.0)


## Bloodlust: up to +60% damage at 0 HP.
func damage_mult() -> float:
	return 1.0 + 0.6 * missing_frac()


func attack_speed_mult() -> float:
	return 1.0 + 0.3 * missing_frac()


func hp_cost(slot: int) -> float:
	return hero.max_hp * float(DB.SKILLS[hero.skill_ids[slot]].get("hp", 0.0))


func blocked(slot: int) -> bool:
	var c := hp_cost(slot)
	return c > 0.0 and hero.hp <= c + 1.0


func can_cast(slot: int) -> bool:
	if blocked(slot):
		run.toast("Too little blood left", BLOOD)
		return false
	if slot == 1 and not rush.is_empty():
		return false
	return true


func lifesteal() -> float:
	if pact_t <= 0.0:
		return 0.0
	return [0.25, 0.35, 0.45][clampi(rank(3) - 1, 0, 2)]


## Deal damage and drink from it.
func hit(e: Unit, amount: float, tag: String, dtype := "phys", heal_frac := 0.0, opts := {}) -> float:
	var o := opts.duplicate()
	if not o.has("color"):
		o["color"] = Color(1.0, 0.4, 0.4)
	var a := run.damage(e, amount * damage_mult(), hero, tag, dtype, o)
	var hf := heal_frac + lifesteal()
	if a > 0.0 and hf > 0.0:
		run.heal_unit(hero, a * hf, false)
	return a


func _pay(slot: int) -> void:
	var c := hp_cost(slot)
	if c > 0.0:
		hero.hp = maxf(1.0, hero.hp - c)
		run.fx("blood_burst", {"pos": hero.pos, "size": 0.6})


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0:
			var n := run.nearest_enemy(hero.pos, 6.0)
			if n:
				return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
		1:
			var c := run.best_cluster(hero.pos, 8.0, 2.5)
			if not c.is_empty():
				var d: Vector3 = run._flat(c["pos"] - hero.pos)
				if d.length() > 0.3:
					return {"dir": d.normalized(), "point": c["pos"]}
			var n2 := run.nearest_enemy(hero.pos, 10.0)
			if n2:
				return {"dir": run._flat(n2.pos - hero.pos).normalized(), "point": n2.pos}
		2:
			var c2 := run.best_cluster(hero.pos, 9.0, 3.5)
			if not c2.is_empty():
				return {"point": c2["pos"], "dir": run._flat(c2["pos"] - hero.pos).normalized()}
	return {"point": hero.pos + hero.facing * 3.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	var ok := false
	match slot:
		0:
			ok = _cleave(aim)
		1:
			ok = _rush(aim)
		2:
			ok = _hemorrhage(aim)
		3:
			ok = _pact()
	if ok:
		_pay(slot)
	return ok


func _cleave(aim: Dictionary) -> bool:
	var d := aim_dir(aim)
	hero.face(d)
	run.fx("cone", {"pos": hero.pos, "dir": d, "range": 3.6, "angle": 120.0, "color": BLOOD})
	var dmg := 40.0 + 32.0 * rank(0) + 0.7 * hero.str_v
	var heal := 0.6 if hero.hp < hero.max_hp * 0.5 else 0.3
	for e in enemies_in_cone(hero.pos, d, 3.6, 120.0):
		hit(e, dmg, "Crimson Cleave", "phys", heal)
	run.shake(0.12)
	return true


func _rush(aim: Dictionary) -> bool:
	var d := aim_dir(aim)
	var from := hero.pos
	var to := run.resolve_pos(hero, from + d * DB.SKILLS["blood_rush"]["range"], from)
	to = stop_at_pillars(from, to)
	rush = {"from": from, "to": to, "t": 0.0, "dur": 0.24, "hit": {}}
	hero.invuln_t = maxf(hero.invuln_t, 0.28)
	hero.face(d)
	run.fx("slip_trail", {"from": from, "to": to, "color": BLOOD})
	return true


func override_motion(dt: float) -> bool:
	if rush.is_empty():
		return false
	rush["t"] += dt
	var k: float = clampf(rush["t"] / rush["dur"], 0.0, 1.0)
	var prev := hero.pos
	hero.pos = (rush["from"] as Vector3).lerp(rush["to"], k)
	var dmg := 35.0 + 28.0 * rank(1) + 0.6 * hero.str_v
	for e in run.enemies:
		if not e.alive or e.untargetable or rush["hit"].has(e):
			continue
		var c := Run.seg_closest(e.pos, prev, hero.pos)
		if run._flat(e.pos - c).length() <= e.radius + 0.9:
			rush["hit"][e] = true
			hit(e, dmg, "Blood Rush")
			run.heal_unit(hero, hero.max_hp * 0.03, false)
			run.fx("blood_burst", {"pos": e.pos, "size": 0.7})
	if k >= 1.0:
		rush = {}
	return true


func _hemorrhage(aim: Dictionary) -> bool:
	var rad: float = DB.SKILLS["hemorrhage"]["radius"]
	var p := clamp_point(aim.get("point", hero.pos + hero.facing * 4.0), DB.SKILLS["hemorrhage"]["range"])
	run.fx("ring_burst", {"pos": p, "radius": rad, "color": BLOOD})
	var dps := 12.0 + 10.0 * rank(2) + 0.25 * hero.str_v
	for e in run.enemies_in_radius(p, rad):
		hit(e, dps, "Hemorrhage", "magic")
		if e.alive:
			bleeds[e] = {"t": 5.0, "dps": dps, "tick": 0.5}
			e.flash(BLOOD)
	return true


func _pact() -> bool:
	pact_t = [6.0, 7.0, 8.0][clampi(rank(3) - 1, 0, 2)]
	run.fx_stop(pact_fx)
	pact_fx = run.fx("buff_aura", {"target": hero.node, "duration": pact_t, "pos": hero.pos, "color": BLOOD})
	run.fx("blood_burst", {"pos": hero.pos, "size": 1.4})
	run.shake(0.2)
	return true


func incoming_damage(a: float, _src: Unit) -> float:
	if pact_t > 0.0 and a >= hero.hp:
		return maxf(0.0, hero.hp - 1.0)
	return a


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel:
		return false
	run.fx("hit", {"pos": target.pos + Vector3(0, 1.0, 0), "color": BLOOD})
	# dmg already carries damage_mult() (run applies it before basic_attack)
	var a := run.damage(target, dmg, hero, "Attack", "phys", {"attack": true, "crit": crit, "melee": true})
	# the pact and a sip from every swing: 8% of attack damage
	if a > 0.0:
		run.heal_unit(hero, a * (0.08 + lifesteal()), false)
	on_attack_hit(target)
	Audio.play("hit")
	return true


func on_enemy_killed(e: Unit) -> void:
	if bleeds.has(e):
		bleeds.erase(e)
		if hero.alive and not hero.dead:
			run.heal_unit(hero, hero.max_hp * 0.04)
			run.fx("soul_wisp", {"from": e.pos, "to": hero.pos})


func tick(dt: float) -> void:
	if pact_t > 0.0:
		pact_t -= dt
		if pact_t <= 0.0:
			run.fx_stop(pact_fx)
			pact_fx = null
	if bleeds.is_empty():
		return
	for e in bleeds.keys():
		var b: Dictionary = bleeds[e]
		if not e.alive:
			bleeds.erase(e)
			continue
		b["t"] -= dt
		b["tick"] -= dt
		if b["tick"] <= 0.0:
			b["tick"] = 0.5
			hit(e, b["dps"] * 0.5, "Hemorrhage", "magic", 0.0, {"color": BLOOD})
		if b["t"] <= 0.0 and bleeds.has(e):
			bleeds.erase(e)


func on_wave_end() -> void:
	bleeds.clear()
	rush = {}
	pact_t = 0.0
	run.fx_stop(pact_fx)
	pact_fx = null


func hud_meter() -> Dictionary:
	var m := missing_frac()
	return {"type": "bar", "label": "Bloodlust +%d%%" % int(round(60.0 * m)), "value": m, "max": 1.0, "color": BLOOD}


func bot_wants(slot: int) -> bool:
	if blocked(slot):
		return false
	var hp := hero.hp / maxf(1.0, hero.max_hp)
	match slot:
		0:
			return run.count_enemies(hero.pos, 3.5) >= 1 and hp > 0.12
		1:
			var n := run.nearest_enemy(hero.pos, 8.0)
			return n != null and hp > 0.25 and (run.count_enemies(hero.pos, 8.0) >= 3 or n.is_boss)
		2:
			var c := run.best_cluster(hero.pos, 9.0, 3.5)
			return not c.is_empty() and (int(c["count"]) >= 3 or run.boss_units.size() > 0) and hp > 0.2
		3:
			return hp < 0.35 and run.count_enemies(hero.pos, 6.0) >= 2 or (run.boss_units.size() > 0 and hp < 0.55 and run.nearest_enemy(hero.pos, 6.0) != null)
	return false
