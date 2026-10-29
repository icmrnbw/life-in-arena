extends Node
## Training: a guided first run with the Ashwarden. A coach card on the left of the screen gives one instruction at a
## time and waits until the player has done it (walk to a marker, learn a skill, cast, shop, fight, dig into a barrel stack,
## dodge a captain's slam). The Run's own wave timer is off while this drives it, and the hero can't fall (cfg no_death).

signal finished

const STEPS := [
	{"id": "welcome", "title": "Welcome to the Pit",
		"text": "This is your camp. You are the Ashwarden, a hero who builds the battlefield with totems and walls. Tap Next to begin.", "button": "Next"},
	{"id": "move", "title": "Move",
		"text": "Put your left thumb anywhere on the left half of the screen and drag to walk. Walk onto the glowing marker."},
	{"id": "learn", "title": "Learn a skill",
		"text": "You have a skill point. Tap the small + on a skill button (bottom right) to learn it. Ember Totem, the first one, is a good start."},
	{"id": "cast", "title": "Cast it",
		"text": "Tap the skill to cast it at the best spot. Or drag from its button to aim, and let go to cast. Drag back onto the button to cancel."},
	{"id": "shop", "title": "Buy an item",
		"text": "Gold buys items between waves. Walk to the shop stall at the marker (or tap Shop) and buy something. Iron Knuckles is a good first buy."},
	{"id": "arena", "title": "To the arena",
		"text": "Waves are fought in the arena north of the camp. In a real run a timer sends you there; the Fight! button goes early. Tap Fight! now.", "button": "Fight!"},
	{"id": "fight", "title": "Fight",
		"text": "Your hero attacks the nearest enemy on its own. Tap an enemy to make it your target. Use your skills too. Defeat the pack!"},
	{"id": "level", "title": "Level up",
		"text": "Kills give experience. Every level gives a skill point: tap + to learn another skill, or rank one up."},
	{"id": "nook", "title": "Barrel stacks",
		"text": "Barrel stacks fill the corners of the arena. At the marker, smash your way in (tap the barrels, or push into them) and dig a corridor two or three barrels deep."},
	{"id": "hold", "title": "Hold the corridor",
		"text": "Inside the corridor foes can only follow you single file, so only the front one reaches you. Hold here until the pack is gone."},
	{"id": "captain", "title": "The captain",
		"text": "Every wave has a captain: a big named foe worth a gold bounty. When the ground glows under it, a slam is coming. Step out of the glow!"},
	{"id": "done", "title": "Training complete!",
		"text": "Between waves you return to camp to shop and heal at the fountain. Survive 20 waves; a boss comes every 5th wave. If you fall, you retry the wave, and you have 3 lives. Good luck!", "button": "Finish"},
]
const MOVE_SPOT := Vector3(4.5, 0, 36.0)
const CARD_W := 440.0

var run: Run
var step := -1
var done_t := 0.0          # short pause after a step is completed, before the next one shows
var marker: Node = null
var spawned: Array = []
var _cast_seen := false
var _ranks0 := 0

var panel: PanelContainer
var title_label: Label
var text_label: Label
var step_label: Label
var action_btn: Button
var skip_btn: Button


func setup(r: Run) -> void:
	run = r
	name = "Tutorial"
	run.skill_cast.connect(func(_slot): _cast_seen = true)
	_build_panel()
	_go(0)


func step_id() -> String:
	return STEPS[step]["id"] if step >= 0 and step < STEPS.size() else ""


