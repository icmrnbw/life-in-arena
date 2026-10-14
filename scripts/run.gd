class_name Run
extends Node3D
## One play-through: world, units, phases (prep / wave), economy, combat resolution.

signal run_ended(result: String)
signal toast_requested(text: String, color: Color)
signal banner_requested(text: String, sub: String)

const MAX_ENEMIES := 80
const SUBSTEP := 1.0 / 30.0

var hero_id := "ashwarden"
var hero: Hero
var enemies: Array = []
var allies: Array = []
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
var stats := {"kills": 0, "gold_earned": 0, "deaths": 0, "damage_by": {}, "damage_taken": 0.0, "bosses": 0}
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


func setup(id: String, start_wave := 1) -> void:
	hero_id = id if DB.HEROES.has(id) else "ashwarden"
	wave = clampi(start_wave, 1, DB.TOTAL_WAVES)
	name = "Run"


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var env_parent := Node.new()
	env_parent.name = "Env"
	add_child(env_parent)
	if Art.has_method("setup_environment"):
		Art.setup_environment(env_parent)
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var res = Art.build_world(world) if Art.has_method("build_world") else {}
	if res is Dictionary:
		if res.get("shop") is Node3D:
			shop_node = res["shop"]
		if res.get("fountain") is Node3D:
			fountain_node = res["fountain"]
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

	hero = Hero.new()
	hero.run = self
	hero.init_hero(hero_id)
	hero.setup_visual(make_visual(hero_id))
	hero.radius = clampf(hero.radius, 0.35, 0.8)
	var kit_script = load("res://scripts/kits/%s_kit.gd" % hero_id)
	hero.kit = kit_script.new()
	hero.kit.setup(hero, self)
	hero.pos = DB.CAMP_SPAWN
	hero.sync_visual()
	cam_focus = hero.pos

	if wave > 1:
		_apply_start_wave(wave)

	var hud_script = load("res://scripts/ui/hud.gd")
	hud = hud_script.new()
	add_child(hud)
	hud.setup(self)

	if Game.autoplay:
		var bot_script = load("res://scripts/bot.gd")
		bot = bot_script.new()
		add_child(bot)
		bot.setup(self)

	phase = "prep"
	prep_t = DB.FIRST_PREP_TIME if wave == 1 else DB.PREP_TIME
	hero.in_camp = true
	Game.on_run_started(self)
	banner_requested.emit("Prepare", "Wave %d begins soon. Visit the shop and fountain." % wave)
	_sync_state()


func _apply_start_wave(w: int) -> void:
	var lvl := clampi(int(round(1.0 + (w - 1) * 0.95)), 1, 20)
	while hero.level < lvl:
		hero.add_xp(DB.xp_to_next(hero.level))
	gold = DB.START_GOLD + 430 * (w - 1)
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
	if kind == "gnawer" and v is Node3D:
		v.scale *= 1.15   # read better on phones
	units_root.add_child(v)
	return v


# ---------------------------------------------------------------- fx helpers
func fx(fx_name: String, opts: Dictionary) -> Node:
	if not Art.has_method("fx"):
		return null
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
	if Game.settings.get("shake", true):
		shake_amt = maxf(shake_amt, amount)


func toast(text: String, color := Color(1, 1, 1)) -> void:
	toast_requested.emit(text, color)


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
		if not e.alive or e.untargetable:
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


# ---------------------------------------------------------------- spawning
func spawn_enemy(kind: String, p: Vector3, w := -1) -> Enemy:
	var e: Enemy
	if DB.ENEMIES.get(kind, {}).get("boss", false):
		e = Boss.new()
	else:
		e = Enemy.new()
	e.init_enemy(kind, wave if w < 0 else w, self)
	e.pos = Vector3(p.x, 0, p.z)
	e.setup_visual(make_visual(kind))
	e.post_visual()
	var to_center := _flat(-e.pos)
	e.face(to_center if to_center.length() > 0.1 else Vector3(0, 0, 1))
	e.sync_visual()
	e.set_state("spawn", true)
	enemies.append(e)
	if e.is_boss:
		boss_units.append(e)
	return e


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


