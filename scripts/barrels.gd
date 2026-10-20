class_name BarrelField
extends Node3D
## Barrel nooks and powder kegs in the arena (DB.PENS / DB.KEGS), laid out like Life in Arena.
## A nook ("pen" in code) is a pocket against the arena wall, sealed by a chain of barrels: an end wall running in
## from the arena wall, a front row, and another end wall back out. Smash one (or more) to dig in: whoever is inside
## can only be reached through the hole, so the pack queues up and comes in one at a time. Units too wide for the hole
## smash the barrels next to it; a sealed nook gets broken open; bosses crash straight through. Kegs blow up after a
## short fuse, hurting everything nearby (the hero too) and breaking barrels around them.
## Everything is restored at the start of each wave.

const MK := preload("res://art/mesh_kit.gd")
const SH := preload("res://art/shaders.gd")
const WOOD := Color(0.62, 0.42, 0.24)
const KEG_GLOW := Color(1.0, 0.55, 0.15)

## Pen: {a0, a1 (angle span, radians), r_in, c (middle of the pocket), r (bounding radius), n, mid_slot (front-row
## barrel facing the arena centre), ends: [wall point at a0, wall point at a1], barrels: Array[Barrel] in chain order,
## gaps, gver}.
var pens: Array = []
var run: Run
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
		var pen := make_pen(DB.PENS[i])
		for j in pen["slots"].size():
			var b := Barrel.new()
			b.run = r
			b.pen = i
			b.slot = j
			b.pos = pen["slots"][j]
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


## Geometry of one nook from its DB.PENS entry. Barrel spots go in chain order: end wall a0 (wall inwards),
## front row (a0 -> a1), end wall a1 (outwards to the wall).
static func make_pen(d: Dictionary) -> Dictionary:
	var r_in: float = d.get("r_in", DB.PEN_R_IN)
	var arc: int = d.get("arc", DB.PEN_ARC)
	var am := deg_to_rad(float(d["a"]))
	var half := arc * DB.PEN_SPACING / r_in * 0.5
	var a0 := am - half
	var a1 := am + half
	var m := ceili((DB.PEN_R_OUT - r_in) / 1.05)
	var slots := []
	for k in range(m, 0, -1):
		slots.append(_polar(a0, r_in + (DB.PEN_R_OUT - r_in) * k / float(m)))
	for j in arc + 1:
		slots.append(_polar(lerpf(a0, a1, j / float(arc)), r_in))
	for k in range(1, m + 1):
		slots.append(_polar(a1, r_in + (DB.PEN_R_OUT - r_in) * k / float(m)))
	# the arena wall closes the chain: units can't get between the last barrel and it
	var wall_r := DB.ARENA_R - 0.3 + DB.BARREL_R
	var c_r := (r_in + DB.ARENA_R - 0.3) * 0.5
	var c := _polar(am, c_r)
	var br := 0.0
	for p in slots:
		br = maxf(br, _flat(p - c).length())
	return {"a0": a0, "a1": a1, "am": am, "r_in": r_in, "c": c, "r": br, "n": slots.size(), "mid_slot": m + arc / 2,
		"ends": [_polar(a0, wall_r), _polar(a1, wall_r)], "slots": slots, "barrels": [], "gaps": [], "gver": -1}


static func _polar(a: float, r: float) -> Vector3:
	return Vector3(cos(a) * r, 0, sin(a) * r)


func reset() -> void:
	for b in all:
		b.alive = true
		b.lit = false
		b.hp = DB.BARREL_HP
		b.wob = 0.0
	ver += 1
	_dirty = true


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


# ---------------------------------------------------------------- queries
## True when p is inside pen (behind the front row, between the end walls).
static func inside(pen: Dictionary, p: Vector3) -> bool:
	var rr := Vector2(p.x, p.z).length()
	if rr < pen["r_in"] + 0.1:
		return false
	var d := absf(wrapf(atan2(p.z, p.x) - pen["am"], -PI, PI))
	return d * rr < (pen["a1"] - pen["am"]) * rr - 0.1


## Index of the pen whose inside contains p, or -1.
func pen_at(p: Vector3) -> int:
	for i in pens.size():
		if inside(pens[i], p):
			return i
	return -1


func intact(pen_i: int) -> int:
	var n := 0
	for b in pens[pen_i]["barrels"]:
		if b.alive:
			n += 1
	return n


## Openings of a pen: Array of {p: Vector3 (middle of the hole), dir: Vector3 (outward normal through the hole),
## width: float (metres of free space), slots: Array[int]}. A pen with every barrel broken is one huge gap.
func gaps(pen_i: int) -> Array:
	var pen: Dictionary = pens[pen_i]
	if pen["gver"] == ver:
		return pen["gaps"]
	var out := []
	var bs: Array = pen["barrels"]
	var n: int = pen["n"]
	if intact(pen_i) == 0:
		out.append({"p": _polar(pen["am"], pen["r_in"]), "dir": -_polar(pen["am"], 1.0), "width": 99.0, "slots": range(n)})
	else:
		var j := 0
		while j < n:
			if bs[j].alive:
				j += 1
				continue
			var k := j
			while k + 1 < n and not bs[k + 1].alive:
				k += 1
			var before: Vector3 = bs[j - 1].pos if j > 0 else pen["ends"][0]
			var after: Vector3 = bs[k + 1].pos if k + 1 < n else pen["ends"][1]
			var mid := (before + after) * 0.5
			var t := _flat(after - before).normalized()
			var nrm := Vector3(t.z, 0, -t.x)
			if nrm.dot(mid - pen["c"]) < 0.0:
				nrm = -nrm
			out.append({"p": mid, "dir": nrm, "width": _flat(after - before).length() - 2.0 * DB.BARREL_R, "slots": range(j, k + 1)})
			j = k + 1
	pen["gaps"] = out
	pen["gver"] = ver
	return out


## The gap of pen_i that a unit of radius `r` fits through, closest to `from`. {} if none.
func best_gap(pen_i: int, r: float, from: Vector3) -> Dictionary:
	var best := {}
	var bd := 1e9
	for g in gaps(pen_i):
		if g["width"] < 2.0 * r + 0.04:
			continue
		var d := _flat(g["p"] + g["dir"] * 1.6 - from).length()
		if d < bd:
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
		var u_in := inside(pen, u.pos)
		var g_in := inside(pen, goal)
		if u_in == g_in:
			continue
		if not blocks(i, u.pos, goal, u.radius):
			through_pen = i
			return goal
		var outside := goal if u_in else u.pos
		var g := best_gap(i, u.radius, outside)
		if g.is_empty():
			return goal
		var gp: Vector3 = g["p"]
		var gdir: Vector3 = g["dir"]
		var rel := _flat(u.pos - gp)
		var along := rel.dot(gdir)
		var lateral := (rel - gdir * along).length()
		var lined := lateral < maxf(0.18, float(g["width"]) * 0.5 - u.radius * 0.6) and absf(along) < 1.9
		var outer := gp + gdir * 1.6
		var inner := gp - gdir * 1.0
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
		if _flat(p - pen["c"]).length() > pen["r"] + reach:
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
	var bd := 1e9
	for g in gaps(pi):
		var d := _flat(g["p"] - e.pos).length()
		if d < bd:
			bd = d
			aim = g["p"]
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
