extends CanvasLayer
## In-run HUD: bars, wave/prep info, gold & lives, boss bar, toasts, banner, item slots, shop, touch controls.

signal pause_requested
signal skills_info_requested

var run: Run
var root: Control
var controls: Control
var world_bars: Control
var shop: Control = null

var hp_bar: ProgressBar
var hp_label: Label
var mana_bar: ProgressBar
var mana_label: Label
var xp_bar: ProgressBar
var level_label: Label
var meter_bar: ProgressBar
var meter_label: Label
var meter_box: Control
var wave_label: Label
var prep_box: Control
var prep_label: Label
var fight_btn: Button
var shop_btn: Button
var boss_box: Control
var preview_box: Control
var preview_name: Label
var preview_rule: Label
var preview_desc: Label
var _preview_wave := -1
var boss_bar: ProgressBar
var boss_label: Label
var gold_label: Label
var lives_label: Label
var pause_btn: Button
var info_btn: Button
var toast_box: VBoxContainer
var banner_box: VBoxContainer
var banner_label: Label
var banner_sub: Label
var banner_tween: Tween
var slots_box: HBoxContainer
var slot_nodes: Array = []
var slot_overlay: Control
var top_left: Control
var top_right: Control
var top_center: Control
var right_col: VBoxContainer
var sp_label: Label
var sp_badge: Control
var level_badge: Control
var _near_shop_dismissed := false
var _last_gold := -1


func setup(r: Run) -> void:
	run = r
	layer = 5
	root = Control.new()
	root.name = "HudRoot"
	root.theme = UIK.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	world_bars = load("res://scripts/ui/world_bars.gd").new()
	world_bars.run = run
	root.add_child(world_bars)

	controls = load("res://scripts/ui/touch_controls.gd").new()
	root.add_child(controls)
	controls.setup(run, self)

	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_slots()
	_build_banner_toasts()

	controls.blockers = [top_right, fight_btn, shop_btn, slots_box, pause_btn, info_btn, prep_box]
	run.toast_requested.connect(show_toast)
	run.banner_requested.connect(show_banner)
	root.resized.connect(_apply_safe_area)
	_apply_safe_area()


func _apply_safe_area() -> void:
	var m := UIK.safe_margins(root.get_viewport())
	var g := 16.0
	top_left.position = Vector2(m.x + g, m.y + 12.0)
	right_col.offset_left = -right_col.get_combined_minimum_size().x - m.z - g
	right_col.offset_right = -m.z - g
	right_col.offset_top = m.y + 12.0
	top_center.offset_top = m.y + 8.0
	slots_box.offset_bottom = -m.w - 8.0
	slots_box.offset_top = slots_box.offset_bottom - SLOT_PX


const SLOT_PX := 96.0