func damage(t: Unit, amount: float, src: Unit, tag: String, dtype := "phys", opts := {}) -> float:
	if t == null or not t.alive or amount <= 0.0:
		return 0.0
	if t.invuln_t > 0.0:
		return 0.0
	var a := amount
	if dtype == "phys":
		a *= armor_factor(t.armor)
	if t.team == 1 and t is Enemy:
		a *= (t as Enemy).damage_taken_mult()
	if t == hero:
		if Game.god:
			a = 0.0
		if hero.shield > 0.0:
			var absorbed := minf(hero.shield, a)
			hero.shield -= absorbed
			a -= absorbed
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
	if a <= 0.0:
		return 0.0
	t.hp -= a
	t.hurt_at = run_time
	if t.kind != "broodling":
		t.flash(Color(1, 0.35, 0.3) if t.team == 0 else Color(1, 1, 1))
	if src != null and src.team == 0 and t.team == 1:
		var db: Dictionary = stats["damage_by"]
		db[tag] = db.get(tag, 0.0) + a
		var crit: bool = opts.get("crit", false)
		if crit or a >= 30.0 or (a >= 5.0 and rng.randf() < 0.35):
			var col: Color = opts.get("color", Color(1, 0.95, 0.8))
			damage_number(t.pos, a, crit, col)
		if opts.get("attack", false) and src == hero:
			if hero.lifesteal > 0.0:
				heal_unit(hero, a * hero.lifesteal, false)
			if hero.burn_on_hit:
				t.burn_dps = 10.0 + 0.3 * hero.primary_value()
				t.burn_t = 3.0
				t.burn_src = hero
		if opts.has("heal_hero_frac") and hero.alive:
			heal_unit(hero, a * float(opts["heal_hero_frac"]), false)
	if t.hp <= 0.0:
		kill(t, src)
	return a


func heal_unit(u: Unit, amount: float, show := true) -> void:
	if not u.alive or amount <= 0.0:
		return
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
	t.set_state("death", true)
	t.death_t = 1.2
	corpses.append(t)
	if t.team == 1:
		var e := t as Enemy
		e.on_death()
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
		fx("death_burst", {"pos": e.pos, "size": e.radius * 2.0, "color": Art.palette.get("ember", Color.ORANGE)})
		if e.is_boss:
			shake(0.6)
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
		"wt": snappedf(wave_time, 0.1), "hp": snappedf(hero.hp / maxf(1.0, hero.max_hp), 0.01), "items": hero.items.size()})
	set_meta("wave_log", log)


func _hero_died() -> void:
	_log_wave("death")
	hero.dead = true
	hero.set_state("death", true)
	stats["deaths"] += 1
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
				p["dir"] = to.normalized()
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
				_proj_hit(p, u)
				done = true
				break
		if not done:
			for pl in DB.PILLARS:
				if Vector2(pp.x - pl.x, pp.z - pl.z).length() < DB.PILLAR_R:
					done = true
					fx("hit", {"pos": pp})
					break
		if not done and p["life"] <= 0.0:
			done = true
		if not done and Vector2(pp.x, pp.z).length() > DB.ARENA_R + 1.0 and pp.z < 30.0:
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
			fx("hit", {"pos": u.pos + Vector3(0, 1.0, 0) + u.facing * u.radius, "color": Color(0.7, 0.75, 0.85)})
			u.flash(Color(0.6, 0.7, 1.0))
			return
	fx("hit", {"pos": p["pos"], "color": opts.get("color", Art.palette.get("ember", Color.ORANGE))})
	var o := {}
	if opts.has("heal_hero_frac"):
		o["heal_hero_frac"] = opts["heal_hero_frac"]
	if opts.get("attack", false):
		o["attack"] = true
	if opts.has("crit"):
		o["crit"] = opts["crit"]
	damage(u, p["dmg"], p["src"], p["tag"], opts.get("dtype", "magic"), o)
	if opts.has("slow"):
		u.apply_slow(opts["slow"], opts.get("slow_t", 1.5))
	if opts.get("spit_mark", false):
		u.spit_mark_t = 4.0
	if opts.has("aoe"):
		var r: float = opts["aoe"]
		var group: Array = enemies if p["team"] == 0 else hero_side_targets()
		for o2 in group:
			if o2 != u and o2.alive and _flat(o2.pos - u.pos).length() <= r + o2.radius:
				damage(o2, p["dmg"] * 0.6, p["src"], p["tag"], opts.get("dtype", "magic"))
	if p["src"] == hero and hero.kit:
		if opts.get("attack", false):
			hero.kit.on_attack_hit(u)


