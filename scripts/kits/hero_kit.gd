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
