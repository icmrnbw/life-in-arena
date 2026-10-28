class_name PlayMenu
extends RefCounted
## The Play screen: pick a mode (Classic, Random Hero, Endless, Delve, Daily Run, Practice, Training), a difficulty
## tier and, for the arena modes, an arena (Maps), then either choose a hero or start straight away. Also the Records screen and the first-run Training offer.


## on_choose(cfg): go to hero select with these run settings. on_launch(hero_id, wave, cfg): start the run now.
static func create(on_choose: Callable, on_launch: Callable, on_back: Callable, first_mode := "") -> Control:
	var root := Menus._base()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.01, 0.6)
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
	var title := Menus._outlined(UIK.label("Choose a mode", "TitleLabel", 40, UIK.col("gold", Color.GOLD)))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var go := UIK.button("Choose Hero", "PrimaryButton", Vector2(240, 72))
	go.name = "GoButton"
	go.add_theme_font_size_override("font_size", 28)
	head.add_child(go)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(380, 0)
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var detail_holder := MarginContainer.new()
	detail_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_holder)
	var tier: String = Profile.d().get("last_tier", "hard")
	if not Profile.tier_unlocked(tier):
		tier = "hard"
	var start_mode := first_mode if Modes.MODES.has(first_mode) else ("training" if not Profile.d().get("training_done", false) and int(Profile.d()["totals"]["runs"]) == 0 else "classic")
	var last_map: String = Profile.d().get("last_map", "pit")
	var st := {"mode": start_mode, "tier": tier, "wave": 1, "buttons": {}, "map": last_map if Maps.ORDER.has(last_map) else "pit"}
	# the refresh lambda lives in st so the tier buttons it builds can call it again
	st["refresh"] = func():
		for id in st["buttons"]:
			var b: Button = st["buttons"][id]
			b.modulate = Color(1, 1, 1) if id == st["mode"] else Color(0.7, 0.67, 0.63)
			(b.get_meta("ring") as Control).visible = id == st["mode"]
		go.text = "Choose Hero" if st["mode"] in ["classic", "endless", "practice", "delve"] else "Start"
		for c in detail_holder.get_children():
			c.queue_free()
		detail_holder.add_child(_mode_detail(st, st["refresh"]))
	for id in Modes.MODE_ORDER:
		var b := _mode_button(id)
		list.add_child(b)
		st["buttons"][id] = b
		var mid: String = id
		b.pressed.connect(func():
			st["mode"] = mid
			st["refresh"].call())
	go.pressed.connect(func(): _start(st, on_choose, on_launch))
	st["refresh"].call()
	return root


static func _start(st: Dictionary, on_choose: Callable, on_launch: Callable) -> void:
	var mode: String = st["mode"]
	if mode in MAP_MODES:
		Profile.d()["last_map"] = st["map"]
	match mode:
		"classic", "endless":
			on_choose.call(Modes.config(mode, st["tier"], {"map": st["map"]}))
		"delve":
			on_choose.call(Modes.config(mode, st["tier"]))
		"practice":
			on_choose.call(Modes.config(mode, st["tier"], {"start_wave": st["wave"], "map": st["map"]}))
		"random":
			on_launch.call(Modes.random_hero(), 1, Modes.config("random", st["tier"], {"map": st["map"]}))
		"daily":
			var dd := Modes.daily(Modes.today())
			on_launch.call(dd["hero"], 1, Modes.config("daily", "hard", {"date": dd["date"]}))
		"training":
			on_launch.call("ashwarden", 1, Modes.config("training"))


static func _mode_button(id: String) -> Button:
	var md: Dictionary = Modes.MODES[id]
	var b := UIK.button("", "", Vector2(360, 82))
	b.name = "Mode_" + id
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 10
	hb.offset_right = -10
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var ic := UIK.icon_rect("portrait_" + Modes.daily(Modes.today())["hero"] if id == "daily" else md["icon"], 60)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	tv.add_child(Menus._outlined(UIK.label(md["name"], "", 24, UIK.col("ember", Color(1, 0.55, 0.25))), 5))
	tv.add_child(UIK.label(_mode_line(id), "SmallLabel", 15, UIK.col("dim", Color(0.75, 0.7, 0.62))))
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UIK.col("gold", Color.GOLD)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	ring.add_theme_stylebox_override("panel", sb)
	b.add_child(ring)
	b.set_meta("ring", ring)
	return b


