class_name BarrelField
extends Node3D
## Barrel pens and powder kegs in the arena (DB.PENS / DB.KEGS).
## A pen is a ring of barrels with no way in. Smash one (or more) to open a gap: whoever is inside can only be
## reached through it, so the pack queues up and comes in one at a time. Units too wide for the gap smash the
## barrels next to it; a sealed pen gets broken open; bosses crash straight through. Kegs blow up after a short
## fuse, hurting everything nearby (the hero too) and breaking barrels around them.
## Everything is restored at the start of each wave.

const MK := preload("res://art/mesh_kit.gd")
const SH := preload("res://art/shaders.gd")
const WOOD := Color(0.62, 0.42, 0.24)
const KEG_GLOW := Color(1.0, 0.55, 0.15)

var run: Run
var pens: Array = []      # {c, r, n, rot, barrels: Array[Barrel], gaps: Array, gver: int}
var kegs: Array = []
var all: Array = []
var ver := 0              # bumps whenever a barrel breaks or the field resets (gap caches key on it)
var through_pen := -1     # set by waypoint(): the pen the unit is currently passing through

var _mm: MultiMesh
var _kmm: MultiMesh
var _dirty := true
var _t := 0.0


func setup(r: Run) -> void:
	run = r
	name = "Barrels"
	for i in DB.PENS.size():
		var d: Dictionary = DB.PENS[i]
		var pen := {"c": d["c"], "r": float(d["r"]), "n": int(d["n"]), "rot": float(d["rot"]), "barrels": [], "gaps": [], "gver": -1}
		for j in pen["n"]:
			var b := Barrel.new()
			b.run = r
			b.pen = i
			b.slot = j
			b.pos = pen["c"] + _ring_dir(pen, j) * pen["r"]
			b.yaw = randf() * TAU
			pen["barrels"].append(b)
			all.append(b)
		pens.append(pen)
	for p in DB.KEGS:
		var k := Barrel.new()
		k.run = r
		k.keg = true
		k.pos = p
		k.yaw = randf() * TAU
		kegs.append(k)
		all.append(k)
	_build_visuals()
	reset()


func reset() -> void:
	for b in all:
		b.alive = true
		b.lit = false
		b.hp = DB.BARREL_HP
		b.wob = 0.0
	ver += 1
	_dirty = true


static func _ring_dir(pen: Dictionary, j: int) -> Vector3:
	var a: float = pen["rot"] + TAU * j / float(pen["n"])
	return Vector3(cos(a), 0, sin(a))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


# ---------------------------------------------------------------- queries
## Index of the pen whose inside contains p, or -1.
func pen_at(p: Vector3) -> int:
	for i in pens.size():
		if _flat(p - pens[i]["c"]).length() < pens[i]["r"] - 0.1:
			return i
	return -1


func intact(pen_i: int) -> int:
	var n := 0
	for b in pens[pen_i]["barrels"]:
		if b.alive:
			n += 1
	return n


## Openings of a pen: Array of {dir: Vector3 (centre -> middle of the gap), width: float (metres of free space),
## slots: Array[int]}. A pen with every barrel broken is one huge gap.
func gaps(pen_i: int) -> Array:
	var pen: Dictionary = pens[pen_i]
	if pen["gver"] == ver:
		return pen["gaps"]
	var out := []
	var bs: Array = pen["barrels"]
	var n: int = pen["n"]
	var first := -1
	for j in n:
		if bs[j].alive:
			first = j
			break
	if first < 0:
		out.append({"dir": Vector3(0, 0, 1), "width": 99.0, "slots": range(n)})
	else:
		var run_slots := []
		for s in range(1, n + 1):
			var j := (first + s) % n
			if not bs[j].alive:
				run_slots.append(j)
			elif not run_slots.is_empty():
				var k := run_slots.size()
				var mid_a: float = pen["rot"] + TAU * (float(run_slots[0]) + (k - 1) * 0.5) / float(n)
				# past half the ring the opening is as wide as the pen itself
				var chord: float = 2.0 * pen["r"] * sin(minf(PI * float(k + 1) / float(n), PI * 0.5))
				out.append({"dir": Vector3(cos(mid_a), 0, sin(mid_a)), "width": chord - 2.0 * DB.BARREL_R, "slots": run_slots})
				run_slots = []
	pen["gaps"] = out
	pen["gver"] = ver
	return out


