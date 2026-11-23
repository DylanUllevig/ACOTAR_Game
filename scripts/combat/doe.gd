extends Node2D
## The starving doe in the clearing. Grazes on bark until the wolf reaches her.
## If the wolf turns on Feyre first, she freezes, too frightened to run.

var alive := true
var frightened := false
var sprite: Sprite2D
var _t := randf() * 10.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Art.lit("actors/doe.png")
	if sprite.texture:
		sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	sprite.scale = Vector2(1.3, 1.3)
	add_child(sprite)
	var sh = Sprite2D.new()
	sh.texture = Art.tex("fx/shadow.png")
	sh.modulate = Color(0.05, 0.06, 0.12, 0.4)
	sh.scale = Vector2(1.1, 0.5)
	sh.z_index = -1
	add_child(sh)


func _process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	if frightened:
		sprite.position.x = sin(_t * 47.0) * 0.8
		sprite.rotation = 0.0
	else:
		# head down to the bark, up to listen
		sprite.rotation = 0.04 * sin(_t * 1.3) + (0.06 if fmod(_t, 6.0) < 4.5 else -0.02)


func freeze_in_fear() -> void:
	frightened = true


## Already dead when the area loads (no burst of blood).
func lie_dead() -> void:
	alive = false
	sprite.rotation = PI / 2.0
	sprite.modulate = Color(0.7, 0.62, 0.6)
	sprite.position.y = 10.0
	for i in 5:
		Fx.blood_decals(self, global_position + Vector2(randf_range(-60, 60), randf_range(-10, 20)), Vector2.ZERO, 1)


func kill(from: Vector2) -> void:
	if not alive:
		return
	alive = false
	var dir = (global_position - from).normalized()
	Fx.burst(self, global_position + Vector2(0, -40), dir, Color(0.6, 0.05, 0.08), 26, 260.0, 1.0)
	Fx.blood_decals(self, global_position, dir, 7)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sprite, "rotation", PI / 2.0 * (1.0 if dir.x >= 0.0 else -1.0), 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sprite, "modulate", Color(0.7, 0.62, 0.6), 0.8)
	tw.tween_property(sprite, "position:y", 10.0, 0.35)
