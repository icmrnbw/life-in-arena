class_name Enemy
extends Unit
## Regular enemies: gnawer, shieldbearer, hexcaster, burrower, bloater, choir_add.

var data: Dictionary
var wave := 1
var xp_val := 0.0
var gold_val := 0.0
var no_reward := false
var burrowed := false
var emerge_t := -1.0
var above_t := 0.0
var dust_t := 0.0
var twin_index := 0
var turn_rate := 12.0
var display_name := ""


func init_enemy(k: String, w: int, r: Run) -> void:
	run = r
	kind = k
	team = 1
	wave = w
	data = DB.ENEMIES.get(k, DB.ENEMIES["gnawer"])
	display_name = data.get("name", k)
	is_boss = data.get("boss", false)
	var hm := DB.hp_mult(w)
	var dm := DB.dmg_mult(w)
	max_hp = float(data["hp"]) * hm
	hp = max_hp
	atk_dmg = float(data["dmg"]) * dm
	atk_time = data["atk_time"]
	atk_range = data["range"]
	base_speed = float(data["speed"]) * (1.0 + 0.008 * (w - 1))
	armor = float(data["armor"]) + 0.2 * (w - 1)
	radius = data["radius"]
	xp_val = float(data["xp"]) * DB.xp_mult(w)
	gold_val = float(data["gold"]) * DB.gold_mult(w)
	blocks_front = k == "shieldbearer"
	if k == "shieldbearer":
		turn_rate = 2.4
	atk_cd = randf_range(0.2, 0.8)
	retarget_t = randf() * 0.3


func post_visual() -> void:
	# collision radius stays close to design values even if art differs
	radius = clampf(radius, float(data["radius"]) * 0.7, float(data["radius"]) * 1.4)
	if kind == "burrower":
		burrowed = true
		untargetable = true
		collides = false
		if node:
			node.visible = false


func damage_taken_mult() -> float:
	return 1.0


func on_death() -> void:
	if kind == "bloater":
		var dps := 18.0 * DB.dmg_mult(wave)
		run.add_pool(pos, 3.0, dps, 5.0)
		run.fx("death_burst", {"pos": pos, "size": 3.0, "color": Color(0.5, 0.9, 0.3)})


func on_removed() -> void:
	pass


func pick_target() -> Unit:
	if taunt_target != null and taunt_target.alive and taunt_t > 0.0:
		return taunt_target
	var best: Unit = null
	var bd := 1e9
	var h := run.hero
	if h.alive and not h.dead and not h.in_camp:
		best = h
		bd = run._flat(h.pos - pos).length() * 0.9
		# casters and ambushers go for the hero
		if (kind == "hexcaster" and bd < 13.0) or kind == "burrower":
			return h
	for a in run.allies:
		if not a.alive or not a.targetable:
			continue
		var d := run._flat(a.pos - pos).length()
		if a.kind == "ember_totem":
			d += 2.0
		if d < bd:
			bd = d
			best = a
	return best


func tick(dt: float) -> void:
	tick_status(dt)
	if stun_t > 0.0:
		return
	if run.forced_motion(self, dt):
		return
	retarget_t -= dt
	if retarget_t <= 0.0 or target == null or not target.alive or (taunt_t > 0.0 and target != taunt_target):
		retarget_t = 0.35
		target = pick_target()
	if target == null:
		if not burrowed:
			set_state("idle")
		return
	if kind == "hexcaster":
		_ai_ranged(dt)
	elif kind == "burrower" and burrowed:
		_ai_burrow(dt)
	else:
		if kind == "burrower":
			above_t += dt
			if above_t > 8.0 and edge_dist(target) > 9.0 and atk_wind <= 0.0 and run.wave_time < 90.0:
				_burrow()
				return
		_ai_melee(dt)


func turn_toward(dir: Vector3, dt: float) -> void:
	dir.y = 0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	var a := atan2(facing.x, facing.z)
	var b := atan2(dir.x, dir.z)
	var diff := wrapf(b - a, -PI, PI)
	var step := clampf(diff, -turn_rate * dt, turn_rate * dt)
	var na := a + step
	facing = Vector3(sin(na), 0, cos(na))


