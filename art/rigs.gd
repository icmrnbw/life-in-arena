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
	"hexcaster": 0.85, "burrower": 0.7, "bloater": 0.5, "broodling": 0.5}

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
