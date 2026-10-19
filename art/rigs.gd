extends RefCounted
## Procedural unit rigs: every unit is ONE skinned ArrayMesh (rigid bone weights) + Skeleton3D,
## so a unit costs one draw call (two for translucent wings). Built once per kind, then shared.
## Models face -Z, origin at feet, right hand on +X.

static var _cache := {}

class RB extends "res://art/mesh_kit.gd":
	var bnames := PackedStringArray()
	var bparent := PackedInt32Array()
	var bglobal: Array[Vector3] = []

	func _init() -> void:
		super()
		use_bones = true

	func bone(bname: String, parent: String, gpos: Vector3) -> int:
		var pi := -1
		if parent != "":
			pi = bnames.find(parent)
		bnames.append(bname); bparent.append(pi); bglobal.append(gpos)
		return bnames.size() - 1

	func on(bname: String) -> void:
		var i := bnames.find(bname)
		cur_bone = maxi(i, 0)

	func finish(params: Dictionary) -> Dictionary:
		var mesh := build()
		var skin := Skin.new()
		var rest_local: Array[Vector3] = []
		for i in bnames.size():
			skin.add_bind(i, Transform3D(Basis(), -bglobal[i]))
			var pi := bparent[i]
			rest_local.append(bglobal[i] - (bglobal[pi] if pi >= 0 else Vector3.ZERO))
		var p := params.duplicate()
		p["tris"] = tri_count()
		return {"mesh": mesh, "skin": skin, "names": bnames, "parents": bparent, "rest": rest_local,
			"layers": layers(), "params": p}

## Per-kind segment detail so rigs stay inside the triangle budgets
## (hero ~3k, enemy ~1.2k, boss ~6k). Small on-screen enemies lose little from fewer segments.
const DETAIL := {"chanter": 0.8, "drummer": 0.7, "ashwarden": 0.85, "hivemother": 0.62, "gnawer": 0.7, "shieldbearer": 0.5,
	"hexcaster": 0.85, "burrower": 0.7, "bloater": 0.5, "broodling": 0.5,
	"sanguine": 0.85, "snarewright": 0.68, "twinhide": 0.68, "twinhide_beast": 0.62, "gravekeeper": 0.75, "stoneshaper": 1.0,
	"gunsmith": 0.85, "sunspeaker": 0.85, "skeleton": 0.4, "snare_trap": 0.6, "blast_charge": 0.6, "boulder": 0.8, "stone_pillar": 0.8}

static func get_rig(kind: String) -> Dictionary:
	if _cache.has(kind):
		return _cache[kind]
	var MK = load("res://art/mesh_kit.gd")
	MK.default_detail = DETAIL.get(kind, 1.0)
	var r: Dictionary
	match kind:
		"ashwarden": r = _ashwarden()
		"riftdancer": r = _riftdancer()
		"hivemother": r = _hivemother()
		"gnawer": r = _gnawer()
		"shieldbearer": r = _shieldbearer()
		"hexcaster": r = _hexcaster()
		"burrower": r = _burrower()
		"bloater": r = _bloater()
		"pit_brute": r = _pit_brute()
		"matron": r = _matron()
		"hollow_choir": r = _hollow_choir()
		"warden": r = _warden()
		"broodling": r = _broodling()
		"ember_totem": r = _ember_totem()
		"choir_add": r = _choir_add()
		"chanter": r = _chanter()
		"drummer": r = _drummer()
		"sanguine": r = _sanguine()
		"snarewright": r = _snarewright()
		"twinhide": r = _twinhide()
		"twinhide_beast": r = _twinhide_beast()
		"gravekeeper": r = _gravekeeper()
		"stoneshaper": r = _stoneshaper()
		"gunsmith": r = _gunsmith()
		"sunspeaker": r = _sunspeaker()
		"skeleton": r = _skeleton()
		"snare_trap": r = _snare_trap()
		"blast_charge": r = _blast_charge()
		"boulder": r = _boulder()
		"stone_pillar": r = _stone_pillar()
		"afterimage":
			r = get_rig("riftdancer").duplicate()
			var p: Dictionary = r["params"].duplicate()
			p["ghost"] = true
			r["params"] = p
		_: r = _generic()
	MK.default_detail = 1.0
	_cache[kind] = r
	return r

static func _base_params() -> Dictionary:
	return {
		"style": "biped", "attack": "overhead", "radius": 0.5, "height": 1.8,
		"glow": Color(1.0, 0.5, 0.2), "rim": Color(1.0, 0.82, 0.6), "rim_strength": 0.45,
		"run_freq": 10.0, "stride": 0.7, "arm_swing": 0.55, "lean": 0.18,
		"w_idle_r": Vector3.ZERO, "w_idle_l": Vector3.ZERO,
		"atk_dur": 0.5, "cast_dur": 0.6, "atk_override": {}, "ghost": false, "enemy": true,
	}

# =================================================================== HEROES

static func _ashwarden() -> Dictionary:
	var k := RB.new()
	var plate := Color("8e877e"); var plate_d := Color("57524d"); var iron := Color("34302d")
	var bronze := Color("c8843e"); var ember := Color("ff7a2f"); var cloth := Color("6e2216"); var leather := Color("5e3e28")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.92, 0))
	k.bone("chest", "hips", Vector3(0, 1.2, 0))
	k.bone("head", "chest", Vector3(0, 1.58, 0))
	k.bone("arm_l", "chest", Vector3(-0.47, 1.42, 0))
	k.bone("arm_r", "chest", Vector3(0.47, 1.42, 0))
	k.bone("weapon_r", "arm_r", Vector3(0.62, 0.74, -0.04))
	k.bone("leg_l", "hips", Vector3(-0.18, 0.9, 0))
	k.bone("leg_r", "hips", Vector3(0.18, 0.9, 0))
	k.bone("cape", "chest", Vector3(0, 1.46, 0.26))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.18, 0.88, 0), Vector3(s * 0.2, 0.48, 0), 0.14, leather)
		k.ball(1.0, Vector3(s * 0.2, 0.5, -0.09), plate, Vector3(0.12, 0.11, 0.1))
		k.cyl(0.135, 0.16, 0.36, Vector3(s * 0.2, 0.27, 0), plate)
		k.box(Vector3(0.26, 0.15, 0.4), Vector3(s * 0.2, 0.075, -0.05), iron)
		k.box(Vector3(0.22, 0.07, 0.1), Vector3(s * 0.2, 0.13, -0.23), bronze)
	k.on("hips")
	k.cyl(0.33, 0.36, 0.2, Vector3(0, 0.93, 0), leather, Vector3.ZERO, -1, 10)
	k.box(Vector3(0.15, 0.13, 0.06), Vector3(0, 0.94, -0.35), bronze)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.22, 0.32, 0.07), Vector3(s * 0.25, 0.75, -0.16), plate_d, Vector3(10, s * -30, s * 10))
	k.box(Vector3(0.24, 0.48, 0.04), Vector3(0, 0.66, -0.31), cloth, Vector3(6, 0, 0))
	k.box(Vector3(0.36, 0.52, 0.04), Vector3(0, 0.68, 0.3), cloth, Vector3(-6, 0, 0))
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.23, 0), plate, Vector3(0.46, 0.41, 0.35), Vector3.ZERO, -1, 12, 7)
	k.ball(1.0, Vector3(0, 1.27, 0.12), plate_d, Vector3(0.4, 0.34, 0.28))
	k.cyl(0.28, 0.31, 0.22, Vector3(0, 1.0, 0), iron)
	k.box(Vector3(0.24, 0.14, 0.07), Vector3(0, 1.28, -0.34), ember, Vector3.ZERO, 1.6)
	for i in 3:
		k.box(Vector3(0.03, 0.17, 0.05), Vector3(-0.07 + i * 0.07, 1.28, -0.37), iron)
	k.torus(0.15, 0.3, Vector3(0, 1.47, 0), bronze, Vector3.ZERO, -1, 10, 5)
	for s in [-1.0, 1.0]:
		k.cyl(0.07, 0.085, 0.4, Vector3(s * 0.17, 1.58, 0.28), iron, Vector3(-12, 0, 0))
		k.cyl(0.08, 0.075, 0.06, Vector3(s * 0.17, 1.79, 0.24), ember, Vector3(-12, 0, 0), 2.2)
	k.on("cape")
	k.box(Vector3(0.62, 0.95, 0.04), Vector3(0, 0.98, 0.38), cloth, Vector3(-8, 0, 0))
	k.on("head")
	k.cyl(0.18, 0.21, 0.32, Vector3(0, 1.66, 0), plate)
	k.hemi(1.0, Vector3(0, 1.82, 0), plate, Vector3(0.18, 0.15, 0.18))
	k.box(Vector3(0.3, 0.22, 0.06), Vector3(0, 1.64, -0.19), iron)
	k.box(Vector3(0.25, 0.04, 0.03), Vector3(0, 1.68, -0.225), ember, Vector3.ZERO, 2.6)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.06, 0.2, 0.14), Vector3(s * 0.2, 1.62, -0.05), plate_d)
	k.extrude(PackedVector2Array([Vector2(-0.22, 0), Vector2(0.24, 0), Vector2(0.18, 0.13), Vector2(-0.04, 0.22), Vector2(-0.26, 0.08)]),
		0.06, Vector3(0, 1.86, 0), bronze, Vector3(0, 90, 0))
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.53, 1.5, 0), plate, Vector3(0.32, 0.22, 0.32), Vector3(0, 0, s * -18))
		k.torus(0.26, 0.32, Vector3(s * 0.56, 1.44, 0), bronze, Vector3(0, 0, s * -18), -1, 12, 4, Vector3(1.0, 1.4, 1.0))
		k.ball(1.0, Vector3(s * 0.6, 1.33, 0), plate_d, Vector3(0.27, 0.15, 0.28), Vector3(0, 0, s * -28))
		k.spike(Vector3(s * 0.55, 1.66, 0), Vector3(s * 0.64, 1.9, 0.04), 0.08, bronze)
		k.spike(Vector3(s * 0.62, 1.6, -0.12), Vector3(s * 0.74, 1.76, -0.16), 0.055, bronze)
		k.limb(Vector3(s * 0.5, 1.38, 0), Vector3(s * 0.57, 1.0, 0), 0.12, iron)
		k.cyl(0.135, 0.16, 0.3, Vector3(s * 0.59, 0.88, 0), plate)
		k.box(Vector3(0.24, 0.23, 0.26), Vector3(s * 0.62, 0.7, -0.03), iron)
		k.box(Vector3(0.21, 0.05, 0.06), Vector3(s * 0.62, 0.67, -0.17), ember, Vector3.ZERO, 1.4)
	k.on("weapon_r")
	var hx := 0.62
	k.cyl(0.045, 0.05, 1.7, Vector3(hx, 1.06, -0.04), leather)
	k.ball(0.085, Vector3(hx, 0.2, -0.04), bronze)
	for hy in [0.5, 0.8, 1.45]:
		k.cyl(0.06, 0.06, 0.07, Vector3(hx, hy, -0.04), bronze)
	var hc := Vector3(hx, 2.0, -0.04)
	k.box(Vector3(0.4, 0.46, 0.8), hc, iron)
	k.box(Vector3(0.44, 0.5, 0.1), hc + Vector3(0, 0, -0.36), bronze)
	k.box(Vector3(0.44, 0.5, 0.1), hc + Vector3(0, 0, 0.36), bronze)
	k.box(Vector3(0.36, 0.42, 0.06), hc + Vector3(0, 0, -0.43), ember, Vector3.ZERO, 1.3)
	k.box(Vector3(0.36, 0.42, 0.06), hc + Vector3(0, 0, 0.43), ember, Vector3.ZERO, 1.3)
	k.box(Vector3(0.43, 0.49, 0.1), hc, plate_d)
	for s2 in [-1.0, 1.0]:
		k.box(Vector3(0.02, 0.26, 0.5), hc + Vector3(s2 * 0.2, 0, 0), ember, Vector3.ZERO, 2.0)
	k.spike(hc + Vector3(0, 0.23, 0), hc + Vector3(0, 0.45, 0), 0.09, bronze)
	var p := _base_params()
	p.merge({"radius": 0.55, "height": 1.95, "glow": Color("ff7a2f"), "rim": Color(1.0, 0.72, 0.45),
		"attack": "overhead", "run_freq": 8.5, "stride": 0.65, "arm_swing": 0.35, "lean": 0.12,
		"w_idle_r": Vector3(-0.42, 0, 0.12), "atk_dur": 0.62, "enemy": false}, true)
	return k.finish(p)

static func _riftdancer() -> Dictionary:
	var k := RB.new()
	var hood := Color("54327e"); var dark := Color("261c36"); var leather := Color("5e3e2c"); var metal := Color("8a7aaa")
	var scarf := Color("27c9b5"); var teal := Color("3ff0dc"); var violet := Color("b45cff"); var blade := Color("c8f6ff")
	var shadow := Color("0a0810")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.95, 0))
	k.bone("chest", "hips", Vector3(0, 1.22, 0))
	k.bone("head", "chest", Vector3(0, 1.5, 0))
	k.bone("arm_l", "chest", Vector3(-0.27, 1.38, 0))
	k.bone("arm_r", "chest", Vector3(0.27, 1.38, 0))
	k.bone("weapon_l", "arm_l", Vector3(-0.33, 0.86, -0.04))
	k.bone("weapon_r", "arm_r", Vector3(0.33, 0.86, -0.04))
	k.bone("leg_l", "hips", Vector3(-0.12, 0.93, 0))
	k.bone("leg_r", "hips", Vector3(0.12, 0.93, 0))
	k.bone("scarf1", "chest", Vector3(0, 1.42, 0.14))
	k.bone("scarf2", "scarf1", Vector3(0, 1.3, 0.56))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.12, 0.93, 0), Vector3(s * 0.13, 0.52, -0.02), 0.09, dark)
		k.limb(Vector3(s * 0.13, 0.52, -0.02), Vector3(s * 0.13, 0.12, 0.02), 0.075, leather)
		k.cyl(0.095, 0.095, 0.05, Vector3(s * 0.125, 0.7, 0), metal)
		k.box(Vector3(0.12, 0.1, 0.3), Vector3(s * 0.13, 0.05, -0.07), dark)
	k.on("hips")
	k.cyl(0.19, 0.21, 0.16, Vector3(0, 0.95, 0), leather)
	k.box(Vector3(0.24, 0.52, 0.03), Vector3(0, 0.68, -0.17), hood, Vector3(8, 0, 0))
	k.box(Vector3(0.26, 0.56, 0.03), Vector3(0, 0.68, 0.17), hood, Vector3(-10, 0, 0))
	k.ball(0.06, Vector3(0, 0.97, -0.21), violet, Vector3.ONE, Vector3.ZERO, 2.4)
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.22, 0), dark, Vector3(0.25, 0.29, 0.19))
	k.ball(1.0, Vector3(0, 1.31, -0.05), hood, Vector3(0.25, 0.2, 0.17))
	k.box(Vector3(0.06, 0.5, 0.04), Vector3(0, 1.22, -0.18), metal, Vector3(0, 0, 35))
	k.torus(0.08, 0.19, Vector3(0, 1.43, 0), scarf, Vector3.ZERO, -1, 10, 5)
	k.on("scarf1")
	k.box(Vector3(0.26, 0.035, 0.46), Vector3(0, 1.36, 0.36), scarf, Vector3(-18, 0, 0))
	k.on("scarf2")
	k.box(Vector3(0.24, 0.035, 0.56), Vector3(0, 1.25, 0.82), scarf, Vector3(-10, 0, 0))
	k.box(Vector3(0.26, 0.045, 0.1), Vector3(0, 1.2, 1.1), teal, Vector3(-10, 0, 0), 1.4)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.56, 0.02), hood, Vector3(0.21, 0.23, 0.23))
	k.spike(Vector3(0, 1.64, 0.1), Vector3(0, 1.74, 0.46), 0.14, hood)
	k.ball(1.0, Vector3(0, 1.53, -0.15), shadow, Vector3(0.14, 0.14, 0.07))
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.06, 0.024, 0.02), Vector3(s * 0.05, 1.55, -0.205), teal, Vector3(0, 0, s * -12), 3.2)
	var crescent := PackedVector2Array([Vector2(0, -0.03), Vector2(0.18, -0.07), Vector2(0.38, -0.06), Vector2(0.56, 0.02),
		Vector2(0.7, 0.17), Vector2(0.6, 0.11), Vector2(0.44, 0.06), Vector2(0.28, 0.04), Vector2(0.12, 0.04), Vector2(0, 0.04)])
	var edge := PackedVector2Array([Vector2(0.2, -0.075), Vector2(0.38, -0.068), Vector2(0.56, 0.0), Vector2(0.7, 0.17),
		Vector2(0.58, 0.06), Vector2(0.4, -0.02), Vector2(0.2, -0.04)])
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.29, 1.4, 0), metal, Vector3(0.13, 0.1, 0.13))
		k.limb(Vector3(s * 0.27, 1.38, 0), Vector3(s * 0.32, 0.9, -0.02), 0.07, dark)
		k.cyl(0.07, 0.082, 0.22, Vector3(s * 0.315, 1.0, -0.01), metal)
		k.cyl(0.086, 0.086, 0.04, Vector3(s * 0.315, 1.06, -0.01), teal, Vector3.ZERO, 1.6)
		k.ball(0.065, Vector3(s * 0.33, 0.85, -0.04), leather)
		k.on("weapon_l" if s < 0 else "weapon_r")
		var o := Vector3(s * 0.33, 0.86, -0.04)
		k.box(Vector3(0.045, 0.045, 0.16), o + Vector3(0, 0, 0.04), leather)
		k.extrude(crescent, 0.03, o + Vector3(0, 0, -0.05), blade, Vector3(0, 90, 0), Vector3(1.7, 1.9, 1), 0.3)
		k.extrude(edge, 0.042, o + Vector3(0, 0, -0.05), teal, Vector3(0, 90, 0), Vector3(1.7, 1.9, 1), 1.8)
	var p := _base_params()
	p.merge({"radius": 0.45, "height": 1.8, "glow": Color("3ff0dc"), "rim": Color(0.6, 0.9, 1.0),
		"attack": "slash2", "run_freq": 12.5, "stride": 0.95, "arm_swing": 0.3, "lean": 0.38, "atk_dur": 0.42,
		"enemy": false, "run_arms": Vector3(-0.6, 0, 0),
		"w_idle_r": Vector3(0.5, -0.5, 0), "w_idle_l": Vector3(0.5, 0.5, 0)}, true)
	return k.finish(p)