# ---------------------------------------------------------------- walls & pools
func add_wall(a: Vector3, b: Vector3, dur: float, dps: float, src: Unit, tag: String) -> Dictionary:
	a.y = 0
	b.y = 0
	var w := {"a": a, "b": b, "t": dur, "dps": dps, "src": src, "tag": tag, "tick": 0.0,
		"fx": fx("ash_wall", {"from": a, "to": b, "duration": dur})}
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
		if w["tick"] <= 0.0:
			w["tick"] = 0.25
			var mult := 1.0
			var heal := 0.0
			if hero.kit and hero.kit.has_method("wall_mult"):
				mult = hero.kit.wall_mult()
				heal = hero.kit.empower_heal()
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
	for pl in DB.PILLARS:
		var d := Vector2(p.x - pl.x, p.z - pl.z)
		var minr := DB.PILLAR_R + u.radius
		if d.length() < minr:
			if d.length() < 0.001:
				d = Vector2(1, 0)
			d = d.normalized() * minr
			p.x = pl.x + d.x
			p.z = pl.z + d.y
	var r := Vector2(p.x, p.z).length()
	var lim2 := DB.ARENA_R - u.radius - 0.3
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
	var to := _flat(goal - u.pos)
	var dist := to.length()
	if dist < 0.01:
		return Vector3.ZERO
	var dir := to / dist
	if u.pos.z > 30.0:
		return dir
	for pl in DB.PILLARS:
		var rel := _flat(pl - u.pos)
		var along := rel.dot(dir)
		if along <= 0.0 or along > dist + DB.PILLAR_R:
			continue
		var perp := rel - dir * along
		var clear := DB.PILLAR_R + u.radius + 0.4
		if perp.length() < clear and rel.length() < 7.0:
			# steer to the side away from the pillar center
			var side := -perp.normalized() if perp.length() > 0.01 else Vector3(dir.z, 0, -dir.x)
			var w := 1.0 - clampf((rel.length() - DB.PILLAR_R) / 5.0, 0.0, 1.0)
			dir = (dir + side * (0.6 + 1.2 * w)).normalized()
	return dir


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
	if result != "" and phase in ["victory", "defeat"]:
		_update_camera(delta)
		return
	_num_budget = minf(10.0, _num_budget + delta * 40.0)
	var t0 := Time.get_ticks_usec()
	var n := maxi(1, ceili(delta / SUBSTEP))
	var dt := delta / n
	for i in n:
		_step(dt)
		if result != "":
			break
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
	_update_camera(delta)
	_sync_state()


func _step(dt: float) -> void:
	_step_n += 1
	run_time += dt
	# timers
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
	match phase:
		"prep":
			_tick_prep(dt)
		"wave":
			_tick_wave(dt)
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
	_tick_hero(dt)
	if hero.kit:
		hero.kit.tick(dt)
	for e in enemies:
		if e.alive:
			e.tick(dt)
	_tick_allies_generic(dt)
	_separate(dt)
	_tick_projectiles(dt)
	_tick_walls_pools(dt)
	_tick_burns(dt)
	_tick_corpses(dt)
	if bot:
		bot.tick(dt)


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
		if not a.alive:
			continue
		a.tick_status(dt)
		if a.lifetime > 0.0:
			a.lifetime -= dt
			if a.lifetime <= 0.0:
				remove_ally(a)


# ---------------------------------------------------------------- hero
func _tick_hero(dt: float) -> void:
	var h := hero
	if not h.alive or h.dead:
		return
	h.tick_status(dt)
	# regen
	var regen_mult := 1.0
	h.hp = minf(h.max_hp, h.hp + h.hp_regen * dt * regen_mult)
	h.mana = minf(h.max_mana, h.mana + h.mana_regen * dt)
	var keep := []
	for b in h.regen_buff:
		b["t"] -= dt
		h.hp = minf(h.max_hp, h.hp + b["hp"] * dt)
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
			move_unit(h, v * dt)
			h.face(v)
			moved = true
			if h.focus != null and mi.length() > 0.5:
				h.focus = null
		elif h.focus != null and h.focus.alive and not h.focus.untargetable:
			var d := h.edge_dist(h.focus)
			if d > h.atk_range:
				var dir := steer_dir(h, h.focus.pos)
				move_unit(h, dir * h.speed() * dt)
				h.face(dir)
				moved = true
	h.moving = moved
	if moved:
		h.still_t = 0.0
	else:
		h.still_t += dt
	# attack
	if h.atk_wind > 0.0:
		h.atk_wind -= dt
		if h.atk_wind <= 0.0:
			_hero_attack_resolve()
	elif h.atk_cd <= 0.0 and not h.in_camp:
		var t := _pick_hero_target()
		if t != null:
			h.atk_target = t
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


