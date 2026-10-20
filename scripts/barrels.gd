class_name BarrelField
extends Node3D
## Barrel stacks and powder kegs in the arena (DB.STACKS / DB.KEGS), laid out like Life in Arena.
## A stack is a solid block of barrels on a square grid filling a corner of the arena. Smash your way in to dig a
## corridor and fight from the end of it: foes follow the corridor single file, so only the front one reaches you.
## Foes path over the same grid (A*): a sealed corridor costs them a barrel to break, so they smash in; wide foes
## don't fit a one-barrel corridor and chew it wider; bosses crash straight through. Kegs blow up after a short fuse,
## hurting everything nearby (the hero too) and breaking barrels around them.
## Everything is restored at the start of each wave.

const MK := preload("res://art/mesh_kit.gd")
const SH := preload("res://art/shaders.gd")
const WOOD := Color(0.62, 0.42, 0.24)
const KEG_GLOW := Color(1.0, 0.55, 0.15)
const N := 39                  # grid cells per side (N * BARREL_GRID covers the arena)
const ORIGIN := -22.0
const WIDE_R := 0.58           # foes wider than this (Shieldbearers, Bloaters, big elites) don't fit a corridor:
const WIDE_PAD := 0.15         # they bump barrels as if this much wider
const NARROW_COST := 30.0      # path cost of a barrel cell: breaking one is worth a long walk round
const WIDE_COST := 4.0         # wide foes smash through rather than squeeze
const DIG_DEPTH := 4           # barrels the bot digs into a stack

var run: Run
## Stack: {sx, sz, t, cells: Array[Vector2i], lane: Array[Vector2i] (a row from the face to the wall),
## front: Vector3 (just outside lane[0]), step: Vector2i (dig direction)}.
var stacks: Array = []
var kegs: Array = []
var all: Array = []
var ver := 0              # bumps whenever a barrel breaks or the field resets (path caches key on it)

var _grid: Array = []     # N * N: Barrel or null
var _astar: AStarGrid2D   # regular foes, the hero side
var _astar_w: AStarGrid2D # wide foes
var _paths := {}          # unit instance id -> {cells, i, t, ver, goal}
var _bump := {}           # unit instance id -> [Barrel, run_time]: last barrel a foe walked into
var _mm: MultiMesh
var _kmm: MultiMesh
var _dirty := true
var _t := 0.0


func setup(r: Run) -> void:
	run = r
	name = "Barrels"
	_grid.resize(N * N)
	for si in DB.STACKS.size():
		var d: Dictionary = DB.STACKS[si]
		var st := {"sx": int(d["sx"]), "sz": int(d["sz"]), "t": float(d["t"]), "cells": [], "lane": []}
		for j in N:
			for i in N:
				var c := cell_pos(Vector2i(i, j))
				if st["sx"] * c.x >= st["t"] and st["sz"] * c.z >= st["t"] and Vector2(c.x, c.z).length() <= DB.STACK_R:
					_add(Vector2i(i, j), si, false)
					st["cells"].append(Vector2i(i, j))
		for kp in d.get("kegs", []):
			var kc := cell_of(kp)
			if _grid[_idx(kc)] != null:
				_grid[_idx(kc)].keg = true
		_make_lane(st)
		stacks.append(st)
	for kp in DB.KEGS:
		var kc := cell_of(kp)
		if _grid[_idx(kc)] == null:
			_add(kc, -1, true)
	for b in all:
		if b.keg:
			kegs.append(b)
	_astar = _make_astar()
	_astar_w = _make_astar()
	_build_visuals()
	reset()


func _add(c: Vector2i, si: int, keg: bool) -> void:
	var b := Barrel.new()
	b.run = run
	b.pen = si
	b.slot = _idx(c)
	b.keg = keg
	b.pos = cell_pos(c)
	b.yaw = randf() * TAU
	_grid[_idx(c)] = b
	all.append(b)


## The dig lane: a row of cells from the middle of the stack's x face, straight in towards the wall.
func _make_lane(st: Dictionary) -> void:
	var t: float = st["t"]
	var face_len := sqrt(DB.STACK_R * DB.STACK_R - t * t) - t
	var z := float(st["sz"]) * (t + face_len * 0.45)
	var x := float(st["sx"]) * (t + DB.BARREL_GRID * 0.5)
	var c := cell_of(Vector3(x, 0, z))
	var step := Vector2i(int(st["sx"]), 0)
	# start at the first barrel of the row
	while not _in_grid(c) or _grid[_idx(c)] == null or _grid[_idx(c)].pen < 0:
		c += step
		if not _in_grid(c):
			return
	var lane := []
	while _in_grid(c) and _grid[_idx(c)] != null:
		lane.append(c)
		c += step
	st["lane"] = lane
	st["step"] = step
	st["front"] = cell_pos(lane[0] - step)


