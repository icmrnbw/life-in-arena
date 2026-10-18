extends Control
## Multi-touch controls: floating joystick (left), skill buttons in an arc (right), active-item buttons.
## Tap a skill = smart cast; drag out of a skill = aim (release to cast, drag back onto the button to cancel).
## Press and hold a skill (without dragging) = show its description; releasing then doesn't cast.
## Keyboard/mouse fallback: arrows move (or hold right mouse), Q/W/E/R cast, Ctrl+Q/W/E/R rank up, 1-6 items.

const JOY_R := 95.0
const KNOB_R := 44.0
const SKILL_D := 112.0
const ULT_D := 128.0
const ITEM_D := 100.0
const BADGE_HIT := 42.0
const AIM_PIXELS := 190.0
const HOLD_MS := 450

var run: Run
var hud: Node
var skill_buttons: Array = []
var item_buttons: Array = []     # Controls for active items (index -> inventory index)
var item_map: Array = [-1, -1]
var blockers: Array = []         # Controls whose rects must not start a joystick
var enabled := true

var joy_finger := -1
var joy_center := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_home := Vector2.ZERO
var joy_shift := Vector2.ZERO   # base clamped away from the screen edge: finger offset so a still thumb doesn't walk
var skill_touch := {}            # finger -> {slot, start, left, aim_fx, last_aim}
var tap_touch := {}              # finger -> {start, t}
var _keys_move := Vector2.ZERO
var _rmb := false
var tip: PanelContainer = null


func setup(r: Run, h: Node) -> void:
	run = r
	hud = h
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var keys := ["Q", "W", "E", "R"]
	for i in 4:
		var sb := SkillButton.new()
		var sid: String = run.hero.skill_ids[i]
		sb.setup(i, keys[i], UIK.icon(sid), ULT_D if i == 3 else SKILL_D)
		sb.max_rank = run.hero.max_rank(i)
		add_child(sb)
		skill_buttons.append(sb)
	for i in 2:
		var ib := _make_item_button()
		add_child(ib)
		item_buttons.append(ib)
	resized.connect(_layout)
	_layout()


## Active-item button: an empty Control for layout / hit-testing; drawn in _draw() so all of them batch.
func _make_item_button() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(ITEM_D, ITEM_D)
	c.size = Vector2(ITEM_D, ITEM_D)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	c.set_meta("tex", null)
	c.set_meta("count", "")
	c.set_meta("frac", 0.0)
	return c


func _layout() -> void:
	var vs := get_viewport_rect().size
	var m := UIK.safe_margins(get_viewport())
	var cx := vs.x - m.z - 28.0 - ULT_D * 0.5
	var cy := vs.y - m.w - 24.0 - ULT_D * 0.5
	var rad := 168.0
	var angs := [180.0, 226.0, 272.0]
	for i in 3:
		var a := deg_to_rad(angs[i])
		var p := Vector2(cx + cos(a) * rad, cy + sin(a) * rad)
		skill_buttons[i].position = p - Vector2(SKILL_D, SKILL_D) * 0.5
	skill_buttons[3].position = Vector2(cx, cy) - Vector2(ULT_D, ULT_D) * 0.5
	var iangs := [194.0, 256.0]
	for i in 2:
		var a2 := deg_to_rad(iangs[i])
		var p2 := Vector2(cx + cos(a2) * 292.0, cy + sin(a2) * 292.0)
		item_buttons[i].position = p2 - Vector2(ITEM_D, ITEM_D) * 0.5
	joy_home = Vector2(m.x + 40.0 + JOY_R + 40.0, vs.y - m.w - 40.0 - JOY_R - 20.0)
	queue_redraw()


