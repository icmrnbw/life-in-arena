extends RefCounted
## 128x128 icons rendered from original procedural SVG (ThorVG via Image.load_svg_from_string).
## Frame language: chamfered dark-bronze octagon with ember rune notches (not a square stone/gold bevel).

static var _cache := {}

const D := "#120a04"  # outline

const HERO_BG := {
	"ash": ["#9a4416", "#1e0904", "#ffb040"],
	"rift": ["#3e2c78", "#0c0718", "#3ff0dc"],
	"hive": ["#2e6230", "#071407", "#9cff3a"],
	"basic": ["#56626e", "#11151a", "#e0b070"],
	"adv": ["#6a3490", "#150a20", "#ffcf5a"],
	"cons": ["#2e6658", "#08160f", "#8affd8"],
}

const GRADS := """
<linearGradient id="fire" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff0a0"/><stop offset="0.45" stop-color="#ffa030"/><stop offset="1" stop-color="#e2380c"/></linearGradient>
<linearGradient id="teal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e6fffb"/><stop offset="0.5" stop-color="#3ff0dc"/><stop offset="1" stop-color="#1a8a9a"/></linearGradient>
<linearGradient id="viol" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e8c8ff"/><stop offset="0.5" stop-color="#b45cff"/><stop offset="1" stop-color="#5a1ea0"/></linearGradient>
<linearGradient id="acid" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4ffb0"/><stop offset="0.5" stop-color="#9cff3a"/><stop offset="1" stop-color="#3a8a14"/></linearGradient>
<linearGradient id="metal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f4f4fa"/><stop offset="0.5" stop-color="#a8aebc"/><stop offset="1" stop-color="#4e5462"/></linearGradient>
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff2a8"/><stop offset="0.5" stop-color="#f2c14e"/><stop offset="1" stop-color="#a8641a"/></linearGradient>
<linearGradient id="bronze" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f0c27a"/><stop offset="0.5" stop-color="#b0773a"/><stop offset="1" stop-color="#5a3414"/></linearGradient>
<linearGradient id="wood" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#5e3a1e"/><stop offset="0.5" stop-color="#b07a44"/><stop offset="1" stop-color="#6a4222"/></linearGradient>
<linearGradient id="leather" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c88a52"/><stop offset="1" stop-color="#6a3e1e"/></linearGradient>
<linearGradient id="blood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff7a7a"/><stop offset="0.5" stop-color="#e2343a"/><stop offset="1" stop-color="#7a0e16"/></linearGradient>
<linearGradient id="mana" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b8e4ff"/><stop offset="0.5" stop-color="#3a8aff"/><stop offset="1" stop-color="#16308a"/></linearGradient>
<linearGradient id="stone" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#a8a0a8"/><stop offset="1" stop-color="#4e4852"/></linearGradient>
<linearGradient id="chit" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6aa070"/><stop offset="1" stop-color="#1c3a26"/></linearGradient>
<linearGradient id="ivory" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff6d8"/><stop offset="1" stop-color="#b8a46a"/></linearGradient>
<linearGradient id="hood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a5ac8"/><stop offset="1" stop-color="#2a1848"/></linearGradient>
<radialGradient id="glowE" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ffd27a" stop-opacity="0.9"/><stop offset="1" stop-color="#ff7a2f" stop-opacity="0"/></radialGradient>
<radialGradient id="glowT" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#b8fff6" stop-opacity="0.9"/><stop offset="1" stop-color="#3ff0dc" stop-opacity="0"/></radialGradient>
<radialGradient id="glowA" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#eaffa0" stop-opacity="0.9"/><stop offset="1" stop-color="#9cff3a" stop-opacity="0"/></radialGradient>
<radialGradient id="glowR" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ffb0a0" stop-opacity="0.9"/><stop offset="1" stop-color="#ff3a26" stop-opacity="0"/></radialGradient>
"""

## Glyph size normalisation: every framed glyph (except portraits) is measured by its opaque
## pixels and scaled/centred so its opaque area is ~GLYPH_COV^2 px (larger side <= GLYPH_MAX) inside the 128 canvas.
const GLYPH_COV := 62.0
const GLYPH_MAX := 92.0
static var _cur_id := ""
static var last_bbox := Rect2()
static var _last_cov := 0

