extends Creature
## The wolf in the winter clearing. Phase one: he stalks the doe and ignores
## Feyre unless she gives herself away (the Hunt controller decides that).
## Phase two: he hunts her. Chase, a telegraphed lunge, quick bites when close,
## circling to reset. He heals until an ash arrow strikes him. Below a third of
## his health he gets faster and the lunge tell gets shorter.

signal became_alerted(reason: String)
signal killed_doe
signal ash_hit
signal regen_noticed

enum S { STALK, EAT, ALERT, CHASE, WINDUP, LUNGE, RECOVER, BITE_WINDUP, BITE, CIRCLE, STAGGER, DEAD }

var hunt: Node                # the Hunt controller: player, doe, cover
var lurking := true          # before the hunt: only his eyes show in the brush
var s := S.STALK
var t := 0.0
var alerted := false
var regenerating := false
var _since_hit := 99.0
var _regen_acc := 0.0
var _healed := 0.0
var _noticed := false
var _lunge_dir := Vector2.ZERO
var _bite_dir := Vector2.RIGHT
var _lunge_cd := 0.0
var _struck := false
var _circle_dir := 1.0
var _circle_time := 1.5
var _anim := 0.0
var _recover_time := 0.8
var _bites_in_row := 0
var eyes: Sprite2D
var eye_light: PointLight2D
var _regen_fx: CPUParticles2D
var _growl_cd := 0.0

var eye_pos := Vector2(106, -122)   # where the eyes sit on the art (facing right); from data


func _init() -> void:
	feet_radius = 26.0
	hurt_radius = 62.0
	hurt_offset = Vector2(0, -62)


func build_visual() -> void:
	var art: Dictionary = def.get("art", {})
	sprite.texture = Art.lit(String(art.get("sprite", "actors/wolf.png")))
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0) if sprite.texture else Vector2.ZERO
	var sc = float(art.get("scale", 1.45))
	sprite.scale = Vector2(sc, sc)
	var ep: Array = art.get("eye", [106, -122])
	eye_pos = Vector2(float(ep[0]), float(ep[1]))
	shadow.scale = Vector2(2.2, 1.0)
	shadow.position = Vector2(0, -2)
	eyes = Sprite2D.new()
	eyes.texture = Art.soft_light_texture()
	eyes.scale = Vector2(0.07, 0.035)
	eyes.position = eye_pos
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/fae_glow.gdshader")
	m.set_shader_parameter("glow_color", Color(1.0, 0.78, 0.25))
	m.set_shader_parameter("power", 3.0)
	eyes.material = m
	body.add_child(eyes)
	eye_light = PointLight2D.new()
	eye_light.texture = Art.soft_light_texture()
	eye_light.color = Color(1.0, 0.75, 0.3)
	eye_light.energy = 0.6
	eye_light.texture_scale = 0.35
	eye_light.position = eye_pos
	body.add_child(eye_light)
	_regen_fx = CPUParticles2D.new()
	_regen_fx.amount = 18
	_regen_fx.lifetime = 1.1
	_regen_fx.texture = Art.tex("fx/dot.png")
	_regen_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_regen_fx.emission_rect_extents = Vector2(80, 40)
	_regen_fx.position = Vector2(0, -70)
	_regen_fx.direction = Vector2.UP
	_regen_fx.spread = 20
	_regen_fx.gravity = Vector2(0, -40)
	_regen_fx.initial_velocity_min = 10
	_regen_fx.initial_velocity_max = 30
	_regen_fx.scale_amount_min = 0.2
	_regen_fx.scale_amount_max = 0.45
	_regen_fx.color = Color(0.95, 0.85, 0.45, 0.8)
	var pm = CanvasItemMaterial.new()
	pm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_regen_fx.material = pm
	_regen_fx.emitting = false
	add_child(_regen_fx)


func _go(st: S) -> void:
	s = st
	t = 0.0


func desperate() -> bool:
	return float(hp) / float(max_hp) < float(def.get("desperate_below", 0.35))


