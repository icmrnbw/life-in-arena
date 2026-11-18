class_name Delve
extends Node3D
## Delve mode (Diablo style). Instead of waves pouring into the Pit, each "wave" is a depth of the Undercroft:
## rooms, caves and corridors generated from the run's seed, branching with loops and dead ends. Foes wait in packs
## (dormant) and wake when the hero comes close with a clear view, or hits one of them. The depth is cleared when
## its guardian falls: a wave captain, or a boss on depths 3, 6 and 10. The guardian appears when the hero steps into
## the last room (the lair).
##
## Delve-only mechanics (none of this exists in the arena modes):
## - Darkness: the hero sees by a lantern. Rooms stay black until their beacon brazier is lit (walk up to it); foes in
##   lit rooms are Exposed (+20% damage taken). Foes in the dark show glowing eyes.
## - Shrines: a blessing for the rest of the depth (scripts/delve_lore.gd SHRINES); the Blood Shrine costs health.
## - Traps: rows of spikes (or fire vents in the Abyss) across corridors, on a timer. They hurt foes too.
## - Terrain by depth: the Bone Crypt (1-3), the Flooded Caverns (4-6, water slows), the Abyss (7-10, ember cracks
##   burn). Lure foes through it.
## - Sealed vault: a dead end that bars shut when entered; foes crawl out of the walls in three bursts. Clear it for a
##   relic: pick 1 of 3 run-long passives (DelveLore.RELICS). Boss depths give a relic too.
## - Press on or rest: after a depth, take the stairs straight down (streak: +20% gold and xp per depth in a row, no
##   shop, no heal) or go back to camp.
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
const NAMES := ["The Cellars", "The Ossuary", "The Charnel Halls", "The Sunken Halls", "The Drowned Crypt",
	"The Weeping Grotto", "The Ember Vaults", "The Iron Galleries", "The Hollow Deep", "The Heart of the Undercroft"]

const LANTERN_R := 9.0           # the hero's light (m); DelveLore relic stat lantern_r adds a share
const EXPOSED := 1.2             # damage taken by a foe standing in a lit room (not bosses)
const BEACON_R := 2.6            # walk this close to a room's beacon to light it
const SHRINE_R := 2.2
const WATER_SLOW := 0.3
const EMBER_HERO := 0.035        # share of max HP an ember crack burns every EMBER_TICK
const EMBER_FOE := 0.06
const EMBER_TICK := 0.5
const SPIKE_HERO := 0.12         # share of max HP a spike strike takes
const SPIKE_FOE := 0.35
const SPIKE_BOSS := 0.02
const VENT_HERO := 0.04          # fire vents burn every 0.25 s while they blaze
const VENT_FOE := 0.1
const TRAP_WARN := 0.75
const VAULT_BURSTS := 3

var run: Run
var active := false              # a depth is built (wave phase)
var depth := 1
var wave := 2
var tier := 0                    # DelveLore.TIERS index
var solid := PackedByteArray()   # W * H, 1 = rock
var seen := PackedByteArray()    # W * H, 1 = revealed on the minimap
var cave := PackedByteArray()    # W * H, 1 = rough cave floor (art)
var terrain := PackedByteArray() # W * H, 0 none, 1 water, 2 ember cracks
var lit := PackedByteArray()     # W * H, 0..255 light (beacon-lit rooms, corridor torches); feeds the shaders
var lit_tex: ImageTexture
var rooms: Array = []            # {rect, kind: start|room|side|shrine|vault|lair, cave, lit, beacon, parent}
var packs: Array = []            # {units: Array[Enemy], awake: bool}
var lair := Rect2i()
var lair_open := false
var guardians: Array = []
var wells: Array = []            # {pos, used, node}
var chests: Array = []           # {pos, opened, gold, node}
var shrines: Array = []          # {pos, kind, used, node}
var traps: Array = []            # {cells, kind, t, period, state, from, to, node, hit, tick}
var vault := {}                  # {room, rect, doors, state: idle|sealed|done, burst, units, bars, chest}
var start_pos := Vector3.ZERO
var lair_pos := Vector3.ZERO
var cleared := false
var choosing := false            # the relic / stairs choice is open after a clear
var streak := 0                  # depths in a row without going back to camp
var blessing_kind := ""          # the shrine whose blessing the hero has this depth
var vis: Node3D = null
var eyes: MultiMeshInstance3D = null
var astar: AStarGrid2D
var _paths := {}                 # unit instance id -> {cells, i, t, goal}
var _corr := {}                  # corridor cells (no pillars there)
var _line := {}                  # corridor centre-line cells -> true
var _vault_corr := {}            # cells of the vault's own corridor (its doors)
var _t := 0.0
var _seen_t := 0.0
var _ember_t := 0.0
var _dark := 0.0                 # 0 in camp, eases to 1 in the dungeon
var _env: Environment = null
var _sun: DirectionalLight3D = null
var _env_base := {}


