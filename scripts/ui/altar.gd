class_name AltarUI
extends RefCounted
## The Altar of Souls: permanent upgrades bought with the Souls every run pays (scripts/meta.gd ALTAR).


static func create(on_back: Callable) -> Control:
	var root := Menus._base()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.01, 0.66)
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
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var back := UIK.button("Back", "", Vector2(140, 64))
	back.pressed.connect(on_back)
	head.add_child(back)
	var title := Menus._outlined(UIK.label("Altar of Souls", "TitleLabel", 40, UIK.col("gold", Color.GOLD)))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var purse := Menus._outlined(UIK.label("", "TitleLabel", 30, PlayMenu.SOUL_COL), 6)
	purse.name = "SoulsLabel"
	purse.custom_minimum_size = Vector2(140, 0)
	purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(purse)
	var hint := UIK.label("Every run pays Souls: more for waves, depths, bosses, harder tiers and Heat. Upgrades are kept forever and work in every mode.",
		"SmallLabel", 17, UIK.col("dim", Color(0.75, 0.7, 0.62)))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.name = "AltarScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var st := {}
	st["fill"] = func():
		purse.text = L.f("%d Souls", [Meta.souls()])
		for c in grid.get_children():
			grid.remove_child(c)
			c.queue_free()
		for id in Meta.ALTAR_ORDER:
			grid.add_child(_card(id, st["fill"]))
		PlayMenu._swipeable(grid)
	st["fill"].call()
	return root


static func _card(id: String, refill: Callable) -> Control:
	var d: Dictionary = Meta.ALTAR[id]
	var r := Meta.rank(id)
	var mx := int(d["max"])
	var cost := Meta.next_cost(id)
	var card := UIK.panel("FramePanel")
	card.name = "Altar_" + id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var ic := UIK.icon_rect(String(d["icon"]), 64)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(Menus._fit(Menus._outlined(UIK.label(L.t(d["name"]), "", 22, UIK.col("ember", Color(1, 0.55, 0.25))), 4)))
	var pips := ""
	for i in mx:
		pips += "●" if i < r else "○"
	var pl := UIK.label(pips, "", 18, UIK.col("gold", Color.GOLD))
	pl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tv.add_child(pl)
	var dl := UIK.label(L.t(d["desc"]), "SmallLabel", 16, UIK.col("text", Color(0.95, 0.9, 0.82)))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(150, 44)
	tv.add_child(dl)
	var can := cost >= 0 and Meta.souls() >= cost
	var b := UIK.button(L.t("Maxed") if cost < 0 else L.f("%d Souls", [cost]), "PrimaryButton" if can else "", Vector2(0, 52))
	b.name = "Buy_" + id
	b.disabled = not can
	b.pressed.connect(func():
		if Meta.buy(id):
			Audio.play("level_up")
			refill.call_deferred())   # deferred: this button is freed by the rebuild
	tv.add_child(b)
	return card
