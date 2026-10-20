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
static func title_screen(on_play: Callable, on_heroes := Callable(), on_continue := Callable(), on_records := Callable(), snap := {}) -> Control:
	var root := _base()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# darken the right side only: the bonfire scene stays bright on the left
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 0.7])
	g.colors = PackedColorArray([Color(0.03, 0.02, 0.01, 0.7), Color(0.03, 0.02, 0.01, 0.45), Color(0.03, 0.02, 0.01, 0.0)])
	gt.gradient = g
	gt.fill_from = Vector2(1, 0.5)
	gt.fill_to = Vector2(0, 0.5)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var center := CenterContainer.new()
	center.anchor_left = 0.54
	center.anchor_right = 1.0
	center.anchor_top = 0.0
	center.anchor_bottom = 1.0
	center.offset_right = -UIK.safe_margins((Engine.get_main_loop() as SceneTree).root).z
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
	if on_continue.is_valid() and not snap.is_empty():
		# the run saved in camp: hero, mode and wave on the button
		var cont := UIK.button("Continue", "PrimaryButton", Vector2(360, 96))
		cont.add_theme_font_size_override("font_size", 34)
		cont.pressed.connect(on_continue)
		cont.name = "ContinueButton"
		var cc := CenterContainer.new()
		cc.add_child(cont)
		v.add_child(cc)
		var what := _outlined(UIK.label("%s  ·  wave %d  ·  %s" % [DB.HEROES[String(snap["hero"])]["name"], int(snap.get("wave", 1)),
			Modes.label(snap.get("cfg", {}))], "SmallLabel", 18, UIK.col("dim", Color(0.75, 0.7, 0.62))), 6)
		what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(what)
	var play := UIK.button("Play" if snap.is_empty() else "New Run", "" if not snap.is_empty() else "PrimaryButton", Vector2(360, 104 if snap.is_empty() else 76))
	play.add_theme_font_size_override("font_size", 40 if snap.is_empty() else 30)
	play.pressed.connect(on_play)
	play.name = "PlayButton"
	var pc := CenterContainer.new()
	pc.add_child(play)
	v.add_child(pc)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 12)
	if on_heroes.is_valid():
		var heroes := UIK.button("Heroes", "", Vector2(174, 72))
		heroes.add_theme_font_size_override("font_size", 28)
		heroes.pressed.connect(on_heroes)
		heroes.name = "HeroesButton"
		row2.add_child(heroes)
	if on_records.is_valid():
		var rec := UIK.button("Records", "", Vector2(174, 72))
		rec.add_theme_font_size_override("font_size", 28)
		rec.pressed.connect(on_records)
		rec.name = "RecordsButton"
		row2.add_child(rec)
	v.add_child(row2)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.add_child(_toggle("Sound", "sound"))
	row.add_child(_toggle("Music", "music"))
	row.add_child(_toggle("Screen shake", "shake"))
	if not OS.has_feature("mobile"):
		var q := UIK.button("Quit", "", Vector2(140, 64))
		q.pressed.connect(func(): Game.quit_game())
		row.add_child(q)
	v.add_child(row)
	var tip := _outlined(UIK.label("Survive 20 waves in the Pit. Shop between waves. Unlock heroes by playing.", "SmallLabel", 20, UIK.col("dim", Color(0.75, 0.7, 0.62))), 6)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tip)
	if not Game.prev_crash.is_empty():
		v.add_child(_crash_notice())
	return root


## Shown after a session that closed unexpectedly: copies the crash trail so the player can paste it to us.
static func _crash_notice() -> Control:
	var p := UIK.panel()
	p.name = "CrashNotice"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var l := UIK.label("The last game closed unexpectedly.", "SmallLabel", 20, UIK.col("text", Color(0.95, 0.92, 0.85)))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var copy := UIK.button("Copy report", "", Vector2(200, 64))
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(Game.crash_report_text())
		copy.text = "Copied")
	h.add_child(copy)
	var dismiss := UIK.button("Dismiss", "", Vector2(160, 64))
	dismiss.pressed.connect(func():
		Game.prev_crash = {}
		p.queue_free())
	h.add_child(dismiss)
	var c := CenterContainer.new()
	c.add_child(p)
	return c


