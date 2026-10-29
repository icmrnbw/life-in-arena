class_name Run
extends Node3D
## One play-through: world, units, phases (prep / wave), economy, combat resolution.

signal run_ended(result: String)
signal toast_requested(text: String, color: Color)
signal banner_requested(text: String, sub: String)
signal skill_cast(slot: int)

const MAX_ENEMIES := 80
const SUBSTEP := 1.0 / 30.0

var hero_id := "ashwarden"
var hero: Hero
var enemies: Array = []
var allies: Array = []
var companions: Array = []   # AI ally heroes (team 0); listed in `allies` too while they stand in the arena
var brains := {}             # AI hero -> its bot (scripts/bot.gd) for companions and the duel rival
var rival: Hero = null       # duel opponent (team 1); listed in `enemies` while the duel is on
var duel: Duel
var _pov_rival := false      # the rival's view is swapped in (see as_unit)
var _real: Array = []        # [enemies, allies, boss_units] while the rival's view is swapped in
var _quiet := 0              # > 0 while an AI hero acts: its kit's toasts / hints / shakes stay silent
var corpses: Array = []
var projs: Array = []
var proj_pool := {}
var walls: Array = []      # {a, b, t, dps, src, tag, fx, tick}
var pools: Array = []      # {pos, r, dps, t, fx, tick}
var hazards: Array = []    # {type, pos, r, from, to, width, t}
var timers: Array = []     # [time_left, Callable]
var spawn_queue: Array = []
var boss_units: Array = []
var boss_title := ""
var wave_rule := ""        # this wave's twist (DB.WAVE_RULES), "" = none
var captain: Enemy = null  # the wave's captain while it lives
var gauntlet_i := 0        # next DB.GAUNTLET step on the final wave
var echoes: Array = []     # gauntlet echo bosses alive
var pit_enraged := false
var warders: Array = []    # alive Warding elites
var chanters: Array = []   # alive Ward Chanters (foes near them take no damage)
var drummers: Array = []   # alive War Drummers (foes near them deal double damage)
var barrels: BarrelField
var weather: Weather
var arena: Arena
var delve: Delve           # Delve mode's dungeon (null in the arena modes)
var wave_step := 1         # Delve: 2 (a depth is fought at wave = 2 * depth)
var immune_shown_t := -10.0
var hints_shown := {}
## Mode and tier settings (Modes.config); the hot multipliers are copied into plain vars below.
var cfg := {}
var mode := "classic"
var tier := "hard"
var hp_scale := 1.0
var dmg_scale := 1.0
var gold_scale := 1.0
var xp_scale := 1.0
var hero_dmg_mult := 1.0
var hero_taken_mult := 1.0
var enemy_speed_mult := 1.0
var hero_speed_mult := 1.0
var waves_cleared := 0
var end_info := {}         # Profile.on_run_ended(): score, new best, unlocks (for the end screen)
var tutorial: Node = null  # Training: the coach that drives this run

var phase := "prep"
var wave := 1
var prep_t := DB.FIRST_PREP_TIME
var wave_time := 0.0
var phase_t := 0.0
var lives := DB.START_LIVES
var gold := DB.START_GOLD
var run_time := 0.0
var wave_died := false
var wave_gold := 0
var max_wave_reached := 0
var feathers := 0
var stats := {"kills": 0, "gold_earned": 0, "deaths": 0, "damage_by": {}, "damage_taken": 0.0, "bosses": 0, "shield_blocks": 0, "shield_hits": 0}
var result := ""

var world: Node3D
var units_root: Node3D
var fx_root: Node3D
var camera: Camera3D
var cam_focus := Vector3.ZERO
var cam_zoom := 1.0
var shake_amt := 0.0
var hud: Node
var bot: Node
var soak: Node     # --soak: crash soak monitor (scripts/soak.gd)
var shop_node: Node3D
var fountain_node: Node3D
var _num_budget := 0.0
var sim_us_sum := 0.0
var sim_frames := 0
var sim_us_max_busy := 0.0
var sim_us_busy_sum := 0.0
var sim_busy_frames := 0
var _fountain_fx_t := 0.0
var _grid := {}
var _tgrid := {}
var _tgrid_step := -1
var _step_n := 0
var _cluster_cache := {}
var rng := RandomNumberGenerator.new()


func setup(id: String, start_wave := 1, run_cfg := {}) -> void:
	hero_id = id if DB.HEROES.has(id) else "ashwarden"
	wave = clampi(start_wave, 1, DB.TOTAL_WAVES)
	name = "Run"
	cfg = run_cfg if not run_cfg.is_empty() else Modes.config("classic", "hard")
	mode = cfg.get("mode", "classic")
	tier = cfg.get("tier", "hard")
	hp_scale = float(cfg.get("hp", 1.0))
	dmg_scale = float(cfg.get("dmg", 1.0))
	gold_scale = float(cfg.get("gold", 1.0))
	xp_scale = float(cfg.get("xp", 1.0))
	hero_dmg_mult = float(cfg.get("hero_dmg", 1.0))
	hero_taken_mult = float(cfg.get("hero_taken", 1.0))
	enemy_speed_mult = float(cfg.get("enemy_speed", 1.0))
	hero_speed_mult = float(cfg.get("hero_speed", 1.0))
	lives = int(cfg.get("lives", DB.START_LIVES))
	gold = DB.START_GOLD + int(cfg.get("bonus_gold", 0))
	Maps.use(String(cfg.get("map", "pit")))
	if mode == "delve":
		Maps.use("delve")
		wave_step = 2
		wave = clampi(wave + wave % 2, 2, DB.TOTAL_WAVES)


func _ready() -> void:
	rng.randomize()
	if int(cfg.get("seed", 0)) != 0:
		# Daily Run: the same seed for everyone on that day
		rng.seed = int(cfg["seed"])
		seed(int(cfg["seed"]))
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var env_parent := Node.new()
	env_parent.name = "Env"
	add_child(env_parent)
	if Art.has_method("setup_environment"):
		Art.setup_environment(env_parent, Maps.theme())
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var res = Art.build_world(world) if Art.has_method("build_world") else {}
	if res is Dictionary:
		if res.get("shop") is Node3D:
			shop_node = res["shop"]
		if res.get("fountain") is Node3D:
			fountain_node = res["fountain"]
	barrels = BarrelField.new()
	world.add_child(barrels)
	barrels.setup(self)
	arena = Arena.new()
	arena.setup(self, res if res is Dictionary else {})
	if mode == "delve":
		delve = Delve.new()
		world.add_child(delve)
		delve.setup(self)
	units_root = Node3D.new()
	units_root.name = "Units"
	add_child(units_root)
	fx_root = Node3D.new()
	fx_root.name = "Fx"
	add_child(fx_root)
	if Art.has_method("set_fx_root"):
		Art.set_fx_root(fx_root)
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.far = 300.0
	add_child(camera)
	camera.current = true

	hero = make_hero(hero_id, 0)
	hero.pos = DB.CAMP_SPAWN
	hero.sync_visual()
	cam_focus = hero.pos
	weather = Weather.new()
	weather.setup(self)
	duel = Duel.new()
	duel.setup(self)
	if delve:
		weather.pin("clear")   # underground

	if wave > wave_step:
		_apply_start_wave(wave)
	if mode == "practice":
		gold = Modes.PRACTICE_GOLD
	if cfg.has("resume"):
		_restore(cfg["resume"])
	_add_companions(cfg["resume"].get("companions", []) if cfg.has("resume") else [])
	weather.roll_for(wave)

	var hud_script = load("res://scripts/ui/hud.gd")
	hud = hud_script.new()
	add_child(hud)
	hud.setup(self)

	if Game.autoplay:
		var bot_script = load("res://scripts/bot.gd")
		bot = bot_script.new()
		add_child(bot)
		bot.setup(self)
	if Game.args.has("soak"):
		soak = load("res://scripts/soak.gd").new()
		add_child(soak)
		soak.setup(self)

	phase = "prep"
	prep_t = DB.FIRST_PREP_TIME if wave == wave_step else DB.PREP_TIME
	hero.in_camp = true
	duel.on_prep()
	Game.on_run_started(self)
	Profile.on_run_started(self)
	if mode == "training":
		tutorial = load("res://scripts/tutorial.gd").new()
		add_child(tutorial)
		tutorial.setup(self)
	elif cfg.has("resume"):
		banner_requested.emit("Welcome back", "Wave %d begins soon. Your run was saved in camp." % wave)
	else:
		banner_requested.emit("Prepare", ("Depth %d awaits. Visit the shop and fountain." % Delve.depth_of(wave)) if delve else ("Wave %d begins soon. Visit the shop and fountain." % wave))
	_sync_state()


## Boss kind on wave w ("" = regular wave), including Endless boss waves past 20 and Delve's boss depths.
func boss_kind(w := -1) -> String:
	if mode == "delve":
		return Delve.boss_kind(wave if w < 0 else w)
	return Modes.boss_kind(wave if w < 0 else w)


func wave_info(w := -1) -> Dictionary:
	if mode == "delve":
		return Delve.info(wave if w < 0 else w)
	return Modes.wave_info(wave if w < 0 else w)


func score() -> int:
	return Modes.score(waves_cleared, int(stats["kills"]), int(stats["bosses"]), int(stats["deaths"]), tier)


## Everything needed to carry on from camp after the app is closed (saved at the start of every prep phase).
func snapshot() -> Dictionary:
	var c := cfg.duplicate(true)
	c.erase("resume")
	var its := []
	for it in hero.items:
		var e: Dictionary = it.duplicate()
		e["cd"] = 0.0
		its.append(e)
	return {"version": Profile.VERSION, "hero": hero_id, "wave": wave, "gold": gold, "lives": lives, "level": hero.level,
		"xp": hero.xp, "skill_points": hero.skill_points, "ranks": hero.ranks.duplicate(), "bonus": hero.bonus.duplicate(),
		"train": hero.train.duplicate(),
		"items": its, "stats": stats.duplicate(true), "max_wave": max_wave_reached, "waves_cleared": waves_cleared,
		"run_time": run_time, "feathers": feathers, "cfg": c, "saved_at": int(Time.get_unix_time_from_system()),
		"kills_saved": int(get_meta("kills_saved", 0)), "companions": companions.map(_hero_state), "duel": duel.snapshot()}


## An AI ally's level, skills and items for a saved run.
func _hero_state(h: Hero) -> Dictionary:
	return {"id": h.hero_id, "level": h.level, "xp": h.xp, "skill_points": h.skill_points, "ranks": h.ranks.duplicate(),
		"bonus": h.bonus.duplicate(), "items": h.items.map(func(it): return {"id": it["id"], "charges": it.get("charges", 1), "choice": it.get("choice", "")}),
		"purse": h.purse}


func _restore(s: Dictionary) -> void:
	wave = clampi(int(s.get("wave", 1)), 1, 999)
	gold = int(s.get("gold", gold))
	lives = int(s.get("lives", lives))
	duel.restore(s.get("duel", {}))
	_restore_hero(hero, s)
	var st: Dictionary = s.get("stats", {})
	for k in stats:
		if st.has(k):
			stats[k] = st[k] if k == "damage_by" else (float(st[k]) if k == "damage_taken" else int(st[k]))
	max_wave_reached = int(s.get("max_wave", 0))
	waves_cleared = int(s.get("waves_cleared", 0))
	run_time = float(s.get("run_time", 0.0))
	feathers = int(s.get("feathers", 0))
	set_meta("kills_saved", int(s.get("kills_saved", 0)))
	set_meta("deaths_saved", int(stats["deaths"]))


## Level, attributes, Training ranks, items and skill ranks of `h` from a saved state.
func _restore_hero(h: Hero, s: Dictionary) -> void:
	h.level = clampi(int(s.get("level", 1)), 1, 20)
	h.xp = float(s.get("xp", 0.0))
	h.skill_points = int(s.get("skill_points", 0))
	var b: Dictionary = s.get("bonus", {})
	for k in h.bonus:
		h.bonus[k] = float(b.get(k, 0.0))
	h.train.clear()
	var tr: Dictionary = s.get("train", {})
	for id in tr:
		if DB.UPGRADES.has(String(id)):
			h.train[String(id)] = clampi(int(tr[id]), 0, int(DB.UPGRADES[String(id)].get("max", 999)))
	h.items.clear()
	for it in s.get("items", []):
		if it is Dictionary and DB.ITEMS.has(String(it.get("id", ""))):
			var e: Dictionary = it.duplicate()
			e["charges"] = int(e.get("charges", 1))
			e["cd"] = 0.0
			h.items.append(e)
	h.recalc(true)
	var rk: Array = s.get("ranks", [0, 0, 0, 0])
	for slot in 4:
		var want := clampi(int(rk[slot]) if slot < rk.size() else 0, 0, h.max_rank(slot))
		while h.ranks[slot] < want:
			h.ranks[slot] += 1
			if h.kit:
				h.kit.on_rank_up(slot)


