extends Node3D
## Weather visuals: falling rain / embers / wind-blown dust / ground mist around the camera focus, plus the
## WorldEnvironment and sun eased toward each weather's mood, and lightning bolts with a sky flash.
## Logic lives in scripts/weather.gd; this node only draws. API: set_weather(id, wind), follow(pos), lightning(pos).

const SH := preload("res://art/shaders.gd")

## Environment mood per weather, as changes from the arena's own look (missing keys keep the base value).
const MOODS := {
	"clear": {},
	"rain": {"ambient": Color("6878a8"), "ambient_e": 0.55, "sun_e": 0.7, "sun": Color(0.8, 0.85, 1.0), "fog": Color("2a3048"), "fog_d": 0.008, "sat": 0.92},
	"storm": {"ambient": Color("5a6694"), "ambient_e": 0.48, "sun_e": 0.45, "sun": Color(0.7, 0.78, 1.0), "fog": Color("1e2440"), "fog_d": 0.011, "sat": 0.85},
	"fog": {"ambient": Color("8890a8"), "ambient_e": 0.7, "sun_e": 0.8, "sun": Color(0.92, 0.92, 0.95), "fog": Color("8a909e"), "fog_d": 0.017, "sat": 0.82},
	"gale": {"ambient": Color("8a8070"), "ambient_e": 0.62, "fog": Color("5a4c36"), "fog_d": 0.006, "sat": 1.0},
	"emberfall": {"ambient": Color("b07050"), "ambient_e": 0.62, "sun": Color(1.0, 0.62, 0.38), "sun_e": 1.1, "fog": Color("4a1e10"), "fog_d": 0.006, "sat": 1.18},
	"bloodmoon": {"ambient": Color("8a5a66"), "ambient_e": 0.58, "sun": Color(1.0, 0.5, 0.45), "sun_e": 1.0, "fog": Color("3a0c16"), "fog_d": 0.006,
		"bg": Color("1e0609"), "sat": 1.05},
}

var env: Environment
var sun: DirectionalLight3D
var base := {}
var cur := "clear"
var wind := Vector3.ZERO
var flash := 0.0
var rain: CPUParticles3D
var splash: CPUParticles3D
var mist: CPUParticles3D
var dust: CPUParticles3D
var embers: CPUParticles3D
var _bolts: Array = []            # [{node, t}]


func setup(run_node: Node) -> void:
	name = "WeatherFx"
	var we := run_node.get_node_or_null("Env/ArtEnvironment") as WorldEnvironment
	if we:
		env = we.environment
	sun = run_node.get_node_or_null("Env/Sun") as DirectionalLight3D
	if env:
		base = {"ambient": env.ambient_light_color, "ambient_e": env.ambient_light_energy, "fog": env.fog_light_color,
			"fog_d": env.fog_density, "sat": env.adjustment_saturation, "bg": env.background_color}
	if sun:
		base["sun"] = sun.light_color
		base["sun_e"] = sun.light_energy
	rain = _streaks(520, Color(0.72, 0.82, 1.0, 0.32), Vector2(0.035, 0.95))
	splash = _parts(140, "add", Color(0.75, 0.85, 1.0, 0.55), 0.06, 0.12, 0.3)
	splash.emission_box_extents = Vector3(17, 0.05, 12)
	splash.direction = Vector3.UP
	splash.spread = 30.0
	splash.initial_velocity_min = 0.6; splash.initial_velocity_max = 1.4
	splash.gravity = Vector3(0, -6, 0)
	mist = _parts(30, "mix", Color(0.86, 0.88, 0.94, 0.1), 5.0, 9.0, 9.0)
	mist.emission_box_extents = Vector3(20, 0.4, 15)
	mist.direction = Vector3(1, 0, 0)
	mist.spread = 180.0
	mist.initial_velocity_min = 0.2; mist.initial_velocity_max = 0.6
	mist.preprocess = 9.0
	dust = _parts(160, "mix", Color(0.86, 0.74, 0.52, 0.32), 0.1, 0.32, 1.6)
	dust.emission_box_extents = Vector3(20, 1.2, 15)
	dust.spread = 12.0
	dust.initial_velocity_min = 9.0; dust.initial_velocity_max = 14.0
	embers = _parts(120, "add", Color(1.0, 0.55, 0.15, 0.9), 0.07, 0.16, 3.2)
	embers.emission_box_extents = Vector3(20, 0.5, 15)
	embers.direction = Vector3(0.15, -1, 0.1)
	embers.spread = 20.0
	embers.initial_velocity_min = 3.0; embers.initial_velocity_max = 5.5
	embers.gravity = Vector3(0, -0.6, 0)


