class_name SkillButton
extends Control
## Round skill button drawn in code: themed frame, circular icon, cooldown sweep, rank pips, "+" badge.

var slot := 0
var key_text := ""
var icon_tex: Texture2D
var diameter := 116.0
var cd_frac := 0.0
var cd_left := 0.0
var is_ready := true
var no_mana := false
var learned := false
var rank := 0
var max_rank := 4
var can_rank := false
var charges := -1
var label_text := ""
var pressed := false
var cancel := false
var _flash := 0.0


func setup(s: int, key: String, tex: Texture2D, d: float) -> void:
	slot = s
	key_text = key
	icon_tex = tex
	diameter = d
	custom_minimum_size = Vector2(d, d)
	size = Vector2(d, d)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func center() -> Vector2:
	return global_position + size * 0.5


func radius() -> float:
	return diameter * 0.5


func badge_center() -> Vector2:
	# sits outside the rim (top-right) so it never covers the cast area
	return center() + Vector2(0.7071, -0.7071) * (radius() + 14.0)


func flash_ready() -> void:
	_flash = 0.35


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta


# ---- batched drawing: every disc / ring / pip is a rect with one shared texture, so a whole
# button costs ~4 canvas draw calls (shapes, icon, sweep, text) instead of ~20 polygons.
# One 256x128 atlas: left half a soft disc, right half a ring. Sharing a single texture keeps
# discs, rings and solid rects in the same batch.
static var _atlas: Texture2D
const _DISC := Rect2(0, 0, 128, 128)
const _RING := Rect2(128, 0, 128, 128)
const _SOLID := Rect2(60, 60, 8, 8)