func setup(r: Run) -> void:
	run = r
	name = "Delve"
	var img := Image.create(W, H, false, Image.FORMAT_L8)
	lit_tex = ImageTexture.create_from_image(img)


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
	var td: Dictionary = DelveLore.tier(d)
	var desc := L.f("Find the lair and slay %s. Light the braziers: foes in the light take more damage.", [L.t(boss_title(w)) if bk != "" else L.t(DB.CAPTAIN_NAMES.get(cap, "the captain"))])
	match String(td["hazard"]):
		"water":
			desc += " " + L.t("Water slows everyone who wades through it.")
		"ember":
			desc += " " + L.t("Ember cracks burn everyone who stands on them.")
	return {"name": L.f("Depth %d", [d]) + " · " + L.t(depth_name(w)), "captain": "" if bk != "" else cap,
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


func terrain_at(p: Vector3) -> int:
	var c := cell_of(p)
	return terrain[c.y * W + c.x] if in_grid(c) and terrain.size() == W * H else 0


func light_at(p: Vector3) -> float:
	var c := cell_of(p)
	return lit[c.y * W + c.x] / 255.0 if in_grid(c) and lit.size() == W * H else 0.0


## A foe standing in a lit room takes more damage (bosses excepted).
func exposed(u: Unit) -> bool:
	return active and u.team == 1 and not u.is_boss and light_at(u.pos) >= 0.5


func lantern_r() -> float:
	return LANTERN_R * (1.0 + float(run.hero.item_stats.get("lantern_r", 0.0))) if run and run.hero else LANTERN_R


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
## Lays out depth `w / 2`: a main path of rooms from the start to the lair that wanders north, east and west;
## branches off it (vault, shrine room, treasure rooms) and a loop or two back into the path. Some rooms are rough
## caves (more of them deeper down), the rest crypt halls with pillars.
func generate(w: int, seed_v: int) -> void:
	wave = w
	depth = depth_of(w)
	tier = DelveLore.tier_of(depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for attempt in 8:
		if _try_layout(rng):
			break
	_place_pillars(rng)
	_prune_unreachable()
	_place_terrain(rng)
	_place_traps(rng)
	_build_astar()
	seen = PackedByteArray()
	seen.resize(W * H)
	start_pos = cell_pos(_open_near(_center(rooms[0]["rect"]) + Vector2i(0, 2)))
	lair = _lair()["rect"]
	lair_pos = cell_pos(_center(lair))


func _try_layout(rng: RandomNumberGenerator) -> bool:
	solid = PackedByteArray()
	solid.resize(W * H)
	solid.fill(1)
	cave = PackedByteArray()
	cave.resize(W * H)
	terrain = PackedByteArray()
	terrain.resize(W * H)
	rooms.clear()
	_corr.clear()
	_line.clear()
	_vault_corr.clear()
	var cave_p: float = DelveLore.tier(depth)["caves"]
	var n_rooms := 6 + depth / 3
	var cur_i := 0
	_add_room(Rect2i(W / 2 - 4, H - 12, 9, 8), "start", false, rng, -1)
	var last_dir := Vector2i(0, -1)
	for i in range(1, n_rooms):
		var last := i == n_rooms - 1
		var placed := false
		for attempt in 50:
			var is_cave := rng.randf() < cave_p and not last
			var rw := rng.randi_range(13, 16) if last else rng.randi_range(9, 14)
			var rh := rng.randi_range(12, 14) if last else rng.randi_range(8, 13)
			# wander: north mostly, but turn east / west often, never straight back
			var dirs := [Vector2i(0, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 0)]
			var dir: Vector2i = dirs[rng.randi() % dirs.size()]
			if dir == -last_dir:
				dir = Vector2i(0, -1)
			var cur: Rect2i = rooms[cur_i]["rect"]
			var r := _beside(cur, dir, rw, rh, rng.randi_range(4, 9), rng)
			if not _fits(r):
				continue
			_add_room(r, "lair" if last else "room", is_cave, rng, cur_i)
			_corridor(_center(cur), _center(r), rng)
			cur_i = rooms.size() - 1
			last_dir = dir
			placed = true
			break
		if not placed:
			break
	if rooms.size() < 5:
		return false
	if rooms[-1]["kind"] != "lair":
		rooms[-1]["kind"] = "lair"
	var main_n := rooms.size()
	# branches off the main path: the vault (a dead end), a shrine room, treasure rooms. Some branch twice.
	# the vault (a relic) on depths without a boss; boss depths give their relic for the kill
	var want := ["shrine", "side", "side"] if depth >= 2 else ["shrine", "side"]
	if boss_kind(wave) == "":
		want.push_front("vault")
	if depth >= 5:
		want.append("room")
	for kind in want:
		for attempt in 40:
			var bi := rng.randi_range(1, main_n - 2)
			if kind == "room" and rooms.size() > main_n and rng.randf() < 0.5:
				bi = rng.randi_range(main_n, rooms.size() - 1)   # a branch off a branch
			if rooms[bi]["kind"] == "vault":
				continue
			var base: Rect2i = rooms[bi]["rect"]
			var dirs2 := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
			var dir2: Vector2i = dirs2[rng.randi() % dirs2.size()]
			var small: bool = kind in ["vault", "shrine", "side"]
			var rw2 := rng.randi_range(7, 9) if small else rng.randi_range(9, 12)
			var rh2 := rng.randi_range(7, 9) if small else rng.randi_range(8, 11)
			if kind == "vault":
				rw2 = 10
				rh2 = 9
			var r2 := _beside(base, dir2, rw2, rh2, rng.randi_range(4, 8), rng)
			if not _fits(r2):
				continue
			_add_room(r2, kind, kind != "vault" and rng.randf() < cave_p, rng, bi)
			_corridor(_center(base), _center(r2), rng, kind == "vault")
			break
	# loops: join two rooms that are near each other but far apart along the path (never the vault or the lair)
	var loops := 0
	for attempt in 60:
		if loops >= 1 + depth / 4:
			break
		var a := rng.randi_range(0, rooms.size() - 1)
		var b := rng.randi_range(0, rooms.size() - 1)
		if a == b or absi(a - b) < 2 or rooms[a]["kind"] in ["vault", "lair"] or rooms[b]["kind"] in ["vault", "lair"]:
			continue
		if rooms[a]["parent"] == b or rooms[b]["parent"] == a:
			continue
		var ca := _center(rooms[a]["rect"])
		var cb := _center(rooms[b]["rect"])
		if ca.distance_to(cb) > 26.0:
			continue
		if not _corridor_clear(ca, cb, a, b):
			continue
		_corridor(ca, cb, rng)
		loops += 1
	return true


## A w x h room `gap` cells beside r in direction dir, jittered sideways.
func _beside(r: Rect2i, dir: Vector2i, rw: int, rh: int, gap: int, rng: RandomNumberGenerator) -> Rect2i:
	var cc := _center(r)
	var nc := cc + Vector2i(dir.x * (r.size.x / 2 + gap + rw / 2), dir.y * (r.size.y / 2 + gap + rh / 2))
	if dir.x == 0:
		nc.x += rng.randi_range(-6, 6)
	else:
		nc.y += rng.randi_range(-4, 4)
	return Rect2i(nc.x - rw / 2, nc.y - rh / 2, rw, rh)


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


## A loop corridor (both L bends) must not cut through a third room: that would open the vault or skip the lair.
func _corridor_clear(a: Vector2i, b: Vector2i, ia: int, ib: int) -> bool:
	for bend in [Vector2i(b.x, a.y), Vector2i(a.x, b.y)]:
		var ok := true
		for seg in [[a, bend], [bend, b]]:
			var s: Vector2i = seg[0]
			var e: Vector2i = seg[1]
			var step := Vector2i(signi(e.x - s.x), signi(e.y - s.y))
			var c := s
			while true:
				for ri in rooms.size():
					if ri != ia and ri != ib and (rooms[ri]["rect"] as Rect2i).grow(2).has_point(c):
						ok = false
				if c == e or not ok:
					break
				c += step
		if ok:
			return true
	return false


func _add_room(r: Rect2i, kind: String, is_cave: bool, rng: RandomNumberGenerator, parent: int) -> void:
	rooms.append({"rect": r, "kind": kind, "cave": is_cave, "lit": false, "beacon": Vector3.ZERO, "parent": parent})
	if not is_cave:
		for j in range(r.position.y, r.end.y):
			for i in range(r.position.x, r.end.x):
				solid[j * W + i] = 0
		return
	# a cave: a lumpy blob inside the rect, smoothed twice, with an open middle
	var cx := r.position.x + r.size.x * 0.5
	var cy := r.position.y + r.size.y * 0.5
	var blob := {}
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var dx := (i + 0.5 - cx) / (r.size.x * 0.5)
			var dy := (j + 0.5 - cy) / (r.size.y * 0.5)
			blob[Vector2i(i, j)] = dx * dx + dy * dy < 0.7 + rng.randf() * 0.45
	for it in 2:
		var nb := {}
		for c in blob:
			var n := 0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					if blob.get(c + Vector2i(di, dj), false):
						n += 1
			nb[c] = n >= 5
		blob = nb
	var mid := _center(r)
	for dj in range(-1, 2):
		for di in range(-1, 2):
			blob[mid + Vector2i(di, dj)] = true
	for c in blob:
		if blob[c]:
			solid[c.y * W + c.x] = 0
			cave[c.y * W + c.x] = 1


## Three cells wide, one bend. The vault's corridor is remembered: its cells next to the room are the doors.
func _corridor(a: Vector2i, b: Vector2i, rng: RandomNumberGenerator, is_vault := false) -> void:
	var bend := Vector2i(b.x, a.y) if rng.randf() < 0.5 else Vector2i(a.x, b.y)
	_carve_line(a, bend, is_vault)
	_carve_line(bend, b, is_vault)


func _carve_line(a: Vector2i, b: Vector2i, is_vault := false) -> void:
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var c := a
	while true:
		_line[c] = true
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var cc := c + Vector2i(di, dj)
				if in_grid(cc) and cc.x > 0 and cc.y > 0 and cc.x < W - 1 and cc.y < H - 1:
					solid[cc.y * W + cc.x] = 0
					_corr[cc] = true
					if is_vault:
						_vault_corr[cc] = true
		if c == b:
			break
		c += step


## Square pillars in the crypt halls: cover to fight round, never on a corridor line.
func _place_pillars(rng: RandomNumberGenerator) -> void:
	for rm in rooms:
		var r: Rect2i = rm["rect"]
		if rm["cave"] or rm["kind"] in ["start", "side", "shrine", "vault"] or r.size.x < 9 or r.size.y < 9:
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


## Floor pockets that the caves' smoothing cut off from the start are filled in (nothing can be placed in them).
func _prune_unreachable() -> void:
	var from := _open_near(_center(rooms[0]["rect"]))
	var reach := PackedByteArray()
	reach.resize(W * H)
	var q: Array[Vector2i] = [from]
	reach[from.y * W + from.x] = 1
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not is_solid(n) and reach[n.y * W + n.x] == 0:
				reach[n.y * W + n.x] = 1
				q.append(n)
	for i in W * H:
		if solid[i] == 0 and reach[i] == 0:
			solid[i] = 1


## Water pools (Flooded Caverns) or ember cracks (the Abyss): blobs in the rooms, never in the start room, on the
## lair's middle or in the vault, and never on a room's very centre (the paths meet there).
func _place_terrain(rng: RandomNumberGenerator) -> void:
	var hz: String = DelveLore.tier(depth)["hazard"]
	if hz == "":
		return
	var val := 1 if hz == "water" else 2
	for rm in rooms:
		if rm["kind"] in ["start", "vault", "shrine"]:
			continue
		var r: Rect2i = rm["rect"]
		var blobs := (2 if rm["cave"] else 1) if val == 1 else 1
		if val == 2 and rm["kind"] == "lair":
			blobs = 2
		for b in blobs:
			var cells := _room_cells(r, 2)
			if cells.is_empty():
				break
			var mid := _center(r)
			var c: Vector2i = cells[rng.randi() % cells.size()]
			if val == 2 and c.distance_to(mid) < 3.0:
				continue
			var rad := rng.randf_range(2.0, 3.6) if val == 1 else rng.randf_range(1.4, 2.4)
			for dj in range(-4, 5):
				for di in range(-4, 5):
					var cc := c + Vector2i(di, dj)
					if is_solid(cc) or not r.grow(1).has_point(cc):
						continue
					if Vector2(di, dj).length() + rng.randf() * 0.8 < rad:
						if val == 2 and cc.distance_to(mid) < 1.6:
							continue
						terrain[cc.y * W + cc.x] = val


## Rows of spike plates (fire vents in the Abyss) right across corridors, away from the rooms.
func _place_traps(rng: RandomNumberGenerator) -> void:
	traps.clear()
	var kind := "vent" if tier == 2 else "spikes"
	var want := 1 + depth / 2
	var cands: Array = _line.keys()
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cands[i]
		cands[i] = cands[j]
		cands[j] = t
	for c in cands:
		if traps.size() >= want:
			break
		var cell: Vector2i = c
		var horiz := _line.has(cell + Vector2i(1, 0)) and _line.has(cell - Vector2i(1, 0)) and not _line.has(cell + Vector2i(0, 1)) and not _line.has(cell - Vector2i(0, 1))
		var vert := _line.has(cell + Vector2i(0, 1)) and _line.has(cell - Vector2i(0, 1)) and not _line.has(cell + Vector2i(1, 0)) and not _line.has(cell - Vector2i(1, 0))
		if not (horiz or vert):
			continue
		var across := Vector2i(0, 1) if horiz else Vector2i(1, 0)
		var row := [cell - across, cell, cell + across]
		var ok := true
		for rc in row:
			if is_solid(rc) or _in_any_room(rc, 2) or _vault_corr.has(rc):
				ok = false
		for t in traps:
			if (t["cells"][1] as Vector2i).distance_to(cell) < 7.0:
				ok = false
		if not ok:
			continue
		var period := rng.randf_range(2.8, 3.6) if kind == "spikes" else rng.randf_range(3.4, 4.2)
		traps.append({"cells": row, "kind": kind, "t": rng.randf() * period, "period": period, "state": "idle",
			"from": cell_pos(row[0]), "to": cell_pos(row[2]), "node": null, "hit": {}, "tick": 0.0, "hz": {}})


func _in_any_room(c: Vector2i, grow := 0) -> bool:
	for rm in rooms:
		if (rm["rect"] as Rect2i).grow(grow).has_point(c):
			return true
	return false


func _open_near(c: Vector2i) -> Vector2i:
	if not is_solid(c):
		return c
	for ring in range(1, 6):
		for dj in range(-ring, ring + 1):
			for di in range(-ring, ring + 1):
				if not is_solid(c + Vector2i(di, dj)):
					return c + Vector2i(di, dj)
	return c


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
## Builds depth `w` (layout, visuals, packs, wells, chests, shrines, the vault). The caller sends the hero down.
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
	choosing = false
	lair_open = false
	guardians.clear()
	_place_packs()
	_place_props()
	_init_light()
	if Art.has_method("build_dungeon"):
		vis = Art.build_dungeon(self)
		eyes = vis.get_node_or_null("Eyes") as MultiMeshInstance3D
	light_room(0, false)
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
			if (rm["rect"] as Rect2i).get_area() >= 110:
				spots.append(rm)   # big rooms hold two packs
		elif rm["kind"] in ["side", "shrine"] and rng.randf() < 0.5:
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
	shrines.clear()
	vault = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("props-%d-%d" % [wave, int(run.get_meta("delve_seed", run.cfg.get("seed", 1)))]))
	var mains := []
	var shrine_kinds: Array = DelveLore.SHRINES.keys()
	for ri in rooms.size():
		var rm: Dictionary = rooms[ri]
		var r: Rect2i = rm["rect"]
		match String(rm["kind"]):
			"room":
				mains.append(rm)
			"side":
				chests.append({"pos": cell_pos(_open_near(_center(r))), "opened": false, "node": null,
					"gold": int(round((60 + 18 * wave) * run.gold_scale))})
			"shrine":
				shrines.append({"pos": cell_pos(_open_near(_center(r) + Vector2i(0, -1))), "kind": shrine_kinds[rng.randi() % shrine_kinds.size()],
					"used": false, "node": null})
			"vault":
				var doors := []
				for c in _vault_corr:
					if r.grow(1).has_point(c) and not r.has_point(c) and not is_solid(c):
						doors.append(c)
				vault = {"room": ri, "rect": r, "doors": doors, "state": "idle", "burst": 0, "units": [], "bars": null,
					"chest": {"pos": cell_pos(_open_near(_center(r))), "node": null}}
		# every room but the start and the lair has a beacon brazier to light
		if rm["kind"] not in ["start", "lair"]:
			var bc := _open_near(_center(r) + (Vector2i(2, -1) if rm["kind"] in ["side", "shrine", "vault"] else Vector2i(0, 0)))
			rm["beacon"] = cell_pos(bc)
	# a second shrine in a main room now and then
	if not mains.is_empty() and rng.randf() < 0.45:
		var rm2: Dictionary = mains[rng.randi() % mains.size()]
		var r2: Rect2i = rm2["rect"]
		var cs := _room_cells(r2, 2)
		if not cs.is_empty():
			var c: Vector2i = cs[0]
			shrines.append({"pos": cell_pos(c), "kind": shrine_kinds[rng.randi() % shrine_kinds.size()], "used": false, "node": null})
	# wells: one about a third of the way in, one just before the lair
	for f in [0.34, 0.99]:
		if mains.is_empty():
			break
		var rm: Dictionary = mains[clampi(int(f * (mains.size() - 1)), 0, mains.size() - 1)]
		var r: Rect2i = rm["rect"]
		var c := Vector2i(r.position.x + 1, r.position.y + 1) if rng.randf() < 0.5 else Vector2i(r.end.x - 2, r.position.y + 1)
		c = _open_near(c)
		if not is_solid(c) and not _has_prop(cell_pos(c)):
			wells.append({"pos": cell_pos(c), "used": false, "node": null})
	# no terrain under the props
	var spots: Array = []
	for wl in wells:
		spots.append(wl["pos"])
	for sh in shrines:
		spots.append(sh["pos"])
	for ch in chests:
		spots.append(ch["pos"])
	for rm in rooms:
		if rm["beacon"] != Vector3.ZERO:
			spots.append(rm["beacon"])
	for p in spots:
		var c := cell_of(p)
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var cc := c + Vector2i(di, dj)
				if in_grid(cc):
					terrain[cc.y * W + cc.x] = 0


func _has_prop(p: Vector3) -> bool:
	for wl in wells:
		if (wl["pos"] as Vector3).distance_to(p) < 1.0:
			return true
	return false


# ---------------------------------------------------------------- light
## Corridor torches light a little patch round them from the start; rooms are dark until lit.
func _init_light() -> void:
	lit = PackedByteArray()
	lit.resize(W * H)
	_push_light()


## Lights room i: its braziers burn, its floor shows, foes on it are Exposed, the minimap shows all of it.
func light_room(i: int, announce := true) -> void:
	if i < 0 or i >= rooms.size() or rooms[i]["lit"]:
		return
	var rm: Dictionary = rooms[i]
	rm["lit"] = true
	var r: Rect2i = rm["rect"]
	for j in range(r.position.y - 2, r.end.y + 2):
		for k in range(r.position.x - 2, r.end.x + 2):
			var c := Vector2i(k, j)
			if not in_grid(c):
				continue
			var edge := not r.grow(1).has_point(c)
			var v := 120 if edge else 255
			lit[j * W + k] = maxi(lit[j * W + k], v)
			seen[j * W + k] = 1
	_push_light()
	if Art.has_method("light_dungeon_room"):
		Art.light_dungeon_room(self, i)
	if announce:
		var td: Dictionary = DelveLore.tier(depth)
		run.fx("ring_burst", {"pos": rm["beacon"], "radius": 4.0, "color": td["light"]})
		Audio.play("teleport")
		run.hint_once("delve_light", "Room lit! Foes standing in the light are Exposed and take 20% more damage.")


func _push_light() -> void:
	var img := Image.create_from_data(W, H, false, Image.FORMAT_L8, lit)
	if lit_tex == null:
		lit_tex = ImageTexture.create_from_image(img)
	else:
		lit_tex.update(img)


## Shader globals (project.godot [shader_globals]): the hero's lantern, the light map and how dark it is.
func _process(dt: float) -> void:
	if run == null or run.hero == null:
		return
	var h := run.hero
	var want := 1.0 if active and not h.in_camp and h.pos.z < 30.0 else 0.0
	_dark = move_toward(_dark, want, dt * 1.5)
	RenderingServer.global_shader_parameter_set("delve_lantern", Vector4(h.pos.x, h.pos.z, lantern_r(), _dark))
	if _dark > 0.0:
		RenderingServer.global_shader_parameter_set("delve_grid", Vector4(ORIGIN.x, ORIGIN.z, W * CELL, H * CELL))
		RenderingServer.global_shader_parameter_set("delve_litmap", lit_tex)
	_env_tick()
	_eyes_tick()


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("delve_lantern", Vector4(0, 0, 1, 0))


## The camp keeps its look; down in the dungeon the ambient light drops and turns the tier's colour.
func _env_tick() -> void:
	if _env == null:
		var we := run.get_node_or_null("Env/ArtEnvironment") as WorldEnvironment
		if we == null or we.environment == null:
			return
		_env = we.environment
		_sun = run.get_node_or_null("Env/Sun") as DirectionalLight3D
		_env_base = {"amb": _env.ambient_light_color, "amb_e": _env.ambient_light_energy, "fog": _env.fog_light_color,
			"bg": _env.background_color, "sun": _sun.light_energy if _sun else 1.0}
	var td: Dictionary = DelveLore.tier(depth)
	var k := _dark
	_env.ambient_light_color = (_env_base["amb"] as Color).lerp(td["ambient"], k)
	_env.ambient_light_energy = lerpf(_env_base["amb_e"], 0.42, k)
	_env.fog_light_color = (_env_base["fog"] as Color).lerp(Color(0.02, 0.02, 0.03), k)
	_env.background_color = (_env_base["bg"] as Color).lerp(Color(0.0, 0.0, 0.0), k)
	if _sun:
		_sun.light_energy = lerpf(_env_base["sun"], 0.35, k)


## Glowing eyes over every foe out in the dark (beyond the lantern, outside lit rooms).
func _eyes_tick() -> void:
	if eyes == null or not is_instance_valid(eyes):
		return
	var mm := eyes.multimesh
	var n := 0
	if active and _dark > 0.5:
		var h := run.hero
		var lr := lantern_r() * 0.75
		var cam := run.camera.global_position if run.camera else h.pos + Vector3(0, 20, 12)
		for e in run.enemies:
			if n >= mm.instance_count:
				break
			if not e.alive or not e is Enemy or e.untargetable:
				continue
			if Vector2(e.pos.x - h.pos.x, e.pos.z - h.pos.z).length() < lr or light_at(e.pos) >= 0.5:
				continue
			var top: Vector3 = e.pos + Vector3(0, e.height * 0.82, 0)
			top += (cam - top).normalized() * (e.radius + 0.2)
			var s: float = 0.55 + e.radius * 0.35
			mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(s, s, s)), top))
			mm.set_instance_color(n, Color(1.0, 0.25, 0.1) if e.dormant else Color(1.0, 0.75, 0.2))
			n += 1
	mm.visible_instance_count = n


