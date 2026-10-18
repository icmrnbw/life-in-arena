extends Node
## Emberpit logic tests (QA). Run headless:
##   godot --headless --path /home/claude/emberpit res://tests/test_logic.tscn
## Exit code 0 = all pass, 1 = failures. Prints one line per check.

var passed := 0
var failed := 0
var fails: Array = []
var _section := ""


func section(s: String) -> void:
	_section = s
	print("\n== ", s)


func check(cond: bool, what: String, detail := "") -> void:
	if cond:
		passed += 1
		print("  ok   ", what)
	else:
		failed += 1
		var line := "[%s] %s %s" % [_section, what, detail]
		fails.append(line)
		print("  FAIL ", what, "  ", detail)


func near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps


func make_run(hero := "ashwarden", wave := 1) -> Run:
	var r := Run.new()
	r.setup(hero, wave)
	get_tree().root.add_child(r)
	return r


func free_run(r: Run) -> void:
	if is_instance_valid(r):
		r.queue_free()


func _ready() -> void:
	_main.call_deferred()


func _main() -> void:
	await get_tree().process_frame
	Engine.time_scale = 1.0
	test_data()
	test_armor()
	await test_damage()
	await test_ranks()
	await test_cooldowns()
	await test_shop()
	await test_consumables()
	await test_lives()
	await test_waves()
	await test_gold()
	await test_difficulty()
	await test_barrels_buffers()
	print("\n==== RESULT: %d passed, %d failed" % [passed, failed])
	for f in fails:
		print("FAILED: ", f)
	var out := FileAccess.open("/tmp/qa-agent/test_logic_result.txt", FileAccess.WRITE)
	if out:
		out.store_string("passed=%d failed=%d\n%s\n" % [passed, failed, "\n".join(fails)])
	get_tree().quit(0 if failed == 0 else 1)


# ------------------------------------------------------------------ data
func test_data() -> void:
	section("data")
	check(DB.TOTAL_WAVES == 20, "20 waves")
	check(DB.BOSS_WAVES.keys().size() == 4 and DB.BOSS_WAVES.has(5) and DB.BOSS_WAVES.has(10) and DB.BOSS_WAVES.has(15) and DB.BOSS_WAVES.has(20), "bosses at 5/10/15/20")
	check(DB.START_LIVES == 3 and DB.START_GOLD == 300, "3 lives, 300 start gold")
	check(DB.ITEM_ORDER.size() == 18, "18 items", str(DB.ITEM_ORDER.size()))
	var kinds := {"basic": 0, "advanced": 0, "consumable": 0}
	for id in DB.ITEMS:
		kinds[DB.ITEMS[id]["kind"]] += 1
		for f in DB.ITEMS[id].get("from", []):
			check(DB.ITEMS.has(f), "recipe part exists: %s <- %s" % [id, f])
	check(kinds["basic"] == 8 and kinds["advanced"] == 6 and kinds["consumable"] == 4, "8 basic / 6 advanced / 4 consumable", str(kinds))
	# plan costs
	var plan_costs := {"iron_knuckles": 250, "swift_gloves": 250, "hide_vest": 250, "vigor_charm": 300, "focus_pendant": 300,
		"runners_boots": 300, "stout_belt": 400, "sage_circlet": 400, "emberbrand": 400, "bulwark_plate": 450, "wayfarer_treads": 350,
		"hivecore_sigil": 500, "bloodthirst_fang": 450, "wardens_aegis": 900, "healing_draught": 90, "mana_draught": 90,
		"tome_of_might": 500, "phoenix_feather": 1500}
	for id in plan_costs:
		check(int(DB.ITEMS[id]["cost"]) == plan_costs[id], "cost %s = %d" % [id, plan_costs[id]], str(DB.ITEMS[id]["cost"]))
	check(DB.item_total_cost("wardens_aegis") == 900 + 450 + 250 + 300 + 400, "Warden's Aegis full cost 2300", str(DB.item_total_cost("wardens_aegis")))
	for h in DB.HERO_ORDER:
		for s in DB.HEROES[h]["skills"]:
			check(DB.SKILLS.has(s), "skill exists %s" % s)
			var sd: Dictionary = DB.SKILLS[s]
			check(sd["mana"].size() == sd["max"] and sd["cd"].size() == sd["max"], "per-rank arrays sized %s" % s)
		for it in DB.HEROES[h]["build"]:
			check(DB.ITEMS.has(it), "build item exists %s/%s" % [h, it])
	for w in range(1, 21):
		var b := DB.wave_bursts(w)
		var n := 0
		for bb in b:
			n += bb["units"].size()
			check(DB.GATES.has(bb["gate"]), "wave %d gate valid" % w)
		check(n > 0 and n <= 80, "wave %d has 1..80 units (%d)" % [w, n])


func test_armor() -> void:
	section("armor")
	check(near(Run.armor_factor(0.0), 1.0), "armor 0 -> x1.0")
	check(near(Run.armor_factor(5.0), 1.0 - 0.3 / 1.3, 0.001), "armor 5 -> x0.769", str(Run.armor_factor(5.0)))
	check(near(Run.armor_factor(10.0), 1.0 - 0.6 / 1.6, 0.001), "armor 10 -> x0.625")
	check(Run.armor_factor(-3.0) > 1.0, "negative armor amplifies")
	var prev := 2.0
	var mono := true
	for a in range(-10, 60):
		var f := Run.armor_factor(float(a))
		if f > prev + 1e-6:
			mono = false
		prev = f
	check(mono, "armor factor monotonic decreasing")
	check(Run.armor_factor(50.0) > 0.2, "armor 50 still takes >20%")