## The gap of pen_i that a unit of radius `r` fits through, closest to `from` (by direction). {} if none.
func best_gap(pen_i: int, r: float, from: Vector3) -> Dictionary:
	var pen: Dictionary = pens[pen_i]
	var rel := _flat(from - pen["c"])
	var dir := rel.normalized() if rel.length() > 0.01 else Vector3(0, 0, 1)
	var best := {}
	var bd := -2.0
	for g in gaps(pen_i):
		if g["width"] < 2.0 * r + 0.04:
			continue
		var d: float = dir.dot(g["dir"])
		if d > bd:
			bd = d
			best = g
	return best


## True when a unit of radius `r` walking straight from `a` to `b` would bump an intact barrel of pen_i.
## Broken barrels are gone: a pen with its barrels smashed out of the way doesn't block anything.
func blocks(pen_i: int, a: Vector3, b: Vector3, r: float) -> bool:
	var ab := _flat(b - a)
	var l2 := ab.length_squared()
	var reach := r + DB.BARREL_R + 0.05
	for br in pens[pen_i]["barrels"]:
		if not br.alive:
			continue
		var ap := _flat(br.pos - a)
		var t := clampf(ap.dot(ab) / l2, 0.0, 1.0) if l2 > 0.0001 else 0.0
		if (ap - ab * t).length() < reach:
			return true
	return false


## Where a unit at u.pos should walk next to reach `goal`, threading pen gaps. Sets through_pen.
func waypoint(u: Unit, goal: Vector3) -> Vector3:
	through_pen = -1
	if u.is_boss and u.team == 1:
		return goal   # bosses crash straight through (see _push); threading gaps made them dither on the ring
	for i in pens.size():
		var pen: Dictionary = pens[i]
		var c: Vector3 = pen["c"]
		var r: float = pen["r"]
		var ud := _flat(u.pos - c).length()
		var gd := _flat(goal - c).length()
		var u_in := ud < r - 0.1
		var g_in := gd < r - 0.1
		if u_in == g_in:
			continue
		if not blocks(i, u.pos, goal, u.radius):
			through_pen = i
			return goal
		var outside := goal if u_in else u.pos
		var g := best_gap(i, u.radius, outside)
		if g.is_empty():
			return goal
		var gdir: Vector3 = g["dir"]
		var rel := _flat(u.pos - c)
		var lateral := (rel - gdir * rel.dot(gdir)).length()
		var lined := rel.dot(gdir) > 0.0 and lateral < maxf(0.18, float(g["width"]) * 0.5 - u.radius * 0.6) and absf(ud - r) < 1.9
		var outer := c + gdir * (r + 1.6)
		var inner := c + gdir * (r - 1.0)
		if lined:
			through_pen = i
		if not u_in:
			return inner if lined else outer
		return outer if lined else inner
	return goal


## Static collision against intact barrels. Bosses smash whatever they walk into.
func resolve(u: Unit, p: Vector3) -> Vector3:
	if not u.collides:
		return p
	var reach := u.radius + DB.BARREL_R + 0.05
	for pen in pens:
		var d := _flat(p - pen["c"]).length()
		if absf(d - pen["r"]) > reach:
			continue
		for b in pen["barrels"]:
			if b.alive:
				p = _push(u, p, b)
	for k in kegs:
		if k.alive:
			p = _push(u, p, k)
	return p


func _push(u: Unit, p: Vector3, b: Barrel) -> Vector3:
	var off := _flat(p - b.pos)
	var minr := u.radius + DB.BARREL_R
	var d := off.length()
	if d >= minr:
		return p
	if u.is_boss and u.team == 1:
		smash(b, u)
		return p
	if d < 0.001:
		off = _flat(p - (pens[b.pen]["c"] if b.pen >= 0 else b.pos + Vector3(1, 0, 0)))
		d = maxf(off.length(), 0.001)
	var q := b.pos + off / d * minr
	return Vector3(q.x, 0, q.z)


