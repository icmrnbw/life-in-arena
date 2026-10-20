extends Node3D
## Crumbling-rim visuals: a glowing crack ring while the edge is about to fall, then a dark chasm over the
## fallen ring with stone chunks dropping into the void. Logic lives in scripts/arena.gd; this node only draws.
## API: crack(inner, outer, dur), collapse(inner, outer), restore().

const OUTER := 24.7   # the floor's edge (cliff top)

var crack_mi: MeshInstance3D
var void_mi: MeshInstance3D
var debris: CPUParticles3D
var _crack_mat: StandardMaterial3D
var _t := 0.0
var _crack_t := 0.0


func setup(_run_node: Node) -> void:
	name = "ArenaFx"
	crack_mi = MeshInstance3D.new()
	crack_mi.name = "RimCrack"
	_crack_mat = StandardMaterial3D.new()
	_crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crack_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crack_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_crack_mat.vertex_color_use_as_albedo = true
	_crack_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	crack_mi.material_override = _crack_mat
	crack_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crack_mi.visible = false
	add_child(crack_mi)
	void_mi = MeshInstance3D.new()
	void_mi.name = "RimVoid"
	var vm := StandardMaterial3D.new()
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vm.vertex_color_use_as_albedo = true
	vm.cull_mode = BaseMaterial3D.CULL_DISABLED
	void_mi.material_override = vm
	void_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	void_mi.visible = false
	add_child(void_mi)
	debris = CPUParticles3D.new()
	debris.name = "RimDebris"
	debris.emitting = false
	debris.one_shot = true
	debris.explosiveness = 0.85
	debris.amount = 90
	debris.lifetime = 1.8
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.4, 0.5)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("5a5462")
	bm.material = dm
	debris.mesh = bm
	debris.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	debris.emission_ring_axis = Vector3.UP
	debris.emission_ring_height = 0.2
	debris.direction = Vector3.UP
	debris.spread = 40.0
	debris.initial_velocity_min = 1.0
	debris.initial_velocity_max = 3.5
	debris.gravity = Vector3(0, -16, 0)
	debris.angular_velocity_min = -220.0
	debris.angular_velocity_max = 220.0
	debris.scale_amount_min = 0.6
	debris.scale_amount_max = 1.5
	debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(debris)


## The ring between `inner` and `outer` is about to fall in `dur` seconds.
func crack(inner: float, outer: float, dur: float) -> void:
	crack_mi.mesh = _ring(inner, outer, Color(1.0, 0.35, 0.08, 0.9), Color(1.0, 0.2, 0.05, 0.25), 0.05)
	crack_mi.visible = true
	_crack_t = dur
	debris.emission_ring_radius = outer
	debris.emission_ring_inner_radius = inner
	debris.amount = 40
	debris.emitting = false
	debris.restart()   # pebbles shaking loose


## The ring fell: a dark chasm from `inner` out to the cliff edge.
func collapse(inner: float, _outer: float) -> void:
	crack_mi.visible = false
	_crack_t = 0.0
	void_mi.mesh = _ring(inner, OUTER + 0.4, Color(0.55, 0.12, 0.04), Color(0.01, 0.005, 0.015), 0.04, 0.5)
	void_mi.visible = true
	debris.emission_ring_radius = _outer
	debris.emission_ring_inner_radius = inner
	debris.amount = 120
	debris.restart()


func restore() -> void:
	crack_mi.visible = false
	void_mi.visible = false
	_crack_t = 0.0
	debris.emitting = false


func _process(dt: float) -> void:
	if not crack_mi.visible:
		return
	_t += dt
	_crack_t = maxf(0.0, _crack_t - dt)
	# pulses faster as the fall nears
	var f := 3.0 + 9.0 * (1.0 - clampf(_crack_t / 3.0, 0.0, 1.0))
	_crack_mat.albedo_color = Color(1, 1, 1, 0.45 + 0.55 * absf(sin(_t * f)))


## Flat annulus at height `y`, inner edge `ci`, outer edge `co`. `edge` > 0 adds a thin bright band at the inner edge.
func _ring(inner: float, outer: float, ci: Color, co: Color, y: float, edge := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 96
	var radii := [inner, inner + edge, outer] if edge > 0.0 else [inner, outer]
	var cols := [ci, co, co] if edge > 0.0 else [ci, co]
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for k in radii.size() - 1:
			var r0: float = radii[k]
			var r1: float = radii[k + 1]
			var c0: Color = cols[k]
			var c1: Color = cols[k + 1]
			var p00 := Vector3(cos(a0) * r0, y, sin(a0) * r0)
			var p01 := Vector3(cos(a1) * r0, y, sin(a1) * r0)
			var p10 := Vector3(cos(a0) * r1, y, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, y, sin(a1) * r1)
			st.set_color(c0); st.add_vertex(p00)
			st.set_color(c1); st.add_vertex(p10)
			st.set_color(c1); st.add_vertex(p11)
			st.set_color(c0); st.add_vertex(p00)
			st.set_color(c1); st.add_vertex(p11)
			st.set_color(c0); st.add_vertex(p01)
	return st.commit()
