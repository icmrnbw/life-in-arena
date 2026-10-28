class_name Delve
extends Node3D
## Delve mode (experimental, Diablo style). Instead of waves pouring into the Pit, each "wave" is a depth of the
## Undercroft: rooms and corridors generated from the run's seed. Foes wait in packs (dormant) and wake when the hero
## comes close with a clear view, or hits one of them. The depth is cleared when its guardian falls: a wave captain,
## or a boss on depths 3, 6 and 10. The guardian appears when the hero steps into the last room (the lair).
## Ember wells heal once; chests hold gold. The camp and shop between depths work as in the arena modes.
##
## A depth is fought at run.wave = 2 * depth (Run.wave_step is 2), so enemy stats, the shop, Training upgrades and
## captains scale exactly as in Classic. Its foes are the two waves' worth (2d-1 and 2d) times SHARE, with rewards
## raised to match. Walls are a grid of CELL squares: resolve() keeps units out of them, waypoint() paths round them
## (AStarGrid2D), blocks_shot() stops projectiles. The whole level sits at z < 30 (the camp is z > 30).

const CELL := 2.0
const W := 80
const H := 96
const ORIGIN := Vector3(-80.0, 0, -170.0)   # world corner of cell (0, 0); the grid ends at z = 22
const DEPTHS := 10
const SHARE := 0.6               # share of the two waves' foes that is placed in a depth
const REWARD := 1.0 / SHARE      # gold / xp per foe, so a depth pays like two Classic waves
const AGGRO_R := 11.0            # a dormant pack wakes when the hero is this close with a clear line of sight
const AGGRO_NEAR := 5.0          # ... or this close through anything
const BOSSES := {6: "pit_brute", 12: "matron", 20: "hollow_choir"}   # by run.wave (depth 3, 6, 10)
const BOSS_HOME := {"pit_brute": 5, "matron": 10, "hollow_choir": 15}
const WELL_HEAL := 0.6           # share of max HP and mana an ember well restores
const NAMES := ["The Cellars", "The Ossuary", "The Sunken Halls", "The Rat Warrens", "The Ember Vaults",
	"The Drowned Crypt", "The Iron Galleries", "The Bone Choir", "The Hollow Deep", "The Heart of the Undercroft"]

var run: Run
var active := false              # a depth is built (wave phase)
var depth := 1
var wave := 2
var solid := PackedByteArray()   # W * H, 1 = rock
var seen := PackedByteArray()    # W * H, 1 = revealed on the minimap
var rooms: Array = []            # {rect: Rect2i, kind: "start" | "room" | "side" | "lair"}
var packs: Array = []            # {units: Array[Enemy], awake: bool}
var lair := Rect2i()
var lair_open := false
var guardians: Array = []
var wells: Array = []            # {pos, used, node}
var chests: Array = []           # {pos, opened, gold, node}
var start_pos := Vector3.ZERO
var lair_pos := Vector3.ZERO
var cleared := false
var vis: Node3D = null
var astar: AStarGrid2D
var _paths := {}                 # unit instance id -> {cells, i, t, goal}
var _corr := {}                  # corridor cells (no pillars there)
var _t := 0.0
var _seen_t := 0.0


func setup(r: Run) -> void:
	run = r
	name = "Delve"


static func depth_of(w: int) -> int:
	return clampi(w / 2, 1, DEPTHS)


static func depth_name(w: int) -> String:
	return NAMES[clampi(depth_of(w) - 1, 0, NAMES.size() - 1)]


static func boss_kind(w: int) -> String:
	return BOSSES.get(w, "")


static func boss_title(w: int) -> String:
	var bk := boss_kind(w)
	return DB.BOSS_TITLES.get(BOSS_HOME.get(bk, 0), "") if bk != "" else ""


## What the camp preview and banners show for the depth fought at run.wave = w.
static func info(w: int) -> Dictionary:
	var d := depth_of(w)
	var bk := boss_kind(w)
	var cap: String = DB.wave_info(w).get("captain", "gnawer")
	var desc := "Find the lair and slay %s. Foes sleep in packs until you come close." % (boss_title(w) if bk != "" else DB.CAPTAIN_NAMES.get(cap, "the captain"))
	return {"name": "Depth %d · %s" % [d, depth_name(w)], "captain": "" if bk != "" else cap,
		"rule": "", "mods": {}, "desc": desc}


