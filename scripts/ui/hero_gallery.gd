class_name HeroGallery
extends Control
## Main-menu Heroes screen: roster on the left, the hero's model on a turntable in the middle (drag to spin,
## tap it to attack), skills and skins on the right. Skins preview on tap and equip with the Equip button.

const TURN_SPEED := 0.45          # idle spin, rad/s
const IDLE_SPIN_DELAY := 2.5      # seconds after a drag before the idle spin resumes

var on_back: Callable
var hero_id := ""
var skin_id := "classic"           # skin shown on the model (previewed, not necessarily equipped)
var tab := "skills"
var beast := false

var _vp: SubViewport
var _vpc: SubViewportContainer
var _turntable: Node3D
var _model: Node3D
var _cam: Camera3D
var _spin_pause := 0.0
var _drag_px := 0.0
var _tiles := {}
var _info: VBoxContainer
var _anim_row: HBoxContainer
var _tab_btns := {}
var _content: VBoxContainer
var _scroll: ScrollContainer


static func create(back: Callable, first_hero := "") -> HeroGallery:
	var g := HeroGallery.new()
	g.on_back = back
	g.hero_id = first_hero if DB.HEROES.has(first_hero) else DB.HERO_ORDER[0]
	return g


func _ready() -> void:
	name = "HeroGallery"
	theme = UIK.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.01, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := UIK.safe_margins(get_viewport())
	margin.add_theme_constant_override("margin_left", int(16 + m.x))
	margin.add_theme_constant_override("margin_right", int(16 + m.z))
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var back := UIK.button("Back", "", Vector2(140, 64))
	back.pressed.connect(func(): on_back.call())
	head.add_child(back)
	var title := Menus._outlined(UIK.label("Heroes", "TitleLabel", 40, UIK.col("gold", Color.GOLD)))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(140, 0)
	head.add_child(spacer)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	body.add_child(_build_roster())
	body.add_child(_build_stage())
	body.add_child(_build_info())
	tab = Game.arg("tab", tab)   # test hooks: --tab=skins --skin=<id>
	_select(hero_id)
	if Game.args.has("skin"):
		skin_id = Game.arg("skin", "classic")
		_rebuild_model()
		_rebuild_tab()


# ---------------------------------------------------------------- roster
func _build_roster() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(2 * 92 + 8 + 12, 0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for id in DB.HERO_ORDER:
		var hid: String = id
		var b := Button.new()
		b.name = "Tile_" + hid
		b.custom_minimum_size = Vector2(92, 92)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.tooltip_text = DB.HEROES[hid]["name"]
		var por := UIK.icon_rect("portrait_" + hid, 80)
		por.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		por.offset_left = 6; por.offset_top = 6; por.offset_right = -6; por.offset_bottom = -6
		b.add_child(por)
		b.pressed.connect(func():
			Audio.play("click")
			_select(hid))
		grid.add_child(b)
		_tiles[hid] = b
	return scroll


# ---------------------------------------------------------------- 3D stage
func _build_stage() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	col.add_theme_constant_override("separation", 6)
	_vpc = SubViewportContainer.new()
	_vpc.name = "Stage"
	_vpc.stretch = true
	_vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vpc.custom_minimum_size = Vector2(260, 200)
	_vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	_vpc.gui_input.connect(_on_stage_input)
	col.add_child(_vpc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.handle_input_locally = false
	_vpc.add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.5, 0.48)
	e.ambient_light_energy = 0.4
	env.environment = e
	_vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.7)
	key.light_energy = 1.0
	key.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	_vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.65, 1.0)
	fill.light_energy = 0.45
	fill.rotation = Vector3(deg_to_rad(-15), deg_to_rad(-140), 0)
	_vp.add_child(fill)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.2)
	glow.light_energy = 1.2
	glow.omni_range = 4.0
	glow.position = Vector3(0, 0.15, 1.6)
	_vp.add_child(glow)
	# stone plinth with an ember rim
	var plinth := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.25
	cm.bottom_radius = 1.4
	cm.height = 0.3
	cm.radial_segments = 40
	plinth.mesh = cm
	plinth.position.y = -0.15
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.2, 0.18, 0.17)
	pm.roughness = 0.9
	plinth.material_override = pm
	_vp.add_child(plinth)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.22
	tm.outer_radius = 1.3
	tm.rings = 48
	rim.mesh = tm
	rim.position.y = 0.0
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.0, 0.45, 0.15)
	rim.material_override = rm
	rim.name = "PlinthRim"
	_vp.add_child(rim)
	_turntable = Node3D.new()
	_turntable.rotation.y = 0.5
	_vp.add_child(_turntable)
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_cam.current = true
	_vp.add_child(_cam)
	_anim_row = HBoxContainer.new()
	_anim_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_anim_row.add_theme_constant_override("separation", 8)
	col.add_child(_anim_row)
	return col


