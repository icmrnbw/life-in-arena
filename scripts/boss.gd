class_name Boss
extends Enemy
## Bosses: Pit Brute (5), Twin Matrons (10), Hollow Choir (15), Warden of the Pit (20).

var pattern_t := 3.0
var busy_t := 0.0
var charge := {}
var beam := {}
var phase := 1
var phase_invuln := 0.0
var link_fx: Node = null
var summon_t := 6.0
var adds: Array = []
var enraged := false
var last_pattern := ""
var chain_charge := false
var withdrawn := false         # Warden's gauntlet: out of the fight while echoes of earlier bosses fight


func init_enemy(k: String, w: int, r: Run) -> void:
	super.init_enemy(k, w, r)
	is_boss = true
	no_push = true
	# bosses use designed numbers, scaled gently
	max_hp = float(data["hp"])
	hp = max_hp
	atk_dmg = float(data["dmg"]) * (1.0 + 0.02 * w) * DB.BOSS_DMG_BASE
	armor = data["armor"]
	base_speed = data["speed"]
	xp_val = data["xp"]
	gold_val = 0.0
	pattern_t = 2.5
	turn_rate = 4.0


func post_visual() -> void:
	radius = clampf(radius, float(data["radius"]) * 0.8, float(data["radius"]) * 1.3)


func pick_target() -> Unit:
	# bosses hunt the hero (decoys can still distract them briefly)
	if taunt_target != null and taunt_target.alive and taunt_t > 0.0:
		return taunt_target
	var h := run.hero
	if h.alive and not h.dead and not h.in_camp:
		return h
	return super.pick_target()


func damage_taken_mult() -> float:
	return 0.0 if phase_invuln > 0.0 or withdrawn else 1.0


func on_death() -> void:
	_stop_beam()
	run.fx_stop(link_fx)
	link_fx = null
	run.fx("slam", {"pos": pos, "radius": 4.0})
	if kind == "matron":
		for b in run.boss_units:
			if b != self and b.alive and b.kind == "matron":
				(b as Boss).enraged = true
				run.toast("The surviving Matron is enraged!", Art.palette.get("danger", Color.RED))
	if kind == "hollow_choir" or kind == "warden":
		for a in adds:
			if a.alive:
				run.kill(a, null)


func on_removed() -> void:
	_stop_beam()
	run.fx_stop(link_fx)
	link_fx = null


func tick(dt: float) -> void:
	tick_status(dt)
	if phase_invuln > 0.0:
		phase_invuln -= dt
	if kind == "matron":
		_matron_link(dt)
	if kind == "warden":
		if withdrawn:
			set_state("cast")
			return
		if _gauntlet_check():
			return
		_warden_phase()
	if not beam.is_empty():
		_tick_beam(dt)
	if not charge.is_empty():
		_tick_charge(dt)
		return
	if stun_t > 0.0:
		set_state("idle")
		return
	if busy_t > 0.0:
		busy_t -= dt
		return
	retarget_t -= dt
	if retarget_t <= 0.0 or target == null or not target.alive:
		retarget_t = 0.5
		target = pick_target()
	if target == null:
		set_state("idle")
		return
	if not beam.is_empty():
		# stands still while channeling
		set_state("cast")
		return
	pattern_t -= dt * (1.35 if enraged else 1.0) * (1.25 if run.pit_enraged else 1.0)
	summon_t -= dt
	if pattern_t <= 0.0:
		_choose_pattern()
		return
	if kind == "matron" or (kind == "warden" and phase == 2):
		_ai_kite(dt)
	elif kind == "hollow_choir":
		_ai_choir(dt)
	else:
		_ai_melee(dt)


