extends Node3D
## Art review scene. User args (after --):
##   --view=world|camp|units|heroes|bosses|fx|icons|ui|game|perf   --shot=<png path>   --delay=<s>
##   --state=<idle|run|attack|cast|hit|death|spawn|sit> (hold one state in units/bosses views)   --count=<n> (perf view enemies)
##   --view=row --kinds=a,b,c   close-up row of any unit kinds

const HEROES := ["ashwarden", "riftdancer", "hivemother", "sanguine", "snarewright", "twinhide", "twinhide_beast",
	"gravekeeper", "stoneshaper", "gunsmith", "sunspeaker", "duelist", "vanguard", "nightblade", "skyspear", "frostweaver",
	"stormcaller", "alchemist", "chronomancer"]
const ENEMIES := ["gnawer", "shieldbearer", "hexcaster", "burrower", "bloater", "ironhulk", "veilwraith"]
const BOSSES := ["pit_brute", "matron", "hollow_choir", "warden"]
const SUMMONS := ["broodling", "ember_totem", "afterimage", "choir_add", "skeleton", "snare_trap", "blast_charge", "boulder", "stone_pillar"]
const PROJ := ["fire_bolt", "spit", "hex_bolt", "boss_orb", "hero_bolt", "bullet", "crossbow_bolt", "spirit_lance", "grave_bolt", "blood_bolt",
	"dagger", "frost_bolt", "vial", "time_bolt"]
const FX_ONESHOT := ["hit", "death_burst", "level_up", "heal", "gold", "damage_number", "teleport", "tether_pull", "slip_trail",
	"shatter", "rift_strike", "brood_hatch", "sacrifice_explosion", "slam", "fountain_heal",
	"cone", "ring_burst", "blood_burst", "trap_snap", "explosion", "soul_wisp", "form_shift"]
const FX_PERSIST := ["telegraph_circle", "telegraph_line", "aim_circle", "aim_line", "ash_wall", "foundry_aura", "mark",
	"rally_marker", "carapace", "bloater_pool", "beam", "zone", "stone_ridge", "grave_marker"]
const CYCLE := [["idle", 1.6], ["run", 1.8], ["attack", 1.0], ["run", 1.0], ["cast", 1.1], ["idle", 0.8], ["hit", 0.6], ["idle", 0.6], ["death", 1.4], ["spawn", 1.0]]

var view := "units"
var shot := ""
var delay := 2.5
var hold := ""
var count := 60
var fxsel: Array = []
var kinds_sel: Array = []
var cam: Camera3D
var t := 0.0
var units: Array = []
var projs: Array = []
var fx_slots: Array = []
var persist: Dictionary = {}
var fx_t := 0.0
var _shot_done := false
var _perf_frames := 0
var _perf_acc := {}
var game_hero: Node3D
var game_enemies: Array = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--view="): view = a.substr(7)
		elif a.begins_with("--shot="): shot = a.substr(7)
		elif a.begins_with("--delay="): delay = float(a.substr(8))
		elif a.begins_with("--state="): hold = a.substr(8)
		elif a.begins_with("--count="): count = int(a.substr(8))
		elif a.begins_with("--fxsel="): fxsel = Array(a.substr(8).split(","))
		elif a.begins_with("--kinds="): kinds_sel = Array(a.substr(8).split(","))
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	Art.setup_environment(self)
	var fx_root := Node3D.new()
	fx_root.name = "FxRoot"
	add_child(fx_root)
	Art.set_fx_root(fx_root)
	if view in ["icons", "ui"]:
		Art.build_world(self)
		_cam_at(Vector3(0, 40, 54), Vector3(0, 0, 37))
		if view == "icons":
			_build_icons()
		else:
			_build_ui()
	else:
		Art.build_world(self)
		match view:
			"world": _cam_at(Vector3(0, 40, 36), Vector3(0, 0, 2))
			"camp": _cam_at(Vector3(0, 18, 51), Vector3(0, 0, 37))
			"units": _build_units()
			"heroes": _build_heroes()
			"enemies": _build_row(ENEMIES, 2.3)
			"summons": _build_row(SUMMONS, 2.0)
			"row": _build_row(kinds_sel, 2.0)
			"lineup":
				# every hero at the real game camera distance (phone-scale readability check)
				var ks: Array = kinds_sel if not kinds_sel.is_empty() else HEROES
				for i in ks.size():
					_spawn_unit(ks[i], Vector3((i - (ks.size() - 1) * 0.5) * 1.9, 0, 0), i * 0.5)
				_cam_at(Vector3(0, 18, 14), Vector3(0, 0, 0))
			"bosses": _build_bosses()
			"fx": _build_fx()
			"game": _build_game(24)
			"perf": _build_game(count)
			"occlude":
				# game camera framing with the hero just north of the (0,10) pillar
				var hp := Vector3(0.6, 0, 7.0)
				_spawn_unit("ashwarden", hp, 0.0)
				_spawn_unit("gnawer", hp + Vector3(-1.6, 0, -0.8), 0.4)
				_cam_at(hp + Vector3(0, 18, 14), hp + Vector3(0, 0.5, 0))
				cam.fov = 45.0
			_: _build_units()
	if shot != "":
		get_tree().create_timer(delay).timeout.connect(_take_shot)

