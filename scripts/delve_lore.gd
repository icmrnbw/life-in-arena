class_name DelveLore
extends RefCounted
## Delve-only content data: relics (run-long passives found in vaults and on boss depths), shrine blessings (one
## depth long), the three looks of the Undercroft and the press-on streak. Stats use the item stat keys
## (scripts/hero.gd recalc), plus a few Delve keys: dmg_pct (all damage), gold_pct / xp_pct (rewards from foes),
## lantern_r (lantern radius).

## Relics: pick 1 of 3. Never offered twice in a run.
const RELICS := {
	"vampire_fang": {"name": "Vampire Fang", "desc": "Attacks heal you for 8% of the damage dealt.", "icon": "bloodthirst_fang",
		"stats": {"lifesteal": 0.08}, "color": Color(0.9, 0.25, 0.3)},
	"thorn_shard": {"name": "Thorn Shard", "desc": "Melee attackers take 30% of their hit back.", "icon": "bulwark_plate",
		"stats": {"reflect": 0.3}, "color": Color(0.6, 0.8, 0.4)},
	"everburning_lantern": {"name": "Everburning Lantern", "desc": "Your lantern lights 40% farther. +5% damage.", "icon": "hooded_lantern",
		"stats": {"lantern_r": 0.4, "dmg_pct": 0.05}, "color": Color(1.0, 0.8, 0.4)},
	"gravebloom": {"name": "Gravebloom", "desc": "+300 max health and +3 health regen.", "icon": "vigor_charm",
		"stats": {"hp": 300.0, "hp_regen": 3.0}, "color": Color(0.5, 0.9, 0.5)},
	"whetstone": {"name": "Whetstone of Ages", "desc": "+20 attack damage.", "icon": "iron_knuckles",
		"stats": {"dmg": 20.0}, "color": Color(0.85, 0.85, 0.9)},
	"quicksand": {"name": "Quicksand Hourglass", "desc": "+25% attack speed.", "icon": "swift_gloves",
		"stats": {"as": 0.25}, "color": Color(0.95, 0.8, 0.45)},
	"runed_skull": {"name": "Runed Skull", "desc": "Skills recharge 12% faster.", "icon": "focus_pendant",
		"stats": {"cdr": 0.12}, "color": Color(0.6, 0.6, 1.0)},
	"frost_rune": {"name": "Frostbitten Rune", "desc": "Attacks slow foes by 25%.", "icon": "ice_shard",
		"stats": {"chill": 0.25}, "color": Color(0.5, 0.85, 1.0)},
	"ember_heart": {"name": "Ember Heart", "desc": "Attacks set foes on fire.", "icon": "emberbrand",
		"stats": {"burn": 1.0}, "color": Color(1.0, 0.5, 0.2)},
	"miners_boots": {"name": "Miner's Boots", "desc": "+15% move speed. Water no longer slows you.", "icon": "runners_boots",
		"stats": {"ms": 0.15, "wade": 1.0}, "color": Color(0.7, 0.55, 0.35)},
	"oathstone": {"name": "Oathstone", "desc": "+7 armor and +12% magic resist.", "icon": "spellward_mantle",
		"stats": {"armor": 7.0, "mres": 0.12}, "color": Color(0.7, 0.75, 0.85)},
	"greedy_idol": {"name": "Greedy Idol", "desc": "Foes in the Undercroft drop 30% more gold.", "icon": "golden_touch",
		"stats": {"gold_pct": 0.3}, "color": Color(1.0, 0.85, 0.3)},
	"soul_jar": {"name": "Soul Jar", "desc": "Every hit heals you for 8 health.", "icon": "healing_draught",
		"stats": {"hit_heal": 8.0}, "color": Color(0.4, 1.0, 0.85)},
	"ashen_soles": {"name": "Ashen Soles", "desc": "Spikes and ember cracks don't hurt you.", "icon": "wayfarer_treads",
		"stats": {"trapproof": 1.0}, "color": Color(1.0, 0.45, 0.25)},
	"warlord_crown": {"name": "Warlord's Crown", "desc": "+12% damage.", "icon": "berserkers_torc",
		"stats": {"dmg_pct": 0.12}, "color": Color(1.0, 0.6, 0.3)},
	"sage_tome": {"name": "Sage's Tome", "desc": "+200 max mana and +2.5 mana regen.", "icon": "sage_circlet",
		"stats": {"mana": 200.0, "mana_regen": 2.5}, "color": Color(0.45, 0.65, 1.0)},
	"hunters_mark": {"name": "Hunter's Mark", "desc": "Foes give 25% more gold and 15% more experience.", "icon": "hawkeye_lens",
		"stats": {"gold_pct": 0.25, "xp_pct": 0.15}, "color": Color(0.95, 0.75, 0.35)},
	"stoneskin_idol": {"name": "Stoneskin Idol", "desc": "+5 armor and +150 max health.", "icon": "hide_vest",
		"stats": {"armor": 5.0, "hp": 150.0}, "color": Color(0.7, 0.68, 0.6)},
}

