extends RefCounted
## Accumulates transformed primitives into one ArrayMesh (one draw call per layer).
## Vertex format used by Emberpit shaders:
##   COLOR.rgb = albedo, COLOR.a = 1
##   UV.x = emission factor (0 = none), UV.y = aux (units: ambient-occlusion factor; world: brick mask)
##   UV2 = rest-space coords for painterly noise (units) or brick coords (world)
## Optional rigid skinning: every primitive is bound to one bone (cur_bone).

static var _prim_cache := {}

class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()

## Segment multiplier for round primitives (lower = fewer triangles). New kits copy default_detail.
static var default_detail := 1.0
var detail := 1.0

var surfs := {}
var use_bones := false
var cur_bone := 0
var cur_layer := 0
var cur_emis := 0.0
var cur_aux := 1.0
## When set (world meshes), UV2 = custom value instead of rest coords.
var uv2_override := false
var uv2_value := Vector2.ZERO

static func T(pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scl)
	return Transform3D(b, pos)

static func align_y(a: Vector3, b: Vector3) -> Basis:
	var d := (b - a)
	if d.length() < 0.0001:
		return Basis()
	d = d.normalized()
	if d.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, d))

func _surf(layer: int) -> Surf:
	if not surfs.has(layer):
		surfs[layer] = Surf.new()
	return surfs[layer]

func tri_count() -> int:
	var t := 0
	for k in surfs:
		t += (surfs[k] as Surf).idx.size() / 3
	return t

## Append raw mesh arrays transformed by xf.
func add(arr: Array, xf: Transform3D, col: Color, emis := -1.0) -> void:
	var s := _surf(cur_layer)
	var e := cur_emis if emis < 0.0 else emis
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ind = arr[Mesh.ARRAY_INDEX]
	var base := s.v.size()
	var nb := xf.basis.inverse().transposed()
	var flip := xf.basis.determinant() < 0.0
	for i in verts.size():
		var p: Vector3 = xf * verts[i]
		s.v.append(p)
		s.n.append((nb * norms[i]).normalized())
		s.c.append(col)
		s.uv.append(Vector2(e, cur_aux))
		if uv2_override:
			s.uv2.append(uv2_value)
		else:
			s.uv2.append(Vector2(p.x + p.z * 0.73, p.y))
		if use_bones:
			s.bones.append(cur_bone); s.bones.append(0); s.bones.append(0); s.bones.append(0)
			s.weights.append(1.0); s.weights.append(0.0); s.weights.append(0.0); s.weights.append(0.0)
	if ind == null or (ind as PackedInt32Array).size() == 0:
		for i in range(0, verts.size(), 3):
			if flip:
				s.idx.append(base + i); s.idx.append(base + i + 2); s.idx.append(base + i + 1)
			else:
				s.idx.append(base + i); s.idx.append(base + i + 1); s.idx.append(base + i + 2)
	else:
		var ia: PackedInt32Array = ind
		for i in range(0, ia.size(), 3):
			if flip:
				s.idx.append(base + ia[i]); s.idx.append(base + ia[i + 2]); s.idx.append(base + ia[i + 1])
			else:
				s.idx.append(base + ia[i]); s.idx.append(base + ia[i + 1]); s.idx.append(base + ia[i + 2])

## Append a single triangle with a flat normal, winding fixed to face `nrm`.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, nrm := Vector3.ZERO, uv2s := PackedVector2Array()) -> void:
	var s := _surf(cur_layer)
	var n := (b - a).cross(c - a)
	if nrm == Vector3.ZERO:
		nrm = -n.normalized()
	if n.dot(nrm) > 0.0:
		var t := b; b = c; c = t
		if uv2s.size() == 3:
			var u := uv2s[1]; uv2s[1] = uv2s[2]; uv2s[2] = u
	var base := s.v.size()
	var pts := [a, b, c]
	for i in 3:
		var p: Vector3 = pts[i]
		s.v.append(p); s.n.append(nrm.normalized()); s.c.append(col)
		s.uv.append(Vector2(cur_emis, cur_aux))
		if uv2s.size() == 3:
			s.uv2.append(uv2s[i])
		elif uv2_override:
			s.uv2.append(uv2_value)
		else:
			s.uv2.append(Vector2(p.x + p.z * 0.73, p.y))
		if use_bones:
			s.bones.append(cur_bone); s.bones.append(0); s.bones.append(0); s.bones.append(0)
			s.weights.append(1.0); s.weights.append(0.0); s.weights.append(0.0); s.weights.append(0.0)
		s.idx.append(base + i)

