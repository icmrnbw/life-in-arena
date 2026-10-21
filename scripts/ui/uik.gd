class_name UIK
extends RefCounted
## UI helpers: theme access, palette colors, icons, small widget factories.

static var _theme: Theme = null
static var _icons := {}


static func theme() -> Theme:
	if _theme == null:
		var t = null
		if Art.has_method("make_theme"):
			t = Art.make_theme()
		_theme = t if t is Theme else Theme.new()
	return _theme


static func col(key: String, fallback := Color.WHITE) -> Color:
	var p = Art.get("palette")
	if p is Dictionary and p.has(key) and p[key] is Color:
		return p[key]
	return fallback


static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var t = null
	if Art.has_method("icon"):
		t = Art.icon(id)
	if not (t is Texture2D):
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.25, 0.2))
		t = ImageTexture.create_from_image(img)
	_icons[id] = t
	return t


static func label(text: String, variation := "", size := 0, color := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, variation := "", min_size := Vector2(200, 96)) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Audio.play("click"))
	return b


static func panel(variation := "FramePanel") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


static func bar(variation: String, fill: Color, min_size := Vector2(200, 20)) -> ProgressBar:
	var b := ProgressBar.new()
	b.theme_type_variation = variation
	b.show_percentage = false
	b.custom_minimum_size = min_size
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# only tint the fill when the theme doesn't define this variation
	var t := theme()
	if not t.has_stylebox("fill", variation):
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override("fill", sb)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.55)
		bg.set_corner_radius_all(4)
		bg.set_border_width_all(2)
		bg.border_color = col("frame", Color(0.55, 0.42, 0.24))
		b.add_theme_stylebox_override("background", bg)
	return b


static func icon_rect(id: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


## Safe-area margins in viewport (canvas) pixels: left, top, right, bottom.
static func safe_margins(vp: Viewport) -> Vector4:
	if not (OS.has_feature("mobile") or OS.has_feature("android")):
		return Vector4.ZERO
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var vis := vp.get_visible_rect().size
	var sx := vis.x / float(win.x)
	var sy := vis.y / float(win.y)
	var l := maxf(0.0, safe.position.x) * sx
	var t := maxf(0.0, safe.position.y) * sy
	var r := maxf(0.0, win.x - (safe.position.x + safe.size.x)) * sx
	var b := maxf(0.0, win.y - (safe.position.y + safe.size.y)) * sy
	return Vector4(l, t, r, b)


## Button with a fixed-size icon beside a label (icons never shrink when the text wraps).
## The Label is at meta "label", the TextureRect at meta "icon". The Button's own text stays empty.
static func icon_button(text: String, icon_id: String, variation := "", min_size := Vector2(200, 96), icon_px := 64.0, font_size := 20) -> Button:
	var b := button("", variation, min_size)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8
	hb.offset_right = -8
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var ic := icon_rect(icon_id, icon_px)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var l := label(text, "", font_size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.visible = text != ""
	hb.add_child(l)
	b.set_meta("label", l)
	b.set_meta("icon", ic)
	b.set_meta("box", hb)
	return b


## Let a swipe that starts on scroll content reach its ScrollContainer: non-button Controls stop the touch by default.
static func pass_touch(n: Node) -> void:
	if n is Control and not n is BaseButton and n.mouse_filter == Control.MOUSE_FILTER_STOP:
		n.mouse_filter = Control.MOUSE_FILTER_PASS
	for c in n.get_children():
		pass_touch(c)
