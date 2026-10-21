extends Node
## Autoplay bot (--autoplay). Plays through the same inputs a player has: move vector, casts, rank-ups, shop.
## --autoplay=passive: a careless player for difficulty calibration: shops the recommended build and taps skills
## whenever they're ready, but just walks at the nearest enemy (no dodging, kiting, healing or potions).

var run: Run
var think_t := 0.0
var shop_done_wave := -1
var stuck_t := 0.0
var stuck_dir := Vector3.ZERO
var stuck_left := 0.0
var last_pos := Vector3.ZERO
var orbit_sign := 1.0
var orbit_flip_t := 4.0
var passive := false
## --noshop=N: buy nothing before wave N+1 (checks that skills and movement alone can't carry the early waves).
var noshop := 0
## Barrel stack play (smart bot, regular waves): dig a corridor into the nearest stack and fight from its end.
var use_pens := true
var pen_wave := -1
var pen_i := -1
var pen_slot := -1
var pen_quit := false
var pen_idle_t := 0.0
var pen_kills := 0
var pen_dry_t := 0.0   # time in pen play since the last kill


func setup(r: Run) -> void:
	run = r
	passive = Game.autoplay_mode == "passive"
	use_pens = Game.arg("pens", "1") != "0"
	noshop = int(Game.arg("noshop", "0"))


func tick(dt: float) -> void:
	var h := run.hero
	if h.dead or not h.alive:
		h.move_input = Vector2.ZERO
		return
	_rank_up()
	think_t -= dt
	match run.phase:
		"prep":
			_prep(dt)
		"wave", "clear", "victory_wait":
			_fight(dt)
		_:
			h.move_input = Vector2.ZERO


func _rank_up() -> void:
	var h := run.hero
	var guard := 0
	while h.skill_points > 0 and h.any_rank_up() and guard < 8:
		guard += 1
		var order: Array = h.data["skill_order"]
		var counts := [0, 0, 0, 0]
		var done := false
		for s in order:
			counts[s] += 1
			if h.ranks[s] < counts[s]:
				if h.can_rank_up(s):
					run.rank_up(s)
					done = true
				break
		if not done:
			for s in [3, 0, 1, 2]:
				if h.can_rank_up(s):
					run.rank_up(s)
					break


# ---------------------------------------------------------------- prep
func _prep(_dt: float) -> void:
	var h := run.hero
	if shop_done_wave != run.wave:
		shop_done_wave = run.wave
		_shop()
	if passive:
		h.move_input = Vector2.ZERO
		run.skip_prep()
		return
	if think_t <= 0.0:
		think_t = 0.25
		# fill the brood / prepare in camp
		var camp_cast: Array = h.kit.bot_profile().get("camp_cast", [])
		for s in camp_cast:
			if h.ranks[s] > 0 and h.kit.is_ready(s) and h.mana >= h.skill_mana(s) and h.kit.bot_wants(s):
				run.try_cast(s)
	var need_heal := h.hp < h.max_hp * 0.97 or h.mana < h.max_mana * 0.9
	if need_heal:
		var to := run._flat(DB.FOUNTAIN_POS - h.pos)
		h.move_input = Vector2(to.x, to.z).normalized() if to.length() > 1.5 else Vector2.ZERO
	else:
		h.move_input = Vector2.ZERO
		if run.prep_t < DB.PREP_TIME - 2.0 or run.wave == 1:
			run.skip_prep()


func _shop() -> void:
	var h := run.hero
	if run.wave <= noshop:
		return
	# make room for the build: sell potions when the bag is nearly full
	if h.items.size() >= 5 and not run.build_needs().is_empty():
		for i in range(h.items.size() - 1, -1, -1):
			if DB.ITEMS[h.items[i]["id"]]["kind"] == "consumable":
				run.sell(i)
	var guard := 0
	while guard < 12:
		guard += 1
		var bought := false
		var needs := run.build_needs()
		for i in needs.size():
			var id: String = needs[i]
			var why := run.can_buy(id)
			if why == "":
				run.buy(id, "agi" if h.data["primary"] == "agi" else "int")
				bought = true
				break
			if why.begins_with("Inventory full"):
				# jump to the next recipe that uses what we have
				for j in range(i + 1, needs.size()):
					var nid: String = needs[j]
					if DB.ITEMS[nid]["kind"] == "advanced":
						if run.can_buy(nid) == "":
							run.buy(nid)
							bought = true
						break
				break
			if why == "Not enough gold":
				break
			# other reasons (boots already owned etc.): skip this entry
		if not bought:
			break
	# extras
	var spare := run.gold
	var needs2 := run.build_needs()
	var reserve := 0 if needs2.is_empty() else mini(run.buy_price(needs2[0]), 900)
	if h.items.size() <= 5 and spare - reserve >= 180 and run.wave >= 3:
		var have := 0
		for it in h.items:
			if it["id"] == "healing_draught":
				have = int(it.get("charges", 1))
		if have < 2 and run.can_buy("healing_draught") == "":
			run.buy("healing_draught")
	if needs2.is_empty():
		if run.feathers == 0 and run.gold >= 1500 and run.lives <= 2:
			run.buy("phoenix_feather")
		# spare gold: the cheapest Training rank that suits the hero, or a Tome once ranks cost more than it
		var keep := 1500 if run.feathers == 0 and run.lives <= 2 else 0
		var picks := ["train_" + String(h.data["primary"]), "train_dmg", "train_armor", "train_haste", "train_vigor", "train_regen"]
		var guard2 := 0
		while guard2 < 60:
			guard2 += 1
			var best := ""
			var best_p := 500
			for u in picks:
				if run.can_upgrade(u) == "" and run.upgrade_price(u) < best_p:
					best = u
					best_p = run.upgrade_price(u)
			if run.gold - best_p < keep:
				break
			if best != "":
				run.buy_upgrade(best)
			elif run.can_buy("tome_of_might") == "":
				run.buy("tome_of_might")
			else:
				break