func _pick_hero_target() -> Unit:
	var h := hero
	var reach := h.atk_range + h.radius
	if h.focus != null and h.focus.alive and not h.focus.untargetable:
		if h.edge_dist(h.focus) <= h.atk_range + 0.3:
			return h.focus
	var best: Unit = null
	var bd := 1e9
	for e in enemies:
		if not e.alive or e.untargetable:
			continue
		var d: float = _flat(e.pos - h.pos).length() - e.radius
		if d <= reach and d < bd:
			bd = d
			best = e
	return best


func _hero_attack_resolve() -> void:
	var h := hero
	var t := h.atk_target
	if t == null or not t.alive or t.untargetable:
		return
	if h.edge_dist(t) > h.atk_range + 1.2:
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
	Audio.play("hit")


## Cast hero skill `slot`. aim: {} for smart cast, else {"point": Vector3, "dir": Vector3}.
func try_cast(slot: int, aim := {}) -> bool:
	var h := hero
	if not h.alive or h.dead or slot < 0 or slot > 3:
		return false
	if h.ranks[slot] <= 0:
		toast("Learn it first (tap +)", Art.palette.get("dim", Color.GRAY))
		return false
	if h.stun_t > 0.0:
		return false
	var kit := h.kit
	if kit.free_cast(slot):
		var a0 := aim if not aim.is_empty() else kit.smart_aim(slot)
		return kit.cast(slot, a0)
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
	Audio.play("cast")
	return true


func rank_up(slot: int) -> bool:
	if hero.rank_up(slot):
		Audio.play("rank")
		return true
	return false


func use_item(idx: int) -> bool:
	var h := hero
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
func build_needs() -> Array:
	var build: Array = hero.data["build"]
	var n := build.size()
	var sat := []
	sat.resize(n)
	sat.fill(false)
	var owned := []
	for it in hero.items:
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


func _consume_components(id: String, owned: Array) -> Array:
	# returns list of inventory indices consumed (recursively)
	var used := []
	var d: Dictionary = DB.ITEMS.get(id, {})
	for f in d.get("from", []):
		var found := -1
		for i in hero.items.size():
			if hero.items[i]["id"] == f and not used.has(i) and not owned.has(i):
				found = i
				break
		if found >= 0:
			used.append(found)
			owned.append(found)
		else:
			used.append_array(_consume_components(f, owned))
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
		hero.bonus[hero.data["primary"]] += 2.0
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
	phase = "wave"
	wave_time = 0.0
	wave_died = false
	wave_gold = 0
	hero.aegis_ready = true
	max_wave_reached = maxi(max_wave_reached, wave)
	if hud and hud.has_method("close_shop"):
		hud.close_shop()
	_teleport_hero(DB.ARENA_SPAWN)
	hero.in_camp = false
	if hero.kit:
		hero.kit.on_wave_start()
	# build the spawn queue
	spawn_queue.clear()
	var bursts := DB.wave_bursts(wave)
	var t := 1.0
	for b in bursts:
		t += float(b["delay"])
		var k := 0
		var gate: Vector3 = DB.GATES[b["gate"]]
		for kind in b["units"]:
			spawn_queue.append({"t": t + k * 0.16, "kind": kind, "gate": gate})
			k += 1
	boss_title = ""
	if DB.BOSS_WAVES.has(wave):
		boss_title = DB.BOSS_TITLES[wave]
		var bk: String = DB.BOSS_WAVES[wave]
		if bk == "matron":
			spawn_queue.append({"t": 2.0, "kind": bk, "gate": Vector3(-6, 0, -14)})
			spawn_queue.append({"t": 2.0, "kind": bk, "gate": Vector3(6, 0, -14), "tint": true})
		else:
			spawn_queue.append({"t": 2.0, "kind": bk, "gate": Vector3(0, 0, -13)})
		banner_requested.emit("Wave %d" % wave, "Boss: " + boss_title)
		schedule(2.6, toast.bind(DB.BOSS_HINTS.get(wave, ""), Art.palette.get("gold", Color.GOLD)))
		Audio.play("boss")
	else:
		banner_requested.emit("Wave %d" % wave, "Survive!")
		Audio.play("wave")
	spawn_queue.sort_custom(func(a, b): return a["t"] < b["t"])


