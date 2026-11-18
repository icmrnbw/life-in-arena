extends HeroKit
## Frostweaver: Chill stacks (max 5, each slows 8%). Five Chill freezes a foe solid for 1.6 s (bosses far less);
## a frozen foe is Brittle: it loses BRITTLE armor, so any physical hit (hers, an ally's, an item's) lands ~50% harder.
## Ice Shard, Frost Nova, Shatter, Blizzard. All her damage is magic.

const ICE := Color(0.6, 0.9, 1.0)
const DEEP := Color(0.35, 0.6, 1.0)
const MAX_CHILL := 5
const FREEZE_TIME := 1.6
const BRITTLE := 10.0
const CHILL_TIME := 4.0

var chill := {}             # Enemy -> {"n": stacks, "t": s left, "frozen": s left, "armor": armor taken, "fx": mark}
var storm := {}             # {pos, r, t, tick, fx}


func stacks(e: Unit) -> int:
	return int(chill[e]["n"]) if chill.has(e) else 0


func is_frozen(e: Unit) -> bool:
	return chill.has(e) and float(chill[e]["frozen"]) > 0.0


func add_chill(e: Unit, n: int) -> void:
	if not e.alive or n <= 0:
		return
	if not chill.has(e):
		chill[e] = {"n": 0, "t": CHILL_TIME, "frozen": 0.0, "armor": 0.0, "fx": null}
	var c: Dictionary = chill[e]
	c["t"] = CHILL_TIME
	if c["frozen"] > 0.0:
		return
	c["n"] = mini(MAX_CHILL, int(c["n"]) + n)
	e.apply_slow(0.08 * c["n"], 0.6)
	if c["n"] >= MAX_CHILL:
		_freeze(e, c)


func _freeze(e: Unit, c: Dictionary) -> void:
	var t := FREEZE_TIME * (0.35 if e.is_boss else 1.0)
	c["frozen"] = t
	c["n"] = 0
	e.stun_t = maxf(e.stun_t, t)
	c["armor"] = BRITTLE
	e.armor -= BRITTLE
	c["fx"] = run.fx("mark", {"target": e.node, "pos": e.pos, "color": ICE})
	e.flash(ICE)
	run.fx("hit", {"pos": e.pos + Vector3(0, 1.0, 0), "color": ICE})
	run.hint_once("brittle", "Frozen foes are brittle: physical hits deal about 50% more.")


func _thaw(e: Unit, c: Dictionary) -> void:
	c["frozen"] = 0.0
	if c["armor"] > 0.0:
		e.armor += c["armor"]
		c["armor"] = 0.0
	if c["fx"] != null:
		run.fx_stop(c["fx"])
		c["fx"] = null


