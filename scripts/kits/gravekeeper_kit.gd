extends HeroKit
## Gravekeeper: every enemy that dies leaves a grave for a while; graves are the resource.
## Raise Dead, Corpse Blast, Grave Chill, Open the Graves.

const MINT := Color(0.55, 1.0, 0.8)
const GRAVE_LIFE := 12.0
const MAX_GRAVES := 24

var graves: Array = []       # {pos, t}
var skeletons: Array = []
var chills: Array = []       # {pos, r, t, fx, tick}


func cap() -> int:
	return [0, 4, 6, 8, 10][clampi(rank(0), 0, 4)]


func _add_grave(p: Vector3) -> void:
	var q := Vector3(p.x, 0, p.z)
	graves.append({"pos": q, "t": GRAVE_LIFE, "fx": run.fx("grave_marker", {"pos": q, "duration": GRAVE_LIFE})})
	while graves.size() > MAX_GRAVES:
		_drop_grave(graves[0])


func _drop_grave(g: Dictionary) -> void:
	run.fx_stop(g.get("fx"))
	graves.erase(g)


func graves_near(p: Vector3, r: float) -> Array:
	var out := []
	for g in graves:
		if run._flat(g["pos"] - p).length() <= r:
			out.append(g)
	out.sort_custom(func(a, b): return run._flat(a["pos"] - p).length() < run._flat(b["pos"] - p).length())
	return out


func on_enemy_killed(e: Unit) -> void:
	if not run.in_arena() and e.pos.z > 30.0:
		return
	var n := 3 if e.is_boss else 1
	for c in chills:
		if run._flat(e.pos - c["pos"]).length() <= c["r"] + e.radius:
			n += 1
			break
	for i in n:
		var off := Vector3(run.rng.randf_range(-0.6, 0.6), 0, run.rng.randf_range(-0.6, 0.6)) if i > 0 else Vector3.ZERO
		_add_grave(e.pos + off)


func can_cast(slot: int) -> bool:
	match slot:
		0:
			if alive_of(skeletons).size() >= cap():
				run.toast("All %d skeletons are up" % cap(), Art.palette.get("dim", Color.GRAY))
				return false
			if graves_near(hero.pos, 10.0).is_empty():
				run.toast("No graves nearby: let something die first", MINT)
				return false
	return true


func blocked(slot: int) -> bool:
	if slot == 0 and rank(0) > 0:
		return graves_near(hero.pos, 10.0).is_empty() or alive_of(skeletons).size() >= cap()
	return false