func _player() -> Node2D:
	return hunt.player if hunt else null


## Where his jaws are during an attack: ahead of his chest along the line he
## is attacking on. Works in every direction, not just left and right.
func jaws(dir: Vector2) -> Vector2:
	return hurt_center() + dir.normalized() * 70.0


func _jaws_hit(p: Node2D, dir: Vector2, reach: float) -> bool:
	return jaws(dir).distance_to(p.global_position + Vector2(0, -28)) < reach


## Steps out of the brush: the body fades in and he can be hurt.
func emerge() -> void:
	if not lurking:
		return
	lurking = false
	hurtbox.monitorable = true
	hurtbox.collision_layer = LAYER_HURTBOX
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 1.0, 1.2)
	tw.tween_property(shadow, "modulate:a", 0.45, 1.2)


func hide_in_brush() -> void:
	lurking = true
	sprite.modulate.a = 0.0
	shadow.modulate.a = 0.0
	hurtbox.collision_layer = 0


# ------------------------------------------------------------------ brain
func think(delta: float) -> void:
	if lurking:
		velocity = Vector2.ZERO
		return
	t += delta
	_lunge_cd -= delta
	_since_hit += delta
	_growl_cd -= delta
	_regen(delta)
	var p = _player()
	if p == null:
		velocity = Vector2.ZERO
		return
	var to_p: Vector2 = p.global_position - global_position
	var dist = to_p.length()
	var slow = 0.6 if hunt.in_cover(global_position) else 1.0
	var lunge: Dictionary = def.get("lunge", {})
	var bite: Dictionary = def.get("bite", {})
	match s:
		S.STALK:
			var doe = hunt.doe
			if doe != null and doe.alive:
				var to_d: Vector2 = doe.global_position - global_position
				if to_d.length() < float(def.get("doe_reach", 90)):
					_kill_doe(doe)
					return
				velocity = to_d.normalized() * float(def.get("stalk_speed", 40))
				face(to_d.x)
			else:
				velocity = Vector2.ZERO
		S.EAT:
			velocity = Vector2.ZERO
			if t >= float(def.get("eat_time", 2.0)):
				become_alerted("scent")
		S.ALERT:
			velocity = velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
			face(to_p.x)
			if t >= 0.85:
				_go(S.CHASE)
		S.CHASE:
			var spd = float(def.get("desperate_chase_speed" if desperate() else "chase_speed", 250))
			velocity = to_p.normalized() * spd * slow
			face(to_p.x)
			if dist < float(bite.get("range", 120)) and _lunge_cd > 0.0:
				_start_bite(p)
			elif dist < float(lunge.get("range", 320)) and _lunge_cd <= 0.0:
				_start_lunge(p)
			elif _growl_cd <= 0.0:
				_growl_cd = rng.randf_range(3.0, 5.0)
				Audio.sfx_at("wolf_growl", global_position, -8.0)
		S.WINDUP:
			# he fixes on where she stood when his eyes flared and only tracks a
			# little after that: moving during the tell is how you dodge
			velocity = velocity.move_toward(Vector2.ZERO, 2200.0 * delta)
			var turn = float(lunge.get("desperate_turn" if desperate() else "turn", 0.6))
			_lunge_dir = _track(_lunge_dir, to_p, turn * delta)
			face(_lunge_dir.x)
			var wt = float(lunge.get("desperate_windup" if desperate() else "windup", 0.6))
			if t >= wt:
				_struck = false
				_go(S.LUNGE)
				Audio.sfx_at("wolf_lunge", global_position)
		S.LUNGE:
			var ls = float(lunge.get("desperate_speed" if desperate() else "speed", 680))
			velocity = _lunge_dir * ls
			face(_lunge_dir.x)
			if not _struck and _jaws_hit(p, _lunge_dir, 64.0):
				_struck = true
				p.take_damage(int(lunge.get("damage", 9)), global_position, _lunge_dir * float(lunge.get("knockback", 500)), self)
			if t >= float(lunge.get("time", 0.42)) or (t > 0.08 and get_slide_collision_count() > 0):
				_lunge_cd = float(lunge.get("cooldown", 1.1))
				_bites_in_row = 0
				_recover_time = float(def.get("recover_time", 0.8)) * (0.75 if desperate() else 1.0)
				_go(S.RECOVER)
		S.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 1300.0 * delta)
			if t >= _recover_time:
				# two snaps in a row at most, then he backs off and circles:
				# a rhythm the player can learn
				if dist < float(bite.get("range", 120)) * 1.2 and _bites_in_row < int(bite.get("max_in_row", 2)):
					_start_bite(p)
				elif _bites_in_row > 0 or rng.randf() < 0.5:
					_bites_in_row = 0
					_start_circle()
				else:
					_go(S.CHASE)
		S.BITE_WINDUP:
			velocity = velocity.move_toward(Vector2.ZERO, 2200.0 * delta)
			_bite_dir = _track(_bite_dir, to_p, float(bite.get("turn", 1.5)) * delta)
			face(_bite_dir.x)
			if t >= float(bite.get("windup", 0.35)) * (0.8 if desperate() else 1.0):
				_struck = false
				_go(S.BITE)
				Audio.sfx_at("wolf_bite", global_position)
		S.BITE:
			velocity = _bite_dir * float(bite.get("speed", 260))
			if not _struck and _jaws_hit(p, _bite_dir, 70.0):
				_struck = true
				p.take_damage(int(bite.get("damage", 6)), global_position, _bite_dir * float(bite.get("knockback", 300)), self)
			if t >= 0.2:
				_bites_in_row += 1
				_recover_time = float(bite.get("recover", 0.7))
				_go(S.RECOVER)
		S.CIRCLE:
			var tangent = Vector2(-to_p.y, to_p.x).normalized() * _circle_dir
			var radial = to_p.normalized() * (dist - float(def.get("circle_radius", 240))) * 2.2
			velocity = (tangent * 210.0 + radial).limit_length(270.0) * slow
			face(to_p.x)
			if t >= _circle_time:
				_go(S.CHASE)
		S.STAGGER:
			velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
			if t >= 0.55:
				_go(S.CHASE if alerted else S.STALK)
		S.DEAD:
			velocity = Vector2.ZERO


