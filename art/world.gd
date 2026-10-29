extends RefCounted
## Arena ("the Pit") + camp, built procedurally. Stone geometry is merged into a handful of meshes;
## torch light is faked in shaders (light pools), only the camp uses real OmniLights (3).

const MK := preload("res://art/mesh_kit.gd")
const SH := preload("res://art/shaders.gd")

# pillar and gate positions come from Maps (scripts/maps.gd): the arena the run fights in
const PILLAR_PIVOT := 0.8   # pillars topple about this height (top of the plinth)
const CAMP := Vector3(0, 0, 40)
const SHOP := Vector3(-4, 0, 42)
const FOUNTAIN := Vector3(4, 0, 42)
const SPAWN := Vector3(0, 0, 37)
const SUN_ROT := Vector3(-52, -32, 0)

## Arena looks (Maps "theme"). "ember" = the Pit's warm stone; "frost" = Rimefang Hollow.
const THEMES := {
	"ember": {"bg": Color("120e1c"), "ambient": Color("7480b8"), "ambient_e": 0.62, "fog": Color("2c2348"),
		"wall": Color("6e6a78"), "wall_top": Color("827d8a"), "wall_out": Color("4c4756"), "cliff": Color("3c3444"),
		"cloth": Color("8e1f1c"), "trim": Color("d6a24a"), "emblem": Color("ff8a3a"),
		"pillar": Color("706a78"), "pillar_d": Color("524c5a"), "bronze": Color("9a6a36"), "rune": Color("ff7a2f"),
		"gate": Color("736e7c"), "gate_d": Color("4e4958"),
		"floor_a": Color(0.30, 0.29, 0.30), "floor_b": Color(0.40, 0.37, 0.34), "sand": Color(0.48, 0.38, 0.26),
		"mortar": Color(0.12, 0.10, 0.10), "grate": Color(1.0, 0.42, 0.12),
		"braziers": [157.5, 22.5, -157.5, 90.0], "particles": "embers"},
	"frost": {"bg": Color("0b1120"), "ambient": Color("8fa8e0"), "ambient_e": 0.72, "fog": Color("223452"),
		"wall": Color("6c7686"), "wall_top": Color("9aa6b8"), "wall_out": Color("465060"), "cliff": Color("3a4456"),
		"cloth": Color("1f3f86"), "trim": Color("c8d4e4"), "emblem": Color("8ad8ff"),
		"pillar": Color("6e7a8c"), "pillar_d": Color("505a6c"), "bronze": Color("8c9aac"), "rune": Color("6fd2ff"),
		"gate": Color("717b8c"), "gate_d": Color("4c5466"),
		"floor_a": Color(0.31, 0.34, 0.40), "floor_b": Color(0.43, 0.47, 0.54), "sand": Color(0.80, 0.86, 0.93),
		"mortar": Color(0.08, 0.10, 0.14), "grate": Color(0.35, 0.78, 1.0),
		"braziers": [-90.0, 90.0, -20.0, -160.0], "particles": "snow"},
}
## The look being built (set by build()).
static var T: Dictionary = THEMES["ember"]

static func _gates_v2() -> Array:
	var out := []
	for g in Maps.gates().values():
		out.append(Vector2(g.x, g.z).normalized() * 22.0)
	return out

static func _pillars_v2() -> Array:
	var out := []
	for p in Maps.pillars():
		out.append(Vector2(p.x, p.z))
	return out

static func setup_environment(parent: Node, theme := "ember") -> void:
	var th: Dictionary = THEMES.get(theme, THEMES["ember"])
	var we := WorldEnvironment.new()
	we.name = "ArtEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = th["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = th["ambient"]
	env.ambient_light_energy = th["ambient_e"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		env.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)
	env.fog_enabled = true
	env.fog_light_color = th["fog"]
	env.fog_light_energy = 1.0
	env.fog_density = 0.0035
	env.fog_height = -1.0
	env.fog_height_density = 0.22
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.2
	sun.rotation_degrees = SUN_ROT
	sun.shadow_enabled = false
	parent.add_child(sun)

static func _sun_dir() -> Vector3:
	return Basis.from_euler(SUN_ROT * (PI / 180.0)) * Vector3(0, 0, -1)

static func _p(a: float, r: float, y: float) -> Vector3:
	return Vector3(cos(a) * r, y, sin(a) * r)

## rotation (deg, around Y) that maps local +X to direction (dx, dz)
static func _yrot(dx: float, dz: float) -> float:
	return rad_to_deg(atan2(-dz, dx))

static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "ArtWorld"
	parent.add_child(root)
	T = THEMES.get(Maps.theme(), THEMES["ember"])
	var flames: Array = []   # [pos, scale]

	# ---------------- arena (Delve builds no arena: its dungeon is art/dungeon.gd)
	var pillar_res: Array = []
	if Maps.theme() != "none":
		pillar_res = _arena(root, flames)

	# ---------------- camp
	var shop := Node3D.new(); shop.name = "Shop"; shop.position = SHOP
	var fountain := Node3D.new(); fountain.name = "Fountain"; fountain.position = FOUNTAIN
	root.add_child(shop); root.add_child(fountain)
	var camp_lights: Array = []
	var ck := MK.new()
	_camp(ck, flames, camp_lights, root)
	var camp_mesh := MeshInstance3D.new()
	camp_mesh.name = "CampProps"
	camp_mesh.mesh = ck.build()
	var cmat: ShaderMaterial = (SH.mat("world") as ShaderMaterial).duplicate()
	SH.occluder_mats.append(cmat)
	camp_mesh.material_override = cmat
	camp_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(camp_mesh)
	var cl := PackedVector4Array()
	for l in camp_lights:
		cl.append(l)
	while cl.size() < 12:
		cl.append(Vector4(0, 0, 1, 0))
	cl.resize(12)
	cmat.set_shader_parameter("lights", cl)
	var grass := MeshInstance3D.new()
	grass.name = "CampGround"
	var gp := PlaneMesh.new(); gp.size = Vector2(21, 21)
	grass.mesh = gp
	grass.position = CAMP
	var gmat: ShaderMaterial = SH.mat("grass")
	gmat.set_shader_parameter("lights", cl)
	grass.material_override = gmat
	root.add_child(grass)
	_fountain_water(root)
	_grass_tufts(root, cmat)
	# real OmniLights removed: in GL Compatibility each light adds a pass per lit object; camp glow is faked in shaders
	_teleport_pad(root)

	# ---------------- flames, embers, void rocks
	var flames_mm := _flames(root, flames)
	if Maps.theme() != "none":
		_embers(root)
	_void_rocks(root)
	return {"shop": shop, "fountain": fountain, "pillars": pillar_res, "flames_mm": flames_mm}

# =================================================================== arena