func _apply_start_wave(w: int) -> void:
	var lvl := clampi(int(round(1.0 + (w - 1) * 0.95)), 1, 20)
	while hero.level < lvl:
		hero.add_xp(DB.xp_to_next(hero.level))
	gold = DB.START_GOLD + int(cfg.get("bonus_gold", 0)) + 430 * (w - 1)
	hero.recalc(true)


func make_visual(kind: String) -> Node3D:
	var v = null
	if Art.has_method("create_unit"):
		v = Art.create_unit(kind)
	if not (v is Node3D):
		var mi := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.5
		cap.height = 1.8
		mi.mesh = cap
		mi.position.y = 0.9
		var holder := Node3D.new()
		holder.add_child(mi)
		v = holder
	Skins.apply_equipped(v, kind)
	if kind == "gnawer" and v is Node3D:
		v.scale *= 1.15   # read better on phones
	units_root.add_child(v)
	return v


# ---------------------------------------------------------------- fx helpers
func fx(fx_name: String, opts: Dictionary) -> Node:
	if not Art.has_method("fx"):
		return null
	Game.note_fx(fx_name)
	var n = Art.fx(fx_name, opts)
	if n is Node and is_instance_valid(n):
		return n
	return null


func fx_stop(n) -> void:
	if n != null and is_instance_valid(n) and n is Node:
		if n.has_method("stop"):
			n.call("stop")
		elif n.is_inside_tree():
			n.queue_free()


func fx_timed(fx_name: String, opts: Dictionary, dur: float) -> Node:
	var n := fx(fx_name, opts)
	if n != null:
		schedule(dur + 0.05, fx_stop.bind(n))
	return n


func fx_params(n, opts: Dictionary) -> void:
	if n != null and is_instance_valid(n) and n.has_method("set_params"):
		n.call("set_params", opts)


func schedule(delay: float, c: Callable) -> void:
	timers.append([delay, c])


func damage_number(p: Vector3, amount: float, crit := false, color := Color(1, 1, 1)) -> void:
	if _num_budget <= 0.0:
		return
	_num_budget -= 1.0
	fx("damage_number", {"pos": p + Vector3(0, 2.0, 0), "amount": int(round(amount)), "crit": crit, "color": color})


func shake(amount: float) -> void:
	if _quiet > 0:
		return
	if Game.settings.get("shake", true):
		shake_amt = maxf(shake_amt, amount)


func toast(text: String, color := Color(1, 1, 1)) -> void:
	if _quiet > 0:
		return
	toast_requested.emit(text, color)


## Shows a gold hint toast once per run.
func hint_once(id: String, text: String) -> void:
	if hints_shown.has(id) or _quiet > 0:
		return
	hints_shown[id] = true
	toast(text, Art.palette.get("gold", Color.GOLD))


func add_hazard(h: Dictionary) -> Dictionary:
	hazards.append(h)
	return h


# ---------------------------------------------------------------- queries
func in_arena() -> bool:
	return phase == "wave" or phase == "clear"


func enemies_in_radius(p: Vector3, r: float, include_hidden := false) -> Array:
	var out := []
	for e in enemies:
		if not e.alive or (e.untargetable and not include_hidden):
			continue
		var dx: float = e.pos.x - p.x
		var dz: float = e.pos.z - p.z
		var rr: float = r + e.radius
		if dx * dx + dz * dz <= rr * rr:
			out.append(e)
	return out


func nearest_enemy(p: Vector3, max_r: float) -> Unit:
	var best: Unit = null
	var bd := max_r * max_r
	for e in enemies:
		if not e.alive or e.untargetable or e.dormant:
			continue
		var dx: float = e.pos.x - p.x
		var dz: float = e.pos.z - p.z
		var d := dx * dx + dz * dz
		if d < bd:
			bd = d
			best = e
	return best


func count_enemies(p: Vector3, r: float) -> int:
	return enemies_in_radius(p, r).size()


## Best point (an enemy position) within max_range of `from` that has the most enemies within `radius`.
## Targetable enemies bucketed in 2 m cells; rebuilt at most once per sim step.
func _target_grid() -> Dictionary:
	if _tgrid_step == _step_n:
		return _tgrid
	_tgrid_step = _step_n
	_tgrid.clear()
	_cluster_cache.clear()
	for e in enemies:
		if not e.alive or e.untargetable:
			continue
		var key := Vector2i(floori(e.pos.x / 2.0), floori(e.pos.z / 2.0))
		if _tgrid.has(key):
			_tgrid[key].append(e)
		else:
			_tgrid[key] = [e]
	return _tgrid


## Densest pack of enemies within max_range of `from` (cluster radius `radius`). Grid-based, cached per step.
func best_cluster(from: Vector3, max_range: float, radius: float) -> Dictionary:
	var g := _target_grid()
	var ck := "%d|%d|%.1f|%.1f" % [roundi(from.x * 2.0), roundi(from.z * 2.0), max_range, radius]
	if _cluster_cache.has(ck):
		var cached: Dictionary = _cluster_cache[ck]
		if cached.is_empty() or (cached["unit"] as Unit).alive:
			return cached
	var best := {}
	var best_score := 0.0
	var reach := int(ceil(radius / 2.0))
	var r2 := radius * radius
	var mr2 := max_range * max_range
	for e in enemies:
		if not e.alive or e.untargetable:
			continue
		var fx_: float = e.pos.x - from.x
		var fz_: float = e.pos.z - from.z
		var d2f := fx_ * fx_ + fz_ * fz_
		if d2f > mr2:
			continue
		var score := 0.0
		var centroid := Vector3.ZERO
		var n := 0
		var kx := floori(e.pos.x / 2.0)
		var kz := floori(e.pos.z / 2.0)
		for ox in range(-reach, reach + 1):
			for oz in range(-reach, reach + 1):
				var k2 := Vector2i(kx + ox, kz + oz)
				if not g.has(k2):
					continue
				for o in g[k2]:
					var dx: float = o.pos.x - e.pos.x
					var dz: float = o.pos.z - e.pos.z
					if dx * dx + dz * dz <= r2:
						score += 3.0 if o.is_boss else 1.0
						centroid += o.pos
						n += 1
		score -= sqrt(d2f) * 0.02
		if score > best_score and n > 0:
			best_score = score
			best = {"pos": centroid / n, "count": n, "unit": e}
	_cluster_cache[ck] = best
	return best


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func hero_side_targets() -> Array:
	var out := []
	if hero.alive and not hero.dead and not hero.in_camp:
		out.append(hero)
	for a in allies:
		if a.alive and a.targetable:
			out.append(a)
	return out


# ---------------------------------------------------------------- AI heroes (allies and duel rivals)
## A hero with its kit and model. team 0 = the player's side, 1 = a duel rival.
func make_hero(id: String, team := 0) -> Hero:
	var h := Hero.new()
	h.run = self
	h.init_hero(id)
	h.team = team
	h.setup_visual(make_visual(id))
	h.radius = clampf(h.radius, 0.35, 0.8)
	h.kit = load("res://scripts/kits/%s_kit.gd" % id).new()
	h.kit.setup(h, self)
	return h


## Runs `c` as the AI hero `u` acts: its kit's toasts stay quiet, and for the duel rival the world is seen from its
## side (`enemies` = the player and the player's summons), so every kit's targeting works unchanged against the player.
func as_unit(u: Unit, c: Callable) -> Variant:
	var r: Variant = null
	var want_rival := rival != null and u == rival
	if u != hero:
		_quiet += 1
	if want_rival == _pov_rival:
		r = c.call()
	elif want_rival:
		_real = [enemies, allies, boss_units]
		enemies = _rival_view()
		allies = []
		# the duel opponent counts as the boss: kits and the bot save their single-target play for bosses
		boss_units = enemies.filter(func(u): return u == hero)
		_pov_rival = true
		_tgrid_step = -1
		r = c.call()
		enemies = _real[0]
		allies = _real[1]
		boss_units = _real[2]
		_real = []
		_pov_rival = false
		_tgrid_step = -1
	else:
		var view := [enemies, allies, boss_units]
		enemies = _real[0]
		allies = _real[1]
		boss_units = _real[2]
		_pov_rival = false
		_tgrid_step = -1
		r = c.call()
		_real = [enemies, allies, boss_units]
		enemies = view[0]
		allies = view[1]
		boss_units = view[2]
		_pov_rival = true
		_tgrid_step = -1
	if u != hero:
		_quiet -= 1
	return r


## What the duel rival fights: the player and the player's summons in the arena.
func _rival_view() -> Array:
	var out := []
	if hero.alive and not hero.dead and not hero.in_camp:
		out.append(hero)
	for a in _real[1]:
		if a.alive and a.targetable and not (a is Hero) and a.pos.z < 30.0:
			out.append(a)
	return out


## Heroes that fight alongside the player: cfg "allies" (how many, picked to complement the player's damage type)
## or cfg "ally_ids" (exactly these).
## `saved`: their state from a saved run (snapshot()), in the same order.
func _add_companions(saved: Array) -> void:
	var ids: Array = cfg.get("ally_ids", [])
	if ids.is_empty() and int(cfg.get("allies", 0)) > 0:
		ids = pick_companions(hero_id, int(cfg["allies"]), rng)
	for id in ids:
		if not DB.HEROES.has(String(id)) or companions.size() >= 3:
			continue
		var c := make_hero(String(id), 0)
		c.ai = true
		var b: Node = load("res://scripts/bot.gd").new()
		add_child(b)
		b.setup(self, c, "ally")
		brains[c] = b
		var sv: Dictionary = saved[companions.size()] if companions.size() < saved.size() and saved[companions.size()] is Dictionary else {}
		companions.append(c)
		if sv.get("id", "") == c.hero_id:
			_restore_hero(c, sv)
			c.purse = int(sv.get("purse", 0))
			continue
		c.purse = gold if mode != "practice" else Modes.PRACTICE_GOLD
		while c.level < hero.level:
			c.add_xp(DB.xp_to_next(c.level))
		c.recalc(true)
		b.rank_all()
		kit_out(c)
	cfg["ally_ids"] = companions.map(func(c): return c.hero_id)
	_place_companions(DB.CAMP_SPAWN, true)


## n ally heroes for `player`: the first deals the other damage type (so resistant foes still melt), the rest vary.
## The Alchemist is left out: its bombs would burn the player's gold.
static func pick_companions(player: String, n: int, r: RandomNumberGenerator) -> Array:
	var pool: Array = DB.HERO_ORDER.filter(func(id): return id != player and id != "alchemist")
	var mine: String = DB.HEROES[player].get("dmg_type", "mixed")
	var out := []
	for i in n:
		if pool.is_empty():
			break
		var want := ""
		if i == 0 and mine != "mixed":
			want = "magic" if mine == "phys" else "phys"
		elif i == 1:
			want = mine
		var cands: Array = pool.filter(func(id): return want == "" or DB.HEROES[id].get("dmg_type", "mixed") == want)
		if cands.is_empty():
			cands = pool
		var pick: String = cands[r.randi() % cands.size()]
		out.append(pick)
		pool.erase(pick)
	return out


## Companions take their spots beside the player (in camp or at the arena entrance); downed ones get back up.
func _place_companions(at: Vector3, camp: bool) -> void:
	var offs := [Vector3(-2.4, 0, 1.2), Vector3(2.4, 0, 1.2), Vector3(0, 0, 2.6)]
	for i in companions.size():
		var c: Hero = companions[i]
		if c.dead or not c.alive:
			c.alive = true
			c.dead = false
			c.hp = c.max_hp
			c.mana = c.max_mana
			c.set_state("spawn", true)
		if camp:
			c.hp = maxf(c.hp, c.max_hp * 0.5)
		c.shield = 0.0
		c.slow_t = 0.0
		c.stun_t = 0.0
		c.burn_t = 0.0
		_teleport_unit(c, at + offs[i % offs.size()])
		c.in_camp = camp
		c.targetable = not camp
		if not allies.has(c):
			allies.append(c)


## An ally hero fell: out until the wave ends (no lives are lost).
func _companion_down(c: Hero) -> void:
	c.dead = true
	c.set_state("death", true)
	c.focus = null
	allies.erase(c)
	as_unit(c, func(): c.kit.on_wave_end())
	toast("%s has fallen. Back next wave" % c.data["name"], Art.palette.get("danger", Color.RED))


## AI heroes "shop" from their build list with their own purse (the gold the team earns; it isn't taken from the player).
func kit_out(h: Hero) -> void:
	var guard := 0
	while guard < 24:
		guard += 1
		var needs := build_needs(h)
		var bought := false
		for id in needs:
			var owned: Array = h.items.map(func(it): return it["id"])
			var price := _price_with(id, owned)
			var used := _consume_components(id, [], h)
			if h.items.size() - used.size() + 1 > 6 or DB.ITEMS[id].get("kind") == "consumable":
				continue
			if DB.ITEMS[id].get("boots", false) and h.has_boots() and not (id == "wayfarer_treads" and h.has_item("runners_boots")):
				continue
			if price > h.purse:
				break
			h.purse -= price
			used.sort()
			used.reverse()
			for i in used:
				h.items.remove_at(i)
			var entry := {"id": id, "charges": 1, "cd": 0.0}
			if id == "sage_circlet":
				entry["choice"] = "agi" if h.data["primary"] == "agi" else "int"
			h.items.append(entry)
			bought = true
			break
		if not bought:
			break
	# a finished build turns spare gold into Tomes
	var tome := DB.item_total_cost("tome_of_might")
	while build_needs(h).is_empty() and h.purse >= tome + 300:
		h.purse -= tome
		h.bonus[h.data["primary"]] += 5.0
	h.recalc()


