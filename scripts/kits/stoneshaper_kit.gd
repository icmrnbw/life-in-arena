extends HeroKit
## Stoneshaper: the arena is the weapon. Shoved foes that slam into a pillar, the outer wall, a ridge,
## a barrel or another foe take impact damage and are stunned (and the foe they hit is knocked on).
## Rock Shove, Stone Ridge, Quake, Avalanche.

const SAND := Color(0.95, 0.68, 0.38)

var flying := {}        # Enemy -> {"t": s, "dmg": impact damage, "depth": chain depth}
var ridges: Array = []  # run wall dicts
var boulder := {}       # {pos, dir, left, node, hit: {}}


func impact_dmg() -> float:
	return 65.0 + 45.0 * maxi(1, rank(0)) + 1.0 * hero.str_v


func launch(e: Unit, dir: Vector3, strength: float, depth := 0) -> void:
	if not e.alive:
		return
	shove(e, dir, strength)
	flying[e] = {"t": 0.7, "dmg": impact_dmg() * (1.0 if depth == 0 else 0.6), "depth": depth}


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0:
			# shove the nearest foe toward the closest pillar or wall behind it, if any
			var n := run.nearest_enemy(hero.pos, 5.0)
			if n:
				return {"dir": run._flat(n.pos - hero.pos).normalized(), "point": n.pos}
		1:
			var c := run.best_cluster(hero.pos, 12.0, 3.5)
			if not c.is_empty():
				var d: Vector3 = run._flat(c["pos"] - hero.pos)
				var p := hero.pos + d.normalized() * clampf(d.length() * 0.5, 2.5, 6.0)
				return {"point": p, "dir": d.normalized()}
		3:
			var c2 := run.best_cluster(hero.pos, 14.0, 2.5)
			if not c2.is_empty():
				var d2: Vector3 = run._flat(c2["pos"] - hero.pos)
				return {"dir": d2.normalized(), "point": c2["pos"]}
	return {"point": hero.pos + hero.facing * 4.0, "dir": hero.facing}


func aim_spec(slot: int) -> Dictionary:
	var s := super.aim_spec(slot)
	if slot == 1:
		s["length"] = ridge_len()
	return s


func ridge_len() -> float:
	return 5.0 + 1.0 * maxi(1, rank(1))


func can_cast(slot: int) -> bool:
	if slot == 3 and not boulder.is_empty():
		return false
	return true


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			return _shove(aim)
		1:
			return _ridge(aim)
		2:
			return _quake()
		3:
			return _avalanche(aim)
	return false


func _shove(aim: Dictionary) -> bool:
	var d := aim_dir(aim)
	hero.face(d)
	run.fx("cone", {"pos": hero.pos, "dir": d, "range": 3.6, "angle": 100.0, "color": SAND})
	var dmg := 45.0 + 30.0 * rank(0) + 0.65 * hero.str_v
	for e in enemies_in_cone(hero.pos, d, 3.6, 100.0):
		run.damage(e, dmg, hero, "Rock Shove", "phys", {"color": SAND})
		# push mostly along the aim, a little away from the hero
		var away := run._flat(e.pos - hero.pos).normalized()
		launch(e, (d * 0.75 + away * 0.25).normalized(), 15.0)
	run.shake(0.15)
	return true


func _ridge(aim: Dictionary) -> bool:
	var center := clamp_point(aim.get("point", hero.pos + hero.facing * 4.0), DB.SKILLS["stone_ridge"]["range"])
	var d := run._flat(center - hero.pos)
	if d.length() < 0.3:
		d = aim_dir(aim)
	d = d.normalized()
	var perp := Vector3(-d.z, 0, d.x)
	var half := ridge_len() * 0.5
	var dur := 6.0 + 1.0 * rank(1)
	var w := run.add_wall(center - perp * half, center + perp * half, dur, 0.0, hero, "Stone Ridge", "stone_ridge")
	ridges.append(w)
	# rising rock jolts anything standing on the line
	for e in enemies_on_line(w["a"], w["b"], 1.2):
		run.damage(e, 25.0 + 20.0 * rank(1), hero, "Stone Ridge", "phys", {"color": SAND})
		var side := signf(Vector3(-perp.z, 0, perp.x).dot(e.pos - center))
		e.knock = d * (side if side != 0.0 else 1.0) * 6.0
	run.shake(0.18)
	return true


func _quake() -> bool:
	var r: float = DB.SKILLS["quake"]["range"]
	run.fx("ring_burst", {"pos": hero.pos, "radius": r, "color": SAND})
	run.fx("slam", {"pos": hero.pos, "radius": r, "color": SAND})
	var dmg := 55.0 + 40.0 * rank(2) + 0.75 * hero.str_v
	for e in run.enemies_in_radius(hero.pos, r):
		run.damage(e, dmg, hero, "Quake", "phys", {"color": SAND})
		if e.alive:
			e.apply_slow(0.3, 2.0)
			launch(e, e.pos - hero.pos, 8.0)
	run.shake(0.3)
	Audio.play("slam")
	return true


