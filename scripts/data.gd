class_name DB
extends RefCounted
## All static game content: heroes, skills, items, enemies, waves, economy curves.
## Numbers are starting balance (see plan sections 3-5).

const HERO_ORDER := ["ashwarden", "riftdancer", "hivemother", "sanguine", "snarewright", "twinhide", "gravekeeper", "stoneshaper", "gunsmith", "sunspeaker"]

## Adding a hero: an entry here + its skills below + scripts/kits/<id>_kit.gd + a rig, a portrait and 4 skill icons in art/.
## "tag" is the one-word playstyle shown on hero select (each hero has its own), "difficulty" 1-3 stars.
## "bot" tunes the autoplay bot: ranged (kite at "keep" m), "crowd" (melee: back off when this many are close),
## "retreat" (HP fraction), "orbit" (circle-strafe strength), "camp_cast" (slots cast in camp before a wave).

const HEROES := {
	"ashwarden": {
		"name": "Ashwarden", "title": "The Architect", "role": "Zone control", "tag": "Zones", "difficulty": 1,
		"bot": {"crowd": 7},
		"playstyle": "Builds the battlefield: plant totems, raise walls, then pull the enemy pack into the fire.",
		"primary": "str", "str": 24.0, "agi": 12.0, "int": 16.0, "str_g": 2.8, "agi_g": 1.3, "int_g": 1.7,
		"dmg": 24.0, "range": 2.3, "atk_time": 1.4, "speed": 5.0, "armor": 3.0, "ranged": false,
		"skills": ["ember_totem", "ash_wall", "tether_pull", "foundry_heart"],
		"skill_order": [0, 2, 0, 1, 0, 3, 2, 0, 1, 2, 3, 1, 2, 1, 3],
		"build": ["iron_knuckles", "vigor_charm", "hide_vest", "bulwark_plate", "focus_pendant", "runners_boots", "wayfarer_treads", "stout_belt", "wardens_aegis", "swift_gloves", "iron_knuckles", "emberbrand", "vigor_charm", "iron_knuckles", "bloodthirst_fang", "sage_circlet", "focus_pendant", "hivecore_sigil"],
	},
	"riftdancer": {
		"name": "Riftdancer", "title": "The Momentum Fighter", "role": "Combo / mobility", "tag": "Momentum", "difficulty": 3,
		"bot": {"crowd": 4, "orbit": 0.8},
		"playstyle": "Never stop moving: dash through foes, mark them, then shatter every mark at once.",
		"primary": "agi", "str": 19.0, "agi": 24.0, "int": 14.0, "str_g": 2.0, "agi_g": 3.0, "int_g": 1.5,
		"dmg": 18.0, "range": 2.1, "atk_time": 1.25, "speed": 6.0, "armor": 3.0, "ranged": false,
		"skills": ["slip", "shatter_mark", "afterimage", "rift_cascade"],
		"skill_order": [0, 1, 0, 2, 1, 3, 0, 1, 0, 1, 3, 2, 2, 2, 3],
		"build": ["iron_knuckles", "vigor_charm", "bloodthirst_fang", "brawlers_wraps", "iron_knuckles", "cleaving_axe", "runners_boots", "focus_pendant", "wayfarer_treads", "hide_vest", "vigor_charm", "bulwark_plate", "stout_belt", "wardens_aegis", "sage_circlet", "focus_pendant", "hivecore_sigil"],
	},
	"hivemother": {
		"name": "Hivemother", "title": "The Commander", "role": "Swarm management", "tag": "Summons", "difficulty": 2,
		"bot": {"ranged": true, "keep": 7.0, "retreat": 0.45, "orbit": 0.35, "camp_cast": [0]},
		"playstyle": "Fights through her brood: hatch broodlings, send them in, spend them as living bombs.",
		"primary": "int", "str": 19.0, "agi": 13.0, "int": 24.0, "str_g": 2.1, "agi_g": 1.3, "int_g": 3.0,
		"dmg": 14.0, "range": 9.0, "atk_time": 1.5, "speed": 5.0, "armor": 2.0, "ranged": true,
		"skills": ["brood", "rally_pheromone", "volatile_sacrifice", "queens_carapace"],
		"skill_order": [0, 2, 0, 1, 0, 3, 0, 2, 2, 2, 3, 1, 1, 1, 3],
		"build": ["focus_pendant", "vigor_charm", "sage_circlet", "hivecore_sigil", "hide_vest", "bulwark_plate", "runners_boots", "focus_pendant", "wayfarer_treads", "stout_belt", "wardens_aegis", "iron_knuckles", "vigor_charm", "bloodthirst_fang"],
	},
	"sanguine": {
		"name": "Sanguine", "title": "The Blood Pact", "role": "Risk / sustain", "tag": "Blood", "difficulty": 2, "no_mana": true,
		"playstyle": "Pays for every skill with his own blood and drinks it back with every hit. The lower his HP, the harder he hits.",
		"primary": "str", "str": 25.0, "agi": 14.0, "int": 12.0, "str_g": 3.0, "agi_g": 1.4, "int_g": 1.1,
		"dmg": 22.0, "range": 2.2, "atk_time": 1.3, "speed": 5.2, "armor": 2.0, "ranged": false,
		"skills": ["crimson_cleave", "blood_rush", "hemorrhage", "undying_pact"],
		"skill_order": [0, 1, 0, 2, 0, 3, 0, 2, 1, 2, 3, 2, 1, 1, 3],
		"build": ["iron_knuckles", "vigor_charm", "bloodthirst_fang", "hide_vest", "vigor_charm", "bulwark_plate", "swift_gloves", "vigor_charm", "berserkers_torc", "runners_boots", "stout_belt", "wardens_aegis", "focus_pendant", "wayfarer_treads", "vigor_charm", "iron_knuckles", "bloodthirst_fang"],
		"bot": {"crowd": 5, "retreat": 0.22, "orbit": 0.3},
	},
	"snarewright": {
		"name": "Snarewright", "title": "The Trapper", "role": "Traps / planning", "tag": "Traps", "difficulty": 2,
		"playstyle": "Wins before the fight starts: lay traps, timed charges and tripwires where the pack will walk, then pick off the snared.",
		"primary": "agi", "str": 21.0, "agi": 23.0, "int": 16.0, "str_g": 2.2, "agi_g": 2.8, "int_g": 1.7,
		"dmg": 17.0, "range": 8.0, "atk_time": 1.35, "speed": 5.4, "armor": 3.0, "ranged": true,
		"skills": ["snare_trap", "blast_charge", "tripwire", "killing_field"],
		"skill_order": [0, 1, 0, 2, 0, 3, 1, 0, 1, 1, 3, 2, 2, 2, 3],
		"build": ["fletchers_quiver", "swift_gloves", "vigor_charm", "splinter_quiver", "runners_boots", "bloodthirst_fang", "hide_vest", "focus_pendant", "wayfarer_treads", "vigor_charm", "bulwark_plate", "stout_belt", "wardens_aegis", "iron_knuckles", "sage_circlet", "focus_pendant", "hivecore_sigil"],
		"bot": {"ranged": true, "keep": 7.0, "retreat": 0.5, "orbit": 0.4},
	},
	"twinhide": {
		"name": "Twinhide", "title": "The Two-Souled", "role": "Shapeshifter", "tag": "Forms", "difficulty": 3,
		"playstyle": "Two heroes in one: a spirit caster at range and a beast up close, each with its own Q and W. Shift right after a skill to get its twin ready at once.",
		"primary": "agi", "str": 20.0, "agi": 20.0, "int": 20.0, "str_g": 2.3, "agi_g": 2.3, "int_g": 2.2,
		"dmg": 16.0, "range": 8.0, "atk_time": 1.45, "speed": 5.2, "armor": 2.0, "ranged": true,
		"skills": ["spirit_lance", "moonwell", "shift", "twin_fury"],
		"beast_skills": ["rend", "pounce"],
		"skill_order": [0, 2, 1, 0, 2, 3, 0, 1, 0, 1, 3, 1, 2, 2, 3],
		"build": ["fletchers_quiver", "hide_vest", "vigor_charm", "skirmisher_cloak", "runners_boots", "bloodthirst_fang", "hide_vest", "focus_pendant", "wayfarer_treads", "vigor_charm", "bulwark_plate", "stout_belt", "wardens_aegis", "iron_knuckles", "sage_circlet", "focus_pendant", "hivecore_sigil"],
		"bot": {"ranged": true, "keep": 7.0, "retreat": 0.4, "orbit": 0.4},
	},
	"gravekeeper": {
		"name": "Gravekeeper", "title": "The Undertaker", "role": "Corpse summoner", "tag": "Corpses", "difficulty": 2,
		"playstyle": "Every enemy that falls leaves a grave. Raise skeletons from them, blow them up, or open every grave at once.",
		"primary": "int", "str": 18.0, "agi": 12.0, "int": 25.0, "str_g": 2.0, "agi_g": 1.2, "int_g": 3.0,
		"dmg": 15.0, "range": 8.5, "atk_time": 1.6, "speed": 5.0, "armor": 2.0, "ranged": true,
		"skills": ["raise_dead", "corpse_blast", "grave_chill", "open_graves"],
		"skill_order": [0, 2, 0, 1, 0, 3, 0, 1, 1, 1, 3, 2, 2, 2, 3],
		"build": ["focus_pendant", "vigor_charm", "sage_circlet", "hivecore_sigil", "hide_vest", "bulwark_plate", "runners_boots", "focus_pendant", "wayfarer_treads", "stout_belt", "wardens_aegis", "iron_knuckles", "vigor_charm", "bloodthirst_fang"],
		"bot": {"ranged": true, "keep": 7.5, "retreat": 0.45, "orbit": 0.35},
	},
	"stoneshaper": {
		"name": "Stoneshaper", "title": "The Mountain's Hand", "role": "Terrain / control", "tag": "Impact", "difficulty": 2,
		"playstyle": "Uses the arena as a weapon: shove foes into pillars, walls and each other. A body that hits something takes heavy damage and is stunned. Skin of stone: takes 20% less damage.",
		"primary": "str", "str": 26.0, "agi": 12.0, "int": 15.0, "str_g": 3.1, "agi_g": 1.3, "int_g": 1.6,
		"dmg": 28.0, "range": 2.3, "atk_time": 1.4, "speed": 4.8, "armor": 4.0, "ranged": false,
		"skills": ["rock_shove", "stone_ridge", "quake", "avalanche"],
		"skill_order": [0, 2, 0, 1, 0, 3, 2, 0, 2, 1, 3, 2, 1, 1, 3],
		"build": ["iron_knuckles", "vigor_charm", "hide_vest", "bulwark_plate", "focus_pendant", "runners_boots", "wayfarer_treads", "stout_belt", "wardens_aegis", "stout_belt", "iron_knuckles", "skullcrusher", "vigor_charm", "iron_knuckles", "bloodthirst_fang", "sage_circlet", "focus_pendant", "hivecore_sigil"],
		"bot": {"crowd": 6, "orbit": 0.2},
	},
	"gunsmith": {
		"name": "Gunsmith", "title": "The Deadshot", "role": "Long range", "tag": "Ammo", "difficulty": 2,
		"playstyle": "Longest reach in the Pit, but eight shots to a magazine. Reload on an empty chamber for incendiary rounds, and keep the pack at mortar range.",
		"primary": "agi", "str": 21.0, "agi": 25.0, "int": 14.0, "str_g": 2.3, "agi_g": 3.1, "int_g": 1.4,
		"dmg": 20.0, "range": 10.5, "atk_time": 0.9, "speed": 5.2, "armor": 3.0, "ranged": true,
		"skills": ["hot_reload", "scattershot", "mortar", "deadeye"],
		"skill_order": [1, 0, 2, 1, 2, 3, 1, 2, 1, 2, 3, 0, 0, 0, 3],
		"build": ["fletchers_quiver", "focus_pendant", "vigor_charm", "hawkeye_lens", "runners_boots", "bloodthirst_fang", "hide_vest", "focus_pendant", "wayfarer_treads", "vigor_charm", "bulwark_plate", "stout_belt", "wardens_aegis", "iron_knuckles", "sage_circlet", "focus_pendant", "hivecore_sigil"],
		"bot": {"ranged": true, "keep": 8.5, "retreat": 0.5, "orbit": 0.45},
	},
	"sunspeaker": {
		"name": "Sunspeaker", "title": "The Channeler", "role": "Stand-and-cast", "tag": "Channel", "difficulty": 3,
		"playstyle": "Stand your ground: Radiance builds while you stay still and powers every beam. Moving bleeds it away.",
		"primary": "int", "str": 21.0, "agi": 11.0, "int": 26.0, "str_g": 2.3, "agi_g": 1.1, "int_g": 3.2,
		"dmg": 14.0, "range": 8.5, "atk_time": 1.55, "speed": 5.0, "armor": 2.5, "ranged": true,
		"skills": ["sunbeam", "solar_flare", "sanctum", "dawn_lance"],
		"skill_order": [0, 1, 0, 2, 0, 3, 0, 1, 1, 1, 3, 2, 2, 2, 3],
		"build": ["focus_pendant", "vigor_charm", "sage_circlet", "hivecore_sigil", "hide_vest", "bulwark_plate", "runners_boots", "focus_pendant", "wayfarer_treads", "stout_belt", "wardens_aegis", "iron_knuckles", "vigor_charm", "bloodthirst_fang"],
		"bot": {"ranged": true, "keep": 8.0, "retreat": 0.5, "orbit": 0.1},
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

	# --- Sanguine (no mana: "hp" is the share of max HP each cast costs) ---
	"crimson_cleave": {"name": "Crimson Cleave", "max": 4, "mana": [0, 0, 0, 0], "hp": 0.05, "cd": [4.5, 4.0, 3.5, 3.0],
		"aim": "direction", "range": 3.6, "width": 3.0,
		"desc": "Costs 5% HP. Cleave in front of you; heal 30% of the damage dealt (60% below half HP)."},
	"blood_rush": {"name": "Blood Rush", "max": 4, "mana": [0, 0, 0, 0], "hp": 0.08, "cd": [10.0, 9.0, 8.0, 7.0],
		"aim": "direction", "range": 7.0, "width": 1.8,
		"desc": "Costs 8% HP. Charge through enemies, cutting each; every enemy hit heals 3% max HP."},
	"hemorrhage": {"name": "Hemorrhage", "max": 4, "mana": [0, 0, 0, 0], "hp": 0.06, "cd": [12.0, 11.0, 10.0, 9.0],
		"aim": "point", "range": 9.0, "radius": 3.5,
		"desc": "Costs 6% HP. Open wounds in an area: enemies bleed for 5 s. A bleeding enemy that dies heals you 4% max HP."},
	"undying_pact": {"name": "Undying Pact", "max": 3, "mana": [0, 0, 0], "hp": 0.0, "cd": [80.0, 70.0, 60.0],
		"aim": "self", "range": 0.0,
		"desc": "For 6/7/8 s you can't drop below 1 HP and every hit you deal heals you 25/35/45% of its damage."},
	# --- Snarewright ---
	"snare_trap": {"name": "Snare Trap", "max": 4, "mana": [30, 30, 30, 30], "cd": [6.0, 5.5, 5.0, 4.5],
		"aim": "point", "range": 9.0, "radius": 1.0,
		"desc": "Set a trap that snaps on the first foe to step on it: damage and root. 2 charges (3 at rank 3). Up to 4-7 traps."},
	"blast_charge": {"name": "Blast Charge", "max": 4, "mana": [60, 65, 70, 75], "cd": [9.0, 8.5, 8.0, 7.5],
		"aim": "point", "range": 10.0, "radius": 3.5,
		"desc": "Plant a charge that blows up after 2 s, knocking foes back. Traps in the blast snap too."},
	"tripwire": {"name": "Tripwire", "max": 4, "mana": [50, 50, 55, 55], "cd": [12.0, 11.0, 10.0, 9.0],
		"aim": "wall", "range": 9.0,
		"desc": "String a wire for 8 s. Foes that cross it are cut, slowed and snared."},
	"killing_field": {"name": "Killing Field", "max": 3, "mana": [120, 140, 160], "cd": [60.0, 52.0, 45.0],
		"aim": "point", "range": 10.0, "radius": 4.0,
		"desc": "Throw a ring of 6/8/10 armed traps. For 8 s your bolts deal double damage to snared foes."},
	# --- Twinhide (Q and W change with the form; E shifts) ---
	"spirit_lance": {"name": "Spirit Lance", "max": 4, "mana": [50, 55, 60, 65], "cd": [6.0, 5.5, 5.0, 4.5],
		"aim": "direction", "range": 12.0, "width": 1.4,
		"desc": "Spirit form. Hurl a lance of light that pierces every foe in a line."},
	"moonwell": {"name": "Moonwell", "max": 4, "mana": [70, 75, 80, 85], "cd": [14.0, 13.0, 12.0, 11.0],
		"aim": "point", "range": 9.0, "radius": 3.0,
		"desc": "Spirit form. Open a pool for 5 s that heals you while you stand in it and slows foes."},
	"rend": {"name": "Rend", "max": 4, "mana": [35, 35, 40, 40], "cd": [4.0, 3.6, 3.2, 2.8],
		"aim": "direction", "range": 3.2, "width": 3.0,
		"desc": "Beast form. Rake everything in front of you and heal 25% of the damage."},
	"pounce": {"name": "Pounce", "max": 4, "mana": [45, 45, 50, 50], "cd": [9.0, 8.0, 7.0, 6.0],
		"aim": "point", "range": 8.0, "radius": 2.5,
		"desc": "Beast form. Leap to a spot, damaging and stunning foes where you land."},
	"shift": {"name": "Shift", "max": 4, "mana": [20, 20, 20, 20], "cd": [4.0, 3.5, 3.0, 2.5],
		"aim": "self", "range": 0.0,
		"desc": "Swap between spirit and beast form with a burst. Shift within 2 s of a skill and its twin is ready at once."},
	"twin_fury": {"name": "Twin Fury", "max": 3, "mana": [100, 120, 140], "cd": [60.0, 52.0, 45.0],
		"aim": "self", "range": 0.0,
		"desc": "For 10/12/14 s Shift is free and instant, each shift bursts twice as hard, and you keep both forms' strengths."},
	# --- Gravekeeper ---
	"raise_dead": {"name": "Raise Dead", "max": 4, "mana": [40, 45, 50, 55], "cd": [5.0, 4.5, 4.0, 3.5],
		"aim": "self", "range": 10.0,
		"desc": "Raise 2 skeletons (3 at rank 3) from graves near you. Up to 4/6/8/10 skeletons."},
	"corpse_blast": {"name": "Corpse Blast", "max": 4, "mana": [60, 65, 70, 75], "cd": [7.0, 6.5, 6.0, 5.5],
		"aim": "point", "range": 11.0, "radius": 4.0,
		"desc": "Every grave and skeleton in the area explodes, hurting foes around it."},
	"grave_chill": {"name": "Grave Chill", "max": 4, "mana": [70, 75, 80, 85], "cd": [13.0, 12.0, 11.0, 10.0],
		"aim": "point", "range": 10.0, "radius": 3.5,
		"desc": "Curse an area for 6 s: foes inside are slowed and wither. Each one that dies there leaves 2 graves."},
	"open_graves": {"name": "Open the Graves", "max": 3, "mana": [150, 175, 200], "cd": [75.0, 65.0, 55.0],
		"aim": "self", "range": 14.0,
		"desc": "Raise every grave nearby (up to 8/10/12) plus 3 more from the earth as empowered skeletons."},
	# --- Stoneshaper ---
	"rock_shove": {"name": "Rock Shove", "max": 4, "mana": [45, 50, 55, 60], "cd": [5.0, 4.6, 4.2, 3.8],
		"aim": "direction", "range": 3.6, "width": 3.2,
		"desc": "Shove everything in front of you. Foes that slam into a pillar, wall, ridge or another foe take impact damage and are stunned."},
	"stone_ridge": {"name": "Stone Ridge", "max": 4, "mana": [70, 75, 80, 85], "cd": [13.0, 12.0, 11.0, 10.0],
		"aim": "wall", "range": 9.0,
		"desc": "Raise a rock ridge foes can't cross. Good to shove them into."},
	"quake": {"name": "Quake", "max": 4, "mana": [60, 65, 70, 75], "cd": [9.0, 8.5, 8.0, 7.5],
		"aim": "self", "range": 4.5,
		"desc": "Stomp: damage and slow around you and throw foes outward."},
	"avalanche": {"name": "Avalanche", "max": 3, "mana": [120, 140, 160], "cd": [50.0, 44.0, 38.0],
		"aim": "direction", "range": 18.0, "width": 2.2,
		"desc": "Roll a huge boulder that crushes and flings every foe in its path, then shatters."},
	# --- Gunsmith ---
	"hot_reload": {"name": "Hot Reload", "max": 4, "mana": [20, 20, 20, 20], "cd": [8.0, 7.0, 6.0, 5.0],
		"aim": "self", "range": 0.0,
		"desc": "Reload instantly. On an empty or last bullet, the new magazine is incendiary: +35/45/55/65% damage and burn."},
	"scattershot": {"name": "Scattershot", "max": 4, "mana": [40, 40, 45, 45], "cd": [6.0, 5.5, 5.0, 4.5],
		"aim": "direction", "range": 7.0, "width": 4.0,
		"desc": "Fire every loaded bullet at once as a spray of pellets (2 per bullet) that knocks foes back."},
	"mortar": {"name": "Mortar", "max": 4, "mana": [60, 65, 70, 75], "cd": [10.0, 9.5, 9.0, 8.5],
		"aim": "point", "range": 14.0, "radius": 3.2,
		"desc": "Lob a shell (at least 4 m away) that lands after 1 s: big area damage and a slow."},
	"deadeye": {"name": "Deadeye", "max": 3, "mana": [100, 120, 140], "cd": [45.0, 40.0, 35.0],
		"aim": "self", "range": 16.0,
		"desc": "Mark up to 4/5/6 foes (bosses first), then fire a piercing shot at each. Refills the magazine."},
	# --- Sunspeaker ---
	"sunbeam": {"name": "Sunbeam", "max": 4, "mana": [50, 55, 60, 65], "cd": [7.0, 6.5, 6.0, 5.5],
		"aim": "direction", "range": 11.0, "width": 1.4,
		"desc": "Channel a beam for up to 3 s that slowly tracks foes. Moving ends it. Damage grows with Radiance."},
	"solar_flare": {"name": "Solar Flare", "max": 4, "mana": [60, 65, 70, 75], "cd": [8.0, 7.5, 7.0, 6.5],
		"aim": "point", "range": 12.0, "radius": 3.0,
		"desc": "Call down a burst of sunfire after a moment. Damage grows with Radiance."},
	"sanctum": {"name": "Sanctum", "max": 4, "mana": [70, 70, 75, 75], "cd": [16.0, 15.0, 14.0, 13.0],
		"aim": "self", "range": 0.0, "radius": 3.5,
		"desc": "Consecrate the ground for 6 s: inside it you heal, gain Radiance twice as fast, and foes are slowed."},
	"dawn_lance": {"name": "Dawn Lance", "max": 3, "mana": [140, 160, 180], "cd": [60.0, 52.0, 45.0],
		"aim": "direction", "range": 26.0, "width": 3.0,
		"desc": "Channel for 1.2 s, then fire a lance of dawn across the arena. Spends all Radiance for more damage."},
}

## Items. kind: basic / advanced / consumable. "from" = recipe components.
## "only": "melee" / "ranged": anyone can buy the item, but its special effect only works on attacks of that kind
## (like a cleave that only melee swings carry). The shop marks them; a hero of the other kind gets just the stats.
const ITEM_ORDER := ["iron_knuckles", "swift_gloves", "hide_vest", "vigor_charm", "focus_pendant", "runners_boots", "stout_belt", "sage_circlet",
	"brawlers_wraps", "fletchers_quiver", "hooded_lantern", "oilskin_cloak",
	"emberbrand", "bulwark_plate", "wayfarer_treads", "hivecore_sigil", "bloodthirst_fang", "wardens_aegis",
	"cleaving_axe", "skullcrusher", "berserkers_torc", "hawkeye_lens", "splinter_quiver", "skirmisher_cloak",
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
	# melee / ranged / weather items
	"brawlers_wraps": {"name": "Brawler's Wraps", "kind": "basic", "cost": 300,
		"stats": {"as": 0.12, "armor": 3.0, "hit_heal": 6.0}, "desc": "+12% attack speed, +3 armor. Every hit you land heals you 6 HP"},
	"fletchers_quiver": {"name": "Fletcher's Quiver", "kind": "basic", "cost": 300,
		"stats": {"dmg": 8.0, "range": 1.0}, "desc": "+8 damage. Ranged heroes also get +1 m attack range"},
	"hooded_lantern": {"name": "Hooded Lantern", "kind": "basic", "cost": 250,
		"stats": {"hp": 120.0, "lantern": 1.0}, "desc": "+120 HP. Fog doesn't shorten your range, and in Fog or under a Blood Moon you deal +10% damage"},
	"oilskin_cloak": {"name": "Oilskin Cloak", "kind": "basic", "cost": 250,
		"stats": {"armor": 3.0, "weatherproof": 1.0}, "desc": "+3 armor. Rain doesn't slow you, wind doesn't push you, lightning and embers hurt you half as much"},
	"cleaving_axe": {"name": "Cleaving Axe", "kind": "advanced", "cost": 400, "only": "melee", "from": ["iron_knuckles", "brawlers_wraps"],
		"stats": {"dmg": 18.0, "as": 0.12, "armor": 3.0, "hit_heal": 6.0, "cleave": 0.4},
		"desc": "+18 damage, Wraps stats. Melee hits splash 40% damage on foes around the target"},
	"skullcrusher": {"name": "Skullcrusher", "kind": "advanced", "cost": 450, "from": ["iron_knuckles", "stout_belt"],
		"stats": {"dmg": 14.0, "str": 6.0, "bash": 1.0}, "desc": "+14 damage, +6 Strength. Every 4th hit stuns for 0.8 s and deals 60% extra"},
	"berserkers_torc": {"name": "Berserker's Torc", "kind": "advanced", "cost": 400, "from": ["vigor_charm", "swift_gloves"],
		"stats": {"hp": 250.0, "as": 0.15, "berserk": 1.0}, "desc": "+250 HP, +15% attack speed. Below 40% HP: +40% attack speed and 15% lifesteal"},
	"hawkeye_lens": {"name": "Hawkeye Lens", "kind": "advanced", "cost": 400, "from": ["fletchers_quiver", "focus_pendant"],
		"stats": {"dmg": 16.0, "range": 2.0, "mana": 150.0, "mana_regen": 1.0, "far_shot": 0.25},
		"desc": "+16 damage, +150 mana. Attacks on foes 6 m or more away deal +25%. Ranged heroes also get +2 m range"},
	"splinter_quiver": {"name": "Splinter Quiver", "kind": "advanced", "cost": 450, "only": "ranged", "from": ["fletchers_quiver", "swift_gloves"],
		"stats": {"dmg": 10.0, "range": 1.0, "as": 0.2, "split": 0.45},
		"desc": "+10 damage, +20% attack speed. Every shot ricochets to 2 nearby foes for 45% damage"},
	"skirmisher_cloak": {"name": "Skirmisher's Cloak", "kind": "advanced", "cost": 400, "from": ["hide_vest", "fletchers_quiver"],
		"stats": {"armor": 5.0, "dmg": 8.0, "range": 1.0, "ms": 0.08, "chill": 0.25},
		"desc": "+5 armor, +8% move speed. Attacks slow foes by 25% for 1.5 s"},
	"healing_draught": {"name": "Healing Draught", "kind": "consumable", "cost": 90, "stack": 5, "active": "heal_potion", "active_cd": 1.0,
		"desc": "Heal 400 HP over 8 s. Stacks to 5"},
	"mana_draught": {"name": "Mana Draught", "kind": "consumable", "cost": 90, "stack": 5, "active": "mana_potion", "active_cd": 1.0,
		"desc": "Restore 250 mana over 6 s. Stacks to 5"},
	"tome_of_might": {"name": "Tome of Might", "kind": "consumable", "cost": 500, "noslot": true,
		"desc": "+2 primary attribute permanently (no slot)"},
	"phoenix_feather": {"name": "Phoenix Feather", "kind": "consumable", "cost": 1500, "noslot": true, "max_per_run": 1,
		"desc": "+1 life (once per run, no slot)"},
}

## Weather: rolled for every wave (it is already falling in camp, so the shop visit can answer it) and sometimes
## turning mid-wave. speed: everyone's move speed; fire: damage of FIRE_TAGS and burns; range: shot range (hero and foes);
## wind: shots with the wind deal up to +wind share, shots into it as much less, and everyone drifts downwind;
## foe_dmg / foe_speed: Blood Moon. lightning / embers: telegraphed strikes / burning patches during waves.
const WEATHER := {
	"clear": {"name": "Clear Skies", "color": Color(1.0, 0.88, 0.6), "desc": "Calm air. Nothing changes."},
	"rain": {"name": "Rain", "color": Color(0.55, 0.75, 1.0), "speed": 0.9, "fire": 0.6,
		"desc": "Everyone moves 10% slower. Fire and burns deal 40% less."},
	"storm": {"name": "Thunderstorm", "color": Color(0.7, 0.8, 1.2), "speed": 0.9, "fire": 0.6, "lightning": true,
		"desc": "Rain, and lightning strikes the glowing rings. It hurts foes and you alike."},
	"fog": {"name": "Fog", "color": Color(0.8, 0.85, 0.9), "range": 0.7,
		"desc": "Shots reach 30% less far, yours and theirs. A good day for melee."},
	"gale": {"name": "Gale", "color": Color(0.85, 0.95, 0.75), "wind": 0.3,
		"desc": "Wind pushes everyone. Shots with the wind hit 30% harder, shots into it 30% softer."},
	"emberfall": {"name": "Emberfall", "color": Color(1.0, 0.55, 0.25), "fire": 1.5, "embers": true,
		"desc": "Fire and burns deal 50% more. Falling embers set patches of sand alight."},
	"bloodmoon": {"name": "Blood Moon", "color": Color(1.0, 0.35, 0.35), "foe_dmg": 1.15, "foe_speed": 1.1,
		"desc": "Foes hit 15% harder and move 10% faster."},
}
const FIRE_TAGS := ["Emberbrand Burn", "Ember Totem", "Ash Wall", "Mortar", "Ember Patch"]
const WIND_DRIFT := 1.1           # m/s everyone drifts downwind in a Gale
const WEATHER_SHIFT_CHANCE := 0.4 # a regular wave from wave 3 on turns mid-fight this often
const LIGHTNING_R := 2.3
const LIGHTNING_TELE := 1.3
const LIGHTNING_HERO := 0.16      # share of the hero's max HP a strike takes
const EMBER_R := 1.9
const EMBER_TIME := 6.0
const EMBER_HERO := 0.04          # share of the hero's max HP per second in a patch


## Weather that can roll on wave `w`, with weights. Wave 1 is always clear.
static func weather_pool(w: int) -> Dictionary:
	if w <= 1:
		return {"clear": 1}
	var pool := {"clear": 4, "rain": 3, "fog": 2, "gale": 2}
	if w >= 4:
		pool["storm"] = 2
		pool["emberfall"] = 2
	if w >= 8:
		pool["bloodmoon"] = 1
	return pool


## Enemy base stats at wave 1.
const ENEMIES := {
	"gnawer": {"name": "Gnawer", "hp": 55.0, "dmg": 7.0, "atk_time": 1.0, "range": 1.0, "speed": 5.0, "armor": 0.0, "radius": 0.45, "xp": 9.0, "gold": 4.0},
	"shieldbearer": {"name": "Shieldbearer", "hp": 230.0, "dmg": 15.0, "atk_time": 1.5, "range": 1.3, "speed": 2.8, "armor": 5.0, "radius": 0.75, "xp": 24.0, "gold": 10.0},
	"hexcaster": {"name": "Hexcaster", "hp": 90.0, "dmg": 11.0, "atk_time": 2.2, "range": 9.0, "speed": 3.4, "armor": 0.0, "radius": 0.5, "xp": 20.0, "gold": 9.0},
	"burrower": {"name": "Burrower", "hp": 140.0, "dmg": 13.0, "atk_time": 1.2, "range": 1.2, "speed": 4.0, "armor": 2.0, "radius": 0.55, "xp": 20.0, "gold": 9.0},
	"bloater": {"name": "Bloater", "hp": 170.0, "dmg": 9.0, "atk_time": 1.4, "range": 1.2, "speed": 2.4, "armor": 0.0, "radius": 0.8, "xp": 20.0, "gold": 9.0},
	# Buffers (wave 7+): weak on their own, but they make the pack around them dangerous. Kill them first.
	"chanter": {"name": "Ward Chanter", "hp": 150.0, "dmg": 6.0, "atk_time": 1.6, "range": 1.2, "speed": 3.3, "armor": 1.0, "radius": 0.5, "xp": 30.0, "gold": 14.0, "support": true},
	"drummer": {"name": "War Drummer", "hp": 175.0, "dmg": 8.0, "atk_time": 1.5, "range": 1.2, "speed": 3.5, "armor": 2.0, "radius": 0.55, "xp": 30.0, "gold": 14.0, "support": true},
	"choir_add": {"name": "Choir Voice", "hp": 240.0, "dmg": 13.0, "atk_time": 1.3, "range": 1.2, "speed": 4.0, "armor": 1.0, "radius": 0.5, "xp": 10.0, "gold": 4.0},
	# Bosses (absolute numbers; only lightly scaled)
	"pit_brute": {"name": "Pit Brute", "hp": 3400.0, "dmg": 38.0, "atk_time": 1.6, "range": 2.2, "speed": 3.6, "armor": 4.0, "radius": 1.5, "xp": 400.0, "gold": 0.0, "boss": true},
	"matron": {"name": "Twin Matron", "hp": 3600.0, "dmg": 34.0, "atk_time": 1.5, "range": 2.0, "speed": 3.4, "armor": 4.0, "radius": 1.3, "xp": 350.0, "gold": 0.0, "boss": true},
	"hollow_choir": {"name": "The Hollow Choir", "hp": 12000.0, "dmg": 50.0, "atk_time": 2.0, "range": 2.5, "speed": 1.6, "armor": 5.0, "radius": 1.8, "xp": 900.0, "gold": 0.0, "boss": true},
	"warden": {"name": "The Warden of the Pit", "hp": 23000.0, "dmg": 70.0, "atk_time": 1.5, "range": 2.6, "speed": 3.6, "armor": 8.0, "radius": 1.9, "xp": 0.0, "gold": 0.0, "boss": true},
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

## Buffer auras. A Chanter makes nearby foes immune to damage; a Drummer doubles their damage.
## Neither affects bosses or its own kind (two Chanters can't shield each other).
const AURAS := {
	"chanter": {"radius": 3.8, "color": Color(1.0, 0.85, 0.35), "from_wave": 9,
		"hint": "Ward Chanter! Foes near it can't be hurt. Tap it and kill it first."},
	"drummer": {"radius": 5.0, "color": Color(1.0, 0.3, 0.2), "from_wave": 7,
		"hint": "War Drummer! Foes near it hit twice as hard. Take it out first."},
}
const DRUM_DMG := 2.0

## Barrels, laid out like Life in Arena: big solid barrel stacks filling three corners of the arena. Smash your way
## in to dig a corridor (tap a barrel, or push into it) and fight from the end of it: foes can only follow you single
## file. Barrels sit on a square grid (BARREL_GRID apart), so a corridor one barrel wide (1.3 m of room) lets every hero and regular foes through
## but not wide ones (Shieldbearers, Bloaters), which have to smash it wider. Powder kegs are packed into the stacks.
## A stack is every grid cell past the corner lines (sx * x >= t and sz * z >= t) inside the arena wall.
const STACKS := [
	{"sx": 1, "sz": 1, "t": 7.5, "kegs": [Vector3(9.6, 0, 17.5), Vector3(14.0, 0, 9.6)]},
	{"sx": -1, "sz": 1, "t": 7.5, "kegs": [Vector3(-9.6, 0, 17.5), Vector3(-14.0, 0, 9.6)]},
	{"sx": -1, "sz": -1, "t": 10.0, "kegs": [Vector3(-10.6, 0, -18.0), Vector3(-15.0, 0, -10.6)]},
]
const BARREL_GRID := 1.15          # barrel spacing
const STACK_R := 21.6              # cells out to here are filled (the outer ones tuck against the wall)
const KEGS := [Vector3(-4.5, 0, -17.0), Vector3(10.5, 0, -13.0)]   # loose kegs out in the open
const BARREL_R := 0.5
const BARREL_HP := 8.0          # hero swings deal BARREL_HERO_HIT, enemy swings 1 (big ones 2)
const BARREL_HERO_HIT := 5.0
const KEG_RADIUS := 3.6
const KEG_FUSE := 0.9
const KEG_CHAIN_FUSE := 0.25

## Pit pressure: a wave that drags on enrages the enemies still alive (more damage, faster).
const BOSS_ENRAGE_TIME := {5: 100.0, 10: 120.0, 15: 150.0, 20: 300.0}
const ENRAGE_DMG := 1.3
const ENRAGE_SPEED := 1.2

## Hexcaster bolts hex the hero: healing received is reduced while hexed.
const HEX_TIME := 4.0
const HEX_HEAL_MULT := 0.5
## Hex bolts are dodgeable: slow, they only turn a little after the hero (rad/s), and pillars and barrels stop them.
## The caster glows and holds its cast for HEX_WINDUP seconds before it lets go.
const HEX_BOLT_SPEED := 7.0
const HEX_BOLT_TURN := 0.35
const HEX_BOLT_LIFE := 2.6
const HEX_WINDUP := 0.5

const BOSS_WAVES := {5: "pit_brute", 10: "matron", 15: "hollow_choir", 20: "warden"}
const BOSS_TITLES := {5: "Pit Brute", 10: "Twin Matrons", 15: "The Hollow Choir", 20: "The Warden of the Pit"}
const BOSS_HINTS := {5: "Glowing ground means a slam or a charge is coming. Step out!",
	10: "The Matrons heal each other while close. Focus one down!",
	15: "The Choir's beam sweeps the arena. Keep moving around it.",
	20: "The Warden uses every trick in the Pit. Stay sharp!"}

## Every wave has a name and a gimmick, previewed in camp so the prep phase is a build decision.
## mods: extra units per kind (added to the base mix); rule: the wave's twist (see WAVE_RULES);
## captain: the kind that leads the wave as a tougher, named captain ("" on boss waves).
const WAVES := {
	1: {"name": "The Hungry Pack", "captain": "gnawer", "rule": "", "mods": {},
		"desc": "Gnawers and their alpha. Kill the captain for a bounty."},
	2: {"name": "Shield Wall", "captain": "shieldbearer", "rule": "", "mods": {"shieldbearer": 2},
		"desc": "Shieldbearers block hits from the front. Flank them."},
	3: {"name": "The Hexwood", "captain": "hexcaster", "rule": "", "mods": {"hexcaster": 2},
		"desc": "Hexcasters from range. Their bolts halve your healing: sidestep them or hide behind a pillar."},
	4: {"name": "Bloodthirsty", "captain": "gnawer", "rule": "bloodthirsty", "mods": {"gnawer": 4},
		"desc": "Every hit they land heals them. Don't trade blows bare-handed."},
	5: {"name": "The Pit Brute", "captain": "", "rule": "", "mods": {}, "desc": "Boss. Glowing ground means a slam or a charge."},
	6: {"name": "Ambush", "captain": "burrower", "rule": "", "mods": {"burrower": 2},
		"desc": "Burrowers tunnel under the sand and burst up beside you."},
	7: {"name": "Powder Keg", "captain": "bloater", "rule": "explosive", "mods": {"bloater": 1},
		"desc": "Many elites, and every elite explodes when it dies."},
	8: {"name": "Phantoms", "captain": "gnawer", "rule": "evasive", "mods": {"gnawer": 4},
		"desc": "They dodge a third of weapon attacks. Spells always land."},
	9: {"name": "The Choir Gate", "captain": "chanter", "rule": "", "mods": {},
		"desc": "Ward Chanters make their pack immune. Cut through to them."},
	10: {"name": "Twin Matrons", "captain": "", "rule": "", "mods": {}, "desc": "Boss. The Matrons heal each other while close."},
	11: {"name": "Stunners", "captain": "shieldbearer", "rule": "stunning", "mods": {"shieldbearer": 2},
		"desc": "Shieldbearers bash every second swing. Armor up."},
	12: {"name": "Blood Drums", "captain": "drummer", "rule": "bloodthirsty", "mods": {"drummer": 1},
		"desc": "Drummers double their damage, and every hit heals them."},
	13: {"name": "Spellwarded", "captain": "shieldbearer", "rule": "spellward", "mods": {"shieldbearer": 1},
		"desc": "They shrug off half of all magic damage. Bring weapons, not spells."},
	14: {"name": "Hexstorm", "captain": "hexcaster", "rule": "warded", "mods": {"hexcaster": 3},
		"desc": "Hexcasters behind Warding elites. Kill the warders first."},
	15: {"name": "The Hollow Choir", "captain": "", "rule": "", "mods": {}, "desc": "Boss. The beam sweeps the arena. Keep moving."},
	16: {"name": "Frenzy", "captain": "gnawer", "rule": "frenzy", "mods": {"gnawer": 4},
		"desc": "Everything moves 20% faster and attacks faster."},
	17: {"name": "Silent Wall", "captain": "shieldbearer", "rule": "spellward", "mods": {"chanter": 1, "shieldbearer": 1},
		"desc": "Spellwarded shields and Chanters. Weapons win this one."},
	18: {"name": "Chain Reaction", "captain": "bloater", "rule": "explosive", "mods": {"bloater": 2},
		"desc": "Bloaters and exploding elites. Don't fight in a crowd."},
	19: {"name": "Mutants", "captain": "burrower", "rule": "mutants", "mods": {},
		"desc": "Half of them are elites with random affixes."},
	20: {"name": "The Warden's Gauntlet", "captain": "", "rule": "", "mods": {},
		"desc": "Final boss. As he weakens, the Pit's earlier bosses come back."},
}
const WAVE_RULES := {
	"bloodthirsty": {"name": "Bloodthirsty", "color": Color(1.0, 0.35, 0.35)},
	"explosive": {"name": "Explosive", "color": Color(1.0, 0.7, 0.3)},
	"spellward": {"name": "Spellwarded", "color": Color(0.55, 0.8, 1.0)},
	"stunning": {"name": "Stunning", "color": Color(0.75, 0.8, 1.0)},
	"evasive": {"name": "Evasive", "color": Color(0.8, 0.7, 1.0)},
	"warded": {"name": "Warded", "color": Color(0.5, 0.85, 1.55)},
	"frenzy": {"name": "Frenzied", "color": Color(1.0, 0.5, 0.4)},
	"mutants": {"name": "Mutants", "color": Color(0.7, 1.0, 0.5)},
}
const BLOODTHIRST_HEAL := 0.4     # share of damage dealt that a Bloodthirsty enemy heals
const SPELLWARD_MAGIC := 0.5      # magic damage taken on Spellwarded waves
const EVADE_CHANCE := 0.33
const FRENZY_SPEED := 1.2

## Captains: every regular wave is led by a named, tougher version of its signature enemy.
const CAPTAIN_NAMES := {"gnawer": "Alpha Gnawer", "shieldbearer": "Shield Sergeant", "hexcaster": "Hex Matriarch",
	"burrower": "Tunnel King", "bloater": "Plague Belly", "chanter": "High Chanter", "drummer": "Drum Major"}
const CAPTAIN_HP := 650.0         # wave-1 captain HP, scaled by hp_mult
const CAPTAIN_DMG_MULT := 1.9
const CAPTAIN_SCALE := 1.5


static func wave_info(w: int) -> Dictionary:
	return WAVES.get(w, {"name": "Wave %d" % w, "captain": "gnawer", "rule": "", "mods": {}, "desc": ""})


static func wave_rule(w: int) -> String:
	return wave_info(w).get("rule", "")


static func captain_hp(w: int) -> float:
	return CAPTAIN_HP * pow(hp_mult(w), 0.8)


static func captain_gold(w: int) -> int:
	return 45 + 15 * w


## Final gauntlet: below each HP threshold the Warden withdraws and an echo of an earlier boss returns.
const GAUNTLET := [
	{"at": 0.75, "boss": "pit_brute", "hp": 0.45, "title": "Echo of the Pit Brute"},
	{"at": 0.5, "boss": "matron", "hp": 0.35, "title": "Echoes of the Twin Matrons"},
	{"at": 0.25, "boss": "hollow_choir", "hp": 0.25, "title": "Echo of the Hollow Choir"},
]

const GATES := {"N": Vector3(0, 0, -21.0), "E": Vector3(21.0, 0, 0), "W": Vector3(-21.0, 0, 0), "NE": Vector3(14.8, 0, -14.8)}
const GATE_NAMES := ["N", "E", "W", "NE"]
const PILLARS := [Vector3(-9, 0, -6), Vector3(9, 0, -6), Vector3(0, 0, 10)]
const PILLAR_R := 1.6
const ARENA_R := 22.0
# Arena changes in boss fights (scripts/arena.gd)
const RUBBLE_W := 1.3          # half-width of a fallen pillar
const RUBBLE_LEN := 7.0        # how far a fallen pillar reaches from its base
const TOPPLE_TIME := 0.75      # fall time (telegraphed)
const TOPPLE_STUN := 3.0       # a boss that charges into a pillar is stunned this long
const CRUSH_BOSS := 0.04       # max-hp share a falling pillar takes off a boss
const CRUSH_FOE := 0.6         # ... off other foes
const CRUSH_HERO := 0.25       # ... off the hero
const RIM_STEPS := [18.0, 15.0]  # walkable radius after each Warden phase change
const RIM_WARN := 3.0          # seconds of cracking before the rim falls
const RIM_HERO := 0.2          # max-hp share the hero loses scrambling off a falling rim
const CAMP_CENTER := Vector3(0, 0, 40)
const CAMP_R := 9.0
const SHOP_POS := Vector3(-4, 0, 42)
const FOUNTAIN_POS := Vector3(4, 0, 42)
const CAMP_SPAWN := Vector3(0, 0, 37)
const ARENA_SPAWN := Vector3(0, 0, 15)

const TOTAL_WAVES := 20
const START_GOLD := 400
const START_LIVES := 3
const PREP_TIME := 20.0
const FIRST_PREP_TIME := 30.0


static func hp_mult(w: int) -> float:
	var x := float(w - 1)
	# steeper late (12-20); the early bump is in early_pressure()
	return (1.0 + 0.10 * x + 0.014 * x * x + 0.0009 * x * x * x) * (1.0 + EARLY_HP * early_pressure(w))


## 0..1: how hard the early waves lean on you. Peaks on waves 4-9, when the shop should already be paying off,
## and fades out by wave 13 where the regular curve takes over. Skills and dodging alone can't keep up.
static func early_pressure(w: int) -> float:
	if w <= 9:
		return minf(1.0, float(w) / 4.0)
	return clampf(float(13 - w) / 4.0, 0.0, 1.0)


const EARLY_HP := 0.3
const EARLY_DMG := 0.4


## Enemy damage is a notch higher since barrel stacks let you fight the pack one at a time.
const DMG_BASE := 1.1
const BOSS_DMG_BASE := 1.1


static func dmg_mult(w: int) -> float:
	var x := float(w - 1)
	return DMG_BASE * (1.0 + 0.05 * x + 0.006 * x * x + 0.0001 * x * x * x) * (1.0 + EARLY_DMG * early_pressure(w))


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
	return 1.2 + 0.09 * float(w - 1)


static func xp_mult(w: int) -> float:
	return 1.0 + 0.06 * float(w - 1)


static func xp_to_next(level: int) -> float:
	return 90.0 + 55.0 * float(level - 1)


static func wave_clear_gold(w: int) -> int:
	return 100 + 20 * w


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
	if w >= AURAS["drummer"]["from_wave"]:
		counts["drummer"] = 1 + int(w >= 16)
	if w >= AURAS["chanter"]["from_wave"]:
		counts["chanter"] = 1 + int(w >= 18)
	var mods: Dictionary = wave_info(w).get("mods", {})
	for k in mods:
		counts[k] = int(counts.get(k, 0)) + int(mods[k])
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
	for kind in ["drummer", "chanter", "shieldbearer", "hexcaster", "burrower", "bloater", "gnawer"]:
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