## Quad a-b-c-d (in order around the face) facing nrm.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, nrm: Vector3, uv2s := PackedVector2Array()) -> void:
	if uv2s.size() == 4:
		tri(a, b, c, col, nrm, PackedVector2Array([uv2s[0], uv2s[1], uv2s[2]]))
		tri(a, c, d, col, nrm, PackedVector2Array([uv2s[0], uv2s[2], uv2s[3]]))
	else:
		tri(a, b, c, col, nrm)
		tri(a, c, d, col, nrm)

# ---------------------------------------------------------------- primitives

static func _cached(key: String, maker: Callable) -> Array:
	if not _prim_cache.has(key):
		_prim_cache[key] = maker.call()
	return _prim_cache[key]

static func box_arrays() -> Array:
	return _cached("box", func():
		var m := BoxMesh.new(); m.size = Vector3.ONE
		return m.get_mesh_arrays())

static func sphere_arrays(seg := 10, rings := 6, hemi := false) -> Array:
	return _cached("sph%d_%d_%s" % [seg, rings, hemi], func():
		var m := SphereMesh.new(); m.radius = 1.0; m.height = 1.0 if hemi else 2.0
		m.radial_segments = seg; m.rings = rings; m.is_hemisphere = hemi
		return m.get_mesh_arrays())

static func cyl_arrays(top: float, bottom: float, seg := 8, caps := true) -> Array:
	return _cached("cyl%.3f_%.3f_%d_%s" % [top, bottom, seg, caps], func():
		var m := CylinderMesh.new(); m.top_radius = top; m.bottom_radius = bottom; m.height = 1.0
		m.radial_segments = seg; m.rings = 1; m.cap_top = caps; m.cap_bottom = caps
		return m.get_mesh_arrays())

static func capsule_arrays(r: float, h: float, seg := 8) -> Array:
	return _cached("cap%.3f_%.3f_%d" % [r, h, seg], func():
		var m := CapsuleMesh.new(); m.radius = r; m.height = maxf(h, r * 2.0 + 0.001)
		m.radial_segments = seg; m.rings = 2
		return m.get_mesh_arrays())

static func torus_arrays(inner: float, outer: float, rings := 12, ring_seg := 6) -> Array:
	return _cached("tor%.3f_%.3f_%d_%d" % [inner, outer, rings, ring_seg], func():
		var m := TorusMesh.new(); m.inner_radius = inner; m.outer_radius = outer
		m.rings = rings; m.ring_segments = ring_seg
		return m.get_mesh_arrays())

static func prism_arrays(skew := 0.5) -> Array:
	return _cached("pri%.2f" % skew, func():
		var m := PrismMesh.new(); m.size = Vector3.ONE; m.left_to_right = skew
		return m.get_mesh_arrays())

## Extruded 2D polygon (XY plane), thickness along Z, centered on z=0.
static func extrude_arrays(poly: PackedVector2Array, depth: float) -> Array:
	# make CCW
	var area := 0.0
	for i in poly.size():
		var a := poly[i]; var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	if area < 0.0:
		poly = poly.duplicate(); poly.reverse()
	var tris := Geometry2D.triangulate_polygon(poly)
	var v := PackedVector3Array(); var n := PackedVector3Array(); var idx := PackedInt32Array()
	var hz := depth * 0.5
	# Godot front faces are clockwise as seen by the viewer.
	for i in range(0, tris.size(), 3):
		var p0 := poly[tris[i]]; var p1 := poly[tris[i + 1]]; var p2 := poly[tris[i + 2]]
		if (p1 - p0).cross(p2 - p0) < 0.0:
			var tmp := p1; p1 = p2; p2 = tmp
		var b := v.size()
		v.append(Vector3(p0.x, p0.y, hz)); v.append(Vector3(p2.x, p2.y, hz)); v.append(Vector3(p1.x, p1.y, hz))
		for k in 3: n.append(Vector3(0, 0, 1))
		idx.append(b); idx.append(b + 1); idx.append(b + 2)
		b = v.size()
		v.append(Vector3(p0.x, p0.y, -hz)); v.append(Vector3(p1.x, p1.y, -hz)); v.append(Vector3(p2.x, p2.y, -hz))
		for k in 3: n.append(Vector3(0, 0, -1))
		idx.append(b); idx.append(b + 1); idx.append(b + 2)
	for i in poly.size():
		var a := poly[i]; var c := poly[(i + 1) % poly.size()]
		var e := (c - a)
		var out := Vector3(e.y, -e.x, 0).normalized()
		var b := v.size()
		var A := Vector3(a.x, a.y, hz); var B := Vector3(c.x, c.y, hz)
		var C := Vector3(c.x, c.y, -hz); var D := Vector3(a.x, a.y, -hz)
		v.append(A); v.append(B); v.append(C); v.append(D)
		for k in 4: n.append(out)
		# check winding vs outward normal (clockwise when seen from outside)
		if (B - A).cross(C - A).dot(out) > 0.0:
			idx.append(b); idx.append(b + 2); idx.append(b + 1)
			idx.append(b); idx.append(b + 3); idx.append(b + 2)
		else:
			idx.append(b); idx.append(b + 1); idx.append(b + 2)
			idx.append(b); idx.append(b + 2); idx.append(b + 3)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_INDEX] = idx
	return arr

