extends HeroKit
## Nightblade: position matters. Hits on a foe's back deal +60% (backstab). Shadowstep (blink behind a foe),
## Fan of Knives, Vanish (foes swarm a hidden decoy where she vanished; next hit x3), Death Mark (stores damage).

const SHADOW := Color(0.62, 0.42, 1.0)
const STEEL := Color(0.9, 0.9, 1.0)
const BACKSTAB := 1.6

var vanish_t := 0.0
var decoy: Unit = null
var ambush := false          # next hit out of Vanish is a triple-damage backstab
var mark := {}               # {e, t, stored, fx}


## A foe is struck from behind when the Nightblade stands in the half-space behind its facing.
func is_behind(e: Unit) -> bool:
	var off := run._flat(hero.pos - e.pos)
	if off.length() < 0.05:
		return true
	return off.normalized().dot(e.facing) < -0.15


func speed_mult() -> float:
	return 1.4 if vanish_t > 0.0 else 1.0


## Every hit she lands goes through here: backstab bonus and Death Mark bookkeeping.
func hit(e: Unit, amount: float, tag: String, opts := {}) -> float:
	var o := opts.duplicate()
	var a := amount
	if is_behind(e) or opts.get("force_back", false):
		a *= BACKSTAB
		o["crit"] = true
		o["color"] = SHADOW
	o.erase("force_back")
	var dealt := run.damage(e, a, hero, tag, "phys", o)
	if not mark.is_empty() and mark["e"] == e:
		mark["stored"] += dealt
	return dealt


func smart_aim(slot: int) -> Dictionary:
	if slot == 0:
		var t: Unit = null
		if not mark.is_empty() and mark["e"].alive:
			t = mark["e"]
		if t == null:
			t = run.nearest_enemy(hero.pos, 8.0)
		if t:
			return {"dir": run._flat(t.pos - hero.pos).normalized(), "point": t.pos}
	return {"point": hero.pos + hero.facing * 3.0, "dir": hero.facing}


func can_cast(slot: int) -> bool:
	match slot:
		0:
			if _step_target(hero.facing, true) == null:
				run.toast("No foe in reach", SHADOW)
				return false
		3:
			if not mark.is_empty():
				return false
			return run.nearest_enemy(hero.pos, 12.0) != null
	return true


## Nearest foe roughly along `d` (any foe in reach when `any`).
func _step_target(d: Vector3, any := false) -> Unit:
	var best: Unit = null
	var bs := 1e9
	for e in run.enemies_in_radius(hero.pos, DB.SKILLS["shadowstep"]["range"]):
		var off := run._flat(e.pos - hero.pos)
		var along := off.normalized().dot(d) if off.length() > 0.05 else 1.0
		if not any and along < 0.4:
			continue
		var score := off.length() * (2.0 - along)
		if score < bs:
			bs = score
			best = e
	return best


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			var t := _step_target(aim_dir(aim))
			if t == null:
				t = _step_target(aim_dir(aim), true)
			if t == null:
				return false
			var back := t.pos - t.facing * (t.radius + hero.radius + 0.3)
			run.fx("teleport", {"pos": hero.pos, "color": SHADOW})
			var old := hero.pos
			hero.pos = run.resolve_pos(hero, back, t.pos)
			run.fx("slip_trail", {"from": old, "to": hero.pos, "color": SHADOW})
			hero.face(t.pos - hero.pos)
			hero.focus = t
			hit(t, 70.0 + 50.0 * rank(0) + 1.5 * hero.agi_v, "Shadowstep", {"force_back": true})
			hero.set_state("attack", true)
			Audio.play("slash")
			return true
		1:
			var r: float = DB.SKILLS["fan_of_knives"]["radius"]
			run.fx("ring_burst", {"pos": hero.pos, "radius": r, "color": STEEL})
			var dmg := 40.0 + 30.0 * rank(1) + 0.9 * hero.agi_v
			for e in run.enemies_in_radius(hero.pos, r):
				hit(e, dmg, "Fan of Knives", {"color": STEEL})
				if e.alive:
					e.apply_slow(0.35, 2.0)
			for i in 10:
				var a := TAU * i / 10.0
				run.fire_projectile("dagger", hero.pos + Vector3(0, 1.1, 0), null, Vector3(cos(a), 0, sin(a)), 22.0, 0.0, 0, hero, "Fan of Knives",
					{"life": r / 22.0, "hit_r": 0.01, "dtype": "phys", "color": STEEL})
			Audio.play("slash")
			return true
		2:
			_vanish([2.5, 3.0, 3.5, 4.0][clampi(rank(2) - 1, 0, 3)])
			return true
		3:
			var cands := run.enemies_in_radius(hero.pos, 12.0)
			cands.sort_custom(func(a, b):
				if a.is_boss != b.is_boss:
					return a.is_boss
				return a.hp > b.hp)
			var t2: Unit = cands[0]
			mark = {"e": t2, "t": 4.0, "stored": 0.0, "fx": run.fx("mark", {"target": t2.node, "pos": t2.pos, "color": SHADOW})}
			hero.focus = t2
			run.toast("Marked for death", SHADOW)
			return true
	return false


