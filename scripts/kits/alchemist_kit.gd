extends HeroKit
## Alchemist: gold is fuel. Transmute: every foe that dies while she is in the arena yields TRANSMUTE extra gold.
## Gilded Bomb and Golden Touch burn gold for damage. Acid Flask corrodes armor, so physical allies hit harder.

const ACID := Color(0.6, 1.0, 0.3)
const GOLD := Color(1.0, 0.8, 0.25)
const TRANSMUTE := 2
const BOMB_GOLD := 25

var pools: Array = []        # {pos, r, t, tick, fx}
var corroded := {}           # Enemy -> {"armor": taken, "t": s}
var gilded := {}             # Enemy -> s left: foes that drop extra gold if they die now
var statues: Array = []      # {e, t, dmg, armor}
var elixir_t := 0.0
var elixir_fx: Node = null


func attack_speed_mult() -> float:
	return 1.4 if elixir_t > 0.0 else 1.0


func corrode_amt() -> float:
	return 3.0 + float(maxi(1, rank(0)))


func _corrode(e: Unit, t: float) -> void:
	if not e.alive:
		return
	if not corroded.has(e):
		var amt := corrode_amt()
		e.armor -= amt
		corroded[e] = {"armor": amt, "t": t}
		e.flash(ACID)
	else:
		corroded[e]["t"] = maxf(corroded[e]["t"], t)


func _uncorrode(e: Unit) -> void:
	if corroded.has(e):
		e.armor += corroded[e]["armor"]
		corroded.erase(e)


func smart_aim(slot: int) -> Dictionary:
	match slot:
		0, 1, 3:
			var rr: float = DB.SKILLS[hero.skill_ids[slot]]["radius"]
			var c := run.best_cluster(hero.pos, DB.SKILLS[hero.skill_ids[slot]]["range"], rr)
			if not c.is_empty():
				return {"point": c["pos"]}
			var n := run.nearest_enemy(hero.pos, 10.0)
			if n:
				return {"point": n.pos}
	return {"point": hero.pos + hero.facing * 5.0, "dir": hero.facing}


func cast(slot: int, aim: Dictionary) -> bool:
	match slot:
		0:
			var p := clamp_point(aim.get("point", hero.pos + hero.facing * 6.0), DB.SKILLS["acid_flask"]["range"])
			var r: float = DB.SKILLS["acid_flask"]["radius"]
			pools.append({"pos": p, "r": r, "t": 4.0, "tick": 0.0, "fx": run.fx("zone", {"pos": p, "radius": r, "duration": 4.0, "color": ACID})})
			run.fx("explosion", {"pos": p, "radius": 1.6, "color": ACID})
			Audio.play("orb")
			return true
		1:
			var p2 := clamp_point(aim.get("point", hero.pos + hero.facing * 6.0), DB.SKILLS["gilded_bomb"]["range"])
			var r2: float = DB.SKILLS["gilded_bomb"]["radius"]
			var dmg := 70.0 + 50.0 * rank(1) + 1.2 * hero.int_v
			var paid := run.gold >= BOMB_GOLD
			if paid:
				run.gold -= BOMB_GOLD
				dmg *= 1.6
				run.fx("damage_number", {"pos": hero.pos + Vector3(0, 2.0, 0), "text": "-%d gold" % BOMB_GOLD, "color": GOLD})
			run.fx("explosion", {"pos": p2, "radius": r2, "color": GOLD if paid else ACID})
			for e in run.enemies_in_radius(p2, r2):
				if paid:
					gilded[e] = 0.5
				run.damage(e, dmg, hero, "Gilded Bomb", "magic", {"color": GOLD if paid else ACID})
			run.shake(0.18)
			Audio.play("slam")
			return true
		2:
			var heal := hero.max_hp * (0.15 + 0.05 * rank(2))
			hero.regen_buff.append({"hp": heal / 4.0, "mana": 0.0, "t": 4.0})
			elixir_t = 6.0
			if elixir_fx == null:
				elixir_fx = run.fx("buff_aura", {"target": hero.node, "pos": hero.pos, "radius": 1.1, "color": ACID})
			run.fx("heal", {"pos": hero.pos})
			return true
		3:
			var p3 := clamp_point(aim.get("point", hero.pos + hero.facing * 6.0), DB.SKILLS["golden_touch"]["range"])
			var r3: float = DB.SKILLS["golden_touch"]["radius"]
			var spend := mini(run.gold, maxi(50, int(run.gold * 0.1)))
			run.gold -= spend
			var dmg3 := 160.0 + 130.0 * rank(3) + 2.0 * hero.int_v + 1.5 * spend
			run.fx("ring_burst", {"pos": p3, "radius": r3, "color": GOLD})
			if spend > 0:
				run.fx("damage_number", {"pos": hero.pos + Vector3(0, 2.0, 0), "text": "-%d gold" % spend, "color": GOLD})
			for e in run.enemies_in_radius(p3, r3):
				var t := 3.0 * (0.35 if e.is_boss else 1.0)
				e.stun_t = maxf(e.stun_t, t)
				e.flash(GOLD)
				statues.append({"e": e, "t": t, "dmg": dmg3, "fx": run.fx("mark", {"target": e.node, "pos": e.pos, "color": GOLD})})
			run.toast("Golden Touch: -%d gold" % spend, GOLD)
			return true
	return false


