extends CharacterBody2D
## Feyre in the overworld. Weighty-but-cozy movement (acceleration, friction),
## and whatever is selected on the hotbar on the left mouse button, aimed at
## the cursor: slash with the knife, hold to draw the bow and release to loose,
## eat to heal. Mouse wheel or 1 to 0 picks the hotbar slot. Taking a hit
## knocks her back and gives a moment of invulnerability. Footprints in snow,
## footsteps, the nearest-interactable prompt, camera look-ahead while aiming.

signal died
signal shot_fired(ammo_id: String)

const ACCEL := 1600.0
const FRICTION := 1800.0
const SPEED := 230.0
const SPRINT := 330.0
const ARROW := preload("res://scripts/combat/arrow.gd")
const HAND_Y := -34.0

var sprite: Sprite2D
var hand: Node2D
var held: Sprite2D           # the selected weapon, shown while it is in use
var nocked: Sprite2D         # arrow on the string while drawing
var facing = 0               # 0 down, 1 left, 2 right, 3 up
var anim_t = 0.0
var footprints = false
var surface = "snow"
var auto_move = Vector2.ZERO # cutscenes can drive her
var locked = false
var combat_allowed = true
var camera: Camera2D
var terrain_mult := 1.0      # set by the region: brambles and deep snow slow her
var bot_aim: Variant = null   # automated tests aim at this world point instead of the mouse

var aim := Vector2.RIGHT
var drawing := false
var draw_t := 0.0
var draw_item := ""
var draw_ammo := ""
var _draw_full_played := false
var slash_cd := 0.0
var _slash_flip := false
var _slash_pending := -1.0
var _slash_def := {}
var action := ""             # "slash" | "eat" | ""
var action_t := 0.0
var _show_held := 0.0
var invuln := 0.0
var knock := Vector2.ZERO
var _walk := Vector2.ZERO      # the walking part of velocity, without knockback
var dead := false
var _heal_left := 0           # whole HP still to restore from food
var _heal_rate := 0.0
var _kb_aim := false
var _look := Vector2.ZERO
var _shake := 0.0

var _near: Node = null
var _foot_timer = 0.0
var _left_foot = false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 8
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 14
	cs.shape = c
	add_child(cs)
	var sh = Sprite2D.new()
	sh.texture = Art.tex("fx/shadow.png")
	sh.modulate = Color(0.05, 0.06, 0.12, 0.45)
	sh.scale = Vector2(0.75, 0.4)
	sh.z_index = -1
	add_child(sh)
	sprite = Sprite2D.new()
	sprite.texture = Art.lit("actors/feyre.png")
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.scale = Vector2(1.7, 1.7)
	sprite.offset = Vector2(0, -32)
	add_child(sprite)
	hand = Node2D.new()
	hand.position = Vector2(0, HAND_Y)
	add_child(hand)
	held = Sprite2D.new()
	held.visible = false
	hand.add_child(held)
	nocked = Sprite2D.new()
	nocked.texture = Art.tex("fx/arrow.png")
	nocked.visible = false
	hand.add_child(nocked)
	var region = get_parent().get_parent()
	footprints = region != null and "snow_amount" in region and region.snow_amount > 0
	if region != null and "surface" in region:
		surface = region.surface
	if region != null and "combat_allowed" in region:
		combat_allowed = region.combat_allowed
	GameState.hotbar_changed.connect(_on_hotbar_changed)


func can_act() -> bool:
	return not (Dialogue.active or UI.modal_open or Router.busy or locked or dead)


func is_sprinting() -> bool:
	return Input.is_action_pressed("sprint") and velocity.length() > SPEED * 1.08 and not drawing


