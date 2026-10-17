class_name Menus
extends RefCounted
## Builders for the title screen, hero select, end screen and pause menu. Each returns a full-rect Control.


static func _base() -> Control:
	var c := Control.new()
	c.theme = UIK.theme()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


static func _outlined(l: Label, size := 8) -> Label:
	l.add_theme_constant_override("outline_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	return l


static func _toggle(text: String, key: String) -> CheckButton:
	var t := CheckButton.new()
	t.text = text
	t.focus_mode = Control.FOCUS_NONE
	t.custom_minimum_size = Vector2(0, 64)
	t.button_pressed = Game.settings.get(key, true)
	t.toggled.connect(func(v): Game.settings[key] = v; Game.save_settings())
	return t


# ---------------------------------------------------------------- title
static func title_screen(on_play: Callable) -> Control:
	var root := _base()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# darken the left side only: the bonfire scene stays bright on the right
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 0.7])
	g.colors = PackedColorArray([Color(0.03, 0.02, 0.01, 0.7), Color(0.03, 0.02, 0.01, 0.45), Color(0.03, 0.02, 0.01, 0.0)])
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var center := CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_right = 0.46
	center.anchor_top = 0.0
	center.anchor_bottom = 1.0
	center.offset_left = UIK.safe_margins((Engine.get_main_loop() as SceneTree).root).x
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var t := _outlined(UIK.label("EMBERPIT", "TitleLabel", 104, UIK.col("ember", Color(1, 0.5, 0.2))), 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _outlined(UIK.label("Hero Arena Survival", "", 30, UIK.col("text", Color(0.95, 0.92, 0.85))), 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	var play := UIK.button("Play", "PrimaryButton", Vector2(360, 104))
	play.add_theme_font_size_override("font_size", 40)
	play.pressed.connect(on_play)
	play.name = "PlayButton"
	var pc := CenterContainer.new()
	pc.add_child(play)
	v.add_child(pc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.add_child(_toggle("Sound", "sound"))
	row.add_child(_toggle("Screen shake", "shake"))
	if not OS.has_feature("mobile"):
		var q := UIK.button("Quit", "", Vector2(140, 64))
		q.pressed.connect(func(): Game.quit_game())
		row.add_child(q)
	v.add_child(row)
	var tip := _outlined(UIK.label("Survive 20 waves in the Pit. 3 lives. Shop between waves.", "SmallLabel", 20, UIK.col("dim", Color(0.75, 0.7, 0.62))), 6)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tip)
	return root


# ---------------------------------------------------------------- hero select
static func hero_select(on_start: Callable, on_back: Callable) -> Control:
	var root := _base()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.01, 0.55)
	root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := UIK.safe_margins((Engine.get_main_loop() as SceneTree).root)
	margin.add_theme_constant_override("margin_left", int(16 + m.x))
	margin.add_theme_constant_override("margin_right", int(16 + m.z))
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	root.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var back := UIK.button("Back", "", Vector2(140, 64))
	back.pressed.connect(on_back)
	head.add_child(back)
	var title := _outlined(UIK.label("Choose your hero", "TitleLabel", 40, UIK.col("gold", Color.GOLD)))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var start := UIK.button("Begin Run", "PrimaryButton", Vector2(220, 72))
	start.add_theme_font_size_override("font_size", 28)
	head.add_child(start)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cards)
	var state := {"sel": DB.HERO_ORDER[0], "cards": {}}
	var refresh := func():
		for id in state["cards"]:
			var card: Control = state["cards"][id]
			card.modulate = Color(1, 1, 1) if id == state["sel"] else Color(0.62, 0.6, 0.58)
			var mark: Control = card.get_meta("mark")
			mark.visible = id == state["sel"]
	for id in DB.HERO_ORDER:
		var card := _hero_card(id)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(card)
		state["cards"][id] = card
		var hid: String = id
		var btn: Button = card.get_meta("button")
		btn.pressed.connect(func():
			if state["sel"] == hid:
				on_start.call(hid)
				return
			state["sel"] = hid
			Audio.play("click")
			refresh.call())
	start.pressed.connect(func(): on_start.call(state["sel"]))
	refresh.call()
	return root


