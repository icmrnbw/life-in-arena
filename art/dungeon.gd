extends RefCounted
## Delve mode's dungeon (the Undercroft), built from scripts/delve.gd's cell grid.
## Floor cells are flagstone quads; rock next to the floor is a block: tall where it backs the floor (north, east,
## west of it) and a low ledge where it sits between the floor and the camera (south), so walls never hide the fight.
## The level is cut into CHUNK x CHUNK cell meshes, each with its own copy of the world material holding the
## (up to 12) torch lights near it. Wells and chests are separate nodes so they can change when used.

const MK := preload("res://art/mesh_kit.gd")
const SH := preload("res://art/shaders.gd")
const World := preload("res://art/world.gd")

const CHUNK := 16
const WALL_H := 2.6
const LEDGE_H := 0.6


static func build(dv: Delve) -> Node3D:
	var root := Node3D.new()
	root.name = "Dungeon"
	dv.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = dv.wave * 7919 + 13
	var flames: Array = []
	var lights: Array = []   # Vector4(x, z, radius, intensity)
	var kits := {}           # chunk -> MK: torches and decor go into the chunk they stand in
	_torches(dv, rng, kits, flames, lights)
	_decor(dv, rng, kits)
	var stone := Color("5e5866"); var stone_top := Color("4a4552"); var ledge := Color("6a6472")
	var floor_a := Color(0.36, 0.32, 0.3); var floor_lair := Color(0.42, 0.24, 0.2)
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
					if not dv.is_solid(c):
						any = true
						var col := floor_lair if dv.lair.has_point(c) else floor_a
						col = col * (0.88 + 0.2 * rng.randf())
						col.a = 1.0
						k.cur_aux = 1.0
						var a := p + Vector3(-h, 0, -h); var b := p + Vector3(h, 0, -h)
						var cc := p + Vector3(h, 0, h); var d := p + Vector3(-h, 0, h)
						k.quad(a, b, cc, d, col, Vector3.UP, PackedVector2Array([Vector2(a.x, a.z) * 0.8, Vector2(b.x, b.z) * 0.8,
							Vector2(cc.x, cc.z) * 0.8, Vector2(d.x, d.z) * 0.8]))
						continue
					if not _touches_floor(dv, c):
						continue
					any = true
					k.cur_aux = 1.0
					if not dv.is_solid(c + Vector2i(0, -1)):
						# rock between the floor and the camera: a low ledge
						k.box(Vector3(Delve.CELL, LEDGE_H, Delve.CELL), p + Vector3(0, LEDGE_H * 0.5, 0), ledge)
					else:
						k.box(Vector3(Delve.CELL, WALL_H, Delve.CELL), p + Vector3(0, WALL_H * 0.5, 0), stone)
						k.cur_aux = 0.0
						k.box(Vector3(Delve.CELL + 0.1, 0.18, Delve.CELL + 0.1), p + Vector3(0, WALL_H + 0.09, 0), stone_top)
			if not any:
				continue
			var mi := MeshInstance3D.new()
			mi.name = "Chunk%d_%d" % [cx, cy]
			mi.mesh = k.build()
			var m: ShaderMaterial = (SH.mat("world") as ShaderMaterial).duplicate()
			SH.occluder_mats.append(m)
			var lo := Delve.ORIGIN + Vector3(cx * CHUNK * Delve.CELL, 0, cy * CHUNK * Delve.CELL)
			m.set_shader_parameter("lights", _lights_near(lights, Rect2(lo.x - 10.0, lo.z - 10.0, CHUNK * Delve.CELL + 20.0, CHUNK * Delve.CELL + 20.0)))
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
	_props(dv, root, lights)
	if not flames.is_empty():
		World._flames(root, flames)
		var fl := root.get_node_or_null("Flames")
		if fl is GeometryInstance3D:
			var size := Vector3(Delve.W * Delve.CELL, 20, Delve.H * Delve.CELL)
			(fl as GeometryInstance3D).custom_aabb = AABB(Delve.ORIGIN + Vector3(0, -5, 0), size)
	return root


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