# ------------------------------------------------------------------ frame
func _physics_process(delta: float) -> void:
	var free = can_act()
	if not free and drawing:
		_cancel_draw()
	slash_cd = max(0.0, slash_cd - delta)
	invuln = max(0.0, invuln - delta)
	_show_held = max(0.0, _show_held - delta)
	if action_t > 0.0:
		action_t -= delta
		if action_t <= 0.0:
			action = ""
	if _slash_pending >= 0.0:
		_slash_pending -= delta
		if _slash_pending < 0.0:
			_slash_strike()
	if _heal_left > 0 and free:
		# whole points over about a second, so food never loses a point to rounding
		_heal_acc += _heal_rate * delta
		var n = mini(int(_heal_acc), _heal_left)
		if n > 0:
			_heal_acc -= n
			_heal_left -= n
			GameState.heal(n)
		if _heal_left <= 0:
			_heal_acc = 0.0
			_heal_rate = 0.0
	_update_aim()
	if drawing:
		draw_t += delta
		var full = _draw_time()
		if draw_t >= full and not _draw_full_played:
			_draw_full_played = true
			Audio.sfx("bow_full", -10.0)
	# movement
	var input = Vector2.ZERO
	if free:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if auto_move != Vector2.ZERO:
		input = auto_move
	var max_speed = SPEED * GameState.speed_mult * terrain_mult
	if Input.is_action_pressed("sprint") and not drawing and action != "eat" and free:
		max_speed = SPRINT * GameState.speed_mult * terrain_mult
	if drawing:
		max_speed *= 0.42
	elif action == "slash":
		max_speed *= 0.6
	elif action == "eat":
		max_speed *= 0.5
	if input != Vector2.ZERO and not dead:
		_walk = _walk.move_toward(input.normalized() * max_speed, ACCEL * delta)
		if not _aiming():
			if abs(input.x) > abs(input.y):
				facing = 1 if input.x < 0 else 2
			else:
				facing = 3 if input.y < 0 else 0
	else:
		_walk = _walk.move_toward(Vector2.ZERO, FRICTION * delta)
	if _aiming():
		facing = _dir_index(aim)
	# knockback rides on top of walking and decays on its own; it is never
	# folded into the walking speed, or a hit would launch her across the map
	velocity = _walk + knock
	move_and_slide()
	knock = knock.move_toward(Vector2.ZERO, 2600.0 * delta)
	_animate(delta)
	_update_held()
	_update_camera(delta)
	_update_prompt()


var _heal_acc := 0.0


func _aiming() -> bool:
	return drawing or action == "slash"


func _dir_index(v: Vector2) -> int:
	if abs(v.x) > abs(v.y):
		return 1 if v.x < 0 else 2
	return 3 if v.y < 0 else 0


func _facing_vec() -> Vector2:
	return [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP][facing]


func _update_aim() -> void:
	if bot_aim != null:
		var v: Vector2 = (bot_aim as Vector2) - (global_position + Vector2(0, HAND_Y))
		if v.length() > 1.0:
			aim = v.normalized()
		return
	if _kb_aim:
		aim = _facing_vec()
		return
	var m = get_global_mouse_position() - (global_position + Vector2(0, HAND_Y))
	if m.length() > 4.0:
		aim = m.normalized()