static func _hivemother() -> Dictionary:
	var k := RB.new()
	var chit := Color("346448"); var chit_hi := Color("5e9058"); var plate := Color("e2d092"); var acid := Color("9cff3a")
	var belly := Color("7a3a64"); var wing := Color(0.55, 0.85, 0.45)
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3(0, 0.78, -0.05))
	k.bone("abdomen", "body", Vector3(0, 0.85, 0.36))
	k.bone("chest", "body", Vector3(0, 1.15, -0.3))
	k.bone("head", "chest", Vector3(0, 1.66, -0.33))
	k.bone("arm_l", "chest", Vector3(-0.26, 1.5, -0.32))
	k.bone("arm_r", "chest", Vector3(0.26, 1.5, -0.32))
	k.bone("leg_fl", "body", Vector3(-0.26, 0.72, -0.3))
	k.bone("leg_fr", "body", Vector3(0.26, 0.72, -0.3))
	k.bone("leg_bl", "body", Vector3(-0.26, 0.72, 0.12))
	k.bone("leg_br", "body", Vector3(0.26, 0.72, 0.12))
	k.bone("wing_l", "chest", Vector3(-0.1, 1.5, -0.14))
	k.bone("wing_r", "chest", Vector3(0.1, 1.5, -0.14))
	k.on("body")
	k.ball(1.0, Vector3(0, 0.8, -0.08), chit, Vector3(0.34, 0.27, 0.42))
	k.ball(1.0, Vector3(0, 0.69, -0.08), belly, Vector3(0.28, 0.17, 0.36))
	k.on("abdomen")
	k.ball(1.0, Vector3(0, 0.86, 0.42), chit, Vector3(0.36, 0.32, 0.28))
	k.ball(1.0, Vector3(0, 0.88, 0.6), acid, Vector3(0.33, 0.28, 0.16), Vector3.ZERO, 1.5)
	k.ball(1.0, Vector3(0, 0.9, 0.8), chit, Vector3(0.42, 0.37, 0.3), Vector3.ZERO, -1, 12, 7)
	k.ball(1.0, Vector3(0, 1.06, 0.8), chit_hi, Vector3(0.3, 0.14, 0.25))
	k.ball(1.0, Vector3(0, 0.92, 1.0), acid, Vector3(0.29, 0.25, 0.14), Vector3.ZERO, 1.5)
	k.ball(1.0, Vector3(0, 0.92, 1.15), chit, Vector3(0.31, 0.28, 0.26))
	k.spike(Vector3(0, 0.92, 1.33), Vector3(0, 0.78, 1.62), 0.1, plate)
	k.on("chest")
	k.limb(Vector3(0, 0.95, -0.22), Vector3(0, 1.25, -0.3), 0.16, chit)
	k.ball(1.0, Vector3(0, 1.36, -0.32), chit, Vector3(0.28, 0.28, 0.22))
	k.ball(1.0, Vector3(0, 1.36, -0.45), plate, Vector3(0.2, 0.22, 0.1))
	k.ball(0.06, Vector3(0, 1.4, -0.55), acid, Vector3.ONE, Vector3.ZERO, 1.2)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.74, -0.34), chit, Vector3(0.17, 0.19, 0.19))
	k.ball(1.0, Vector3(0, 1.7, -0.48), plate, Vector3(0.13, 0.12, 0.08))
	for s in [-1.0, 1.0]:
		k.ball(0.048, Vector3(s * 0.075, 1.76, -0.51), acid, Vector3.ONE, Vector3.ZERO, 3.2)
		k.spike(Vector3(s * 0.06, 1.63, -0.5), Vector3(s * 0.02, 1.52, -0.6), 0.035, plate)
	for i in 5:
		var a := deg_to_rad(-56.0 + i * 28.0)
		var base := Vector3(sin(a) * 0.12, 1.86, -0.31)
		var tip := Vector3(sin(a) * 0.36, 2.2 - absf(a) * 0.18, -0.2)
		k.spike(base, tip, 0.045, plate)
		k.ball(0.035, tip, acid, Vector3.ONE, Vector3.ZERO, 3.0, 6, 4)
	var scythe := PackedVector2Array([Vector2(-0.06, 0), Vector2(-0.06, 0.24), Vector2(0.04, 0.44), Vector2(0.24, 0.56),
		Vector2(0.46, 0.52), Vector2(0.62, 0.34), Vector2(0.44, 0.42), Vector2(0.26, 0.42), Vector2(0.12, 0.32), Vector2(0.06, 0.16), Vector2(0.06, 0)])
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.29, 1.5, -0.32), chit_hi, Vector3(0.13, 0.11, 0.13))
		k.spike(Vector3(s * 0.3, 1.56, -0.3), Vector3(s * 0.44, 1.8, -0.2), 0.05, plate)
		k.limb(Vector3(s * 0.28, 1.48, -0.32), Vector3(s * 0.46, 1.2, -0.5), 0.06, chit)
		k.ball(0.075, Vector3(s * 0.46, 1.2, -0.5), chit_hi)
		k.extrude(scythe, 0.05, Vector3(s * 0.46, 1.2, -0.5), plate, Vector3(0, 90, 0), Vector3(1.0, 1.0, 1))
	for leg in [["leg_fl", -1.0, -0.3, -0.22], ["leg_fr", 1.0, -0.3, -0.22], ["leg_bl", -1.0, 0.12, 0.28], ["leg_br", 1.0, 0.12, 0.28]]:
		k.on(leg[0])
		var s: float = leg[1]; var z0: float = leg[2]; var dz: float = leg[3]
		var hip := Vector3(s * 0.26, 0.72, z0)
		var knee := Vector3(s * 0.6, 0.92, z0 + dz)
		var foot := Vector3(s * 0.7, 0.02, z0 + dz * 1.4)
		k.limb(hip, knee, 0.085, chit)
		k.ball(0.09, knee, plate)
		k.limb(knee, foot, 0.065, chit_hi)
		k.spike(foot + Vector3(0, 0.12, 0), foot + Vector3(0, -0.02, 0), 0.06, plate, -1, 5)
	k.cur_layer = 1
	var wpoly := PackedVector2Array([Vector2(0, -0.02), Vector2(0.25, 0.09), Vector2(0.6, 0.13), Vector2(0.88, 0.07),
		Vector2(0.98, -0.01), Vector2(0.72, -0.1), Vector2(0.35, -0.09)])
	for s in [-1.0, 1.0]:
		k.on("wing_l" if s < 0 else "wing_r")
		k.extrude(wpoly, 0.01, Vector3(s * 0.1, 1.52, -0.12), wing, Vector3(-90, s * -40, s * 25), Vector3(s * 1.15, 1.0, 1.0))
		k.extrude(wpoly, 0.01, Vector3(s * 0.1, 1.46, -0.08), wing, Vector3(-90, s * -70, s * 12), Vector3(s * 0.85, 0.8, 1.0))
	k.cur_layer = 0
	var p := _base_params()
	p.merge({"style": "taur", "radius": 0.62, "height": 2.05, "glow": Color("9cff3a"), "rim": Color(0.75, 1.0, 0.6),
		"attack": "spit", "run_freq": 11.0, "stride": 0.45, "arm_swing": 0.15, "atk_dur": 0.45, "enemy": false}, true)
	return k.finish(p)

# =================================================================== ENEMIES

static func _gnawer() -> Dictionary:
	var k := RB.new()
	var fur := Color("4a3c3e"); var fur_d := Color("2a2226"); var belly := Color("a88a7a"); var tooth := Color("f6eed4")
	var eye := Color("ff3a2a"); var spike := Color("efe2c0"); var tail := Color("c88e7e")
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3(0, 0.45, 0))
	k.bone("head", "body", Vector3(0, 0.52, -0.34))
	k.bone("leg_fl", "body", Vector3(-0.15, 0.38, -0.22))
	k.bone("leg_fr", "body", Vector3(0.15, 0.38, -0.22))
	k.bone("leg_bl", "body", Vector3(-0.17, 0.4, 0.2))
	k.bone("leg_br", "body", Vector3(0.17, 0.4, 0.2))
	k.bone("tail", "body", Vector3(0, 0.45, 0.36))
	k.on("body")
	k.ball(1.0, Vector3(0, 0.48, 0), fur, Vector3(0.27, 0.24, 0.38), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 0.6, -0.08), fur_d, Vector3(0.23, 0.2, 0.24), Vector3.ZERO, -1, 8, 5)
	for i in 4:
		k.spike(Vector3(0, 0.72 - i * 0.03, -0.16 + i * 0.12), Vector3(0, 0.92 - i * 0.05, -0.06 + i * 0.14), 0.05, spike, -1, 4)
	k.on("head")
	k.ball(1.0, Vector3(0, 0.52, -0.42), fur, Vector3(0.21, 0.17, 0.22), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 0.46, -0.6), belly, Vector3(0.12, 0.1, 0.14), Vector3.ZERO, -1, 8, 5)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.035, 0.1, 0.025), Vector3(s * 0.025, 0.37, -0.69), tooth)
		k.spike(Vector3(s * 0.12, 0.6, -0.36), Vector3(s * 0.2, 0.8, -0.32), 0.065, fur_d, -1, 4)
		k.ball(0.038, Vector3(s * 0.09, 0.56, -0.57), eye, Vector3.ONE, Vector3.ZERO, 3.0, 6, 4)
		k.spike(Vector3(s * 0.09, 0.42, -0.6), Vector3(s * 0.17, 0.5, -0.74), 0.03, tooth, -1, 4)
	for leg in [["leg_fl", -1.0, -0.22, 0.055], ["leg_fr", 1.0, -0.22, 0.055], ["leg_bl", -1.0, 0.2, 0.065], ["leg_br", 1.0, 0.2, 0.065]]:
		k.on(leg[0])
		var s: float = leg[1]; var z: float = leg[2]; var r: float = leg[3]
		if z > 0:
			k.ball(1.0, Vector3(s * 0.17, 0.4, z), fur, Vector3(0.1, 0.14, 0.14), Vector3.ZERO, -1, 6, 4)
		k.limb(Vector3(s * 0.16, 0.38, z), Vector3(s * 0.17, 0.04, z - 0.05), r, fur_d, -1, 6)
		k.box(Vector3(0.08, 0.04, 0.12), Vector3(s * 0.17, 0.02, z - 0.1), fur_d)
	k.on("tail")
	k.tube(Vector3(0, 0.45, 0.34), Vector3(0, 0.3, 0.9), 0.045, 0.015, tail, -1, 5)
	var p := _base_params()
	p.merge({"style": "quad", "radius": 0.38, "height": 0.85, "glow": Color("ff3a2a"), "rim": Color(1.0, 0.75, 0.6),
		"attack": "bite", "run_freq": 16.0, "stride": 0.8, "atk_dur": 0.35}, true)
	return k.finish(p)

static func _shieldbearer() -> Dictionary:
	var k := RB.new()
	var iron := Color("6e6860"); var rust := Color("9a5430"); var cloth := Color("7a2a24"); var leather := Color("5e4230")
	var skin := Color("7f8e6a"); var dark := Color("141210"); var bronze := Color("b07a3c"); var eye := Color("ffb040")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.78, 0))
	k.bone("chest", "hips", Vector3(0, 1.02, 0))
	k.bone("head", "chest", Vector3(0, 1.32, -0.08))
	k.bone("arm_l", "chest", Vector3(-0.42, 1.24, 0))
	k.bone("arm_r", "chest", Vector3(0.42, 1.24, 0))
	k.bone("weapon_r", "arm_r", Vector3(0.47, 0.66, -0.04))
	k.bone("leg_l", "hips", Vector3(-0.17, 0.76, 0))
	k.bone("leg_r", "hips", Vector3(0.17, 0.76, 0))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.17, 0.76, 0), Vector3(s * 0.19, 0.15, 0), 0.12, leather, -1, 6)
		k.ball(1.0, Vector3(s * 0.19, 0.45, -0.09), iron, Vector3(0.12, 0.1, 0.08), Vector3.ZERO, -1, 6, 4)
		k.box(Vector3(0.22, 0.14, 0.3), Vector3(s * 0.19, 0.07, -0.04), iron)
	k.on("hips")
	k.cyl(0.3, 0.33, 0.18, Vector3(0, 0.8, 0), leather)
	k.box(Vector3(0.3, 0.36, 0.04), Vector3(0, 0.6, -0.29), cloth)
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.06, 0), iron, Vector3(0.43, 0.37, 0.34), Vector3.ZERO, -1, 10, 6)
	k.ball(1.0, Vector3(0, 1.22, 0.12), rust, Vector3(0.37, 0.23, 0.27), Vector3.ZERO, -1, 8, 5)
	k.box(Vector3(0.52, 0.08, 0.05), Vector3(0, 1.18, -0.33), bronze, Vector3(0, 0, -18))
	k.on("head")
	k.cyl(0.17, 0.19, 0.3, Vector3(0, 1.38, -0.1), iron)
	k.hemi(1.0, Vector3(0, 1.53, -0.1), iron, Vector3(0.17, 0.12, 0.17), Vector3.ZERO, -1, 8, 3)
	k.box(Vector3(0.25, 0.035, 0.03), Vector3(0, 1.4, -0.29), eye, Vector3.ZERO, 2.6)
	k.box(Vector3(0.05, 0.2, 0.05), Vector3(0, 1.36, -0.3), iron)
	k.spike(Vector3(0, 1.6, -0.1), Vector3(0, 1.82, -0.04), 0.05, bronze, -1, 5)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.46, 1.32, 0), rust, Vector3(0.21, 0.17, 0.21), Vector3.ZERO, -1, 8, 5)
		k.limb(Vector3(s * 0.44, 1.24, 0), Vector3(s * 0.47, 0.75, -0.02), 0.11, skin, -1, 6)
		k.box(Vector3(0.19, 0.18, 0.2), Vector3(s * 0.47, 0.66, -0.04), iron)
	k.on("arm_l")
	var sc := Vector3(-0.14, 0.88, -0.56)
	k.box(Vector3(0.95, 1.22, 0.08), sc, Color("4e443c"))
	k.box(Vector3(0.22, 1.22, 0.09), sc + Vector3(0.0, 0, 0), Color("8a2a20"))
	k.box(Vector3(1.0, 0.08, 0.11), sc + Vector3(0, 0.61, 0), iron)
	k.box(Vector3(1.0, 0.08, 0.11), sc + Vector3(0, -0.61, 0), iron)
	k.box(Vector3(0.08, 1.25, 0.11), sc + Vector3(-0.48, 0, 0), iron)
	k.box(Vector3(0.08, 1.25, 0.11), sc + Vector3(0.48, 0, 0), iron)
	k.box(Vector3(0.95, 0.05, 0.1), sc + Vector3(0, 0.25, 0), iron)
	k.box(Vector3(0.95, 0.05, 0.1), sc + Vector3(0, -0.28, 0), iron)
	k.ball(1.0, sc + Vector3(0, 0.0, -0.05), bronze, Vector3(0.17, 0.17, 0.09), Vector3.ZERO, -1, 8, 4)
	for i in 3:
		k.spike(sc + Vector3(-0.32 + i * 0.32, 0.64, 0), sc + Vector3(-0.32 + i * 0.32, 0.86, 0), 0.05, iron, -1, 4)
	k.on("weapon_r")
	k.cyl(0.035, 0.04, 0.7, Vector3(0.47, 0.88, -0.04), leather, Vector3.ZERO, -1, 6)
	k.ball(0.13, Vector3(0.47, 1.25, -0.04), iron, Vector3.ONE, Vector3.ZERO, -1, 8, 5)
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(0, 1, 0)]:
		k.spike(Vector3(0.47, 1.25, -0.04) + d * 0.1, Vector3(0.47, 1.25, -0.04) + d * 0.22, 0.04, bronze, -1, 4)
	var p := _base_params()
	p.merge({"radius": 0.6, "height": 1.7, "glow": Color("ffb040"), "attack": "overhead", "run_freq": 7.0,
		"stride": 0.5, "arm_swing": 0.15, "lean": 0.1, "w_idle_r": Vector3(0.5, 0, 0), "atk_dur": 0.6,
		"atk_override": {"arm_l": [[0.3, Vector3(0.5, 0, -0.1)], [0.5, Vector3(0.9, 0, 0)], [0.75, Vector3(0.9, 0, 0)]]}}, true)
	return k.finish(p)

static func _hexcaster() -> Dictionary:
	var k := RB.new()
	var robe := Color("3a2c6a"); var robe_d := Color("21193c"); var trim := Color("a874e0"); var skin := Color("7a9a7a")
	var hex := Color("e04aff"); var bone := Color("ddd2b8"); var dark := Color("0c0a12")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.7, 0))
	k.bone("chest", "hips", Vector3(0, 1.05, 0))
	k.bone("head", "chest", Vector3(0, 1.36, -0.04))
	k.bone("arm_l", "chest", Vector3(-0.24, 1.24, 0))
	k.bone("arm_r", "chest", Vector3(0.24, 1.24, 0))
	k.bone("orb", "root", Vector3(0.34, 1.55, -0.42))
	k.on("hips")
	k.cyl(0.17, 0.42, 0.74, Vector3(0, 0.37, 0), robe, Vector3.ZERO, -1, 9)
	k.torus(0.37, 0.44, Vector3(0, 0.05, 0), trim, Vector3.ZERO, -1, 10, 4)
	k.box(Vector3(0.15, 0.62, 0.03), Vector3(0, 0.4, -0.31), trim, Vector3(-14, 0, 0))
	k.cyl(0.2, 0.2, 0.06, Vector3(0, 0.82, 0), trim)
	k.ball(0.045, Vector3(0.12, 0.74, -0.17), bone, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
	k.ball(0.04, Vector3(-0.1, 0.72, -0.17), hex, Vector3.ONE, Vector3.ZERO, 2.0, 6, 4)
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.05, 0), robe, Vector3(0.24, 0.28, 0.2), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 1.22, 0), robe_d, Vector3(0.31, 0.13, 0.25), Vector3.ZERO, -1, 8, 5)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.4, -0.02), robe_d, Vector3(0.17, 0.19, 0.19), Vector3.ZERO, -1, 8, 5)
	k.cyl(0.32, 0.32, 0.03, Vector3(0, 1.52, -0.02), robe_d, Vector3.ZERO, -1, 10)
	k.cone(0.19, 0.58, Vector3(0, 1.78, 0.05), robe, Vector3(-22, 0, 0), -1, 7)
	k.spike(Vector3(0, 2.02, 0.15), Vector3(0, 2.12, 0.42), 0.06, robe, -1, 5)
	k.ball(1.0, Vector3(0, 1.37, -0.15), dark, Vector3(0.11, 0.11, 0.05), Vector3.ZERO, -1, 6, 4)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.04, 0.022, 0.02), Vector3(s * 0.045, 1.39, -0.19), hex, Vector3.ZERO, 3.2)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.tube(Vector3(s * 0.25, 1.24, 0), Vector3(s * 0.32, 0.82, -0.1), 0.07, 0.14, robe, -1, 7)
		k.ball(0.065, Vector3(s * 0.33, 0.76, -0.12), skin, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
	k.on("orb")
	var oc := Vector3(0.34, 1.55, -0.42)
	k.ball(0.15, oc, hex, Vector3.ONE, Vector3.ZERO, 2.8, 10, 6)
	k.torus(0.2, 0.24, oc, trim, Vector3(60, 0, 20), 0.8, 10, 4)
	for i in 3:
		var a := TAU * i / 3.0
		k.prism(Vector3(0.06, 0.14, 0.06), oc + Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), hex, Vector3(0, 0, 180 * (i % 2)), 2.0)
	var p := _base_params()
	p.merge({"style": "robe", "radius": 0.45, "height": 1.75, "glow": Color("e04aff"), "rim": Color(0.85, 0.65, 1.0),
		"attack": "thrust", "run_freq": 7.0, "atk_dur": 0.5}, true)
	return k.finish(p)

static func _burrower() -> Dictionary:
	var k := RB.new()
	var flesh := Color("c08a72"); var plate := Color("63503e"); var plate_hi := Color("85705a"); var maw := Color("ff6a3a")
	var tooth := Color("efe2c4"); var dirt := Color("5e4632"); var dirt_d := Color("6e5a48")
	k.bone("root", "", Vector3.ZERO)
	k.bone("mound", "root", Vector3.ZERO)
	k.bone("seg1", "root", Vector3(0, 0.2, 0))
	k.bone("seg2", "seg1", Vector3(0, 0.55, 0))
	k.bone("seg3", "seg2", Vector3(0, 0.9, -0.04))
	k.bone("head", "seg3", Vector3(0, 1.18, -0.1))
	k.on("mound")
	k.ball(1.0, Vector3(0, 0.0, 0), dirt, Vector3(0.78, 0.24, 0.78), Vector3.ZERO, -1, 10, 5)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		k.box(Vector3(0.2, 0.14, 0.17), Vector3(cos(a) * 0.66, 0.05, sin(a) * 0.66), dirt_d if i % 2 == 0 else dirt, Vector3(i * 17, i * 40, i * 23))
	k.ball(1.0, Vector3(0.0, 0.1, 0.0), Color("7a6046"), Vector3(0.5, 0.16, 0.5), Vector3.ZERO, -1, 8, 4)
	k.on("seg1")
	k.ball(1.0, Vector3(0, 0.3, 0), flesh, Vector3(0.33, 0.27, 0.33), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 0.36, 0.1), plate, Vector3(0.31, 0.22, 0.27), Vector3.ZERO, -1, 8, 5)
	k.on("seg2")
	k.ball(1.0, Vector3(0, 0.63, -0.02), flesh, Vector3(0.3, 0.25, 0.3), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 0.69, 0.08), plate_hi, Vector3(0.29, 0.21, 0.25), Vector3.ZERO, -1, 8, 5)
	k.on("seg3")
	k.ball(1.0, Vector3(0, 0.95, -0.06), flesh, Vector3(0.28, 0.23, 0.28), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 1.0, 0.04), plate, Vector3(0.27, 0.21, 0.24), Vector3.ZERO, -1, 8, 5)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.27, -0.14), plate, Vector3(0.31, 0.28, 0.31), Vector3.ZERO, -1, 8, 6)
	k.ball(1.0, Vector3(0, 1.25, -0.41), maw, Vector3(0.18, 0.18, 0.08), Vector3.ZERO, 1.8, 8, 4)
	for i in 6:
		var a := TAU * i / 6.0
		var c := Vector3(cos(a) * 0.17, 1.25 + sin(a) * 0.17, -0.42)
		k.spike(c, c + Vector3(-cos(a) * 0.08, -sin(a) * 0.08, -0.07), 0.03, tooth, -1, 4)
	for s in [-1.0, 1.0]:
		k.spike(Vector3(s * 0.16, 1.18, -0.36), Vector3(s * 0.1, 1.0, -0.62), 0.06, tooth, -1, 5)
		k.spike(Vector3(s * 0.12, 1.45, -0.1), Vector3(s * 0.2, 1.64, 0.02), 0.05, plate_hi, -1, 4)
		k.ball(0.035, Vector3(s * 0.17, 1.35, -0.38), maw, Vector3.ONE, Vector3.ZERO, 3.0, 6, 4)
	var p := _base_params()
	p.merge({"style": "worm", "radius": 0.5, "height": 1.55, "glow": Color("ff6a3a"), "rim": Color(1.0, 0.8, 0.6),
		"attack": "bite", "atk_dur": 0.45}, true)
	return k.finish(p)