# ---------------------------------------------------------------- fight
func _fight(dt: float) -> void:
	var h := run.hero
	if think_t <= 0.0:
		think_t = 0.15
		if passive:
			_cast_careless()
		else:
			_cast()
			_items()
	_move(dt)


func _cast() -> void:
	var h := run.hero
	for s in [3, 0, 1, 2]:
		if h.ranks[s] <= 0:
			continue
		if not (h.kit.is_ready(s) or h.kit.free_cast(s)):
			continue
		if not h.kit.free_cast(s) and h.mana < h.skill_mana(s):
			continue
		if h.kit.bot_wants(s):
			if run.try_cast(s):
				return


func _cast_careless() -> void:
	var h := run.hero
	if run.nearest_enemy(h.pos, 9.0) == null:
		return
	for s in [0, 1, 2, 3]:
		if h.ranks[s] > 0 and h.kit.is_ready(s) and h.mana >= h.skill_mana(s):
			if h.kit.free_cast(s):
				continue
			if s in h.kit.bot_profile().get("camp_cast", []) and not h.kit.bot_wants(s):
				continue
			if h.kit.blocked(s):
				continue
			if run.try_cast(s):
				return


func _items() -> void:
	var h := run.hero
	for i in h.items.size():
		var id: String = h.items[i]["id"]
		if id == "healing_draught" and h.hp < h.max_hp * 0.45 and float(h.items[i].get("cd", 0.0)) <= 0.0:
			var active := false
			for b in h.regen_buff:
				if b["hp"] > 0.0:
					active = true
			if not active:
				run.use_item(i)
				return
		if id == "mana_draught" and h.mana < h.max_mana * 0.25:
			run.use_item(i)
			return
		if id == "wayfarer_treads" and h.hp < h.max_hp * 0.35 and float(h.items[i].get("cd", 0.0)) <= 0.0:
			run.use_item(i)
			return


