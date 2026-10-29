extends Control
## Delve minimap (top right while exploring): the floor you have seen round the hero, foes that are awake, wells and
## chests, and the lair, which is always marked (on the rim, pointing the way, when it is out of view). North is up.

const SPAN := 44            # cells across
const REDRAW := 0.2

var run: Run
var _t := 0.0


func setup(r: Run) -> void:
	run = r
	custom_minimum_size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = REDRAW
		queue_redraw()


func _draw() -> void:
	if run == null or run.delve == null or not run.delve.active:
		return
	var dv: Delve = run.delve
	var sz := size
	var px := sz.x / SPAN
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.02, 0.02, 0.72))
	var hc := Delve.cell_of(run.hero.pos)
	var o := hc - Vector2i(SPAN / 2, SPAN / 2)
	var floor_c := Color(0.55, 0.45, 0.33, 0.85)
	var lair_c := Color(0.75, 0.3, 0.22, 0.9)
	for j in SPAN:
		var cy := o.y + j
		var run_start := -1
		var run_lair := false
		for i in SPAN + 1:
			var cx := o.x + i
			var ok := i < SPAN and Delve.in_grid(Vector2i(cx, cy)) and dv.seen[cy * Delve.W + cx] == 1 and dv.solid[cy * Delve.W + cx] == 0
			var il := ok and dv.lair.has_point(Vector2i(cx, cy))
			# draw horizontal runs of floor in one rect (far fewer draw calls)
			if run_start >= 0 and (not ok or il != run_lair):
				draw_rect(Rect2(Vector2(run_start * px, j * px), Vector2((i - run_start) * px + 0.5, px + 0.5)), lair_c if run_lair else floor_c)
				run_start = -1
			if ok and run_start < 0:
				run_start = i
				run_lair = il
	var to_px := func(p: Vector3) -> Vector2:
		return (Vector2(p.x - Delve.ORIGIN.x, p.z - Delve.ORIGIN.z) / Delve.CELL - Vector2(o)) * px
	for wl in dv.wells:
		var c := Delve.cell_of(wl["pos"])
		if dv.seen[c.y * Delve.W + c.x] == 1:
			draw_circle(to_px.call(wl["pos"]), 4.0, Color(0.3, 0.7, 1.0) if not wl["used"] else Color(0.3, 0.35, 0.45))
	for ch in dv.chests:
		var c := Delve.cell_of(ch["pos"])
		if dv.seen[c.y * Delve.W + c.x] == 1 and not ch["opened"]:
			var q: Vector2 = to_px.call(ch["pos"])
			draw_rect(Rect2(q - Vector2(4, 3), Vector2(8, 6)), Color(1.0, 0.8, 0.3))
	for e in run.enemies:
		if not e.alive or e.untargetable:
			continue
		var q: Vector2 = to_px.call(e.pos)
		if q.x < 0 or q.y < 0 or q.x > sz.x or q.y > sz.y:
			continue
		if e.dormant:
			var c := Delve.cell_of(e.pos)
			if Delve.in_grid(c) and dv.seen[c.y * Delve.W + c.x] == 1:
				draw_circle(q, 2.2, Color(0.7, 0.35, 0.3, 0.8))
		else:
			draw_circle(q, 3.0 if not e.is_boss else 5.0, Color(1.0, 0.25, 0.2))
	# the lair: on the map, or on the rim pointing at it
	var lp: Vector2 = to_px.call(dv.lair_pos)
	var mid := sz * 0.5
	var inside := Rect2(Vector2(8, 8), sz - Vector2(16, 16)).has_point(lp)
	if not inside:
		var d := lp - mid
		var k := minf((mid.x - 10) / maxf(absf(d.x), 0.01), (mid.y - 10) / maxf(absf(d.y), 0.01))
		lp = mid + d * k
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 220.0)
	draw_circle(lp, 7.0, Color(0.1, 0.02, 0.02, 0.9))
	draw_circle(lp, 5.0, Color(1.0, 0.35, 0.15) * pulse)
	if not inside:
		var dir := (lp - mid).normalized()
		var tip := lp + dir * 9.0
		var side := Vector2(-dir.y, dir.x) * 5.0
		draw_colored_polygon(PackedVector2Array([tip, lp + side, lp - side]), Color(1.0, 0.55, 0.2))
	# the hero
	draw_circle(mid, 4.5, Color(0, 0, 0))
	draw_circle(mid, 3.5, Color(1.0, 0.85, 0.35))
	draw_rect(Rect2(Vector2.ZERO, sz), UIK.col("frame", Color(0.54, 0.42, 0.23)), false, 2.0)
