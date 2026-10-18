class_name HeroKit
extends RefCounted
## Base class for hero skill kits. Subclasses implement cast() and smart_aim().

var hero: Hero
var run: Run


func setup(h: Hero, r: Run) -> void:
	hero = h
	run = r


func speed_mult() -> float:
	return 1.0


func attack_speed_mult() -> float:
	return 1.0


func damage_mult() -> float:
	return 1.0


func cd_rate() -> float:
	return 1.0


func on_rank_up(_slot: int) -> void:
	pass


func rank(slot: int) -> int:
	return hero.ranks[slot]


func free_cast(_slot: int) -> bool:
	return false


func is_ready(slot: int) -> bool:
	return hero.cds[slot] <= 0.0


func start_cooldown(slot: int) -> void:
	hero.cds[slot] = hero.skill_cd(slot)


## Fraction of cooldown remaining (0 = ready), for the HUD.
func cd_frac(slot: int) -> float:
	var full := hero.skill_cd(slot)
	if full <= 0.0:
		return 0.0
	return clampf(hero.cds[slot] / full, 0.0, 1.0)


func cd_left(slot: int) -> float:
	return hero.cds[slot]


## -1 when the skill has no charges.
func charges(_slot: int) -> int:
	return -1


func can_cast(_slot: int) -> bool:
	return true


## A learned, ready skill that still can't be cast (e.g. not enough HP): the button greys out like "no mana".
func blocked(_slot: int) -> bool:
	return false


## Last say on damage the hero is about to take (after armor and shields). Return the new amount.
func incoming_damage(a: float, _src: Unit) -> float:
	return a


## An enemy died (any cause) while this hero is in the run.
func on_enemy_killed(_e: Unit) -> void:
	pass


func cast(_slot: int, _aim: Dictionary) -> bool:
	return false


func after_cast(_slot: int) -> void:
	pass


func smart_aim(_slot: int) -> Dictionary:
	return {}


## Aim indicator description: {type: "circle"|"line"|"wall"|"none", range, radius, width}
func aim_spec(slot: int) -> Dictionary:
	var sid: String = hero.skill_ids[slot]
	var d: Dictionary = DB.SKILLS[sid]
	match d.get("aim", "self"):
		"point":
			return {"type": "circle", "range": d.get("range", 8.0), "radius": d.get("radius", 2.0)}
		"direction":
			return {"type": "line", "range": d.get("range", 6.0), "width": d.get("width", 1.2)}
		"wall":
			return {"type": "wall", "range": d.get("range", 8.0), "length": 6.0}
	return {"type": "none"}


func skill_label(_slot: int) -> String:
	return ""


func override_motion(_dt: float) -> bool:
	return false


## Bot hint: true while the kit is channeling / dashing and the bot should keep its hands off the stick.
func override_motion_active() -> bool:
	return false


## False holds basic attacks (reloading, channeling, ...).
func can_attack() -> bool:
	return true


## Autoplay bot movement profile (see DB.HEROES "bot"); kits with changing ranges override it.
func bot_profile() -> Dictionary:
	return hero.data.get("bot", {})


## Return true if the kit fully handled the basic attack (e.g. a projectile).
func basic_attack(_target: Unit, _dmg: float, _crit: bool) -> bool:
	return false


func on_attack_hit(_target: Unit) -> void:
	pass


func tick(_dt: float) -> void:
	pass


func on_wave_start() -> void:
	pass


func on_wave_end() -> void:
	pass


func on_teleport(_p: Vector3) -> void:
	pass


## HUD meter: {} or {"type": "flow", "value": v, "max": m} / {"type": "brood", "count": n, "cap": c}
func hud_meter() -> Dictionary:
	return {}


## Bot hint: should the autoplay bot cast this skill now?
func bot_wants(_slot: int) -> bool:
	return false


# helpers
func clamp_point(p: Vector3, max_range: float) -> Vector3:
	var off := p - hero.pos
	off.y = 0
	if off.length() > max_range:
		off = off.normalized() * max_range
	var q := hero.pos + off
	return run.resolve_pos(hero, q, hero.pos)


func aim_dir(aim: Dictionary) -> Vector3:
	var d: Vector3 = aim.get("dir", hero.facing)
	d.y = 0
	if d.length() < 0.01:
		d = hero.facing
	return d.normalized()