## Intact barrel nearest to p within max_d (ground distance to its edge). Kegs included.
func barrel_near(p: Vector3, max_d: float) -> Barrel:
	var best: Barrel = null
	var bd := max_d
	for b in all:
		if not b.alive:
			continue
		var d := _flat(b.pos - p).length() - DB.BARREL_R
		if d < bd:
			bd = d
			best = b
	return best


## For an enemy whose target sits inside a pen it can't get into (no gap wide enough), the barrel to break.
## Returns `t` unchanged when the way in is open (or the unit doesn't walk through barrels).
func detour(e: Unit, t: Unit) -> Unit:
	if t == null or t is Barrel or not e.collides or e.is_boss:
		return t
	var pi := pen_at(t.pos)
	if pi < 0 or pen_at(e.pos) == pi:
		return t
	if not best_gap(pi, e.radius, e.pos).is_empty():
		return t
	# widen the nearest (too narrow) opening, or break in where we stand
	var aim := e.pos
	var gs := gaps(pi)
	if not gs.is_empty():
		var rel := _flat(e.pos - pens[pi]["c"]).normalized()
		var bd := -2.0
		for g in gs:
			if rel.dot(g["dir"]) > bd:
				bd = rel.dot(g["dir"])
				aim = pens[pi]["c"] + g["dir"] * pens[pi]["r"]
	var best: Barrel = null
	var bdist := 1e9
	for b in pens[pi]["barrels"]:
		if b.alive:
			var d := _flat(b.pos - aim).length()
			if d < bdist:
				bdist = d
				best = b
	return best if best != null else t


# ---------------------------------------------------------------- damage
func hit(b: Barrel, src: Unit) -> float:
	if not b.alive:
		return 0.0
	var dmg := 1.0
	if src != null and src == run.hero:
		dmg = DB.BARREL_HERO_HIT
	elif src is Enemy and ((src as Enemy).kind in ["shieldbearer", "bloater"] or (src as Enemy).elite != ""):
		dmg = 2.0
	b.hp -= dmg
	b.wob = 0.3
	_dirty = true
	run.fx("hit", {"pos": b.pos + Vector3(0, 0.6, 0), "color": KEG_GLOW if b.keg else WOOD})
	if b.hp <= 0.0:
		smash(b, src)
	return dmg


func smash(b: Barrel, _src: Unit = null, fuse := DB.KEG_FUSE) -> void:
	if not b.alive:
		return
	b.alive = false
	b.hp = 0.0
	ver += 1
	_dirty = true
	if run.hero.focus == b:
		run.hero.focus = null
	if run.hero.atk_target == b:
		run.hero.atk_target = null
	run.fx("death_burst", {"pos": b.pos, "size": 1.1, "color": WOOD})
	Audio.play("hit")
	if b.keg:
		b.lit = true
		run.fx_timed("telegraph_circle", {"pos": b.pos, "radius": DB.KEG_RADIUS, "duration": fuse, "color": KEG_GLOW}, fuse)
		run.add_hazard({"type": "circle", "pos": b.pos, "r": DB.KEG_RADIUS, "t": fuse + 0.1})
		run.schedule(fuse, _explode.bind(b))
		run.hint_once("keg", "Powder keg! It blows up everything around it. Step back!")


func _explode(b: Barrel) -> void:
	if not b.lit:
		return
	b.lit = false
	_dirty = true
	if not run.in_arena():
		return
	var p := b.pos
	var r := DB.KEG_RADIUS
	run.fx("death_burst", {"pos": p, "size": r * 2.0, "color": KEG_GLOW})
	run.fx("slam", {"pos": p, "radius": r})
	run.shake(0.55)
	Audio.play("boss")
	for e in run.enemies.duplicate():
		if e.alive and not e.untargetable and _flat(e.pos - p).length() <= r + e.radius:
			var amt: float = e.max_hp * (0.04 if e.is_boss else 0.5) + 60.0 * DB.dmg_mult(run.wave)
			run.damage(e, amt, run.hero, "Powder Keg", "magic", {"color": KEG_GLOW})
	for u in run.hero_side_targets():
		if _flat(u.pos - p).length() <= r + u.radius * 0.5:
			run.damage(u, u.max_hp * 0.22, null, "Powder Keg", "magic")
	for o in all:
		if o.alive and _flat(o.pos - p).length() <= r:
			smash(o, null, DB.KEG_CHAIN_FUSE)