static func _arena(root: Node3D, flames: Array) -> Array:
	var arena_lights: Array = []  # Vector4(x, z, radius, intensity)
	# ---------------- floor
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(49, 49)
	floor_mi.mesh = pm
	floor_mi.name = "ArenaFloor"
	var fmat: ShaderMaterial = SH.mat("floor")
	floor_mi.material_override = fmat
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(floor_mi)

	# ---------------- arena stone
	var k := MK.new()
	arena_lights.append(Vector4(0, 0, 5.5, 0.55))
	_walls(k, flames, arena_lights)
	var pillar_mks: Array = []
	var pillar_flames: Array = []
	_pillars(k, flames, arena_lights, pillar_mks, pillar_flames)
	_gates(k, flames, arena_lights)
	_cliff(k, Vector3.ZERO, 24.6, 17.0, T["cliff"], 64, 11)
	var arena_mesh := MeshInstance3D.new()
	arena_mesh.name = "ArenaStone"
	arena_mesh.mesh = k.build()
	var wmat: ShaderMaterial = SH.mat("world")
	arena_mesh.material_override = wmat
	arena_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(arena_mesh)
	# pillar shafts are their own nodes so they can topple (scripts/arena.gd); the plinths stay in ArenaStone
	var pillar_res: Array = []
	var pv := _pillars_v2()
	for i in pillar_mks.size():
		var pmi := MeshInstance3D.new()
		pmi.name = "Pillar%d" % i
		pmi.mesh = (pillar_mks[i] as MK).build()
		pmi.material_override = wmat
		pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pmi.position = Vector3(pv[i].x, PILLAR_PIVOT, pv[i].y)
		root.add_child(pmi)
		pillar_res.append({"node": pmi, "flame": pillar_flames[i]})
	var lights := PackedVector4Array()
	for l in arena_lights:
		lights.append(l)
	while lights.size() < 12:
		lights.append(Vector4(0, 0, 1, 0))
	lights.resize(12)
	wmat.set_shader_parameter("lights", lights)
	fmat.set_shader_parameter("lights", lights)
	var pil := PackedVector4Array()
	for pp in pv:
		pil.append(Vector4(pp.x, pp.y, 1.6, 0))
	while pil.size() < 6:
		pil.append(Vector4(0, 0, 0, 0))
	fmat.set_shader_parameter("pillars", pil)
	fmat.set_shader_parameter("sun_dir", _sun_dir())
	fmat.set_shader_parameter("stone_a", T["floor_a"])
	fmat.set_shader_parameter("stone_b", T["floor_b"])
	fmat.set_shader_parameter("sand", T["sand"])
	fmat.set_shader_parameter("mortar_c", T["mortar"])
	fmat.set_shader_parameter("ember", T["grate"])
	return pillar_res



static func _gate_angles() -> Array:
	var out := []
	for g in _gates_v2():
		out.append(atan2(g.y, g.x))
	return out

static func _near_gate(a: float, gap: float) -> bool:
	for ga in _gate_angles():
		if absf(wrapf(a - ga, -PI, PI)) < gap:
			return true
	return false

static func _walls(k: MK, flames: Array, lights: Array) -> void:
	var r_in := 22.0
	var r_out := 24.3
	var h := 3.3
	var steps := 144
	var stone: Color = T["wall"]; var stone_top: Color = T["wall_top"]; var stone_out: Color = T["wall_out"]
	var gap := 0.135
	k.cur_aux = 1.0
	for i in steps:
		var a0 := TAU * i / steps - PI
		var a1 := TAU * (i + 1) / steps - PI
		var am := (a0 + a1) * 0.5
		if _near_gate(am, gap):
			continue
		var nin := -Vector3(cos(am), 0, sin(am))
		k.quad(_p(a0, r_in, 0), _p(a1, r_in, 0), _p(a1, r_in, h), _p(a0, r_in, h), stone, nin,
			PackedVector2Array([Vector2(a0 * r_in, 0), Vector2(a1 * r_in, 0), Vector2(a1 * r_in, h), Vector2(a0 * r_in, h)]))
		k.quad(_p(a0, r_out, -1.0), _p(a1, r_out, -1.0), _p(a1, r_out, h), _p(a0, r_out, h), stone_out, -nin,
			PackedVector2Array([Vector2(a0 * r_out, -1), Vector2(a1 * r_out, -1), Vector2(a1 * r_out, h), Vector2(a0 * r_out, h)]))
		k.cur_aux = 0.0
		k.quad(_p(a0, r_in, h), _p(a1, r_in, h), _p(a1, r_out, h), _p(a0, r_out, h), stone_top, Vector3.UP)
		# base plinth along inner face
		k.cur_aux = 1.0
		if i % 2 == 0:
			var mid := (r_in + r_out) * 0.5
			k.box(Vector3(2.0, 0.75, 0.62), _p(am, r_out - 0.3, h + 0.37), stone_top, Vector3(0, _yrot(-sin(am), cos(am)), 0))
		k.box(Vector3(0.5, 0.35, 1.05), _p(am, r_in - 0.2, 0.17), stone_out, Vector3(0, _yrot(cos(am), sin(am)), 0))
		# buttresses with banners in between
		if i % 8 == 4 and not _near_gate(am, gap + 0.12):
			k.box(Vector3(0.9, h + 0.5, 1.2), _p(am, r_in - 0.35, (h + 0.5) * 0.5), stone, Vector3(0, _yrot(cos(am), sin(am)), 0))
			k.box(Vector3(1.1, 0.4, 1.4), _p(am, r_in - 0.35, h + 0.6), stone_top, Vector3(0, _yrot(cos(am), sin(am)), 0))
		if i % 8 == 0 and not _near_gate(am, gap + 0.12):
			_banner(k, am, r_in - 0.04)
	k.cur_aux = 0.0
	# wall braziers (fake lights) between the gates (the Pit: beside the barrel stacks and at S)
	for deg in T["braziers"]:
		var c := _p(deg_to_rad(deg), 20.9, 0)
		_brazier(k, c, 0.9, flames)
		lights.append(Vector4(c.x, c.z, 7.0, 0.9))

static func _banner(k: MK, a: float, r: float) -> void:
	var cloth: Color = T["cloth"]; var trim: Color = T["trim"]; var ember: Color = T["emblem"]
	var rot := Vector3(0, _yrot(cos(a), sin(a)), 0)
	k.cur_aux = 0.0
	k.box(Vector3(0.06, 1.9, 1.0), _p(a, r - 0.03, 2.05), cloth, rot)
	k.box(Vector3(0.08, 0.1, 1.2), _p(a, r - 0.05, 3.02), Color("3a2a1c"), rot)
	k.box(Vector3(0.07, 0.07, 1.0), _p(a, r - 0.04, 1.2), trim, rot)
	# tattered tail
	k.prism(Vector3(1.0, 0.35, 0.06), _p(a, r - 0.03, 0.96), cloth, Vector3(180, rot.y + 90.0, 0))
	# original emblem: a rising flame inside a ring
	var n := -Vector3(cos(a), 0, sin(a))
	var ey := atan2(n.x, n.z)
	var flame := PackedVector2Array([Vector2(0, -0.28), Vector2(0.17, -0.12), Vector2(0.12, 0.08), Vector2(0.04, 0.0),
		Vector2(0.06, 0.26), Vector2(-0.06, 0.08), Vector2(-0.14, 0.14), Vector2(-0.17, -0.1)])
	k.extrude(flame, 0.03, _p(a, r - 0.09, 2.2), ember, Vector3(0, rad_to_deg(ey), 0), Vector3.ONE, 0.9)
	k.torus(0.3, 0.36, _p(a, r - 0.08, 2.2), trim, Vector3(90, rad_to_deg(ey), 0), -1, 12, 3)
	k.cur_aux = 1.0

static func _brazier(k: MK, c: Vector3, s: float, flames: Array) -> void:
	var iron := Color("2e2a2a"); var bronze := Color("a8743c"); var coal := Color("ff6a22")
	k.cur_aux = 0.0
	k.cyl(0.14 * s, 0.22 * s, 1.1 * s, c + Vector3(0, 0.55 * s, 0), iron)
	for i in 3:
		var a := TAU * i / 3.0
		k.spike(c + Vector3(cos(a) * 0.1, 0.6, sin(a) * 0.1) * s, c + Vector3(cos(a) * 0.45, 0.0, sin(a) * 0.45) * s, 0.06 * s, iron, -1, 4)
	k.cyl(0.55 * s, 0.3 * s, 0.32 * s, c + Vector3(0, 1.2 * s, 0), bronze, Vector3.ZERO, -1, 10)
	k.cyl(0.48 * s, 0.48 * s, 0.05 * s, c + Vector3(0, 1.34 * s, 0), coal, Vector3.ZERO, 2.2, 10)
	flames.append([c + Vector3(0, 1.3 * s, 0), Vector2(1.0, 1.7) * s])
	k.cur_aux = 1.0