# ------------------------------------------------------------------ damage
func test_damage() -> void:
	section("damage")
	var r := make_run("ashwarden", 1)
	await get_tree().process_frame
	r.phase = "wave"
	r.hero.in_camp = false
	r.hero.pos = Vector3(0, 0, 0)
	var e := r.spawn_enemy("shieldbearer", Vector3(3, 0, 0), 1)
	var hp0 := e.hp
	var dealt := r.damage(e, 100.0, r.hero, "Test", "phys")
	check(near(dealt, 100.0 * Run.armor_factor(e.armor), 0.01), "phys damage reduced by armor", "%f vs %f" % [dealt, 100.0 * Run.armor_factor(e.armor)])
	check(near(e.hp, hp0 - dealt), "enemy hp reduced")
	var dealt2 := r.damage(e, 50.0, r.hero, "Test", "magic")
	check(near(dealt2, 50.0), "magic damage ignores armor")
	check(near(r.stats["damage_by"].get("Test", 0.0), dealt + dealt2), "damage_by tracks tag")
	# hero damage
	var h := r.hero
	var mhp := h.hp
	var got := r.damage(h, 40.0, e, "Hit", "phys")
	check(near(got, 40.0 * Run.armor_factor(h.armor)), "hero takes armor-reduced damage")
	check(near(h.hp, mhp - got), "hero hp reduced")
	h.shield = 30.0
	var hp1 := h.hp
	r.damage(h, 20.0, e, "Hit", "magic")
	check(near(h.hp, hp1) and near(h.shield, 10.0), "shield absorbs first", "hp %f->%f shield %f" % [hp1, h.hp, h.shield])
	h.shield = 0.0
	# invulnerability
	h.invuln_t = 1.0
	check(r.damage(h, 999.0, e, "Hit", "magic") == 0.0, "invulnerable takes no damage")
	h.invuln_t = 0.0
	# aegis
	h.items.append({"id": "wardens_aegis", "charges": 1, "cd": 0.0})
	h.recalc(true)
	h.aegis_ready = true
	r.damage(h, h.max_hp * 5.0, e, "Hit", "magic")
	check(h.alive and near(h.hp, 1.0) and h.invuln_t > 1.9, "Warden's Aegis: lethal hit leaves 1 HP + 2 s invuln", "hp=%f inv=%f" % [h.hp, h.invuln_t])
	h.invuln_t = 0.0
	r.damage(h, h.max_hp * 5.0, e, "Hit", "magic")
	check(not h.alive or h.dead, "Aegis only once per wave")
	# reflect
	free_run(r)
	await get_tree().process_frame
	r = make_run("ashwarden", 1)
	await get_tree().process_frame
	r.phase = "wave"
	r.hero.in_camp = false
	r.hero.items.append({"id": "bulwark_plate", "charges": 1, "cd": 0.0})
	r.hero.recalc(true)
	var g := r.spawn_enemy("gnawer", Vector3(1, 0, 0), 1)
	var ghp := g.hp
	r.damage(r.hero, 20.0, g, "Gnawer", "phys", {"melee": true})
	check(near(ghp - g.hp, 20.0 * 0.15, 0.01), "Bulwark reflects 15% of melee (pre-mitigation)", "reflected %f" % (ghp - g.hp))
	# lifesteal
	r.hero.items.clear()
	r.hero.items.append({"id": "bloodthirst_fang", "charges": 1, "cd": 0.0})
	r.hero.recalc(true)
	r.hero.hp = 100.0
	var g2 := r.spawn_enemy("shieldbearer", Vector3(2, 0, 0), 1)
	var d2 := r.damage(g2, 100.0, r.hero, "Attack", "phys", {"attack": true})
	check(near(r.hero.hp, 100.0 + d2 * 0.12, 0.5), "lifesteal 12% on attacks", "hp=%f dealt=%f" % [r.hero.hp, d2])
	# god mode
	_g().god = true
	var hpg := r.hero.hp
	r.damage(r.hero, 500.0, g2, "Hit", "magic")
	check(near(r.hero.hp, hpg), "--god: no damage")
	_g().god = false
	free_run(r)
	await get_tree().process_frame