## One short line under each mode's name: its record or what's special today.
static func _mode_line(id: String) -> String:
	var p := Profile.d()
	match id:
		"classic":
			var best := 0
			for t in p["tier_best"]:
				best = maxi(best, int(p["tier_best"][t]))
			return "Best: wave %d" % best if best > 0 else "20 waves, 4 bosses"
		"random":
			return "Any of %d heroes" % DB.HERO_ORDER.size()
		"endless":
			return "Best: wave %d" % int(p["endless_best"]) if int(p["endless_best"]) > 0 else "No wave limit"
		"delve":
			return "Deepest: depth %d" % int(p.get("delve_best", 0)) if int(p.get("delve_best", 0)) > 0 else "New · explore a dungeon"
		"daily":
			var dd := Modes.daily(Modes.today())
			return "%s · %s" % [DB.HEROES[dd["hero"]]["name"], Modes.DAILY_MODS[dd["mod"]]["name"]]
		"practice":
			return "Free gold, any wave"
		"training":
			return "Done" if p.get("training_done", false) else "Start here"
	return ""


static func _mode_detail(st: Dictionary, refresh: Callable) -> Control:
	var mode: String = st["mode"]
	var md: Dictionary = Modes.MODES[mode]
	var card := UIK.panel("FramePanel")
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	v.add_child(Menus._outlined(UIK.label(md["name"], "TitleLabel", 36, UIK.col("ember", Color(1, 0.55, 0.25))), 6))
	var desc := UIK.label(md["desc"], "", 20, UIK.col("text", Color(0.95, 0.9, 0.82)))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	v.add_child(desc)
	if md.get("tiers", false):
		v.add_child(UIK.label("Difficulty", "", 20, UIK.col("gold", Color.GOLD)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		for t in Modes.TIER_ORDER:
			var td: Dictionary = Modes.TIERS[t]
			var open := Profile.tier_unlocked(t)
			var tb := UIK.button(td["name"] if open else td["name"] + " (locked)", "PrimaryButton" if t == st["tier"] else "", Vector2(150, 64))
			tb.name = "Tier_" + t
			tb.add_theme_color_override("font_color", td["color"] if open else Color(0.55, 0.52, 0.5))
			tb.disabled = not open
			var tid: String = t
			tb.pressed.connect(func():
				st["tier"] = tid
				refresh.call())
			row.add_child(tb)
		var td2: Dictionary = Modes.TIERS[st["tier"]]
		var tl := UIK.label(td2["desc"], "SmallLabel", 18, UIK.col("dim", Color(0.75, 0.7, 0.62)))
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(300, 0)
		v.add_child(tl)
		if not Profile.tier_unlocked("extreme"):
			v.add_child(UIK.label("Extreme unlocks when you clear wave 10 on Hard.", "SmallLabel", 16, UIK.col("dim", Color(0.75, 0.7, 0.62))))
	if mode in MAP_MODES:
		v.add_child(UIK.label("Arena", "", 20, UIK.col("gold", Color.GOLD)))
		var mrow := HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 10)
		v.add_child(mrow)
		for id in Maps.ORDER:
			var mb := UIK.button(Maps.map_name(id), "PrimaryButton" if id == st["map"] else "", Vector2(220, 60))
			mb.name = "Map_" + id
			var mid: String = id
			mb.pressed.connect(func():
				st["map"] = mid
				refresh.call())
			mrow.add_child(mb)
		var ml2 := UIK.label(String(Maps.MAPS[st["map"]]["desc"]), "SmallLabel", 17, UIK.col("dim", Color(0.75, 0.7, 0.62)))
		ml2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ml2.custom_minimum_size = Vector2(300, 0)
		v.add_child(ml2)
	match mode:
		"daily":
			var dd := Modes.daily(Modes.today())
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 14)
			v.add_child(h)
			h.add_child(UIK.icon_rect("portrait_" + dd["hero"], 96))
			var tv := VBoxContainer.new()
			tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(tv)
			var mod: Dictionary = Modes.DAILY_MODS[dd["mod"]]
			tv.add_child(UIK.label("Today: %s" % DB.HEROES[dd["hero"]]["name"], "", 24, UIK.col("gold", Color.GOLD)))
			tv.add_child(UIK.label("Twist: " + String(mod["name"]), "", 20, UIK.col("ember", Color(1, 0.55, 0.25))))
			var ml := UIK.label(mod["desc"], "SmallLabel", 18, UIK.col("text", Color(0.95, 0.9, 0.82)))
			ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ml.custom_minimum_size = Vector2(240, 0)
			tv.add_child(ml)
			var rec := Profile.daily_today()
			if int(rec["runs"]) > 0:
				v.add_child(UIK.label("Your best today: wave %d, score %d (%d tries)" % [int(rec["best_wave"]), int(rec["best_score"]), int(rec["runs"])],
					"SmallLabel", 18, UIK.col("dim", Color(0.75, 0.7, 0.62))))
		"practice":
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			v.add_child(row)
			row.add_child(UIK.label("Start at wave", "", 22, UIK.col("gold", Color.GOLD)))
			var minus := UIK.button("-", "", Vector2(72, 64))
			var wl := UIK.label(str(st["wave"]), "TitleLabel", 30, UIK.col("text", Color(0.95, 0.9, 0.82)))
			wl.custom_minimum_size = Vector2(60, 0)
			wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var plus := UIK.button("+", "", Vector2(72, 64))
			plus.name = "WavePlus"
			minus.pressed.connect(func():
				st["wave"] = maxi(1, int(st["wave"]) - 1)
				wl.text = str(st["wave"]))
			plus.pressed.connect(func():
				st["wave"] = mini(DB.TOTAL_WAVES, int(st["wave"]) + 1)
				wl.text = str(st["wave"]))
			row.add_child(minus)
			row.add_child(wl)
			row.add_child(plus)
			v.add_child(UIK.label("Your hero starts at the level and gold of that wave. Every hero is playable here.", "SmallLabel", 17, UIK.col("dim", Color(0.75, 0.7, 0.62))))
		"endless":
			v.add_child(UIK.label("Bosses return every 5th wave, tougher with each lap past wave 20.", "SmallLabel", 17, UIK.col("dim", Color(0.75, 0.7, 0.62))))
		"delve":
			var dl := UIK.label("Bosses guard depths 3, 6 and 10. Ember wells heal you once, side rooms hide treasure. The camp and shop wait between depths.",
				"SmallLabel", 17, UIK.col("dim", Color(0.75, 0.7, 0.62)))
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dl.custom_minimum_size = Vector2(300, 0)
			v.add_child(dl)
		"training":
			v.add_child(UIK.label("You play the Ashwarden and can't fall. Takes about three minutes.", "SmallLabel", 17, UIK.col("dim", Color(0.75, 0.7, 0.62))))
	return card