func _avalanche(aim: Dictionary) -> bool:
	var d := aim_dir(aim)
	var node := run.spawn_summon("boulder", hero.pos + d * 1.2)
	node.targetable = false
	node.collides = false
	node.no_push = true
	node.lifetime = 4.0
	boulder = {"pos": hero.pos + d * 1.2, "dir": d, "left": DB.SKILLS["avalanche"]["range"], "node": node, "hit": {},
		"dmg": 120.0 + 80.0 * rank(3) + 1.2 * hero.str_v}
	hero.face(d)
	return true


func _tick_boulder(dt: float) -> void:
	var step: float = minf(15.0 * dt, boulder["left"])
	var a: Vector3 = boulder["pos"]
	var b: Vector3 = a + boulder["dir"] * step
	boulder["left"] -= step
	var stop: bool = boulder["left"] <= 0.0
	for pl in DB.PILLARS:
		if Vector2(b.x - pl.x, b.z - pl.z).length() < DB.PILLAR_R + 0.9:
			stop = true
	if Vector2(b.x, b.z).length() > DB.ARENA_R - 1.2:
		stop = true
	boulder["pos"] = b
	var n: Unit = boulder["node"]
	if n and n.alive:
		n.pos = b
		n.facing = boulder["dir"]
		n.sync_visual()
	var side := Vector3(-boulder["dir"].z, 0, boulder["dir"].x)
	for e in enemies_on_line(a, b, 2.2):
		if boulder["hit"].has(e):
			continue
		boulder["hit"][e] = true
		run.damage(e, boulder["dmg"], hero, "Avalanche", "phys", {"color": SAND, "crit": true})
		if e.alive:
			var s := signf(side.dot(e.pos - b))
			launch(e, (boulder["dir"] * 0.6 + side * (s if s != 0.0 else 1.0)).normalized(), 18.0)
	if stop:
		run.fx("ring_burst", {"pos": b, "radius": 3.5, "color": SAND})
		run.fx("death_burst", {"pos": b, "size": 2.0, "color": SAND})
		for e in run.enemies_in_radius(b, 3.5):
			if not boulder["hit"].has(e):
				run.damage(e, boulder["dmg"] * 0.5, hero, "Avalanche", "phys", {"color": SAND})
				launch(e, e.pos - b, 12.0)
		run.shake(0.4)
		Audio.play("slam")
		if n and n.alive:
			run.remove_ally(n, false)
		boulder = {}


## True when `e` (moving) has run into something solid; returns the foe it hit, if any, via `other`.
func _impact(e: Unit, other: Array) -> bool:
	var p := e.pos
	for pl in DB.PILLARS:
		if Vector2(p.x - pl.x, p.z - pl.z).length() < DB.PILLAR_R + e.radius + 0.3:
			return true
	if Vector2(p.x, p.z).length() > DB.ARENA_R - e.radius - 0.6:
		return true
	for w in run.walls:
		var c := Run.seg_closest(p, w["a"], w["b"])
		if run._flat(p - c).length() < e.radius + 0.55:
			return true
	if run.barrels and run.barrels.barrel_near(p, e.radius + 0.2) != null:
		return true
	var kv := run._flat(e.knock)
	for o in run.enemies_in_radius(p, e.radius + 0.6):
		if o == e or flying.has(o):
			continue
		var rel := run._flat(o.pos - p)
		if rel.length() < e.radius + o.radius + 0.15 and (kv.length() < 0.1 or rel.normalized().dot(kv.normalized()) > 0.2):
			other.append(o)
			return true
	return false


func tick(dt: float) -> void:
	if not boulder.is_empty():
		_tick_boulder(dt)
	if flying.is_empty():
		return
	for e in flying.keys():
		var f: Dictionary = flying[e]
		f["t"] -= dt
		if not e.alive or f["t"] <= 0.0:
			flying.erase(e)
			continue
		if e.knock.length() < 2.0:
			flying.erase(e)
			continue
		var other := []
		if _impact(e, other):
			var kdir := run._flat(e.knock)
			flying.erase(e)
			e.knock = Vector3.ZERO
			run.fx("hit", {"pos": e.pos + Vector3(0, 0.8, 0), "color": SAND})
			run.fx("ring_burst", {"pos": e.pos, "radius": 1.4, "color": SAND})
			run.damage(e, f["dmg"], hero, "Impact", "phys", {"color": SAND, "crit": true})
			if e.alive:
				stun(e, 1.0)
			run.shake(0.12)
			for o in other:
				run.damage(o, f["dmg"] * 0.6, hero, "Impact", "phys", {"color": SAND})
				if o.alive:
					stun(o, 0.6)
					if int(f["depth"]) < 2:
						launch(o, kdir, 10.0, int(f["depth"]) + 1)


func on_wave_end() -> void:
	flying.clear()
	if not boulder.is_empty():
		var n: Unit = boulder["node"]
		if n and n.alive:
			run.remove_ally(n, false)
	boulder = {}
	ridges.clear()


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			return run.count_enemies(hero.pos, 3.5) >= 1
		1:
			if run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 9.0) != null:
				return true
			return run.count_enemies(hero.pos, 9.0) >= 5
		2:
			return run.count_enemies(hero.pos, 4.5) >= 3 or (hero.hp < hero.max_hp * 0.45 and run.count_enemies(hero.pos, 4.5) >= 2)
		3:
			var c := run.best_cluster(hero.pos, 14.0, 2.5)
			return not c.is_empty() and (int(c["count"]) >= 4 or run.boss_units.size() > 0)
	return false