# ------------------------------------------------------------ pattern selection
func _choose_pattern() -> void:
	var d := run._flat(target.pos - pos).length()
	match kind:
		"pit_brute":
			if d > 6.0 and last_pattern != "charge":
				# wounded: the second charge follows straight after the first
				chain_charge = hp < max_hp * 0.5
				_charge()
			else:
				_slam_front(4.0, 2.6, 1.1)
			pattern_t = randf_range(3.6, 4.6) if hp >= max_hp * 0.5 else randf_range(2.8, 3.6)
		"matron":
			if last_pattern == "volley":
				_slam_at(target.pos, 3.2, 2.2, 1.3)
			else:
				_volley(3 if not enraged else 5, 0.35)
			pattern_t = randf_range(2.6, 3.4)
		"hollow_choir":
			if summon_t <= 0.0 and _alive_adds() < 8:
				_summon_adds("choir_add", 3)
				summon_t = 10.0
				pattern_t = 2.0
			elif last_pattern != "beam":
				_start_beam(220.0, 6.0, 20.0, 1.8, 2.2)
				pattern_t = 9.0
			else:
				_ring(10 if hp >= max_hp * 0.5 else 14)
				pattern_t = 3.0
		"warden":
			match phase:
				1:
					if d > 6.0 and last_pattern != "charge":
						_charge()
					else:
						_slam_front(4.5, 2.4, 1.0)
					pattern_t = randf_range(3.0, 3.8)
				2:
					if summon_t <= 0.0:
						_summon_adds("gnawer", 6)
						summon_t = 11.0
						pattern_t = 1.5
					elif last_pattern == "volley":
						_slam_at(target.pos, 3.5, 2.4, 1.2)
						pattern_t = 2.4
					else:
						_volley(5, 0.3)
						pattern_t = 2.4
				_:
					if summon_t <= 0.0 and _alive_adds() < 8:
						_summon_adds("choir_add", 3)
						summon_t = 12.0
						pattern_t = 1.5
					elif last_pattern != "beam":
						_start_beam(240.0, 6.0, 20.0, 1.8, 2.6)
						pattern_t = 8.0
					elif d > 7.0:
						_charge()
						pattern_t = 3.0
					else:
						_slam_front(5.0, 2.6, 0.9)
						pattern_t = 2.8


func _alive_adds() -> int:
	var n := 0
	var keep := []
	for a in adds:
		if a.alive:
			n += 1
			keep.append(a)
	adds = keep
	return n


# ------------------------------------------------------------ movement styles
func _ai_kite(dt: float) -> void:
	var t := target
	var d := run._flat(t.pos - pos).length()
	if d < 4.0:
		_ai_melee(dt)
		return
	if d > 10.0:
		var dir := run.steer_dir(self, t.pos)
		run.move_unit(self, dir * speed() * dt)
		turn_toward(dir, dt)
		set_state("run")
	elif d < 6.5:
		var away := run._flat(pos - t.pos).normalized()
		if Vector2(pos.x, pos.z).length() > run.arena_safe_r() - 4.0:
			away = Vector3(-away.z, 0, away.x)
		run.move_unit(self, away * speed() * 0.7 * dt)
		turn_toward(t.pos - pos, dt)
		set_state("run")
	else:
		turn_toward(t.pos - pos, dt)
		set_state("idle")


func _ai_choir(dt: float) -> void:
	var t := target
	var d := run._flat(t.pos - pos).length()
	if d <= atk_range + radius + t.radius:
		_ai_melee(dt)
		return
	# drifts slowly toward the hero
	var dir := run.steer_dir(self, t.pos)
	run.move_unit(self, dir * speed() * dt)
	turn_toward(dir, dt)
	set_state("run")


# ------------------------------------------------------------ attacks
func _slam_front(r: float, mult: float, delay: float) -> void:
	last_pattern = "slam"
	var dir := run._flat(target.pos - pos).normalized()
	face(dir)
	var center := pos + dir * minf(radius + 1.8, run._flat(target.pos - pos).length())
	_slam_at(center, r, mult, delay)


func _slam_at(center: Vector3, r: float, mult: float, delay: float) -> void:
	last_pattern = "slam" if last_pattern != "volley" else "slam_at"
	busy_t = delay + 0.2
	set_state("cast")
	run.fx_timed("telegraph_circle", {"pos": center, "radius": r, "duration": delay}, delay)
	run.add_hazard({"type": "circle", "pos": center, "r": r, "t": delay + 0.1})
	run.schedule(delay, _slam_hit.bind(center, r, atk_dmg * mult))


