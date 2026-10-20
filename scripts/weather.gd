class_name Weather
extends RefCounted
## Arena weather (DB.WEATHER). Rolled when the hero reaches camp for the next wave, so the forecast is already
## falling around the shop; regular waves from wave 3 on can turn mid-fight. Rules are read by Run and Unit
## through the *_mult() queries; storms and Emberfall also add telegraphed hazards during waves.

var run: Run
var id := "clear"
var wind := Vector3.ZERO          # unit vector downwind (Gale only)
var shift_at := -1.0              # wave_time of this wave's mid-fight change (-1 = none)
var shift_to := ""
var strike_t := 0.0
var ember_t := 0.0
var patches: Array = []           # burning sand: {pos, t, tick, fx}
var vis: Node = null              # Art weather visual (null in tests without it)
var override := ""                # --weather=<id>: always this weather, never turning (tests, screenshots)


func setup(r: Run) -> void:
	run = r
	override = Game.arg("weather", "")
	if Art.has_method("weather_fx"):
		vis = Art.weather_fx(r)


func info() -> Dictionary:
	return DB.WEATHER.get(id, DB.WEATHER["clear"])


func display_name() -> String:
	return String(info()["name"])


## Keep weather `w` for the rest of the run, starting now (tests; --weather= does the same).
func pin(w: String) -> void:
	override = w
	roll_for(run.wave)


## Forecast for wave `w` (called on entering camp).
func roll_for(w: int) -> void:
	var pick := override
	if not DB.WEATHER.has(pick):
		pick = _pick(DB.weather_pool(w), "")
	_apply(pick)
	shift_at = -1.0
	shift_to = ""
	if override == "" and w >= 3 and run.boss_kind(w) == "" and run.rng.randf() < DB.WEATHER_SHIFT_CHANCE:
		shift_at = run.rng.randf_range(18.0, 32.0)
		shift_to = _pick(DB.weather_pool(w), id)


func _pick(pool: Dictionary, avoid: String) -> String:
	var total := 0.0
	for k in pool:
		if k != avoid:
			total += float(pool[k])
	var x := run.rng.randf() * total
	for k in pool:
		if k == avoid:
			continue
		x -= float(pool[k])
		if x <= 0.0:
			return k
	return "clear" if avoid != "clear" else "rain"


func _apply(w: String) -> void:
	id = w
	if info().has("wind"):
		var a := run.rng.randf() * TAU
		wind = Vector3(cos(a), 0, sin(a))
	else:
		wind = Vector3.ZERO
	strike_t = run.rng.randf_range(2.5, 4.0)
	ember_t = run.rng.randf_range(2.0, 3.5)
	if not info().get("embers", false):
		clear_patches()
	if vis and vis.has_method("set_weather"):
		vis.set_weather(id, wind)
	# shot ranges follow Fog in and out
	run.hero.update_range()
	for e in run.enemies:
		if e.alive:
			apply_to_enemy(e)


## Fog shortens enemy shots too (only ranged foes, not bosses).
func apply_to_enemy(e: Enemy) -> void:
	var base := float(e.data.get("range", e.atk_range))
	if base >= 4.0 and not e.is_boss:
		e.atk_range = base * range_mult()


# ---------------------------------------------------------------- rules
func speed_mult(u: Unit) -> float:
	var d := info()
	var m := 1.0
	if d.has("speed") and not (u is Hero and (u as Hero).item_stats.get("weatherproof", 0.0) > 0.0):
		m *= float(d["speed"])
	if u.team == 1 and d.has("foe_speed"):
		m *= float(d["foe_speed"])
	return m


func range_mult() -> float:
	return float(info().get("range", 1.0))


func fire_mult() -> float:
	return float(info().get("fire", 1.0))


func foe_dmg_mult() -> float:
	return float(info().get("foe_dmg", 1.0))


## Shots with the wind hit harder, shots into it softer.
func shot_mult(dir: Vector3) -> float:
	if wind == Vector3.ZERO:
		return 1.0
	return 1.0 + float(info().get("wind", 0.0)) * clampf(dir.dot(wind), -1.0, 1.0)


## Lantern bonus: +10% damage in Fog or under a Blood Moon.
func lantern_mult() -> float:
	return 1.1 if id in ["fog", "bloodmoon"] else 1.0


# ---------------------------------------------------------------- per-step
func tick(dt: float) -> void:
	if run.phase != "wave":
		return
	if shift_at > 0.0 and run.wave_time >= shift_at:
		shift_at = -1.0
		_shift()
	if wind != Vector3.ZERO:
		_drift(dt)
	if info().get("lightning", false):
		strike_t -= dt
		if strike_t <= 0.0:
			strike_t = run.rng.randf_range(3.2, 5.5)
			_lightning()
	if info().get("embers", false):
		ember_t -= dt
		if ember_t <= 0.0:
			ember_t = run.rng.randf_range(4.0, 6.5)
			_ember_fall()
	_tick_patches(dt)


func _shift() -> void:
	var from := display_name()
	_apply(shift_to)
	var c: Color = info()["color"]
	run.banner_requested.emit("The weather turns", "%s gives way to %s" % [from, display_name()])
	run.schedule(1.8, run.toast.bind(String(info()["desc"]), c))
	Audio.play("wave")


