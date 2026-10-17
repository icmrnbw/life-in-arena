extends Node3D
## UnitVisual: procedural animated unit. API (CONTRACT.md):
##   var radius, height; set_state(s), flash(c), set_tint(c)
## States: idle, run (loops); attack, cast, hit (one-shot, return to loop); death (terminal); spawn (-> idle).

const SH := preload("res://art/shaders.gd")

var radius := 0.5
var height := 1.8
var kind := ""

var P: Dictionary = {}
var skel: Skeleton3D
var mi: MeshInstance3D
var mat: ShaderMaterial
var mat2: ShaderMaterial
var bi := {}
var bnames: PackedStringArray
var rest: Array = []
var cur_q: Array = []
var cur_p: Array = []
var cur_s: Array = []

var state := "idle"
var loop_state := "idle"
var one_shot := ""
var os_t := 0.0
var os_dur := 0.0
var t := 0.0
var dead := false
var flash_a := 0.0
var flash_c := Color.WHITE
var tint := Color.WHITE
var dissolve := 0.0
var glow_boost := 0.0
var shadow_alpha := 1.0
var style := "biped"
var hs := 1.0
var _phase := 0.0
var _acc := 0.0
var _flame: Node3D
var _last_dissolve := -1.0
var _last_boost := -1.0

var R := {}
var PO := {}
var S := {}