func _process(_delta: float) -> void:
	if run == null:
		return
	var h := run.hero
	for i in 4:
		var sb: SkillButton = skill_buttons[i]
		var kit := h.kit
		sb.learned = h.ranks[i] > 0
		sb.rank = h.ranks[i]
		var was_ready := sb.is_ready
		sb.cd_frac = kit.cd_frac(i) if sb.learned else 0.0
		sb.cd_left = kit.cd_left(i) if sb.learned else 0.0
		sb.is_ready = sb.learned and (kit.is_ready(i) or kit.free_cast(i))
		if sb.is_ready and not was_ready:
			sb.flash_ready()
		sb.no_mana = sb.learned and not kit.free_cast(i) and h.mana < h.skill_mana(i)
		sb.can_rank = h.can_rank_up(i)
		sb.charges = kit.charges(i)
		sb.label_text = kit.skill_label(i)
	# active items
	var actives := []
	for idx in h.items.size():
		if DB.ITEMS.get(h.items[idx]["id"], {}).has("active"):
			actives.append(idx)
	for i in 2:
		var ib: Control = item_buttons[i]
		if i < actives.size():
			var idx: int = actives[i]
			item_map[i] = idx
			var it: Dictionary = h.items[idx]
			ib.visible = true
			ib.set_meta("tex", UIK.icon(it["id"]))
			var ch := int(it.get("charges", 1))
			ib.set_meta("count", ("x%d" % ch) if DB.ITEMS[it["id"]].get("kind") == "consumable" else "")
			var d: Dictionary = DB.ITEMS[it["id"]]
			ib.set_meta("frac", clampf(float(it.get("cd", 0.0)) / maxf(0.1, float(d.get("active_cd", 1.0))), 0.0, 1.0))
		else:
			item_map[i] = -1
			ib.visible = false
	# a still finger on an enemy (left side) that is held becomes the joystick
	if joy_finger < 0:
		for f in tap_touch.keys():
			var tt: Dictionary = tap_touch[f]
			if tt.get("joy", false) and Time.get_ticks_msec() - int(tt["t"]) > 300:
				tap_touch.erase(f)
				_start_joy(f, tt["start"])
				break
	# keyboard / mouse movement
	if not Game.autoplay and enabled:
		var mv := Vector2.ZERO
		if joy_finger >= 0:
			mv = (joy_pos - joy_center) / JOY_R
			if mv.length() > 1.0:
				mv = mv.normalized()
		else:
			mv = _keys_move
			if _rmb:
				var gp := run.screen_to_ground(get_viewport().get_mouse_position())
				var d2 := Vector2(gp.x - h.pos.x, gp.z - h.pos.z)
				mv = d2.normalized() if d2.length() > 0.6 else Vector2.ZERO
		h.move_input = mv
	elif not enabled and not Game.autoplay:
		h.move_input = Vector2.ZERO
	# keep aim indicators following the hero; a finger held still on a skill shows its description
	for f in skill_touch:
		var st: Dictionary = skill_touch[f]
		if not st["left"] and not st["tip"] and Time.get_ticks_msec() - int(st["t"]) > HOLD_MS:
			st["tip"] = true
			_show_tip(st["slot"])
		if st.get("left", false):
			_update_aim(st, st["last_pos"])
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var frame := UIK.col("frame", Color(0.54, 0.42, 0.23))
	var ember := UIK.col("ember", Color(1, 0.48, 0.18))
	# skill buttons: painted layer by layer across all four so each layer is one batch
	for phase in 6:
		for sb in skill_buttons:
			sb.paint(self, phase)
	# batched: discs / rings are rects sharing one texture (see SkillButton)
	var items_vis := []
	for ib in item_buttons:
		if ib.visible:
			items_vis.append(ib)
	var ir := ITEM_D * 0.5
	for ib in items_vis:
		var ic: Vector2 = ib.position + ib.size * 0.5
		SkillButton.disc(self, ic, ir, Color(0, 0, 0, 0.5))
		SkillButton.disc(self, ic, ir - 3.0, UIK.col("panel", Color(0.11, 0.09, 0.07)))
		SkillButton.ring(self, ic, ir - 1.0, frame.lightened(0.15))
	for ib in items_vis:
		var ic2: Vector2 = ib.position + ib.size * 0.5
		var tex = ib.get_meta("tex")
		if tex is Texture2D:
			draw_texture_rect(tex, Rect2(ic2 - Vector2(ir - 14.0, ir - 14.0), Vector2(ir - 14.0, ir - 14.0) * 2.0), false)
	var font := get_theme_default_font()
	for ib in items_vis:
		var frac: float = ib.get_meta("frac")
		if frac > 0.0:
			var ic3: Vector2 = ib.position + ib.size * 0.5
			var hh := (ITEM_D - 24.0) * frac
			SkillButton.solid(self, Rect2(ic3 + Vector2(-ir + 12.0, ir - 12.0 - hh), Vector2(ITEM_D - 24.0, hh)), Color(0, 0, 0, 0.6))
	for ib in items_vis:
		var cs: String = ib.get_meta("count")
		if cs != "":
			draw_string_outline(font, ib.position + Vector2(ITEM_D - 36, ITEM_D - 12), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0))
	for ib in items_vis:
		var cs2: String = ib.get_meta("count")
		if cs2 != "":
			draw_string(font, ib.position + Vector2(ITEM_D - 36, ITEM_D - 12), cs2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))
	if joy_finger >= 0:
		SkillButton.disc(self, joy_center, JOY_R, Color(0, 0, 0, 0.28))
		SkillButton.ring(self, joy_center, JOY_R + 2.0, frame.lightened(0.2))
		var kp := joy_center + (joy_pos - joy_center).limit_length(JOY_R)
		SkillButton.disc(self, kp, KNOB_R, Color(ember.r, ember.g, ember.b, 0.75))
		SkillButton.ring(self, kp, KNOB_R + 1.0, Color(1, 0.9, 0.7, 0.9))
	elif enabled and not Game.autoplay:
		SkillButton.disc(self, joy_home, JOY_R, Color(0, 0, 0, 0.26))
		SkillButton.ring(self, joy_home, JOY_R + 3.0, Color(0, 0, 0, 0.4))
		SkillButton.ring(self, joy_home, JOY_R, Color(1.0, 0.86, 0.6, 0.55))
		SkillButton.disc(self, joy_home, KNOB_R * 0.8, Color(0, 0, 0, 0.25))
		SkillButton.ring(self, joy_home, KNOB_R * 0.8, Color(1.0, 0.86, 0.6, 0.45))


