extends RefCounted
## Effects + projectiles. Persistent fx return an FxNode with stop()/set_params(); one-shots free themselves.

const SH := preload("res://art/shaders.gd")

var art: Node

# ------------------------------------------------------------------ fx node

class FxNode extends Node3D:
	var kind := ""
	var t := 0.0
	var duration := -1.0
	var free_after := -1.0
	var target: Node3D
	var target_off := Vector3.ZERO
	var follow := false
	var stopping := false
	var stop_t := 0.0
	var fade_time := 0.25
	var linger := 0.0
	var mats: Array = []
	var parts: Array = []
	var update: Callable
	var params_cb: Callable
	var on_stop: Callable
	var data := {}

	func _process(dt: float) -> void:
		t += dt
		if follow:
			if target == null or not is_instance_valid(target) or not target.is_inside_tree():
				follow = false
				stop()
			else:
				global_position = target.global_position + target_off
		if update.is_valid():
			update.call(self, dt)
		if free_after > 0.0 and t >= free_after:
			queue_free()
			return
		if duration > 0.0 and t >= duration and not stopping:
			stop()
		if stopping:
			stop_t += dt
			var a := clampf(1.0 - stop_t / fade_time, 0.0, 1.0)
			for m in mats:
				(m as ShaderMaterial).set_shader_parameter("alpha", a * float(data.get("alpha", 1.0)))
			if stop_t >= maxf(fade_time, linger):
				queue_free()

	func stop() -> void:
		if stopping:
			return
		stopping = true
		for p in parts:
			if is_instance_valid(p):
				(p as CPUParticles3D).emitting = false
		if on_stop.is_valid():
			on_stop.call(self)

	func set_params(o: Dictionary) -> void:
		if params_cb.is_valid() and o != null:
			params_cb.call(self, o)

class ProjNode extends Node3D:
	var kind := ""
	var spin := Vector3.ZERO
	var core: Node3D
	var t := 0.0
	func tick(dt: float) -> void:
		pass
	func _process(dt: float) -> void:
		t += dt
		if core:
			core.rotate_object_local(Vector3.UP, spin.y * dt)
			core.rotate_object_local(Vector3.RIGHT, spin.x * dt)
			core.rotate_object_local(Vector3.FORWARD, spin.z * dt)

# ------------------------------------------------------------------ shared resources

static var _res := {}

static func _mesh(key: String) -> Mesh:
	if _res.has(key):
		return _res[key]
	var m: Mesh
	match key:
		"quad":
			var q := QuadMesh.new(); q.size = Vector2.ONE; m = q
		"plane":
			var p := PlaneMesh.new(); p.size = Vector2.ONE; m = p
		"sphere":
			var s := SphereMesh.new(); s.radius = 0.5; s.height = 1.0; s.radial_segments = 12; s.rings = 6; m = s
		"box":
			var b := BoxMesh.new(); b.size = Vector3.ONE; m = b
		"shard":
			var pr := PrismMesh.new(); pr.size = Vector3(0.5, 1.0, 0.3); m = pr
		"column":
			var c := CylinderMesh.new(); c.top_radius = 0.5; c.bottom_radius = 0.5; c.height = 1.0
			c.radial_segments = 16; c.rings = 1; c.cap_top = false; c.cap_bottom = false; m = c
		"hex":
			var h := CylinderMesh.new(); h.top_radius = 0.5; h.bottom_radius = 0.5; h.height = 0.5; h.radial_segments = 6; h.rings = 1; m = h
		"ring":
			var t := TorusMesh.new(); t.inner_radius = 0.42; t.outer_radius = 0.5; t.rings = 16; t.ring_segments = 4; m = t
		"coin":
			var c := CylinderMesh.new(); c.top_radius = 0.18; c.bottom_radius = 0.18; c.height = 0.05; c.radial_segments = 12; c.rings = 1; m = c
	_res[key] = m
	return m

static func _ramp(c: Color, end_alpha := 0.0, mid := -1.0) -> Gradient:
	var key := "ramp_%s_%.2f_%.2f" % [c.to_html(), end_alpha, mid]
	if _res.has(key):
		return _res[key]
	var g := Gradient.new()
	if mid > 0.0:
		g.offsets = PackedFloat32Array([0.0, mid, 1.0])
		g.colors = PackedColorArray([c, Color(c.r, c.g, c.b, c.a * 0.8), Color(c.r, c.g, c.b, end_alpha)])
	else:
		g.set_color(0, c)
		g.set_color(1, Color(c.r, c.g, c.b, end_alpha))
	_res[key] = g
	return g

static func _shrink_curve() -> Curve:
	if _res.has("shrink"):
		return _res["shrink"]
	var c := Curve.new(); c.add_point(Vector2(0, 1)); c.add_point(Vector2(1, 0.0))
	_res["shrink"] = c
	return c

static func _grow_curve() -> Curve:
	if _res.has("grow"):
		return _res["grow"]
	var c := Curve.new(); c.add_point(Vector2(0, 0.4)); c.add_point(Vector2(1, 1.0))
	_res["grow"] = c
	return c

static func _coin_mat() -> Material:
	if _res.has("coin_mat"):
		return _res["coin_mat"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("f2c14e")
	m.emission_enabled = true
	m.emission = Color("ffb020")
	m.emission_energy_multiplier = 1.4
	m.metallic = 0.6
	m.roughness = 0.35
	_res["coin_mat"] = m
	return m

# ------------------------------------------------------------------ helpers

func _v(o: Dictionary, key: String, def := Vector3.ZERO) -> Vector3:
	var v = o.get(key, def)
	if v is Vector3:
		return v
	if v is Vector2:
		return Vector3(v.x, 0, v.y)
	if v is Node3D and is_instance_valid(v):
		return (v as Node3D).global_position
	return def

func _f(o: Dictionary, key: String, def: float) -> float:
	var v = o.get(key, def)
	if v is float or v is int:
		return float(v)
	return def

func _c(o: Dictionary, key: String, def: Color) -> Color:
	var v = o.get(key, def)
	if v is Color:
		return v
	return def

func _node(root: Node, kind: String, pos: Vector3) -> FxNode:
	var n := FxNode.new()
	n.kind = kind
	n.name = "Fx_" + kind
	if root:
		root.add_child(n)
		n.global_position = pos
	else:
		n.position = pos
	return n

func _particles(parent: Node3D, cfg: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = cfg.get("amount", 12)
	p.lifetime = cfg.get("life", 0.6)
	p.one_shot = cfg.get("one_shot", true)
	p.explosiveness = cfg.get("explode", 1.0 if p.one_shot else 0.0)
	p.randomness = 0.3
	p.local_coords = cfg.get("local", false)
	var mk: String = cfg.get("mesh", "quad")
	p.mesh = _mesh(mk)
	match cfg.get("mat", "add"):
		"add": p.material_override = SH.mat("particle_add")
		"mix": p.material_override = SH.mat("particle_mix")
		"debris": p.material_override = SH.mat("debris")
		"glow": p.material_override = SH.mat("debris_glow")
	var shape: String = cfg.get("shape", "sphere")
	match shape:
		"sphere":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = cfg.get("radius", 0.2)
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_radius = cfg.get("radius", 1.0)
			p.emission_ring_inner_radius = cfg.get("inner", cfg.get("radius", 1.0) * 0.85)
			p.emission_ring_height = 0.05
		"box":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = cfg.get("box", Vector3.ONE)
		"point":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	p.direction = cfg.get("dir", Vector3.UP)
	p.spread = cfg.get("spread", 180.0)
	p.gravity = cfg.get("gravity", Vector3.ZERO)
	p.initial_velocity_min = cfg.get("vmin", 1.0)
	p.initial_velocity_max = cfg.get("vmax", 3.0)
	p.radial_accel_min = cfg.get("radial", 0.0)
	p.radial_accel_max = cfg.get("radial", 0.0)
	p.tangential_accel_min = cfg.get("tangent", 0.0)
	p.tangential_accel_max = cfg.get("tangent", 0.0)
	p.damping_min = cfg.get("damp", 0.0)
	p.damping_max = cfg.get("damp", 0.0)
	p.scale_amount_min = cfg.get("smin", 0.1)
	p.scale_amount_max = cfg.get("smax", 0.2)
	if cfg.get("grow", false):
		p.scale_amount_curve = _grow_curve()
	elif cfg.get("shrink", true):
		p.scale_amount_curve = _shrink_curve()
	if mk != "quad":
		p.particle_flag_rotate_y = true
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
	var col: Color = cfg.get("color", Color.WHITE)
	p.color_ramp = _ramp(col, 0.0 if cfg.get("fade", true) else col.a, cfg.get("mid", -1.0))
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 14, 16))
	parent.add_child(p)
	p.emitting = true
	return p

