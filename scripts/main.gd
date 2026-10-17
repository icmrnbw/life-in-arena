extends Node
## Scene flow: title -> hero select -> run -> end screen. Pause menu, auto-pause, test-hook entry points.

var ui: CanvasLayer
var backdrop: Node3D
var backdrop_cam: Camera3D
var run: Run
var screen: Control
var pause_ui: Control
var menu_hero := ""
var _sway := 0.0

## Title scene: a hero resting by a bonfire on a ledge south of the camp; the camp and the Pit glow beyond.
const FIRE_POS := Vector3(-4.0, 0, 72.0)
const SEAT_POS := Vector3(-5.56, 0, 70.83)
const CAM_POS := Vector3(-3.9, 2.3, 77.6)
const CAM_LOOK := Vector3(-7.4, 1.0, 70.6)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(true)
	ui = CanvasLayer.new()
	ui.layer = 10
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var sc := Game.arg("scene", "")
	var hero := Game.arg("hero", "")
	if hero != "" and not DB.HEROES.has(hero):
		push_warning("Unknown hero '%s', using ashwarden" % hero)
		hero = "ashwarden"
	var wave := int(Game.arg("wave", "1"))
	match sc:
		"menu", "title":
			show_title()
		"hero_select":
			show_hero_select()
		"shop":
			start_run(hero if hero != "" else "ashwarden", maxi(1, wave))
			get_tree().create_timer(0.6).timeout.connect(func():
				if run and run.hud:
					run.hud.open_shop())
		"pause":
			start_run(hero if hero != "" else "ashwarden", maxi(1, wave))
			get_tree().create_timer(0.8).timeout.connect(pause_game)
		"end", "victory":
			start_run(hero if hero != "" else "ashwarden", maxi(1, wave))
			get_tree().create_timer(0.8).timeout.connect(func():
				if run:
					run.stats["damage_by"] = {"Attack": 5200.0, "Ember Totem": 8100.0, "Ash Wall": 2300.0, "Tether Pull": 1900.0}
					run.max_wave_reached = 7
					run._end_run("victory" if sc == "victory" else "defeat"))
		"hud":
			start_run(hero if hero != "" else "ashwarden", wave if Game.args.has("wave") else 3)
			get_tree().create_timer(0.5).timeout.connect(func():
				if run:
					run.skip_prep())
		_:
			if hero != "":
				start_run(hero, maxi(1, wave))
			else:
				show_title()
	if sc != "" and Game.args.has("screenshot-dir") and float(Game.arg("screenshot-every", "0")) <= 0.0:
		_shot_when_ready(sc)


## --scene screenshots: wait until the world / menu is actually built and a few frames have rendered.
func _shot_when_ready(sc: String) -> void:
	var min_wait := 4.0 if sc == "hud" else 2.0
	await get_tree().create_timer(min_wait, true, false, true).timeout
	var t := 0.0
	while t < 8.0:
		var ok := true
		if sc in ["hud", "shop", "pause", "end", "victory"]:
			ok = run != null and is_instance_valid(run) and run.camera != null
			if ok and sc == "shop":
				ok = run.hud != null and run.hud.shop != null
			if ok and (sc == "end" or sc == "victory"):
				ok = screen != null
		else:
			ok = screen != null and backdrop != null
		if ok:
			break
		await get_tree().create_timer(0.25, true, false, true).timeout
		t += 0.25
	for i in 6:
		await get_tree().process_frame
	Game.screenshot(sc)


func _process(delta: float) -> void:
	if backdrop_cam and is_instance_valid(backdrop_cam):
		# slow handheld drift
		_sway += delta
		var off := Vector3(sin(_sway * 0.21) * 0.25, sin(_sway * 0.17) * 0.08, cos(_sway * 0.13) * 0.15)
		backdrop_cam.position = CAM_POS + off
		backdrop_cam.look_at(CAM_LOOK + off * 0.3, Vector3.UP)


# ---------------------------------------------------------------- screens
func _clear_screen() -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = null


func _ensure_backdrop() -> void:
	if backdrop and is_instance_valid(backdrop):
		return
	backdrop = Node3D.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	var env := Node.new()
	backdrop.add_child(env)
	if Art.has_method("setup_environment"):
		Art.setup_environment(env)
	var w := Node3D.new()
	backdrop.add_child(w)
	if Art.has_method("build_world"):
		Art.build_world(w)
	if Art.has_method("set_fx_root"):
		Art.set_fx_root(w)
	if Art.has_method("menu_camp"):
		Art.menu_camp(w, FIRE_POS)
	# one of the heroes (random each visit) resting by the fire
	menu_hero = Game.arg("menu-hero", "")
	if not DB.HEROES.has(menu_hero):
		menu_hero = DB.HERO_ORDER[randi() % DB.HERO_ORDER.size()]
	var u = Art.create_unit(menu_hero) if Art.has_method("create_unit") else null
	if u is Node3D:
		w.add_child(u)
		u.position = SEAT_POS + (Vector3(-0.32, 0, -0.24) if menu_hero == "hivemother" else Vector3.ZERO)
		u.rotation.y = -2.21   # facing the fire
		if u.has_method("set_state"):
			u.call("set_state", "sit")
	backdrop_cam = Camera3D.new()
	backdrop_cam.fov = 40.0
	backdrop_cam.far = 200.0
	backdrop.add_child(backdrop_cam)
	backdrop_cam.position = CAM_POS
	backdrop_cam.current = true


