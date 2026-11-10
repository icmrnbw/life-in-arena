class_name Meta
extends RefCounted
## What makes players come back between runs (0.9): Souls, the Altar of Souls, Heat, hero Mastery, Bounties and the
## Survival boons. Everything is saved in the profile (scripts/profile.gd); runs only read it through cfg, so bot and
## test runs (which never call dress()) play the game exactly as tuned.
##
## - Souls: earned by every counted run (Survival, Random Hero, Endless, Delve, Daily), spent at the Altar.
## - Altar of Souls: permanent upgrades with ranks (ALTAR). dress() writes them into a run's cfg ("perks", gold, ...).
## - Heat: optional curses for Survival and Delve (Modes.HEAT). Win at Heat N (Hard or Extreme) to open Heat N+1.
## - Mastery: per-hero level 1-10 from playing that hero. Level 5 unlocks the hero's legendary skin.
## - Bounties: 3 daily + 1 weekly goals, the same for everyone that day / week, paid in Souls.
## - Boons: Survival offers 1 of 3 run-long boons (DelveLore.RELICS) after each boss.

# ---------------------------------------------------------------- the Altar of Souls
const ALTAR_ORDER := ["vitality", "might", "bulwark", "focus", "purse", "fortune", "scholar", "insight", "second_wind"]
## cost = price of rank 1; rank r costs cost * r. stats go on the hero (Hero.perks), cfg adds to the run cfg,
## cfg_mult raises a run multiplier by that share per rank.
const ALTAR := {
	"vitality": {"name": "Vitality", "desc": "+40 max health per rank.", "max": 5, "cost": 80, "stats": {"hp": 40.0}, "icon": "vigor_charm"},
	"might": {"name": "Might", "desc": "+3% damage per rank.", "max": 5, "cost": 100, "stats": {"dmg_pct": 0.03}, "icon": "iron_knuckles"},
	"bulwark": {"name": "Bulwark", "desc": "+1 armor per rank.", "max": 5, "cost": 80, "stats": {"armor": 1.0}, "icon": "bulwark_plate"},
	"focus": {"name": "Focus", "desc": "Skills recharge 2% faster per rank.", "max": 5, "cost": 100, "stats": {"cdr": 0.02}, "icon": "focus_pendant"},
	"purse": {"name": "Heavy Purse", "desc": "+50 starting gold per rank.", "max": 5, "cost": 60, "cfg": {"bonus_gold": 50}, "icon": "gold"},
	"fortune": {"name": "Fortune", "desc": "+4% gold from every source per rank.", "max": 5, "cost": 90, "cfg_mult": {"gold": 0.04}, "icon": "golden_touch"},
	"scholar": {"name": "Scholar", "desc": "+4% experience per rank.", "max": 5, "cost": 90, "cfg_mult": {"xp": 0.04}, "icon": "tome_of_might"},
	"insight": {"name": "Insight", "desc": "Reroll a boon or relic choice once per run, per rank.", "max": 2, "cost": 250, "cfg": {"rerolls": 1}, "icon": "hooded_lantern"},
	"second_wind": {"name": "Second Wind", "desc": "+1 life in every run.", "max": 1, "cost": 1200, "cfg": {"lives": 1}, "icon": "phoenix_feather"},
}


static func rank(id: String) -> int:
	return clampi(int((Profile.d()["altar"] as Dictionary).get(id, 0)), 0, int(ALTAR[id]["max"]))


## Souls for the next rank, or -1 when it is maxed.
static func next_cost(id: String) -> int:
	var r := rank(id)
	if r >= int(ALTAR[id]["max"]):
		return -1
	return int(ALTAR[id]["cost"]) * (r + 1)


static func souls() -> int:
	return int(Profile.d().get("souls", 0))


## Buys the next rank. Returns false if maxed or too expensive.
static func buy(id: String) -> bool:
	if not ALTAR.has(id):
		return false
	var c := next_cost(id)
	if c < 0 or souls() < c:
		return false
	Profile.d()["souls"] = souls() - c
	Profile.d()["altar"][id] = rank(id) + 1
	Profile.save()
	return true


## Gives every Soul spent at the Altar back (ranks go to 0).
static func refund_all() -> int:
	var back := 0
	for id in ALTAR_ORDER:
		for r in rank(id):
			back += int(ALTAR[id]["cost"]) * (r + 1)
	Profile.d()["altar"] = {}
	Profile.d()["souls"] = souls() + back
	Profile.save()
	return back


## Hero stats from the Altar (summed into Hero.perks).
static func perk_stats() -> Dictionary:
	var out := {}
	for id in ALTAR_ORDER:
		var r := rank(id)
		if r == 0:
			continue
		var st: Dictionary = ALTAR[id].get("stats", {})
		for k in st:
			out[k] = float(out.get(k, 0.0)) + float(st[k]) * r
	return out