## Plinths go into `k`; each shaft + top goes into its own MK in `out_mks` (local to the pillar's pivot,
## PILLAR_PIVOT above its base) and the index of its flame (-1 = none) into `out_flames`.
static func _pillars(k0: MK, flames: Array, lights: Array, out_mks: Array, out_flames: Array) -> void:
	var stone: Color = T["pillar"]; var stone_d: Color = T["pillar_d"]; var bronze: Color = T["bronze"]; var rune: Color = T["rune"]
	var pv := _pillars_v2()
	for idx in pv.size():
		var pp: Vector2 = pv[idx]
		var base := Vector3(pp.x, 0, pp.y)
		var broken := idx == pv.size() - 1
		k0.cur_aux = 1.0
		k0.cyl(1.95, 2.1, 0.55, base + Vector3(0, 0.27, 0), stone_d, Vector3.ZERO, -1, 8)
		k0.cyl(1.7, 1.85, 0.3, base + Vector3(0, 0.68, 0), stone, Vector3.ZERO, -1, 8)
		var k := MK.new()
		out_mks.append(k)
		var c := Vector3(0, -PILLAR_PIVOT, 0)   # base in pivot space
		var nflames := flames.size()
		k.cur_aux = 1.0
		var sh := 3.6 if broken else 5.0
		k.cyl(1.38, 1.5, sh, c + Vector3(0, 0.8 + sh * 0.5, 0), stone, Vector3.ZERO, -1, 10)
		k.cur_aux = 0.0
		k.cyl(1.56, 1.56, 0.32, c + Vector3(0, 2.3, 0), bronze, Vector3.ZERO, -1, 10)
		for i in 6:
			var a := TAU * i / 6.0 + idx
			k.box(Vector3(0.08, 0.2, 0.3), c + Vector3(cos(a) * 1.58, 2.3, sin(a) * 1.58), rune, Vector3(0, _yrot(cos(a), sin(a)), 0), 1.8)
		k.cur_aux = 1.0
		if broken:
			# jagged broken top + rubble
			for i in 7:
				var a := TAU * i / 7.0
				var hh := 0.4 + fposmod(i * 0.37, 0.7)
				k.box(Vector3(0.8, hh, 0.7), c + Vector3(cos(a) * 1.05, 0.8 + sh + hh * 0.4, sin(a) * 1.05), stone, Vector3(fposmod(i * 23.0, 20.0) - 10.0, _yrot(cos(a), sin(a)), 8))
			for i in 6:
				var a := TAU * i / 6.0 + 0.4
				var rr := 2.3 + fposmod(i * 0.53, 0.9)
				k0.box(Vector3(0.7, 0.45, 0.6), base + Vector3(cos(a) * rr, 0.22, sin(a) * rr), stone_d, Vector3(fposmod(i * 31.0, 40.0) - 20.0, i * 47.0, fposmod(i * 17.0, 30.0) - 15.0))
			k.cur_aux = 0.0
			_brazier(k, c + Vector3(0, 0.8 + sh + 0.2, 0), 1.4, flames)
		else:
			k.cyl(1.8, 1.55, 0.5, c + Vector3(0, 0.8 + sh + 0.25, 0), stone_d, Vector3.ZERO, -1, 8)
			k.box(Vector3(3.5, 0.3, 3.5), c + Vector3(0, 0.8 + sh + 0.62, 0), stone, Vector3(0, 22.5, 0))
			k.cur_aux = 0.0
			var top := c + Vector3(0, 0.8 + sh + 0.77, 0)
			k.cyl(1.0, 0.6, 0.45, top + Vector3(0, 0.22, 0), bronze, Vector3.ZERO, -1, 10)
			k.cyl(0.92, 0.92, 0.06, top + Vector3(0, 0.42, 0), rune, Vector3.ZERO, 2.0, 10)
			flames.append([top + Vector3(0, 0.4, 0), Vector2(1.7, 2.6)])
		lights.append(Vector4(pp.x, pp.y, 8.5, 0.75))
		k.cur_aux = 0.0
		# flames were placed in pivot space: move them to the world
		out_flames.append(nflames if flames.size() > nflames else -1)
		for fi in range(nflames, flames.size()):
			flames[fi][0] += base + Vector3(0, PILLAR_PIVOT, 0)
	k0.cur_aux = 0.0

static func _gates(k: MK, flames: Array, lights: Array) -> void:
	var stone: Color = T["gate"]; var stone_d: Color = T["gate_d"]; var iron := Color("2a2626"); var rune: Color = T["rune"]
	var void_c := Color(0.015, 0.01, 0.02)
	for g in _gates_v2():
		var a := atan2(g.y, g.x)
		var rad := Vector3(cos(a), 0, sin(a))
		var tn := Vector3(-sin(a), 0, cos(a))
		var yr := _yrot(tn.x, tn.z)
		var base := rad * 23.1
		var L := func(x: float, y: float, z: float) -> Vector3:
			return base + tn * x + Vector3(0, y, 0) - rad * z  # +z = towards the arena
		k.cur_aux = 1.0
		for s in [-1.0, 1.0]:
			k.box(Vector3(2.0, 5.6, 3.2), L.call(s * 3.15, 2.8, 0.2), stone, Vector3(0, yr, 0))
			k.box(Vector3(2.4, 0.5, 3.6), L.call(s * 3.15, 5.8, 0.2), stone_d, Vector3(0, yr, 0))
			for m in 2:
				k.box(Vector3(0.7, 0.7, 0.7), L.call(s * 3.15 + (m - 0.5) * 1.3, 6.4, 1.6), stone, Vector3(0, yr, 0))
			# corner fill (arch shoulders)
			k.box(Vector3(1.2, 1.2, 2.6), L.call(s * 1.75, 4.05, 0.2), stone, Vector3(0, yr, s * 45.0))
		k.box(Vector3(4.6, 1.5, 3.0), L.call(0, 5.05, 0.2), stone_d, Vector3(0, yr, 0))
		k.cur_aux = 0.0
		k.box(Vector3(0.7, 0.9, 0.3), L.call(0, 4.45, 1.75), stone, Vector3(0, yr, 0))
		k.box(Vector3(0.3, 0.5, 0.06), L.call(0, 4.45, 1.92), rune, Vector3(0, yr, 0), 2.2)
		# dark tunnel
		k.box(Vector3(4.4, 4.6, 0.3), L.call(0, 2.3, -1.3), void_c, Vector3(0, yr, 0))
		# portcullis (half raised)
		for i in 9:
			var x := -1.8 + i * 0.45
			k.cyl(0.06, 0.06, 3.1, L.call(x, 2.75, 0.7), iron, Vector3.ZERO, -1, 5, false)
			k.cone(0.08, 0.3, L.call(x, 1.05, 0.7), iron, Vector3(180, 0, 0), -1, 4)
		for y in [1.5, 2.5, 3.5]:
			k.box(Vector3(4.1, 0.1, 0.1), L.call(0, y, 0.7), iron, Vector3(0, yr, 0))
		# gate torches
		for s in [-1.0, 1.0]:
			var tp: Vector3 = L.call(s * 2.35, 2.9, 1.85)
			k.box(Vector3(0.12, 0.5, 0.12), tp + Vector3(0, -0.2, 0), iron)
			k.cyl(0.18, 0.1, 0.22, tp + Vector3(0, 0.1, 0), Color("8a5a2a"), Vector3.ZERO, -1, 6)
			k.cyl(0.15, 0.15, 0.04, tp + Vector3(0, 0.2, 0), rune, Vector3.ZERO, 2.0, 6)
			flames.append([tp + Vector3(0, 0.18, 0), Vector2(0.75, 1.25)])
		var lp := rad * 20.6
		lights.append(Vector4(lp.x, lp.z, 7.5, 1.0))
	k.cur_aux = 0.0

