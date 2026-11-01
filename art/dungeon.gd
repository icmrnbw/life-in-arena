extends RefCounted
## Delve mode's dungeon (the Undercroft), built from scripts/delve.gd's cell grid, in the look of the depth's tier
## (DelveLore.TIERS: Bone Crypt, Flooded Caverns, the Abyss).
## Floor cells are flagstone quads in the halls and rough rock in the caves; water glows faintly teal, ember cracks
## glow orange. Rock next to the floor is a block: tall where it backs the floor (north, east, west of it), ragged in
## the caves, and a low ledge where it sits between the floor and the camera (south), so walls never hide the fight.
## The level is cut into CHUNK x CHUNK cell meshes, each with its own copy of the world material holding the (up to
## 12) lights near it. Everything is dark until lit: the world shader multiplies by the Delve light map, and a
## room's brazier flames are only added (light_room) when the hero lights its beacon. Corridor torches always burn.
## Wells, chests, shrines, beacons, traps and the vault's bars are separate nodes so they can change.

const MK := preload("res://art/mesh_kit.gd")
const SH := preload("res://art/shaders.gd")
const World := preload("res://art/world.gd")

const CHUNK := 16
const WALL_H := 2.6
const LEDGE_H := 0.6

const EYES_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
varying float seed;
void vertex() {
	seed = MODEL_MATRIX[3].x * 1.37 + MODEL_MATRIX[3].z * 2.11;
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 wpos = MODEL_MATRIX[3].xyz + (right * VERTEX.x + up * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wpos, 1.0);
}
void fragment() {
	float a = 0.0;
	for (int i = 0; i < 2; i++) {
		vec2 c = vec2(i == 0 ? 0.3 : 0.7, 0.5);
		vec2 q = (UV - c) * vec2(6.5, 11.0);
		q.y += (i == 0 ? 1.0 : -1.0) * q.x * 0.35;
		float d = length(q);
		a += (1.0 - smoothstep(0.35, 1.0, d)) + 0.25 * (1.0 - smoothstep(0.0, 2.6, d));
	}
	float blink = step(0.05, fract(TIME * 0.21 + seed));
	ALBEDO = COLOR.rgb * a * 2.2 * blink;
}
"""


static func build(dv: Delve) -> Node3D:
	var root := Node3D.new()
	root.name = "Dungeon"
	dv.add_child(root)
	var td: Dictionary = DelveLore.tier(dv.depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = dv.wave * 7919 + 13
	var flames: Array = []   # always burning: corridor torches
	var lights: Array = []   # Vector4(x, z, radius, intensity), gated by the light map in the shader
	var kits := {}           # chunk -> MK: torches and decor go into the chunk they stand in
	_torches(dv, rng, kits, flames, lights, td)
	_decor(dv, rng, kits, td)
	var stone: Color = td["wall"]; var stone_top: Color = td["wall_top"]; var ledge: Color = td["ledge"]
	var floor_a: Color = td["floor"]; var floor_cave: Color = td["floor_cave"]; var floor_lair: Color = td["lair"]
	var nx := ceili(float(Delve.W) / CHUNK)
	var ny := ceili(float(Delve.H) / CHUNK)
	for cy in ny:
		for cx in nx:
			var k: MK = kits.get(Vector2i(cx, cy), MK.new())
			var any: bool = kits.has(Vector2i(cx, cy))
			for j in range(cy * CHUNK, mini((cy + 1) * CHUNK, Delve.H)):
				for i in range(cx * CHUNK, mini((cx + 1) * CHUNK, Delve.W)):
					var c := Vector2i(i, j)
					var p := Delve.cell_pos(c)
					var h := Delve.CELL * 0.5
					var idx := j * Delve.W + i
					if not dv.is_solid(c):
						any = true
						_floor_cell(k, dv, c, p, h, rng, floor_lair if dv.lair.has_point(c) else (floor_cave if dv.cave[idx] == 1 else floor_a))
						continue
					if not _touches_floor(dv, c):
						continue
					any = true
					var rough := _near_cave(dv, c)
					k.cur_aux = 0.0 if rough else 1.0
					k.cur_emis = 0.0
					if not dv.is_solid(c + Vector2i(0, -1)):
						# rock between the floor and the camera: a low ledge
						var lh := LEDGE_H * (rng.randf_range(0.7, 1.4) if rough else 1.0)
						k.box(Vector3(Delve.CELL, lh, Delve.CELL), p + Vector3(0, lh * 0.5, 0), ledge)
					elif rough:
						# ragged cave rock: uneven heights, a boulder or two at the foot
						var wh := rng.randf_range(2.2, 3.7)
						var off := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
						k.box(Vector3(Delve.CELL + 0.3, wh, Delve.CELL + 0.3), p + off + Vector3(0, wh * 0.5, 0), stone, Vector3(0, rng.randf_range(-8, 8), 0))
						k.ball(rng.randf_range(0.5, 0.9), p + off + Vector3(rng.randf_range(-0.6, 0.6), wh, rng.randf_range(-0.6, 0.6)), stone_top,
							Vector3(1.2, 0.7, 1.1), Vector3(0, rng.randf() * 90.0, 0), -1, 7, 4)
						if rng.randf() < 0.5:
							k.ball(rng.randf_range(0.35, 0.6), p + Vector3(rng.randf_range(-0.8, 0.8), 0.2, Delve.CELL * 0.5 + 0.1), stone.darkened(0.15),
								Vector3(1.2, 0.8, 1.0), Vector3.ZERO, -1, 6, 4)
					else:
						k.box(Vector3(Delve.CELL, WALL_H, Delve.CELL), p + Vector3(0, WALL_H * 0.5, 0), stone)
						k.cur_aux = 0.0
						k.box(Vector3(Delve.CELL + 0.1, 0.18, Delve.CELL + 0.1), p + Vector3(0, WALL_H + 0.09, 0), stone_top)
			if not any:
				continue
			var mi := MeshInstance3D.new()
			mi.name = "Chunk%d_%d" % [cx, cy]
			mi.mesh = k.build()
			var m := _mat(td)
			SH.occluder_mats.append(m)
			var lo := Delve.ORIGIN + Vector3(cx * CHUNK * Delve.CELL, 0, cy * CHUNK * Delve.CELL)
			m.set_shader_parameter("lights", _lights_near(lights, Rect2(lo.x - 10.0, lo.z - 10.0, CHUNK * Delve.CELL + 20.0, CHUNK * Delve.CELL + 20.0)))
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
	_props(dv, root, lights, td)
	_traps(dv, root, lights, td)
	_vault(dv, root, lights)
	if not flames.is_empty():
		_flames(root, flames, td, "Flames")
	_eyes(root)
	dv._push_light()
	return root


static func _mat(td: Dictionary) -> ShaderMaterial:
	var m: ShaderMaterial = (SH.mat("world") as ShaderMaterial).duplicate()
	var lc: Color = td["light"]
	m.set_shader_parameter("light_col", Vector3(lc.r, lc.g, lc.b))
	m.set_shader_parameter("rim_color", Color(lc.r * 0.5, lc.g * 0.5, lc.b * 0.6, 1.0))
	# big square flagstones and wall blocks, not the arena's small bricks
	m.set_shader_parameter("brick_w", 1.6)
	m.set_shader_parameter("brick_h", 1.25)
	return m


## One floor cell: flagstones in the halls, rough rock in the caves, water or ember cracks on top.
static func _floor_cell(k: MK, dv: Delve, c: Vector2i, p: Vector3, h: float, rng: RandomNumberGenerator, col: Color) -> void:
	var idx := c.y * Delve.W + c.x
	var t := dv.terrain[idx]
	col = col * (0.85 + 0.25 * rng.randf())
	col.a = 1.0
	k.cur_aux = 0.0 if dv.cave[idx] == 1 else 1.0
	k.cur_emis = 0.0
	if t == 1:
		col = Color(0.09, 0.24, 0.26)
		k.cur_aux = 0.0
		k.cur_emis = 0.06
	elif t == 2:
		col = Color(0.1, 0.05, 0.045)
		k.cur_aux = 0.0
	var a := p + Vector3(-h, 0, -h); var b := p + Vector3(h, 0, -h)
	var cc := p + Vector3(h, 0, h); var d := p + Vector3(-h, 0, h)
	k.quad(a, b, cc, d, col, Vector3.UP, PackedVector2Array([Vector2(a.x, a.z) * 0.8, Vector2(b.x, b.z) * 0.8,
		Vector2(cc.x, cc.z) * 0.8, Vector2(d.x, d.z) * 0.8]))
	k.cur_emis = 0.0
	if t == 2:
		# glowing cracks
		for n in 2:
			var ang := rng.randf() * 180.0
			k.box(Vector3(rng.randf_range(1.0, 1.9), 0.04, rng.randf_range(0.08, 0.16)), p + Vector3(rng.randf_range(-0.4, 0.4), 0.02, rng.randf_range(-0.4, 0.4)),
				Color(1.0, 0.32, 0.06), Vector3(0, ang, 0), 2.4)
	elif t == 1 and rng.randf() < 0.1:
		k.ball(0.12, p + Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6)), Color(0.2, 0.7, 0.6), Vector3(1, 0.15, 1), Vector3.ZERO, 0.7, 6, 3)
	k.cur_aux = 1.0


## The mesh kit of the chunk that world point p falls in.
static func _kit(kits: Dictionary, p: Vector3) -> MK:
	var c := Delve.cell_of(p)
	var key := Vector2i(clampi(c.x, 0, Delve.W - 1) / CHUNK, clampi(c.y, 0, Delve.H - 1) / CHUNK)
	if not kits.has(key):
		kits[key] = MK.new()
	return kits[key]


static func _touches_floor(dv: Delve, c: Vector2i) -> bool:
	for dj in range(-1, 2):
		for di in range(-1, 2):
			if (di != 0 or dj != 0) and not dv.is_solid(c + Vector2i(di, dj)):
				return true
	return false


static func _near_cave(dv: Delve, c: Vector2i) -> bool:
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var cc := c + Vector2i(di, dj)
			if Delve.in_grid(cc) and dv.cave[cc.y * Delve.W + cc.x] == 1:
				return true
	return false


## The 12 lights nearest the chunk (padded with off lights).
static func _lights_near(lights: Array, area: Rect2) -> PackedVector4Array:
	var mid := area.get_center()
	var near: Array = []
	for l in lights:
		if area.grow(l.z).has_point(Vector2(l.x, l.y)):
			near.append(l)
	near.sort_custom(func(a, b): return Vector2(a.x, a.y).distance_to(mid) < Vector2(b.x, b.y).distance_to(mid))
	var out := PackedVector4Array()
	for l in near.slice(0, 12):
		out.append(l)
	while out.size() < 12:
		out.append(Vector4(0, 0, 1, 0))
	return out


## Unlit braziers in room corners (lair: four big ones) and a beacon in the middle of each room; their flames are
## kept per room for light_room(). Sparse wall torches along the corridors always burn.
static func _torches(dv: Delve, rng: RandomNumberGenerator, kits: Dictionary, flames: Array, lights: Array, td: Dictionary) -> void:
	for ri in dv.rooms.size():
		var rm: Dictionary = dv.rooms[ri]
		var r: Rect2i = rm["rect"]
		var lair: bool = rm["kind"] == "lair"
		var rf: Array = []
		var corners := [Vector2i(r.position.x, r.position.y), Vector2i(r.end.x - 1, r.position.y),
			Vector2i(r.position.x, r.end.y - 1), Vector2i(r.end.x - 1, r.end.y - 1)]
		if rm["cave"]:
			corners = [r.position + Vector2i(2, 2), Vector2i(r.end.x - 3, r.position.y + 2)]
		for ci in corners.size():
			if not lair and ci >= 2 and rng.randf() < 0.6:
				continue
			var c: Vector2i = corners[ci]
			if dv.is_solid(c):
				continue
			var p := Delve.cell_pos(c)
			if not rm["cave"]:
				p += Vector3(-0.35 if ci % 2 == 0 else 0.35, 0, -0.35 if ci < 2 else 0.35)
			_brazier(_kit(kits, p), p, 1.1 if lair else 0.85, rf)
			lights.append(Vector4(p.x, p.z, 9.0 if lair else 7.5, 1.0 if lair else 0.85))
		var b: Vector3 = rm["beacon"]
		if b != Vector3.ZERO:
			_beacon(_kit(kits, b), b, rf)
			lights.append(Vector4(b.x, b.z, 8.0, 0.9))
		rm["flames"] = rf
	# corridor torches: every so often along corridor floor that hugs a tall wall; they light a patch round them
	var placed: Array = []
	for c in dv._corr.keys():
		var cell: Vector2i = c
		if dv.is_solid(cell) or _in_room(dv, cell):
			continue
		var north := cell + Vector2i(0, -1)
		if not dv.is_solid(north):
			continue
		var p := Delve.cell_pos(cell)
		var far := true
		for q in placed:
			if (q as Vector3).distance_to(p) < 15.0:
				far = false
				break
		if not far:
			continue
		placed.append(p)
		var tp := p + Vector3(0, 1.7, -Delve.CELL * 0.5 + 0.15)
		var k := _kit(kits, p)
		k.box(Vector3(0.12, 0.5, 0.12), tp + Vector3(0, -0.2, 0.05), Color("2a2626"))
		k.cyl(0.18, 0.1, 0.22, tp + Vector3(0, 0.1, 0.1), Color("5a4a3a"), Vector3.ZERO, -1, 6)
		flames.append([tp + Vector3(0, 0.22, 0.1), Vector2(0.7, 1.15)])
		lights.append(Vector4(p.x, p.z, 6.0, 0.7))
		for dj in range(-2, 3):
			for di in range(-2, 3):
				var cc := cell + Vector2i(di, dj)
				if Delve.in_grid(cc) and di * di + dj * dj <= 5:
					var ii := cc.y * Delve.W + cc.x
					dv.lit[ii] = maxi(dv.lit[ii], 100 if di * di + dj * dj <= 2 else 60)


## An iron brazier with a cold, dark bowl (it lights with its room).
static func _brazier(k: MK, c: Vector3, s: float, rf: Array) -> void:
	var iron := Color("2a2626"); var bronze := Color("5a4a3c")
	k.cur_aux = 0.0
	k.cyl(0.14 * s, 0.22 * s, 1.1 * s, c + Vector3(0, 0.55 * s, 0), iron)
	for i in 3:
		var a := TAU * i / 3.0
		k.spike(c + Vector3(cos(a) * 0.1, 0.6, sin(a) * 0.1) * s, c + Vector3(cos(a) * 0.45, 0.0, sin(a) * 0.45) * s, 0.06 * s, iron, -1, 4)
	k.cyl(0.55 * s, 0.3 * s, 0.32 * s, c + Vector3(0, 1.2 * s, 0), bronze, Vector3.ZERO, -1, 10)
	k.cyl(0.48 * s, 0.48 * s, 0.05 * s, c + Vector3(0, 1.34 * s, 0), Color("1a1414"), Vector3.ZERO, 0.0, 10)
	rf.append([c + Vector3(0, 1.3 * s, 0), Vector2(1.0, 1.7) * s])
	k.cur_aux = 1.0


## The room's beacon: a wide stone fire bowl on a plinth with a faint ember in it (so it can be found in the dark).
static func _beacon(k: MK, c: Vector3, rf: Array) -> void:
	k.cur_aux = 0.0
	k.cyl(0.75, 0.9, 0.35, c + Vector3(0, 0.17, 0), Color("4a4650"), Vector3.ZERO, -1, 8)
	k.cyl(0.32, 0.42, 0.8, c + Vector3(0, 0.75, 0), Color("3a3640"), Vector3.ZERO, -1, 8)
	k.cyl(0.8, 0.45, 0.35, c + Vector3(0, 1.3, 0), Color("4e4048"), Vector3.ZERO, -1, 10)
	k.cyl(0.7, 0.7, 0.04, c + Vector3(0, 1.46, 0), Color(0.9, 0.3, 0.08), Vector3.ZERO, 0.35, 10)
	rf.append([c + Vector3(0, 1.4, 0), Vector2(1.3, 2.0)])
	k.cur_aux = 1.0


static func _in_room(dv: Delve, c: Vector2i) -> bool:
	for rm in dv.rooms:
		if (rm["rect"] as Rect2i).has_point(c):
			return true
	return false


## Flames (and sparks) for a list of [pos, size]; tinted to the tier's fire.
static func _flames(parent: Node3D, list: Array, td: Dictionary, nm: String) -> void:
	var holder := Node3D.new()
	holder.name = nm
	parent.add_child(holder)
	World._flames(holder, list)
	var fm: ShaderMaterial = (SH.mat("flame") as ShaderMaterial).duplicate()
	fm.set_shader_parameter("col_hot", td["flame_hot"])
	fm.set_shader_parameter("col_cool", td["flame_cool"])
	for ch in holder.get_children():
		if ch is MultiMeshInstance3D:
			(ch as MultiMeshInstance3D).material_override = fm
			(ch as GeometryInstance3D).custom_aabb = AABB(Delve.ORIGIN + Vector3(0, -5, 0), Vector3(Delve.W * Delve.CELL, 20, Delve.H * Delve.CELL))
		elif ch is CPUParticles3D:
			var hot: Color = td["flame_hot"]
			var cool: Color = td["flame_cool"]
			(ch as CPUParticles3D).color_ramp = World._ramp(Color(hot.r, hot.g, hot.b, 1.0), Color(cool.r, cool.g, cool.b, 0.0))


## A room catches light: its braziers and beacon burn.
static func light_room(dv: Delve, i: int) -> void:
	if dv.vis == null or not is_instance_valid(dv.vis):
		return
	var rf: Array = dv.rooms[i].get("flames", [])
	if rf.is_empty():
		return
	_flames(dv.vis, rf, DelveLore.tier(dv.depth), "RoomFire%d" % i)


## Bones, rubble and crates (crypt: sarcophagi too; caverns: stalagmites; abyss: obsidian shards). Looks only.
static func _decor(dv: Delve, rng: RandomNumberGenerator, kits: Dictionary, td: Dictionary) -> void:
	var bone := Color("c8bea4"); var rubble: Color = (td["wall"] as Color).lightened(0.05); var wood := Color("4a3a2a")
	var tid: String = td["id"]
	for rm in dv.rooms:
		var r: Rect2i = rm["rect"]
		for n in rng.randi_range(4, 7):
			var edge := rng.randi() % 3
			var c := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), r.position.y if edge == 0 else rng.randi_range(r.position.y, r.end.y - 1))
			if edge == 1:
				c.x = r.position.x
			elif edge == 2:
				c.x = r.end.x - 1
			if rm["cave"]:
				var mc := Delve._center(r)
				c = Vector2i(roundi(lerpf(c.x, mc.x, 0.25)), roundi(lerpf(c.y, mc.y, 0.25)))
			if dv.is_solid(c) or dv.terrain[c.y * Delve.W + c.x] != 0:
				continue
			var p := Delve.cell_pos(c) + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			if p.distance_to(rm["beacon"]) < 1.8:
				continue
			var k := _kit(kits, p)
			k.cur_aux = 0.0
			var pick := rng.randi() % 4
			if pick == 3:
				match tid:
					"crypt":
						# a sarcophagus
						var rot := Vector3(0, 90.0 * (rng.randi() % 2), 0)
						k.box(Vector3(1.0, 0.6, 2.0), p + Vector3(0, 0.3, 0), Color("5a5866"), rot)
						k.box(Vector3(1.1, 0.14, 2.1), p + Vector3(0, 0.67, 0), Color("6a6876"), rot)
						k.box(Vector3(0.3, 0.06, 1.2), p + Vector3(0, 0.76, 0), Color(0.5, 0.65, 0.9), rot, 0.5)
					"flooded":
						for s in 3:
							k.cone(rng.randf_range(0.25, 0.45), rng.randf_range(0.8, 1.8), p + Vector3(rng.randf_range(-0.6, 0.6), 0.5, rng.randf_range(-0.6, 0.6)),
								Color("3e4e4a"), Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)))
						k.ball(0.35, p + Vector3(0.3, 0.1, -0.2), Color(0.2, 0.45, 0.3), Vector3(1.3, 0.4, 1.0))
					_:
						for s in 3:
							var h := rng.randf_range(0.7, 1.6)
							k.cone(rng.randf_range(0.18, 0.32), h, p + Vector3(rng.randf_range(-0.6, 0.6), h * 0.5, rng.randf_range(-0.6, 0.6)),
								Color("1a1418"), Vector3(rng.randf_range(-15, 15), rng.randf() * 90.0, rng.randf_range(-15, 15)))
						k.ball(0.12, p + Vector3(0, 0.05, 0), Color(1.0, 0.35, 0.08), Vector3(1.4, 0.3, 1.0), Vector3.ZERO, 2.0, 6, 3)
				continue
			match pick:
				0:
					for b in 3:
						k.cyl(0.05, 0.05, 0.7, p + Vector3(rng.randf_range(-0.4, 0.4), 0.05, rng.randf_range(-0.4, 0.4)), bone,
							Vector3(90, rng.randf() * 180.0, 0), -1, 5)
					k.ball(0.16, p + Vector3(0.2, 0.14, 0.1), bone, Vector3.ONE, Vector3.ZERO, -1, 7, 4)
				1:
					for b in 4:
						k.box(Vector3(0.5, 0.35, 0.45) * rng.randf_range(0.6, 1.3), p + Vector3(rng.randf_range(-0.6, 0.6), 0.15, rng.randf_range(-0.6, 0.6)),
							rubble, Vector3(rng.randf() * 30.0, rng.randf() * 90.0, rng.randf() * 30.0))
				2:
					k.box(Vector3(0.8, 0.7, 0.8), p + Vector3(0, 0.35, 0), wood, Vector3(0, rng.randf() * 90.0, 0))
					k.box(Vector3(0.6, 0.5, 0.6), p + Vector3(0.1, 0.95, 0.05), wood.darkened(0.15), Vector3(0, rng.randf() * 90.0, 0))
	# a glowing rune ring on the lair floor, in the tier's colour
	var lc := Delve.cell_pos(Delve._center(dv.lair))
	var k := _kit(kits, lc)
	k.cur_aux = 0.0
	k.torus(3.6, 3.9, lc + Vector3(0, 0.03, 0), td["rune"], Vector3.ZERO, 1.6, 32, 3, Vector3(1, 0.05, 1))
	k.torus(2.2, 2.35, lc + Vector3(0, 0.03, 0), td["rune"], Vector3.ZERO, 1.2, 24, 3, Vector3(1, 0.05, 1))


## Ember wells (heal once), chests (gold once) and shrines (a blessing): their own nodes, so they can change.
static func _props(dv: Delve, root: Node3D, lights: Array, td: Dictionary) -> void:
	for wl in dv.wells:
		var wmat := _prop_mat(wl["pos"], lights, td)
		var n := Node3D.new()
		n.name = "Well"
		n.position = wl["pos"]
		root.add_child(n)
		var k := MK.new()
		k.cur_aux = 1.0
		k.cyl(1.0, 1.1, 0.7, Vector3(0, 0.35, 0), Color("5a5662"), Vector3.ZERO, -1, 12)
		k.cur_aux = 0.0
		k.cyl(0.8, 0.8, 0.05, Vector3(0, 0.72, 0), Color("2a1a10"), Vector3.ZERO, -1, 12)
		var mi := MeshInstance3D.new()
		mi.mesh = k.build()
		mi.material_override = wmat
		n.add_child(mi)
		var gk := MK.new()
		gk.cur_aux = 0.0
		gk.cyl(0.78, 0.78, 0.04, Vector3(0, 0.76, 0), Color("ff9a3a"), Vector3.ZERO, 2.4, 12)
		var glow := MeshInstance3D.new()
		glow.name = "Glow"
		glow.mesh = gk.build()
		glow.material_override = wmat
		n.add_child(glow)
		wl["node"] = glow
	for ch in dv.chests:
		ch["node"] = _chest(root, ch["pos"], _prop_mat(ch["pos"], lights, td))
	for sh in dv.shrines:
		var sd: Dictionary = DelveLore.SHRINES[sh["kind"]]
		var col: Color = sd["color"]
		var smat := _prop_mat(sh["pos"], lights, td)
		var n := Node3D.new()
		n.name = "Shrine"
		n.position = sh["pos"]
		root.add_child(n)
		var k := MK.new()
		k.cur_aux = 1.0
		k.box(Vector3(2.0, 0.3, 2.0), Vector3(0, 0.15, 0), Color("4a4652"))
		k.box(Vector3(1.4, 0.25, 1.4), Vector3(0, 0.42, 0), Color("55515e"))
		k.cur_aux = 0.0
		k.box(Vector3(0.7, 2.2, 0.5), Vector3(0, 1.6, 0), Color("3c3844"))
		k.prism(Vector3(0.7, 0.5, 0.5), Vector3(0, 2.95, 0), Color("3c3844"))
		var mi := MeshInstance3D.new()
		mi.mesh = k.build()
		mi.material_override = smat
		n.add_child(mi)
		var gk := MK.new()
		gk.cur_aux = 0.0
		gk.box(Vector3(0.12, 1.2, 0.04), Vector3(0, 1.7, 0.26), col, Vector3.ZERO, 2.6)
		gk.box(Vector3(0.5, 0.1, 0.04), Vector3(0, 1.95, 0.26), col, Vector3.ZERO, 2.6)
		gk.ball(0.22, Vector3(0, 3.4, 0), col, Vector3.ONE, Vector3.ZERO, 3.0, 8, 5)
		gk.torus(1.05, 1.15, Vector3(0, 0.56, 0), col, Vector3.ZERO, 1.4, 20, 3, Vector3(1, 0.1, 1))
		var glow := MeshInstance3D.new()
		glow.name = "Glow"
		glow.mesh = gk.build()
		glow.material_override = smat
		n.add_child(glow)
		sh["node"] = n


static func _chest(root: Node3D, pos: Vector3, wmat: ShaderMaterial) -> Node3D:
	var n := Node3D.new()
	n.name = "Chest"
	n.position = pos
	root.add_child(n)
	var k := MK.new()
	k.cur_aux = 0.0
	k.box(Vector3(1.2, 0.6, 0.8), Vector3(0, 0.3, 0), Color("6a4226"))
	k.box(Vector3(1.26, 0.08, 0.86), Vector3(0, 0.5, 0), Color("d8a440"), Vector3.ZERO, 0.4)
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	mi.material_override = wmat
	n.add_child(mi)
	var lk := MK.new()
	lk.cur_aux = 0.0
	lk.cyl(0.42, 0.42, 1.2, Vector3.ZERO, Color("7a4c2c"), Vector3(0, 0, 90), -1, 8)
	lk.box(Vector3(0.14, 0.16, 0.12), Vector3(0, 0.05, 0.42), Color("f2c14e"), Vector3.ZERO, 1.6)
	var lid := MeshInstance3D.new()
	lid.name = "Lid"
	lid.mesh = lk.build()
	lid.material_override = wmat
	lid.position = Vector3(0, 0.62, 0)
	n.add_child(lid)
	return lid


## Spike rows (iron plates with spikes under them) and fire vents (grates over a glow).
static func _traps(dv: Delve, root: Node3D, lights: Array, td: Dictionary) -> void:
	for tr in dv.traps:
		var n := Node3D.new()
		n.name = "Trap"
		root.add_child(n)
		var mid: Vector3 = Delve.cell_pos(tr["cells"][1])
		n.position = mid
		var mat := _prop_mat(mid, lights, td)
		var base := MK.new()
		base.cur_aux = 0.0
		var spikes := MK.new()
		spikes.cur_aux = 0.0
		var glowk := MK.new()
		glowk.cur_aux = 0.0
		var vent: bool = tr["kind"] == "vent"
		for c in tr["cells"]:
			var lp: Vector3 = Delve.cell_pos(c) - mid
			base.box(Vector3(1.85, 0.06, 1.85), lp + Vector3(0, 0.03, 0), Color("2a2828"))
			for sx in [-0.7, 0.7]:
				for sz in [-0.7, 0.7]:
					base.ball(0.06, lp + Vector3(sx, 0.07, sz), Color("5a5050"), Vector3(1, 0.5, 1), Vector3.ZERO, -1, 5, 3)
			if vent:
				for g in 4:
					base.box(Vector3(1.5, 0.08, 0.1), lp + Vector3(0, 0.07, -0.55 + g * 0.37), Color("1a1616"))
				glowk.box(Vector3(1.5, 0.02, 1.4), lp + Vector3(0, 0.04, 0), Color(1.0, 0.35, 0.08), Vector3.ZERO, 0.9)
			else:
				for gx in 3:
					for gz in 3:
						var sp := lp + Vector3(-0.55 + gx * 0.55, 0, -0.55 + gz * 0.55)
						base.box(Vector3(0.12, 0.02, 0.12), sp + Vector3(0, 0.065, 0), Color("0a0808"))
						spikes.cone(0.1, 0.65, sp + Vector3(0, 0.32, 0), Color("8a8a92"), Vector3.ZERO, -1, 5)
				glowk.box(Vector3(1.7, 0.02, 0.06), lp + Vector3(0, 0.07, 0.85), Color(1.0, 0.2, 0.1), Vector3.ZERO, 1.2)
				glowk.box(Vector3(1.7, 0.02, 0.06), lp + Vector3(0, 0.07, -0.85), Color(1.0, 0.2, 0.1), Vector3.ZERO, 1.2)
		var bm := MeshInstance3D.new()
		bm.mesh = base.build()
		bm.material_override = mat
		n.add_child(bm)
		var gm := MeshInstance3D.new()
		gm.name = "Glow"
		gm.mesh = glowk.build()
		gm.material_override = mat
		gm.visible = not vent
		n.add_child(gm)
		if not vent:
			var sm := MeshInstance3D.new()
			sm.name = "Spikes"
			sm.mesh = spikes.build()
			sm.material_override = mat
			sm.position.y = -0.75
			n.add_child(sm)
		else:
			var fire := CPUParticles3D.new()
			fire.name = "Fire"
			fire.emitting = false
			fire.amount = 40
			fire.lifetime = 0.7
			fire.mesh = World._quad()
			fire.material_override = SH.mat("particle_add")
			fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			var along: Vector3 = (Delve.cell_pos(tr["cells"][2]) - Delve.cell_pos(tr["cells"][0])).abs()
			fire.emission_box_extents = Vector3(maxf(along.x * 0.5 + 0.7, 0.7), 0.1, maxf(along.z * 0.5 + 0.7, 0.7))
			fire.direction = Vector3.UP
			fire.spread = 12.0
			fire.gravity = Vector3(0, 2.0, 0)
			fire.initial_velocity_min = 3.0
			fire.initial_velocity_max = 5.5
			fire.scale_amount_min = 0.35
			fire.scale_amount_max = 0.7
			fire.color_ramp = World._ramp(Color(1.0, 0.8, 0.3, 1.0), Color(1.0, 0.15, 0.02, 0.0))
			n.add_child(fire)
		tr["node"] = n


## A trap changes state: spikes peek on the warning and shoot up on the strike; vents glow, then blaze.
static func trap_state(tr: Dictionary, st: String, near: bool) -> void:
	var n = tr.get("node")
	if not (n is Node3D) or not is_instance_valid(n):
		return
	var nd := n as Node3D
	var sp := nd.get_node_or_null("Spikes") as Node3D
	if sp:
		var y := -0.75
		if st == "warn":
			y = -0.5
		elif st == "strike":
			y = 0.0
		if near and st != "idle":
			var tw := nd.create_tween()
			tw.tween_property(sp, "position:y", y, 0.06 if st == "strike" else 0.15)
		else:
			sp.position.y = y
	var g := nd.get_node_or_null("Glow") as Node3D
	var fire := nd.get_node_or_null("Fire") as CPUParticles3D
	if fire:
		g.visible = st != "idle"
		fire.emitting = st == "strike" and near


## The vault's iron bars over its doorway cells (hidden until it seals) and its relic chest.
static func _vault(dv: Delve, root: Node3D, lights: Array) -> void:
	if dv.vault.is_empty():
		return
	var td := DelveLore.tier(dv.depth)
	var r: Rect2i = dv.vault["rect"]
	var cpos: Vector3 = dv.vault["chest"]["pos"]
	var cm := _prop_mat(cpos, lights, td)
	var lid := _chest(root, cpos, cm)
	lid.get_parent().scale = Vector3.ONE * 1.3
	dv.vault["chest"]["node"] = lid
	# gold trim on the floor: this room is different
	var fk := MK.new()
	fk.cur_aux = 0.0
	var rc := Delve.cell_pos(Delve._center(r))
	fk.torus(2.4, 2.6, Vector3.ZERO, Color(1.0, 0.75, 0.3), Vector3.ZERO, 1.0, 28, 3, Vector3(1, 0.05, 1))
	var fm := MeshInstance3D.new()
	fm.mesh = fk.build()
	fm.material_override = cm
	fm.position = rc + Vector3(0, 0.03, 0)
	root.add_child(fm)
	var bk := MK.new()
	bk.cur_aux = 0.0
	for c in dv.vault["doors"]:
		var p: Vector3 = Delve.cell_pos(c)
		var along_x: bool = dv.vault["doors"].has(c + Vector2i(1, 0)) or dv.vault["doors"].has(c - Vector2i(1, 0))
		for b in 5:
			var o := -0.8 + b * 0.4
			var off := Vector3(o, 0, 0) if along_x else Vector3(0, 0, o)
			bk.cyl(0.07, 0.07, 2.6, p + off + Vector3(0, 1.3, 0), Color("3a3434"), Vector3.ZERO, -1, 6)
		var bar := Vector3(2.0, 0.15, 0.15) if along_x else Vector3(0.15, 0.15, 2.0)
		bk.box(bar, p + Vector3(0, 2.4, 0), Color("4a4040"))
		bk.box(bar * Vector3(1, 0.5, 1) if along_x else bar * Vector3(1, 0.5, 1), p + Vector3(0, 0.5, 0), Color(1.0, 0.6, 0.2), Vector3.ZERO, 1.5)
	var bars := MeshInstance3D.new()
	bars.name = "VaultBars"
	bars.mesh = bk.build()
	bars.material_override = _prop_mat(rc, lights, td)
	bars.visible = false
	root.add_child(bars)
	dv.vault["bars"] = bars


static func vault_bars(dv: Delve, on: bool) -> void:
	var b = dv.vault.get("bars")
	if b is Node3D and is_instance_valid(b):
		(b as Node3D).visible = on


## Glowing eyes for foes out in the dark (Delve._eyes_tick fills the instances).
static func _eyes(root: Node3D) -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(0.6, 0.3)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = qm
	mm.instance_count = 64
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = "Eyes"
	mi.multimesh = mm
	var sm := ShaderMaterial.new()
	var s := Shader.new()
	s.code = EYES_SHADER
	sm.shader = s
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Delve.ORIGIN + Vector3(0, -5, 0), Vector3(Delve.W * Delve.CELL, 20, Delve.H * Delve.CELL))
	root.add_child(mi)


static func _prop_mat(p: Vector3, lights: Array, td: Dictionary) -> ShaderMaterial:
	var m := _mat(td)
	m.set_shader_parameter("lights", _lights_near(lights, Rect2(p.x - 8.0, p.z - 8.0, 16.0, 16.0)))
	return m