func _vanish(dur: float) -> void:
	_end_vanish()
	vanish_t = dur
	ambush = true
	run.fx("teleport", {"pos": hero.pos, "color": SHADOW})
	# an unseen decoy at the spot she vanished from: every foe nearby hunts it instead of her
	decoy = Unit.new()
	decoy.run = run
	decoy.kind = "shadow_decoy"
	decoy.team = 0
	decoy.is_summon = true
	decoy.pos = hero.pos
	decoy.collides = false
	decoy.no_push = true
	decoy.radius = 0.5
	decoy.max_hp = 1e6
	decoy.hp = 1e6
	decoy.invuln_t = dur + 1.0
	decoy.lifetime = dur
	run.allies.append(decoy)
	for e in run.enemies_in_radius(hero.pos, 16.0):
		e.taunt_target = decoy
		e.taunt_t = dur
		e.target = decoy
	hero.set_tint(Color(0.35, 0.3, 0.55))
	hero.atk_target = null


func _end_vanish() -> void:
	vanish_t = 0.0
	if decoy != null:
		if decoy.alive:
			run.remove_ally(decoy, false)
		decoy = null
	hero.set_tint(Color(1, 1, 1))


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel:
		return false
	var d := dmg
	var o := {"attack": true, "crit": crit, "melee": true}
	if ambush:
		d *= 3.0
		o["force_back"] = true
		ambush = false
		_end_vanish()
		run.fx("rift_strike", {"pos": target.pos})
	run.fx("hit", {"pos": target.pos + Vector3(0, 1.0, 0), "color": SHADOW if is_behind(target) else STEEL})
	hit(target, d, "Attack", o)
	Audio.play("hit")
	return true


func tick(dt: float) -> void:
	if vanish_t > 0.0:
		vanish_t -= dt
		if vanish_t <= 0.0:
			_end_vanish()
	if not mark.is_empty():
		mark["t"] -= dt
		var e: Unit = mark["e"]
		if not e.alive:
			run.fx_stop(mark["fx"])
			mark = {}
		elif mark["t"] <= 0.0:
			run.fx_stop(mark["fx"])
			var burst: float = mark["stored"] * 0.5 + 150.0 + 120.0 * rank(3) + 2.0 * hero.agi_v
			run.fx("shatter", {"pos": e.pos, "color": SHADOW})
			mark = {}
			run.damage(e, burst, hero, "Death Mark", "phys", {"crit": true, "color": SHADOW})
			if e.alive and not e.is_boss and e.hp < e.max_hp * 0.25:
				run.damage_number(e.pos, e.hp, true, SHADOW)
				run.kill(e, hero)
			run.shake(0.2)


func _clear() -> void:
	_end_vanish()
	ambush = false
	if not mark.is_empty():
		run.fx_stop(mark["fx"])
	mark = {}


func on_wave_end() -> void:
	_clear()


func on_teleport(_p: Vector3) -> void:
	_clear()


func hud_meter() -> Dictionary:
	if vanish_t > 0.0:
		return {"type": "bar", "label": "Hidden", "value": vanish_t, "max": 4.0, "color": SHADOW}
	if not mark.is_empty():
		return {"type": "bar", "label": "Death Mark %d" % int(mark["stored"]), "value": mark["t"], "max": 4.0, "color": SHADOW}
	return {}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			var n := run.nearest_enemy(hero.pos, 8.0)
			return n != null and (not mark.is_empty() or run._flat(n.pos - hero.pos).length() > 3.0 or n.is_boss)
		1:
			return run.count_enemies(hero.pos, 4.0) >= 3
		2:
			return hero.hp < hero.max_hp * 0.45 or run.count_enemies(hero.pos, 3.5) >= 5
		3:
			return run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 12.0) != null or run.count_enemies(hero.pos, 12.0) >= 8
	return false
