extends Node
## Crash soak monitor (--soak). Watches a bot run for the kinds of bugs that have reached phones before and
## writes what it finds into the --report JSON under "soak" (tools/soak.py runs the matrix and reads it):
## - freezes: a real frame longer than --soak-freeze-ms (default 1500)
## - broken positions: NaN/inf, the hero or a foe far outside the world, the hero below the ground
## - the hero model stuck in its death pose (or missing) while the hero is alive (the 0.4.2 "under the earth" bug)
## - wave flow: a wave skipped after a death (0.4.4), a wave number that jumps, a fight where no damage lands
##   for 90 s, a wave that never ends,
##   or a phase (clear, dead, prep) that never moves on (the camp-return freeze)
## - live foes without a model, bosses left over after a cleared wave
## - nodes or orphan nodes that keep piling up from one camp visit to the next
## Each issue is also printed as "SOAK ISSUE: ..." so it shows up even if the process dies afterwards.

const WORLD_R := 48.0         # camp sits at z 37, the arena rim at 22
const STUCK_PHASE_S := {"clear": 12.0, "dead": 12.0, "victory_wait": 12.0}
const PREP_SLACK_S := 20.0

var run: Run
var freeze_ms := 1500
var wave_limit_s := 1800.0    # sim seconds; a slow hero under --god can take 10+ minutes on wave 20, but not this long
const STALL_S := 90.0         # sim seconds with foes alive and no damage dealt to them = stalemate
var issues := {}              # key -> {what, detail, n, t, wave}
var preps: Array = []         # [{wave, nodes, orphans, static_mb}] sampled on each camp visit
var checks := 0
var longest_frame_ms := 0
var waves_started := 0
var deaths := 0

var _last_ms := 0
var _last_phase := ""
var _last_wave := 0
var _phase_t := 0.0
var _death_wave := -1
var _pose_bad_t := 0.0
var _empty_wave_t := 0.0
var _stall_t := 0.0
var _dealt := -1.0


func setup(r: Run) -> void:
	run = r
	freeze_ms = int(Game.arg("soak-freeze-ms", "1500"))
	wave_limit_s = float(Game.arg("soak-wave-limit", "1800"))
	_last_ms = Time.get_ticks_msec()
	_last_phase = r.phase
	_last_wave = r.wave
	Game.soak = self


func issue(key: String, what: String, detail := "") -> void:
	if issues.has(key):
		issues[key]["n"] += 1
		return
	var w := run.wave if run and is_instance_valid(run) else 0
	var t := snappedf(run.run_time, 0.1) if run and is_instance_valid(run) else 0.0
	issues[key] = {"what": what, "detail": detail, "n": 1, "t": t, "wave": w}
	print("SOAK ISSUE: w%d t%.1f %s %s" % [w, t, what, detail])
	Game.crumb("soak: " + what)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var ms := now - _last_ms
	_last_ms = now
	longest_frame_ms = maxi(longest_frame_ms, ms)
	if ms > freeze_ms and run.run_time > 2.0:
		issue("freeze_w%d_%s" % [run.wave, run.phase], "freeze", "%d ms frame in %s" % [ms, run.phase])


## Called by Run after each simulation step.
func tick(dt: float) -> void:
	if run.result != "":
		return
	checks += 1
	_check_flow(dt)
	_check_hero(dt)
	_check_units()


func _check_flow(dt: float) -> void:
	var ph := run.phase
	if ph != _last_phase:
		_on_phase(_last_phase, ph)
		_last_phase = ph
		_phase_t = 0.0
	else:
		_phase_t += dt
	if run.wave != _last_wave:
		if run.wave != _last_wave + 1:
			issue("wave_jump", "wave number jumped", "%d -> %d" % [_last_wave, run.wave])
		if run.wave > _last_wave and _death_wave == _last_wave:
			issue("wave_skipped_after_death", "wave skipped after a death", "died on %d, now %d" % [_death_wave, run.wave])
		_last_wave = run.wave
	if STUCK_PHASE_S.has(ph) and _phase_t > STUCK_PHASE_S[ph]:
		issue("stuck_" + ph, "phase never moves on", "%s for %.0f s" % [ph, _phase_t])
	if ph == "prep" and run.tutorial == null and _phase_t > DB.FIRST_PREP_TIME + PREP_SLACK_S and not Game.paused_by_shop:
		issue("stuck_prep", "prep never ends", "%.0f s" % _phase_t)
	if ph == "wave":
		if run.wave_time > wave_limit_s:
			issue("long_wave_%d" % run.wave, "wave never ends", "%.0f s, %d queued, %s" % [run.wave_time, run.spawn_queue.size(), _foes_left()])
		var alive_n := 0
		for e in run.enemies:
			if e.alive:
				alive_n += 1
		# damage keeps flowing while the fight progresses; none for a long time means foes nobody can hit or reach
		var dealt := 0.0
		for v in run.stats["damage_by"].values():
			dealt += float(v)
		_stall_t = _stall_t + dt if alive_n > 0 and dealt <= _dealt else 0.0
		_dealt = dealt
		if _stall_t > STALL_S:
			issue("stall_%d" % run.wave, "fight stalled: no damage dealt", "%.0f s, %s" % [_stall_t, _foes_left()])
		_empty_wave_t = _empty_wave_t + dt if alive_n == 0 and run.spawn_queue.is_empty() else 0.0
		if _empty_wave_t > 5.0:
			issue("empty_wave_%d" % run.wave, "wave has no foes left but doesn't clear", "%.0f s" % _empty_wave_t)