func _build_panel() -> void:
	panel = UIK.panel("FramePanel")
	panel.name = "Coach"
	# docked on the left under the portrait, clear of the hero (the camera keeps it near the screen's centre)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.custom_minimum_size = Vector2(CARD_W, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	title_label = Menus._outlined(UIK.label("", "TitleLabel", 24, UIK.col("gold", Color.GOLD)), 6)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	step_label = UIK.label("", "SmallLabel", 16, UIK.col("dim", Color(0.75, 0.7, 0.62)))
	step_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(step_label)
	text_label = UIK.label("", "", 17, UIK.col("text", Color(0.95, 0.92, 0.85)))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(CARD_W - 30, 0)
	v.add_child(text_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	skip_btn = UIK.button("Skip training", "", Vector2(170, 50))
	skip_btn.name = "SkipTraining"
	skip_btn.add_theme_font_size_override("font_size", 17)
	skip_btn.pressed.connect(finish)
	row.add_child(skip_btn)
	action_btn = UIK.button("Next", "PrimaryButton", Vector2(150, 50))
	action_btn.name = "CoachAction"
	action_btn.pressed.connect(_on_action)
	row.add_child(action_btn)
	run.hud.root.add_child(panel)
	_place_panel()
	if run.hud.controls and "blockers" in run.hud.controls:
		run.hud.controls.blockers.append(skip_btn)
		run.hud.controls.blockers.append(action_btn)


## Keep the card under the HUD's top-left block, and fade it out of the way if the hero ever walks behind it.
func _place_panel() -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var tl: Control = run.hud.top_left
	var x := 16.0
	var y := 120.0
	if tl and is_instance_valid(tl):
		x = tl.position.x
		y = tl.position.y + tl.size.y + 14.0
	panel.position = Vector2(x, y)
	panel.size = Vector2(CARD_W, 0)
	var a := 1.0
	var h := run.hero
	if run.camera and h and not run.camera.is_position_behind(h.pos):
		var feet := run.camera.unproject_position(h.pos)
		var head := run.camera.unproject_position(h.pos + Vector3(0, 2.2, 0))
		var hero_rect := Rect2(head - Vector2(60, 10), Vector2(120, feet.y - head.y + 20))
		if panel.get_global_rect().intersects(hero_rect):
			a = 0.3
	panel.self_modulate.a = lerpf(panel.self_modulate.a, a, 0.2)
	(panel.get_child(0) as Control).modulate.a = panel.self_modulate.a


func _process(_dt: float) -> void:
	_place_panel()


func _go(i: int) -> void:
	step = i
	done_t = 0.0
	var s: Dictionary = STEPS[i]
	title_label.text = s["title"]
	text_label.text = s["text"]
	step_label.text = "%d / %d" % [i + 1, STEPS.size()]
	action_btn.text = s.get("button", "")
	action_btn.visible = s.has("button")
	skip_btn.visible = s["id"] != "done"
	_clear_marker()
	match s["id"]:
		"move":
			_set_marker(MOVE_SPOT)
		"learn":
			_ranks0 = _rank_sum()
		"cast":
			_cast_seen = false
		"shop":
			_set_marker(DB.SHOP_POS)
		"level":
			if run.hero.skill_points <= 0:
				run.hero.add_xp(DB.xp_to_next(run.hero.level) - run.hero.xp + 1.0)
				run._on_level_up()
			_ranks0 = _rank_sum()
		"nook":
			var st := _nearest_stack()
			if st.is_empty():
				_go(i + 2)   # no barrel stacks in this arena: skip to the captain
				return
			_set_marker(st["front"])
		"hold":
			_spawn_pack(7)
		"captain":
			_spawn_captain()
		"done":
			Audio.play("victory")
	_flash_panel()


func _on_action() -> void:
	match step_id():
		"welcome":
			_complete()
		"arena":
			_enter_arena()
			_complete()
		"done":
			finish()


## Player did what the step asked: a short beat, then the next step.
func _complete() -> void:
	if done_t > 0.0:
		return
	done_t = 0.9
	_clear_marker()
	Audio.play("rank")
	title_label.text = "Done!"
	action_btn.visible = false


func tick(dt: float) -> void:
	if step < 0 or step >= STEPS.size():
		return
	if done_t > 0.0:
		done_t -= dt
		if done_t <= 0.0:
			_go(step + 1)
		return
	var h := run.hero
	match step_id():
		"move":
			if _flat_dist(h.pos, MOVE_SPOT) < 1.8:
				_complete()
		"learn":
			if _rank_sum() > _ranks0:
				_complete()
		"cast":
			if _cast_seen:
				_complete()
		"shop":
			if not h.items.is_empty():
				# wait for the shop to be closed before moving on
				if run.hud.shop == null:
					_complete()
				else:
					text_label.text = "Nice! Close the shop when you're done (the X, or Back)."
		"fight", "hold", "captain":
			if not spawned.is_empty() and _alive_spawned() == 0:
				_complete()
		"level":
			if _rank_sum() > _ranks0 or h.skill_points <= 0:
				_complete()
		"nook":
			# dug in: barrels on both sides of the hero
			if run.barrels.cover(h.pos) >= 2:
				_complete()


## Training fight: the arena without a wave timer; the coach spawns each pack.
func _enter_arena() -> void:
	if run.hud and run.hud.has_method("close_shop"):
		run.hud.close_shop()
	run.phase = "wave"
	run.wave_time = 0.0
	run.barrels.reset()
	run._teleport_hero(DB.ARENA_SPAWN)
	run.hero.in_camp = false
	if run.hero.kit:
		run.hero.kit.on_wave_start()
	_spawn_pack(5)


func _spawn_pack(n: int) -> void:
	spawned.clear()
	var gate: Vector3 = Maps.gates()["N"]
	for i in n:
		var p := gate + Vector3(randf_range(-2.0, 2.0), 0, randf_range(0.0, 2.5))
		var e := run.spawn_enemy("gnawer", p, 1)
		spawned.append(e)
	run.fx("teleport", {"pos": gate})


func _spawn_captain() -> void:
	spawned.clear()
	var gate: Vector3 = Maps.gates()["N"]
	var e := run.spawn_enemy("gnawer", gate + Vector3(0, 0, 2.0), 1)
	e.make_captain()
	e.max_hp *= 0.6
	e.hp = e.max_hp
	run.captain = e
	run.fx("teleport", {"pos": e.pos})
	spawned.append(e)


func _alive_spawned() -> int:
	var n := 0
	for e in spawned:
		if is_instance_valid(e) and e.alive:
			n += 1
	return n


func _rank_sum() -> int:
	var s := 0
	for r in run.hero.ranks:
		s += int(r)
	return s


## The barrel stack closest to the hero ("front" is the spot just outside its dig lane, where the marker goes).
func _nearest_stack() -> Dictionary:
	if run.barrels == null or not ("stacks" in run.barrels) or not run.barrels.has_method("cover"):
		return {}
	var best := {}
	var bd := 1e9
	for st in run.barrels.stacks:
		if not (st is Dictionary) or not st.has("front") or not st.has("lane"):
			continue
		var d := _flat_dist(st["front"], run.hero.pos)
		if d < bd:
			bd = d
			best = st
	return best


func _set_marker(p: Vector3) -> void:
	_clear_marker()
	marker = run.fx("rally_marker", {"pos": p, "duration": 3600.0, "color": Color(1.0, 0.8, 0.3)})


func _clear_marker() -> void:
	if marker != null:
		run.fx_stop(marker)
	marker = null


func _flash_panel() -> void:
	panel.modulate = Color(1.6, 1.4, 1.0)
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate", Color(1, 1, 1), 0.5)


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Training is over (finished or skipped): it counts as done, and the run ends on the Training complete screen.
func finish() -> void:
	if run.result != "":
		return
	_clear_marker()
	Profile.d()["training_done"] = true
	Profile.d()["training_offered"] = true
	Profile.save()
	panel.visible = false
	finished.emit()
	run._end_run("training")


func _exit_tree() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