func _badge_box(bg: Color, border: Color, radius: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_top_left() -> void:
	top_left = HBoxContainer.new()
	top_left.add_theme_constant_override("separation", 10)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_left)
	# portrait with level badge
	var pframe := UIK.panel("FramePanel")
	pframe.custom_minimum_size = Vector2(84, 84)
	pframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_child(pframe)
	var pstack := Control.new()
	pstack.custom_minimum_size = Vector2(72, 72)
	pstack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pframe.add_child(pstack)
	var portrait := UIK.icon_rect("portrait_" + run.hero_id, 72)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pstack.add_child(portrait)
	# level: round dark badge on the portrait's bottom-left corner
	level_badge = _badge_box(Color(0.07, 0.05, 0.03, 0.95), UIK.col("gold", Color(0.95, 0.76, 0.3)), 18)
	level_badge.custom_minimum_size = Vector2(36, 34)
	level_badge.position = Vector2(-14, 50)
	pstack.add_child(level_badge)
	level_label = UIK.label("1", "", 22, Color(1, 0.95, 0.8))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_badge.add_child(level_label)
	# unspent skill points: gold pill on the bottom-right corner, pulses
	sp_badge = _badge_box(UIK.col("gold", Color(0.95, 0.76, 0.3)), Color(0.2, 0.12, 0.04), 12)
	sp_badge.position = Vector2(26, 78)   # under the portrait, clear of the bars
	sp_badge.visible = false
	pstack.add_child(sp_badge)
	sp_label = UIK.label("", "", 18, Color(0.16, 0.09, 0.03))
	sp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sp_badge.add_child(sp_label)

	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 4)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_child(bars)
	var hp_stack := _bar_with_label("HpBar", UIK.col("hp", Color(0.85, 0.23, 0.23)), Vector2(330, 28))
	hp_bar = hp_stack[0]
	hp_label = hp_stack[1]
	bars.add_child(hp_stack[2])
	var mana_stack := _bar_with_label("ManaBar", UIK.col("mana", Color(0.23, 0.48, 0.85)), Vector2(330, 20))
	mana_bar = mana_stack[0]
	mana_label = mana_stack[1]
	bars.add_child(mana_stack[2])
	mana_stack[2].visible = not run.hero.data.get("no_mana", false)
	xp_bar = UIK.bar("XpBar", UIK.col("xp", Color(0.65, 0.36, 0.88)), Vector2(330, 10))
	bars.add_child(xp_bar)
	meter_box = HBoxContainer.new()
	meter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_box.add_theme_constant_override("separation", 8)
	bars.add_child(meter_box)
	meter_label = UIK.label("", "SmallLabel", 18)
	meter_label.add_theme_constant_override("outline_size", 5)
	meter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	meter_bar = UIK.bar("FlowBar", Color(0.45, 0.85, 1.0), Vector2(200, 14))
	meter_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter_box.add_child(meter_label)
	meter_box.add_child(meter_bar)
	var m := run.hero.kit.hud_meter()
	meter_box.visible = not m.is_empty()
	meter_bar.visible = m.get("type", "") in ["flow", "bar"]


func _bar_with_label(variation: String, color: Color, sz: Vector2) -> Array:
	var holder := Control.new()
	holder.custom_minimum_size = sz
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := UIK.bar(variation, color, sz)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(b)
	var l := UIK.label("", "SmallLabel", int(sz.y * 0.62) + 2)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	holder.add_child(l)
	return [b, l, holder]


func _build_top_center() -> void:
	top_center = VBoxContainer.new()
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_center.add_theme_constant_override("separation", 6)
	top_center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_center.anchor_left = 0.5
	top_center.anchor_right = 0.5
	top_center.offset_left = -200
	top_center.offset_right = 200
	top_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(top_center)
	wave_label = UIK.label("Wave 1 / 20", "TitleLabel", 30)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.add_theme_constant_override("outline_size", 8)
	wave_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	top_center.add_child(wave_label)
	_build_preview()
	# prep row (Shop / countdown / Fight!) lives in the right column, under gold & lives
	prep_box = HBoxContainer.new()
	prep_box.alignment = BoxContainer.ALIGNMENT_END
	prep_box.add_theme_constant_override("separation", 10)
	prep_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_btn = UIK.icon_button("Shop", "shop", "PrimaryButton", Vector2(150, 76), 48.0, 22)
	shop_btn.pressed.connect(toggle_shop)
	prep_box.add_child(shop_btn)
	prep_label = UIK.label("", "", 22, Color(1, 0.95, 0.85))
	prep_label.add_theme_constant_override("outline_size", 6)
	prep_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prep_label.custom_minimum_size = Vector2(112, 0)
	prep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prep_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prep_box.add_child(prep_label)
	fight_btn = UIK.button("Fight!", "PrimaryButton", Vector2(140, 76))
	fight_btn.pressed.connect(func(): run.skip_prep())
	prep_box.add_child(fight_btn)
	boss_box = VBoxContainer.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.add_theme_constant_override("separation", 2)
	top_center.add_child(boss_box)
	boss_label = UIK.label("", "", 20, UIK.col("danger", Color(1, 0.3, 0.3)).lightened(0.3))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_constant_override("outline_size", 6)
	boss_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	boss_box.add_child(boss_label)
	boss_bar = UIK.bar("BossBar", UIK.col("danger", Color(0.9, 0.2, 0.2)), Vector2(380, 22))
	boss_box.add_child(boss_bar)
	boss_box.visible = false


