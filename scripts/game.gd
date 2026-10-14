extends Node
## Global: command-line test hooks, shared state, settings, run report, screenshots, error capture.

var state := {"phase": "menu", "wave": 0, "lives": DB.START_LIVES, "gold": 0, "level": 1, "enemies_alive": 0}
var args := {}
var autoplay := false
var autoplay_mode := "smart"
var god := false
var timescale := 1.0
var settings := {"auto_shop": true, "shake": true, "sound": true}
var paused_by_shop := false
var run: Run = null
var last_result := ""
var errors: Array = []

var _quit_after := -1.0
var _start_ms := 0
var _fps_sum := 0.0
var _fps_n := 0
var _min_fps := 1e9
var _fps_t := 0.0
var _shot_dir := ""
var _shot_every := 0.0
var _shot_t := 0.0
var _shot_n := 0
var _report_path := ""
var _logger: ErrLogger
var _quitting := false


class ErrLogger extends Logger:
	var sink: Array = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var msg := "%s (%s:%d %s) %s" % [code, file, line, function, rationale]
		var low := msg.to_lower()
		# audio drivers are absent in containers; that's not a game error
		if low.contains("audio") or low.contains("alsa") or low.contains("pulse") or low.contains("wasapi"):
			return
		if error_type == 1 and not low.contains("script"):
			pass
		mutex.lock()
		if sink.size() < 60:
			sink.append(("WARNING: " if error_type == 1 else "ERROR: ") + msg)
		mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		if not error:
			return
		var low := message.to_lower()
		if low.contains("audio") or low.contains("alsa") or low.contains("pulse"):
			return
		mutex.lock()
		if sink.size() < 60:
			sink.append("STDERR: " + message.strip_edges())
		mutex.unlock()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_ms = Time.get_ticks_msec()
	_logger = ErrLogger.new()
	OS.add_logger(_logger)
	_parse_args()
	_load_settings()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = a
		if not s.begins_with("--"):
			continue
		s = s.substr(2)
		var k := s
		var v := "true"
		var eq := s.find("=")
		if eq >= 0:
			k = s.substr(0, eq)
			v = s.substr(eq + 1)
		args[k] = v
	if args.has("autoplay"):
		autoplay = true
		if args["autoplay"] != "true":
			autoplay_mode = args["autoplay"]
	god = args.has("god")
	if args.has("timescale"):
		timescale = clampf(float(args["timescale"]), 0.1, 20.0)
		Engine.time_scale = timescale
	if args.has("quit-after"):
		_quit_after = float(args["quit-after"])
	if args.has("report"):
		_report_path = args["report"]
	if args.has("screenshot-dir"):
		_shot_dir = args["screenshot-dir"]
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		_shot_every = float(args.get("screenshot-every", "0"))
		_shot_t = _shot_every if _shot_every > 0.0 else 0.0
	if autoplay or args.has("hero"):
		# keep the sim steady when running accelerated on slow machines
		Engine.max_fps = 0


func arg(k: String, default := "") -> String:
	return str(args.get(k, default))


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("settings", k, settings[k])


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	cf.save("user://settings.cfg")


func real_seconds() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0


func _process(delta: float) -> void:
	var real := real_seconds()
	# fps sampling (after warm-up)
	_fps_t += delta / maxf(0.01, Engine.time_scale)
	if _fps_t >= 1.0:
		_fps_t = 0.0
		if real > 3.0:
			var f := Engine.get_frames_per_second()
			_fps_sum += f
			_fps_n += 1
			_min_fps = minf(_min_fps, f)
	# screenshots
	if _shot_dir != "" and DisplayServer.get_name() != "headless":
		if _shot_every > 0.0:
			_shot_t -= delta / maxf(0.01, Engine.time_scale)
			if _shot_t <= 0.0:
				_shot_t = _shot_every
				screenshot()
	if _quit_after > 0.0 and real >= _quit_after and not _quitting:
		quit_game()


func screenshot(tag := "") -> void:
	if _shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	var vp := get_viewport()
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	_shot_n += 1
	var nm := "shot_%04d%s.png" % [_shot_n, ("_" + tag) if tag != "" else ""]
	img.save_png(_shot_dir.path_join(nm))


func on_run_started(r: Run) -> void:
	run = r
	last_result = ""


func on_prep() -> void:
	pass


func on_run_ended(res: String) -> void:
	last_result = res
	write_report()
	if autoplay:
		# give QA screenshots of the end screen, then exit
		get_tree().create_timer(3.0, true, false, true).timeout.connect(quit_game)


func avg_fps() -> float:
	if _fps_n == 0:
		return Engine.get_frames_per_second()
	return _fps_sum / _fps_n


func build_report() -> Dictionary:
	var rep := {"hero": arg("hero", ""), "result": "none", "wave_reached": 0, "level": 1, "gold_earned": 0, "kills": 0,
		"deaths": 0, "lives_left": 0, "duration_s": 0.0, "avg_fps": snappedf(avg_fps(), 0.1),
		"min_fps": snappedf(_min_fps if _min_fps < 1e8 else avg_fps(), 0.1), "errors": _logger.sink.duplicate() if _logger else []}
	if run != null and is_instance_valid(run):
		rep["hero"] = run.hero_id
		var res := run.result
		if res == "" or res == "quit":
			res = "in_progress" if res == "" else "quit"
		rep["result"] = res
		rep["wave_reached"] = maxi(run.max_wave_reached, 0)
		rep["level"] = run.hero.level
		rep["gold_earned"] = run.stats["gold_earned"]
		rep["kills"] = run.stats["kills"]
		rep["deaths"] = run.stats["deaths"]
		rep["lives_left"] = maxi(0, run.lives)
		rep["duration_s"] = snappedf(run.run_time, 0.1)
		rep["gold"] = run.gold
		rep["items"] = run.hero.items.map(func(it): return it["id"])
		rep["ranks"] = run.hero.ranks.duplicate()
		rep["damage_by"] = run.stats["damage_by"].duplicate()
		rep["wave_log"] = run.get_meta("wave_log", [])
		rep["sim_ms_avg"] = snappedf(run.sim_us_sum / maxf(1.0, run.sim_frames) / 1000.0, 0.001)
		rep["sim_ms_max_busy"] = snappedf(run.sim_us_max_busy / 1000.0, 0.001)
		rep["sim_ms_avg_busy"] = snappedf(run.sim_us_busy_sum / maxf(1.0, run.sim_busy_frames) / 1000.0, 0.001)
	elif last_result != "":
		rep["result"] = last_result
	return rep


func write_report() -> void:
	if _report_path == "":
		return
	var rep := build_report()
	var dir := _report_path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rep, "  "))
		f.close()


func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	write_report()
	get_tree().quit()