static func _fit(l: Label) -> Label:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.custom_minimum_size = Vector2(60, 0)
	return l


static func _hero_card(id: String) -> Control:
	var d: Dictionary = DB.HEROES[id]
	var card := UIK.panel("FramePanel")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(UIK.icon_rect("portrait_" + id, 104))
	var names := VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	names.add_child(_fit(_outlined(UIK.label(d["name"], "TitleLabel", 32, UIK.col("ember", Color(1, 0.55, 0.25))), 6)))
	names.add_child(_fit(UIK.label(d["title"], "", 20, UIK.col("text", Color(0.95, 0.9, 0.82)))))
	var stat_names := {"str": "Strength", "agi": "Agility", "int": "Intellect"}
	var role := UIK.label("%s · %s" % [d["role"], stat_names[d["primary"]]], "SmallLabel", 18, UIK.col("dim", Color(0.75, 0.7, 0.62)))
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.custom_minimum_size = Vector2(120, 0)
	names.add_child(role)
	var mark := _fit(UIK.label("Selected - tap again to start", "SmallLabel", 18, UIK.col("gold", Color.GOLD)))
	names.add_child(mark)
	card.set_meta("mark", mark)
	var ps := UIK.label(d["playstyle"], "", 17, UIK.col("text", Color(0.95, 0.9, 0.82)))
	ps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ps.add_theme_constant_override("line_spacing", -3)
	ps.custom_minimum_size = Vector2(200, 0)
	v.add_child(ps)
	var keys := ["Q", "W", "E", "R"]
	for i in 4:
		var sid: String = d["skills"][i]
		var sd: Dictionary = DB.SKILLS[sid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(row)
		var sic := UIK.icon_rect(sid, 48)
		sic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(sic)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tv)
		tv.add_child(UIK.label("%s  %s" % [keys[i], sd["name"]], "", 18, UIK.col("gold", Color.GOLD)))
		var desc := String(sd["desc"])
		var dl := UIK.label(desc, "SmallLabel", 16, UIK.col("text", Color(0.9, 0.86, 0.8)))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_constant_override("line_spacing", -3)
		dl.custom_minimum_size = Vector2(150, 0)
		tv.add_child(dl)
	# whole card is a button
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		btn.add_theme_stylebox_override(s, empty)
	card.set_meta("button", btn)
	# overlay the button on the card
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(btn)
	holder.set_meta("button", btn)
	holder.set_meta("mark", mark)
	return holder