# ------------------------------------------------------------------ ranks / skill points
func test_ranks() -> void:
	section("ranks & skill points")
	for hid in DB.HERO_ORDER:
		var r := make_run(hid, 1)
		await get_tree().process_frame
		var h := r.hero
		check(h.level == 1 and h.skill_points == 1, "%s starts L1 with 1 point" % hid)
		check(not h.can_rank_up(3), "%s R locked at L1" % hid)
		check(h.can_rank_up(0) and h.can_rank_up(1) and h.can_rank_up(2), "%s Q/W/E available at L1" % hid)
		# level to 5: R still locked
		while h.level < 5:
			h.add_xp(DB.xp_to_next(h.level))
		check(not h.can_rank_up(3), "%s R locked at L5" % hid)
		h.add_xp(DB.xp_to_next(h.level))
		check(h.level == 6 and h.can_rank_up(3), "%s R unlocks at L6" % hid)
		check(r.rank_up(3), "%s R rank 1 at L6" % hid)
		check(not h.can_rank_up(3), "%s R rank 2 locked until L11" % hid)
		while h.level < 10:
			h.add_xp(DB.xp_to_next(h.level))
		check(not h.can_rank_up(3), "%s R rank 2 still locked at L10" % hid)
		h.add_xp(DB.xp_to_next(h.level))
		check(h.can_rank_up(3), "%s R rank 2 at L11" % hid)
		r.rank_up(3)
		while h.level < 15:
			h.add_xp(DB.xp_to_next(h.level))
		check(not h.can_rank_up(3), "%s R rank 3 locked at L15" % hid)
		h.add_xp(DB.xp_to_next(h.level))
		check(h.can_rank_up(3), "%s R rank 3 at L16" % hid)
		r.rank_up(3)
		check(h.ranks[3] == 3 and not h.can_rank_up(3), "%s R max rank 3" % hid)
		# spend everything
		var guard := 0
		while h.skill_points > 0 and guard < 50:
			guard += 1
			var any := false
			for s in 3:
				if r.rank_up(s):
					any = true
			if not any:
				break
		check(h.ranks[0] == 4 and h.ranks[1] == 4 and h.ranks[2] == 4, "%s Q/W/E reach rank 4 by L16" % hid, str(h.ranks))
		check(not h.can_rank_up(0), "%s cannot exceed rank 4" % hid)
		while h.level < 20:
			h.add_xp(DB.xp_to_next(h.level))
		check(h.level == 20, "%s caps at L20" % hid)
		check(h.add_xp(99999.0) == false and h.level == 20, "%s no level past 20" % hid)
		var total_spent: int = h.ranks[0] + h.ranks[1] + h.ranks[2] + h.ranks[3]
		check(total_spent == 15 and h.skill_points == 0, "%s 15 ranks spent, leftover points auto-converted" % hid, "spent=%d sp=%d" % [total_spent, h.skill_points])
		check(near(h.bonus["str"], 10.0), "%s 5 extra points -> +10 all stats" % hid, str(h.bonus))
		free_run(r)
		await get_tree().process_frame
	# Q rank level requirements 1/3/5/7
	var r2 := make_run("riftdancer", 1)
	await get_tree().process_frame
	var h2 := r2.hero
	check(r2.rank_up(0), "Q rank1 at L1")
	h2.add_xp(DB.xp_to_next(1))
	check(h2.level == 2 and not h2.can_rank_up(0), "Q rank2 locked at L2")
	h2.add_xp(DB.xp_to_next(2))
	check(h2.can_rank_up(0), "Q rank2 at L3")
	free_run(r2)
	await get_tree().process_frame


# ------------------------------------------------------------------ cooldowns
func test_cooldowns() -> void:
	section("cooldowns & mana")
	var r := make_run("ashwarden", 1)
	await get_tree().process_frame
	var h := r.hero
	r.phase = "wave"
	h.in_camp = false
	h.pos = Vector3(0, 0, 5)
	check(not r.try_cast(0), "unlearned skill cannot cast")
	r.rank_up(0)
	var e := r.spawn_enemy("gnawer", Vector3(0, 0, 0), 1)
	h.mana = h.max_mana
	var m0 := h.mana
	check(r.try_cast(0), "Ember Totem casts")
	check(near(h.mana, m0 - 60.0), "mana deducted 60", str(m0 - h.mana))
	check(near(h.cds[0], 6.0), "cooldown 6 s at rank 1", str(h.cds[0]))
	check(not r.try_cast(0), "cannot recast on cooldown")
	# cdr
	h.items.append({"id": "hivecore_sigil", "charges": 1, "cd": 0.0})
	h.recalc()
	check(near(h.skill_cd(0), 6.0 * 0.85), "Hivecore -15% cooldown", str(h.skill_cd(0)))
	h.cds[0] = 0.0
	h.mana = 10.0
	check(not r.try_cast(0), "not enough mana blocks cast")
	# cooldown ticks
	h.mana = h.max_mana
	h.cds[1] = 3.0
	for i in 30:
		r._tick_hero(0.1)
	check(near(h.cds[1], 0.0, 0.05), "cooldown ticks down in real time", str(h.cds[1]))
	# all 12 skills cast without error on every hero
	free_run(r)
	await get_tree().process_frame
	for hid in DB.HERO_ORDER:
		var rr := make_run(hid, 16)
		await get_tree().process_frame
		rr.phase = "wave"
		rr.hero.in_camp = false
		rr.hero.pos = Vector3(0, 0, 5)
		for k in 6:
			rr.spawn_enemy("gnawer", Vector3(k - 3, 0, 0), 5)
		var hh := rr.hero
		for s in 4:
			while hh.can_rank_up(s):
				rr.rank_up(s)
		for s in 4:
			hh.mana = hh.max_mana
			hh.cds[s] = 0.0
			var sid: String = hh.skill_ids[s]
			for k3 in 4:
				rr.spawn_enemy("shieldbearer", Vector3(k3 * 2 - 3, 0, 1), 5)
			if sid == "raise_dead" or sid == "corpse_blast":
				# graves come from kills
				for en in rr.enemies.slice(0, 3):
					rr.kill(en, hh)
			if sid == "shatter_mark":
				for en in rr.enemies:
					en.mark_t = 5.0
			if sid == "queens_carapace":
				for k2 in 3:
					hh.mana = hh.max_mana
					hh.cds[0] = 0.0
					rr.try_cast(0)
				hh.mana = hh.max_mana
			var ok := rr.try_cast(s)
			check(ok, "%s skill %d (%s) casts at max rank" % [hid, s, hh.skill_ids[s]], "ranks=%s" % str(hh.ranks))
			# a few ticks of simulation after each cast
			for i in 10:
				rr._step(1.0 / 30.0)
		if hid == "twinhide":
			# Shift (cast above) put it in beast form: its Q/W are Rend and Pounce now
			check(hh.skill_ids[0] == "rend" and hh.skill_ids[1] == "pounce" and hh.kit.beast(), "twinhide shift swaps to beast skills", str(hh.skill_ids))
			for s2 in 2:
				hh.mana = hh.max_mana
				hh.cds[s2] = 0.0
				check(rr.try_cast(s2), "twinhide beast skill %s casts" % hh.skill_ids[s2])
				for i in 15:
					rr._step(1.0 / 30.0)
		free_run(rr)
		await get_tree().process_frame


