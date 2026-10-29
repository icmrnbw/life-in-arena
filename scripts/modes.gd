class_name Modes
extends RefCounted
## Replayability content: difficulty tiers, game modes, Daily Run modifiers, hero unlocks, Endless waves and the run score.
## A run's settings live in Run.cfg (built by config()); Profile keeps what carries over between runs.

## Heroes everyone starts with: all of them (Ernest's call). UNLOCKS below only applies to heroes left out of this
## list, so moving heroes out of it brings unlock-by-playing back without other changes.
const STARTER_HEROES := DB.HERO_ORDER

## "stat": what Profile.progress() measures, "n": the target. Order = the order they tend to unlock in.
const UNLOCKS := {
	"sanguine": {"text": "Clear wave 3 with any hero", "stat": "best_wave", "n": 3},
	"snarewright": {"text": "Beat the Pit Brute (clear wave 5)", "stat": "best_wave", "n": 5},
	"twinhide": {"text": "Clear 20 waves in total", "stat": "total_waves", "n": 20},
	"gravekeeper": {"text": "Clear wave 8 with two different heroes", "stat": "heroes_at_8", "n": 2},
	"stoneshaper": {"text": "Defeat 1,000 enemies in total", "stat": "kills", "n": 1000},
	"gunsmith": {"text": "Beat the Twin Matrons (clear wave 10)", "stat": "best_wave", "n": 10},
	"sunspeaker": {"text": "Beat the Hollow Choir (clear wave 15)", "stat": "best_wave", "n": 15},
	"duelist": {"text": "Clear wave 6 with any hero", "stat": "best_wave", "n": 6},
	"vanguard": {"text": "Clear wave 4 with any hero", "stat": "best_wave", "n": 4},
	"nightblade": {"text": "Defeat 2,000 enemies in total", "stat": "kills", "n": 2000},
	"skyspear": {"text": "Clear 40 waves in total", "stat": "total_waves", "n": 40},
	"frostweaver": {"text": "Clear wave 8 with two different heroes", "stat": "heroes_at_8", "n": 2},
	"stormcaller": {"text": "Beat the Twin Matrons (clear wave 10)", "stat": "best_wave", "n": 10},
	"alchemist": {"text": "Clear 60 waves in total", "stat": "total_waves", "n": 60},
	"chronomancer": {"text": "Clear wave 8 with three different heroes", "stat": "heroes_at_8", "n": 3},
}

const TIER_ORDER := ["normal", "hard", "extreme"]
## hp / dmg: enemy multipliers; gold / xp: reward multipliers; elite: elite chance multiplier, elite_from: first wave
## with elites; score: score multiplier. Hard is the tuning the game has been balanced at so far.
const TIERS := {
	"normal": {"name": "Normal", "hp": 0.72, "dmg": 0.72, "gold": 1.15, "xp": 1.15, "lives": 3, "elite": 0.6, "elite_from": 4, "score": 0.6,
		"desc": "Gentler waves and more gold. Learn the heroes and the bosses.", "color": Color(0.55, 0.9, 0.5)},
	"hard": {"name": "Hard", "hp": 1.0, "dmg": 1.0, "gold": 1.0, "xp": 1.0, "lives": 3, "elite": 1.0, "elite_from": 4, "score": 1.0,
		"desc": "The Pit as it was built: shop well, dig into the barrel stacks, kill the buffers first.", "color": Color(1.0, 0.75, 0.3)},
	"extreme": {"name": "Extreme", "hp": 1.25, "dmg": 1.2, "gold": 0.85, "xp": 0.9, "lives": 1, "elite": 1.7, "elite_from": 2, "score": 1.7,
		"desc": "One life. Tougher foes, less gold, elites from wave 2.", "color": Color(1.0, 0.35, 0.3),
		"unlock": "Clear wave 10 on Hard"},
}

