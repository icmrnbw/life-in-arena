class_name Skins
extends RefCounted
## Hero skins: cosmetic recolours with a rarity. The Heroes screen (main menu) previews and equips them;
## the equipped skin is saved in Game.settings["skins"] and used for the hero model in a run.
##
## A skin entry: "id", "name", "rarity" (key of RARITIES), "unlock" ("free" = owned by everyone, "store" = needs
## buying, no store yet so it can only be previewed), and the look: "hue" (degrees), "sat" / "val" (multipliers on
## the body colours), "accent" (rim, ground ring and glow colour), "glow" (emissive strength multiplier).

const RARITY_ORDER := ["common", "uncommon", "rare", "mythical", "legendary"]
const RARITIES := {
	"common": {"name": "Common", "color": Color("c9c2b6")},
	"uncommon": {"name": "Uncommon", "color": Color("6cd65a")},
	"rare": {"name": "Rare", "color": Color("4fa3ff")},
	"mythical": {"name": "Mythical", "color": Color("b46bff")},
	"legendary": {"name": "Legendary", "color": Color("ffa42e")},
}

const CLASSIC := {"id": "classic", "name": "Classic", "rarity": "common", "unlock": "free"}

const SKINS := {
	"ashwarden": [
		{"id": "frostwarden", "name": "Frostwarden", "rarity": "uncommon", "unlock": "free", "hue": 180.0, "accent": Color("6fd8ff")},
		{"id": "obsidian", "name": "Obsidian Warden", "rarity": "mythical", "unlock": "free", "sat": 0.35, "val": 0.6, "accent": Color("ff3a1a"), "glow": 1.6},
		{"id": "sunforged", "name": "Sunforged", "rarity": "legendary", "unlock": "store", "hue": -25.0, "sat": 1.2, "val": 1.3, "accent": Color("ffd24a"), "glow": 2.2},
	],
	"riftdancer": [
		{"id": "bloodrift", "name": "Bloodrift", "rarity": "uncommon", "unlock": "free", "hue": 180.0, "accent": Color("ff4a5a")},
		{"id": "voidstep", "name": "Voidstep", "rarity": "mythical", "unlock": "free", "hue": 60.0, "val": 0.7, "accent": Color("b06bff"), "glow": 1.5},
		{"id": "starlit", "name": "Starlit Duelist", "rarity": "legendary", "unlock": "store", "sat": 0.4, "val": 1.3, "accent": Color("fff1a8"), "glow": 2.4},
	],
	"hivemother": [
		{"id": "crimson_brood", "name": "Crimson Brood", "rarity": "uncommon", "unlock": "free", "hue": 150.0, "accent": Color("ff5a3a")},
		{"id": "frost_hive", "name": "Frost Hive", "rarity": "mythical", "unlock": "free", "hue": -120.0, "accent": Color("7ad8ff"), "glow": 1.5},
		{"id": "gilded_queen", "name": "Gilded Queen", "rarity": "legendary", "unlock": "store", "hue": 60.0, "sat": 1.2, "val": 1.2, "accent": Color("ffcc33"), "glow": 2.2},
	],
	"sanguine": [
		{"id": "plague", "name": "Plaguebound", "rarity": "uncommon", "unlock": "free", "hue": -110.0, "accent": Color("9cff3a")},
		{"id": "moonblood", "name": "Moonblood", "rarity": "mythical", "unlock": "free", "sat": 0.3, "val": 1.2, "accent": Color("c8d8ff"), "glow": 1.5},
		{"id": "abyssal", "name": "Abyssal Sanguine", "rarity": "legendary", "unlock": "store", "hue": 140.0, "val": 0.7, "accent": Color("9a4bff"), "glow": 2.4},
	],
	"snarewright": [
		{"id": "desert", "name": "Dune Stalker", "rarity": "uncommon", "unlock": "free", "hue": 20.0, "val": 1.1, "accent": Color("ffb04a")},
		{"id": "nightstalker", "name": "Nightstalker", "rarity": "mythical", "unlock": "free", "sat": 0.4, "val": 0.6, "accent": Color("4aff9a"), "glow": 1.6},
		{"id": "gilded_hunter", "name": "Gilded Hunter", "rarity": "legendary", "unlock": "store", "hue": -20.0, "sat": 1.4, "val": 1.25, "accent": Color("ffd24a"), "glow": 2.2},
	],
	"twinhide": [
		{"id": "crimson_twin", "name": "Crimson Twin", "rarity": "uncommon", "unlock": "free", "hue": -60.0, "accent": Color("ff4a6a")},
		{"id": "deepwood", "name": "Deepwood Beast", "rarity": "mythical", "unlock": "free", "hue": 60.0, "accent": Color("5affb0"), "glow": 1.5},
		{"id": "spirit_twin", "name": "Spirit Twin", "rarity": "legendary", "unlock": "store", "sat": 0.5, "val": 1.25, "accent": Color("3ff0dc"), "glow": 2.5},
	],
	"gravekeeper": [
		{"id": "ashen", "name": "Ashen Keeper", "rarity": "uncommon", "unlock": "free", "sat": 0.3, "accent": Color("ff9a4a")},
		{"id": "bloodmoon", "name": "Bloodmoon", "rarity": "mythical", "unlock": "free", "hue": 180.0, "accent": Color("ff3a4a"), "glow": 1.5},
		{"id": "lich", "name": "Lich King", "rarity": "legendary", "unlock": "store", "hue": 60.0, "val": 0.8, "accent": Color("6fa8ff"), "glow": 2.5},
	],
	"stoneshaper": [
		{"id": "jade", "name": "Jadeshaper", "rarity": "uncommon", "unlock": "free", "hue": -100.0, "accent": Color("6cff7a")},
		{"id": "basalt", "name": "Basalt", "rarity": "mythical", "unlock": "free", "sat": 0.4, "val": 0.6, "accent": Color("ff5a1a"), "glow": 1.7},
		{"id": "crystal_titan", "name": "Crystal Titan", "rarity": "legendary", "unlock": "store", "hue": 160.0, "sat": 1.2, "val": 1.2, "accent": Color("7af0ff"), "glow": 2.4},
	],
	"gunsmith": [
		{"id": "brass", "name": "Brass Barrel", "rarity": "uncommon", "unlock": "free", "hue": 180.0, "accent": Color("f2c14e")},
		{"id": "redcoat", "name": "Redcoat", "rarity": "mythical", "unlock": "free", "hue": 120.0, "accent": Color("ff4a3a"), "glow": 1.5},
		{"id": "ghost_gunner", "name": "Ghost Gunner", "rarity": "legendary", "unlock": "store", "sat": 0.25, "val": 1.3, "accent": Color("9affe8"), "glow": 2.5},
	],
	"sunspeaker": [
		{"id": "moonspeaker", "name": "Moonspeaker", "rarity": "uncommon", "unlock": "free", "hue": 180.0, "accent": Color("9ab8ff")},
		{"id": "dusk", "name": "Duskspeaker", "rarity": "mythical", "unlock": "free", "hue": -40.0, "val": 0.8, "accent": Color("ff6a3a"), "glow": 1.5},
		{"id": "solar", "name": "Solar Ascendant", "rarity": "legendary", "unlock": "store", "sat": 1.4, "val": 1.15, "accent": Color("ffe680"), "glow": 2.8},
	],
	"duelist": [
		{"id": "crimson_fencer", "name": "Crimson Fencer", "rarity": "uncommon", "unlock": "free", "hue": 150.0, "accent": Color("ff4a4a")},
		{"id": "masquerade", "name": "Masquerade", "rarity": "mythical", "unlock": "free", "hue": 60.0, "val": 0.75, "accent": Color("d86bff"), "glow": 1.5},
		{"id": "gilded_blade", "name": "Gilded Blade", "rarity": "legendary", "unlock": "store", "sat": 1.3, "val": 1.25, "accent": Color("fff0a0"), "glow": 2.4},
	],
	"vanguard": [
		{"id": "verdigris", "name": "Verdigris", "rarity": "uncommon", "unlock": "free", "hue": 140.0, "accent": Color("5affb0")},
		{"id": "blackiron", "name": "Blackiron", "rarity": "mythical", "unlock": "free", "sat": 0.4, "val": 0.55, "accent": Color("ff3a1a"), "glow": 1.7},
		{"id": "dragonplate", "name": "Dragonplate", "rarity": "legendary", "unlock": "store", "hue": -20.0, "sat": 1.3, "val": 1.2, "accent": Color("ffb030"), "glow": 2.4},
	],
	"nightblade": [
		{"id": "ashen_veil", "name": "Ashen Veil", "rarity": "uncommon", "unlock": "free", "sat": 0.3, "val": 1.2, "accent": Color("e0e0ff")},
		{"id": "bloodmoon_blade", "name": "Bloodmoon", "rarity": "mythical", "unlock": "free", "hue": 90.0, "accent": Color("ff2a4a"), "glow": 1.6},
		{"id": "void_walker", "name": "Void Walker", "rarity": "legendary", "unlock": "store", "hue": -60.0, "val": 0.7, "accent": Color("3ff0dc"), "glow": 2.6},
	],
	"skyspear": [
		{"id": "sunspear", "name": "Sunspear", "rarity": "uncommon", "unlock": "free", "hue": 180.0, "accent": Color("ffb04a")},
		{"id": "stormspear", "name": "Stormspear", "rarity": "mythical", "unlock": "free", "hue": 60.0, "val": 0.8, "accent": Color("c08aff"), "glow": 1.5},
		{"id": "valkyrie", "name": "Valkyrie", "rarity": "legendary", "unlock": "store", "sat": 0.5, "val": 1.3, "accent": Color("fff6c0"), "glow": 2.5},
	],
	"frostweaver": [
		{"id": "emberweaver", "name": "Emberweaver", "rarity": "uncommon", "unlock": "free", "hue": 170.0, "accent": Color("ff8a3a")},
		{"id": "glacier_queen", "name": "Glacier Queen", "rarity": "mythical", "unlock": "free", "sat": 0.4, "val": 1.25, "accent": Color("e8fbff"), "glow": 1.6},
		{"id": "aurora", "name": "Aurora", "rarity": "legendary", "unlock": "store", "hue": -70.0, "sat": 1.3, "accent": Color("6cff9a"), "glow": 2.6},
	],
	"stormcaller": [
		{"id": "sandstorm", "name": "Sandstorm", "rarity": "uncommon", "unlock": "free", "hue": 170.0, "accent": Color("ffc86a")},
		{"id": "red_thunder", "name": "Red Thunder", "rarity": "mythical", "unlock": "free", "hue": 110.0, "accent": Color("ff4a4a"), "glow": 1.6},
		{"id": "tempest_lord", "name": "Tempest Lord", "rarity": "legendary", "unlock": "store", "sat": 0.4, "val": 1.3, "accent": Color("bff4ff"), "glow": 2.6},
	],
	"alchemist": [
		{"id": "plague_doctor", "name": "Plague Doctor", "rarity": "uncommon", "unlock": "free", "sat": 0.35, "val": 0.75, "accent": Color("b0ff6a")},
		{"id": "quicksilver", "name": "Quicksilver", "rarity": "mythical", "unlock": "free", "hue": 120.0, "accent": Color("8ad8ff"), "glow": 1.5},
		{"id": "midas", "name": "Midas", "rarity": "legendary", "unlock": "store", "hue": -50.0, "sat": 1.4, "val": 1.25, "accent": Color("ffd24a"), "glow": 2.6},
	],
	"chronomancer": [
		{"id": "dusk_glass", "name": "Dusk Glass", "rarity": "uncommon", "unlock": "free", "hue": 160.0, "accent": Color("ff8a6a")},
		{"id": "eternity", "name": "Eternity", "rarity": "mythical", "unlock": "free", "hue": -90.0, "val": 0.8, "accent": Color("7af0d0"), "glow": 1.6},
		{"id": "starfall", "name": "Starfall Seer", "rarity": "legendary", "unlock": "store", "sat": 0.45, "val": 1.3, "accent": Color("c8d8ff"), "glow": 2.7},
	],
}