## Braziers in room corners (lair: four big ones) and wall torches along the corridors.
static func _torches(dv: Delve, rng: RandomNumberGenerator, kits: Dictionary, flames: Array, lights: Array) -> void:
	for rm in dv.rooms:
		var r: Rect2i = rm["rect"]
		var lair: bool = rm["kind"] == "lair"
		var corners := [Vector2i(r.position.x, r.position.y), Vector2i(r.end.x - 1, r.position.y),
			Vector2i(r.position.x, r.end.y - 1), Vector2i(r.end.x - 1, r.end.y - 1)]
		for ci in corners.size():
			if not lair and ci >= 2 and rng.randf() < 0.6:
				continue
			var c: Vector2i = corners[ci]
			if dv.is_solid(c):
				continue
			var p := Delve.cell_pos(c)
			# tuck it into the corner
			p += Vector3(-0.35 if ci % 2 == 0 else 0.35, 0, -0.35 if ci < 2 else 0.35)
			World._brazier(_kit(kits, p), p, 1.1 if lair else 0.85, flames)
			lights.append(Vector4(p.x, p.z, 9.0 if lair else 7.5, 1.0 if lair else 0.85))
	# corridor torches: every few cells along corridor floor that hugs a tall wall
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
			if (q as Vector3).distance_to(p) < 9.0:
				far = false
				break
		if not far:
			continue
		placed.append(p)
		var tp := p + Vector3(0, 1.7, -Delve.CELL * 0.5 + 0.15)
		var k := _kit(kits, p)
		k.box(Vector3(0.12, 0.5, 0.12), tp + Vector3(0, -0.2, 0.05), Color("2a2626"))
		k.cyl(0.18, 0.1, 0.22, tp + Vector3(0, 0.1, 0.1), Color("8a5a2a"), Vector3.ZERO, -1, 6)
		flames.append([tp + Vector3(0, 0.22, 0.1), Vector2(0.7, 1.15)])
		lights.append(Vector4(p.x, p.z, 6.5, 0.8))


static func _in_room(dv: Delve, c: Vector2i) -> bool:
	for rm in dv.rooms:
		if (rm["rect"] as Rect2i).has_point(c):
			return true
	return false


## Bones, rubble and crates scattered along the room walls (looks only; nothing blocks).
static func _decor(dv: Delve, rng: RandomNumberGenerator, kits: Dictionary) -> void:
	var bone := Color("d8ccb0"); var rubble := Color("4e4856"); var wood := Color("6a4a2c")
	for rm in dv.rooms:
		var r: Rect2i = rm["rect"]
		for n in rng.randi_range(3, 6):
			var edge := rng.randi() % 3
			var c := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), r.position.y if edge == 0 else rng.randi_range(r.position.y, r.end.y - 1))
			if edge == 1:
				c.x = r.position.x
			elif edge == 2:
				c.x = r.end.x - 1
			if dv.is_solid(c):
				continue
			var p := Delve.cell_pos(c) + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			var k := _kit(kits, p)
			k.cur_aux = 0.0
			match rng.randi() % 3:
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
	# a glowing rune ring on the lair floor
	var lc := Delve.cell_pos(Delve._center(dv.lair))
	var k := _kit(kits, lc)
	k.cur_aux = 0.0
	k.torus(3.6, 3.9, lc + Vector3(0, 0.03, 0), Color("ff5a2a"), Vector3.ZERO, 1.6, 32, 3, Vector3(1, 0.05, 1))
	k.torus(2.2, 2.35, lc + Vector3(0, 0.03, 0), Color("ff5a2a"), Vector3.ZERO, 1.2, 24, 3, Vector3(1, 0.05, 1))


## Ember wells (heal once) and chests (gold once): their own nodes, so they can go dark / open.
static func _props(dv: Delve, root: Node3D, lights: Array) -> void:
	for wl in dv.wells:
		var wmat := _prop_mat(wl["pos"], lights)
		var n := Node3D.new()
		n.name = "Well"
		n.position = wl["pos"]
		root.add_child(n)
		var k := MK.new()
		k.cur_aux = 1.0
		k.cyl(1.0, 1.1, 0.7, Vector3(0, 0.35, 0), Color("6a6472"), Vector3.ZERO, -1, 12)
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
		var wmat := _prop_mat(ch["pos"], lights)
		var n := Node3D.new()
		n.name = "Chest"
		n.position = ch["pos"]
		root.add_child(n)
		var k := MK.new()
		k.cur_aux = 0.0
		k.box(Vector3(1.2, 0.6, 0.8), Vector3(0, 0.3, 0), Color("6a4226"))
		k.box(Vector3(1.26, 0.08, 0.86), Vector3(0, 0.5, 0), Color("d8a440"))
		var mi := MeshInstance3D.new()
		mi.mesh = k.build()
		mi.material_override = wmat
		n.add_child(mi)
		var lk := MK.new()
		lk.cur_aux = 0.0
		lk.cyl(0.42, 0.42, 1.2, Vector3.ZERO, Color("7a4c2c"), Vector3(0, 0, 90), -1, 8)
		lk.box(Vector3(0.14, 0.16, 0.12), Vector3(0, 0.05, 0.42), Color("f2c14e"), Vector3.ZERO, 1.2)
		var lid := MeshInstance3D.new()
		lid.name = "Lid"
		lid.mesh = lk.build()
		lid.material_override = wmat
		lid.position = Vector3(0, 0.62, 0)
		n.add_child(lid)
		ch["node"] = lid


static func _prop_mat(p: Vector3, lights: Array) -> ShaderMaterial:
	var m: ShaderMaterial = (SH.mat("world") as ShaderMaterial).duplicate()
	m.set_shader_parameter("lights", _lights_near(lights, Rect2(p.x - 8.0, p.z - 8.0, 16.0, 16.0)))
	return m