# ------------------------------------------------------------------ shop
func test_shop() -> void:
	section("shop: recipes, pricing, sell, slots, boots")
	var r := make_run("ashwarden", 1)
	await get_tree().process_frame
	var h := r.hero
	r.gold = 100000
	check(r.shop_open_allowed(), "shop open in camp during prep")
	check(r.buy_price("emberbrand") == 900, "Emberbrand from scratch 900", str(r.buy_price("emberbrand")))
	r.buy("iron_knuckles")
	check(r.buy_price("emberbrand") == 650, "Emberbrand with knuckles 650", str(r.buy_price("emberbrand")))
	r.buy("swift_gloves")
	check(r.buy_price("emberbrand") == 400, "Emberbrand with both parts = recipe 400")
	var g0 := r.gold
	r.buy("emberbrand")
	check(g0 - r.gold == 400, "charged 400 for recipe")
	check(h.items.size() == 1 and h.items[0]["id"] == "emberbrand", "parts auto-combined into Emberbrand", str(h.items))
	check(h.burn_on_hit, "Emberbrand gives burn")
	# nested: Warden's Aegis from scratch
	check(r.buy_price("wardens_aegis") == 2300, "Aegis from scratch 2300", str(r.buy_price("wardens_aegis")))
	r.buy("hide_vest")
	check(r.buy_price("wardens_aegis") == 2050, "Aegis with Hide Vest 2050", str(r.buy_price("wardens_aegis")))
	g0 = r.gold
	r.buy("wardens_aegis")
	check(g0 - r.gold == 2050 and h.has_item("wardens_aegis") and not h.has_item("hide_vest") and h.items.size() == 2, "nested recipe consumes parts", str(h.items))
	# sell 50% of total value
	g0 = r.gold
	var idx := -1
	for i in h.items.size():
		if h.items[i]["id"] == "wardens_aegis":
			idx = i
	r.sell(idx)
	check(r.gold - g0 == 1150, "sell Aegis refunds 50% (1150)", str(r.gold - g0))
	g0 = r.gold
	r.sell(0)
	check(r.gold - g0 == 450 and h.items.is_empty(), "sell Emberbrand refunds 450", str(r.gold - g0))
	# slot limit
	for i in 6:
		r.buy("hide_vest")
	check(h.items.size() == 6, "6 items fill the bag")
	check(r.can_buy("iron_knuckles").begins_with("Inventory full"), "7th item blocked", r.can_buy("iron_knuckles"))
	check(r.can_buy("tome_of_might") == "", "tome needs no slot when full")
	# recipe while full: vest + vigor -> bulwark, vigor bought implicitly; result uses 1 slot from 1 owned part -> 6 items
	check(r.can_buy("bulwark_plate") == "", "recipe with an owned part allowed when full", r.can_buy("bulwark_plate"))
	r.buy("bulwark_plate")
	check(h.items.size() == 6 and h.has_item("bulwark_plate"), "bulwark replaces a vest")
	for i in range(h.items.size() - 1, -1, -1):
		r.sell(i)
	# boots rule
	r.buy("runners_boots")
	check(r.can_buy("runners_boots") == "Only one boots item", "second Runner's Boots blocked", r.can_buy("runners_boots"))
	check(r.can_buy("wayfarer_treads") == "", "upgrade Runner's -> Wayfarer allowed")
	r.buy("wayfarer_treads")
	check(h.has_item("wayfarer_treads") and not h.has_item("runners_boots"), "boots upgraded")
	check(r.can_buy("runners_boots") == "Only one boots item", "Runner's blocked while Wayfarer owned")
	check(near(h.base_speed, DB.HEROES["ashwarden"]["speed"] * 1.20), "Wayfarer +20% MS (no stacking)", str(h.base_speed))
	# sprint active
	var wi := 0
	r.phase = "wave"
	h.in_camp = false
	check(r.use_item(wi) and h.sprint_t > 2.9, "Wayfarer active: sprint")
	check(not r.use_item(wi), "sprint on cooldown")
	r.phase = "prep"
	h.in_camp = true
	for i in range(h.items.size() - 1, -1, -1):
		r.sell(i)
	# not in camp
	r.phase = "wave"
	h.in_camp = false
	check(r.can_buy("iron_knuckles") != "", "cannot buy during wave", r.can_buy("iron_knuckles"))
	h.items.append({"id": "iron_knuckles", "charges": 1, "cd": 0.0})
	var gs := r.gold
	r.sell(0)
	check(r.gold == gs and h.items.size() == 1, "cannot sell during wave")
	h.items.clear()
	r.phase = "prep"
	h.in_camp = true
	# gold check
	r.gold = 100
	check(r.can_buy("iron_knuckles") == "Not enough gold", "not enough gold")
	r.gold = 100000
	# sage circlet choice
	r.buy("sage_circlet", "agi")
	var agi0 := h.agi_v
	check(h.items[0].get("choice") == "agi", "Sage Circlet choice stored")
	h.items[0]["choice"] = "int"
	h.recalc()
	check(near(agi0 - h.agi_v, 6.0), "Sage Circlet +6 to the chosen stat")
	h.items.clear()
	h.recalc()
	free_run(r)
	await get_tree().process_frame