func _foes_left() -> String:
	var left := []
	for e in run.enemies:
		if e.alive and left.size() < 6:
			left.append("%s hp %d at (%.0f, %.0f)%s" % [e.kind, int(e.hp), e.pos.x, e.pos.z, " untargetable" if e.untargetable else ""])
	return "foes: " + ", ".join(left)


func _on_phase(from: String, to: String) -> void:
	match to:
		"wave":
			waves_started += 1
			if _death_wave > 0 and run.wave != _death_wave and run.mode != "practice":
				issue("wave_skipped_after_death", "wave skipped after a death", "died on %d, fighting %d" % [_death_wave, run.wave])
			_death_wave = -1
		"dead":
			deaths += 1
			_death_wave = run.wave
		"prep":
			if from == "dead" and run.wave != _death_wave:
				issue("wave_skipped_after_death", "wave skipped after a death", "died on %d, back in camp for %d" % [_death_wave, run.wave])
			if run.boss_units.size() > 0:
				issue("boss_left_in_camp", "bosses still listed after the wave", str(run.boss_units.size()))
			if run.enemies.size() > 0:
				issue("foes_left_in_camp", "foes still listed in camp", str(run.enemies.size()))
			preps.append({"wave": run.wave, "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
				"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)})


func _bad_vec(v: Vector3) -> bool:
	return is_nan(v.x) or is_nan(v.y) or is_nan(v.z) or is_inf(v.x) or is_inf(v.y) or is_inf(v.z)


func _check_hero(dt: float) -> void:
	var h := run.hero
	if _bad_vec(h.pos):
		issue("hero_nan", "hero position is NaN/inf")
		return
	if Vector2(h.pos.x, h.pos.z).length() > WORLD_R:
		issue("hero_out", "hero left the world", str(h.pos))
	if h.pos.y < -0.5:
		issue("hero_below", "hero below the ground", "y %.2f" % h.pos.y)
	if is_nan(h.hp) or is_nan(h.mana):
		issue("hero_hp_nan", "hero HP or mana is NaN")
	if h.alive and not h.dead and h.hp > 0.0 and run.phase != "dead":
		var bad := ""
		if h.node == null or not is_instance_valid(h.node):
			bad = "no model"
		elif h.node.position.y < -0.5:
			bad = "model at y %.2f" % h.node.position.y
		elif "dead" in h.node and (h.node.dead or h.node.dissolve > 0.5):
			bad = "model in death pose (dissolve %.2f)" % h.node.dissolve
		elif not h.node.visible:
			bad = "model hidden"
		# the spawn animation rises out of the ground for a moment
		_pose_bad_t = _pose_bad_t + dt if bad != "" else 0.0
		if _pose_bad_t > 3.0:
			issue("hero_model", "hero alive but its model is wrong", bad)


func _check_units() -> void:
	for e in run.enemies:
		if not e.alive:
			continue
		if _bad_vec(e.pos):
			issue("foe_nan_" + e.kind, "foe position is NaN/inf", e.kind)
		elif Vector2(e.pos.x, e.pos.z).length() > WORLD_R:
			issue("foe_out_" + e.kind, "foe left the world", "%s at %s" % [e.kind, e.pos])
		if e.node == null or not is_instance_valid(e.node):
			issue("foe_no_model_" + e.kind, "live foe without a model", e.kind)
		if is_nan(e.hp):
			issue("foe_hp_nan_" + e.kind, "foe HP is NaN", e.kind)
	for a in run.allies:
		if a.alive and _bad_vec(a.pos):
			issue("ally_nan_" + a.kind, "ally position is NaN/inf", a.kind)


func summary() -> Dictionary:
	var growth := {}
	# compare the 2nd camp visit (things settled) with the last one
	if preps.size() >= 4:
		var a: Dictionary = preps[1]
		var b: Dictionary = preps[-1]
		growth = {"nodes": b["nodes"] - a["nodes"], "orphans": b["orphans"] - a["orphans"],
			"static_mb": snappedf(b["static_mb"] - a["static_mb"], 0.1)}
		if growth["orphans"] > 200:
			issue("orphan_growth", "orphan nodes keep piling up", "+%d between camp visits" % growth["orphans"])
		if growth["nodes"] > 400 and growth["nodes"] > a["nodes"] * 0.5:
			issue("node_growth", "node count keeps growing", "+%d between camp visits" % growth["nodes"])
	return {"checks": checks, "waves_started": waves_started, "deaths": deaths, "longest_frame_ms": longest_frame_ms,
		"issues": issues.values(), "preps": preps, "growth": growth}