func smart_aim(slot: int) -> Dictionary:
	match slot:
		1:
			var best := Vector3.ZERO
			var bs := 0.0
			# the spot where graves/skeletons and foes overlap the most
			var spots := []
			for g in graves:
				spots.append(g["pos"])
			for s in alive_of(skeletons):
				spots.append(s.pos)
			for p in spots:
				if run._flat(p - hero.pos).length() > 11.0:
					continue
				var sc := float(run.count_enemies(p, 2.5)) * 2.0 + float(graves_near(p, 4.0).size())
				if sc > bs:
					bs = sc
					best = p
			if bs > 0.0:
				return {"point": best}
		2:
			var c := run.best_cluster(hero.pos, 10.0, 3.5)
			if not c.is_empty():
				return {"point": c["pos"]}
	return {"point": hero.pos + hero.facing * 3.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			return _raise(2 + (1 if rank(0) >= 3 else 0), 10.0, false) > 0
		1:
			return _blast(aim)
		2:
			return _chill(aim)
		3:
			return _open()
	return false


func _make_skeleton(p: Vector3, empowered: bool) -> Unit:
	var s := run.spawn_summon("skeleton", p)
	s.radius = clampf(s.radius, 0.3, 0.5)
	var k := 1.5 if empowered else 1.0
	s.max_hp = (90.0 + 40.0 * maxi(1, rank(0)) + 6.0 * hero.level) * k
	s.hp = s.max_hp
	s.armor = 1.0 + hero.level * 0.2
	s.atk_dmg = (9.0 + 5.0 * maxi(1, rank(0)) + 0.35 * hero.int_v) * k
	s.atk_time = 1.0
	s.atk_range = 1.0
	s.base_speed = 6.0
	s.lifetime = 20.0 if empowered else 25.0
	if empowered:
		s.set_tint(Color(0.8, 1.3, 1.1))
	skeletons.append(s)
	return s


func _raise(n: int, r: float, empowered: bool) -> int:
	var made := 0
	for g in graves_near(hero.pos, r):
		if made >= n or (not empowered and alive_of(skeletons).size() >= cap()):
			break
		_drop_grave(g)
		run.fx("soul_wisp", {"from": g["pos"], "to": g["pos"] + Vector3(0, 1.5, 0)})
		run.fx("brood_hatch", {"pos": g["pos"]})
		_make_skeleton(run.resolve_pos(hero, g["pos"], hero.pos), empowered)
		made += 1
	skeletons = alive_of(skeletons)
	return made


func _blast(aim: Dictionary) -> bool:
	var rad: float = DB.SKILLS["corpse_blast"]["radius"]
	var p := clamp_point(aim.get("point", hero.pos), DB.SKILLS["corpse_blast"]["range"])
	var spots := []
	for g in graves_near(p, rad):
		spots.append(g["pos"])
		_drop_grave(g)
	for s in alive_of(skeletons):
		if run._flat(s.pos - p).length() <= rad:
			spots.append(s.pos)
			run.remove_ally(s, false)
	skeletons = alive_of(skeletons)
	if spots.is_empty():
		run.toast("No graves or skeletons there", MINT)
		return false
	var dmg := 60.0 + 40.0 * rank(1) + 0.9 * hero.int_v
	for q in spots:
		run.fx("sacrifice_explosion", {"pos": q, "radius": 2.5, "color": MINT})
		for e in run.enemies_in_radius(q, 2.5):
			run.damage(e, dmg, hero, "Corpse Blast", "magic", {"color": MINT})
	run.shake(0.12 + 0.03 * mini(spots.size(), 8))
	return true


func _chill(aim: Dictionary) -> bool:
	var rad: float = DB.SKILLS["grave_chill"]["radius"]
	var p := clamp_point(aim.get("point", hero.pos), DB.SKILLS["grave_chill"]["range"])
	chills.append({"pos": p, "r": rad, "t": 6.0, "tick": 0.0,
		"fx": run.fx("zone", {"pos": p, "radius": rad, "duration": 6.0, "color": MINT})})
	return true


func _open() -> bool:
	var n: int = [8, 10, 12][clampi(rank(3) - 1, 0, 2)]
	run.fx("ring_burst", {"pos": hero.pos, "radius": 6.0, "color": MINT})
	var made := _raise(n, 14.0, true)
	for i in 3:
		var ang := TAU * i / 3.0 + run.rng.randf()
		var p := run.resolve_pos(hero, hero.pos + Vector3(cos(ang), 0, sin(ang)) * 2.2, hero.pos)
		run.fx("brood_hatch", {"pos": p})
		_make_skeleton(p, true)
		made += 1
	run.shake(0.3)
	return made > 0


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel:
		return false
	var opts := {"dtype": "phys", "attack": true, "crit": crit, "color": MINT}
	run.fire_projectile("grave_bolt", hero.pos + Vector3(0, 1.3, 0), target, Vector3.ZERO, 16.0, dmg, 0, hero, "Grave Bolt", opts)
	return true


func tick(dt: float) -> void:
	if not graves.is_empty():
		var keep := []
		for g in graves:
			g["t"] -= dt
			if g["t"] > 0.0:
				keep.append(g)
		graves = keep
	if not chills.is_empty():
		var keep2 := []
		var dps := 15.0 + 12.0 * rank(2) + 0.3 * hero.int_v
		for c in chills:
			c["t"] -= dt
			c["tick"] -= dt
			if c["tick"] <= 0.0:
				c["tick"] = 0.5
				for e in run.enemies_in_radius(c["pos"], c["r"]):
					e.apply_slow(0.4, 0.7)
					run.damage(e, dps * 0.5, hero, "Grave Chill", "magic", {"color": MINT})
			if c["t"] <= 0.0:
				run.fx_stop(c["fx"])
			else:
				keep2.append(c)
		chills = keep2
	var ss := alive_of(skeletons)
	if ss.size() != skeletons.size():
		skeletons = ss
	var i := 0
	for s in ss:
		tick_minion(s, dt, hero.pos, 9.0, "Skeleton", i, ss.size())
		i += 1


func on_teleport(p: Vector3) -> void:
	teleport_minions(skeletons, p)


func on_wave_end() -> void:
	for s in skeletons:
		run.remove_ally(s, false)
	skeletons.clear()
	for g in graves:
		run.fx_stop(g.get("fx"))
	graves.clear()
	for c in chills:
		run.fx_stop(c["fx"])
	chills.clear()


func on_rank_up(slot: int) -> void:
	if slot == 0:
		for s in alive_of(skeletons):
			s.atk_dmg = maxf(s.atk_dmg, 9.0 + 5.0 * rank(0) + 0.35 * hero.int_v)


func hud_meter() -> Dictionary:
	return {"type": "count", "label": "Graves %d  ·  Skeletons %d / %d" % [graves.size(), alive_of(skeletons).size(), cap()], "color": MINT}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			return not blocked(0) and run.nearest_enemy(hero.pos, 14.0) != null
		1:
			var a := smart_aim(1)
			if not a.has("point") or run._flat(a["point"] - (hero.pos + hero.facing * 3.0)).length() < 0.01:
				return false
			return run.count_enemies(a["point"], 3.0) >= 2
		2:
			var c := run.best_cluster(hero.pos, 10.0, 3.5)
			return not c.is_empty() and (int(c["count"]) >= 3 or run.boss_units.size() > 0)
		3:
			return graves_near(hero.pos, 14.0).size() >= 5 or (run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 12.0) != null)
	return false
