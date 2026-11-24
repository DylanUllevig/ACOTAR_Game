extends Node2D
## An arrow in flight. Moves by ray casts each physics step, so a fast arrow
## cannot pass through a thin trunk or a hurtbox between frames. On a creature
## it deals damage and sticks; on a tree or rock it sticks and can be pulled
## out; at the end of its range it drops into the snow. Recoverable arrows
## become pickups.

const Pickup := preload("res://scripts/combat/pickup.gd")
const MASK_WORLD := 1
const MASK_HURTBOX := 16

var velocity := Vector2.ZERO
var damage := 10
var ammo_id := "arrow"
var effect := ""
var max_dist := 1000.0
var shooter: Node = null
var break_chance := 0.25
var _travel := 0.0
var _done := false
var sprite: Sprite2D
var trail: Line2D


func setup(from: Vector2, dir: Vector2, speed: float, dmg: int, ammo: String, fx_effect: String, range_px: float, by: Node) -> void:
	position = from
	velocity = dir.normalized() * speed
	damage = dmg
	ammo_id = ammo
	effect = fx_effect
	max_dist = range_px
	shooter = by
	rotation = velocity.angle()


func _ready() -> void:
	z_index = 40
	sprite = Sprite2D.new()
	var rel = "fx/ash_arrow.png" if ammo_id == "ash_arrow" else "fx/arrow.png"
	sprite.texture = Art.tex(rel)
	sprite.scale = Vector2.ONE * Art.density(rel)
	add_child(sprite)
	trail = Line2D.new()
	trail.width = 3.0
	trail.default_color = Color(1, 1, 1, 0.35)
	trail.top_level = true
	trail.z_index = 39
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.45))
	trail.gradient = g
	add_child(trail)


func _frozen() -> bool:
	return Dialogue.active or UI.modal_open or Router.busy


func _physics_process(delta: float) -> void:
	if _done or _frozen():
		return
	var step = velocity * delta
	var from = global_position
	var to = from + step
	var space = get_world_2d().direct_space_state
	var q = PhysicsRayQueryParameters2D.create(from, to, MASK_WORLD | MASK_HURTBOX)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var ex: Array[RID] = []
	if shooter is CollisionObject2D:
		ex.append(shooter.get_rid())
	q.exclude = ex
	var hit = space.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position
		_on_hit(hit.collider, hit.position)
		return
	global_position = to
	_travel += step.length()
	trail.add_point(global_position)
	while trail.get_point_count() > 6:
		trail.remove_point(0)
	if _travel >= max_dist:
		_land()


func _on_hit(col: Object, at: Vector2) -> void:
	_done = true
	trail.clear_points()
	var target: Node = col
	if col is Area2D and col.get_parent() != null and col.get_parent().has_method("take_hit"):
		target = col.get_parent()
	if target != null and target.has_method("take_hit"):
		var hit = {"damage": damage, "kind": "arrow", "ammo": ammo_id, "effect": effect,
			"dir": velocity.normalized(), "knockback": 140.0, "source": shooter, "at": at}
		target.take_hit(hit)
		Audio.sfx_at("arrow_hit_flesh", at)
		if target.has_method("stick_arrow"):
			# the creature carries the arrow until it shakes it loose (or dies)
			target.stick_arrow(ammo_id, at, velocity.angle(), break_chance)
		queue_free()
		return
	# tree, rock or wall: the arrow thunks in and stays, slightly embedded
	Audio.sfx_at("arrow_hit_wood", at)
	Fx.burst(self, at, -velocity.normalized(), Color(0.85, 0.85, 0.9), 6, 140.0, 0.6)
	_become_pickup(at - velocity.normalized() * 6.0, velocity.angle(), true)


func _land() -> void:
	_done = true
	trail.clear_points()
	Audio.sfx_at("arrow_hit_snow", global_position, -6.0)
	Fx.burst(self, global_position, Vector2.ZERO, Color(0.92, 0.95, 1.0), 5, 90.0, 0.5)
	_become_pickup(global_position, velocity.angle(), false)


func _become_pickup(at: Vector2, angle: float, stuck: bool) -> void:
	var host = Fx.world(self)
	var p = Pickup.new()
	p.setup(ammo_id, 1, at, angle, stuck)
	if "world" in host and host.world != null:
		host.world.add_child(p)
	else:
		host.add_child(p)
	queue_free()
