class_name DB
extends RefCounted
## All static game content: heroes, skills, items, enemies, waves, economy curves.
## Numbers are starting balance (see plan sections 3-5).

const HERO_ORDER := ["ashwarden", "riftdancer", "hivemother"]

const HEROES := {
	"ashwarden": {
		"name": "Ashwarden", "title": "The Architect", "role": "Zone control",
		"playstyle": "Builds the battlefield: plant totems, raise walls, then pull the enemy pack into the fire.",
		"primary": "str", "str": 24.0, "agi": 12.0, "int": 16.0, "str_g": 2.8, "agi_g": 1.3, "int_g": 1.7,
		"dmg": 24.0, "range": 2.3, "atk_time": 1.4, "speed": 5.0, "armor": 3.0, "ranged": false,
		"skills": ["ember_totem", "ash_wall", "tether_pull", "foundry_heart"],
		"skill_order": [0, 2, 0, 1, 0, 3, 2, 0, 1, 2, 3, 1, 2, 1, 3],
		"build": ["iron_knuckles", "vigor_charm", "hide_vest", "bulwark_plate", "focus_pendant", "runners_boots", "wayfarer_treads", "stout_belt", "wardens_aegis", "swift_gloves", "iron_knuckles", "emberbrand", "vigor_charm", "iron_knuckles", "bloodthirst_fang", "sage_circlet", "focus_pendant", "hivecore_sigil"],
	},
	"riftdancer": {
		"name": "Riftdancer", "title": "The Momentum Fighter", "role": "Combo / mobility",
		"playstyle": "Never stop moving: dash through foes, mark them, then shatter every mark at once.",
		"primary": "agi", "str": 19.0, "agi": 24.0, "int": 14.0, "str_g": 2.0, "agi_g": 3.0, "int_g": 1.5,
		"dmg": 18.0, "range": 2.1, "atk_time": 1.25, "speed": 6.0, "armor": 3.0, "ranged": false,
		"skills": ["slip", "shatter_mark", "afterimage", "rift_cascade"],
		"skill_order": [0, 1, 0, 2, 1, 3, 0, 1, 0, 1, 3, 2, 2, 2, 3],
		"build": ["iron_knuckles", "vigor_charm", "bloodthirst_fang", "swift_gloves", "iron_knuckles", "emberbrand", "runners_boots", "focus_pendant", "wayfarer_treads", "hide_vest", "vigor_charm", "bulwark_plate", "stout_belt", "wardens_aegis", "sage_circlet", "focus_pendant", "hivecore_sigil"],
	},
	"hivemother": {
		"name": "Hivemother", "title": "The Commander", "role": "Swarm management",
		"playstyle": "Fights through her brood: hatch broodlings, send them in, spend them as living bombs.",
		"primary": "int", "str": 19.0, "agi": 13.0, "int": 24.0, "str_g": 2.1, "agi_g": 1.3, "int_g": 3.0,
		"dmg": 14.0, "range": 9.0, "atk_time": 1.5, "speed": 5.0, "armor": 2.0, "ranged": true,
		"skills": ["brood", "rally_pheromone", "volatile_sacrifice", "queens_carapace"],
		"skill_order": [0, 2, 0, 1, 0, 3, 0, 2, 2, 2, 3, 1, 1, 1, 3],
		"build": ["focus_pendant", "vigor_charm", "sage_circlet", "hivecore_sigil", "hide_vest", "bulwark_plate", "runners_boots", "focus_pendant", "wayfarer_treads", "stout_belt", "wardens_aegis", "iron_knuckles", "vigor_charm", "bloodthirst_fang"],
	},
}