const MODE_ORDER := ["classic", "random", "endless", "delve", "duels", "daily", "practice", "training"]
const MODES := {
	"classic": {"name": "Classic", "desc": "Pick a hero and survive 20 waves. Bosses on every 5th wave.", "icon": "portrait_ashwarden", "tiers": true},
	"random": {"name": "Random Hero", "desc": "The Pit picks your hero for you. +150 starting gold.", "icon": "portrait_twinhide", "tiers": true},
	"endless": {"name": "Endless", "desc": "Past the Warden the waves never stop. How far can you go?", "icon": "portrait_sunspeaker", "tiers": true},
	"delve": {"name": "Delve", "desc": "Experimental. Leave the arena and explore the Undercroft: 10 depths of rooms and corridors. Foes sleep in packs until you come close. Find the lair at the end of each depth and slay its guardian.",
		"icon": "portrait_nightblade", "tiers": true},
	"daily": {"name": "Daily Run", "desc": "Today's hero and twist, the same for everyone. Hard tier. Beat your best score.", "icon": "portrait_gunsmith", "tiers": false},
	"duels": {"name": "Duel Ladder", "desc": "No waves: beat 8 rival heroes one on one, each stronger than the last. Shop between duels. A lost duel costs a life.", "icon": "portrait_duelist", "tiers": true},
	"practice": {"name": "Practice", "desc": "Any hero, any wave, 99,999 gold, no lives lost. Nothing counts toward records.", "icon": "portrait_stoneshaper", "tiers": true},
	"training": {"name": "Training", "desc": "Learn the basics step by step: moving, skills, the shop, fighting, barrel stacks.", "icon": "portrait_riftdancer", "tiers": false},
}
const RANDOM_BONUS_GOLD := 150
const PRACTICE_GOLD := 99999

## Daily Run twists. Each changes one rule of the run; the day decides which.
const DAILY_MODS := {
	"glass": {"name": "Glass Cannon", "desc": "You deal 35% more damage and take 35% more.", "hero_dmg": 1.35, "hero_taken": 1.35},
	"gold_rush": {"name": "Gold Rush", "desc": "40% more gold, but enemies have 20% more HP.", "gold": 1.4, "hp": 1.2},
	"swarm": {"name": "Swarm", "desc": "A third more enemies per wave, each a little weaker.", "extra": 0.35, "hp": 0.9},
	"last_stand": {"name": "Last Stand", "desc": "One life, but 30% more gold and XP.", "lives": 1, "gold": 1.3, "xp": 1.3},
	"elite_pit": {"name": "Elite Pit", "desc": "Elites are twice as common and come from wave 2. 25% more gold.", "elite": 2.0, "elite_from": 2, "gold": 1.25},
	"quickening": {"name": "Quickening", "desc": "Enemies move 20% faster. So do you, 15%.", "enemy_speed": 1.2, "hero_speed": 1.15},
}

## Endless: bosses keep coming every 5th wave, a little tougher each lap.
const ENDLESS_BOSSES := ["pit_brute", "matron", "hollow_choir", "warden"]
const ENDLESS_BOSS_HP_PER_LAP := 0.6


## Run settings for a mode + tier. extra: {"hero", "date", "resume", ...} copied on top.
static func config(mode: String, tier := "hard", extra := {}) -> Dictionary:
	if not MODES.has(mode):
		mode = "classic"
	if mode == "daily":
		tier = "hard"
	if not TIERS.has(tier) or mode == "training":
		tier = "hard" if mode != "training" else "normal"
	var t: Dictionary = TIERS[tier]
	var c := {"mode": mode, "tier": tier, "hp": t["hp"], "dmg": t["dmg"], "gold": t["gold"], "xp": t["xp"], "lives": t["lives"],
		"elite": t["elite"], "elite_from": t["elite_from"], "bonus_gold": 0, "hero_dmg": 1.0, "hero_taken": 1.0, "enemy_speed": 1.0,
		"hero_speed": 1.0, "extra": 0.0, "endless": mode == "endless", "counts": mode in ["classic", "random", "endless", "daily", "delve"],
		"seed": 0, "mod": "", "map": "pit"}
	match mode:
		"random":
			c["bonus_gold"] = RANDOM_BONUS_GOLD
		"practice":
			c["lives"] = 99
		"training":
			c["lives"] = 99
			c["no_death"] = true
		"daily":
			var date: String = extra.get("date", today())
			var dd := daily(date)
			c["seed"] = dd["seed"]
			c["date"] = date
			c["mod"] = dd["mod"]
			var m: Dictionary = DAILY_MODS[dd["mod"]]
			for k in ["hero_dmg", "hero_taken", "extra", "enemy_speed", "hero_speed", "elite_from"]:
				if m.has(k):
					c[k] = m[k]
			for k in ["hp", "gold", "xp", "elite"]:
				if m.has(k):
					c[k] = float(c[k]) * float(m[k])
			if m.has("lives"):
				c["lives"] = m["lives"]
	for k in extra:
		c[k] = extra[k]
	if mode == "delve":
		c["map"] = "delve"
	elif mode in ["daily", "training"] or not Maps.MAPS.has(String(c["map"])):
		c["map"] = "pit"
	return c