func _tick_wave(dt: float) -> void:
	wave_time += dt
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
		var e: Enemy = spawn_enemy(s["kind"], g + jitter + inward)
		if s.get("tint", false):
			e.set_tint(Color(0.75, 0.85, 1.25))
			e.twin_index = 1
		if e.is_boss:
			fx("teleport", {"pos": e.pos})
			shake(0.4)
		alive_n += 1
	if spawn_queue.is_empty() and alive_n == 0 and wave_time > 1.5:
		_wave_cleared()


func _wave_cleared() -> void:
	phase = "clear"
	phase_t = 2.2
	var bonus := DB.wave_clear_gold(wave)
	if boss_title != "":
		bonus += DB.boss_gold(wave)
		stats["bosses"] += 1
	_log_wave("clear")
	var flawless := 0
	if not wave_died:
		flawless = int(round((wave_gold + bonus) * 0.10))
	add_gold(bonus + flawless)
	var sub := "+%d gold" % (bonus + flawless)
	if flawless > 0:
		sub += "  (flawless +%d)" % flawless
	fx("gold", {"pos": hero.pos + Vector3(0, 2, 0), "amount": bonus + flawless})
	if wave >= DB.TOTAL_WAVES:
		banner_requested.emit("Victory!", "The Pit is silent")
		phase = "victory_wait"
		schedule(2.5, _end_run.bind("victory"))
		return
	banner_requested.emit("Wave %d cleared" % wave, sub)
	Audio.play("clear")


func _return_to_camp() -> void:
	wave += 1
	_clear_arena(false)
	if hero.kit:
		hero.kit.on_wave_end()
	_teleport_hero(DB.CAMP_SPAWN)
	hero.in_camp = true
	phase = "prep"
	prep_t = DB.PREP_TIME
	Game.on_prep()


func _after_death() -> void:
	# leftover enemies are cleared, the wave counts as survived
	_clear_arena(true)
	# boss waves (5/10/15/20) must be beaten; other waves count as survived
	var retry := wave >= DB.TOTAL_WAVES or DB.BOSS_WAVES.has(wave)
	if not retry:
		wave += 1
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
	hero.set_state("idle", true)
	_teleport_hero(DB.CAMP_SPAWN)
	hero.in_camp = true
	phase = "prep"
	prep_t = DB.PREP_TIME
	banner_requested.emit("Respawned", ("Boss wave %d: try again" % wave) if retry else ("Wave %d next" % wave))
	Game.on_prep()


func _clear_arena(fx_burst: bool) -> void:
	for e in enemies:
		if e.alive:
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
	spawn_queue.clear()
	timers.clear()


func _teleport_hero(p: Vector3) -> void:
	fx("teleport", {"pos": hero.pos})
	hero.pos = p
	hero.face(Vector3(0, 0, -1))
	hero.pull_t = 0.0
	hero.knock = Vector3.ZERO
	hero.focus = null
	hero.atk_target = null
	if hero.node and is_instance_valid(hero.node):
		hero.node.position = p
		hero.node.rotation.y = 0.0
	if hero.kit:
		hero.kit.on_teleport(p)
	cam_focus = p
	fx("teleport", {"pos": p})
	Audio.play("teleport")


func _end_run(res: String) -> void:
	if result != "":
		return
	result = res
	phase = res
	if res == "victory":
		max_wave_reached = DB.TOTAL_WAVES
		hero.set_state("idle", true)
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
	if not hero.in_camp:
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
		if b.alive:
			cur += b.hp
		mx += b.max_hp
	return Vector2(cur, mx)


func _exit_tree() -> void:
	if Art.has_method("set_fx_root"):
		Art.set_fx_root(null)
