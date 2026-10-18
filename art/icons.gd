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
	"sang": ["#a0182a", "#1e0408", "#ff6070"],
	"snare": ["#6a7020", "#121405", "#e8f070"],
	"twin": ["#5a2c90", "#10061e", "#e0a0ff"],
	"grave": ["#2a6a5a", "#06120e", "#b0ffe0"],
	"stone": ["#9a6a34", "#1c1006", "#ffc070"],
	"gun": ["#245a90", "#060e1c", "#a0e0ff"],
	"sun": ["#b08a20", "#1e1404", "#fff0a0"],
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
<linearGradient id="olive" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4ffb0"/><stop offset="0.5" stop-color="#c8d24a"/><stop offset="1" stop-color="#6a7014"/></linearGradient>
<linearGradient id="mint" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e6fff4"/><stop offset="0.5" stop-color="#8affc8"/><stop offset="1" stop-color="#2a8a64"/></linearGradient>
<linearGradient id="sand" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f0cc98"/><stop offset="0.5" stop-color="#c8945a"/><stop offset="1" stop-color="#6a4626"/></linearGradient>
<linearGradient id="sun" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fffbe0"/><stop offset="0.5" stop-color="#ffe680"/><stop offset="1" stop-color="#e8a020"/></linearGradient>
<radialGradient id="glowC" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ff9aa4" stop-opacity="0.9"/><stop offset="1" stop-color="#e0263c" stop-opacity="0"/></radialGradient>
<radialGradient id="glowO" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#f4ffb0" stop-opacity="0.9"/><stop offset="1" stop-color="#c8d24a" stop-opacity="0"/></radialGradient>
<radialGradient id="glowV" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ecc8ff" stop-opacity="0.9"/><stop offset="1" stop-color="#c86bff" stop-opacity="0"/></radialGradient>
<radialGradient id="glowM" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#d8fff0" stop-opacity="0.9"/><stop offset="1" stop-color="#8affc8" stop-opacity="0"/></radialGradient>
<radialGradient id="glowS" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ffe0a8" stop-opacity="0.9"/><stop offset="1" stop-color="#ffb040" stop-opacity="0"/></radialGradient>
<radialGradient id="glowB" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#d0f0ff" stop-opacity="0.9"/><stop offset="1" stop-color="#4fb8ff" stop-opacity="0"/></radialGradient>
<radialGradient id="glowY" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#fffbe0" stop-opacity="0.95"/><stop offset="1" stop-color="#ffd040" stop-opacity="0"/></radialGradient>
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
		"gold", "life", "attack", "armor", "speed", "pause", "shop"] + WAVE2_IDS

const WAVE2_IDS := ["crimson_cleave", "blood_rush", "hemorrhage", "undying_pact",
	"snare_trap", "blast_charge", "tripwire", "killing_field",
	"spirit_lance", "moonwell", "rend", "pounce", "shift", "twin_fury",
	"raise_dead", "corpse_blast", "grave_chill", "open_graves",
	"rock_shove", "stone_ridge", "quake", "avalanche",
	"hot_reload", "scattershot", "mortar", "deadeye",
	"sunbeam", "solar_flare", "sanctum", "dawn_lance",
	"portrait_sanguine", "portrait_snarewright", "portrait_twinhide", "portrait_gravekeeper",
	"portrait_stoneshaper", "portrait_gunsmith", "portrait_sunspeaker"]

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
			var w2 := _svg_wave2(id)
			if w2 != "":
				return w2
			return _framed("basic", '<path d="M64 26 L94 64 L64 102 L34 64 Z" fill="url(#bronze)"' + _o() + '/>'
				+ '<path d="M64 42 V86 M50 64 H78" stroke="#ffd27a" stroke-width="5" stroke-linecap="round"/>')


