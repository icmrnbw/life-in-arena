extends Node
## Scene flow: title -> hero select -> run -> end screen. Pause menu, auto-pause, test-hook entry points.

var ui: CanvasLayer
var backdrop: Node3D
var backdrop_cam: Camera3D
var run: Run
var screen: Control
var pause_ui: Control
var menu_hero := ""
var menu_unit: Node3D
var overlay: Control       # the first-run Training offer, over the title screen
var _sway := 0.0

## Title scene: a hero resting by a bonfire on a ledge south of the camp; the camp and the Pit glow beyond.
const FIRE_POS := Vector3(-4.0, 0, 72.0)
const SEAT_POS := Vector3(-5.56, 0, 70.83)
const CAM_POS := Vector3(-3.9, 2.3, 77.6)
const CAM_LOOK := Vector3(-2.0, 1.0, 70.6)


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
		"play", "modes":
			show_play(Game.arg("mode", ""))
		"records":
			show_records()
		"languages":
			show_title()
			show_languages()
		"offer":
			show_title()
			_offer_training()
		"training":
			start_run("ashwarden", 1, Modes.config("training"))
		"heroes", "gallery":
			show_gallery(hero)
		"shop":
			start_run(hero if hero != "" else "ashwarden", maxi(1, wave))
			get_tree().create_timer(0.6).timeout.connect(func():
				if run and run.hud:
					run.hud.open_shop())
		"pause":
			start_run(hero if hero != "" else "ashwarden", maxi(1, wave))
			get_tree().create_timer(0.8).timeout.connect(pause_game)
		"skills":
			start_run(hero if hero != "" else "ashwarden", maxi(1, wave))
			get_tree().create_timer(0.8).timeout.connect(func():
				if run and run.hero:
					run.hero.ranks[0] = 2
					run.hero.ranks[1] = 1
				show_skill_info())
		"end", "victory":
			start_run(hero if hero != "" else "ashwarden", maxi(1, wave))
			get_tree().create_timer(0.8).timeout.connect(func():
				if run:
					run.stats["damage_by"] = {"Attack": 5200.0, "Ember Totem": 8100.0, "Ash Wall": 2300.0, "Tether Pull": 1900.0}
					run.max_wave_reached = 7
					run._end_run("victory" if sc == "victory" else "defeat"))
		"hud":
			start_run(hero if hero != "" else "ashwarden", wave if Game.args.has("wave") else 3, _arg_cfg())
			get_tree().create_timer(0.5).timeout.connect(func():
				if run:
					run.skip_prep())
		"camp":
			start_run(hero if hero != "" else "ashwarden", wave if Game.args.has("wave") else 4, _arg_cfg())
		"duel":
			# a camp duel under way (--duel=<hero> picks the rival)
			start_run(hero if hero != "" else "ashwarden", wave if Game.args.has("wave") else 4, _arg_cfg())
			get_tree().create_timer(0.5).timeout.connect(func():
				if run:
					run.duel.accept())
		_:
			if hero != "":
				start_run(hero, maxi(1, wave), _arg_cfg())
			else:
				show_title()
	if sc != "" and Game.args.has("screenshot-dir") and float(Game.arg("screenshot-every", "0")) <= 0.0:
		_shot_when_ready(sc)


## --scene screenshots: wait until the world / menu is actually built and a few frames have rendered.
func _shot_when_ready(sc: String) -> void:
	var min_wait := 4.0 if sc in ["hud", "duel"] else 2.0
	await get_tree().create_timer(min_wait, true, false, true).timeout
	var t := 0.0
	while t < 8.0:
		var ok := true
		if sc in ["hud", "shop", "pause", "skills", "end", "victory", "training", "camp", "duel"]:
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


## Run settings from the test hooks: --mode=<id> --tier=<id> --map=<arena id> (--date=YYYY-MM-DD for daily).
## Bot and test runs don't touch the saved profile unless --profile is passed.
func _arg_cfg() -> Dictionary:
	var extra := {"map": Game.arg("map", "pit")}
	if Game.args.has("date"):
		extra["date"] = Game.arg("date", Modes.today())
	if Game.args.has("seed"):
		extra["seed"] = int(Game.arg("seed", "0"))
	var c := Modes.config(Game.arg("mode", "classic"), Game.arg("tier", "hard"), extra)
	if not Game.args.has("profile"):
		c["counts"] = false
	# --allies=N: N AI ally heroes picked for the hero; --ally=<id>,<id>: exactly these
	if Game.args.has("ally"):
		c["ally_ids"] = Array(Game.arg("ally", "").split(",", false))
	elif Game.args.has("allies"):
		c["allies"] = clampi(int(Game.arg("allies", "1")), 0, 3)
	return c


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
	# a hero resting by the fire
	menu_hero = Game.arg("menu-hero", "riftdancer")   # the swordsman rests by the fire
	if not DB.HEROES.has(menu_hero):
		menu_hero = "riftdancer"
	var u = Art.create_unit(menu_hero) if Art.has_method("create_unit") else null
	if u is Node3D:
		w.add_child(u)
		u.position = SEAT_POS + (Vector3(-0.32, 0, -0.24) if menu_hero == "hivemother" else Vector3.ZERO)
		u.rotation.y = -2.21   # facing the fire
		Skins.apply_equipped(u, menu_hero)
		menu_unit = u
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
	_close_overlay()
	Game.state["phase"] = "menu"
	var snap := Profile.load_run()
	screen = Menus.title_screen(_on_play, show_gallery, continue_run if not snap.is_empty() else Callable(), show_records, snap, show_languages)
	ui.add_child(screen)