## Camp preview of the next wave: its name, twist and captain, so the shop visit is a decision.
func _build_preview() -> void:
	preview_box = UIK.panel("DarkPanel")
	preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.035, 0.82)
	sb.border_color = UIK.col("frame", Color(0.54, 0.42, 0.23))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	preview_box.add_theme_stylebox_override("panel", sb)
	top_center.add_child(preview_box)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	preview_box.add_child(v)
	preview_name = UIK.label("", "", 24, UIK.col("gold", Color.GOLD))
	preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(preview_name)
	preview_rule = UIK.label("", "", 19, Color(1, 1, 1))
	preview_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(preview_rule)
	preview_desc = UIK.label("", "", 19, Color(1, 0.93, 0.82))
	preview_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_desc.custom_minimum_size = Vector2(372, 0)
	v.add_child(preview_desc)
	preview_box.visible = false


func _refresh_preview() -> void:
	if _preview_wave == run.wave:
		return
	_preview_wave = run.wave
	var info := run.wave_info()
	preview_name.text = "Next: " + String(info.get("name", ""))
	var bits := []
	var rule: String = info.get("rule", "")
	if rule != "":
		bits.append(String(DB.WAVE_RULES[rule]["name"]))
		preview_rule.add_theme_color_override("font_color", DB.WAVE_RULES[rule]["color"])
	else:
		preview_rule.add_theme_color_override("font_color", Color(1, 0.85, 0.55))
	var cap: String = info.get("captain", "")
	if cap != "":
		bits.append("Captain: " + String(DB.CAPTAIN_NAMES.get(cap, cap)))
	elif run.boss_kind() != "":
		bits.append("Boss wave")
	preview_rule.text = "  ·  ".join(bits)
	preview_rule.visible = not bits.is_empty()
	preview_desc.text = String(info.get("desc", ""))


func _build_top_right() -> void:
	right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 8)
	right_col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_col.z_index = 2
	root.add_child(right_col)
	top_right = HBoxContainer.new()
	top_right.add_theme_constant_override("separation", 10)
	top_right.alignment = BoxContainer.ALIGNMENT_END
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_col.add_child(top_right)
	right_col.add_child(prep_box)
	var info := UIK.panel("DarkPanel")
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# near-opaque so world numbers / bars behind never muddle gold & lives
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.07, 0.05, 0.035, 0.93)
	isb.border_color = UIK.col("frame", Color(0.54, 0.42, 0.23))
	isb.set_border_width_all(2)
	isb.set_corner_radius_all(8)
	isb.content_margin_left = 12
	isb.content_margin_right = 12
	isb.content_margin_top = 8
	isb.content_margin_bottom = 8
	info.add_theme_stylebox_override("panel", isb)
	top_right.add_child(info)
	var ib := HBoxContainer.new()
	ib.add_theme_constant_override("separation", 6)
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(ib)
	ib.add_child(UIK.icon_rect("gold", 34))
	gold_label = UIK.label("0", "", 24, UIK.col("gold", Color.GOLD))
	gold_label.custom_minimum_size = Vector2(70, 0)
	ib.add_child(gold_label)
	ib.add_child(UIK.icon_rect("life", 34))
	lives_label = UIK.label("3", "", 24, Color(1, 0.6, 0.55))
	lives_label.custom_minimum_size = Vector2(28, 0)
	ib.add_child(lives_label)
	# one button for every skill's description (holding a skill button used to show it, and ranked it up by accident)
	info_btn = UIK.button("", "SkillButton", Vector2(96, 96))
	info_btn.icon = UIK.icon("info")
	info_btn.expand_icon = true
	info_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_btn.add_theme_constant_override("icon_max_width", 56)
	info_btn.pressed.connect(func(): skills_info_requested.emit())
	top_right.add_child(info_btn)
	pause_btn = UIK.button("", "SkillButton", Vector2(96, 96))
	pause_btn.icon = UIK.icon("pause")
	pause_btn.expand_icon = true
	pause_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_btn.add_theme_constant_override("icon_max_width", 56)
	pause_btn.pressed.connect(func(): pause_requested.emit())
	top_right.add_child(pause_btn)