# ---------------------------------------------------------------- clear
## Frees the depth (visuals; the run frees the enemies). Called on wave end, death and when the run ends.
func clear() -> void:
	active = false
	packs.clear()
	guardians.clear()
	wells.clear()
	chests.clear()
	shrines.clear()
	traps.clear()
	vault = {}
	blessing_kind = ""
	_paths.clear()
	if run and run.hero and not run.hero.blessing.is_empty():
		run.hero.blessing = {}
		run.hero.recalc()
	if vis and is_instance_valid(vis):
		vis.queue_free()
	vis = null
	eyes = null


# ---------------------------------------------------------------- tick
func tick(dt: float) -> void:
	if not active:
		return
	_t -= dt
	var h := run.hero
	_traps_tick(dt)
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
			_vault_tick(h)
		_terrain_tick(h)
	_seen_t -= dt
	if _seen_t <= 0.0:
		_seen_t = 0.3
		_reveal(h.pos)
	if lair_open and not cleared:
		var any := false
		for g in guardians:
			if g.alive:
				any = true
		if not any and vault.get("state", "") != "sealed":
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
	light_room(rooms.find(_lair()), false)
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
		run.banner_requested.emit("The lair", L.f("Boss: %s", [L.t(run.boss_title)]))
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
		run.banner_requested.emit("The lair", L.f("%s guards the way down", [e.shown_name()]))
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
			var g := int(ch["gold"])
			run.add_gold(g)
			run.fx("gold", {"pos": ch["pos"] + Vector3(0, 1.5, 0), "amount": g})
			run.toast(L.f("Treasure! +%d gold", [g]), Art.palette.get("gold", Color.GOLD))
			Audio.play("clear")
			_open_lid(ch["node"])
	for i in rooms.size():
		var rm: Dictionary = rooms[i]
		if rm["lit"] or rm["beacon"] == Vector3.ZERO or rm["kind"] == "vault":
			continue
		var b: Vector3 = rm["beacon"]
		if Vector2(h.pos.x - b.x, h.pos.z - b.z).length() < BEACON_R:
			light_room(i)
	for sh in shrines:
		if not sh["used"] and Vector2(h.pos.x - sh["pos"].x, h.pos.z - sh["pos"].z).length() < SHRINE_R:
			_use_shrine(sh, h)