# ------------------------------------------------------------------ consumables
func test_consumables() -> void:
	section("consumables / tome / phoenix")
	var r := make_run("hivemother", 1)
	await get_tree().process_frame
	var h := r.hero
	r.gold = 100000
	for i in 5:
		r.buy("healing_draught")
	check(h.items.size() == 1 and h.items[0]["charges"] == 5, "Healing Draught stacks to 5", str(h.items))
	r.buy("healing_draught")
	check(h.items.size() == 2, "6th draught takes a new slot")
	# sell stack refunds 50% per charge
	var g0 := r.gold
	r.sell(1)
	check(r.gold - g0 == 45, "sell 1 draught = 45")
	r.phase = "wave"
	h.in_camp = false
	h.hp = 100.0
	check(r.use_item(0), "use draught")
	check(h.items[0]["charges"] == 4, "charge consumed")
	for i in 90:
		r._tick_hero(0.1)
	var healed := h.hp - 100.0 - h.hp_regen * 9.0
	check(near(healed, 400.0, 6.0), "Healing Draught heals 400 over 8 s", str(healed))
	h.mana = 0.0
	r.phase = "prep"
	h.in_camp = true
	r.buy("mana_draught")
	r.phase = "wave"
	h.in_camp = false
	var mi := -1
	for i in h.items.size():
		if h.items[i]["id"] == "mana_draught":
			mi = i
	h.mana = 0.0
	check(r.use_item(mi), "use mana draught")
	check(h.items.size() == 1, "last charge removes the slot")
	for i in 70:
		r._tick_hero(0.1)
	var restored := h.mana - h.mana_regen * 7.0
	check(near(restored, 250.0, 5.0) or h.mana >= h.max_mana - 1.0, "Mana Draught restores 250", str(restored))
	r.phase = "prep"
	h.in_camp = true
	# tome
	var int0 := h.int_v
	var n0 := h.items.size()
	r.buy("tome_of_might")
	check(near(h.int_v - int0, 2.0) and h.items.size() == n0, "Tome: +2 primary, no slot")
	# phoenix
	var l0 := r.lives
	check(r.buy("phoenix_feather") == "", "buy Phoenix Feather")
	check(r.lives == l0 + 1, "Phoenix +1 life")
	check(r.can_buy("phoenix_feather") == "Only one per run", "second Phoenix blocked", r.can_buy("phoenix_feather"))
	check(h.items.size() == n0, "Phoenix uses no slot")
	free_run(r)
	await get_tree().process_frame


# ------------------------------------------------------------------ lives
func test_lives() -> void:
	section("lives / death / respawn")
	var r := make_run("riftdancer", 3)
	await get_tree().process_frame
	var h := r.hero
	r.skip_prep()
	r._step(0.05)
	check(r.phase == "wave" and not h.in_camp, "skip_prep starts the wave")
	for i in 120:
		r._step(1.0 / 30.0)
	check(r.enemies.size() > 0, "enemies spawned")
	var e: Unit = r.enemies[0]
	r.damage(h, 999999.0, e, "Test", "magic")
	check(h.dead and r.lives == 2 and r.phase == "dead", "death costs a life", "lives=%d phase=%s" % [r.lives, r.phase])
	for i in 120:
		r._step(1.0 / 30.0)
	check(r.phase == "prep" and h.in_camp and h.alive and not h.dead, "respawn in camp at prep", r.phase)
	check(r.wave == 4, "next wave after death", str(r.wave))
	check(r.enemies.is_empty(), "leftover enemies cleared")
	check(near(h.hp, h.max_hp), "respawn at full HP")
	# lose all lives
	for k in 2:
		r.skip_prep()
		r._step(0.05)
		for i in 60:
			r._step(1.0 / 30.0)
		var src: Unit = r.enemies[0] if r.enemies.size() > 0 else null
		r.damage(h, 999999.0, src, "Test", "magic")
		for i in 120:
			r._step(1.0 / 30.0)
			if r.result != "":
				break
	check(r.result == "defeat" and r.lives == 0, "3 deaths -> defeat", "result=%s lives=%d" % [r.result, r.lives])
	free_run(r)
	await get_tree().process_frame
	# phoenix gives an extra death
	var r2 := make_run("ashwarden", 1)
	await get_tree().process_frame
	r2.gold = 5000
	r2.buy("phoenix_feather")
	check(r2.lives == 4, "4 lives with Phoenix")
	free_run(r2)
	await get_tree().process_frame
	# death on the final wave: must re-fight wave 20
	var r3 := make_run("ashwarden", 20)
	await get_tree().process_frame
	r3.skip_prep()
	r3._step(0.05)
	for i in 30:
		r3._step(1.0 / 30.0)
	r3.damage(r3.hero, 999999.0, null, "Test", "magic")
	for i in 120:
		r3._step(1.0 / 30.0)
	check(r3.wave == 20 and r3.phase == "prep", "dying on wave 20 retries wave 20", "wave=%d" % r3.wave)
	free_run(r3)
	await get_tree().process_frame


