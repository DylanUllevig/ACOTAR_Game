extends Node2D
## The starving doe in the clearing. Grazes on bark until the wolf reaches her.
## If the wolf turns on Feyre first, she freezes, too frightened to run.

const DEAD_ART := "actors/doe_dead.png"

var alive := true
var frightened := false
var sprite: Sprite2D
var shadow: Sprite2D
var _t := randf() * 10.0
var _px := {}                # pixel sheet layout, when the art is pixel art


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Art.lit("actors/doe.png")
	if Art.is_pixel("actors/doe.png"):
		_px = Art.pixel_meta("actors/doe.png")
		sprite.hframes = int(_px.grid[0])
		sprite.vframes = int(_px.grid[1])
		sprite.scale = Art.sprite_scale("actors/doe.png")
		sprite.offset = Vector2(0, -sprite.texture.get_height() / (2.0 * sprite.vframes))
		_frame("graze")
	else:
		if sprite.texture:
			sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
		sprite.scale = Vector2(1.3, 1.3) * Art.density("actors/doe.png")
	add_child(sprite)
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("fx/shadow.png")
	shadow.modulate = Color(0.05, 0.06, 0.12, 0.4)
	shadow.scale = Vector2(1.1, 0.5)
	shadow.z_index = -1
	add_child(shadow)


func _frame(anim: String, k := 0) -> void:
	var a: Array = _px.get("anims", {}).get(anim, [])
	if not a.is_empty():
		sprite.frame = int(a[k % a.size()])


func _process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	if not _px.is_empty():
		if frightened:
			_frame("alert")
			sprite.position.x = float(int(_t * 30.0) % 2) * Art.PX
		else:
			# head down to the bark, up to listen, a glance back now and then
			var c = fmod(_t, 6.0)
			_frame("graze" if c < 4.5 else ("look" if fmod(_t, 18.0) > 12.0 else "alert"))
		return
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
	if not _show_carcass(true):
		sprite.rotation = PI / 2.0
		sprite.modulate = Color(0.7, 0.62, 0.6)
		sprite.position.y = 10.0
	for i in 5:
		Fx.blood_decals(self, global_position + Vector2(randf_range(-50, 50), randf_range(-40, -5)), Vector2.ZERO, 1)


func kill(from: Vector2) -> void:
	if not alive:
		return
	alive = false
	var dir = (global_position - from).normalized()
	Fx.burst(self, global_position + Vector2(0, -40), dir, Color(0.6, 0.05, 0.08), 26, 260.0, 1.0)
	Fx.blood_decals(self, global_position, dir, 7)
	if _show_carcass(false):
		return
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sprite, "rotation", PI / 2.0 * (1.0 if dir.x >= 0.0 else -1.0), 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sprite, "modulate", Color(0.7, 0.62, 0.6), 0.8)
	tw.tween_property(sprite, "position:y", 10.0, 0.35)


## Swaps in the painted carcass (actors/doe_dead.png) if there is one, so she
## lies on her side instead of the live sprite being tipped over. Returns
## false when there is no such art.
func _show_carcass(instant: bool) -> bool:
	if not _px.is_empty():
		# the sheet's own frame: lying on her side
		_frame("dead")
		sprite.position = Vector2.ZERO
		sprite.modulate = Color(0.92, 0.88, 0.86)
		var pfit = Creature.lying_shadow(sprite)
		shadow.scale = pfit[0]
		shadow.position = pfit[1] + Vector2(0, Creature.frame_size(sprite).y * 0.25)
		shadow.modulate.a = 0.6
		return true
	var tex = Art.lit(DEAD_ART)
	if tex == null:
		return false
	var carcass = Sprite2D.new()
	carcass.texture = tex
	carcass.offset = Vector2(0, -tex.get_height() / 2.0)
	carcass.scale = Vector2(1.3, 1.3) * Art.density(DEAD_ART)
	carcass.modulate = Color(0.9, 0.86, 0.84)
	add_child(carcass)
	sprite.rotation = 0.0
	var fit = Creature.lying_shadow(carcass)
	if instant:
		sprite.visible = false
		shadow.scale = fit[0]
		shadow.position = fit[1]
		shadow.modulate.a = 0.7
		return true
	carcass.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale:y", sprite.scale.y * 0.7, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tw.tween_property(carcass, "modulate:a", 1.0, 0.16).set_delay(0.06)
	tw.tween_property(shadow, "scale", fit[0], 0.2)
	tw.tween_property(shadow, "position", fit[1], 0.2)
	tw.tween_property(shadow, "modulate:a", 0.7, 0.2)
	return true