# ------------------------------------------------------------------ input
func _blocked(p: Vector2) -> bool:
	for b in blockers:
		if b is Control and is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_rect().has_point(p):
			return true
	return false


func _skill_at(p: Vector2) -> int:
	# a firm press on a button's face always means the skill, never a neighbour's badge
	for i in 4:
		var sb0: SkillButton = skill_buttons[i]
		if p.distance_to(sb0.center()) <= sb0.radius() * 0.75:
			return i
	var best := -1
	var bd := BADGE_HIT
	for i in 4:
		var sb: SkillButton = skill_buttons[i]
		if sb.can_rank:
			var d := p.distance_to(sb.badge_center())
			if d <= bd:
				bd = d
				best = 10 + i   # badge
	if best >= 0:
		return best
	for i in 4:
		var sb2: SkillButton = skill_buttons[i]
		if p.distance_to(sb2.center()) <= sb2.radius() * 1.08:
			return i
	return -1


func _item_at(p: Vector2) -> int:
	for i in 2:
		var ib: Control = item_buttons[i]
		if ib.visible and ib.get_global_rect().grow(6).has_point(p):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if run == null:
		return
	if event is InputEventKey:
		_key(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_rmb = event.pressed and enabled
		return
	if not enabled or Game.autoplay:
		if event is InputEventScreenTouch and not event.pressed:
			_release_all()
		return
	if event is InputEventScreenTouch:
		if event.canceled:
			# the OS took the touch away (gesture, notification shade...): drop everything, cast nothing
			_release_all()
			return
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position)