# ---------------------------------------------------------------- spawning
func spawn_enemy(kind: String, p: Vector3, w := -1) -> Enemy:
	var e: Enemy
	if DB.ENEMIES.get(kind, {}).get("boss", false):
		e = Boss.new()
	else:
		e = Enemy.new()
	e.init_enemy(kind, wave if w < 0 else w, self)
	_scale_enemy(e)
	e.pos = Vector3(p.x, 0, p.z)
	e.setup_visual(make_visual(kind))
	e.post_visual()
	var to_center := _flat(-e.pos)
	e.face(to_center if to_center.length() > 0.1 else Vector3(0, 0, 1))
	e.sync_visual()
	e.set_state("spawn", true)
	weather.apply_to_enemy(e)
	enemies.append(e)
	if e.is_boss:
		boss_units.append(e)
	if kind == "chanter":
		chanters.append(e)
	elif kind == "drummer":
		drummers.append(e)
	if DB.AURAS.has(kind):
		hint_once("aura_" + kind, DB.AURAS[kind]["hint"])
	if DB.MATCHUPS.get(kind, {}).has("hint"):
		hint_once("matchup_" + kind, DB.MATCHUPS[kind]["hint"])
	return e


## Tier / Daily Run multipliers on a freshly made enemy (Endless bosses also grow each lap).
func _scale_enemy(e: Enemy) -> void:
	var hm := hp_scale * (Modes.boss_hp_mult(e.wave) if e.is_boss else 1.0) * party_hp_mult()
	e.max_hp *= hm
	e.hp = e.max_hp
	e.atk_dmg *= dmg_scale
	e.gold_val *= gold_scale
	e.xp_val *= xp_scale
	e.base_speed *= enemy_speed_mult


## Foes get tougher for every AI ally in the run.
func party_hp_mult() -> float:
	return 1.0 + DB.ALLY_FOE_HP * companions.size()


## Rolls whether a freshly spawned wave enemy becomes an elite.
func _roll_elite(e: Enemy) -> void:
	var from := int(cfg.get("elite_from", 4))
	if wave < from:
		return
	var chance := DB.elite_chance(maxi(wave, 4)) * float(cfg.get("elite", 1.0)) * (0.5 if boss_title != "" else 1.0)
	match wave_rule:
		"explosive", "warded":
			chance = maxf(0.18, chance * 1.6)
		"mutants":
			chance = 0.5
	if e.is_boss or e.support or e.captain or rng.randf() >= chance:
		return
	var affixes := DB.elite_affixes(maxi(wave, 4))
	if wave_rule == "explosive":
		affixes = ["volatile"]
	elif wave_rule == "warded":
		affixes = ["warding"] if e.kind != "shieldbearer" else ["frenzied"]
	if e.kind == "shieldbearer":
		affixes.erase("warding")   # a warded wall of shields stalls the wave
	if affixes.is_empty():
		return
	var affix: String = affixes[rng.randi() % affixes.size()]
	e.make_elite(affix)
	if affix == "warding":
		warders.append(e)
	hint_once("elite_" + affix, DB.ELITE_AFFIXES[affix]["hint"])


## True when a living Warding elite (other than `e`) stands near `e`.
func is_warded(e: Unit) -> bool:
	if warders.is_empty():
		return false
	for w in warders:
		if w != e and w.alive and _flat(w.pos - e.pos).length() <= DB.WARD_RADIUS:
			return true
	return false


## True when a living Ward Chanter stands near `e`: it takes no damage. Bosses and Chanters aren't covered.
func is_sheltered(e: Unit) -> bool:
	if chanters.is_empty() or e.is_boss or e.kind == "chanter":
		return false
	var r: float = DB.AURAS["chanter"]["radius"]
	for c in chanters:
		if c.alive and _flat(c.pos - e.pos).length() <= r:
			return true
	return false


## True when a living War Drummer stands near `e`: it deals double damage. Bosses and Drummers aren't covered.
func is_drummed(e: Unit) -> bool:
	if drummers.is_empty() or e.is_boss or e.kind == "drummer":
		return false
	var r: float = DB.AURAS["drummer"]["radius"]
	for d in drummers:
		if d.alive and _flat(d.pos - e.pos).length() <= r:
			return true
	return false


## Volatile elite death: a telegraphed blast after a short delay.
func volatile_burst(p: Vector3, dmg: float) -> void:
	var r := DB.VOLATILE_RADIUS
	fx_timed("telegraph_circle", {"pos": p, "radius": r, "duration": DB.VOLATILE_DELAY, "color": Color(1.0, 0.6, 0.2)}, DB.VOLATILE_DELAY)
	add_hazard({"type": "circle", "pos": p, "r": r, "t": DB.VOLATILE_DELAY + 0.1})
	schedule(DB.VOLATILE_DELAY, _volatile_hit.bind(p, r, dmg))


func _volatile_hit(p: Vector3, r: float, dmg: float) -> void:
	if not in_arena():
		return
	fx("death_burst", {"pos": p, "size": r * 2.0, "color": Color(1.0, 0.6, 0.2)})
	fx("slam", {"pos": p, "radius": r})
	shake(0.35)
	for u in hero_side_targets():
		if _flat(u.pos - p).length() <= r + u.radius * 0.5:
			damage(u, dmg, null, "Volatile Blast", "magic")


func spawn_summon(kind: String, p: Vector3) -> Unit:
	var s := Unit.new()
	s.run = self
	s.kind = kind
	s.team = 0
	s.is_summon = true
	s.pos = Vector3(p.x, 0, p.z)
	s.setup_visual(make_visual(kind))
	s.radius = clampf(s.radius, 0.25, 1.0)
	s.facing = hero.facing
	s.sync_visual()
	s.set_state("spawn", true)
	allies.append(s)
	return s


# ---------------------------------------------------------------- combat
static func armor_factor(a: float) -> float:
	if a >= 0.0:
		return 1.0 - (0.06 * a) / (1.0 + 0.06 * a)
	return 2.0 - pow(0.94, -a)


## Share of a `dtype` hit that `t` takes after armor / magic resist. The hero's items cut through a foe's armor
## ("armor_pen", flat) and magic resist ("mres_pen", a share of it) for every hero-side source, summons included.
func type_mult(t: Unit, dtype: String, src: Unit) -> float:
	# an AI hero's own items count for its hits; summons use the player's
	var who: Hero = null
	if src is Hero:
		who = src
	elif src != null and src.team == 0:
		who = hero
	var pen := who != null and t.team != who.team
	match dtype:
		"phys":
			var arm := t.armor
			if pen and arm > 0.0:
				arm = maxf(0.0, arm - float(who.item_stats.get("armor_pen", 0.0)))
			return armor_factor(arm)
		"magic":
			var mr := t.mres
			if pen and mr > 0.0:
				mr *= 1.0 - clampf(float(who.item_stats.get("mres_pen", 0.0)), 0.0, 1.0)
			return 1.0 - clampf(mr, -1.0, 0.9)
	return 1.0


func damage(t: Unit, amount: float, src: Unit, tag: String, dtype := "phys", opts := {}) -> float:
	if t == null or not t.alive or amount <= 0.0:
		return 0.0
	if t is Barrel:
		return barrels.hit(t, src)
	if delve and t is Enemy and (t as Enemy).dormant:
		delve.wake_unit(t)
	if t.invuln_t > 0.0:
		return 0.0
	# the wave is already won: a late projectile, pool or burn mustn't kill the hero and replay a cleared wave
	if t == hero and phase in ["clear", "victory_wait"]:
		return 0.0
	var a := amount
	if src != null and src.team == 0:
		a *= hero_dmg_mult
	if src != null and src.team == 1:
		a *= weather.foe_dmg_mult()
		if pit_enraged:
			a *= DB.ENRAGE_DMG
		if is_drummed(src):
			a *= DB.DRUM_DMG
	if t.team == 1 and tag in DB.FIRE_TAGS:
		a *= weather.fire_mult()
	if src is Hero and t.team != src.team:
		a *= _hero_item_mult(t, opts, src)
	if t.team == 1 and not t.is_boss and src != null and src.team == 0:
		if wave_rule == "evasive" and opts.get("attack", false) and rng.randf() < DB.EVADE_CHANCE:
			if rng.randf() < 0.5:
				fx("damage_number", {"pos": t.pos + Vector3(0, 2.0, 0), "text": "Miss", "color": DB.WAVE_RULES["evasive"]["color"]})
			return 0.0
	if duel.active:
		a *= Duel.DMG_MULT
	var tm := type_mult(t, dtype, src)
	if t.team == 1 and not t.is_boss and src != null and src.team == 0:
		if wave_rule == "spellward" and dtype == "magic" and not opts.get("attack", false):
			tm = minf(tm, DB.SPELLWARD_MAGIC)
	a *= tm
	if t.team == 1 and t is Enemy:
		a *= (t as Enemy).damage_taken_mult()
		if a <= 0.0 and src != null and src.team == 0:
			(t as Enemy).show_immune()
		elif src != null and src.team == 0 and not t.is_boss and (tm < DB.MATCHUP_RESIST or tm > DB.MATCHUP_WEAK):
			(t as Enemy).show_matchup(tm > 1.0)
	if t == hero:
		if Game.god:
			a = 0.0
		a *= hero_taken_mult
		if duel.active and a >= hero.hp - hero.shield:
			# a duel never costs a life: the loser is left standing on 1 HP
			hero.hp = 1.0
			duel.finish(false)
			return 0.0
		if hero.shield > 0.0:
			var absorbed := minf(hero.shield, a)
			hero.shield -= absorbed
			a -= absorbed
		if hero.kit:
			var a0 := a
			a = as_unit(hero, func(): return hero.kit.incoming_damage(a0, src))
		if cfg.get("no_death", false) and a >= hero.hp:
			a = maxf(0.0, hero.hp - 1.0)   # Training: the hero can't fall
		if a >= hero.hp and hero.has_aegis and hero.aegis_ready:
			hero.aegis_ready = false
			hero.hp = 1.0
			hero.invuln_t = 2.0
			toast("Warden's Aegis saved you!", Art.palette.get("gold", Color.GOLD))
			fx("heal", {"pos": hero.pos})
			return 0.0
		stats["damage_taken"] += a
		if opts.get("melee", false) and hero.reflect > 0.0 and src != null and src.alive:
			damage(src, amount * hero.reflect, hero, "Bulwark Reflect", "magic")
		if a > hero.max_hp * 0.08:
			shake(0.25 + minf(0.5, a / hero.max_hp))
		if a >= 3.0:
			damage_number(t.pos, a, false, Art.palette.get("danger", Color.RED))
		if wave_rule == "bloodthirsty" and src != null and src.team == 1 and src.alive and a > 0.0:
			src.hp = minf(src.max_hp, src.hp + a * DB.BLOODTHIRST_HEAL)
	elif t is Hero:
		# AI heroes (allies, the duel rival): shields and their kit's own defences (parries, rewinds, ...)
		var th := t as Hero
		if th.shield > 0.0:
			var ab := minf(th.shield, a)
			th.shield -= ab
			a -= ab
		if th.kit and a > 0.0:
			var a1 := a
			a = as_unit(th, func(): return th.kit.incoming_damage(a1, src))
		if a >= 3.0:
			damage_number(t.pos, a, false, Art.palette.get("danger", Color.RED) if t.team == 0 else Color(1, 0.95, 0.8))
	if a <= 0.0:
		return 0.0
	t.hp -= a
	t.hurt_at = run_time
	if t.kind != "broodling":
		t.flash(Color(1, 0.35, 0.3) if t.team == 0 else Color(1, 1, 1))
	if src != null and src.team == 0 and t.team == 1:
		var db: Dictionary = stats["damage_by"]
		var key := tag
		if src is Hero and src != hero:
			key = "%s (ally)" % src.data["name"]
		db[key] = db.get(key, 0.0) + a
		var crit: bool = opts.get("crit", false)
		if crit or a >= 30.0 or (a >= 5.0 and rng.randf() < 0.35):
			var col: Color = opts.get("color", Color(1, 0.95, 0.8))
			damage_number(t.pos, a, crit, col)
	if src is Hero and t.team != src.team:
		var sh := src as Hero
		if opts.get("attack", false):
			if sh.lifesteal > 0.0:
				heal_unit(sh, a * sh.lifesteal, false)
			if sh.burn_on_hit:
				t.burn_dps = 10.0 + 0.3 * sh.primary_value()
				t.burn_t = 3.0
				t.burn_src = sh
			_item_on_hit(t, a, amount, opts, sh)
		if opts.has("heal_hero_frac") and sh.alive:
			heal_unit(sh, a * float(opts["heal_hero_frac"]), false)
	elif src != null and src.team == 0 and opts.has("heal_hero_frac") and hero.alive:
		heal_unit(hero, a * float(opts["heal_hero_frac"]), false)
	if t.hp <= 0.0:
		kill(t, src)
	return a


