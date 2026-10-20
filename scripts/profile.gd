class_name Profile
extends RefCounted
## What carries over between runs, saved on the phone: unlocked heroes, records, totals, the training flag,
## and the run in progress (saved in camp, so closing the app mid-run loses at most the wave being fought).
## Only runs whose cfg["counts"] is true (Classic, Random Hero, Endless, Daily) add to records and unlocks.

const VERSION := 1
static var path := "user://profile.json"
static var run_path := "user://saved_run.json"
static var data := {}
static var _loaded := false


static func defaults() -> Dictionary:
	return {"version": VERSION, "unlocked": Modes.STARTER_HEROES.duplicate(), "tiers": ["normal", "hard"],
		"training_done": false, "training_offered": false, "last_tier": "hard",
		"totals": {"runs": 0, "wins": 0, "kills": 0, "bosses": 0, "waves": 0, "deaths": 0, "time": 0.0},
		"heroes": {},       # id -> {runs, best_wave, wins, kills}
		"tier_best": {},    # tier -> best wave cleared (Classic / Random Hero)
		"best_score": {},   # mode -> best score
		"endless_best": 0,  # best wave cleared in Endless
		"daily": {"date": "", "best_wave": 0, "best_score": 0, "runs": 0}}


## Points the profile at other files (tests) and reloads.
static func use_paths(p: String, rp: String) -> void:
	path = p
	run_path = rp
	_loaded = false
	data = {}


static func d() -> Dictionary:
	if not _loaded:
		load_profile()
	return data


static func load_profile() -> void:
	_loaded = true
	data = defaults()
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for k in parsed:
			if data.has(k) and typeof(data[k]) == TYPE_DICTIONARY and parsed[k] is Dictionary:
				(data[k] as Dictionary).merge(parsed[k], true)
			else:
				data[k] = parsed[k]
	for h in Modes.STARTER_HEROES:
		if not (data["unlocked"] as Array).has(h):
			data["unlocked"].append(h)


static func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d(), " "))
		f.close()


static func reset() -> void:
	data = defaults()
	_loaded = true
	save()
	clear_run()


# ---------------------------------------------------------------- unlocks
static func is_unlocked(hero_id: String) -> bool:
	return (d()["unlocked"] as Array).has(hero_id)


static func tier_unlocked(tier: String) -> bool:
	return (d()["tiers"] as Array).has(tier)


static func unlock_all() -> void:
	d()["unlocked"] = DB.HERO_ORDER.duplicate()
	d()["tiers"] = Modes.TIER_ORDER.duplicate()
	save()


static func hero_rec(id: String) -> Dictionary:
	var hs: Dictionary = d()["heroes"]
	if not hs.has(id):
		hs[id] = {"runs": 0, "best_wave": 0, "wins": 0, "kills": 0}
	return hs[id]


static func best_wave_any() -> int:
	var b := 0
	for id in d()["heroes"]:
		b = maxi(b, int(d()["heroes"][id].get("best_wave", 0)))
	return b


## [current, target] for a hero's unlock condition.
static func progress(hero_id: String) -> Array:
	var u: Dictionary = Modes.UNLOCKS.get(hero_id, {})
	if u.is_empty():
		return [1, 1]
	var n := int(u["n"])
	var cur := 0
	match String(u["stat"]):
		"best_wave":
			cur = best_wave_any()
		"total_waves":
			cur = int(d()["totals"]["waves"])
		"kills":
			cur = int(d()["totals"]["kills"])
		"heroes_at_8":
			for id in d()["heroes"]:
				if int(d()["heroes"][id].get("best_wave", 0)) >= 8:
					cur += 1
	return [mini(cur, n), n]


## Unlocks everything whose condition is met; returns the names of what was newly unlocked.
static func check_unlocks() -> Array:
	var out := []
	for id in Modes.UNLOCKS:
		if is_unlocked(id):
			continue
		var p := progress(id)
		if p[0] >= p[1]:
			d()["unlocked"].append(id)
			out.append(String(DB.HEROES[id]["name"]))
	if not tier_unlocked("extreme") and int(d()["tier_best"].get("hard", 0)) >= 10:
		d()["tiers"].append("extreme")
		out.append("Extreme tier")
	return out