func _touch_down(f: int, p: Vector2) -> void:
	var s := _skill_at(p)
	if s >= 10:
		run.rank_up(s - 10)
		get_viewport().set_input_as_handled()
		return
	if s >= 0:
		var h := run.hero
		if h.ranks[s] == 0 and h.can_rank_up(s):
			run.rank_up(s)
			get_viewport().set_input_as_handled()
			return
		skill_touch[f] = {"slot": s, "start": p, "left": false, "aim_fx": null, "last_pos": p, "aim": {}, "t": Time.get_ticks_msec(), "tip": false}
		skill_buttons[s].pressed = true
		skill_buttons[s].cancel = false
		get_viewport().set_input_as_handled()
		return
	var it := _item_at(p)
	if it >= 0:
		if item_map[it] >= 0:
			run.use_item(item_map[it])
		get_viewport().set_input_as_handled()
		return
	if _blocked(p):
		return
	var vs := get_viewport_rect().size
	if p.x < vs.x * 0.45 and joy_finger < 0:
		if _enemy_under(p) != null:
			# might be a quick tap to focus that enemy: decide on movement / hold time
			tap_touch[f] = {"start": p, "t": Time.get_ticks_msec(), "joy": true}
			get_viewport().set_input_as_handled()
			return
		_start_joy(f, p)
		get_viewport().set_input_as_handled()
		return
	tap_touch[f] = {"start": p, "t": Time.get_ticks_msec()}


func _start_joy(f: int, p: Vector2) -> void:
	var vs := get_viewport_rect().size
	var m := UIK.safe_margins(get_viewport())
	joy_finger = f
	joy_center = Vector2(clampf(p.x, m.x + JOY_R + 8.0, vs.x * 0.45), clampf(p.y, m.y + JOY_R + 90.0, vs.y - m.w - JOY_R - 8.0))
	joy_shift = joy_center - p
	joy_pos = joy_center


## Enemy whose on-screen body is under the finger (screen-space, generous for thumbs).
func _enemy_under(p: Vector2) -> Unit:
	if run == null or run.camera == null:
		return null
	var best: Unit = null
	var bd := 70.0
	for e in run.enemies:
		if not e.alive or e.untargetable:
			continue
		if run.camera.is_position_behind(e.pos):
			continue
		var sp := run.camera.unproject_position(e.pos + Vector3(0, e.height * 0.45, 0))
		var d := sp.distance_to(p)
		if d < bd:
			bd = d
			best = e
	return best


func _touch_drag(f: int, p: Vector2) -> void:
	if tap_touch.has(f) and tap_touch[f].get("joy", false) and joy_finger < 0:
		var tt: Dictionary = tap_touch[f]
		if p.distance_to(tt["start"]) > 22.0:
			tap_touch.erase(f)
			_start_joy(f, tt["start"])
	if f == joy_finger:
		joy_pos = p + joy_shift
		# drag the base along when the thumb goes far (floating stick)
		var off := joy_pos - joy_center
		if off.length() > JOY_R * 1.4:
			joy_center = joy_pos - off.normalized() * JOY_R * 1.4
		get_viewport().set_input_as_handled()
		return
	if skill_touch.has(f):
		var st: Dictionary = skill_touch[f]
		var sb: SkillButton = skill_buttons[st["slot"]]
		st["last_pos"] = p
		var inside := p.distance_to(sb.center()) <= sb.radius() * 1.05
		if not inside:
			if st["tip"]:
				st["tip"] = false
				_hide_tip()
			st["left"] = true
			sb.cancel = false
			_update_aim(st, p)
		elif st["left"]:
			sb.cancel = true
			_stop_aim(st)
		get_viewport().set_input_as_handled()


func _touch_up(f: int, p: Vector2) -> void:
	if f == joy_finger:
		joy_finger = -1
		if run and run.hero:
			run.hero.move_input = Vector2.ZERO
		get_viewport().set_input_as_handled()
		return
	if skill_touch.has(f):
		var st: Dictionary = skill_touch[f]
		var slot: int = st["slot"]
		var sb: SkillButton = skill_buttons[slot]
		var inside := p.distance_to(sb.center()) <= sb.radius() * 1.05
		_stop_aim(st)
		sb.pressed = false
		sb.cancel = false
		skill_touch.erase(f)
		if st["tip"]:
			_hide_tip()   # it was a hold to read the description, not a cast
		elif not st["left"]:
			run.try_cast(slot)
		elif not inside:
			var aim: Dictionary = _compute_aim(slot, p)
			run.try_cast(slot, aim)
		get_viewport().set_input_as_handled()
		return
	if tap_touch.has(f):
		var tt: Dictionary = tap_touch[f]
		tap_touch.erase(f)
		if p.distance_to(tt["start"]) < 24.0 and Time.get_ticks_msec() - int(tt["t"]) < 350:
			if tt.get("joy", false):
				var e := _enemy_under(p)
				if e:
					_set_focus(e)
			else:
				_focus_tap(p)