# ---------------------------------------------------------------- hero select
static func hero_select(on_start: Callable, on_back: Callable, cfg := {}) -> Control:
	var any_hero: bool = cfg.get("mode", "classic") == "practice"
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
	if not cfg.is_empty():
		title.text = "Choose your hero  ·  " + Modes.label(cfg)
		title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var start := UIK.button("Begin Run", "PrimaryButton", Vector2(220, 72))
	start.add_theme_font_size_override("font_size", 28)
	head.add_child(start)
	# roster grid on the left (scrolls once the roster outgrows it), details of the selected hero on the right
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(5 * TILE_W + 4 * 8 + 12, 0)
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var detail_holder := MarginContainer.new()
	detail_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_holder)
	var state := {"sel": DB.HERO_ORDER[0], "tiles": {}}
	var can := func(id: String) -> bool: return any_hero or Profile.is_unlocked(id)
	var refresh := func():
		for id in state["tiles"]:
			var tile: Control = state["tiles"][id]
			var on: bool = id == state["sel"]
			var dim := 1.0 if on else 0.66
			if not can.call(id):
				dim *= 0.55
			tile.modulate = Color(dim, dim * 0.96, dim * 0.92)
			(tile.get_meta("ring") as Control).visible = on
		for c in detail_holder.get_children():
			c.queue_free()
		detail_holder.add_child(_hero_detail(state["sel"], can.call(state["sel"])))
		start.disabled = not can.call(state["sel"])
	for id in DB.HERO_ORDER:
		var tile := _hero_tile(id, can.call(id))
		grid.add_child(tile)
		state["tiles"][id] = tile
		var hid: String = id
		var btn: Button = tile.get_meta("button")
		btn.pressed.connect(func():
			if state["sel"] == hid:
				if can.call(hid):
					on_start.call(hid)
				return
			state["sel"] = hid
			Audio.play("click")
			refresh.call())
	start.pressed.connect(func():
		if can.call(state["sel"]):
			on_start.call(state["sel"]))
	refresh.call()
	return root


const TILE_W := 136.0


static func _fit(l: Label) -> Label:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.custom_minimum_size = Vector2(60, 0)
	return l


static func difficulty_name(n: int) -> String:
	return ["Easy", "Easy", "Medium", "Hard"][clampi(n, 0, 3)]


