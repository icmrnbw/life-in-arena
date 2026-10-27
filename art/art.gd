extends Node
## Emberpit `Art` autoload — procedural visuals (see CONTRACT.md for the API).
## Everything here is generated in code: meshes, shaders, textures, icons, UI theme.

const SH := preload("res://art/shaders.gd")
const Rigs := preload("res://art/rigs.gd")
const UnitVisual := preload("res://art/unit_visual.gd")
const World := preload("res://art/world.gd")
const Fx := preload("res://art/fx.gd")
const Icons := preload("res://art/icons.gd")
const UiTheme := preload("res://art/ui_theme.gd")
const WeatherFx := preload("res://art/weather_fx.gd")
const ArenaFx := preload("res://art/arena_fx.gd")

var palette := {
	"ember": Color("ff7a2f"), "gold": Color("f2c14e"), "hp": Color("d83a3a"), "mana": Color("3a7bd8"),
	"xp": Color("a55be0"), "danger": Color("ff3030"), "text": Color("f4ead8"), "dim": Color("9a8f80"),
	"panel": Color("1c1712"), "frame": Color("8a6a3a"),
	# extras (safe to ignore)
	"flow": Color("3ff0dc"), "heal": Color("6cff7a"), "bronze": Color("b0773a"), "bronze_dark": Color("4a3020"),
	"ashwarden": Color("ff7a2f"), "riftdancer": Color("3ff0dc"), "hivemother": Color("9cff3a"),
	"sanguine": Color("e0263c"), "snarewright": Color("c8d24a"), "twinhide": Color("c86bff"), "twinhide_beast": Color("c86bff"),
	"gravekeeper": Color("8affc8"), "stoneshaper": Color("d9a066"), "gunsmith": Color("4fb8ff"), "sunspeaker": Color("ffe680"),
	"duelist": Color("ffd25a"), "vanguard": Color("ff5a33"), "nightblade": Color("9a6bff"), "skyspear": Color("7fd4ff"), "frostweaver": Color("9ae8ff"), "stormcaller": Color("b0a0ff"), "alchemist": Color("9cff4a"), "chronomancer": Color("f0d890"),
}

var _fx_root: Node3D
var _units: Array = []
var _unit_count := 0
var _shadow_mmi: MultiMeshInstance3D
var _theme: Theme
var _fx: RefCounted

func _ready() -> void:
	_fx = Fx.new()
	_fx.art = self
	SH.noise_tex()
	process_priority = 1000
	_diag_on = OS.get_cmdline_user_args().has("--art-diag")  # run after game scripts have moved the camera this frame

# ------------------------------------------------------------------ occluder fade
# World stone (pillars, walls, camp props) is screen-door dithered where it lies inside a capsule
# from the active Camera3D to the focus point, so the hero is never hidden. Focus, in priority order:
#   1. a point passed to set_focus() this frame or recently (optional; no caller required),
#   2. the first Node3D in group "art_focus" (optional),
#   3. automatic: the active camera's forward ray hit on the plane y = 0.5, raised 0.4 m.
var _diag_on := false
var _focus_override := Vector3.ZERO
var _focus_override_t := -1.0

func set_focus(pos: Vector3) -> void:
	_focus_override = pos
	_focus_override_t = 0.25

func _update_occluders(delta: float) -> void:
	var on := false
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam != null and cam.is_inside_tree():
		a = cam.global_position
		_focus_override_t -= delta
		if _focus_override_t > 0.0:
			b = _focus_override; on = true
		else:
			var f := get_tree().get_first_node_in_group("art_focus")
			if f is Node3D and (f as Node3D).is_inside_tree():
				b = (f as Node3D).global_position + Vector3(0, 0.9, 0); on = true
			else:
				var fw := -cam.global_transform.basis.z
				if fw.y < -0.05:
					var t := (0.5 - a.y) / fw.y
					b = a + fw * t + Vector3(0, 0.4, 0); on = true
	var keep: Array = []
	for m in SH.occluder_mats:
		if m == null or not is_instance_valid(m):
			continue
		keep.append(m)
		var sm := m as ShaderMaterial
		sm.set_shader_parameter("occ_on", 1.0 if on else 0.0)
		if on:
			sm.set_shader_parameter("occ_a", a)
			sm.set_shader_parameter("occ_b", b)
	SH.occluder_mats = keep

# ------------------------------------------------------------------ environment / world

func setup_environment(world_env_parent: Node) -> void:
	if world_env_parent == null:
		return
	World.setup_environment(world_env_parent)

func build_world(parent: Node3D) -> Dictionary:
	if parent == null:
		return {"shop": null, "fountain": null}
	return World.build(parent)

## Title-screen campsite (ledge, bench, tent, props) with the bonfire at `pos`.
func menu_camp(parent: Node3D, pos: Vector3) -> Node3D:
	if parent == null:
		return null
	return World.menu_camp(parent, pos)

## Title-screen bonfire (stone ring, log teepee, flames, sparks, smoke, flickering light) at `pos`.
func bonfire(parent: Node3D, pos: Vector3) -> Node3D:
	if parent == null:
		return null
	return World.bonfire(parent, pos)

## Weather visuals for a run (rain, mist, dust, embers, lightning, sky mood); see art/weather_fx.gd.
func arena_fx(run_node: Node) -> Node:
	if run_node == null:
		return null
	var a: Node3D = ArenaFx.new()
	run_node.add_child(a)
	a.setup(run_node)
	return a