const ATTACKS := {
	"overhead": {
		"arm_r": [[0.0, Vector3(0.1, 0, 0.12)], [0.38, Vector3(2.7, 0, 0.2)], [0.52, Vector3(0.95, 0, 0.1)], [0.72, Vector3(0.95, 0, 0.1)], [1.0, Vector3(0.1, 0, 0.12)]],
		"weapon_r": [[0.0, Vector3(0.35, 0, 0)], [0.38, Vector3(-1.4, 0, 0)], [0.52, Vector3(-3.0, 0, 0)], [0.72, Vector3(-3.0, 0, 0)], [1.0, Vector3(0.35, 0, 0)]],
		"arm_l": [[0.0, Vector3(0, 0, -0.12)], [0.38, Vector3(1.6, 0, -0.1)], [0.52, Vector3(0.9, 0, -0.1)], [0.72, Vector3(0.9, 0, 0)], [1.0, Vector3(0, 0, -0.12)]],
		"chest": [[0.0, Vector3.ZERO], [0.38, Vector3(0.25, -0.25, 0)], [0.52, Vector3(-0.42, 0.15, 0)], [0.72, Vector3(-0.35, 0.1, 0)], [1.0, Vector3.ZERO]],
		"@hips": [[0.0, Vector3.ZERO], [0.38, Vector3(0, 0.03, 0.02)], [0.52, Vector3(0, -0.1, -0.06)], [0.72, Vector3(0, -0.1, -0.06)], [1.0, Vector3.ZERO]],
		"head": [[0.38, Vector3(-0.15, 0, 0)], [0.52, Vector3(0.2, 0, 0)]],
	},
	"slash2": {
		"arm_r": [[0.0, Vector3(0.3, 0, 0.12)], [0.2, Vector3(1.4, 0, -0.7)], [0.38, Vector3(1.3, 0, 1.15)], [0.6, Vector3(1.1, 0, 0.9)], [1.0, Vector3(0.3, 0, 0.12)]],
		"arm_l": [[0.0, Vector3(0.3, 0, -0.12)], [0.35, Vector3(1.4, 0, 0.7)], [0.55, Vector3(1.3, 0, -1.15)], [0.75, Vector3(1.1, 0, -0.9)], [1.0, Vector3(0.3, 0, -0.12)]],
		"chest": [[0.0, Vector3.ZERO], [0.2, Vector3(-0.1, 0.55, 0)], [0.4, Vector3(-0.25, -0.45, 0)], [0.6, Vector3(-0.2, 0.4, 0)], [1.0, Vector3.ZERO]],
		"@root": [[0.0, Vector3.ZERO], [0.35, Vector3(0, 0, -0.25)], [1.0, Vector3.ZERO]],
		"weapon_r": [[0.2, Vector3(0, 0.6, 0)], [0.4, Vector3(0, -0.5, 0)]],
		"weapon_l": [[0.35, Vector3(0, -0.6, 0)], [0.55, Vector3(0, 0.5, 0)]],
	},
	"bite": {
		"head": [[0.0, Vector3.ZERO], [0.3, Vector3(0.45, 0, 0)], [0.5, Vector3(-0.4, 0, 0)], [1.0, Vector3.ZERO]],
		"@head": [[0.0, Vector3.ZERO], [0.3, Vector3(0, 0.04, 0.08)], [0.5, Vector3(0, -0.04, -0.2)], [1.0, Vector3.ZERO]],
		"@body": [[0.0, Vector3.ZERO], [0.3, Vector3(0, 0.02, 0.08)], [0.5, Vector3(0, -0.02, -0.18)], [1.0, Vector3.ZERO]],
		"body": [[0.0, Vector3.ZERO], [0.3, Vector3(0.2, 0, 0)], [0.5, Vector3(-0.18, 0, 0)], [1.0, Vector3.ZERO]],
		"seg2": [[0.3, Vector3(0.35, 0, 0)], [0.5, Vector3(-0.45, 0, 0)]],
		"seg3": [[0.3, Vector3(0.3, 0, 0)], [0.5, Vector3(-0.5, 0, 0)]],
		"arm_l": [[0.3, Vector3(1.2, 0, -0.3)], [0.5, Vector3(0.4, 0, 0)]],
		"arm_r": [[0.3, Vector3(1.2, 0, 0.3)], [0.5, Vector3(0.4, 0, 0)]],
		"leg_fl": [[0.3, Vector3(0.5, 0, 0)], [0.5, Vector3(0.8, 0, 0)]],
		"leg_fr": [[0.3, Vector3(0.5, 0, 0)], [0.5, Vector3(0.8, 0, 0)]],
	},
	"thrust": {
		"arm_r": [[0.0, Vector3(0, 0, 0.1)], [0.35, Vector3(2.5, 0, 0.35)], [0.55, Vector3(1.5, 0, 0.1)], [1.0, Vector3(0, 0, 0.1)]],
		"arm_l": [[0.35, Vector3(0.8, 0, -0.4)], [0.55, Vector3(0.4, 0, -0.2)]],
		"chest": [[0.35, Vector3(0.2, 0.2, 0)], [0.55, Vector3(-0.25, -0.1, 0)]],
		"@orb": [[0.0, Vector3.ZERO], [0.35, Vector3(0, 0.25, 0.15)], [0.55, Vector3(0, 0.0, -0.45)], [1.0, Vector3.ZERO]],
	},
	"slam2": {
		"arm_l": [[0.0, Vector3(0.2, 0, -0.1)], [0.4, Vector3(2.7, 0, -0.35)], [0.55, Vector3(0.55, 0, -0.1)], [0.75, Vector3(0.55, 0, -0.1)], [1.0, Vector3(0.2, 0, -0.1)]],
		"arm_r": [[0.0, Vector3(0.2, 0, 0.1)], [0.4, Vector3(2.7, 0, 0.35)], [0.55, Vector3(0.55, 0, 0.1)], [0.75, Vector3(0.55, 0, 0.1)], [1.0, Vector3(0.2, 0, 0.1)]],
		"chest": [[0.0, Vector3.ZERO], [0.4, Vector3(0.35, 0, 0)], [0.55, Vector3(-0.5, 0, 0)], [0.75, Vector3(-0.45, 0, 0)], [1.0, Vector3.ZERO]],
		"head": [[0.4, Vector3(-0.3, 0, 0)], [0.55, Vector3(0.3, 0, 0)]],
		"@hips": [[0.0, Vector3.ZERO], [0.4, Vector3(0, 0.08, 0)], [0.55, Vector3(0, -0.3, -0.15)], [0.75, Vector3(0, -0.3, -0.15)], [1.0, Vector3.ZERO]],
	},
	"spit": {
		"chest": [[0.0, Vector3.ZERO], [0.3, Vector3(0.3, 0, 0)], [0.5, Vector3(-0.35, 0, 0)], [1.0, Vector3.ZERO]],
		"head": [[0.0, Vector3.ZERO], [0.3, Vector3(0.45, 0, 0)], [0.5, Vector3(-0.3, 0, 0)], [1.0, Vector3.ZERO]],
		"arm_l": [[0.3, Vector3(1.1, 0, -0.35)], [0.5, Vector3(0.3, 0, -0.1)]],
		"arm_r": [[0.3, Vector3(1.1, 0, 0.35)], [0.5, Vector3(0.3, 0, 0.1)]],
		"abdomen": [[0.3, Vector3(-0.2, 0, 0)], [0.5, Vector3(0.15, 0, 0)]],
	},
	"swipe": {
		"arm_r": [[0.0, Vector3(0.1, 0, 0.1)], [0.35, Vector3(1.7, 0, 1.0)], [0.55, Vector3(1.3, 0, -0.6)], [0.75, Vector3(1.0, 0, -0.4)], [1.0, Vector3(0.1, 0, 0.1)]],
		"arm_l": [[0.35, Vector3(0.6, 0, -0.5)], [0.55, Vector3(0.9, 0, -0.2)]],
		"weapon_r": [[0.35, Vector3(-0.4, 0, 0)], [0.55, Vector3(-1.3, 0, 0)], [0.75, Vector3(-1.0, 0, 0)]],
		"chest": [[0.0, Vector3.ZERO], [0.35, Vector3(0.1, -0.45, 0)], [0.55, Vector3(-0.25, 0.4, 0)], [1.0, Vector3.ZERO]],
		"body": [[0.35, Vector3(0.1, -0.35, 0)], [0.55, Vector3(-0.2, 0.35, 0)]],
	},
	"pulse": {
		"%head": [[0.0, Vector3.ONE], [0.3, Vector3(1.3, 0.8, 1.3)], [0.55, Vector3(0.9, 1.2, 0.9)], [1.0, Vector3.ONE]],
		"%body": [[0.0, Vector3.ONE], [0.3, Vector3(1.06, 0.95, 1.06)], [0.55, Vector3(0.97, 1.04, 0.97)], [1.0, Vector3.ONE]],
	},
	"cast": {
		"arm_l": [[0.0, Vector3(0.2, 0, -0.2)], [0.4, Vector3(2.5, 0, -0.65)], [0.75, Vector3(2.4, 0, -0.6)], [1.0, Vector3(0.2, 0, -0.2)]],
		"arm_r": [[0.0, Vector3(0.2, 0, 0.2)], [0.4, Vector3(2.5, 0, 0.65)], [0.75, Vector3(2.4, 0, 0.6)], [1.0, Vector3(0.2, 0, 0.2)]],
		"chest": [[0.4, Vector3(0.28, 0, 0)], [0.75, Vector3(0.22, 0, 0)]],
		"head": [[0.4, Vector3(0.3, 0, 0)], [0.75, Vector3(0.25, 0, 0)]],
		"body": [[0.4, Vector3(0.35, 0, 0)], [0.75, Vector3(0.3, 0, 0)]],
		"seg3": [[0.4, Vector3(0.3, 0, 0)]],
		"@root": [[0.0, Vector3.ZERO], [0.4, Vector3(0, 0.08, 0)], [0.75, Vector3(0, 0.06, 0)], [1.0, Vector3.ZERO]],
		"weapon_r": [[0.4, Vector3(-0.6, 0, 0)]],
	},
}