## The player's Altar upgrades written into a run's cfg. Called only by the menus (never by bot / test runs).
## Training is left alone; Practice keeps its own gold and lives.
static func dress(cfg: Dictionary) -> Dictionary:
	var mode := String(cfg.get("mode", "classic"))
	if mode == "training" or cfg.get("dressed", false):
		return cfg
	cfg["dressed"] = true
	cfg["perks"] = perk_stats()
	for id in ALTAR_ORDER:
		var r := rank(id)
		if r == 0:
			continue
		var add: Dictionary = ALTAR[id].get("cfg", {})
		for k in add:
			if mode == "practice" and k in ["lives", "bonus_gold"]:
				continue
			cfg[k] = int(cfg.get(k, 0)) + int(add[k]) * r
		var mul: Dictionary = ALTAR[id].get("cfg_mult", {})
		for k in mul:
			cfg[k] = float(cfg.get(k, 1.0)) * (1.0 + float(mul[k]) * r)
	return cfg


# ---------------------------------------------------------------- heat
## Heat is per mode family: "classic" (Survival) and "delve".
static func heat_key(mode: String) -> String:
	return "delve" if mode == "delve" else ("classic" if mode == "classic" else "")


## Highest Heat the player may pick for a mode (0 = none opened yet).
static func heat_open(mode: String) -> int:
	var k := heat_key(mode)
	if k == "":
		return 0
	return clampi(int((Profile.d()["heat"] as Dictionary).get(k, 0)), 0, Modes.HEAT.size())


static func heat_best(mode: String) -> int:
	var k := heat_key(mode)
	return int((Profile.d()["heat_best"] as Dictionary).get(k, -1)) if k != "" else -1


## A won run opens the next Heat (Hard or Extreme only). Returns the newly opened level, or 0.
static func on_victory_heat(mode: String, tier: String, heat: int) -> int:
	var k := heat_key(mode)
	if k == "" or tier == "normal":
		return 0
	Profile.d()["heat_best"][k] = maxi(heat_best(mode), heat)
	var nxt := mini(heat + 1, Modes.HEAT.size())
	if nxt > heat_open(mode):
		Profile.d()["heat"][k] = nxt
		return nxt
	return 0


# ---------------------------------------------------------------- souls from a run
const TIER_SOULS := {"normal": 0.6, "hard": 1.0, "extreme": 1.5}
const HEAT_SOULS := 0.25   # +25% Souls per Heat level


## Souls a finished run pays. Delve depths count double (there are 10 of them against 20 waves).
static func run_souls(r: Run) -> int:
	var waves := r.waves_cleared * (16 if r.mode == "delve" else 8)
	var s := float(waves + int(r.stats["bosses"]) * 20 + int(r.stats["kills"]) / 20 + (60 if r.result == "victory" else 0))
	if r.mode == "daily":
		s *= 1.2
	s *= float(TIER_SOULS.get(r.tier, 1.0)) * (1.0 + HEAT_SOULS * int(r.cfg.get("heat", 0)))
	return maxi(0, int(round(s)))


static func add_souls(n: int) -> void:
	Profile.d()["souls"] = souls() + n
	Profile.d()["souls_total"] = int(Profile.d().get("souls_total", 0)) + n


# ---------------------------------------------------------------- mastery
## Mastery xp needed to reach level i + 1 (level 1 = 0 xp).
const MASTERY_XP := [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200]
const MASTERY_SKIN := 5        # this level unlocks the hero's legendary skin
const MASTERY_SOULS := 40      # Souls per level reached, times the level


static func mastery_xp(hero_id: String) -> int:
	return int(Profile.hero_rec(hero_id).get("mxp", 0))


static func level_for(xp: int) -> int:
	var lv := 1
	for i in MASTERY_XP.size():
		if xp >= int(MASTERY_XP[i]):
			lv = i + 1
	return lv


static func mastery(hero_id: String) -> int:
	return level_for(mastery_xp(hero_id))


static func max_mastery() -> int:
	return MASTERY_XP.size()


## [xp into this level, xp this level needs] (both 0 at the top level).
static func mastery_progress(hero_id: String) -> Array:
	var xp := mastery_xp(hero_id)
	var lv := level_for(xp)
	if lv >= MASTERY_XP.size():
		return [0, 0]
	return [xp - int(MASTERY_XP[lv - 1]), int(MASTERY_XP[lv]) - int(MASTERY_XP[lv - 1])]