## Small roster tile: portrait, name, playstyle tag. The whole tile is a button.
static func _hero_tile(id: String, open := true) -> Control:
	var d: Dictionary = DB.HEROES[id]
	var holder := MarginContainer.new()
	holder.custom_minimum_size = Vector2(TILE_W, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := UIK.panel("FramePanel")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var por := UIK.icon_rect("portrait_" + id, 84)
	por.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(por)
	var n := _fit(_outlined(UIK.label(d["name"], "", 16 if String(d["name"]).length() <= 9 else 14, UIK.col("ember", Color(1, 0.55, 0.25))), 5))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var t := _fit(UIK.label(d.get("tag", "") if open else "Locked", "SmallLabel", 15, UIK.col("gold", Color.GOLD) if open else Color(0.7, 0.66, 0.6)))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	# selection ring: a bright frame drawn over the tile
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UIK.col("gold", Color.GOLD)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	ring.add_theme_stylebox_override("panel", sb)
	holder.add_child(ring)
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.tooltip_text = d["name"]
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		btn.add_theme_stylebox_override(st, empty)
	holder.add_child(btn)
	holder.set_meta("button", btn)
	holder.set_meta("ring", ring)
	return holder


## Details of one hero: who they are, how they play, and their skills.
static func _hero_detail(id: String, open := true) -> Control:
	var d: Dictionary = DB.HEROES[id]
	var card := UIK.panel("FramePanel")
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	top.add_child(UIK.icon_rect("portrait_" + id, 96))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	names.add_child(_fit(_outlined(UIK.label(d["name"], "TitleLabel", 32, UIK.col("ember", Color(1, 0.55, 0.25))), 6)))
	names.add_child(_fit(UIK.label(d["title"], "", 19, UIK.col("text", Color(0.95, 0.9, 0.82)))))
	var stat_names := {"str": "Strength", "agi": "Agility", "int": "Intellect"}
	var role := UIK.label("%s · %s · %s" % [d.get("tag", ""), d["role"], stat_names[d["primary"]]], "SmallLabel", 17, UIK.col("dim", Color(0.75, 0.7, 0.62)))
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.custom_minimum_size = Vector2(120, 0)
	names.add_child(role)
	var diff := UIK.label("Difficulty: %s" % difficulty_name(int(d.get("difficulty", 1))), "SmallLabel", 17, UIK.col("gold", Color.GOLD))
	names.add_child(diff)
	if open:
		names.add_child(_fit(UIK.label("Tap again to start", "SmallLabel", 16, UIK.col("dim", Color(0.75, 0.7, 0.62)))))
	else:
		var pr := Profile.progress(id)
		var lk := UIK.label("Locked: %s (%d / %d)" % [Modes.UNLOCKS.get(id, {}).get("text", ""), pr[0], pr[1]], "SmallLabel", 17, UIK.col("danger", Color(1, 0.45, 0.4)).lightened(0.2))
		lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lk.custom_minimum_size = Vector2(120, 0)
		lk.name = "LockLabel"
		names.add_child(lk)
	var ps := UIK.label(d["playstyle"], "", 17, UIK.col("text", Color(0.95, 0.9, 0.82)))
	ps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ps.add_theme_constant_override("line_spacing", -3)
	ps.custom_minimum_size = Vector2(200, 0)
	v.add_child(ps)
	var skills: Array = d["skills"].duplicate()
	var keys := ["Q", "W", "E", "R"]
	if d.has("beast_skills"):
		skills = [d["skills"][0], d["skills"][1], d["beast_skills"][0], d["beast_skills"][1], d["skills"][2], d["skills"][3]]
		keys = ["Q", "W", "Q·beast", "W·beast", "E", "R"]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for i in skills.size():
		var sid: String = skills[i]
		var sd: Dictionary = DB.SKILLS[sid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(row)
		var sic := UIK.icon_rect(sid, 46 if skills.size() <= 4 else 40)
		sic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(sic)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tv)
		tv.add_child(UIK.label("%s  %s" % [keys[i], sd["name"]], "", 17, UIK.col("gold", Color.GOLD)))
		var dl := UIK.label(String(sd["desc"]), "SmallLabel", 15 if skills.size() <= 4 else 14, UIK.col("text", Color(0.9, 0.86, 0.8)))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_constant_override("line_spacing", -3)
		dl.custom_minimum_size = Vector2(150, 0)
		tv.add_child(dl)
	return card


# ---------------------------------------------------------------- end screen
static func end_screen(run: Run, on_again: Callable, on_title: Callable) -> Control:
	var root := _base()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var win := run.result == "victory" or run.result == "training"
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
	if run.result == "training":
		return _training_end(root, v, on_again, on_title)
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
	var sub_text: String = ("%s survived all 20 waves." if win else "%s fell in the Pit.") % hd["name"]
	if run.mode == "endless":
		sub_text = "%s held out until wave %d." % [hd["name"], run.max_wave_reached]
	var sub := UIK.label(sub_text, "", 22, UIK.col("text", Color(0.95, 0.9, 0.82)))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_run_summary(run))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	v.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	body.add_child(left)
	var rows := [
		["Hero", hd["name"]],
		["Wave reached", ("%d" % run.max_wave_reached) if run.mode == "endless" else ("%d / %d" % [run.max_wave_reached, DB.TOTAL_WAVES])],
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
	again.name = "AgainButton"
	again.add_theme_font_size_override("font_size", 28)
	again.pressed.connect(on_again)
	btns.add_child(again)
	var tt := UIK.button("Title", "", Vector2(200, 88))
	tt.pressed.connect(on_title)
	btns.add_child(tt)
	return root


## End of Training: what's next instead of run stats.
static func _training_end(root: Control, v: VBoxContainer, on_play: Callable, on_title: Callable) -> Control:
	var t := _outlined(UIK.label("Training complete!", "TitleLabel", 64, UIK.col("gold", Color(1.0, 0.8, 0.3)).lightened(0.15)), 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var lines := ["You know the basics. Now pick a mode and a hero.",
		"Classic is the full 20 waves. Random Hero and the Daily Run let you try heroes you haven't unlocked yet.",
		"Practice gives you any hero, any wave and free gold to learn them."]
	for s in lines:
		var l := UIK.label(s, "", 21, UIK.col("text", Color(0.95, 0.9, 0.82)))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(820, 0)
		v.add_child(l)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	v.add_child(btns)
	var play := UIK.button("Play", "PrimaryButton", Vector2(260, 88))
	play.name = "AgainButton"
	play.add_theme_font_size_override("font_size", 30)
	play.pressed.connect(on_play)
	btns.add_child(play)
	var tt := UIK.button("Title", "", Vector2(200, 88))
	tt.pressed.connect(on_title)
	btns.add_child(tt)
	return root


## Mode, tier, score and anything newly unlocked, under the end screen's headline.
static func _run_summary(run: Run) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var info: Dictionary = run.end_info
	var line := Modes.label(run.cfg)
	if run.cfg.get("counts", false):
		line += "  ·  Score %d" % int(info.get("score", run.score()))
		if info.get("best", false):
			line += "  (new best!)"
	elif run.mode == "practice":
		line += "  ·  not recorded"
	var l := UIK.label(line, "", 21, UIK.col("gold", Color.GOLD))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.name = "SummaryLabel"
	v.add_child(l)
	for u in info.get("unlocks", []):
		var ul := _outlined(UIK.label("Unlocked: %s!" % u, "", 24, UIK.col("ember", Color(1, 0.55, 0.25))), 6)
		ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ul)
	return v


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
	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 12)
	for pair in [["Sound", "sound"], ["Music", "music"]]:
		var tg := _toggle(pair[0], pair[1])
		tg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		audio_row.add_child(tg)
	v.add_child(audio_row)
	v.add_child(_toggle("Screen shake", "shake"))
	v.add_child(_toggle("Open shop when near", "auto_shop"))
	var help := UIK.label("Left thumb: move.  Tap a skill: quick cast.\nDrag from a skill: aim, release to cast;\ndrag back onto it to cancel.  Tap + to rank up.\nThe (i) button shows what every skill does.", "SmallLabel", 19, UIK.col("dim", Color(0.75, 0.7, 0.62)))
	v.add_child(help)
	var q := UIK.button("Quit to Title", "", Vector2(400, 88))
	q.pressed.connect(on_quit)
	v.add_child(q)
	return root