func hit(e: Unit, amount: float, tag: String, n_chill: int, opts := {}) -> float:
	var o := opts.duplicate()
	if not o.has("color"):
		o["color"] = ICE
	var a := run.damage(e, amount, hero, tag, "magic", o)
	add_chill(e, n_chill)
	return a


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0:
			var c := run.best_cluster(hero.pos, 11.0, 1.6)
			if not c.is_empty():
				return {"dir": run._flat(c["pos"] - hero.pos).normalized(), "point": c["pos"]}
			var n := run.nearest_enemy(hero.pos, 11.0)
			if n:
				return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
		2:
			var best := Vector3.ZERO
			var bs := 0
			for e in chill:
				if is_frozen(e) and e.alive and run._flat(e.pos - hero.pos).length() < 10.0:
					var s := 0
					for o in chill:
						if o.alive and run._flat(o.pos - e.pos).length() < 4.0:
							s += 2 if is_frozen(o) else 1
					if s > bs:
						bs = s
						best = e.pos
			if bs > 0:
				return {"point": best}
			var c2 := run.best_cluster(hero.pos, 10.0, 4.0)
			if not c2.is_empty():
				return {"point": c2["pos"]}
		3:
			var c3 := run.best_cluster(hero.pos, 12.0, 4.5)
			if not c3.is_empty():
				return {"point": c3["pos"]}
	return {"point": hero.pos + hero.facing * 5.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			var d := aim_dir(aim)
			hero.face(d)
			var a := hero.pos
			var b := a + d * DB.SKILLS["ice_shard"]["range"]
			run.fx_timed("beam", {"from": a + Vector3(0, 1.2, 0), "to": b + Vector3(0, 1.2, 0), "width": 0.5, "color": ICE}, 0.25)
			var dmg := 55.0 + 40.0 * rank(0) + 1.1 * hero.int_v
			for e in enemies_on_line(a, b, 1.4):
				hit(e, dmg, "Ice Shard", 2)
			Audio.play("orb")
			return true
		1:
			var r: float = DB.SKILLS["frost_nova"]["radius"]
			run.fx("ring_burst", {"pos": hero.pos, "radius": r, "color": ICE})
			var dmg2 := 45.0 + 35.0 * rank(1) + 0.9 * hero.int_v
			for e in run.enemies_in_radius(hero.pos, r):
				hit(e, dmg2, "Frost Nova", 2)
				if e.alive:
					stun(e, 1.0)
			Audio.play("slam")
			return true
		2:
			var p := clamp_point(aim.get("point", hero.pos + hero.facing * 6.0), DB.SKILLS["shatter"]["range"])
			_shatter(p)
			return true
		3:
			var p2 := clamp_point(aim.get("point", hero.pos + hero.facing * 6.0), DB.SKILLS["blizzard"]["range"])
			if not storm.is_empty():
				run.fx_stop(storm["fx"])
			var r2: float = DB.SKILLS["blizzard"]["radius"]
			storm = {"pos": p2, "r": r2, "t": 6.0, "tick": 0.0, "fx": run.fx("zone", {"pos": p2, "radius": r2, "duration": 6.0, "color": ICE})}
			return true
	return false


func _shatter(p: Vector3) -> void:
	var r: float = DB.SKILLS["shatter"]["radius"]
	run.fx("explosion", {"pos": p, "radius": r, "color": ICE})
	var base := 50.0 + 35.0 * rank(2) + 1.0 * hero.int_v
	var spread := []
	for e in run.enemies_in_radius(p, r):
		if is_frozen(e):
			_thaw(e, chill[e])
			run.fx("shatter", {"pos": e.pos, "color": ICE})
			run.damage(e, base * 3.0, hero, "Shatter", "magic", {"crit": true, "color": ICE})
			spread.append(e.pos)
		else:
			run.damage(e, base * (1.0 + 0.15 * stacks(e)), hero, "Shatter", "magic", {"color": ICE})
	for sp in spread:
		for o in run.enemies_in_radius(sp, 2.5):
			add_chill(o, 2)
	run.shake(0.18)
	Audio.play("slam")


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel:
		return false
	run.fire_projectile("frost_bolt", hero.pos + Vector3(0, 1.3, 0), target, Vector3.ZERO, 17.0, dmg, 0, hero, "Frost Bolt",
		{"dtype": "magic", "attack": true, "crit": crit, "color": ICE})
	return true


func on_attack_hit(target: Unit) -> void:
	add_chill(target, 1)


func tick(dt: float) -> void:
	if not chill.is_empty():
		var keep := {}
		for e in chill:
			var c: Dictionary = chill[e]
			if not e.alive:
				_thaw(e, c)
				continue
			if c["frozen"] > 0.0:
				c["frozen"] -= dt
				if c["frozen"] <= 0.0:
					_thaw(e, c)
			c["t"] -= dt
			if c["t"] <= 0.0 and c["frozen"] <= 0.0:
				continue
			keep[e] = c
		chill = keep
	if not storm.is_empty():
		storm["t"] -= dt
		storm["tick"] -= dt
		for e in run.enemies_in_radius(storm["pos"], storm["r"]):
			e.apply_slow(0.3, 0.3)
		if storm["tick"] <= 0.0:
			storm["tick"] = 1.0
			var dps := 50.0 + 40.0 * rank(3) + 1.0 * hero.int_v
			for e in run.enemies_in_radius(storm["pos"], storm["r"]):
				hit(e, dps, "Blizzard", 1)
		if storm["t"] <= 0.0:
			run.fx_stop(storm["fx"])
			storm = {}


func _clear() -> void:
	for e in chill:
		_thaw(e, chill[e])
	chill.clear()
	if not storm.is_empty():
		run.fx_stop(storm["fx"])
	storm = {}


func on_wave_end() -> void:
	_clear()


func on_teleport(_p: Vector3) -> void:
	_clear()


func hud_meter() -> Dictionary:
	var frozen := 0
	for e in chill:
		if is_frozen(e):
			frozen += 1
	return {"type": "bar", "label": "Frozen %d" % frozen, "value": float(mini(frozen, 6)), "max": 6.0, "color": ICE}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			var c := run.best_cluster(hero.pos, 11.0, 1.6)
			return not c.is_empty()
		1:
			return run.count_enemies(hero.pos, 4.0) >= 2
		2:
			var f := 0
			for e in chill:
				if is_frozen(e) and run._flat(e.pos - hero.pos).length() < 10.0:
					f += 1
			return f >= 2 or (f >= 1 and run.boss_units.size() > 0)
		3:
			var c3 := run.best_cluster(hero.pos, 12.0, 4.5)
			return not c3.is_empty() and (int(c3["count"]) >= 5 or run.boss_units.size() > 0)
	return false