static func run_mastery_xp(r: Run) -> int:
	var x := float(r.waves_cleared * (20 if r.mode == "delve" else 10) + int(r.stats["bosses"]) * 25 + (100 if r.result == "victory" else 0))
	return int(round(x * (1.0 + 0.2 * int(r.cfg.get("heat", 0)))))


## Adds mastery xp; returns [old level, new level, souls paid for the levels gained].
static func add_mastery(hero_id: String, xp: int) -> Array:
	var hr := Profile.hero_rec(hero_id)
	var old := level_for(int(hr.get("mxp", 0)))
	hr["mxp"] = int(hr.get("mxp", 0)) + xp
	var now := level_for(int(hr["mxp"]))
	var paid := 0
	for lv in range(old + 1, now + 1):
		paid += MASTERY_SOULS * lv
	if paid > 0:
		add_souls(paid)
	return [old, now, paid]


## The hero's legendary skin unlocks at Mastery 5 (skins.gd "unlock": "store" skins).
static func skin_unlocked(hero_id: String) -> bool:
	return mastery(hero_id) >= MASTERY_SKIN


# ---------------------------------------------------------------- bounties
## ev = the event that moves it (track()), n = targets to pick from, souls = reward. {hero} = a hero picked for the day.
const DAILY := {
	"surv_waves": {"text": "Clear %d waves in Survival", "ev": "surv_wave", "n": [6, 10, 14], "souls": 60},
	"delve_depths": {"text": "Clear %d Delve depths", "ev": "depth", "n": [3, 5, 7], "souls": 70},
	"bosses": {"text": "Defeat %d bosses", "ev": "boss", "n": [1, 2, 3], "souls": 70},
	"kills": {"text": "Defeat %d foes", "ev": "kill", "n": [300, 500, 800], "souls": 50},
	"flawless": {"text": "Clear %d waves or depths without falling", "ev": "flawless", "n": [4, 6, 9], "souls": 60},
	"boons": {"text": "Take %d boons or relics", "ev": "relic", "n": [2, 3, 4], "souls": 60},
	"magic": {"text": "Clear %d waves or depths with a magic hero", "ev": "wave_magic", "n": [5, 8], "souls": 60},
	"phys": {"text": "Clear %d waves or depths with a physical hero", "ev": "wave_phys", "n": [5, 8], "souls": 60},
	"hero": {"text": "Clear %d waves or depths as {hero}", "ev": "wave_hero", "n": [4, 6], "souls": 90},
}
const WEEKLY := {
	"w_win": {"text": "Win a Survival run on Hard or Extreme", "ev": "win_surv", "n": [1], "souls": 400},
	"w_delve": {"text": "Conquer all 10 depths of the Undercroft", "ev": "win_delve", "n": [1], "souls": 400},
	"w_bosses": {"text": "Defeat %d bosses", "ev": "boss", "n": [10], "souls": 350},
	"w_waves": {"text": "Clear %d waves or depths", "ev": "any_wave", "n": [60], "souls": 350},
}
const DAILY_COUNT := 3


## Days since 1970 (UTC), and the week they fall in. Tests pass `now` to step through days.
static func day_key(now := -1) -> String:
	var t := int(Time.get_unix_time_from_system()) if now < 0 else now
	var d := Time.get_date_dict_from_unix_time(t)
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


static func week_key(now := -1) -> String:
	var t := int(Time.get_unix_time_from_system()) if now < 0 else now
	# weeks start on Monday: 1970-01-01 was a Thursday
	return "W%d" % int((t / 86400 + 3) / 7)


static func _make(id: String, def: Dictionary, s: int) -> Dictionary:
	var ns: Array = def["n"]
	var b := {"id": id, "n": int(ns[s % ns.size()]), "prog": 0, "done": false, "souls": int(def["souls"])}
	if String(def["text"]).contains("{hero}"):
		b["hero"] = DB.HERO_ORDER[(s / 3) % DB.HERO_ORDER.size()]
	return b


## Today's and this week's bounties (made fresh when the day / week turns over).
static func bounties(now := -1) -> Dictionary:
	var bd: Dictionary = Profile.d()["bounties"]
	var day := day_key(now)
	if String(bd.get("day", "")) != day:
		var s := absi(hash("emberpit-bounty-" + day))
		var ids := DAILY.keys()
		var list := []
		var k := 0
		while list.size() < DAILY_COUNT and k < 40:
			var id: String = ids[(s / (k * 7 + 1)) % ids.size()]
			k += 1
			if list.any(func(b): return b["id"] == id):
				continue
			list.append(_make(id, DAILY[id], s + k))
		bd["day"] = day
		bd["daily"] = list
	var wk := week_key(now)
	if String(bd.get("week", "")) != wk:
		var s2 := absi(hash("emberpit-weekly-" + wk))
		var wids := WEEKLY.keys()
		var wid: String = wids[s2 % wids.size()]
		bd["week"] = wk
		bd["weekly"] = _make(wid, WEEKLY[wid], s2)
	return bd