func _ai_melee(dt: float) -> void:
	var t := target
	if atk_wind > 0.0:
		atk_wind -= dt
		turn_toward(t.pos - pos, dt)
		if atk_wind <= 0.0 and t.alive and edge_dist(t) <= atk_range + 0.8:
			run.damage(t, atk_dmg, self, display_name, "phys", {"melee": true})
		return
	var d := edge_dist(t)
	if d > atk_range:
		var dir := run.steer_dir(self, t.pos)
		run.move_unit(self, dir * speed() * dt)
		turn_toward(dir, dt)
		set_state("run")
		moving = true
	else:
		moving = false
		turn_toward(t.pos - pos, dt)
		if atk_cd <= 0.0:
			atk_cd = atk_time
			atk_wind = 0.32
			set_state("attack")
		else:
			set_state("idle")


func _ai_ranged(dt: float) -> void:
	var t := target
	var d := run._flat(t.pos - pos).length()
	if atk_wind > 0.0:
		atk_wind -= dt
		turn_toward(t.pos - pos, dt)
		if atk_wind <= 0.0 and t.alive:
			run.fire_projectile("hex_bolt", pos + Vector3(0, 1.3, 0), t, Vector3.ZERO, 11.0, atk_dmg, 1, self, display_name,
				{"slow": 0.3, "slow_t": 1.6, "dtype": "magic", "life": 2.0, "color": Color(0.7, 0.4, 1.0)})
		return
	if d > atk_range - 0.5:
		var dir := run.steer_dir(self, t.pos)
		run.move_unit(self, dir * speed() * dt)
		turn_toward(dir, dt)
		set_state("run")
	elif d < 5.0 and run.wave_time < 90.0:
		var away := run._flat(pos - t.pos).normalized()
		# don't back into the wall: slide sideways near the edge
		if Vector2(pos.x, pos.z).length() > DB.ARENA_R - 3.0:
			away = Vector3(-away.z, 0, away.x)
		run.move_unit(self, away * speed() * 0.85 * dt)
		turn_toward(t.pos - pos, dt)
		set_state("run")
		if atk_cd <= 0.0:
			atk_cd = atk_time
			atk_wind = 0.35
			set_state("cast")
	else:
		turn_toward(t.pos - pos, dt)
		if atk_cd <= 0.0:
			atk_cd = atk_time
			atk_wind = 0.35
			set_state("cast")
		else:
			set_state("idle")


func _ai_burrow(dt: float) -> void:
	var t := target
	if emerge_t > 0.0:
		emerge_t -= dt
		if emerge_t <= 0.0:
			_emerge()
		return
	var d := run._flat(t.pos - pos).length()
	if d < 2.6 or run.wave_time > 90.0:
		emerge_t = 0.7
		run.fx_timed("telegraph_circle", {"pos": pos, "radius": 1.9, "duration": 0.7, "color": Color(0.8, 0.5, 0.2)}, 0.7)
		run.add_hazard({"type": "circle", "pos": pos, "r": 1.9, "t": 0.7})
		return
	var dir := run.steer_dir(self, t.pos)
	run.move_unit(self, dir * 7.5 * dt)
	face(dir)
	dust_t -= dt
	if dust_t <= 0.0:
		dust_t = 0.3
		run.fx("hit", {"pos": pos + Vector3(0, 0.1, 0), "color": Color(0.55, 0.4, 0.25)})


func _emerge() -> void:
	burrowed = false
	untargetable = false
	collides = true
	above_t = 0.0
	if node:
		node.visible = true
		node.position = pos
	set_state("spawn", true)
	run.fx("slam", {"pos": pos, "radius": 1.9})
	for u in run.hero_side_targets():
		if run._flat(u.pos - pos).length() <= 1.9 + u.radius:
			run.damage(u, atk_dmg * 1.4, self, display_name, "phys")
	atk_cd = 0.6


func _burrow() -> void:
	burrowed = true
	untargetable = true
	collides = false
	clear_mark()
	run.fx("hit", {"pos": pos, "color": Color(0.55, 0.4, 0.25)})
	if node:
		node.visible = false