# ---------------------------------------------------------------- run events (called by Run)
static func on_run_started(r: Run) -> void:
	if not r.cfg.get("counts", false) or r.cfg.has("resume"):
		return
	d()["totals"]["runs"] = int(d()["totals"]["runs"]) + 1
	var hr := hero_rec(r.hero_id)
	hr["runs"] = int(hr["runs"]) + 1
	if r.cfg.get("mode") == "daily":
		_daily_rec(r)["runs"] = int(_daily_rec(r)["runs"]) + 1
	if Modes.MODES[r.cfg["mode"]].get("tiers", false):
		d()["last_tier"] = r.tier
	save()


## A wave was cleared: records, totals and unlocks. Returns newly unlocked names.
static func on_wave_cleared(r: Run, boss: bool) -> Array:
	if not r.cfg.get("counts", false):
		return []
	var t: Dictionary = d()["totals"]
	t["waves"] = int(t["waves"]) + 1
	if boss:
		t["bosses"] = int(t["bosses"]) + 1
	_add_kills(r)
	var w := r.wave
	var hr := hero_rec(r.hero_id)
	hr["best_wave"] = maxi(int(hr["best_wave"]), w)
	var mode: String = r.cfg.get("mode", "classic")
	if mode in ["classic", "random"]:
		d()["tier_best"][r.tier] = maxi(int(d()["tier_best"].get(r.tier, 0)), w)
	elif mode == "endless":
		d()["endless_best"] = maxi(int(d()["endless_best"]), w)
	elif mode == "daily":
		var dr := _daily_rec(r)
		dr["best_wave"] = maxi(int(dr["best_wave"]), w)
	var news := check_unlocks()
	save()
	return news


## The run is over. Returns {"score", "best" (new best score), "unlocks"}.
static func on_run_ended(r: Run) -> Dictionary:
	if r.mode not in ["practice", "training"]:
		clear_run()
	var out := {"score": r.score(), "best": false, "unlocks": []}
	if not r.cfg.get("counts", false):
		return out
	var t: Dictionary = d()["totals"]
	_add_kills(r)
	t["deaths"] = int(t["deaths"]) + int(r.stats["deaths"]) - int(r.get_meta("deaths_saved", 0))
	r.set_meta("deaths_saved", int(r.stats["deaths"]))
	t["time"] = float(t["time"]) + r.run_time
	if r.result == "victory":
		t["wins"] = int(t["wins"]) + 1
		var hr := hero_rec(r.hero_id)
		hr["wins"] = int(hr["wins"]) + 1
	var mode: String = r.cfg.get("mode", "classic")
	var key := mode if mode != "classic" else "classic_" + r.tier
	var sc: int = out["score"]
	if mode == "daily":
		var dr := _daily_rec(r)
		if sc > int(dr["best_score"]):
			dr["best_score"] = sc
			out["best"] = true
	elif sc > int(d()["best_score"].get(key, 0)):
		d()["best_score"][key] = sc
		out["best"] = true
	out["unlocks"] = check_unlocks()
	save()
	return out


static func _add_kills(r: Run) -> void:
	var k := int(r.stats["kills"])
	var done := int(r.get_meta("kills_saved", 0))
	if k <= done:
		return
	d()["totals"]["kills"] = int(d()["totals"]["kills"]) + (k - done)
	var hr := hero_rec(r.hero_id)
	hr["kills"] = int(hr.get("kills", 0)) + (k - done)
	r.set_meta("kills_saved", k)


static func _daily_rec(r: Run) -> Dictionary:
	var date: String = r.cfg.get("date", Modes.today())
	if String(d()["daily"].get("date", "")) != date:
		d()["daily"] = {"date": date, "best_wave": 0, "best_score": 0, "runs": 0}
	return d()["daily"]


static func daily_today() -> Dictionary:
	var dd: Dictionary = d()["daily"]
	if String(dd.get("date", "")) != Modes.today():
		return {"date": Modes.today(), "best_wave": 0, "best_score": 0, "runs": 0}
	return dd


# ---------------------------------------------------------------- the run in progress
static func save_run(snap: Dictionary) -> void:
	var f := FileAccess.open(run_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(snap))
		f.close()


static func has_run() -> bool:
	return not load_run().is_empty()


static func load_run() -> Dictionary:
	if not FileAccess.file_exists(run_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(run_path))
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != VERSION or not DB.HEROES.has(String(parsed.get("hero", ""))):
		return {}
	return parsed


static func clear_run() -> void:
	if FileAccess.file_exists(run_path):
		DirAccess.remove_absolute(run_path)
