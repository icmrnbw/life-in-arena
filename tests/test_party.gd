extends "res://tests/test_regressions.gd"
## Other players (0.7): AI ally heroes, camp duels against a rival hero, the Duel Ladder.
##   godot --headless --path . res://tests/test_party.tscn
## Exit code 0 = all pass, 1 = failures.


func _main() -> void:
	await get_tree().process_frame
	Engine.time_scale = 1.0
	Profile.use_paths("user://test_profile.json", "user://test_saved_run.json")
	Profile.reset()
	await test_pick_allies()
	await test_allies_wave()
	await test_allies_save_resume()
	await test_duel_win()
	await test_duel_loss()
	await test_duel_declined()
	await test_ladder()
	await test_every_hero_as_ally()
	await test_every_rival()
	_end_section()
	print("\n==== RESULT: %d passed, %d failed" % [passed, failed])
	for f in fails:
		print("FAILED: ", f)
	OS.remove_logger(_log)
	get_tree().quit(0 if failed == 0 else 1)


func make_party_run(hero: String, wave: int, extra: Dictionary) -> Run:
	var r := Run.new()
	r.setup(hero, wave, Modes.config("classic", "hard", extra))
	get_tree().root.add_child(r)
	r.weather.pin("clear")
	return r


func ally_damage(r: Run) -> float:
	var t := 0.0
	for k in r.stats["damage_by"]:
		if String(k).ends_with("(ally)"):
			t += float(r.stats["damage_by"][k])
	return t


func test_pick_allies() -> void:
	section("allies are picked to complement the player")
	var rng := RandomNumberGenerator.new()
	for i in 20:
		rng.seed = i
		var p: String = DB.HERO_ORDER[i % DB.HERO_ORDER.size()]
		var ids := Run.pick_companions(p, 3, rng)
		var ok := ids.size() == 3 and not ids.has(p) and not ids.has("alchemist")
		var mine: String = DB.HEROES[p]["dmg_type"]
		if ok and mine != "mixed":
			ok = DB.HEROES[ids[0]]["dmg_type"] == ("magic" if mine == "phys" else "phys")
		check(ok, "%s gets %s" % [p, ", ".join(ids)])


func test_allies_wave() -> void:
	section("two allies fight a wave, one falls and is back next wave")
	var r := make_party_run("ashwarden", 3, {"ally_ids": ["frostweaver", "vanguard"]})
	await get_tree().process_frame
	check(r.companions.size() == 2, "two allies")
	var c0: Hero = r.companions[0]
	check(c0.level == r.hero.level and c0.items.size() > 0, "allies start at the player's level with items", "lv %d items %d" % [c0.level, c0.items.size()])
	check(c0.in_camp and not c0.targetable and r.allies.has(c0), "allies wait in camp")
	start_wave(r)
	check(not c0.in_camp and c0.targetable and c0.pos.z < 30.0, "allies come into the arena")
	await steps(r, 600)
	check(ally_damage(r) > 0.0, "allies deal damage", str(r.stats["damage_by"].keys()))
	var cast_any := false
	for c in r.companions:
		for s in 4:
			if c.ranks[s] > 0 and c.cds[s] > 0.0:
				cast_any = true
	check(cast_any, "allies cast skills")
	r.kill(c0, null)
	check(c0.dead and not r.allies.has(c0), "a fallen ally leaves the fight")
	check(r.phase == "wave" and r.lives == 3, "the wave goes on, no life lost")
	await steps(r, 60)
	for k in 8:
		kill_all(r)
		await steps(r, 40)
		if r.phase != "wave":
			break
	await steps(r, 120)
	check(r.phase == "prep" and r.wave == 4, "camp for wave 4", "wave %d %s" % [r.wave, r.phase])
	check(not c0.dead and c0.alive and c0.in_camp and r.allies.has(c0), "the fallen ally is back in camp")
	start_wave(r)
	check(r.enemies.size() + r.spawn_queue.size() > 0, "wave 4 starts")
	var e := r.spawn_enemy("gnawer", Vector3(0, 0, 0))
	check(e.max_hp > float(DB.ENEMIES["gnawer"]["hp"]) * 1.5, "foes are tougher with allies", "%.0f" % e.max_hp)
	await steps(r, 30)
	await free_run(r)