func _drift(dt: float) -> void:
	var v := wind * DB.WIND_DRIFT * dt
	var h := run.hero
	if h.alive and not h.dead and h.item_stats.get("weatherproof", 0.0) <= 0.0:
		run.move_unit(h, v)
	for e in run.enemies:
		if e.alive and not e.no_push and not e.is_boss:
			run.move_unit(e, v)


## A lightning strike: telegraphed ring, then damage to everything inside. It favours packs of foes,
## but now and then it comes down beside the hero.
func _lightning() -> void:
	var p := Vector3.ZERO
	var roll := run.rng.randf()
	var h := run.hero
	if roll < 0.3 and h.alive and not h.dead:
		p = h.pos + Vector3(run.rng.randf_range(-1.5, 1.5), 0, run.rng.randf_range(-1.5, 1.5))
	elif roll < 0.8 and run.enemies.size() > 0:
		var e: Unit = run.enemies[run.rng.randi() % run.enemies.size()]
		p = e.pos if e.alive else Vector3.ZERO
	else:
		var a := run.rng.randf() * TAU
		p = Vector3(cos(a), 0, sin(a)) * run.rng.randf_range(0.0, run.arena_safe_r() - 3.0)
	p.y = 0.0
	if p.length() > run.arena_safe_r() - 1.0:
		p = p.normalized() * (run.arena_safe_r() - 1.0)
	var r := DB.LIGHTNING_R
	run.fx("telegraph_circle", {"pos": p, "radius": r, "duration": DB.LIGHTNING_TELE, "color": Color(0.55, 0.75, 1.0)})
	run.add_hazard({"type": "circle", "pos": p, "r": r, "t": DB.LIGHTNING_TELE + 0.1})
	run.schedule(DB.LIGHTNING_TELE, _strike.bind(p))


func _strike(p: Vector3) -> void:
	if run.phase != "wave":
		return
	var r := DB.LIGHTNING_R
	if vis and vis.has_method("lightning"):
		vis.lightning(p)
	run.fx("explosion", {"pos": p, "radius": r, "color": Color(0.55, 0.75, 1.0)})
	run.shake(0.35)
	Audio.play("slam")
	var foe_dmg := 70.0 * DB.hp_mult(run.wave)
	for e in run.enemies_in_radius(p, r):
		run.damage(e, foe_dmg * (0.4 if e.is_boss else 1.0), null, "Lightning", "pure", {"color": Color(0.6, 0.8, 1.0)})
	var h := run.hero
	if h.alive and not h.dead and run._flat(h.pos - p).length() <= r + h.radius * 0.5:
		var share := DB.LIGHTNING_HERO * (0.5 if h.item_stats.get("weatherproof", 0.0) > 0.0 else 1.0)
		run.damage(h, h.max_hp * share, null, "Lightning", "pure")


## Emberfall: an ember lands and leaves a patch of burning sand for a few seconds.
func _ember_fall() -> void:
	var p := Vector3.ZERO
	var h := run.hero
	if run.rng.randf() < 0.3 and h.alive and not h.dead:
		p = h.pos + Vector3(run.rng.randf_range(-3, 3), 0, run.rng.randf_range(-3, 3))
	else:
		var a := run.rng.randf() * TAU
		p = Vector3(cos(a), 0, sin(a)) * run.rng.randf_range(2.0, run.arena_safe_r() - 3.0)
	p.y = 0.0
	if p.length() > run.arena_safe_r() - 1.5:
		p = p.normalized() * (run.arena_safe_r() - 1.5)
	run.fx("telegraph_circle", {"pos": p, "radius": DB.EMBER_R, "duration": 1.0, "color": Color(1.0, 0.5, 0.15)})
	run.add_hazard({"type": "circle", "pos": p, "r": DB.EMBER_R, "t": 1.0 + DB.EMBER_TIME})
	run.schedule(1.0, _ember_land.bind(p))


func _ember_land(p: Vector3) -> void:
	if run.phase != "wave":
		return
	run.fx("explosion", {"pos": p, "radius": DB.EMBER_R, "color": Color(1.0, 0.5, 0.15)})
	var f = run.fx("zone", {"pos": p, "radius": DB.EMBER_R, "color": Color(1.0, 0.45, 0.12), "duration": DB.EMBER_TIME})
	patches.append({"pos": p, "t": DB.EMBER_TIME, "tick": 0.0, "fx": f})


func _tick_patches(dt: float) -> void:
	if patches.is_empty():
		return
	var keep := []
	for pt in patches:
		pt["t"] -= dt
		pt["tick"] -= dt
		if pt["tick"] <= 0.0:
			pt["tick"] = 0.5
			var p: Vector3 = pt["pos"]
			for e in run.enemies_in_radius(p, DB.EMBER_R):
				run.damage(e, 22.0 * DB.hp_mult(run.wave) * 0.5, null, "Ember Patch", "magic", {"color": Color(1.0, 0.55, 0.2)})
			var h := run.hero
			if h.alive and not h.dead and run._flat(h.pos - p).length() <= DB.EMBER_R + h.radius * 0.5:
				var share := DB.EMBER_HERO * (0.5 if h.item_stats.get("weatherproof", 0.0) > 0.0 else 1.0)
				run.damage(h, h.max_hp * share * 0.5, null, "Ember Patch", "pure")
		if pt["t"] > 0.0:
			keep.append(pt)
		else:
			run.fx_stop(pt["fx"])
	patches = keep


func clear_patches() -> void:
	for pt in patches:
		run.fx_stop(pt["fx"])
	patches.clear()