static func _open_lid(lid) -> void:
	if lid is Node3D and is_instance_valid(lid):
		(lid as Node3D).position += Vector3(0, 0.1, -0.35)
		(lid as Node3D).rotation_degrees.x = -75.0


## A shrine's blessing replaces any earlier one and lasts until the depth ends.
func _use_shrine(sh: Dictionary, h: Hero) -> void:
	sh["used"] = true
	var sd: Dictionary = DelveLore.SHRINES[sh["kind"]]
	var cost := float(sd.get("cost", 0.0))
	if cost > 0.0:
		h.hp = maxf(1.0, h.hp - h.hp * cost)
		run.fx("blood_burst", {"pos": h.pos})
		run.damage_number(h.pos, h.hp * cost, false, Art.palette.get("danger", Color.RED))
	_log("shrine " + String(sh["kind"]))
	h.blessing = (sd["stats"] as Dictionary).duplicate()
	blessing_kind = sh["kind"]
	h.recalc()
	run.fx("ring_burst", {"pos": sh["pos"], "radius": 3.0, "color": sd["color"]})
	run.fx("buff_aura", {"pos": h.pos, "color": sd["color"]})
	run.banner_requested.emit(sd["name"], sd["desc"])
	Audio.play("level_up")
	var n = sh["node"]
	if n is Node3D and is_instance_valid(n):
		var g := (n as Node3D).get_node_or_null("Glow")
		if g:
			g.visible = false