func _make_astar() -> AStarGrid2D:
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, N, N)
	a.cell_size = Vector2(DB.BARREL_GRID, DB.BARREL_GRID)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	a.update()
	for j in N:
		for i in N:
			var c := Vector2i(i, j)
			var p := cell_pos(c)
			var solid := Vector2(p.x, p.z).length() > DB.ARENA_R - 0.5 and _grid[_idx(c)] == null
			for pl in DB.PILLARS:
				if _flat(p - pl).length() < DB.PILLAR_R + 0.25:
					solid = true
			if solid:
				a.set_point_solid(c, true)
	return a


func reset() -> void:
	for b in all:
		b.alive = true
		b.lit = false
		b.hp = DB.BARREL_HP
		b.wob = 0.0
		_set_cost(b)
	ver += 1
	_paths.clear()
	_bump.clear()
	_dirty = true


func _set_cost(b: Barrel) -> void:
	var c := _cell2(b.slot)
	if _astar == null or _astar.is_point_solid(c):
		return
	_astar.set_point_weight_scale(c, NARROW_COST if b.alive else 1.0)
	_astar_w.set_point_weight_scale(c, WIDE_COST if b.alive else 1.0)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


# ---------------------------------------------------------------- grid
static func _idx(c: Vector2i) -> int:
	return c.y * N + c.x


static func _cell2(i: int) -> Vector2i:
	return Vector2i(i % N, i / N)


static func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - ORIGIN) / DB.BARREL_GRID), floori((p.z - ORIGIN) / DB.BARREL_GRID))


static func cell_pos(c: Vector2i) -> Vector3:
	return Vector3(ORIGIN + DB.BARREL_GRID * (c.x + 0.5), 0, ORIGIN + DB.BARREL_GRID * (c.y + 0.5))


## The intact barrel (or keg) in cell c, or null.
func barrel_at(c: Vector2i) -> Barrel:
	if not _in_grid(c):
		return null
	var b = _grid[_idx(c)]
	return b if b != null and b.alive else null


## How many of the four cells around p hold an intact barrel (4 = sealed in, 3 = the end of a corridor).
func cover(p: Vector3) -> int:
	var c := cell_of(p)
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if barrel_at(c + d) != null:
			n += 1
	return n


func intact(si: int) -> int:
	var n := 0
	for c in stacks[si]["cells"]:
		if barrel_at(c) != null:
			n += 1
	return n


# ---------------------------------------------------------------- queries
## True when a unit of radius r can walk straight from a to b without bumping an intact barrel
## (barrels right at b don't count: that's where it's going).
func clear_line(a: Vector3, b: Vector3, r: float) -> bool:
	var ab := _flat(b - a)
	var len := ab.length()
	if len < 0.01:
		return true
	var reach := r + DB.BARREL_R - 0.02
	# only sample where the segment crosses a stack's box (or passes a loose keg)
	var t0 := 1.0
	var t1 := 0.0
	for st in stacks:
		var lo := Vector2(minf(st["sx"] * st["t"], st["sx"] * 22.0), minf(st["sz"] * st["t"], st["sz"] * 22.0)) - Vector2(1.2, 1.2)
		var hi := Vector2(maxf(st["sx"] * st["t"], st["sx"] * 22.0), maxf(st["sz"] * st["t"], st["sz"] * 22.0)) + Vector2(1.2, 1.2)
		var span := _clip(Vector2(a.x, a.z), Vector2(ab.x, ab.z), lo, hi)
		if span.x <= span.y:
			t0 = minf(t0, span.x)
			t1 = maxf(t1, span.y)
	for k in kegs:
		if k.alive and k.pen < 0 and _flat(k.pos - b).length() > 0.9:
			var tk := clampf(_flat(k.pos - a).dot(ab) / (len * len), 0.0, 1.0)
			if _flat(a + ab * tk - k.pos).length() < reach:
				return false
	if t0 > t1:
		return true
	var steps := maxi(1, ceili((t1 - t0) * len / 0.35))
	for s in steps + 1:
		var q := a + ab * lerpf(t0, t1, float(s) / steps)
		var c := cell_of(q)
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var br := barrel_at(c + Vector2i(di, dj))
				if br != null and _flat(br.pos - q).length() < reach and _flat(br.pos - b).length() > 0.9:
					return false
	return true


## Parametric span [t0, t1] of segment o + d*t (t in 0..1) inside the box lo..hi; t0 > t1 when it misses.
static func _clip(o: Vector2, d: Vector2, lo: Vector2, hi: Vector2) -> Vector2:
	var t0 := 0.0
	var t1 := 1.0
	for ax in 2:
		var oo := o.x if ax == 0 else o.y
		var dd := d.x if ax == 0 else d.y
		var l := lo.x if ax == 0 else lo.y
		var h := hi.x if ax == 0 else hi.y
		if absf(dd) < 0.00001:
			if oo < l or oo > h:
				return Vector2(1, 0)
		else:
			var ta := (l - oo) / dd
			var tb := (h - oo) / dd
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
	return Vector2(t0, t1)