func weather_fx(run_node: Node) -> Node:
	if run_node == null:
		return null
	var w: Node3D = WeatherFx.new()
	run_node.add_child(w)
	w.setup(run_node)
	return w

# ------------------------------------------------------------------ units

func create_unit(kind: String) -> Node3D:
	var rig := Rigs.get_rig(String(kind))
	var u: Node3D = UnitVisual.new()
	u.name = "Unit_" + String(kind)
	u.setup(rig, String(kind))
	return u

func create_projectile(kind: String) -> Node3D:
	return _fx.projectile(String(kind))

# ------------------------------------------------------------------ fx

func set_fx_root(root: Node3D) -> void:
	_fx_root = root

func fx(name: String, opts: Dictionary) -> Node:
	var root := _get_fx_root()
	if opts == null:
		opts = {}
	return _fx.spawn(String(name), opts, root)

func _get_fx_root() -> Node:
	if _fx_root != null and is_instance_valid(_fx_root) and _fx_root.is_inside_tree():
		return _fx_root
	var cs := get_tree().current_scene if get_tree() else null
	if cs != null:
		return cs
	return get_tree().root if get_tree() else null

# ------------------------------------------------------------------ icons / theme

func icon(id: String) -> Texture2D:
	return Icons.get_icon(String(id))

func make_theme() -> Theme:
	if _theme == null:
		_theme = UiTheme.build(palette)
	return _theme

# ------------------------------------------------------------------ blob shadows (one MultiMesh for all units)

func _register_unit(u: Node3D) -> void:
	if not _units.has(u):
		_units.append(u)
	_unit_count = _units.size()

func _unregister_unit(u: Node3D) -> void:
	_units.erase(u)
	_unit_count = _units.size()

func _ensure_shadow_layer() -> bool:
	if _shadow_mmi != null and is_instance_valid(_shadow_mmi) and _shadow_mmi.is_inside_tree():
		return true
	var parent: Node = null
	if _fx_root != null and is_instance_valid(_fx_root) and _fx_root.is_inside_tree():
		parent = _fx_root
	else:
		for u in _units:
			if is_instance_valid(u) and u.is_inside_tree() and u.get_parent() is Node3D:
				parent = u.get_parent()
				break
	if parent == null:
		return false
	_shadow_mmi = MultiMeshInstance3D.new()
	_shadow_mmi.name = "BlobShadows"
	_shadow_mmi.top_level = true
	_shadow_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	mm.mesh = pm
	mm.instance_count = 256
	mm.visible_instance_count = 0
	_shadow_mmi.multimesh = mm
	_shadow_mmi.material_override = SH.mat("shadow")
	_shadow_mmi.custom_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 40, 800))
	parent.add_child(_shadow_mmi)
	_shadow_mmi.global_transform = Transform3D.IDENTITY
	return true

var _diag_t := 0.0

func _diag(dt: float) -> void:
	_diag_t += dt
	if _diag_t < 4.0:
		return
	_diag_t = 0.0
	var counts := {}
	var lights := []
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Light3D and (n as Light3D).is_visible_in_tree():
			lights.append("%s:%s r=%.1f" % [n.get_class(), n.name, (n as OmniLight3D).omni_range if n is OmniLight3D else 0.0])
		if n is GeometryInstance3D and (n as Node3D).is_visible_in_tree():
			var key := n.get_class()
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				key += "(%d surf)" % (n as MeshInstance3D).mesh.get_surface_count()
			var par := n.get_parent()
			var pk = par.get("kind") if par else null
			key += " <" + (("fx:" + str(pk)) if pk != null and par.get("free_after") != null else (str(par.name).left(18) if par else "")) + ">"
			counts[key] = counts.get(key, 0) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var vp := get_viewport().get_viewport_rid()
	var info := []
	for ty in [RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS]:
		info.append([RenderingServer.viewport_get_render_info(vp, ty, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp, ty, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)])
	print("ART_DIAG drawcalls/objects visible,shadow,canvas = ", info, " total=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("ART_DIAG lights=", lights)
	for k in keys.slice(0, 25):
		print("ART_DIAG  ", counts[k], "  ", k)

func _process(_dt: float) -> void:
	_update_occluders(_dt)
	if _diag_on:
		_diag(_dt)
	if _units.is_empty():
		if _shadow_mmi != null and is_instance_valid(_shadow_mmi):
			_shadow_mmi.multimesh.visible_instance_count = 0
		return
	if not _ensure_shadow_layer():
		return
	var mm := _shadow_mmi.multimesh
	var n := 0
	for u in _units:
		if n >= mm.instance_count:
			break
		if not is_instance_valid(u) or not u.is_inside_tree() or not u.is_visible_in_tree():
			continue
		var gp: Vector3 = u.global_position
		var r: float = u.radius
		var a: float = u.shadow_alpha if u.get("shadow_alpha") != null else 1.0
		var floating: bool = u.get("style") == "float"
		if floating:
			a *= 0.6
		var sc := r * 2.6
		mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(sc, 1.0, sc)), Vector3(gp.x, gp.y + 0.035, gp.z)))
		mm.set_instance_color(n, Color(1, 1, 1, a))
		n += 1
	mm.visible_instance_count = n