# ------------------------------------------------------------------ waves & bosses
func test_waves() -> void:
	section("waves & bosses")
	for w in [5, 10, 15, 20]:
		var r := make_run("ashwarden", w)
		await get_tree().process_frame
		_g().god = true
		r.skip_prep()
		r._step(0.05)
		for i in 120:
			r._step(1.0 / 30.0)
		var bosses := []
		for b in r.boss_units:
			bosses.append(b.kind)
		var want: String = DB.BOSS_WAVES[w]
		check(bosses.has(want), "wave %d spawns %s" % [w, want], str(bosses))
		if w == 10:
			check(bosses.size() == 2, "wave 10 has two Matrons", str(bosses))
		check(r.boss_title == DB.BOSS_TITLES[w], "boss title set")
		# kill everything and make sure the wave clears and advances
		for i in 2400:
			for e in r.enemies.duplicate():
				if e.alive:
					r.damage(e, 1e7, r.hero, "Test", "magic")
			r._step(1.0 / 30.0)
			if r.phase != "wave":
				break
		check(r.phase in ["clear", "victory_wait"], "wave %d clears when all dead" % w, r.phase)
		for i in 200:
			r._step(1.0 / 30.0)
			if r.result != "" or r.phase == "prep":
				break
		if w == 20:
			check(r.result == "victory", "clearing wave 20 = victory", r.result)
		else:
			check(r.phase == "prep" and r.wave == w + 1, "wave %d -> camp, next wave %d" % [w, w + 1], "phase=%s wave=%d" % [r.phase, r.wave])
		_g().god = false
		free_run(r)
		await get_tree().process_frame
	for w in [1, 4, 6, 9]:
		var r := make_run("ashwarden", w)
		await get_tree().process_frame
		r.skip_prep()
		r._step(0.05)
		check(r.boss_title == "", "wave %d has no boss" % w)
		free_run(r)
		await get_tree().process_frame


# ------------------------------------------------------------------ gold
func test_gold() -> void:
	section("gold economy")
	var r := make_run("ashwarden", 3)
	await get_tree().process_frame
	_g().god = true
	var g_start := r.gold
	check(g_start == DB.START_GOLD + 430 * 2, "--wave=3 start gold", str(g_start))
	r.skip_prep()
	r._step(0.05)
	var kills_gold := 0
	for i in 900:
		for e in r.enemies.duplicate():
			if e.alive:
				r.damage(e, 1e7, r.hero, "Test", "magic")
		r._step(1.0 / 30.0)
		if r.phase != "wave":
			break
	var earned := r.gold - g_start
	var clear := DB.wave_clear_gold(3)
	var kill_g := earned - clear - int(round((r.wave_gold - clear) * 0.0))
	# flawless = 10% of (kill gold + clear bonus)
	var wave_kill_gold := r.wave_gold - clear
	# wave_gold includes bonus+flawless after add_gold; recompute
	check(r.phase == "clear", "wave 3 cleared")
	check(earned > clear, "kills + clear bonus paid", "earned=%d clear=%d" % [earned, clear])
	var expect_kill := 0.0
	for b in DB.wave_bursts(3):
		for k in b["units"]:
			expect_kill += round(DB.ENEMIES[k]["gold"] * DB.gold_mult(3))
	var expect_total := int(expect_kill) + clear + int(round((expect_kill + clear) * 0.10))
	check(abs(earned - expect_total) <= 2, "flawless wave pays kills + clear + 10%", "earned=%d expected=%d" % [earned, expect_total])
	check(r.stats["gold_earned"] == earned, "gold_earned stat matches")
	_g().god = false
	free_run(r)
	await get_tree().process_frame
	# total income estimate across a run (kills + clear + boss), no flawless
	var total := float(DB.START_GOLD)
	for w in range(1, 21):
		for b in DB.wave_bursts(w):
			for k in b["units"]:
				total += round(DB.ENEMIES[k]["gold"] * DB.gold_mult(w))
		total += DB.wave_clear_gold(w)
		if DB.BOSS_WAVES.has(w):
			total += DB.boss_gold(w)
	print("  info estimated run income (no flawless): %d" % int(total))
	var build_cost := 0
	for id in DB.HEROES["ashwarden"]["build"]:
		build_cost += int(DB.ITEMS[id]["cost"])
	print("  info ashwarden recommended build list cost: %d" % build_cost)
	check(total > 6000, "run income can afford a full build", str(total))


func _g() -> Node:
	return get_node("/root/Game")


