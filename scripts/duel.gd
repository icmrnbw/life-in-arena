class_name Duel
extends RefCounted
## AI duels (roadmap phase 5). In camp before waves 4, 8, 12 and 16 a rival hero challenges the player to a 1v1 in the
## arena: winning pays gold and +2 to every attribute, losing costs nothing (the loser is left standing on 1 HP).
## The Duel Ladder mode is nothing but duels: 8 rivals of rising level, and a lost duel costs a life there.
## The rival is a full hero with its kit and items, played by scripts/bot.gd from its own side (see Run.as_unit()).

const OFFER_WAVES := [4, 8, 12, 16]
const LADDER_ROUNDS := 8
const TIME_LIMIT := 75.0
const WIN_STATS := 2.0
## Damage in a duel is scaled down so heroes built to clear waves don't burst each other down in two seconds.
const DMG_MULT := 0.6
## Rival heroes: kits that only use the shared damage and projectile paths (no summons, walls, traps or gold costs).
const POOL := ["sanguine", "twinhide", "gunsmith", "sunspeaker", "duelist", "vanguard", "skyspear", "frostweaver", "stormcaller", "chronomancer"]
## The rival's gear, as a share of what the player's items cost.
const GEAR := {"normal": 0.7, "hard": 0.95, "extreme": 1.15}
const P_SPOT := Vector3(0, 0, 5)   # clear of the Pit's south pillar at (0, 10)
const R_SPOT := Vector3(0, 0, -5)
const HOLLOW_P_SPOT := Vector3(0, 0, 2)   # Rimefang Hollow has a pillar at (0, 7)

var run: Run
var offer := {}        # {"hero", "level", "gold"} while a challenger waits
var active := false    # the fight is on
var t := 0.0
var end_t := 0.0
var won := false
var taken := {}        # waves whose challenge was answered: fought, or the wave started instead
var record := {"won": 0, "lost": 0}
var _prep_left := 0.0


func setup(r: Run) -> void:
	run = r


func ladder() -> bool:
	return run.mode == "duels"


## Ladder level of round w: 2, 4, 7, 9, 12, 14, 17, 19.
static func round_level(w: int) -> int:
	return clampi(int(2.0 + (w - 1) * 2.5), 1, 20)


## Camp: a challenger arrives on duel waves (--duel=<hero> offers one every wave, for tests).
func on_prep() -> void:
	offer = {}
	if run.mode in ["training", "delve"] or run.result != "":
		return
	var forced: String = Game.arg("duel", "")
	if ladder():
		_roll(forced, round_level(run.wave), 0)
		return
	if taken.has(run.wave) or (forced == "" and not run.wave in OFFER_WAVES):
		return
	_roll(forced, run.hero.level, int(round((80 + 30 * run.wave) * run.gold_scale)))
	run.schedule(2.6, _announce)


## The challenger's toast and the first-time hint, unless the duel (or the wave) already started.
func _announce() -> void:
	if run.phase != "prep" or offer.is_empty():
		return
	run.toast("A challenger waits: %s. Win the duel for %d gold and +%d to all attributes" % [
		DB.HEROES[offer["hero"]]["name"], offer["gold"], int(WIN_STATS)], Art.palette.get("gold", Color.GOLD))
	run.schedule(2.4, func():
		if run.phase == "prep":
			run.hint_once("duel", "Duels are optional. Tap Duel! in camp to fight the challenger 1 on 1. Losing costs nothing."))


func _roll(forced: String, lvl: int, gold: int) -> void:
	var pool: Array = POOL.filter(func(id): return id != run.hero_id)
	var id: String = forced if DB.HEROES.has(forced) and forced != run.hero_id else pool[run.rng.randi() % pool.size()]
	offer = {"hero": id, "level": lvl, "gold": gold}


func can_accept() -> bool:
	return run.phase == "prep" and not offer.is_empty() and not active and run.hero.alive and run.tutorial == null


## The wave starts with the challenge unanswered: the challenger leaves.
func on_wave_start() -> void:
	if not offer.is_empty():
		taken[run.wave] = true
	offer = {}


func accept() -> bool:
	if not can_accept():
		return false
	taken[run.wave] = true
	_prep_left = run.prep_t
	if run.hud and run.hud.has_method("close_shop"):
		run.hud.close_shop()
	run.phase = "duel"
	active = true
	won = false
	t = 0.0
	run.wave_rule = ""
	run.barrels.reset()
	run.arena.reset()
	var h := run.hero
	if ladder():
		while h.level < int(offer["level"]):
			h.add_xp(DB.xp_to_next(h.level))
	h.hp = h.max_hp
	h.mana = h.max_mana
	run._teleport_hero(HOLLOW_P_SPOT if Maps.cur == "hollow" else P_SPOT)
	h.in_camp = false
	if h.kit:
		h.kit.on_wave_start()
	_spawn_rival()
	Game.crumb("duel start vs " + String(offer["hero"]))
	run.banner_requested.emit("Duel!", "%s, level %d" % [DB.HEROES[offer["hero"]]["name"], run.rival.level])
	Audio.play("boss")
	return true