func setup(rig: Dictionary, k: String) -> void:
	kind = k
	P = rig["params"]
	style = P["style"]
	radius = P["radius"]
	height = P["height"]
	hs = height / 1.8
	_phase = randf() * 10.0
	skel = Skeleton3D.new()
	skel.name = "Skeleton"
	add_child(skel)
	bnames = rig["names"]
	var parents: PackedInt32Array = rig["parents"]
	var rl: Array = rig["rest"]
	for i in bnames.size():
		skel.add_bone(bnames[i])
	for i in bnames.size():
		if parents[i] >= 0:
			skel.set_bone_parent(i, parents[i])
		skel.set_bone_rest(i, Transform3D(Basis(), rl[i]))
		bi[bnames[i]] = i
		rest.append(rl[i])
		cur_q.append(Quaternion.IDENTITY)
		cur_p.append(rl[i])
		cur_s.append(Vector3.ONE)
		skel.set_bone_pose_position(i, rl[i])
	mi = MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = rig["mesh"]
	mi.skin = rig["skin"]
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ext := maxf(radius * 3.0, height * 1.2)
	mi.custom_aabb = AABB(Vector3(-ext, -height, -ext), Vector3(ext * 2.0, height * 2.6, ext * 2.0))
	var glow: Color = P["glow"]
	if P.get("ghost", false):
		mat = SH.new_ghost_mat(Color(0.35, 1.0, 0.92), 0.6, 0.0)
		mat.set_shader_parameter("glow_strength", 1.2)
		for si in mi.mesh.get_surface_count():
			mi.set_surface_override_material(si, mat)
	else:
		mat = SH.new_unit_mat(glow, height)
		var rim_c: Color = P["rim"]
		var rim_s: float = P["rim_strength"]
		if HERO_RING.has(kind):
			# heroes: strong rim in the hero colour + a coloured ground ring, so they never sink into the floor
			rim_c = (HERO_RING[kind] as Color).lerp(Color.WHITE, 0.35)
			rim_s = maxf(rim_s, 0.95)
			mat.set_shader_parameter("rim_pow", 2.0)
			_make_ring(HERO_RING[kind])
		elif P.get("enemy", true):
			# enemies: warm hostile rim that separates them from the cool stone
			rim_c = rim_c.lerp(Color(1.0, 0.42, 0.22), 0.6)
			rim_s = maxf(rim_s, 0.6)
		mat.set_shader_parameter("rim_color", rim_c)
		mat.set_shader_parameter("rim_strength", rim_s)
		mi.set_surface_override_material(0, mat)
		if mi.mesh.get_surface_count() > 1:
			mat2 = SH.new_ghost_mat(glow, 0.28, 1.0)
			mat2.set_shader_parameter("glow_strength", 0.6)
			mi.set_surface_override_material(1, mat2)
	if P.has("flame"):
		_flame = _make_flame(P["flame"])
		add_child(_flame)
	_apply_pose(1.0)

const HERO_RING := {"ashwarden": Color(1.0, 0.76, 0.25), "riftdancer": Color(0.25, 0.95, 0.88), "hivemother": Color(0.62, 1.0, 0.25)}
var _ring: MeshInstance3D
var _ring_mat: ShaderMaterial

func _make_ring(c: Color) -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "HeroRing"
	var pm := PlaneMesh.new()
	var sz := maxf(radius * 4.2, 2.0)
	pm.size = Vector2(sz, sz)
	_ring.mesh = pm
	_ring.position = Vector3(0, 0.05, 0)
	_ring_mat = SH.new_decal_mat(false)
	_ring_mat.set_shader_parameter("mode", 9)
	_ring_mat.set_shader_parameter("color", Color(c.r, c.g, c.b, 1.0))
	_ring_mat.set_shader_parameter("color2", c.lerp(Color.WHITE, 0.5))
	_ring_mat.set_shader_parameter("size", Vector2(sz, sz))
	_ring_mat.set_shader_parameter("edge_w", 0.07)
	_ring_mat.set_shader_parameter("intensity", 1.25)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

func _make_flame(pos: Vector3) -> Node3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 14
	p.lifetime = 0.7
	p.mesh = _quad_mesh()
	p.material_override = SH.mat("particle_add")
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.16
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.6, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.45
	var c := Curve.new(); c.add_point(Vector2(0, 1)); c.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 1.0)); g.set_color(1, Color(1.0, 0.2, 0.02, 0.0))
	p.color_ramp = g
	p.local_coords = false
	return p

