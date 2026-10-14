class_name Unit
extends RefCounted
## Base logical unit. The visual is a Node3D from Art.create_unit(); all logic is kinematic math.

var kind := ""
var team := 0                 # 0 = hero side, 1 = enemies
var node: Node3D
var pos := Vector3.ZERO
var facing := Vector3(0, 0, -1)
var radius := 0.5
var height := 1.8
var hp := 100.0
var hurt_at := -100.0          # run_time of the last damage taken (world HP bar visibility)
var max_hp := 100.0
var armor := 0.0
var base_speed := 4.0
var alive := true
var removed := false
var death_t := 0.0

var atk_dmg := 10.0
var atk_range := 1.2
var atk_time := 1.0
var atk_cd := 0.0
var atk_wind := 0.0            # >0 while an attack wind-up is in progress
var atk_target: Unit = null
var target: Unit = null
var retarget_t := 0.0

var slow_amt := 0.0
var slow_t := 0.0
var stun_t := 0.0
var invuln_t := 0.0
var burn_dps := 0.0
var burn_t := 0.0
var burn_src: Unit = null
var burn_tick := 0.0
var taunt_target: Unit = null
var taunt_t := 0.0
var mark_t := 0.0
var mark_fx: Node = null
var spit_mark_t := 0.0
var knock := Vector3.ZERO     # knockback velocity
var pull_to := Vector3.ZERO
var pull_t := 0.0

var is_boss := false
var is_summon := false
var targetable := true         # enemies can pick it as a target
var untargetable := false      # hero side can't target (burrowed)
var collides := true
var blocks_front := false      # shieldbearer
var no_push := false           # totems, bosses
var lifetime := -1.0
var vis_state := ""
var moving := false
var run: Run


func setup_visual(n: Node3D) -> void:
	node = n
	if n == null:
		return
	if "radius" in n:
		var r = n.get("radius")
		if typeof(r) == TYPE_FLOAT or typeof(r) == TYPE_INT:
			radius = maxf(0.2, float(r))
	if "height" in n:
		var h = n.get("height")
		if typeof(h) == TYPE_FLOAT or typeof(h) == TYPE_INT:
			height = maxf(0.5, float(h))


func speed() -> float:
	var s := base_speed
	if slow_t > 0.0:
		s *= (1.0 - clampf(slow_amt, 0.0, 0.8))
	return s


func apply_slow(amount: float, dur: float) -> void:
	if amount >= slow_amt or slow_t <= 0.0:
		slow_amt = amount
	slow_t = maxf(slow_t, dur)


func set_state(s: String, force := false) -> void:
	if node == null or not is_instance_valid(node):
		return
	if s == vis_state and not force and s != "attack" and s != "cast" and s != "hit":
		return
	if s != "attack" and s != "cast" and s != "hit":
		vis_state = s
	if node.has_method("set_state"):
		node.call("set_state", s)


func flash(c: Color) -> void:
	if node and is_instance_valid(node) and node.has_method("flash"):
		node.call("flash", c)


func set_tint(c: Color) -> void:
	if node and is_instance_valid(node) and node.has_method("set_tint"):
		node.call("set_tint", c)


func sync_visual() -> void:
	if node == null or not is_instance_valid(node):
		return
	node.position = pos
	if facing.length_squared() > 0.001:
		var yaw := atan2(-facing.x, -facing.z)
		node.rotation.y = lerp_angle(node.rotation.y, yaw, 0.35)


func face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()


func dist_to(u: Unit) -> float:
	return Vector2(pos.x - u.pos.x, pos.z - u.pos.z).length()


func edge_dist(u: Unit) -> float:
	return dist_to(u) - radius - u.radius


func tick_status(dt: float) -> void:
	if slow_t > 0.0:
		slow_t -= dt
		if slow_t <= 0.0:
			slow_amt = 0.0
	if stun_t > 0.0:
		stun_t -= dt
	if invuln_t > 0.0:
		invuln_t -= dt
	if taunt_t > 0.0:
		taunt_t -= dt
		if taunt_t <= 0.0 or taunt_target == null or not taunt_target.alive:
			taunt_target = null
			taunt_t = 0.0
	if spit_mark_t > 0.0:
		spit_mark_t -= dt
	if mark_t > 0.0:
		mark_t -= dt
		if mark_t <= 0.0:
			clear_mark()
	if atk_cd > 0.0:
		atk_cd -= dt


func clear_mark() -> void:
	mark_t = 0.0
	if mark_fx != null and is_instance_valid(mark_fx) and mark_fx.has_method("stop"):
		mark_fx.call("stop")
	mark_fx = null


func is_marked() -> bool:
	return mark_t > 0.0