## Modes fought in an arena you can pick (Maps.ORDER).
const MAP_MODES := ["classic", "random", "endless", "practice"]


# ---------------------------------------------------------------- first-run offer
## Shown the first time Play is pressed: Training is recommended, Skip goes to the mode list.
static func training_offer(on_train: Callable, on_skip: Callable) -> Control:
	var root := Menus._base()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var frame := UIK.panel("FramePanel")
	frame.custom_minimum_size = Vector2(640, 0)
	center.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	frame.add_child(v)
	var t := Menus._outlined(UIK.label("New to the Pit?", "TitleLabel", 44, UIK.col("gold", Color.GOLD)))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := UIK.label("Training shows you how to move, use skills, shop, fight and dig into a barrel stack. It takes about three minutes, and you can't fall.",
		"", 21, UIK.col("text", Color(0.95, 0.9, 0.82)))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var go := UIK.button("Start Training", "PrimaryButton", Vector2(280, 88))
	go.add_theme_font_size_override("font_size", 28)
	go.pressed.connect(on_train)
	row.add_child(go)
	var skip := UIK.button("Skip", "", Vector2(180, 88))
	skip.pressed.connect(on_skip)
	row.add_child(skip)
	var hint := UIK.label("You can always find it under Play.", "SmallLabel", 17, UIK.col("dim", Color(0.75, 0.7, 0.62)))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	return root