## Rocky underside for a floating island.
static func _cliff(k: MK, c: Vector3, r_top: float, depth: float, col: Color, seg: int, seed: int) -> void:
	var rings := [[0.0, 1.0], [-1.6, 0.98], [-4.0, 0.86], [-8.0, 0.62], [-depth * 0.75, 0.35], [-depth, 0.08]]
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var jit: Array = []
	for ri in rings.size():
		var row: Array = []
		for i in seg:
			row.append(1.0 + (rng.randf() - 0.5) * (0.0 if ri == 0 else 0.16))
		jit.append(row)
	k.cur_aux = 0.0
	for ri in rings.size() - 1:
		var y0: float = rings[ri][0]; var y1: float = rings[ri + 1][0]
		var f0: float = rings[ri][1]; var f1: float = rings[ri + 1][1]
		var c0 := col.lightened(0.08) if ri == 0 else col.darkened(ri * 0.12)
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var p00 := c + _p(a0, r_top * f0 * jit[ri][i], y0)
			var p01 := c + _p(a1, r_top * f0 * jit[ri][(i + 1) % seg], y0)
			var p10 := c + _p(a0, r_top * f1 * jit[ri + 1][i], y1)
			var p11 := c + _p(a1, r_top * f1 * jit[ri + 1][(i + 1) % seg], y1)
			var n := (p01 - p00).cross(p10 - p00).normalized()
			var am := (a0 + a1) * 0.5
			if n.dot(Vector3(cos(am), 0, sin(am))) < 0:
				n = -n
			k.quad(p00, p01, p11, p10, c0, n)

# =================================================================== camp

