class_name Arena
extends RefCounted
## The Pit's ground changing during a fight (both rebuilt between waves):
## - Toppling pillars: a boss charge that runs into a pillar, or a boss slam on one, knocks it over into a rubble
##   wall that blocks movement and shots and crushes whatever is under it. A charge into a pillar stuns the boss.
##   The pillar's stump stays solid where it stood.
## - Crumbling rim: when the Warden changes phase the outer ring of floor cracks (DB.RIM_WARN s of warning) and
##   falls into the void, so the walkable radius shrinks (DB.RIM_STEPS).

var run: Run
var radius := DB.ARENA_R        # walkable radius right now
var warn_r := -1.0              # radius the floor is about to shrink to (-1 = no crack)
var rim_step := 0               # how many rim collapses happened this wave
var pillars: Array = []         # {pos, up, dir, a, b, node, flame}
var vis: Node = null            # Art arena visual (rim ring; null without it)
var _pillar_nodes: Array = []   # from Art.build_world: [{node, flame}] per DB.PILLARS entry
var _flames_mm: MultiMesh
var _obs: Array = []            # obstacles() cache, cleared when the ground changes


func setup(r: Run, world_res: Dictionary) -> void:
	run = r
	_pillar_nodes = world_res.get("pillars", [])
	_flames_mm = world_res.get("flames_mm", null)
	for i in DB.PILLARS.size():
		var pn: Dictionary = _pillar_nodes[i] if i < _pillar_nodes.size() else {}
		pillars.append({"pos": DB.PILLARS[i], "up": true, "dir": Vector3.ZERO, "a": Vector3.ZERO, "b": Vector3.ZERO,
			"node": pn.get("node", null), "flame": int(pn.get("flame", -1)), "flame_xf": Transform3D()})
		if _flames_mm and int(pn.get("flame", -1)) >= 0:
			pillars[i]["flame_xf"] = _flames_mm.get_instance_transform(int(pn["flame"]))
	if Art.has_method("arena_fx"):
		vis = Art.arena_fx(r)


## Back to a whole arena (wave start / end).
func reset() -> void:
	radius = DB.ARENA_R
	warn_r = -1.0
	rim_step = 0
	_obs.clear()
	for i in pillars.size():
		var p: Dictionary = pillars[i]
		if not p["up"]:
			p["up"] = true
			var n = p["node"]
			if n is Node3D and is_instance_valid(n):
				(n as Node3D).basis = Basis()
			if _flames_mm and p["flame"] >= 0:
				_flames_mm.set_instance_transform(p["flame"], p["flame_xf"])
	if vis and vis.has_method("restore"):
		vis.restore()


# ---------------------------------------------------------------- queries
## Is a shot at `p` stopped by a standing pillar or rubble?
func blocks_shot(p: Vector3) -> bool:
	for pl in pillars:
		var c: Vector3 = pl["pos"]
		if pl["up"]:
			if Vector2(p.x - c.x, p.z - c.z).length() < DB.PILLAR_R:
				return true
		elif _rubble_dist(pl, p) < DB.RUBBLE_W:
			return true
	return false


## Something solid (stump, standing pillar, rubble) within `r` of `p`.
func solid_at(p: Vector3, r: float) -> bool:
	for pl in pillars:
		var c: Vector3 = pl["pos"]
		if Vector2(p.x - c.x, p.z - c.z).length() < DB.PILLAR_R + r:
			return true
		if not pl["up"] and _rubble_dist(pl, p) < DB.RUBBLE_W + r:
			return true
	return false


## Circles to steer round: every pillar (or its stump) plus points along each rubble wall. Cached.
func obstacles() -> Array:
	if _obs.is_empty():
		for pl in pillars:
			_obs.append([pl["pos"], DB.PILLAR_R])
			if not pl["up"]:
				var a: Vector3 = pl["a"]
				var b: Vector3 = pl["b"]
				var n := maxi(2, ceili(a.distance_to(b) / 1.6))
				for i in range(1, n + 1):
					_obs.append([a.lerp(b, float(i) / n), DB.RUBBLE_W])
	return _obs


func _rubble_dist(pl: Dictionary, p: Vector3) -> float:
	var c := Run.seg_closest(p, pl["a"], pl["b"])
	return Vector2(p.x - c.x, p.z - c.z).length()