static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


## Today's Daily Run: the same hero, twist and seed for everyone on that date.
static func daily(date: String) -> Dictionary:
	var s := absi(hash("emberpit-daily-" + date))
	var mods := DAILY_MODS.keys()
	return {"seed": s, "hero": DB.HERO_ORDER[s % DB.HERO_ORDER.size()], "mod": mods[(s / 7) % mods.size()], "date": date}


static func random_hero(rng: RandomNumberGenerator = null) -> String:
	var i := rng.randi() if rng else randi()
	return DB.HERO_ORDER[i % DB.HERO_ORDER.size()]


# ---------------------------------------------------------------- endless waves
## The wave's name, twist and captain. Past wave 20 the regular waves cycle through 1-19 again.
static func wave_info(w: int) -> Dictionary:
	if w <= DB.TOTAL_WAVES:
		return DB.wave_info(w)
	var bk := boss_kind(w)
	if bk != "":
		return {"name": boss_title(w), "captain": "", "rule": "", "mods": {}, "desc": "Endless boss. Tougher with every lap."}
	var base: Dictionary = DB.wave_info(((w - 1) % DB.TOTAL_WAVES) + 1).duplicate()
	base["name"] = String(base.get("name", "")) + " " + _lap_mark(w)
	return base


static func _lap_mark(w: int) -> String:
	return ["", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi((w - 1) / DB.TOTAL_WAVES, 0, 9)]


## Boss kind on wave w ("" = no boss). Waves 1-20 use DB.BOSS_WAVES; Endless keeps the cycle going.
static func boss_kind(w: int) -> String:
	if w <= DB.TOTAL_WAVES:
		return DB.BOSS_WAVES.get(w, "")
	if w % 5 != 0:
		return ""
	return ENDLESS_BOSSES[(w / 5 - 1) % ENDLESS_BOSSES.size()]


static func boss_title(w: int) -> String:
	if w <= DB.TOTAL_WAVES:
		return DB.BOSS_TITLES.get(w, "")
	var bk := boss_kind(w)
	var base_w: int = {"pit_brute": 5, "matron": 10, "hollow_choir": 15, "warden": 20}.get(bk, 5)
	return "%s %s" % [DB.BOSS_TITLES[base_w], _lap_mark(w)]


static func boss_hp_mult(w: int) -> float:
	if w <= DB.TOTAL_WAVES:
		return 1.0
	return 1.0 + ENDLESS_BOSS_HP_PER_LAP * float((w - 1) / DB.TOTAL_WAVES)


## Bursts for wave w; Endless boss waves get the same light escort as the first 20.
static func wave_bursts(w: int) -> Array:
	var b := DB.wave_bursts(w)
	if w > DB.TOTAL_WAVES and boss_kind(w) != "":
		for burst in b:
			var u: Array = burst["units"]
			burst["units"] = u.slice(0, int(ceil(u.size() * 0.4)))
	return b


# ---------------------------------------------------------------- score
## Run score for records: waves, kills and bosses, minus deaths, scaled by tier.
static func score(waves_cleared: int, kills: int, bosses: int, deaths: int, tier: String) -> int:
	var s := waves_cleared * 100 + kills * 2 + bosses * 300 - deaths * 150
	return maxi(0, int(round(s * float(TIERS.get(tier, TIERS["hard"])["score"]))))


static func label(cfg: Dictionary) -> String:
	var mode: String = cfg.get("mode", "classic")
	var nm: String = MODES.get(mode, MODES["classic"])["name"]
	if mode == "daily":
		return "Daily Run · " + String(DAILY_MODS.get(cfg.get("mod", ""), {}).get("name", ""))
	var map: String = cfg.get("map", "pit")
	if map not in ["pit", "delve"]:
		nm += " · " + Maps.map_name(map)
	if MODES.get(mode, {}).get("tiers", false):
		return "%s · %s" % [nm, TIERS[cfg.get("tier", "hard")]["name"]]
	return nm