static func atlas_tex() -> Texture2D:
	if _atlas == null:
		var n := 128
		var img := Image.create(n * 2, n, false, Image.FORMAT_RGBA8)
		var c := (n - 1) * 0.5
		for y in n:
			for x in n:
				var d := Vector2(x - c, y - c).length()
				var a := clampf(c + 0.5 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
				img.set_pixel(x + n, y, Color(1, 1, 1, minf(a, clampf(d - (c - 6.0) + 0.5, 0.0, 1.0))))
		_atlas = ImageTexture.create_from_image(img)
	return _atlas


## Filled circle (batched).
static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect_region(atlas_tex(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), _DISC, col)


## Ring of outer radius r, ~r/10.5 thick (batched).
static func ring(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect_region(atlas_tex(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), _RING, col)


## Solid rect drawn from the disc's opaque centre (keeps the batch).
static func solid(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_texture_rect_region(atlas_tex(), r, _SOLID, col)


func _icon_polygon(c: Vector2, ir: float) -> Array:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var n := 32
	for i in n:
		var a := TAU * i / n
		var p := c + Vector2(cos(a), sin(a)) * ir
		pts.append(p)
		uvs.append((p - c) / (ir * 2.0) + Vector2(0.5, 0.5))
	return [pts, uvs]


## Draws one layer of this button onto `ci` (the parent, which paints all four buttons layer by layer
## so every layer batches into one draw call). Phases: 0 base, 1 icon, 2 sweep, 3 rings/pips/badge, 4 text outline, 5 text.
func paint(ci: CanvasItem, phase: int) -> void:
	var c := position + size * 0.5
	var r := radius()
	var ember := UIK.col("ember", Color(1, 0.48, 0.18))
	var frame := UIK.col("frame", Color(0.54, 0.42, 0.23))
	var panel := UIK.col("panel", Color(0.11, 0.09, 0.07))
	var gold := UIK.col("gold", Color(0.95, 0.76, 0.3))
	# 1) base discs
	if phase == 0:
		disc(ci, c, r, Color(0, 0, 0, 0.45))
		disc(ci, c, r - 2.0, frame.darkened(0.25))
		disc(ci, c, r - 6.0, panel)
		return
	# 2) icon
	var ir := r - 9.0
	var tint := Color(1, 1, 1)
	if not learned:
		tint = Color(0.35, 0.35, 0.35)
	elif no_mana:
		tint = Color(0.45, 0.55, 1.0)
	if phase == 1:
		if icon_tex:
			var poly := _icon_polygon(c, ir)
			ci.draw_colored_polygon(poly[0], tint, poly[1], icon_tex)
		return
	# 3) cooldown sweep
	if phase == 2:
		if learned and cd_frac > 0.001:
			_sweep(ci, c, ir)
		return
	var kp := c + Vector2(-r * 0.78, -r * 0.55)
	var cp := c + Vector2(r * 0.55, r * 0.5)
	if phase == 3:
		_rings(ci, c, r, kp, cp, ember, frame, gold)
		return
	_texts(ci, c, r, kp, cp, phase)


func _sweep(ci: CanvasItem, c: Vector2, ir: float) -> void:
	if true:
		var sweep := PackedVector2Array()
		sweep.append(c)
		var steps := 24
		var start := -PI * 0.5
		for i in steps + 1:
			var a := start + TAU * cd_frac * float(i) / steps
			sweep.append(c + Vector2(cos(a), sin(a)) * ir)
		ci.draw_colored_polygon(sweep, Color(0, 0, 0, 0.62))


func _rings(ci: CanvasItem, c: Vector2, r: float, kp: Vector2, cp: Vector2, ember: Color, frame: Color, gold: Color) -> void:
	var ring_col := frame.lightened(0.15)
	if pressed:
		ring_col = Color(1, 0.3, 0.25) if cancel else ember.lightened(0.2)
	elif learned and is_ready and not no_mana:
		ring_col = ember
	if _flash > 0.0:
		ring_col = ring_col.lerp(Color(1, 1, 0.8), _flash / 0.35)
	ring(ci, c, r - 2.0, ring_col)
	if (is_ready and learned) or pressed:
		ring(ci, c, r - 3.0, Color(ring_col.r, ring_col.g, ring_col.b, 0.6))
	for i in max_rank:
		var a := PI * 0.5 + (float(i) - (max_rank - 1) * 0.5) * 0.22
		var pp := c + Vector2(cos(a), sin(a)) * (r - 3.0)
		disc(ci, pp, 5.5, Color(0, 0, 0, 0.8))
		disc(ci, pp, 4.0, gold if i < rank else Color(0.25, 0.22, 0.2))
	if key_text != "":
		disc(ci, kp + Vector2(6, -6), 13, Color(0, 0, 0, 0.65))
	if charges >= 0 and learned:
		disc(ci, cp, 15, Color(0, 0, 0, 0.75))
	if can_rank:
		var bc := c + Vector2(0.7071, -0.7071) * (r + 14.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
		disc(ci, bc, 25.0 + pulse * 3.0, Color(1, 0.85, 0.4, 0.25 * pulse))
		disc(ci, bc, 23.0, Color(0, 0, 0, 0.7))
		disc(ci, bc, 20.0, gold.lerp(Color(1, 1, 0.8), pulse * 0.4))
		solid(ci, Rect2(bc + Vector2(-11, -3), Vector2(22, 6)), Color(0.15, 0.1, 0.05))
		solid(ci, Rect2(bc + Vector2(-3, -11), Vector2(6, 22)), Color(0.15, 0.1, 0.05))


## Phase 4 = outlines, phase 5 = fills (outline glyphs live in a separate cache texture).
func _texts(ci: CanvasItem, c: Vector2, r: float, kp: Vector2, cp: Vector2, phase: int) -> void:
	var font := get_theme_default_font()
	var outl := []   # [pos, text, size, outline, color]
	var fills := []
	if learned and cd_left > 0.05 and cd_frac > 0.0:
		var txt := ("%.1f" % cd_left) if cd_left < 3.0 else str(int(ceil(cd_left)))
		var fs := int(diameter * 0.30)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := c + Vector2(-tw * 0.5, fs * 0.35)
		outl.append([tp, txt, fs, 6])
		fills.append([tp, txt, fs, Color(1, 1, 1)])
	if label_text != "":
		var fs2 := int(diameter * 0.17)
		var tw2 := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var lp := c + Vector2(-tw2 * 0.5, r * 0.55)
		outl.append([lp, label_text, fs2, 5])
		fills.append([lp, label_text, fs2, Color(0.75, 0.95, 1.0)])
	if key_text != "":
		fills.append([kp, key_text, 18, Color(1, 0.95, 0.85)])
	if charges >= 0 and learned:
		var ct := str(charges)
		var cw := font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		fills.append([cp + Vector2(-cw * 0.5, 7), ct, 20, Color(0.8, 0.95, 1.0)])
	if phase == 4:
		for t in outl:
			ci.draw_string_outline(font, t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, t[2], t[3], Color(0, 0, 0, 0.9))
		return
	for t in fills:
		ci.draw_string(font, t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, t[2], t[3])