func _build_slots() -> void:
	slots_box = HBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 6)
	slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	slots_box.anchor_left = 0.5
	slots_box.anchor_right = 0.5
	# shifted left of centre so the row clears the item / skill ring on the right
	slots_box.offset_left = -360
	slots_box.offset_right = 260
	slots_box.offset_top = -8 - SLOT_PX
	slots_box.offset_bottom = -8
	slots_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(slots_box)
	for i in 6:
		var b := Button.new()
		b.theme_type_variation = "ShopItemButton"
		b.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		b.size = Vector2(SLOT_PX, SLOT_PX)
		b.focus_mode = Control.FOCUS_NONE
		var idx := i
		b.pressed.connect(func(): run.use_item(idx))
		slots_box.add_child(b)
		slot_nodes.append(b)
	# icons + counts for all six slots drawn by one overlay, after the frames, so they batch
	slot_overlay = Control.new()
	slot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot_overlay.draw.connect(_draw_slot_overlay)
	root.add_child(slot_overlay)


func _draw_slot_overlay() -> void:
	if run == null:
		return
	var h := run.hero
	var font := slot_overlay.get_theme_default_font()
	var o := slot_overlay.get_global_rect().position
	var texts := []
	for i in mini(6, h.items.size()):
		var b: Button = slot_nodes[i]
		var r := Rect2(b.get_global_rect().position - o, b.size)
		var it: Dictionary = h.items[i]
		var cool := float(it.get("cd", 0.0)) > 0.0
		slot_overlay.draw_texture_rect(UIK.icon(it["id"]), Rect2(r.get_center() - Vector2(34, 34), Vector2(68, 68)), false, Color(0.55, 0.55, 0.55) if cool else Color(1, 1, 1))
		if DB.ITEMS[it["id"]].get("kind") == "consumable":
			texts.append([r.position + Vector2(SLOT_PX - 40, SLOT_PX - 10), "x%d" % int(it.get("charges", 1))])
	for t in texts:
		slot_overlay.draw_string_outline(font, t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0))
	for t in texts:
		slot_overlay.draw_string(font, t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))


func _build_banner_toasts() -> void:
	banner_box = VBoxContainer.new()
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.set_anchors_preset(Control.PRESET_CENTER)
	banner_box.anchor_top = 0.18
	banner_box.anchor_bottom = 0.18
	banner_box.offset_left = -500
	banner_box.offset_right = 500
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(banner_box)
	banner_label = UIK.label("", "BannerLabel", 54, UIK.col("gold", Color.GOLD))
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_constant_override("outline_size", 10)
	banner_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	banner_box.add_child(banner_label)
	banner_sub = UIK.label("", "", 24, Color(1, 0.93, 0.82))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.add_theme_constant_override("outline_size", 7)
	banner_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner_box.add_child(banner_sub)
	banner_box.modulate.a = 0.0
	banner_box.visible = false
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.set_anchors_preset(Control.PRESET_CENTER)
	toast_box.anchor_top = 0.36
	toast_box.anchor_bottom = 0.36
	toast_box.offset_left = -400
	toast_box.offset_right = 400
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(toast_box)


func show_banner(text: String, sub: String) -> void:
	banner_label.text = text
	banner_sub.text = sub
	if banner_tween:
		banner_tween.kill()
	banner_box.modulate.a = 0.0
	banner_box.scale = Vector2.ONE
	banner_box.visible = true
	banner_tween = create_tween()
	banner_tween.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	banner_tween.tween_interval(1.8)
	banner_tween.tween_property(banner_box, "modulate:a", 0.0, 0.6)
	banner_tween.tween_callback(func(): banner_box.visible = false)   # out of the draw list once faded