func _cam_at(pos: Vector3, look: Vector3) -> void:
	cam.position = pos
	cam.look_at(look, Vector3.UP)

# ------------------------------------------------------------------ units

func _spawn_unit(kind: String, pos: Vector3, phase: float) -> Node3D:
	var u := Art.create_unit(kind)
	add_child(u)
	u.position = pos
	u.rotation_degrees.y = 180.0
	units.append({"u": u, "phase": phase, "idx": -1})
	return u

func _build_units() -> void:
	var front := HEROES.slice(0, 3) + SUMMONS
	for i in front.size():
		_spawn_unit(front[i], Vector3(-9.6 + i * 1.6, 0, -3.0), i * 0.7)
	for i in ENEMIES.size():
		_spawn_unit(ENEMIES[i], Vector3(-5.0 + i * 2.5, 0, -6.5), i * 0.9 + 0.3)
	for i in PROJ.size():
		var p := Art.create_projectile(PROJ[i])
		add_child(p)
		p.position = Vector3(-6.75 + i * 1.5, 1.2, -9.0)
		projs.append(p)
	_cam_at(Vector3(0, 9.0, 6.5), Vector3(0, 0.6, -5.0))

func _build_heroes() -> void:
	# two rows: 5 in front, 6 behind (offset so every silhouette reads)
	for i in HEROES.size():
		var back := i >= 5
		var j := i - 5 if back else i
		var n := 6 if back else 5
		var x := (j - (n - 1) * 0.5) * 2.15
		var z := -9.4 if back else -5.4
		if back:
			x += 0.0
		var u := _spawn_unit(HEROES[i], Vector3(x, 0, z), i * 0.5)
		u.rotation_degrees.y = 180.0 - x * 4.0
	_cam_at(Vector3(0, 6.4, 2.6), Vector3(0, 0.6, -7.4))

func _build_row(kinds: Array, sp: float) -> void:
	for i in kinds.size():
		var u := _spawn_unit(kinds[i], Vector3((i - (kinds.size() - 1) * 0.5) * sp, 0, -6.0), i * 0.5)
		u.rotation_degrees.y = 180.0 - (i - (kinds.size() - 1) * 0.5) * 12.0
	_cam_at(Vector3(0, 3.6, 0.6), Vector3(0, 0.6, -6.0))

func _build_bosses() -> void:
	for i in BOSSES.size():
		_spawn_unit(BOSSES[i], Vector3(-8.4 + i * 5.6, 0, -14.0), i * 0.8)
	_cam_at(Vector3(0, 11.5, -0.5), Vector3(0, 2.0, -14.0))

func _cycle_units(dt: float) -> void:
	var total := 0.0
	for c in CYCLE:
		total += c[1]
	for e in units:
		var u: Node3D = e["u"]
		if not is_instance_valid(u):
			continue
		if hold != "":
			var key := int((t + e["phase"]) / 1.2)
			if hold in ["idle", "run"]:
				if e["idx"] != 0:
					u.set_state(hold); e["idx"] = 0
			elif key != e["idx"]:
				e["idx"] = key
				if hold == "death":
					u.set_state("spawn") if key % 2 == 1 else u.set_state("death")
				else:
					u.set_state(hold)
			continue
		var lt := fmod(t + e["phase"], total)
		var acc := 0.0
		for i in CYCLE.size():
			acc += CYCLE[i][1]
			if lt < acc:
				if e["idx"] != i:
					e["idx"] = i
					u.set_state(CYCLE[i][0])
				break

