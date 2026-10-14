extends Control
## Shop overlay: recommended row, tabs (Basic / Advanced / Consumables), item grid, details, inventory with sell.

var run: Run
var hud: Node
var tab := "basic"
var selected := ""
var selected_slot := -1
var gold_label: Label
var grid: GridContainer
var rec_row: HBoxContainer
var inv_row: HBoxContainer
var tab_buttons := {}
var d_icon: TextureRect
var d_name: Label
var d_desc: Label
var d_recipe: Label
var d_price: Label
var buy_btn: Button
var buy_alt_btn: Button
var sell_btn: Button
var auto_chk: CheckButton
var _last_gold := -1
var _last_items := ""


func setup(r: Run, h: Node) -> void:
	run = r
	hud = h
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var frame := UIK.panel("FramePanel")
	frame.custom_minimum_size = Vector2(1150, 640)
	center.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	frame.add_child(outer)

	# header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	outer.add_child(head)
	head.add_child(UIK.icon_rect("shop", 44))
	var title := UIK.label("Ember Market", "TitleLabel", 32)
	head.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	auto_chk = CheckButton.new()
	auto_chk.text = "Open when near"
	auto_chk.focus_mode = Control.FOCUS_NONE
	auto_chk.button_pressed = Game.settings.get("auto_shop", true)
	auto_chk.toggled.connect(func(v): Game.settings["auto_shop"] = v; Game.save_settings())
	head.add_child(auto_chk)
	head.add_child(UIK.icon_rect("gold", 38))
	gold_label = UIK.label("0", "", 30, UIK.col("gold", Color.GOLD))
	gold_label.custom_minimum_size = Vector2(90, 0)
	head.add_child(gold_label)
	var close := UIK.button("Close", "PrimaryButton", Vector2(150, 64))
	close.pressed.connect(func(): hud.close_shop())
	head.add_child(close)

	# recommended row
	var rec_head := HBoxContainer.new()
	outer.add_child(rec_head)
	rec_head.add_child(UIK.label("Recommended for %s:" % DB.HEROES[run.hero_id]["name"], "SmallLabel", 19, UIK.col("dim", Color(0.7, 0.65, 0.6))))
	rec_row = HBoxContainer.new()
	rec_row.add_theme_constant_override("separation", 8)
	outer.add_child(rec_row)

	# body: tabs+grid | details
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	left.add_child(tabs)
	for t in [["basic", "Basic"], ["advanced", "Advanced"], ["consumable", "Consumables"]]:
		var tb := UIK.button(t[1], "", Vector2(180, 56))
		tb.toggle_mode = true
		var key: String = t[0]
		tb.pressed.connect(func(): _set_tab(key))
		tabs.add_child(tb)
		tab_buttons[key] = tb
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)

	var det := UIK.panel("DarkPanel")
	det.custom_minimum_size = Vector2(380, 0)
	body.add_child(det)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	det.add_child(dv)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 10)
	dv.add_child(dh)
	d_icon = UIK.icon_rect("gold", 72)
	dh.add_child(d_icon)
	d_name = UIK.label("Select an item", "", 24, Color(1, 0.93, 0.8))
	d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(d_name)
	d_desc = UIK.label("", "", 20)
	d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_desc.custom_minimum_size = Vector2(350, 0)
	dv.add_child(d_desc)
	d_recipe = UIK.label("", "SmallLabel", 19, UIK.col("dim", Color(0.75, 0.7, 0.62)))
	d_recipe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_recipe.custom_minimum_size = Vector2(350, 0)
	dv.add_child(d_recipe)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(fill)
	d_price = UIK.label("", "", 24, UIK.col("gold", Color.GOLD))
	dv.add_child(d_price)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	dv.add_child(brow)
	buy_btn = UIK.button("Buy", "PrimaryButton", Vector2(170, 72))
	buy_btn.pressed.connect(func(): _buy(""))
	brow.add_child(buy_btn)
	buy_alt_btn = UIK.button("Buy (+Agi)", "PrimaryButton", Vector2(170, 72))
	buy_alt_btn.pressed.connect(func(): _buy("agi"))
	brow.add_child(buy_alt_btn)
	sell_btn = UIK.button("Sell", "", Vector2(170, 72))
	sell_btn.pressed.connect(_sell)
	brow.add_child(sell_btn)

	# inventory
	outer.add_child(UIK.label("Inventory (tap to sell)", "SmallLabel", 19, UIK.col("dim", Color(0.7, 0.65, 0.6))))
	inv_row = HBoxContainer.new()
	inv_row.add_theme_constant_override("separation", 8)
	outer.add_child(inv_row)
	_set_tab("basic")
	_refresh()