func _free_backdrop() -> void:
	if backdrop and is_instance_valid(backdrop):
		backdrop.queue_free()
	backdrop = null
	backdrop_cam = null


func show_title() -> void:
	_end_run_node()
	_ensure_backdrop()
	_clear_screen()
	Game.state["phase"] = "menu"
	screen = Menus.title_screen(show_hero_select)
	ui.add_child(screen)


func show_hero_select() -> void:
	_end_run_node()
	_ensure_backdrop()
	_clear_screen()
	Game.state["phase"] = "hero_select"
	screen = Menus.hero_select(func(id): start_run(id, 1), show_title)
	ui.add_child(screen)


func start_run(hero_id: String, wave := 1) -> void:
	_clear_screen()
	_end_run_node()
	_free_backdrop()
	get_tree().paused = false
	run = Run.new()
	run.setup(hero_id, wave)
	add_child(run)
	run.run_ended.connect(_on_run_ended)
	run.hud.pause_requested.connect(pause_game)


func _end_run_node() -> void:
	if run and is_instance_valid(run):
		run.process_mode = Node.PROCESS_MODE_DISABLED
		run.queue_free()
	run = null
	_close_pause()
	get_tree().paused = false
	Game.paused_by_shop = false


func _on_run_ended(res: String) -> void:
	Game.on_run_ended(res)
	_close_pause()
	get_tree().paused = false
	var r := run
	# real-time timer: works even if the tree is paused or time is scaled
	get_tree().create_timer(1.2, true, false, true).timeout.connect(func(): _show_end(r))


func _show_end(for_run: Run = null) -> void:
	if run == null or not is_instance_valid(run):
		return
	if for_run != null and for_run != run:
		return
	_clear_screen()
	if run.hud:
		run.hud.visible = false
	screen = Menus.end_screen(run, show_hero_select, show_title)
	ui.add_child(screen)
	if run.result == "victory":
		_victory_bursts(run)


## Gold ember bursts around the champion while the victory screen is up.
func _victory_bursts(r: Run) -> void:
	for i in 7:
		get_tree().create_timer(0.15 + i * 0.45, true, false, true).timeout.connect(func():
			if r == null or not is_instance_valid(r) or r != run or r.hero == null:
				return
			var a := randf() * TAU
			var p := r.hero.pos + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 3.5)
			r.fx("death_burst", {"pos": p + Vector3(0, 0.6, 0), "color": UIK.col("gold", Color(1, 0.8, 0.3)), "size": 2.2})
			if i % 3 == 0:
				r.fx("level_up", {"pos": r.hero.pos}))


# ---------------------------------------------------------------- pause
func pause_game() -> void:
	if run == null or not is_instance_valid(run) or run.result != "":
		return
	if pause_ui != null:
		return
	_release_controls()
	get_tree().paused = true
	pause_ui = Menus.pause_menu(resume_game, func(): show_title())
	ui.add_child(pause_ui)


func resume_game() -> void:
	_close_pause()
	_release_controls()
	get_tree().paused = false


## Drop every held finger / joystick so nothing keeps walking or aiming after a pause or focus loss.
func _release_controls() -> void:
	if run == null or not is_instance_valid(run):
		return
	if run.hud and run.hud.controls and run.hud.controls.has_method("_release_all"):
		run.hud.controls._release_all()
	if run.hero:
		run.hero.move_input = Vector2.ZERO


func _close_pause() -> void:
	if pause_ui and is_instance_valid(pause_ui):
		pause_ui.queue_free()
	pause_ui = null


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_release_controls()
			if not Game.autoplay:
				pause_game()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			Game.write_report()


func _on_back() -> void:
	if pause_ui != null:
		resume_game()
	elif run != null and is_instance_valid(run):
		if run.result != "":
			show_title()
		elif run.hud and run.hud.shop != null:
			run.hud.close_shop()
		else:
			pause_game()
	elif Game.state.get("phase", "") == "hero_select":
		show_title()
	else:
		Game.quit_game()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if pause_ui != null:
				resume_game()
			else:
				pause_game()