func test_allies_save_resume() -> void:
	section("a saved run keeps its allies")
	var r := make_party_run("gunsmith", 7, {"allies": 2})
	await get_tree().process_frame
	var ids: Array = r.companions.map(func(c): return c.hero_id)
	var lv: int = r.companions[1].level
	var its: int = r.companions[1].items.size()
	var snap := r.snapshot()
	await free_run(r)
	var r2 := Run.new()
	r2.setup("gunsmith", 1, Modes.config("classic", "hard").merged(snap["cfg"]).merged({"resume": snap}))
	get_tree().root.add_child(r2)
	await get_tree().process_frame
	check(r2.companions.map(func(c): return c.hero_id) == ids, "same allies", str(ids))
	check(r2.companions[1].level == lv and r2.companions[1].items.size() == its, "same level and items")
	start_wave(r2)
	await steps(r2, 90)
	check(r2.phase == "wave", "resumed run plays")
	await free_run(r2)


func _duel_run(hero := "duelist", wave := 4) -> Run:
	var r := make_party_run(hero, wave, {"allies": 1})
	await get_tree().process_frame
	return r


func test_duel_win() -> void:
	section("camp duel: won")
	var r: Run = await _duel_run()
	check(not r.duel.offer.is_empty() and r.duel.can_accept(), "a challenger waits before wave 4")
	var g0 := r.gold
	var str0: float = r.hero.bonus["str"]
	check(r.duel.accept(), "duel accepted")
	check(r.phase == "duel" and r.rival != null and r.enemies.has(r.rival), "the rival is in the arena")
	check(r.rival.level == r.hero.level and r.rival.team == 1, "rival at the player's level, on the foe side")
	check(r.companions[0].in_camp, "allies watch from camp")
	var hp0 := r.hero.hp
	await steps(r, 300)
	check(r.hero.hp < hp0 or r.phase != "duel", "the rival fights the player", "%.0f / %.0f" % [r.hero.hp, hp0])
	if r.phase == "duel":
		r.kill(r.rival, r.hero)
	check(r.phase == "duel_end" or r.phase == "prep", "duel over")
	await steps(r, 120)
	check(r.phase == "prep" and r.rival == null and r.enemies.is_empty(), "back in camp, rival gone")
	if r.duel.won:
		check(r.gold > g0 and r.hero.bonus["str"] == str0 + Duel.WIN_STATS, "won: gold and attributes")
	check(not r.duel.can_accept(), "one duel per challenge")
	check(r.hero.in_camp and r.hero.hp >= r.hero.max_hp - 1.0, "healed in camp")
	arena_clean(r, "after the duel")
	start_wave(r)
	await steps(r, 60)
	check(r.phase == "wave" and r.wave == 4, "wave 4 goes on")
	await free_run(r)


func test_duel_loss() -> void:
	section("camp duel: lost costs nothing")
	var r: Run = await _duel_run("frostweaver", 8)
	r.duel.accept()
	await steps(r, 10)
	r.damage(r.hero, 999999.0, r.rival, "test", "pure")
	check(r.phase == "duel_end" and not r.duel.won, "duel lost")
	check(r.hero.alive and not r.hero.dead and r.lives == 3, "no death, no life lost")
	await steps(r, 120)
	check(r.phase == "prep" and r.wave == 8 and r.hero.alive, "back in camp for wave 8")
	await hero_ok(r, "after a lost duel")
	await free_run(r)


func test_duel_declined() -> void:
	section("camp duel: the wave starts instead")
	var r: Run = await _duel_run("gunsmith", 12)
	check(not r.duel.offer.is_empty(), "challenger before wave 12")
	start_wave(r)
	check(r.duel.offer.is_empty() and r.phase == "wave", "challenger leaves when the wave starts")
	for k in 8:
		kill_all(r)
		await steps(r, 40)
		if r.phase != "wave":
			break
	await steps(r, 120)
	check(r.phase == "prep" and r.wave == 13 and r.duel.offer.is_empty(), "no challenger before wave 13")
	await free_run(r)