static func _bloater() -> Dictionary:
	var k := RB.new()
	var skin := Color("a8b468"); var skin_d := Color("5f6e38"); var belly := Color("c8c88a"); var pust := Color("c8ff4a")
	var mouth := Color("3a1418"); var eye := Color("ffe04a"); var stitch := Color("3a2a1a")
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3(0, 0.78, 0))
	k.bone("head", "body", Vector3(0, 1.32, -0.28))
	k.bone("leg_l", "root", Vector3(-0.28, 0.42, 0))
	k.bone("leg_r", "root", Vector3(0.28, 0.42, 0))
	k.bone("arm_l", "body", Vector3(-0.6, 0.92, -0.05))
	k.bone("arm_r", "body", Vector3(0.6, 0.92, -0.05))
	k.on("body")
	k.ball(1.0, Vector3(0, 0.82, 0), skin, Vector3(0.68, 0.62, 0.64), Vector3.ZERO, -1, 12, 7)
	k.ball(1.0, Vector3(0, 0.7, -0.25), belly, Vector3(0.48, 0.42, 0.42), Vector3.ZERO, -1, 10, 6)
	var dirs := [Vector3(0.5, 0.6, -0.4), Vector3(-0.6, 0.4, -0.3), Vector3(0.2, 0.9, 0.2), Vector3(-0.3, 0.7, 0.6),
		Vector3(0.7, 0.2, 0.4), Vector3(-0.75, -0.1, 0.3), Vector3(0.3, 0.3, 0.85), Vector3(-0.1, 0.95, -0.2)]
	for i in dirs.size():
		var d: Vector3 = (dirs[i] as Vector3).normalized()
		var pos := Vector3(0, 0.82, 0) + Vector3(d.x * 0.66, d.y * 0.6, d.z * 0.62)
		k.ball(0.09 + 0.04 * (i % 3), pos, pust, Vector3.ONE, Vector3.ZERO, 1.8, 6, 4)
	for i in 3:
		k.box(Vector3(0.24, 0.03, 0.02), Vector3(-0.05, 0.55 + i * 0.12, -0.66 + i * 0.02), stitch, Vector3(0, 0, 70))
	k.on("head")
	k.ball(1.0, Vector3(0, 1.38, -0.32), skin, Vector3(0.2, 0.17, 0.18), Vector3.ZERO, -1, 8, 5)
	k.box(Vector3(0.2, 0.05, 0.04), Vector3(0, 1.31, -0.48), mouth)
	for s in [-1.0, 1.0]:
		k.ball(0.045, Vector3(s * 0.075, 1.42, -0.47), eye, Vector3.ONE, Vector3.ZERO, 3.0, 6, 4)
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.28, 0.45, 0), Vector3(s * 0.3, 0.08, -0.02), 0.1, skin_d, -1, 6)
		k.box(Vector3(0.17, 0.08, 0.22), Vector3(s * 0.3, 0.04, -0.06), skin_d)
		k.on("arm_l" if s < 0 else "arm_r")
		k.limb(Vector3(s * 0.6, 0.92, -0.05), Vector3(s * 0.74, 0.55, -0.15), 0.07, skin_d, -1, 6)
		k.ball(0.085, Vector3(s * 0.75, 0.5, -0.16), skin_d, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
	var p := _base_params()
	p.merge({"style": "blob", "radius": 0.62, "height": 1.5, "glow": Color("c8ff4a"), "rim": Color(0.85, 1.0, 0.6),
		"attack": "bite", "run_freq": 8.0, "stride": 0.5, "atk_dur": 0.5}, true)
	return k.finish(p)

# =================================================================== BOSSES

static func _pit_brute() -> Dictionary:
	var k := RB.new()
	var rock := Color("5e5048"); var rock_hi := Color("85766a"); var hide := Color("8e5c44"); var magma := Color("ff6a1a")
	var horn := Color("e2d4b4"); var iron := Color("2e2a28"); var cloth := Color("5a2a1e")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 2.0, 0.45))
	k.bone("chest", "hips", Vector3(0, 2.9, -0.2))
	k.bone("head", "chest", Vector3(0, 3.15, -1.25))
	k.bone("arm_l", "chest", Vector3(-1.45, 3.45, -0.5))
	k.bone("arm_r", "chest", Vector3(1.45, 3.45, -0.5))
	k.bone("leg_l", "hips", Vector3(-0.7, 1.95, 0.55))
	k.bone("leg_r", "hips", Vector3(0.7, 1.95, 0.55))
	k.on("hips")
	k.ball(1.0, Vector3(0, 2.05, 0.45), hide, Vector3(1.0, 0.75, 0.8))
	k.box(Vector3(0.95, 0.95, 0.08), Vector3(0, 1.45, -0.28), cloth, Vector3(8, 0, 0))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.7, 1.95, 0.55), Vector3(s * 0.82, 0.32, 0.5), 0.45, rock)
		k.box(Vector3(0.8, 0.36, 1.0), Vector3(s * 0.84, 0.18, 0.36), rock_hi)
		k.box(Vector3(0.08, 0.9, 0.08), Vector3(s * 0.8, 1.15, 0.08), magma, Vector3(0, 0, s * 8), 1.8)
	k.on("chest")
	k.ball(1.0, Vector3(0, 2.95, -0.25), rock, Vector3(1.48, 1.18, 1.22), Vector3.ZERO, -1, 12, 8)
	for s in [-1.0, 1.0]:
		k.box(Vector3(1.05, 0.38, 0.95), Vector3(s * 0.85, 3.88, 0.0), rock_hi, Vector3(-10, 0, s * -22))
		k.spike(Vector3(s * 0.45, 3.95, 0.45), Vector3(s * 0.65, 4.65, 0.95), 0.2, horn)
		k.box(Vector3(0.09, 1.1, 0.09), Vector3(s * 0.42, 2.95, -1.38), magma, Vector3(0, 0, s * 25), 2.0)
	k.box(Vector3(0.85, 0.32, 0.85), Vector3(0, 4.05, 0.35), rock_hi, Vector3(-20, 0, 0))
	k.spike(Vector3(0, 4.1, 0.6), Vector3(0, 4.85, 1.1), 0.22, horn)
	k.ball(1.0, Vector3(0, 2.55, -1.08), magma, Vector3(0.48, 0.42, 0.16), Vector3.ZERO, 1.6)
	for i in 3:
		k.box(Vector3(1.05, 0.11, 0.14), Vector3(0, 2.32 + i * 0.24, -1.17), rock_hi)
	k.on("head")
	k.ball(1.0, Vector3(0, 3.15, -1.35), rock, Vector3(0.56, 0.5, 0.56))
	k.box(Vector3(0.98, 0.22, 0.38), Vector3(0, 3.42, -1.66), rock_hi, Vector3(10, 0, 0))
	k.box(Vector3(0.88, 0.36, 0.62), Vector3(0, 2.86, -1.56), rock_hi)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.15, 0.08, 0.05), Vector3(s * 0.21, 3.28, -1.86), magma, Vector3(0, 0, s * 12), 3.5)
		k.spike(Vector3(s * 0.32, 2.96, -1.84), Vector3(s * 0.42, 3.46, -2.05), 0.1, horn)
		k.spike(Vector3(s * 0.45, 3.5, -1.4), Vector3(s * 1.05, 3.92, -1.62), 0.17, horn)
		k.spike(Vector3(s * 1.03, 3.9, -1.6), Vector3(s * 1.12, 4.4, -1.98), 0.11, horn)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 1.55, 3.55, -0.45), rock_hi, Vector3(0.66, 0.56, 0.66))
		k.limb(Vector3(s * 1.5, 3.45, -0.5), Vector3(s * 1.85, 2.1, -0.85), 0.46, rock)
		k.limb(Vector3(s * 1.85, 2.1, -0.85), Vector3(s * 1.9, 0.78, -1.15), 0.53, rock)
		k.ball(1.0, Vector3(s * 1.9, 0.52, -1.2), rock_hi, Vector3(0.63, 0.55, 0.66))
		k.cyl(0.6, 0.6, 0.36, Vector3(s * 1.9, 1.08, -1.12), iron, Vector3.ZERO, -1, 10)
		for i in 3:
			k.torus(0.07, 0.16, Vector3(s * 2.45, 0.95 - i * 0.26, -1.0), iron, Vector3(0, i * 90, 90), -1, 8, 4)
		k.box(Vector3(0.09, 1.1, 0.09), Vector3(s * 1.95, 1.65, -1.55), magma, Vector3(-12, 0, 0), 1.8)
	var p := _base_params()
	p.merge({"radius": 1.75, "height": 4.7, "glow": Color("ff6a1a"), "rim": Color(1.0, 0.65, 0.4), "rim_strength": 0.5,
		"attack": "slam2", "run_freq": 4.5, "stride": 0.4, "arm_swing": 0.3, "lean": 0.1, "atk_dur": 1.0, "cast_dur": 0.9}, true)
	return k.finish(p)

static func _matron() -> Dictionary:
	var k := RB.new()
	var robe := Color("9a1e32"); var robe_d := Color("4a121e"); var gold := Color("e0b050"); var mask := Color("efe5cf")
	var skin := Color("5e4c60"); var flame := Color("b6ff6a"); var metal := Color("8a6a3a"); var dark := Color("0c0808")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 1.6, 0))
	k.bone("chest", "hips", Vector3(0, 2.45, -0.05))
	k.bone("head", "chest", Vector3(0, 3.1, -0.3))
	k.bone("arm_l", "chest", Vector3(-0.74, 2.85, -0.1))
	k.bone("arm_r", "chest", Vector3(0.74, 2.85, -0.1))
	k.bone("weapon_r", "arm_r", Vector3(1.02, 1.55, -0.3))
	k.on("hips")
	k.cyl(0.62, 1.22, 1.75, Vector3(0, 0.88, 0), robe, Vector3.ZERO, -1, 10)
	k.cyl(1.24, 1.27, 0.12, Vector3(0, 0.06, 0), gold, Vector3.ZERO, -1, 10)
	k.box(Vector3(0.62, 1.55, 0.05), Vector3(0, 0.95, -0.96), robe_d, Vector3(-19, 0, 0))
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.07, 1.55, 0.06), Vector3(s * 0.28, 0.95, -0.97), gold, Vector3(-19, 0, 0))
	k.on("chest")
	k.ball(1.0, Vector3(0, 2.45, -0.08), robe, Vector3(0.74, 0.72, 0.62))
	k.ball(1.0, Vector3(0, 2.92, -0.05), robe_d, Vector3(0.98, 0.38, 0.82))
	k.torus(0.32, 0.48, Vector3(0, 3.0, -0.18), gold, Vector3(15, 0, 0), -1, 12, 4)
	k.ball(0.13, Vector3(0, 2.62, -0.7), flame, Vector3.ONE, Vector3.ZERO, 2.4)
	k.on("head")
	k.ball(1.0, Vector3(0, 3.25, -0.3), robe_d, Vector3(0.4, 0.45, 0.42))
	k.ball(1.0, Vector3(0, 3.2, -0.62), mask, Vector3(0.27, 0.33, 0.12))
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.1, 0.045, 0.03), Vector3(s * 0.1, 3.28, -0.735), flame, Vector3(0, 0, s * 10), 3.2)
	k.box(Vector3(0.13, 0.025, 0.02), Vector3(0, 3.06, -0.735), dark)
	var cres := PackedVector2Array()
	for i in 13:
		var a := deg_to_rad(180.0 + i * 15.0)
		cres.append(Vector2(cos(a) * 0.8, 0.75 + sin(a) * 0.8))
	for i in 13:
		var a := deg_to_rad(360.0 - i * 15.0)
		cres.append(Vector2(cos(a) * 0.62, 0.86 + sin(a) * 0.62))
	k.extrude(cres, 0.09, Vector3(0, 3.42, -0.3), gold)
	k.ball(0.11, Vector3(0, 3.55, -0.38), flame, Vector3.ONE, Vector3.ZERO, 3.0)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.tube(Vector3(s * 0.74, 2.85, -0.1), Vector3(s * 1.0, 1.75, -0.3), 0.19, 0.32, robe)
		k.ball(1.0, Vector3(s * 1.02, 1.56, -0.32), skin, Vector3(0.13, 0.16, 0.13))
		for i in 3:
			k.spike(Vector3(s * 1.02 + (i - 1) * 0.06, 1.46, -0.36), Vector3(s * 1.04 + (i - 1) * 0.08, 1.2, -0.44), 0.035, skin, -1, 4)
	k.on("weapon_r")
	k.cyl(0.06, 0.07, 3.5, Vector3(1.02, 1.75, -0.3), metal)
	k.torus(0.16, 0.22, Vector3(1.02, 3.62, -0.42), metal, Vector3(0, 90, 90), -1, 10, 4)
	var cc := Vector3(1.02, 3.08, -0.62)
	k.box(Vector3(0.03, 0.4, 0.03), cc + Vector3(0, 0.38, 0.08), metal, Vector3(20, 0, 0))
	for r in [Vector3.ZERO, Vector3(90, 0, 0), Vector3(0, 0, 90)]:
		k.torus(0.2, 0.24, cc, metal, r, -1, 10, 4)
	k.ball(0.18, cc, flame, Vector3.ONE, Vector3.ZERO, 3.2)
	var p := _base_params()
	p.merge({"style": "robe", "radius": 1.3, "height": 4.1, "glow": Color("b6ff6a"), "rim": Color(1.0, 0.7, 0.55),
		"attack": "swipe", "run_freq": 5.0, "atk_dur": 0.75, "cast_dur": 0.9}, true)
	return k.finish(p)

static func _hollow_choir() -> Dictionary:
	var k := RB.new()
	var robe := Color("232a46"); var robe_hi := Color("3c4a7a"); var mask := Color("f2ece0"); var glow := Color("8fd8ff")
	var gold := Color("d0b878"); var dark := Color("06080e")
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3(0, 2.0, 0))
	k.bone("head", "body", Vector3(0, 3.05, -0.1))
	k.bone("arm_l", "body", Vector3(-0.7, 2.8, 0))
	k.bone("arm_r", "body", Vector3(0.7, 2.8, 0))
	k.bone("tail", "body", Vector3(0, 1.55, 0.1))
	k.bone("mask1", "root", Vector3(0, 2.6, 0))
	k.bone("mask2", "root", Vector3(0, 2.6, 0))
	k.on("body")
	k.cyl(0.42, 0.95, 1.6, Vector3(0, 2.3, 0), robe, Vector3.ZERO, -1, 9)
	k.box(Vector3(0.1, 1.3, 0.05), Vector3(0, 2.2, -0.75), glow, Vector3(-16, 0, 0), 1.8)
	k.torus(0.9, 0.98, Vector3(0, 1.52, 0), robe_hi, Vector3.ZERO, -1, 12, 4)
	k.on("tail")
	k.cyl(0.95, 0.1, 1.5, Vector3(0, 0.78, 0.1), robe, Vector3.ZERO, -1, 9)
	for i in 5:
		var a := TAU * i / 5.0
		k.spike(Vector3(cos(a) * 0.6, 1.25, 0.1 + sin(a) * 0.6), Vector3(cos(a) * 0.35, 0.25, 0.25 + sin(a) * 0.35), 0.13, robe_hi, -1, 5)
	k.on("head")
	k.ball(1.0, Vector3(0, 3.25, -0.05), robe, Vector3(0.48, 0.52, 0.5))
	k.spike(Vector3(0, 3.55, 0.1), Vector3(0, 3.95, 0.48), 0.25, robe)
	k.ball(1.0, Vector3(0, 3.2, -0.35), dark, Vector3(0.34, 0.38, 0.2))
	k.ball(1.0, Vector3(0, 3.18, -0.5), mask, Vector3(0.28, 0.36, 0.1))
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.11, 0.04, 0.03), Vector3(s * 0.1, 3.28, -0.595), glow, Vector3(0, 0, s * -15), 3.2)
	k.ball(1.0, Vector3(0, 3.02, -0.59), glow, Vector3(0.07, 0.1, 0.03), Vector3.ZERO, 3.5)
	k.torus(0.62, 0.69, Vector3(0, 3.38, 0.28), gold, Vector3(75, 0, 0), 0.9, 16, 4)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.tube(Vector3(s * 0.7, 2.8, 0), Vector3(s * 1.15, 1.9, -0.35), 0.22, 0.36, robe)
		k.ball(1.0, Vector3(s * 1.18, 1.75, -0.4), glow, Vector3(0.14, 0.18, 0.14), Vector3.ZERO, 2.2)
	for m in [["mask1", 1.0], ["mask2", -1.0]]:
		k.on(m[0])
		var x: float = 1.55 * m[1]
		k.ball(1.0, Vector3(x, 2.6, 0.05), robe, Vector3(0.26, 0.3, 0.26), Vector3.ZERO, -1, 8, 5)
		k.ball(1.0, Vector3(x, 2.58, -0.16), mask, Vector3(0.18, 0.23, 0.07), Vector3.ZERO, -1, 8, 5)
		k.ball(1.0, Vector3(x, 2.47, -0.22), glow, Vector3(0.045, 0.065, 0.02), Vector3.ZERO, 3.2, 6, 4)
		for s in [-1.0, 1.0]:
			k.box(Vector3(0.06, 0.025, 0.02), Vector3(x + s * 0.065, 2.64, -0.225), glow, Vector3.ZERO, 3.0)
		k.spike(Vector3(x, 2.42, 0.05), Vector3(x, 1.7, 0.3), 0.16, robe, -1, 5)
	var p := _base_params()
	p.merge({"style": "float", "radius": 1.4, "height": 4.0, "glow": Color("8fd8ff"), "rim": Color(0.6, 0.85, 1.0), "rim_strength": 0.6,
		"attack": "swipe", "run_freq": 4.0, "atk_dur": 0.7, "cast_dur": 1.0}, true)
	return k.finish(p)