func _set_tab(t: String) -> void:
	tab = t
	for k in tab_buttons:
		tab_buttons[k].button_pressed = k == t
	for c in grid.get_children():
		c.queue_free()
	for id in DB.ITEM_ORDER:
		var d: Dictionary = DB.ITEMS[id]
		if d["kind"] != t:
			continue
		grid.add_child(_item_button(id, Vector2(174, 96), true))
	_refresh()


## Item tile: fixed-size icon on the left (never shrinks), name + price on the right.
func _item_button(id: String, sz: Vector2, show_name: bool, icon_px := 64.0) -> Button:
	var d: Dictionary = DB.ITEMS[id]
	var b := Button.new()
	b.theme_type_variation = "ShopItemButton"
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.tooltip_text = d["name"]
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8
	hb.offset_right = -6
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var ic := UIK.icon_rect(id, icon_px)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	var longest_word := 0
	for w in String(d["name"]).split(" "):
		longest_word = maxi(longest_word, w.length())
	var name_px := 18 if show_name else 17
	if show_name and longest_word >= 10:
		name_px = 15
	elif show_name and longest_word >= 8:
		name_px = 16
	var nm := UIK.label(d["name"], "", name_px, Color(1, 0.95, 0.88))
	if show_name:
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD
		nm.max_lines_visible = 2
	else:
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.clip_text = true
	nm.custom_minimum_size = Vector2(maxf(40.0, sz.x - icon_px - 30.0), 0)
	tv.add_child(nm)
	var pr := UIK.label(str(run.buy_price(id)), "", 18, UIK.col("gold", Color.GOLD))
	tv.add_child(pr)
	b.set_meta("item", id)
	b.set_meta("show_name", show_name)
	b.set_meta("name_label", nm)
	b.set_meta("price_label", pr)
	b.pressed.connect(func(): _select(id))
	return b


func _select(id: String) -> void:
	selected = id
	selected_slot = -1
	Audio.play("click")
	_refresh()


func _select_slot(i: int) -> void:
	selected_slot = i
	selected = run.hero.items[i]["id"] if i < run.hero.items.size() else ""
	_refresh()


func _buy(choice: String) -> void:
	if selected == "":
		return
	var c := choice
	if selected == "sage_circlet" and c == "":
		c = "int"
	var why := run.buy(selected, c)
	if why == "":
		hud.show_toast("Bought %s" % DB.ITEMS[selected]["name"], UIK.col("gold", Color.GOLD))
	_refresh()


func _sell() -> void:
	if selected_slot < 0:
		return
	var nm: String = DB.ITEMS[run.hero.items[selected_slot]["id"]]["name"]
	run.sell(selected_slot)
	hud.show_toast("Sold %s" % nm, UIK.col("gold", Color.GOLD))
	selected_slot = -1
	selected = ""
	_refresh()


func _process(_d: float) -> void:
	var key := str(run.gold) + "|" + str(run.hero.items)
	if key != _last_items:
		_last_items = key
		_refresh()