func _animate(delta: float) -> void:
	if dead:
		return
	var spd = velocity.length()
	if spd > 10:
		anim_t += delta * (spd / 60.0)
		sprite.frame = facing * 4 + int(anim_t) % 4
		_foot_timer -= delta
		if _foot_timer <= 0:
			_foot_timer = 0.3 * SPEED / max(spd, 1.0)
			_left_foot = not _left_foot
			Audio.sfx("step_" + surface, -14.0 if spd < SPEED * 1.1 else -10.0, 0.12)
			if footprints:
				_drop_footprint()
	else:
		sprite.frame = facing * 4
	# hurt blink and eating bob
	if invuln > 0.0:
		sprite.modulate.a = 0.35 if int(invuln * 14.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0
	sprite.position.y = -2.0 * absf(sin(action_t * 18.0)) if action == "eat" else 0.0


# ------------------------------------------------------------------ input
func _unhandled_input(ev: InputEvent) -> void:
	if not can_act():
		return
	if ev is InputEventMouseMotion:
		_kb_aim = false
		return
	if ev.is_action_pressed("use_item"):
		_kb_aim = not (ev is InputEventMouseButton)
		get_viewport().set_input_as_handled()
		_use_pressed()
	elif ev.is_action_released("use_item"):
		get_viewport().set_input_as_handled()
		if drawing:
			_release()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		if drawing:
			_cancel_draw()
		else:
			_interact()
	elif ev.is_action_pressed("hotbar_next"):
		get_viewport().set_input_as_handled()
		GameState.select_hotbar(GameState.hotbar_index + 1)
	elif ev.is_action_pressed("hotbar_prev"):
		get_viewport().set_input_as_handled()
		GameState.select_hotbar(GameState.hotbar_index - 1)
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode >= KEY_0 and ev.keycode <= KEY_9:
		get_viewport().set_input_as_handled()
		var n = ev.keycode - KEY_1
		if ev.keycode == KEY_0:
			n = 9
		GameState.select_hotbar(n)
	elif ev.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_interact()


func _interact() -> void:
	if _near and can_act():
		var n = _near
		UI.set_prompt("")
		n.activate()


func _on_hotbar_changed(_i: int) -> void:
	if drawing:
		_cancel_draw()
	Audio.ui("hotbar", -12.0)


# ------------------------------------------------------------- using items
func _use_pressed() -> void:
	var id = GameState.selected_item_id()
	if id == "":
		return
	var d: Dictionary = DB.item(id)
	match String(d.get("use", "")):
		"knife":
			if _combat_ok():
				_slash(d)
		"bow":
			if _combat_ok():
				_begin_draw(id, d)
		"eat":
			_eat(id, d)
		_:
			UI.toast(String(d.get("name", id)) + ": " + String(d.get("text", "")))


func _combat_ok() -> bool:
	if combat_allowed:
		return true
	UI.toast("Not here.")
	return false


func _slash(d: Dictionary) -> void:
	if slash_cd > 0.0 or action == "eat":
		return
	slash_cd = float(d.get("cooldown", 0.34))
	action = "slash"
	action_t = 0.24
	_show_held = 0.35
	_slash_flip = not _slash_flip
	_slash_def = d
	_slash_pending = 0.05
	held.texture = Art.tex("fx/knife.png")
	Audio.sfx("knife_swing", -4.0, 0.1)
	var origin = global_position + Vector2(0, HAND_Y)
	Fx.slash(self, origin + aim * 34.0, aim.angle(), _slash_flip, float(d.get("reach", 80)))


func _slash_strike() -> void:
	var d = _slash_def
	var origin = global_position + Vector2(0, HAND_Y)
	var reach = float(d.get("reach", 80))
	var half = deg_to_rad(float(d.get("arc_deg", 120)) * 0.5)
	var dmg = int(round(float(d.get("damage", 7)) * GameState.damage_mult))
	var any = false
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead or not c.is_inside_tree():
			continue
		var v: Vector2 = c.hurt_center() - origin
		var edge = v.length() - float(c.hurt_radius)
		if edge > reach:
			continue
		if edge > 18.0 and absf(angle_difference(aim.angle(), v.angle())) > half:
			continue
		any = true
		c.take_hit({"damage": dmg, "kind": "knife", "dir": v.normalized(), "knockback": float(d.get("knockback", 220)),
			"source": self, "at": origin + v.normalized() * min(v.length(), reach * 0.8)})
	if any:
		Audio.sfx("knife_hit", -2.0, 0.08)
		UI.shake(4.0)


func _draw_time() -> float:
	return float(DB.item("bow").get("draw_time", 0.8)) / max(0.1, GameState.draw_mult)


func _begin_draw(id: String, d: Dictionary) -> void:
	if drawing or action == "eat":
		return
	if not GameState.has_item("bow"):
		UI.toast("You need your bow for that.")
		return
	var ammo = String(d.get("ammo", "arrow"))
	if GameState.count(ammo) <= 0:
		UI.toast("No %s left." % ("ash arrow" if ammo == "ash_arrow" else "arrows"))
		Audio.sfx("dry_click", -6.0)
		return
	drawing = true
	draw_t = 0.0
	draw_item = id
	draw_ammo = ammo
	_draw_full_played = false
	held.texture = Art.tex("fx/bow.png")
	nocked.texture = Art.tex("fx/ash_arrow.png" if ammo == "ash_arrow" else "fx/arrow.png")
	Audio.sfx("bow_draw", -6.0, 0.05)


func draw_fraction() -> float:
	return clampf(draw_t / _draw_time(), 0.0, 1.0) if drawing else 0.0


func _release() -> void:
	var frac = draw_fraction()
	drawing = false
	nocked.visible = false
	if frac < 0.2:
		return  # not drawn far enough to loose; nothing spent
	if not GameState.remove_item(draw_ammo, 1):
		return
	var bow: Dictionary = DB.item("bow")
	var f = pow(frac, 1.3)
	var dmg = lerpf(float(bow.get("min_damage", 6)), float(bow.get("max_damage", 18)), f) * GameState.damage_mult
	var effect = ""
	if draw_ammo != "arrow":
		var ad: Dictionary = DB.item(draw_ammo)
		dmg += float(ad.get("bonus_damage", 0))
		effect = String(ad.get("effect", ""))
	var speed = lerpf(float(bow.get("speed_min", 700)), float(bow.get("speed_max", 1350)), frac)
	var a = ARROW.new()
	var origin = global_position + Vector2(0, HAND_Y) + aim * 30.0
	a.setup(origin, aim, speed, int(round(dmg)), draw_ammo, effect, float(bow.get("range", 1000)) * (0.6 + 0.4 * frac), self)
	var host = get_parent()
	host.add_child(a)
	_show_held = 0.3
	knock -= aim * 40.0
	GameState.bump("arrows_shot")
	Audio.sfx("bow_release", -2.0, 0.06)
	shot_fired.emit(draw_ammo)
	# hares bolt at the sound
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.has_method("spook") and c.global_position.distance_to(global_position) < 500.0:
			c.spook()


func _cancel_draw() -> void:
	drawing = false
	nocked.visible = false


func _eat(id: String, d: Dictionary) -> void:
	if action == "eat":
		return
	if GameState.hp >= GameState.max_hp:
		UI.toast("You're not hurt.")
		return
	if not GameState.remove_item(id, 1):
		return
	if drawing:
		_cancel_draw()
	action = "eat"
	action_t = 0.6
	_heal_left += int(d.get("heal", 5))
	_heal_rate = max(_heal_rate, float(d.get("heal", 5)) / 1.2)
	GameState.bump("food_eaten")
	Audio.sfx("eat", -4.0, 0.08)
	Fx.burst(self, global_position + Vector2(0, -60), Vector2.UP, Color(1.0, 0.85, 0.5), 10, 60.0, 0.5)


# ------------------------------------------------------------ held weapon
func _update_held() -> void:
	var show = drawing or _show_held > 0.0
	held.visible = show
	if not show:
		nocked.visible = false
		return
	hand.rotation = aim.angle()
	# behind her when aiming up, in front otherwise
	hand.z_index = -1 if facing == 3 else 1
	var vflip = aim.x < 0.0
	held.flip_v = vflip
	if drawing:
		var f = draw_fraction()
		held.position = Vector2(24, 0)
		nocked.visible = true
		nocked.position = Vector2(24 - 22.0 * f, 0)
		nocked.flip_v = vflip
		held.scale = Vector2(1.0 - 0.06 * f, 1.0 + 0.04 * f)
	else:
		nocked.visible = false
		held.scale = Vector2.ONE
		if action == "slash":
			# sweep the blade through the arc
			var k = 1.0 - clampf(action_t / 0.24, 0.0, 1.0)
			var sweep = lerpf(-1.0, 1.0, k) * (1.0 if _slash_flip else -1.0)
			held.position = Vector2(26, 0).rotated(sweep * 0.9)
			held.rotation = sweep * 0.9
		else:
			held.position = Vector2(24, 0)
			held.rotation = 0.0


# --------------------------------------------------------------- damage
func take_damage(amount: int, from: Vector2, push: Vector2, _source: Node = null) -> void:
	if dead or invuln > 0.0 or locked:
		return
	GameState.set_hp(GameState.hp - amount)
	invuln = 0.9
	knock = push
	if drawing:
		_cancel_draw()
	var dir = (global_position - from).normalized()
	Fx.burst(self, global_position + Vector2(0, -40), dir, Color(0.62, 0.05, 0.08), 14, 240.0, 0.9)
	Fx.blood_decals(self, global_position, dir, 2)
	Fx.number(self, global_position + Vector2(0, -70), amount, Color(1.0, 0.35, 0.3), amount >= 8)
	UI.shake(10.0)
	UI.hurt_flash()
	Fx.hitstop(self, 0.07)
	Audio.sfx("player_hurt", 0.0, 0.08)
	if GameState.hp <= 0:
		_die()


func _die() -> void:
	dead = true
	drawing = false
	velocity = Vector2.ZERO
	_walk = Vector2.ZERO
	Audio.sfx("player_down", 0.0)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sprite, "rotation", PI / 2.0, 0.5).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sprite, "modulate", Color(0.7, 0.6, 0.65), 0.8)
	died.emit()


# ---------------------------------------------------------------- camera
func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var want = aim * 110.0 * draw_fraction() if drawing else Vector2.ZERO
	_look = _look.lerp(want, 1.0 - exp(-6.0 * delta))
	_shake = UI.take_shake(delta)
	var jitter = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	camera.offset = _look + jitter


# ------------------------------------------------------------- footprints
func _drop_footprint() -> void:
	var f = Sprite2D.new()
	f.texture = Art.tex("fx/footprint.png")
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


# ----------------------------------------------------------------- prompt
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
	UI.set_prompt(best.label if best else "")