static var _qm: QuadMesh
static func _quad_mesh() -> QuadMesh:
	if _qm == null:
		_qm = QuadMesh.new(); _qm.size = Vector2.ONE
	return _qm

func _enter_tree() -> void:
	if Engine.has_singleton("Art") or get_node_or_null("/root/Art") != null:
		var art = get_node_or_null("/root/Art")
		if art and art.has_method("_register_unit"):
			art._register_unit(self)

func _exit_tree() -> void:
	var art = get_node_or_null("/root/Art")
	if art and art.has_method("_unregister_unit"):
		art._unregister_unit(self)

# ------------------------------------------------------------------ API

func set_state(s: String) -> void:
	match s:
		"idle", "run", "sit":
			loop_state = s
			if _ring:
				_ring.visible = s != "sit"
			if dead:
				return
			if one_shot == "" or one_shot == "spawn":
				state = s
		"attack", "cast", "hit":
			if dead:
				return
			if s == "hit" and (one_shot == "attack" or one_shot == "cast" or one_shot == "spawn"):
				flash(Color(1, 0.35, 0.3))
				return
			one_shot = s
			os_t = 0.0
			os_dur = P.get("atk_dur", 0.5) if s == "attack" else (P.get("cast_dur", 0.6) if s == "cast" else 0.28)
			state = s
			if s == "hit":
				flash(Color(1, 0.35, 0.3))
		"death":
			if dead:
				return
			dead = true
			one_shot = "death"
			os_t = 0.0
			os_dur = 1.2
			state = "death"
			if _flame:
				(_flame as CPUParticles3D).emitting = false
		"spawn":
			dead = false
			one_shot = "spawn"
			os_t = 0.0
			os_dur = 0.75 if style != "worm" else 0.9
			state = "spawn"
			dissolve = 1.0
			if _flame:
				(_flame as CPUParticles3D).emitting = true
		_:
			pass

func flash(c: Color) -> void:
	flash_c = c
	flash_a = 1.0
	if mat:
		mat.set_shader_parameter("flash", Color(c.r, c.g, c.b, 1.0))

func set_tint(c: Color) -> void:
	tint = c
	if mat:
		mat.set_shader_parameter("tint", c)
	if mat2:
		mat2.set_shader_parameter("tint", c)

# ------------------------------------------------------------------ animation

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	# throttle big crowds: enemies animate at 30 Hz when the screen is busy
	var art = get_node_or_null("/root/Art")
	if art and P.get("enemy", true) and art.get("_unit_count") != null and int(art._unit_count) > 40:
		_acc += dt
		if (Engine.get_process_frames() + get_instance_id()) % 2 == 0:
			return
		dt = _acc
	_acc = 0.0
	t += dt
	if flash_a > 0.0:
		flash_a = maxf(0.0, flash_a - dt * 6.0)
		mat.set_shader_parameter("flash", Color(flash_c.r, flash_c.g, flash_c.b, flash_a))
	if one_shot != "":
		os_t += dt
		if os_t >= os_dur and one_shot != "death":
			if one_shot == "spawn":
				dissolve = 0.0
			one_shot = ""
			state = loop_state
	_compute_pose()
	var k := 1.0 - exp(-dt * (26.0 if one_shot == "attack" or one_shot == "hit" else 14.0))
	_apply_pose(k)
	if absf(dissolve - _last_dissolve) > 0.001:
		_last_dissolve = dissolve
		mat.set_shader_parameter("dissolve", dissolve)
		if mat2:
			mat2.set_shader_parameter("dissolve", dissolve)
		if _ring_mat:
			_ring_mat.set_shader_parameter("alpha", clampf(1.0 - dissolve * 2.5, 0.0, 1.0))
	if absf(glow_boost - _last_boost) > 0.001:
		_last_boost = glow_boost
		mat.set_shader_parameter("glow_boost", glow_boost)

func _r(n: String, v: Vector3) -> void:
	R[n] = v
func _p(n: String, v: Vector3) -> void:
	PO[n] = v
func _s(n: String, v: Vector3) -> void:
	S[n] = v

func _compute_pose() -> void:
	R.clear(); PO.clear(); S.clear()
	var run := loop_state == "run"
	var lt := t + _phase
	if loop_state == "sit":
		_loop_sit(lt)
		glow_boost = 0.0
		shadow_alpha = 1.0
		return
	match style:
		"biped": _loop_biped(run, lt)
		"robe": _loop_robe(run, lt)
		"quad": _loop_quad(run, lt)
		"taur": _loop_taur(run, lt)
		"worm": _loop_worm(run, lt)
		"blob": _loop_blob(run, lt)
		"float": _loop_float(run, lt)
		"totem": _loop_totem(run, lt)
	if kind == "drummer":
		# beats the belly drum, alternating mallets
		var beat := lt * 5.5
		_r("arm_l", Vector3(0.7 + maxf(0.0, sin(beat)) * 0.7, 0, -0.15))
		_r("arm_r", Vector3(0.7 + maxf(0.0, -sin(beat)) * 0.7, 0, 0.15))
		_r("weapon_l", Vector3(-maxf(0.0, sin(beat)) * 0.5, 0, 0))
		_r("weapon_r", Vector3(-maxf(0.0, -sin(beat)) * 0.5, 0, 0))
	glow_boost = 0.0
	if style == "totem":
		glow_boost = 0.25 + 0.15 * sin(lt * 5.0)
	shadow_alpha = 1.0
	if one_shot != "":
		var p := clampf(os_t / maxf(os_dur, 0.01), 0.0, 1.0)
		match one_shot:
			"attack": _overlay(ATTACKS.get(P["attack"], ATTACKS["overhead"]), p, P.get("atk_override", {}))
			"cast":
				_overlay(ATTACKS["cast"], p, {})
				glow_boost = sin(p * PI) * 1.2
			"hit": _pose_hit(p)
			"death": _pose_death(p)
			"spawn": _pose_spawn(p)
		if one_shot == "attack" and P["attack"] == "pulse":
			glow_boost = sin(p * PI) * 1.5