# ---------------------------------------------------------------- end screen
static func end_screen(run: Run, on_again: Callable, on_title: Callable) -> Control:
	var root := _base()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var win := run.result == "victory"
	shade.color = Color(0.06, 0.03, 0.0, 0.42) if win else Color(0.02, 0.01, 0.01, 0.6)
	root.add_child(shade)
	if win:
		root.add_child(_ember_rain())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var frame := UIK.panel("FramePanel")
	frame.custom_minimum_size = Vector2(900, 0)
	center.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	frame.add_child(v)
	var gold := UIK.col("gold", Color(1.0, 0.8, 0.3))
	var t := _outlined(UIK.label("Victory!" if win else "Defeat", "TitleLabel", 76 if win else 64, gold.lightened(0.15) if win else UIK.col("danger", Color(0.9, 0.3, 0.3))), 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if win:
		t.add_theme_color_override("font_shadow_color", Color(1.0, 0.45, 0.1, 0.7))
		t.add_theme_constant_override("shadow_offset_x", 0)
		t.add_theme_constant_override("shadow_offset_y", 0)
		t.add_theme_constant_override("shadow_outline_size", 22)
	v.add_child(t)
	var hd: Dictionary = DB.HEROES[run.hero_id]
	if win:
		var champ := _outlined(UIK.label("Champion of the Pit", "TitleLabel", 34, UIK.col("ember", Color(1, 0.55, 0.25))), 8)
		champ.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(champ)
	var sub := UIK.label(("%s survived all 20 waves." if win else "%s fell in the Pit.") % hd["name"], "", 22, UIK.col("text", Color(0.95, 0.9, 0.82)))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	v.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	body.add_child(left)
	var rows := [
		["Hero", hd["name"]],
		["Wave reached", "%d / %d" % [run.max_wave_reached, DB.TOTAL_WAVES]],
		["Level", str(run.hero.level)],
		["Kills", str(run.stats["kills"])],
		["Gold earned", str(run.stats["gold_earned"])],
		["Deaths", str(run.stats["deaths"])],
		["Time", UIK.fmt_time(run.run_time)],
	]
	for r in rows:
		var h := HBoxContainer.new()
		var a := UIK.label(r[0], "", 21, UIK.col("dim", Color(0.75, 0.7, 0.62)))
		a.custom_minimum_size = Vector2(190, 0)
		h.add_child(a)
		h.add_child(UIK.label(r[1], "", 21, UIK.col("text", Color(0.95, 0.9, 0.82))))
		left.add_child(h)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(UIK.label("Damage dealt", "", 21, UIK.col("gold", Color.GOLD)))
	var db: Dictionary = run.stats["damage_by"]
	var keys := db.keys()
	keys.sort_custom(func(x, y): return db[x] > db[y])
	var total := 0.0
	for k in keys:
		total += db[k]
	for i in mini(7, keys.size()):
		var k: String = keys[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var nl := UIK.label(k, "SmallLabel", 19, UIK.col("text", Color(0.95, 0.9, 0.82)))
		nl.custom_minimum_size = Vector2(170, 0)
		row.add_child(nl)
		var b := UIK.bar("XpBar", UIK.col("ember", Color(1, 0.5, 0.2)), Vector2(200, 16))
		b.value = db[k] / maxf(1.0, total)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		row.add_child(UIK.label(_short(db[k]), "SmallLabel", 19, UIK.col("dim", Color(0.75, 0.7, 0.62))))
		right.add_child(row)
	if keys.is_empty():
		right.add_child(UIK.label("-", "SmallLabel", 17))
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	v.add_child(btns)
	var again := UIK.button("Play Again", "PrimaryButton", Vector2(260, 88))
	again.add_theme_font_size_override("font_size", 28)
	again.pressed.connect(on_again)
	btns.add_child(again)
	var tt := UIK.button("Title", "", Vector2(200, 88))
	tt.pressed.connect(on_title)
	btns.add_child(tt)
	return root


## Rising embers across the whole screen (victory).
static func _ember_rain() -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := CPUParticles2D.new()
	p.amount = 90
	p.lifetime = 4.0
	p.preprocess = 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700, 10)
	p.position = Vector2(640, 760)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -20)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	g.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	p.color_ramp = g
	holder.add_child(p)
	holder.resized.connect(func():
		p.position = Vector2(holder.size.x * 0.5, holder.size.y + 40.0)
		p.emission_rect_extents = Vector2(holder.size.x * 0.55, 10))
	return holder


static func _short(v: float) -> String:
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return str(int(v))


# ---------------------------------------------------------------- pause
static func pause_menu(on_resume: Callable, on_quit: Callable) -> Control:
	var root := _base()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var frame := UIK.panel("FramePanel")
	frame.custom_minimum_size = Vector2(460, 0)
	center.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	frame.add_child(v)
	var t := _outlined(UIK.label("Paused", "TitleLabel", 52, UIK.col("gold", Color.GOLD)))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var r := UIK.button("Resume", "PrimaryButton", Vector2(400, 96))
	r.add_theme_font_size_override("font_size", 30)
	r.pressed.connect(on_resume)
	v.add_child(r)
	v.add_child(_toggle("Sound", "sound"))
	v.add_child(_toggle("Screen shake", "shake"))
	v.add_child(_toggle("Open shop when near", "auto_shop"))
	var help := UIK.label("Left thumb: move.  Tap a skill: quick cast.\nDrag from a skill: aim, release to cast;\ndrag back onto it to cancel.  Tap + to rank up.", "SmallLabel", 19, UIK.col("dim", Color(0.75, 0.7, 0.62)))
	v.add_child(help)
	var q := UIK.button("Quit to Title", "", Vector2(400, 88))
	q.pressed.connect(on_quit)
	v.add_child(q)
	return root
