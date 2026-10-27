extends Control
## Shop overlay: recommended row, tabs (Basic / Advanced / Consumables / Training), item grid, details, inventory with sell.
## Training = stat upgrades bought rank by rank (DB.UPGRADES), opening from wave 3.

var run: Run
var hud: Node
var tab := "basic"
var selected := ""
var selected_up := ""   # a Training upgrade (DB.UPGRADES id) instead of an item
var selected_slot := -1
var gold_label: Label
var grid: GridContainer
var grid_scroll: ScrollContainer
var rec_row: HBoxContainer
var inv_row: HBoxContainer
var tab_buttons := {}
var d_icon: TextureRect
var d_name: Label
var d_desc: Label
var d_recipe: Label
var d_scroll: ScrollContainer
var d_price: Label
var buy_btn: Button
var buy_alt_btn: Button
var sell_btn: Button
var auto_chk: CheckButton
var _last_gold := -1
const ONLY_COL := {"melee": Color(1.0, 0.62, 0.45), "ranged": Color(0.55, 0.85, 1.0)}
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
	# fill the screen (minus a margin) so the grid and the item text get every pixel a phone has
	var vis := get_viewport().get_visible_rect().size
	frame.custom_minimum_size = Vector2(clampf(vis.x - 48.0, 1150.0, 1500.0), maxf(640.0, vis.y - 36.0))
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
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	left.add_child(tabs)
	for t in [["basic", "Basic"], ["advanced", "Advanced"], ["consumable", "Consumables"], ["upgrades", "Training"]]:
		var tb := UIK.button(t[1], "", Vector2(176, 56))
		tb.toggle_mode = true
		var key: String = t[0]
		tb.pressed.connect(func(): _set_tab(key))
		tabs.add_child(tb)
		tab_buttons[key] = tb
	# the grid scrolls: with melee/ranged items a tab can hold more than fits on a phone
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	grid_scroll = scroll

	var det := UIK.panel("DarkPanel")
	det.custom_minimum_size = Vector2(380, 0)
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # extra width on wide phones goes to the item text
	body.add_child(det)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	det.add_child(dv)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 10)
	dv.add_child(dh)
	d_icon = UIK.icon_rect("gold", 60)
	dh.add_child(d_icon)
	d_name = UIK.label("Select an item", "", 24, Color(1, 0.93, 0.8))
	d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(d_name)
	# long descriptions scroll inside the panel instead of stretching the shop past the screen
	d_scroll = ScrollContainer.new()
	d_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dv.add_child(d_scroll)
	var dt := VBoxContainer.new()
	dt.add_theme_constant_override("separation", 8)
	dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_scroll.add_child(dt)
	d_desc = UIK.label("", "", 20)
	d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_desc.custom_minimum_size = Vector2(340, 0)
	dt.add_child(d_desc)
	d_recipe = UIK.label("", "SmallLabel", 19, UIK.col("dim", Color(0.75, 0.7, 0.62)))
	d_recipe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_recipe.custom_minimum_size = Vector2(340, 0)
	dt.add_child(d_recipe)
	UIK.pass_touch(d_scroll)
	# price shares the button row: every line of height goes to the item text on a phone
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	dv.add_child(brow)
	d_price = UIK.label("", "", 24, UIK.col("gold", Color.GOLD))
	d_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(d_price)
	buy_btn = UIK.button("Buy", "PrimaryButton", Vector2(150, 66))
	buy_btn.pressed.connect(func(): _buy(""))
	brow.add_child(buy_btn)
	buy_alt_btn = UIK.button("Buy (+Agi)", "PrimaryButton", Vector2(150, 66))
	buy_alt_btn.pressed.connect(func(): _buy("agi"))
	buy_alt_btn.add_theme_font_size_override("font_size", 22)
	brow.add_child(buy_alt_btn)
	sell_btn = UIK.button("Sell", "", Vector2(170, 66))
	sell_btn.pressed.connect(_sell)
	brow.add_child(sell_btn)

	# inventory
	outer.add_child(UIK.label("Inventory (tap to sell)", "SmallLabel", 19, UIK.col("dim", Color(0.7, 0.65, 0.6))))
	inv_row = HBoxContainer.new()
	inv_row.add_theme_constant_override("separation", 8)
	outer.add_child(inv_row)
	var t0 := Game.arg("tab", "basic")   # test hook: --scene=shop --tab=upgrades
	_set_tab(t0 if tab_buttons.has(t0) else "basic")
	if DB.ITEMS.has(Game.arg("item", "")):   # test hook: --item=splinter_quiver
		selected = Game.arg("item", "")
	_refresh()