func _rebuild_model() -> void:
	if _model and is_instance_valid(_model):
		_model.queue_free()
	_model = null
	var kind := "twinhide_beast" if beast and hero_id == "twinhide" else hero_id
	var u = Art.create_unit(kind) if Art.has_method("create_unit") else null
	if not (u is Node3D):
		return
	_model = u
	if _model.get("shadow_alpha") != null:
		_model.set("shadow_alpha", 0.0)   # the shared blob-shadow layer lives in the menu world, not this one
	_turntable.add_child(_model)
	Skins.apply(_model, hero_id, skin_id)
	var h: float = float(_model.get("height")) if _model.get("height") != null else 1.8
	var r: float = float(_model.get("radius")) if _model.get("radius") != null else 0.5
	var size := maxf(h, r * 2.6)
	var look := Vector3(0, h * 0.48, 0)
	_cam.position = look + Vector3(0, size * 0.3, size * 2.6 + 2.2)
	_cam.look_at(look, Vector3.UP)
	var rim := _vp.get_node_or_null("PlinthRim") as MeshInstance3D
	if rim:
		(rim.material_override as StandardMaterial3D).albedo_color = Skins.rarity_color(Skins.find(hero_id, skin_id)["rarity"]).lerp(Color(1, 0.45, 0.15), 0.25 if skin_id == "classic" else 0.0)


func _play(state: String) -> void:
	if _model and _model.has_method("set_state"):
		_model.call("set_state", state)


func _on_stage_input(ev: InputEvent) -> void:
	if ev is InputEventScreenDrag:
		_turntable.rotation.y += ev.relative.x * 0.012
		_drag_px += absf(ev.relative.x) + absf(ev.relative.y)
		_spin_pause = IDLE_SPIN_DELAY
	elif ev is InputEventScreenTouch:
		if ev.pressed:
			_drag_px = 0.0
		elif _drag_px < 12.0:
			_play("attack")


func _process(delta: float) -> void:
	if _turntable == null:
		return
	if _spin_pause > 0.0:
		_spin_pause -= delta
	else:
		_turntable.rotation.y += TURN_SPEED * delta


# ---------------------------------------------------------------- info panel
func _build_info() -> Control:
	var card := UIK.panel("FramePanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.05
	card.custom_minimum_size = Vector2(420, 0)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 6)
	card.add_child(_info)
	return card


func _select(id: String) -> void:
	hero_id = id
	skin_id = Skins.equipped(id)
	beast = false
	for k in _tiles:
		(_tiles[k] as Button).set_pressed_no_signal(k == id)
		(_tiles[k] as Button).modulate = Color.WHITE if k == id else Color(0.7, 0.67, 0.64)
	_rebuild_model()
	_rebuild_anim_row()
	_rebuild_info()


func _rebuild_anim_row() -> void:
	for c in _anim_row.get_children():
		c.queue_free()
	var acts := [["Idle", "idle"], ["Run", "run"], ["Attack", "attack"], ["Cast", "cast"]]
	for a in acts:
		var st: String = a[1]
		var b := UIK.button(a[0], "", Vector2(104, 56))
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func(): _play(st))
		_anim_row.add_child(b)
	if DB.HEROES[hero_id].has("beast_skills"):
		var f := UIK.button(L.t("Human form") if beast else L.t("Beast form"), "", Vector2(150, 56))
		f.add_theme_font_size_override("font_size", 20)
		f.pressed.connect(func():
			beast = not beast
			_rebuild_model()
			_rebuild_anim_row())
		_anim_row.add_child(f)


func _rebuild_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	var d: Dictionary = DB.HEROES[hero_id]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_info.add_child(top)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	names.add_child(Menus._fit(Menus._outlined(UIK.label(d["name"], "TitleLabel", 32, UIK.col("ember", Color(1, 0.55, 0.25))), 6)))
	names.add_child(Menus._fit(UIK.label(L.t(d["title"]), "", 19, UIK.col("text", Color(0.95, 0.9, 0.82)))))
	var stat_names := {"str": "Strength", "agi": "Agility", "int": "Intellect"}
	names.add_child(Menus._fit(UIK.label("%s · %s · %s · %s" % [L.t(d.get("tag", "")), L.t(d["role"]), L.t(stat_names[d["primary"]]), Menus.difficulty_name(int(d.get("difficulty", 1)))],
		"SmallLabel", 16, UIK.col("dim", Color(0.75, 0.7, 0.62)))))
	names.add_child(Menus._dmg_label(hero_id, 16, true))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_info.add_child(tabs)
	_tab_btns.clear()
	for t in [["skills", "Skills"], ["skins", "Skins"]]:
		var key: String = t[0]
		var b := UIK.button(t[1], "", Vector2(150, 56))
		b.name = "Tab_" + key
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func():
			tab = key
			_rebuild_tab())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_tab_btns[key] = b
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_rebuild_tab()


func _rebuild_tab() -> void:
	for k in _tab_btns:
		(_tab_btns[k] as Button).set_pressed_no_signal(k == tab)
	for c in _content.get_children():
		_content.remove_child(c)   # detach now so the rebuilt widgets keep their names
		c.queue_free()
	if tab == "skins":
		_fill_skins()
	else:
		_fill_skills()
	_scroll.scroll_vertical = 0


static func _num(x: float) -> String:
	return "%d" % int(x) if is_equal_approx(x, roundf(x)) else "%.1f" % x


