extends Node
## Regression tests for bugs that reached phones, plus a smoke pass of every hero through the same paths.
## Any engine or script error logged while a section runs fails that section.
##   godot --headless --path . res://tests/test_regressions.tscn
## Exit code 0 = all pass, 1 = failures.

var passed := 0
var failed := 0
var fails: Array = []
var _section := ""
var _log := ErrSink.new()
var _err_mark := 0


class ErrSink extends Logger:
	var errs: Array = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == 1:   # warnings
			return
		var msg := "%s (%s:%d %s) %s" % [code, file, line, function, rationale]
		var low := msg.to_lower()
		if low.contains("audio") or low.contains("alsa") or low.contains("pulse"):
			return
		mutex.lock()
		errs.append(msg)
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func count() -> int:
		mutex.lock()
		var n := errs.size()
		mutex.unlock()
		return n


func section(s: String) -> void:
	_end_section()
	_section = s
	_err_mark = _log.count()
	print("\n== ", s)


func _end_section() -> void:
	if _section == "":
		return
	var n := _log.count()
	if n > _err_mark:
		check(false, "no errors logged", "; ".join(_log.errs.slice(_err_mark, mini(n, _err_mark + 3))))
	else:
		check(true, "no errors logged")


func check(cond: bool, what: String, detail := "") -> void:
	if cond:
		passed += 1
		print("  ok   ", what)
	else:
		failed += 1
		var line := "[%s] %s %s" % [_section, what, detail]
		fails.append(line)
		print("  FAIL ", what, "  ", detail)


func make_run(hero := "ashwarden", wave := 1) -> Run:
	var r := Run.new()
	r.setup(hero, wave)
	get_tree().root.add_child(r)
	r.weather.pin("clear")
	return r


func free_run(r: Run) -> void:
	if is_instance_valid(r):
		r.queue_free()
	await get_tree().process_frame


## Steps the sim n times and lets the engine draw in between, so visuals and fx run like in the game.
func steps(r: Run, n: int, dt := 1.0 / 30.0) -> void:
	for i in n:
		r._step(dt)
		if i % 6 == 5:
			await get_tree().process_frame
		if r.result != "":
			return


func start_wave(r: Run) -> void:
	r.skip_prep()
	r._step(0.05)


## Steps until the wave's bosses are out (they spawn ~2 s in).
func wait_bosses(r: Run, want: int) -> void:
	for i in 300:
		r._step(1.0 / 30.0)
		if r.boss_units.filter(func(b): return b.alive).size() >= want:
			return


func kill_all(r: Run) -> void:
	for e in r.enemies.duplicate():
		if e.alive:
			r.kill(e, r.hero)
	r.spawn_queue.clear()


func power_up(h: Hero) -> void:
	h.skill_points = 4
	for s in 4:
		h.ranks[s] = maxi(h.ranks[s], 1)
	h.mana = 99999.0
	h.max_mana = maxf(h.max_mana, 99999.0)


func cast_all(r: Run) -> int:
	var n := 0
	for s in 4:
		r.hero.cds[s] = 0.0
		r.hero.mana = r.hero.max_mana
		if r.try_cast(s):
			n += 1
	return n


## Waits for the respawn rise (the model animates in real time) and checks the hero is standing on the ground.
func hero_ok(r: Run, what: String) -> void:
	await get_tree().create_timer(1.2).timeout
	var h := r.hero
	check(h.alive and not h.dead, what + ": hero alive")
	check(h.pos.y > -0.05 and h.pos.y < 0.5, what + ": hero on the ground", "y=%.2f" % h.pos.y)
	if h.node and is_instance_valid(h.node):
		check(h.node.visible and h.node.position.y > -0.05, what + ": model on the ground", "y=%.2f" % h.node.position.y)
		if "dead" in h.node:
			check(not h.node.dead and h.node.dissolve < 0.05, what + ": model not in death pose",
				"dead=%s dissolve=%.2f" % [h.node.dead, h.node.dissolve])


func arena_clean(r: Run, what: String) -> void:
	check(r.enemies.is_empty() and r.boss_units.is_empty(), what + ": no foes left", "%d/%d" % [r.enemies.size(), r.boss_units.size()])
	check(r.projs.is_empty() and r.walls.is_empty() and r.pools.is_empty() and r.hazards.is_empty(), what + ": no projectiles/walls/pools/hazards left")


func _ready() -> void:
	OS.add_logger(_log)
	_main.call_deferred()