func _keyval(keys: Array, p: float) -> Vector3:
	if keys.size() == 1:
		return keys[0][1]
	if p <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if p <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var f := (p - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			f = f * f * (3.0 - 2.0 * f)
			return (a[1] as Vector3).lerp(b[1], f)
	return keys[keys.size() - 1][1]

func _overlay(anim: Dictionary, p: float, override: Dictionary) -> void:
	var w := smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.85, 1.0, p))
	var src := anim
	if not override.is_empty():
		src = anim.duplicate()
		src.merge(override, true)
	for key in src:
		var keys: Array = src[key]
		var v := _keyval(keys, p)
		var n: String = key
		if n.begins_with("@"):
			n = n.substr(1)
			var base: Vector3 = PO.get(n, Vector3.ZERO)
			PO[n] = base.lerp(base + v * hs, w)
		elif n.begins_with("%"):
			n = n.substr(1)
			var base: Vector3 = S.get(n, Vector3.ONE)
			S[n] = base.lerp(v, w)
		else:
			var base: Vector3 = R.get(n, Vector3.ZERO)
			R[n] = base.lerp(v, w)

func _apply_pose(k: float) -> void:
	for i in bnames.size():
		var n := bnames[i]
		var tq := Quaternion.from_euler(R.get(n, Vector3.ZERO))
		cur_q[i] = (cur_q[i] as Quaternion).slerp(tq, k)
		var tp: Vector3 = rest[i] + PO.get(n, Vector3.ZERO)
		cur_p[i] = (cur_p[i] as Vector3).lerp(tp, k)
		var ts: Vector3 = S.get(n, Vector3.ONE)
		cur_s[i] = (cur_s[i] as Vector3).lerp(ts, k)
		skel.set_bone_pose_rotation(i, cur_q[i])
		skel.set_bone_pose_position(i, cur_p[i])
		skel.set_bone_pose_scale(i, cur_s[i])

# ------------------------------------------------------------------ loops

func _loop_biped(run: bool, lt: float) -> void:
	var w_r: Vector3 = P["w_idle_r"]
	var w_l: Vector3 = P["w_idle_l"]
	if run:
		var f: float = P["run_freq"]
		var s := sin(lt * f)
		var c := cos(lt * f)
		var st: float = P["stride"]
		var sw: float = P["arm_swing"]
		_r("leg_l", Vector3(s * st, 0, 0))
		_r("leg_r", Vector3(-s * st, 0, 0))
		var ra: Vector3 = P.get("run_arms", Vector3.ZERO)
		_r("arm_l", Vector3(-s * sw, 0, -0.14) + ra)
		_r("arm_r", Vector3(s * sw, 0, 0.14) + ra)
		_p("hips", Vector3(0, (absf(c) * 0.07 - 0.03) * hs, 0))
		_r("hips", Vector3(0, s * 0.12, 0))
		_r("chest", Vector3(-P["lean"], -s * 0.16, 0))
		_r("head", Vector3(P["lean"] * 0.5, s * 0.08, 0))
		_r("cape", Vector3(-0.45 + c * 0.1, 0, 0))
		_r("scarf1", Vector3(-0.15 + sin(lt * f * 0.5) * 0.15, sin(lt * f * 0.25) * 0.2, 0))
		_r("scarf2", Vector3(0.1 + c * 0.25, 0, sin(lt * f * 0.5) * 0.2))
		_r("weapon_r", w_r + Vector3(c * 0.08, 0, 0))
		_r("weapon_l", w_l + Vector3(-c * 0.08, 0, 0))
	else:
		var b := sin(lt * 1.8)
		_r("chest", Vector3(b * 0.03, 0, 0))
		_s("chest", Vector3(1.0 + b * 0.012, 1.0 + b * 0.018, 1.0 + b * 0.012))
		_r("arm_l", Vector3(0.05 + b * 0.03, 0, -0.14 - b * 0.03))
		_r("arm_r", Vector3(0.05 + b * 0.03, 0, 0.14 + b * 0.03))
		_r("head", Vector3(-b * 0.03, sin(lt * 0.45) * 0.15, 0))
		_r("cape", Vector3(-0.05 + b * 0.04, 0, 0))
		_r("scarf1", Vector3(0.45 + sin(lt * 2.3) * 0.1, sin(lt * 1.7) * 0.15, 0))
		_r("scarf2", Vector3(0.35 + sin(lt * 2.9) * 0.15, 0, sin(lt * 2.0) * 0.15))
		_r("weapon_r", w_r + Vector3(b * 0.03, 0, 0))
		_r("weapon_l", w_l + Vector3(b * 0.03, 0, 0))
		_p("hips", Vector3(0, b * 0.008 * hs, 0))

