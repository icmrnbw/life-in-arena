extends HeroKit
## Duelist: parry timing. Riposte opens a short window; a hit inside it is parried (no damage), countered and
## refunds the cooldown. Parries build Poise (faster, harder swings). Lunge, Feint (Exposed foes), Blade Dance.

const STEEL := Color(0.85, 0.92, 1.0)
const GOLDEN := Color(1.0, 0.82, 0.35)
const PARRY_WINDOW := 0.7
const POISE_MAX := 5
const EXPOSE_TIME := 4.0

var parry_t := 0.0
var parry_fx: Node = null
var poise := 0
var poise_t := 0.0          # Poise fades one stack every 5 s without a parry
var dance_t := 0.0
var dance_fx: Node = null
var exposed := {}           # Enemy -> seconds left
var lunge := {}             # {from, to, t, dur, hit: {}}


func is_exposed(e: Unit) -> bool:
	return exposed.has(e) and float(exposed[e]) > 0.0


func attack_speed_mult() -> float:
	return 1.0 + 0.08 * poise


func damage_mult() -> float:
	return 1.0 + 0.06 * poise


func counter_dmg() -> float:
	return (35.0 + 25.0 * maxi(1, rank(0)) + 1.6 * hero.agi_v) * (1.0 + 0.1 * poise)


func can_cast(slot: int) -> bool:
	if slot == 1 and not lunge.is_empty():
		return false
	return true