func _set_tab(t: String) -> void:
	tab = t
	for k in tab_buttons:
		tab_buttons[k].button_pressed = k == t
	for c in grid.get_children():
		c.queue_free()
	if t == "upgrades":
		for id in DB.UPGRADE_ORDER:
			grid.add_child(_upgrade_button(id))
		_pass_grid_touch()
		_refresh()
		return
	for id in DB.ITEM_ORDER:
		var d: Dictionary = DB.ITEMS[id]
		if d["kind"] != t:
			continue
		grid.add_child(_item_button(id, Vector2(174, 96), true))
	_pass_grid_touch()
	_refresh()


## Tiles let touches through so a swipe that starts on one scrolls the grid, not just the scrollbar.
func _pass_grid_touch() -> void:
	UIK.pass_touch(grid_scroll)
	for b in grid.get_children():
		b.mouse_filter = Control.MOUSE_FILTER_PASS


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
	var only: String = d.get("only", "")
	if only != "" and show_name:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pr)
		var tag := UIK.label(only.capitalize(), "", 15, ONLY_COL[only])
		if not run.hero.item_fits(id):
			tag.modulate = Color(1, 1, 1, 0.55)
		row.add_child(tag)
		tv.add_child(row)
	else:
		tv.add_child(pr)
	b.set_meta("item", id)
	b.set_meta("show_name", show_name)
	b.set_meta("name_label", nm)
	b.set_meta("price_label", pr)
	b.pressed.connect(func(): _select(id))
	return b


## Training tile: icon, name, rank and next price (or why it can't be bought yet).
func _upgrade_button(id: String) -> Button:
	var d: Dictionary = DB.UPGRADES[id]
	var b := Button.new()
	b.theme_type_variation = "ShopItemButton"
	b.custom_minimum_size = Vector2(174, 96)
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
	var ic := UIK.icon_rect(id, 64)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	var nm := UIK.label(d["name"], "", 18, Color(1, 0.95, 0.88))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD
	nm.max_lines_visible = 2
	nm.custom_minimum_size = Vector2(80, 0)
	tv.add_child(nm)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(row)
	var pr := UIK.label("", "", 18, UIK.col("gold", Color.GOLD))
	row.add_child(pr)
	var rk := UIK.label("", "", 15, UIK.col("dim", Color(0.75, 0.7, 0.62)))
	row.add_child(rk)
	b.set_meta("upgrade", id)
	b.set_meta("name_label", nm)
	b.set_meta("rank_label", rk)
	b.set_meta("price_label", pr)
	b.pressed.connect(func(): _select_upgrade(id))
	return b


func _select_upgrade(id: String) -> void:
	d_scroll.scroll_vertical = 0
	selected_up = id
	selected = ""
	selected_slot = -1
	Audio.play("click")
	_refresh()


func _select(id: String) -> void:
	d_scroll.scroll_vertical = 0
	selected = id
	selected_up = ""
	selected_slot = -1
	Audio.play("click")
	_refresh()


func _select_slot(i: int) -> void:
	d_scroll.scroll_vertical = 0
	selected_slot = i
	selected_up = ""
	selected = run.hero.items[i]["id"] if i < run.hero.items.size() else ""
	_refresh()