func _release_all() -> void:
	joy_finger = -1
	_keys_move = Vector2.ZERO
	_rmb = false
	if run and run.hero:
		run.hero.move_input = Vector2.ZERO
	for f in skill_touch:
		_stop_aim(skill_touch[f])
		skill_buttons[skill_touch[f]["slot"]].pressed = false
	skill_touch.clear()
	_hide_tip()
	tap_touch.clear()


func _focus_tap(p: Vector2) -> void:
	var gp := run.screen_to_ground(p)
	var best: Unit = null
	var bd := 2.6
	for e in run.enemies:
		if not e.alive or e.untargetable:
			continue
		var d: float = Vector2(e.pos.x - gp.x, e.pos.z - gp.z).length() - e.radius
		if d < bd:
			bd = d
			best = e
	if best == null:
		best = _enemy_under(p)
	if best == null and run.barrels and run.in_arena():
		best = run.barrels.barrel_near(gp, 1.0)
	if best:
		_set_focus(best)


func _set_focus(e: Unit) -> void:
	run.hero.focus = e
	run.fx("hit", {"pos": e.pos + Vector3(0, 0.2, 0), "color": UIK.col("gold", Color.GOLD)})


func _compute_aim(slot: int, p: Vector2) -> Dictionary:
	var h := run.hero
	var sb: SkillButton = skill_buttons[slot]
	var v := p - sb.center()
	var spec: Dictionary = h.kit.aim_spec(slot)
	var rng: float = float(spec.get("range", 6.0))
	var dir := Vector3(v.x, 0, v.y)
	if dir.length() < 0.01:
		dir = h.facing
	dir = dir.normalized()
	var frac := clampf((v.length() - sb.radius()) / AIM_PIXELS, 0.0, 1.0)
	var point := h.pos + dir * maxf(1.0, frac * rng)
	if spec.get("type", "none") == "line":
		point = h.pos + dir * rng
	return {"point": point, "dir": dir}


func _update_aim(st: Dictionary, p: Vector2) -> void:
	var slot: int = st["slot"]
	var h := run.hero
	var spec: Dictionary = h.kit.aim_spec(slot)
	var aim := _compute_aim(slot, p)
	st["aim"] = aim
	var t: String = spec.get("type", "none")
	var opts := {}
	var fx_name := "aim_circle"
	match t:
		"circle":
			opts = {"pos": aim["point"], "radius": float(spec.get("radius", 2.0))}
		"line":
			fx_name = "aim_line"
			opts = {"from": h.pos, "to": aim["point"], "width": float(spec.get("width", 1.2))}
		"wall":
			fx_name = "aim_line"
			var d: Vector3 = run._flat(aim["point"] - h.pos)
			if d.length() < 0.2:
				d = aim["dir"]
			d = d.normalized()
			var perp := Vector3(-d.z, 0, d.x)
			var half := float(spec.get("length", 6.0)) * 0.5
			opts = {"from": aim["point"] - perp * half, "to": aim["point"] + perp * half, "width": 0.9}
		_:
			var r := float(DB.SKILLS[h.skill_ids[slot]].get("range", 0.0))
			opts = {"pos": h.pos, "radius": maxf(2.0, r)}
	if st["aim_fx"] == null or not is_instance_valid(st["aim_fx"]) or st.get("aim_kind", "") != fx_name:
		_stop_aim(st)
		st["aim_fx"] = run.fx(fx_name, opts)
		st["aim_kind"] = fx_name
	else:
		run.fx_params(st["aim_fx"], opts)


