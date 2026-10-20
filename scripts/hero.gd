class_name Hero
extends Unit
## Player hero: attributes, leveling, skills, items, mana.

var hero_id := ""
var data: Dictionary
var level := 1
var xp := 0.0
var skill_points := 0
var skill_ids: Array = []
var ranks := [0, 0, 0, 0]
var cds := [0.0, 0.0, 0.0, 0.0]
var mana := 100.0
var max_mana := 100.0
var hp_regen := 0.5
var mana_regen := 0.5
var str_v := 0.0
var agi_v := 0.0
var int_v := 0.0
var bonus := {"str": 0.0, "agi": 0.0, "int": 0.0}   # tomes / auto stat points
var items: Array = []     # [{id, charges, choice, cd}]
var item_stats := {}
var attack_speed := 1.0
var dmg_bonus_mult := 1.0
var cd_mult := 1.0
var lifesteal := 0.0
var reflect := 0.0
var burn_on_hit := false
var has_aegis := false
var aegis_ready := true
var shield := 0.0
var sprint_t := 0.0
var regen_buff := []      # [{hp_per_s, mana_per_s, t}]
var move_input := Vector2.ZERO
var focus: Unit = null
var bump: Unit = null           # barrel the player is pushing into (gets swung at)
var bump_t := 0.0
var kit: HeroKit
var feathers_bought := 0
var still_t := 0.0
var in_camp := true
var dead := false


func init_hero(id: String) -> void:
	hero_id = id
	data = DB.HEROES[id]
	kind = id
	team = 0
	skill_ids = data["skills"].duplicate()
	atk_range = data["range"]
	atk_time = data["atk_time"]
	skill_points = 1
	recalc(true)


func primary_value() -> float:
	match data["primary"]:
		"str": return str_v
		"agi": return agi_v
		_: return int_v


func recalc(fill := false) -> void:
	var old_max_hp := max_hp
	var old_max_mana := max_mana
	item_stats = {}
	burn_on_hit = false
	has_aegis = false
	for it in items:
		var d: Dictionary = DB.ITEMS.get(it["id"], {})
		for k in d.get("stats", {}):
			item_stats[k] = item_stats.get(k, 0.0) + float(d["stats"][k])
		if it["id"] == "sage_circlet":
			var ch: String = it.get("choice", "int")
			item_stats[ch] = item_stats.get(ch, 0.0) + 6.0
	var lv := float(level - 1)
	str_v = data["str"] + data["str_g"] * lv + bonus["str"] + item_stats.get("str", 0.0)
	agi_v = data["agi"] + data["agi_g"] * lv + bonus["agi"] + item_stats.get("agi", 0.0)
	int_v = data["int"] + data["int_g"] * lv + bonus["int"] + item_stats.get("int", 0.0)
	max_hp = 160.0 + str_v * 21.0 + item_stats.get("hp", 0.0)
	hp_regen = 0.6 + str_v * 0.06
	max_mana = 80.0 + int_v * 12.0 + item_stats.get("mana", 0.0)
	mana_regen = 0.7 + int_v * 0.045 + item_stats.get("mana_regen", 0.0)
	armor = data["armor"] + agi_v * 0.14 + item_stats.get("armor", 0.0)
	attack_speed = 1.0 + agi_v * 0.012 + item_stats.get("as", 0.0)
	atk_dmg = data["dmg"] + primary_value() + item_stats.get("dmg", 0.0)
	base_speed = data["speed"] * (1.0 + item_stats.get("ms", 0.0))
	cd_mult = 1.0 - item_stats.get("cdr", 0.0)
	lifesteal = item_stats.get("lifesteal", 0.0)
	reflect = item_stats.get("reflect", 0.0)
	burn_on_hit = item_stats.get("burn", 0.0) > 0.0
	has_aegis = item_stats.get("aegis", 0.0) > 0.0
	if fill:
		hp = max_hp
		mana = max_mana
	else:
		# keep the same missing amount when max changes upward
		if max_hp > old_max_hp:
			hp += max_hp - old_max_hp
		if max_mana > old_max_mana:
			mana += max_mana - old_max_mana
		hp = minf(hp, max_hp)
		mana = minf(mana, max_mana)


func speed() -> float:
	var s := super.speed()
	if sprint_t > 0.0:
		s *= 1.6
	if kit:
		s *= kit.speed_mult()
	if run:
		s *= run.hero_speed_mult
	return s


func attack_interval() -> float:
	var t := atk_time / maxf(0.2, attack_speed)
	if kit:
		t /= kit.attack_speed_mult()
	return t


func add_xp(amount: float) -> bool:
	if level >= 20:
		return false
	xp += amount
	var leveled := false
	while level < 20 and xp >= DB.xp_to_next(level):
		xp -= DB.xp_to_next(level)
		level += 1
		skill_points += 1
		leveled = true
	if level >= 20:
		xp = 0.0
	if leveled:
		var frac_hp := hp / maxf(1.0, max_hp)
		recalc()
		hp = maxf(hp, max_hp * frac_hp)
		auto_spend_extra_points()
	return leveled


func xp_frac() -> float:
	if level >= 20:
		return 1.0
	return clampf(xp / DB.xp_to_next(level), 0.0, 1.0)


func max_rank(slot: int) -> int:
	return int(DB.SKILLS[skill_ids[slot]]["max"])


func rank_level_req(slot: int, next_rank: int) -> int:
	if slot == 3:
		return [6, 11, 16][clampi(next_rank - 1, 0, 2)]
	return 2 * next_rank - 1


func can_rank_up(slot: int) -> bool:
	if skill_points <= 0:
		return false
	var r: int = ranks[slot]
	if r >= max_rank(slot):
		return false
	return level >= rank_level_req(slot, r + 1)


func any_rank_up() -> bool:
	for i in 4:
		if can_rank_up(i):
			return true
	return false


func rank_up(slot: int) -> bool:
	if not can_rank_up(slot):
		return false
	ranks[slot] += 1
	skill_points -= 1
	if kit:
		kit.on_rank_up(slot)
	auto_spend_extra_points()
	return true


func all_maxed() -> bool:
	for i in 4:
		if ranks[i] < max_rank(i):
			return false
	return true


## Points that can never be spent on skills become +2 all attributes.
func auto_spend_extra_points() -> void:
	while skill_points > 0 and all_maxed():
		skill_points -= 1
		bonus["str"] += 2.0
		bonus["agi"] += 2.0
		bonus["int"] += 2.0
		recalc()


func skill_mana(slot: int) -> float:
	var r: int = maxi(1, ranks[slot])
	var arr: Array = DB.SKILLS[skill_ids[slot]]["mana"]
	return float(arr[clampi(r - 1, 0, arr.size() - 1)])


func skill_cd(slot: int) -> float:
	var r: int = maxi(1, ranks[slot])
	var arr: Array = DB.SKILLS[skill_ids[slot]]["cd"]
	return float(arr[clampi(r - 1, 0, arr.size() - 1)]) * cd_mult


func item_count() -> int:
	return items.size()


func has_item(id: String) -> bool:
	for it in items:
		if it["id"] == id:
			return true
	return false


func has_boots() -> bool:
	for it in items:
		if DB.ITEMS.get(it["id"], {}).get("boots", false):
			return true
	return false
