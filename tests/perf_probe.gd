extends Node
## Perf + screenshot probe (QA). Loads the real main scene (Game parses the user args), samples Performance
## monitors once per second, optionally stress-spawns enemies, and saves screenshots.
##   xvfb-run -a -s "-screen 0 2400x1080x24" godot --rendering-driver opengl3 --path /home/claude/emberpit \
##     --resolution 2400x1080 res://tests/perf_probe.tscn -- --hero=ashwarden --wave=12 --autoplay --god \
##     --probe-out=/tmp/qa-agent/perf --probe-secs=40 --probe-stress=70 --probe-shot-every=6
## Optional --probe-action=shop|shop_adv|pause|victory|defeat|death at --probe-action-at=<s>.
## Writes <probe-out>/perf.json and shots/*.png.

var main: Node
var out := "/tmp/qa-agent/perf"
var secs := 40.0
var stress := 0
var shot_every := 6.0
var t := 0.0
var sample_t := 0.0
var shot_t := 0.0
var samples: Array = []
var stressed := false
var nshot := 0
var action := ""
var action_at := 5.0
var action_done := false


func _ready() -> void:
	var g := get_node("/root/Game")
	out = str(g.args.get("probe-out", out))
	secs = float(g.args.get("probe-secs", secs))
	stress = int(g.args.get("probe-stress", "0"))
	shot_every = float(g.args.get("probe-shot-every", shot_every))
	action = str(g.args.get("probe-action", ""))
	action_at = float(g.args.get("probe-action-at", action_at))
	DirAccess.make_dir_recursive_absolute(out + "/shots")
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(delta: float) -> void:
	var real := delta / maxf(0.01, Engine.time_scale)
	t += real
	sample_t += real
	shot_t += real
	var run = main.get("run") if main else null
	if stress > 0 and not stressed and t > 6.0 and run != null and is_instance_valid(run) and run.phase == "wave":
		stressed = true
		var kinds := ["gnawer", "gnawer", "gnawer", "shieldbearer", "hexcaster", "bloater", "burrower"]
		for i in stress:
			var a := TAU * float(i) / stress
			var r := 6.0 + float(i % 4) * 2.5
			run.spawn_enemy(kinds[i % kinds.size()], run.hero.pos + Vector3(cos(a) * r, 0, sin(a) * r))
	if action != "" and not action_done and t >= action_at and run != null and is_instance_valid(run):
		action_done = true
		match action:
			"shop":
				run.hud.open_shop()
			"shop_adv":
				run.hud.open_shop()
				if run.hud.shop:
					run.hud.shop._set_tab("advanced")
					run.hud.shop._select("wardens_aegis")
			"pause":
				main.pause_game()
			"victory", "defeat":
				run.stats["damage_by"]["Attack"] = 5200.0
				run._end_run(action)
			"pillar":
				run.skip_prep()
				run.schedule(0.6, func():
					run.hero.pos = Vector3(0.3, 0, 6.6)
					run.cam_focus = run.hero.pos)
			"death":
				run.damage(run.hero, 1e9, null, "probe", "magic")
		shot_t = shot_every - 1.5
	if sample_t >= 1.0:
		sample_t = 0.0
		var s := {
			"t": snappedf(t, 0.1),
			"fps": Performance.get_monitor(Performance.TIME_FPS),
			"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects_drawn": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"video_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
			"static_mem_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		}
		if run != null and is_instance_valid(run):
			s["enemies"] = run.enemies.size()
			s["allies"] = run.allies.size()
			s["phase"] = run.phase
			s["wave"] = run.wave
		samples.append(s)
		print(JSON.stringify(s))
	if shot_every > 0.0 and shot_t >= shot_every:
		shot_t = 0.0
		_shot()
	if t >= secs:
		_finish()


func _shot() -> void:
	var img := get_viewport().get_texture().get_image()
	if img:
		nshot += 1
		img.save_png("%s/shots/probe_%02d.png" % [out, nshot])


func _finish() -> void:
	set_process(false)
	_shot()
	var run = main.get("run") if main else null
	if run != null and is_instance_valid(run):
		samples.append({"sim_ms_avg": run.sim_us_sum / maxf(1.0, run.sim_frames) / 1000.0,
			"sim_ms_avg_busy": run.sim_us_busy_sum / maxf(1.0, run.sim_busy_frames) / 1000.0,
			"sim_ms_max_busy": run.sim_us_max_busy / 1000.0, "busy_frames": run.sim_busy_frames})
	var f := FileAccess.open(out + "/perf.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(samples, "  "))
	get_tree().quit()