func smart_aim(slot: int) -> Dictionary:
	match slot:
		1:
			var t := run.nearest_enemy(hero.pos, 7.0)
			for e in exposed:
				if is_exposed(e) and e.alive and run._flat(e.pos - hero.pos).length() < 7.0:
					t = e
					break
			if t:
				return {"dir": run._flat(t.pos - hero.pos).normalized(), "point": t.pos}
		2:
			var c := run.best_cluster(hero.pos, 3.6, 2.0)
			if not c.is_empty():
				return {"dir": run._flat(c["pos"] - hero.pos).normalized(), "point": c["pos"]}
			var n := run.nearest_enemy(hero.pos, 6.0)
			if n:
				return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
	return {"point": hero.pos + hero.facing * 3.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			_open_parry()
			return true
		1:
			var d := aim_dir(aim)
			hero.face(d)
			var to := stop_at_pillars(hero.pos, run.resolve_pos(hero, hero.pos + d * DB.SKILLS["lunge"]["range"], hero.pos))
			lunge = {"from": hero.pos, "to": to, "t": 0.0, "dur": 0.2, "hit": {}, "refund": false}
			run.fx("slip_trail", {"from": hero.pos, "to": to, "color": STEEL})
			Audio.play("slash")
			return true
		2:
			var d2 := aim_dir(aim)
			hero.face(d2)
			run.fx("cone", {"pos": hero.pos, "dir": d2, "range": 3.6, "angle": 80.0, "color": GOLDEN})
			for e in enemies_in_cone(hero.pos, d2, 3.6, 80.0):
				exposed[e] = EXPOSE_TIME
				run.damage(e, 20.0 + 15.0 * rank(2) + 0.5 * hero.agi_v, hero, "Feint", "phys", {"color": GOLDEN})
				if e.alive:
					e.flash(GOLDEN)
			return true
		3:
			dance_t = [5.0, 6.0, 7.0][clampi(rank(3) - 1, 0, 2)]
			if dance_fx == null:
				dance_fx = run.fx("buff_aura", {"target": hero.node, "pos": hero.pos, "radius": 1.3, "color": STEEL})
			run.fx("ring_burst", {"pos": hero.pos, "radius": 2.5, "color": STEEL})
			run.toast("Blade Dance!", STEEL)
			return true
	return false


func _open_parry() -> void:
	parry_t = PARRY_WINDOW
	if parry_fx == null:
		parry_fx = run.fx("buff_aura", {"target": hero.node, "pos": hero.pos, "radius": 1.0, "color": GOLDEN})
	hero.set_state("attack", true)


func _close_parry() -> void:
	parry_t = 0.0
	if parry_fx != null:
		run.fx_stop(parry_fx)
		parry_fx = null


## A parry: no damage, counter the attacker, refund Riposte, +1 Poise.
func incoming_damage(a: float, src: Unit) -> float:
	if a <= 0.0:
		return a
	var parried := parry_t > 0.0 or (dance_t > 0.0 and src != null and run._flat(src.pos - hero.pos).length() < 4.0)
	if src != null and src.team == 1 and is_exposed(src):
		a *= 0.6
	if not parried or src == null or src.team != 1:
		return a
	var times := 2 if dance_t > 0.0 else 1
	for i in times:
		if src.alive:
			hero.face(src.pos - hero.pos)
			run.fx("rift_strike", {"pos": src.pos})
			run.damage(src, counter_dmg(), hero, "Counter", "phys", {"crit": true, "color": GOLDEN})
	if parry_t > 0.0:
		hero.cds[0] = 0.0
		_close_parry()
	poise = mini(POISE_MAX, poise + 1)
	poise_t = 5.0
	run.fx("hit", {"pos": hero.pos + Vector3(0, 1.3, 0) + hero.facing * 0.5, "color": GOLDEN})
	run.fx("damage_number", {"pos": hero.pos + Vector3(0, 2.2, 0), "text": "Parry!", "color": GOLDEN})
	hero.set_state("attack", true)
	Audio.play("slash")
	return 0.0


func override_motion(dt: float) -> bool:
	if lunge.is_empty():
		return false
	lunge["t"] += dt
	var k := clampf(lunge["t"] / lunge["dur"], 0.0, 1.0)
	var prev := hero.pos
	hero.pos = run.resolve_pos(hero, lunge["from"].lerp(lunge["to"], k), prev)
	var dmg := 60.0 + 40.0 * rank(1) + 1.2 * hero.agi_v
	for e in enemies_on_line(prev, hero.pos, 1.5):
		if lunge["hit"].has(e):
			continue
		lunge["hit"][e] = true
		var ex := is_exposed(e)
		run.damage(e, dmg * (2.0 if ex else 1.0), hero, "Lunge", "phys", {"crit": ex, "color": STEEL})
		if ex and not lunge["refund"]:
			lunge["refund"] = true
	if k >= 1.0:
		if lunge["refund"]:
			hero.cds[1] = hero.skill_cd(1) * 0.5
		lunge = {}
	return true


func override_motion_active() -> bool:
	return not lunge.is_empty()


## Exposed foes take 25% more from the Duelist's swings.
func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel or not is_exposed(target):
		return false
	run.fx("hit", {"pos": target.pos + Vector3(0, 1.0, 0), "color": GOLDEN})
	run.damage(target, dmg * 1.25, hero, "Attack", "phys", {"attack": true, "crit": crit, "melee": true})
	Audio.play("hit")
	return true


func tick(dt: float) -> void:
	if parry_t > 0.0:
		parry_t -= dt
		if parry_t <= 0.0:
			_close_parry()
	if dance_t > 0.0:
		dance_t -= dt
		if dance_t <= 0.0 and dance_fx != null:
			run.fx_stop(dance_fx)
			dance_fx = null
	if poise > 0:
		poise_t -= dt
		if poise_t <= 0.0:
			poise -= 1
			poise_t = 5.0
	if not exposed.is_empty():
		var keep := {}
		for e in exposed:
			var t: float = exposed[e] - dt
			if t > 0.0 and e.alive:
				keep[e] = t
		exposed = keep


func _clear() -> void:
	_close_parry()
	dance_t = 0.0
	if dance_fx != null:
		run.fx_stop(dance_fx)
		dance_fx = null
	exposed.clear()
	lunge = {}


func on_wave_end() -> void:
	_clear()
	poise = 0


func on_teleport(_p: Vector3) -> void:
	_clear()


func hud_meter() -> Dictionary:
	var label := "Poise %d / %d" % [poise, POISE_MAX]
	if parry_t > 0.0:
		label = "PARRY!"
	return {"type": "bar", "label": label, "value": float(poise), "max": float(POISE_MAX), "color": GOLDEN}


## The bot parries when a foe next to it is mid-swing (or when crowded), the way a player would time it.
func bot_wants(slot: int) -> bool:
	match slot:
		0:
			for e in run.enemies_in_radius(hero.pos, 3.2):
				if e.atk_wind > 0.0 and e.target == hero:
					return true
			return run.count_enemies(hero.pos, 2.6) >= 3
		1:
			var n := run.nearest_enemy(hero.pos, 6.0)
			return n != null and (is_exposed(n) or run.count_enemies(hero.pos, 6.0) >= 2)
		2:
			return run.count_enemies(hero.pos, 3.6) >= 2 or run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 3.6) != null
		3:
			return run.count_enemies(hero.pos, 4.0) >= 5 or (run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 4.0) != null)
	return false