## Wave-2 hero icons (skills + portraits). Returns "" for unknown ids.
static func _svg_wave2(id: String) -> String:
	var O := _o()
	match id:
		# ---------------------------------------------------------- Sanguine (crimson)
		"crimson_cleave":
			return _framed("sang", '<ellipse cx="64" cy="64" rx="46" ry="42" fill="url(#glowC)" opacity="0.6"/>'
				+ '<path d="M16 96 C26 46 62 20 112 22 C74 34 46 60 36 104 Z" fill="url(#blood)"' + O + '/>'
				+ '<path d="M30 88 C42 54 66 36 98 28" stroke="#ffd0d0" stroke-width="3.5" fill="none" stroke-linecap="round"/>'
				+ '<path d="M70 70 L104 104 M64 76 L58 70 L76 64 L82 70 Z" stroke="' + D + '" stroke-width="4" fill="url(#metal)" stroke-linejoin="round"/>'
				+ '<path d="M70 70 L104 104" stroke="url(#metal)" stroke-width="9" stroke-linecap="round"/>'
				+ '<path d="M70 70 L104 104" stroke="' + D + '" stroke-width="2"/>'
				+ _drop(96, 52, 0.8) + _drop(84, 40, 0.6) + _drop(108, 66, 0.55))
		"blood_rush":
			var ch := ""
			for i in 3:
				var x := 30.0 + i * 24.0
				ch += '<path d="M%s 34 L%s 64 L%s 94 L%s 94 L%s 64 L%s 34 Z" fill="url(#blood)" opacity="%s"%s/>' % [x, x + 28, x, x + 14, x + 42, x + 14, 0.5 + i * 0.25, _o(3.5)]
			return _framed("sang", '<ellipse cx="80" cy="64" rx="40" ry="34" fill="url(#glowC)" opacity="0.7"/>'
				+ '<path d="M12 50 H34 M8 64 H30 M14 78 H34" stroke="#ff8a90" stroke-width="5" stroke-linecap="round"/>' + ch
				+ _drop(46, 104, 0.6) + _drop(66, 108, 0.5))
		"hemorrhage":
			return _framed("sang", '<ellipse cx="64" cy="54" rx="42" ry="34" fill="url(#glowC)" opacity="0.55"/>'
				+ '<path d="M24 40 C50 30 80 46 104 36 C84 60 50 52 24 40 Z" fill="#4a0810"' + O + '/>'
				+ '<path d="M34 42 C54 38 76 46 94 40" stroke="#ff4a5a" stroke-width="4" fill="none" stroke-linecap="round"/>'
				+ _drop(44, 74, 1.1) + _drop(66, 92, 1.4) + _drop(88, 72, 1.0)
				+ '<path d="M44 50 V62 M66 52 V74 M88 48 V60" stroke="url(#blood)" stroke-width="5" stroke-linecap="round"/>')
		"undying_pact":
			var links := ""
			for i in 6:
				var x := 18.0 + i * 18.4
				var y := 44.0 + i * 8.0
				links += '<ellipse cx="%s" cy="%s" rx="9" ry="5.5" transform="rotate(24 %s %s)" fill="none" stroke="%s" stroke-width="7"/><ellipse cx="%s" cy="%s" rx="9" ry="5.5" transform="rotate(24 %s %s)" fill="none" stroke="url(#metal)" stroke-width="3.5"/>' % [x, y, x, y, D, x, y, x, y]
			return _framed("sang", '<circle cx="64" cy="62" r="44" fill="url(#glowC)" opacity="0.7"/>'
				+ '<circle cx="64" cy="62" r="38" fill="none" stroke="#ff4a5a" stroke-width="3" stroke-dasharray="6 5"/>'
				+ '<path d="M64 104 C38 86 24 70 28 52 C32 36 54 32 64 48 C74 32 96 36 100 52 C104 70 90 86 64 104 Z" fill="url(#blood)"' + O + '/>'
				+ '<ellipse cx="48" cy="54" rx="7" ry="4.5" fill="#ffffff" opacity="0.6"/>' + links)
		# ---------------------------------------------------------- Snarewright (olive)
		"snare_trap":
			var teeth := ""
			for i in 7:
				var x := 30.0 + i * 11.3
				teeth += '<path d="M%s 62 L%s 46 L%s 62 Z" fill="#f0ecd8"%s/>' % [x - 4.5, x, x + 4.5, _o(2)]
				teeth += '<path d="M%s 66 L%s 82 L%s 66 Z" fill="#f0ecd8"%s/>' % [x - 4.5, x + 0.5, x + 4.5, _o(2)]
			return _framed("snare", '<ellipse cx="64" cy="64" rx="46" ry="30" fill="url(#glowO)" opacity="0.7"/>'
				+ '<path d="M18 64 C18 30 110 30 110 64 L100 64 C98 40 30 40 28 64 Z" fill="url(#metal)"' + O + '/>'
				+ '<path d="M18 64 C18 98 110 98 110 64 L100 64 C98 88 30 88 28 64 Z" fill="url(#metal)"' + O + '/>'
				+ teeth + '<ellipse cx="64" cy="64" rx="12" ry="5" fill="url(#olive)"' + _o(2.5) + '/>'
				+ '<rect x="6" y="58" width="16" height="12" rx="3" fill="#5a5448"' + _o(3) + '/><rect x="106" y="58" width="16" height="12" rx="3" fill="#5a5448"' + _o(3) + '/>')
		"blast_charge":
			return _framed("snare", '<ellipse cx="60" cy="74" rx="42" ry="36" fill="url(#glowO)" opacity="0.5"/>'
				+ '<circle cx="58" cy="76" r="32" fill="#2e2c2a"' + O + '/>'
				+ '<path d="M28 74 C40 82 76 82 88 74" stroke="url(#olive)" stroke-width="7" fill="none"/>'
				+ '<ellipse cx="46" cy="64" rx="9" ry="6" fill="#ffffff" opacity="0.35"/>'
				+ '<rect x="66" y="38" width="16" height="12" rx="2" fill="url(#bronze)" transform="rotate(30 74 44)"' + _o(3) + '/>'
				+ '<path d="M80 38 C86 28 96 30 98 22" stroke="#d8c08a" stroke-width="4" fill="none" stroke-linecap="round"/>'
				+ '<circle cx="100" cy="20" r="11" fill="url(#glowE)"/>'
				+ '<path d="M100 10 L103 17 L110 18 L104 22 L106 30 L100 25 L94 30 L96 22 L90 18 L97 17 Z" fill="#fff0a0"' + _o(1.5) + '/>')
		"tripwire":
			return _framed("snare", '<ellipse cx="64" cy="66" rx="48" ry="20" fill="url(#glowO)" opacity="0.6"/>'
				+ '<path d="M22 104 L28 34 L36 34 L34 104 Z" fill="url(#wood)"' + O + '/>'
				+ '<path d="M94 104 L92 34 L100 34 L106 104 Z" fill="url(#wood)"' + O + '/>'
				+ '<path d="M30 58 C50 64 78 64 98 58" stroke="' + D + '" stroke-width="7" fill="none"/>'
				+ '<path d="M30 58 C50 64 78 64 98 58" stroke="#f0ff9a" stroke-width="3" fill="none"/>'
				+ '<path d="M56 62 L50 52 M64 63 L64 50 M72 62 L78 52" stroke="#e8f070" stroke-width="3" stroke-linecap="round"/>'
				+ '<circle cx="64" cy="74" r="7" fill="url(#gold)"' + _o(2.5) + '/>')
		"killing_field":
			var traps := ""
			for p in [[34, 92], [94, 92], [26, 66], [102, 66], [64, 104]]:
				traps += '<ellipse cx="%s" cy="%s" rx="9" ry="5" fill="url(#metal)"%s/><circle cx="%s" cy="%s" r="2.5" fill="#e8f070"/>' % [p[0], p[1], _o(2.5), p[0], p[1]]
			return _framed("snare", '<ellipse cx="64" cy="74" rx="46" ry="32" fill="url(#glowO)" opacity="0.6"/>'
				+ '<ellipse cx="64" cy="74" rx="40" ry="26" fill="none" stroke="#c8d24a" stroke-width="3" stroke-dasharray="7 5"/>' + traps
				+ '<circle cx="64" cy="54" r="24" fill="none" stroke="' + D + '" stroke-width="9"/>'
				+ '<circle cx="64" cy="54" r="24" fill="none" stroke="#f0ff9a" stroke-width="4"/>'
				+ '<path d="M64 22 V40 M64 68 V86 M32 54 H50 M78 54 H96" stroke="' + D + '" stroke-width="8" stroke-linecap="round"/>'
				+ '<path d="M64 22 V40 M64 68 V86 M32 54 H50 M78 54 H96" stroke="#f0ff9a" stroke-width="3.5" stroke-linecap="round"/>'
				+ '<circle cx="64" cy="54" r="4" fill="#ff5a3a"/>')
		# ---------------------------------------------------------- Twinhide (violet)
		"spirit_lance":
			return _framed("twin", '<ellipse cx="64" cy="64" rx="48" ry="26" transform="rotate(-40 64 64)" fill="url(#glowV)"/>'
				+ '<path d="M18 110 L82 46" stroke="' + D + '" stroke-width="12" stroke-linecap="round"/>'
				+ '<path d="M18 110 L82 46" stroke="url(#viol)" stroke-width="6" stroke-linecap="round"/>'
				+ '<path d="M76 40 L112 16 L88 52 Z" fill="#f2e6ff"' + O + '/>'
				+ '<path d="M80 44 L106 22" stroke="#c86bff" stroke-width="2.5"/>'
				+ '<path d="M70 40 L64 30 M88 58 L98 62 M60 52 L50 48" stroke="#e8c8ff" stroke-width="3" stroke-linecap="round"/>')
		"moonwell":
			return _framed("twin", '<ellipse cx="64" cy="94" rx="44" ry="14" fill="url(#glowV)"/>'
				+ '<ellipse cx="64" cy="94" rx="40" ry="11" fill="#3a1e6a"' + O + '/>'
				+ '<ellipse cx="64" cy="92" rx="30" ry="6" fill="#c86bff" opacity="0.6"/>'
				+ '<path d="M78 18 C56 20 44 38 46 56 C48 74 66 84 84 78 C66 74 58 58 62 44 C64 32 70 24 78 18 Z" fill="#f4eeff"' + O + '/>'
				+ '<path d="M58 84 V92 M70 80 V90" stroke="#e8c8ff" stroke-width="3" stroke-linecap="round" opacity="0.8"/>'
				+ '<circle cx="96" cy="34" r="3" fill="#ffffff"/><circle cx="30" cy="40" r="2.5" fill="#ffffff"/><circle cx="100" cy="60" r="2" fill="#e8c8ff"/>')
		"rend":
			var cl := ""
			for i in 3:
				var dx := i * 20.0
				cl += '<path d="M%s 22 C%s 52 %s 80 %s 108 C%s 82 %s 52 %s 22 Z" fill="url(#viol)"%s/>' % [30 + dx, 44 + dx, 40 + dx, 30 + dx, 48 + dx, 52 + dx, 38 + dx, _o(3.5)]
				cl += '<path d="M%s 30 C%s 56 %s 80 %s 98" stroke="#ffffff" stroke-width="2" fill="none" opacity="0.8"/>' % [36 + dx, 46 + dx, 42 + dx, 36 + dx]
			return _framed("twin", '<ellipse cx="64" cy="64" rx="42" ry="44" fill="url(#glowV)" opacity="0.7"/>' + cl)
		"pounce":
			return _framed("twin", '<ellipse cx="64" cy="60" rx="46" ry="34" fill="url(#glowV)" opacity="0.6"/>'
				+ '<path d="M14 104 Q60 40 112 92" stroke="#c86bff" stroke-width="3" fill="none" stroke-dasharray="6 6"/>'
				+ '<path d="M22 72 C34 56 50 50 66 52 L82 42 L90 34 L92 44 L100 48 L96 56 C92 62 86 66 80 68 L94 86 L84 88 L70 74 C60 76 52 76 46 74 L34 90 L24 86 L34 70 Z" fill="#3a2a40"' + O + '/>'
				+ '<path d="M88 36 L84 20 L92 26 L96 14 L98 30" stroke="url(#ivory)" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
				+ '<circle cx="92" cy="46" r="3" fill="#e8b0ff"/>'
				+ '<path d="M94 86 L100 92 M84 88 L88 96 M34 90 L30 98 M24 86 L18 90" stroke="url(#ivory)" stroke-width="3" stroke-linecap="round"/>')
		"shift":
			return _framed("twin", '<circle cx="64" cy="62" r="44" fill="url(#glowV)" opacity="0.6"/>'
				+ '<path d="M64 20 C40 20 28 38 30 60 C32 84 46 100 64 104 Z" fill="url(#ivory)"' + O + '/>'
				+ '<path d="M64 20 C88 20 100 38 98 60 C96 84 82 100 64 104 Z" fill="#3a2a40"' + O + '/>'
				+ '<path d="M40 26 L30 8 L48 20 M88 26 L98 8 L80 20" stroke="url(#ivory)" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
				+ '<ellipse cx="48" cy="56" rx="7" ry="5" fill="#1a0e22"/><circle cx="48" cy="56" r="2.5" fill="#e8b0ff"/>'
				+ '<path d="M74 54 L88 50 L84 58 Z" fill="#e8b0ff"/>'
				+ '<path d="M46 80 H62 M66 80 L72 86 L78 80 L84 86 L90 78" stroke="' + D + '" stroke-width="3" fill="none"/>')
		"twin_fury":
			return _framed("twin", '<circle cx="64" cy="64" r="46" fill="url(#glowV)" opacity="0.6"/>'
				+ '<path d="M64 18 C38 18 18 38 18 64 C18 90 38 110 64 110 C50 100 44 82 64 64 C84 46 78 28 64 18 Z" fill="url(#viol)"' + O + '/>'
				+ '<path d="M64 18 C90 18 110 38 110 64 C110 90 90 110 64 110 C78 100 84 82 64 64 C44 46 50 28 64 18 Z" fill="url(#fire)"' + O + '/>'
				+ '<circle cx="54" cy="40" r="6" fill="#1a0e22"/><circle cx="54" cy="40" r="2.5" fill="#ffe0a0"/>'
				+ '<circle cx="74" cy="88" r="6" fill="#2a1406"/><circle cx="74" cy="88" r="2.5" fill="#e8b0ff"/>')
		# ---------------------------------------------------------- Gravekeeper (mint)
		"raise_dead":
			return _framed("grave", '<ellipse cx="64" cy="70" rx="40" ry="40" fill="url(#glowM)" opacity="0.7"/>'
				+ '<path d="M14 108 C30 88 98 88 114 108 Z" fill="#3a3028"' + O + '/>'
				+ '<path d="M50 96 L52 70 L46 50 L50 48 L56 66 L58 40 L63 40 L64 64 L68 38 L73 39 L72 64 L78 44 L83 46 L78 70 L86 58 L90 61 L80 80 L78 96 Z" fill="url(#ivory)"' + O + '/>'
				+ '<path d="M56 78 H74 M58 86 H74" stroke="#7a705a" stroke-width="2.5"/>'
				+ '<path d="M30 92 C26 80 34 74 30 64 M100 90 C104 80 96 72 100 62" stroke="#8affc8" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.8"/>')
		"corpse_blast":
			var rays := ""
			for i in 10:
				var a := TAU * i / 10.0
				rays += '<path d="M%s %s L%s %s" stroke="#b0ffe0" stroke-width="4" stroke-linecap="round"/>' % [64 + cos(a) * 34, 64 + sin(a) * 34, 64 + cos(a) * 50, 64 + sin(a) * 50]
			var ribs := ""
			for i in 4:
				var y := 48.0 + i * 11.0
				var w := 22.0 - i * 2.0
				ribs += '<path d="M64 %s C%s %s %s %s %s %s" stroke="url(#ivory)" stroke-width="5" fill="none" stroke-linecap="round"/>' % [y, 64 - w, y - 4, 64 - w - 4, y + 8, 64 - w + 2, y + 12]
				ribs += '<path d="M64 %s C%s %s %s %s %s %s" stroke="url(#ivory)" stroke-width="5" fill="none" stroke-linecap="round"/>' % [y, 64 + w, y - 4, 64 + w + 4, y + 8, 64 + w - 2, y + 12]
			return _framed("grave", '<circle cx="64" cy="64" r="46" fill="url(#glowM)"/>' + rays
				+ '<path d="M64 38 V98" stroke="' + D + '" stroke-width="10" stroke-linecap="round"/>'
				+ '<path d="M64 38 V98" stroke="url(#ivory)" stroke-width="5" stroke-linecap="round"/>' + ribs
				+ '<path d="M30 30 L38 36 M98 28 L90 36 M100 100 L92 92" stroke="url(#ivory)" stroke-width="4" stroke-linecap="round"/>')
		"grave_chill":
			return _framed("grave", '<ellipse cx="64" cy="62" rx="44" ry="40" fill="url(#glowM)" opacity="0.6"/>'
				+ '<path d="M64 20 C88 20 98 36 96 56 C95 66 90 72 86 76 V90 H42 V76 C38 72 33 66 32 56 C30 36 40 20 64 20 Z" fill="#dff8ee"' + O + '/>'
				+ '<ellipse cx="50" cy="56" rx="10" ry="9" fill="#0e3a2c"/><ellipse cx="78" cy="56" rx="10" ry="9" fill="#0e3a2c"/>'
				+ '<circle cx="50" cy="56" r="3.5" fill="#8affc8"/><circle cx="78" cy="56" r="3.5" fill="#8affc8"/>'
				+ '<path d="M60 72 L64 66 L68 72 Z" fill="#0e3a2c"/><path d="M50 82 V90 M58 82 V90 M66 82 V90 M74 82 V90" stroke="#0e3a2c" stroke-width="3"/>'
				+ '<path d="M64 20 L60 8 M44 26 L36 16 M84 26 L92 16" stroke="#b0ffe0" stroke-width="3" stroke-linecap="round"/>'
				+ '<path d="M18 104 C34 94 48 106 64 98 C80 90 94 104 110 96" stroke="#8affc8" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.8"/>')
		"open_graves":
			var st := ""
			for p in [[30, 0.85], [64, 1.0], [98, 0.85]]:
				var x: float = p[0]; var s: float = p[1]
				st += '<path d="M%s 52 C%s 52 %s 52 %s 104 H%s C%s 52 %s 52 %s 52 Z" transform="translate(0 %s)" fill="url(#mint)"%s/>' % [x, x - 2, x - 16 * s, x - 16 * s, x + 16 * s, x + 16 * s, x + 2, x, (1.0 - s) * 20.0, O]
				st += '<path d="M%s %s V%s M%s %s H%s" stroke="#1a3a30" stroke-width="3"/>' % [x, 68 + (1.0 - s) * 20, 86 + (1.0 - s) * 20, x - 6, 74 + (1.0 - s) * 20, x + 6]
				st += '<path d="M%s %s C%s %s %s %s %s %s" stroke="#b0ffe0" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.85"/>' % [x, 46 + (1.0 - s) * 20, x - 8, 36, x + 8, 30, x, 16 + (1.0 - s) * 10]
			return _framed("grave", '<ellipse cx="64" cy="64" rx="48" ry="40" fill="url(#glowM)" opacity="0.6"/>'
				+ '<rect x="12" y="102" width="104" height="10" fill="#3a3028"' + _o(3) + '/>' + st)
		# ---------------------------------------------------------- Stoneshaper (sandstone)
		"rock_shove":
			return _framed("stone", '<ellipse cx="74" cy="64" rx="40" ry="34" fill="url(#glowS)" opacity="0.6"/>'
				+ '<path d="M10 50 H34 M6 66 H30 M12 82 H34" stroke="#ffc070" stroke-width="5" stroke-linecap="round"/>'
				+ '<path d="M40 40 L84 34 L104 46 L108 82 L90 96 L46 92 L38 72 Z" fill="url(#sand)"' + O + '/>'
				+ '<path d="M84 34 L82 56 L104 58 M82 56 L86 76 L108 78 M86 76 L84 96" stroke="' + D + '" stroke-width="3" fill="none"/>'
				+ '<path d="M50 50 L62 62 L56 76 M70 46 L74 60" stroke="#ffb040" stroke-width="3.5" fill="none" stroke-linecap="round"/>')
		"stone_ridge":
			return _framed("stone", '<ellipse cx="64" cy="98" rx="50" ry="12" fill="url(#glowS)"/>'
				+ '<path d="M14 104 L20 70 L30 60 L36 74 L46 40 L58 36 L64 62 L74 30 L86 40 L90 62 L100 52 L114 70 L114 104 Z" fill="url(#sand)"' + O + '/>'
				+ '<path d="M26 102 L30 80 L34 90 M52 102 L54 60 L58 78 M78 102 L78 50 L84 72 M102 102 L104 76" stroke="#ffb040" stroke-width="3.5" fill="none" stroke-linecap="round"/>'
				+ '<path d="M30 30 L36 22 L40 30 Z M96 26 L102 18 L106 28 Z" fill="url(#sand)"' + _o(2.5) + '/>')
		"quake":
			return _framed("stone", '<ellipse cx="64" cy="80" rx="48" ry="26" fill="url(#glowS)" opacity="0.7"/>'
				+ '<ellipse cx="64" cy="80" rx="44" ry="20" fill="none" stroke="#ffc070" stroke-width="4" opacity="0.7"/>'
				+ '<ellipse cx="64" cy="80" rx="28" ry="12" fill="none" stroke="#ffc070" stroke-width="4"/>'
				+ '<path d="M64 80 L56 60 L66 46 L58 28 M64 80 L86 70 L96 56 M64 80 L40 88 L24 84 M64 80 L80 98 L98 104 M64 80 L50 104" stroke="' + D + '" stroke-width="9" fill="none" stroke-linejoin="round" stroke-linecap="round"/>'
				+ '<path d="M64 80 L56 60 L66 46 L58 28 M64 80 L86 70 L96 56 M64 80 L40 88 L24 84 M64 80 L80 98 L98 104 M64 80 L50 104" stroke="#ffb040" stroke-width="4" fill="none" stroke-linejoin="round" stroke-linecap="round"/>'
				+ '<path d="M30 40 L38 32 L42 42 Z M96 34 L104 30 L102 40 Z" fill="url(#sand)"' + _o(2.5) + '/>')
		"avalanche":
			return _framed("stone", '<ellipse cx="70" cy="66" rx="42" ry="38" fill="url(#glowS)" opacity="0.6"/>'
				+ '<path d="M8 104 L120 104" stroke="' + D + '" stroke-width="5"/>'
				+ '<path d="M12 46 H30 M8 62 H26 M12 78 H28" stroke="#ffc070" stroke-width="5" stroke-linecap="round"/>'
				+ '<circle cx="72" cy="66" r="36" fill="url(#sand)"' + O + '/>'
				+ '<path d="M50 44 L64 56 L58 72 L72 84 M80 38 L84 56 L100 62 M66 98 L72 84" stroke="#ffb040" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
				+ '<path d="M30 98 L36 90 L42 98 Z M108 96 L114 88 L118 98 Z" fill="url(#sand)"' + _o(2.5) + '/>')
		# ---------------------------------------------------------- Gunsmith (sky blue)
		"hot_reload":
			var ch := ""
			for i in 6:
				var a := TAU * i / 6.0 - PI / 2.0
				ch += '<circle cx="%s" cy="%s" r="9" fill="#14202e"%s/><circle cx="%s" cy="%s" r="5" fill="url(#gold)"/>' % [64 + cos(a) * 24, 64 + sin(a) * 24, _o(2.5), 64 + cos(a) * 24, 64 + sin(a) * 24]
			return _framed("gun", '<circle cx="64" cy="64" r="46" fill="url(#glowB)"/>'
				+ '<circle cx="64" cy="64" r="38" fill="url(#metal)"' + O + '/>' + ch
				+ '<circle cx="64" cy="64" r="7" fill="#4fb8ff"' + _o(2.5) + '/>'
				+ '<path d="M98 26 A48 48 0 0 1 110 74" stroke="#a0e0ff" stroke-width="5" fill="none" stroke-linecap="round"/>'
				+ '<path d="M104 70 L110 80 L116 68 Z" fill="#a0e0ff"/>')
		"scattershot":
			var pel := ""
			for i in 7:
				var a := deg_to_rad(-30.0 + i * 10.0)
				for j in 2:
					var r := 30.0 + j * 22.0 + (i % 2) * 8.0
					pel += '<circle cx="%s" cy="%s" r="%s" fill="#dff4ff"%s/>' % [44 + cos(a) * r, 70 + sin(a) * r, 4.5 - j, _o(1.5)]
			return _framed("gun", '<path d="M44 70 L116 30 L116 110 Z" fill="url(#glowB)" opacity="0.8"/>'
				+ '<rect x="8" y="58" width="40" height="22" rx="4" fill="url(#metal)"' + O + '/>'
				+ '<rect x="38" y="56" width="12" height="26" rx="2" fill="url(#gold)"' + _o(3) + '/>'
				+ '<ellipse cx="54" cy="69" rx="10" ry="14" fill="url(#glowE)"/>' + pel)
		"mortar":
			return _framed("gun", '<ellipse cx="80" cy="40" rx="30" ry="22" fill="url(#glowB)" opacity="0.6"/>'
				+ '<path d="M34 80 Q66 6 104 58" stroke="#a0e0ff" stroke-width="3.5" fill="none" stroke-dasharray="7 6"/>'
				+ '<rect x="22" y="60" width="26" height="46" rx="4" transform="rotate(30 35 83)" fill="url(#metal)"' + O + '/>'
				+ '<rect x="20" y="58" width="30" height="8" rx="2" transform="rotate(30 35 62)" fill="url(#gold)"' + _o(3) + '/>'
				+ '<path d="M12 110 H62 L54 98 H20 Z" fill="url(#wood)"' + _o(3) + '/>'
				+ '<circle cx="100" cy="54" r="10" fill="#2a2c32"' + _o(3) + '/><circle cx="96" cy="50" r="3" fill="#4fb8ff"/>')
		"deadeye":
			return _framed("gun", '<circle cx="64" cy="64" r="46" fill="url(#glowB)" opacity="0.6"/>'
				+ '<path d="M24 64 C36 44 92 44 104 64 C92 84 36 84 24 64 Z" fill="#eef6ff"' + O + '/>'
				+ '<circle cx="64" cy="64" r="15" fill="url(#mana)"' + _o(3) + '/><circle cx="64" cy="64" r="6" fill="#0a1220"/>'
				+ '<circle cx="64" cy="64" r="36" fill="none" stroke="' + D + '" stroke-width="8"/>'
				+ '<circle cx="64" cy="64" r="36" fill="none" stroke="#a0e0ff" stroke-width="3.5"/>'
				+ '<path d="M64 14 V36 M64 92 V114 M14 64 H36 M92 64 H114" stroke="' + D + '" stroke-width="7" stroke-linecap="round"/>'
				+ '<path d="M64 14 V36 M64 92 V114 M14 64 H36 M92 64 H114" stroke="#ff5a3a" stroke-width="3" stroke-linecap="round"/>')
		# ---------------------------------------------------------- Sunspeaker (sun gold)
		"sunbeam":
			return _framed("sun", '<path d="M50 70 L120 40 L120 100 Z" fill="url(#glowY)"/>'
				+ '<path d="M54 66 L118 52 V88 L54 74 Z" fill="#fff6c0" opacity="0.9"/>'
				+ '<path d="M14 98 L30 74 C32 62 38 56 44 56 L56 58 C62 60 62 66 56 68 L48 68 L60 70 C66 72 64 78 58 78 L44 80 C40 90 34 96 26 106 Z" fill="#c8885a"' + O + '/>'
				+ '<circle cx="56" cy="70" r="10" fill="url(#glowY)"/>'
				+ '<path d="M78 46 L84 34 M96 46 L106 38 M80 94 L86 106" stroke="#ffe680" stroke-width="3.5" stroke-linecap="round"/>')
		"solar_flare":
			var r2 := ""
			for i in 12:
				var a := TAU * i / 12.0
				var l := 40.0 if i % 2 == 0 else 32.0
				r2 += '<path d="M%s %s L%s %s L%s %s Z" fill="url(#sun)"%s/>' % [64 + cos(a - 0.12) * 20, 56 + sin(a - 0.12) * 20, 64 + cos(a) * l, 56 + sin(a) * l, 64 + cos(a + 0.12) * 20, 56 + sin(a + 0.12) * 20, _o(2)]
			return _framed("sun", '<ellipse cx="64" cy="100" rx="48" ry="12" fill="url(#glowY)"/>'
				+ '<ellipse cx="64" cy="100" rx="38" ry="8" fill="none" stroke="#fff0a0" stroke-width="3"/>'
				+ '<circle cx="64" cy="56" r="42" fill="url(#glowY)" opacity="0.7"/>' + r2
				+ '<circle cx="64" cy="56" r="20" fill="url(#sun)"' + O + '/>'
				+ '<circle cx="64" cy="56" r="11" fill="#fffbe0"/>')
		"sanctum":
			return _framed("sun", '<ellipse cx="64" cy="94" rx="46" ry="14" fill="url(#glowY)"/>'
				+ '<rect x="22" y="34" width="12" height="62" fill="#fff6c0" opacity="0.55"/><rect x="58" y="24" width="12" height="72" fill="#fff6c0" opacity="0.7"/><rect x="94" y="34" width="12" height="62" fill="#fff6c0" opacity="0.55"/>'
				+ '<ellipse cx="64" cy="94" rx="42" ry="12" fill="none" stroke="' + D + '" stroke-width="9"/>'
				+ '<ellipse cx="64" cy="94" rx="42" ry="12" fill="none" stroke="url(#gold)" stroke-width="5"/>'
				+ '<ellipse cx="64" cy="30" rx="22" ry="7" fill="none" stroke="' + D + '" stroke-width="8"/>'
				+ '<ellipse cx="64" cy="30" rx="22" ry="7" fill="none" stroke="#fff0a0" stroke-width="4"/>'
				+ '<path d="M64 46 L70 58 L64 70 L58 58 Z" fill="url(#sun)"' + _o(2.5) + '/>')
		"dawn_lance":
			return _framed("sun", '<path d="M14 92 A50 50 0 0 1 114 92 Z" fill="url(#glowY)"/>'
				+ '<path d="M34 92 A30 30 0 0 1 94 92 Z" fill="url(#sun)"' + O + '/>'
				+ '<path d="M10 92 H118" stroke="' + D + '" stroke-width="5"/>'
				+ '<path d="M8 58 L96 52 L120 58 L96 64 Z" fill="#fffbe0"' + O + '/>'
				+ '<path d="M12 58 H100" stroke="#ffd040" stroke-width="2.5"/>'
				+ '<path d="M30 44 H60 M40 72 H70" stroke="#fff0a0" stroke-width="3" stroke-linecap="round" opacity="0.8"/>')
		# ---------------------------------------------------------- portraits
		"portrait_sanguine":
			return _framed("sang", '<ellipse cx="64" cy="62" rx="44" ry="40" fill="url(#glowC)" opacity="0.45"/>'
				+ '<path d="M14 116 C14 96 30 86 46 84 H82 C98 86 114 96 114 116 Z" fill="#3e3539"' + O + '/>'
				+ '<ellipse cx="26" cy="92" rx="22" ry="13" fill="#5a4e54"' + O + '/>'
				+ '<path d="M12 86 L4 64 L20 80 M22 82 L20 58 L30 80" fill="url(#ivory)"' + _o(2.5) + '/>'
				+ '<ellipse cx="102" cy="94" rx="16" ry="11" fill="#5a4e54"' + O + '/>'
				+ '<path d="M52 84 L64 112 L76 84 Z" fill="url(#blood)"' + _o(3) + '/>'
				+ '<path d="M38 42 C38 24 50 18 64 18 C78 18 90 24 90 42 V82 H38 Z" fill="#4a4046"' + O + '/>'
				+ '<path d="M38 30 C30 22 26 12 30 4 C36 14 42 18 46 24 Z M90 30 C98 22 102 12 98 4 C92 14 86 18 82 24 Z" fill="url(#ivory)"' + _o(3) + '/>'
				+ '<path d="M44 50 H84 V58 H70 V76 H58 V58 H44 Z" fill="#14080a"' + _o(2) + '/>'
				+ '<path d="M47 53 H81 M64 58 V73" stroke="#ff2a40" stroke-width="3.5"/>'
				+ '<ellipse cx="64" cy="54" rx="22" ry="7" fill="url(#glowC)"/>')
		"portrait_snarewright":
			return _framed("snare", '<ellipse cx="64" cy="62" rx="44" ry="40" fill="url(#glowO)" opacity="0.35"/>'
				+ '<path d="M16 116 C16 96 32 86 48 84 H80 C96 86 112 96 112 116 Z" fill="url(#leather)"' + O + '/>'
				+ '<path d="M20 98 C36 82 92 82 108 98 C96 90 32 90 20 98 Z" fill="#e2cc9e"' + _o(3) + '/>'
				+ '<ellipse cx="64" cy="88" rx="40" ry="10" fill="#d8c090"' + _o(3) + '/>'
				+ '<path d="M64 26 C86 26 94 44 92 62 C90 78 82 86 64 88 C46 86 38 78 36 62 C34 44 42 26 64 26 Z" fill="#5e6230"' + O + '/>'
				+ '<path d="M64 46 C76 48 80 58 78 66 C76 74 70 78 64 78 C58 78 52 74 50 66 C48 58 52 48 64 46 Z" fill="#120e08"/>'
				+ '<path d="M50 70 H78 V80 H50 Z" fill="#5e6230"/>'
				+ '<path d="M54 61 L60 63 M74 61 L68 63" stroke="#e8f070" stroke-width="4" stroke-linecap="round"/>'
				+ '<path d="M40 30 C44 18 84 18 88 30 C80 40 48 40 40 30 Z" fill="#8a6e4c"' + _o(3) + '/>'
				+ '<path d="M44 26 L40 6 L54 20 Z M84 26 L88 6 L74 20 Z" fill="#8a6e4c"' + _o(3) + '/>'
				+ '<path d="M56 36 L64 48 L72 36" fill="#6a5238"' + _o(2) + '/><circle cx="56" cy="30" r="2.5" fill="#e8f070"/><circle cx="72" cy="30" r="2.5" fill="#e8f070"/>')
		"portrait_twinhide":
			return _framed("twin", '<ellipse cx="64" cy="62" rx="44" ry="40" fill="url(#glowV)" opacity="0.4"/>'
				+ '<path d="M16 116 C16 98 32 88 48 86 H80 C96 88 112 98 112 116 Z" fill="#342a62"' + O + '/>'
				+ '<path d="M22 100 C40 84 88 84 106 100 L102 92 C84 80 44 80 26 92 Z" fill="#5e7034"' + _o(3) + '/>'
				+ '<path d="M40 36 L24 8 L34 12 L30 2 L42 18 M88 36 L104 8 L94 12 L98 2 L86 18" stroke="url(#ivory)" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
				+ '<path d="M64 26 C86 26 94 44 92 62 C90 78 82 88 64 90 C46 88 38 78 36 62 C34 44 42 26 64 26 Z" fill="#1c1634"' + O + '/>'
				+ '<path d="M64 34 C80 34 84 46 82 56 C80 66 74 70 70 84 H58 C54 70 48 66 46 56 C44 46 48 34 64 34 Z" fill="url(#ivory)"' + _o(3) + '/>'
				+ '<ellipse cx="55" cy="54" rx="6" ry="5" fill="#1a0e22"/><ellipse cx="73" cy="54" rx="6" ry="5" fill="#1a0e22"/>'
				+ '<circle cx="55" cy="54" r="2.5" fill="#e8b0ff"/><circle cx="73" cy="54" r="2.5" fill="#e8b0ff"/>'
				+ '<path d="M61 76 H67" stroke="#1a0e22" stroke-width="3"/>')
		"portrait_gravekeeper":
			return _framed("grave", '<ellipse cx="64" cy="62" rx="44" ry="40" fill="url(#glowM)" opacity="0.35"/>'
				+ '<path d="M18 116 C18 96 34 86 50 84 H78 C94 86 110 96 110 116 Z" fill="#33323c"' + O + '/>'
				+ '<path d="M44 84 L54 104 L64 90 L74 104 L84 84 Z" fill="#1c1b22"' + _o(3) + '/>'
				+ '<circle cx="64" cy="96" r="3" fill="#8affc8"/>'
				+ '<path d="M64 36 C80 36 86 48 84 62 C82 76 74 86 64 88 C54 86 46 76 44 62 C42 48 48 36 64 36 Z" fill="#b4c2b0"' + O + '/>'
				+ '<ellipse cx="56" cy="58" rx="6" ry="5" fill="#0a0c0c"/><ellipse cx="72" cy="58" rx="6" ry="5" fill="#0a0c0c"/>'
				+ '<circle cx="56" cy="58" r="2.5" fill="#8affc8"/><circle cx="72" cy="58" r="2.5" fill="#8affc8"/>'
				+ '<path d="M64 60 L60 72 H66" stroke="#5a6458" stroke-width="2.5" fill="none"/><path d="M58 78 H70" stroke="#2a302a" stroke-width="2.5"/>'
				+ '<ellipse cx="64" cy="38" rx="52" ry="9" fill="#24222a"' + O + '/>'
				+ '<path d="M44 38 L46 12 H82 L84 38 Z" fill="#24222a"' + O + '/>'
				+ '<rect x="45" y="28" width="38" height="6" fill="#8affc8"/>')
		"portrait_stoneshaper":
			return _framed("stone", '<ellipse cx="64" cy="62" rx="44" ry="40" fill="url(#glowS)" opacity="0.4"/>'
				+ '<path d="M12 116 C12 96 30 86 46 84 H82 C98 86 116 96 116 116 Z" fill="#6e4e2e"' + O + '/>'
				+ '<path d="M8 96 L14 74 L34 70 L40 88 L28 100 Z M120 96 L114 74 L94 70 L88 88 L100 100 Z" fill="url(#sand)"' + O + '/>'
				+ '<path d="M22 80 L28 90 M106 80 L100 90" stroke="#ffb040" stroke-width="3"/>'
				+ '<path d="M64 26 C84 26 90 40 88 56 C86 66 82 70 80 72 H48 C46 70 42 66 40 56 C38 40 44 26 64 26 Z" fill="#b47c56"' + O + '/>'
				+ '<rect x="38" y="36" width="52" height="9" rx="2" fill="url(#sand)"' + _o(3) + '/>'
				+ '<path d="M64 36 L68 40 L64 44 L60 40 Z" fill="#ffb040"/>'
				+ '<path d="M52 54 H59 M69 54 H76" stroke="#ffb040" stroke-width="4" stroke-linecap="round"/>'
				+ '<path d="M42 64 C46 72 52 70 64 70 C76 70 82 72 86 64 C88 84 78 98 64 102 C50 98 40 84 42 64 Z" fill="#6a4026"' + O + '/>')
		"portrait_gunsmith":
			return _framed("gun", '<ellipse cx="64" cy="62" rx="44" ry="40" fill="url(#glowB)" opacity="0.35"/>'
				+ '<path d="M16 116 C16 96 32 86 48 84 H80 C96 86 112 96 112 116 Z" fill="#6a4228"' + O + '/>'
				+ '<path d="M40 84 L52 112 L64 92 L76 112 L88 84 Z" fill="#2c3a50"' + _o(3) + '/>'
				+ '<path d="M44 84 C52 92 76 92 84 84 L80 78 H48 Z" fill="#2e78b0"' + _o(3) + '/>'
				+ '<path d="M64 30 C82 30 88 44 86 60 C84 74 76 84 64 86 C52 84 44 74 42 60 C40 44 46 30 64 30 Z" fill="#d8a47c"' + O + '/>'
				+ '<path d="M42 50 C40 30 52 22 64 22 C78 22 90 30 86 50 C80 40 50 40 42 50 Z" fill="#3a2216"' + _o(3) + '/>'
				+ '<rect x="40" y="38" width="48" height="7" fill="#3a2418"/>'
				+ '<circle cx="54" cy="40" r="9" fill="url(#gold)"' + _o(3) + '/><circle cx="74" cy="40" r="9" fill="url(#gold)"' + _o(3) + '/>'
				+ '<circle cx="54" cy="40" r="5.5" fill="#4fb8ff"/><circle cx="74" cy="40" r="5.5" fill="#4fb8ff"/>'
				+ '<path d="M53 60 H59 M69 60 H75" stroke="#1a100a" stroke-width="3.5" stroke-linecap="round"/>'
				+ '<path d="M56 74 C60 71 68 71 72 74" stroke="#3a2216" stroke-width="4" fill="none" stroke-linecap="round"/>')
		"portrait_sunspeaker":
			var rays := ""
			for i in 12:
				var a := TAU * i / 12.0
				rays += '<path d="M%s %s L%s %s" stroke="url(#sun)" stroke-width="6" stroke-linecap="round"/>' % [64 + cos(a) * 36, 52 + sin(a) * 36, 64 + cos(a) * (50 if i % 2 == 0 else 44), 52 + sin(a) * (50 if i % 2 == 0 else 44)]
			return _framed("sun", '<circle cx="64" cy="52" r="48" fill="url(#glowY)" opacity="0.6"/>' + rays
				+ '<circle cx="64" cy="52" r="34" fill="none" stroke="' + D + '" stroke-width="9"/>'
				+ '<circle cx="64" cy="52" r="34" fill="none" stroke="url(#gold)" stroke-width="5"/>'
				+ '<path d="M16 116 C16 96 32 86 48 84 H80 C96 86 112 96 112 116 Z" fill="#f2ead8"' + O + '/>'
				+ '<path d="M34 92 C46 80 82 80 94 92 C82 104 46 104 34 92 Z" fill="url(#gold)"' + _o(3) + '/>'
				+ '<circle cx="64" cy="94" r="4" fill="#fff6c0"/>'
				+ '<path d="M64 26 C84 26 92 42 90 62 C88 80 78 88 64 88 C50 88 40 80 38 62 C36 42 44 26 64 26 Z" fill="#f2ead8"' + O + '/>'
				+ '<path d="M64 36 C76 36 82 46 80 60 C78 72 72 80 64 80 C56 80 50 72 48 60 C46 46 52 36 64 36 Z" fill="#9a6440"' + _o(3) + '/>'
				+ '<path d="M46 40 C54 30 74 30 82 40" stroke="url(#gold)" stroke-width="5" fill="none"/>'
				+ '<path d="M64 33 L67 38 L64 43 L61 38 Z" fill="#ff9a30"/>'
				+ '<path d="M55 58 H61 M67 58 H73" stroke="#fff0a0" stroke-width="3.5" stroke-linecap="round"/>')
	return ""

static func _drop(x: float, y: float, s: float) -> String:
	return '<path d="M%s %s C%s %s %s %s %s %s C%s %s %s %s %s %s C%s %s %s %s %s %s Z" fill="url(#blood)"%s/>' % [x, y - 12 * s,
		x + 4 * s, y - 6 * s, x + 7 * s, y - 2 * s, x + 7 * s, y + 2 * s,
		x + 7 * s, y + 8 * s, x - 7 * s, y + 8 * s, x - 7 * s, y + 2 * s,
		x - 7 * s, y - 2 * s, x - 4 * s, y - 6 * s, x, y - 12 * s, _o(2)]

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
