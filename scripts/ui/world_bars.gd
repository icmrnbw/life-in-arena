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
		var elite: bool = e.is_boss or e.elite != "" or float(DB.ENEMIES.get(e.kind, {}).get("hp", 0.0)) >= 200.0
		var recent: bool = now - e.hurt_at < 3.0 and e.hp < e.max_hp - 0.5
		if e == focus:
			_bar(cam, e, 52.0 if not e.is_boss else 110.0, hpc, 0.3, 6.0, 1.0)
			var sp := cam.unproject_position(e.pos)
			SkillButton.ring(self, sp, 30.0 + e.radius * 8.0, UIK.col("gold", Color.GOLD))
		elif e.is_boss:
			_bar(cam, e, 110.0, hpc, 0.3, 6.0, 0.85)
		elif e.elite != "":
			# elites always show a bar in their affix colour
			var tc: Color = DB.ELITE_AFFIXES[e.elite]["tint"]
			_bar(cam, e, 44.0, Color(minf(tc.r, 1.0), minf(tc.g, 1.0), minf(tc.b, 1.0)), 0.3, 5.0, 0.95)
		elif recent or (elite and e.hp < e.max_hp - 0.5):
			_bar(cam, e, 40.0 if elite else 30.0, hpc, 0.3, 4.0, 0.72)
	for a in run.allies:
		if a.alive and a.hp < a.max_hp - 0.5:
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