static func _camp(k: MK, flames: Array, lights: Array, root: Node3D) -> void:
	_cliff(k, CAMP, 10.3, 11.0, Color("3e3646"), 40, 23)
	var wood := Color("7a5232"); var wood_d := Color("4e3220"); var red := Color("b8322a"); var cream := Color("eadcb4")
	var gold := Color("f2c14e"); var stone := Color("8a8494"); var stone_d := Color("5e5868"); var canvas := Color("b89a6a")
	var canvas2 := Color("7e2a2a"); var iron := Color("2e2a2a")
	k.cur_aux = 0.0
	# --- shop stall (front faces +Z / the camera)
	var s := SHOP
	k.box(Vector3(3.0, 1.0, 0.9), s + Vector3(0, 0.5, 0.55), wood)
	k.box(Vector3(3.15, 0.1, 1.05), s + Vector3(0, 1.03, 0.55), wood_d)
	k.box(Vector3(2.9, 0.08, 0.06), s + Vector3(0, 0.7, 1.01), gold)
	for x in [-1.5, 1.5]:
		for z in [-0.9, 1.0]:
			k.cyl(0.09, 0.1, 2.9, s + Vector3(x, 1.45, z), wood_d, Vector3.ZERO, -1, 6)
	for i in 7:
		var col := red if i % 2 == 0 else cream
		k.box(Vector3(0.48, 0.06, 2.6), s + Vector3(-1.5 + i * 0.5, 2.95, 0.05), col, Vector3(-14, 0, 0))
	for i in 7:
		var col := red if i % 2 == 0 else cream
		k.prism(Vector3(0.48, 0.3, 0.05), s + Vector3(-1.5 + i * 0.5, 2.55, 1.35), col, Vector3(180, 0, 0))
	k.box(Vector3(3.0, 2.2, 0.1), s + Vector3(0, 1.1, -0.92), wood_d)
	for y in [1.35, 1.95]:
		k.box(Vector3(2.8, 0.06, 0.35), s + Vector3(0, y, -0.75), wood)
		for i in 6:
			var pc: Color = [Color("ff3a3a"), Color("3a8aff"), Color("6cff6a"), Color("ffc23a")][(i + int(y * 10)) % 4]
			k.cyl(0.07, 0.09, 0.22, s + Vector3(-1.1 + i * 0.44, y + 0.14, -0.72), pc, Vector3.ZERO, 0.9, 6)
			k.ball(0.04, s + Vector3(-1.1 + i * 0.44, y + 0.28, -0.72), cream, Vector3.ONE, Vector3.ZERO, -1, 6, 3)
	# goods on counter
	for i in 4:
		k.cyl(0.13, 0.13, 0.04, s + Vector3(0.6 + (i % 2) * 0.12, 1.1 + i * 0.04, 0.5 + (i / 2) * 0.1), gold, Vector3.ZERO, 0.5, 8)
	k.box(Vector3(0.5, 0.3, 0.35), s + Vector3(-0.8, 1.23, 0.5), Color("5a3a7a"))
	k.ball(0.12, s + Vector3(-0.2, 1.2, 0.5), Color("3ff0dc"), Vector3.ONE, Vector3.ZERO, 1.6, 8, 5)
	# crates + barrels
	for c in [[Vector3(-2.2, 0.35, 0.9), 0.7], [Vector3(-2.3, 0.3, -0.2), 0.6], [Vector3(-2.15, 0.93, 0.85), 0.5], [Vector3(2.15, 0.3, 1.0), 0.6]]:
		var cp: Vector3 = c[0]; var sz: float = c[1]
		k.box(Vector3(sz, sz, sz), s + cp, wood, Vector3(0, cp.x * 20.0, 0))
		k.box(Vector3(sz + 0.04, 0.08, sz + 0.04), s + cp + Vector3(0, sz * 0.3, 0), wood_d, Vector3(0, cp.x * 20.0, 0))
	for b in [Vector3(2.2, 0.45, -0.3), Vector3(2.6, 0.45, 0.4)]:
		k.cyl(0.36, 0.33, 0.9, s + b, wood, Vector3.ZERO, -1, 10)
		k.torus(0.33, 0.39, s + b + Vector3(0, 0.25, 0), iron, Vector3.ZERO, -1, 10, 3)
		k.torus(0.33, 0.39, s + b + Vector3(0, -0.25, 0), iron, Vector3.ZERO, -1, 10, 3)
	# hanging sign with coin emblem
	k.cyl(0.06, 0.07, 3.4, s + Vector3(-1.85, 1.7, 1.6), wood_d, Vector3.ZERO, -1, 6)
	k.box(Vector3(0.9, 0.08, 0.08), s + Vector3(-1.45, 3.3, 1.6), wood_d)
	k.box(Vector3(0.8, 0.6, 0.06), s + Vector3(-1.3, 2.85, 1.6), wood)
	k.cyl(0.2, 0.2, 0.05, s + Vector3(-1.3, 2.85, 1.65), gold, Vector3(90, 0, 0), 0.8, 12)
	# lantern
	var lan := s + Vector3(1.5, 2.45, 1.35)
	k.box(Vector3(0.22, 0.3, 0.22), lan, Color("ffcf6a"), Vector3.ZERO, 2.6)
	k.box(Vector3(0.28, 0.05, 0.28), lan + Vector3(0, 0.17, 0), iron)
	lights.append(Vector4(s.x, s.z + 1.0, 6.0, 0.9))

	# --- fountain
	var f := FOUNTAIN
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var len := 2.0 * 2.0 * tan(PI / 8.0)
		k.box(Vector3(0.32, 0.62, len + 0.1), f + Vector3(cos(a) * 1.85, 0.31, sin(a) * 1.85), stone, Vector3(0, _yrot(-sin(a), cos(a)) + 90.0, 0))
		k.box(Vector3(0.42, 0.08, len + 0.18), f + Vector3(cos(a) * 1.85, 0.64, sin(a) * 1.85), stone_d, Vector3(0, _yrot(-sin(a), cos(a)) + 90.0, 0))
	k.cyl(1.8, 1.8, 0.1, f + Vector3(0, 0.05, 0), stone_d, Vector3.ZERO, -1, 8)
	k.cyl(0.32, 0.42, 1.5, f + Vector3(0, 0.75, 0), stone, Vector3.ZERO, -1, 8)
	k.cyl(0.95, 0.32, 0.4, f + Vector3(0, 1.62, 0), stone, Vector3.ZERO, -1, 10)
	k.torus(0.88, 0.98, f + Vector3(0, 1.8, 0), stone_d, Vector3.ZERO, -1, 12, 3)
	k.cyl(0.12, 0.18, 0.5, f + Vector3(0, 2.0, 0), stone, Vector3.ZERO, -1, 6)
	k.prism(Vector3(0.26, 0.5, 0.26), f + Vector3(0, 2.45, 0), Color("6af0ff"), Vector3.ZERO, 2.4)
	k.prism(Vector3(0.26, 0.3, 0.26), f + Vector3(0, 2.07, 0), Color("6af0ff"), Vector3(180, 0, 0), 2.4)
	lights.append(Vector4(f.x, f.z, 4.0, 0.35))

	# --- teleport pad ring stones
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var sp := SPAWN + Vector3(cos(a) * 2.0, 0, sin(a) * 2.0)
		k.box(Vector3(0.4, 1.1, 0.35), sp + Vector3(0, 0.55, 0), stone, Vector3(0, -rad_to_deg(a), 0))
		k.box(Vector3(0.05, 0.4, 0.1), sp + Vector3(cos(a) * -0.2, 0.7, sin(a) * -0.2), Color("ff7a2f"), Vector3(0, -rad_to_deg(a), 0), 2.0)
	k.cyl(1.7, 1.75, 0.08, SPAWN + Vector3(0, 0.03, 0), stone_d, Vector3.ZERO, -1, 16)
	lights.append(Vector4(SPAWN.x, SPAWN.z, 3.5, 0.5))

	# --- tents
	for t in [[Vector3(-7.2, 0, 38.0), canvas, 70.0], [Vector3(7.4, 0, 37.6), canvas2, -65.0], [Vector3(-3.2, 0, 47.6), canvas, 5.0]]:
		var tp: Vector3 = t[0]; var tc: Color = t[1]; var ry: float = t[2]
		k.prism(Vector3(2.8, 2.1, 3.2), tp + Vector3(0, 1.05, 0), tc, Vector3(0, ry, 0))
		var fwd := Basis.from_euler(Vector3(0, deg_to_rad(ry), 0)) * Vector3(0, 0, 1)
		k.prism(Vector3(1.0, 1.2, 0.05), tp + Vector3(0, 0.6, 0) + fwd * 1.61, Color(0.06, 0.04, 0.03), Vector3(0, ry, 0))
		k.cyl(0.05, 0.05, 2.5, tp + Vector3(0, 1.25, 0) + fwd * 1.7, wood_d, Vector3.ZERO, -1, 5)
		k.box(Vector3(0.06, 0.5, 0.35), tp + Vector3(0, 2.25, 0) + fwd * 1.72, red if tc == canvas else gold, Vector3(0, ry + 90.0, 0))

	# --- campfire with log benches
	var cf := Vector3(1.6, 0, 47.0)
	for i in 8:
		var a := TAU * i / 8.0
		k.box(Vector3(0.36, 0.25, 0.3), cf + Vector3(cos(a) * 0.75, 0.12, sin(a) * 0.75), stone_d, Vector3(0, -rad_to_deg(a), 0))
	for i in 3:
		var a := TAU * i / 3.0
		k.cyl(0.09, 0.09, 1.0, cf + Vector3(cos(a) * 0.2, 0.2, sin(a) * 0.2), wood_d, Vector3(70, rad_to_deg(a), 0), -1, 6)
	k.ball(0.32, cf + Vector3(0, 0.12, 0), Color("ff6a22"), Vector3(1, 0.4, 1), Vector3.ZERO, 2.2, 8, 4)
	flames.append([cf + Vector3(0, 0.15, 0), Vector2(1.3, 1.9)])
	for b in [[cf + Vector3(-1.9, 0.22, 0.2), 80.0], [cf + Vector3(1.8, 0.22, -0.5), 100.0]]:
		k.cyl(0.24, 0.24, 1.6, b[0], wood, Vector3(90, b[1], 0), -1, 8)
	lights.append(Vector4(cf.x, cf.z, 7.5, 1.2))

	# --- training dummy
	var dm := Vector3(6.3, 0, 45.5)
	k.cyl(0.08, 0.1, 2.0, dm + Vector3(0, 1.0, 0), wood_d, Vector3.ZERO, -1, 6)
	k.box(Vector3(1.3, 0.1, 0.1), dm + Vector3(0, 1.55, 0), wood_d)
	k.cyl(0.32, 0.28, 0.85, dm + Vector3(0, 1.2, 0), Color("c8a660"), Vector3.ZERO, -1, 8)
	k.ball(0.24, dm + Vector3(0, 1.85, 0), Color("b8955a"), Vector3.ONE, Vector3.ZERO, -1, 8, 5)
	k.torus(0.26, 0.3, dm + Vector3(0, 1.25, -0.0), red, Vector3(90, 0, 0), -1, 10, 3, Vector3(1, 1, 1))
	k.box(Vector3(0.6, 0.6, 0.04), dm + Vector3(1.0, 0.3, 0.3), Color("8a6a40"), Vector3(-75, 30, 0))

	# --- fence posts with lanterns along the rim (open towards the arena)
	for i in 30:
		var a := TAU * i / 30.0
		if sin(a) < -0.45:
			continue
		var pp := CAMP + _p(a, 9.6, 0)
		k.cyl(0.09, 0.11, 1.2, pp + Vector3(0, 0.6, 0), wood_d, Vector3.ZERO, -1, 5)
		var a2 := TAU * (i + 1) / 30.0
		if sin(a2) >= -0.45:
			var pn := CAMP + _p(a2, 9.6, 0)
			var mid := (pp + pn) * 0.5
			var d := pn - pp
			k.box(Vector3(d.length(), 0.08, 0.08), mid + Vector3(0, 0.95, 0), wood, Vector3(0, _yrot(d.x, d.z), 0))
			k.box(Vector3(d.length(), 0.08, 0.08), mid + Vector3(0, 0.55, 0), wood, Vector3(0, _yrot(d.x, d.z), 0))
		if i % 5 == 0:
			k.cyl(0.05, 0.05, 0.8, pp + Vector3(0, 1.5, 0), iron, Vector3.ZERO, -1, 4)
			k.box(Vector3(0.18, 0.24, 0.18), pp + Vector3(0, 1.95, 0), Color("ffcf6a"), Vector3.ZERO, 2.4)
			k.box(Vector3(0.24, 0.05, 0.24), pp + Vector3(0, 2.09, 0), iron)
			if lights.size() < 12:
				lights.append(Vector4(pp.x, pp.z, 3.5, 0.6))
	# --- rocks and crates scattered
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for i in 10:
		var a := rng.randf() * TAU
		var r := 7.5 + rng.randf() * 1.8
		var rp := CAMP + _p(a, r, 0.15)
		if sin(a) < -0.5:
			continue
		k.ball(0.35 + rng.randf() * 0.3, rp, stone_d, Vector3(1.0, 0.6, 0.9), Vector3(0, rng.randf() * 360.0, 0), -1, 6, 4)