func _slam_hit(center: Vector3, r: float, dmg: float) -> void:
	if not alive:
		return
	set_state("attack")
	run.fx("slam", {"pos": center, "radius": r})
	run.shake(0.5)
	Audio.play("slam")
	for u in run.hero_side_targets():
		var off := run._flat(u.pos - center)
		if off.length() <= r + u.radius * 0.5:
			run.damage(u, dmg, self, display_name, "phys")
			if u.alive and not u.no_push:
				u.knock = (off.normalized() if off.length() > 0.1 else Vector3(1, 0, 0)) * 9.0
	# a slam on a pillar knocks it over, away from the boss
	for i in run.arena.pillars.size():
		var pl: Dictionary = run.arena.pillars[i]
		if pl["up"] and run._flat(pl["pos"] - center).length() <= r + DB.PILLAR_R * 0.5:
			run.arena.topple(i, run._flat(pl["pos"] - pos), self)


func _charge() -> void:
	last_pattern = "charge"
	var dir := run._flat(target.pos - pos).normalized()
	face(dir)
	var length := minf(run._flat(target.pos - pos).length() + 5.0, 26.0)
	var end := pos + dir * length
	# keep inside the arena
	var lim := run.arena_safe_r() - radius - 0.5
	if Vector2(end.x, end.z).length() > lim:
		var e2 := Vector2(end.x, end.z).normalized() * lim
		end = Vector3(e2.x, 0, e2.y)
	var delay := 1.0
	busy_t = delay + 0.1
	set_state("cast")
	run.fx_timed("telegraph_line", {"from": pos, "to": end, "width": radius * 2.0 + 0.6, "duration": delay}, delay)
	run.add_hazard({"type": "line", "from": pos, "to": end, "width": radius * 2.0 + 0.8, "t": delay + 0.6})
	run.schedule(delay, _start_charge.bind(end))


func _start_charge(end: Vector3) -> void:
	if not alive:
		return
	charge = {"to": end, "hit": {}, "t": 1.6}
	set_state("run", true)


func _tick_charge(dt: float) -> void:
	charge["t"] -= dt
	var to: Vector3 = run._flat(charge["to"] - pos)
	var spd := 21.0
	var stepl := spd * dt
	var done := false
	if to.length() <= stepl or charge["t"] <= 0.0:
		stepl = to.length()
		done = true
	var dir := to.normalized() if to.length() > 0.01 else facing
	var old := pos
	pos = run.resolve_pos(self, pos + dir * stepl, pos)
	if run._flat(pos - old).length() < stepl * 0.5 and not done:
		done = true   # hit something solid
		var pi := run.arena.pillar_hit(pos, radius)
		if pi >= 0:
			run.arena.topple(pi, dir, self, true)
			chain_charge = false
	face(dir)
	for u in run.hero_side_targets():
		if charge["hit"].has(u):
			continue
		if run._flat(u.pos - pos).length() <= radius + u.radius + 0.4:
			charge["hit"][u] = true
			run.damage(u, atk_dmg * 3.0, self, display_name, "phys")
			if u.alive and not u.no_push:
				var side := Vector3(-dir.z, 0, dir.x)
				if side.dot(u.pos - pos) < 0:
					side = -side
				u.knock = side * 10.0 + dir * 4.0
			run.shake(0.6)
	if done and chain_charge and target != null and target.alive:
		chain_charge = false
		charge = {}
		run.fx("slam", {"pos": pos, "radius": 2.5})
		set_state("idle", true)
		_charge()
		return
	if done:
		charge = {}
		stun_t = maxf(stun_t, 1.2)   # dazed after a charge: punish window (longer after a pillar)
		run.fx("slam", {"pos": pos, "radius": 2.5})
		run.shake(0.4)
		set_state("idle", true)