# ---------------------------------------------------------------- records
static func records(on_back: Callable) -> Control:
	var root := Menus._base()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.01, 0.62)
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
	var title := Menus._outlined(UIK.label("Records", "TitleLabel", 40, UIK.col("gold", Color.GOLD)))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(140, 0)
	head.add_child(pad)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var p := Profile.d()
	# left: totals and bests
	var lc := UIK.panel("FramePanel")
	lc.custom_minimum_size = Vector2(400, 0)
	body.add_child(lc)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	lc.add_child(lv)
	var t: Dictionary = p["totals"]
	var rows := [["Runs", str(int(t["runs"]))], ["Victories", str(int(t["wins"]))], ["Waves cleared", str(int(t["waves"]))],
		["Bosses beaten", str(int(t["bosses"]))], ["Enemies slain", str(int(t["kills"]))], ["Time in the Pit", UIK.fmt_time(float(t["time"]))]]
	for tr in Modes.TIER_ORDER:
		rows.append(["Best wave, %s" % Modes.TIERS[tr]["name"], str(int(p["tier_best"].get(tr, 0))) if Profile.tier_unlocked(tr) else "locked"])
	rows.append(["Best wave, Endless", str(int(p["endless_best"]))])
	rows.append(["Deepest Delve", str(int(p.get("delve_best", 0)))])
	var dr := Profile.daily_today()
	rows.append(["Daily Run today", "score %d" % int(dr["best_score"]) if int(dr["runs"]) > 0 else "not played"])
	for r in rows:
		var h := HBoxContainer.new()
		var a := UIK.label(r[0], "", 19, UIK.col("dim", Color(0.75, 0.7, 0.62)))
		a.custom_minimum_size = Vector2(230, 0)
		h.add_child(a)
		h.add_child(UIK.label(r[1], "", 19, UIK.col("text", Color(0.95, 0.9, 0.82))))
		lv.add_child(h)
	# right: heroes, with how to unlock the locked ones
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var hl := VBoxContainer.new()
	hl.add_theme_constant_override("separation", 6)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(hl)
	for id in DB.HERO_ORDER:
		hl.add_child(_hero_record_row(id))
	return root


static func _hero_record_row(id: String) -> Control:
	var row := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.065, 0.045, 0.95)
	bg.border_color = UIK.col("frame", Color(0.54, 0.42, 0.23))
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", bg)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var open := Profile.is_unlocked(id)
	var por := UIK.icon_rect("portrait_" + id, 56)
	if not open:
		por.modulate = Color(0.35, 0.35, 0.35)
	h.add_child(por)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UIK.label(DB.HEROES[id]["name"], "", 21, UIK.col("ember", Color(1, 0.55, 0.25)) if open else Color(0.6, 0.57, 0.53)))
	if open:
		var hr: Dictionary = Profile.d()["heroes"].get(id, {})
		tv.add_child(UIK.label("Runs %d  ·  best wave %d  ·  victories %d" % [int(hr.get("runs", 0)), int(hr.get("best_wave", 0)), int(hr.get("wins", 0))],
			"SmallLabel", 16, UIK.col("text", Color(0.9, 0.86, 0.8))))
	else:
		var pr := Profile.progress(id)
		tv.add_child(UIK.label("Locked: %s  (%d / %d)" % [Modes.UNLOCKS[id]["text"], pr[0], pr[1]], "SmallLabel", 16, UIK.col("dim", Color(0.75, 0.7, 0.62))))
	return row