static func _fountain_water(root: Node3D) -> void:
	var f := FOUNTAIN
	var w := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 1.72; cm.bottom_radius = 1.72; cm.height = 0.02; cm.radial_segments = 16; cm.rings = 1
	w.mesh = cm; w.position = f + Vector3(0, 0.5, 0)
	w.material_override = SH.mat("water")
	w.name = "FountainWater"
	root.add_child(w)
	var w2 := MeshInstance3D.new()
	var cm2 := CylinderMesh.new(); cm2.top_radius = 0.82; cm2.bottom_radius = 0.82; cm2.height = 0.02; cm2.radial_segments = 12; cm2.rings = 1
	w2.mesh = cm2; w2.position = f + Vector3(0, 1.76, 0)
	w2.material_override = SH.mat("water")
	root.add_child(w2)
	var fall := MeshInstance3D.new()
	var cm3 := CylinderMesh.new(); cm3.top_radius = 0.9; cm3.bottom_radius = 1.25; cm3.height = 1.25; cm3.radial_segments = 14; cm3.rings = 1
	cm3.cap_top = false; cm3.cap_bottom = false
	fall.mesh = cm3; fall.position = f + Vector3(0, 1.15, 0)
	fall.material_override = SH.mat("water_fall")
	root.add_child(fall)
	var mist := CPUParticles3D.new()
	mist.position = f + Vector3(0, 0.6, 0)
	mist.amount = 10; mist.lifetime = 1.6
	mist.mesh = _quad()
	mist.material_override = SH.mat("particle_add")
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	mist.emission_ring_axis = Vector3.UP; mist.emission_ring_radius = 1.2; mist.emission_ring_inner_radius = 0.9; mist.emission_ring_height = 0.05
	mist.direction = Vector3.UP; mist.spread = 30; mist.gravity = Vector3(0, 0.3, 0)
	mist.initial_velocity_min = 0.1; mist.initial_velocity_max = 0.4
	mist.scale_amount_min = 0.3; mist.scale_amount_max = 0.6
	mist.color_ramp = _ramp(Color(0.5, 0.9, 1.0, 0.25), Color(0.5, 0.9, 1.0, 0.0))
	root.add_child(mist)

static func _grass_tufts(root: Node3D, mat: Material) -> void:
	var k := MK.new()
	var g1 := Color("3e6626"); var g2 := Color("6a8434")
	for i in 5:
		var a := TAU * i / 5.0
		k.spike(Vector3(cos(a) * 0.05, 0, sin(a) * 0.05), Vector3(cos(a) * 0.22, 0.42 + (i % 2) * 0.12, sin(a) * 0.22), 0.06, g1 if i % 2 == 0 else g2, -1, 3)
	var mesh := k.build()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var xs: Array = []
	for i in 260:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 9.4
		var p := CAMP + _p(a, r, 0)
		var q := Vector2(p.x - CAMP.x, p.z - CAMP.z)
		# keep paths, stall, fountain and pad clear
		if absf(q.length() - 4.6) < 1.1:
			continue
		if Vector2(p.x, p.z).distance_to(Vector2(SHOP.x, SHOP.z)) < 2.8 or Vector2(p.x, p.z).distance_to(Vector2(FOUNTAIN.x, FOUNTAIN.z)) < 2.5:
			continue
		if Vector2(p.x, p.z).distance_to(Vector2(SPAWN.x, SPAWN.z)) < 2.4:
			continue
		var s := 0.7 + rng.randf() * 0.8
		xs.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s, s)), p))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GrassTufts"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)

static func _camp_real_lights(root: Node3D) -> void:
	for l in [[SHOP + Vector3(1.5, 2.3, 1.6), Color(1.0, 0.7, 0.4), 1.4, 6.0], [Vector3(1.6, 1.2, 47.0), Color(1.0, 0.55, 0.25), 2.0, 8.0],
			[FOUNTAIN + Vector3(0, 2.4, 0), Color(0.4, 0.9, 1.0), 1.0, 5.0]]:
		var o := OmniLight3D.new()
		o.position = l[0]; o.light_color = l[1]; o.light_energy = l[2]; o.omni_range = l[3]
		o.omni_attenuation = 1.4
		o.shadow_enabled = false
		root.add_child(o)

static func _teleport_pad(root: Node3D) -> void:
	var d := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(3.4, 3.4)
	d.mesh = pm
	d.position = SPAWN + Vector3(0, 0.09, 0)
	var m: ShaderMaterial = SH.new_decal_mat(true)
	m.set_shader_parameter("mode", 5)
	m.set_shader_parameter("color", Color(1.0, 0.5, 0.18, 1.0))
	m.set_shader_parameter("color2", Color(1.0, 0.8, 0.4, 1.0))
	m.set_shader_parameter("size", Vector2(3.4, 3.4))
	m.set_shader_parameter("intensity", 1.6)
	m.set_shader_parameter("edge_w", 0.1)
	d.material_override = m
	d.name = "TeleportPad"
	root.add_child(d)

# =================================================================== shared fx

static var _q: QuadMesh
static func _quad() -> QuadMesh:
	if _q == null:
		_q = QuadMesh.new(); _q.size = Vector2.ONE
	return _q

static func _ramp(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a); g.set_color(1, b)
	return g

static func _flames(root: Node3D, flames: Array) -> MultiMesh:
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	qm.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	mm.instance_count = flames.size()
	for i in flames.size():
		var p: Vector3 = flames[i][0]
		var s: Vector2 = flames[i][1]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s.x, s.y, 1)), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Flames"
	mmi.multimesh = mm
	mmi.material_override = SH.mat("flame")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 20, 100))
	root.add_child(mmi)
	# sparks rising from all big braziers: ONE emitter with point emission (1 draw call instead of one per brazier)
	var pts := PackedVector3Array()
	for i in flames.size():
		var s: Vector2 = flames[i][1]
		if s.x < 1.2:
			continue
		var c: Vector3 = flames[i][0] + Vector3(0, s.y * 0.4, 0)
		for j in 6:
			var a := TAU * j / 6.0
			pts.append(c + Vector3(cos(a), 0.0, sin(a)) * s.x * 0.25)
	if pts.size() > 0:
		var sp := CPUParticles3D.new()
		sp.name = "BrazierSparks"
		sp.amount = mini(6 * pts.size() / 6, 64)
		sp.lifetime = 1.8
		sp.mesh = _quad(); sp.material_override = SH.mat("particle_add")
		sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
		sp.emission_points = pts
		sp.direction = Vector3.UP; sp.spread = 25; sp.gravity = Vector3(0.2, 0.6, 0)
		sp.initial_velocity_min = 0.6; sp.initial_velocity_max = 1.4
		sp.scale_amount_min = 0.05; sp.scale_amount_max = 0.1
		sp.color_ramp = _ramp(Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.25, 0.05, 0.0))
		root.add_child(sp)
	return mm