func _main() -> void:
	await get_tree().process_frame
	Engine.time_scale = 1.0
	Profile.use_paths("user://test_profile.json", "user://test_saved_run.json")
	Profile.reset()
	await test_matrons_same_frame()
	await test_matrons_one_by_one()
	await test_matron_dies_mid_beam_hero_dies()
	await test_every_boss_to_camp()
	await test_camp_return_with_fx()
	await test_death_replays_wave()
	await test_death_during_clear()
	await test_last_kill_and_death_same_step()
	await test_respawn_model()
	await test_save_resume()
	await test_sanguine_bleed_kills_choir()
	await test_hex_bolts_dodgeable()
	await test_soak_monitor()
	await test_every_hero()
	_end_section()
	print("\n==== RESULT: %d passed, %d failed" % [passed, failed])
	for f in fails:
		print("FAILED: ", f)
	OS.remove_logger(_log)
	get_tree().quit(0 if failed == 0 else 1)


# ------------------------------------------------------------------ Twin Matrons (0.1.1 crash on the kill)
func test_matrons_same_frame() -> void:
	section("Twin Matrons die in the same frame")
	var r := make_run("riftdancer", 10)
	await get_tree().process_frame
	start_wave(r)
	await wait_bosses(r, 2)
	var ms: Array = r.boss_units.filter(func(b): return b.kind == "matron")
	check(ms.size() == 2, "both Matrons spawned", str(ms.size()))
	if ms.size() == 2:
		await steps(r, 90)   # let the heal link and patterns start
		ms[0]._start_beam(220.0, 6.0, 20.0, 1.8, 0.1)
		await steps(r, 10)
		r.kill(ms[0], r.hero)
		r.kill(ms[1], r.hero)
		for m in ms:
			check(m.beam.is_empty() and m.link_fx == null, "Matron %d beam and link stopped" % m.twin_index)
		kill_all(r)
		await steps(r, 200)
		check(r.wave == 11 and r.phase == "prep", "wave cleared, back in camp for wave 11", "wave %d %s" % [r.wave, r.phase])
		arena_clean(r, "after the Matrons")
		await hero_ok(r, "after the Matrons")
	await free_run(r)


func test_matrons_one_by_one() -> void:
	section("Twin Matrons die one after the other")
	var r := make_run("hivemother", 10)
	await get_tree().process_frame
	start_wave(r)
	await wait_bosses(r, 2)
	var ms: Array = r.boss_units.filter(func(b): return b.kind == "matron")
	if ms.size() == 2:
		await steps(r, 60)
		r.kill(ms[1], r.hero)
		check(ms[0].enraged, "the survivor enrages")
		await steps(r, 150)   # survivor keeps fighting with its twin dead (link target gone)
		check(ms[0].alive, "survivor still fighting")
		ms[0]._start_beam(240.0, 6.0, 20.0, 1.8, 0.1)
		await steps(r, 20)
		r.kill(ms[0], r.hero)
		kill_all(r)
		await steps(r, 200)
		check(r.wave == 11 and r.phase == "prep", "back in camp for wave 11", "wave %d %s" % [r.wave, r.phase])
		arena_clean(r, "after the Matrons")
	else:
		check(false, "both Matrons spawned", str(ms.size()))
	await free_run(r)


func test_matron_dies_mid_beam_hero_dies() -> void:
	section("hero dies while a Matron beam is sweeping")
	var r := make_run("gunsmith", 10)
	await get_tree().process_frame
	start_wave(r)
	await wait_bosses(r, 2)
	var ms: Array = r.boss_units.filter(func(b): return b.kind == "matron")
	if ms.size() > 0:
		ms[0]._start_beam(220.0, 6.0, 20.0, 1.8, 0.1)
		await steps(r, 15)
	r.damage(r.hero, 999999.0, ms[0] if ms.size() > 0 else null, "Test", "magic")
	await steps(r, 150)
	check(r.phase == "prep" and r.wave == 10, "respawned in camp for wave 10 again", "wave %d %s" % [r.wave, r.phase])
	arena_clean(r, "after the death")
	for m in ms:
		check(m.beam.is_empty(), "removed Matron's beam stopped")
	await steps(r, 45)
	await hero_ok(r, "after the respawn")
	await free_run(r)


