extends RefCounted
## Emberpit UI theme: dark bronze, chamfered corners, ember accents, carved-rune studs. Built-in font only.

static func _svg_tex(svg: String) -> Texture2D:
	var img := Image.new()
	if img.load_svg_from_string(svg, 1.0) != OK or img.is_empty():
		img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.1, 0.08, 0.06))
	return ImageTexture.create_from_image(img)

static func _chamfer_path(x0: float, y0: float, x1: float, y1: float, c: float) -> String:
	return "M%s %s H%s L%s %s V%s L%s %s H%s L%s %s V%s Z" % [x0 + c, y0, x1 - c, x1, y0 + c, y1 - c, x1 - c, y1, x0 + c, x0, y1 - c, y0 + c]

## Generic chamfered 9-patch: outer dark line, rim gradient, inner fill gradient, optional accent line + corner studs.
static func _panel_svg(size: int, ch: float, rim_a: String, rim_b: String, fill_a: String, fill_b: String, accent: String, accent_op: float, studs: String) -> String:
	var s := float(size)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><defs>' % [size, size, size, size]
	svg += '<linearGradient id="r" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % [rim_a, rim_b]
	svg += '<linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % [fill_a, fill_b]
	svg += '</defs>'
	svg += '<path d="%s" fill="#0c0704"/>' % _chamfer_path(0.5, 0.5, s - 0.5, s - 0.5, ch)
	svg += '<path d="%s" fill="url(#r)"/>' % _chamfer_path(2, 2, s - 2, s - 2, ch - 0.8)
	svg += '<path d="%s" fill="#140c06"/>' % _chamfer_path(5, 5, s - 5, s - 5, ch - 2.0)
	svg += '<path d="%s" fill="url(#f)"/>' % _chamfer_path(6, 6, s - 6, s - 6, ch - 2.4)
	if accent != "":
		svg += '<path d="%s" fill="none" stroke="%s" stroke-opacity="%s" stroke-width="1.2"/>' % [_chamfer_path(8.5, 8.5, s - 8.5, s - 8.5, ch - 3.2), accent, accent_op]
		svg += '<path d="M%s 7 H%s" stroke="#ffffff" stroke-opacity="0.12" stroke-width="1.5"/>' % [ch, s - ch]
	if studs != "":
		var k := ch * 0.42
		for p in [[k, k], [s - k, k], [k, s - k], [s - k, s - k]]:
			svg += '<path d="M%s %s l3.2 -3.2 l3.2 3.2 l-3.2 3.2 z" fill="%s" stroke="#1a0c04" stroke-width="0.8"/>' % [p[0] - 3.2, p[1], studs]
	svg += '</svg>'
	return svg

static func _sbt(svg: String, margin: float, content_h: float, content_v: float) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _svg_tex(svg)
	sb.set_texture_margin_all(margin)
	sb.content_margin_left = content_h
	sb.content_margin_right = content_h
	sb.content_margin_top = content_v
	sb.content_margin_bottom = content_v
	return sb

