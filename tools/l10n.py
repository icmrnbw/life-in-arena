#!/usr/bin/env python3
"""Emberpit localization helper (see scripts/l10n.gd).

  python3 tools/l10n.py extract        list every UI string into locale/keys.json (English source text)
  python3 tools/l10n.py check          per language: missing / stale keys, broken placeholders
  python3 tools/l10n.py todo <lang>    write the keys <lang> still lacks to locale/todo_<lang>.json
  python3 tools/l10n.py merge <lang> <file.json>   add translations from a file into locale/<lang>.json
  python3 tools/l10n.py fonts          subset the bundled Noto fonts to the glyphs the translations use

Keys are the English strings themselves. They are found in L.t()/L.f() calls, widget factories (UIK.label,
UIK.button, ...), banners/toasts/hints, damage tags and the display fields of the data tables.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALE = os.path.join(ROOT, "locale")
LANGS = ["es", "pt_BR", "fr", "de", "it", "ru", "tr", "id", "vi", "th", "ar", "ja", "ko", "zh_CN", "zh_TW"]

STR = r'"((?:[^"\\\n]|\\.)*)"'
# data-table fields shown to the player
DATA_FIELDS = ["name", "desc", "title", "role", "tag", "playstyle", "text", "hint", "button", "unlock"]
DATA_FILES = ["scripts/data.gd", "scripts/modes.gd", "scripts/maps.gd", "scripts/skins.gd", "scripts/tutorial.gd",
              "scripts/delve.gd", "scripts/duel.gd", "scripts/weather.gd"]
# calls whose string arguments (all of them, also inside "a" if c else "b") are UI text
CALLS = ["L.t(", "L.f(", "UIK.label(", "UIK.button(", "UIK.icon_button(", "_toggle(", "banner_requested.emit(",
         "toast(", "toast.bind(", "hint_once("]
# constant tables whose values (or listed strings) are UI text
CONST_TABLES = ["CAPTAIN_NAMES", "BOSS_TITLES", "BOSS_HINTS", "NAMES", "FIRE_TAGS"]
# ids and other strings that are never shown
STOP = {"", "phys", "pure", "EMBERPIT", "TabBar", "Wave 1 / 20", "Opens", "x%d", "classic", "SmallLabel", "TitleLabel", "PrimaryButton", "SkillButton",
        "FramePanel", "DarkPanel", "XpBar", "FlowBar", "BossBar", "ShopItemButton", "BannerLabel", "gold", "life",
        "shop", "danger", "dim", "heal", "mana", "xp", "ember", "text", "frame", "str", "agi", "int"}


def unescape(s):
    return s.replace('\\"', '"').replace("\\'", "'").replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")


def call_args(src, start):
    """Text inside the parentheses that open at src[start-1]."""
    depth, i, ins = 1, start, False
    while i < len(src) and depth > 0:
        c = src[i]
        if ins:
            if c == "\\":
                i += 1
            elif c == '"':
                ins = False
        elif c == '"':
            ins = True
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        i += 1
    return src[start:i - 1]


def strip_comments(src):
    out = []
    for line in src.split("\n"):
        # drop "## doc" and "# comment" tails that are outside strings
        ins, cut = False, None
        for j, c in enumerate(line):
            if c == '"' and (j == 0 or line[j - 1] != "\\"):
                ins = not ins
            elif c == "#" and not ins:
                cut = j
                break
        out.append(line if cut is None else line[:cut])
    return "\n".join(out)


def shown(s):
    if s in STOP or len(s) <= 1 or s in HERO_NAMES:
        return False
    if "{" not in s and not re.search(r"[A-Za-z]", re.sub(r"%[-+]?\d*(?:\.\d+)?[dsf]|\{\w+\}", "", s)):
        return False   # pure layout: "%s  ·  %s", "x%d"
    if re.match(r"M[\d%]", s):
        return False   # SVG paths
    if re.fullmatch(r"[a-z0-9_]+", s) and s not in ("down", "beast", "owned", "locked", "hot", "physical", "magic", "mixed",
                                                  "not recorded", "not played"):
        return False   # ids, node and meta names
    if s.startswith("res://") or s.startswith("portrait_") or s.startswith("user://"):
        return False
    return True


HERO_NAMES = set()


def extract():
    keys = {}
    data = open(os.path.join(ROOT, "scripts/data.gd"), encoding="utf-8").read()
    HERO_NAMES.update(re.findall(r'"name": "([^"]+)", "title"', data))   # hero names stay as they are

    def add(s, where):
        s = unescape(s)
        if shown(s):
            keys.setdefault(s, where)

    files = []
    for d in ["scripts", "scripts/ui", "scripts/kits", "art"]:
        for f in sorted(os.listdir(os.path.join(ROOT, d))):
            if f.endswith(".gd") and f not in ("preview.gd",):
                files.append(os.path.join(d, f))
    for rel in files:
        src = strip_comments(open(os.path.join(ROOT, rel), encoding="utf-8").read())
        for call in CALLS:
            for m in re.finditer(re.escape(call), src):
                if call == "toast(" and src[m.start() - 1:m.start()] in (".",) and not src[:m.start()].endswith("run."):
                    pass
                if call in ("toast(",) and re.match(r"\w", src[m.start() - 1:m.start()] or " "):
                    continue   # show_toast( etc.
                args = call_args(src, m.end())
                strs = re.findall(STR, args)
                if call == "hint_once(":
                    strs = strs[1:]
                elif call in ("UIK.label(", "UIK.button("):
                    strs = [s for s in strs if s not in STOP]
                for s in strs:
                    add(s, rel)
        for m in re.finditer(r'\.(?:text|tooltip_text)\s*=\s*([^\n]*)', src):
            for s in re.findall(STR, m.group(1)):
                if re.search(r"[A-Z ]", s):
                    add(s, rel)
        for m in re.finditer(r'"(?:label|text)":\s*' + STR, src):
            add(m.group(1), rel)
        # damage / projectile tags: capitalised string arguments of damage calls
        for m in re.finditer(r'(?:damage|fire_projectile|_proj|burn|dot)\w*\(', src):
            for s in re.findall(STR, call_args(src, m.end())):
                if re.match(r"[A-Z]", s):
                    add(s, rel)
        # small literal tables of UI text: [["Hero", ...]], {"str": "Strength"}, ["Easy", ...]
        for m in re.finditer(r'\[\s*' + STR + r'\s*,', src):
            s = m.group(1)
            if re.match(r"[A-Z][a-z]", s) and len(s) > 2:
                add(s, rel)
        for m in re.finditer(r'(?:stat_names|acts|for t in|for pair in|lines|rows)\b[^\n]*', src):
            for s in re.findall(STR, m.group(0)):
                if re.match(r"[A-Z]", s):
                    add(s, rel)
    for rel in DATA_FILES:
        src = strip_comments(open(os.path.join(ROOT, rel), encoding="utf-8").read())
        for fld in DATA_FIELDS:
            for m in re.finditer(r'"%s":\s*' % fld + STR, src):
                add(m.group(1), rel)
        for tbl in CONST_TABLES:
            m = re.search(r'const %s\b[^=]*=\s*' % tbl, src)
            if m:
                body = call_args(src, m.end() + 1)
                for s in re.findall(STR, body):
                    if re.match(r"[A-Z]", s):
                        add(s, rel)
    for s in EXTRA:
        add(s, "tools/l10n.py")
    os.makedirs(LOCALE, exist_ok=True)
    out = dict(sorted(keys.items(), key=lambda kv: (kv[1], kv[0])))
    json.dump(out, open(os.path.join(LOCALE, "keys.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("%d keys -> locale/keys.json" % len(out))
    return out


# strings built at runtime that the patterns above can't see
EXTRA = ["STR", "AGI", "INT", "Melee", "Ranged", "Extreme tier", "Unknown item", "Shop is only open in camp", "Not enough gold",
         "Only one per run", "Only one boots item", "Inventory full (sell something)", "Unknown upgrade", "Opens at wave %d",
         "magic", "mixed"]


def placeholders(s):
    return sorted(re.findall(r"%[-+]?\d*(?:\.\d+)?[dsf%]", s)), sorted(re.findall(r"\{\w+\}", s))


def load(lang):
    p = os.path.join(LOCALE, lang + ".json")
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}


def check():
    keys = json.load(open(os.path.join(LOCALE, "keys.json"), encoding="utf-8"))
    bad = 0
    for lang in LANGS:
        tr = load(lang)
        missing = [k for k in keys if not tr.get(k)]
        stale = [k for k in tr if k not in keys]
        broken = [k for k in keys if tr.get(k) and placeholders(k) != placeholders(tr[k])]
        print("%-6s %4d/%d  missing %d  stale %d  placeholder errors %d" % (lang, len(keys) - len(missing), len(keys),
                                                                          len(missing), len(stale), len(broken)))
        for k in broken[:10]:
            print("    %r -> %r" % (k, tr[k]))
        bad += len(missing) + len(broken)
    return bad


def todo(lang):
    keys = json.load(open(os.path.join(LOCALE, "keys.json"), encoding="utf-8"))
    tr = load(lang)
    left = [k for k in keys if not tr.get(k)]
    json.dump(left, open(os.path.join(LOCALE, "todo_%s.json" % lang), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print("%d keys left for %s" % (len(left), lang))


def merge(lang, path):
    keys = json.load(open(os.path.join(LOCALE, "keys.json"), encoding="utf-8"))
    tr = load(lang)
    new = json.load(open(path, encoding="utf-8"))
    n = 0
    for k, v in new.items():
        if k in keys:
            tr[k] = v
            n += 1
        else:
            print("  not a key: %r" % k)
    out = {k: tr[k] for k in keys if k in tr}   # key order, stale entries dropped
    json.dump(out, open(os.path.join(LOCALE, lang + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("%s: merged %d, now %d / %d" % (lang, n, len(out), len(keys)))


FONT_SRC = {
    # out name: (source font, ttc index or None, languages whose text it must cover)
    "noto_latin.ttf": ("/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf", None, ["es", "pt_BR", "fr", "de", "it", "ru", "tr", "id", "vi"]),
    "noto_thai.ttf": ("/usr/share/fonts/truetype/noto/NotoSansThai-Bold.ttf", None, ["th"]),
    "noto_arabic.ttf": ("/usr/share/fonts/truetype/noto/NotoSansArabic-Bold.ttf", None, ["ar"]),
    "noto_cjk_jp.otf": ("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc", 0, ["ja"]),
    "noto_cjk_kr.otf": ("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc", 1, ["ko"]),
    "noto_cjk_sc.otf": ("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc", 2, ["zh_CN"]),
    "noto_cjk_tc.otf": ("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc", 3, ["zh_TW"]),
}
# the language picker shows every language's own name in every language
PICKER = "English Español Português (Brasil) Français Deutsch Italiano Русский Türkçe Bahasa Indonesia Tiếng Việt ไทย العربية 日本語 한국어 简体中文 繁體中文"


def fonts():
    from fontTools import subset
    from fontTools.ttLib import TTFont
    out_dir = os.path.join(LOCALE, "fonts")
    os.makedirs(out_dir, exist_ok=True)
    ascii_ = "".join(chr(c) for c in range(32, 127)) + "·…→∞—–’“”«»°×"
    for name, (src, idx, langs) in FONT_SRC.items():
        text = ascii_ + PICKER
        for lang in langs:
            text += "".join(load(lang).values())
        font = TTFont(src, fontNumber=idx) if idx is not None else TTFont(src)
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        opts.hinting = False
        sub = subset.Subsetter(opts)
        sub.populate(text=text)
        sub.subset(font)
        font.save(os.path.join(out_dir, name))
        print("%-18s %6.0f KB  (%d chars)" % (name, os.path.getsize(os.path.join(out_dir, name)) / 1024, len(set(text))))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "extract":
        extract()
    elif cmd == "check":
        sys.exit(1 if check() else 0)
    elif cmd == "todo":
        todo(sys.argv[2])
    elif cmd == "merge":
        merge(sys.argv[2], sys.argv[3])
    elif cmd == "fonts":
        fonts()
    else:
        print(__doc__)