static func _glyph_rect(glyph: String) -> Rect2:
	var img := Image.new()
	if img.load_svg_from_string(_plain(glyph), 1.0) != OK or img.is_empty():
		return Rect2()
	var x0 := 999; var y0 := 999; var x1 := -1; var y1 := -1
	_last_cov = 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.95:
				_last_cov += 1
				x0 = mini(x0, x); y0 = mini(y0, y); x1 = maxi(x1, x); y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2()
	return Rect2(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

static func _normalise(glyph: String) -> String:
	if _cur_id.begins_with("portrait_"):
		return glyph
	var r := _glyph_rect(glyph)
	last_bbox = r
	if r.size.x < 4.0:
		return glyph
	# perceived size ~ sqrt(opaque area); never let the glyph outgrow the inner frame
	var sc := minf(GLYPH_COV / sqrt(float(_last_cov)), GLYPH_MAX / maxf(r.size.x, r.size.y))
	sc = clampf(sc, 0.75, 1.45)
	var c := r.get_center()
	var tx := 64.0 - c.x * sc
	var ty := 65.0 - c.y * sc
	return '<g clip-path="url(#inner)"><g transform="translate(%.2f %.2f) scale(%.4f)">%s</g></g>' % [tx, ty, sc, glyph]

static func _framed(theme: String, glyph: String) -> String:
	glyph = _normalise(glyph)
	var c: Array = HERO_BG.get(theme, HERO_BG["basic"])
	var s := '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><defs>'
	s += '<radialGradient id="bg" cx="0.5" cy="0.36" r="0.72"><stop offset="0" stop-color="' + c[0] + '"/><stop offset="1" stop-color="' + c[1] + '"/></radialGradient>'
	s += '<linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e8b878"/><stop offset="0.35" stop-color="#9a6630"/><stop offset="0.7" stop-color="#5a3818"/><stop offset="1" stop-color="#2e1a0a"/></linearGradient>'
	s += '<linearGradient id="hl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity="0.2"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient>'
	s += '<clipPath id="inner"><path d="M25 14 H103 L114 25 V103 L103 114 H25 L14 103 V25 Z"/></clipPath>'
	s += GRADS + '</defs>'
	s += '<path d="M20 2 H108 L126 20 V108 L108 126 H20 L2 108 V20 Z" fill="#140b05"/>'
	s += '<path d="M21 5 H107 L123 21 V107 L107 123 H21 L5 107 V21 Z" fill="url(#rim)"/>'
	s += '<path d="M24 12 H104 L116 24 V104 L104 116 H24 L12 104 V24 Z" fill="#1a0f07"/>'
	s += '<path d="M25 14 H103 L114 25 V103 L103 114 H25 L14 103 V25 Z" fill="url(#bg)"/>'
	s += glyph
	s += '<path d="M25 14 H103 L114 25 V58 H14 V25 Z" fill="url(#hl)"/>'
	# carved rune notches on the rim
	var a: String = c[2]
	for pt in [[64, 8.5], [64, 119.5], [8.5, 64], [119.5, 64]]:
		s += '<path d="M%s %s l4.5 -4.5 l4.5 4.5 l-4.5 4.5 z" fill="%s" stroke="#2a1608" stroke-width="1.2"/>' % [str(pt[0] - 4.5), str(pt[1]), a]
	for pt in [[13, 13], [115, 13], [13, 115], [115, 115]]:
		s += '<circle cx="%s" cy="%s" r="2.6" fill="#f0c27a" stroke="#2a1608" stroke-width="1"/>' % [str(pt[0]), str(pt[1])]
	s += '</svg>'
	return s

static func _plain(glyph: String) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><defs>' + GRADS + '</defs>' + glyph + '</svg>'

static func _o(w := 4.0) -> String:
	return ' stroke="' + D + '" stroke-width="' + str(w) + '" stroke-linejoin="round" stroke-linecap="round" '

static func get_icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	_cur_id = id
	var svg := _svg_for(id)
	_cur_id = ""
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK or img.is_empty():
		img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.2, 0.12))
	if img.get_width() != 128:
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex

static func all_ids() -> Array:
	return ["ember_totem", "ash_wall", "tether_pull", "foundry_heart", "slip", "shatter_mark", "afterimage", "rift_cascade",
		"brood", "rally_pheromone", "volatile_sacrifice", "queens_carapace",
		"iron_knuckles", "swift_gloves", "hide_vest", "vigor_charm", "focus_pendant", "runners_boots", "stout_belt", "sage_circlet",
		"emberbrand", "bulwark_plate", "wayfarer_treads", "hivecore_sigil", "bloodthirst_fang", "wardens_aegis",
		"healing_draught", "mana_draught", "tome_of_might", "phoenix_feather",
		"portrait_ashwarden", "portrait_riftdancer", "portrait_hivemother",
		"gold", "life", "attack", "armor", "speed", "pause", "shop"]

static func _flame(x: float, y: float, s: float, fill := "url(#fire)") -> String:
	# flame shape with tip at (x, y - 30s), base at (x, y)
	var p := "M%s %s C%s %s %s %s %s %s C%s %s %s %s %s %s C%s %s %s %s %s %s Z" % [
		x, y - 30 * s,
		x + 12 * s, y - 16 * s, x + 16 * s, y - 8 * s, x + 10 * s, y,
		x + 6 * s, y + 5 * s, x - 6 * s, y + 5 * s, x - 10 * s, y,
		x - 16 * s, y - 10 * s, x - 6 * s, y - 16 * s, x, y - 30 * s]
	return '<path d="' + p + '" fill="' + fill + '"' + _o(3) + '/>'