# ------------------------------------------------------------------ difficulty mechanics
func test_difficulty() -> void:
	section("difficulty mechanics")
	check(DB.elite_chance(3) == 0.0 and DB.elite_chance(4) > 0.0 and DB.elite_chance(20) <= 0.26, "elites from wave 4, chance capped")
	check(DB.elite_affixes(4) == ["frenzied"] and DB.elite_affixes(8).size() == 3, "affixes unlock by wave", str(DB.elite_affixes(8)))
	check(DB.enrage_time(10) == DB.BOSS_ENRAGE_TIME[10] and DB.enrage_time(7) > 60.0, "enrage timers")
	var r := make_run("ashwarden", 8)
	await get_tree().process_frame
	r.phase = "wave"
	r.hero.in_camp = false
	r.hero.pos = Vector3(0, 0, 0)
	var h := r.hero
	# elite stats
	var g := r.spawn_enemy("gnawer", Vector3(8, 0, 0), 8)
	var hp0 := g.max_hp
	var gold0 := g.gold_val
	g.make_elite("frenzied")
	check(near(g.max_hp, hp0 * DB.ELITE_HP_MULT) and near(g.hp, g.max_hp), "elite hp multiplied")
	check(near(g.gold_val, gold0 * DB.ELITE_REWARD_MULT) and g.display_name.begins_with("Frenzied"), "elite reward + name")
	# warding: nearby allies take less damage, the warder itself does not
	var w := r.spawn_enemy("gnawer", Vector3(-8, 0, 0), 8)
	w.make_elite("warding")
	r.warders.append(w)
	var near_e := r.spawn_enemy("hexcaster", Vector3(-8, 0, 2), 8)
	var far_e := r.spawn_enemy("hexcaster", Vector3(8, 0, 8), 8)
	var d_near := r.damage(near_e, 100.0, h, "Test", "magic")
	var d_far := r.damage(far_e, 100.0, h, "Test", "magic")
	var d_self := r.damage(w, 100.0, h, "Test", "magic")
	check(near(d_near, 100.0 * DB.WARD_DAMAGE_TAKEN) and near(d_far, 100.0) and near(d_self, 100.0), "warding shields neighbours only",
		"%f %f %f" % [d_near, d_far, d_self])
	# hex halves healing
	h.hp = 100.0
	h.hex_t = 2.0
	r.heal_unit(h, 100.0, false)
	check(near(h.hp, 150.0), "hex halves healing", str(h.hp))
	h.hex_t = 0.0
	r.heal_unit(h, 100.0, false)
	check(near(h.hp, 250.0), "healing normal after hex", str(h.hp))
	h.hp = h.max_hp
	# enrage: enemies hit harder
	var base := r.damage(h, 50.0, g, "Hit", "magic")
	h.hp = h.max_hp
	r.pit_enraged = true
	var enr := r.damage(h, 50.0, g, "Hit", "magic")
	check(near(enr, base * DB.ENRAGE_DMG), "enraged enemies deal more damage", "%f vs %f" % [enr, base])
	check(g.speed() > g.base_speed * 1.1, "enraged enemies move faster")
	r.pit_enraged = false
	h.hp = h.max_hp
	# volatile: telegraphed blast after a delay
	var v := r.spawn_enemy("gnawer", Vector3(1, 0, 0), 8)
	v.make_elite("volatile")
	r.damage(v, 1e7, h, "Test", "magic")
	var hp_before := h.hp
	check(r.hazards.size() > 0, "volatile death adds a hazard")
	for i in 20:
		r._step(1.0 / 30.0)
	check(near(h.hp, hp_before, 30.0), "no blast before the delay", "%f -> %f" % [hp_before, h.hp])
	h.pos = Vector3(1, 0, 0)
	for i in 30:
		r._step(1.0 / 30.0)
	check(h.hp < hp_before - 50.0, "volatile blast hits", "%f -> %f" % [hp_before, h.hp])
	free_run(r)
	await get_tree().process_frame
	# shieldbearer bash: every 3rd swing stuns
	var r2 := make_run("ashwarden", 6)
	await get_tree().process_frame
	_g().god = true
	r2.phase = "wave"
	r2.wave_time = 5.0
	r2.hero.in_camp = false
	r2.hero.pos = Vector3(0, 0, 0)
	var sb := r2.spawn_enemy("shieldbearer", Vector3(2.0, 0, 0), 6)
	var stunned := false
	for i in 400:
		r2.hero.pos = Vector3(0, 0, 0)
		r2._step(1.0 / 30.0)
		if r2.hero.stun_t > 0.0:
			stunned = true
			break
	check(stunned and sb.swings >= 3, "shield bash stuns on the 3rd swing", "swings=%d" % sb.swings)
	_g().god = false
	free_run(r2)
	await get_tree().process_frame


