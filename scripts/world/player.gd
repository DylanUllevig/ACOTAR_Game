extends CharacterBody2D
## Feyre in the overworld: weighty-but-cozy movement (acceleration and
## friction), 4-direction walk cycle, footprints in snow, nearest-interactable
## prompt.

const ACCEL := 1500.0
const FRICTION := 1700.0
const SPEED := 230.0
const SPRINT := 340.0

var sprite: Sprite2D
var facing = 0  # 0 down, 1 left, 2 right, 3 up
var anim_t = 0.0
var footprints = false
var auto_move = Vector2.ZERO   # cutscenes can drive her
var _foot_timer = 0.0
var _left_foot = false
var _near: Node = null
var locked = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 14
	cs.shape = c
	add_child(cs)
	sprite = Sprite2D.new()
	sprite.texture = Art.lit("actors/feyre.png")
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.scale = Vector2(1.7, 1.7)
	sprite.offset = Vector2(0, -32)
	add_child(sprite)
	var region = get_parent().get_parent()
	footprints = region != null and "snow_amount" in region and region.snow_amount > 0


func can_act() -> bool:
	return not (Dialogue.active or UI.modal_open or Router.busy or locked)


func _physics_process(delta: float) -> void:
	var input = Vector2.ZERO
	if can_act():
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if auto_move != Vector2.ZERO:
		input = auto_move
	var max_speed = SPRINT if Input.is_action_pressed("sprint") else SPEED
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input.normalized() * max_speed, ACCEL * delta)
		if abs(input.x) > abs(input.y):
			facing = 1 if input.x < 0 else 2
		else:
			facing = 3 if input.y < 0 else 0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	var spd = velocity.length()
	if spd > 10:
		anim_t += delta * (spd / 60.0)
		sprite.frame = facing * 4 + int(anim_t) % 4
		if footprints:
			_foot_timer -= delta
			if _foot_timer <= 0:
				_foot_timer = 0.28 * SPEED / max(spd, 1.0)
				_drop_footprint()
	else:
		sprite.frame = facing * 4
	_update_prompt()


func _drop_footprint() -> void:
	var f = Sprite2D.new()
	f.texture = Art.tex("fx/footprint.png")
	_left_foot = not _left_foot
	var side = Vector2(-6 if _left_foot else 6, 0).rotated(velocity.angle() + PI / 2)
	f.global_position = global_position + side
	f.rotation = velocity.angle() + PI / 2
	f.z_index = -5
	f.modulate.a = 0.8
	get_parent().get_parent().add_child(f)
	var tw = f.create_tween()
	tw.tween_interval(10.0)
	tw.tween_property(f, "modulate:a", 0.0, 6.0)
	tw.tween_callback(f.queue_free)


func _update_prompt() -> void:
	var best: Node = null
	var best_d = INF
	if can_act():
		for n in get_tree().get_nodes_in_group("interactable"):
			if not n.is_inside_tree() or not n.enabled:
				continue
			var d = global_position.distance_to(n.global_position)
			if d < n.radius and d < best_d:
				best = n
				best_d = d
	_near = best
	UI.set_prompt("[E]  " + best.label if best else "")


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("interact") and _near and can_act():
		get_viewport().set_input_as_handled()
		var n = _near
		UI.set_prompt("")
		n.activate()
