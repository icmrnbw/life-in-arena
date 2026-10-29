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
var elite := ""                # elite affix id (DB.ELITE_AFFIXES), "" = normal
var swings := 0
var bashing := false
var support := false           # Chanter / Drummer: hangs back behind the pack
var pack := -1                 # Delve: index of its pack
var captain := false           # leads the wave: tougher, named, slams every third swing
var bash_r := 1.5
var aura_fx: Node = null
var _immune_t := -10.0
var _matchup_t := -10.0
var _support_goal := Vector3.ZERO
var _support_n := 0
var _support_t := 0.0


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
	armor = float(data["armor"])
	if armor > 0.0:
		armor += 0.2 * (w - 1)   # soft foes (armor below 0) stay soft
	mres = float(data.get("mres", 0.0))
	if r.wave_rule == "ironhide" and not is_boss:
		armor += DB.IRONHIDE_ARMOR
	radius = data["radius"]
	xp_val = float(data["xp"]) * DB.xp_mult(w)
	gold_val = float(data["gold"]) * DB.gold_mult(w)
	blocks_front = k == "shieldbearer"
	support = data.get("support", false)
	if k == "shieldbearer":
		turn_rate = 0.5   # ~29 deg/s: slow enough to circle round at bow range
	if r.wave_rule == "frenzy" and not is_boss:
		atk_time *= 0.85
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
	if DB.AURAS.has(kind) and node:
		var a: Dictionary = DB.AURAS[kind]
		aura_fx = run.fx("buff_aura", {"target": node, "radius": a["radius"], "color": a["color"]})


## Turns this enemy into an elite with `affix` (see DB.ELITE_AFFIXES).
func make_elite(affix: String) -> void:
	var a: Dictionary = DB.ELITE_AFFIXES.get(affix, {})
	if a.is_empty():
		return
	elite = affix
	max_hp *= DB.ELITE_HP_MULT
	hp = max_hp
	atk_dmg *= DB.ELITE_DMG_MULT
	xp_val *= DB.ELITE_REWARD_MULT
	gold_val *= DB.ELITE_REWARD_MULT
	display_name = "%s %s" % [a["name"], display_name]
	if affix == "frenzied":
		base_speed *= 1.35
		atk_time *= 0.7
	set_tint(a["tint"])
	if node:
		node.scale *= 1.18
	radius *= 1.1


## Turns this enemy into the wave's captain (see DB.CAPTAIN_NAMES).
func make_captain() -> void:
	captain = true
	max_hp = DB.captain_hp(wave) * (0.75 if kind == "hexcaster" else (0.6 if support else 1.0)) * run.hp_scale
	hp = max_hp
	atk_dmg *= DB.CAPTAIN_DMG_MULT
	armor += 2.0
	xp_val *= 5.0
	gold_val = 0.0   # paid as a bounty on death (Run.kill)
	bash_r = 2.2
	display_name = DB.CAPTAIN_NAMES.get(kind, "Captain " + display_name)
	set_tint(Color(1.35, 1.1, 0.55))
	if node:
		node.scale *= DB.CAPTAIN_SCALE
	radius *= 1.3


func speed() -> float:
	var s := super.speed()
	if run.pit_enraged:
		s *= DB.ENRAGE_SPEED
	if run.wave_rule == "frenzy" and not is_boss:
		s *= DB.FRENZY_SPEED
	return s


func damage_taken_mult() -> float:
	if run.is_sheltered(self):
		return 0.0
	return DB.WARD_DAMAGE_TAKEN if run.is_warded(self) else 1.0


## Floating "Immune" when the hero hits something a Chanter protects (rate-limited per enemy).
func show_immune() -> void:
	if run.run_time - _immune_t < 1.0 or run.run_time - run.immune_shown_t < 0.35:
		return
	_immune_t = run.run_time
	run.immune_shown_t = run.run_time
	flash(Color(1.0, 0.9, 0.5))
	run.fx("damage_number", {"pos": pos + Vector3(0, 2.0, 0), "text": "Immune", "color": DB.AURAS["chanter"]["color"]})