## Shrine blessing shown on the HUD ("" = none).
func blessing_name() -> String:
	if blessing_kind == "" or run == null or run.hero == null or run.hero.blessing.is_empty():
		return ""
	return DelveLore.SHRINES[blessing_kind]["name"]


## Gold and xp from foes: the press-on streak, shrine and relic bonuses.
func reward_mult(kind: String) -> float:
	var m := 1.0 + streak * DelveLore.STREAK_BONUS
	if run and run.hero:
		m += float(run.hero.item_stats.get(kind + "_pct", 0.0))
	return m


# ---------------------------------------------------------------- terrain and traps
func _terrain_tick(h: Hero) -> void:
	var hz: String = DelveLore.tier(depth)["hazard"]
	if hz == "":
		return
	_ember_t -= 0.2
	var burn := _ember_t <= 0.0
	if burn:
		_ember_t = EMBER_TICK
	var who: Array = [h]
	for e in run.enemies:
		if e.alive and e is Enemy and not (e as Enemy).dormant:
			who.append(e)
	for u in who:
		var t := terrain_at(u.pos)
		if t == 1 and not (u == h and float(h.item_stats.get("wade", 0.0)) > 0.0):
			u.apply_slow(WATER_SLOW, 0.35)
		elif t == 2 and burn:
			if u == h:
				if float(h.item_stats.get("trapproof", 0.0)) <= 0.0 and not h.dead:
					run.damage(h, h.max_hp * EMBER_HERO, null, "Ember Cracks", "pure")
					run.hint_once("delve_ember", "Ember cracks burn whoever stands on them, foes too. Lure packs across!")
			elif not u.is_boss:
				run.damage(u, u.max_hp * EMBER_FOE, h, "Ember Cracks", "pure")