func _buy(choice: String) -> void:
	if selected_up != "":
		if run.buy_upgrade(selected_up) == "":
			hud.show_toast("%s rank %d" % [DB.UPGRADES[selected_up]["name"], run.upgrade_rank(selected_up)], UIK.col("gold", Color.GOLD))
		_refresh()
		return
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
	var key := str(run.gold) + "|" + str(run.hero.items) + "|" + str(run.hero.train)
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
		if b.has_meta("upgrade"):
			_refresh_upgrade_tile(b)
			continue
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
	var ranks := 0
	for k in run.hero.train:
		ranks += int(run.hero.train[k])
	extra.text = "  Tomes: +%d %s   Training ranks: %d   Lives: %d" % [int(run.hero.bonus[run.hero.data["primary"]]),
		run.hero.data["primary"].to_upper(), ranks, run.lives]
	inv_row.add_child(extra)
	# details
	buy_alt_btn.visible = false
	if selected_up != "":
		_show_upgrade(selected_up)
		return
	if selected == "":
		d_name.text = "Select an item"
		d_desc.text = "Tap an item to see what it does. Advanced items combine the parts you own automatically." if tab != "upgrades" \
			else "Training: permanent stat upgrades, no slot. Buy them again and again; each rank costs a little more."
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
	var only2: String = d.get("only", "")
	if only2 != "":
		var fits := run.hero.item_fits(selected)
		rec = ("%s item: the effect only works on %s attacks.%s\n" % [only2.capitalize(), only2,
			"" if fits else " Your hero gets just the stats."]) + rec
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


func _refresh_upgrade_tile(b: Button) -> void:
	var id: String = b.get_meta("upgrade")
	var d: Dictionary = DB.UPGRADES[id]
	var rank := run.upgrade_rank(id)
	var why := run.can_upgrade(id)
	var rk: Label = b.get_meta("rank_label")
	var pr: Label = b.get_meta("price_label")
	rk.text = "Lv %d" % rank if not d.has("max") else "Lv %d/%d" % [rank, int(d["max"])]
	if why.begins_with("Opens"):
		pr.text = "Wave %d" % int(d["wave"])
	elif why == "Fully trained":
		pr.text = "Max"
	else:
		pr.text = str(run.upgrade_price(id))
	b.modulate = Color(1, 1, 1) if why == "" else Color(0.6, 0.6, 0.6)
	(b.get_meta("name_label") as Label).add_theme_color_override("font_color", UIK.col("gold", Color.GOLD) if id == selected_up else Color(1, 0.95, 0.88))


func _show_upgrade(id: String) -> void:
	var d: Dictionary = DB.UPGRADES[id]
	var rank := run.upgrade_rank(id)
	d_icon.texture = UIK.icon(id)
	d_name.text = "%s (rank %d)" % [d["name"], rank]
	d_desc.text = d["desc"] + " per rank. Permanent, no slot."
	var parts := []
	for k in d["stats"]:
		parts.append(_stat_text(k, float(d["stats"][k]) * rank))
	d_recipe.text = ("Trained so far: " + ", ".join(parts)) if rank > 0 else "Not trained yet."
	sell_btn.visible = false
	buy_btn.visible = true
	var why := run.can_upgrade(id)
	d_price.text = "" if why.begins_with("Opens") or why == "Fully trained" else "Next rank: %d" % run.upgrade_price(id)
	buy_btn.disabled = why != ""
	buy_btn.text = "Train" if why == "" else why
	buy_btn.add_theme_font_size_override("font_size", 22 if why == "" else 15)


static func _stat_text(k: String, v: float) -> String:
	match k:
		"str": return "+%d Strength" % int(v)
		"agi": return "+%d Agility" % int(v)
		"int": return "+%d Intellect" % int(v)
		"hp_regen": return "+%.1f HP/s" % v
		"mana_regen": return "+%.2f mana/s" % v
		"dmg": return "+%d damage" % int(v)
		"armor": return "+%.1f armor" % v
		"as": return "+%d%% attack speed" % int(round(v * 100.0))
		"hp": return "+%d HP" % int(v)
		"cdr": return "-%d%% cooldowns" % int(round(v * 100.0))
	return "%s +%s" % [k, v]