static func _flat(bg: Color, border: Color, bw: int, radius: int, detail := 1, margin := 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = detail
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb

static func _bar_tex(top: Color, mid: Color, bot: Color) -> Texture2D:
	var img := Image.create(4, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		var f := y / 31.0
		var c := top.lerp(mid, f / 0.45) if f < 0.45 else mid.lerp(bot, (f - 0.45) / 0.55)
		if y == 2 or y == 3:
			c = c.lightened(0.35)
		for x in 4:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

static func _bar_fill(top: Color, mid: Color, bot: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _bar_tex(top, mid, bot)
	sb.set_content_margin_all(0)
	return sb

static func _label_style(th: Theme, type: String, size: int, col: Color, outline: int, shadow := 2) -> void:
	th.set_font_size("font_size", type, size)
	th.set_color("font_color", type, col)
	th.set_color("font_outline_color", type, Color(0.05, 0.025, 0.01, 1.0))
	th.set_constant("outline_size", type, outline)
	# no font shadow: the outline already separates text from the scene, and the shadow pass
	# cost ~30 extra canvas draw calls on the HUD (GL Compatibility can't batch it with the fill)
	th.set_color("font_shadow_color", type, Color(0, 0, 0, 0))
	th.set_constant("shadow_offset_x", type, 0)
	th.set_constant("shadow_offset_y", type, 0)
	th.set_constant("shadow_outline_size", type, 0)

static func _button_set(th: Theme, type: String, n: StyleBox, h: StyleBox, p: StyleBox, d: StyleBox, f: StyleBox, size: int, col: Color) -> void:
	th.set_stylebox("normal", type, n)
	th.set_stylebox("hover", type, h)
	th.set_stylebox("pressed", type, p)
	th.set_stylebox("hover_pressed", type, p)
	th.set_stylebox("disabled", type, d)
	th.set_stylebox("focus", type, f)
	th.set_font_size("font_size", type, size)
	th.set_color("font_color", type, col)
	th.set_color("font_hover_color", type, Color("ffe8b8"))
	th.set_color("font_pressed_color", type, Color("ffd27a"))
	th.set_color("font_hover_pressed_color", type, Color("ffd27a"))
	th.set_color("font_focus_color", type, col)
	th.set_color("font_disabled_color", type, Color(0.55, 0.5, 0.45, 0.8))
	th.set_color("font_outline_color", type, Color(0.05, 0.025, 0.01, 1.0))
	th.set_constant("outline_size", type, 6)
	th.set_color("icon_normal_color", type, Color.WHITE)
	th.set_color("icon_disabled_color", type, Color(0.45, 0.45, 0.45, 0.85))
	th.set_constant("h_separation", type, 10)

static func build(pal: Dictionary) -> Theme:
	var th := Theme.new()
	th.default_font = ThemeDB.fallback_font
	th.default_font_size = 22
	var text: Color = pal.get("text", Color("f4ead8"))
	var dim: Color = pal.get("dim", Color("9a8f80"))
	var gold: Color = pal.get("gold", Color("f2c14e"))
	var ember: Color = pal.get("ember", Color("ff7a2f"))

	# ---------------- panels
	var frame := _sbt(_panel_svg(96, 18, "#e2b070", "#4a2c12", "#2c2219", "#130e0a", "#ff7a2f", 0.45, "#ff8a3a"), 26, 22, 18)
	var plain := _flat(Color(0.11, 0.09, 0.07, 0.94), Color("8a6a3a"), 3, 10, 1, 12)
	plain.shadow_color = Color(0, 0, 0, 0.45); plain.shadow_size = 6
	var dark := _flat(Color(0.05, 0.04, 0.03, 0.8), Color("4a3020"), 2, 8, 1, 10)
	th.set_stylebox("panel", "Panel", plain)
	th.set_stylebox("panel", "PanelContainer", plain)
	th.set_type_variation("FramePanel", "PanelContainer")
	th.set_stylebox("panel", "FramePanel", frame)
	th.set_type_variation("DarkPanel", "PanelContainer")
	th.set_stylebox("panel", "DarkPanel", dark)
	th.set_stylebox("panel", "PopupPanel", frame)
	th.set_stylebox("panel", "TooltipPanel", _flat(Color(0.08, 0.06, 0.05, 0.96), Color("b0773a"), 2, 6, 1, 10))
	_label_style(th, "TooltipLabel", 18, text, 4, 1)

	# ---------------- buttons
	var bn := _sbt(_panel_svg(64, 12, "#d8a466", "#5a3618", "#4e3c2a", "#21170f", "#ffb060", 0.25, ""), 14, 18, 10)
	var bh := _sbt(_panel_svg(64, 12, "#ffd08a", "#7a4a1e", "#664c32", "#2c1e12", "#ff8a3a", 0.8, ""), 14, 18, 10)
	var bp := _sbt(_panel_svg(64, 12, "#8a5a2a", "#3a2210", "#1a120a", "#3a2a1c", "#ff7a2f", 0.9, ""), 14, 18, 11)
	var bd := _sbt(_panel_svg(64, 12, "#6a6460", "#2e2a28", "#2e2a28", "#181614", "", 0.0, ""), 14, 18, 10)
	var bf := _flat(Color(0, 0, 0, 0), Color(ember.r, ember.g, ember.b, 0.85), 2, 10, 1, 0)
	bf.draw_center = false
	bf.set_expand_margin_all(2)
	_button_set(th, "Button", bn, bh, bp, bd, bf, 22, text)
	th.set_constant("icon_max_width", "Button", 0)

	th.set_type_variation("PrimaryButton", "Button")
	var pn := _sbt(_panel_svg(64, 12, "#ffe08a", "#8a5212", "#e8661e", "#7a220a", "#fff0b0", 0.5, ""), 14, 26, 14)
	var ph := _sbt(_panel_svg(64, 12, "#fff2b8", "#a8641a", "#ff8a34", "#952c0c", "#ffffff", 0.7, ""), 14, 26, 14)
	var pp := _sbt(_panel_svg(64, 12, "#c8902a", "#5a3008", "#6a1e08", "#c84a14", "#ffd27a", 0.7, ""), 14, 26, 15)
	var pd := _sbt(_panel_svg(64, 12, "#7a7068", "#3a3430", "#4a3c34", "#26201c", "", 0.0, ""), 14, 26, 14)
	_button_set(th, "PrimaryButton", pn, ph, pp, pd, bf, 30, Color("fff6e0"))
	th.set_constant("outline_size", "PrimaryButton", 8)

	th.set_type_variation("SkillButton", "Button")
	var sn := _flat(Color(0.06, 0.045, 0.03, 0.88), Color("b0773a"), 4, 64, 16, 6)
	sn.shadow_color = Color(0, 0, 0, 0.5); sn.shadow_size = 4
	var sh := _flat(Color(0.12, 0.08, 0.05, 0.92), ember, 4, 64, 16, 6)
	sh.shadow_color = Color(ember.r, ember.g, ember.b, 0.35); sh.shadow_size = 8
	var sp := _flat(Color(0.35, 0.14, 0.04, 0.95), Color("ffd27a"), 5, 64, 16, 6)
	var sd := _flat(Color(0.05, 0.05, 0.05, 0.8), Color("4e4842"), 4, 64, 16, 6)
	var sf := _flat(Color(0, 0, 0, 0), Color(ember.r, ember.g, ember.b, 0.8), 3, 64, 16, 0)
	sf.draw_center = false
	_button_set(th, "SkillButton", sn, sh, sp, sd, sf, 26, text)
	th.set_constant("outline_size", "SkillButton", 7)

	th.set_type_variation("ShopItemButton", "Button")
	var shn := _sbt(_panel_svg(64, 10, "#a87a48", "#3e2814", "#262a30", "#14161a", "#e0b070", 0.25, "#b0773a"), 14, 14, 8)
	var shh := _sbt(_panel_svg(64, 10, "#ffcf8a", "#7a4a1e", "#323842", "#1a1c22", "#ff8a3a", 0.8, "#ff8a3a"), 14, 14, 8)
	var shp := _sbt(_panel_svg(64, 10, "#ffd27a", "#8a5212", "#3a2a1c", "#1a120a", "#ffd27a", 0.9, "#ffd27a"), 14, 14, 8)
	var shd := _sbt(_panel_svg(64, 10, "#5e5852", "#2a2624", "#1e1e20", "#121214", "", 0.0, ""), 14, 14, 8)
	_button_set(th, "ShopItemButton", shn, shh, shp, shd, bf, 20, text)
	th.set_constant("icon_max_width", "ShopItemButton", 72)
	th.set_constant("h_separation", "ShopItemButton", 12)
	th.set_constant("align_to_largest_stylebox", "ShopItemButton", 0)

	# ---------------- labels
	_label_style(th, "Label", 22, text, 6)
	th.set_type_variation("TitleLabel", "Label")
	_label_style(th, "TitleLabel", 58, gold, 12, 4)
	th.set_type_variation("BannerLabel", "Label")
	_label_style(th, "BannerLabel", 46, Color("ffe2b0"), 11, 3)
	th.set_type_variation("SmallLabel", "Label")
	_label_style(th, "SmallLabel", 16, dim.lightened(0.15), 4, 1)
	_label_style(th, "RichTextLabel", 20, text, 5)
	th.set_color("default_color", "RichTextLabel", text)
	th.set_constant("outline_size", "RichTextLabel", 5)
	th.set_color("font_outline_color", "RichTextLabel", Color(0.05, 0.025, 0.01, 1.0))

	# ---------------- progress bars
	var bar_bg := _flat(Color(0.04, 0.03, 0.025, 0.92), Color("5a3a20"), 2, 5, 1, 2)
	th.set_stylebox("background", "ProgressBar", bar_bg)
	th.set_stylebox("fill", "ProgressBar", _bar_fill(Color("ffd27a"), Color("d89a3a"), Color("7a4a14")))
	th.set_font_size("font_size", "ProgressBar", 16)
	th.set_color("font_color", "ProgressBar", text)
	th.set_color("font_outline_color", "ProgressBar", Color(0.05, 0.025, 0.01, 1.0))
	th.set_constant("outline_size", "ProgressBar", 5)
	var bars := {
		"HpBar": [Color("ff8a7a"), Color("d83a3a"), Color("6a1010")],
		"ManaBar": [Color("9ac8ff"), Color("3a7bd8"), Color("12306a")],
		"XpBar": [Color("e0b0ff"), Color("a55be0"), Color("4a1a7a")],
		"BossBar": [Color("ff9a6a"), Color("c8281e"), Color("4a0808")],
		"FlowBar": [Color("c8fff6"), Color("2fd6c8"), Color("0e5a62")],
	}
	for k in bars:
		th.set_type_variation(k, "ProgressBar")
		var c: Array = bars[k]
		th.set_stylebox("fill", k, _bar_fill(c[0], c[1], c[2]))
		th.set_stylebox("background", k, bar_bg)
	var boss_bg := _flat(Color(0.05, 0.02, 0.02, 0.94), Color("c8501a"), 3, 6, 1, 3)
	boss_bg.shadow_color = Color(1.0, 0.3, 0.1, 0.25); boss_bg.shadow_size = 8
	th.set_stylebox("background", "BossBar", boss_bg)
	th.set_font_size("font_size", "BossBar", 20)

	# ---------------- tabs / containers / scroll / misc controls
	var tab_sel := _flat(Color(0.2, 0.14, 0.09, 1.0), Color("e0a050"), 2, 8, 1, 12)
	tab_sel.border_width_bottom = 0
	tab_sel.corner_radius_bottom_left = 0; tab_sel.corner_radius_bottom_right = 0
	var tab_un := _flat(Color(0.08, 0.06, 0.05, 0.9), Color("5a3a20"), 2, 8, 1, 12)
	tab_un.corner_radius_bottom_left = 0; tab_un.corner_radius_bottom_right = 0
	var tab_hov := tab_un.duplicate()
	tab_hov.border_color = ember
	for tt in ["TabBar", "TabContainer"]:
		th.set_stylebox("tab_selected", tt, tab_sel)
		th.set_stylebox("tab_unselected", tt, tab_un)
		th.set_stylebox("tab_hovered", tt, tab_hov)
		th.set_stylebox("tab_disabled", tt, tab_un)
		th.set_stylebox("tab_focus", tt, bf)
		th.set_font_size("font_size", tt, 22)
		th.set_color("font_selected_color", tt, gold)
		th.set_color("font_unselected_color", tt, dim)
		th.set_color("font_hovered_color", tt, text)
		th.set_color("font_outline_color", tt, Color(0.05, 0.025, 0.01, 1.0))
		th.set_constant("outline_size", tt, 5)
	th.set_stylebox("panel", "TabContainer", _flat(Color(0.12, 0.09, 0.07, 0.95), Color("e0a050"), 2, 6, 1, 12))

	var grab := _flat(Color("8a6a3a"), Color("c8944e"), 1, 6, 4, 0)
	var grab_h := _flat(Color("c8843e"), Color("ffd27a"), 1, 6, 4, 0)
	var scroll_bg := _flat(Color(0.05, 0.04, 0.03, 0.6), Color(0, 0, 0, 0), 0, 6, 4, 4)
	for st in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", st, scroll_bg)
		th.set_stylebox("grabber", st, grab)
		th.set_stylebox("grabber_highlight", st, grab_h)
		th.set_stylebox("grabber_pressed", st, grab_h)
	var le := _flat(Color(0.05, 0.04, 0.03, 0.95), Color("8a6a3a"), 2, 6, 1, 10)
	th.set_stylebox("normal", "LineEdit", le)
	var le_f := le.duplicate(); le_f.border_color = ember
	th.set_stylebox("focus", "LineEdit", le_f)
	th.set_color("font_color", "LineEdit", text)
	var slider := _flat(Color(0.05, 0.04, 0.03, 0.95), Color("5a3a20"), 2, 4, 1, 4)
	slider.content_margin_top = 4; slider.content_margin_bottom = 4
	th.set_stylebox("slider", "HSlider", slider)
	th.set_stylebox("grabber_area", "HSlider", _flat(ember.darkened(0.2), Color(0, 0, 0, 0), 0, 4, 1, 4))
	th.set_stylebox("grabber_area_highlight", "HSlider", _flat(ember, Color(0, 0, 0, 0), 0, 4, 1, 4))
	th.set_color("font_color", "CheckBox", text)
	th.set_color("font_color", "CheckButton", text)
	th.set_font_size("font_size", "CheckBox", 22)
	th.set_font_size("font_size", "CheckButton", 22)
	var sep := StyleBoxLine.new()
	sep.color = Color("8a6a3a"); sep.thickness = 2
	th.set_stylebox("separator", "HSeparator", sep)
	var sepv := StyleBoxLine.new()
	sepv.color = Color("8a6a3a"); sepv.thickness = 2; sepv.vertical = true
	th.set_stylebox("separator", "VSeparator", sepv)
	th.set_constant("separation", "HBoxContainer", 10)
	th.set_constant("separation", "VBoxContainer", 10)
	th.set_constant("h_separation", "GridContainer", 10)
	th.set_constant("v_separation", "GridContainer", 10)
	return th