func _volley(n: int, spread: float) -> void:
	last_pattern = "volley"
	busy_t = 0.5
	set_state("cast")
	var base := run._flat(target.pos - pos).normalized()
	face(base)
	for i in n:
		var a := (float(i) - (n - 1) / 2.0) * spread
		var d := base.rotated(Vector3.UP, a)
		run.fire_projectile("boss_orb", pos + Vector3(0, 1.8, 0) + d * radius, null, d, 11.0, atk_dmg * 1.1, 1, self, display_name,
			{"dtype": "magic", "life": 2.6, "hit_r": 0.6, "color": Color(0.8, 0.3, 1.0)})
	Audio.play("orb")


func _ring(n: int) -> void:
	last_pattern = "ring"
	busy_t = 0.6
	set_state("cast")
	var off := randf() * TAU
	for i in n:
		var a := off + TAU * float(i) / n
		var d := Vector3(cos(a), 0, sin(a))
		run.fire_projectile("boss_orb", pos + Vector3(0, 1.8, 0) + d * radius, null, d, 9.0, atk_dmg * 0.9, 1, self, display_name,
			{"dtype": "magic", "life": 2.8, "hit_r": 0.6})
	Audio.play("orb")


func _summon_adds(add_kind: String, n: int) -> void:
	last_pattern = "summon"
	busy_t = 0.8
	set_state("cast")
	for i in n:
		var a := TAU * float(i) / n + randf() * 0.5
		var p := pos + Vector3(cos(a), 0, sin(a)) * (radius + 2.0)
		p = run.resolve_pos(self, p, pos)
		var e := run.spawn_enemy(add_kind, p, maxi(1, wave - 2))
		e.gold_val *= 0.5
		e.xp_val *= 0.5
		adds.append(e)
		run.fx("teleport", {"pos": p})
	run.toast("%s calls for aid!" % display_name, Art.palette.get("danger", Color.RED))


func _start_beam(sweep_deg: float, dur: float, length: float, width: float, tele: float) -> void:
	last_pattern = "beam"
	var dir := run._flat(target.pos - pos).normalized()
	var ang := atan2(dir.z, dir.x)
	var sgn := 1.0 if randf() < 0.5 else -1.0
	busy_t = tele + 0.2
	set_state("cast")
	var to := pos + dir * length
	run.fx_timed("telegraph_line", {"from": pos, "to": to, "width": width, "duration": tele}, tele)
	run.add_hazard({"type": "line", "from": pos, "to": to, "width": width + 1.0, "t": tele + 0.5})
	beam = {"ang": ang, "speed": deg_to_rad(sweep_deg) / dur * sgn, "t": dur, "delay": tele, "length": length,
		"width": width, "fx": null, "tick": 0.0, "hz": {}, "dps": atk_dmg * 2.2}


func _tick_beam(dt: float) -> void:
	if beam["delay"] > 0.0:
		beam["delay"] -= dt
		if beam["delay"] <= 0.0:
			var d0: Vector3 = Vector3(cos(beam["ang"]), 0, sin(beam["ang"]))
			beam["fx"] = run.fx("beam", {"from": pos + Vector3(0, 1.5, 0), "to": pos + d0 * beam["length"] + Vector3(0, 1.0, 0), "width": beam["width"], "duration": beam["t"]})
			beam["hz"] = run.add_hazard({"type": "line", "from": pos, "to": pos + d0 * beam["length"], "width": beam["width"] + 1.5, "t": beam["t"]})
			Audio.play("beam")
		return
	beam["t"] -= dt
	beam["ang"] += beam["speed"] * dt
	var d: Vector3 = Vector3(cos(beam["ang"]), 0, sin(beam["ang"]))
	var from := pos
	var to: Vector3 = pos + d * float(beam["length"])
	run.fx_params(beam["fx"], {"from": from + Vector3(0, 1.5, 0), "to": to + Vector3(0, 1.0, 0)})
	var hz: Dictionary = beam["hz"]
	if not hz.is_empty():
		hz["from"] = from
		# the hazard covers where the beam is about to sweep
		var lead: Vector3 = Vector3(cos(beam["ang"] + beam["speed"] * 0.6), 0, sin(beam["ang"] + beam["speed"] * 0.6))
		hz["to"] = pos + lead * beam["length"]
		hz["sweep_from"] = d
	beam["tick"] -= dt
	if beam["tick"] <= 0.0:
		beam["tick"] = 0.2
		for u in run.hero_side_targets():
			var c := Run.seg_closest(u.pos, from, to)
			if run._flat(u.pos - c).length() <= beam["width"] * 0.5 + u.radius:
				run.damage(u, beam["dps"] * 0.2, self, display_name, "magic")
	set_state("cast")
	if beam["t"] <= 0.0:
		_stop_beam()