func _traps_tick(dt: float) -> void:
	var h := run.hero
	for tr in traps:
		tr["t"] += dt
		var per: float = tr["period"]
		var strike := 0.45 if tr["kind"] == "spikes" else 1.1
		var ph := fmod(float(tr["t"]), per)
		var st := "idle"
		if ph >= per - strike:
			st = "strike"
		elif ph >= per - strike - TRAP_WARN:
			st = "warn"
		if st != tr["state"]:
			tr["state"] = st
			tr["hit"] = {}
			tr["tick"] = 0.0
			var near := Vector2(h.pos.x - tr["to"].x, h.pos.z - tr["to"].z).length() < 22.0
			if Art.has_method("dungeon_trap_state"):
				Art.dungeon_trap_state(tr, st, near)
			if st == "warn":
				# the bot (and the danger area) know a strike is coming
				tr["hz"] = run.add_hazard({"type": "line", "from": tr["from"], "to": tr["to"], "width": CELL, "t": TRAP_WARN + strike})
			if st == "strike" and near:
				Audio.play("hit")
		if st != "strike":
			continue
		tr["tick"] -= dt
		var vent: bool = tr["kind"] == "vent"
		if vent:
			if tr["tick"] > 0.0:
				continue
			tr["tick"] = 0.25
		for u in _units_on(tr["cells"]):
			if not vent and tr["hit"].has(u.get_instance_id()):
				continue
			tr["hit"][u.get_instance_id()] = true
			if u is Hero:
				var hh := u as Hero
				if float(hh.item_stats.get("trapproof", 0.0)) > 0.0 or hh.dead:
					continue
				run.damage(hh, hh.max_hp * (VENT_HERO if vent else SPIKE_HERO), null, "Fire Vent" if vent else "Spike Trap", "pure")
				run.hint_once("delve_trap", "Traps strike on a beat and hurt foes too. Time your crossing, or lead a pack through.")
			elif u.is_boss:
				run.damage(u, u.max_hp * SPIKE_BOSS * (0.3 if vent else 1.0), h, "Spike Trap", "pure")
			else:
				run.damage(u, u.max_hp * (VENT_FOE if vent else SPIKE_FOE), h, "Fire Vent" if vent else "Spike Trap", "pure")