# ---------------------------------------------------------------- grid
static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - ORIGIN.x) / CELL), floori((p.z - ORIGIN.z) / CELL))


static func cell_pos(c: Vector2i) -> Vector3:
	return Vector3(ORIGIN.x + (c.x + 0.5) * CELL, 0, ORIGIN.z + (c.y + 0.5) * CELL)


static func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func is_solid(c: Vector2i) -> bool:
	return not in_grid(c) or solid[c.y * W + c.x] == 1


func walkable(p: Vector3) -> bool:
	return not is_solid(cell_of(p))


## A projectile at p hits a wall.
func blocks_shot(p: Vector3) -> bool:
	return active and is_solid(cell_of(p))


## Clear straight line between two points (cells sampled every half cell).
func los(a: Vector3, b: Vector3) -> bool:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var n := maxi(1, ceili(d.length() / (CELL * 0.5)))
	for i in range(1, n):
		if is_solid(cell_of(a + d * (float(i) / n))):
			return false
	return true


## Keeps a unit's circle out of rock: pushed out of the walls round it, or back onto the nearest floor if it ended
## up inside one (a blink or knockback into a wall).
func resolve(u: Unit, p: Vector3) -> Vector3:
	p.y = 0.0
	var c := cell_of(p)
	if is_solid(c):
		p = _nearest_open(p)
		c = cell_of(p)
	var r := u.radius if u != null else 0.5
	for it in 2:
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var cc := c + Vector2i(di, dj)
				if not is_solid(cc):
					continue
				var lo := Vector2(ORIGIN.x + cc.x * CELL, ORIGIN.z + cc.y * CELL)
				var q := Vector2(clampf(p.x, lo.x, lo.x + CELL), clampf(p.z, lo.y, lo.y + CELL))
				var off := Vector2(p.x, p.z) - q
				var dl := off.length()
				if dl < r:
					if dl < 0.001:
						off = Vector2(p.x, p.z) - (lo + Vector2(CELL, CELL) * 0.5)
						dl = maxf(off.length(), 0.001)
					var push := off / dl * (r - dl + 0.01)
					p.x += push.x
					p.z += push.y
	return p


func _nearest_open(p: Vector3) -> Vector3:
	var c := cell_of(p)
	for ring in range(1, 8):
		var best := Vector3.ZERO
		var bd := 1e9
		for dj in range(-ring, ring + 1):
			for di in range(-ring, ring + 1):
				if maxi(absi(di), absi(dj)) != ring:
					continue
				var cc := c + Vector2i(di, dj)
				if is_solid(cc):
					continue
				var cp := cell_pos(cc)
				var d := Vector2(cp.x - p.x, cp.z - p.z).length()
				if d < bd:
					bd = d
					best = cp
		if bd < 1e9:
			return best
	return start_pos


## Next point to walk to on the way to `goal`: the goal itself with a clear line, else the next cell of an A* path.
func waypoint(u: Unit, goal: Vector3) -> Vector3:
	if not active:
		return goal
	var id := u.get_instance_id()
	var pd: Dictionary = _paths.get(id, {})
	var gc := cell_of(goal)
	if pd.is_empty() or run.run_time - float(pd["t"]) > 0.5 or (pd["goal"] as Vector2i).distance_to(gc) > 1.5:
		if los(u.pos, goal) and _wide_clear(u.pos, goal, u.radius):
			_paths[id] = {"cells": [], "i": 0, "t": run.run_time, "goal": gc, "direct": true}
			return goal
		var from := cell_of(u.pos)
		if is_solid(from) or is_solid(gc):
			return goal
		var cells: Array[Vector2i] = astar.get_id_path(from, gc, true)
		pd = {"cells": cells, "i": 1, "t": run.run_time, "goal": gc, "direct": false}
		_paths[id] = pd
	if pd.get("direct", false):
		return goal
	var cells: Array[Vector2i] = pd["cells"]
	if cells.size() < 2:
		return goal
	var i: int = pd["i"]
	while i < cells.size() - 1 and Vector2(cell_pos(cells[i]).x - u.pos.x, cell_pos(cells[i]).z - u.pos.z).length() < CELL * 0.6:
		i += 1
	pd["i"] = i
	return goal if i >= cells.size() - 1 else cell_pos(cells[i])