## Damage bonuses from the hero's items on this hit (Hawkeye Lens long shots, Lantern in Fog / Blood Moon).
func _hero_item_mult(t: Unit, opts: Dictionary, h: Hero) -> float:
	var st: Dictionary = h.item_stats
	var m := 1.0
	if st.get("lantern", 0.0) > 0.0:
		m *= weather.lantern_mult()
	if opts.get("attack", false) and not opts.get("melee", false) and st.get("far_shot", 0.0) > 0.0 \
			and _flat(t.pos - h.pos).length() >= 6.0:
		m *= 1.0 + float(st["far_shot"])
	return m


## On-hit effects of items (Cleaving Axe only on melee hits, Splinter Quiver only on shots). `a` is the damage dealt, `raw` the hit before armor.
func _item_on_hit(t: Unit, a: float, raw: float, opts: Dictionary, h: Hero) -> void:
	var st: Dictionary = h.item_stats
	if st.get("hit_heal", 0.0) > 0.0:
		heal_unit(h, float(st["hit_heal"]), false)
	if st.get("berserk", 0.0) > 0.0 and h.hp < h.max_hp * 0.4:
		heal_unit(h, a * 0.15, false)
	if st.get("chill", 0.0) > 0.0 and t.alive:
		t.apply_slow(float(st["chill"]), 1.5)
	if st.get("bash", 0.0) > 0.0:
		h.hit_n += 1
		if h.hit_n % 4 == 0 and t.alive:
			t.stun_t = maxf(t.stun_t, 0.8 * (0.35 if t.is_boss else 1.0))
			fx("ring_burst", {"pos": t.pos, "radius": 1.4, "color": Color(1.0, 0.85, 0.5)})
			damage(t, a * 0.6, h, "Skullcrusher", "pure", {"crit": true})
	if opts.get("melee", false):
		if st.get("cleave", 0.0) > 0.0:
			var any := false
			for e in enemies_in_radius(t.pos, 2.2):
				if e != t:
					damage(e, raw * float(st["cleave"]), h, "Cleaving Axe", "phys")
					any = true
			if any:
				fx("slam", {"pos": t.pos, "radius": 2.2, "color": Color(1.0, 0.8, 0.55)})
	elif st.get("split", 0.0) > 0.0:
		var n := 0
		for e in enemies_in_radius(t.pos, 5.0):
			if e == t or e.untargetable:
				continue
			fire_projectile("hero_bolt", t.pos + Vector3(0, 1.1, 0), e, Vector3.ZERO, 22.0, raw * float(st["split"]), 0, h,
				"Splinter Quiver", {"dtype": "phys", "color": Color(0.95, 0.85, 0.6)})
			n += 1
			if n >= 2:
				break


func heal_unit(u: Unit, amount: float, show := true) -> void:
	if not u.alive or amount <= 0.0:
		return
	if u.hex_t > 0.0:
		amount *= DB.HEX_HEAL_MULT
	var before := u.hp
	u.hp = minf(u.max_hp, u.hp + amount)
	if show and u.hp - before > 5.0:
		fx("heal", {"pos": u.pos})


func kill(t: Unit, src: Unit) -> void:
	if not t.alive:
		return
	t.alive = false
	t.hp = 0.0
	t.clear_mark()
	if t == hero:
		_hero_died()
		return
	# an AI hero's kill can still announce captains and gold
	var q := _quiet
	_quiet = 0
	_kill_rest(t)
	_quiet = q


func _kill_rest(t: Unit) -> void:
	if t == rival:
		duel.finish(true)
		return
	if t is Hero and t in companions:
		_companion_down(t)
		return
	t.set_state("death", true)
	t.death_t = 1.2
	corpses.append(t)
	if t.team == 1 and t is Enemy:
		var e := t as Enemy
		if e.is_boss:
			Game.crumb("boss death %s #%d (bosses left %d)" % [e.kind, e.twin_index, boss_units.filter(func(b): return b.alive).size()])
		e.on_death()
		if e == captain:
			captain = null
			var cg := int(round(DB.captain_gold(wave) * gold_scale))
			add_gold(cg)
			fx("gold", {"pos": e.pos + Vector3(0, 2.0, 0), "amount": cg})
			toast("%s slain! +%d gold" % [e.display_name, cg], Art.palette.get("gold", Color.GOLD))
		if e in echoes:
			_echo_died()
		if hero.kit:
			as_unit(hero, func(): hero.kit.on_enemy_killed(e))
		for c in companions:
			if c.alive and not c.dead and c.kit:
				as_unit(c, func(): c.kit.on_enemy_killed(e))
		if not e.no_reward:
			stats["kills"] += 1
			var g := int(round(e.gold_val))
			if g > 0:
				add_gold(g)
				if rng.randf() < 0.5 or e.is_boss:
					fx("gold", {"pos": e.pos + Vector3(0, 1.5, 0), "amount": g})
			if hero.alive and not hero.dead:
				if hero.add_xp(e.xp_val):
					_on_level_up()
			for c in companions:
				if not c.dead:
					c.add_xp(e.xp_val)
		fx("death_burst", {"pos": e.pos, "size": e.radius * 2.0, "color": Art.palette.get("ember", Color.ORANGE)})
		if e.is_boss:
			shake(0.6)
			Game.crumb("boss death handled")
			Game.watch_frames("boss death %s #%d" % [e.kind, e.twin_index])
	else:
		fx("death_burst", {"pos": t.pos, "size": t.radius * 2.0})


func add_gold(g: int) -> void:
	gold += g
	stats["gold_earned"] += g
	wave_gold += g


func _on_level_up() -> void:
	fx("level_up", {"pos": hero.pos})
	toast("Level %d! Skill point ready" % hero.level, Art.palette.get("xp", Color.MEDIUM_PURPLE))
	Audio.play("level_up")


func _log_wave(what: String) -> void:
	var log: Array = get_meta("wave_log", [])
	log.append({"wave": wave, "ev": what, "lvl": hero.level, "gold": gold, "t": snappedf(run_time, 0.1),
		"wt": snappedf(wave_time, 0.1), "hp": snappedf(hero.hp / maxf(1.0, hero.max_hp), 0.01), "items": hero.items.size(),
		"weather": weather.id if weather else ""})
	set_meta("wave_log", log)


func _hero_died() -> void:
	_log_wave("death")
	Game.crumb("hero died")
	hero.dead = true
	hero.set_state("death", true)
	stats["deaths"] += 1
	if mode != "practice":
		lives -= 1
	wave_died = true
	shake(0.8)
	Audio.play("death")
	hero.focus = null
	if lives <= 0:
		phase = "dead"
		phase_t = 2.5
		banner_requested.emit("Fallen", "No lives remain")
	else:
		phase = "dead"
		phase_t = 3.0
		banner_requested.emit("You have fallen", "%d %s left. Respawning in camp..." % [lives, "life" if lives == 1 else "lives"])


# ---------------------------------------------------------------- projectiles
func fire_projectile(kind: String, from: Vector3, target: Unit, dir: Vector3, spd: float, dmg: float, team: int, src: Unit, tag: String, opts := {}) -> void:
	if src is Hero:
		team = src.team   # kits pass 0; the duel rival's shots are foe shots
	var node := _get_proj_node(kind)
	var d := dir
	if target != null:
		d = _flat(target.pos - from)
	d.y = 0
	if d.length_squared() < 0.0001:
		d = Vector3(0, 0, -1)
	d = d.normalized()
	var p := {"kind": kind, "node": node, "pos": Vector3(from.x, 1.1, from.z), "origin": from, "dir": d, "speed": spd,
		"dmg": dmg, "team": team, "src": src, "tag": tag, "target": target, "life": opts.get("life", 2.2), "opts": opts}
	if node:
		node.position = p["pos"]
		node.rotation.y = atan2(-d.x, -d.z)
	projs.append(p)


func _get_proj_node(kind: String) -> Node3D:
	var arr: Array = proj_pool.get(kind, [])
	while arr.size() > 0:
		var n = arr.pop_back()
		if is_instance_valid(n):
			n.visible = true
			return n
	var nn = null
	if Art.has_method("create_projectile"):
		nn = Art.create_projectile(kind)
	if not (nn is Node3D):
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.2
		s.height = 0.4
		mi.mesh = s
		nn = mi
	units_root.add_child(nn)
	return nn


func _release_proj(p: Dictionary) -> void:
	var n = p["node"]
	if n != null and is_instance_valid(n):
		n.visible = false
		n.position = Vector3(0, -50, 0)
		if not proj_pool.has(p["kind"]):
			proj_pool[p["kind"]] = []
		proj_pool[p["kind"]].append(n)


func _tick_projectiles(dt: float) -> void:
	var keep := []
	for p in projs:
		var done := false
		p["life"] -= dt
		var tgt: Unit = p["target"]
		if tgt != null and (not tgt.alive or tgt.untargetable):
			p["target"] = null
			tgt = null
		if tgt != null:
			var to: Vector3 = _flat(tgt.pos - p["pos"])
			if to.length() > 0.01:
				var turn: float = p["opts"].get("turn", -1.0)
				if turn < 0.0:
					p["dir"] = to.normalized()
				elif to.dot(p["dir"]) <= 0.0:
					# lazy homing (foe bolts): once it has flown past, it stops chasing
					p["target"] = null
				else:
					var ang: float = p["dir"].signed_angle_to(to.normalized(), Vector3.UP)
					p["dir"] = p["dir"].rotated(Vector3.UP, clampf(ang, -turn * dt, turn * dt))
		var step: Vector3 = p["dir"] * p["speed"] * dt
		p["pos"] += step
		var pp: Vector3 = p["pos"]
		# hit test
		var victims: Array = enemies if p["team"] == 0 else hero_side_targets()
		var hit_r: float = p["opts"].get("hit_r", 0.45)
		for u in victims:
			if not u.alive or u.untargetable:
				continue
			var dx: float = u.pos.x - pp.x
			var dz: float = u.pos.z - pp.z
			var rr: float = u.radius + hit_r
			if dx * dx + dz * dz <= rr * rr:
				if p["src"] is Hero and p["src"] != hero:
					as_unit(p["src"], _proj_hit.bind(p, u))
				else:
					_proj_hit(p, u)
				done = true
				break
		if not done and pp.z < 30.0 and (arena.blocks_shot(pp) or (delve and delve.blocks_shot(pp))):
			done = true
			fx("hit", {"pos": pp})
		# barrel stacks are cover from foe shots (the hero's own shots still fly over them)
		if not done and p["team"] == 1 and barrels and pp.z < 30.0 and barrels.barrel_near(pp, 0.05) != null:
			done = true
			fx("hit", {"pos": pp, "color": p["opts"].get("color", Color(1, 1, 1))})
		if not done and p["life"] <= 0.0:
			done = true
		if not done and delve == null and Vector2(pp.x, pp.z).length() > DB.ARENA_R + 1.0 and pp.z < 30.0:
			done = true
		if done:
			_release_proj(p)
		else:
			var n = p["node"]
			if n != null and is_instance_valid(n):
				n.position = pp
				n.rotation.y = atan2(-p["dir"].x, -p["dir"].z)
				if n.has_method("tick"):
					n.call("tick", dt)
			keep.append(p)
	projs = keep


func _proj_hit(p: Dictionary, u: Unit) -> void:
	var opts: Dictionary = p["opts"]
	if u.blocks_front:
		var incoming: Vector3 = -p["dir"]
		if incoming.dot(u.facing) > 0.3:
			stats["shield_blocks"] += 1
			if p["src"] == hero:
				hint_once("shield_turn", "Blocked! Shieldbearers turn slowly: circle round and hit their back.")
			fx("hit", {"pos": u.pos + Vector3(0, 1.0, 0) + u.facing * u.radius, "color": Color(0.7, 0.75, 0.85)})
			u.flash(Color(0.6, 0.7, 1.0))
			return
		stats["shield_hits"] += 1
	fx("hit", {"pos": p["pos"], "color": opts.get("color", Art.palette.get("ember", Color.ORANGE))})
	var o := {}
	if opts.has("heal_hero_frac"):
		o["heal_hero_frac"] = opts["heal_hero_frac"]
	if opts.get("attack", false):
		o["attack"] = true
	if opts.has("crit"):
		o["crit"] = opts["crit"]
	var dmg: float = p["dmg"] * weather.shot_mult(p["dir"])
	damage(u, dmg, p["src"], p["tag"], opts.get("dtype", "magic"), o)
	if opts.has("slow"):
		u.apply_slow(opts["slow"], opts.get("slow_t", 1.5))
	if opts.has("hex") and u.alive:
		u.hex_t = maxf(u.hex_t, float(opts["hex"]))
		u.flash(Color(0.7, 0.35, 1.0))
		if u == hero:
			hint_once("hex", "Hexed! Hexcaster bolts halve your healing. They are slow: sidestep them or hide behind pillars and barrels.")
	if opts.get("spit_mark", false):
		u.spit_mark_t = 4.0
	if opts.has("aoe"):
		var r: float = opts["aoe"]
		var group: Array = enemies if p["team"] == 0 else hero_side_targets()
		for o2 in group:
			if o2 != u and o2.alive and _flat(o2.pos - u.pos).length() <= r + o2.radius:
				damage(o2, p["dmg"] * 0.6, p["src"], p["tag"], opts.get("dtype", "magic"))
	if p["src"] is Hero and p["src"].kit and opts.get("attack", false):
		p["src"].kit.on_attack_hit(u)