# ------------------------------------------------------------------ every boss, kill -> clear -> camp
func test_every_boss_to_camp() -> void:
	for w in [5, 10, 15, 20]:
		section("boss wave %d: kill -> clear -> camp" % w)
		var r := make_run("stoneshaper", w)
		await get_tree().process_frame
		power_up(r.hero)
		start_wave(r)
		await wait_bosses(r, 1)
		check(r.boss_units.size() > 0, "boss spawned")
		await steps(r, 120)
		cast_all(r)
		await steps(r, 5)
		# the Warden's gauntlet brings echoes after the boss; keep killing until the wave ends
		for k in 12:
			kill_all(r)
			await steps(r, 30)
			if r.phase != "wave":
				break
		await steps(r, 200)
		if w == 20:
			check(r.result == "victory", "wave 20 ends in victory", "%s %s" % [r.phase, r.result])
		else:
			check(r.wave == w + 1 and r.phase == "prep", "back in camp for the next wave", "wave %d %s" % [r.wave, r.phase])
			arena_clean(r, "camp")
			check(r.hero.in_camp and r.hero.pos.distance_to(DB.CAMP_SPAWN) < 3.0, "hero teleported to camp")
			await hero_ok(r, "camp")
		await free_run(r)


# ------------------------------------------------------------------ camp return (render freeze report)
func test_camp_return_with_fx() -> void:
	section("camp return while skills and fx are live")
	for hero in ["ashwarden", "hivemother", "gravekeeper", "sunspeaker"]:
		var r := make_run(hero, 6)
		await get_tree().process_frame
		power_up(r.hero)
		start_wave(r)
		await steps(r, 150)
		var casts := cast_all(r)
		await steps(r, 3)
		kill_all(r)
		await steps(r, 100)
		check(r.phase == "prep" and r.wave == 7, hero + ": back in camp", "wave %d %s (cast %d)" % [r.wave, r.phase, casts])
		await steps(r, 60)
		var fx_a := r.fx_root.get_child_count()
		await steps(r, 240)
		var fx_b := r.fx_root.get_child_count()
		check(fx_b <= fx_a, hero + ": fx don't pile up in camp", "%d -> %d" % [fx_a, fx_b])
		arena_clean(r, hero)
		await hero_ok(r, hero)
		await free_run(r)


# ------------------------------------------------------------------ wave replay after death (0.4.4)
func test_death_replays_wave() -> void:
	section("dying replays the wave (normal and boss)")
	for w in [3, 5, 12]:
		var r := make_run("sanguine", w)
		await get_tree().process_frame
		start_wave(r)
		await steps(r, 90)
		r.damage(r.hero, 999999.0, null, "Test", "magic")
		await steps(r, 150)
		check(r.wave == w and r.phase == "prep", "died on %d, camp for %d again" % [w, w], "wave %d %s" % [r.wave, r.phase])
		start_wave(r)
		check(r.wave == w and r.phase == "wave", "fighting wave %d again" % w)
		await steps(r, 60)
		check(r.enemies.size() > 0 or r.spawn_queue.size() > 0, "wave %d spawns again" % w)
		await free_run(r)


func test_death_during_clear() -> void:
	section("hero hit after the last kill (wave already cleared)")
	var r := make_run("snarewright", 4)
	await get_tree().process_frame
	start_wave(r)
	await steps(r, 60)
	kill_all(r)
	await steps(r, 3)
	check(r.phase == "clear", "wave cleared", r.phase)
	var cleared := r.waves_cleared
	# a projectile already in the air lands after the wave ends
	r.damage(r.hero, 999999.0, null, "Test", "magic")
	await steps(r, 200)
	check(r.result == "" and r.phase in ["prep", "wave"], "run continues", "%s %s" % [r.phase, r.result])
	check(r.wave == 5, "a cleared wave isn't replayed", "wave %d" % r.wave)
	check(r.waves_cleared == cleared, "cleared count unchanged")
	check(r.lives == DB.START_LIVES, "no life lost", str(r.lives))
	await hero_ok(r, "after")
	await free_run(r)
	# same on the last wave: a late hit must not turn the victory into a replay
	var r2 := make_run("snarewright", 20)
	await get_tree().process_frame
	start_wave(r2)
	for k in 12:
		await steps(r2, 60)
		kill_all(r2)
		if r2.phase != "wave":
			break
	r2.damage(r2.hero, 999999.0, null, "Test", "magic")
	await steps(r2, 200)
	check(r2.result == "victory", "late hit after the Warden still ends in victory", "%s %s" % [r2.phase, r2.result])
	await free_run(r2)