## A line clear for a body of radius r (checks both edges of the swept circle).
func _wide_clear(a: Vector3, b: Vector3, r: float) -> bool:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	if d.length() < 0.01:
		return true
	var side := Vector3(-d.z, 0, d.x).normalized() * (r + 0.15)
	return los(a + side, b + side) and los(a - side, b - side)


# ---------------------------------------------------------------- generation
## Lays out depth `w / 2`: rooms north from the start, one lair at the end, two side rooms.
func generate(w: int, seed_v: int) -> void:
	wave = w
	depth = depth_of(w)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for attempt in 6:
		if _try_layout(rng):
			break
	_place_pillars(rng)
	_build_astar()
	seen = PackedByteArray()
	seen.resize(W * H)
	start_pos = cell_pos(_center(rooms[0]["rect"]) + Vector2i(0, 2))
	lair = _lair()["rect"]
	lair_pos = cell_pos(_center(lair))


func _try_layout(rng: RandomNumberGenerator) -> bool:
	solid = PackedByteArray()
	solid.resize(W * H)
	solid.fill(1)
	rooms.clear()
	_corr.clear()
	var n_rooms := 6 + depth / 3
	var cur := Rect2i(W / 2 - 4, H - 12, 9, 8)
	_add_room(cur, "start")
	for i in range(1, n_rooms):
		var last := i == n_rooms - 1
		var placed := false
		for attempt in 40:
			var rw := rng.randi_range(13, 16) if last else rng.randi_range(8, 13)
			var rh := rng.randi_range(12, 14) if last else rng.randi_range(8, 12)
			var dirs := [Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]
			var dir: Vector2i = dirs[rng.randi() % dirs.size()]
			var gap := rng.randi_range(4, 8)
			var cc := _center(cur)
			var nc := cc + Vector2i(dir.x * (cur.size.x / 2 + gap + rw / 2), dir.y * (cur.size.y / 2 + gap + rh / 2))
			if dir.x == 0:
				nc.x += rng.randi_range(-6, 6)
			else:
				nc.y += rng.randi_range(-4, 4)
			var r := Rect2i(nc.x - rw / 2, nc.y - rh / 2, rw, rh)
			if not _fits(r):
				continue
			_add_room(r, "lair" if last else "room")
			_corridor(cc, _center(r), rng)
			cur = r
			placed = true
			break
		if not placed:
			break
	if rooms.size() < 4:
		return false
	if rooms[-1]["kind"] != "lair":
		rooms[-1]["kind"] = "lair"
	# side rooms off the main path: a chest (and sometimes a pack) in each
	var sides := 0
	for attempt in 30:
		if sides >= 2:
			break
		var base: Dictionary = rooms[rng.randi_range(1, rooms.size() - 2)]
		var br: Rect2i = base["rect"]
		var dir := Vector2i(-1, 0) if rng.randf() < 0.5 else Vector2i(1, 0)
		var rw := rng.randi_range(6, 8)
		var rh := rng.randi_range(6, 8)
		var cc := _center(br)
		var nc := cc + Vector2i(dir.x * (br.size.x / 2 + rng.randi_range(4, 7) + rw / 2), rng.randi_range(-2, 2))
		var r := Rect2i(nc.x - rw / 2, nc.y - rh / 2, rw, rh)
		if not _fits(r):
			continue
		_add_room(r, "side")
		_corridor(cc, _center(r), rng)
		sides += 1
	return true


static func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


func _lair() -> Dictionary:
	for rm in rooms:
		if rm["kind"] == "lair":
			return rm
	return rooms[-1]


func _fits(r: Rect2i) -> bool:
	if r.position.x < 2 or r.position.y < 2 or r.end.x > W - 2 or r.end.y > H - 2:
		return false
	for rm in rooms:
		if (rm["rect"] as Rect2i).grow(3).intersects(r):
			return false
	return true


func _add_room(r: Rect2i, kind: String) -> void:
	rooms.append({"rect": r, "kind": kind})
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			solid[j * W + i] = 0