## Units standing on any of these cells (hero and allies, awake foes).
func _units_on(cells: Array) -> Array:
	var out := []
	var pool: Array = [run.hero]
	pool.append_array(run.companions)
	for e in run.enemies:
		if e.alive and e is Enemy and not (e as Enemy).dormant:
			pool.append(e)
	for u in pool:
		if not u.alive:
			continue
		var c := cell_of(u.pos)
		if c in cells:
			out.append(u)
	return out


# ---------------------------------------------------------------- the vault
## Sealed when the hero is well inside; foes crawl out of the walls in bursts; a relic when the last one falls.
func _vault_tick(h: Hero) -> void:
	if vault.is_empty():
		return
	var r: Rect2i = vault["rect"]
	match String(vault["state"]):
		"idle":
			if r.grow(-1).has_point(cell_of(h.pos)):
				_seal_vault()
		"sealed":
			var any := false
			for e in vault["units"]:
				if e.alive:
					any = true
			if any:
				return
			if int(vault["burst"]) < VAULT_BURSTS:
				_vault_burst()
			else:
				_open_vault()


func _log(ev: String) -> void:
	var lg: Array = run.get_meta("delve_log", [])
	lg.append("d%d %s" % [depth, ev])
	run.set_meta("delve_log", lg)
	Game.crumb("delve " + ev)


func _seal_vault() -> void:
	vault["state"] = "sealed"
	_log("vault sealed")
	for c in vault["doors"]:
		solid[c.y * W + c.x] = 1
		astar.set_point_solid(c, true)
	_paths.clear()
	# whoever stood in the doorway is pushed off the bars (in or out)
	var who: Array = [run.hero]
	who.append_array(run.companions)
	who.append_array(run.enemies)
	for u in who:
		if u.alive and is_solid(cell_of(u.pos)):
			u.pos = resolve(u, u.pos)
	light_room(int(vault["room"]), false)
	if Art.has_method("dungeon_vault_bars"):
		Art.dungeon_vault_bars(self, true)
	run.shake(0.4)
	Audio.play("boss")
	run.banner_requested.emit("The vault seals!", "Survive what crawls out of the walls")
	run.schedule(1.2, _vault_burst)