## Skill data. mana/cd arrays are per rank (index 0 = rank 1).
const SKILLS := {
	# --- Ashwarden ---
	"ember_totem": {"name": "Ember Totem", "max": 4, "mana": [60, 65, 70, 75], "cd": [6.0, 6.0, 5.5, 5.0],
		"aim": "point", "range": 9.0, "radius": 1.0,
		"desc": "Plant a totem that hurls fire bolts at nearby foes. Max 2 totems (3 at rank 3, 4 at rank 4)."},
	"ash_wall": {"name": "Ash Wall", "max": 4, "mana": [80, 85, 90, 95], "cd": [14.0, 13.0, 12.0, 11.0],
		"aim": "wall", "range": 9.0,
		"desc": "Raise a burning wall across the aimed spot. Enemies can't pass; touching it burns."},
	"tether_pull": {"name": "Tether Pull", "max": 4, "mana": [70, 75, 80, 85], "cd": [13.0, 11.5, 10.0, 8.5],
		"aim": "point", "range": 11.0, "radius_r": [3.5, 4.0, 4.5, 5.0],
		"desc": "Hook an area: enemies inside are dragged to you, damaged and slowed."},
	"foundry_heart": {"name": "Foundry Heart", "max": 3, "mana": [150, 175, 200], "cd": [70.0, 62.0, 55.0],
		"aim": "self", "range": 0.0,
		"desc": "For 10 s totems fire twice as fast, walls burn hotter, and you heal from their damage."},
	# --- Riftdancer ---
	"slip": {"name": "Slip", "max": 4, "mana": [25, 25, 25, 25], "cd": [5.0, 4.6, 4.2, 3.8],
		"aim": "direction", "range": 6.5, "width": 1.6,
		"desc": "Dash through enemies, cutting and marking them. 2 charges (3 at rank 4)."},
	"shatter_mark": {"name": "Shatter Mark", "max": 4, "mana": [55, 60, 65, 70], "cd": [7.0, 6.5, 6.0, 5.5],
		"aim": "self", "range": 16.0,
		"desc": "Detonate every mark. Damage per mark grows with Flow."},
	"afterimage": {"name": "Afterimage", "max": 4, "mana": [50, 50, 50, 50], "cd": [16.0, 14.0, 12.0, 10.0],
		"aim": "self", "range": 0.0,
		"desc": "Leave a decoy that taunts nearby foes. Tap again to swap places with it."},
	"rift_cascade": {"name": "Rift Cascade", "max": 3, "mana": [120, 140, 160], "cd": [55.0, 48.0, 40.0],
		"aim": "self", "range": 13.0,
		"desc": "Blink between up to 6 enemies (marked first), striking each. At full Flow the cooldown resets once."},
	# --- Hivemother ---
	"brood": {"name": "Brood", "max": 4, "mana": [45, 45, 50, 50], "cd": [4.0, 3.5, 3.0, 2.5],
		"aim": "self", "range": 0.0,
		"desc": "Hatch 2 broodlings that follow and fight for you. Brood cap 4/6/8/10."},
	"rally_pheromone": {"name": "Rally Pheromone", "max": 4, "mana": [40, 40, 45, 45], "cd": [10.0, 9.0, 8.0, 7.0],
		"aim": "point", "range": 14.0, "radius": 3.0,
		"desc": "Mark a rally point: the brood rushes there and attacks faster."},
	"volatile_sacrifice": {"name": "Volatile Sacrifice", "max": 4, "mana": [30, 30, 30, 30], "cd": [6.0, 5.5, 5.0, 4.5],
		"aim": "self", "range": 0.0,
		"desc": "Detonate your 3 nearest broodlings (+1 per rank) for area damage; refunds mana."},
	"queens_carapace": {"name": "Queen's Carapace", "max": 3, "mana": [100, 110, 120], "cd": [50.0, 45.0, 40.0],
		"aim": "self", "range": 0.0,
		"desc": "Absorb up to 6 broodlings into a shell of HP; your spit becomes a wide cone."},
}

## Items. kind: basic / advanced / consumable. "from" = recipe components.
const ITEM_ORDER := ["iron_knuckles", "swift_gloves", "hide_vest", "vigor_charm", "focus_pendant", "runners_boots", "stout_belt", "sage_circlet",
	"emberbrand", "bulwark_plate", "wayfarer_treads", "hivecore_sigil", "bloodthirst_fang", "wardens_aegis",
	"healing_draught", "mana_draught", "tome_of_might", "phoenix_feather"]