func _sprite(parent: Node3D, c: Color, c2: Color, size: float, intensity := 2.0, mode := 0, y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("quad")
	var m := SH.new_add_mat(c, c2, mode, intensity, true)
	mi.material_override = m
	mi.scale = Vector3(size, size, size)
	mi.position = Vector3(0, y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _decal(parent: Node3D, mode: int, sx: float, sz: float, c: Color, c2: Color, additive: bool, intensity := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("plane")
	var m := SH.new_decal_mat(additive)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("color2", c2)
	m.set_shader_parameter("size", Vector2(sx, sz))
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("seed", randf() * 10.0)
	mi.material_override = m
	mi.scale = Vector3(maxf(sx, 0.01), 1, maxf(sz, 0.01))
	mi.position = Vector3(0, 0.06, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Orient a unit plane (XZ) from a to b (local, y ignored): UV.y runs a -> b.
func _line_xform(a: Vector3, b: Vector3, width: float, y := 0.06) -> Transform3D:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var L := maxf(d.length(), 0.05)
	var z := d / L if d.length() > 0.001 else Vector3.FORWARD
	var x := Vector3.UP.cross(z).normalized()
	var mid := (a + b) * 0.5
	return Transform3D(Basis(x * width, Vector3.UP, z * L), Vector3(mid.x, y, mid.z))

func _label(parent: Node3D, text: String, c: Color, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.modulate = c
	l.outline_modulate = Color(0.08, 0.04, 0.02, 0.95)
	l.font_size = size
	l.outline_size = int(size * 0.28)
	l.pixel_size = 0.0075
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.render_priority = 10
	l.outline_render_priority = 9
	l.shaded = false
	l.double_sided = true
	parent.add_child(l)
	return l

func _set_alpha(mi: MeshInstance3D, a: float) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter("alpha", a)

# ------------------------------------------------------------------ projectiles

func projectile(kind: String) -> Node3D:
	var n := ProjNode.new()
	n.kind = kind
	n.name = "Proj_" + kind
	var c := Color(1.0, 0.85, 0.5); var c2 := Color(1.0, 1.0, 0.9); var size := 0.35; var trail := Color(1.0, 0.7, 0.3, 1.0)
	var mesh_key := "sphere"; var tgrav := Vector3.ZERO; var tamount := 16
	match kind:
		"fire_bolt":
			c = Color(1.0, 0.42, 0.08); c2 = Color(1.0, 0.92, 0.6); size = 0.36; trail = Color(1.0, 0.45, 0.1, 1.0)
		"spit":
			c = Color(0.45, 0.95, 0.12); c2 = Color(0.9, 1.0, 0.6); size = 0.32; trail = Color(0.55, 1.0, 0.2, 0.9); tgrav = Vector3(0, -4, 0); tamount = 12
		"hex_bolt":
			c = Color(0.85, 0.25, 1.0); c2 = Color(1.0, 0.8, 1.0); size = 0.34; trail = Color(0.8, 0.3, 1.0, 1.0); mesh_key = "hex"
			n.spin = Vector3(4.0, 7.0, 0.0)
		"boss_orb":
			c = Color(1.0, 0.18, 0.32); c2 = Color(1.0, 0.85, 0.75); size = 0.7; trail = Color(1.0, 0.25, 0.4, 1.0); tamount = 22
			n.spin = Vector3(0.0, 3.0, 0.0)
		"hero_bolt":
			c = Color(0.35, 0.95, 1.0); c2 = Color(1.0, 1.0, 0.85); size = 0.28; trail = Color(0.5, 1.0, 1.0, 1.0)
		"bullet":
			c = Color(0.45, 0.8, 1.0); c2 = Color(1.0, 1.0, 1.0); size = 0.13; trail = Color(0.6, 0.88, 1.0, 1.0); tamount = 10
		"crossbow_bolt":
			c = Color(0.78, 0.86, 0.28); c2 = Color(1.0, 1.0, 0.75); size = 0.12; trail = Color(0.82, 0.9, 0.35, 0.8); tamount = 8
		"spirit_lance":
			c = Color(0.72, 0.36, 1.0); c2 = Color(1.0, 0.9, 1.0); size = 0.24; trail = Color(0.78, 0.45, 1.0, 1.0); tamount = 20
		"grave_bolt":
			c = Color(0.4, 1.0, 0.72); c2 = Color(0.9, 1.0, 0.95); size = 0.26; trail = Color(0.5, 1.0, 0.78, 0.9); tgrav = Vector3(0, 1.2, 0)
		"blood_bolt":
			c = Color(0.9, 0.06, 0.16); c2 = Color(1.0, 0.65, 0.6); size = 0.3; trail = Color(0.85, 0.05, 0.12, 1.0); tgrav = Vector3(0, -3.0, 0)
		"dagger":
			c = Color(0.82, 0.86, 0.95); c2 = Color(1.0, 1.0, 1.0); size = 0.14; trail = Color(0.62, 0.42, 1.0, 0.8); mesh_key = "shard"; tamount = 8
		"frost_bolt":
			c = Color(0.55, 0.88, 1.0); c2 = Color(0.95, 1.0, 1.0); size = 0.26; trail = Color(0.7, 0.95, 1.0, 1.0); mesh_key = "shard"
			n.spin = Vector3(0.0, 0.0, 9.0)
		"vial":
			c = Color(0.55, 1.0, 0.25); c2 = Color(1.0, 0.95, 0.6); size = 0.24; trail = Color(0.6, 1.0, 0.3, 0.9); tgrav = Vector3(0, -3.0, 0); tamount = 12
			n.spin = Vector3(6.0, 0.0, 4.0)
		"time_bolt":
			c = Color(0.95, 0.8, 0.4); c2 = Color(1.0, 1.0, 0.9); size = 0.26; trail = Color(0.55, 0.75, 1.0, 1.0); mesh_key = "hex"
			n.spin = Vector3(0.0, 5.0, 0.0)
		_:
			pass
	var core := MeshInstance3D.new()
	core.mesh = _mesh(mesh_key)
	core.material_override = SH.add_mat_shared(c, c2, 1, 2.6)
	core.scale = Vector3.ONE * size
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(core)
	n.core = core
	if kind == "boss_orb":
		var ring := MeshInstance3D.new()
		ring.mesh = _mesh("ring")
		ring.material_override = SH.add_mat_shared(Color(0.7, 0.15, 1.0), Color(1, 0.6, 1), 1, 2.4)
		ring.scale = Vector3.ONE * size * 1.7
		ring.rotation_degrees = Vector3(70, 0, 0)
		core.add_child(ring)
		ring.scale = Vector3.ONE * 1.7
	if kind == "hero_bolt":
		core.scale = Vector3(size, size, size * 2.4)
	elif kind == "bullet":
		core.scale = Vector3(size, size, size * 7.0)
		core.position.z = size * 2.0
	elif kind == "spirit_lance":
		core.scale = Vector3(size * 0.6, size * 0.6, size * 6.0)
		var tip := MeshInstance3D.new()
		tip.mesh = _mesh("shard")
		tip.material_override = SH.add_mat_shared(c2, Color(1, 1, 1), 1, 2.8)
		tip.rotation_degrees = Vector3(-90, 0, 0)
		tip.scale = Vector3(0.5, 0.7, 0.3)
		tip.position = Vector3(0, 0, -size * 3.2)
		n.add_child(tip)
		var ring := MeshInstance3D.new()
		ring.mesh = _mesh("ring")
		ring.material_override = SH.add_mat_shared(c, c2, 1, 2.2)
		ring.scale = Vector3.ONE * size * 1.8
		ring.rotation_degrees = Vector3(90, 0, 0)
		core.add_child(ring)
		ring.scale = Vector3(3.0, 3.0, 0.5)
		n.spin = Vector3(0, 0, 6.0)
	elif kind == "crossbow_bolt" or kind == "grave_bolt":
		var bm := MeshInstance3D.new()
		bm.mesh = _bolt_mesh(kind)
		bm.material_override = _bolt_mat(kind)
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(bm)
		if kind == "crossbow_bolt":
			core.scale = Vector3.ONE * size * 0.8
			core.position.z = -0.42
		else:
			core.scale = Vector3.ONE * size * 0.55
			n.core = bm
			n.spin = Vector3(0, 0, 0)
	var halo := MeshInstance3D.new()
	halo.mesh = _mesh("quad")
	halo.material_override = SH.add_mat_shared(c, c2, 0, 1.8, true)
	halo.scale = Vector3.ONE * size * 3.6
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(halo)
	var tr := CPUParticles3D.new()
	tr.amount = tamount
	tr.lifetime = 0.35
	tr.local_coords = false
	tr.mesh = _mesh("quad")
	tr.material_override = SH.mat("particle_add")
	tr.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	tr.emission_sphere_radius = size * 0.35
	tr.spread = 180.0
	tr.initial_velocity_min = 0.0
	tr.initial_velocity_max = 0.4
	tr.gravity = tgrav
	tr.scale_amount_min = size * 1.1
	tr.scale_amount_max = size * 1.6
	tr.scale_amount_curve = _shrink_curve()
	tr.color_ramp = _ramp(trail)
	tr.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
	n.add_child(tr)
	return n

## Small solid meshes for the crossbow bolt (shaft, head, fletching) and the grave bolt (ghost skull). Cached.
static func _bolt_mesh(kind: String) -> Mesh:
	var key := "boltmesh_" + kind
	if _res.has(key):
		return _res[key]
	var MK = load("res://art/mesh_kit.gd")
	var k = MK.new()
	if kind == "crossbow_bolt":
		var wood := Color("8a6034"); var metal := Color("c8c4b0"); var olive := Color("c8d24a")
		k.box(Vector3(0.035, 0.035, 0.8), Vector3(0, 0, 0), wood)
		k.spike(Vector3(0, 0, -0.38), Vector3(0, 0, -0.52), 0.05, metal, 0.4, 4)
		for r in [0.0, 90.0]:
			k.prism(Vector3(0.16, 0.14, 0.012), Vector3(0, 0, 0.34), olive, Vector3(90, 0, r), 1.4)
	else:
		var bone := Color("c8fff0"); var dark := Color("0a2a20"); var mint := Color("8affc8")
		k.ball(0.17, Vector3.ZERO, bone, Vector3(1, 0.95, 1.1), Vector3.ZERO, 1.2, 8, 5)
		k.box(Vector3(0.18, 0.08, 0.12), Vector3(0, -0.13, -0.06), bone, Vector3.ZERO, 1.2)
		for s in [-1.0, 1.0]:
			k.ball(0.05, Vector3(s * 0.065, 0.02, -0.15), dark, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
			k.ball(0.025, Vector3(s * 0.065, 0.02, -0.18), mint, Vector3.ONE, Vector3.ZERO, 3.5, 6, 4)
	var m: Mesh = k.build()
	_res[key] = m
	return m

static func _bolt_mat(kind: String) -> Material:
	var key := "boltmat_" + kind
	if _res.has(key):
		return _res[key]
	var m: ShaderMaterial
	if kind == "grave_bolt":
		m = SH.new_ghost_mat(Color(0.5, 1.0, 0.78), 0.75, 1.0)
		m.set_shader_parameter("glow_strength", 1.4)
	else:
		m = SH.new_unit_mat(Color(0.8, 0.9, 0.3), 1.0)
		m.set_shader_parameter("rim_color", Color(0.9, 1.0, 0.6))
		m.set_shader_parameter("rim_strength", 0.8)
	_res[key] = m
	return m

# ------------------------------------------------------------------ dispatcher

const PERSISTENT := ["telegraph_circle", "telegraph_line", "aim_circle", "aim_line", "ash_wall", "foundry_aura",
	"mark", "rally_marker", "carapace", "bloater_pool", "beam", "buff_aura", "zone", "stone_ridge", "grave_marker"]

## Concurrency budget for cosmetic one-shots (keeps draw calls bounded in big fights).
## Over budget: damage numbers recycle the oldest; others spawn a light variant or nothing visible.
const FX_CAP := {"damage_number": 10, "hit": 6, "death_burst": 4, "gold": 4, "heal": 4, "slam": 3,
	"cone": 4, "ring_burst": 4, "blood_burst": 6, "trap_snap": 4, "explosion": 4, "soul_wisp": 8, "form_shift": 2, "grave_marker": 24}
var _live := {}

func _live_list(kind: String) -> Array:
	var arr: Array = _live.get(kind, [])
	var keep: Array = []
	for x in arr:
		if is_instance_valid(x) and not (x as Node).is_queued_for_deletion():
			keep.append(x)
	_live[kind] = keep
	return keep

func _null_fx(o: Dictionary, root: Node, kind: String) -> FxNode:
	var n := _node(root, kind, _v(o, "pos"))
	n.free_after = 0.05
	return n

func spawn(fx_name: String, o: Dictionary, root: Node) -> Node:
	var over := false
	if FX_CAP.has(fx_name):
		var live := _live_list(fx_name)
		if live.size() >= int(FX_CAP[fx_name]):
			if fx_name == "damage_number":
				var old := live.pop_front() as Node3D
				old.visible = false
				old.queue_free()
			else:
				over = true
	var n: FxNode
	if over:
		if fx_name == "death_burst" and _live_list("death_burst_lite").size() < 8:
			n = _death_burst_lite(o, root)
			_live["death_burst_lite"].append(n)
		elif fx_name == "slam" and _live_list("slam_lite").size() < 6:
			n = _slam_lite(o, root)
			_live["slam_lite"].append(n)
		elif fx_name == "explosion" and _live_list("explosion_lite").size() < 6:
			n = _explosion_lite(o, root)
			_live["explosion_lite"].append(n)
		elif fx_name == "grave_marker":
			# recycle the oldest marker instead of dropping the new one
			var oldm = _live_list("grave_marker").pop_front()
			if oldm is FxNode:
				(oldm as FxNode).stop()
			n = _grave_marker(o, root)
			_live["grave_marker"].append(n)
		else:
			n = _null_fx(o, root, fx_name)
		return n
	n = _spawn_kind(fx_name, o, root)
	if FX_CAP.has(fx_name) and n != null:
		_live[fx_name].append(n)
	return n

func _spawn_kind(fx_name: String, o: Dictionary, root: Node) -> FxNode:
	var n: FxNode
	match fx_name:
		"hit": n = _hit(o, root)
		"death_burst": n = _death_burst(o, root)
		"level_up": n = _level_up(o, root)
		"heal": n = _heal(o, root)
		"gold": n = _gold(o, root)
		"damage_number": n = _damage_number(o, root)
		"teleport": n = _teleport(o, root)
		"telegraph_circle": n = _telegraph_circle(o, root)
		"telegraph_line": n = _telegraph_line(o, root)
		"aim_circle": n = _aim_circle(o, root)
		"aim_line": n = _aim_line(o, root)
		"ash_wall": n = _ash_wall(o, root)
		"tether_pull": n = _tether_pull(o, root)
		"foundry_aura": n = _foundry_aura(o, root)
		"buff_aura": n = _buff_aura(o, root)
		"slip_trail": n = _slip_trail(o, root)
		"mark": n = _mark(o, root)
		"shatter": n = _shatter(o, root)
		"rift_strike": n = _rift_strike(o, root)
		"brood_hatch": n = _brood_hatch(o, root)
		"rally_marker": n = _rally_marker(o, root)
		"sacrifice_explosion": n = _sacrifice(o, root)
		"carapace": n = _carapace(o, root)
		"bloater_pool": n = _bloater_pool(o, root)
		"beam": n = _beam(o, root)
		"slam": n = _slam(o, root)
		"fountain_heal": n = _fountain_heal(o, root)
		"cone": n = _cone(o, root)
		"zone": n = _zone(o, root)
		"ring_burst": n = _ring_burst(o, root)
		"stone_ridge": n = _stone_ridge(o, root)
		"blood_burst": n = _blood_burst(o, root)
		"trap_snap": n = _trap_snap(o, root)
		"explosion": n = _explosion(o, root)
		"soul_wisp": n = _soul_wisp(o, root)
		"form_shift": n = _form_shift(o, root)
		"grave_marker": n = _grave_marker(o, root)
		_:
			n = _hit(o, root)
			if fx_name in PERSISTENT:
				n.free_after = -1.0
				n.duration = _f(o, "duration", 1.0)
	return n

# ------------------------------------------------------------------ one-shots

func _hit(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos")
	p.y = maxf(p.y, 1.0)
	var c := _c(o, "color", Color(1.0, 0.75, 0.35))
	var n := _node(root, "hit", p)
	n.free_after = 0.5
	_particles(n, {"amount": 10, "life": 0.35, "vmin": 3.0, "vmax": 6.5, "gravity": Vector3(0, -7, 0), "smin": 0.08, "smax": 0.16, "color": c, "damp": 4.0})
	var fl := _sprite(n, c, Color(1, 1, 0.9), 0.9, 2.5)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.16, 0.0, 1.0)
		fl.scale = Vector3.ONE * lerpf(0.5, 1.5, k)
		_set_alpha(fl, 1.0 - k)
	return n

func _death_burst(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var c := _c(o, "color", Color(1.0, 0.45, 0.2))
	var s := _f(o, "size", 1.0)
	var n := _node(root, "death_burst", p)
	n.free_after = 1.3
	_particles(n, {"amount": 10, "life": 0.9, "mat": "mix", "radius": 0.4 * s, "vmin": 0.8, "vmax": 2.2 * s, "dir": Vector3.UP, "spread": 70.0,
		"gravity": Vector3(0, 0.6, 0), "smin": 0.6 * s, "smax": 1.1 * s, "grow": true, "color": Color(0.12, 0.09, 0.12, 0.55), "damp": 2.0}).position.y = 0.6 * s
	_particles(n, {"amount": 18, "life": 0.6, "radius": 0.3 * s, "vmin": 3.0 * s, "vmax": 7.0 * s, "dir": Vector3.UP, "spread": 80.0,
		"gravity": Vector3(0, -6, 0), "smin": 0.1 * s, "smax": 0.22 * s, "color": c.lightened(0.2), "damp": 2.0}).position.y = 0.7 * s
	_particles(n, {"amount": 8, "life": 0.9, "mesh": "box", "mat": "debris", "radius": 0.3 * s, "vmin": 2.5 * s, "vmax": 5.0 * s, "dir": Vector3.UP, "spread": 60.0,
		"gravity": Vector3(0, -14, 0), "smin": 0.1 * s, "smax": 0.22 * s, "shrink": false, "fade": false, "color": c.darkened(0.45)}).position.y = 0.6 * s
	var ring := _decal(n, 6, 4.0 * s, 4.0 * s, c, Color(1, 0.9, 0.7), true, 1.8)
	var fl := _sprite(n, c, Color(1, 1, 0.9), 2.0 * s, 2.5, 0, 0.8 * s)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.4, 0.0, 1.0)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", k * 0.95)
		_set_alpha(ring, 1.0 - k)
		_set_alpha(fl, 1.0 - clampf(node.t / 0.2, 0.0, 1.0))
	return n

func _death_burst_lite(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var c := _c(o, "color", Color(1.0, 0.45, 0.2))
	var s := _f(o, "size", 1.0)
	var n := _node(root, "death_burst", p)
	n.free_after = 0.8
	_particles(n, {"amount": 12, "life": 0.55, "radius": 0.3 * s, "vmin": 3.0 * s, "vmax": 6.0 * s, "dir": Vector3.UP, "spread": 80.0,
		"gravity": Vector3(0, -6, 0), "smin": 0.1 * s, "smax": 0.2 * s, "color": c.lightened(0.2), "damp": 2.0}).position.y = 0.7 * s
	return n

func _column(n: Node3D, c: Color, c2: Color, r: float, h: float, intensity := 2.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("column")
	mi.material_override = SH.new_add_mat(c, c2, 3, intensity)
	mi.scale = Vector3(r * 2.0, h, r * 2.0)
	mi.position = Vector3(0, h * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return mi

func _level_up(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var n := _node(root, "level_up", p)
	n.free_after = 1.8
	var gold := Color(1.0, 0.78, 0.25)
	var col := _column(n, gold, Color(1, 1, 0.8), 0.9, 4.5, 2.4)
	_particles(n, {"amount": 34, "life": 1.3, "shape": "ring", "radius": 0.9, "vmin": 1.5, "vmax": 3.5, "dir": Vector3.UP, "spread": 10.0,
		"gravity": Vector3(0, 1.0, 0), "smin": 0.08, "smax": 0.18, "color": Color(1.0, 0.85, 0.4), "explode": 0.6})
	var ring := _decal(n, 6, 5.0, 5.0, gold, Color(1, 1, 0.8), true, 2.0)
	var rune := _decal(n, 5, 2.6, 2.6, gold, Color(1, 0.95, 0.7), true, 1.8)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.35, 0.0, 1.0)
		col.scale.y = lerpf(0.2, 4.5, k)
		col.position.y = col.scale.y * 0.5
		var fade := 1.0 - clampf((node.t - 1.0) / 0.8, 0.0, 1.0)
		_set_alpha(col, fade)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", clampf(node.t / 0.5, 0.0, 1.0))
		_set_alpha(ring, 1.0 - clampf(node.t / 0.5, 0.0, 1.0))
		_set_alpha(rune, fade)
	return n

func _heal(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var n := _node(root, "heal", p)
	n.free_after = 1.3
	var g := Color(0.35, 1.0, 0.45)
	var col := _column(n, g, Color(0.9, 1, 0.8), 0.6, 2.4, 1.6)
	_particles(n, {"amount": 18, "life": 1.0, "shape": "ring", "radius": 0.6, "inner": 0.1, "vmin": 1.0, "vmax": 2.2, "dir": Vector3.UP, "spread": 15.0,
		"smin": 0.12, "smax": 0.22, "color": Color(0.5, 1.0, 0.55), "explode": 0.4}).position.y = 0.3
	n.update = func(node: FxNode, _dt: float) -> void:
		_set_alpha(col, sin(clampf(node.t / 1.0, 0.0, 1.0) * PI))
	return n

func _gold(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = maxf(p.y, 0.6)
	var amount := int(_f(o, "amount", 0.0))
	var n := _node(root, "gold", p)
	n.free_after = 1.0
	var coin := MeshInstance3D.new()
	coin.mesh = _mesh("coin")
	coin.material_override = _coin_mat()
	coin.rotation_degrees = Vector3(90, 0, 0)
	n.add_child(coin)
	var l: Label3D = null
	if amount > 0:
		l = _label(n, "+%d" % amount, Color("ffd54a"), 56)
		l.position = Vector3(0.45, 0.35, 0)
	var sp := _sprite(n, Color(1.0, 0.75, 0.2), Color(1, 1, 0.8), 0.9, 1.5)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 1.0, 0.0, 1.0)
		coin.position.y = 1.4 * (1.0 - pow(1.0 - k, 3.0))
		coin.rotate_y(_dt * 9.0)
		sp.position.y = coin.position.y
		_set_alpha(sp, 1.0 - k)
		if l:
			l.position.y = 0.35 + k * 1.1
			l.modulate.a = 1.0 - smoothstep(0.6, 1.0, k)
			l.outline_modulate.a = l.modulate.a
		if k > 0.7:
			coin.scale = Vector3.ONE * (1.0 - (k - 0.7) / 0.3)
	return n

func _damage_number(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos")
	p.y = (p.y + 0.6) if p.y > 0.5 else 2.1
	p.x += randf_range(-0.35, 0.35)
	var crit: bool = bool(o.get("crit", false))
	var amount := _f(o, "amount", 0.0)
	var c := _c(o, "color", Color(1.0, 0.55, 0.15) if crit else Color(1.0, 0.97, 0.9))
	var n := _node(root, "damage_number", p)
	n.free_after = 0.95
	var txt := str(int(round(amount)))
	if crit:
		txt += "!"
	if o.has("text"):
		txt = str(o["text"])
	var l := _label(n, txt, c, 96 if crit else 64)
	# constant on-screen size (~44 px tall at 1080p, crits ~66 px) regardless of camera zoom
	l.fixed_size = true
	l.pixel_size = 0.00073  # digits ~= font_size * 0.69 px at 1080p with a 45 deg fov
	l.outline_size = 22 if crit else 16
	l.outline_modulate = Color(0.04, 0.02, 0.01, 1.0)
	var drift := randf_range(-0.4, 0.4)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := node.t
		var pop := 1.0 + (0.6 if crit else 0.35) * (1.0 - clampf(k / 0.14, 0.0, 1.0))
		if k < 0.06:
			pop = lerpf(0.4, 1.6 if crit else 1.35, k / 0.06)
		l.scale = Vector3.ONE * pop
		l.position = Vector3(drift * k, k * 1.3 - k * k * 0.5, 0)
		var a := 1.0 - smoothstep(0.6, 0.95, k)
		l.modulate.a = a
		l.outline_modulate.a = a * 0.95
	return n

func _teleport(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var n := _node(root, "teleport", p)
	n.free_after = 1.1
	var c := _c(o, "color", Color(0.55, 0.45, 1.0))
	var col := _column(n, c, Color(0.85, 0.95, 1.0), 0.8, 5.0, 2.8)
	_particles(n, {"amount": 30, "life": 0.6, "radius": 2.2, "vmin": 0.0, "vmax": 0.3, "radial": -14.0, "smin": 0.1, "smax": 0.2,
		"color": Color(0.7, 0.75, 1.0)}).position.y = 1.0
	var ring := _decal(n, 6, 4.0, 4.0, c, Color(0.9, 0.95, 1), true, 2.0)
	var fl := _sprite(n, c, Color(1, 1, 1), 2.4, 2.2, 0, 1.0)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 1.0, 0.0, 1.0)
		col.scale.x = lerpf(1.6, 0.2, k); col.scale.z = col.scale.x
		_set_alpha(col, 1.0 - k)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", 1.0 - clampf(node.t / 0.5, 0.0, 1.0))
		_set_alpha(ring, 1.0 - k)
		_set_alpha(fl, clampf(1.0 - absf(node.t - 0.3) / 0.3, 0.0, 1.0))
	return n

func _tether_pull(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := _f(o, "radius", 3.0)
	var n := _node(root, "tether_pull", p)
	n.free_after = 0.9
	var c := _c(o, "color", Color(1.0, 0.5, 0.15))
	var tc := o.has("color")
	var ring := _decal(n, 6, r * 2.0, r * 2.0, c, c.lerp(Color.WHITE, 0.6) if tc else Color(1, 0.85, 0.5), true, 2.4)
	var rune := _decal(n, 5, r * 2.0, r * 2.0, c, c.lerp(Color.WHITE, 0.4) if tc else Color(1.0, 0.75, 0.4), true, 1.2)
	_particles(n, {"amount": 32, "life": 0.55, "shape": "ring", "radius": r, "inner": r * 0.8, "vmin": 0.0, "vmax": 0.2, "radial": -r * 9.0,
		"tangent": 6.0, "smin": 0.12, "smax": 0.24, "color": c.lerp(Color.WHITE, 0.2) if tc else Color(1.0, 0.6, 0.25)}).position.y = 0.4
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.45, 0.0, 1.0)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", 1.0 - k * k)
		_set_alpha(ring, 1.0 - smoothstep(0.7, 1.0, k))
		_set_alpha(rune, 1.0 - clampf(node.t / 0.8, 0.0, 1.0))
	return n

func _slip_trail(o: Dictionary, root: Node) -> FxNode:
	var a := _v(o, "from"); var b := _v(o, "to", a + Vector3(0, 0, -3))
	var n := _node(root, "slip_trail", Vector3.ZERO)
	n.global_position = Vector3.ZERO
	n.free_after = 0.75
	var c := _c(o, "color", Color(0.25, 1.0, 0.9))
	var tc := o.has("color")
	var rib := MeshInstance3D.new()
	rib.mesh = _mesh("plane")
	var m := SH.new_add_mat(c, c.lerp(Color.WHITE, 0.5) if tc else Color(0.75, 0.6, 1.0), 2, 1.3)
	m.set_shader_parameter("len", a.distance_to(b))
	rib.material_override = m
	rib.transform = _line_xform(a, b, 1.0, 0.9)
	n.add_child(rib)
	var rib2 := MeshInstance3D.new()
	rib2.mesh = _mesh("plane")
	rib2.material_override = m
	var dd := Vector3(b.x - a.x, 0, b.z - a.z)
	var dl := maxf(dd.length(), 0.05)
	var dn := dd / dl if dd.length() > 0.001 else Vector3.FORWARD
	rib2.transform = Transform3D(Basis(Vector3.UP * 0.9, Vector3.UP.cross(dn).normalized(), dn * dl), Vector3((a.x + b.x) * 0.5, 0.9, (a.z + b.z) * 0.5))
	n.add_child(rib2)
	var mid := (a + b) * 0.5
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var pp := _particles(n, {"amount": 22, "life": 0.5, "shape": "box", "box": Vector3(0.3, 0.4, maxf(d.length() * 0.5, 0.1)), "vmin": 0.2, "vmax": 1.0,
		"smin": 0.08, "smax": 0.18, "color": c.lerp(Color.WHITE, 0.3) if tc else Color(0.6, 1.0, 1.0), "gravity": Vector3(0, 1.0, 0)})
	pp.global_transform = Transform3D(Basis.looking_at(d.normalized() if d.length() > 0.01 else Vector3.FORWARD, Vector3.UP), Vector3(mid.x, 0.9, mid.z))
	n.update = func(node: FxNode, _dt: float) -> void:
		m.set_shader_parameter("alpha", 1.0 - clampf(node.t / 0.6, 0.0, 1.0))
	return n

func _shatter(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = maxf(p.y, 1.0)
	var n := _node(root, "shatter", p)
	n.free_after = 1.0
	var c := _c(o, "color", Color(0.75, 0.35, 1.0))
	var tc := o.has("color")
	_particles(n, {"amount": 14, "life": 0.7, "mesh": "shard", "mat": "glow", "radius": 0.2, "vmin": 4.0, "vmax": 8.0, "gravity": Vector3(0, -10, 0),
		"smin": 0.15, "smax": 0.3, "color": c.lerp(Color.WHITE, 0.2) if tc else Color(0.7, 0.5, 1.0), "damp": 1.0})
	_particles(n, {"amount": 16, "life": 0.4, "vmin": 3.0, "vmax": 6.0, "smin": 0.1, "smax": 0.2, "color": c.lerp(Color.WHITE, 0.5) if tc else Color(0.4, 1.0, 0.95), "damp": 5.0})
	var fl := _sprite(n, c, Color(1, 0.9, 1), 2.2, 2.6, 6)
	var ring := _decal(n, 6, 3.4, 3.4, c, c.lerp(Color.WHITE, 0.5) if tc else Color(0.6, 1.0, 1.0), true, 2.0)
	ring.position.y = 0.06 - p.y
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.3, 0.0, 1.0)
		fl.scale = Vector3.ONE * lerpf(1.0, 2.6, k)
		_set_alpha(fl, 1.0 - k)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", clampf(node.t / 0.35, 0.0, 1.0))
		_set_alpha(ring, 1.0 - clampf(node.t / 0.45, 0.0, 1.0))
	return n

func _rift_strike(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var n := _node(root, "rift_strike", p)
	n.free_after = 0.6
	var slashes: Array = []
	for i in 2:
		var s := MeshInstance3D.new()
		s.mesh = _mesh("quad")
		s.material_override = SH.new_add_mat(Color(0.25, 1.0, 0.9) if i == 0 else Color(0.75, 0.4, 1.0), Color(1, 1, 1), 4, 3.0)
		s.position = Vector3(0, 1.1, 0)
		s.rotation = Vector3(0, randf() * TAU, (0.7 if i == 0 else -0.7))
		s.scale = Vector3(2.4, 2.4, 1)
		n.add_child(s)
		slashes.append(s)
	_particles(n, {"amount": 16, "life": 0.4, "vmin": 2.0, "vmax": 5.0, "smin": 0.08, "smax": 0.16, "color": Color(0.5, 1.0, 0.95), "damp": 3.0}).position.y = 1.0
	var ring := _decal(n, 6, 2.6, 2.6, Color(0.3, 1.0, 0.9), Color(0.8, 0.6, 1.0), true, 1.8)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.35, 0.0, 1.0)
		for i in slashes.size():
			var s: MeshInstance3D = slashes[i]
			var kk := clampf((node.t - i * 0.07) / 0.3, 0.0, 1.0)
			s.scale = Vector3(2.0 + kk * 1.2, 2.0 + kk * 1.2, 1)
			_set_alpha(s, (1.0 - kk) * (1.0 if node.t >= i * 0.07 else 0.0))
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", k)
		_set_alpha(ring, 1.0 - k)
	return n

func _brood_hatch(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var n := _node(root, "brood_hatch", p)
	n.free_after = 1.0
	_particles(n, {"amount": 16, "life": 0.7, "mat": "mix", "radius": 0.2, "vmin": 2.0, "vmax": 4.0, "dir": Vector3.UP, "spread": 60.0,
		"gravity": Vector3(0, -12, 0), "smin": 0.12, "smax": 0.24, "color": Color(0.45, 0.85, 0.1, 0.95)}).position.y = 0.3
	_particles(n, {"amount": 8, "life": 0.8, "mesh": "shard", "mat": "debris", "radius": 0.2, "vmin": 2.0, "vmax": 3.5, "dir": Vector3.UP, "spread": 50.0,
		"gravity": Vector3(0, -12, 0), "smin": 0.1, "smax": 0.18, "shrink": false, "fade": false, "color": Color(0.9, 0.85, 0.65)}).position.y = 0.3
	var ring := _decal(n, 6, 2.0, 2.0, Color(0.6, 1.0, 0.2), Color(0.9, 1, 0.6), true, 1.8)
	var pool := _decal(n, 4, 1.4, 1.4, Color(0.25, 0.45, 0.06, 0.9), Color(0.6, 0.95, 0.2), false)
	n.update = func(node: FxNode, _dt: float) -> void:
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", clampf(node.t / 0.3, 0.0, 1.0))
		_set_alpha(ring, 1.0 - clampf(node.t / 0.35, 0.0, 1.0))
		_set_alpha(pool, 1.0 - clampf((node.t - 0.5) / 0.5, 0.0, 1.0))
	return n

func _sacrifice(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := _f(o, "radius", 3.0)
	var n := _node(root, "sacrifice_explosion", p)
	n.free_after = 1.5
	var g := _c(o, "color", Color(0.6, 1.0, 0.15))
	var tc := o.has("color")
	var ring := _decal(n, 6, r * 2.0, r * 2.0, g, g.lerp(Color.WHITE, 0.6) if tc else Color(1, 1, 0.6), true, 2.6)
	var splat := _decal(n, 4, r * 1.6, r * 1.6, Color(g.r * 0.4, g.g * 0.4, g.b * 0.4, 0.9) if tc else Color(0.25, 0.5, 0.05, 0.9), g if tc else Color(0.7, 1.0, 0.2), false)
	_particles(n, {"amount": 26, "life": 0.7, "radius": 0.4, "vmin": 3.0, "vmax": 3.0 + r * 2.0, "dir": Vector3.UP, "spread": 75.0,
		"gravity": Vector3(0, -8, 0), "smin": 0.18, "smax": 0.35, "color": g.lerp(Color.WHITE, 0.3) if tc else Color(0.7, 1.0, 0.3), "damp": 1.5}).position.y = 0.5
	_particles(n, {"amount": 14, "life": 0.9, "mat": "mix", "radius": 0.5, "vmin": 3.0, "vmax": 6.0, "dir": Vector3.UP, "spread": 70.0,
		"gravity": Vector3(0, -14, 0), "smin": 0.15, "smax": 0.3, "color": Color(g.r * 0.55, g.g * 0.55, g.b * 0.55, 0.95) if tc else Color(0.35, 0.7, 0.08, 0.95)}).position.y = 0.4
	var fl := _sprite(n, g, Color(1, 1, 0.8), r * 1.6, 2.6, 0, 0.8)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.4, 0.0, 1.0)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", sqrt(k))
		_set_alpha(ring, 1.0 - k)
		_set_alpha(fl, 1.0 - clampf(node.t / 0.25, 0.0, 1.0))
		_set_alpha(splat, 1.0 - clampf((node.t - 0.8) / 0.6, 0.0, 1.0))
	return n

func _slam(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := _f(o, "radius", 3.0)
	var n := _node(root, "slam", p)
	n.free_after = 1.7
	var dust := Color(0.55, 0.46, 0.36, 0.85)
	var ring := _decal(n, 6, r * 2.2, r * 2.2, dust, Color(0.8, 0.7, 0.55, 0.9), false)
	var sc := _c(o, "color", Color(1.0, 0.45, 0.1))
	var cracks := _decal(n, 7, r * 1.8, r * 1.8, Color(0.2, 0.1, 0.05), sc, false)
	(cracks.material_override as ShaderMaterial).set_shader_parameter("fill", 1.0)
	_particles(n, {"amount": 14, "life": 1.0, "mesh": "box", "mat": "debris", "radius": r * 0.4, "vmin": 4.0, "vmax": 7.5, "dir": Vector3.UP, "spread": 40.0,
		"gravity": Vector3(0, -16, 0), "smin": 0.15, "smax": 0.35, "shrink": false, "fade": false, "color": Color(0.42, 0.38, 0.4)}).position.y = 0.2
	_particles(n, {"amount": 16, "life": 1.0, "mat": "mix", "shape": "ring", "radius": r * 0.7, "inner": r * 0.3, "vmin": 1.0, "vmax": 3.0, "radial": 3.0,
		"dir": Vector3.UP, "spread": 50.0, "gravity": Vector3(0, 0.4, 0), "smin": 0.8, "smax": 1.5, "grow": true, "color": dust, "damp": 2.5}).position.y = 0.3
	var fl := _sprite(n, _c(o, "color", Color(1.0, 0.55, 0.2)), Color(1, 0.9, 0.7), r * 1.2, 2.0, 0, 0.5)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.45, 0.0, 1.0)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", sqrt(k))
		_set_alpha(ring, 1.0 - k)
		(cracks.material_override as ShaderMaterial).set_shader_parameter("fill", 1.0 - clampf(node.t / 1.6, 0.0, 1.0))
		_set_alpha(cracks, 1.0 - clampf((node.t - 1.0) / 0.6, 0.0, 1.0))
		_set_alpha(fl, 1.0 - clampf(node.t / 0.2, 0.0, 1.0))
	return n

func _slam_lite(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := _f(o, "radius", 3.0)
	var n := _node(root, "slam", p)
	n.free_after = 0.5
	var ring := _decal(n, 6, r * 2.2, r * 2.2, Color(0.55, 0.46, 0.36, 0.85), Color(0.8, 0.7, 0.55, 0.9), false)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.45, 0.0, 1.0)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", sqrt(k))
		_set_alpha(ring, 1.0 - k)
	return n

func _fountain_heal(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var n := _node(root, "fountain_heal", p)
	n.free_after = 1.6
	var c := Color(0.3, 0.95, 1.0)
	var col := _column(n, c, Color(0.8, 1, 0.9), 0.8, 3.2, 1.8)
	_particles(n, {"amount": 36, "life": 1.3, "shape": "ring", "radius": 0.9, "inner": 0.7, "vmin": 1.2, "vmax": 2.4, "dir": Vector3.UP, "spread": 5.0,
		"tangent": 4.0, "smin": 0.1, "smax": 0.2, "color": Color(0.5, 1.0, 0.9), "explode": 0.3})
	var ring := _decal(n, 6, 3.6, 3.6, c, Color(0.8, 1, 0.9), true, 2.0)
	n.update = func(node: FxNode, _dt: float) -> void:
		_set_alpha(col, sin(clampf(node.t / 1.4, 0.0, 1.0) * PI))
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", clampf(node.t / 0.5, 0.0, 1.0))
		_set_alpha(ring, 1.0 - clampf(node.t / 0.6, 0.0, 1.0))
	return n

# ------------------------------------------------------------------ persistent

func _telegraph_circle(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := _f(o, "radius", 2.0)
	var n := _node(root, "telegraph_circle", p)
	n.duration = _f(o, "duration", 1.0)
	n.fade_time = 0.15
	var tcol := _c(o, "color", Color(1.0, 0.16, 0.08, 1.0))
	var d := _decal(n, 0, r * 2.0, r * 2.0, tcol, tcol.lerp(Color.WHITE, 0.45) if o.has("color") else Color(1.0, 0.6, 0.2, 1.0), false, 1.4)
	var m: ShaderMaterial = d.material_override
	n.mats.append(m)
	n.update = func(node: FxNode, _dt: float) -> void:
		m.set_shader_parameter("fill", clampf(node.t / maxf(node.duration, 0.01), 0.0, 1.0))
	n.params_cb = func(node: FxNode, op: Dictionary) -> void:
		if op.has("color"):
			var cc := _c(op, "color", tcol)
			m.set_shader_parameter("color", cc); m.set_shader_parameter("color2", cc.lerp(Color.WHITE, 0.45))
		if op.has("pos"):
			var q := _v(op, "pos"); node.global_position = Vector3(q.x, 0, q.z)
		if op.has("radius"):
			var rr := _f(op, "radius", 2.0)
			d.scale = Vector3(rr * 2.0, 1, rr * 2.0); m.set_shader_parameter("size", Vector2(rr * 2.0, rr * 2.0))
	return n

func _telegraph_line(o: Dictionary, root: Node) -> FxNode:
	var a := _v(o, "from"); var b := _v(o, "to", a + Vector3(0, 0, -4))
	var w := _f(o, "width", 1.5)
	var n := _node(root, "telegraph_line", Vector3.ZERO)
	n.global_position = Vector3.ZERO
	n.duration = _f(o, "duration", 1.0)
	n.fade_time = 0.15
	var d := _decal(n, 1, w, a.distance_to(b), Color(1.0, 0.16, 0.08, 1.0), Color(1.0, 0.6, 0.2, 1.0), false, 1.4)
	d.transform = _line_xform(a, b, w)
	var m: ShaderMaterial = d.material_override
	m.set_shader_parameter("size", Vector2(w, Vector2(b.x - a.x, b.z - a.z).length()))
	n.mats.append(m)
	n.update = func(node: FxNode, _dt: float) -> void:
		m.set_shader_parameter("fill", clampf(node.t / maxf(node.duration, 0.01), 0.0, 1.0))
	n.params_cb = func(node: FxNode, op: Dictionary) -> void:
		var aa := _v(op, "from", a); var bb := _v(op, "to", b); var ww := _f(op, "width", w)
		d.transform = _line_xform(aa, bb, ww)
		m.set_shader_parameter("size", Vector2(ww, Vector2(bb.x - aa.x, bb.z - aa.z).length()))
	return n

func _aim_circle(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := _f(o, "radius", 2.0)
	var n := _node(root, "aim_circle", p)
	n.fade_time = 0.08
	var d := _decal(n, 2, r * 2.0, r * 2.0, Color(0.55, 0.95, 1.0, 1.0), Color(1, 1, 1, 1), true, 1.2)
	var m: ShaderMaterial = d.material_override
	n.mats.append(m)
	n.params_cb = func(node: FxNode, op: Dictionary) -> void:
		if op.has("pos"):
			var q := _v(op, "pos"); node.global_position = Vector3(q.x, 0, q.z)
		if op.has("radius"):
			var rr := _f(op, "radius", r)
			d.scale = Vector3(rr * 2.0, 1, rr * 2.0); m.set_shader_parameter("size", Vector2(rr * 2.0, rr * 2.0))
		if op.has("color"):
			m.set_shader_parameter("color", _c(op, "color", Color.WHITE))
	return n

func _aim_line(o: Dictionary, root: Node) -> FxNode:
	var a := _v(o, "from"); var b := _v(o, "to", a + Vector3(0, 0, -4))
	var w := _f(o, "width", 1.0)
	var n := _node(root, "aim_line", Vector3.ZERO)
	n.global_position = Vector3.ZERO
	n.fade_time = 0.08
	var d := _decal(n, 3, w, a.distance_to(b), Color(0.55, 0.95, 1.0, 1.0), Color(1, 1, 1, 1), true, 1.2)
	d.transform = _line_xform(a, b, w)
	var m: ShaderMaterial = d.material_override
	m.set_shader_parameter("size", Vector2(w, Vector2(b.x - a.x, b.z - a.z).length()))
	n.mats.append(m)
	n.data = {"from": a, "to": b, "width": w}
	n.params_cb = func(node: FxNode, op: Dictionary) -> void:
		var aa := _v(op, "from", node.data["from"]); var bb := _v(op, "to", node.data["to"]); var ww := _f(op, "width", node.data["width"])
		node.data["from"] = aa; node.data["to"] = bb; node.data["width"] = ww
		d.transform = _line_xform(aa, bb, ww)
		m.set_shader_parameter("size", Vector2(ww, Vector2(bb.x - aa.x, bb.z - aa.z).length()))
		if op.has("color"):
			m.set_shader_parameter("color", _c(op, "color", Color.WHITE))
	return n

func _ash_wall(o: Dictionary, root: Node) -> FxNode:
	var a := _v(o, "from"); var b := _v(o, "to", a + Vector3(4, 0, 0))
	a.y = 0; b.y = 0
	var n := _node(root, "ash_wall", (a + b) * 0.5)
	n.duration = _f(o, "duration", 4.0)
	n.fade_time = 0.45
	n.linger = 0.8
	var d := b - a
	var L := maxf(d.length(), 0.5)
	n.global_transform = Transform3D(Basis.looking_at(d / L if d.length() > 0.01 else Vector3.FORWARD, Vector3.UP), (a + b) * 0.5)
	var MK = load("res://art/mesh_kit.gd")
	var k = MK.new()
	var ash := Color("4a4448"); var ash2 := Color("6a6264"); var ember := Color("ff6a1e")
	var cnt := int(ceil(L / 0.55)) + 1
	var rng := RandomNumberGenerator.new(); rng.seed = int(a.x * 13.0 + a.z * 7.0)
	for i in cnt:
		var z := -L * 0.5 + L * float(i) / maxf(cnt - 1, 1)
		var h := 1.1 + rng.randf() * 0.9
		var w := 0.45 + rng.randf() * 0.3
		k.prism(Vector3(w, h, 0.55 + rng.randf() * 0.3), Vector3(rng.randf_range(-0.12, 0.12), h * 0.5, z), ash if i % 2 == 0 else ash2,
			Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 360), rng.randf_range(-14, 14)))
		k.box(Vector3(0.05, h * 0.6, 0.05), Vector3(rng.randf_range(-0.1, 0.1), h * 0.35, z + rng.randf_range(-0.1, 0.1)), ember, Vector3(0, 0, rng.randf_range(-20, 20)), 2.4)
	k.box(Vector3(0.9, 0.22, L + 0.4), Vector3(0, 0.08, 0), Color("2e2a2c"))
	k.box(Vector3(0.7, 0.04, L + 0.2), Vector3(0, 0.2, 0), ember, Vector3.ZERO, 1.6)
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	var um := SH.new_unit_mat(Color(1.0, 0.45, 0.1), 2.0)
	um.set_shader_parameter("rim_color", Color(1.0, 0.5, 0.2))
	um.set_shader_parameter("rim_strength", 0.6)
	mi.material_override = um
	mi.position.y = -1.6
	n.add_child(mi)
	var fire := _particles(n, {"amount": int(clampf(L * 6.0, 8.0, 40.0)), "life": 0.8, "one_shot": false, "shape": "box", "box": Vector3(0.3, 0.3, L * 0.5),
		"vmin": 0.6, "vmax": 1.6, "dir": Vector3.UP, "spread": 15.0, "gravity": Vector3(0, 1.5, 0), "smin": 0.3, "smax": 0.6, "color": Color(1.0, 0.5, 0.12), "mid": 0.4})
	fire.position.y = 0.6
	n.parts.append(fire)
	n.update = func(node: FxNode, _dt: float) -> void:
		if not node.stopping:
			mi.position.y = lerpf(-1.6, 0.0, 1.0 - pow(1.0 - clampf(node.t / 0.22, 0.0, 1.0), 3.0))
			um.set_shader_parameter("glow_boost", 0.4 + 0.2 * sin(node.t * 6.0))
		else:
			var k2 := clampf(node.stop_t / 0.45, 0.0, 1.0)
			mi.position.y = -1.0 * k2 * k2
			um.set_shader_parameter("dissolve", k2)
	return n

func _foundry_aura(o: Dictionary, root: Node) -> FxNode:
	var tgt = o.get("target")
	var p := _v(o, "pos")
	if tgt is Node3D and is_instance_valid(tgt):
		p = (tgt as Node3D).global_position
	var n := _node(root, "foundry_aura", p)
	n.duration = _f(o, "duration", 10.0)
	n.fade_time = 0.4
	n.linger = 1.0
	if tgt is Node3D:
		n.target = tgt; n.follow = true
	var r := 1.8
	var d := _decal(n, 5, r * 2.0, r * 2.0, Color(1.0, 0.45, 0.1), Color(1.0, 0.85, 0.4), true, 2.0)
	var m: ShaderMaterial = d.material_override
	n.mats.append(m)
	var em := _particles(n, {"amount": 26, "life": 1.1, "one_shot": false, "shape": "ring", "radius": 1.3, "inner": 0.4, "vmin": 1.0, "vmax": 2.6, "dir": Vector3.UP,
		"spread": 12.0, "gravity": Vector3(0, 1.2, 0), "smin": 0.08, "smax": 0.18, "color": Color(1.0, 0.6, 0.2)})
	n.parts.append(em)
	var glow := _sprite(n, Color(1.0, 0.45, 0.12), Color(1.0, 0.8, 0.4), 3.0, 0.9, 0, 1.0)
	n.mats.append(glow.material_override)
	n.update = func(node: FxNode, _dt: float) -> void:
		d.rotation.y = node.t * 0.6
		if not node.stopping:
			(glow.material_override as ShaderMaterial).set_shader_parameter("alpha", 0.6 + 0.25 * sin(node.t * 5.0))
	return n

## Ground ring showing a buffer enemy's aura (Ward Chanter / War Drummer). Follows `target` until stop().
func _buff_aura(o: Dictionary, root: Node) -> FxNode:
	var tgt = o.get("target")
	var p := _v(o, "pos")
	if tgt is Node3D and is_instance_valid(tgt):
		p = (tgt as Node3D).global_position
	var n := _node(root, "buff_aura", p)
	n.fade_time = 0.3
	if tgt is Node3D:
		n.target = tgt; n.follow = true
	var r := _f(o, "radius", 4.5)
	var c := _c(o, "color", Color(1.0, 0.85, 0.35))
	var d := _decal(n, 5, r * 2.0, r * 2.0, c, c.lerp(Color.WHITE, 0.5), true, 0.9)
	n.mats.append(d.material_override)
	var pulse := _decal(n, 6, r * 2.0, r * 2.0, c, Color(1, 1, 1), true, 1.1)
	n.mats.append(pulse.material_override)
	var em := _particles(n, {"amount": 10, "life": 1.4, "one_shot": false, "shape": "ring", "radius": r * 0.95, "inner": r * 0.85, "vmin": 0.4, "vmax": 1.0,
		"dir": Vector3.UP, "spread": 10.0, "smin": 0.08, "smax": 0.16, "color": c})
	n.parts.append(em)
	var glow := _sprite(n, c, c.lerp(Color.WHITE, 0.6), 1.4, 1.6, 0, 2.4)
	n.mats.append(glow.material_override)
	n.update = func(node: FxNode, _dt: float) -> void:
		d.rotation.y = node.t * 0.4
		var k := fmod(node.t * 0.7, 1.0)
		(pulse.material_override as ShaderMaterial).set_shader_parameter("fill", k)
		if not node.stopping:
			(pulse.material_override as ShaderMaterial).set_shader_parameter("alpha", (1.0 - k) * 0.8)
			(glow.material_override as ShaderMaterial).set_shader_parameter("alpha", 0.55 + 0.3 * sin(node.t * 4.0))
	return n

func _mark(o: Dictionary, root: Node) -> FxNode:
	var tgt = o.get("target")
	var p := _v(o, "pos")
	var h := 2.0
	if tgt is Node3D and is_instance_valid(tgt):
		p = (tgt as Node3D).global_position
		var hh = tgt.get("height")
		if hh != null:
			h = float(hh) + 0.45
	var n := _node(root, "mark", p)
	n.fade_time = 0.15
	if tgt is Node3D:
		n.target = tgt; n.follow = true
	var mc := _c(o, "color", Color(0.7, 0.3, 1.0))
	var s := _sprite(n, mc, mc.lerp(Color.WHITE, 0.5) if o.has("color") else Color(0.4, 1.0, 0.95), 0.75, 2.6, 6, h)
	n.mats.append(s.material_override)
	var ring := _decal(n, 2, 1.4, 1.4, mc, Color(1, 1, 1), true, 1.0)
	n.mats.append(ring.material_override)
	n.update = func(node: FxNode, _dt: float) -> void:
		var pulse := 1.0 + 0.12 * sin(node.t * 8.0)
		var pop := clampf(node.t / 0.12, 0.0, 1.0)
		s.scale = Vector3.ONE * 0.75 * pulse * lerpf(1.8, 1.0, pop)
		s.position.y = h + 0.08 * sin(node.t * 3.0)
	return n

func _rally_marker(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var n := _node(root, "rally_marker", p)
	n.duration = _f(o, "duration", 4.0)
	n.fade_time = 0.3
	n.linger = 1.0
	var g := _c(o, "color", Color(0.6, 1.0, 0.2))
	var d := _decal(n, 5, 2.6, 2.6, g, g.lerp(Color.WHITE, 0.6) if o.has("color") else Color(0.95, 1.0, 0.6), true, 1.8)
	n.mats.append(d.material_override)
	var pulse := _decal(n, 6, 3.4, 3.4, g, Color(1, 1, 0.7), true, 1.6)
	n.mats.append(pulse.material_override)
	var stalk := MeshInstance3D.new()
	stalk.mesh = _mesh("shard")
	stalk.material_override = SH.new_add_mat(g, Color(1, 1, 0.8), 1, 2.4)
	stalk.scale = Vector3(0.35, 1.3, 0.35)
	stalk.position.y = 0.65
	n.add_child(stalk)
	n.mats.append(stalk.material_override)
	var ph := _particles(n, {"amount": 16, "life": 1.4, "one_shot": false, "shape": "ring", "radius": 1.1, "inner": 0.2, "vmin": 0.5, "vmax": 1.4,
		"dir": Vector3.UP, "spread": 20.0, "tangent": 2.0, "smin": 0.1, "smax": 0.2, "color": g.lerp(Color.WHITE, 0.25) if o.has("color") else Color(0.7, 1.0, 0.35)})
	n.parts.append(ph)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := fmod(node.t, 1.0)
		(pulse.material_override as ShaderMaterial).set_shader_parameter("fill", k)
		if not node.stopping:
			(pulse.material_override as ShaderMaterial).set_shader_parameter("alpha", 1.0 - k)
		stalk.rotation.y = node.t * 2.0
		stalk.position.y = 0.65 + 0.1 * sin(node.t * 3.0)
	return n

func _carapace(o: Dictionary, root: Node) -> FxNode:
	var tgt = o.get("target")
	var p := _v(o, "pos")
	var r := 1.3
	var h := 2.0
	if tgt is Node3D and is_instance_valid(tgt):
		p = (tgt as Node3D).global_position
		var rr = tgt.get("radius")
		if rr != null:
			r = maxf(float(rr) * 2.0, 1.0)
		var hh = tgt.get("height")
		if hh != null:
			h = float(hh)
	var n := _node(root, "carapace", p)
	n.duration = _f(o, "duration", 8.0)
	n.fade_time = 0.35
	if tgt is Node3D:
		n.target = tgt; n.follow = true
	var dome := MeshInstance3D.new()
	dome.mesh = _mesh("sphere")
	var m := SH.new_add_mat(Color(0.45, 0.95, 0.2), Color(1.0, 0.95, 0.55), 5, 1.6)
	dome.material_override = m
	dome.position.y = h * 0.5
	n.add_child(dome)
	n.mats.append(m)
	var base := _decal(n, 5, r * 2.2, r * 2.2, Color(0.55, 1.0, 0.2), Color(1, 1, 0.6), true, 1.2)
	n.mats.append(base.material_override)
	n.update = func(node: FxNode, _dt: float) -> void:
		var pop := 1.0 - pow(1.0 - clampf(node.t / 0.25, 0.0, 1.0), 3.0)
		var pulse := 1.0 + 0.03 * sin(node.t * 4.0)
		dome.scale = Vector3(r * 2.0, h * 1.25, r * 2.0) * pop * pulse
		dome.rotation.y = node.t * 0.4
	return n

func _bloater_pool(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := _f(o, "radius", 2.5)
	var n := _node(root, "bloater_pool", p)
	n.duration = _f(o, "duration", 5.0)
	n.fade_time = 0.5
	n.linger = 0.8
	var d := _decal(n, 4, r * 2.0, r * 2.0, Color(0.22, 0.42, 0.05, 0.92), Color(0.7, 1.0, 0.2, 1.0), false, 1.2)
	var m: ShaderMaterial = d.material_override
	n.mats.append(m)
	var glow := _decal(n, 8, r * 2.2, r * 2.2, Color(0.5, 1.0, 0.15, 0.6), Color(0.5, 1.0, 0.15), true, 0.9)
	n.mats.append(glow.material_override)
	glow.position.y = 0.07
	var bub := _particles(n, {"amount": int(clampf(r * 5.0, 6.0, 24.0)), "life": 0.9, "one_shot": false, "shape": "ring", "radius": r * 0.7, "inner": 0.0,
		"vmin": 0.3, "vmax": 0.9, "dir": Vector3.UP, "spread": 10.0, "smin": 0.1, "smax": 0.25, "color": Color(0.75, 1.0, 0.3), "grow": true})
	n.parts.append(bub)
	n.update = func(node: FxNode, _dt: float) -> void:
		var g := 1.0 - pow(1.0 - clampf(node.t / 0.3, 0.0, 1.0), 2.0)
		d.scale = Vector3(r * 2.0 * g, 1, r * 2.0 * g)
		glow.scale = Vector3(r * 2.2 * g, 1, r * 2.2 * g)
	return n

func _beam(o: Dictionary, root: Node) -> FxNode:
	var a := _v(o, "from"); var b := _v(o, "to", a + Vector3(0, 0, -10))
	var w := _f(o, "width", 1.2)
	var n := _node(root, "beam", Vector3.ZERO)
	n.global_position = Vector3.ZERO
	n.duration = _f(o, "duration", 3.0)
	n.fade_time = 0.25
	var c := _c(o, "color", Color(0.55, 0.85, 1.0))
	var c2 := c.lerp(Color.WHITE, 0.55) if o.has("color") else Color(0.75, 0.95, 1.0)
	var m := SH.new_add_mat(c, c2, 2, 1.7)
	var mg := SH.new_add_mat(c * 0.8, c2.lerp(c, 0.4), 2, 0.7)
	n.mats.append(m); n.mats.append(mg)
	var q1 := MeshInstance3D.new(); q1.mesh = _mesh("plane"); q1.material_override = m; n.add_child(q1)
	var q2 := MeshInstance3D.new(); q2.mesh = _mesh("plane"); q2.material_override = m; n.add_child(q2)
	var qg := MeshInstance3D.new(); qg.mesh = _mesh("plane"); qg.material_override = mg; n.add_child(qg)
	var src := _sprite(n, c, c2, w * 1.4, 1.6)
	var hit := _sprite(n, c, c2, w * 1.2, 1.4)
	n.mats.append(src.material_override); n.mats.append(hit.material_override)
	var sparks := _particles(n, {"amount": 14, "life": 0.4, "one_shot": false, "vmin": 2.0, "vmax": 4.0, "smin": 0.08, "smax": 0.16, "color": c.lerp(Color.WHITE, 0.4) if o.has("color") else Color(0.7, 0.95, 1.0), "gravity": Vector3(0, -4, 0)})
	n.parts.append(sparks)
	var place := func(aa: Vector3, bb: Vector3, ww: float) -> void:
		var y := maxf(aa.y, 1.3)
		var A := Vector3(aa.x, y, aa.z); var B := Vector3(bb.x, y, bb.z)
		var t1 := _line_xform(A, B, ww, y)
		q1.transform = t1
		var dir := (B - A); var L := maxf(dir.length(), 0.05); dir = dir / L
		if dir.length_squared() < 0.0001:
			dir = Vector3.FORWARD   # ends on top of each other (e.g. the Matrons overlapping): keep the basis invertible
		var side := Vector3.UP.cross(dir).normalized()
		# vertical strip: same along-axis, width along up
		q2.transform = Transform3D(Basis(Vector3.UP * ww, side, dir * L), (A + B) * 0.5)
		qg.transform = _line_xform(A, B, ww * 1.6, 0.07)
		src.position = A
		hit.position = B
		sparks.position = B
		m.set_shader_parameter("len", L)
		mg.set_shader_parameter("len", L)
	place.call(a, b, w)
	n.data = {"from": a, "to": b, "width": w}
	n.params_cb = func(node: FxNode, op: Dictionary) -> void:
		var aa := _v(op, "from", node.data["from"]); var bb := _v(op, "to", node.data["to"]); var ww := _f(op, "width", node.data["width"])
		node.data["from"] = aa; node.data["to"] = bb; node.data["width"] = ww
		place.call(aa, bb, ww)
		if op.has("width"):
			src.scale = Vector3.ONE * ww * 1.4; hit.scale = Vector3.ONE * ww * 1.2
		if op.has("color"):
			var cc := _c(op, "color", c)
			var cc2 := cc.lerp(Color.WHITE, 0.55)
			m.set_shader_parameter("color", cc); m.set_shader_parameter("color2", cc2)
			mg.set_shader_parameter("color", cc * 0.8); mg.set_shader_parameter("color2", cc2.lerp(cc, 0.4))
			for sm in [src.material_override, hit.material_override]:
				(sm as ShaderMaterial).set_shader_parameter("color", cc); (sm as ShaderMaterial).set_shader_parameter("color2", cc2)
			sparks.color_ramp = _ramp(cc.lerp(Color.WHITE, 0.4))
	n.update = func(node: FxNode, _dt: float) -> void:
		if not node.stopping:
			var grow := clampf(node.t / 0.15, 0.0, 1.0)
			m.set_shader_parameter("alpha", grow * (0.85 + 0.15 * sin(node.t * 30.0)))
	return n

# ------------------------------------------------------------------ wave-2 hero fx

## Sweeping wedge on the ground (cleaves, shotgun blasts, shoves). Forward = dir.
func _cone(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := maxf(_f(o, "range", 3.0), 0.3)
	var ang := clampf(_f(o, "angle", 70.0), 5.0, 359.0)
	var c := _c(o, "color", Color(1.0, 0.6, 0.25))
	var d := _v(o, "dir", Vector3.FORWARD); d.y = 0.0
	if d.length() < 0.01:
		d = Vector3.FORWARD
	d = d.normalized()
	var n := _node(root, "cone", p)
	n.free_after = 0.75
	if n.is_inside_tree():
		n.global_basis = Basis.looking_at(d, Vector3.UP)
	else:
		n.basis = Basis.looking_at(d, Vector3.UP)
	var w := _decal(n, 10, r * 2.0, r * 2.0, c, c.lerp(Color.WHITE, 0.65), true, 1.9)
	var m: ShaderMaterial = w.material_override
	m.set_shader_parameter("arc", deg_to_rad(ang * 0.5))
	var sp := _particles(n, {"amount": 16, "life": 0.4, "shape": "point", "dir": Vector3(0, 0.15, -1), "spread": minf(ang * 0.5, 90.0),
		"vmin": r * 2.5, "vmax": r * 4.5, "damp": r * 6.0, "smin": 0.08, "smax": 0.17, "color": c.lerp(Color.WHITE, 0.3), "local": true})
	sp.position.y = 0.6
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.16, 0.0, 1.0)
		m.set_shader_parameter("fill", 1.0 - pow(1.0 - k, 2.0))
		m.set_shader_parameter("alpha", 1.0 - smoothstep(0.2, 0.6, node.t))
	return n

## Soft glowing ground circle with a rim and slow motes (heal wells, curses, sanctums).
func _zone(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := maxf(_f(o, "radius", 2.5), 0.2)
	var c := _c(o, "color", Color(0.5, 1.0, 0.65))
	var n := _node(root, "zone", p)
	var dur := _f(o, "duration", 0.0)
	n.duration = dur if dur > 0.0 else -1.0
	n.fade_time = 0.4
	n.linger = 0.9
	var dc := _decal(n, 11, r * 2.0, r * 2.0, c, c.lerp(Color.WHITE, 0.55), true, 1.25)
	var m: ShaderMaterial = dc.material_override
	n.mats.append(m)
	var motes := _particles(n, {"amount": int(clampf(r * 4.0, 6.0, 20.0)), "life": 1.6, "one_shot": false, "shape": "ring", "radius": r * 0.85, "inner": 0.0,
		"vmin": 0.25, "vmax": 0.7, "dir": Vector3.UP, "spread": 12.0, "gravity": Vector3(0, 0.3, 0), "smin": 0.08, "smax": 0.16, "color": c.lerp(Color.WHITE, 0.25)})
	n.parts.append(motes)
	n.data = {"r": r}
	n.update = func(node: FxNode, _dt: float) -> void:
		var g := 1.0 - pow(1.0 - clampf(node.t / 0.3, 0.0, 1.0), 2.0)
		var rr: float = node.data["r"]
		dc.scale = Vector3(rr * 2.0 * g, 1, rr * 2.0 * g)
	n.params_cb = func(node: FxNode, op: Dictionary) -> void:
		if op.has("pos"):
			var q := _v(op, "pos"); node.global_position = Vector3(q.x, 0, q.z)
		if op.has("radius"):
			var rr := maxf(_f(op, "radius", node.data["r"]), 0.2)
			node.data["r"] = rr
			m.set_shader_parameter("size", Vector2(rr * 2.0, rr * 2.0))
			motes.emission_ring_radius = rr * 0.85
		if op.has("color"):
			var cc := _c(op, "color", c)
			m.set_shader_parameter("color", cc); m.set_shader_parameter("color2", cc.lerp(Color.WHITE, 0.55))
	return n

## Expanding shockwave ring + dust and sparks.
func _ring_burst(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := maxf(_f(o, "radius", 3.0), 0.3)
	var c := _c(o, "color", Color(1.0, 0.8, 0.5))
	var n := _node(root, "ring_burst", p)
	n.free_after = 1.1
	var r1 := _decal(n, 6, r * 2.0, r * 2.0, c, c.lerp(Color.WHITE, 0.6), true, 2.4)
	var r2 := _decal(n, 6, r * 2.0, r * 2.0, c, Color(1, 1, 1), true, 1.4)
	_particles(n, {"amount": 14, "life": 0.8, "mat": "mix", "shape": "ring", "radius": r * 0.3, "inner": r * 0.1, "vmin": r * 1.5, "vmax": r * 2.6, "dir": Vector3.UP,
		"spread": 80.0, "damp": r * 1.5, "gravity": Vector3(0, 0.5, 0), "smin": 0.5, "smax": 1.0, "grow": true, "color": Color(0.5, 0.42, 0.34, 0.6)}).position.y = 0.25
	_particles(n, {"amount": 18, "life": 0.5, "shape": "ring", "radius": r * 0.2, "inner": 0.0, "vmin": r * 3.0, "vmax": r * 5.0, "dir": Vector3.UP, "spread": 85.0,
		"damp": r * 4.0, "gravity": Vector3(0, -4, 0), "smin": 0.08, "smax": 0.16, "color": c.lerp(Color.WHITE, 0.3)}).position.y = 0.4
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.42, 0.0, 1.0)
		(r1.material_override as ShaderMaterial).set_shader_parameter("fill", sqrt(k))
		_set_alpha(r1, 1.0 - k)
		var k2 := clampf((node.t - 0.1) / 0.5, 0.0, 1.0)
		(r2.material_override as ShaderMaterial).set_shader_parameter("fill", sqrt(k2) * 0.85)
		_set_alpha(r2, (1.0 - k2) * (1.0 if node.t > 0.1 else 0.0))
	return n

## Jagged sandstone wall with amber cracks rising along a segment (Stoneshaper).
func _stone_ridge(o: Dictionary, root: Node) -> FxNode:
	var a := _v(o, "from"); var b := _v(o, "to", a + Vector3(4, 0, 0))
	a.y = 0; b.y = 0
	var n := _node(root, "stone_ridge", (a + b) * 0.5)
	n.duration = _f(o, "duration", 4.0)
	n.fade_time = 0.45
	n.linger = 0.8
	var d := b - a
	var L := maxf(d.length(), 0.5)
	n.global_transform = Transform3D(Basis.looking_at(d / L if d.length() > 0.01 else Vector3.FORWARD, Vector3.UP), (a + b) * 0.5)
	var key := "ridge_%d" % int(round(L * 4.0))
	var mesh: Mesh = _res.get(key)
	if mesh == null:
		var MK = load("res://art/mesh_kit.gd")
		var k = MK.new()
		var st := Color("a8906e"); var st2 := Color("7a6650"); var sand := Color("d0a26a"); var amber := Color("ffb040")
		var cnt := int(ceil(L / 0.5)) + 1
		var rng := RandomNumberGenerator.new(); rng.seed = cnt * 31
		for i in cnt:
			var z := -L * 0.5 + L * float(i) / maxf(cnt - 1, 1)
			var h := 1.0 + rng.randf() * 0.9
			var w := 0.5 + rng.randf() * 0.3
			k.prism(Vector3(w, h, 0.6 + rng.randf() * 0.3), Vector3(rng.randf_range(-0.12, 0.12), h * 0.5, z), st if i % 2 == 0 else st2,
				Vector3(rng.randf_range(-10, 10), rng.randf_range(-30, 30), rng.randf_range(-12, 12)))
			k.box(Vector3(w * 0.8, h * 0.45, 0.5), Vector3(rng.randf_range(-0.1, 0.1), h * 0.22, z), sand if i % 3 == 0 else st2, Vector3(0, rng.randf_range(0, 90), rng.randf_range(-8, 8)))
			k.box(Vector3(0.05, h * 0.55, 0.05), Vector3(rng.randf_range(-0.3, -0.24) if i % 2 == 0 else rng.randf_range(0.24, 0.3), h * 0.32, z + rng.randf_range(-0.1, 0.1)), amber,
				Vector3(0, 0, rng.randf_range(-25, 25)), 2.4)
		k.box(Vector3(1.1, 0.2, L + 0.5), Vector3(0, 0.06, 0), Color("5a4a3a"))
		mesh = k.build()
		_res[key] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var um := SH.new_unit_mat(Color(1.0, 0.7, 0.25), 2.0)
	um.set_shader_parameter("rim_color", Color(1.0, 0.75, 0.45))
	um.set_shader_parameter("rim_strength", 0.55)
	mi.material_override = um
	mi.position.y = -2.0
	n.add_child(mi)
	_particles(n, {"amount": int(clampf(L * 3.0, 6.0, 18.0)), "life": 0.9, "mat": "mix", "shape": "box", "box": Vector3(0.5, 0.1, L * 0.5), "vmin": 0.8, "vmax": 2.2,
		"dir": Vector3.UP, "spread": 40.0, "gravity": Vector3(0, 0.3, 0), "damp": 1.5, "smin": 0.5, "smax": 1.0, "grow": true, "color": Color(0.55, 0.46, 0.34, 0.65)}).position.y = 0.2
	_particles(n, {"amount": int(clampf(L * 2.0, 4.0, 12.0)), "life": 0.9, "mesh": "box", "mat": "debris", "shape": "box", "box": Vector3(0.4, 0.1, L * 0.5), "vmin": 3.0, "vmax": 5.5,
		"dir": Vector3.UP, "spread": 30.0, "gravity": Vector3(0, -16, 0), "smin": 0.1, "smax": 0.22, "shrink": false, "fade": false, "color": Color(0.6, 0.5, 0.38)}).position.y = 0.3
	n.update = func(node: FxNode, _dt: float) -> void:
		if not node.stopping:
			mi.position.y = lerpf(-2.0, 0.0, 1.0 - pow(1.0 - clampf(node.t / 0.25, 0.0, 1.0), 3.0))
			um.set_shader_parameter("glow_boost", 0.35 + 0.15 * sin(node.t * 4.0))
		else:
			var k2 := clampf(node.stop_t / 0.45, 0.0, 1.0)
			mi.position.y = -1.2 * k2 * k2
			um.set_shader_parameter("dissolve", k2)
	return n

## Crimson splash.
func _blood_burst(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos")
	var s := clampf(_f(o, "size", 1.0), 0.3, 3.0)
	var n := _node(root, "blood_burst", Vector3(p.x, 0, p.z))
	n.free_after = 1.4
	var hy := maxf(p.y, 1.0)
	_particles(n, {"amount": 14, "life": 0.6, "mat": "mix", "radius": 0.15 * s, "vmin": 2.0 * s, "vmax": 4.5 * s, "dir": Vector3.UP, "spread": 75.0,
		"gravity": Vector3(0, -16, 0), "smin": 0.1 * s, "smax": 0.22 * s, "color": Color(0.62, 0.02, 0.08, 0.95), "fade": false}).position.y = hy
	_particles(n, {"amount": 8, "life": 0.35, "radius": 0.1 * s, "vmin": 1.5 * s, "vmax": 3.5 * s, "smin": 0.12 * s, "smax": 0.24 * s, "damp": 4.0,
		"color": Color(1.0, 0.18, 0.25)}).position.y = hy
	var fl := _sprite(n, Color(0.9, 0.08, 0.15), Color(1.0, 0.55, 0.55), 1.3 * s, 2.0, 0, hy)
	var pool := _decal(n, 4, 1.4 * s, 1.4 * s, Color(0.35, 0.0, 0.04, 0.85), Color(0.7, 0.06, 0.12), false)
	n.update = func(node: FxNode, _dt: float) -> void:
		_set_alpha(fl, 1.0 - clampf(node.t / 0.2, 0.0, 1.0))
		var g := clampf((node.t - 0.25) / 0.25, 0.0, 1.0)
		pool.scale = Vector3(1.4 * s * g, 1, 1.4 * s * g)
		_set_alpha(pool, 1.0 - clampf((node.t - 0.9) / 0.5, 0.0, 1.0))
	return n

## Bear-trap jaws snapping shut + sparks.
func _trap_snap(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var n := _node(root, "trap_snap", p)
	n.free_after = 0.8
	var c := Color(0.85, 0.92, 0.3)
	var jaws: Array = []
	for i in 2:
		var j := MeshInstance3D.new()
		j.mesh = _mesh("quad")
		j.material_override = SH.new_add_mat(Color(0.9, 0.9, 0.75), c, 4, 2.6)
		j.scale = Vector3(1.1, 0.9, 1)
		n.add_child(j)
		jaws.append(j)
	_particles(n, {"amount": 14, "life": 0.35, "vmin": 3.0, "vmax": 6.0, "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, -10, 0), "damp": 2.0,
		"smin": 0.06, "smax": 0.13, "color": Color(1.0, 0.95, 0.55)}).position.y = 0.35
	var ring := _decal(n, 6, 1.8, 1.8, c, Color(1, 1, 0.7), true, 2.0)
	var fl := _sprite(n, c, Color(1, 1, 0.8), 1.2, 2.2, 0, 0.35)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.1, 0.0, 1.0)
		for i in 2:
			var j: MeshInstance3D = jaws[i]
			var sgn := 1.0 if i == 0 else -1.0
			# two crescents closing like jaws
			j.position = Vector3(0, 0.35, sgn * lerpf(0.4, 0.06, k))
			j.rotation = Vector3(sgn * lerpf(1.3, 0.0, k), 0, PI if i == 1 else 0.0)
			_set_alpha(j, 1.0 - clampf((node.t - 0.25) / 0.3, 0.0, 1.0))
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", clampf(node.t / 0.3, 0.0, 1.0))
		_set_alpha(ring, 1.0 - clampf(node.t / 0.4, 0.0, 1.0))
		_set_alpha(fl, clampf(1.0 - absf(node.t - 0.1) / 0.12, 0.0, 1.0))
	return n

## Fiery blast (blast charges, mortar shells); bigger than hit.
func _explosion(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := clampf(_f(o, "radius", 2.5), 0.4, 8.0)
	var c := _c(o, "color", Color(1.0, 0.5, 0.12))
	var n := _node(root, "explosion", p)
	n.free_after = 1.8
	var fire := _particles(n, {"amount": 26, "life": 0.6, "radius": r * 0.25, "vmin": r * 1.2, "vmax": r * 2.6, "dir": Vector3.UP, "spread": 80.0, "damp": r * 2.0,
		"gravity": Vector3(0, 2.0, 0), "smin": r * 0.4, "smax": r * 0.7, "color": c.lerp(Color(1, 0.95, 0.6), 0.4), "mid": 0.35})
	fire.position.y = 0.5
	_particles(n, {"amount": 10, "life": 1.3, "mat": "mix", "radius": r * 0.3, "vmin": r * 0.5, "vmax": r * 1.2, "dir": Vector3.UP, "spread": 60.0, "damp": 1.5,
		"gravity": Vector3(0, 1.0, 0), "smin": r * 0.35, "smax": r * 0.7, "grow": true, "color": Color(0.14, 0.11, 0.1, 0.6)}).position.y = 0.8
	_particles(n, {"amount": 8, "life": 1.0, "mesh": "box", "mat": "debris", "radius": r * 0.2, "vmin": 4.0, "vmax": 7.0, "dir": Vector3.UP, "spread": 55.0,
		"gravity": Vector3(0, -16, 0), "smin": 0.1, "smax": 0.2, "shrink": false, "fade": false, "color": Color(0.3, 0.24, 0.2)}).position.y = 0.4
	var ring := _decal(n, 6, r * 2.2, r * 2.2, c, Color(1, 0.9, 0.6), true, 2.4)
	var scorch := _decal(n, 7, r * 1.6, r * 1.6, Color(0.2, 0.1, 0.05), c, false)
	(scorch.material_override as ShaderMaterial).set_shader_parameter("fill", 1.0)
	var fl := _sprite(n, c, Color(1, 0.95, 0.75), r * 2.2, 2.8, 0, 0.9)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.35, 0.0, 1.0)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", sqrt(k))
		_set_alpha(ring, 1.0 - k)
		fl.scale = Vector3.ONE * r * 2.2 * lerpf(0.6, 1.3, clampf(node.t / 0.15, 0.0, 1.0))
		_set_alpha(fl, 1.0 - clampf(node.t / 0.3, 0.0, 1.0))
		(scorch.material_override as ShaderMaterial).set_shader_parameter("fill", 1.0 - clampf(node.t / 1.6, 0.0, 1.0))
		_set_alpha(scorch, 1.0 - clampf((node.t - 1.1) / 0.7, 0.0, 1.0))
	return n

func _explosion_lite(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var r := clampf(_f(o, "radius", 2.5), 0.4, 8.0)
	var c := _c(o, "color", Color(1.0, 0.5, 0.12))
	var n := _node(root, "explosion", p)
	n.free_after = 0.5
	var ring := _decal(n, 6, r * 2.2, r * 2.2, c, Color(1, 0.9, 0.6), true, 2.4)
	var fl := _sprite(n, c, Color(1, 0.95, 0.75), r * 2.0, 2.6, 0, 0.9)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 0.35, 0.0, 1.0)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", sqrt(k))
		_set_alpha(ring, 1.0 - k)
		_set_alpha(fl, 1.0 - clampf(node.t / 0.25, 0.0, 1.0))
	return n

## Mint wisp flying from a corpse to a point.
func _soul_wisp(o: Dictionary, root: Node) -> FxNode:
	var a := _v(o, "from"); var b := _v(o, "to", a + Vector3(0, 0, -3))
	var n := _node(root, "soul_wisp", Vector3.ZERO)
	n.global_position = Vector3.ZERO
	n.free_after = 1.0
	var c := Color(0.55, 1.0, 0.8)
	var head := _sprite(n, c, Color(0.95, 1, 0.95), 0.7, 2.6, 0, 0.0)
	var tr := _particles(n, {"amount": 14, "life": 0.4, "one_shot": false, "radius": 0.08, "vmin": 0.0, "vmax": 0.3, "gravity": Vector3(0, 0.6, 0),
		"smin": 0.15, "smax": 0.28, "color": c})
	n.parts.append(tr)
	var dur := clampf(a.distance_to(b) / 9.0, 0.25, 0.6)
	var y0 := maxf(a.y, 0.6); var y1 := maxf(b.y, 1.0)
	var pos_at := func(k: float) -> Vector3:
		var e := k * k * (3.0 - 2.0 * k)
		var q := Vector3(a.x, y0, a.z).lerp(Vector3(b.x, y1, b.z), e)
		q.y += sin(k * PI) * 1.1
		q.x += sin(k * TAU * 1.5) * 0.15
		return q
	head.position = pos_at.call(0.0)
	tr.position = head.position
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / dur, 0.0, 1.0)
		head.position = pos_at.call(k)
		tr.position = head.position
		if k >= 1.0:
			tr.emitting = false
			head.scale = Vector3.ONE * lerpf(0.7, 1.6, clampf((node.t - dur) / 0.15, 0.0, 1.0))
			_set_alpha(head, 1.0 - clampf((node.t - dur) / 0.2, 0.0, 1.0))
	return n

## Violet swirl + leaves for Twinhide changing form.
func _form_shift(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var n := _node(root, "form_shift", p)
	n.free_after = 1.3
	var v := Color(0.78, 0.42, 1.0)
	var col := _column(n, v, Color(0.95, 0.85, 1.0), 0.9, 3.4, 2.4)
	_particles(n, {"amount": 26, "life": 0.9, "shape": "ring", "radius": 1.0, "inner": 0.6, "vmin": 0.8, "vmax": 2.0, "dir": Vector3.UP, "spread": 15.0,
		"tangent": 9.0, "radial": -1.5, "smin": 0.1, "smax": 0.2, "color": Color(0.85, 0.6, 1.0), "explode": 0.7})
	_particles(n, {"amount": 12, "life": 1.1, "mesh": "shard", "mat": "glow", "shape": "ring", "radius": 0.5, "inner": 0.1, "vmin": 2.0, "vmax": 4.0, "dir": Vector3.UP,
		"spread": 60.0, "tangent": 5.0, "gravity": Vector3(0, -3, 0), "damp": 1.5, "smin": 0.1, "smax": 0.18, "color": Color(0.5, 0.75, 0.3)}).position.y = 0.6
	var ring := _decal(n, 6, 4.0, 4.0, v, Color(1, 0.85, 1), true, 2.2)
	var rune := _decal(n, 5, 2.8, 2.8, v, Color(0.95, 0.8, 1.0), true, 1.6)
	var fl := _sprite(n, v, Color(1, 0.9, 1), 2.6, 2.4, 0, 1.0)
	n.update = func(node: FxNode, _dt: float) -> void:
		var k := clampf(node.t / 1.0, 0.0, 1.0)
		col.scale.x = lerpf(2.0, 0.3, k); col.scale.z = col.scale.x
		_set_alpha(col, 1.0 - k)
		rune.rotation.y = node.t * 3.0
		_set_alpha(rune, 1.0 - k)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fill", clampf(node.t / 0.4, 0.0, 1.0))
		_set_alpha(ring, 1.0 - clampf(node.t / 0.5, 0.0, 1.0))
		_set_alpha(fl, clampf(1.0 - absf(node.t - 0.15) / 0.2, 0.0, 1.0))
	return n

## Small mint grave glyph where an enemy died (Gravekeeper's corpses). One decal, no particles.
func _grave_marker(o: Dictionary, root: Node) -> FxNode:
	var p := _v(o, "pos"); p.y = 0.0
	var n := _node(root, "grave_marker", p)
	var dur := _f(o, "duration", 8.0)
	n.duration = dur if dur > 0.0 else -1.0
	n.fade_time = 0.3
	var sz := clampf(_f(o, "size", 0.95), 0.3, 3.0)
	var c := _c(o, "color", Color(0.4, 1.0, 0.72))
	var dc := _decal(n, 12, sz, sz, c, c.lerp(Color.WHITE, 0.6), true, 2.0)
	dc.position.y = 0.05 + randf() * 0.01
	var m: ShaderMaterial = dc.material_override
	n.mats.append(m)
	n.data = {"alpha": 1.0}
	n.update = func(node: FxNode, _dt: float) -> void:
		if node.stopping:
			return
		var pop := 1.0 + 0.5 * (1.0 - clampf(node.t / 0.2, 0.0, 1.0))
		dc.scale = Vector3(sz * pop, 1, sz * pop)
		var a := 0.85 + 0.15 * sin(node.t * 3.0)
		if node.duration > 0.0:
			a *= clampf((node.duration - node.t) / 1.5, 0.0, 1.0)
		node.data["alpha"] = a
		m.set_shader_parameter("alpha", a)
	return n