static func _embers(root: Node3D) -> void:
	var e := CPUParticles3D.new()
	e.name = "Embers"
	e.position = Vector3(0, 0.3, 12)
	e.amount = 70; e.lifetime = 7.0; e.preprocess = 7.0
	e.mesh = _quad(); e.material_override = SH.mat("particle_add")
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	e.emission_box_extents = Vector3(30, 1.5, 38)
	e.direction = Vector3.UP; e.spread = 35
	e.gravity = Vector3(0.15, 0.25, -0.05)
	e.initial_velocity_min = 0.2; e.initial_velocity_max = 0.7
	e.scale_amount_min = 0.03; e.scale_amount_max = 0.07
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.5, 0.1, 0.0), Color(1.0, 0.6, 0.2, 0.75), Color(1.0, 0.35, 0.05, 0.55), Color(1.0, 0.2, 0.0, 0.0)])
	if T.get("particles", "embers") == "snow":
		# Rimefang Hollow: slow snow drifting down instead of embers rising
		e.name = "Snow"
		e.position = Vector3(0, 9.0, 8)
		e.amount = 110
		e.emission_box_extents = Vector3(30, 2.0, 36)
		e.direction = Vector3.DOWN; e.spread = 20
		e.gravity = Vector3(0.25, -0.5, 0.1)
		e.scale_amount_min = 0.04; e.scale_amount_max = 0.09
		g.colors = PackedColorArray([Color(0.8, 0.9, 1.0, 0.0), Color(0.85, 0.92, 1.0, 0.55), Color(0.8, 0.88, 1.0, 0.45), Color(0.7, 0.8, 1.0, 0.0)])
	e.color_ramp = g
	e.visibility_aabb = AABB(Vector3(-35, -5, -45), Vector3(70, 30, 90))
	root.add_child(e)
	var pit := CPUParticles3D.new()
	pit.name = "PitEmbers"
	pit.position = Vector3(0, 0.1, 0)
	pit.amount = 18; pit.lifetime = 2.2; pit.preprocess = 2.0
	pit.mesh = _quad(); pit.material_override = SH.mat("particle_add")
	pit.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; pit.emission_sphere_radius = 0.9
	pit.direction = Vector3.UP; pit.spread = 15; pit.gravity = Vector3(0, 0.8, 0)
	pit.initial_velocity_min = 0.6; pit.initial_velocity_max = 1.6
	pit.scale_amount_min = 0.06; pit.scale_amount_max = 0.14
	pit.color_ramp = _ramp(Color(1.0, 0.7, 0.3, 1.0), Color(1.0, 0.2, 0.0, 0.0))
	if T.get("particles", "embers") == "snow":
		pit.color_ramp = _ramp(Color(0.6, 0.9, 1.0, 1.0), Color(0.2, 0.5, 1.0, 0.0))
	root.add_child(pit)

static func _void_rocks(root: Node3D) -> void:
	var k := MK.new()
	k.ball(1.0, Vector3.ZERO, Color("3a3444"), Vector3(1.0, 0.7, 0.9), Vector3.ZERO, -1, 7, 4)
	k.ball(0.6, Vector3(0.5, -0.4, 0.2), Color("2e2a36"), Vector3(1.0, 1.4, 0.9), Vector3(20, 30, 0), -1, 6, 4)
	k.cone(0.7, 1.6, Vector3(0, -1.0, 0), Color("2a2632"), Vector3(180, 0, 0), -1, 6)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = k.build()
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var xs: Array = []
	for i in 40:
		var a := rng.randf() * TAU
		var r := 28.0 + rng.randf() * 22.0
		var p := Vector3(cos(a) * r, -2.0 - rng.randf() * 9.0, sin(a) * r + 8.0)
		if Vector2(p.x, p.z - 40.0).length() < 13.0:
			continue
		var s := 0.6 + rng.randf() * 2.2
		xs.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * 0.5, rng.randf() * TAU, rng.randf() * 0.5)).scaled(Vector3(s, s, s)), p))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "VoidRocks"
	mmi.multimesh = mm
	mmi.material_override = SH.mat("world")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)

# =================================================================== title screen bonfire

class Flicker extends OmniLight3D:
	var base := 2.2
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		light_energy = base * (0.86 + 0.09 * sin(t * 13.0) + 0.06 * sin(t * 29.0 + 1.3) + 0.04 * sin(t * 4.1))

## A big crackling bonfire for the title screen at `c` (stone ring, log teepee, flames, sparks, smoke, a warm
## flickering light). Returns the root node.
static func bonfire(parent: Node3D, c: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Bonfire"
	parent.add_child(root)
	root.position = c
	var k := MK.new()
	var stone := Color("6e6876"); var stone_d := Color("4a4452"); var wood := Color("6a4428"); var wood_d := Color("3a2414")
	var coal := Color("ff5a1a"); var ash := Color("2a2220")
	k.cur_aux = 0.0
	for i in 11:
		var a := TAU * i / 11.0
		var sc := 0.85 + 0.25 * sin(i * 2.7)
		k.ball(0.3 * sc, Vector3(cos(a) * 1.05, 0.12, sin(a) * 1.05), stone if i % 2 == 0 else stone_d, Vector3(1.2, 0.75, 1.0), Vector3(0, -rad_to_deg(a), 0), -1, 7, 4)
	k.cyl(0.9, 0.95, 0.06, Vector3(0, 0.03, 0), ash, Vector3.ZERO, -1, 12)
	k.ball(0.55, Vector3(0, 0.08, 0), coal, Vector3(1.2, 0.3, 1.2), Vector3.ZERO, 2.6, 10, 4)
	for i in 6:
		var a := TAU * i / 6.0 + 0.2
		var foot := Vector3(cos(a) * 0.62, 0.05, sin(a) * 0.62)
		var top := Vector3(cos(a) * 0.08, 1.15, sin(a) * 0.08)
		k.limb(foot, top, 0.085, wood if i % 2 == 0 else wood_d, -1, 6)
		k.ball(0.06, foot.lerp(top, 0.25), coal, Vector3.ONE, Vector3.ZERO, 1.8, 5, 3)
	for b in [[Vector3(0.75, 0.1, 0.55), 30.0], [Vector3(-0.7, 0.1, -0.5), -40.0]]:
		k.cyl(0.1, 0.1, 0.9, b[0], wood_d, Vector3(90, b[1], 0), -1, 6)
	k.cur_aux = 1.0
	var mi := MeshInstance3D.new()
	mi.name = "BonfireStones"
	mi.mesh = k.build()
	mi.material_override = SH.mat("world")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# flame sheets (same shader as the braziers), crossed so they read from any side
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	qm.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	var sheets := [[Vector3(0, 0.1, 0), Vector2(1.2, 1.5), 0.0], [Vector3(0.1, 0.1, 0.05), Vector2(0.9, 1.2), 60.0],
		[Vector3(-0.1, 0.1, -0.05), Vector2(0.9, 1.3), 120.0], [Vector3(0.3, 0.05, 0.2), Vector2(0.6, 0.9), 30.0], [Vector3(-0.3, 0.05, 0.25), Vector2(0.55, 0.8), 90.0]]
	mm.instance_count = sheets.size()
	for i in sheets.size():
		var sh: Array = sheets[i]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, deg_to_rad(sh[2])).scaled(Vector3(sh[1].x, sh[1].y, 1)), sh[0]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "BonfireFlames"
	mmi.multimesh = mm
	mmi.material_override = SH.mat("flame")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	root.add_child(mmi)
	var fire := CPUParticles3D.new()
	fire.name = "BonfireCore"
	fire.position = Vector3(0, 0.25, 0)
	fire.amount = 16; fire.lifetime = 0.55; fire.preprocess = 1.0
	fire.mesh = _quad(); fire.material_override = SH.mat("particle_add")
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; fire.emission_sphere_radius = 0.45
	fire.direction = Vector3.UP; fire.spread = 14; fire.gravity = Vector3(0, 1.0, 0)
	fire.initial_velocity_min = 0.6; fire.initial_velocity_max = 1.4
	fire.scale_amount_min = 0.22; fire.scale_amount_max = 0.45
	var sc_c := Curve.new(); sc_c.add_point(Vector2(0, 1)); sc_c.add_point(Vector2(1, 0.15))
	fire.scale_amount_curve = sc_c
	var fg := Gradient.new()
	fg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	fg.colors = PackedColorArray([Color(1.0, 0.8, 0.4, 0.7), Color(1.0, 0.45, 0.1, 0.55), Color(0.8, 0.12, 0.02, 0.0)])
	fire.color_ramp = fg
	root.add_child(fire)
	var sp := CPUParticles3D.new()
	sp.name = "BonfireSparks"
	sp.position = Vector3(0, 0.8, 0)
	sp.amount = 24; sp.lifetime = 2.2; sp.preprocess = 2.2
	sp.mesh = _quad(); sp.material_override = SH.mat("particle_add")
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 0.4
	sp.direction = Vector3.UP; sp.spread = 22; sp.gravity = Vector3(0.25, 0.9, 0)
	sp.initial_velocity_min = 1.2; sp.initial_velocity_max = 2.6
	sp.tangential_accel_min = -0.6; sp.tangential_accel_max = 0.6
	sp.scale_amount_min = 0.04; sp.scale_amount_max = 0.09
	sp.color_ramp = _ramp(Color(1.0, 0.85, 0.45, 1.0), Color(1.0, 0.25, 0.05, 0.0))
	sp.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8))
	root.add_child(sp)
	var l := Flicker.new()
	l.name = "BonfireLight"
	l.position = Vector3(0, 1.1, 0)
	l.light_color = Color(1.0, 0.58, 0.26)
	l.omni_range = 9.0
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	root.add_child(l)
	return root