func _start_lunge(p: Node2D) -> void:
	var lead: Vector2 = p.velocity * 0.12
	_lunge_dir = (p.global_position + lead - global_position).normalized()
	_go(S.WINDUP)
	Audio.sfx_at("wolf_growl", global_position)


func _start_bite(p: Node2D) -> void:
	_bite_dir = (p.global_position - global_position).normalized()
	_go(S.BITE_WINDUP)


## Turns a direction toward another by at most max_angle radians.
static func _track(cur: Vector2, want: Vector2, max_angle: float) -> Vector2:
	if want == Vector2.ZERO:
		return cur
	var d = angle_difference(cur.angle(), want.angle())
	return Vector2.from_angle(cur.angle() + clampf(d, -max_angle, max_angle))


func _start_circle() -> void:
	_circle_dir = 1.0 if rng.randf() < 0.5 else -1.0
	var ct: Array = def.get("circle_time", [1.2, 2.4])
	_circle_time = rng.randf_range(float(ct[0]), float(ct[1]))
	_go(S.CIRCLE)


func _kill_doe(doe: Node) -> void:
	doe.kill(global_position)
	_go(S.EAT)
	Audio.sfx_at("wolf_snarl", global_position)
	killed_doe.emit()


func become_alerted(reason: String) -> void:
	if alerted or dead:
		return
	alerted = true
	_go(S.ALERT)
	Audio.sfx_at("wolf_snarl", global_position, 2.0)
	if hunt and hunt.doe and hunt.doe.alive:
		hunt.doe.freeze_in_fear()
	became_alerted.emit(reason)