const ITEMS := {
	"iron_knuckles": {"name": "Iron Knuckles", "kind": "basic", "cost": 250, "stats": {"dmg": 8.0}, "desc": "+8 damage"},
	"swift_gloves": {"name": "Swift Gloves", "kind": "basic", "cost": 250, "stats": {"as": 0.15}, "desc": "+15% attack speed"},
	"hide_vest": {"name": "Hide Vest", "kind": "basic", "cost": 250, "stats": {"armor": 4.0}, "desc": "+4 armor"},
	"vigor_charm": {"name": "Vigor Charm", "kind": "basic", "cost": 300, "stats": {"hp": 200.0}, "desc": "+200 HP"},
	"focus_pendant": {"name": "Focus Pendant", "kind": "basic", "cost": 300, "stats": {"mana": 150.0, "mana_regen": 1.0}, "desc": "+150 mana, +1 mana regen"},
	"runners_boots": {"name": "Runner's Boots", "kind": "basic", "cost": 300, "stats": {"ms": 0.15}, "boots": true, "desc": "+15% move speed (one boots item only)"},
	"stout_belt": {"name": "Stout Belt", "kind": "basic", "cost": 400, "stats": {"str": 6.0}, "desc": "+6 Strength"},
	"sage_circlet": {"name": "Sage Circlet", "kind": "basic", "cost": 400, "stats": {}, "choice": true, "desc": "+6 Intellect or +6 Agility (choose at purchase)"},
	"emberbrand": {"name": "Emberbrand", "kind": "advanced", "cost": 400, "from": ["iron_knuckles", "swift_gloves"],
		"stats": {"dmg": 20.0, "as": 0.25, "burn": 1.0}, "desc": "+20 damage, +25% attack speed, attacks burn"},
	"bulwark_plate": {"name": "Bulwark Plate", "kind": "advanced", "cost": 450, "from": ["hide_vest", "vigor_charm"],
		"stats": {"armor": 8.0, "hp": 450.0, "reflect": 0.15}, "desc": "+8 armor, +450 HP, reflect 15% melee damage"},
	"wayfarer_treads": {"name": "Wayfarer Treads", "kind": "advanced", "cost": 350, "from": ["runners_boots", "focus_pendant"],
		"stats": {"ms": 0.20, "mana": 100.0}, "boots": true, "active": "sprint", "active_cd": 18.0,
		"desc": "+20% move speed, +100 mana. Active: 3 s sprint"},
	"hivecore_sigil": {"name": "Hivecore Sigil", "kind": "advanced", "cost": 500, "from": ["focus_pendant", "sage_circlet"],
		"stats": {"cdr": 0.15, "mana": 300.0, "mana_regen": 1.5}, "desc": "-15% cooldowns, +300 mana"},
	"bloodthirst_fang": {"name": "Bloodthirst Fang", "kind": "advanced", "cost": 450, "from": ["iron_knuckles", "vigor_charm"],
		"stats": {"dmg": 15.0, "lifesteal": 0.12, "hp": 150.0}, "desc": "+15 damage, 12% lifesteal"},
	"wardens_aegis": {"name": "Warden's Aegis", "kind": "advanced", "cost": 900, "from": ["bulwark_plate", "stout_belt"],
		"stats": {"armor": 10.0, "hp": 550.0, "str": 6.0, "reflect": 0.15, "aegis": 1.0},
		"desc": "Bulwark stats. Once per wave, lethal damage leaves you at 1 HP, invulnerable 2 s"},
	"healing_draught": {"name": "Healing Draught", "kind": "consumable", "cost": 90, "stack": 5, "active": "heal_potion", "active_cd": 1.0,
		"desc": "Heal 400 HP over 8 s. Stacks to 5"},
	"mana_draught": {"name": "Mana Draught", "kind": "consumable", "cost": 90, "stack": 5, "active": "mana_potion", "active_cd": 1.0,
		"desc": "Restore 250 mana over 6 s. Stacks to 5"},
	"tome_of_might": {"name": "Tome of Might", "kind": "consumable", "cost": 500, "noslot": true,
		"desc": "+2 primary attribute permanently (no slot)"},
	"phoenix_feather": {"name": "Phoenix Feather", "kind": "consumable", "cost": 1500, "noslot": true, "max_per_run": 1,
		"desc": "+1 life (once per run, no slot)"},
}