func test_last_kill_and_death_same_step() -> void:
	section("hero dies on the same step as the last kill")
	var r := make_run("twinhide", 7)
	await get_tree().process_frame
	start_wave(r)
	await steps(r, 60)
	r.spawn_queue.clear()
	r.damage(r.hero, 999999.0, null, "Test", "magic")
	kill_all(r)
	await steps(r, 200)
	check(r.phase == "prep" and r.wave == 7, "the wave is fought again", "wave %d %s" % [r.wave, r.phase])
	check(r.lives == DB.START_LIVES - 1, "one life lost", str(r.lives))
	await hero_ok(r, "after")
	await free_run(r)


# ------------------------------------------------------------------ hero sunk in the ground (0.4.2)
func test_respawn_model() -> void:
	section("hero model after respawns")
	var r := make_run("riftdancer", 2)
	await get_tree().process_frame
	for k in 2:
		start_wave(r)
		await steps(r, 45)
		r.damage(r.hero, 999999.0, null, "Test", "magic")
		await steps(r, 150)
		await get_tree().create_timer(1.5).timeout
		await hero_ok(r, "respawn %d" % (k + 1))
		check(r.hero.pos.distance_to(DB.CAMP_SPAWN) < 3.0, "respawn %d: in camp" % (k + 1))
	await free_run(r)


# ------------------------------------------------------------------ saved run in camp
func test_save_resume() -> void:
	section("save in camp, resume")
	var r := make_run("gravekeeper", 6)
	await get_tree().process_frame
	r.gold = 777
	var snap := r.snapshot()
	await free_run(r)
	var r2 := Run.new()
	r2.setup("gravekeeper", 1, Modes.config("classic", "hard").merged({"resume": snap}))
	get_tree().root.add_child(r2)
	await get_tree().process_frame
	check(r2.wave == 6 and r2.gold == 777 and r2.phase == "prep", "resumed at wave 6 with the gold", "wave %d gold %d %s" % [r2.wave, r2.gold, r2.phase])
	start_wave(r2)
	await steps(r2, 60)
	check(r2.phase == "wave" and r2.enemies.size() > 0, "resumed run plays")
	await free_run(r2)


# ------------------------------------------------------------------ Sanguine bleeds (found by the CI soak)
func test_sanguine_bleed_kills_choir() -> void:
	section("Sanguine bleed kills the Hollow Choir, which takes its bleeding adds with it")
	var r := make_run("sanguine", 15)
	await get_tree().process_frame
	start_wave(r)
	await wait_bosses(r, 1)
	var choir: Boss = null
	for b in r.boss_units:
		if b.kind == "hollow_choir":
			choir = b
	check(choir != null, "Choir spawned")
	if choir:
		choir._summon_adds("choir_add", 3)
		await steps(r, 2)
		var kit = r.hero.kit
		# the Choir bleeds first, so its death clears the adds' bleeds while the kit is still walking the list
		kit.bleeds[choir] = {"t": 5.0, "dps": 10.0, "tick": 0.0}
		for a in choir.adds:
			if a.alive:
				kit.bleeds[a] = {"t": 5.0, "dps": 10.0, "tick": 0.0}
		choir.phase_invuln = 0.0
		choir.hp = 1.0
		kit.tick(0.05)
		check(not choir.alive, "the bleed killed the Choir")
		check(kit.bleeds.is_empty(), "no bleeds left on dead foes", str(kit.bleeds.size()))
	await free_run(r)


# ------------------------------------------------------------------ hex bolts always hit (wave 17 unplayable)
## Fires one hex bolt from `from` at the hero, standing at `at` (moving by `vel` m/s), and reports whether it hit.
func _hex_shot(r: Run, from: Vector3, at: Vector3, vel := Vector3.ZERO) -> bool:
	var h := r.hero
	h.pos = at
	h.hp = h.max_hp
	r.projs.clear()
	var e := r.spawn_enemy("hexcaster", from)
	var opts := {"slow": 0.3, "slow_t": 1.6, "hex": DB.HEX_TIME, "dtype": "magic", "life": DB.HEX_BOLT_LIFE,
		"turn": DB.HEX_BOLT_TURN, "color": Color(0.7, 0.4, 1.0)}
	r.fire_projectile("hex_bolt", from + Vector3(0, 1.3, 0), h, Vector3.ZERO, DB.HEX_BOLT_SPEED, 20.0, 1, e, "Hexcaster", opts)
	for i in 120:
		h.pos += vel / 30.0
		r._tick_projectiles(1.0 / 30.0)
		if r.projs.is_empty():
			break
	r.kill(e, null)
	return h.hp < h.max_hp