## Language list over the title screen. Picking one saves it and rebuilds the title in that language.
func show_languages() -> void:
	_close_overlay()
	overlay = Menus.language_picker(func(code: String):
		Game.settings["lang"] = code
		Game.save_settings()
		L.set_lang(code)
		show_title(),
	_close_overlay)
	ui.add_child(overlay)


## Play: the first time, offer Training before the mode list.
func _on_play() -> void:
	if not Profile.d().get("training_done", false) and not Profile.d().get("training_offered", false):
		_offer_training()
		return
	show_play()


func _offer_training() -> void:
	Profile.d()["training_offered"] = true
	Profile.save()
	_close_overlay()
	overlay = PlayMenu.training_offer(func():
		_close_overlay()
		start_run("ashwarden", 1, Modes.config("training")),
	func():
		_close_overlay()
		show_play())
	ui.add_child(overlay)


func _close_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


## Mode list: Classic, Random Hero, Endless, Daily Run, Practice, Training.
func show_play(first_mode := "") -> void:
	_end_run_node()
	_ensure_backdrop()
	_clear_screen()
	_close_overlay()
	Game.state["phase"] = "play"
	screen = PlayMenu.create(show_hero_select, start_run, show_title, first_mode)
	ui.add_child(screen)


func show_records() -> void:
	_end_run_node()
	_ensure_backdrop()
	_clear_screen()
	Game.state["phase"] = "records"
	screen = PlayMenu.records(show_title)
	ui.add_child(screen)


## Carry on with the run saved in camp.
func continue_run() -> void:
	var snap := Profile.load_run()
	if snap.is_empty():
		show_title()
		return
	var c: Dictionary = snap.get("cfg", {}).duplicate()
	if c.is_empty():
		c = Modes.config("classic")
	c["resume"] = snap
	start_run(String(snap["hero"]), 1, c)


## Hero select for a mode (Classic by default). Locked heroes can't be picked, except in Practice.
func show_hero_select(run_cfg := {}) -> void:
	_end_run_node()
	_ensure_backdrop()
	_clear_screen()
	var c: Dictionary = run_cfg if not run_cfg.is_empty() else Modes.config("classic", Profile.d().get("last_tier", "hard"))
	Game.state["phase"] = "hero_select"
	screen = Menus.hero_select(func(id): start_run(id, int(c.get("start_wave", 1)), c), func(): show_play(c.get("mode", "classic")), c)
	ui.add_child(screen)


## Heroes screen: browse every hero's model, skills and skins.
func show_gallery(first_hero := "") -> void:
	_end_run_node()
	_ensure_backdrop()
	_clear_screen()
	Game.state["phase"] = "gallery"
	screen = HeroGallery.create(_close_gallery, first_hero)
	ui.add_child(screen)


## Leaving the Heroes screen: re-dress the hero resting by the fire in any newly equipped skin.
func _close_gallery() -> void:
	if menu_unit and is_instance_valid(menu_unit):
		Skins.apply(menu_unit, menu_hero, Skins.equipped(menu_hero))
	show_title()


func start_run(hero_id: String, wave := 1, run_cfg := {}) -> void:
	_clear_screen()
	_close_overlay()
	_end_run_node()
	_free_backdrop()
	get_tree().paused = false
	if not run_cfg.has("resume") and String(run_cfg.get("mode", "classic")) not in ["practice", "training"] and not Game.autoplay:
		Profile.clear_run()   # a new run replaces the saved one
	run = Run.new()
	run.setup(hero_id, wave, run_cfg)
	add_child(run)
	run.run_ended.connect(_on_run_ended)
	run.hud.pause_requested.connect(pause_game)
	run.hud.skills_info_requested.connect(show_skill_info)


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
	var c: Dictionary = run.cfg.duplicate()
	c.erase("resume")
	var again := func():
		match String(c.get("mode", "classic")):
			"random":
				start_run(Modes.random_hero(), 1, Modes.config("random", c.get("tier", "hard")))
			"daily":
				start_run(run.hero_id, 1, Modes.config("daily", "hard", {"date": c.get("date", Modes.today())}))
			"training":
				show_play()
			_:
				show_hero_select(c)
	screen = Menus.end_screen(run, again, show_title)
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


## Skill descriptions: pauses like the pause menu and shares its slot, so Back / Esc / resume close it too.
func show_skill_info() -> void:
	if run == null or not is_instance_valid(run) or run.result != "" or run.hero == null:
		return
	if pause_ui != null:
		return
	_release_controls()
	get_tree().paused = true
	pause_ui = Menus.skill_info(run.hero, resume_game)
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
	elif overlay != null:
		_close_overlay()
	elif Game.state.get("phase", "") == "hero_select":
		show_play()
	elif Game.state.get("phase", "") in ["play", "records", "gallery"]:
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