## Enemy base stats at wave 1.
const ENEMIES := {
	"gnawer": {"name": "Gnawer", "hp": 55.0, "dmg": 7.0, "atk_time": 1.0, "range": 1.0, "speed": 5.0, "armor": 0.0, "radius": 0.45, "xp": 9.0, "gold": 4.0},
	"shieldbearer": {"name": "Shieldbearer", "hp": 230.0, "dmg": 15.0, "atk_time": 1.5, "range": 1.3, "speed": 2.8, "armor": 5.0, "radius": 0.75, "xp": 24.0, "gold": 10.0},
	"hexcaster": {"name": "Hexcaster", "hp": 90.0, "dmg": 11.0, "atk_time": 2.2, "range": 9.0, "speed": 3.4, "armor": 0.0, "radius": 0.5, "xp": 20.0, "gold": 9.0},
	"burrower": {"name": "Burrower", "hp": 140.0, "dmg": 13.0, "atk_time": 1.2, "range": 1.2, "speed": 4.0, "armor": 2.0, "radius": 0.55, "xp": 20.0, "gold": 9.0},
	"bloater": {"name": "Bloater", "hp": 170.0, "dmg": 9.0, "atk_time": 1.4, "range": 1.2, "speed": 2.4, "armor": 0.0, "radius": 0.8, "xp": 20.0, "gold": 9.0},
	"choir_add": {"name": "Choir Voice", "hp": 240.0, "dmg": 13.0, "atk_time": 1.3, "range": 1.2, "speed": 4.0, "armor": 1.0, "radius": 0.5, "xp": 10.0, "gold": 4.0},
	# Bosses (absolute numbers; only lightly scaled)
	"pit_brute": {"name": "Pit Brute", "hp": 3400.0, "dmg": 38.0, "atk_time": 1.6, "range": 2.2, "speed": 3.6, "armor": 4.0, "radius": 1.5, "xp": 400.0, "gold": 0.0, "boss": true},
	"matron": {"name": "Twin Matron", "hp": 3600.0, "dmg": 34.0, "atk_time": 1.5, "range": 2.0, "speed": 3.4, "armor": 4.0, "radius": 1.3, "xp": 350.0, "gold": 0.0, "boss": true},
	"hollow_choir": {"name": "The Hollow Choir", "hp": 12000.0, "dmg": 50.0, "atk_time": 2.0, "range": 2.5, "speed": 1.6, "armor": 5.0, "radius": 1.8, "xp": 900.0, "gold": 0.0, "boss": true},
	"warden": {"name": "The Warden of the Pit", "hp": 26000.0, "dmg": 70.0, "atk_time": 1.5, "range": 2.6, "speed": 3.6, "armor": 8.0, "radius": 1.9, "xp": 0.0, "gold": 0.0, "boss": true},
}

## Elite affixes (wave 4+). Elites are tinted, tougher and pay more; each affix asks for a different answer.
const ELITE_AFFIXES := {
	"frenzied": {"name": "Frenzied", "from_wave": 4, "tint": Color(1.45, 0.55, 0.45),
		"hint": "Frenzied elites: fast and furious. Don't let them catch you in a crowd!"},
	"volatile": {"name": "Volatile", "from_wave": 6, "tint": Color(1.5, 1.05, 0.35),
		"hint": "Volatile elites explode when they die. Step out of the glow!"},
	"warding": {"name": "Warding", "from_wave": 8, "tint": Color(0.5, 0.85, 1.55),
		"hint": "Warding elites shield nearby foes. Kill the warder first!"},
}
const ELITE_HP_MULT := 1.9
const ELITE_DMG_MULT := 1.2
const ELITE_REWARD_MULT := 2.5
const WARD_RADIUS := 5.0
const WARD_DAMAGE_TAKEN := 0.6
const VOLATILE_RADIUS := 3.2
const VOLATILE_DELAY := 1.1

## Pit pressure: a wave that drags on enrages the enemies still alive (more damage, faster).
const BOSS_ENRAGE_TIME := {5: 100.0, 10: 120.0, 15: 150.0, 20: 210.0}
const ENRAGE_DMG := 1.3
const ENRAGE_SPEED := 1.2

## Hexcaster bolts hex the hero: healing received is reduced while hexed.
const HEX_TIME := 4.0
const HEX_HEAL_MULT := 0.5

const BOSS_WAVES := {5: "pit_brute", 10: "matron", 15: "hollow_choir", 20: "warden"}
const BOSS_TITLES := {5: "Pit Brute", 10: "Twin Matrons", 15: "The Hollow Choir", 20: "The Warden of the Pit"}
const BOSS_HINTS := {5: "Glowing ground means a slam or a charge is coming. Step out!",
	10: "The Matrons heal each other while close. Focus one down!",
	15: "The Choir's beam sweeps the arena. Keep moving around it.",
	20: "The Warden uses every trick in the Pit. Stay sharp!"}