func test_ladder() -> void:
	section("Duel Ladder")
	var r := Run.new()
	r.setup("vanguard", 1, Modes.config("duels", "normal"))
	get_tree().root.add_child(r)
	r.weather.pin("clear")
	await get_tree().process_frame
	check(r.duel.ladder() and not r.duel.offer.is_empty(), "first rival waits")
	start_wave(r)
	check(r.phase == "duel" and r.rival != null, "Fight starts the duel")
	check(r.hero.level == Duel.round_level(1), "hero at the round's level", str(r.hero.level))
	await steps(r, 30)
	r.kill(r.rival, r.hero)
	await steps(r, 120)
	check(r.phase == "prep" and r.wave == 2 and r.waves_cleared == 1, "round 2 next", "wave %d %s" % [r.wave, r.phase])
	start_wave(r)
	await steps(r, 10)
	r.damage(r.hero, 999999.0, r.rival, "test", "pure")
	await steps(r, 120)
	check(r.phase == "prep" and r.wave == 2 and r.lives == r.cfg["lives"] - 1, "a lost duel costs a life, same round", "lives %d" % r.lives)
	r.lives = 1
	start_wave(r)
	await steps(r, 10)
	r.damage(r.hero, 999999.0, r.rival, "test", "pure")
	await steps(r, 120)
	check(r.result == "defeat", "out of lives: defeat", r.result)
	await free_run(r)


func test_every_hero_as_ally() -> void:
	for id in DB.HERO_ORDER:
		section("ally %s: fights a boss wave beside the player" % id)
		var r := make_party_run("hivemother" if id != "hivemother" else "ashwarden", 5, {"ally_ids": [id]})
		await get_tree().process_frame
		var c: Hero = r.companions[0]
		start_wave(r)
		await wait_bosses(r, 1)
		await steps(r, 30)
		var n := 0
		for s in 4:
			c.ranks[s] = maxi(c.ranks[s], 1)
			c.cds[s] = 0.0
			c.mana = c.max_mana
			if r.as_unit(c, r.cast_for.bind(c, s)):
				n += 1
		check(n > 0, "casts skills", str(n))
		await steps(r, 150)
		r.kill(c, null)
		await steps(r, 30)
		for k in 6:
			kill_all(r)
			await steps(r, 30)
			if r.phase != "wave":
				break
		await steps(r, 150)
		check(r.phase == "prep" and r.wave == 6 and c.alive and not c.dead, "camp for wave 6 with the ally back", "wave %d %s" % [r.wave, r.phase])
		arena_clean(r, "camp")
		await free_run(r)


func test_every_rival() -> void:
	for id in Duel.POOL:
		section("rival %s: fights the player in a duel" % id)
		var me := "ashwarden" if id != "ashwarden" else "sanguine"
		var r := make_party_run(me, 8, {})
		await get_tree().process_frame
		r.duel.offer = {"hero": id, "level": 10, "gold": 100}
		check(r.duel.accept(), "duel starts")
		var rv := r.rival
		var hp0 := r.hero.hp
		var n := 0
		await steps(r, 20)
		for s in 4:
			rv.cds[s] = 0.0
			rv.mana = rv.max_mana
			if r.as_unit(rv, r.cast_for.bind(rv, s)):
				n += 1
		check(n > 0, "the rival casts skills", str(n))
		await steps(r, 240)
		check(r.hero.hp < hp0 or r.phase != "duel", "the player gets hurt", "%.0f / %.0f" % [r.hero.hp, hp0])
		check(r.enemies.size() <= 1 and r.allies.filter(func(a): return a.team != 0).is_empty(), "the views are restored")
		if r.phase == "duel":
			r.kill(rv, r.hero)
		await steps(r, 120)
		check(r.phase == "prep" and r.rival == null, "back in camp")
		arena_clean(r, "after the duel")
		await free_run(r)