func _streaks(amount: int, c: Color, sz: Vector2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = sz
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	p.material_override = m
	p.amount = amount
	p.lifetime = 0.62
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18, 0.5, 14)
	p.direction = Vector3.DOWN
	p.spread = 3.0
	p.initial_velocity_min = 24.0; p.initial_velocity_max = 28.0
	p.gravity = Vector3.ZERO
	p.color = c
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	add_child(p)
	return p


func _parts(amount: int, mat: String, c: Color, smin: float, smax: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	p.mesh = q
	p.material_override = SH.mat("particle_mix" if mat == "mix" else "particle_add")
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(c, 0.0), c, c, Color(c, 0.0)])
	p.color_ramp = g
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	add_child(p)
	return p


func set_weather(id: String, w: Vector3) -> void:
	cur = id if MOODS.has(id) else "clear"
	wind = w
	var wet := cur in ["rain", "storm"]
	rain.emitting = wet
	splash.emitting = wet
	rain.amount = 620 if cur == "storm" else 480
	mist.emitting = cur == "fog"
	dust.emitting = cur == "gale"
	if cur == "gale":
		dust.direction = (w + Vector3(0, 0.05, 0)).normalized()
		dust.gravity = w * 2.0
	embers.emitting = cur == "emberfall"


func follow(p: Vector3) -> void:
	rain.global_position = p + Vector3(0, 14.5, 1.5)
	splash.global_position = Vector3(p.x, 0.05, p.z + 1.5)
	mist.global_position = Vector3(p.x, 0.8, p.z + 1.0)
	dust.global_position = Vector3(p.x, 1.2, p.z + 1.0) - wind * 12.0
	embers.global_position = p + Vector3(0, 12.0, 1.5)


## A jagged bolt from the sky onto `p`, with a short bright flash of the whole scene.
func lightning(p: Vector3) -> void:
	flash = 1.0
	var pts := PackedVector3Array()
	var x := 0.0
	var y := 26.0
	while y > 0.0:
		pts.append(Vector3(x, y, 0))
		y -= randf_range(2.0, 4.0)
		x = clampf(x + randf_range(-1.1, 1.1), -2.0, 2.0)
	pts.append(Vector3(0, 0, 0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var w := 0.32 * (0.6 + 0.4 * float(pts.size() - i) / pts.size())
		st.add_vertex(a + Vector3(-w, 0, 0)); st.add_vertex(a + Vector3(w, 0, 0)); st.add_vertex(b + Vector3(-w, 0, 0))
		st.add_vertex(a + Vector3(w, 0, 0)); st.add_vertex(b + Vector3(w, 0, 0)); st.add_vertex(b + Vector3(-w, 0, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.4, 1.7, 2.6, 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(p.x, 0, p.z)
	_bolts.append({"node": mi, "mat": m, "t": 0.0})


func _process(dt: float) -> void:
	if not _bolts.is_empty():
		var keep := []
		for b in _bolts:
			b["t"] += dt
			var t: float = b["t"]
			if t > 0.32:
				(b["node"] as Node).queue_free()
				continue
			# flicker twice, then fade
			var a := (1.0 if fmod(t, 0.1) < 0.06 else 0.35) * (1.0 - t / 0.32)
			(b["mat"] as StandardMaterial3D).albedo_color.a = a
			keep.append(b)
		_bolts = keep
	flash = maxf(0.0, flash - dt * 4.0)
	if env == null:
		return
	var mood: Dictionary = MOODS.get(cur, {})
	var k := 1.0 - exp(-1.2 * dt)
	env.ambient_light_color = env.ambient_light_color.lerp(mood.get("ambient", base["ambient"]), k)
	var amb_e: float = mood.get("ambient_e", base["ambient_e"])
	env.ambient_light_energy = lerpf(env.ambient_light_energy, amb_e, k) if flash <= 0.0 else amb_e + flash * 1.4
	env.fog_light_color = env.fog_light_color.lerp(mood.get("fog", base["fog"]), k)
	env.fog_density = lerpf(env.fog_density, mood.get("fog_d", base["fog_d"]), k)
	env.adjustment_saturation = lerpf(env.adjustment_saturation, mood.get("sat", base["sat"]), k)
	env.background_color = env.background_color.lerp(mood.get("bg", base["bg"]), k)
	if sun:
		sun.light_color = sun.light_color.lerp(mood.get("sun", base["sun"]), k)
		var se: float = mood.get("sun_e", base["sun_e"])
		sun.light_energy = lerpf(sun.light_energy, se, k) if flash <= 0.0 else se + flash * 1.6