const GATES := {"N": Vector3(0, 0, -21.0), "E": Vector3(21.0, 0, 0), "W": Vector3(-21.0, 0, 0), "NE": Vector3(14.8, 0, -14.8)}
const GATE_NAMES := ["N", "E", "W", "NE"]
const PILLARS := [Vector3(-9, 0, -6), Vector3(9, 0, -6), Vector3(0, 0, 10)]
const PILLAR_R := 1.6
const ARENA_R := 22.0
const CAMP_CENTER := Vector3(0, 0, 40)
const CAMP_R := 9.0
const SHOP_POS := Vector3(-4, 0, 42)
const FOUNTAIN_POS := Vector3(4, 0, 42)
const CAMP_SPAWN := Vector3(0, 0, 37)
const ARENA_SPAWN := Vector3(0, 0, 15)

const TOTAL_WAVES := 20
const START_GOLD := 300
const START_LIVES := 3
const PREP_TIME := 20.0
const FIRST_PREP_TIME := 30.0


static func hp_mult(w: int) -> float:
	var x := float(w - 1)
	# gentle early (waves 4-6), steeper late (12-20)
	return 1.0 + 0.10 * x + 0.014 * x * x + 0.0009 * x * x * x


static func dmg_mult(w: int) -> float:
	var x := float(w - 1)
	return 1.0 + 0.05 * x + 0.006 * x * x + 0.00015 * x * x * x


## Seconds into wave w before the survivors enrage.
static func enrage_time(w: int) -> float:
	return BOSS_ENRAGE_TIME.get(w, 55.0 + 3.0 * float(w))


## Chance that a regular enemy spawns as an elite.
static func elite_chance(w: int) -> float:
	if w < 4:
		return 0.0
	return minf(0.26, 0.05 + 0.012 * float(w - 4))


## Affixes that can roll on wave w.
static func elite_affixes(w: int) -> Array:
	var out := []
	for k in ELITE_AFFIXES:
		if w >= int(ELITE_AFFIXES[k]["from_wave"]):
			out.append(k)
	return out


static func gold_mult(w: int) -> float:
	return 1.0 + 0.09 * float(w - 1)


static func xp_mult(w: int) -> float:
	return 1.0 + 0.06 * float(w - 1)


static func xp_to_next(level: int) -> float:
	return 90.0 + 55.0 * float(level - 1)


static func wave_clear_gold(w: int) -> int:
	return 70 + 18 * w


static func boss_gold(w: int) -> int:
	return 200 + 40 * w


## Builds the bursts for wave w: Array of {delay, gate, units:[kind...]}
static func wave_bursts(w: int) -> Array:
	var counts := {}
	counts["gnawer"] = int(6 + w * 1.5)
	if w >= 2:
		counts["shieldbearer"] = int(1 + w / 4.0)
	if w >= 3:
		counts["hexcaster"] = int(1 + (w - 1) / 4.0)
	if w >= 4:
		counts["burrower"] = int(1 + (w - 4) / 5.0)
	if w >= 6:
		counts["bloater"] = int(1 + (w - 6) / 4.0)
	if BOSS_WAVES.has(w):
		# boss waves: lighter escort
		for k in counts.keys():
			counts[k] = int(ceil(counts[k] * 0.4))
	var n_bursts := 2 + mini(2, w / 6)
	var bursts := []
	for i in n_bursts:
		bursts.append({"delay": 0.0 if i == 0 else 7.0 + 1.0 * i, "gate": "", "units": []})
	# distribute
	var idx := 0
	for kind in ["shieldbearer", "hexcaster", "burrower", "bloater", "gnawer"]:
		var c: int = counts.get(kind, 0)
		for j in c:
			bursts[idx % n_bursts]["units"].append(kind)
			idx += 1
	var gate_cycle := GATE_NAMES.duplicate()
	for i in n_bursts:
		bursts[i]["gate"] = gate_cycle[(w + i) % gate_cycle.size()]
	return bursts


static func skill_aim(skill_id: String) -> String:
	return SKILLS.get(skill_id, {}).get("aim", "self")


static func item_total_cost(id: String) -> int:
	var d: Dictionary = ITEMS.get(id, {})
	var c: int = d.get("cost", 0)
	for f in d.get("from", []):
		c += item_total_cost(f)
	return c