# ------------------------------------------------------------------ fx

func _build_fx() -> void:
	var names := FX_ONESHOT + FX_PERSIST
	var cols := 9
	if not fxsel.is_empty():
		names = fxsel
		cols = 4
	for i in names.size():
		var x := -16.0 + (i % cols) * 4.0
		var z := -10.0 + (i / cols) * 4.6
		if not fxsel.is_empty():
			x = -6.75 + (i % cols) * 4.5
			z = -5.0 + (i / cols) * 4.6
		var p := Vector3(x, 0, z)
		fx_slots.append({"name": names[i], "pos": p, "next": 0.2 + (i % 5) * 0.15})
		var l := Label3D.new()
		l.text = names[i]
		l.font_size = 40; l.outline_size = 10; l.pixel_size = 0.01
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = p + Vector3(0, 0.2, 1.7)
		l.modulate = Color(1, 0.95, 0.8)
		add_child(l)
	if fxsel.is_empty():
		_cam_at(Vector3(0, 27, 20), Vector3(0, 0, 0.5))
	else:
		_cam_at(Vector3(0, 13, 9.5), Vector3(0, 0, -1.2))

func _target_for(p: Vector3, kind: String) -> Node3D:
	var key := "tgt_%s" % str(p)
	if persist.has(key) and is_instance_valid(persist[key]):
		return persist[key]
	var u := Art.create_unit(kind)
	add_child(u)
	u.position = p
	persist[key] = u
	return u

func _fire_fx(slot: Dictionary) -> void:
	var n: String = slot["name"]
	var p: Vector3 = slot["pos"]
	var o := {"pos": p}
	match n:
		"hit": o["color"] = Color(1.0, 0.7, 0.3)
		"death_burst": o["color"] = Color(0.9, 0.4, 1.0); o["size"] = 1.0
		"gold": o["amount"] = 25
		"damage_number": o["amount"] = randi_range(12, 180); o["crit"] = randf() < 0.4
		"tether_pull": o["radius"] = 2.0
		"slip_trail": o["from"] = p + Vector3(-1.8, 0, 1.0); o["to"] = p + Vector3(1.8, 0, -1.0)
		"sacrifice_explosion": o["radius"] = 2.0
		"slam": o["radius"] = 2.0
		"telegraph_circle": o["radius"] = 1.8; o["duration"] = 1.6
		"telegraph_line": o["from"] = p + Vector3(-1.9, 0, 1.2); o["to"] = p + Vector3(1.9, 0, -1.2); o["width"] = 1.2; o["duration"] = 1.6
		"aim_circle": o["radius"] = 1.6
		"aim_line": o["from"] = p + Vector3(-1.8, 0, 1.0); o["to"] = p + Vector3(1.8, 0, -1.0); o["width"] = 0.9
		"ash_wall": o["from"] = p + Vector3(-1.8, 0, 0.6); o["to"] = p + Vector3(1.8, 0, -0.6); o["duration"] = 2.4
		"foundry_aura": o["target"] = _target_for(p, "ashwarden"); o["duration"] = 2.6
		"mark": o["target"] = _target_for(p, "gnawer")
		"rally_marker": o["duration"] = 2.6
		"carapace": o["target"] = _target_for(p, "hivemother"); o["duration"] = 2.6
		"bloater_pool": o["radius"] = 1.7; o["duration"] = 2.6
		"beam": o["from"] = p + Vector3(-1.9, 1.2, 0); o["to"] = p + Vector3(1.9, 1.2, 0); o["width"] = 0.9; o["duration"] = 2.6
		"cone": o["dir"] = Vector3(0.3, 0, -1); o["range"] = 2.6; o["angle"] = 100.0; o["color"] = Color(1.0, 0.25, 0.3)
		"ring_burst": o["radius"] = 2.0; o["color"] = Color(0.85, 0.65, 0.4)
		"explosion": o["radius"] = 1.8
		"soul_wisp": o["from"] = p + Vector3(-1.8, 0, 1.0); o["to"] = p + Vector3(1.6, 1.2, -1.0)
		"zone": o["radius"] = 1.8; o["duration"] = 2.6; o["color"] = Color(1.0, 0.85, 0.4)
		"stone_ridge": o["from"] = p + Vector3(-1.8, 0, 0.6); o["to"] = p + Vector3(1.8, 0, -0.6); o["duration"] = 2.4
		"grave_marker": o["duration"] = 2.8
	var node := Art.fx(n, o)
	if n in FX_PERSIST:
		slot["node"] = node
		slot["born"] = t
		if n in ["aim_circle", "aim_line", "mark"]:
			slot["next"] = t + 2.6
			get_tree().create_timer(2.4).timeout.connect(func(): if is_instance_valid(node): node.stop())
		else:
			slot["next"] = t + 3.0
	else:
		slot["next"] = t + 1.6