## Push `p` (unit `u`) out of rubble and inside the rim.
func resolve(u: Unit, p: Vector3) -> Vector3:
	for pl in pillars:
		if pl["up"]:
			continue
		var c := Run.seg_closest(p, pl["a"], pl["b"])
		var d := Vector2(p.x - c.x, p.z - c.z)
		var minr := DB.RUBBLE_W + u.radius
		if d.length() < minr:
			if d.length() < 0.001:
				var ab: Vector3 = pl["b"] - pl["a"]
				d = Vector2(-ab.z, ab.x)
			d = d.normalized() * minr
			p.x = c.x + d.x
			p.z = c.z + d.y
	return p


## Index of the standing pillar touching a unit of radius `r` at `p` (within `pad`), or -1.
func pillar_hit(p: Vector3, r: float, pad := 0.6) -> int:
	for i in pillars.size():
		var pl: Dictionary = pillars[i]
		var c: Vector3 = pl["pos"]
		if pl["up"] and Vector2(p.x - c.x, p.z - c.z).length() < DB.PILLAR_R + r + pad:
			return i
	return -1


# ---------------------------------------------------------------- toppling
## Knock pillar `i` over toward `dir`. `by` is the boss that did it (stunned if `stun`).
func topple(i: int, dir: Vector3, by: Unit, stun := false) -> void:
	if i < 0 or i >= pillars.size() or not pillars[i]["up"]:
		return
	var pl: Dictionary = pillars[i]
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
	var c: Vector3 = pl["pos"]
	var length := DB.RUBBLE_LEN
	# don't lay it past the rim
	for k in 8:
		var tip := c + dir * length
		if Vector2(tip.x, tip.z).length() <= radius - 1.0 or length <= 3.0:
			break
		length -= 0.6
	pl["up"] = false
	pl["dir"] = dir
	pl["a"] = c + dir * (DB.PILLAR_R + 0.3)
	pl["b"] = c + dir * length
	_obs.clear()
	if _flames_mm and pl["flame"] >= 0:
		_flames_mm.set_instance_transform(pl["flame"], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -50, 0)))
	var n = pl["node"]
	if n is Node3D and is_instance_valid(n):
		var axis := Vector3.UP.cross(dir).normalized()
		var node3 := n as Node3D
		var tw := run.create_tween()
		tw.tween_method(func(t: float): if is_instance_valid(node3): node3.basis = Basis(axis, t * PI * 0.5), 0.0, 1.0, DB.TOPPLE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	run.fx_timed("telegraph_line", {"from": pl["a"], "to": pl["b"], "width": DB.RUBBLE_W * 2.0, "duration": DB.TOPPLE_TIME}, DB.TOPPLE_TIME)
	run.add_hazard({"type": "line", "from": pl["a"], "to": pl["b"], "width": DB.RUBBLE_W * 2.0 + 0.6, "t": DB.TOPPLE_TIME + 0.1})
	Audio.play("boss")
	run.schedule(DB.TOPPLE_TIME, _land.bind(i, by))
	if stun and by != null and by.alive:
		by.stun_t = maxf(by.stun_t, DB.TOPPLE_STUN)
		run.toast("The pillar falls on %s! Stunned" % (by as Enemy).display_name if by is Enemy else "The pillar falls!", Art.palette.get("gold", Color.GOLD))
	else:
		run.hint_once("topple", "Pillars topple when a boss hits them. Bait the Brute's charge into one: it stuns him.")


func _land(i: int, by: Unit) -> void:
	var pl: Dictionary = pillars[i]
	if pl["up"]:
		return   # rebuilt (wave ended) before it landed
	var a: Vector3 = pl["a"]
	var b: Vector3 = pl["b"]
	run.shake(0.7)
	Audio.play("slam")
	var steps := maxi(2, ceili(a.distance_to(b) / 2.5))
	for k in steps + 1:
		run.fx("slam", {"pos": a.lerp(b, float(k) / steps), "radius": 1.8, "color": Color(0.7, 0.62, 0.55)})
	var reach := DB.RUBBLE_W + 0.4
	for e in run.enemies_in_radius((a + b) * 0.5, a.distance_to(b) * 0.5 + reach + 1.0):
		if _rubble_dist(pl, e.pos) <= reach + e.radius * 0.5:
			if e.is_boss:
				run.damage(e, e.max_hp * DB.CRUSH_BOSS, null, "Falling Pillar", "pure", {"crit": true})
			else:
				run.damage(e, e.max_hp * DB.CRUSH_FOE, null, "Falling Pillar", "pure", {"crit": true})
	for u in run.hero_side_targets():
		if u is Barrel:
			continue
		if _rubble_dist(pl, u.pos) <= reach + u.radius * 0.5:
			if u == run.hero:
				run.damage(u, u.max_hp * DB.CRUSH_HERO, by, "Falling Pillar", "pure")
			else:
				run.damage(u, u.max_hp * 0.5, by, "Falling Pillar", "pure")
	# whatever is still inside the rubble is shoved out to the side
	for e in run.enemies:
		if e.alive:
			e.pos = resolve(e, e.pos)
	if run.hero.alive:
		run.hero.pos = resolve(run.hero, run.hero.pos)
	for al in run.allies:
		if al.alive:
			al.pos = resolve(al, al.pos)
	if run.barrels:
		for br in run.barrels.all:
			if br.alive and _rubble_dist(pl, br.pos) < DB.RUBBLE_W + 0.3:
				run.barrels.smash(br, null)


# ---------------------------------------------------------------- crumbling rim
## Start the next rim collapse (the Warden's phase changes). No-op once every step has fallen.
func crumble() -> void:
	if rim_step >= DB.RIM_STEPS.size() or warn_r > 0.0 or run.phase != "wave":
		return
	warn_r = float(DB.RIM_STEPS[rim_step])
	rim_step += 1
	if vis and vis.has_method("crack"):
		vis.crack(warn_r, radius, DB.RIM_WARN)
	run.banner_requested.emit("The Pit crumbles", "The edge is falling. Get inside!")
	run.shake(0.4)
	Audio.play("boss")
	run.schedule(DB.RIM_WARN, _fall)


func _fall() -> void:
	if warn_r <= 0.0 or run.phase != "wave":
		return
	var old := radius
	radius = warn_r
	warn_r = -1.0
	if vis and vis.has_method("collapse"):
		vis.collapse(radius, old)
	run.shake(0.9)
	Audio.play("slam")
	var edge := radius - 0.3
	# foes on the falling ring go down with it; bosses and the hero side scramble back in
	for e in run.enemies.duplicate():
		if not e.alive:
			continue
		if Vector2(e.pos.x, e.pos.z).length() > edge - e.radius:
			if e.is_boss or e.no_push:
				e.pos = _inside(e.pos, e.radius + 0.8)
			else:
				run.fx("death_burst", {"pos": e.pos, "size": e.radius * 2.0})
				run.kill(e, null)
	var h := run.hero
	if h.alive and not h.dead and Vector2(h.pos.x, h.pos.z).length() > edge - h.radius:
		run.damage(h, h.max_hp * DB.RIM_HERO, null, "Crumbling Rim", "pure")
		run.fx("teleport", {"pos": h.pos})
		h.pos = _inside(h.pos, h.radius + 1.2)
		run.fx("teleport", {"pos": h.pos})
		run.toast("You scramble back from the edge!", Art.palette.get("danger", Color.RED))
	for al in run.allies:
		if al.alive and Vector2(al.pos.x, al.pos.z).length() > edge - al.radius:
			al.pos = _inside(al.pos, al.radius + 0.8)
	if run.barrels:
		for br in run.barrels.all:
			if br.alive and Vector2(br.pos.x, br.pos.z).length() > radius - 0.2:
				run.barrels.drop(br)
	# rubble that now hangs over the void is shortened to what is still on the floor
	for pl in pillars:
		if pl["up"]:
			continue
		var b: Vector3 = pl["b"]
		if Vector2(b.x, b.z).length() > radius - 0.8:
			var a: Vector3 = pl["a"]
			var t := 1.0
			while t > 0.0 and Vector2(a.lerp(b, t).x, a.lerp(b, t).z).length() > radius - 0.8:
				t -= 0.05
			pl["b"] = a.lerp(b, maxf(t, 0.0))


func _inside(p: Vector3, margin: float) -> Vector3:
	var v := Vector2(p.x, p.z)
	if v.length() < 0.01:
		return p
	v = v.normalized() * (radius - margin)
	return Vector3(v.x, 0, v.y)


## Where foes come in: the gate pulled in to the current rim.
func gate_point(g: Vector3) -> Vector3:
	var v := Vector2(g.x, g.z)
	if v.length() > radius - 1.5:
		v = v.normalized() * (radius - 1.5)
	return Vector3(v.x, 0, v.y)


## The radius the bot and AI should keep inside (the crack if one is coming).
func safe_radius() -> float:
	return warn_r if warn_r > 0.0 else radius