func _loop_robe(run: bool, lt: float) -> void:
	var b := sin(lt * 1.6)
	_p("orb", Vector3(0, sin(lt * 2.2) * 0.08, 0))
	_r("orb", Vector3(0, lt * 2.0, 0))
	if run:
		var f: float = P["run_freq"]
		var s := sin(lt * f)
		_r("hips", Vector3(0, 0, s * 0.06))
		_p("hips", Vector3(0, absf(cos(lt * f)) * 0.04 * hs, 0))
		_r("chest", Vector3(-0.25, -s * 0.1, 0))
		_r("head", Vector3(0.15, 0, 0))
		_r("arm_l", Vector3(-0.5, 0, -0.25))
		_r("arm_r", Vector3(-0.5, 0, 0.25))
		_r("weapon_r", Vector3(0.25, 0, 0))
	else:
		_r("hips", Vector3(0, 0, b * 0.02))
		_r("chest", Vector3(0.04 + b * 0.04, sin(lt * 0.6) * 0.1, 0))
		_s("chest", Vector3(1.0 + b * 0.015, 1.0 + b * 0.02, 1.0 + b * 0.015))
		_r("head", Vector3(-b * 0.04, sin(lt * 0.45) * 0.2, 0))
		_r("arm_l", Vector3(0.1 + b * 0.05, 0, -0.15))
		_r("arm_r", Vector3(0.1 + b * 0.05, 0, 0.15))

func _loop_quad(run: bool, lt: float) -> void:
	var insect: bool = P.get("insect", false)
	if run:
		var f: float = P["run_freq"]
		var s := sin(lt * f)
		var c := cos(lt * f)
		var st: float = P["stride"]
		if insect:
			for n in ["leg_fl", "leg_mr", "leg_bl"]:
				_r(n, Vector3(s * st, 0, (0.3 if n.ends_with("l") else -0.3) * maxf(c, 0.0)))
			for n in ["leg_fr", "leg_ml", "leg_br"]:
				_r(n, Vector3(-s * st, 0, (0.3 if n.ends_with("l") else -0.3) * maxf(-c, 0.0)))
			_p("body", Vector3(0, absf(c) * 0.02, 0))
			_r("head", Vector3(0, s * 0.15, 0))
		else:
			_r("leg_fl", Vector3(s * st, 0, 0)); _r("leg_fr", Vector3(s * st * 0.8, 0, 0))
			_r("leg_bl", Vector3(-s * st, 0, 0)); _r("leg_br", Vector3(-s * st * 0.8, 0, 0))
			_p("body", Vector3(0, absf(c) * 0.08 * hs, 0))
			_r("body", Vector3(c * 0.14, 0, 0))
			_r("head", Vector3(-c * 0.12 - 0.1, 0, 0))
			_r("tail", Vector3(0.3 + s * 0.2, sin(lt * f * 0.5) * 0.3, 0))
	else:
		var b := sin(lt * 2.4)
		_p("body", Vector3(0, b * 0.012, 0))
		_r("head", Vector3(b * 0.05 + sin(lt * 0.9) * 0.1, sin(lt * 0.7) * 0.35, 0))
		_r("tail", Vector3(0.1, sin(lt * 2.0) * 0.4, 0))
		if insect:
			for n in ["leg_fl", "leg_fr", "leg_ml", "leg_mr", "leg_bl", "leg_br"]:
				_r(n, Vector3(sin(lt * 3.0 + n.length()) * 0.06, 0, 0))

func _loop_taur(run: bool, lt: float) -> void:
	var b := sin(lt * 1.8)
	if run:
		var f: float = P["run_freq"]
		var s := sin(lt * f)
		var c := cos(lt * f)
		var st: float = P["stride"]
		_r("leg_fl", Vector3(s * st, 0, -0.3 * maxf(c, 0.0)))
		_r("leg_br", Vector3(s * st, 0, 0.3 * maxf(c, 0.0)))
		_r("leg_fr", Vector3(-s * st, 0, 0.3 * maxf(-c, 0.0)))
		_r("leg_bl", Vector3(-s * st, 0, -0.3 * maxf(-c, 0.0)))
		_p("body", Vector3(0, absf(c) * 0.05, 0))
		_r("abdomen", Vector3(0.05, s * 0.12, 0))
		_r("chest", Vector3(-0.2, -s * 0.08, 0))
		_r("arm_l", Vector3(0.5, 0, -0.2)); _r("arm_r", Vector3(0.5, 0, 0.2))
		var wf := sin(lt * 38.0) * 0.35
		_r("wing_l", Vector3(0, 0, wf)); _r("wing_r", Vector3(0, 0, -wf))
	else:
		_p("body", Vector3(0, b * 0.02, 0))
		_r("abdomen", Vector3(b * 0.04, sin(lt * 0.8) * 0.1, 0))
		_r("chest", Vector3(b * 0.03, sin(lt * 0.5) * 0.12, 0))
		_r("head", Vector3(-b * 0.05, sin(lt * 0.6) * 0.15, 0))
		_r("arm_l", Vector3(0.3 + b * 0.08, 0, -0.1)); _r("arm_r", Vector3(0.3 + b * 0.08, 0, 0.1))
		var wf := sin(lt * 3.0) * 0.08
		_r("wing_l", Vector3(0, wf, wf)); _r("wing_r", Vector3(0, -wf, -wf))
		for n in ["leg_fl", "leg_fr", "leg_bl", "leg_br"]:
			_r(n, Vector3(sin(lt * 2.0 + n.hash() % 7) * 0.03, 0, 0))