func _move(dt: float) -> void:
	var h := run.hero
	if passive:
		# walks at the nearest enemy and auto-attacks; no skills, no shopping, no dodging
		var n := run.nearest_enemy(h.pos, 60.0)
		var goal := n.pos if n else Vector3(0, 0, 4)
		var to := run._flat(goal - h.pos)
		var stop := (h.atk_range + n.radius + h.radius - 0.3) if n else 1.0
		h.move_input = Vector2(to.x, to.z).normalized() if to.length() > stop else Vector2.ZERO
		return
	_focus_buffers()
	if _pen_play(dt):
		return
	var v := Vector3.ZERO
	var enemies := []
	for e in run.enemies:
		if e.alive and not e.untargetable:
			enemies.append(e)
	var hp_frac := h.hp / maxf(1.0, h.max_hp)
	var prof: Dictionary = h.kit.bot_profile()
	var ranged: bool = prof.get("ranged", false)
	var orbit: float = prof.get("orbit", 0.0)
	# a channeling hero stands still (stick input would cancel the channel), unless something must be dodged
	if h.kit.override_motion_active():
		var hz0 := _hazard_push()
		h.move_input = Vector2(hz0.x, hz0.z).normalized() if hz0.length() > 0.5 else Vector2.ZERO
		return
	orbit_flip_t -= dt
	if orbit_flip_t <= 0.0:
		orbit_flip_t = randf_range(3.0, 6.0)
		orbit_sign = -orbit_sign
	if enemies.size() > 0:
		# local crowd
		var near_n := 0
		var centroid := Vector3.ZERO
		for e in enemies:
			var d := run._flat(e.pos - h.pos).length()
			if d < 6.0:
				near_n += 1
				centroid += e.pos
		if near_n > 0:
			centroid /= near_n
		# target: boss first, else nearest
		var tgt: Unit = null
		for b in run.boss_units:
			if b.alive and not b.untargetable:
				tgt = b
		if tgt == null or (run._flat(tgt.pos - h.pos).length() > 6.0 and near_n >= 3):
			tgt = run.nearest_enemy(h.pos, 60.0)
		if tgt != null:
			var to_t := run._flat(tgt.pos - h.pos)
			var dist := to_t.length()
			var dirt := to_t / maxf(0.01, dist)
			var want := h.atk_range + tgt.radius + h.radius - 0.2
			if ranged:
				want = float(prof.get("keep", 7.0))
			var boss_only := near_n <= 2 and tgt.is_boss
			var retreat := hp_frac < float(prof.get("retreat", 0.32)) and not (boss_only and hp_frac > 0.2)
			var crowd_limit: int = prof.get("crowd", 2)
			if retreat or (near_n >= crowd_limit and not ranged):
				if near_n > 0:
					var away := run._flat(h.pos - centroid)
					v += (away.normalized() if away.length() > 0.1 else -dirt) * 1.5
				else:
					v -= dirt
			elif ranged:
				var nd := run._flat(run.nearest_enemy(h.pos, 60.0).pos - h.pos).length() if run.nearest_enemy(h.pos, 60.0) else 99.0
				var shielded := tgt.blocks_front and tgt.facing.dot(-dirt) > 0.3
				if nd < (3.5 if shielded else 5.5):
					v -= dirt * 1.2
				elif dist > want + 2.0:
					v += dirt * 0.8
				# shields block shots from the front: circle round to its side
				var flank := 1.0 if shielded else orbit
				v += Vector3(-dirt.z, 0, dirt.x) * orbit_sign * flank
			else:
				if dist > want + 0.3:
					v += dirt
				elif dist < want - 0.8:
					v -= dirt * 0.5
				if orbit >= 0.6 or tgt.is_boss:
					v += Vector3(-dirt.z, 0, dirt.x) * orbit_sign * maxf(orbit, 0.4)
		# ranged harassers: melee heroes go for hexcasters when nothing is close
		if near_n == 0 and not ranged:
			var hx := _nearest_kind("hexcaster")
			if hx:
				v += run._flat(hx.pos - h.pos).normalized() * 0.5
	else:
		# nothing visible: drift to the middle (burrowers / spawns)
		var to2 := run._flat(Vector3(0, 0, 3) - h.pos)
		if to2.length() > 2.0:
			v += to2.normalized() * 0.6
	# hazards
	var hz := _hazard_push()
	if hz.length() > 0.01:
		v = v * 0.3 + hz * 3.0
	# stay off the outer wall
	var rr := Vector2(h.pos.x, h.pos.z).length()
	if rr > run.arena_safe_r() - 4.0 and not h.in_camp:
		v += run._flat(-h.pos).normalized() * (rr - (run.arena_safe_r() - 4.0)) * 0.6
	# out in the open, keep off the barrel stacks: kiting into one gets you pinned
	if run.barrels and not h.in_camp and run.barrels.cover(h.pos) < 2:
		var nb := run.barrels.barrel_near(h.pos, 2.5)
		if nb != null:
			var gap := run._flat(h.pos - nb.pos).length() - DB.BARREL_R - h.radius
			v += run._flat(h.pos - nb.pos).normalized() * clampf(1.0 - gap / 2.0, 0.0, 1.0) * 1.5
	# in a corridor mid-wave: out the way we came, not into the barrels
	if run.barrels and run.barrels.cover(h.pos) >= 2 and not h.in_camp:
		v = run._flat(run.barrels.waypoint(h, Vector3(0, 0, 3)) - h.pos).normalized() * 2.0 + v * 0.2
	# unstick
	if stuck_left > 0.0:
		stuck_left -= dt
		v += stuck_dir
	var moved := run._flat(h.pos - last_pos).length()
	last_pos = h.pos
	if v.length() > 0.3 and moved < h.speed() * dt * 0.25:
		stuck_t += dt
		if stuck_t > 0.6:
			stuck_t = 0.0
			stuck_dir = Vector3(-v.z, 0, v.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
			stuck_left = 0.8
	else:
		stuck_t = maxf(0.0, stuck_t - dt)
	h.move_input = Vector2(v.x, v.z).normalized() if v.length() > 0.15 else Vector2.ZERO


## Tap Chanters and Drummers first when they're close.
func _focus_buffers() -> void:
	var h := run.hero
	if h.focus != null and h.focus.alive and not (h.focus is Barrel):
		return
	var best: Unit = null
	var bd := 12.0
	for b in run.chanters + run.drummers:
		if b.alive:
			var d := run._flat(b.pos - h.pos).length()
			if d < bd:
				bd = d
				best = b
	if best != null:
		h.focus = best


func _pen_play(dt: float) -> bool:
	var h := run.hero
	var bf := run.barrels
	if not use_pens or bf == null or run.phase != "wave" or not run.boss_units.is_empty() or run.boss_kind() != "":
		return false
	if pen_wave != run.wave:
		pen_wave = run.wave
		pen_quit = false
		pen_idle_t = 0.0
		pen_dry_t = 0.0
		pen_kills = int(run.stats["kills"])
		pen_i = -1
		var bd := 1e9
		for i in bf.stacks.size():
			if bf.stacks[i]["lane"].is_empty():
				continue
			var d := run._flat(bf.stacks[i]["front"] - h.pos).length()
			if d < bd:
				bd = d
				pen_i = i
	if pen_quit or pen_i < 0:
		return false
	var st: Dictionary = bf.stacks[pen_i]
	var lane: Array = st["lane"]
	var want := mini(BarrelField.DIG_DEPTH, lane.size())
	var depth := 0
	while depth < want and bf.barrel_at(lane[depth]) == null:
		depth += 1
	var hold: Vector3 = st["front"] if depth == 0 else BarrelField.cell_pos(lane[depth - 1])
	var hp_frac := h.hp / maxf(1.0, h.max_hp)
	var near := run.count_enemies(hold, 8.0)
	var dug_in := depth >= want and run._flat(h.pos - hold).length() < 0.8
	if dug_in and near == 0:
		pen_idle_t += dt
	else:
		pen_idle_t = 0.0
	if int(run.stats["kills"]) != pen_kills:
		pen_kills = int(run.stats["kills"])
		pen_dry_t = 0.0
	else:
		pen_dry_t += dt
	# the corridor got smashed open around us, nothing is coming, nothing is dying, or a buffer needs killing
	var breached := depth >= want and bf.cover(hold) < 2
	if breached or pen_idle_t > 6.0 or pen_dry_t > 14.0 or (h.focus != null and h.focus.alive and not (h.focus is Barrel) and run._flat(h.focus.pos - hold).length() > h.atk_range + 2.5):
		pen_quit = true
		return false
	var goal := hold
	if depth < want:
		h.focus = bf.barrel_at(lane[depth])   # dig: break the next barrel of the lane
	if run._flat(goal - h.pos).length() > 1.5:
		goal = bf.waypoint(h, goal)
	var to := run._flat(goal - h.pos)
	var v := to.normalized() if to.length() > 0.2 else Vector3.ZERO
	var hz := _hazard_push()
	if hz.length() > 0.01:
		v = v * 0.3 + hz * 3.0
	h.move_input = Vector2(v.x, v.z).normalized() if v.length() > 0.15 else Vector2.ZERO
	return true


func _nearest_kind(k: String) -> Unit:
	var best: Unit = null
	var bd := 1e9
	for e in run.enemies:
		if e.alive and not e.untargetable and e.kind == k:
			var d := run._flat(e.pos - run.hero.pos).length()
			if d < bd:
				bd = d
				best = e
	return best


func _hazard_push() -> Vector3:
	var h := run.hero
	var push := Vector3.ZERO
	for hz in run.hazards:
		match hz.get("type", ""):
			"circle":
				var off: Vector3 = run._flat(h.pos - hz["pos"])
				var lim: float = hz["r"] + h.radius + 0.8
				if off.length() < lim:
					var dir := off.normalized() if off.length() > 0.05 else Vector3(1, 0, 0)
					push += dir * (1.0 + (lim - off.length()))
			"line":
				var c: Vector3 = Run.seg_closest(h.pos, hz["from"], hz["to"])
				var off2 := run._flat(h.pos - c)
				var lim2: float = hz["width"] * 0.5 + h.radius + 0.9
				if off2.length() < lim2:
					var dir2 := off2.normalized()
					if off2.length() < 0.05:
						var ab: Vector3 = run._flat(hz["to"] - hz["from"]).normalized()
						dir2 = Vector3(-ab.z, 0, ab.x)
					if hz.has("sweep_from"):
						# rotating beam: move against the sweep direction is hard; move outward/behind the boss instead
						var toward_center: Vector3 = run._flat(hz["from"] - h.pos)
						dir2 = (dir2 + toward_center.normalized() * 0.6).normalized()
					push += dir2 * (1.0 + (lim2 - off2.length()))
	return push