func _stop_beam() -> void:
	if beam.is_empty():
		return
	run.fx_stop(beam.get("fx"))
	beam = {}


# ------------------------------------------------------------ matron link
func _matron_link(dt: float) -> void:
	var other: Boss = null
	for b in run.boss_units:
		if b != self and b.alive and b.kind == "matron":
			other = b
	if twin_index != 0:
		return   # the first matron owns the link visual
	if other == null:
		run.fx_stop(link_fx)
		link_fx = null
		return
	var d := run._flat(other.pos - pos).length()
	if d < 8.0:
		hp = minf(max_hp, hp + max_hp * 0.008 * dt)
		other.hp = minf(other.max_hp, other.hp + other.max_hp * 0.008 * dt)
		var a := pos + Vector3(0, 2.0, 0)
		var b2 := other.pos + Vector3(0, 2.0, 0)
		if link_fx == null or not is_instance_valid(link_fx):
			link_fx = run.fx("beam", {"from": a, "to": b2, "width": 0.4, "duration": 999.0, "color": Color(0.4, 1.0, 0.5)})
		else:
			run.fx_params(link_fx, {"from": a, "to": b2})
	else:
		run.fx_stop(link_fx)
		link_fx = null


# ------------------------------------------------------------ warden phases
func _warden_phase() -> void:
	var f := hp / max_hp
	var want := 1
	if f < 0.34:
		want = 3
	elif f < 0.67:
		want = 2
	if want > phase:
		phase = want
		phase_invuln = 1.5
		busy_t = 1.5
		charge = {}
		_stop_beam()
		pattern_t = 2.0
		summon_t = 1.0
		base_speed = float(data["speed"]) * (1.0 + 0.1 * phase)
		run.fx("level_up", {"pos": pos})
		run.shake(0.7)
		run.banner_requested.emit("The Warden enrages", "Phase %d" % phase)
		set_state("cast", true)
		run.schedule(2.2, run.arena.crumble)


# ------------------------------------------------------------ final gauntlet
## Below each DB.GAUNTLET threshold the Warden steps back to the north wall, untouchable, and an echo of an
## earlier boss takes his place. He returns when the echo falls.
func _gauntlet_check() -> bool:
	if run.gauntlet_i >= DB.GAUNTLET.size():
		return false
	var step: Dictionary = DB.GAUNTLET[run.gauntlet_i]
	if hp > max_hp * float(step["at"]):
		return false
	run.gauntlet_i += 1
	hp = max_hp * float(step["at"])
	withdrawn = true
	untargetable = true
	collides = false
	charge = {}
	_stop_beam()
	clear_mark()
	run.fx("teleport", {"pos": pos})
	pos = Vector3(0, 0, -(run.arena_r() - 3.5))
	face(Vector3(0, 0, 1))
	if node:
		node.position = pos
	run.fx("teleport", {"pos": pos})
	set_state("cast", true)
	run.start_echo(step)
	return true


func return_from_gauntlet() -> void:
	withdrawn = false
	untargetable = false
	collides = true
	phase_invuln = 1.0
	busy_t = 1.0
	pattern_t = 2.0
	run.fx("level_up", {"pos": pos})
	run.shake(0.6)
	run.banner_requested.emit("The Warden returns", "Finish him!" if run.gauntlet_i >= DB.GAUNTLET.size() else "")