func _loop_worm(run: bool, lt: float) -> void:
	_r("seg1", Vector3(sin(lt * 2.0) * 0.08, 0, cos(lt * 1.7) * 0.08))
	_r("seg2", Vector3(sin(lt * 2.0 + 0.8) * 0.12, 0, cos(lt * 1.7 + 0.8) * 0.12))
	_r("seg3", Vector3(sin(lt * 2.0 + 1.6) * 0.14, 0, cos(lt * 1.7 + 1.6) * 0.14))
	_r("head", Vector3(sin(lt * 2.0 + 2.4) * 0.12, sin(lt * 0.9) * 0.4, 0))
	if run:
		# tunnelling: body sinks below the mound, the mound churns
		_p("seg1", Vector3(0, -1.3, 0))
		_s("mound", Vector3(0.85 + sin(lt * 14.0) * 0.08, 1.2 + sin(lt * 11.0) * 0.2, 0.85 + cos(lt * 14.0) * 0.08))
		_r("mound", Vector3(0, lt * 3.0, 0))

func _loop_blob(run: bool, lt: float) -> void:
	var b := sin(lt * 3.2)
	_s("body", Vector3(1.0 + b * 0.05, 1.0 - b * 0.03, 1.0 + b * 0.05))
	_r("head", Vector3(0, sin(lt * 0.8) * 0.3, 0))
	_r("arm_l", Vector3(sin(lt * 2.0) * 0.2, 0, -0.2)); _r("arm_r", Vector3(-sin(lt * 2.0) * 0.2, 0, 0.2))
	if run:
		var f: float = P["run_freq"]
		var s := sin(lt * f)
		_r("root", Vector3(0, 0, s * 0.1))
		_r("leg_l", Vector3(s * 0.5, 0, 0)); _r("leg_r", Vector3(-s * 0.5, 0, 0))
		_p("body", Vector3(0, absf(cos(lt * f)) * 0.06, 0))
		_r("arm_l", Vector3(0.8 + s * 0.4, 0, -0.6)); _r("arm_r", Vector3(0.8 - s * 0.4, 0, 0.6))

func _loop_float(run: bool, lt: float) -> void:
	var b := sin(lt * 1.4)
	_p("body", Vector3(0, b * 0.12 * hs * 0.6, 0))
	_r("tail", Vector3(sin(lt * 1.9) * 0.08, 0, cos(lt * 1.5) * 0.1))
	_r("arm_l", Vector3(0.2 + sin(lt * 1.1) * 0.15, 0, -0.15)); _r("arm_r", Vector3(0.2 + sin(lt * 1.1 + 1.0) * 0.15, 0, 0.15))
	_r("head", Vector3(sin(lt * 0.9) * 0.08, sin(lt * 0.5) * 0.2, 0))
	_r("mask1", Vector3(0, lt * 0.9, 0)); _r("mask2", Vector3(0, lt * 0.9, 0))
	_p("mask1", Vector3(0, sin(lt * 2.0) * 0.2, 0)); _p("mask2", Vector3(0, cos(lt * 2.0) * 0.2, 0))
	if run:
		_r("body", Vector3(-0.22, 0, 0))
		_r("tail", Vector3(-0.45, 0, sin(lt * 4.0) * 0.12))

## Resting by a fire (title screen): bipeds sit on a log, the brood queen settles down on her legs.
func _loop_sit(lt: float) -> void:
	var b := sin(lt * 1.5)
	var look := sin(lt * 0.23) * 0.35 + sin(lt * 0.61) * 0.12
	if style == "taur":
		_p("body", Vector3(0, -0.16 + b * 0.01, 0))
		_r("body", Vector3(0.04, 0, 0))
		for n in ["leg_fl", "leg_bl"]:
			_r(n, Vector3(0, 0, 0.22))
		for n in ["leg_fr", "leg_br"]:
			_r(n, Vector3(0, 0, -0.22))
		_r("abdomen", Vector3(0.12 + b * 0.02, 0, 0))
		_r("chest", Vector3(0.12 + b * 0.03, look * 0.5, 0))
		_s("chest", Vector3(1.0 + b * 0.012, 1.0 + b * 0.018, 1.0 + b * 0.012))
		_r("head", Vector3(0.1 - b * 0.03, look, 0))
		_r("arm_l", Vector3(-0.35, 0, 0.15)); _r("arm_r", Vector3(-0.35, 0, -0.15))
		_r("wing_l", Vector3(0, 0.25, 0.2)); _r("wing_r", Vector3(0, -0.25, -0.2))
		return
	var hip_y: float = rest[bi["hips"]].y if bi.has("hips") else 0.9
	_p("hips", Vector3(0, 0.46 - hip_y, 0.05))
	_r("leg_l", Vector3(1.0, 0.1, -0.16))
	_r("leg_r", Vector3(1.0, -0.1, 0.16))
	_r("chest", Vector3(-0.32 + b * 0.025, look * 0.4, 0))
	_s("chest", Vector3(1.0 + b * 0.012, 1.0 + b * 0.018, 1.0 + b * 0.012))
	_r("head", Vector3(0.22 - b * 0.02, look, 0))
	_r("arm_l", Vector3(0.95 + b * 0.02, 0, -0.18))
	_r("arm_r", Vector3(0.95 + b * 0.02, 0, 0.18))
	_r("cape", Vector3(0.5, 0, 0))
	_r("scarf1", Vector3(0.6 + sin(lt * 2.3) * 0.08, sin(lt * 1.7) * 0.1, 0))
	_r("scarf2", Vector3(0.5 + sin(lt * 2.9) * 0.1, 0, sin(lt * 2.0) * 0.1))
	# weapons rest across the lap / lean on the ground instead of pointing at the fire
	var wx := 0.75 if kind == "ashwarden" else -1.1
	_r("weapon_r", (P["w_idle_r"] as Vector3) + Vector3(wx, 0, 0.35))
	_r("weapon_l", (P["w_idle_l"] as Vector3) + Vector3(wx, 0, -0.35))