static func all_bounties(now := -1) -> Array:
	var bd := bounties(now)
	return (bd["daily"] as Array) + [bd["weekly"]]


static func bounty_text(b: Dictionary) -> String:
	var def: Dictionary = DAILY.get(b["id"], WEEKLY.get(b["id"], {}))
	if def.is_empty():
		return ""
	var t := String(def["text"])
	if t.contains("{hero}"):
		return L.t(t).replace("%d", str(int(b["n"]))).format({"hero": DB.HEROES.get(String(b.get("hero", "")), {"name": "?"})["name"]})
	if t.contains("%d"):
		return L.f(t, [int(b["n"])])
	return L.t(t)


static func is_weekly(b: Dictionary) -> bool:
	return WEEKLY.has(b["id"])


## Moves every bounty listening to `ev` by n. ctx: {"hero": id}. Returns the bounties finished just now.
static func track(ev: String, n: int, ctx := {}) -> Array:
	if n <= 0:
		return []
	var done := []
	for b in all_bounties():
		if b["done"]:
			continue
		var def: Dictionary = DAILY.get(b["id"], WEEKLY.get(b["id"], {}))
		if String(def.get("ev", "")) != ev:
			continue
		if ev == "wave_hero" and String(ctx.get("hero", "")) != String(b.get("hero", "")):
			continue
		b["prog"] = mini(int(b["prog"]) + n, int(b["n"]))
		if int(b["prog"]) >= int(b["n"]):
			b["done"] = true
			add_souls(int(b["souls"]))
			done.append(b)
	return done


## Events from a cleared wave / depth of a counted run.
static func track_wave(r: Run, boss: bool) -> Array:
	var ctx := {"hero": r.hero_id}
	var out := []
	out += track("any_wave", 1, ctx)
	out += track("depth" if r.mode == "delve" else "surv_wave", 1, ctx)
	if boss:
		out += track("boss", 1, ctx)
	if not r.wave_died:
		out += track("flawless", 1, ctx)
	var dt := String(DB.HEROES[r.hero_id].get("dmg_type", "phys"))
	if dt in ["magic", "mixed"]:
		out += track("wave_magic", 1, ctx)
	if dt in ["phys", "mixed"]:
		out += track("wave_phys", 1, ctx)
	out += track("wave_hero", 1, ctx)
	return out


# ---------------------------------------------------------------- survival boons
## Relics that work in the arena (no lantern, water, traps or Undercroft gold).
const BOONS := ["vampire_fang", "thorn_shard", "gravebloom", "whetstone", "quicksand", "runed_skull", "frost_rune", "ember_heart",
	"oathstone", "soul_jar", "warlord_crown", "sage_tome", "hunters_mark", "stoneskin_idol"]
const BOON_MODES := ["classic", "random", "endless", "daily", "practice"]


static func boon_offer(owned: Array, n: int, rng: RandomNumberGenerator, pool: Array = BOONS) -> Array:
	var ids := []
	for id in pool:
		if DelveLore.RELICS.has(id) and not id in owned:
			ids.append(id)
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = ids[i]
		ids[i] = ids[j]
		ids[j] = t
	return ids.slice(0, n)


## Shows a pick-1-of-3 relic card on `run` (Delve vaults and bosses, Survival bosses), with a Reroll button while the
## run has rerolls left. take(id) gets the pick; then_cb runs after it.
static func offer_relics(run: Run, title: String, sub: String, pool: Array, take: Callable, then_cb: Callable, auto_pick: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ids := boon_offer(run.hero.relics, 3, rng, pool)
	if ids.is_empty():
		if then_cb.is_valid():
			then_cb.call()
		return
	var opts := []
	for id in ids:
		var rd: Dictionary = DelveLore.RELICS[id]
		opts.append({"id": id, "name": rd["name"], "desc": rd["desc"], "icon": rd["icon"], "color": rd["color"]})
	var data := {"title": title, "sub": sub, "options": opts, "auto": auto_pick.call(ids)}
	if run.rerolls > 0 and pool.size() - run.hero.relics.size() > 3:
		data["reroll"] = run.rerolls
	run.request_choice(data, func(id: String):
		if id == "__reroll":
			run.rerolls -= 1
			offer_relics(run, title, sub, pool, take, then_cb, auto_pick)
			return
		take.call(id)
		if run.cfg.get("counts", false):
			Profile.note_bounties(track("relic", 1, {"hero": run.hero_id}))
			Profile.save()
			run._bounty_toasts()
		if then_cb.is_valid():
			then_cb.call())