static func _warden() -> Dictionary:
	var k := RB.new()
	var steel := Color("465068"); var steel_hi := Color("6e7a96"); var rust := Color("844026"); var chain := Color("7c7c86")
	var rune := Color("ff3a26"); var cloth := Color("561818"); var leather := Color("3e2c22"); var dark := Color("08080a")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 1.95, 0))
	k.bone("chest", "hips", Vector3(0, 2.65, 0))
	k.bone("head", "chest", Vector3(0, 3.5, -0.1))
	k.bone("arm_l", "chest", Vector3(-1.1, 3.2, 0))
	k.bone("arm_r", "chest", Vector3(1.1, 3.2, 0))
	k.bone("weapon_r", "arm_r", Vector3(1.3, 1.62, -0.12))
	k.bone("leg_l", "hips", Vector3(-0.45, 1.9, 0))
	k.bone("leg_r", "hips", Vector3(0.45, 1.9, 0))
	k.bone("cape", "chest", Vector3(0, 3.2, 0.6))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.45, 1.9, 0), Vector3(s * 0.5, 0.9, 0), 0.32, leather)
		k.ball(1.0, Vector3(s * 0.52, 0.95, -0.22), steel_hi, Vector3(0.28, 0.25, 0.2))
		k.cyl(0.3, 0.36, 0.85, Vector3(s * 0.52, 0.45, 0), steel)
		k.box(Vector3(0.56, 0.3, 0.82), Vector3(s * 0.52, 0.15, -0.1), steel_hi)
	k.on("hips")
	k.cyl(0.62, 0.66, 0.4, Vector3(0, 1.95, 0), leather, Vector3.ZERO, -1, 10)
	k.box(Vector3(0.32, 0.32, 0.08), Vector3(0, 1.95, -0.66), rust)
	k.box(Vector3(0.62, 1.3, 0.06), Vector3(0, 1.25, -0.6), cloth, Vector3(5, 0, 0))
	k.torus(0.11, 0.18, Vector3(0, 1.42, -0.66), rune, Vector3(90, 0, 0), 1.6, 10, 4)
	k.box(Vector3(0.06, 0.42, 0.05), Vector3(0, 1.12, -0.65), rune, Vector3(5, 0, 0), 1.6)
	k.torus(0.13, 0.19, Vector3(-0.66, 1.82, -0.15), chain, Vector3(0, 0, 90), -1, 8, 4)
	for i in 3:
		k.box(Vector3(0.05, 0.28, 0.08), Vector3(-0.68, 1.55 - i * 0.02, -0.24 + i * 0.1), rust, Vector3(i * 12, 0, 0))
	k.on("chest")
	k.ball(1.0, Vector3(0, 2.75, 0), steel, Vector3(1.0, 0.86, 0.72), Vector3.ZERO, -1, 12, 7)
	for i in 3:
		k.box(Vector3(0.95 - i * 0.12, 0.22, 0.12), Vector3(0, 2.25 - i * 0.2, -0.6 + i * 0.03), steel_hi if i % 2 == 0 else steel, Vector3(-8, 0, 0))
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.07, 0.65, 0.05), Vector3(s * 0.3, 2.85, -0.72), rune, Vector3(0, 0, s * -20), 1.8)
	k.box(Vector3(0.45, 0.06, 0.05), Vector3(0, 3.12, -0.68), rune, Vector3.ZERO, 1.8)
	for i in 7:
		var f := i / 6.0
		k.torus(0.055, 0.11, Vector3(lerpf(-0.85, 0.85, f), lerpf(3.25, 2.25, f), -0.7 - sin(f * PI) * 0.08), chain, Vector3(0, 90 * (i % 2), 50), -1, 8, 4)
	k.on("cape")
	k.box(Vector3(1.45, 2.3, 0.06), Vector3(0, 2.05, 0.76), cloth, Vector3(-8, 0, 0))
	k.on("head")
	k.cyl(0.36, 0.4, 0.62, Vector3(0, 3.75, -0.06), steel)
	k.hemi(1.0, Vector3(0, 4.05, -0.06), steel, Vector3(0.36, 0.25, 0.36))
	k.box(Vector3(0.44, 0.44, 0.04), Vector3(0, 3.72, -0.42), dark)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.11, 0.045, 0.03), Vector3(s * 0.1, 3.8, -0.43), rune, Vector3.ZERO, 3.8)
	for i in 5:
		k.box(Vector3(0.045, 0.5, 0.05), Vector3((i - 2) * 0.095, 3.72, -0.46), steel_hi)
	k.box(Vector3(0.5, 0.06, 0.06), Vector3(0, 3.95, -0.45), steel_hi)
	for s in [-1.0, 0.0, 1.0]:
		k.spike(Vector3(s * 0.24, 4.15, -0.06), Vector3(s * 0.42, 4.65 + (0.15 if s == 0.0 else 0.0), -0.0), 0.09, steel_hi, -1, 5)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 1.15, 3.36, 0), steel_hi, Vector3(0.62, 0.44, 0.62))
		k.spike(Vector3(s * 1.2, 3.62, 0), Vector3(s * 1.4, 4.1, 0), 0.11, steel, -1, 5)
		k.spike(Vector3(s * 1.45, 3.46, -0.2), Vector3(s * 1.8, 3.6, -0.25), 0.09, steel, -1, 5)
		k.limb(Vector3(s * 1.1, 3.15, 0), Vector3(s * 1.25, 1.95, -0.1), 0.3, leather)
		k.cyl(0.3, 0.35, 0.7, Vector3(s * 1.27, 1.98, -0.1), steel)
		k.box(Vector3(0.5, 0.45, 0.5), Vector3(s * 1.3, 1.6, -0.12), steel_hi)
	k.on("arm_l")
	for i in 3:
		k.torus(0.32, 0.38, Vector3(-1.27, 2.1 + i * 0.18, -0.1), chain, Vector3(8, 0, 0), -1, 10, 4)
	for i in 5:
		k.torus(0.06, 0.12, Vector3(-1.3, 1.3 - i * 0.2, -0.1), chain, Vector3(0, 90 * (i % 2), 90), -1, 8, 4)
	k.on("weapon_r")
	for i in 5:
		k.torus(0.07, 0.14, Vector3(1.3, 1.4 - i * 0.2, -0.12), chain, Vector3(0, 90 * (i % 2), 90), -1, 8, 4)
	var bc := Vector3(1.3, 0.45, -0.12)
	k.ball(0.42, bc, steel_hi, Vector3.ONE, Vector3.ZERO, -1, 10, 6)
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(0.7, 0.7, 0), Vector3(-0.7, 0.7, 0), Vector3(0, 0.7, -0.7)]:
		var dn: Vector3 = (d as Vector3).normalized()
		k.spike(bc + dn * 0.36, bc + dn * 0.66, 0.1, steel, -1, 5)
	k.torus(0.4, 0.46, bc, rune, Vector3(90, 0, 0), 1.2, 12, 4)
	var p := _base_params()
	p.merge({"radius": 1.65, "height": 4.6, "glow": Color("ff3a26"), "rim": Color(0.8, 0.85, 1.0), "rim_strength": 0.5,
		"attack": "overhead", "run_freq": 5.0, "stride": 0.45, "arm_swing": 0.25, "lean": 0.08, "atk_dur": 0.95, "cast_dur": 0.9,
		"w_idle_r": Vector3.ZERO,
		"atk_override": {"weapon_r": [[0.38, Vector3(0.3, 0, 0)], [0.52, Vector3(-0.4, 0, 0)], [0.72, Vector3(-0.4, 0, 0)]]}}, true)
	return k.finish(p)

# =================================================================== SUMMONS

static func _broodling() -> Dictionary:
	var k := RB.new()
	var chit := Color("2f5a40"); var chit_hi := Color("5a8a56"); var acid := Color("9cff3a"); var plate := Color("e2d092")
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3(0, 0.32, 0))
	k.bone("head", "body", Vector3(0, 0.34, -0.22))
	for leg in ["leg_fl", "leg_fr", "leg_ml", "leg_mr", "leg_bl", "leg_br"]:
		k.bone(leg, "body", Vector3(-0.12 if leg.ends_with("l") else 0.12, 0.3, {"f": -0.12, "m": 0.02, "b": 0.16}[leg.substr(4, 1)]))
	k.on("body")
	k.ball(1.0, Vector3(0, 0.34, 0.05), chit, Vector3(0.22, 0.17, 0.3), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 0.44, 0.12), acid, Vector3(0.16, 0.09, 0.18), Vector3.ZERO, 1.4, 6, 4)
	k.ball(1.0, Vector3(0, 0.34, 0.3), chit_hi, Vector3(0.16, 0.14, 0.16), Vector3.ZERO, -1, 6, 4)
	k.on("head")
	k.ball(1.0, Vector3(0, 0.36, -0.27), chit, Vector3(0.14, 0.12, 0.13), Vector3.ZERO, -1, 8, 5)
	for s in [-1.0, 1.0]:
		k.ball(0.035, Vector3(s * 0.07, 0.4, -0.37), acid, Vector3.ONE, Vector3.ZERO, 3.0, 6, 4)
		k.spike(Vector3(s * 0.06, 0.3, -0.36), Vector3(s * 0.02, 0.26, -0.48), 0.03, plate, -1, 4)
	for leg in ["leg_fl", "leg_fr", "leg_ml", "leg_mr", "leg_bl", "leg_br"]:
		k.on(leg)
		var s := -1.0 if leg.ends_with("l") else 1.0
		var z: float = {"f": -0.12, "m": 0.02, "b": 0.16}[leg.substr(4, 1)]
		var hip := Vector3(s * 0.12, 0.3, z)
		var knee := Vector3(s * 0.3, 0.38, z + signf(z) * 0.06)
		var foot := Vector3(s * 0.38, 0.0, z + signf(z) * 0.12)
		k.limb(hip, knee, 0.03, chit, -1, 5)
		k.limb(knee, foot, 0.025, chit_hi, -1, 5)
	var p := _base_params()
	p.merge({"style": "quad", "radius": 0.32, "height": 0.55, "glow": Color("9cff3a"), "rim": Color(0.75, 1.0, 0.6),
		"attack": "bite", "run_freq": 18.0, "stride": 0.6, "atk_dur": 0.32, "insect": true, "enemy": false}, true)
	return k.finish(p)

static func _ember_totem() -> Dictionary:
	var k := RB.new()
	var stone := Color("7a7068"); var stone_d := Color("4e4740"); var ember := Color("ff7a2f"); var bronze := Color("c8843e")
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3(0, 0.0, 0))
	k.bone("head", "body", Vector3(0, 1.22, 0))
	k.on("body")
	k.box(Vector3(0.66, 0.2, 0.66), Vector3(0, 0.1, 0), stone_d)
	k.box(Vector3(0.44, 0.52, 0.44), Vector3(0, 0.46, 0), stone)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.1, 0.035, 0.03), Vector3(s * 0.1, 0.56, -0.225), ember, Vector3(0, 0, s * -15), 2.6)
	k.box(Vector3(0.2, 0.06, 0.03), Vector3(0, 0.38, -0.225), ember, Vector3.ZERO, 2.0)
	k.box(Vector3(0.4, 0.42, 0.4), Vector3(0, 0.92, 0), stone_d, Vector3(0, 45, 0))
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		k.box(Vector3(0.03, 0.3, 0.03), Vector3(cos(a) * 0.205, 0.92, sin(a) * 0.205), ember, Vector3(0, -rad_to_deg(a), 0), 1.6)
	for s in [-1.0, 1.0]:
		k.spike(Vector3(s * 0.2, 0.75, 0), Vector3(s * 0.42, 0.95, 0), 0.06, stone_d, -1, 4)
	k.on("head")
	k.cyl(0.38, 0.2, 0.22, Vector3(0, 1.25, 0), bronze, Vector3.ZERO, -1, 10)
	k.ball(1.0, Vector3(0, 1.36, 0), ember, Vector3(0.3, 0.09, 0.3), Vector3.ZERO, 2.8, 8, 4)
	var p := _base_params()
	p.merge({"style": "totem", "radius": 0.4, "height": 1.5, "glow": Color("ff7a2f"), "attack": "pulse",
		"atk_dur": 0.35, "enemy": false, "flame": Vector3(0, 1.4, 0)}, true)
	return k.finish(p)

static func _choir_add() -> Dictionary:
	var k := RB.new()
	var robe := Color("2a3252"); var mask := Color("f2ece0"); var glow := Color("8fd8ff"); var dark := Color("06080e")
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3(0, 0.9, 0))
	k.bone("head", "body", Vector3(0, 1.3, -0.05))
	k.bone("tail", "body", Vector3(0, 0.75, 0.05))
	k.on("body")
	k.cyl(0.18, 0.4, 0.75, Vector3(0, 1.0, 0), robe, Vector3.ZERO, -1, 8)
	k.on("tail")
	k.cyl(0.4, 0.05, 0.6, Vector3(0, 0.33, 0.06), robe, Vector3.ZERO, -1, 8)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.42, 0), robe, Vector3(0.24, 0.27, 0.25), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 1.4, -0.14), dark, Vector3(0.17, 0.19, 0.1), Vector3.ZERO, -1, 6, 4)
	k.ball(1.0, Vector3(0, 1.39, -0.21), mask, Vector3(0.14, 0.18, 0.05), Vector3.ZERO, -1, 8, 5)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.05, 0.02, 0.02), Vector3(s * 0.05, 1.44, -0.26), glow, Vector3.ZERO, 3.0)
	k.ball(1.0, Vector3(0, 1.31, -0.255), glow, Vector3(0.035, 0.05, 0.015), Vector3.ZERO, 3.2, 6, 4)
	var p := _base_params()
	p.merge({"style": "float", "radius": 0.45, "height": 1.6, "glow": Color("8fd8ff"), "rim": Color(0.6, 0.85, 1.0),
		"attack": "bite", "atk_dur": 0.4}, true)
	return k.finish(p)

## Ward Chanter: tall pale-gold robed priest with a halo and a hanging bell-lantern. Shields nearby foes.
static func _chanter() -> Dictionary:
	var k := RB.new()
	var robe := Color("d8c8a0"); var robe_d := Color("8a7450"); var trim := Color("f2c14e"); var skin := Color("9a8a7a")
	var glow := Color("ffd860"); var dark := Color("120c06"); var chain := Color("6a5a40")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.75, 0))
	k.bone("chest", "hips", Vector3(0, 1.12, 0))
	k.bone("head", "chest", Vector3(0, 1.45, -0.03))
	k.bone("arm_l", "chest", Vector3(-0.25, 1.32, 0))
	k.bone("arm_r", "chest", Vector3(0.25, 1.32, 0))
	k.bone("orb", "root", Vector3(0.0, 1.25, -0.5))
	k.on("hips")
	k.cyl(0.18, 0.46, 0.8, Vector3(0, 0.4, 0), robe, Vector3.ZERO, -1, 10)
	k.torus(0.41, 0.48, Vector3(0, 0.05, 0), trim, Vector3.ZERO, -1, 10, 4)
	k.box(Vector3(0.18, 0.7, 0.03), Vector3(0, 0.42, -0.33), trim, Vector3(-14, 0, 0))
	k.box(Vector3(0.1, 0.1, 0.02), Vector3(0, 0.5, -0.35), glow, Vector3(-14, 0, 45), 2.2)
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.12, 0), robe, Vector3(0.26, 0.3, 0.21), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 1.3, 0), robe_d, Vector3(0.34, 0.12, 0.26), Vector3.ZERO, -1, 8, 5)
	k.torus(0.12, 0.2, Vector3(0, 1.36, 0), trim, Vector3.ZERO, -1, 10, 4)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.5, 0), robe, Vector3(0.18, 0.2, 0.2), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 1.47, -0.14), dark, Vector3(0.12, 0.12, 0.05), Vector3.ZERO, -1, 6, 4)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.04, 0.02, 0.02), Vector3(s * 0.045, 1.49, -0.18), glow, Vector3.ZERO, 3.0)
	k.torus(0.26, 0.31, Vector3(0, 1.82, 0.08), glow, Vector3(75, 0, 0), 2.6, 12, 4)
	for i in 6:
		var a := TAU * i / 6.0
		k.prism(Vector3(0.05, 0.12, 0.05), Vector3(cos(a) * 0.29, 1.82 + sin(a) * 0.29, 0.08 + sin(a) * 0.07), trim, Vector3(0, 0, rad_to_deg(a) - 90.0), 1.4)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.tube(Vector3(s * 0.26, 1.32, 0), Vector3(s * 0.2, 0.95, -0.28), 0.07, 0.15, robe, -1, 7)
		k.ball(0.06, Vector3(s * 0.16, 0.92, -0.34), skin, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
	k.on("orb")
	var oc := Vector3(0.0, 1.25, -0.5)
	k.cyl(0.015, 0.015, 0.34, oc + Vector3(0, -0.12, 0.08), chain, Vector3(-25, 0, 0), -1, 4)
	k.cyl(0.07, 0.17, 0.26, oc + Vector3(0, -0.4, 0.0), trim, Vector3.ZERO, -1, 8)
	k.ball(0.09, oc + Vector3(0, -0.52, 0.0), glow, Vector3.ONE, Vector3.ZERO, 3.0, 8, 5)
	var p := _base_params()
	p.merge({"style": "robe", "radius": 0.5, "height": 1.95, "glow": glow, "rim": Color(1.0, 0.92, 0.6),
		"attack": "thrust", "run_freq": 6.0, "atk_dur": 0.5}, true)
	return k.finish(p)

## War Drummer: squat horned brute with a war drum on its belly and two bone mallets. Doubles nearby foes' damage.
static func _drummer() -> Dictionary:
	var k := RB.new()
	var hide := Color("7a3a2a"); var hide_d := Color("4a2018"); var skin := Color("8a5a48"); var drum := Color("c8a070")
	var rim := Color("6a4a2a"); var paint := Color("ff3a20"); var bone := Color("e8dcc0"); var dark := Color("1a0c08")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.78, 0))
	k.bone("chest", "hips", Vector3(0, 1.05, 0))
	k.bone("head", "chest", Vector3(0, 1.42, -0.06))
	k.bone("arm_l", "chest", Vector3(-0.38, 1.32, 0))
	k.bone("arm_r", "chest", Vector3(0.38, 1.32, 0))
	k.bone("weapon_l", "arm_l", Vector3(-0.42, 0.82, -0.2))
	k.bone("weapon_r", "arm_r", Vector3(0.42, 0.82, -0.2))
	k.bone("leg_l", "hips", Vector3(-0.17, 0.78, 0))
	k.bone("leg_r", "hips", Vector3(0.17, 0.78, 0))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.17, 0.78, 0), Vector3(s * 0.2, 0.12, 0.02), 0.13, hide_d, -1, 6)
		k.box(Vector3(0.22, 0.12, 0.32), Vector3(s * 0.2, 0.06, -0.06), dark)
	k.on("hips")
	k.cyl(0.3, 0.33, 0.24, Vector3(0, 0.8, 0), hide, Vector3.ZERO, -1, 8)
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.12, 0.04), skin, Vector3(0.4, 0.36, 0.32), Vector3.ZERO, -1, 8, 5)
	k.box(Vector3(0.5, 0.06, 0.06), Vector3(0, 1.22, -0.27), hide_d, Vector3(0, 0, 30))
	k.cyl(0.3, 0.3, 0.34, Vector3(0, 1.0, -0.36), drum, Vector3(90, 0, 0), -1, 12)
	k.torus(0.28, 0.33, Vector3(0, 1.0, -0.2), rim, Vector3(90, 0, 0), -1, 12, 3)
	k.torus(0.28, 0.33, Vector3(0, 1.0, -0.53), rim, Vector3(90, 0, 0), -1, 12, 3)
	k.cyl(0.24, 0.24, 0.01, Vector3(0, 1.0, -0.54), paint, Vector3(90, 0, 0), 1.6, 12)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.5, -0.08), skin, Vector3(0.2, 0.19, 0.2), Vector3.ZERO, -1, 8, 5)
	k.box(Vector3(0.24, 0.04, 0.02), Vector3(0, 1.52, -0.27), paint, Vector3.ZERO, 2.4)
	for s in [-1.0, 1.0]:
		k.spike(Vector3(s * 0.15, 1.6, -0.06), Vector3(s * 0.38, 1.82, 0.02), 0.07, bone)
		k.box(Vector3(0.04, 0.02, 0.02), Vector3(s * 0.06, 1.48, -0.27), Color("ffd060"), Vector3.ZERO, 3.0)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.4, 1.36, 0), hide, Vector3(0.16, 0.12, 0.16))
		k.limb(Vector3(s * 0.38, 1.32, 0), Vector3(s * 0.42, 0.85, -0.18), 0.1, skin, -1, 6)
		k.on("weapon_l" if s < 0 else "weapon_r")
		k.limb(Vector3(s * 0.42, 0.82, -0.2), Vector3(s * 0.3, 0.98, -0.58), 0.03, bone, -1, 5)
		k.ball(0.07, Vector3(s * 0.3, 0.98, -0.6), bone, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
	var p := _base_params()
	p.merge({"radius": 0.55, "height": 1.8, "glow": paint, "rim": Color(1.0, 0.6, 0.4),
		"attack": "slam2", "run_freq": 8.0, "stride": 0.5, "arm_swing": 0.4, "lean": 0.1, "atk_dur": 0.55}, true)
	return k.finish(p)

# =================================================================== HEROES (wave 2)

## Sanguine: blood-pact warrior in dark iron and crimson cloth, a heavy curved greatblade, glowing red veins.
static func _sanguine() -> Dictionary:
	var k := RB.new()
	var iron := Color("3e3539"); var iron_hi := Color("6e6066"); var crim := Color("a3162a"); var crim_d := Color("5a0c18")
	var blood := Color("ff2a40"); var leather := Color("4a2a24"); var skin := Color("b8887a"); var bone := Color("e8dcc0"); var steel := Color("c0b4b8")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.92, 0))
	k.bone("chest", "hips", Vector3(0, 1.2, 0))
	k.bone("head", "chest", Vector3(0, 1.6, -0.02))
	k.bone("arm_l", "chest", Vector3(-0.42, 1.44, 0))
	k.bone("arm_r", "chest", Vector3(0.42, 1.44, 0))
	k.bone("weapon_r", "arm_r", Vector3(0.56, 0.78, -0.04))
	k.bone("leg_l", "hips", Vector3(-0.16, 0.9, 0))
	k.bone("leg_r", "hips", Vector3(0.16, 0.9, 0))
	k.bone("cape", "chest", Vector3(0, 1.46, 0.22))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.16, 0.88, 0), Vector3(s * 0.18, 0.5, 0), 0.12, leather)
		k.ball(1.0, Vector3(s * 0.18, 0.5, -0.08), iron_hi, Vector3(0.11, 0.1, 0.09))
		k.spike(Vector3(s * 0.18, 0.52, -0.15), Vector3(s * 0.18, 0.62, -0.27), 0.045, iron_hi, -1, 5)
		k.cyl(0.12, 0.15, 0.38, Vector3(s * 0.18, 0.27, 0), iron)
		k.box(Vector3(0.03, 0.26, 0.03), Vector3(s * 0.18, 0.3, -0.145), blood, Vector3.ZERO, 2.2)
		k.box(Vector3(0.24, 0.14, 0.38), Vector3(s * 0.18, 0.07, -0.05), iron)
	k.on("hips")
	k.cyl(0.3, 0.33, 0.2, Vector3(0, 0.93, 0), leather, Vector3.ZERO, -1, 10)
	k.box(Vector3(0.15, 0.13, 0.06), Vector3(0, 0.94, -0.33), iron_hi)
	k.ball(0.045, Vector3(0, 0.94, -0.37), blood, Vector3.ONE, Vector3.ZERO, 2.6, 6, 4)
	k.box(Vector3(0.3, 0.6, 0.04), Vector3(0, 0.6, -0.3), crim, Vector3(6, 0, 0))
	for i in 3:
		k.prism(Vector3(0.1, 0.14, 0.04), Vector3(-0.1 + i * 0.1, 0.24, -0.27), crim, Vector3(186, 0, 0))
	k.box(Vector3(0.04, 0.5, 0.045), Vector3(0, 0.62, -0.325), crim_d, Vector3(6, 0, 0))
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.22, 0.3, 0.07), Vector3(s * 0.26, 0.76, -0.12), iron, Vector3(10, s * -35, s * 12))
	k.box(Vector3(0.4, 0.62, 0.04), Vector3(0, 0.64, 0.29), crim_d, Vector3(-6, 0, 0))
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.24, 0), iron, Vector3(0.42, 0.4, 0.32), Vector3.ZERO, -1, 12, 7)
	k.ball(1.0, Vector3(0, 1.3, -0.1), iron_hi, Vector3(0.33, 0.28, 0.24))
	k.cyl(0.27, 0.3, 0.2, Vector3(0, 1.0, 0), leather)
	k.box(Vector3(0.11, 0.78, 0.05), Vector3(0.02, 1.2, -0.31), crim, Vector3(0, 0, 32))
	k.box(Vector3(0.12, 0.12, 0.04), Vector3(0, 1.34, -0.345), blood, Vector3(0, 0, 45), 2.8)
	for a in [30.0, 150.0, 210.0, 330.0, 90.0]:
		var r := deg_to_rad(a)
		k.box(Vector3(0.022, 0.16, 0.02), Vector3(cos(r) * 0.12, 1.34 + sin(r) * 0.12, -0.33), blood, Vector3(0, 0, a - 90.0), 2.0)
	k.torus(0.13, 0.27, Vector3(0, 1.48, 0), iron_hi, Vector3.ZERO, -1, 10, 5)
	k.on("cape")
	k.box(Vector3(0.6, 1.0, 0.04), Vector3(0, 0.96, 0.36), crim, Vector3(-8, 0, 0))
	for i in 4:
		k.prism(Vector3(0.15, 0.2, 0.04), Vector3(-0.22 + i * 0.147, 0.38, 0.44), crim, Vector3(172, 0, 0))
	k.on("head")
	k.cyl(0.16, 0.19, 0.3, Vector3(0, 1.69, 0), iron)
	k.hemi(1.0, Vector3(0, 1.84, 0), iron, Vector3(0.16, 0.13, 0.17))
	k.box(Vector3(0.27, 0.22, 0.05), Vector3(0, 1.66, -0.18), iron_hi, Vector3(-6, 0, 0))
	k.box(Vector3(0.22, 0.035, 0.03), Vector3(0, 1.7, -0.215), blood, Vector3.ZERO, 3.0)
	k.box(Vector3(0.035, 0.12, 0.03), Vector3(0, 1.63, -0.21), blood, Vector3.ZERO, 2.4)
	for s in [-1.0, 1.0]:
		k.tube(Vector3(s * 0.15, 1.78, 0.0), Vector3(s * 0.3, 1.96, 0.08), 0.06, 0.04, bone, -1, 6)
		k.spike(Vector3(s * 0.3, 1.96, 0.08), Vector3(s * 0.3, 2.16, 0.22), 0.04, bone, -1, 5)
	k.extrude(PackedVector2Array([Vector2(-0.18, 0), Vector2(0.2, 0), Vector2(0.12, 0.08), Vector2(-0.12, 0.08)]), 0.05, Vector3(0, 1.88, 0), crim, Vector3(0, 90, 0))
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		var big: bool = s < 0
		var pr: float = 1.1 if big else 0.85
		k.ball(1.0, Vector3(s * 0.48, 1.52, 0), iron, Vector3(0.27, 0.15, 0.26) * pr, Vector3(0, 0, s * -22), -1, 8, 5)
		k.ball(1.0, Vector3(s * 0.53, 1.42, 0), iron_hi, Vector3(0.24, 0.1, 0.24) * pr, Vector3(0, 0, s * -32), -1, 8, 5)
		k.torus(0.22 * pr, 0.27 * pr, Vector3(s * 0.5, 1.47, 0), crim, Vector3(0, 0, s * -20), -1, 10, 4)
		if big:
			for i in 3:
				k.spike(Vector3(-0.42 - i * 0.08, 1.66 - i * 0.04, -0.08 + i * 0.08), Vector3(-0.5 - i * 0.13, 1.98 - i * 0.07, -0.08 + i * 0.1), 0.05, bone, -1, 5)
		k.limb(Vector3(s * 0.45, 1.38, 0), Vector3(s * 0.52, 1.06, 0), 0.1, skin)
		k.box(Vector3(0.025, 0.24, 0.02), Vector3(s * 0.5, 1.2, -0.1), blood, Vector3(0, 0, s * 8), 2.4)
		k.cyl(0.12, 0.14, 0.32, Vector3(s * 0.54, 0.92, 0), iron)
		k.box(Vector3(0.025, 0.28, 0.02), Vector3(s * 0.54, 0.92, -0.135), blood, Vector3.ZERO, 2.4)
		k.box(Vector3(0.2, 0.18, 0.21), Vector3(s * 0.56, 0.74, -0.03), iron)
	k.on("weapon_r")
	var h := Vector3(0.56, 0.78, -0.04)
	k.cyl(0.04, 0.045, 0.62, h + Vector3(0, 0.02, 0), leather)
	k.ball(0.07, h + Vector3(0, -0.3, 0), iron_hi)
	k.ball(0.04, h + Vector3(0, -0.36, 0), blood, Vector3.ONE, Vector3.ZERO, 2.4, 6, 4)
	var g := h + Vector3(0, 0.34, 0)
	k.box(Vector3(0.42, 0.08, 0.1), g, iron_hi)
	for s2 in [-1.0, 1.0]:
		k.spike(g + Vector3(s2 * 0.2, 0, 0), g + Vector3(s2 * 0.3, 0.12, 0), 0.045, iron_hi, -1, 5)
	k.ball(0.06, g + Vector3(0, 0, -0.05), blood, Vector3.ONE, Vector3.ZERO, 2.8, 6, 4)
	var blade := PackedVector2Array([Vector2(-0.09, 0), Vector2(-0.08, 0.42), Vector2(-0.05, 0.82), Vector2(0.0, 1.08), Vector2(0.1, 1.3),
		Vector2(0.2, 1.08), Vector2(0.27, 0.76), Vector2(0.25, 0.4), Vector2(0.16, 0.12), Vector2(0.09, 0)])
	var edge := PackedVector2Array([Vector2(0.1, 1.3), Vector2(0.2, 1.08), Vector2(0.27, 0.76), Vector2(0.25, 0.4), Vector2(0.16, 0.12),
		Vector2(0.12, 0.14), Vector2(0.2, 0.42), Vector2(0.215, 0.76), Vector2(0.16, 1.04)])
	var bo := g + Vector3(-0.02, 0.04, 0)
	k.extrude(blade, 0.06, bo, steel)
	k.extrude(edge, 0.072, bo, blood, Vector3.ZERO, Vector3.ONE, 1.8)
	k.box(Vector3(0.035, 0.7, 0.075), bo + Vector3(0.05, 0.45, 0), crim_d, Vector3(0, 0, -4))
	k.box(Vector3(0.018, 0.6, 0.08), bo + Vector3(0.05, 0.45, 0), blood, Vector3(0, 0, -4), 2.2)
	var p := _base_params()
	p.merge({"radius": 0.55, "height": 1.9, "glow": Color("ff2a40"), "rim": Color(1.0, 0.55, 0.55),
		"attack": "swipe", "run_freq": 9.5, "stride": 0.72, "arm_swing": 0.4, "lean": 0.2,
		"w_idle_r": Vector3(0.5, 0, 0.14), "atk_dur": 0.5, "enemy": false, "sit_wx": -0.9}, true)
	return k.finish(p)