func _loop_totem(_run: bool, lt: float) -> void:
	_s("head", Vector3.ONE * (1.0 + sin(lt * 5.0) * 0.03))

# ------------------------------------------------------------------ one-shots

func _pose_hit(p: float) -> void:
	var w := sin(p * PI)
	_r("chest", R.get("chest", Vector3.ZERO) + Vector3(0.35, 0, 0) * w)
	_r("head", R.get("head", Vector3.ZERO) + Vector3(0.3, 0, 0) * w)
	_r("body", R.get("body", Vector3.ZERO) + Vector3(0.25, 0, 0) * w)
	_r("seg3", R.get("seg3", Vector3.ZERO) + Vector3(0.3, 0, 0) * w)
	_p("root", Vector3(0, 0, 0.1 * hs * w))

func _pose_death(p: float) -> void:
	var f := smoothstep(0.0, 0.42, p)
	dissolve = clampf((p - 0.4) / 0.55, 0.0, 1.0)
	shadow_alpha = 1.0 - dissolve
	glow_boost = 0.4 * f
	match style:
		"biped":
			_r("root", Vector3(1.4 * f, 0, 0.15 * f))
			_p("root", Vector3(0, 0.05 * hs * f, 0.1 * hs * f))
			_r("arm_l", Vector3(0.6, 0, -1.1) * f); _r("arm_r", Vector3(0.6, 0, 1.1) * f)
			_r("leg_l", Vector3(0.5, 0, -0.2) * f); _r("leg_r", Vector3(0.2, 0, 0.2) * f)
			_r("head", Vector3(-0.5, 0.3, 0) * f)
		"quad", "taur":
			_r("root", Vector3(0, 0, 1.45 * f))
			_p("root", Vector3(0, 0.08 * hs * f, 0))
			for n in ["leg_fl", "leg_fr", "leg_ml", "leg_mr", "leg_bl", "leg_br"]:
				_r(n, Vector3(0.9 * f, 0, 0))
		"worm":
			_p("seg1", Vector3(0, -1.4 * f, 0))
			_r("head", Vector3(0.8 * f, 0, 0))
			_s("mound", Vector3.ONE * (1.0 - 0.6 * dissolve))
		"blob":
			_s("body", Vector3.ONE * (1.0 + 0.35 * f))
			_p("body", Vector3(0, -0.2 * f, 0))
		"float":
			_p("body", Vector3(0, -0.8 * hs * f, 0))
			_r("body", Vector3(0.4 * f, 0, 0))
			_p("mask1", Vector3(0, -1.5 * f, 0)); _p("mask2", Vector3(0, -1.5 * f, 0))
		"robe":
			_s("hips", Vector3(1.0 + 0.3 * f, 1.0 - 0.6 * f, 1.0 + 0.3 * f))
			_r("chest", Vector3(-0.9 * f, 0, 0))
			_r("head", Vector3(-0.4 * f, 0, 0))
		"totem":
			_r("root", Vector3(0.3 * f, 0, 0.2 * f))
			_p("root", Vector3(0, -0.4 * f, 0))

func _pose_spawn(p: float) -> void:
	if style == "worm":
		var m := smoothstep(0.0, 0.35, p)
		_s("mound", Vector3(m, m, m))
		var rise := smoothstep(0.3, 0.8, p)
		_p("seg1", Vector3(0, -1.4 * (1.0 - rise), 0))
		dissolve = 1.0 - smoothstep(0.2, 0.6, p)
		if p > 0.6:
			_r("head", Vector3(0.4 * sin((p - 0.6) / 0.4 * PI), 0, 0))
	else:
		var e := smoothstep(0.0, 1.0, p)
		dissolve = 1.0 - e
		_p("root", Vector3(0, -0.45 * height * (1.0 - e), 0))
		_r("root", Vector3(-0.3 * (1.0 - e), 0, 0))
		glow_boost = 1.0 - e
	shadow_alpha = smoothstep(0.0, 0.6, p)
