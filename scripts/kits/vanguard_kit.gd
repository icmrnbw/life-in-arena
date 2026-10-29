extends HeroKit
## Vanguard: no mana. Rage (0-100) fills from blows given and taken and pays for skills; it drains out of combat.
## Shield Bash, War Cry (taunt + damage cut), Iron Will (Rage -> shield that bursts), Juggernaut.

const RAGE := Color(1.0, 0.36, 0.2)
const IRON := Color(0.78, 0.82, 0.9)
const RAGE_MAX := 100.0

var rage := 0.0
var calm_t := 0.0           # seconds since the last blow; Rage drains after 4 s
var cry_t := 0.0
var will := {}              # {t, fx}
var jugg_t := 0.0
var jugg_fx: Node = null


func rage_cost(slot: int) -> float:
	return float(DB.SKILLS[hero.skill_ids[slot]].get("rage", 0))


func add_rage(v: float) -> void:
	rage = clampf(rage + v, 0.0, RAGE_MAX)
	calm_t = 0.0


func blocked(slot: int) -> bool:
	return jugg_t <= 0.0 and rage < rage_cost(slot)


func can_cast(slot: int) -> bool:
	if blocked(slot):
		run.toast("Not enough Rage", RAGE)
		return false
	if slot == 2 and not will.is_empty():
		return false
	return true


func after_cast(slot: int) -> void:
	if jugg_t > 0.0 or slot == 2:
		return
	rage = maxf(0.0, rage - rage_cost(slot))


func smart_aim(slot: int) -> Dictionary:
	if slot == 0:
		var c := run.best_cluster(hero.pos, 3.4, 2.0)
		if not c.is_empty():
			return {"dir": run._flat(c["pos"] - hero.pos).normalized(), "point": c["pos"]}
		var n := run.nearest_enemy(hero.pos, 6.0)
		if n:
			return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
	return {"point": hero.pos + hero.facing * 3.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			var d := aim_dir(aim)
			hero.face(d)
			run.fx("cone", {"pos": hero.pos, "dir": d, "range": 3.4, "angle": 75.0, "color": IRON})
			var dmg := 50.0 + 35.0 * rank(0) + 0.8 * hero.str_v + 6.0 * hero.armor
			for e in enemies_in_cone(hero.pos, d, 3.4, 75.0):
				run.damage(e, dmg, hero, "Shield Bash", "phys", {"color": IRON})
				if e.alive:
					stun(e, 1.2)
					shove(e, e.pos - hero.pos, 5.0)
			run.shake(0.2)
			Audio.play("slam")
			return true
		1:
			var r: float = DB.SKILLS["war_cry"]["radius"]
			for e in run.enemies_in_radius(hero.pos, r):
				e.taunt_target = hero
				e.taunt_t = 3.0
				e.target = hero
			cry_t = 5.0
			run.fx("ring_burst", {"pos": hero.pos, "radius": r, "color": RAGE})
			run.fx("slam", {"pos": hero.pos, "radius": 2.0, "color": RAGE})
			run.shake(0.15)
			Audio.play("boss")
			return true
		2:
			var spent := rage if jugg_t <= 0.0 else RAGE_MAX * 0.6
			if jugg_t <= 0.0:
				rage = 0.0
			hero.shield += spent * (3.0 + float(rank(2)))
			will = {"t": 6.0, "fx": run.fx("carapace", {"target": hero.node, "pos": hero.pos, "duration": 6.0}), "dmg": 40.0 + 30.0 * rank(2) + spent * 1.5}
			run.fx("hit", {"pos": hero.pos + Vector3(0, 1.2, 0), "color": IRON})
			return true
		3:
			jugg_t = [8.0, 9.0, 10.0][clampi(rank(3) - 1, 0, 2)]
			rage = RAGE_MAX
			if jugg_fx == null:
				jugg_fx = run.fx("buff_aura", {"target": hero.node, "pos": hero.pos, "radius": 1.4, "color": RAGE})
			run.fx("slam", {"pos": hero.pos, "radius": 3.0, "color": RAGE})
			run.toast("Juggernaut!", RAGE)
			Audio.play("boss")
			return true
	return false


## War Cry: 15/20/25/30% less damage taken while it lasts.
func cry_mult() -> float:
	return 1.0 - (0.1 + 0.05 * rank(1)) if cry_t > 0.0 else 1.0


func _burst_will() -> void:
	if will.is_empty():
		return
	run.fx_stop(will["fx"])
	var r: float = DB.SKILLS["iron_will"]["radius"]
	run.fx("explosion", {"pos": hero.pos, "radius": r, "color": IRON})
	for e in run.enemies_in_radius(hero.pos, r):
		run.damage(e, will["dmg"], hero, "Iron Will", "phys", {"color": IRON})
		if e.alive:
			shove(e, e.pos - hero.pos, 6.0)
	hero.shield = 0.0
	will = {}
	run.shake(0.2)


## Taking a blow fills Rage (more for bigger blows); Juggernaut shrugs off a quarter of it.
func incoming_damage(a: float, src: Unit) -> float:
	if a <= 0.0:
		return a
	a *= 0.85   # Unbroken: plate takes the edge off every blow
	if jugg_t > 0.0:
		a *= 0.75
	a *= cry_mult()
	if src != null:
		add_rage(4.0 + 120.0 * a / maxf(1.0, hero.max_hp))
	return a


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel:
		return false
	add_rage(10.0)
	if jugg_t <= 0.0:
		return false
	run.fx("cone", {"pos": hero.pos, "dir": hero.facing, "range": 2.8, "angle": 300.0, "color": RAGE})
	for e in run.enemies_in_radius(hero.pos, hero.atk_range + 1.0):
		run.damage(e, dmg * (1.0 if e == target else 0.6), hero, "Attack", "phys", {"attack": e == target, "crit": crit, "melee": true})
	Audio.play("hit")
	return true


func tick(dt: float) -> void:
	calm_t += dt
	if jugg_t > 0.0:
		rage = RAGE_MAX
		jugg_t -= dt
		if jugg_t <= 0.0:
			if jugg_fx != null:
				run.fx_stop(jugg_fx)
				jugg_fx = null
	elif calm_t > 4.0 or hero.in_camp:
		rage = maxf(0.0, rage - 6.0 * dt)
	if cry_t > 0.0:
		cry_t -= dt
	if not will.is_empty():
		will["t"] -= dt
		if will["t"] <= 0.0 or hero.shield <= 0.0:
			_burst_will()


func _clear() -> void:
	if not will.is_empty():
		run.fx_stop(will["fx"])
		hero.shield = 0.0
		will = {}
	cry_t = 0.0
	jugg_t = 0.0
	if jugg_fx != null:
		run.fx_stop(jugg_fx)
		jugg_fx = null


func on_wave_start() -> void:
	rage = maxf(rage, 30.0)


func on_wave_end() -> void:
	_clear()


func on_teleport(_p: Vector3) -> void:
	_clear()


func hud_meter() -> Dictionary:
	return {"type": "bar", "label": "Rage %d" % int(rage), "value": rage, "max": RAGE_MAX, "color": RAGE}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			return run.count_enemies(hero.pos, 3.4) >= 2 or (run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 3.4) != null)
		1:
			return run.count_enemies(hero.pos, 5.5) >= 4
		2:
			return rage >= 45.0 and (hero.hp < hero.max_hp * 0.7 or run.count_enemies(hero.pos, 4.0) >= 4)
		3:
			return run.count_enemies(hero.pos, 5.0) >= 6 or (run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 5.0) != null)
	return false