# ---------------------------------------------------------------- skill info
## Every skill of the hero on one card: name, key, rank, cost, cooldown and what it does. Opened by the HUD's info button.
static func skill_info(h: Hero, on_close: Callable) -> Control:
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
	center.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	frame.add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	outer.add_child(head)
	var t := _outlined(UIK.label("%s skills" % DB.HEROES[h.hero_id]["name"], "TitleLabel", 36, UIK.col("gold", Color.GOLD)))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := UIK.button("Close", "PrimaryButton", Vector2(150, 72))
	close.pressed.connect(on_close)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(1000, 520)
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var keys := ["Q", "W", "E", "R"]
	for slot in 4:
		list.add_child(_skill_row(h, slot, keys[slot]))
	# fit the card to the screen (phones are ~720 px tall at base size)
	root.resized.connect(func():
		var s := root.size
		scroll.custom_minimum_size = Vector2(minf(1000.0, s.x - 120.0), minf(560.0, s.y - 200.0)))
	return root


static func _skill_row(h: Hero, slot: int, key: String) -> Control:
	var sid: String = h.skill_ids[slot]
	var sd: Dictionary = DB.SKILLS[sid]
	var r: int = h.ranks[slot]
	var ri := clampi(r - 1, 0, 3)
	var row := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.065, 0.045, 0.97)
	bg.border_color = UIK.col("frame", Color(0.54, 0.42, 0.23))
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(14)
	row.add_theme_stylebox_override("panel", bg)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	row.add_child(hb)
	var ic := UIK.icon_rect(sid, 84)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if r == 0:
		ic.modulate = Color(0.6, 0.6, 0.6)
	hb.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	var name_line := "%s  ·  %s" % [String(sd["name"]), key + (" (ultimate)" if slot == 3 else "")]
	v.add_child(UIK.label(name_line, "", 26, UIK.col("gold", Color.GOLD)))
	var bits := ["Rank %d/%d" % [r, h.max_rank(slot)] if r > 0 else "Not learned yet"]
	var mana: Array = sd.get("mana", [])
	if not mana.is_empty():
		bits.append("%d mana" % int(mana[mini(ri, mana.size() - 1)]))
	var cds: Array = sd.get("cd", [])
	if not cds.is_empty():
		bits.append("%ss cooldown" % String.num(float(cds[mini(ri, cds.size() - 1)]), 1).trim_suffix(".0"))
	if h.can_rank_up(slot):
		bits.append("rank up ready: tap + on its button")
	v.add_child(UIK.label("  ·  ".join(bits), "SmallLabel", 18, UIK.col("dim", Color(0.75, 0.7, 0.62))))
	var d := UIK.label(String(sd.get("desc", "")), "", 20, UIK.col("text", Color(0.95, 0.92, 0.85)))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(600, 0)
	v.add_child(d)
	return row