func _refresh() -> void:
	if gold_label == null:
		return
	gold_label.text = str(run.gold)
	var owned := []
	for it in run.hero.items:
		owned.append(it["id"])
	# grid prices
	for b in grid.get_children():
		if not b.has_meta("item"):
			continue
		var id: String = b.get_meta("item")
		var p := run.buy_price(id)
		(b.get_meta("price_label") as Label).text = str(p)
		var why := run.can_buy(id)
		b.modulate = Color(1, 1, 1) if why == "" else Color(0.6, 0.6, 0.6)
		(b.get_meta("name_label") as Label).add_theme_color_override("font_color", UIK.col("gold", Color.GOLD) if id == selected else Color(1, 0.95, 0.88))
	# recommended: next items of the build not yet owned
	for c in rec_row.get_children():
		c.queue_free()
	var count := 0
	for id in run.build_needs():
		if count >= 6:
			break
		var b := _item_button(id, Vector2(176, 76), false, 56.0)
		b.modulate = Color(1, 1, 1) if run.can_buy(id) == "" else Color(0.65, 0.65, 0.65)
		rec_row.add_child(b)
		count += 1
	# inventory
	for c in inv_row.get_children():
		c.queue_free()
	for i in 6:
		var b2 := Button.new()
		b2.theme_type_variation = "ShopItemButton"
		b2.custom_minimum_size = Vector2(96, 76)
		b2.focus_mode = Control.FOCUS_NONE
		if i < run.hero.items.size():
			var it: Dictionary = run.hero.items[i]
			var ic2 := UIK.icon_rect(it["id"], 60)
			ic2.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			ic2.offset_left = -30
			ic2.offset_right = 30
			ic2.offset_top = -30
			ic2.offset_bottom = 30
			b2.add_child(ic2)
			b2.tooltip_text = DB.ITEMS[it["id"]]["name"]
			if int(it.get("charges", 1)) > 1:
				var cl := UIK.label("x%d" % int(it["charges"]), "", 20)
				cl.add_theme_constant_override("outline_size", 5)
				cl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
				cl.position = Vector2(56, 46)
				b2.add_child(cl)
			var idx := i
			b2.pressed.connect(func(): _select_slot(idx))
			if i == selected_slot:
				b2.modulate = Color(1.2, 1.1, 0.8)
		else:
			b2.disabled = true
			b2.modulate = Color(1, 1, 1, 0.5)
		inv_row.add_child(b2)
	var extra := UIK.label("", "SmallLabel", 19, UIK.col("dim", Color(0.7, 0.65, 0.6)))
	extra.text = "  Tomes: +%d %s   Lives: %d" % [int(run.hero.bonus[run.hero.data["primary"]]), run.hero.data["primary"].to_upper(), run.lives]
	inv_row.add_child(extra)
	# details
	buy_alt_btn.visible = false
	if selected == "":
		d_name.text = "Select an item"
		d_desc.text = "Tap an item to see what it does. Advanced items combine the parts you own automatically."
		d_recipe.text = ""
		d_price.text = ""
		d_icon.texture = UIK.icon("shop")
		buy_btn.visible = false
		sell_btn.visible = false
		return
	var d: Dictionary = DB.ITEMS[selected]
	d_icon.texture = UIK.icon(selected)
	d_name.text = d["name"]
	d_desc.text = d["desc"]
	var rec := ""
	if d.has("from"):
		var parts := []
		var tmp := owned.duplicate()
		for f in d["from"]:
			var have := tmp.find(f)
			if have >= 0:
				tmp.remove_at(have)
			parts.append(("[owned] " if have >= 0 else "") + DB.ITEMS[f]["name"])
		rec = "Recipe: " + " + ".join(parts) + " + %d gold" % int(d["cost"])
	d_recipe.text = rec
	if selected_slot >= 0:
		var it2: Dictionary = run.hero.items[selected_slot]
		var refund := int(DB.item_total_cost(it2["id"]) * 0.5) * int(it2.get("charges", 1))
		d_price.text = "Sell value: %d" % refund
		buy_btn.visible = false
		sell_btn.visible = true
		sell_btn.text = "Sell +%d" % refund
		return
	sell_btn.visible = false
	buy_btn.visible = true
	var price := run.buy_price(selected)
	d_price.text = "Price: %d" % price
	var why2 := run.can_buy(selected)
	buy_btn.disabled = why2 != ""
	buy_btn.text = "Buy" if why2 == "" else why2
	buy_btn.add_theme_font_size_override("font_size", 22 if why2 == "" else 15)
	if selected == "sage_circlet":
		buy_btn.text = "Buy (+Int)" if why2 == "" else why2
		buy_alt_btn.visible = why2 == ""
