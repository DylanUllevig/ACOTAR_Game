extends Creature
## A snow hare: nibbles and hops about, bolts in zig-zags when Feyre gets close
## or an arrow lands nearby. One hit is enough. Drops a hare to carry home.

var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _wait := 0.0
var _flee := 0.0
var _hop := 0.0
var _zig := 1.0
var _zig_t := 0.0


func _init() -> void:
	feet_radius = 8.0
	hurt_radius = 20.0
	hurt_offset = Vector2(0, -16)


func build_visual() -> void:
	var art: Dictionary = def.get("art", {})
	sprite.texture = Art.lit(String(art.get("sprite", "actors/hare.png")))
	if sprite.texture:
		sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	var sc = float(art.get("scale", 1.0))
	sprite.scale = Vector2(sc, sc)
	shadow.scale = Vector2(0.6, 0.35)
	_home = global_position
	_target = global_position
	_wait = rng.randf_range(0.5, 2.5)


func spook() -> void:
	_flee = 2.2


func think(delta: float) -> void:
	var r = Router.current_region
	var p: Node2D = r.player if r else null
	if p != null:
		var d = global_position.distance_to(p.global_position)
		var radius = float(def.get("flee_radius", 240))
		if d < radius * (1.4 if p.has_method("is_sprinting") and p.is_sprinting() else 1.0):
			_flee = max(_flee, 1.2)
	if _flee > 0.0:
		_flee -= delta
		_zig_t -= delta
		if _zig_t <= 0.0:
			_zig = -_zig
			_zig_t = rng.randf_range(0.25, 0.5)
		var away = (global_position - p.global_position).normalized() if p else Vector2.RIGHT
		var dir = (away + away.orthogonal() * 0.6 * _zig).normalized()
		velocity = dir * float(def.get("flee_speed", 320))
		face(velocity.x)
		_home = global_position
		_target = global_position
		return
	# idle: nibble, then hop a short way
	if global_position.distance_to(_target) < 6.0:
		velocity = Vector2.ZERO
		_wait -= delta
		if _wait <= 0.0:
			_wait = rng.randf_range(1.0, 3.5)
			_target = _home + Vector2(rng.randf_range(-90, 90), rng.randf_range(-60, 60))
	else:
		var to = _target - global_position
		velocity = to.normalized() * float(def.get("wander_speed", 40)) * 2.2
		face(to.x)


func animate(delta: float) -> void:
	if dead:
		return
	var moving = velocity.length() > 10.0
	if moving:
		_hop += delta * (16.0 if _flee > 0.0 else 9.0)
		body.position.y = -absf(sin(_hop)) * (10.0 if _flee > 0.0 else 6.0)
	else:
		body.position.y = lerpf(body.position.y, 0.0, 0.3)
		body.rotation = sin(Time.get_ticks_msec() * 0.004) * 0.03


func on_hit(_dmg: int, _hit: Dictionary) -> void:
	Fx.hitstop(self, 0.03)


func on_death(_hit: Dictionary) -> void:
	GameState.bump("hares_hunted")
	var tw = create_tween().set_parallel(true)
	tw.tween_property(body, "rotation", PI / 2.0, 0.25)
	tw.tween_property(body, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.chain().tween_callback(queue_free)