## Where a unit at u.pos should walk next to reach `goal`: straight there when nothing is in the way, else along the
## barrel grid (through dug corridors, or up to the barrel it has to break).
func waypoint(u: Unit, goal: Vector3) -> Vector3:
	if u.is_boss and u.team == 1:
		return goal   # bosses crash straight through (see _push)
	var id := u.get_instance_id()
	if clear_line(u.pos, goal, u.radius):
		_paths.erase(id)
		return goal
	var gc := cell_of(goal)
	var pd: Dictionary = _paths.get(id, {})
	if pd.is_empty() or pd["ver"] != ver or pd["goal"] != gc or run.run_time - float(pd["t"]) > 0.6:
		var a := _astar_w if u.radius > WIDE_R else _astar
		var from := cell_of(u.pos)
		if not _in_grid(from) or not _in_grid(gc):
			return goal
		var cells := a.get_id_path(from, gc, true)
		pd = {"cells": cells, "i": 1, "t": run.run_time, "ver": ver, "goal": gc}
		_paths[id] = pd
	var cells: Array[Vector2i] = pd["cells"]
	if cells.size() < 2:
		return goal
	var i: int = pd["i"]
	while i < cells.size() - 1 and _flat(cell_pos(cells[i]) - u.pos).length() < 0.45:
		i += 1
	pd["i"] = i
	return goal if i >= cells.size() - 1 else cell_pos(cells[i])


## Static collision against intact barrels. Bosses smash whatever they walk into.
func resolve(u: Unit, p: Vector3) -> Vector3:
	if not u.collides:
		return p
	var c := cell_of(p)
	var ur := u.radius + (WIDE_PAD if u.team == 1 and u.radius > WIDE_R else 0.0)
	var k := ceili((ur + DB.BARREL_R) / DB.BARREL_GRID)
	for dj in range(-k, k + 1):
		for di in range(-k, k + 1):
			var b := barrel_at(c + Vector2i(di, dj))
			if b != null:
				p = _push(u, p, b, ur)
	return p


func _push(u: Unit, p: Vector3, b: Barrel, ur: float) -> Vector3:
	var off := _flat(p - b.pos)
	var minr := ur + DB.BARREL_R
	var d := off.length()
	if d >= minr:
		return p
	if u.is_boss and u.team == 1:
		smash(b, u)
		return p
	if u.team == 1:
		_bump[u.get_instance_id()] = [b, run.run_time]
	if d < 0.001:
		off = Vector3(1, 0, 0)
		d = 1.0
	var q := b.pos + off / d * minr
	return Vector3(q.x, 0, q.z)


## Intact barrel nearest to p within max_d (ground distance to its edge). Kegs included.
func barrel_near(p: Vector3, max_d: float) -> Barrel:
	var best: Barrel = null
	var bd := max_d
	var c := cell_of(p)
	var k := ceili((max_d + DB.BARREL_R) / DB.BARREL_GRID)
	for dj in range(-k, k + 1):
		for di in range(-k, k + 1):
			var b := barrel_at(c + Vector2i(di, dj))
			if b == null:
				continue
			var d := _flat(b.pos - p).length() - DB.BARREL_R
			if d < bd:
				bd = d
				best = b
	return best


## The barrel a foe has to break on its way to `t`: the next cell of its path when that's a barrel (a sealed way in),
## or, for foes too wide for the corridor, the barrel it keeps walking into. Otherwise `t` unchanged.
func detour(e: Unit, t: Unit) -> Unit:
	if t == null or t is Barrel or not e.collides or e.is_boss:
		return t
	var id := e.get_instance_id()
	# a wide foe finishes the barrel it started on
	if e.radius > WIDE_R and e is Enemy and (e as Enemy).target is Barrel and (e as Enemy).target.alive and e.edge_dist((e as Enemy).target) < 0.5:
		return (e as Enemy).target
	if e.radius > WIDE_R and _bump.has(id):
		var bb: Array = _bump[id]
		if bb[0].alive and run.run_time - float(bb[1]) < 0.5:
			return bb[0]
	var pd: Dictionary = _paths.get(id, {})
	if pd.is_empty() or pd["ver"] != ver:
		return t
	var cells: Array[Vector2i] = pd["cells"]
	var i: int = pd["i"]
	for j in range(i, mini(i + 2, cells.size())):
		var b := barrel_at(cells[j])
		if b != null and e.edge_dist(b) < 1.6:
			return b
	return t


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
	_set_cost(b)
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