## Shrines: walk up to one for a blessing that lasts until the depth ends. Cursed ones cost health first.
const SHRINES := {
	"fury": {"name": "Shrine of Fury", "desc": "+35% attack speed for this depth", "stats": {"as": 0.35}, "color": Color(1.0, 0.45, 0.2)},
	"iron": {"name": "Shrine of Iron", "desc": "+8 armor and +15% magic resist for this depth", "stats": {"armor": 8.0, "mres": 0.15}, "color": Color(0.65, 0.75, 0.95)},
	"haste": {"name": "Shrine of Haste", "desc": "+20% move speed for this depth", "stats": {"ms": 0.2}, "color": Color(0.4, 1.0, 0.5)},
	"greed": {"name": "Shrine of Greed", "desc": "+50% gold from foes for this depth", "stats": {"gold_pct": 0.5}, "color": Color(1.0, 0.82, 0.25)},
	"wisdom": {"name": "Shrine of Wisdom", "desc": "+50% experience for this depth", "stats": {"xp_pct": 0.5}, "color": Color(0.7, 0.5, 1.0)},
	"blood": {"name": "Blood Shrine", "desc": "Costs 25% of your health: +40% damage for this depth", "stats": {"dmg_pct": 0.4}, "color": Color(0.9, 0.08, 0.12), "cost": 0.25},
}

## The Undercroft's three looks: Bone Crypt (depths 1-3), Flooded Caverns (4-6), the Abyss (7-10).
## light = torch / brazier colour, hazard = the floor terrain of that tier ("" none, "water" slows, "ember" burns).
const TIERS := [
	{"id": "crypt", "name": "Bone Crypt", "floor": Color(0.27, 0.27, 0.3), "floor_cave": Color(0.25, 0.24, 0.26), "wall": Color("4c4c58"),
		"wall_top": Color("3a3a44"), "ledge": Color("55555f"), "lair": Color(0.24, 0.25, 0.32), "light": Color(0.55, 0.75, 1.0),
		"flame_hot": Color(0.75, 0.9, 1.0), "flame_cool": Color(0.2, 0.45, 1.0), "rune": Color("7ab8ff"), "hazard": "", "caves": 0.25,
		"ambient": Color(0.35, 0.4, 0.6)},
	{"id": "flooded", "name": "Flooded Caverns", "floor": Color(0.22, 0.27, 0.26), "floor_cave": Color(0.2, 0.25, 0.23), "wall": Color("3c4a48"),
		"wall_top": Color("2c3836"), "ledge": Color("465450"), "lair": Color(0.2, 0.3, 0.3), "light": Color(0.4, 1.0, 0.8),
		"flame_hot": Color(0.7, 1.0, 0.85), "flame_cool": Color(0.1, 0.7, 0.55), "rune": Color("5affc8"), "hazard": "water", "caves": 0.65,
		"ambient": Color(0.3, 0.5, 0.5)},
	{"id": "abyss", "name": "The Abyss", "floor": Color(0.16, 0.14, 0.15), "floor_cave": Color(0.15, 0.12, 0.12), "wall": Color("2e2628"),
		"wall_top": Color("221c1e"), "ledge": Color("3a3032"), "lair": Color(0.3, 0.12, 0.1), "light": Color(1.0, 0.4, 0.15),
		"flame_hot": Color(1.0, 0.75, 0.35), "flame_cool": Color(1.0, 0.2, 0.04), "rune": Color("ff4a1a"), "hazard": "ember", "caves": 0.5,
		"ambient": Color(0.5, 0.3, 0.3)},
]

const STREAK_BONUS := 0.2      # press on: +20% gold and xp from foes per depth in a row (up to 3)
const STREAK_MAX := 3


static func tier_of(depth: int) -> int:
	return 0 if depth <= 3 else (1 if depth <= 6 else 2)


static func tier(depth: int) -> Dictionary:
	return TIERS[tier_of(depth)]


## Up to n relic ids the hero doesn't own yet, shuffled with rng.
static func relic_offer(owned: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var pool := []
	for id in RELICS:
		if not id in owned:
			pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool.slice(0, n)
