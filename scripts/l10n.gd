class_name L
extends RefCounted
## Localization: UI text is written in English and looked up in locale/<code>.json (English text -> translation).
## L.t("Play") for plain text, L.f("Wave %d", [n]) for format strings: the format string is the key.
## tools/l10n.py extracts every key and checks each language file. Labels and buttons also auto-translate
## text that exactly matches a key, so data strings shown as-is need no wrapper.

## Picker order: code, native name. The first is the source language.
const LANGS := [
	["en", "English"], ["es", "Español"], ["pt_BR", "Português (Brasil)"], ["fr", "Français"], ["de", "Deutsch"],
	["it", "Italiano"], ["ru", "Русский"], ["tr", "Türkçe"], ["id", "Bahasa Indonesia"], ["vi", "Tiếng Việt"],
	["th", "ไทย"], ["ar", "العربية"], ["ja", "日本語"], ["ko", "한국어"], ["zh_CN", "简体中文"], ["zh_TW", "繁體中文"],
]

## Glyph fallbacks for scripts the built-in font doesn't cover. Subsets made by tools/l10n.py fonts.
const FONTS := {
	"latin": "res://locale/fonts/noto_latin.ttf",
	"ja": "res://locale/fonts/noto_cjk_jp.otf", "ko": "res://locale/fonts/noto_cjk_kr.otf",
	"zh_CN": "res://locale/fonts/noto_cjk_sc.otf", "zh_TW": "res://locale/fonts/noto_cjk_tc.otf",
	"th": "res://locale/fonts/noto_thai.ttf", "ar": "res://locale/fonts/noto_arabic.ttf",
}

static var lang := "en"
static var _loaded := {}


static func t(s: String) -> String:
	if lang == "en" or s == "":
		return s
	var r := TranslationServer.translate(s)
	if r != s or not _digits.search(s):
		return r
	# text formatted before it got here ("Opens at wave 5"): look up its "%d" template, then put the numbers back
	if _cache.has(s):
		return _cache[s]
	var nums := []
	for m in _digits.search_all(s):
		nums.append(int(m.get_string()))
	var key := _digits.sub(s, "%d", true)
	var tk := TranslationServer.translate(key)
	if tk == key and key.contains("%"):   # "+30%" was formatted from "+%d%%"
		var k2 := key.replace("%", "%%").replace("%%d", "%d")
		tk = TranslationServer.translate(k2)
		if tk == k2:
			tk = key
	r = s if tk == key or tk.count("%d") != nums.size() else tk % nums
	if _cache.size() > 4000:
		_cache.clear()
	_cache[s] = r
	return r


static var _digits := RegEx.create_from_string("\\d+")
static var _cache := {}


static func f(fmt: String, args) -> String:
	if args is Dictionary:   # named placeholders, for sentences whose word order changes between languages
		return t(fmt).format(args)
	return t(fmt) % args


## The language to use: the saved choice, else the device's, else English.
static func setup(saved: String) -> void:
	set_lang(saved if has_lang(saved) else device_lang())


static func has_lang(code: String) -> bool:
	for l in LANGS:
		if l[0] == code:
			return true
	return false


static func device_lang() -> String:
	var loc := OS.get_locale()                      # e.g. "pt_BR", "zh_Hant_TW", "in_ID"
	var base := OS.get_locale_language()
	match base:
		"pt":
			return "pt_BR"
		"zh":
			return "zh_TW" if (loc.contains("Hant") or loc.contains("TW") or loc.contains("HK") or loc.contains("MO")) else "zh_CN"
		"in":
			return "id"                              # old Android code for Indonesian
	return base if has_lang(base) else "en"


static func lang_name(code: String) -> String:
	for l in LANGS:
		if l[0] == code:
			return l[1]
	return code


static func set_lang(code: String) -> void:
	lang = code if has_lang(code) else "en"
	_cache.clear()
	if lang != "en" and not _loaded.has(lang):
		var tr := Translation.new()
		tr.locale = lang
		var fa := FileAccess.open("res://locale/%s.json" % lang, FileAccess.READ)
		if fa:
			var d = JSON.parse_string(fa.get_as_text())
			if d is Dictionary:
				for k in d:
					if String(d[k]) != "":
						tr.add_message(k, d[k])
		TranslationServer.add_translation(tr)
		_loaded[lang] = tr
	TranslationServer.set_locale(lang)
	# Arabic text still shapes right to left, but the screen keeps its layout (stick on the left, skills on the right).
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.set_layout_direction(Window.LAYOUT_DIRECTION_LTR)
	_apply_fonts()


## The built-in font covers Latin and Cyrillic; other scripts fall back to bundled Noto subsets, with the
## current language's CJK font first so shared Han characters take that language's shapes.
static func _apply_fonts() -> void:
	var base := ThemeDB.fallback_font
	if base == null:
		return
	var fb: Array[Font] = []
	var order: Array = ["latin"]
	if FONTS.has(lang):
		order.append(lang)
	for code in FONTS:   # the rest still draw the language picker's native names
		if not order.has(code):
			order.append(code)
	for path in order.map(func(c): return FONTS[c]):
		if ResourceLoader.exists(path):
			fb.append(load(path))
	base.fallbacks = fb