# ---------------------------------------------------------------- visuals
func _build_visuals() -> void:
	_mm = _make_mm(_barrel_mesh(false), all.size() - kegs.size(), "BarrelMesh")
	_kmm = _make_mm(_barrel_mesh(true), kegs.size(), "KegMesh")
	var n := 0
	var nk := 0
	for b in all:
		if b.keg:
			b.idx = nk
			nk += 1
		else:
			b.idx = n
			n += 1


func _make_mm(mesh: Mesh, count: int, nm: String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = SH.mat("world")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-25, -2, -25), Vector3(50, 6, 50))
	add_child(mmi)
	return mm


static func _barrel_mesh(keg: bool) -> Mesh:
	var k := MK.new()
	var wood := Color("6e2a1e") if keg else Color("7a5232")
	var wood_d := Color("3e1a14") if keg else Color("4e3220")
	var band := Color("a8743c") if keg else Color("2e2a2a")
	k.cur_aux = 0.0
	k.cyl(0.45, 0.39, 0.47, Vector3(0, 0.235, 0), wood, Vector3.ZERO, -1, 10, false)
	k.cyl(0.39, 0.45, 0.47, Vector3(0, 0.705, 0), wood, Vector3.ZERO, -1, 10, false)
	k.cyl(0.39, 0.39, 0.04, Vector3(0, 0.95, 0), wood_d, Vector3.ZERO, -1, 10)
	for y in [0.16, 0.8]:
		k.torus(0.4, 0.45, Vector3(0, y, 0), band, Vector3.ZERO, -1, 10, 3)
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		k.box(Vector3(0.035, 0.86, 0.03), Vector3(cos(a) * 0.445, 0.47, sin(a) * 0.445), wood_d, Vector3(0, -rad_to_deg(a), 0))
	if keg:
		k.torus(0.42, 0.47, Vector3(0, 0.47, 0), Color("ff7a2f"), Vector3.ZERO, 2.2, 10, 3)
		for s in [-1.0, 1.0]:
			k.box(Vector3(0.06, 0.34, 0.04), Vector3(0, 0.62, -0.455), Color("ffb040"), Vector3(0, 0, s * 40.0), 1.8)
		k.cyl(0.03, 0.03, 0.22, Vector3(0.12, 1.06, 0), Color("2a1a10"), Vector3(0, 0, -20))
		k.ball(0.06, Vector3(0.16, 1.17, 0), Color("ffcf6a"), Vector3.ONE, Vector3.ZERO, 3.0, 6, 4)
	k.cur_aux = 1.0
	return k.build()


func _process(dt: float) -> void:
	_t += dt
	var any_lit := false
	for b in all:
		if b.wob > 0.0:
			b.wob = maxf(0.0, b.wob - dt)
			_dirty = true
		if b.lit:
			any_lit = true
	if not _dirty and not any_lit:
		return
	_dirty = false
	for b in all:
		var mm := _kmm if b.keg else _mm
		var xf: Transform3D
		if b.alive or b.lit:
			var basis := Basis(Vector3.UP, b.yaw)
			if b.wob > 0.0:
				var w := sin(b.wob / 0.3 * PI) * 0.22
				basis = Basis(Vector3(1, 0, 0), w) * basis
			var s := 1.0
			if b.lit:
				s = 1.0 + 0.08 * sin(_t * 30.0)
			elif b.hp < DB.BARREL_HP:
				basis = Basis(Vector3(0, 0, 1), 0.08) * basis   # cracked: leans a little
			xf = Transform3D(basis.scaled(Vector3(s, s, s)), b.pos)
		else:
			xf = Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), Vector3(b.pos.x, -20.0, b.pos.z))
		mm.set_instance_transform(b.idx, xf)