func basic_attack(target: Unit, dmg: float, crit: bool) -> bool:
	if target is Barrel:
		return false
	run.fire_projectile("vial", hero.pos + Vector3(0, 1.3, 0), target, Vector3.ZERO, 15.0, dmg, 0, hero, "Vial",
		{"dtype": "magic", "attack": true, "crit": crit, "color": ACID, "aoe": 1.4})
	return true


func on_enemy_killed(e: Unit) -> void:
	if hero.in_camp or not hero.alive or e.get("no_reward"):
		return
	var g := TRANSMUTE
	if gilded.has(e):
		g += 3
	run.add_gold(g)
	if gilded.has(e) or run.rng.randf() < 0.2:
		run.fx("gold", {"pos": e.pos + Vector3(0, 1.8, 0), "amount": g})
	_uncorrode(e)


func tick(dt: float) -> void:
	if not pools.is_empty():
		var keep := []
		for pl in pools:
			pl["t"] -= dt
			pl["tick"] -= dt
			for e in run.enemies_in_radius(pl["pos"], pl["r"]):
				_corrode(e, 1.0)
			if pl["tick"] <= 0.0:
				pl["tick"] = 0.5
				var dps := 30.0 + 22.0 * rank(0) + 0.6 * hero.int_v
				for e in run.enemies_in_radius(pl["pos"], pl["r"]):
					run.damage(e, dps * 0.5, hero, "Acid", "magic", {"color": ACID})
			if pl["t"] <= 0.0:
				run.fx_stop(pl["fx"])
			else:
				keep.append(pl)
		pools = keep
	if not corroded.is_empty():
		for e in corroded.keys():
			corroded[e]["t"] -= dt
			if corroded[e]["t"] <= 0.0 or not e.alive:
				_uncorrode(e)
	if not gilded.is_empty():
		for e in gilded.keys():
			gilded[e] -= dt
			if gilded[e] <= 0.0:
				gilded.erase(e)
	if not statues.is_empty():
		var keep2 := []
		for s in statues:
			s["t"] -= dt
			var e: Unit = s["e"]
			if s["t"] <= 0.0 or not e.alive:
				run.fx_stop(s["fx"])
				if e.alive:
					run.fx("shatter", {"pos": e.pos, "color": GOLD})
					gilded[e] = 0.5
					run.damage(e, s["dmg"], hero, "Golden Touch", "magic", {"crit": true, "color": GOLD})
			else:
				keep2.append(s)
		statues = keep2
	if elixir_t > 0.0:
		elixir_t -= dt
		if elixir_t <= 0.0 and elixir_fx != null:
			run.fx_stop(elixir_fx)
			elixir_fx = null


func _clear() -> void:
	for pl in pools:
		run.fx_stop(pl["fx"])
	pools.clear()
	for e in corroded.keys():
		_uncorrode(e)
	gilded.clear()
	for s in statues:
		run.fx_stop(s["fx"])
	statues.clear()
	elixir_t = 0.0
	if elixir_fx != null:
		run.fx_stop(elixir_fx)
		elixir_fx = null


func on_wave_end() -> void:
	_clear()


func on_teleport(_p: Vector3) -> void:
	_clear()


func hud_meter() -> Dictionary:
	return {"type": "bar", "label": "Gold %d" % run.gold, "value": minf(float(run.gold), 1000.0), "max": 1000.0, "color": GOLD}


func bot_wants(slot: int) -> bool:
	match slot:
		0:
			var c := run.best_cluster(hero.pos, 10.0, 2.8)
			return not c.is_empty() and (int(c["count"]) >= 2 or run.boss_units.size() > 0)
		1:
			var c2 := run.best_cluster(hero.pos, 11.0, 3.0)
			return not c2.is_empty() and (int(c2["count"]) >= 3 or run.boss_units.size() > 0)
		2:
			return hero.hp < hero.max_hp * 0.6 or run.boss_units.size() > 0 and run.nearest_enemy(hero.pos, 9.0) != null
		3:
			var c3 := run.best_cluster(hero.pos, 10.0, 4.0)
			return not c3.is_empty() and (int(c3["count"]) >= 6 or run.boss_units.size() > 0)
	return false