func _tick_fx(_dt: float) -> void:
	for s in fx_slots:
		if t >= s["next"]:
			_fire_fx(s)
		var node = s.get("node")
		if node != null and is_instance_valid(node):
			var n: String = s["name"]
			var lt: float = t - float(s["born"])
			var p: Vector3 = s["pos"]
			if n == "beam":
				var a := lt * 1.6
				node.set_params({"from": p + Vector3(0, 1.2, 0), "to": p + Vector3(cos(a) * 2.0, 1.2, sin(a) * 2.0)})
			elif n == "aim_circle":
				node.set_params({"pos": p + Vector3(sin(lt * 2.0) * 0.4, 0, cos(lt * 2.0) * 0.3)})
			elif n == "aim_line":
				var a2 := sin(lt) * 0.6
				node.set_params({"from": p + Vector3(-1.8, 0, 0), "to": p + Vector3(-1.8 + cos(a2) * 3.6, 0, sin(a2) * 3.6)})

# ------------------------------------------------------------------ game composition / perf

func _build_game(n: int) -> void:
	game_hero = Art.create_unit("ashwarden")
	add_child(game_hero)
	game_hero.position = Vector3(2.0, 0, 6.0)
	game_hero.set_state("attack")
	units.append({"u": game_hero, "phase": 0.0, "idx": -1})
	var kinds := ENEMIES
	var rng := RandomNumberGenerator.new(); rng.seed = 4
	for i in n:
		var k: String = kinds[i % kinds.size()]
		var a := rng.randf() * TAU
		var r := 2.5 + rng.randf() * 9.0
		var u := Art.create_unit(k)
		add_child(u)
		u.position = game_hero.position + Vector3(cos(a) * r * 1.3, 0, sin(a) * r * 0.8)
		u.look_at(game_hero.position + Vector3(0, 0, 0.001), Vector3.UP)
		u.rotate_y(PI)
		u.set_state("run")
		game_enemies.append(u)
	for k in ["broodling", "ember_totem"]:
		var s := Art.create_unit(k)
		add_child(s)
		s.position = game_hero.position + Vector3(-1.6 if k == "ember_totem" else 1.4, 0, 1.2)
	var boss := Art.create_unit("pit_brute")
	add_child(boss)
	boss.position = Vector3(-4.0, 0, -4.5)
	boss.rotation_degrees.y = 200
	var pr := Art.create_projectile("fire_bolt")
	add_child(pr)
	pr.position = game_hero.position + Vector3(-1.0, 1.1, -2.0)
	Art.fx("telegraph_circle", {"pos": boss.position + Vector3(2.0, 0, 3.0), "radius": 3.0, "duration": 30.0})
	Art.fx("foundry_aura", {"target": game_hero, "duration": 60.0})
	_cam_at(game_hero.position + Vector3(0, 18, 14), game_hero.position)

func _tick_game(dt: float) -> void:
	for u in game_enemies:
		if not is_instance_valid(u):
			continue
		var to: Vector3 = game_hero.position - u.position
		to.y = 0
		if to.length() > 1.6:
			u.position += to.normalized() * dt * 1.2
		else:
			u.set_state("attack")
	if fmod(t, 1.4) < dt:
		game_hero.set_state("attack")
		Art.fx("damage_number", {"pos": game_hero.position + Vector3(0, 0, -1.5), "amount": randi_range(20, 90), "crit": randf() < 0.3})
		Art.fx("hit", {"pos": game_hero.position + Vector3(0, 1, -1.4)})

# ------------------------------------------------------------------ 2D views

