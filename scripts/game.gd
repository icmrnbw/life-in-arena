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
## Trail of the previous session when it ended without a clean exit (a crash or a kill by the OS while in front).
var prev_crash := {}

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
var _trail: Array = []
var _watch: Array = []      # [frames_left, label]: crumbs a few frames after a risky moment (boss death)
var _beat_t := 0.0
var _live: Array = []      # last few "live" snapshots (every 0.5 s in a wave), to see the moment before a crash
var _live_t := 0.0
var _frame_ms := 0       # ticks at the previous frame, for the longest-frame figure
var _max_frame := 0      # longest frame (ms) since the last snapshot
var _fx_recent := {}       # fx name -> spawns since the last snapshot
var _trail_on := false      # off under test hooks (they quit abruptly), unless --trail is passed

const TRAIL_PATH := "user://crash_trail.json"


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
	_trail_on = args.is_empty() or args.has("trail")
	_load_prev_trail()
	crumb("app start %s, %s, %s" % [ProjectSettings.get_setting("application/config/version", "?"), OS.get_model_name(), RenderingServer.get_video_adapter_name()])


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
	_tick_trail(delta)
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
	crumb("run start " + r.hero_id)


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
	_write_trail(false)
	get_tree().quit()


# ---------------------------------------------------------------- crash trail
## Breadcrumbs for crashes on phones: the last events are kept on disk while the app is in front, so a session
## that dies without a clean exit can be reported from the title screen on the next launch.
func crumb(what: String) -> void:
	if not _trail_on:
		return
	var w := 0
	if run != null and is_instance_valid(run):
		w = run.wave
	_trail.append("%7.2f w%d %s" % [real_seconds(), w, what])
	if _trail.size() > 40:
		_trail.remove_at(1)   # keep the "app start" line with the device and GPU
	_write_trail(true)


## Counts an effect spawn for the next live snapshot.
func note_fx(fx_name: String) -> void:
	if _trail_on:
		_fx_recent[fx_name] = int(_fx_recent.get(fx_name, 0)) + 1


## Leaves crumbs 1, 10 and 60 frames after a risky moment, to tell a crash in the same frame from one in rendering.
func watch_frames(label: String) -> void:
	for n in [1, 10, 60]:
		_watch.append([n, "%s +%d frames" % [label, n]])


func _tick_trail(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _frame_ms > 0:
		_max_frame = maxi(_max_frame, now - _frame_ms)
	_frame_ms = now
	if not _watch.is_empty():
		var keep := []
		for w in _watch:
			w[0] -= 1
			if w[0] <= 0:
				crumb(w[1])
			else:
				keep.append(w)
		_watch = keep
	if run != null and is_instance_valid(run) and run.phase == "wave":
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = 5.0
			crumb("wave beat: %d enemies, %d bosses, hp %d, fps %d" % [run.enemies.size(), run.boss_units.size(), int(run.hero.hp), int(Engine.get_frames_per_second())])
		_live_t -= delta
		if _live_t <= 0.0:
			_live_t = 0.5
			var fxs := []
			for k in _fx_recent:
				fxs.append("%s x%d" % [k, _fx_recent[k]])
			_fx_recent.clear()
			_live.append("%7.2f w%d t%.1f: %d enemies, %d allies, %d corpses, %d projectiles, %d hazards, %d nodes, %.0f MB, fps %d, longest frame %d ms | %s" % [
				real_seconds(), run.wave, run.wave_time, run.enemies.size(), run.allies.size(), run.corpses.size(), run.projs.size(),
				run.hazards.size(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, int(Engine.get_frames_per_second()), _max_frame, ", ".join(fxs)])
			_max_frame = 0
			if _live.size() > 6:
				_live.remove_at(0)
			_write_trail(true)


func _write_trail(open: bool) -> void:
	if not _trail_on:
		return
	var errs: Array = []
	if _logger:
		_logger.mutex.lock()
		errs = _logger.sink.slice(-10)
		_logger.mutex.unlock()
	var f := FileAccess.open(TRAIL_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"open": open, "trail": _trail, "live": _live, "errors": errs}))
		f.close()


func _load_prev_trail() -> void:
	if not _trail_on or not FileAccess.file_exists(TRAIL_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(TRAIL_PATH))
	if d is Dictionary and d.get("open", false):
		prev_crash = d
		prev_crash["log"] = _prev_log_tail(25)


## Last lines of the previous session's engine log (Godot rotates logs/godot.log to a timestamped name on start).
func _prev_log_tail(n: int) -> Array:
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return []
	var newest := ""
	for fn in dir.get_files():
		if fn.ends_with(".log") and fn != "godot.log" and fn > newest:
			newest = fn
	if newest == "":
		return []
	var lines := FileAccess.get_file_as_string("user://logs/" + newest).split("\n", false)
	return Array(lines.slice(-n))


func crash_report_text() -> String:
	var out := ["Emberpit crash report"]
	out.append_array(prev_crash.get("trail", []))
	var live: Array = prev_crash.get("live", [])
	if not live.is_empty():
		out.append("-- last moments")
		out.append_array(live)
	var errs: Array = prev_crash.get("errors", [])
	if not errs.is_empty():
		out.append("-- errors")
		out.append_array(errs)
	var lg: Array = prev_crash.get("log", [])
	if not lg.is_empty():
		out.append("-- log")
		out.append_array(lg)
	return "\n".join(out)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			crumb("app paused / closing")
			_write_trail(false)
		NOTIFICATION_APPLICATION_RESUMED:
			crumb("app resumed")