## Snarewright: hooded trapper in leather and fur, wolf-pelt hood, hand crossbow, belt of traps and pouches, a coil of wire.
static func _snarewright() -> Dictionary:
	var k := RB.new()
	var leather := Color("7a5232"); var leather_d := Color("3e2a1a"); var hood := Color("5e6230"); var fur := Color("cdb68e"); var fur_d := Color("8a6e4c")
	var metal := Color("8e887a"); var olive := Color("c8d24a"); var skin := Color("c89a74"); var wire := Color("b8ae94"); var wood := Color("6a4424"); var dark := Color("120e08")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.92, 0))
	k.bone("chest", "hips", Vector3(0, 1.2, 0))
	k.bone("head", "chest", Vector3(0, 1.52, -0.02))
	k.bone("arm_l", "chest", Vector3(-0.29, 1.38, 0))
	k.bone("arm_r", "chest", Vector3(0.29, 1.38, 0))
	k.bone("weapon_r", "arm_r", Vector3(0.35, 0.86, -0.04))
	k.bone("leg_l", "hips", Vector3(-0.13, 0.9, 0))
	k.bone("leg_r", "hips", Vector3(0.13, 0.9, 0))
	k.bone("cape", "chest", Vector3(0, 1.4, 0.2))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.13, 0.9, 0), Vector3(s * 0.14, 0.5, -0.01), 0.095, leather_d)
		k.cyl(0.1, 0.1, 0.06, Vector3(s * 0.14, 0.6, 0), leather, Vector3(0, 0, s * 8))
		k.cyl(0.1, 0.12, 0.42, Vector3(s * 0.145, 0.27, 0.0), leather)
		k.torus(0.08, 0.15, Vector3(s * 0.145, 0.48, 0), fur, Vector3.ZERO, -1, 8, 4)
		k.box(Vector3(0.15, 0.1, 0.32), Vector3(s * 0.145, 0.05, -0.06), leather_d)
	k.on("hips")
	k.cyl(0.22, 0.24, 0.16, Vector3(0, 0.93, 0), leather)
	k.cyl(0.235, 0.235, 0.05, Vector3(0, 0.9, 0), leather_d)
	for i in 5:
		var a := deg_to_rad(-60.0 + i * 30.0)
		k.box(Vector3(0.09, 0.11, 0.07), Vector3(sin(a) * 0.25, 0.86, -cos(a) * 0.23), leather if i % 2 == 0 else fur_d, Vector3(0, -rad_to_deg(a), 0))
	k.ball(0.035, Vector3(0, 0.88, -0.29), olive, Vector3.ONE, Vector3.ZERO, 2.4, 6, 4)
	var tc := Vector3(-0.29, 0.74, 0.02)
	k.torus(0.11, 0.15, tc, metal, Vector3(0, 0, 80), -1, 10, 4)
	for i in 6:
		var a := TAU * i / 6.0
		k.spike(tc + Vector3(0, sin(a) * 0.12, cos(a) * 0.12), tc + Vector3(0, sin(a) * 0.06, cos(a) * 0.06), 0.022, metal, -1, 4)
	k.ball(0.04, tc, olive, Vector3.ONE, Vector3.ZERO, 2.2, 6, 4)
	k.box(Vector3(0.2, 0.44, 0.03), Vector3(0, 0.66, -0.2), leather, Vector3(8, 0, 0))
	k.box(Vector3(0.3, 0.5, 0.03), Vector3(0, 0.64, 0.21), leather_d, Vector3(-9, 0, 0))
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.2, 0), leather, Vector3(0.27, 0.3, 0.2))
	k.ball(1.0, Vector3(0, 1.28, -0.05), leather_d, Vector3(0.24, 0.2, 0.16))
	k.box(Vector3(0.06, 0.56, 0.04), Vector3(0, 1.2, -0.19), wood, Vector3(0, 0, -34))
	for i in 3:
		k.box(Vector3(0.05, 0.08, 0.05), Vector3(-0.1 + i * 0.09, 1.33 - i * 0.12, -0.2), metal, Vector3(0, 0, -34))
	k.ball(1.0, Vector3(0, 1.4, 0.02), fur, Vector3(0.36, 0.12, 0.27), Vector3.ZERO, -1, 10, 5)
	k.ball(1.0, Vector3(0, 1.36, 0.06), fur_d, Vector3(0.34, 0.1, 0.25))
	k.torus(0.13, 0.19, Vector3(0.0, 1.22, 0.2), wire, Vector3(90, 0, 25), -1, 12, 4)
	k.torus(0.1, 0.16, Vector3(0.0, 1.22, 0.21), wire, Vector3(90, 0, 25), -1, 12, 4)
	k.ball(0.03, Vector3(0.12, 1.3, 0.24), olive, Vector3.ONE, Vector3.ZERO, 2.0, 6, 4)
	k.on("cape")
	k.box(Vector3(0.42, 0.7, 0.03), Vector3(0, 1.0, 0.26), hood, Vector3(-6, 0, 0))
	for i in 3:
		k.prism(Vector3(0.14, 0.16, 0.03), Vector3(-0.14 + i * 0.14, 0.6, 0.3), hood, Vector3(174, 0, 0))
	k.on("head")
	k.ball(1.0, Vector3(0, 1.57, 0.0), hood, Vector3(0.2, 0.22, 0.21))
	k.ball(1.0, Vector3(0, 1.54, -0.14), dark, Vector3(0.13, 0.13, 0.07))
	k.box(Vector3(0.22, 0.09, 0.08), Vector3(0, 1.47, -0.15), hood)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.05, 0.025, 0.02), Vector3(s * 0.05, 1.55, -0.2), olive, Vector3(0, 0, s * -10), 3.2)
	k.ball(1.0, Vector3(0, 1.72, -0.06), fur_d, Vector3(0.17, 0.09, 0.2))
	k.ball(1.0, Vector3(0, 1.69, -0.24), fur_d, Vector3(0.09, 0.06, 0.1))
	k.ball(0.025, Vector3(0, 1.69, -0.33), dark)
	for s in [-1.0, 1.0]:
		k.spike(Vector3(s * 0.1, 1.76, -0.02), Vector3(s * 0.14, 1.95, 0.04), 0.06, fur_d, -1, 4)
		k.spike(Vector3(s * 0.1, 1.78, -0.03), Vector3(s * 0.13, 1.9, 0.0), 0.03, fur, -1, 4)
		k.ball(0.022, Vector3(s * 0.06, 1.73, -0.22), olive, Vector3.ONE, Vector3.ZERO, 2.0, 6, 4)
	k.spike(Vector3(0, 1.6, 0.16), Vector3(0, 1.3, 0.3), 0.1, fur_d, -1, 5)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.31, 1.39, 0), fur, Vector3(0.13, 0.11, 0.13))
		k.limb(Vector3(s * 0.29, 1.36, 0), Vector3(s * 0.34, 0.92, -0.02), 0.075, leather_d)
		k.cyl(0.08, 0.09, 0.22, Vector3(s * 0.335, 1.0, -0.01), leather)
		k.cyl(0.092, 0.092, 0.03, Vector3(s * 0.335, 1.08, -0.01), olive, Vector3.ZERO, 1.4)
		k.ball(0.065, Vector3(s * 0.35, 0.86, -0.04), skin)
	k.on("weapon_r")
	var o := Vector3(0.35, 0.86, -0.04)
	k.box(Vector3(0.055, 0.1, 0.16), o + Vector3(0, -0.02, 0.06), wood, Vector3(-20, 0, 0))
	k.box(Vector3(0.07, 0.07, 0.42), o + Vector3(0, 0.05, -0.16), wood)
	k.box(Vector3(0.075, 0.03, 0.3), o + Vector3(0, 0.095, -0.2), metal)
	for s2 in [-1.0, 1.0]:
		k.box(Vector3(0.24, 0.035, 0.04), o + Vector3(s2 * 0.12, 0.06, -0.37), wood, Vector3(0, s2 * 18, 0))
		k.ball(0.022, o + Vector3(s2 * 0.235, 0.06, -0.33), metal, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
	k.box(Vector3(0.44, 0.012, 0.012), o + Vector3(0, 0.07, -0.29), wire)
	k.box(Vector3(0.022, 0.022, 0.36), o + Vector3(0, 0.12, -0.24), olive, Vector3.ZERO, 2.4)
	k.prism(Vector3(0.05, 0.08, 0.03), o + Vector3(0, 0.12, -0.45), olive, Vector3(-90, 0, 0), 2.8)
	var p := _base_params()
	p.merge({"radius": 0.45, "height": 1.85, "glow": Color("c8d24a"), "rim": Color(0.9, 0.95, 0.6),
		"attack": "aim", "run_freq": 11.5, "stride": 0.85, "arm_swing": 0.45, "lean": 0.26, "atk_dur": 0.42,
		"w_idle_r": Vector3(-0.15, 0, 0), "enemy": false, "sit_wx": -0.6}, true)
	return k.finish(p)

static func _antlers(k: RB, base_y: float, base_z: float, sc: float, col: Color, glow: Color) -> void:
	for s in [-1.0, 1.0]:
		var a := Vector3(s * 0.1 * sc, base_y, base_z)
		var b := a + Vector3(s * 0.16, 0.2, 0.04) * sc
		var c := b + Vector3(s * 0.12, 0.2, 0.06) * sc
		var d := c + Vector3(s * 0.02, 0.18, 0.02) * sc
		k.tube(a, b, 0.045 * sc, 0.035 * sc, col, -1, 6)
		k.tube(b, c, 0.035 * sc, 0.026 * sc, col, -1, 6)
		k.spike(c, d, 0.026 * sc, col, -1, 5)
		k.spike(b, b + Vector3(s * 0.02, 0.17, -0.1) * sc, 0.025 * sc, col, -1, 5)
		k.spike(c, c + Vector3(s * 0.16, 0.06, -0.04) * sc, 0.022 * sc, col, -1, 5)
		k.spike(a + Vector3(s * 0.06, 0.07, 0.0) * sc, a + Vector3(s * 0.08, 0.16, -0.14) * sc, 0.022 * sc, col, -1, 5)
		k.ball(0.022 * sc, d, glow, Vector3.ONE, Vector3.ZERO, 2.6, 6, 4)

## Twinhide (caster form): robed druid with an antlered skull-mask and a crooked staff holding a moon crystal.
static func _twinhide() -> Dictionary:
	var k := RB.new()
	var robe := Color("342a62"); var robe_d := Color("1c1634"); var moss := Color("5e7034"); var bark := Color("5e4230")
	var bone := Color("ece2c8"); var glow := Color("c86bff"); var moon := Color("efe6ff"); var leaf := Color("74963e"); var skin := Color("8a6a5a"); var dark := Color("0c0812")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.92, 0))
	k.bone("chest", "hips", Vector3(0, 1.2, 0))
	k.bone("head", "chest", Vector3(0, 1.52, -0.03))
	k.bone("arm_l", "chest", Vector3(-0.28, 1.38, 0))
	k.bone("arm_r", "chest", Vector3(0.28, 1.38, 0))
	k.bone("weapon_r", "arm_r", Vector3(0.36, 0.84, -0.06))
	k.bone("leg_l", "hips", Vector3(-0.12, 0.9, 0))
	k.bone("leg_r", "hips", Vector3(0.12, 0.9, 0))
	k.bone("cape", "chest", Vector3(0, 1.42, 0.18))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.12, 0.9, 0), Vector3(s * 0.13, 0.14, 0), 0.08, robe_d)
		k.box(Vector3(0.13, 0.09, 0.28), Vector3(s * 0.13, 0.045, -0.05), bark)
		k.torus(0.06, 0.11, Vector3(s * 0.13, 0.2, 0), moss, Vector3.ZERO, -1, 8, 4)
	k.on("hips")
	k.cyl(0.21, 0.25, 0.18, Vector3(0, 0.92, 0), robe)
	k.torus(0.2, 0.26, Vector3(0, 0.88, 0), bark, Vector3(4, 0, 0), -1, 10, 4)
	for i in 3:
		var x := -0.1 + i * 0.1
		k.cyl(0.006, 0.006, 0.14, Vector3(x, 0.79, -0.25), bark)
		k.ball(0.035, Vector3(x, 0.71, -0.25), bone if i != 1 else glow, Vector3.ONE, Vector3.ZERO, -1.0 if i != 1 else 2.4, 6, 4)
	k.box(Vector3(0.26, 0.74, 0.03), Vector3(0, 0.52, -0.2), robe, Vector3(9, 0, 0))
	k.box(Vector3(0.08, 0.72, 0.035), Vector3(0, 0.52, -0.205), robe_d, Vector3(9, 0, 0))
	k.box(Vector3(0.36, 0.78, 0.03), Vector3(0, 0.52, 0.2), robe, Vector3(-9, 0, 0))
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.03, 0.7, 0.26), Vector3(s * 0.22, 0.54, 0), robe_d, Vector3(0, 0, s * -8))
	for i in 5:
		k.prism(Vector3(0.09, 0.12, 0.04), Vector3(-0.16 + i * 0.08, 0.13, -0.15 + (i % 2) * 0.02), leaf, Vector3(190, 0, 0))
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.2, 0), robe, Vector3(0.25, 0.3, 0.2))
	k.ball(1.0, Vector3(0, 1.38, 0.0), moss, Vector3(0.32, 0.12, 0.25), Vector3.ZERO, -1, 10, 5)
	for i in 6:
		var a := TAU * i / 6.0
		k.prism(Vector3(0.08, 0.14, 0.03), Vector3(cos(a) * 0.3, 1.32, sin(a) * 0.23), leaf, Vector3(180, -rad_to_deg(a) + 90.0, 0))
	k.box(Vector3(0.06, 0.06, 0.03), Vector3(0, 1.22, -0.2), glow, Vector3(0, 0, 45), 2.6)
	k.on("cape")
	k.box(Vector3(0.46, 1.1, 0.03), Vector3(0, 0.86, 0.24), robe_d, Vector3(-5, 0, 0))
	for i in 4:
		k.prism(Vector3(0.12, 0.16, 0.03), Vector3(-0.17 + i * 0.115, 0.28, 0.29), robe_d, Vector3(175, 0, 0))
	k.on("head")
	k.ball(1.0, Vector3(0, 1.57, 0.04), robe_d, Vector3(0.21, 0.22, 0.22))
	k.ball(1.0, Vector3(0, 1.58, -0.08), bone, Vector3(0.14, 0.13, 0.14))
	k.ball(1.0, Vector3(0, 1.51, -0.2), bone, Vector3(0.075, 0.07, 0.12))
	for s in [-1.0, 1.0]:
		k.ball(1.0, Vector3(s * 0.055, 1.59, -0.18), dark, Vector3(0.04, 0.035, 0.03))
		k.ball(0.02, Vector3(s * 0.055, 1.59, -0.2), glow, Vector3.ONE, Vector3.ZERO, 3.4, 6, 4)
	k.ball(1.0, Vector3(0, 1.49, -0.3), dark, Vector3(0.03, 0.02, 0.02))
	_antlers(k, 1.66, -0.04, 1.0, bone, glow)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.3, 1.38, 0), moss, Vector3(0.12, 0.1, 0.12))
		k.tube(Vector3(s * 0.29, 1.36, 0), Vector3(s * 0.35, 0.92, -0.04), 0.07, 0.12, robe, -1, 7)
		k.ball(0.06, Vector3(s * 0.36, 0.84, -0.06), skin)
	k.on("arm_l")
	k.ball(0.07, Vector3(-0.36, 0.8, -0.1), glow, Vector3.ONE, Vector3.ZERO, 2.4, 6, 4)
	k.on("weapon_r")
	var o := Vector3(0.36, 0.84, -0.06)
	var pts := [o + Vector3(0, -0.72, 0.02), o + Vector3(0.02, -0.2, 0), o + Vector3(-0.03, 0.4, -0.02), o + Vector3(0.03, 0.86, 0.0),
		o + Vector3(0.0, 1.14, -0.06), o + Vector3(-0.1, 1.3, -0.14), o + Vector3(-0.2, 1.26, -0.24), o + Vector3(-0.22, 1.12, -0.26)]
	for i in pts.size() - 1:
		var ra := 0.035 - i * 0.002
		k.tube(pts[i], pts[i + 1], ra, ra - 0.002, bark, -1, 6)
		k.ball(ra, pts[i + 1], bark, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
	k.prism(Vector3(0.08, 0.12, 0.03), o + Vector3(0.07, 0.5, -0.02), leaf, Vector3(0, 0, -50))
	k.prism(Vector3(0.08, 0.12, 0.03), o + Vector3(-0.08, 0.96, -0.02), leaf, Vector3(0, 0, 50))
	var cres := PackedVector2Array()
	for i in 9:
		var a := deg_to_rad(-120.0 + i * 30.0)
		cres.append(Vector2(cos(a) * 0.15, sin(a) * 0.15))
	for i in 9:
		var a := deg_to_rad(120.0 - i * 30.0)
		cres.append(Vector2(0.06 + cos(a) * 0.11, sin(a) * 0.11))
	var mc := o + Vector3(-0.12, 1.12, -0.2)
	k.extrude(cres, 0.05, mc, moon, Vector3(0, 0, 90), Vector3(1.5, 1.5, 1), 2.2)
	k.ball(0.09, mc + Vector3(0, -0.02, 0), glow, Vector3.ONE, Vector3.ZERO, 3.0, 8, 5)
	var p := _base_params()
	p.merge({"radius": 0.45, "height": 1.9, "glow": Color("c86bff"), "rim": Color(0.85, 0.65, 1.0),
		"attack": "cast", "run_freq": 10.0, "stride": 0.7, "arm_swing": 0.35, "lean": 0.18, "atk_dur": 0.5,
		"w_idle_r": Vector3(-0.1, 0, 0), "enemy": false, "sit_wx": -0.75}, true)
	return k.finish(p)

## Twinhide (beast form): hunched broad-shouldered were-beast with claws, a shaggy mane and the same antlers and violet glow.
static func _twinhide_beast() -> Dictionary:
	var k := RB.new()
	var fur := Color("4e4048"); var fur_d := Color("2c2228"); var mane := Color("18121a"); var belly := Color("8e7e7a")
	var bone := Color("ece2c8"); var claw := Color("f4ecd6"); var glow := Color("c86bff"); var pad := Color("3a2830"); var dark := Color("0c0810")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 1.0, 0.08))
	k.bone("chest", "hips", Vector3(0, 1.32, -0.02))
	k.bone("head", "chest", Vector3(0, 1.66, -0.42))
	k.bone("arm_l", "chest", Vector3(-0.52, 1.62, -0.14))
	k.bone("arm_r", "chest", Vector3(0.52, 1.62, -0.14))
	k.bone("weapon_l", "arm_l", Vector3(-0.68, 0.66, -0.3))
	k.bone("weapon_r", "arm_r", Vector3(0.68, 0.66, -0.3))
	k.bone("leg_l", "hips", Vector3(-0.22, 0.98, 0.08))
	k.bone("leg_r", "hips", Vector3(0.22, 0.98, 0.08))
	k.bone("cape", "hips", Vector3(0, 0.98, 0.36))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		var hip := Vector3(s * 0.22, 0.98, 0.08); var knee := Vector3(s * 0.26, 0.6, -0.12)
		var ank := Vector3(s * 0.26, 0.24, 0.12); var toe := Vector3(s * 0.26, 0.05, -0.12)
		k.ball(1.0, Vector3(s * 0.23, 0.82, 0.0), fur, Vector3(0.17, 0.24, 0.2))
		k.limb(hip, knee, 0.13, fur)
		k.limb(knee, ank, 0.085, fur_d)
		k.limb(ank, toe, 0.07, fur_d)
		k.box(Vector3(0.2, 0.08, 0.2), toe + Vector3(0, -0.01, 0.0), pad)
		for i in 3:
			k.spike(toe + Vector3((i - 1) * 0.06, 0.0, -0.08), toe + Vector3((i - 1) * 0.07, -0.04, -0.2), 0.025, claw, -1, 4)
	k.on("hips")
	k.ball(1.0, Vector3(0, 1.02, 0.1), fur, Vector3(0.36, 0.26, 0.3), Vector3.ZERO, -1, 10, 6)
	k.box(Vector3(0.36, 0.3, 0.04), Vector3(0, 0.84, -0.18), fur_d, Vector3(8, 0, 0))
	k.on("cape")
	k.tube(Vector3(0, 0.98, 0.34), Vector3(0, 0.62, 0.7), 0.1, 0.05, fur_d, -1, 6)
	k.spike(Vector3(0, 0.62, 0.7), Vector3(0, 0.42, 0.86), 0.06, mane, -1, 5)
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.34, -0.04), fur, Vector3(0.48, 0.42, 0.42), Vector3(-18, 0, 0), -1, 12, 7)
	k.ball(1.0, Vector3(0, 1.3, -0.3), belly, Vector3(0.34, 0.32, 0.2), Vector3(-15, 0, 0))
	k.ball(1.0, Vector3(0, 1.62, 0.02), mane, Vector3(0.5, 0.26, 0.4), Vector3(-25, 0, 0), -1, 10, 6)
	for i in 7:
		var a := deg_to_rad(-75.0 + i * 25.0)
		k.spike(Vector3(sin(a) * 0.28, 1.66, 0.06 + cos(a) * 0.06), Vector3(sin(a) * 0.52, 1.92 - absf(sin(a)) * 0.2, 0.28), 0.1, mane, -1, 5)
	for i in 4:
		k.spike(Vector3(0, 1.5 - i * 0.14, 0.32 - i * 0.02), Vector3(0, 1.62 - i * 0.16, 0.56 - i * 0.03), 0.08, mane, -1, 5)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.04, 0.22, 0.03), Vector3(s * 0.2, 1.36, -0.39), glow, Vector3(-15, 0, s * 20), 2.4)
		k.box(Vector3(0.035, 0.14, 0.03), Vector3(s * 0.12, 1.22, -0.43), glow, Vector3(-15, 0, s * 10), 2.2)
	k.on("head")
	var hc := Vector3(0, 1.68, -0.48)
	k.ball(1.0, hc, fur, Vector3(0.2, 0.19, 0.21))
	k.ball(1.0, hc + Vector3(0, -0.05, -0.22), fur_d, Vector3(0.1, 0.09, 0.2))
	k.ball(1.0, hc + Vector3(0, -0.12, -0.2), belly, Vector3(0.085, 0.05, 0.17))
	k.ball(0.03, hc + Vector3(0, -0.03, -0.41), dark)
	for s in [-1.0, 1.0]:
		k.spike(hc + Vector3(s * 0.05, -0.1, -0.32), hc + Vector3(s * 0.05, -0.2, -0.34), 0.022, claw, -1, 4)
		k.spike(hc + Vector3(s * 0.15, 0.12, 0.02), hc + Vector3(s * 0.22, 0.26, 0.08), 0.06, fur_d, -1, 4)
		k.box(Vector3(0.1, 0.045, 0.03), hc + Vector3(s * 0.085, 0.05, -0.19), glow, Vector3(0, 0, s * -18), 3.8)
	_antlers(k, 1.8, -0.42, 1.25, bone, glow)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.52, 1.64, -0.12), fur, Vector3(0.24, 0.22, 0.24))
		k.ball(1.0, Vector3(s * 0.52, 1.72, -0.06), mane, Vector3(0.2, 0.12, 0.2))
		k.limb(Vector3(s * 0.54, 1.56, -0.14), Vector3(s * 0.62, 1.06, -0.22), 0.13, fur)
		k.tube(Vector3(s * 0.62, 1.06, -0.22), Vector3(s * 0.67, 0.72, -0.28), 0.1, 0.15, fur_d, -1, 8)
		k.ball(1.0, Vector3(s * 0.6, 1.12, -0.2), mane, Vector3(0.13, 0.12, 0.13))
		k.box(Vector3(0.035, 0.24, 0.03), Vector3(s * 0.64, 0.92, -0.36), glow, Vector3(0, 0, s * 6), 2.2)
		k.on("weapon_l" if s < 0 else "weapon_r")
		var hd := Vector3(s * 0.68, 0.64, -0.3)
		k.ball(1.0, hd, pad, Vector3(0.13, 0.11, 0.13))
		for i in 4:
			var x := (i - 1.5) * 0.055
			k.spike(hd + Vector3(s * x * 0.3 + x, -0.05, -0.08), hd + Vector3(s * x * 0.3 + x * 1.3, -0.2, -0.24), 0.026, claw, -1, 4)
	var p := _base_params()
	p.merge({"radius": 0.6, "height": 2.1, "glow": Color("c86bff"), "rim": Color(0.85, 0.65, 1.0),
		"attack": "swipe", "run_freq": 9.0, "stride": 0.8, "arm_swing": 0.6, "lean": 0.3, "atk_dur": 0.4,
		"enemy": false, "run_arms": Vector3(0.3, 0, 0), "sit_wx": 0.0}, true)
	return k.finish(p)