static func _range_text(a: Array) -> String:
	if a.is_empty():
		return ""
	var lo := _num(float(a[0]))
	var hi := _num(float(a[a.size() - 1]))
	return lo if lo == hi else "%s→%s" % [lo, hi]


func _fill_skills() -> void:
	var d: Dictionary = DB.HEROES[hero_id]
	var ps := UIK.label(d["playstyle"], "", 17, UIK.col("text", Color(0.95, 0.9, 0.82)))
	ps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ps.custom_minimum_size = Vector2(200, 0)
	_content.add_child(ps)
	var skills: Array = d["skills"].duplicate()
	var keys := ["Q", "W", "E", "R"]
	if d.has("beast_skills"):
		skills = [d["skills"][0], d["skills"][1], d["beast_skills"][0], d["beast_skills"][1], d["skills"][2], d["skills"][3]]
		keys = ["Q", "W", "Q·" + L.t("beast"), "W·" + L.t("beast"), "E", "R"]
	for i in skills.size():
		var sid: String = skills[i]
		var sd: Dictionary = DB.SKILLS[sid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_content.add_child(row)
		var ic := UIK.icon_rect(sid, 56)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tv)
		tv.add_child(UIK.label("%s  %s" % [keys[i], L.t(sd["name"])], "", 19, UIK.col("gold", Color.GOLD)))
		var facts := []
		var mana: Array = sd.get("mana", [])
		if not mana.is_empty() and float(mana.max()) > 0.0:
			facts.append(L.f("Mana %s", [_range_text(mana)]))
		if float(sd.get("hp", 0.0)) > 0.0:
			facts.append(L.f("Costs %d%% HP", [roundi(float(sd["hp"]) * 100.0)]))
		if int(sd.get("rage", 0)) > 0:
			facts.append(L.f("Costs %d Rage", [int(sd["rage"])]))
		if (sd.get("cd", []) as Array).size() > 0:
			facts.append(L.f("Cooldown %s s", [_range_text(sd["cd"])]))
		facts.append(L.f("Ranks %d", [int(sd.get("max", 4))]))
		var fl := UIK.label("   ".join(facts), "SmallLabel", 14, UIK.col("dim", Color(0.75, 0.7, 0.62)))
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(150, 0)
		tv.add_child(fl)
		var dl := UIK.label(L.t(sd["desc"]), "SmallLabel", 16, UIK.col("text", Color(0.9, 0.86, 0.8)))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(150, 0)
		tv.add_child(dl)


func _fill_skins() -> void:
	var eq := Skins.equipped(hero_id)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for s in Skins.for_hero(hero_id):
		grid.add_child(_skin_card(s, eq))
	var cur := Skins.find(hero_id, skin_id)
	var own := Skins.owned(hero_id, skin_id)
	var act := UIK.button(L.t("Equipped") if skin_id == eq else (L.f("Equip %s", [L.t(cur["name"])]) if own else L.t("Locked: store coming soon")),
		"PrimaryButton" if own and skin_id != eq else "", Vector2(0, 68))
	act.name = "EquipButton"
	act.add_theme_font_size_override("font_size", 22)
	act.disabled = skin_id == eq or not own
	act.pressed.connect(func():
		if Skins.equip(hero_id, skin_id):
			Audio.play("level_up")
			_rebuild_tab())
	_content.add_child(act)


func _skin_card(s: Dictionary, eq: String) -> Control:
	var sid: String = s["id"]
	var rc := Skins.rarity_color(s["rarity"])
	var b := Button.new()
	b.name = "Skin_" + sid
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.07, 0.9).lerp(rc, 0.12)
	sb.border_color = rc if sid == skin_id else rc.darkened(0.45)
	sb.set_border_width_all(4 if sid == skin_id else 2)
	sb.set_corner_radius_all(10)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, sb)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10; h.offset_right = -8
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var sw := Panel.new()
	sw.custom_minimum_size = Vector2(40, 40)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swb := StyleBoxFlat.new()
	swb.bg_color = s.get("accent", UIK.col(hero_id, Color(1, 0.5, 0.2)))
	swb.set_corner_radius_all(20)
	swb.set_border_width_all(3)
	swb.border_color = rc
	sw.add_theme_stylebox_override("panel", swb)
	h.add_child(sw)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	tv.add_child(Menus._fit(Menus._outlined(UIK.label(L.t(s["name"]), "", 18, UIK.col("text", Color(0.95, 0.9, 0.82))), 4)))
	tv.add_child(Menus._fit(UIK.label(L.t(Skins.rarity_name(s["rarity"])), "SmallLabel", 15, rc)))
	var status := L.t("Equipped") if sid == eq else (L.t("Owned") if Skins.owned(hero_id, sid) else L.t("Locked"))
	tv.add_child(Menus._fit(UIK.label(status, "SmallLabel", 14, UIK.col("gold", Color.GOLD) if sid == eq else UIK.col("dim", Color(0.75, 0.7, 0.62)))))
	b.pressed.connect(func():
		Audio.play("click")
		skin_id = sid
		_rebuild_model()
		_play("cast")
		_rebuild_tab())
	return b