func show_toast(text: String, color: Color) -> void:
	for c in toast_box.get_children():
		if c is Label and c.text == text:
			return
	while toast_box.get_child_count() >= 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var l := UIK.label(text, "", 22, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	toast_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _process(_delta: float) -> void:
	if run == null:
		return
	var h := run.hero
	hp_bar.value = h.hp / maxf(1.0, h.max_hp)
	hp_label.text = "%d / %d%s" % [int(ceil(h.hp)), int(ceil(h.max_hp)), ("  +%d" % int(h.shield)) if h.shield > 0.0 else ""]
	mana_bar.value = h.mana / maxf(1.0, h.max_mana)
	mana_label.text = "%d / %d" % [int(h.mana), int(h.max_mana)]
	xp_bar.value = h.xp_frac()
	level_label.text = str(h.level)
	var sp_on := h.skill_points > 0 and h.any_rank_up()
	sp_badge.visible = sp_on
	if sp_on:
		sp_label.text = "+%d skill" % h.skill_points
		sp_badge.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 160.0)
	var m := h.kit.hud_meter()
	match m.get("type", ""):
		"flow":
			meter_label.text = "Flow %d" % int(m["value"])
			meter_bar.value = float(m["value"]) / float(m["max"])
		"brood":
			meter_label.text = "Brood %d / %d" % [int(m["count"]), int(m["cap"])]
		"bar":
			meter_label.text = String(m.get("label", ""))
			meter_bar.value = float(m["value"]) / maxf(0.001, float(m["max"]))
			meter_bar.self_modulate = m.get("color", Color.WHITE)
		"count":
			meter_label.text = String(m.get("label", ""))
	if run.gold != _last_gold:
		_last_gold = run.gold
		gold_label.text = str(run.gold)
	lives_label.text = "∞" if run.mode in ["practice", "training"] else str(maxi(0, run.lives))
	var ph := run.phase
	if ph == "prep":
		wave_label.text = _wave_text()
		prep_box.visible = true
		prep_label.text = "Next wave\n%d s" % int(ceil(run.prep_t))
		if run.boss_kind() != "":
			prep_label.text = "BOSS wave\n%d s" % int(ceil(run.prep_t))
		shop_btn.visible = true
		_refresh_preview()
		preview_box.visible = shop == null and run.tutorial == null
		# Training: the coach decides when to fight, so no countdown or Fight! button
		prep_label.visible = run.tutorial == null
		fight_btn.visible = run.tutorial == null
	else:
		prep_box.visible = false
		preview_box.visible = false
		if ph == "wave" or ph == "clear":
			wave_label.text = "%s  ·  %d left" % [_wave_text(), run.enemies.size() + run.spawn_queue.size()]
	var bh := run.boss_hp()
	boss_box.visible = run.boss_units.size() > 0 and bh.y > 0.0
	if boss_box.visible:
		boss_bar.value = bh.x / bh.y
		boss_label.text = "%s  %d%%" % [run.boss_title, int(ceil(100.0 * bh.x / bh.y))]
	elif run.captain != null and run.captain.alive and ph == "wave":
		boss_box.visible = true
		boss_bar.value = run.captain.hp / maxf(1.0, run.captain.max_hp)
		boss_label.text = "%s  %d%%" % [run.captain.display_name, int(ceil(100.0 * boss_bar.value))]
	# inventory (icons are drawn by slot_overlay)
	for i in 6:
		var b: Button = slot_nodes[i]
		if i < h.items.size():
			b.tooltip_text = DB.ITEMS[h.items[i]["id"]]["name"]
			b.modulate = Color(1, 1, 1)
		else:
			b.tooltip_text = ""
			b.modulate = Color(1, 1, 1, 0.55)
	slot_overlay.queue_redraw()
	# auto-open the shop when walking up to it
	if ph == "prep" and h.in_camp and not Game.autoplay:
		var d := Vector2(h.pos.x - DB.SHOP_POS.x, h.pos.z - DB.SHOP_POS.z).length()
		if d < 3.0 and Game.settings.get("auto_shop", true) and shop == null and not _near_shop_dismissed:
			open_shop()
			_near_shop_dismissed = true
		elif d > 4.5:
			_near_shop_dismissed = false
	if ph != "prep" and shop != null:
		close_shop()
	controls.enabled = shop == null


## "Wave 7 / 20", or "Wave 23 · Endless" past the Warden, or "Training".
func _wave_text() -> String:
	if run.mode == "training":
		return "Training"
	if run.mode == "endless":
		return "Wave %d · Endless" % run.wave
	return "Wave %d / %d" % [run.wave, DB.TOTAL_WAVES]


func toggle_shop() -> void:
	if shop != null:
		close_shop()
	else:
		open_shop()


func open_shop() -> void:
	if shop != null:
		return
	if not run.shop_open_allowed():
		show_toast("The shop opens between waves", UIK.col("dim", Color.GRAY))
		return
	shop = load("res://scripts/ui/shop_ui.gd").new()
	shop.z_index = 10   # above the HUD's right column
	root.add_child(shop)
	shop.setup(run, self)
	Game.paused_by_shop = true
	controls._release_all()


func close_shop() -> void:
	if shop != null:
		shop.queue_free()
		shop = null
	Game.paused_by_shop = false