## Every skin of a hero, Classic first.
static func for_hero(hero_id: String) -> Array:
	return [CLASSIC] + (SKINS.get(hero_id, []) as Array)


static func find(hero_id: String, skin_id: String) -> Dictionary:
	for s in for_hero(hero_id):
		if s["id"] == skin_id:
			return s
	return CLASSIC


static func rarity_name(r: String) -> String:
	return RARITIES.get(r, RARITIES["common"])["name"]


static func rarity_color(r: String) -> Color:
	return RARITIES.get(r, RARITIES["common"])["color"]


static func owned(hero_id: String, skin_id: String) -> bool:
	if find(hero_id, skin_id).get("unlock", "free") == "free":
		return true
	return (Game.settings.get("skins_owned", []) as Array).has("%s/%s" % [hero_id, skin_id])


static func equipped(hero_id: String) -> String:
	var id := String((Game.settings.get("skins", {}) as Dictionary).get(hero_id, "classic"))
	return id if owned(hero_id, id) else "classic"


static func equip(hero_id: String, skin_id: String) -> bool:
	if not owned(hero_id, skin_id):
		return false
	var d: Dictionary = (Game.settings.get("skins", {}) as Dictionary).duplicate()
	d[hero_id] = skin_id
	Game.settings["skins"] = d
	Game.save_settings()
	return true


## Hero id whose skin a model kind wears (the Twinhide beast form wears the Twinhide skin), or "" for non-heroes.
static func hero_of(kind: String) -> String:
	if kind == "twinhide_beast":
		return "twinhide"
	return kind if DB.HEROES.has(kind) else ""


## Recolour a model from Art.create_unit() with a skin (Classic resets it).
static func apply(visual: Node, hero_id: String, skin_id: String) -> void:
	if visual and visual.has_method("apply_skin"):
		visual.call("apply_skin", find(hero_id, skin_id))


## Dress a freshly made model in its hero's equipped skin; no-op for enemies and summons.
static func apply_equipped(visual: Node, kind: String) -> void:
	var h := hero_of(kind)
	if h != "" and equipped(h) != "classic":
		apply(visual, h, equipped(h))