func _spawn_rival() -> void:
	var r := run.make_hero(String(offer["hero"]), 1)
	r.ai = true
	run.rival = r
	var b: Node = load("res://scripts/bot.gd").new()
	run.add_child(b)
	b.setup(run, r, "rival")
	run.brains[r] = b
	var lvl := int(offer["level"])
	run.as_unit(r, func():
		while r.level < lvl:
			r.add_xp(DB.xp_to_next(r.level))
		b.rank_all())
	var worth := 0
	for it in run.hero.items:
		if DB.ITEMS[it["id"]].get("kind") != "consumable":
			worth += DB.item_total_cost(it["id"])
	if ladder():
		worth = maxi(worth, 350 * (run.wave - 1))
	r.purse = int(worth * float(GEAR.get(run.tier, 0.95)))
	run.kit_out(r)
	r.recalc(true)
	r.in_camp = false
	r.pos = R_SPOT
	r.face(Vector3(0, 0, 1))
	r.sync_visual()
	r.set_state("spawn", true)
	run.fx("teleport", {"pos": r.pos})
	run.enemies.append(r)
	run.boss_units.append(r)


func tick(dt: float) -> void:
	if run.phase == "duel":
		t += dt
		if t >= TIME_LIMIT:
			# time's up: whoever has more of their health left wins
			var r := run.rival
			finish(r == null or run.hero.hp / maxf(1.0, run.hero.max_hp) >= r.hp / maxf(1.0, r.max_hp))
	elif run.phase == "duel_end":
		end_t -= dt
		if end_t <= 0.0:
			_back_to_camp()


func finish(player_won: bool) -> void:
	if not active:
		return
	active = false
	won = player_won
	run.phase = "duel_end"
	end_t = 2.6
	var h := run.hero
	var r := run.rival
	h.invuln_t = maxf(h.invuln_t, end_t + 0.5)
	for p in run.projs:
		run._release_proj(p)
	run.projs.clear()
	if r != null:
		r.invuln_t = end_t + 0.5
		if player_won:
			r.alive = false
			r.set_state("death", true)
		else:
			r.move_input = Vector2.ZERO
	Game.crumb("duel %s" % ("won" if player_won else "lost"))
	if player_won:
		record["won"] = int(record["won"]) + 1
		if ladder():
			var g := int(round((250 + 75 * run.wave) * run.gold_scale))
			run.add_gold(g)
			run.banner_requested.emit("Duel won!", "+%d gold" % g if run.wave < LADDER_ROUNDS else "The ladder is yours")
		else:
			run.add_gold(int(offer.get("gold", 0)))
			for k in h.bonus:
				h.bonus[k] += WIN_STATS
			h.recalc()
			run.fx("level_up", {"pos": h.pos})
			run.banner_requested.emit("Duel won!", "+%d gold, +%d to all attributes" % [int(offer.get("gold", 0)), int(WIN_STATS)])
		Audio.play("victory")
	else:
		record["lost"] = int(record["lost"]) + 1
		if ladder():
			run.stats["deaths"] += 1
			if run.mode != "practice":
				run.lives -= 1
			run.banner_requested.emit("Defeated", "%d %s left" % [maxi(0, run.lives), "life" if run.lives == 1 else "lives"] if run.lives > 0 else "No lives remain")
		else:
			run.banner_requested.emit("Duel lost", "No harm done. The wave still waits")
		Audio.play("defeat")


func _back_to_camp() -> void:
	var r := run.rival
	if r != null:
		run.enemies.erase(r)
		run.boss_units.erase(r)
		var b: Node = run.brains.get(r)
		if b != null:
			b.queue_free()
		run.brains.erase(r)
		if r.node and is_instance_valid(r.node):
			r.node.queue_free()
		r.node = null
		r.alive = false
		r.removed = true
	run.rival = null
	run._clear_arena(false)
	var h := run.hero
	if h.kit:
		h.kit.on_wave_end()
	if ladder():
		if not won and run.lives <= 0:
			run._end_run("defeat")
			return
		if won:
			run.waves_cleared += 1
			run.max_wave_reached = maxi(run.max_wave_reached, run.wave)
			if run.wave >= LADDER_ROUNDS:
				run._end_run("victory")
				return
			run.wave += 1
	h.alive = true
	h.dead = false
	h.hp = h.max_hp
	h.mana = h.max_mana
	run._teleport_hero(DB.CAMP_SPAWN)
	h.in_camp = true
	run.phase = "prep"
	run.prep_t = maxf(_prep_left, 15.0) if not ladder() else DB.PREP_TIME
	run.weather.roll_for(run.wave)
	on_prep()
	Game.on_prep()
	run._save_progress()


func snapshot() -> Dictionary:
	return {"taken": taken.keys(), "record": record.duplicate()}


func restore(s: Dictionary) -> void:
	taken = {}
	for w in s.get("taken", []):
		taken[int(w)] = true
	var rc: Dictionary = s.get("record", {})
	record = {"won": int(rc.get("won", 0)), "lost": int(rc.get("lost", 0))}