func test_hex_bolts_dodgeable() -> void:
	section("hex bolts can be dodged: sidestep, pillar or barrel cover")
	var r := make_run("ashwarden", 3)
	await get_tree().process_frame
	start_wave(r)
	r.spawn_queue.clear()
	kill_all(r)
	check(_hex_shot(r, Vector3(0, 0, -16), Vector3(0, 0, -7)), "a hero standing still is hit")
	check(not _hex_shot(r, Vector3(0, 0, -16), Vector3(0, 0, -7), Vector3(5, 0, 0)), "a hero running sideways dodges it")
	# pillar (-9, -6): caster east of it, hero tucked in west of it
	check(not _hex_shot(r, Vector3(-1, 0, -6), Vector3(-11.4, 0, -6)), "a pillar between stops it")
	var br: Barrel = null
	for b in r.barrels.all:
		if b.alive and not b.keg and b.pos.z < 0.0 and r.barrels.barrel_at(r.barrels.cell_of(b.pos) + Vector2i(-1, 0)) != null:
			br = b
			break
	check(br != null, "found a barrel with one behind it")
	if br:
		# hero dug in two cells deep, caster out in the open on the same row
		var dir := Vector3(-1, 0, 0)
		check(not _hex_shot(r, br.pos - dir * 8.0, br.pos + dir * DB.BARREL_GRID), "barrels between stop it")
	await free_run(r)


# ------------------------------------------------------------------ the soak monitor itself
func test_soak_monitor() -> void:
	section("soak monitor catches the old bugs")
	var r := make_run("ashwarden", 3)
	await get_tree().process_frame
	var mon: Node = load("res://scripts/soak.gd").new()
	r.add_child(mon)
	mon.setup(r)
	r.soak = mon
	start_wave(r)
	await steps(r, 30)
	check(mon.issues.is_empty(), "quiet on a normal wave", str(mon.issues.keys()))
	r.damage(r.hero, 999999.0, null, "Test", "magic")
	await steps(r, 150)
	r.wave += 1   # fixed in 0.4.4: dying used to move on to the next wave
	await steps(r, 2)
	check(mon.issues.has("wave_skipped_after_death"), "flags a wave skipped after a death", str(mon.issues.keys()))
	r.hero.node.dead = true   # fixed in 0.4.2: the model stayed in its death pose after a respawn
	r.hero.node.dissolve = 1.0
	await steps(r, 120)
	check(mon.issues.has("hero_model"), "flags the hero model in its death pose", str(mon.issues.keys()))
	r.hero.pos.y = -2.0
	r._step(0.01)
	check(mon.issues.has("hero_below"), "flags the hero under the ground")
	r.hero.pos = Vector3(0, 0, 37)
	r.phase = "clear"
	r.phase_t = 999.0
	for i in 400:
		mon.tick(1.0 / 30.0)
	check(mon.issues.has("stuck_clear"), "flags a phase that never moves on", str(mon.issues.keys()))
	if Game.soak == mon:
		Game.soak = null
	await free_run(r)


# ------------------------------------------------------------------ every hero through the same paths
func test_every_hero() -> void:
	for hero in DB.HERO_ORDER:
		section("hero %s: casts, boss kill, death, respawn" % hero)
		var r := make_run(hero, 5)
		await get_tree().process_frame
		power_up(r.hero)
		start_wave(r)
		await wait_bosses(r, 1)
		await steps(r, 60)
		check(cast_all(r) > 0, "casts skills")
		await steps(r, 90)
		cast_all(r)
		await steps(r, 30)
		r.kill(r.hero, null)   # straight kill: some kits cheat death from damage
		await steps(r, 150)
		check(r.phase == "prep" and r.wave == 5, "respawned for wave 5", "wave %d %s" % [r.wave, r.phase])
		arena_clean(r, "after the death")
		start_wave(r)
		await wait_bosses(r, 1)
		cast_all(r)
		await steps(r, 30)
		for k in 6:
			kill_all(r)
			await steps(r, 30)
			if r.phase != "wave":
				break
		await steps(r, 150)
		check(r.phase == "prep" and r.wave == 6, "boss down, camp for wave 6", "wave %d %s" % [r.wave, r.phase])
		arena_clean(r, "camp")
		await get_tree().create_timer(0.5).timeout
		await hero_ok(r, "camp")
		await free_run(r)