static func _svg_for(id: String) -> String:
	match id:
		# ---------------------------------------------------------- Ashwarden (ember)
		"ember_totem":
			return _framed("ash", '<ellipse cx="64" cy="40" rx="30" ry="26" fill="url(#glowE)"/>'
				+ _flame(64, 50, 1.25)
				+ '<path d="M60 48 C62 40 66 38 64 30 C70 38 70 44 68 48 Z" fill="#fff6c8"/>'
				+ '<path d="M40 50 H88 L82 60 H46 Z" fill="url(#bronze)"' + _o() + '/>'
				+ '<rect x="47" y="60" width="34" height="22" fill="url(#stone)"' + _o() + '/>'
				+ '<rect x="44" y="82" width="40" height="16" fill="#6a6268"' + _o() + '/>'
				+ '<rect x="38" y="98" width="52" height="10" fill="#4e4852"' + _o() + '/>'
				+ '<path d="M53 67 l8 3 M75 67 l-8 3" stroke="#ffb040" stroke-width="4" stroke-linecap="round"/>'
				+ '<rect x="57" y="74" width="14" height="4" fill="#ffb040"/>'
				+ '<path d="M54 86 v8 M64 86 v8 M74 86 v8" stroke="#ff8a2a" stroke-width="3"/>')
		"ash_wall":
			return _framed("ash", '<ellipse cx="64" cy="98" rx="50" ry="12" fill="url(#glowE)"/>'
				+ _flame(46, 48, 0.75) + _flame(84, 46, 0.65)
				+ '<path d="M16 102 L22 66 L32 58 L38 72 L46 46 L58 42 L64 64 L72 52 L84 46 L90 64 L100 58 L112 68 L112 102 Z" fill="url(#stone)"' + _o() + '/>'
				+ '<path d="M28 100 L32 78 L36 88 M50 100 L54 62 L58 80 M78 100 L80 66 L86 82 M100 100 L102 78" stroke="#ffc050" stroke-width="3.5" fill="none" stroke-linecap="round"/>')
		"tether_pull":
			var links := ""
			for i in 5:
				var x := 22.0 + i * 12.5
				var y := 102.0 - i * 13.0
				links += '<ellipse cx="%s" cy="%s" rx="8" ry="5" transform="rotate(-48 %s %s)" fill="none" stroke="%s" stroke-width="7"/>' % [x, y, x, y, D]
				links += '<ellipse cx="%s" cy="%s" rx="8" ry="5" transform="rotate(-48 %s %s)" fill="none" stroke="url(#bronze)" stroke-width="3.5"/>' % [x, y, x, y]
			return _framed("ash", links
				+ '<path d="M80 34 C98 34 106 56 94 68 C86 76 74 72 72 62" fill="none" stroke="' + D + '" stroke-width="13" stroke-linecap="round"/>'
				+ '<path d="M80 34 C98 34 106 56 94 68 C86 76 74 72 72 62" fill="none" stroke="url(#metal)" stroke-width="7" stroke-linecap="round"/>'
				+ '<path d="M72 64 L64 50 L80 54 Z" fill="url(#metal)"' + _o(3) + '/>'
				+ '<path d="M100 98 l-12 -6 M108 84 l-13 -3 M86 108 l-5 -11" stroke="#ffb040" stroke-width="4" stroke-linecap="round"/>')
		"foundry_heart":
			return _framed("ash", '<ellipse cx="64" cy="56" rx="40" ry="34" fill="url(#glowE)"/>'
				+ '<path d="M28 88 H100 L94 98 H78 L82 110 H46 L50 98 H34 Z" fill="url(#metal)"' + _o() + '/>'
				+ '<path d="M64 86 C40 70 26 56 32 40 C38 26 56 26 64 40 C72 26 90 26 96 40 C102 56 88 70 64 86 Z" fill="url(#fire)"' + _o() + '/>'
				+ '<path d="M50 44 L58 52 L53 61 M78 42 L71 52 L77 61 M64 52 V70" stroke="#fff6c8" stroke-width="3" fill="none" stroke-linecap="round"/>'
				+ '<circle cx="30" cy="26" r="3" fill="#ffd27a"/><circle cx="100" cy="24" r="2.5" fill="#ffd27a"/><circle cx="106" cy="52" r="2" fill="#ffd27a"/>')
		# ---------------------------------------------------------- Riftdancer (teal/violet)
		"slip":
			return _framed("rift", '<path d="M18 72 H50 M26 86 H58 M30 58 H50" stroke="url(#teal)" stroke-width="6" stroke-linecap="round" opacity="0.9"/>'
				+ '<path d="M34 96 C54 84 72 62 88 30 C88 56 76 82 46 102 Z" fill="#3ff0dc" opacity="0.3"/>'
				+ '<path d="M50 96 C70 84 88 62 104 28 C104 54 92 80 62 102 Z" fill="url(#teal)"' + _o() + '/>'
				+ '<path d="M56 100 L48 110" stroke="#5a3a2a" stroke-width="8" stroke-linecap="round"/>')
		"shatter_mark":
			return _framed("rift", '<ellipse cx="64" cy="62" rx="40" ry="40" fill="url(#glowT)"/>'
				+ '<path d="M64 22 L92 60 L64 98 L36 60 Z" fill="url(#viol)"' + _o() + '/>'
				+ '<path d="M64 36 V84 M50 60 H78" stroke="#e8fffb" stroke-width="4" stroke-linecap="round"/>'
				+ '<path d="M64 22 L60 46 L70 60 L58 78 L64 98" stroke="' + D + '" stroke-width="3" fill="none"/>'
				+ '<path d="M98 28 L110 32 L100 42 Z M22 34 L32 30 L28 44 Z M100 90 L112 98 L98 102 Z M24 92 L34 100 L20 104 Z" fill="url(#teal)"' + _o(2.5) + '/>')
		"afterimage":
			var fig := 'M64 24 C76 24 82 34 80 46 L88 58 L80 62 L84 104 H44 L48 62 L40 58 L48 46 C46 34 52 24 64 24 Z'
			return _framed("rift", '<path d="' + fig + '" transform="translate(-18 4)" fill="#3ff0dc" opacity="0.35"/>'
				+ '<path d="' + fig + '" transform="translate(-9 2)" fill="#3ff0dc" opacity="0.25"/>'
				+ '<path d="' + fig + '" transform="translate(8 0)" fill="url(#hood)"' + _o() + '/>'
				+ '<ellipse cx="72" cy="44" rx="10" ry="9" fill="#0a0810"/>'
				+ '<path d="M66 44 h4 M74 44 h4" stroke="#3ff0dc" stroke-width="3" stroke-linecap="round"/>'
				+ '<path d="M60 56 C70 62 82 60 94 70" stroke="url(#teal)" stroke-width="6" fill="none" stroke-linecap="round"/>')
		"rift_cascade":
			var pts := [[24, 98], [46, 38], [72, 86], [102, 30]]
			var s := '<path d="M24 98 L46 38 L72 86 L102 30" stroke="' + D + '" stroke-width="12" fill="none" stroke-linejoin="round"/>'
			s += '<path d="M24 98 L46 38 L72 86 L102 30" stroke="url(#teal)" stroke-width="6" fill="none" stroke-linejoin="round"/>'
			for p in pts:
				s += '<path d="M%s %s l8 -10 l8 10 l-8 10 z" fill="url(#viol)"%s/>' % [p[0] - 8, p[1], _o(3)]
				s += '<circle cx="%s" cy="%s" r="2.5" fill="#ffffff"/>' % [p[0], p[1]]
			return _framed("rift", '<ellipse cx="64" cy="64" rx="44" ry="40" fill="url(#glowT)" opacity="0.6"/>' + s)
		# ---------------------------------------------------------- Hivemother (acid)
		"brood":
			return _framed("hive", '<ellipse cx="64" cy="80" rx="44" ry="26" fill="url(#glowA)"/>'
				+ '<ellipse cx="40" cy="84" rx="15" ry="19" fill="url(#ivory)"' + _o() + '/>'
				+ '<ellipse cx="88" cy="86" rx="15" ry="18" fill="url(#ivory)"' + _o() + '/>'
				+ '<ellipse cx="64" cy="70" rx="19" ry="25" fill="url(#ivory)"' + _o() + '/>'
				+ '<path d="M46 62 L54 56 L60 64 L66 54 L74 62 L82 58" stroke="' + D + '" stroke-width="3" fill="none"/>'
				+ '<ellipse cx="64" cy="54" rx="13" ry="11" fill="url(#chit)"' + _o(3) + '/>'
				+ '<circle cx="59" cy="52" r="3" fill="#c8ff6a"/><circle cx="69" cy="52" r="3" fill="#c8ff6a"/>'
				+ '<path d="M58 62 l-4 6 M70 62 l4 6" stroke="url(#ivory)" stroke-width="3" stroke-linecap="round"/>'
				+ '<path d="M56 46 L48 32 M72 46 L80 32" stroke="' + D + '" stroke-width="3"/>')
		"rally_pheromone":
			return _framed("hive", '<path d="M44 108 V22" stroke="' + D + '" stroke-width="9" stroke-linecap="round"/>'
				+ '<path d="M44 108 V22" stroke="url(#bronze)" stroke-width="4.5" stroke-linecap="round"/>'
				+ '<path d="M47 24 H94 L82 40 L94 56 H47 Z" fill="url(#acid)"' + _o() + '/>'
				+ '<circle cx="64" cy="40" r="6" fill="#1c3a26"/>'
				+ '<path d="M66 80 A20 20 0 0 1 96 76 M60 96 A34 34 0 0 1 108 88 M74 66 A10 10 0 0 1 88 64" stroke="#c8ff6a" stroke-width="4.5" fill="none" stroke-linecap="round"/>')
		"volatile_sacrifice":
			return _framed("hive", '<path d="M64 14 L72 44 L100 26 L84 54 L114 64 L84 74 L100 102 L72 84 L64 114 L56 84 L28 102 L44 74 L14 64 L44 54 L28 26 L56 44 Z" fill="url(#acid)"' + _o(3) + '/>'
				+ '<path d="M50 56 L40 48 M50 66 H38 M50 76 L40 84 M78 56 L88 48 M78 66 H90 M78 76 L88 84" stroke="' + D + '" stroke-width="4" stroke-linecap="round"/>'
				+ '<ellipse cx="64" cy="70" rx="15" ry="19" fill="url(#chit)"' + _o() + '/>'
				+ '<circle cx="64" cy="46" r="9" fill="url(#chit)"' + _o(3) + '/>'
				+ '<path d="M56 64 H72 M56 74 H72" stroke="#c8ff6a" stroke-width="3"/>')
		"queens_carapace":
			return _framed("hive", '<ellipse cx="64" cy="70" rx="42" ry="40" fill="url(#glowA)" opacity="0.7"/>'
				+ '<path d="M64 36 L96 52 V86 L64 106 L32 86 V52 Z" fill="url(#chit)"' + _o() + '/>'
				+ '<path d="M64 48 L84 58 V80 L64 94 L44 80 V58 Z" fill="none" stroke="#c8ff6a" stroke-width="3.5"/>'
				+ '<path d="M64 48 V94 M44 69 H84" stroke="#c8ff6a" stroke-width="2" opacity="0.7"/>'
				+ '<path d="M42 36 L48 16 L56 28 L64 10 L72 28 L80 16 L86 36 Z" fill="url(#gold)"' + _o(3) + '/>'
				+ '<circle cx="64" cy="28" r="3" fill="#9cff3a"/>')
		# ---------------------------------------------------------- basic items
		"iron_knuckles":
			var r := ""
			for x in [34, 54, 74, 94]:
				r += '<circle cx="%s" cy="54" r="11"%s fill="url(#metal)"/><circle cx="%s" cy="54" r="5.5" fill="#202830"/>' % [x, _o(), x]
			return _framed("basic", '<path d="M24 66 Q64 100 104 66 L104 80 Q64 116 24 80 Z" fill="url(#metal)"' + _o() + '/>' + r)
		"swift_gloves":
			return _framed("basic", '<path d="M88 74 C102 66 110 52 112 36 C104 44 96 46 88 46 C98 40 102 32 104 22 C94 32 86 38 78 40" fill="#eaf6ff"' + _o(3) + '/>'
				+ '<path d="M42 106 V66 C42 58 49 58 51 64 V42 C51 35 59 35 59 42 V37 C59 31 67 31 67 37 V41 C67 35 75 35 75 41 V60 C79 54 88 56 86 64 L78 90 V106 Z" fill="url(#leather)"' + _o() + '/>'
				+ '<rect x="40" y="96" width="40" height="12" rx="3" fill="url(#bronze)"' + _o(3) + '/>'
				+ '<path d="M20 60 H34 M16 74 H32 M22 88 H36" stroke="#e0b070" stroke-width="4" stroke-linecap="round"/>')
		"hide_vest":
			return _framed("basic", '<path d="M40 30 L54 26 L64 42 L74 26 L88 30 L98 50 L90 56 V104 H38 V56 L30 50 Z" fill="url(#leather)"' + _o() + '/>'
				+ '<path d="M64 42 V104" stroke="#3a2210" stroke-width="3"/>'
				+ '<path d="M58 54 L70 60 M58 66 L70 72 M58 78 L70 84 M58 90 L70 96" stroke="#e8d8b0" stroke-width="2.5"/>'
				+ '<path d="M40 30 L54 26 L64 42 L74 26 L88 30 L80 40 L64 50 L48 40 Z" fill="#e2d2a8"' + _o(3) + '/>')
		"vigor_charm":
			return _framed("basic", '<path d="M36 16 Q64 52 92 16" stroke="url(#bronze)" stroke-width="4" fill="none"/>'
				+ '<circle cx="64" cy="44" r="6" fill="none" stroke="url(#gold)" stroke-width="4"/>'
				+ '<path d="M64 106 C40 88 28 74 32 60 C36 46 54 44 64 58 C74 44 92 46 96 60 C100 74 88 88 64 106 Z" fill="url(#blood)"' + _o() + '/>'
				+ '<path d="M64 98 C46 84 38 74 40 63 C43 53 56 52 64 63 C72 52 85 53 88 63 C90 74 82 84 64 98 Z" fill="none" stroke="url(#gold)" stroke-width="2.5"/>'
				+ '<ellipse cx="50" cy="64" rx="5" ry="3.5" fill="#ffffff" opacity="0.7"/>')
		"focus_pendant":
			return _framed("basic", '<path d="M34 16 Q64 50 94 16" stroke="url(#gold)" stroke-width="4" fill="none"/>'
				+ '<ellipse cx="64" cy="76" rx="30" ry="30" fill="url(#glowT)" opacity="0.6"/>'
				+ '<path d="M64 42 C80 58 86 72 84 84 C82 98 74 106 64 106 C54 106 46 98 44 84 C42 72 48 58 64 42 Z" fill="url(#mana)"' + _o() + '/>'
				+ '<path d="M52 48 H76 L72 58 H56 Z" fill="url(#gold)"' + _o(3) + '/>'
				+ '<path d="M56 80 C56 70 60 64 64 60" stroke="#e6f6ff" stroke-width="4" fill="none" stroke-linecap="round"/>')
		"runners_boots":
			return _framed("basic", '<path d="M48 22 H74 V68 L98 78 C106 81 108 92 100 96 H42 L44 68 Z" fill="url(#leather)"' + _o() + '/>'
				+ '<rect x="38" y="94" width="68" height="10" rx="4" fill="#3a2414"' + _o(3) + '/>'
				+ '<path d="M48 34 H74 M48 46 H74" stroke="#e0b070" stroke-width="3"/>'
				+ '<path d="M14 58 H34 M10 72 H32 M16 86 H36" stroke="#e8f4ff" stroke-width="4.5" stroke-linecap="round"/>')
		"stout_belt":
			return _framed("basic", '<path d="M12 54 Q64 66 116 54 V76 Q64 88 12 76 Z" fill="url(#leather)"' + _o() + '/>'
				+ '<rect x="46" y="46" width="36" height="38" rx="5" fill="url(#gold)"' + _o() + '/>'
				+ '<rect x="55" y="56" width="18" height="18" rx="2" fill="#3a2414"/>'
				+ '<path d="M64 56 V78" stroke="url(#metal)" stroke-width="4"/>'
				+ '<circle cx="24" cy="66" r="3" fill="#f2c14e"/><circle cx="34" cy="68" r="3" fill="#f2c14e"/><circle cx="94" cy="68" r="3" fill="#f2c14e"/><circle cx="104" cy="66" r="3" fill="#f2c14e"/>')
		"sage_circlet":
			return _framed("basic", '<ellipse cx="64" cy="74" rx="42" ry="20" fill="none" stroke="' + D + '" stroke-width="12"/>'
				+ '<ellipse cx="64" cy="74" rx="42" ry="20" fill="none" stroke="url(#gold)" stroke-width="6"/>'
				+ '<path d="M36 56 L52 50 L56 60 Z M92 56 L76 50 L72 60 Z" fill="url(#gold)"' + _o(3) + '/>'
				+ '<ellipse cx="64" cy="50" rx="22" ry="20" fill="url(#glowT)" opacity="0.6"/>'
				+ '<path d="M64 32 L77 50 L64 66 L51 50 Z" fill="url(#teal)"' + _o() + '/>')
		# ---------------------------------------------------------- advanced items
		"emberbrand":
			return _framed("adv", '<ellipse cx="64" cy="54" rx="30" ry="44" fill="url(#glowE)"/>'
				+ '<path d="M58 96 L56 30 L64 12 L72 30 L70 96 Z" fill="url(#metal)"' + _o() + '/>'
				+ '<path d="M64 20 V92" stroke="#6a7080" stroke-width="2"/>'
				+ _flame(50, 84, 0.9) + _flame(78, 70, 0.8)
				+ '<rect x="36" y="94" width="56" height="10" rx="3" fill="url(#gold)"' + _o() + '/>'
				+ '<rect x="58" y="104" width="12" height="14" fill="#5a3020"' + _o(3) + '/>')
		"bulwark_plate":
			return _framed("adv", '<path d="M32 30 Q64 20 96 30 L104 50 L94 60 V96 Q64 112 34 96 V60 L24 50 Z" fill="url(#metal)"' + _o() + '/>'
				+ '<path d="M64 26 V104" stroke="#5a606c" stroke-width="3"/>'
				+ '<path d="M32 30 Q64 20 96 30 L92 40 Q64 32 36 40 Z" fill="url(#gold)"' + _o(3) + '/>'
				+ '<path d="M40 70 Q64 80 88 70 M42 84 Q64 94 86 84" stroke="#5a606c" stroke-width="3" fill="none"/>'
				+ '<circle cx="64" cy="58" r="7" fill="url(#gold)"' + _o(2.5) + '/>')
		"wayfarer_treads":
			return _framed("adv", '<path d="M24 100 C44 92 56 104 76 96 C92 90 104 98 114 94" stroke="#3ff0dc" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.8"/>'
				+ '<path d="M44 26 H68 V68 L92 78 C100 81 102 92 94 94 H38 L40 68 Z" fill="url(#leather)"' + _o() + '/>'
				+ '<rect x="34" y="92" width="64" height="9" rx="4" fill="#2a1a10"' + _o(3) + '/>'
				+ '<path d="M44 36 H68" stroke="url(#gold)" stroke-width="4"/>'
				+ '<path d="M98 22 L102 34 L114 38 L102 42 L98 54 L94 42 L82 38 L94 34 Z" fill="url(#gold)"' + _o(2.5) + '/>')
		"hivecore_sigil":
			return _framed("adv", '<path d="M64 16 L104 39 V85 L64 108 L24 85 V39 Z" fill="#1e2a1a"' + _o() + '/>'
				+ '<path d="M64 22 L99 42 V82 L64 102 L29 82 V42 Z" fill="none" stroke="url(#gold)" stroke-width="4"/>'
				+ '<circle cx="64" cy="62" r="24" fill="url(#glowA)"/>'
				+ '<circle cx="64" cy="62" r="14" fill="url(#acid)"' + _o(3) + '/>'
				+ '<ellipse cx="64" cy="62" rx="4" ry="10" fill="#0e1a0a"/>'
				+ '<path d="M64 22 V36 M64 88 V102 M29 42 L41 49 M87 75 L99 82 M29 82 L41 75 M87 49 L99 42" stroke="url(#gold)" stroke-width="3"/>')
		"bloodthirst_fang":
			return _framed("adv", '<path d="M42 18 C82 24 94 60 74 110 C70 80 58 56 38 40 Z" fill="url(#ivory)"' + _o() + '/>'
				+ '<path d="M38 22 L46 40" stroke="#5a3a2a" stroke-width="8" stroke-linecap="round"/>'
				+ '<path d="M58 30 C70 42 78 56 80 72 L75 74 C72 58 66 46 56 36 Z" fill="url(#blood)"/>'
				+ '<path d="M76 78 C79 86 80 90 76 92 C72 90 73 86 76 78 Z" fill="url(#blood)"' + _o(2) + '/>'
				+ '<path d="M66 92 C69 100 70 104 66 106 C62 104 63 100 66 92 Z" fill="url(#blood)"' + _o(2) + '/>')
		"wardens_aegis":
			return _framed("adv", '<path d="M64 12 L102 26 V60 C102 86 86 102 64 114 C42 102 26 86 26 60 V26 Z" fill="url(#metal)"' + _o() + '/>'
				+ '<path d="M64 22 L94 33 V60 C94 80 82 94 64 104 C46 94 34 80 34 60 V33 Z" fill="#3e4658" stroke="url(#gold)" stroke-width="3"/>'
				+ '<circle cx="64" cy="56" r="16" fill="url(#glowR)"/>'
				+ '<circle cx="64" cy="54" r="9" fill="#14080a"/><path d="M58 58 L54 84 H74 L70 58 Z" fill="#14080a"/>'
				+ '<circle cx="64" cy="54" r="9" fill="none" stroke="#ff3a26" stroke-width="2"/>')
		# ---------------------------------------------------------- consumables
		"healing_draught":
			return _flask("cons", "url(#blood)", "#e2343a", false)
		"mana_draught":
			return _flask("cons", "url(#mana)", "#3a8aff", true)
		"tome_of_might":
			return _framed("cons", '<path d="M26 32 L64 40 L102 32 V98 L64 106 L26 98 Z" fill="#8a2a1e"' + _o() + '/>'
				+ '<path d="M30 98 L64 104 L98 98 V102 L64 110 L30 102 Z" fill="#f0e2c0"' + _o(2.5) + '/>'
				+ '<path d="M64 40 V106" stroke="' + D + '" stroke-width="4"/>'
				+ '<circle cx="45" cy="68" r="12" fill="none" stroke="url(#gold)" stroke-width="3.5"/>'
				+ '<path d="M45 76 V60 M39 66 L45 58 L51 66" stroke="url(#gold)" stroke-width="3.5" fill="none" stroke-linecap="round"/>'
				+ '<circle cx="83" cy="68" r="12" fill="none" stroke="url(#gold)" stroke-width="3.5"/>'
				+ '<path d="M77 68 H89 M83 62 V74" stroke="url(#gold)" stroke-width="3.5"/>')
		"phoenix_feather":
			return _framed("cons", '<ellipse cx="68" cy="60" rx="38" ry="44" fill="url(#glowE)"/>'
				+ '<path d="M34 110 C38 80 52 50 86 20 C98 16 104 24 98 36 C84 64 62 88 34 110 Z" fill="url(#fire)"' + _o() + '/>'
				+ '<path d="M34 110 C52 84 70 56 94 26" stroke="#fff6c8" stroke-width="3" fill="none"/>'
				+ '<path d="M54 76 L44 70 M62 66 L52 58 M70 56 L62 46 M64 82 L70 90 M72 72 L80 78 M80 60 L88 64" stroke="#a83a10" stroke-width="2.5"/>')
		# ---------------------------------------------------------- portraits
		"portrait_ashwarden":
			return _framed("ash", '<ellipse cx="64" cy="66" rx="44" ry="40" fill="url(#glowE)" opacity="0.5"/>'
				+ '<path d="M16 116 C16 96 30 86 46 84 H82 C98 86 112 96 112 116 Z" fill="url(#stone)"' + _o() + '/>'
				+ '<ellipse cx="30" cy="90" rx="20" ry="14" fill="url(#stone)"' + _o() + '/>'
				+ '<ellipse cx="98" cy="90" rx="20" ry="14" fill="url(#stone)"' + _o() + '/>'
				+ '<rect x="54" y="96" width="20" height="10" fill="#ff8a2a"' + _o(3) + '/>'
				+ '<path d="M38 40 C38 22 50 16 64 16 C78 16 90 22 90 40 V80 H38 Z" fill="url(#metal)"' + _o() + '/>'
				+ '<rect x="44" y="44" width="40" height="28" fill="#2e2a28"' + _o(3) + '/>'
				+ '<ellipse cx="64" cy="54" rx="22" ry="8" fill="url(#glowE)"/>'
				+ '<rect x="46" y="51" width="36" height="6" rx="2" fill="#ffc050"/>'
				+ '<path d="M54 16 L62 4 H70 L74 16 Z" fill="url(#bronze)"' + _o(3) + '/>')
		"portrait_riftdancer":
			return _framed("rift", '<ellipse cx="64" cy="60" rx="44" ry="40" fill="url(#glowT)" opacity="0.35"/>'
				+ '<path d="M18 116 C18 96 34 86 48 84 H80 C94 86 110 96 110 116 Z" fill="#261c36"' + _o() + '/>'
				+ '<path d="M30 92 C48 84 80 84 100 96 L104 104 C80 96 52 96 28 104 Z" fill="url(#teal)"' + _o(3) + '/>'
				+ '<path d="M64 12 C88 14 96 38 94 60 C92 76 84 86 64 88 C44 86 36 76 34 60 C32 38 40 14 64 12 Z" fill="url(#hood)"' + _o() + '/>'
				+ '<path d="M64 12 C74 8 90 10 104 18 C96 20 90 24 88 30 Z" fill="url(#hood)"' + _o(3) + '/>'
				+ '<path d="M64 34 C78 36 82 50 80 62 C78 72 72 78 64 78 C56 78 50 72 48 62 C46 50 50 36 64 34 Z" fill="#0a0810"/>'
				+ '<path d="M53 56 L60 58 M75 56 L68 58" stroke="#3ff0dc" stroke-width="4" stroke-linecap="round"/>'
				+ '<ellipse cx="64" cy="57" rx="16" ry="5" fill="url(#glowT)"/>')
		"portrait_hivemother":
			return _framed("hive", '<ellipse cx="64" cy="58" rx="44" ry="40" fill="url(#glowA)" opacity="0.35"/>'
				+ '<path d="M18 116 C18 98 34 88 50 86 H78 C94 88 110 98 110 116 Z" fill="url(#chit)"' + _o() + '/>'
				+ '<path d="M50 90 C56 100 72 100 78 90 L74 112 H54 Z" fill="url(#ivory)"' + _o(3) + '/>'
				+ '<path d="M36 32 L40 10 L50 28 Z M50 26 L56 4 L62 24 Z M66 24 L72 4 L78 26 Z M78 28 L88 10 L92 32 Z" fill="url(#ivory)"' + _o(3) + '/>'
				+ '<circle cx="40" cy="12" r="3" fill="#9cff3a"/><circle cx="56" cy="6" r="3" fill="#9cff3a"/><circle cx="72" cy="6" r="3" fill="#9cff3a"/><circle cx="88" cy="12" r="3" fill="#9cff3a"/>'
				+ '<path d="M64 24 C84 24 92 40 90 56 C88 72 78 84 64 86 C50 84 40 72 38 56 C36 40 44 24 64 24 Z" fill="url(#chit)"' + _o() + '/>'
				+ '<path d="M64 44 C76 46 80 58 76 68 C72 76 68 80 64 80 C60 80 56 76 52 68 C48 58 52 46 64 44 Z" fill="url(#ivory)"' + _o(3) + '/>'
				+ '<ellipse cx="54" cy="54" rx="6" ry="4.5" fill="#9cff3a" transform="rotate(20 54 54)"/><ellipse cx="74" cy="54" rx="6" ry="4.5" fill="#9cff3a" transform="rotate(-20 74 54)"/>'
				+ '<path d="M58 78 L52 90 M70 78 L76 90" stroke="url(#ivory)" stroke-width="4" stroke-linecap="round"/>')
		# ---------------------------------------------------------- misc (unframed)
		"gold":
			return _plain('<ellipse cx="54" cy="94" rx="34" ry="12" fill="url(#gold)"' + _o() + '/>'
				+ '<ellipse cx="54" cy="80" rx="34" ry="12" fill="url(#gold)"' + _o() + '/>'
				+ '<ellipse cx="54" cy="66" rx="34" ry="12" fill="url(#gold)"' + _o() + '/>'
				+ '<ellipse cx="88" cy="58" rx="22" ry="26" fill="url(#gold)"' + _o() + '/>'
				+ '<ellipse cx="88" cy="58" rx="13" ry="16" fill="none" stroke="#a8641a" stroke-width="3"/>'
				+ '<path d="M88 48 V68" stroke="#a8641a" stroke-width="4"/>')
		"life":
			return _plain('<ellipse cx="64" cy="66" rx="52" ry="50" fill="url(#glowR)" opacity="0.6"/>'
				+ '<path d="M64 110 C34 88 16 70 22 48 C28 28 52 24 64 44 C76 24 100 28 106 48 C112 70 94 88 64 110 Z" fill="url(#blood)"' + _o(6) + '/>'
				+ '<ellipse cx="44" cy="52" rx="9" ry="6" fill="#ffffff" opacity="0.55"/>')
		"attack":
			return _plain('<path d="M28 100 L84 28 L104 20 L98 42 L36 106 Z" fill="url(#metal)"' + _o(6) + '/>'
				+ '<path d="M22 82 L46 106" stroke="' + D + '" stroke-width="16" stroke-linecap="round"/>'
				+ '<path d="M22 82 L46 106" stroke="url(#gold)" stroke-width="9" stroke-linecap="round"/>'
				+ '<path d="M30 98 L16 112" stroke="' + D + '" stroke-width="13" stroke-linecap="round"/>'
				+ '<path d="M30 98 L16 112" stroke="#6a4222" stroke-width="7" stroke-linecap="round"/>')
		"armor":
			return _plain('<path d="M64 10 L106 24 V60 C106 88 88 106 64 118 C40 106 22 88 22 60 V24 Z" fill="url(#metal)"' + _o(6) + '/>'
				+ '<path d="M64 24 L92 34 V60 C92 80 80 94 64 102 Z" fill="#6a7284"/>'
				+ '<path d="M64 10 V118" stroke="' + D + '" stroke-width="3"/>')
		"speed":
			return _plain('<path d="M18 30 L50 64 L18 98 H40 L72 64 L40 30 Z" fill="url(#teal)"' + _o(5) + '/>'
				+ '<path d="M54 30 L86 64 L54 98 H76 L108 64 L76 30 Z" fill="url(#teal)"' + _o(5) + '/>')
		"pause":
			return _plain('<rect x="28" y="20" width="26" height="88" rx="7" fill="#f4ead8"' + _o(6) + '/>'
				+ '<rect x="74" y="20" width="26" height="88" rx="7" fill="#f4ead8"' + _o(6) + '/>')
		"shop":
			return _plain('<path d="M40 40 C36 30 46 22 52 30 L64 36 L76 30 C82 22 92 30 88 40 Z" fill="url(#leather)"' + _o(5) + '/>'
				+ '<path d="M38 42 H90 C108 60 112 82 104 98 C98 110 30 110 24 98 C16 82 20 60 38 42 Z" fill="url(#leather)"' + _o(5) + '/>'
				+ '<path d="M38 46 H90" stroke="url(#gold)" stroke-width="6"/>'
				+ '<circle cx="64" cy="78" r="17" fill="url(#gold)"' + _o(4) + '/>'
				+ '<path d="M64 68 V88" stroke="#a8641a" stroke-width="4"/>')
		_:
			return _framed("basic", '<path d="M64 26 L94 64 L64 102 L34 64 Z" fill="url(#bronze)"' + _o() + '/>'
				+ '<path d="M64 42 V86 M50 64 H78" stroke="#ffd27a" stroke-width="5" stroke-linecap="round"/>')