# ----------------------------------------------------------------- health
func _regen(delta: float) -> void:
	var rate = float(def.get("regen_per_sec", 0.0))
	regenerating = not ash_struck and not dead and hp < max_hp and rate > 0.0 and _since_hit >= float(def.get("regen_delay", 1.0))
	_regen_fx.emitting = regenerating
	if not regenerating:
		return
	_regen_acc += rate * delta
	while _regen_acc >= 1.0 and hp < max_hp:
		_regen_acc -= 1.0
		hp += 1
		_healed += 1.0
	if not _noticed and _healed >= 10.0:
		_noticed = true
		regen_noticed.emit()


func modify_damage(dmg: int, hit: Dictionary) -> int:
	if not alerted:
		hit["ambush"] = true
		return int(round(dmg * float(def.get("stealth", {}).get("ambush_mult", 2.0))))
	return dmg


func on_hit(dmg: int, hit: Dictionary) -> void:
	_since_hit = 0.0
	if String(hit.get("effect", "")) == "ash_struck" and not ash_struck:
		ash_struck = true
		_regen_fx.emitting = false
		_go(S.STAGGER)
		Fx.burst(self, hurt_center(), Vector2.ZERO, Color(1.0, 0.9, 0.55), 30, 300.0, 1.0)
		UI.shake(12)
		Audio.sfx_at("ash_strike", global_position, 2.0)
		ash_hit.emit()
	elif s == S.WINDUP and dmg >= int(def.get("stagger_damage", 12)):
		_go(S.STAGGER)     # a hard hit during the tell interrupts the lunge
		Audio.sfx_at("wolf_yelp", global_position)
	elif s == S.EAT or s == S.STALK:
		pass                # the Hunt controller turns hits into noise
	Fx.hitstop(self, 0.06 if dmg >= 12 else 0.035)


func on_death(_hit: Dictionary) -> void:
	_go(S.DEAD)
	_regen_fx.emitting = false
	Audio.sfx_at("wolf_yelp", global_position, 3.0)
	Fx.slowmo(self, 0.9, 0.3)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(body, "rotation", 0.0, 0.3)
	tw.tween_property(body, "scale:y", 0.62, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate", Color(0.62, 0.6, 0.66), 1.2)
	tw.tween_property(eyes, "modulate:a", 0.0, 2.5)
	tw.tween_property(eye_light, "energy", 0.0, 2.5)


# ---------------------------------------------------------------- looking
func animate(delta: float) -> void:
	_anim += delta
	var sx = 1.0
	var sy = 1.0
	var y = 0.0
	var rot = 0.0
	match s:
		S.STALK:
			sy = 0.9
			y = sin(_anim * 3.0) * 1.5
		S.EAT:
			sy = 0.86
			rot = 0.08 + sin(_anim * 9.0) * 0.03
		S.ALERT:
			sy = 1.04 + sin(_anim * 30.0) * 0.01
		S.CHASE, S.CIRCLE:
			y = -absf(sin(_anim * 13.0)) * 9.0
			rot = sin(_anim * 13.0) * 0.05
		S.WINDUP:
			sy = 0.82
			sx = 1.06
			body.position.x = randf_range(-1.5, 1.5)
		S.LUNGE:
			sy = 0.9
			sx = 1.16
			rot = -0.08
		S.BITE_WINDUP:
			sy = 0.9
		S.BITE:
			sx = 1.08
		S.STAGGER:
			body.position.x = randf_range(-3, 3)
			rot = sin(_anim * 40.0) * 0.06
		S.DEAD:
			return
	if s != S.WINDUP and s != S.STAGGER:
		body.position.x = lerpf(body.position.x, 0.0, 0.3)
	body.scale = Vector2(-sx if facing_left else sx, sy)
	body.position.y = y
	body.rotation = rot if not facing_left else -rot
	# the eyes flare during the tell: the one honest warning he gives
	var hot = 1.0
	if s == S.WINDUP or s == S.BITE_WINDUP:
		hot = 2.2
	eye_light.energy = lerpf(eye_light.energy, 0.6 * hot, 0.25)
	eyes.scale = Vector2(0.07, 0.035) * (1.0 + (hot - 1.0) * 0.4)