# ---------------------------------------------------------------- walls & pools
func add_wall(a: Vector3, b: Vector3, dur: float, dps: float, src: Unit, tag: String, fx_name := "ash_wall") -> Dictionary:
	a.y = 0
	b.y = 0
	var w := {"a": a, "b": b, "t": dur, "dps": dps, "src": src, "tag": tag, "tick": 0.0,
		"fx": fx(fx_name, {"from": a, "to": b, "duration": dur})}
	walls.append(w)
	return w


func add_pool(p: Vector3, r: float, dps: float, dur: float) -> void:
	var pl := {"pos": p, "r": r, "dps": dps, "t": dur, "tick": 0.0,
		"fx": fx("bloater_pool", {"pos": p, "radius": r, "duration": dur})}
	pools.append(pl)
	add_hazard({"type": "circle", "pos": p, "r": r, "t": dur})


static func seg_closest(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return a
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return a + ab * t


func _tick_walls_pools(dt: float) -> void:
	var keep := []
	for w in walls:
		w["t"] -= dt
		w["tick"] -= dt
		if w["tick"] <= 0.0 and w["dps"] > 0.0:
			w["tick"] = 0.25
			var mult := 1.0
			var heal := 0.0
			var wk: HeroKit = w["src"].kit if w["src"] is Hero else null
			if wk and wk.has_method("wall_mult"):
				mult = wk.wall_mult()
				heal = wk.empower_heal()
			for e in enemies:
				if not e.alive or e.untargetable:
					continue
				var c: Vector3 = seg_closest(e.pos, w["a"], w["b"])
				if _flat(e.pos - c).length() <= e.radius + 0.75:
					var o := {"color": Art.palette.get("ember", Color.ORANGE)}
					if heal > 0.0:
						o["heal_hero_frac"] = heal
					damage(e, w["dps"] * 0.25 * mult, w["src"], w["tag"], "magic", o)
		if w["t"] <= 0.0:
			fx_stop(w["fx"])
		else:
			keep.append(w)
	walls = keep
	var keep2 := []
	for pl in pools:
		pl["t"] -= dt
		pl["tick"] -= dt
		if pl["tick"] <= 0.0:
			pl["tick"] = 0.25
			for u in hero_side_targets():
				if _flat(u.pos - pl["pos"]).length() <= pl["r"] + u.radius * 0.5:
					damage(u, pl["dps"] * 0.25, null, "Bloater Pool", "magic")
		if pl["t"] <= 0.0:
			fx_stop(pl["fx"])
		else:
			keep2.append(pl)
	pools = keep2
	var keep3 := []
	for h in hazards:
		h["t"] -= dt
		if h["t"] > 0.0:
			keep3.append(h)
	hazards = keep3


# ---------------------------------------------------------------- movement / collision
## Moves a unit by `v` (already multiplied by dt) and resolves static collisions.
func move_unit(u: Unit, v: Vector3) -> void:
	var old := u.pos
	var p := u.pos + Vector3(v.x, 0, v.z)
	u.pos = resolve_pos(u, p, old)


func resolve_pos(u: Unit, p: Vector3, old: Vector3) -> Vector3:
	p.y = 0.0
	var camp := old.z > 30.0
	if camp:
		var off := p - DB.CAMP_CENTER
		off.y = 0
		var lim := DB.CAMP_R - u.radius
		if off.length() > lim:
			p = DB.CAMP_CENTER + off.normalized() * lim
		return p
	if delve and delve.active:
		p = delve.resolve(u, p)
	else:
		for pl in Maps.pillars():
			var d := Vector2(p.x - pl.x, p.z - pl.z)
			var minr := DB.PILLAR_R + u.radius
			if d.length() < minr:
				if d.length() < 0.001:
					d = Vector2(1, 0)
				d = d.normalized() * minr
				p.x = pl.x + d.x
				p.z = pl.z + d.y
		if arena:
			p = arena.resolve(u, p)
		if barrels:
			p = barrels.resolve(u, p)
		var r := Vector2(p.x, p.z).length()
		var lim2 := arena_r() - u.radius - 0.3
		if r > lim2:
			var k := lim2 / r
			p.x *= k
			p.z *= k
	if u.team == 1 and walls.size() > 0:
		for w in walls:
			var a: Vector3 = w["a"]
			var b: Vector3 = w["b"]
			var c := seg_closest(p, a, b)
			var dv := _flat(p - c)
			var minr2 := u.radius + 0.35
			var ab := b - a
			var n := Vector3(-ab.z, 0, ab.x).normalized()
			var side_old := signf(n.dot(old - a))
			var side_new := signf(n.dot(p - a))
			var crossed := side_old != side_new and side_old != 0.0
			if crossed:
				# block crossing: only if the crossing point is within the segment span
				var t := (p - a).dot(ab) / maxf(0.0001, ab.length_squared())
				if t >= -0.05 and t <= 1.05:
					var cc := seg_closest(p, a, b)
					p = cc + n * side_old * minr2
					p.y = 0
					continue
			if dv.length() < minr2:
				if dv.length() < 0.001:
					dv = n * (side_old if side_old != 0.0 else 1.0)
				p = c + dv.normalized() * minr2
				p.y = 0
	return p


## Steering toward a point with pillar avoidance. Returns a normalized direction.
func steer_dir(u: Unit, goal: Vector3) -> Vector3:
	if delve and delve.active and u.pos.z < 30.0:
		var wp := delve.waypoint(u, goal)
		var tw := _flat(wp - u.pos)
		return tw.normalized() if tw.length() > 0.01 else Vector3.ZERO
	if barrels and u.pos.z < 30.0:
		goal = barrels.waypoint(u, goal)
	var to := _flat(goal - u.pos)
	var dist := to.length()
	if dist < 0.01:
		return Vector3.ZERO
	var dir := to / dist
	if u.pos.z > 30.0:
		return dir
	for ob in (arena.obstacles() if arena else _pillar_obs()):
		var c: Vector3 = ob[0]
		var orad: float = ob[1]
		var rel := _flat(c - u.pos)
		var along := rel.dot(dir)
		if along <= 0.0 or along > dist + orad:
			continue
		var perp := rel - dir * along
		var clear := orad + u.radius + 0.4
		if perp.length() < clear and rel.length() < 7.0:
			# steer to the side away from the obstacle center
			var side := -perp.normalized() if perp.length() > 0.01 else Vector3(dir.z, 0, -dir.x)
			var w := 1.0 - clampf((rel.length() - orad) / 5.0, 0.0, 1.0)
			dir = (dir + side * (0.6 + 1.2 * w)).normalized()
	return dir


func _pillar_obs() -> Array:
	var out := []
	for pl in Maps.pillars():
		out.append([pl, DB.PILLAR_R])
	return out


## Walkable radius of the arena floor right now (shrinks when the rim crumbles).
func arena_r() -> float:
	if delve and delve.active:
		return 1000.0   # the dungeon's walls are delve.resolve()'s business
	return arena.radius if arena else DB.ARENA_R


## Radius AI and the bot should stay inside: the coming crack line while the rim is about to fall.
func arena_safe_r() -> float:
	if delve and delve.active:
		return 1000.0
	return arena.safe_radius() if arena else DB.ARENA_R


func _separate(dt: float) -> void:
	_grid.clear()
	for e in enemies:
		if not e.alive or not e.collides:
			continue
		var key := Vector2i(floori(e.pos.x / 2.0), floori(e.pos.z / 2.0))
		if _grid.has(key):
			_grid[key].append(e)
		else:
			_grid[key] = [e]
	for a in allies:
		if not a.alive or not a.collides or a.pos.z > 30.0:
			continue
		var key2 := Vector2i(floori(a.pos.x / 2.0), floori(a.pos.z / 2.0))
		if _grid.has(key2):
			_grid[key2].append(a)
		else:
			_grid[key2] = [a]
	var pushes := {}
	for key in _grid:
		var cell: Array = _grid[key]
		for u in cell:
			if u.no_push:
				continue
			var push := Vector3.ZERO
			for ox in range(-1, 2):
				for oz in range(-1, 2):
					var k2 := Vector2i(key.x + ox, key.y + oz)
					if not _grid.has(k2):
						continue
					for v in _grid[k2]:
						if v == u:
							continue
						var dx: float = u.pos.x - v.pos.x
						var dz: float = u.pos.z - v.pos.z
						var minr: float = u.radius + v.radius
						var d2 := dx * dx + dz * dz
						if d2 < minr * minr:
							var d := sqrt(d2)
							if d < 0.001:
								dx = rng.randf_range(-1, 1)
								dz = rng.randf_range(-1, 1)
								d = 0.01
							var ov := minr - d
							var share := 1.0 if v.no_push else 0.5
							push += Vector3(dx / d, 0, dz / d) * ov * share
			if push != Vector3.ZERO:
				pushes[u] = push
	for u in pushes:
		var pv: Vector3 = pushes[u]
		if pv.length() > 0.5:
			pv = pv.normalized() * 0.5
		u.pos = resolve_pos(u, u.pos + pv, u.pos)
	# the hero shoves enemies out of its way
	if hero.alive and not hero.in_camp:
		for e in enemies:
			if not e.alive or e.no_push or not e.collides:
				continue
			var dx: float = e.pos.x - hero.pos.x
			var dz: float = e.pos.z - hero.pos.z
			var minr: float = e.radius + hero.radius
			var d2 := dx * dx + dz * dz
			if d2 < minr * minr and d2 > 0.0001:
				var d := sqrt(d2)
				e.pos = resolve_pos(e, e.pos + Vector3(dx / d, 0, dz / d) * (minr - d), e.pos)
			elif d2 <= 0.0001:
				e.pos = resolve_pos(e, e.pos + Vector3(minr, 0, 0), e.pos)
		for b in enemies:
			if b.alive and b.no_push and b.collides:
				var dx2: float = hero.pos.x - b.pos.x
				var dz2: float = hero.pos.z - b.pos.z
				var minr2: float = b.radius + hero.radius
				var dd: float = dx2 * dx2 + dz2 * dz2
				if dd < minr2 * minr2 and dd > 0.0001:
					var d3 := sqrt(dd)
					hero.pos = resolve_pos(hero, hero.pos + Vector3(dx2 / d3, 0, dz2 / d3) * (minr2 - d3), hero.pos)


## Forced motion (pull / knockback). Returns true if the unit is being moved by force.
func forced_motion(u: Unit, dt: float) -> bool:
	if u.pull_t > 0.0:
		var to := _flat(u.pull_to - u.pos)
		var spd := maxf(to.length() / maxf(u.pull_t, 0.05), 6.0)
		u.pull_t -= dt
		var stepv := to.normalized() * minf(to.length(), spd * dt)
		u.pos = resolve_pos(u, u.pos + stepv, u.pos)
		return true
	if u.knock.length_squared() > 0.01:
		u.pos = resolve_pos(u, u.pos + u.knock * dt, u.pos)
		u.knock = u.knock.move_toward(Vector3.ZERO, 30.0 * dt)
		return true
	return false


# ---------------------------------------------------------------- main loop
func _process(delta: float) -> void:
	if result != "" and phase in ["victory", "defeat", "training"]:
		_update_camera(delta)
		return
	Game.mark(1)
	_num_budget = minf(10.0, _num_budget + delta * 40.0)
	var t0 := Time.get_ticks_usec()
	# after a long hitch, don't try to catch the whole gap up in one frame (that frame would be even longer)
	var sim_delta := minf(delta, 0.25 * Engine.time_scale)
	var n := maxi(1, ceili(sim_delta / SUBSTEP))
	var dt := sim_delta / n
	for i in n:
		_step(dt)
		if result != "":
			break
	Game.mark(14)
	# per-frame simulation cost (normalized to one 1/60 s step so accelerated runs stay comparable)
	var us := float(Time.get_ticks_usec() - t0) / maxf(1.0, delta * 60.0)
	sim_us_sum += us
	sim_frames += 1
	if enemies.size() >= 40:
		sim_us_max_busy = maxf(sim_us_max_busy, us)
		sim_us_busy_sum += us
		sim_busy_frames += 1
	for u in enemies:
		u.sync_visual()
	for a in allies:
		a.sync_visual()
	hero.sync_visual()
	for c in corpses:
		pass
	Game.mark(15)
	_update_camera(delta)
	_sync_state()
	Game.mark(16)


func _step(dt: float) -> void:
	_step_n += 1
	run_time += dt
	Game.mark(2)
	if timers.size() > 0:
		var due := []
		var keep := []
		for t in timers:
			t[0] -= dt
			if t[0] <= 0.0:
				due.append(t[1])
			else:
				keep.append(t)
		timers = keep
		for c in due:
			if c.is_valid():
				c.call()
	Game.mark(3)
	match phase:
		"prep":
			if tutorial == null:
				_tick_prep(dt)
		"wave":
			if tutorial == null:
				_tick_wave(dt)
			else:
				wave_time += dt
		"clear":
			phase_t -= dt
			if phase_t <= 0.0:
				_return_to_camp()
		"dead":
			phase_t -= dt
			if phase_t <= 0.0:
				if lives <= 0:
					_end_run("defeat")
					return
				_after_death()
		"duel", "duel_end":
			duel.tick(dt)
	if tutorial:
		tutorial.tick(dt)
	Game.mark(4)
	_tick_hero(dt)
	Game.mark(5)
	if hero.kit:
		hero.kit.tick(dt)
	for c in companions:
		if c.alive and not c.dead:
			as_unit(c, _tick_ai.bind(c, dt))
	if rival != null and rival.alive:
		as_unit(rival, _tick_ai.bind(rival, dt))
	if delve and delve.active and not hero.in_camp:
		hero.pos = delve.resolve(hero, hero.pos)   # dashes and blinks stop at the dungeon's walls
	Game.mark(6)
	for e in enemies:
		if e.alive and e is Enemy:
			e.tick(dt)
	Game.mark(7)
	_tick_allies_generic(dt)
	Game.mark(8)
	_separate(dt)
	Game.mark(9)
	_tick_projectiles(dt)
	Game.mark(10)
	_tick_walls_pools(dt)
	weather.tick(dt)
	Game.mark(11)
	_tick_burns(dt)
	Game.mark(12)
	_tick_corpses(dt)
	if bot:
		Game.mark(13)
		bot.tick(dt)
	if soak:
		soak.tick(dt)


func _tick_burns(dt: float) -> void:
	for e in enemies:
		if e.alive and e.burn_t > 0.0:
			e.burn_t -= dt
			e.burn_tick -= dt
			if e.burn_tick <= 0.0:
				e.burn_tick = 0.5
				damage(e, e.burn_dps * 0.5, e.burn_src, "Emberbrand Burn", "magic", {"color": Color(1.0, 0.6, 0.25)})


func _tick_corpses(dt: float) -> void:
	var dead_e := false
	for e in enemies:
		if not e.alive:
			dead_e = true
			break
	if dead_e:
		var keep := []
		for e in enemies:
			if e.alive:
				keep.append(e)
		enemies = keep
		var kb := []
		for b in boss_units:
			if b.alive:
				kb.append(b)
		boss_units = kb
		if not warders.is_empty():
			warders = warders.filter(func(w): return w.alive)
		if not chanters.is_empty():
			chanters = chanters.filter(func(w): return w.alive)
		if not drummers.is_empty():
			drummers = drummers.filter(func(w): return w.alive)
	var dead_a := false
	for a in allies:
		if not a.alive:
			dead_a = true
			break
	if dead_a:
		var keep2 := []
		for a in allies:
			if a.alive:
				keep2.append(a)
			elif not corpses.has(a):
				a.death_t = 1.2
				a.set_state("death", true)
				corpses.append(a)
		allies = keep2
	if corpses.size() > 0:
		var keepc := []
		for c in corpses:
			c.death_t -= dt
			if c.death_t <= 0.0:
				if c.node != null and is_instance_valid(c.node):
					c.node.queue_free()
				c.node = null
				c.removed = true
			else:
				keepc.append(c)
		corpses = keepc


## Remove a summon immediately (no death animation) or with a death animation.
func remove_ally(a: Unit, animate := true) -> void:
	if not a.alive:
		return
	a.alive = false
	a.clear_mark()
	if animate:
		a.set_state("death", true)
		a.death_t = 1.0
		corpses.append(a)
	else:
		if a.node and is_instance_valid(a.node):
			a.node.queue_free()
		a.node = null
		a.removed = true


func _tick_allies_generic(dt: float) -> void:
	for a in allies:
		if not a.alive or a is Hero:
			continue
		a.tick_status(dt)
		if a.lifetime > 0.0:
			a.lifetime -= dt
			if a.lifetime <= 0.0:
				remove_ally(a)


## An AI hero's step: its bot decides, then it moves / attacks and its kit ticks. Called through as_unit().
func _tick_ai(h: Hero, dt: float) -> void:
	var b: Node = brains.get(h)
	if b != null:
		b.tick(dt)
	tick_hero_unit(h, dt)
	if h.kit and h.alive and not h.dead:
		h.kit.tick(dt)


# ---------------------------------------------------------------- hero
func _tick_hero(dt: float) -> void:
	tick_hero_unit(hero, dt)


## One sim step of a hero: the player's, an AI ally's or the duel rival's (the rival runs inside as_unit()).
func tick_hero_unit(h: Hero, dt: float) -> void:
	if not h.alive or h.dead:
		return
	h.tick_status(dt)
	# regen
	var regen_mult := DB.HEX_HEAL_MULT if h.hex_t > 0.0 else 1.0
	h.hp = minf(h.max_hp, h.hp + h.hp_regen * dt * regen_mult)
	h.mana = minf(h.max_mana, h.mana + h.mana_regen * dt)
	var keep := []
	for b in h.regen_buff:
		b["t"] -= dt
		h.hp = minf(h.max_hp, h.hp + b["hp"] * dt * regen_mult)
		h.mana = minf(h.max_mana, h.mana + b["mana"] * dt)
		if b["t"] > 0.0:
			keep.append(b)
	h.regen_buff = keep
	if h.sprint_t > 0.0:
		h.sprint_t -= dt
	for it in h.items:
		if it.get("cd", 0.0) > 0.0:
			it["cd"] -= dt
	# camp healing
	if h.in_camp:
		h.hp = minf(h.max_hp, h.hp + h.max_hp * 0.03 * dt)
		h.mana = minf(h.max_mana, h.mana + h.max_mana * 0.03 * dt)
		if _flat(h.pos - DB.FOUNTAIN_POS).length() < 3.8:
			h.hp = minf(h.max_hp, h.hp + h.max_hp * 0.3 * dt)
			h.mana = minf(h.max_mana, h.mana + h.max_mana * 0.3 * dt)
			_fountain_fx_t -= dt
			if _fountain_fx_t <= 0.0 and (h.hp < h.max_hp - 1.0 or h.mana < h.max_mana - 1.0):
				_fountain_fx_t = 1.0
				fx("fountain_heal", {"pos": DB.FOUNTAIN_POS})
	# cooldowns
	var rate := 1.0
	if h.kit:
		rate = h.kit.cd_rate()
	for i in 4:
		if h.cds[i] > 0.0:
			h.cds[i] = maxf(0.0, h.cds[i] - dt * rate)
	if h.stun_t > 0.0:
		return
	# movement
	var moved := false
	if h.kit and h.kit.override_motion(dt):
		moved = true
	elif not forced_motion(h, dt):
		var mi := h.move_input
		if mi.length() > 1.0:
			mi = mi.normalized()
		if mi.length() > 0.12:
			var v := Vector3(mi.x, 0, mi.y) * h.speed() * clampf(mi.length() * 1.25, 0.35, 1.0)
			var before := h.pos
			move_unit(h, v * dt)
			h.face(v)
			moved = true
			_check_bump(h, v, before, dt)
			if h.focus != null and mi.length() > 0.5:
				h.focus = null
		elif h.focus != null and h.focus.alive and not h.focus.untargetable:
			var d := h.edge_dist(h.focus)
			if d > h.atk_range:
				var dir := steer_dir(h, h.focus.pos)
				move_unit(h, dir * h.speed() * dt)
				h.face(dir)
				moved = true
	if h.move_input.length() <= 0.5:
		h.bump_t = 0.0
	h.moving = moved
	if moved:
		h.still_t = 0.0
	else:
		h.still_t += dt
	# attack
	if h.atk_wind > 0.0:
		h.atk_wind -= dt
		if h.atk_wind <= 0.0:
			_attack_resolve_for(h)
	elif h.atk_cd <= 0.0 and not h.in_camp and (h.kit == null or h.kit.can_attack()):
		var t := _pick_target_for(h)
		if t != null:
			h.atk_target = t
			h.target = t   # kits read a foe's `target` (e.g. the Duelist's parry of a hit aimed at it)
			h.atk_cd = h.attack_interval()
			h.atk_wind = minf(0.22, h.attack_interval() * 0.3)
			if not moved:
				h.face(t.pos - h.pos)
			h.set_state("attack")
	if h.atk_wind <= 0.0:
		if moved:
			h.set_state("run")
		else:
			h.set_state("idle")


## Pushing into a barrel with the stick for a moment swings at it.
func _check_bump(h: Hero, v: Vector3, before: Vector3, dt: float) -> void:
	var want := v.length() * dt
	if want < 0.001 or _flat(h.pos - before).length() > want * 0.6:
		h.bump_t = 0.0
		return
	var b := barrels.barrel_near(h.pos + v.normalized() * (h.radius + 0.3), 0.35)
	if b == null:
		h.bump_t = 0.0
		return
	h.bump_t += dt
	if h.bump_t >= 0.3:
		h.bump = b


func _pick_target_for(h: Hero) -> Unit:
	var reach := h.atk_range + h.radius
	if h.bump != null:
		if h.bump.alive and h.bump_t > 0.0 and h.edge_dist(h.bump) <= h.atk_range + 0.3:
			return h.bump
		h.bump = null
	if h.focus != null and h.focus.alive and not h.focus.untargetable:
		if h.edge_dist(h.focus) <= h.atk_range + 0.3:
			return h.focus
	# nearest enemy in reach, skipping ones a Ward Chanter makes immune when there's anything else
	var best: Unit = null
	var bd := 1e9
	var best_any: Unit = null
	var bd_any := 1e9
	for e in enemies:
		if not e.alive or e.untargetable:
			continue
		var d: float = _flat(e.pos - h.pos).length() - e.radius
		if d > reach:
			continue
		if delve and not delve.los(h.pos, e.pos):
			continue   # no shooting through the dungeon's walls
		if d < bd_any:
			bd_any = d
			best_any = e
		if d < bd and not is_sheltered(e):
			bd = d
			best = e
	return best if best != null else best_any


func _attack_resolve_for(h: Hero) -> void:
	var t := h.atk_target
	if t == null or not t.alive or t.untargetable:
		return
	if h.edge_dist(t) > h.atk_range + 1.2:
		return
	if t is Barrel:
		barrels.hit(t, h)
		if h == hero:
			Audio.play("hit")
		return
	var crit := rng.randf() < 0.1
	var dmg := h.atk_dmg * rng.randf_range(0.92, 1.08) * (1.8 if crit else 1.0)
	if h.kit:
		dmg *= h.kit.damage_mult()
		if h.kit.basic_attack(t, dmg, crit):
			return
	fx("hit", {"pos": t.pos + Vector3(0, 1.0, 0)})
	damage(t, dmg, h, "Attack", "phys", {"attack": true, "crit": crit, "melee": true})
	if h.kit:
		h.kit.on_attack_hit(t)
	if h == hero:
		Audio.play("hit")


## Cast hero skill `slot`. aim: {} for smart cast, else {"point": Vector3, "dir": Vector3}.
func try_cast(slot: int, aim := {}) -> bool:
	return cast_for(hero, slot, aim)


## Cast skill `slot` of hero `h` (the player, or an AI hero from inside as_unit()).
func cast_for(h: Hero, slot: int, aim := {}) -> bool:
	var me := h == hero
	if not h.alive or h.dead or slot < 0 or slot > 3:
		return false
	if h.ranks[slot] <= 0:
		if me:
			toast("Learn it first (tap +)", Art.palette.get("dim", Color.GRAY))
		return false
	if h.stun_t > 0.0:
		return false
	var kit := h.kit
	if kit.free_cast(slot):
		var a0 := aim if not aim.is_empty() else kit.smart_aim(slot)
		var ok := kit.cast(slot, a0)
		if ok and me:
			skill_cast.emit(slot)
		return ok
	if not kit.is_ready(slot):
		return false
	var cost := h.skill_mana(slot)
	if h.mana < cost:
		toast("Not enough mana", Art.palette.get("mana", Color.CORNFLOWER_BLUE))
		return false
	if not kit.can_cast(slot):
		return false
	var a := aim
	if a.is_empty():
		a = kit.smart_aim(slot)
	if a.is_empty():
		a = {"point": h.pos + h.facing * 3.0, "dir": h.facing}
	if not a.has("dir"):
		var dd: Vector3 = _flat(a["point"] - h.pos)
		a["dir"] = dd.normalized() if dd.length() > 0.05 else h.facing
	if not a.has("point"):
		a["point"] = h.pos + a["dir"] * 3.0
	if not kit.cast(slot, a):
		return false
	h.mana -= cost
	kit.start_cooldown(slot)
	kit.after_cast(slot)
	h.set_state("cast")
	if me:
		Audio.play("cast")
		skill_cast.emit(slot)
	return true


func rank_up(slot: int) -> bool:
	if hero.rank_up(slot):
		Audio.play("rank")
		return true
	return false


func use_item(idx: int) -> bool:
	return use_item_for(hero, idx)


func use_item_for(h: Hero, idx: int) -> bool:
	if idx < 0 or idx >= h.items.size() or not h.alive or h.dead:
		return false
	var it: Dictionary = h.items[idx]
	var d: Dictionary = DB.ITEMS.get(it["id"], {})
	if not d.has("active"):
		return false
	if it.get("cd", 0.0) > 0.0:
		return false
	match d["active"]:
		"sprint":
			h.sprint_t = 3.0
			fx("teleport", {"pos": h.pos})
		"heal_potion":
			h.regen_buff.append({"hp": 50.0, "mana": 0.0, "t": 8.0})
			fx("heal", {"pos": h.pos})
		"mana_potion":
			h.regen_buff.append({"hp": 0.0, "mana": 250.0 / 6.0, "t": 6.0})
			fx("heal", {"pos": h.pos})
	it["cd"] = float(d.get("active_cd", 1.0))
	if d.get("kind", "") == "consumable":
		it["charges"] = int(it.get("charges", 1)) - 1
		if it["charges"] <= 0:
			h.items.remove_at(idx)
			h.recalc()
	if h == hero:
		Audio.play("item")
	return true


# ---------------------------------------------------------------- shop
func shop_open_allowed() -> bool:
	return hero.in_camp and phase == "prep" and hero.alive


## Gold needed to buy an item now (missing components are bought automatically).
func buy_price(id: String) -> int:
	var d: Dictionary = DB.ITEMS.get(id, {})
	var owned := []
	for it in hero.items:
		owned.append(it["id"])
	return _price_with(id, owned)


## Remaining entries of the hero's recommended build, in order. Owned recipes satisfy their entry and the
## earlier entries of their parts; owned basic items satisfy the earliest matching entry.
func build_needs(h: Hero = null) -> Array:
	if h == null:
		h = hero
	var build: Array = h.data["build"]
	var n := build.size()
	var sat := []
	sat.resize(n)
	sat.fill(false)
	var owned := []
	for it in h.items:
		owned.append(it["id"])
	# advanced items: match the latest entry, and the entries of the parts they were built from
	for i in range(n - 1, -1, -1):
		if sat[i] or not DB.ITEMS.get(build[i], {}).has("from"):
			continue
		var k := owned.find(build[i])
		if k >= 0:
			owned.remove_at(k)
			sat[i] = true
			_satisfy_parts(build[i], i, build, sat)
	# basic items: match the earliest open entry
	for i in n:
		if sat[i]:
			continue
		var k2 := owned.find(build[i])
		if k2 >= 0:
			owned.remove_at(k2)
			sat[i] = true
	var needs := []
	for i in n:
		if not sat[i]:
			needs.append(build[i])
	return needs


func _satisfy_parts(id: String, before: int, build: Array, sat: Array) -> void:
	for f in DB.ITEMS.get(id, {}).get("from", []):
		for j in range(before - 1, -1, -1):
			if not sat[j] and build[j] == f:
				sat[j] = true
				_satisfy_parts(f, j, build, sat)
				break


func _price_with(id: String, owned: Array) -> int:
	var d: Dictionary = DB.ITEMS.get(id, {})
	var c: int = d.get("cost", 0)
	for f in d.get("from", []):
		var i := owned.find(f)
		if i >= 0:
			owned.remove_at(i)
		else:
			c += _price_with(f, owned)
	return c


func _consume_components(id: String, owned: Array, h: Hero = null) -> Array:
	# returns list of inventory indices consumed (recursively)
	if h == null:
		h = hero
	var used := []
	var d: Dictionary = DB.ITEMS.get(id, {})
	for f in d.get("from", []):
		var found := -1
		for i in h.items.size():
			if h.items[i]["id"] == f and not used.has(i) and not owned.has(i):
				found = i
				break
		if found >= 0:
			used.append(found)
			owned.append(found)
		else:
			used.append_array(_consume_components(f, owned, h))
	return used


## Returns "" on success, or a reason.
func can_buy(id: String) -> String:
	if not DB.ITEMS.has(id):
		return "Unknown item"
	var d: Dictionary = DB.ITEMS[id]
	if not shop_open_allowed():
		return "Shop is only open in camp"
	var price := buy_price(id)
	if gold < price:
		return "Not enough gold"
	if id == "phoenix_feather" and feathers >= 1:
		return "Only one per run"
	if d.get("noslot", false):
		return ""
	if d.get("boots", false):
		var ok_upgrade: bool = id == "wayfarer_treads" and hero.has_item("runners_boots")
		if hero.has_boots() and not ok_upgrade:
			return "Only one boots item"
	if d.get("kind") == "consumable":
		for it in hero.items:
			if it["id"] == id and int(it.get("charges", 1)) < int(d.get("stack", 1)):
				return ""
	var used := _consume_components(id, [])
	var slots_after := hero.items.size() - used.size() + 1
	if slots_after > 6:
		return "Inventory full (sell something)"
	return ""


func buy(id: String, choice := "") -> String:
	var why := can_buy(id)
	if why != "":
		toast(why, Art.palette.get("danger", Color.RED))
		return why
	var d: Dictionary = DB.ITEMS[id]
	var price := buy_price(id)
	gold -= price
	if id == "tome_of_might":
		hero.bonus[hero.data["primary"]] += 5.0
		hero.recalc()
		fx("level_up", {"pos": hero.pos})
	elif id == "phoenix_feather":
		feathers += 1
		lives += 1
		fx("heal", {"pos": hero.pos})
	else:
		var stacked := false
		if d.get("kind") == "consumable":
			for it in hero.items:
				if it["id"] == id and int(it.get("charges", 1)) < int(d.get("stack", 1)):
					it["charges"] = int(it.get("charges", 1)) + 1
					stacked = true
					break
		if not stacked:
			var used := _consume_components(id, [])
			used.sort()
			used.reverse()
			for i in used:
				hero.items.remove_at(i)
			var entry := {"id": id, "charges": 1, "cd": 0.0}
			if id == "sage_circlet":
				entry["choice"] = choice if choice in ["int", "agi"] else ("agi" if hero.data["primary"] == "agi" else "int")
			hero.items.append(entry)
		hero.recalc()
	Audio.play("buy")
	return ""


func sell(idx: int) -> void:
	if idx < 0 or idx >= hero.items.size() or not shop_open_allowed():
		return
	var it: Dictionary = hero.items[idx]
	var refund := int(DB.item_total_cost(it["id"]) * 0.5) * int(it.get("charges", 1))
	gold += refund
	hero.items.remove_at(idx)
	hero.recalc()
	Audio.play("buy")


# ---------------------------------------------------------------- training grounds (stat upgrades)
func upgrade_rank(id: String) -> int:
	return int(hero.train.get(id, 0))


func upgrade_price(id: String) -> int:
	return DB.upgrade_cost(id, upgrade_rank(id))


## Returns "" when the next rank can be bought now, or a reason.
func can_upgrade(id: String) -> String:
	if not DB.UPGRADES.has(id):
		return "Unknown upgrade"
	var d: Dictionary = DB.UPGRADES[id]
	if wave < int(d["wave"]):
		return "Opens at wave %d" % int(d["wave"])
	if d.has("max") and upgrade_rank(id) >= int(d["max"]):
		return "Fully trained"
	if not shop_open_allowed():
		return "Shop is only open in camp"
	if gold < upgrade_price(id):
		return "Not enough gold"
	return ""


func buy_upgrade(id: String) -> String:
	var why := can_upgrade(id)
	if why != "":
		toast(why, Art.palette.get("danger", Color.RED))
		return why
	gold -= upgrade_price(id)
	hero.train[id] = upgrade_rank(id) + 1
	hero.recalc()
	fx("level_up", {"pos": hero.pos})
	Audio.play("buy")
	return ""


# ---------------------------------------------------------------- phases
func _tick_prep(dt: float) -> void:
	if not Game.paused_by_shop:
		prep_t -= dt
	if prep_t <= 0.0:
		start_wave()


func skip_prep() -> void:
	if phase == "prep":
		prep_t = 0.0


func start_wave() -> void:
	if phase != "prep":
		return
	if duel.ladder():
		# Duel Ladder: every "wave" is the next duel
		duel.accept()
		return
	duel.on_wave_start()
	phase = "wave"
	Game.crumb("wave start")
	wave_time = 0.0
	wave_died = false
	wave_gold = 0
	pit_enraged = false
	warders.clear()
	chanters.clear()
	drummers.clear()
	barrels.reset()
	arena.reset()
	hero.aegis_ready = true
	max_wave_reached = maxi(max_wave_reached, wave)
	if hud and hud.has_method("close_shop"):
		hud.close_shop()
	if delve:
		_start_depth()
		return
	_teleport_hero(DB.ARENA_SPAWN)
	hero.in_camp = false
	if hero.kit:
		hero.kit.on_wave_start()
	_place_companions(DB.ARENA_SPAWN, false)
	for c in companions:
		c.aegis_ready = true
		as_unit(c, func(): c.kit.on_wave_start())
	# build the spawn queue
	spawn_queue.clear()
	captain = null
	echoes.clear()
	gauntlet_i = 0
	var info := wave_info()
	wave_rule = info.get("rule", "")
	var bursts := Modes.wave_bursts(wave)
	var extra := float(cfg.get("extra", 0.0))
	if extra > 0.0:
		# Daily Run "Swarm": more of the same mix
		for b in bursts:
			var us: Array = b["units"]
			var add := int(round(us.size() * extra))
			for i in add:
				us.append(us[i % us.size()])
	var t := 1.0
	for i in bursts.size():
		var b: Dictionary = bursts[i]
		t += float(b["delay"])
		var k := 0
		var gate: Vector3 = Maps.gates()[b["gate"]]
		for kind in b["units"]:
			spawn_queue.append({"t": t + k * 0.16, "kind": kind, "gate": gate})
			k += 1
		# the captain leads the second burst in
		if i == mini(1, bursts.size() - 1) and info.get("captain", "") != "":
			spawn_queue.append({"t": t + 0.5, "kind": info["captain"], "gate": gate, "captain": true})
	boss_title = ""
	var bk := boss_kind()
	if bk != "":
		boss_title = Modes.boss_title(wave)
		if bk == "matron":
			spawn_queue.append({"t": 2.0, "kind": bk, "gate": Vector3(-6, 0, -14)})
			spawn_queue.append({"t": 2.0, "kind": bk, "gate": Vector3(6, 0, -14), "tint": true})
		else:
			spawn_queue.append({"t": 2.0, "kind": bk, "gate": Vector3(0, 0, -13)})
		banner_requested.emit("Wave %d" % wave, "Boss: " + boss_title)
		var hw: int = {"pit_brute": 5, "matron": 10, "hollow_choir": 15, "warden": 20}.get(bk, wave)
		schedule(2.6, toast.bind(DB.BOSS_HINTS.get(hw, ""), Art.palette.get("gold", Color.GOLD)))
		Audio.play("boss")
	else:
		var sub := String(info.get("name", "Survive!"))
		if wave_rule != "":
			sub += "  ·  " + String(DB.WAVE_RULES[wave_rule]["name"])
		banner_requested.emit("Wave %d" % wave, sub)
		if wave_rule != "":
			schedule(2.6, toast.bind(String(info.get("desc", "")), DB.WAVE_RULES[wave_rule]["color"]))
		Audio.play("wave")
		schedule(3.0, hint_once.bind("stacks", "Barrel stacks: smash your way in (tap or push into the barrels) and dig a corridor. Foes can only follow you single file."))
	spawn_queue.sort_custom(func(a, b): return a["t"] < b["t"])
	# --arena=topple|crumble: force the boss-fight arena changes in any wave (screenshots, crash soaks)
	match Game.arg("arena", ""):
		"topple":
			schedule(3.0, arena.topple.bind(0, Vector3(0.3, 0, -1), null))
			schedule(5.0, arena.topple.bind(2, Vector3(-1, 0, 0.4), null))
		"crumble":
			schedule(3.0, arena.crumble)
			schedule(12.0, arena.crumble)


func _tick_wave(dt: float) -> void:
	wave_time += dt
	if delve:
		delve.tick(dt)   # cleared when the guardian falls; no enrage while exploring
		return
	var alive_n := 0
	for e in enemies:
		if e.alive:
			alive_n += 1
	while spawn_queue.size() > 0 and spawn_queue[0]["t"] <= wave_time:
		if alive_n >= MAX_ENEMIES:
			break
		var s: Dictionary = spawn_queue.pop_front()
		var g: Vector3 = s["gate"]
		var jitter := Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
		var inward := _flat(-g).normalized() * rng.randf_range(0.0, 1.5)
		var e: Enemy = spawn_enemy(s["kind"], arena.gate_point(g + jitter + inward))
		if s.get("tint", false):
			e.set_tint(Color(0.75, 0.85, 1.25))
			e.twin_index = 1
		elif s.get("captain", false):
			e.make_captain()
			captain = e
			fx("teleport", {"pos": e.pos})
			toast("%s leads the wave!" % e.display_name, Art.palette.get("gold", Color.GOLD))
		else:
			_roll_elite(e)
		if e.is_boss:
			Game.crumb("boss spawn %s #%d" % [e.kind, e.twin_index])
			fx("teleport", {"pos": e.pos})
			shake(0.4)
		alive_n += 1
	if spawn_queue.is_empty() and alive_n == 0 and wave_time > 1.5:
		_wave_cleared()
		return
	if not pit_enraged and alive_n > 0 and wave_time >= DB.enrage_time(wave):
		_enrage()


## Delve: build this depth (scripts/delve.gd) and send the hero down. The guardian waits in the lair.
func _start_depth() -> void:
	spawn_queue.clear()
	captain = null
	echoes.clear()
	gauntlet_i = 0
	wave_rule = ""
	boss_title = ""
	delve.begin(wave)
	_teleport_hero(delve.start_pos)
	hero.face(Vector3(0, 0, -1))
	hero.in_camp = false
	if hero.kit:
		hero.kit.on_wave_start()
	var info := wave_info()
	banner_requested.emit("Depth %d" % Delve.depth_of(wave), Delve.depth_name(wave))
	schedule(2.6, toast.bind(String(info.get("desc", "")), Art.palette.get("gold", Color.GOLD)))
	Audio.play("wave")


## The wave dragged on: everything still alive hits harder and moves faster.
func _enrage() -> void:
	pit_enraged = true
	shake(0.5)
	Audio.play("boss")
	banner_requested.emit("The Pit grows restless", "Enemies are enraged! Finish them fast")
	for e in enemies:
		if e.alive:
			e.flash(Color(1.0, 0.3, 0.2))


## Final gauntlet: spawn the echo(es) of an earlier boss while the Warden stands back.
func start_echo(step: Dictionary) -> void:
	var kind: String = step["boss"]
	var spots := [Vector3(-6, 0, -10), Vector3(6, 0, -10)] if kind == "matron" else [Vector3(0, 0, -9)]
	for i in spots.size():
		var e: Enemy = spawn_enemy(kind, spots[i])
		e.max_hp *= float(step["hp"])
		e.hp = e.max_hp
		e.display_name = "Echo of " + e.display_name
		if i == 1:
			e.set_tint(Color(0.75, 0.85, 1.25))
			e.twin_index = 1
		echoes.append(e)
		fx("teleport", {"pos": e.pos})
	boss_title = step["title"]
	shake(0.6)
	Audio.play("boss")
	banner_requested.emit("The Warden withdraws", step["title"])
	schedule(2.4, toast.bind(DB.BOSS_HINTS.get({"pit_brute": 5, "matron": 10, "hollow_choir": 15}.get(kind, 20), ""), Art.palette.get("gold", Color.GOLD)))


func _echo_died() -> void:
	for e in echoes:
		if e.alive:
			return
	echoes.clear()
	boss_units = boss_units.filter(func(b): return b.alive)
	boss_title = DB.BOSS_TITLES.get(wave, boss_title)
	for b in boss_units:
		if b is Boss and (b as Boss).withdrawn:
			(b as Boss).return_from_gauntlet()


func _wave_cleared() -> void:
	phase = "clear"
	phase_t = 2.2
	var bonus := DB.wave_clear_gold(wave)
	if boss_title != "":
		bonus += DB.boss_gold(wave)
		stats["bosses"] += 1
	bonus = int(round(bonus * gold_scale))
	waves_cleared += 1
	_log_wave("clear")
	Game.crumb("wave cleared")
	var flawless := 0
	if not wave_died:
		flawless = int(round((wave_gold + bonus) * 0.10))
	add_gold(bonus + flawless)
	var sub := "+%d gold" % (bonus + flawless)
	if flawless > 0:
		sub += "  (flawless +%d)" % flawless
	fx("gold", {"pos": hero.pos + Vector3(0, 2, 0), "amount": bonus + flawless})
	for u in Profile.on_wave_cleared(self, boss_title != ""):
		schedule(1.2, toast.bind("Unlocked: %s!" % u, Art.palette.get("gold", Color.GOLD)))
	if wave >= DB.TOTAL_WAVES and not cfg.get("endless", false):
		banner_requested.emit("Victory!", "The Undercroft is silent" if delve else "The Pit is silent")
		phase = "victory_wait"
		schedule(2.5, _end_run.bind("victory"))
		return
	if wave == DB.TOTAL_WAVES:
		banner_requested.emit("The Warden falls!", "Endless: the Pit keeps coming")
		Audio.play("victory")
		return
	banner_requested.emit(("Depth %d cleared" % Delve.depth_of(wave)) if delve else ("Wave %d cleared" % wave), sub)
	Audio.play("clear")


func _return_to_camp() -> void:
	Game.crumb("return to camp")
	wave += wave_step
	_clear_arena(false)
	if hero.kit:
		hero.kit.on_wave_end()
	_teleport_hero(DB.CAMP_SPAWN)
	hero.in_camp = true
	_companions_to_camp()
	phase = "prep"
	prep_t = DB.PREP_TIME
	weather.roll_for(wave)
	duel.on_prep()
	Game.on_prep()
	_training_hint()
	_save_progress()


## Tells the player once when the shop's Training tab opens new upgrades.
func _training_hint() -> void:
	var opened := []
	for id in DB.UPGRADE_ORDER:
		var uw := int(DB.UPGRADES[id]["wave"])
		if uw <= wave and uw > wave - wave_step:
			opened.append(DB.UPGRADES[id]["name"])
	if opened.is_empty():
		return
	var first := int(DB.UPGRADES[DB.UPGRADE_ORDER[0]]["wave"])
	var text := ("Training is open in the shop: %s" if first <= wave and first > wave - wave_step else "New Training upgrades: %s") % ", ".join(opened)
	schedule(3.0, hint_once.bind("train_%d" % wave, text))


## Saves the run in camp so it can be continued after the app is closed (not Practice or Training).
func _save_progress() -> void:
	if mode in ["practice", "training"] or result != "":
		return
	Profile.save_run(snapshot())


func _after_death() -> void:
	# leftover enemies are cleared and the same wave is fought again
	_clear_arena(true)
	if hero.kit:
		hero.kit.on_wave_end()
	hero.alive = true
	hero.dead = false
	hero.hp = hero.max_hp
	hero.mana = hero.max_mana
	hero.shield = 0.0
	hero.slow_t = 0.0
	hero.stun_t = 0.0
	hero.burn_t = 0.0
	_teleport_hero(DB.CAMP_SPAWN)
	# the model is still in its death pose (dead + dissolved); "spawn" revives it and rises it out of the ground
	hero.set_state("spawn", true)
	hero.in_camp = true
	_companions_to_camp()
	phase = "prep"
	prep_t = DB.PREP_TIME
	weather.roll_for(wave)
	duel.on_prep()
	if delve:
		banner_requested.emit("Respawned", "Depth %d: try again" % Delve.depth_of(wave))
	else:
		banner_requested.emit("Respawned", ("Boss wave %d: try again" % wave) if boss_kind() != "" else ("Wave %d: try again" % wave))
	Game.on_prep()
	_save_progress()


## Back in camp: allies end the wave, spend their share of the wave's gold and get back on their feet.
func _companions_to_camp() -> void:
	for c in companions:
		if not c.dead:
			as_unit(c, func(): c.kit.on_wave_end())
		c.purse += int(wave_gold * DB.ALLY_GOLD_SHARE)
		kit_out(c)
	_place_companions(DB.CAMP_SPAWN, true)


func _clear_arena(fx_burst: bool) -> void:
	for e in enemies:
		if e.alive and e is Enemy:
			e.alive = false
			e.clear_mark()
			e.on_removed()
			if fx_burst:
				fx("death_burst", {"pos": e.pos, "size": e.radius * 2.0})
			if e.node and is_instance_valid(e.node):
				e.node.queue_free()
			e.node = null
	enemies.clear()
	boss_units.clear()
	captain = null
	echoes.clear()
	warders.clear()
	chanters.clear()
	drummers.clear()
	pit_enraged = false
	arena.reset()
	for p in projs:
		_release_proj(p)
	projs.clear()
	for w in walls:
		fx_stop(w["fx"])
	walls.clear()
	for pl in pools:
		fx_stop(pl["fx"])
	pools.clear()
	hazards.clear()
	weather.clear_patches()
	spawn_queue.clear()
	timers.clear()
	if delve:
		delve.clear()


func _teleport_hero(p: Vector3) -> void:
	_teleport_unit(hero, p)
	cam_focus = p
	Audio.play("teleport")


func _teleport_unit(h: Hero, p: Vector3) -> void:
	fx("teleport", {"pos": h.pos})
	h.pos = p
	h.face(Vector3(0, 0, -1))
	h.pull_t = 0.0
	h.knock = Vector3.ZERO
	h.focus = null
	h.atk_target = null
	h.move_input = Vector2.ZERO
	if h.node and is_instance_valid(h.node):
		h.node.position = p
		h.node.rotation.y = 0.0
	if h.kit:
		as_unit(h, func(): h.kit.on_teleport(p))
	fx("teleport", {"pos": p})


func _end_run(res: String) -> void:
	if result != "":
		return
	result = res
	phase = res
	Game.crumb("run ended: " + res)
	if res == "victory":
		max_wave_reached = Duel.LADDER_ROUNDS if duel.ladder() else DB.TOTAL_WAVES
		hero.set_state("idle", true)
	end_info = Profile.on_run_ended(self)
	Audio.play("victory" if res == "victory" else "defeat")
	_sync_state()
	run_ended.emit(res)


func forfeit() -> void:
	if result == "":
		result = "quit"
		phase = "defeat"
		_sync_state()


# ---------------------------------------------------------------- camera & state
func _update_camera(delta: float) -> void:
	if camera == null:
		return
	# lean the view toward the arena centre so more of the fight is on screen near the walls
	var target := hero.pos
	if not hero.in_camp and delve == null:
		var c := Vector3(0, 0, 0)
		target = hero.pos + (_flat(c - hero.pos)).limit_length(12.0) * 0.18
	var k := 1.0 - exp(-7.0 * delta)
	cam_focus = cam_focus.lerp(target, k)
	var want_zoom := 1.18 if (boss_units.size() > 0 and phase == "wave") else 1.0
	cam_zoom = lerpf(cam_zoom, want_zoom, 1.0 - exp(-1.5 * delta))
	var off := Vector3(0, 15, 11.5) * cam_zoom
	var sh := Vector3.ZERO
	if shake_amt > 0.0:
		sh = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake_amt * 0.35
		shake_amt = maxf(0.0, shake_amt - delta * 2.5)
	camera.position = cam_focus + off + sh
	if weather.vis and weather.vis.has_method("follow"):
		weather.vis.follow(cam_focus)
	camera.look_at(cam_focus + sh * 0.5 + Vector3(0, 0.5, 0), Vector3.UP)


func screen_to_ground(sp: Vector2) -> Vector3:
	if camera == null:
		return Vector3.ZERO
	var o := camera.project_ray_origin(sp)
	var d := camera.project_ray_normal(sp)
	if absf(d.y) < 0.0001:
		return o
	var t := -o.y / d.y
	return o + d * t


func _sync_state() -> void:
	var alive_n := 0
	for e in enemies:
		if e.alive:
			alive_n += 1
	var s: Dictionary = Game.state
	s["phase"] = phase
	s["wave"] = wave
	s["lives"] = lives
	s["gold"] = gold
	s["level"] = hero.level
	s["enemies_alive"] = alive_n
	s["hero"] = hero_id
	s["hp"] = hero.hp
	s["max_hp"] = hero.max_hp
	s["prep_t"] = prep_t
	s["time"] = run_time


func boss_hp() -> Vector2:
	var cur := 0.0
	var mx := 0.0
	for b in boss_units:
		if b is Boss and (b as Boss).withdrawn:
			continue
		if b.alive:
			cur += b.hp
		mx += b.max_hp
	return Vector2(cur, mx)


func _exit_tree() -> void:
	if Art.has_method("set_fx_root"):
		Art.set_fx_root(null)