# ------------------------------------------------------------------ barrels + buffers
func test_barrels_buffers() -> void:
	section("buffers and barrels")
	var r := make_run("ashwarden", 10)
	await get_tree().process_frame
	r.phase = "wave"
	r.hero.in_camp = false
	r.hero.pos = Vector3(0, 0, 3)
	var h := r.hero
	check(DB.wave_bursts(9).any(func(b): return b["units"].has("chanter")) and not DB.wave_bursts(6).any(func(b): return b["units"].has("drummer")),
		"buffers join from mid waves")
	# chanter: neighbours immune, itself and far ones not
	var ch := r.spawn_enemy("chanter", Vector3(-6, 0, 0), 10)
	var nb := r.spawn_enemy("gnawer", Vector3(-6, 0, 2), 10)
	var far_e := r.spawn_enemy("gnawer", Vector3(6, 0, -3), 10)
	check(near(r.damage(nb, 50.0, h, "Test", "magic"), 0.0), "chanter makes neighbours immune")
	check(near(r.damage(far_e, 50.0, h, "Test", "magic"), 50.0), "far from the chanter takes damage")
	check(r.damage(ch, 50.0, h, "Test", "magic") > 0.0, "chanter itself can be hurt")
	h.pos = Vector3(-6, 0, 1)
	check(r._pick_hero_target() == ch, "auto-attack skips immune foes")
	r.kill(ch, h)
	r._tick_corpses(0.0)
	check(r.damage(nb, 50.0, h, "Test", "magic") > 0.0, "immunity ends when the chanter dies")
	# drummer: neighbours hit twice as hard
	h.pos = Vector3(0, 0, 3)
	var base := r.damage(h, 40.0, far_e, "Hit", "magic")
	h.hp = h.max_hp
	r.spawn_enemy("drummer", Vector3(6, 0, -1), 10)
	var drummed := r.damage(h, 40.0, far_e, "Hit", "magic")
	check(near(drummed, base * DB.DRUM_DMG), "drummer doubles neighbours' damage", "%f vs %f" % [drummed, base])
	h.hp = h.max_hp
	r._clear_arena(false)
	# pens: sealed until a barrel breaks; the hero breaks one in two swings
	var bf := r.barrels
	bf.reset()
	check(bf.gaps(0).is_empty() and bf.intact(0) == DB.PENS[0]["n"], "pens start sealed")
	var b: Barrel = bf.pens[0]["barrels"][0]
	r.damage(b, 10.0, h, "Attack")
	check(b.alive, "barrel survives one hero swing")
	r.damage(b, 10.0, h, "Attack")
	check(not b.alive and bf.gaps(0).size() == 1, "second swing opens a gap")
	var gw: float = bf.gaps(0)[0]["width"]
	var gn := r.spawn_enemy("gnawer", Vector3(-6, 0, 12), 10)
	var sb := r.spawn_enemy("shieldbearer", Vector3(-7, 0, 12), 10)
	check(gw > gn.radius * 2.0 and gw < 2.0 * float(DB.ENEMIES["pit_brute"]["radius"]), "one-barrel gap fits regular foes, not big ones", "gap %.2f" % gw)
	# collision: can't walk through an intact barrel
	var b2: Barrel = bf.pens[0]["barrels"][4]
	var c: Vector3 = bf.pens[0]["c"]
	var outside := c + (b2.pos - c) * 1.5
	gn.pos = outside
	var q := r.resolve_pos(gn, b2.pos, outside)
	check(BarrelField._flat(q - b2.pos).length() >= gn.radius + DB.BARREL_R - 0.01, "barrels block movement")
	# with a gap they path in; a sealed pen gets broken into
	h.pos = c
	check(gn.pick_target() == h, "foes path to the gap when there is one")
	bf.reset()
	check(sb.pick_target() is Barrel, "a sealed pen gets broken into")
	# queue: with the hero inside, only a couple of gnawers reach it at once
	r._clear_arena(false)
	bf.reset()
	r.damage(bf.pens[0]["barrels"][0], 99.0, h, "Attack")
	r.damage(bf.pens[0]["barrels"][0], 99.0, h, "Attack")
	var gdir: Vector3 = bf.gaps(0)[0]["dir"]
	_g().god = true
	h.pos = c - gdir * 0.3
	for i in 7:
		r.spawn_enemy("gnawer", c + gdir * 6.0 + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), 10)
	var max_adj := 0
	var inside_n := 0
	for i in 150:
		h.pos = c - gdir * 0.3
		h.move_input = Vector2.ZERO
		h.atk_cd = 99.0
		r._step(1.0 / 30.0)
		var adj := 0
		for e in r.enemies:
			if e.alive and h.edge_dist(e) < 0.6:
				adj += 1
		max_adj = maxi(max_adj, adj)
		inside_n = 0
		for e in r.enemies:
			if bf.pen_at(e.pos) == 0:
				inside_n += 1
	check(inside_n >= 1, "gnawers get in through the gap", str(inside_n))
	check(max_adj <= 4, "the pen limits how many reach the hero", str(max_adj))
	_g().god = false
	r._clear_arena(false)
	# kegs: blast after the fuse, hurts foes and the hero, breaks barrels nearby
	bf.reset()
	var k: Barrel = bf.kegs[0]
	var foe := r.spawn_enemy("shieldbearer", k.pos + Vector3(1.5, 0, 0), 10)
	h.pos = k.pos + Vector3(-1.5, 0, 0)
	h.hp = h.max_hp
	r.damage(k, 99.0, h, "Attack")
	r.damage(k, 99.0, h, "Attack")
	check(not k.alive and k.lit, "broken keg starts its fuse")
	for i in int(DB.KEG_FUSE * 30.0) + 3:
		h.pos = k.pos + Vector3(-1.5, 0, 0)
		r._step(1.0 / 30.0)
	check(not foe.alive or foe.hp < foe.max_hp * 0.6, "keg blast hurts nearby foes", "%f / %f" % [foe.hp, foe.max_hp])
	check(h.hp < h.max_hp, "keg blast hurts the hero too")
	bf.reset()
	check(k.alive and bf.gaps(0).is_empty(), "barrels restored on reset")
	free_run(r)
	await get_tree().process_frame