## Title-screen campsite: a small grassy ledge floating in the dark with a bonfire at `c`, a log bench to its
## west (seat at c + SEAT_OFF), a tent, supplies and a banner. The Pit and the camp glow far beyond.
const SEAT_OFF := Vector3(-1.56, 0, -1.17)
const BENCH_YAW := -29.0

static func menu_camp(parent: Node3D, c: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "MenuCamp"
	parent.add_child(root)
	var lights := [Vector4(c.x, c.z, 7.5, 1.5), Vector4(c.x - 3.4, c.z - 2.6, 3.0, 0.5)]
	var k := MK.new()
	_cliff(k, c, 7.5, 9.0, Color("3e3646"), 28, 41)
	var wood := Color("7a5232"); var wood_d := Color("4e3220"); var canvas := Color("b89a6a"); var red := Color("b8322a")
	var iron := Color("2e2a2a"); var gold := Color("f2c14e"); var stone_d := Color("5e5868")
	k.cur_aux = 0.0
	# log bench (the hero's seat) and a second log across the fire
	k.cyl(0.24, 0.24, 1.9, c + SEAT_OFF + Vector3(-0.1, 0.22, -0.08), wood, Vector3(90, BENCH_YAW, 0), -1, 9)
	k.cyl(0.22, 0.22, 1.6, c + Vector3(1.95, 0.2, -0.9), wood_d, Vector3(90, -30, 0), -1, 8)
	# tent behind the bench
	var tp := c + Vector3(-3.6, 0, -2.6)
	k.prism(Vector3(2.8, 2.1, 3.2), tp + Vector3(0, 1.05, 0), canvas, Vector3(0, 35, 0))
	var fwd := Basis.from_euler(Vector3(0, deg_to_rad(35.0), 0)) * Vector3(0, 0, 1)
	k.prism(Vector3(1.0, 1.2, 0.05), tp + Vector3(0, 0.6, 0) + fwd * 1.61, Color(0.06, 0.04, 0.03), Vector3(0, 35, 0))
	k.cyl(0.05, 0.05, 2.5, tp + Vector3(0, 1.25, 0) + fwd * 1.7, wood_d, Vector3.ZERO, -1, 5)
	k.box(Vector3(0.06, 0.5, 0.35), tp + Vector3(0, 2.25, 0) + fwd * 1.72, red, Vector3(0, 125, 0))
	# supplies: barrels and crates
	for b in [Vector3(-0.6, 0.45, -2.9), Vector3(0.3, 0.45, -3.2)]:
		k.cyl(0.36, 0.33, 0.9, c + b, wood, Vector3.ZERO, -1, 10)
		k.torus(0.33, 0.39, c + b + Vector3(0, 0.25, 0), iron, Vector3.ZERO, -1, 10, 3)
		k.torus(0.33, 0.39, c + b + Vector3(0, -0.25, 0), iron, Vector3.ZERO, -1, 10, 3)
	for cr in [[Vector3(1.2, 0.3, -3.0), 0.6, 20.0], [Vector3(1.15, 0.85, -3.0), 0.5, 40.0]]:
		k.box(Vector3(cr[1], cr[1], cr[1]), c + cr[0], wood_d, Vector3(0, cr[2], 0))
	# banner pole with the ember sigil
	var bp := c + Vector3(2.6, 0, -2.4)
	k.cyl(0.06, 0.07, 3.2, bp + Vector3(0, 1.6, 0), wood_d, Vector3.ZERO, -1, 6)
	k.box(Vector3(0.7, 1.1, 0.04), bp + Vector3(0.38, 2.5, 0), red, Vector3(0, -20, 0))
	k.cyl(0.18, 0.18, 0.05, bp + Vector3(0.38, 2.6, 0.03), gold, Vector3(90, -20, 0), 0.9, 10)
	# weapon rack and a dropped pack by the bench
	var wr := c + Vector3(-3.3, 0, 1.3)
	k.box(Vector3(1.3, 0.08, 0.08), wr + Vector3(0, 1.0, 0), wood_d, Vector3(0, 70, 0))
	for z in [-0.55, 0.55]:
		k.cyl(0.05, 0.06, 1.2, wr + Basis(Vector3.UP, deg_to_rad(70)) * Vector3(z, 0.6, 0), wood_d, Vector3.ZERO, -1, 5)
	for i in 3:
		k.cyl(0.025, 0.03, 1.5, wr + Basis(Vector3.UP, deg_to_rad(70)) * Vector3(-0.35 + i * 0.35, 0.75, 0.08), Color("8a8494"), Vector3(-8, 0, 0), -1, 4)
	k.ball(0.32, c + Vector3(-2.2, 0.25, 1.35), Color("6e4a2a"), Vector3(1.0, 0.8, 0.8), Vector3(0, 30, 0), -1, 8, 5)
	# rocks along the rim
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	for i in 12:
		var a := rng.randf() * TAU
		var r := 5.8 + rng.randf() * 1.2
		k.ball(0.3 + rng.randf() * 0.35, c + _p(a, r, 0.12), stone_d, Vector3(1.0, 0.6, 0.9), Vector3(0, rng.randf() * 360.0, 0), -1, 6, 4)
	var mi := MeshInstance3D.new()
	mi.name = "MenuCampProps"
	mi.mesh = k.build()
	var cmat: ShaderMaterial = (SH.mat("world") as ShaderMaterial).duplicate()
	mi.material_override = cmat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var cl := PackedVector4Array()
	for l in lights:
		cl.append(l)
	while cl.size() < 12:
		cl.append(Vector4(0, 0, 1, 0))
	cmat.set_shader_parameter("lights", cl)
	var ground := MeshInstance3D.new()
	ground.name = "MenuGround"
	var gp := CylinderMesh.new(); gp.top_radius = 7.5; gp.bottom_radius = 7.5; gp.height = 0.02; gp.radial_segments = 28; gp.rings = 1
	ground.mesh = gp
	ground.position = c + Vector3(0, -0.01, 0)
	var gmat: ShaderMaterial = (SH.mat("grass") as ShaderMaterial).duplicate()
	gmat.set_shader_parameter("lights", cl)
	gmat.set_shader_parameter("center", Vector2(c.x, c.z))
	ground.material_override = gmat
	root.add_child(ground)
	# grass tufts, kept off the fire, bench and tent
	var tk := MK.new()
	for i in 5:
		var a := TAU * i / 5.0
		tk.spike(Vector3(cos(a) * 0.05, 0, sin(a) * 0.05), Vector3(cos(a) * 0.22, 0.42 + (i % 2) * 0.12, sin(a) * 0.22), 0.06, Color("3e6626") if i % 2 == 0 else Color("6a8434"), -1, 3)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tk.build()
	var xs: Array = []
	for i in 90:
		var a := rng.randf() * TAU
		var r := 2.4 + sqrt(rng.randf()) * 4.6
		var p := c + _p(a, r, 0)
		if p.distance_to(tp) < 2.2 or p.distance_to(c + SEAT_OFF) < 1.3:
			continue
		var sc := 0.7 + rng.randf() * 0.8
		xs.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(sc, sc, sc)), p))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = cmat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	bonfire(root, c)
	return root