# ---------------------------------------------------------------- convenience

func _init() -> void:
	detail = default_detail

func _s(n: int, mn: int) -> int:
	return maxi(mn, int(round(n * detail)))

func box(size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO, emis := -1.0) -> void:
	add(box_arrays(), T(pos, rot, size), col, emis)

func ball(r: float, pos: Vector3, col: Color, scl := Vector3.ONE, rot := Vector3.ZERO, emis := -1.0, seg := 10, rings := 6) -> void:
	add(sphere_arrays(_s(seg, 6), _s(rings, 4)), T(pos, rot, scl * r), col, emis)

func hemi(r: float, pos: Vector3, col: Color, scl := Vector3.ONE, rot := Vector3.ZERO, emis := -1.0, seg := 10, rings := 4) -> void:
	add(sphere_arrays(_s(seg, 6), _s(rings, 2), true), T(pos, rot, scl * r), col, emis)

func cyl(top: float, bottom: float, h: float, pos: Vector3, col: Color, rot := Vector3.ZERO, emis := -1.0, seg := 8, caps := true) -> void:
	add(cyl_arrays(top, bottom, _s(seg, 5), caps), T(pos, rot, Vector3(1, h, 1)), col, emis)

func cone(r: float, h: float, pos: Vector3, col: Color, rot := Vector3.ZERO, emis := -1.0, seg := 6) -> void:
	add(cyl_arrays(0.0, r, _s(seg, 4), true), T(pos, rot, Vector3(1, h, 1)), col, emis)

## Cone from base point a to tip b.
func spike(a: Vector3, b: Vector3, r: float, col: Color, emis := -1.0, seg := 6) -> void:
	var bas := align_y(a, b)
	var h := a.distance_to(b)
	add(cyl_arrays(0.0, r, _s(seg, 4), true), Transform3D(bas * Basis.from_scale(Vector3(1, h, 1)), (a + b) * 0.5), col, emis)

## Capsule between a and b.
func limb(a: Vector3, b: Vector3, r: float, col: Color, emis := -1.0, seg := 8) -> void:
	var h := a.distance_to(b) + r * 2.0
	var arr := capsule_arrays(r, snappedf(h, 0.01), _s(seg, 5))
	add(arr, Transform3D(align_y(a, b), (a + b) * 0.5), col, emis)

## Tapered cylinder between a and b.
func tube(a: Vector3, b: Vector3, ra: float, rb: float, col: Color, emis := -1.0, seg := 8) -> void:
	var h := a.distance_to(b)
	add(cyl_arrays(snappedf(rb, 0.005), snappedf(ra, 0.005), _s(seg, 5), true), Transform3D(align_y(a, b) * Basis.from_scale(Vector3(1, h, 1)), (a + b) * 0.5), col, emis)

func torus(inner: float, outer: float, pos: Vector3, col: Color, rot := Vector3.ZERO, emis := -1.0, rings := 12, rseg := 6, scl := Vector3.ONE) -> void:
	add(torus_arrays(inner, outer, _s(rings, 6), _s(rseg, 4)), T(pos, rot, scl), col, emis)

func prism(size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO, emis := -1.0, skew := 0.5) -> void:
	add(prism_arrays(skew), T(pos, rot, size), col, emis)

func extrude(poly: PackedVector2Array, depth: float, pos: Vector3, col: Color, rot := Vector3.ZERO, scl := Vector3.ONE, emis := -1.0) -> void:
	add(extrude_arrays(poly, depth), T(pos, rot, scl), col, emis)

# ---------------------------------------------------------------- output

func build(layer_order := []) -> ArrayMesh:
	var m := ArrayMesh.new()
	var keys := surfs.keys()
	keys.sort()
	if not layer_order.is_empty():
		keys = layer_order.filter(func(k): return surfs.has(k))
	for k in keys:
		var s: Surf = surfs[k]
		if s.idx.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s.v
		arr[Mesh.ARRAY_NORMAL] = s.n
		arr[Mesh.ARRAY_COLOR] = s.c
		arr[Mesh.ARRAY_TEX_UV] = s.uv
		arr[Mesh.ARRAY_TEX_UV2] = s.uv2
		arr[Mesh.ARRAY_INDEX] = s.idx
		if use_bones:
			arr[Mesh.ARRAY_BONES] = s.bones
			arr[Mesh.ARRAY_WEIGHTS] = s.weights
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func layers() -> Array:
	var keys := surfs.keys()
	keys.sort()
	return keys