## Floating "Resisted" / "Weak!" when a hero-side hit lands on this foe's good or bad damage type (rate-limited).
func show_matchup(weak: bool) -> void:
	if run.run_time - _matchup_t < 1.4 or run.run_time - run.immune_shown_t < 0.35:
		return
	_matchup_t = run.run_time
	run.immune_shown_t = run.run_time
	run.fx("damage_number", {"pos": pos + Vector3(0, 2.2, 0), "text": "Weak!" if weak else "Resisted",
		"color": Color(1.0, 0.62, 0.25) if weak else Color(0.62, 0.7, 0.82)})
	if not weak:
		var m: Dictionary = DB.MATCHUPS.get(kind, {})
		if m.has("weak") and not m.has("hint"):
			run.hint_once("resist_" + kind, "%s resists that. %s" % [data.get("name", kind),
				"Use spells (magic damage) on it." if m["weak"] == "magic" else "Use weapons (physical damage) on it."])


func on_death() -> void:
	run.fx_stop(aura_fx)
	aura_fx = null
	if elite == "volatile":
		run.volatile_burst(pos, atk_dmg * 3.0)
	if kind == "bloater":
		var dps := 18.0 * DB.dmg_mult(wave)
		run.add_pool(pos, 3.0, dps, 5.0)
		run.fx("death_burst", {"pos": pos, "size": 3.0, "color": Color(0.5, 0.9, 0.3)})


func on_removed() -> void:
	run.fx_stop(aura_fx)
	aura_fx = null


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
	if run.barrels:
		best = run.barrels.detour(self, best)
	return best


func tick(dt: float) -> void:
	tick_status(dt)
	if dormant:
		if not burrowed:
			set_state("idle")
		return
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
	elif support:
		_ai_support(dt)
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
		if atk_wind <= 0.0 and bashing:
			_bash_hit()
		elif atk_wind <= 0.0 and t.alive and edge_dist(t) <= atk_range + 0.8:
			run.damage(t, atk_dmg * _pack_mult(t), self, display_name, "magic" if data.get("magic_hits", false) else "phys", {"melee": true})
		return
	var d := edge_dist(t)
	if d > atk_range:
		var dir := run.steer_dir(self, t.pos)
		var spd := speed()
		if blocks_front:
			# a heavy shield turns slowly: it has to slow down to come round
			spd *= clampf(0.5 + 0.5 * facing.dot(dir), 0.3, 1.0)
		run.move_unit(self, dir * spd * dt)
		turn_toward(dir, dt)
		set_state("run")
		moving = true
	else:
		moving = false
		turn_toward(t.pos - pos, dt)
		if atk_cd <= 0.0 and _body_blocked(t):
			set_state("idle")
		elif atk_cd <= 0.0:
			atk_cd = atk_time
			atk_wind = 0.32
			swings += 1
			var every := 2 if run.wave_rule == "stunning" else 3
			bashing = (kind == "shieldbearer" or captain) and swings % every == 0
			if bashing:
				_bash_start()
			set_state("attack")
		else:
			set_state("idle")


## In a barrel corridor foes queue single file: one can't swing past the foe in front of it.
func _body_blocked(t: Unit) -> bool:
	if t is Barrel or run.barrels == null or run.barrels.cover(t.pos) < 2:
		return false
	var to := run._flat(t.pos - pos)
	var d := to.length()
	if d < 0.01:
		return false
	var dir := to / d
	for e in run.enemies:
		if e == self or not e.alive or not e.collides:
			continue
		var rel := run._flat(e.pos - pos)
		var along := rel.dot(dir)
		if along > 0.1 and along < d and (rel - dir * along).length() < e.radius * 0.9:
			return true
	return false


## Gnawers hunt in packs: +8% damage per other gnawer next to the victim (up to +24%).
func _pack_mult(t: Unit) -> float:
	if kind != "gnawer":
		return 1.0
	var n := 0
	for e in run.enemies:
		if e != self and e.alive and e.kind == "gnawer" and run._flat(e.pos - t.pos).length() < 2.6:
			n += 1
			if n >= 3:
				break
	return 1.0 + 0.08 * n


## Shieldbearer shield bash (every 3rd swing): telegraphed, stuns and knocks back.
func _bash_center() -> Vector3:
	return pos + facing * (radius + 0.9)


func _bash_start() -> void:
	atk_wind = 0.75
	var c := _bash_center()
	run.fx_timed("telegraph_circle", {"pos": c, "radius": bash_r, "duration": 0.75, "color": Color(0.7, 0.8, 1.0)}, 0.75)
	run.add_hazard({"type": "circle", "pos": c, "r": bash_r, "t": 0.8})