## Shared minion AI (skeletons, beasts, ...): chase enemies within `leash` of `anchor`, else hold a ring around it.
## Returns the minion's current target (or null).
func tick_minion(m: Unit, dt: float, anchor: Vector3, leash: float, tag: String, idx: int, total: int, as_mult := 1.0) -> Unit:
	if m.stun_t > 0.0 or run.forced_motion(m, dt):
		return m.target
	m.retarget_t -= dt
	if m.retarget_t <= 0.0 or m.target == null or not m.target.alive or m.target.untargetable:
		m.retarget_t = 0.3
		m.target = _minion_target(m, anchor, leash)
	var t: Unit = m.target
	if m.atk_wind > 0.0:
		m.atk_wind -= dt
		if m.atk_wind <= 0.0 and t != null and t.alive and m.edge_dist(t) <= m.atk_range + 0.6:
			run.damage(t, m.atk_dmg, hero, tag, "phys")
		return t
	if t != null:
		if m.edge_dist(t) > m.atk_range:
			var dir := run.steer_dir(m, t.pos)
			run.move_unit(m, dir * m.base_speed * dt)
			m.face(dir)
			m.set_state("run")
		else:
			m.face(t.pos - m.pos)
			if m.atk_cd <= 0.0:
				m.atk_cd = m.atk_time / as_mult
				m.atk_wind = 0.2
				m.set_state("attack")
			else:
				m.set_state("idle")
		return t
	var ang := TAU * float(idx) / maxf(1.0, float(total)) + run.run_time * 0.12
	var spot := anchor + Vector3(cos(ang), 0, sin(ang)) * (1.8 + 0.12 * total)
	var to := run._flat(spot - m.pos)
	if to.length() > 0.4:
		var dir2 := run.steer_dir(m, spot)
		run.move_unit(m, dir2 * m.base_speed * clampf(to.length() / 2.0, 0.4, 1.3) * dt)
		m.face(dir2)
		m.set_state("run")
	else:
		m.set_state("idle")
	return null


func _minion_target(m: Unit, anchor: Vector3, leash: float) -> Unit:
	var best: Unit = null
	var bs := 1e9
	for e in run.enemies:
		if not e.alive or e.untargetable:
			continue
		if run._flat(e.pos - anchor).length() > leash + e.radius:
			continue
		var score := run._flat(e.pos - m.pos).length()
		if e.taunt_target == m:
			score -= 2.0
		if score < bs:
			bs = score
			best = e
	return best


## Move living minions next to the hero after a teleport (camp <-> arena).
func teleport_minions(arr: Array, p: Vector3) -> void:
	for m in arr:
		if not m.alive:
			continue
		var ang := run.rng.randf() * TAU
		m.pos = run.resolve_pos(m, p + Vector3(cos(ang), 0, sin(ang)) * 1.6, p)
		m.target = null
		m.pull_t = 0.0
		m.knock = Vector3.ZERO
		if m.node and is_instance_valid(m.node):
			m.node.position = m.pos


func alive_of(arr: Array) -> Array:
	var out := []
	for u in arr:
		if u != null and u.alive:
			out.append(u)
	return out


## Stun that is weaker on bosses (they shrug most of it off).
func stun(e: Unit, t: float) -> void:
	e.stun_t = maxf(e.stun_t, t * (0.35 if e.is_boss else 1.0))


## Push a unit away along `dir` (bosses barely move).
func shove(e: Unit, dir: Vector3, strength: float) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		dir = hero.facing
	e.knock = dir.normalized() * strength * (0.25 if e.is_boss else 1.0)


## Enemies inside a cone in front of `from` along `dir` (angle in degrees, full width).
func enemies_in_cone(from: Vector3, dir: Vector3, reach: float, angle: float) -> Array:
	var out := []
	var d := run._flat(dir).normalized()
	var cos_half := cos(deg_to_rad(angle * 0.5))
	for e in run.enemies_in_radius(from, reach):
		var off := run._flat(e.pos - from)
		if off.length() <= e.radius + 0.6 or off.normalized().dot(d) >= cos_half:
			out.append(e)
	return out


## Enemies within `width/2` of the segment a->b.
func enemies_on_line(a: Vector3, b: Vector3, width: float) -> Array:
	var out := []
	var mid := (a + b) * 0.5
	var reach := run._flat(b - a).length() * 0.5 + width + 2.0
	for e in run.enemies_in_radius(mid, reach):
		var c := Run.seg_closest(e.pos, a, b)
		if run._flat(e.pos - c).length() <= width * 0.5 + e.radius:
			out.append(e)
	return out


## Cut a dash path short at the first pillar it would pass through.
func stop_at_pillars(from: Vector3, to: Vector3) -> Vector3:
	for i in range(1, 15):
		var p := from + (to - from) * (i / 14.0)
		for pl in DB.PILLARS:
			if Vector2(p.x - pl.x, p.z - pl.z).length() < DB.PILLAR_R + hero.radius:
				return from + (to - from) * ((i - 1) / 14.0)
	return to