## Gravekeeper: gaunt undertaker in a tattered long coat and wide-brimmed hat, a lantern staff, a shovel on his back, ghost-mint glow.
static func _gravekeeper() -> Dictionary:
	var k := RB.new()
	var coat := Color("33323c"); var coat_d := Color("1c1b22"); var hat := Color("24222a"); var mint := Color("8affc8")
	var skin := Color("b4c2b0"); var bone := Color("dcd6c0"); var wood := Color("54402c"); var iron := Color("62626a"); var brass := Color("a8905a")
	var vest := Color("3e4a44"); var dark := Color("0a0c0c")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.98, 0))
	k.bone("chest", "hips", Vector3(0, 1.28, 0))
	k.bone("head", "chest", Vector3(0, 1.64, -0.04))
	k.bone("arm_l", "chest", Vector3(-0.27, 1.48, 0))
	k.bone("arm_r", "chest", Vector3(0.27, 1.48, 0))
	k.bone("weapon_r", "arm_r", Vector3(0.36, 0.86, -0.06))
	k.bone("leg_l", "hips", Vector3(-0.11, 0.96, 0))
	k.bone("leg_r", "hips", Vector3(0.11, 0.96, 0))
	k.bone("cape", "chest", Vector3(0, 1.3, 0.18))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.11, 0.96, 0), Vector3(s * 0.12, 0.14, 0), 0.065, coat_d)
		k.cyl(0.07, 0.085, 0.3, Vector3(s * 0.12, 0.2, 0), dark)
		k.box(Vector3(0.12, 0.08, 0.3), Vector3(s * 0.12, 0.04, -0.07), dark)
		k.spike(Vector3(s * 0.12, 0.04, -0.2), Vector3(s * 0.12, 0.08, -0.3), 0.045, dark, -1, 4)
	k.on("hips")
	k.cyl(0.18, 0.2, 0.16, Vector3(0, 0.98, 0), coat)
	k.box(Vector3(0.34, 0.06, 0.26), Vector3(0, 0.94, 0), Color("3a2a1e"))
	k.box(Vector3(0.06, 0.06, 0.03), Vector3(0, 0.94, -0.14), brass)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.17, 0.68, 0.03), Vector3(s * 0.11, 0.6, -0.17), coat, Vector3(6, 0, s * 4))
	k.box(Vector3(0.36, 0.78, 0.03), Vector3(0, 0.56, 0.17), coat, Vector3(-7, 0, 0))
	for i in 4:
		k.prism(Vector3(0.1, 0.16, 0.03), Vector3(-0.13 + i * 0.087, 0.14, 0.215), coat, Vector3(173, 0, 0))
	for s in [-1.0, 1.0]:
		k.prism(Vector3(0.09, 0.14, 0.03), Vector3(s * 0.11, 0.22, -0.2), coat, Vector3(186, 0, 0))
	k.cyl(0.008, 0.008, 0.16, Vector3(-0.17, 0.86, -0.1), iron)
	k.cyl(0.035, 0.035, 0.08, Vector3(-0.17, 0.75, -0.1), mint, Vector3.ZERO, 2.2)
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.28, 0), coat, Vector3(0.24, 0.3, 0.18))
	k.box(Vector3(0.16, 0.38, 0.04), Vector3(0, 1.24, -0.16), vest)
	for i in 3:
		k.ball(0.018, Vector3(0, 1.36 - i * 0.1, -0.185), mint, Vector3.ONE, Vector3.ZERO, 2.4, 6, 4)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.14, 0.26, 0.04), Vector3(s * 0.12, 1.55, -0.04), coat_d, Vector3(-8, s * -20, s * -12))
		k.box(Vector3(0.1, 0.42, 0.035), Vector3(s * 0.1, 1.3, -0.165), coat_d, Vector3(0, 0, s * -10))
	k.on("cape")
	var sh := Vector3(-0.08, 1.3, 0.24)
	k.cyl(0.025, 0.025, 1.1, sh + Vector3(0, 0.1, 0), wood, Vector3(0, 0, -24))
	var bc := sh + Vector3(-0.27, 0.66, 0)
	k.box(Vector3(0.22, 0.28, 0.03), bc, iron, Vector3(0, 0, -24))
	k.box(Vector3(0.2, 0.03, 0.035), bc + Vector3(-0.06, 0.13, 0), mint, Vector3(0, 0, -24), 1.6)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.68, -0.04), skin, Vector3(0.13, 0.17, 0.14))
	k.ball(1.0, Vector3(0, 1.6, -0.1), skin, Vector3(0.09, 0.08, 0.08))
	for s in [-1.0, 1.0]:
		k.ball(1.0, Vector3(s * 0.05, 1.7, -0.14), dark, Vector3(0.04, 0.03, 0.025))
		k.ball(0.018, Vector3(s * 0.05, 1.7, -0.16), mint, Vector3.ONE, Vector3.ZERO, 3.6, 6, 4)
	k.spike(Vector3(0, 1.66, -0.16), Vector3(0, 1.6, -0.24), 0.022, skin, -1, 4)
	k.box(Vector3(0.08, 0.012, 0.02), Vector3(0, 1.58, -0.17), dark)
	k.cyl(0.42, 0.42, 0.03, Vector3(0, 1.8, -0.04), hat, Vector3(-6, 0, 0), -1, 14)
	k.cyl(0.15, 0.17, 0.26, Vector3(0, 1.93, -0.03), hat, Vector3(-6, 0, 0), -1, 10)
	k.cyl(0.172, 0.172, 0.04, Vector3(0, 1.84, -0.04), mint, Vector3(-6, 0, 0), 1.8, 10)
	k.prism(Vector3(0.12, 0.08, 0.04), Vector3(0.36, 1.79, 0.1), hat, Vector3(-6, 30, 180))
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.28, 1.48, 0), coat, Vector3(0.11, 0.09, 0.11))
		k.tube(Vector3(s * 0.28, 1.46, 0), Vector3(s * 0.34, 0.94, -0.04), 0.06, 0.1, coat, -1, 7)
		k.prism(Vector3(0.1, 0.12, 0.03), Vector3(s * 0.35, 0.86, 0.02), coat_d, Vector3(180, 0, 0))
		k.ball(0.05, Vector3(s * 0.36, 0.86, -0.06), skin, Vector3(1, 1.2, 1))
	k.on("arm_l")
	for i in 3:
		k.spike(Vector3(-0.36 + (i - 1) * 0.025, 0.82, -0.08), Vector3(-0.36 + (i - 1) * 0.03, 0.72, -0.1), 0.012, skin, -1, 4)
	k.on("weapon_r")
	var o := Vector3(0.36, 0.86, -0.06)
	k.cyl(0.028, 0.032, 2.0, o + Vector3(0, 0.22, 0), wood)
	k.ball(0.05, o + Vector3(0, -0.78, 0), iron)
	var top := o + Vector3(0, 1.22, 0)
	var crook := [top, top + Vector3(0, 0.14, -0.04), top + Vector3(0, 0.2, -0.16), top + Vector3(0, 0.14, -0.28), top + Vector3(0, 0.04, -0.3)]
	for i in crook.size() - 1:
		k.tube(crook[i], crook[i + 1], 0.026, 0.024, iron, -1, 6)
		k.ball(0.026, crook[i + 1], iron, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
	k.ball(1.0, o + Vector3(0, 1.0, 0), bone, Vector3(0.07, 0.075, 0.075))
	k.box(Vector3(0.04, 0.02, 0.02), o + Vector3(0, 1.0, -0.07), mint, Vector3.ZERO, 2.6)
	var lc := top + Vector3(0, -0.12, -0.3)
	k.cyl(0.005, 0.005, 0.1, lc + Vector3(0, 0.11, 0), iron)
	k.cone(0.09, 0.08, lc + Vector3(0, 0.08, 0), brass, Vector3.ZERO, -1, 6)
	k.cyl(0.075, 0.075, 0.03, lc + Vector3(0, 0.03, 0), brass, Vector3.ZERO, -1, 6)
	k.ball(1.0, lc + Vector3(0, -0.07, 0), mint, Vector3(0.065, 0.085, 0.065), Vector3.ZERO, 3.2, 8, 5)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		k.box(Vector3(0.014, 0.17, 0.014), lc + Vector3(cos(a) * 0.07, -0.07, sin(a) * 0.07), brass)
	k.cyl(0.08, 0.06, 0.035, lc + Vector3(0, -0.17, 0), brass, Vector3.ZERO, -1, 6)
	var p := _base_params()
	p.merge({"radius": 0.45, "height": 2.0, "glow": Color("8affc8"), "rim": Color(0.65, 1.0, 0.85),
		"attack": "thrust", "run_freq": 9.0, "stride": 0.75, "arm_swing": 0.3, "lean": 0.22, "atk_dur": 0.5,
		"w_idle_r": Vector3(-0.05, 0, 0), "enemy": false, "sit_wx": -0.75}, true)
	return k.finish(p)

## Stoneshaper: stocky earth-shaper with huge stone gauntlets, rocky pauldrons and glowing amber cracks.
static func _stoneshaper() -> Dictionary:
	var k := RB.new()
	var skin := Color("b47c56"); var beard := Color("6a4026"); var cloth := Color("6e4e2e"); var cloth_d := Color("3e2c1c")
	var stone := Color("b09878"); var stone_d := Color("6e5e4e"); var sand := Color("d9a066"); var amber := Color("ffb040"); var dark := Color("140c06")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.8, 0))
	k.bone("chest", "hips", Vector3(0, 1.08, 0))
	k.bone("head", "chest", Vector3(0, 1.44, -0.06))
	k.bone("arm_l", "chest", Vector3(-0.46, 1.34, 0))
	k.bone("arm_r", "chest", Vector3(0.46, 1.34, 0))
	k.bone("leg_l", "hips", Vector3(-0.2, 0.78, 0))
	k.bone("leg_r", "hips", Vector3(0.2, 0.78, 0))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.2, 0.78, 0), Vector3(s * 0.23, 0.36, 0), 0.15, cloth)
		k.torus(0.1, 0.17, Vector3(s * 0.23, 0.42, 0), cloth_d, Vector3.ZERO, -1, 8, 4)
		k.box(Vector3(0.3, 0.3, 0.36), Vector3(s * 0.23, 0.15, -0.04), stone_d, Vector3(0, s * 6, 0))
		k.box(Vector3(0.24, 0.12, 0.2), Vector3(s * 0.23, 0.3, -0.06), stone, Vector3(8, 0, s * 4))
		k.box(Vector3(0.03, 0.18, 0.03), Vector3(s * 0.25, 0.16, -0.225), amber, Vector3(0, 0, s * 12), 2.2)
	k.on("hips")
	k.cyl(0.36, 0.4, 0.24, Vector3(0, 0.82, 0), cloth_d, Vector3.ZERO, -1, 10)
	k.box(Vector3(0.26, 0.2, 0.08), Vector3(0, 0.84, -0.38), stone)
	k.box(Vector3(0.1, 0.1, 0.04), Vector3(0, 0.84, -0.43), amber, Vector3(0, 0, 45), 2.6)
	k.box(Vector3(0.3, 0.42, 0.04), Vector3(0, 0.56, -0.33), cloth, Vector3(5, 0, 0))
	k.box(Vector3(0.4, 0.42, 0.04), Vector3(0, 0.56, 0.33), cloth, Vector3(-5, 0, 0))
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.12, 0.02), cloth, Vector3(0.46, 0.4, 0.38), Vector3.ZERO, -1, 12, 7)
	k.ball(1.0, Vector3(0, 1.2, -0.14), skin, Vector3(0.32, 0.26, 0.26))
	k.box(Vector3(0.12, 0.66, 0.05), Vector3(0, 1.12, -0.36), cloth_d, Vector3(0, 0, -36))
	k.box(Vector3(0.9, 0.14, 0.5), Vector3(0, 1.4, 0.02), stone_d)
	k.box(Vector3(0.62, 0.22, 0.36), Vector3(0, 1.48, 0.16), stone, Vector3(-10, 0, 0))
	k.box(Vector3(0.04, 0.2, 0.03), Vector3(0.12, 1.5, -0.02), amber, Vector3(0, 0, 20), 2.0)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.52, -0.08), skin, Vector3(0.16, 0.17, 0.16))
	k.box(Vector3(0.3, 0.06, 0.28), Vector3(0, 1.58, -0.08), stone)
	k.box(Vector3(0.06, 0.06, 0.03), Vector3(0, 1.58, -0.23), amber, Vector3(0, 0, 45), 3.0)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.05, 0.022, 0.02), Vector3(s * 0.06, 1.52, -0.23), amber, Vector3.ZERO, 3.2)
		k.box(Vector3(0.07, 0.025, 0.03), Vector3(s * 0.06, 1.55, -0.235), beard)
	k.prism(Vector3(0.26, 0.3, 0.14), Vector3(0, 1.36, -0.18), beard, Vector3(180, 0, 0))
	k.ball(1.0, Vector3(0, 1.44, -0.2), beard, Vector3(0.13, 0.08, 0.06))
	var rocks := [[Vector3(0.0, 0.08, 0.0), Vector3(0.36, 0.26, 0.38), Vector3(8, 20, 6)], [Vector3(0.1, 0.22, 0.04), Vector3(0.22, 0.18, 0.24), Vector3(-12, 50, 20)],
		[Vector3(-0.04, 0.2, -0.1), Vector3(0.18, 0.16, 0.18), Vector3(20, 10, -14)]]
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		var sp := Vector3(s * 0.5, 1.42, 0)
		for r in rocks:
			var off: Vector3 = r[0]
			k.box(r[1], sp + Vector3(off.x * s, off.y, off.z), stone if r != rocks[1] else sand, r[2] * Vector3(1, s, s))
		k.spike(sp + Vector3(s * 0.08, 0.26, 0.06), sp + Vector3(s * 0.18, 0.52, 0.1), 0.07, sand, 0.6, 5)
		k.spike(sp + Vector3(s * -0.06, 0.24, 0.1), sp + Vector3(s * -0.04, 0.42, 0.16), 0.05, sand, 0.6, 5)
		k.box(Vector3(0.03, 0.03, 0.3), sp + Vector3(s * 0.19, 0.06, 0), amber, Vector3(0, 0, s * 20), 2.2)
		k.limb(Vector3(s * 0.48, 1.28, 0), Vector3(s * 0.56, 0.9, -0.02), 0.12, skin)
		var fc := Vector3(s * 0.6, 0.62, -0.06)
		k.ball(1.0, fc, stone_d, Vector3(0.24, 0.26, 0.26), Vector3(0, 0, s * 8), -1, 8, 6)
		k.box(Vector3(0.36, 0.2, 0.3), fc + Vector3(0, 0.16, 0.0), stone, Vector3(6, s * 14, s * 8))
		k.box(Vector3(0.38, 0.14, 0.14), fc + Vector3(0, -0.06, -0.2), stone, Vector3(-10, 0, 0))
		for i in 4:
			k.box(Vector3(0.08, 0.09, 0.08), fc + Vector3((i - 1.5) * 0.085, -0.04, -0.29), sand, Vector3(0, 0, (i - 1.5) * 6))
		k.box(Vector3(0.03, 0.26, 0.03), fc + Vector3(s * 0.14, 0.02, -0.18), amber, Vector3(10, 0, s * -18), 2.4)
		k.box(Vector3(0.22, 0.03, 0.03), fc + Vector3(0, 0.07, -0.21), amber, Vector3(0, 0, s * 8), 2.4)
		k.box(Vector3(0.03, 0.2, 0.03), fc + Vector3(s * -0.1, 0.16, -0.16), amber, Vector3(0, 0, s * 30), 2.0)
	var p := _base_params()
	p.merge({"radius": 0.6, "height": 1.75, "glow": Color("ffb040"), "rim": Color(1.0, 0.8, 0.55),
		"attack": "slam2", "run_freq": 8.0, "stride": 0.55, "arm_swing": 0.3, "lean": 0.14, "atk_dur": 0.62, "enemy": false}, true)
	return k.finish(p)

