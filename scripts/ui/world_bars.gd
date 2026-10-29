extends Control
## Draws small health bars above units (projected from 3D) in one pass.

var run: Run


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _bar(cam: Camera3D, u: Unit, w: float, col: Color, extra_y := 0.3, h := 7.0, alpha := 1.0) -> void:
	var wp := u.pos + Vector3(0, u.height + extra_y, 0)
	if cam.is_position_behind(wp):
		return
	var sp := cam.unproject_position(wp)
	var r := Rect2(sp - Vector2(w * 0.5, h), Vector2(w, h))
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.6 * alpha))
	var c := col
	c.a *= alpha
	draw_rect(Rect2(r.position, Vector2(w * clampf(u.hp / maxf(1.0, u.max_hp), 0.0, 1.0), h)), c)


## Small diamond (immune) or dot (double damage) marker over a buffed enemy.
func _pip(sp: Vector2, c: Color, diamond: bool) -> void:
	if diamond:
		var pts := PackedVector2Array([sp + Vector2(0, -8), sp + Vector2(7, 0), sp + Vector2(0, 8), sp + Vector2(-7, 0)])
		draw_primitive(pts, PackedColorArray([Color(0, 0, 0, 0.7)]), PackedVector2Array())
		var inner := PackedVector2Array([sp + Vector2(0, -6), sp + Vector2(5, 0), sp + Vector2(0, 6), sp + Vector2(-5, 0)])
		draw_primitive(inner, PackedColorArray([c]), PackedVector2Array())
	else:
		draw_circle(sp, 7.0, Color(0, 0, 0, 0.7))
		draw_circle(sp, 5.0, c)


func _draw() -> void:
	if run == null or run.camera == null:
		return
	var cam := run.camera
	var hpc := UIK.col("hp", Color(0.85, 0.23, 0.23))
	var now := run.run_time
	var focus: Unit = run.hero.focus
	for e in run.enemies:
		if not e.alive or e.untargetable:
			continue
		if not (e is Enemy):
			# the duel rival: a full-size red bar, ringed when focused
			_bar(cam, e, 80.0, hpc, 0.4, 7.0, 1.0)
			if e == focus:
				SkillButton.ring(self, cam.unproject_position(e.pos), 30.0 + e.radius * 8.0, UIK.col("gold", Color.GOLD))
			continue
		var elite: bool = e.is_boss or e.captain or e.elite != "" or float(DB.ENEMIES.get(e.kind, {}).get("hp", 0.0)) >= 200.0
		var recent: bool = now - e.hurt_at < 3.0 and e.hp < e.max_hp - 0.5
		if e == focus:
			_bar(cam, e, 52.0 if not e.is_boss else 110.0, hpc, 0.3, 6.0, 1.0)
			var sp := cam.unproject_position(e.pos)
			SkillButton.ring(self, sp, 30.0 + e.radius * 8.0, UIK.col("gold", Color.GOLD))
		elif e.is_boss:
			_bar(cam, e, 110.0, hpc, 0.3, 6.0, 0.85)
		elif e.captain:
			_bar(cam, e, 72.0, UIK.col("gold", Color.GOLD), 0.4, 6.0, 0.95)
		elif e.elite != "":
			# elites always show a bar in their affix colour
			var tc: Color = DB.ELITE_AFFIXES[e.elite]["tint"]
			_bar(cam, e, 44.0, Color(minf(tc.r, 1.0), minf(tc.g, 1.0), minf(tc.b, 1.0)), 0.3, 5.0, 0.95)
		elif recent or (elite and e.hp < e.max_hp - 0.5):
			_bar(cam, e, 40.0 if elite else 30.0, hpc, 0.3, 4.0, 0.72)
	# buffed foes: a gold pip over the ones a Chanter makes immune, a red one over Drummer-boosted ones
	if not run.chanters.is_empty() or not run.drummers.is_empty():
		var gold: Color = DB.AURAS["chanter"]["color"]
		var red: Color = DB.AURAS["drummer"]["color"]
		for e in run.enemies:
			if not e.alive or e.untargetable or not (e is Enemy) or e.support:
				continue
			var sh: bool = run.is_sheltered(e)
			var dr: bool = run.is_drummed(e)
			if not sh and not dr:
				continue
			var wp: Vector3 = e.pos + Vector3(0, e.height + 0.75, 0)
			if cam.is_position_behind(wp):
				continue
			var sp: Vector2 = cam.unproject_position(wp)
			if sh:
				_pip(sp + Vector2(-6 if dr else 0, 0), gold, true)
			if dr:
				_pip(sp + Vector2(6 if sh else 0, 0), red, false)
		for b in run.chanters + run.drummers:
			if b.alive and b != focus:
				_bar(cam, b, 44.0, DB.AURAS[b.kind]["color"], 0.3, 5.0, 0.95)
	# barrels: the focused one gets the gold ring, damaged ones a small wood-coloured bar
	if run.barrels and run.in_arena():
		for b in run.barrels.all:
			if not b.alive:
				continue
			if b == focus:
				SkillButton.ring(self, cam.unproject_position(b.pos), 34.0, UIK.col("gold", Color.GOLD))
			if b.hp < b.max_hp - 0.01:
				_bar(cam, b, 30.0, Color(0.85, 0.6, 0.3), 0.2, 4.0, 0.85)
	for a in run.allies:
		if a is Hero:
			# AI ally heroes always show a bar, in a bluer green than the player's
			if a.alive and not a.dead:
				_bar(cam, a, 54.0, Color(0.3, 0.85, 0.75), 0.45, 5.0, 0.95)
		elif a.alive and a.hp < a.max_hp - 0.5:
			_bar(cam, a, 30.0, Color(0.4, 0.9, 0.35), 0.3, 4.0, 0.8)
	var h := run.hero
	if h.alive and not h.dead:
		# purple while hexed (healing halved)
		_bar(cam, h, 70.0, Color(0.7, 0.4, 1.0) if h.hex_t > 0.0 else Color(0.35, 0.95, 0.35), 0.5)
		var wp := h.pos + Vector3(0, h.height + 0.5, 0)
		if not cam.is_position_behind(wp):
			var sp2 := cam.unproject_position(wp)
			var r := Rect2(sp2 - Vector2(35, -2), Vector2(70, 4))
			draw_rect(r.grow(1.0), Color(0, 0, 0, 0.75))
			draw_rect(Rect2(r.position, Vector2(70 * clampf(h.mana / maxf(1.0, h.max_mana), 0, 1), 4)), UIK.col("mana", Color(0.25, 0.5, 0.9)))
			if h.shield > 0.0:
				var sr := Rect2(sp2 - Vector2(35, 13), Vector2(70 * clampf(h.shield / maxf(1.0, h.max_hp), 0, 1), 3))
				draw_rect(sr, Color(0.9, 0.85, 0.5))