func _vault_burst() -> void:
	if vault.is_empty() or vault["state"] != "sealed":
		return
	vault["burst"] = int(vault["burst"]) + 1
	vault["units"] = []
	var kinds := []
	for b in DB.wave_bursts(wave):
		for k in b["units"]:
			kinds.append(k)
	if kinds.is_empty():
		kinds = ["gnawer"]
	var r: Rect2i = vault["rect"]
	var edge := []
	for c in _room_cells(r, 0):
		var cc: Vector2i = c
		if cc.x <= r.position.x + 1 or cc.y <= r.position.y + 1 or cc.x >= r.end.x - 2 or cc.y >= r.end.y - 2:
			edge.append(cc)
	if edge.is_empty():
		edge = _room_cells(r, 0)
	var n := 3 + depth / 3 + int(vault["burst"])
	for i in n:
		var c: Vector2i = edge[randi() % edge.size()]
		var p := cell_pos(c) + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		var e: Enemy = run.spawn_enemy(kinds[randi() % kinds.size()], p, wave)
		if i == 0 and int(vault["burst"]) == VAULT_BURSTS:
			run._roll_elite(e)
		e.retarget_t = randf() * 0.4
		vault["units"].append(e)
		run.fx("death_burst", {"pos": p, "size": 1.6, "color": Color(0.35, 0.3, 0.3)})
	run.shake(0.25)
	if int(vault["burst"]) > 1:
		run.toast(L.f("Wave %d of %d", [int(vault["burst"]), VAULT_BURSTS]), Art.palette.get("danger", Color.RED))


func _open_vault() -> void:
	vault["state"] = "done"
	for c in vault["doors"]:
		solid[c.y * W + c.x] = 0
		astar.set_point_solid(c, false)
	_paths.clear()
	if Art.has_method("dungeon_vault_bars"):
		Art.dungeon_vault_bars(self, false)
	_open_lid(vault["chest"]["node"])
	run.fx("ring_burst", {"pos": vault["chest"]["pos"], "radius": 3.0, "color": Color(1.0, 0.8, 0.3)})
	Audio.play("clear")
	offer_relic(L.t("The vault is yours"), Callable())


# ---------------------------------------------------------------- relics, stairs
## Pick 1 of 3 relics (pauses the game). then_cb runs after the pick.
func offer_relic(title: String, then_cb: Callable) -> void:
	Meta.offer_relics(run, L.t(title), L.t("Choose a relic. It lasts the whole run."), DelveLore.RELICS.keys(), _take_relic, then_cb, _bot_relic)


func _take_relic(id: String) -> void:
	if not DelveLore.RELICS.has(id) or id in run.hero.relics:
		return
	run.hero.relics.append(id)
	run.hero.recalc()
	_log("relic " + id)
	var rd: Dictionary = DelveLore.RELICS[id]
	run.fx("level_up", {"pos": run.hero.pos})
	run.toast(L.f("Relic: %s", [L.t(rd["name"])]), rd["color"])


func _bot_relic(ids: Array) -> String:
	for pref in ["vampire_fang", "gravebloom", "whetstone", "quicksand", "oathstone", "soul_jar"]:
		if pref in ids:
			return pref
	return ids[0]


## After a depth is cleared (not the last): a relic on boss depths, then the stairs: press on or rest in camp.
func after_clear() -> void:
	choosing = true
	if boss_kind(wave) != "":
		offer_relic(L.t("Boss slain"), _stairs)
	else:
		_stairs()


func _stairs() -> void:
	var next := mini(streak + 1, DelveLore.STREAK_MAX)
	var h := run.hero
	var opts := [
		{"id": "descend", "name": "Press on", "desc": L.f("Straight down to depth %d. No shop, no healing. Foes give +%d%% gold and xp while the streak lasts.", [depth + 1, int(round(next * DelveLore.STREAK_BONUS * 100))]),
			"icon": "speed", "color": Color(1.0, 0.55, 0.25)},
		{"id": "camp", "name": "Rest in camp", "desc": L.t("Back up to the camp: shop, fountain, full health. The streak ends."), "icon": "shop",
			"color": Color(0.5, 0.85, 0.6)},
	]
	var auto := "descend" if h.hp >= h.max_hp * 0.6 and streak < 2 else "camp"
	run.request_choice({"title": L.f("Depth %d cleared", [depth]), "sub": L.f("Streak: %d", [streak]) if streak > 0 else L.t("The stairs lead down. Press on, or rest?"),
		"options": opts, "auto": auto, "fallback": "camp"}, func(id: String):
			choosing = false
			_log("stairs " + id)
			if id == "descend":
				streak = next
				run.descend()
			else:
				streak = 0
				run.phase_t = 0.0)


# ---------------------------------------------------------------- minimap, bot
## Minimap: cells within sight of p are revealed.
func _reveal(p: Vector3) -> void:
	var c := cell_of(p)
	var rr := 7
	for dj in range(-rr, rr + 1):
		for di in range(-rr, rr + 1):
			var cc := c + Vector2i(di, dj)
			if in_grid(cc) and di * di + dj * dj <= rr * rr:
				seen[cc.y * W + cc.x] = 1


## Bot: where to head when nothing is awake. The nearest living dormant foe, unused shrine or the unopened vault,
## else the lair.
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
	var extra: Array = []
	for sh in shrines:
		if not sh["used"] and not DelveLore.SHRINES[sh["kind"]].has("cost"):
			extra.append(sh["pos"])
	if not vault.is_empty() and vault["state"] == "idle":
		extra.append(cell_pos(_center(vault["rect"])))
	for p in extra:
		var d2 := Vector2(p.x - from.x, p.z - from.z).length()
		if d2 < bd:
			bd = d2
			best = p
	return best


## Awake foes only: dormant ones don't count as "in the fight".
static func is_dormant(u: Unit) -> bool:
	return u is Enemy and (u as Enemy).dormant