## Gunsmith: duelist-engineer in a long coat with brass goggles, a long brass-fitted flintlock rifle, blue spark.
static func _gunsmith() -> Dictionary:
	var k := RB.new()
	var coat := Color("6a4228"); var coat_d := Color("3a2418"); var vest := Color("2c3a50"); var shirt := Color("dcd0b4"); var brass := Color("dcae4e")
	var steel := Color("8e96a6"); var wood := Color("7e4a26"); var blue := Color("4fb8ff"); var skin := Color("d8a47c"); var hair := Color("3a2216"); var dark := Color("14100c")
	var scarf := Color("2e78b0")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.95, 0))
	k.bone("chest", "hips", Vector3(0, 1.24, 0))
	k.bone("head", "chest", Vector3(0, 1.58, -0.02))
	k.bone("arm_l", "chest", Vector3(-0.3, 1.42, 0))
	k.bone("arm_r", "chest", Vector3(0.3, 1.42, 0))
	k.bone("weapon_r", "arm_r", Vector3(0.36, 0.88, -0.05))
	k.bone("leg_l", "hips", Vector3(-0.13, 0.93, 0))
	k.bone("leg_r", "hips", Vector3(0.13, 0.93, 0))
	k.bone("cape", "chest", Vector3(0, 1.1, 0.2))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.13, 0.93, 0), Vector3(s * 0.14, 0.5, 0), 0.09, vest)
		k.cyl(0.1, 0.115, 0.46, Vector3(s * 0.145, 0.27, 0), coat_d)
		k.box(Vector3(0.15, 0.11, 0.32), Vector3(s * 0.145, 0.055, -0.06), dark)
		k.box(Vector3(0.21, 0.04, 0.22), Vector3(s * 0.145, 0.46, 0), brass)
	k.on("hips")
	k.cyl(0.22, 0.24, 0.18, Vector3(0, 0.95, 0), vest)
	k.cyl(0.245, 0.245, 0.06, Vector3(0, 0.9, 0), coat_d)
	k.box(Vector3(0.08, 0.07, 0.03), Vector3(0, 0.9, -0.25), brass)
	for i in 4:
		k.cyl(0.025, 0.025, 0.08, Vector3(-0.2 + i * 0.045, 0.9, -0.2 + i * 0.02), brass)
	k.box(Vector3(0.08, 0.2, 0.12), Vector3(0.25, 0.8, -0.04), coat_d, Vector3(0, 0, 8))
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.2, 0.7, 0.03), Vector3(s * 0.13, 0.58, -0.17), coat, Vector3(8, 0, s * 6))
	k.on("cape")
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.22, 0.86, 0.03), Vector3(s * 0.12, 0.62, 0.22), coat, Vector3(-8, 0, s * 5))
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.24, 0), coat, Vector3(0.27, 0.3, 0.2))
	k.box(Vector3(0.2, 0.4, 0.04), Vector3(0, 1.22, -0.17), vest)
	k.box(Vector3(0.08, 0.2, 0.03), Vector3(0, 1.36, -0.195), shirt)
	for i in 3:
		k.ball(0.016, Vector3(0, 1.22 - i * 0.08, -0.195), brass, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
	k.box(Vector3(0.07, 0.58, 0.04), Vector3(0.0, 1.22, -0.21), coat_d, Vector3(0, 0, 34))
	for i in 4:
		k.box(Vector3(0.03, 0.07, 0.03), Vector3(-0.1 + i * 0.065, 1.08 + i * 0.09, -0.235), brass, Vector3(0, 0, 34))
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.12, 0.22, 0.04), Vector3(s * 0.13, 1.56, 0.0), coat, Vector3(-12, s * -25, s * -10))
	k.torus(0.08, 0.15, Vector3(0, 1.48, -0.02), scarf, Vector3(10, 0, 0), -1, 10, 4)
	k.box(Vector3(0.08, 0.2, 0.03), Vector3(0.05, 1.36, -0.17), scarf, Vector3(0, 0, -10))
	var tk := Vector3(0, 1.28, 0.24)
	k.cyl(0.11, 0.11, 0.36, tk, brass, Vector3.ZERO, -1, 8)
	k.hemi(0.11, tk + Vector3(0, 0.18, 0), brass)
	k.cyl(0.115, 0.115, 0.04, tk + Vector3(0, 0.08, 0), steel)
	k.cyl(0.115, 0.115, 0.04, tk + Vector3(0, -0.12, 0), steel)
	k.box(Vector3(0.1, 0.12, 0.04), tk + Vector3(0, -0.02, 0.1), blue, Vector3.ZERO, 2.6)
	k.tube(tk + Vector3(0.06, 0.2, 0), Vector3(0.24, 1.45, 0.06), 0.02, 0.02, steel, -1, 5)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.64, -0.02), skin, Vector3(0.14, 0.16, 0.14))
	k.hemi(1.0, Vector3(0, 1.67, 0.0), hair, Vector3(0.155, 0.13, 0.16), Vector3(-10, 0, 0))
	k.box(Vector3(0.18, 0.06, 0.12), Vector3(0, 1.73, -0.1), hair, Vector3(20, 0, 0))
	k.box(Vector3(0.1, 0.022, 0.03), Vector3(0, 1.585, -0.14), hair)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.035, 0.022, 0.02), Vector3(s * 0.05, 1.64, -0.14), dark)
	k.torus(0.13, 0.165, Vector3(0, 1.72, -0.01), coat_d, Vector3(-14, 0, 0), -1, 10, 4)
	for s in [-1.0, 1.0]:
		var gc := Vector3(s * 0.065, 1.75, -0.15)
		k.cyl(0.05, 0.05, 0.05, gc, brass, Vector3(76, 0, 0), -1, 8)
		k.cyl(0.036, 0.036, 0.02, gc + Vector3(0, 0.006, -0.025), blue, Vector3(76, 0, 0), 2.8, 8)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.31, 1.43, 0), coat, Vector3(0.12, 0.1, 0.12))
		k.tube(Vector3(s * 0.3, 1.4, 0), Vector3(s * 0.35, 0.96, -0.04), 0.075, 0.09, coat, -1, 7)
		k.cyl(0.1, 0.095, 0.1, Vector3(s * 0.355, 0.98, -0.04), coat_d)
		k.ball(0.06, Vector3(s * 0.36, 0.88, -0.05), Color("4a3020"))
	k.on("weapon_r")
	var o := Vector3(0.36, 0.88, -0.05)
	k.extrude(PackedVector2Array([Vector2(-0.06, 0.05), Vector2(0.34, -0.12), Vector2(0.36, 0.02), Vector2(0.06, 0.1), Vector2(-0.06, 0.12)]), 0.065,
		o + Vector3(0, 0.0, 0.04), wood, Vector3(0, -90, 0))
	k.box(Vector3(0.07, 0.07, 0.4), o + Vector3(0, 0.08, -0.22), wood)
	k.cyl(0.028, 0.032, 1.0, o + Vector3(0, 0.12, -0.62), steel, Vector3(90, 0, 0), -1, 7)
	for zz in [-0.28, -0.6, -0.95]:
		k.cyl(0.04, 0.04, 0.04, o + Vector3(0, 0.12, zz), brass, Vector3(90, 0, 0), -1, 7)
	k.cyl(0.042, 0.042, 0.03, o + Vector3(0, 0.12, -1.11), blue, Vector3(90, 0, 0), 2.6, 7)
	k.box(Vector3(0.08, 0.08, 0.1), o + Vector3(0.0, 0.1, -0.06), brass)
	k.spike(o + Vector3(0.04, 0.14, -0.04), o + Vector3(0.05, 0.22, 0.0), 0.025, brass, -1, 4)
	k.cyl(0.026, 0.026, 0.32, o + Vector3(0, 0.2, -0.3), brass, Vector3(90, 0, 0), -1, 6)
	k.cyl(0.03, 0.03, 0.02, o + Vector3(0, 0.2, -0.465), blue, Vector3(90, 0, 0), 2.6, 6)
	k.ball(0.035, o + Vector3(0, 0.1, -0.13), blue, Vector3.ONE, Vector3.ZERO, 2.4, 6, 4)
	var p := _base_params()
	p.merge({"radius": 0.45, "height": 1.85, "glow": Color("4fb8ff"), "rim": Color(0.6, 0.85, 1.0),
		"attack": "aim", "run_freq": 10.5, "stride": 0.8, "arm_swing": 0.35, "lean": 0.2, "atk_dur": 0.45,
		"w_idle_r": Vector3(0.3, 0.95, 0.0), "enemy": false, "two_hand": true, "sit_wx": -0.4}, true)
	return k.finish(p)

## Sunspeaker: radiant priest in white-and-gold robes with a sun-disc halo behind the head and a sun staff.
static func _sunspeaker() -> Dictionary:
	var k := RB.new()
	var robe := Color("f2ead8"); var robe_s := Color("c9bc9e"); var gold := Color("eab83e"); var gold_d := Color("a8741a")
	var skin := Color("9a6440"); var sun := Color("ffe680"); var orange := Color("ff9a30"); var sash := Color("c8442a"); var dark := Color("1a0e06")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.94, 0))
	k.bone("chest", "hips", Vector3(0, 1.22, 0))
	k.bone("head", "chest", Vector3(0, 1.56, -0.02))
	k.bone("arm_l", "chest", Vector3(-0.29, 1.4, 0))
	k.bone("arm_r", "chest", Vector3(0.29, 1.4, 0))
	k.bone("weapon_r", "arm_r", Vector3(0.38, 0.86, -0.06))
	k.bone("leg_l", "hips", Vector3(-0.12, 0.92, 0))
	k.bone("leg_r", "hips", Vector3(0.12, 0.92, 0))
	k.bone("cape", "chest", Vector3(0, 1.42, 0.18))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.12, 0.92, 0), Vector3(s * 0.13, 0.14, 0), 0.075, robe_s)
		k.cyl(0.07, 0.075, 0.18, Vector3(s * 0.13, 0.12, 0), skin)
		k.box(Vector3(0.13, 0.05, 0.28), Vector3(s * 0.13, 0.025, -0.05), gold_d)
		k.torus(0.06, 0.09, Vector3(s * 0.13, 0.17, 0), gold, Vector3.ZERO, -1, 8, 4)
	k.on("hips")
	k.cyl(0.22, 0.4, 0.62, Vector3(0, 0.62, 0), robe, Vector3.ZERO, -1, 12)
	k.torus(0.37, 0.43, Vector3(0, 0.33, 0), gold, Vector3.ZERO, -1, 12, 4)
	k.box(Vector3(0.2, 0.7, 0.03), Vector3(0, 0.58, -0.32), gold, Vector3(19, 0, 0))
	k.box(Vector3(0.12, 0.6, 0.035), Vector3(0, 0.58, -0.33), sash, Vector3(19, 0, 0))
	k.box(Vector3(0.06, 0.06, 0.03), Vector3(0, 0.74, -0.32), sun, Vector3(19, 0, 45), 2.6)
	k.cyl(0.235, 0.235, 0.08, Vector3(0, 0.94, 0), gold)
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.22, 0), robe, Vector3(0.27, 0.3, 0.21))
	var pect := PackedVector2Array()
	for i in 11:
		var a := deg_to_rad(200.0 + i * 14.0)
		pect.append(Vector2(cos(a) * 0.3, 0.06 + sin(a) * 0.3))
	for i in 11:
		var a := deg_to_rad(340.0 - i * 14.0)
		pect.append(Vector2(cos(a) * 0.2, 0.16 + sin(a) * 0.2))
	k.extrude(pect, 0.04, Vector3(0, 1.5, -0.15), gold, Vector3(-12, 0, 0))
	k.ball(0.05, Vector3(0, 1.3, -0.21), sun, Vector3.ONE, Vector3.ZERO, 3.0, 8, 5)
	k.box(Vector3(0.08, 0.56, 0.04), Vector3(0, 1.16, -0.2), sash, Vector3(0, 0, -28))
	k.on("cape")
	k.box(Vector3(0.46, 1.1, 0.03), Vector3(0, 0.9, 0.24), robe_s, Vector3(-6, 0, 0))
	k.box(Vector3(0.46, 0.06, 0.035), Vector3(0, 0.36, 0.3), gold, Vector3(-6, 0, 0))
	k.on("head")
	k.ball(1.0, Vector3(0, 1.62, -0.02), skin, Vector3(0.13, 0.15, 0.13))
	k.ball(1.0, Vector3(0, 1.66, 0.03), robe, Vector3(0.16, 0.16, 0.16))
	k.box(Vector3(0.28, 0.2, 0.06), Vector3(0, 1.5, 0.1), robe, Vector3(10, 0, 0))
	k.torus(0.135, 0.165, Vector3(0, 1.7, -0.01), gold, Vector3(-10, 0, 0), -1, 10, 4)
	k.box(Vector3(0.05, 0.05, 0.03), Vector3(0, 1.72, -0.16), orange, Vector3(0, 0, 45), 2.8)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.045, 0.02, 0.02), Vector3(s * 0.05, 1.62, -0.13), sun, Vector3.ZERO, 3.0)
	k.box(Vector3(0.05, 0.012, 0.02), Vector3(0, 1.56, -0.125), dark)
	var hc := Vector3(0, 1.74, 0.2)
	k.torus(0.3, 0.36, hc, gold, Vector3(90, 0, 0), 1.6, 18, 4)
	k.torus(0.18, 0.21, hc, sun, Vector3(90, 0, 0), 2.4, 14, 4)
	for i in 12:
		var a := TAU * i / 12.0
		var ln := 0.16 if i % 2 == 0 else 0.1
		k.spike(hc + Vector3(cos(a) * 0.35, sin(a) * 0.35, 0.01), hc + Vector3(cos(a) * (0.35 + ln), sin(a) * (0.35 + ln), 0.01), 0.04, gold if i % 2 == 0 else orange, 1.4, 4)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(1.0, Vector3(s * 0.3, 1.4, 0), gold, Vector3(0.12, 0.08, 0.12))
		k.tube(Vector3(s * 0.29, 1.38, 0), Vector3(s * 0.36, 0.94, -0.04), 0.07, 0.14, robe, -1, 8)
		k.torus(0.1, 0.145, Vector3(s * 0.36, 0.95, -0.04), gold, Vector3.ZERO, -1, 8, 4)
		k.ball(0.06, Vector3(s * 0.37, 0.86, -0.06), skin)
	k.on("arm_l")
	k.ball(0.06, Vector3(-0.37, 0.82, -0.1), sun, Vector3.ONE, Vector3.ZERO, 2.6, 6, 4)
	k.on("weapon_r")
	var o := Vector3(0.38, 0.86, -0.06)
	k.cyl(0.03, 0.035, 2.0, o + Vector3(0, 0.18, 0), gold_d)
	for yy in [-0.6, 0.2, 0.9]:
		k.cyl(0.045, 0.045, 0.05, o + Vector3(0, yy, 0), gold)
	var sc := o + Vector3(0, 1.34, 0)
	k.cyl(0.04, 0.03, 0.18, sc + Vector3(0, -0.2, 0), gold)
	k.cyl(0.17, 0.17, 0.04, sc, gold, Vector3(90, 0, 0), -1, 14)
	k.ball(1.0, sc + Vector3(0, 0, -0.02), sun, Vector3(0.11, 0.11, 0.05), Vector3.ZERO, 3.2, 10, 5)
	for i in 8:
		var a := TAU * i / 8.0
		k.spike(sc + Vector3(cos(a) * 0.16, sin(a) * 0.16, 0), sc + Vector3(cos(a) * 0.3, sin(a) * 0.3, 0), 0.035, gold, 1.2, 4)
	var p := _base_params()
	p.merge({"radius": 0.45, "height": 1.95, "glow": Color("ffe680"), "rim": Color(1.0, 0.92, 0.6),
		"attack": "cast", "run_freq": 9.0, "stride": 0.6, "arm_swing": 0.3, "lean": 0.14, "atk_dur": 0.55,
		"w_idle_r": Vector3(-0.05, 0, 0), "enemy": false, "sit_wx": -0.75}, true)
	return k.finish(p)