func _ui_root() -> Control:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = Art.make_theme()
	layer.add_child(root)
	return root

func _build_icons() -> void:
	var root := _ui_root()
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.055, 0.045, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	var ids: Array = load("res://art/icons.gd").all_ids()
	var big := ids.size() <= 40
	grid.columns = 10 if big else 13
	grid.position = Vector2(20, 14) if big else Vector2(12, 8)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	root.add_child(grid)
	var Icons = load("res://art/icons.gd")
	for id in Icons.all_ids():
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var tr := TextureRect.new()
		tr.texture = Art.icon(id)
		tr.custom_minimum_size = Vector2(112, 112) if big else Vector2(80, 80)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		v.add_child(tr)
		var l := Label.new()
		l.text = id
		l.theme_type_variation = "SmallLabel"
		l.add_theme_font_size_override("font_size", 12 if big else 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(118, 0) if big else Vector2(84, 0)
		l.clip_text = true
		v.add_child(l)
		grid.add_child(v)
	# small-size readability strip (64 px)
	var strip := HBoxContainer.new()
	strip.position = Vector2(20, 660)
	root.add_child(strip)

func _build_ui() -> void:
	var root := _ui_root()
	# HUD-like top bar
	var top := PanelContainer.new()
	top.theme_type_variation = "DarkPanel"
	top.position = Vector2(16, 12)
	root.add_child(top)
	var th := HBoxContainer.new()
	top.add_child(th)
	var por := TextureRect.new(); por.texture = Art.icon("portrait_ashwarden"); por.custom_minimum_size = Vector2(84, 84)
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; th.add_child(por)
	var bars := VBoxContainer.new(); bars.custom_minimum_size = Vector2(300, 0); th.add_child(bars)
	for b in [["HpBar", 0.72, "820 / 1140"], ["ManaBar", 0.45, "140 / 310"], ["XpBar", 0.3, "Lv 7"]]:
		var pb := ProgressBar.new(); pb.theme_type_variation = b[0]; pb.value = b[1] * 100.0
		pb.custom_minimum_size = Vector2(300, 22); pb.show_percentage = false
		var l := Label.new(); l.text = b[2]; l.theme_type_variation = "SmallLabel"
		l.set_anchors_preset(Control.PRESET_FULL_RECT); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pb.add_child(l)
		bars.add_child(pb)
	var stats := HBoxContainer.new(); th.add_child(stats)
	for s in [["gold", "1,240"], ["life", "3"], ["attack", "64"], ["armor", "12"], ["speed", "330"]]:
		var tr := TextureRect.new(); tr.texture = Art.icon(s[0]); tr.custom_minimum_size = Vector2(34, 34)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; stats.add_child(tr)
		var l := Label.new(); l.text = s[1]; stats.add_child(l)
	var pause := Button.new(); pause.icon = Art.icon("pause"); pause.expand_icon = true; pause.custom_minimum_size = Vector2(96, 96)
	pause.position = Vector2(1170, 12); root.add_child(pause)
	# boss bar
	var boss := VBoxContainer.new(); boss.position = Vector2(390, 120); root.add_child(boss)
	var bl := Label.new(); bl.text = "THE PIT BRUTE"; bl.theme_type_variation = "BannerLabel"; bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.add_theme_font_size_override("font_size", 30)
	boss.add_child(bl)
	var bb := ProgressBar.new(); bb.theme_type_variation = "BossBar"; bb.value = 63; bb.custom_minimum_size = Vector2(500, 30); boss.add_child(bb)
	var fb := ProgressBar.new(); fb.theme_type_variation = "FlowBar"; fb.value = 80; fb.custom_minimum_size = Vector2(500, 14); fb.show_percentage = false; boss.add_child(fb)
	# center banner + title
	var title := Label.new(); title.text = "EMBERPIT"; title.theme_type_variation = "TitleLabel"; title.position = Vector2(470, 200); root.add_child(title)
	var ban := Label.new(); ban.text = "Wave 5  -  The Pit Brute"; ban.theme_type_variation = "BannerLabel"; ban.position = Vector2(380, 270); root.add_child(ban)
	# shop frame
	var shop := PanelContainer.new(); shop.theme_type_variation = "FramePanel"; shop.position = Vector2(24, 340); shop.custom_minimum_size = Vector2(560, 360)
	root.add_child(shop)
	var sv := VBoxContainer.new(); shop.add_child(sv)
	var tabs := TabBar.new(); tabs.add_tab("Basic"); tabs.add_tab("Advanced"); tabs.add_tab("Consumables"); sv.add_child(tabs)
	var sg := GridContainer.new(); sg.columns = 2; sv.add_child(sg)
	var items := [["iron_knuckles", "Iron Knuckles", "250"], ["vigor_charm", "Vigor Charm", "300"], ["emberbrand", "Emberbrand", "400"], ["wardens_aegis", "Warden's Aegis", "900"]]
	for i in items.size():
		var b := Button.new(); b.theme_type_variation = "ShopItemButton"; b.text = "%s\n%s g" % [items[i][1], items[i][2]]
		b.icon = Art.icon(items[i][0]); b.expand_icon = true; b.custom_minimum_size = Vector2(260, 96)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = i == 3
		sg.add_child(b)
	var hb := HBoxContainer.new(); sv.add_child(hb)
	var buy := Button.new(); buy.text = "BUY"; buy.theme_type_variation = "PrimaryButton"; buy.custom_minimum_size = Vector2(200, 72); hb.add_child(buy)
	var sell := Button.new(); sell.text = "Sell"; sell.custom_minimum_size = Vector2(160, 72); hb.add_child(sell)
	var small := Label.new(); small.text = "Selling refunds 50%"; small.theme_type_variation = "SmallLabel"; hb.add_child(small)
	# skill buttons (bottom right)
	var skills := ["ember_totem", "ash_wall", "tether_pull", "foundry_heart"]
	var pos := [Vector2(880, 600), Vector2(890, 470), Vector2(1010, 400), Vector2(1140, 400)]
	for i in skills.size():
		var b := Button.new(); b.theme_type_variation = "SkillButton"; b.icon = Art.icon(skills[i]); b.expand_icon = true
		b.custom_minimum_size = Vector2(112, 112); b.position = pos[i]
		b.disabled = i == 3
		root.add_child(b)
	var atk := Button.new(); atk.theme_type_variation = "SkillButton"; atk.icon = Art.icon("attack"); atk.expand_icon = true
	atk.custom_minimum_size = Vector2(150, 150); atk.position = Vector2(1060, 540); root.add_child(atk)
	var dp := PanelContainer.new(); dp.theme_type_variation = "DarkPanel"; dp.position = Vector2(620, 360); root.add_child(dp)
	var dl := Label.new(); dl.text = "Prep  0:14\nTap the shop to spend gold."; dp.add_child(dl)
	var plain := PanelContainer.new(); plain.position = Vector2(620, 470); root.add_child(plain)
	var pl := Label.new(); pl.text = "Plain PanelContainer"; plain.add_child(pl)

# ------------------------------------------------------------------ loop + capture

func _process(dt: float) -> void:
	if view == "occlude" and OS.get_cmdline_user_args().has("--nofade"):
		Art.set_focus(cam.global_position + Vector3(0, 1, 0))  # degenerate capsule = no fade
	t += dt
	_cycle_units(dt)
	if view == "fx":
		_tick_fx(dt)
	if view in ["game", "perf"] and game_hero:
		_tick_game(dt)
	for p in projs:
		p.position.x += sin(t * 2.0 + p.position.z) * dt * 0.3
	if t > 1.0:
		_perf_frames += 1
		for k in ["dc", "prim", "obj"]:
			var v := 0.0
			match k:
				"dc": v = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				"prim": v = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
				"obj": v = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			_perf_acc[k] = maxf(_perf_acc.get(k, 0.0), v)

func _take_shot() -> void:
	if _shot_done:
		return
	_shot_done = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shot.get_base_dir())
	img.save_png(shot)
	print("ART_PREVIEW view=%s shot=%s draw_calls=%d primitives=%d objects=%d fps=%.1f" % [view, shot,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Engine.get_frames_per_second()])
	var vp := get_viewport().get_viewport_rid()
	print("ART_PREVIEW split draw calls: 3d=%d canvas=%d (canvas items=%d)" % [
		RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)])
	print("ART_PREVIEW max draw_calls=%d max primitives=%d" % [_perf_acc.get("dc", 0), _perf_acc.get("prim", 0)])
	get_tree().quit()