## Three cells wide, one bend.
func _corridor(a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var bend := Vector2i(b.x, a.y) if rng.randf() < 0.5 else Vector2i(a.x, b.y)
	_carve_line(a, bend)
	_carve_line(bend, b)


func _carve_line(a: Vector2i, b: Vector2i) -> void:
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var c := a
	while true:
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var cc := c + Vector2i(di, dj)
				if in_grid(cc) and cc.x > 0 and cc.y > 0 and cc.x < W - 1 and cc.y < H - 1:
					solid[cc.y * W + cc.x] = 0
					_corr[cc] = true
		if c == b:
			break
		c += step


## Square pillars in the bigger rooms: cover to fight round, never on a corridor line.
func _place_pillars(rng: RandomNumberGenerator) -> void:
	for rm in rooms:
		var r: Rect2i = rm["rect"]
		if rm["kind"] in ["start", "side"] or r.size.x < 9 or r.size.y < 9:
			continue
		var qx := maxi(2, r.size.x / 4)
		var qy := maxi(2, r.size.y / 4)
		for p in [Vector2i(qx, qy), Vector2i(r.size.x - 1 - qx, qy), Vector2i(qx, r.size.y - 1 - qy), Vector2i(r.size.x - 1 - qx, r.size.y - 1 - qy)]:
			if rng.randf() < 0.3:
				continue
			var c: Vector2i = r.position + p
			var near_corr := false
			for dj in range(-1, 2):
				for di in range(-1, 2):
					if _corr.has(c + Vector2i(di, dj)):
						near_corr = true
			if not near_corr:
				solid[c.y * W + c.x] = 1


func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for j in H:
		for i in W:
			if solid[j * W + i] == 1:
				astar.set_point_solid(Vector2i(i, j), true)
	_paths.clear()


## Walkable cells of a room, at least `margin` cells from its edge.
func _room_cells(r: Rect2i, margin := 1) -> Array:
	var out := []
	for j in range(r.position.y + margin, r.end.y - margin):
		for i in range(r.position.x + margin, r.end.x - margin):
			if solid[j * W + i] == 0:
				out.append(Vector2i(i, j))
	return out


# ---------------------------------------------------------------- populate
## Builds depth `w` (layout, visuals, packs, wells, chests). The hero is teleported to start_pos by the caller.
func begin(w: int) -> void:
	clear()
	var s := int(run.cfg.get("seed", 0))
	if s == 0:
		s = int(run.get_meta("delve_seed", 0))
		if s == 0:
			s = randi() + 1
			run.set_meta("delve_seed", s)
	generate(w, absi(hash("%d-%d" % [s, w])))
	active = true
	cleared = false
	lair_open = false
	guardians.clear()
	_place_packs()
	_place_props()
	if Art.has_method("build_dungeon"):
		vis = Art.build_dungeon(self)
	_reveal(start_pos)


func _place_packs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("packs-%d-%d" % [wave, int(run.get_meta("delve_seed", run.cfg.get("seed", 1)))]))
	var units := []
	for ww in [wave - 1, wave]:
		for b in DB.wave_bursts(maxi(1, ww)):
			for k in b["units"]:
				units.append([k, maxi(1, ww)])
	# the same mix, a share of it: shuffle and keep the front
	for i in range(units.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = units[i]
		units[i] = units[j]
		units[j] = t
	units = units.slice(0, maxi(8, int(round(units.size() * SHARE))))
	var spots: Array = []
	for rm in rooms:
		if rm["kind"] == "room":
			spots.append(rm)
			if (rm["rect"] as Rect2i).get_area() >= 100:
				spots.append(rm)   # big rooms hold two packs
		elif rm["kind"] == "side" and rng.randf() < 0.5:
			spots.append(rm)
	if spots.is_empty():
		spots.append(_lair())
	var per := maxi(3, ceili(float(units.size()) / spots.size()))
	var ui := 0
	var spot_i := 0
	var cap_kind: String = DB.wave_info(maxi(1, wave - 1)).get("captain", "")
	while ui < units.size():
		var rm: Dictionary = spots[spot_i % spots.size()]
		spot_i += 1
		var cells := _room_cells(rm["rect"], 1)
		if cells.is_empty():
			continue
		var center: Vector2i = cells[rng.randi() % cells.size()]
		var pk := {"units": [], "awake": false}
		var n := mini(per, units.size() - ui)
		for k in n:
			var u: Array = units[ui]
			ui += 1
			var c := center + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if is_solid(c) or not (rm["rect"] as Rect2i).has_point(c):
				c = center
			var p := cell_pos(c) + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
			pk["units"].append(_spawn_dormant(u[0], p, u[1], packs.size()))
		packs.append(pk)
	# the earlier wave's captain leads the pack in the middle of the depth
	if cap_kind != "" and packs.size() > 1:
		var mid: Dictionary = packs[packs.size() / 2]
		var lead: Enemy = mid["units"][0]
		var e := _spawn_dormant(cap_kind, lead.pos + Vector3(0.8, 0, 0.8), maxi(1, wave - 1), packs.find(mid))
		e.make_captain()
		mid["units"].append(e)
	# a pack waits in the lair too, awake with the guardian
	var lr := _room_cells(lair, 2)
	if not lr.is_empty():
		var pk2 := {"units": [], "awake": false, "lair": true}
		var esc := ["gnawer", "gnawer", "shieldbearer", "gnawer"] if wave < 8 else ["shieldbearer", "hexcaster", "gnawer", "gnawer", "ironhulk"]
		for k in esc:
			var c2: Vector2i = lr[rng.randi() % lr.size()]
			pk2["units"].append(_spawn_dormant(k, cell_pos(c2), wave, packs.size()))
		packs.append(pk2)


func _spawn_dormant(kind: String, p: Vector3, w: int, pack_i: int) -> Enemy:
	var e: Enemy = run.spawn_enemy(kind, p, w)
	e.xp_val *= REWARD
	e.gold_val *= REWARD
	run._roll_elite(e)
	e.dormant = true
	e.pack = pack_i
	e.face(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	return e


func _place_props() -> void:
	wells.clear()
	chests.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("props-%d" % wave))
	var mains := []
	for rm in rooms:
		if rm["kind"] == "room":
			mains.append(rm)
		elif rm["kind"] == "side":
			var cs := _room_cells(rm["rect"], 2)
			if not cs.is_empty():
				chests.append({"pos": cell_pos(_center(rm["rect"])), "opened": false, "node": null,
					"gold": int(round((60 + 18 * wave) * run.gold_scale))})
	# wells: one about a third of the way in, one just before the lair
	for f in [0.34, 0.99]:
		if mains.is_empty():
			break
		var rm: Dictionary = mains[clampi(int(f * (mains.size() - 1)), 0, mains.size() - 1)]
		var r: Rect2i = rm["rect"]
		var c := Vector2i(r.position.x + 1, r.position.y + 1) if rng.randf() < 0.5 else Vector2i(r.end.x - 2, r.position.y + 1)
		if not is_solid(c) and not _has_prop(cell_pos(c)):
			wells.append({"pos": cell_pos(c), "used": false, "node": null})


func _has_prop(p: Vector3) -> bool:
	for wl in wells:
		if (wl["pos"] as Vector3).distance_to(p) < 1.0:
			return true
	return false


## Frees the depth (visuals; the run frees the enemies). Called on wave end, death and when the run ends.
func clear() -> void:
	active = false
	packs.clear()
	guardians.clear()
	wells.clear()
	chests.clear()
	_paths.clear()
	if vis and is_instance_valid(vis):
		vis.queue_free()
	vis = null


# ---------------------------------------------------------------- tick
func tick(dt: float) -> void:
	if not active:
		return
	_t -= dt
	var h := run.hero
	if _t <= 0.0:
		_t = 0.2
		if h.alive and not h.dead:
			for pk in packs:
				if pk["awake"]:
					continue
				for e in pk["units"]:
					if not e.alive:
						continue
					var d := Vector2(e.pos.x - h.pos.x, e.pos.z - h.pos.z).length()
					if d < AGGRO_NEAR or (d < AGGRO_R and los(h.pos, e.pos)):
						wake(pk)
						break
			if not lair_open and lair.has_point(cell_of(h.pos)):
				_open_lair()
			_props(h)
	_seen_t -= dt
	if _seen_t <= 0.0:
		_seen_t = 0.3
		_reveal(h.pos)
	if lair_open and not cleared:
		var any := false
		for g in guardians:
			if g.alive:
				any = true
		if not any:
			cleared = true
			run._wave_cleared()


## Wakes a whole pack: they all come for the hero.
func wake(pk: Dictionary) -> void:
	if pk["awake"]:
		return
	pk["awake"] = true
	for e in pk["units"]:
		if e.alive:
			e.dormant = false
			e.retarget_t = randf() * 0.3
			e.flash(Color(1.0, 0.45, 0.3))
	run.hint_once("delve_pack", "You woke a pack! Sleeping foes wake when you come close or hit one of them.")


## A dormant enemy was hit: its pack wakes.
func wake_unit(e: Enemy) -> void:
	if e.pack >= 0 and e.pack < packs.size():
		wake(packs[e.pack])
	else:
		e.dormant = false


func _open_lair() -> void:
	lair_open = true
	var bk := boss_kind(wave)
	var far := lair_pos + Vector3(0, 0, -float(lair.size.y) * CELL * 0.22)
	if bk != "":
		var home: int = BOSS_HOME[bk]
		var spots := [far + Vector3(-4, 0, 0), far + Vector3(4, 0, 0)] if bk == "matron" else [far]
		for i in spots.size():
			var e := run.spawn_enemy(bk, resolve(null, spots[i]), home)
			# deeper bosses are a little tougher than at home
			e.max_hp *= 1.0 + 0.04 * maxi(0, wave - home)
			e.hp = e.max_hp
			if i == 1:
				e.set_tint(Color(0.75, 0.85, 1.25))
				e.twin_index = 1
			guardians.append(e)
			run.fx("teleport", {"pos": e.pos})
		run.boss_title = boss_title(wave)
		run.banner_requested.emit("The lair", "Boss: " + run.boss_title)
		run.schedule(2.6, run.toast.bind(DB.BOSS_HINTS.get(home, ""), Art.palette.get("gold", Color.GOLD)))
		Audio.play("boss")
		run.shake(0.5)
	else:
		var kind: String = DB.wave_info(wave).get("captain", "gnawer")
		var e := run.spawn_enemy(kind, resolve(null, far), wave)
		e.make_captain()
		e.xp_val *= REWARD
		run.captain = e
		guardians.append(e)
		run.fx("teleport", {"pos": e.pos})
		run.banner_requested.emit("The lair", "%s guards the way down" % e.display_name)
		Audio.play("wave")
	for pk in packs:
		if pk.get("lair", false):
			wake(pk)


func _props(h: Hero) -> void:
	for wl in wells:
		if not wl["used"] and Vector2(h.pos.x - wl["pos"].x, h.pos.z - wl["pos"].z).length() < 2.2:
			wl["used"] = true
			run.heal_unit(h, h.max_hp * WELL_HEAL)
			h.mana = minf(h.max_mana, h.mana + h.max_mana * WELL_HEAL)
			run.fx("fountain_heal", {"pos": wl["pos"]})
			run.toast("The ember well restores you", Art.palette.get("heal", Color.GREEN))
			Audio.play("teleport")
			var glow = wl["node"]
			if glow is Node3D and is_instance_valid(glow):
				(glow as Node3D).visible = false   # the well goes dark
	for ch in chests:
		if not ch["opened"] and Vector2(h.pos.x - ch["pos"].x, h.pos.z - ch["pos"].z).length() < 2.0:
			ch["opened"] = true
			run.add_gold(int(ch["gold"]))
			run.fx("gold", {"pos": ch["pos"] + Vector3(0, 1.5, 0), "amount": int(ch["gold"])})
			run.toast("Treasure! +%d gold" % int(ch["gold"]), Art.palette.get("gold", Color.GOLD))
			Audio.play("clear")
			var lid = ch["node"]
			if lid is Node3D and is_instance_valid(lid):
				(lid as Node3D).position += Vector3(0, 0.1, -0.35)
				(lid as Node3D).rotation_degrees.x = -75.0


## Minimap: cells within sight of p are revealed.
func _reveal(p: Vector3) -> void:
	var c := cell_of(p)
	var rr := 7
	for dj in range(-rr, rr + 1):
		for di in range(-rr, rr + 1):
			var cc := c + Vector2i(di, dj)
			if in_grid(cc) and di * di + dj * dj <= rr * rr:
				seen[cc.y * W + cc.x] = 1


## Bot: where to head when nothing is awake. The nearest living dormant foe, else the lair.
func bot_goal(from: Vector3) -> Vector3:
	var best := lair_pos
	var bd := 1e9
	for pk in packs:
		for e in pk["units"]:
			if e.alive and e.dormant:
				var d := Vector2(e.pos.x - from.x, e.pos.z - from.z).length()
				if d < bd:
					bd = d
					best = e.pos
	return best


## Awake foes only: dormant ones don't count as "in the fight".
static func is_dormant(u: Unit) -> bool:
	return u is Enemy and (u as Enemy).dormant