# =================================================================== SUMMONS (wave 2)

## Skeleton (Gravekeeper minion): bony biped with mint glowing eyes and a rusty notched blade.
static func _skeleton() -> Dictionary:
	var k := RB.new()
	var bone := Color("ddd4ba"); var bone_d := Color("a89c80"); var rust := Color("94502c"); var iron := Color("5e5852")
	var mint := Color("8affc8"); var dark := Color("0c0a0a"); var cloth := Color("3e3a2c")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.72, 0))
	k.bone("chest", "hips", Vector3(0, 0.95, 0))
	k.bone("head", "chest", Vector3(0, 1.22, -0.02))
	k.bone("arm_l", "chest", Vector3(-0.22, 1.12, 0))
	k.bone("arm_r", "chest", Vector3(0.22, 1.12, 0))
	k.bone("weapon_r", "arm_r", Vector3(0.28, 0.66, -0.04))
	k.bone("leg_l", "hips", Vector3(-0.1, 0.7, 0))
	k.bone("leg_r", "hips", Vector3(0.1, 0.7, 0))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.tube(Vector3(s * 0.1, 0.7, 0), Vector3(s * 0.11, 0.38, 0), 0.035, 0.035 * 0.8, bone, -1, 5)
		k.ball(0.05, Vector3(s * 0.11, 0.38, -0.01), bone_d, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
		k.tube(Vector3(s * 0.11, 0.38, 0), Vector3(s * 0.11, 0.06, 0), 0.03, 0.03 * 0.8, bone, -1, 5)
		k.box(Vector3(0.08, 0.04, 0.18), Vector3(s * 0.11, 0.02, -0.04), bone_d)
	k.on("hips")
	k.ball(1.0, Vector3(0, 0.72, 0), bone_d, Vector3(0.15, 0.07, 0.1), Vector3.ZERO, -1, 8, 4)
	k.box(Vector3(0.22, 0.26, 0.03), Vector3(0, 0.56, -0.1), cloth, Vector3(6, 0, 0))
	k.prism(Vector3(0.1, 0.1, 0.03), Vector3(0.04, 0.39, -0.12), cloth, Vector3(186, 0, 0))
	k.on("chest")
	k.cyl(0.03, 0.03, 0.3, Vector3(0, 0.88, 0.03), bone_d, Vector3.ZERO, -1, 5)
	for i in 3:
		var y := 0.94 + i * 0.07
		var w := 0.13 + i * 0.015
		k.torus(w - 0.022, w, Vector3(0, y, 0), bone, Vector3(0, 0, 0), -1, 7, 3, Vector3(1, 1.6, 0.8))
	k.box(Vector3(0.035, 0.2, 0.03), Vector3(0, 1.0, -0.12), bone)
	k.box(Vector3(0.4, 0.035, 0.05), Vector3(0, 1.13, 0), bone)
	k.ball(0.035, Vector3(0, 1.0, -0.05), mint, Vector3.ONE, Vector3.ZERO, 2.0, 6, 4)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.3, -0.02), bone, Vector3(0.12, 0.12, 0.13), Vector3.ZERO, -1, 8, 5)
	k.box(Vector3(0.14, 0.06, 0.1), Vector3(0, 1.2, -0.08), bone_d)
	for s in [-1.0, 1.0]:
		k.ball(1.0, Vector3(s * 0.045, 1.31, -0.12), dark, Vector3(0.04, 0.035, 0.02), Vector3.ZERO, -1, 6, 4)
		k.ball(0.02, Vector3(s * 0.045, 1.31, -0.135), mint, Vector3.ONE, Vector3.ZERO, 3.6, 6, 4)
	k.box(Vector3(0.1, 0.012, 0.012), Vector3(0, 1.21, -0.135), dark)
	k.cyl(0.13, 0.13, 0.02, Vector3(0, 1.38, -0.02), iron, Vector3(-8, 0, 12), -1, 8)
	k.hemi(1.0, Vector3(0.0, 1.38, -0.02), iron, Vector3(0.12, 0.08, 0.12), Vector3(-8, 0, 12), -1, 8, 3)
	for s in [-1.0, 1.0]:
		k.on("arm_l" if s < 0 else "arm_r")
		k.ball(0.045, Vector3(s * 0.22, 1.12, 0), bone_d, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
		k.tube(Vector3(s * 0.22, 1.12, 0), Vector3(s * 0.26, 0.88, -0.02), 0.028, 0.028 * 0.8, bone, -1, 5)
		k.tube(Vector3(s * 0.26, 0.88, -0.02), Vector3(s * 0.28, 0.68, -0.04), 0.024, 0.024 * 0.8, bone, -1, 5)
		k.ball(0.04, Vector3(s * 0.28, 0.66, -0.04), bone_d, Vector3.ONE, Vector3.ZERO, -1, 6, 4)
	k.on("weapon_r")
	var o := Vector3(0.28, 0.66, -0.04)
	k.cyl(0.022, 0.022, 0.18, o, Color("4a3020"), Vector3.ZERO, -1, 5)
	k.box(Vector3(0.18, 0.035, 0.05), o + Vector3(0, 0.1, 0), iron)
	k.extrude(PackedVector2Array([Vector2(-0.04, 0), Vector2(0.04, 0), Vector2(0.05, 0.3), Vector2(0.02, 0.36), Vector2(0.045, 0.44),
		Vector2(0.0, 0.62), Vector2(-0.05, 0.4), Vector2(-0.03, 0.3), Vector2(-0.05, 0.2)]), 0.025, o + Vector3(0, 0.11, 0), rust)
	var p := _base_params()
	p.merge({"radius": 0.38, "height": 1.4, "glow": Color("8affc8"), "rim": Color(0.65, 1.0, 0.85),
		"attack": "swipe", "run_freq": 12.0, "stride": 0.7, "arm_swing": 0.5, "lean": 0.22, "atk_dur": 0.42,
		"w_idle_r": Vector3(0.3, 0, 0), "enemy": false}, true)
	return k.finish(p)

## Snare trap: flat toothed bear-trap lying open on the ground with an olive glowing trigger plate.
static func _snare_trap() -> Dictionary:
	var k := RB.new()
	var iron := Color("6e6a60"); var iron_d := Color("3e3a34"); var tooth := Color("d8d4c4"); var olive := Color("c8d24a")
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3.ZERO)
	k.bone("head", "body", Vector3(0, 0.06, 0))
	k.on("body")
	k.cyl(0.2, 0.24, 0.05, Vector3(0, 0.025, 0), iron_d, Vector3.ZERO, -1, 10)
	k.cyl(0.11, 0.11, 0.03, Vector3(0, 0.06, 0), olive, Vector3.ZERO, 2.4, 10)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.22, 0.05, 0.08), Vector3(s * 0.38, 0.03, 0), iron_d)
		k.torus(0.035, 0.06, Vector3(s * 0.48, 0.05, 0), iron, Vector3(90, 0, 0), -1, 6, 3)
	for i in 3:
		k.torus(0.02, 0.04, Vector3(0.05 + i * 0.06, 0.02, 0.28 + i * 0.05), iron_d, Vector3(0, 90 * (i % 2), 90), -1, 6, 3)
	k.cyl(0.02, 0.03, 0.12, Vector3(0.24, 0.06, 0.45), iron_d, Vector3(0, 0, 10), -1, 5)
	k.on("head")
	k.torus(0.34, 0.39, Vector3(0, 0.06, 0), iron, Vector3.ZERO, -1, 16, 4)
	for i in 14:
		var a := TAU * (i + 0.5) / 14.0
		var b := Vector3(cos(a) * 0.36, 0.07, sin(a) * 0.36)
		k.spike(b, Vector3(cos(a) * 0.3, 0.2, sin(a) * 0.3), 0.035, tooth, -1, 4)
	k.ball(0.03, Vector3(0.36, 0.07, 0), olive, Vector3.ONE, Vector3.ZERO, 2.6, 6, 4)
	k.ball(0.03, Vector3(-0.36, 0.07, 0), olive, Vector3.ONE, Vector3.ZERO, 2.6, 6, 4)
	var p := _base_params()
	p.merge({"style": "totem", "radius": 0.5, "height": 0.3, "glow": Color("c8d24a"), "rim": Color(0.9, 0.95, 0.6),
		"attack": "pulse", "atk_dur": 0.3, "enemy": false}, true)
	return k.finish(p)

## Blast charge: leather powder satchel with a curling lit fuse.
static func _blast_charge() -> Dictionary:
	var k := RB.new()
	var leather := Color("7a4e2c"); var leather_d := Color("4a2e1a"); var iron := Color("3a3836"); var rope := Color("c8b080"); var olive := Color("c8d24a")
	var powder := Color("2a2622")
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3.ZERO)
	k.bone("head", "body", Vector3(0, 0.46, 0))
	k.on("body")
	k.ball(1.0, Vector3(0, 0.24, 0), leather, Vector3(0.38, 0.24, 0.3), Vector3.ZERO, -1, 10, 6)
	k.box(Vector3(0.56, 0.12, 0.42), Vector3(0, 0.06, 0), leather_d)
	k.ball(1.0, Vector3(0, 0.36, -0.08), leather_d, Vector3(0.33, 0.12, 0.25), Vector3(-10, 0, 0))
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.06, 0.44, 0.62), Vector3(s * 0.16, 0.24, 0), leather_d)
		k.box(Vector3(0.07, 0.07, 0.07), Vector3(s * 0.16, 0.24, -0.31), iron)
	k.box(Vector3(0.12, 0.12, 0.03), Vector3(0, 0.28, -0.31), olive, Vector3(0, 0, 45), 2.2)
	k.ball(1.0, Vector3(0.0, 0.38, 0.04), powder, Vector3(0.14, 0.12, 0.14))
	k.cyl(0.05, 0.05, 0.05, Vector3(0, 0.49, 0.04), iron)
	k.on("head")
	var pts := [Vector3(0, 0.5, 0.04), Vector3(0.04, 0.56, 0.02), Vector3(0.08, 0.58, -0.04), Vector3(0.1, 0.56, -0.1)]
	for i in pts.size() - 1:
		k.tube(pts[i], pts[i + 1], 0.016, 0.016, rope, -1, 5)
	k.ball(0.035, pts[3], Color("ffd060"), Vector3.ONE, Vector3.ZERO, 3.2, 6, 4)
	k.spike(pts[3], pts[3] + Vector3(0.02, 0.1, -0.02), 0.025, Color("ff9a30"), 3.0, 4)
	var p := _base_params()
	p.merge({"style": "totem", "radius": 0.45, "height": 0.6, "glow": Color("ff9a30"), "rim": Color(1.0, 0.8, 0.5),
		"attack": "pulse", "atk_dur": 0.3, "enemy": false}, true)
	return k.finish(p)

## Boulder: big rolling rock with glowing amber cracks (code moves/rotates it).
static func _boulder() -> Dictionary:
	var k := RB.new()
	var stone := Color("a8906e"); var stone_d := Color("6e5c48"); var sand := Color("d0a26a"); var amber := Color("ffb040")
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3(0, 0.8, 0))
	k.bone("head", "body", Vector3(0, 0.8, 0))
	k.on("body")
	var c := Vector3(0, 0.8, 0)
	k.ball(0.76, c, stone, Vector3.ONE, Vector3(10, 20, 0), -1, 12, 8)
	var lumps := [Vector3(0.6, 0.3, 0.3), Vector3(-0.5, 0.4, -0.3), Vector3(0.1, 0.7, -0.4), Vector3(-0.3, -0.2, 0.62), Vector3(0.4, -0.3, -0.55),
		Vector3(-0.6, -0.1, 0.2), Vector3(0.2, 0.2, 0.7), Vector3(0.0, -0.7, 0.0)]
	for i in lumps.size():
		var d: Vector3 = (lumps[i] as Vector3).normalized()
		k.box(Vector3(0.42, 0.34, 0.4), c + d * 0.62, stone_d if i % 2 == 0 else sand, Vector3(i * 37, i * 53, i * 23))
	var cracks := [[Vector3(0, 0.1, -1), 20.0], [Vector3(0.75, -0.1, -0.6), 70.0], [Vector3(-0.8, 0.3, -0.5), -40.0], [Vector3(0.2, 0.8, -0.5), 110.0],
		[Vector3(0.6, -0.2, 0.7), 110.0], [Vector3(-0.6, 0, 0.7), 150.0], [Vector3(0, 1, 0), 90.0]]
	for cr in cracks:
		var d: Vector3 = (cr[0] as Vector3).normalized()
		var t1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized().rotated(d, deg_to_rad(float(cr[1])))
		var t2 := d.cross(t1)
		var prev := Vector3.ZERO
		for i in 5:
			var q := (d + t1 * (i * 0.16 - 0.32) + t2 * (0.07 if i % 2 == 0 else -0.07)).normalized() * 0.77 + c
			if i > 0:
				k.tube(prev, q, 0.022, 0.022, amber, 2.4, 4)
			prev = q
	var p := _base_params()
	p.merge({"style": "totem", "radius": 0.9, "height": 1.6, "glow": Color("ffb040"), "rim": Color(1.0, 0.8, 0.55),
		"attack": "pulse", "atk_dur": 0.3, "enemy": false}, true)
	return k.finish(p)

## Stone pillar: rough raised column with amber cracks and rubble at its base.
static func _stone_pillar() -> Dictionary:
	var k := RB.new()
	var stone := Color("a8906e"); var stone_d := Color("6e5c48"); var sand := Color("d0a26a"); var amber := Color("ffb040")
	k.bone("root", "", Vector3.ZERO)
	k.bone("body", "root", Vector3.ZERO)
	k.bone("head", "body", Vector3(0, 2.3, 0))
	k.on("body")
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		k.box(Vector3(0.36, 0.26, 0.32), Vector3(cos(a) * 0.72, 0.1, sin(a) * 0.72), stone_d if i % 2 == 0 else stone, Vector3(i * 17, i * 41, i * 29))
	k.box(Vector3(1.2, 0.8, 1.1), Vector3(0, 0.4, 0), stone_d, Vector3(0, 12, 3))
	k.box(Vector3(1.0, 0.9, 0.95), Vector3(0.02, 1.2, 0), stone, Vector3(2, 40, -3))
	k.box(Vector3(0.86, 0.6, 0.8), Vector3(-0.03, 1.9, 0.02), stone_d, Vector3(-3, 75, 4))
	k.box(Vector3(0.95, 0.12, 0.9), Vector3(0, 1.62, 0), sand, Vector3(0, 55, 0))
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		k.box(Vector3(0.05, 1.3, 0.05), Vector3(cos(a) * 0.5, 1.1, sin(a) * 0.5), amber, Vector3(0, -rad_to_deg(a), (i - 1.5) * 10.0), 2.2)
	k.on("head")
	k.prism(Vector3(0.7, 0.5, 0.6), Vector3(0.05, 2.38, 0), stone, Vector3(0, 30, 6))
	k.prism(Vector3(0.36, 0.4, 0.3), Vector3(-0.28, 2.3, 0.15), sand, Vector3(0, -20, -10))
	k.ball(0.07, Vector3(0, 2.2, -0.42), amber, Vector3.ONE, Vector3.ZERO, 3.0, 6, 4)
	var p := _base_params()
	p.merge({"style": "totem", "radius": 0.9, "height": 2.6, "glow": Color("ffb040"), "rim": Color(1.0, 0.8, 0.55),
		"attack": "pulse", "atk_dur": 0.3, "enemy": false}, true)
	return k.finish(p)

static func _generic() -> Dictionary:
	var k := RB.new()
	var cloth := Color("6a6460"); var dark := Color("2a2624"); var glow := Color("ffd27a")
	k.bone("root", "", Vector3.ZERO)
	k.bone("hips", "root", Vector3(0, 0.85, 0))
	k.bone("chest", "hips", Vector3(0, 1.1, 0))
	k.bone("head", "chest", Vector3(0, 1.42, 0))
	k.bone("arm_l", "chest", Vector3(-0.3, 1.32, 0))
	k.bone("arm_r", "chest", Vector3(0.3, 1.32, 0))
	k.bone("leg_l", "hips", Vector3(-0.14, 0.85, 0))
	k.bone("leg_r", "hips", Vector3(0.14, 0.85, 0))
	for s in [-1.0, 1.0]:
		k.on("leg_l" if s < 0 else "leg_r")
		k.limb(Vector3(s * 0.14, 0.85, 0), Vector3(s * 0.15, 0.08, 0), 0.1, dark, -1, 6)
		k.on("arm_l" if s < 0 else "arm_r")
		k.limb(Vector3(s * 0.3, 1.32, 0), Vector3(s * 0.36, 0.8, -0.04), 0.09, cloth, -1, 6)
	k.on("chest")
	k.ball(1.0, Vector3(0, 1.1, 0), cloth, Vector3(0.3, 0.36, 0.24), Vector3.ZERO, -1, 8, 5)
	k.on("head")
	k.ball(1.0, Vector3(0, 1.5, 0), cloth, Vector3(0.2, 0.22, 0.2), Vector3.ZERO, -1, 8, 5)
	k.ball(1.0, Vector3(0, 1.48, -0.13), dark, Vector3(0.13, 0.13, 0.06), Vector3.ZERO, -1, 6, 4)
	for s in [-1.0, 1.0]:
		k.box(Vector3(0.05, 0.02, 0.02), Vector3(s * 0.05, 1.5, -0.18), glow, Vector3.ZERO, 3.0)
	var p := _base_params()
	p.merge({"radius": 0.45, "height": 1.7, "glow": glow, "attack": "slash2"}, true)
	return k.finish(p)
