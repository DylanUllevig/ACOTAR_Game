class_name Fx
extends RefCounted
## One-shot combat effects: blood and snow bursts, ground decals, damage
## numbers, slash arcs, hit-stop and shake. Everything frees itself.
## World-space overlays (numbers, slashes) go on the region's overlay layer so
## the colour grade does not darken them.

static var _time_token := 0


## The region a node belongs to: walks up from the node itself, so effects
## made while a region is still being built land in that region.
static func region_of(n: Node) -> Node:
	var p = n
	while p != null:
		if p is Region:
			return p
		p = p.get_parent()
	return Router.current_region


static func overlay(n: Node) -> Node:
	var r = region_of(n)
	if r != null and r.overlay != null:
		return r.overlay
	return n.get_parent()


static func world(n: Node) -> Node:
	var r = region_of(n)
	if r != null:
		return r
	return n.get_parent()


static func burst(at: Node, pos: Vector2, dir: Vector2, color: Color, amount := 14, speed := 260.0, size := 1.0) -> void:
	var p = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.55
	p.texture = Art.tex("fx/dot.png")
	if dir != Vector2.ZERO:
		p.direction = dir.normalized()
		p.spread = 38.0
	else:
		p.direction = Vector2.UP
		p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 520)
	p.damping_min = 60.0
	p.damping_max = 160.0
	p.scale_amount_min = 0.35 * size
	p.scale_amount_max = 0.9 * size
	p.color = color
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	p.z_index = 30
	world(at).add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Blood spots left in the snow along the hit direction.
static func blood_decals(at: Node, pos: Vector2, dir: Vector2, count := 4) -> void:
	var host = world(at)
	for i in count:
		var b = Polygon2D.new()
		var poly = PackedVector2Array()
		var r = randf_range(5, 15)
		for k in 9:
			var a = TAU * k / 9.0
			poly.append(Vector2(cos(a), sin(a) * 0.55) * r * randf_range(0.75, 1.25))
		b.polygon = poly
		b.color = Color(0.5, 0.04, 0.06, randf_range(0.7, 0.9))
		b.position = pos + dir.normalized() * randf_range(8, 60) + Vector2(randf_range(-14, 14), randf_range(-8, 8))
		b.z_index = -6
		host.add_child(b)
		var tw = b.create_tween()
		tw.tween_interval(40.0)
		tw.tween_property(b, "modulate:a", 0.0, 8.0)
		tw.tween_callback(b.queue_free)


static func number(at: Node, pos: Vector2, value: int, color := Color(1, 0.9, 0.75), big := false) -> void:
	if not Settings.get_v("damage_numbers"):
		return
	var l = Art.label(str(value), 34 if big else 26, color, "caps")
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.03, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos + Vector2(randf_range(-14, 14) - 20, -40)
	l.z_index = 100
	overlay(at).add_child(l)
	var tw = l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


## A crescent swipe at pos, opening toward angle. flip mirrors the sweep.
static func slash(at: Node, pos: Vector2, angle: float, flip: bool, reach: float) -> void:
	var s = Sprite2D.new()
	s.texture = Art.tex("fx/slash.png")
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.position = pos
	s.rotation = angle
	var k = reach / 90.0 * Art.density("fx/slash.png")
	s.scale = Vector2(0.7 * k, (-0.7 if flip else 0.7) * k)
	s.modulate = Color(1.0, 0.95, 0.85, 0.9)
	s.z_index = 50
	overlay(at).add_child(s)
	var tw = s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2(1.05 * k, (-1.05 if flip else 1.05) * k), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "rotation", angle + (-0.5 if flip else 0.5), 0.14)
	tw.tween_property(s, "modulate:a", 0.0, 0.16).set_delay(0.04)
	tw.chain().tween_callback(s.queue_free)


## Freezes the game for a few frames on a solid hit. Uses a timer that ignores
## time scale so it always ends. Hit-stop and slow motion share one token: only
## the most recent effect restores normal speed, so overlapping effects never
## leave the game stuck slow and never cut each other off early.
static func hitstop(at: Node, seconds := 0.05) -> void:
	await _time_effect(at, seconds, 0.05)


## Slow motion for a dramatic beat (the killing blow).
static func slowmo(at: Node, seconds := 1.0, scale := 0.3) -> void:
	await _time_effect(at, seconds, scale)


static func _time_effect(at: Node, seconds: float, scale: float) -> void:
	if at == null or not at.is_inside_tree():
		return
	_time_token += 1
	var mine = _time_token
	Engine.time_scale = scale
	await at.get_tree().create_timer(seconds, true, false, true).timeout
	if mine == _time_token:
		Engine.time_scale = 1.0


## Ends any hit-stop or slow motion at once (menus, game over, scene changes).
static func reset_time() -> void:
	_time_token += 1
	Engine.time_scale = 1.0


static func shake(strength: float) -> void:
	UI.shake(strength)