static func _flask(theme: String, liquid: String, col: String, tall: bool) -> String:
	var body := ""
	var liq := ""
	if tall:
		body = 'M54 20 H74 V38 L90 54 V98 C90 106 84 110 76 110 H52 C44 110 38 106 38 98 V54 L54 38 Z'
		liq = 'M40 66 C54 60 72 72 88 64 V98 C88 104 84 108 76 108 H52 C44 108 40 104 40 98 Z'
	else:
		body = 'M54 22 H74 V40 C92 48 98 64 96 78 C94 98 80 110 64 110 C48 110 34 98 32 78 C30 64 36 48 54 40 Z'
		liq = 'M35 72 C50 64 78 80 93 70 C93 96 80 107 64 107 C48 107 35 96 35 72 Z'
	return _framed(theme, '<ellipse cx="64" cy="80" rx="40" ry="34" fill="' + col + '" opacity="0.25"/>'
		+ '<path d="' + body + '" fill="#dceaf4" fill-opacity="0.3"' + _o() + '/>'
		+ '<path d="' + liq + '" fill="' + liquid + '"/>'
		+ '<path d="' + body + '" fill="none"' + _o() + '/>'
		+ '<rect x="51" y="12" width="26" height="14" rx="3" fill="url(#wood)"' + _o(3) + '/>'
		+ '<path d="M46 64 C44 74 44 84 48 94" stroke="#ffffff" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.7"/>'
		+ '<circle cx="70" cy="86" r="3" fill="#ffffff" opacity="0.6"/><circle cx="78" cy="78" r="2" fill="#ffffff" opacity="0.6"/>')