func _stop_aim(st: Dictionary) -> void:
	if st.get("aim_fx") != null:
		run.fx_stop(st["aim_fx"])
	st["aim_fx"] = null


func _key(e: InputEventKey) -> void:
	var down := e.pressed
	match e.keycode:
		KEY_LEFT:
			_keys_move.x = -1.0 if down else (0.0 if _keys_move.x < 0 else _keys_move.x)
		KEY_RIGHT:
			_keys_move.x = 1.0 if down else (0.0 if _keys_move.x > 0 else _keys_move.x)
		KEY_UP:
			_keys_move.y = -1.0 if down else (0.0 if _keys_move.y < 0 else _keys_move.y)
		KEY_DOWN:
			_keys_move.y = 1.0 if down else (0.0 if _keys_move.y > 0 else _keys_move.y)
	if not down or e.echo or not enabled or Game.autoplay:
		return
	var skill_keys := {KEY_Q: 0, KEY_W: 1, KEY_E: 2, KEY_R: 3}
	if skill_keys.has(e.keycode):
		var s: int = skill_keys[e.keycode]
		if e.ctrl_pressed or e.shift_pressed:
			run.rank_up(s)
		elif run.hero.ranks[s] == 0 and run.hero.can_rank_up(s):
			run.rank_up(s)
		else:
			run.try_cast(s)
		return
	if e.keycode >= KEY_1 and e.keycode <= KEY_6:
		run.use_item(e.keycode - KEY_1)
		return
	if e.keycode == KEY_SPACE:
		run.skip_prep()
	elif e.keycode == KEY_B and hud and hud.has_method("toggle_shop"):
		hud.toggle_shop()


## Description card for a held skill button: name, rank, cost and what it does.
func _show_tip(slot: int) -> void:
	_hide_tip()
	var h := run.hero
	var sid: String = h.skill_ids[slot]
	var sd: Dictionary = DB.SKILLS[sid]
	var r: int = h.ranks[slot]
	var ri := clampi(r - 1, 0, 3)
	tip = UIK.panel()
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()   # solid: the HUD behind must not show through the text
	bg.bg_color = Color(0.09, 0.065, 0.045, 0.97)
	bg.border_color = UIK.col("gold", Color(0.85, 0.65, 0.3))
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(18)
	tip.add_theme_stylebox_override("panel", bg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(v)
	v.add_child(UIK.label(String(sd["name"]), "", 26, UIK.col("gold", Color.GOLD)))
	var bits := ["Rank %d/%d" % [r, h.max_rank(slot)] if r > 0 else "Not learned yet"]
	var mana: Array = sd.get("mana", [])
	if not mana.is_empty():
		bits.append("%d mana" % int(mana[mini(ri, mana.size() - 1)]))
	var cds: Array = sd.get("cd", [])
	if not cds.is_empty():
		bits.append("%ss cooldown" % String.num(float(cds[mini(ri, cds.size() - 1)]), 1).trim_suffix(".0"))
	v.add_child(UIK.label("  ·  ".join(bits), "SmallLabel", 18, UIK.col("dim", Color(0.75, 0.7, 0.62))))
	var d := UIK.label(String(sd.get("desc", "")), "", 20, UIK.col("text", Color(0.95, 0.92, 0.85)))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(440, 0)
	v.add_child(d)
	add_child(tip)
	tip.reset_size()
	# to the left of the button arc, level with the held button, kept on screen
	var sb: SkillButton = skill_buttons[slot]
	var vs := get_viewport_rect().size
	var p := Vector2(sb.center().x - sb.radius() - 24.0 - tip.size.x, sb.center().y - sb.radius() - tip.size.y - 12.0)
	if slot != 3:
		p.x = minf(p.x, skill_buttons[3].center().x - skill_buttons[3].radius() - 24.0 - tip.size.x)
	tip.position = Vector2(clampf(p.x, 16.0, vs.x - tip.size.x - 16.0), clampf(p.y, 16.0, vs.y - tip.size.y - 16.0))


func _hide_tip() -> void:
	if tip and is_instance_valid(tip):
		tip.queue_free()
	tip = null