func _bash_hit() -> void:
	bashing = false
	var c := _bash_center()
	run.fx("slam", {"pos": c, "radius": bash_r})
	for u in run.hero_side_targets():
		var off := run._flat(u.pos - c)
		if off.length() <= bash_r + u.radius * 0.5:
			run.damage(u, atk_dmg * 1.3, self, display_name, "phys", {"melee": true})
			if u.alive:
				u.stun_t = maxf(u.stun_t, 0.7)
			if u == run.hero and kind == "shieldbearer":
				run.hint_once("bash", "Shield bash! Shieldbearers stun every third swing.")


func _ai_ranged(dt: float) -> void:
	var t := target
	var d := run._flat(t.pos - pos).length()
	if atk_wind > 0.0:
		atk_wind -= dt
		turn_toward(t.pos - pos, dt)
		if atk_wind <= 0.0 and t.alive:
			# slow, lazily homing bolts: sidestep them or put a pillar or barrels between you and the caster
			var bolt := {"slow": 0.3, "slow_t": 1.6, "hex": DB.HEX_TIME, "dtype": "magic", "life": DB.HEX_BOLT_LIFE,
				"turn": DB.HEX_BOLT_TURN, "color": Color(0.7, 0.4, 1.0)}
			run.fire_projectile("hex_bolt", pos + Vector3(0, 1.3, 0), t, Vector3.ZERO, DB.HEX_BOLT_SPEED, atk_dmg, 1, self, display_name, bolt)
			if captain:
				# the Matriarch throws a fan: two unguided side bolts
				var d0 := run._flat(t.pos - pos).normalized()
				for ang in [-0.35, 0.35]:
					run.fire_projectile("hex_bolt", pos + Vector3(0, 1.3, 0), null, d0.rotated(Vector3.UP, ang), DB.HEX_BOLT_SPEED, atk_dmg * 0.7, 1, self, display_name, bolt)
		return
	if d > atk_range - 0.5:
		var dir := run.steer_dir(self, t.pos)
		run.move_unit(self, dir * speed() * dt)
		turn_toward(dir, dt)
		set_state("run")
	elif d < 5.0 and run.wave_time < 90.0:
		var away := run._flat(pos - t.pos).normalized()
		# don't back into the wall: slide sideways near the edge
		if Vector2(pos.x, pos.z).length() > run.arena_safe_r() - 3.0:
			away = Vector3(-away.z, 0, away.x)
		run.move_unit(self, away * speed() * 0.85 * dt)
		turn_toward(t.pos - pos, dt)
		set_state("run")
		if atk_cd <= 0.0:
			atk_cd = atk_time
			atk_wind = DB.HEX_WINDUP
			flash(Color(0.7, 0.4, 1.0))
			set_state("cast")
	else:
		turn_toward(t.pos - pos, dt)
		if atk_cd <= 0.0:
			atk_cd = atk_time
			atk_wind = DB.HEX_WINDUP
			flash(Color(0.7, 0.4, 1.0))
			set_state("cast")
		else:
			set_state("idle")


## Buffers keep a few metres behind the pack (away from the hero) and back off when the hero closes in.
## With no pack around they just fight.
func _ai_support(dt: float) -> void:
	var t := target
	_support_t -= dt
	if _support_t <= 0.0:
		_support_t = 0.4
		var c := Vector3.ZERO
		var n := 0
		for e in run.enemies:
			if e == self or not e.alive or e.untargetable or (e as Enemy).support or e.is_boss:
				continue
			if run._flat(e.pos - pos).length() < 14.0:
				c += e.pos
				n += 1
		_support_n = n
		if n > 0:
			c /= n
			var back := run._flat(c - t.pos)
			_support_goal = c + (back.normalized() if back.length() > 0.1 else Vector3(0, 0, -1)) * 2.5
	if _support_n == 0 or t is Barrel or atk_wind > 0.0 or edge_dist(t) <= atk_range + 0.2 or run.wave_time > 50.0:
		_ai_melee(dt)
		return
	var d := run._flat(t.pos - pos).length()
	var mv := Vector3.ZERO
	if d < 3.2:
		mv = run._flat(pos - t.pos).normalized()
		if Vector2(pos.x, pos.z).length() > run.arena_safe_r() - 3.0:
			mv = Vector3(-mv.z, 0, mv.x)
	elif run._flat(_support_goal - pos).length() > 1.0:
		mv = run.steer_dir(self, _support_goal)
	if mv.length() > 0.01:
		run.move_unit(self, mv * speed() * (0.8 if d < 3.2 else 1.0) * dt)
		turn_toward(mv, dt)
		set_state("run")
		moving = true
	else:
		moving = false
		turn_toward(t.pos - pos, dt)
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
