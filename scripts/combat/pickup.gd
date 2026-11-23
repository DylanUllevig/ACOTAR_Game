extends Node2D
## Something lying in the world that Feyre picks up by walking over it: spent
## arrows, a hare, a pelt. Within reach it glides to her (after a short delay
## so a dropped item does not snap back at once).

var item_id := ""
var count := 1
var stuck := false          # an arrow in a trunk: stands upright, no glide
var sprite: Sprite2D
var _age := 0.0
var _taken := false
var _full_warned := false
var _bob := randf() * TAU

const REACH := 40.0
const MAGNET := 110.0
const DELAY := 0.45


func setup(id: String, n: int, at: Vector2, angle := 0.0, is_stuck := false) -> void:
	item_id = id
	count = n
	position = at
	stuck = is_stuck
	rotation = 0.0
	set_meta("angle", angle)


func _ready() -> void:
	add_to_group("pickups")
	sprite = Sprite2D.new()
	if item_id == "arrow" or item_id == "ash_arrow":
		sprite.texture = Art.tex("fx/ash_arrow.png" if item_id == "ash_arrow" else "fx/arrow.png")
		var ang: float = get_meta("angle", 0.0)
		# lying arrows rest at their flight angle; stuck ones lean into the trunk
		sprite.rotation = ang
		if not stuck:
			sprite.scale = Vector2(0.9, 0.9)
			sprite.position = Vector2(0, -4)
	else:
		sprite.texture = Art.tex(String(DB.item(item_id).get("icon", "items/arrow.png")))
		sprite.scale = Vector2(0.5, 0.5)
		sprite.position = Vector2(0, -22)
	add_child(sprite)
	# a faint glint so things on the snow are findable at dusk
	var glint = Sprite2D.new()
	glint.texture = Art.soft_light_texture()
	glint.scale = Vector2(0.12, 0.06)
	glint.modulate = Color(1.0, 0.9, 0.6, 0.35)
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glint.material = m
	glint.position = Vector2(0, 2)
	add_child(glint)
	move_child(glint, 0)


func _process(delta: float) -> void:
	if _taken:
		return
	_age += delta
	if not stuck and item_id != "arrow" and item_id != "ash_arrow":
		_bob += delta * 3.0
		sprite.position.y = -22 + sin(_bob) * 3.0
	var r = Router.current_region
	if r == null or r.player == null or Dialogue.active or UI.modal_open:
		return
	var p: Node2D = r.player
	var d = global_position.distance_to(p.global_position)
	if _age < DELAY:
		return
	if d > REACH * 2.5:
		_full_warned = false
	if d <= REACH:
		_collect()
	elif d <= MAGNET and not stuck and GameState.space_for(item_id) > 0:
		global_position = global_position.move_toward(p.global_position, (420.0 + (MAGNET - d) * 6.0) * delta)


func _collect() -> void:
	if GameState.space_for(item_id) <= 0:
		if not _full_warned:
			_full_warned = true
			UI.toast("No room in your satchel for %s." % DB.item_name(item_id))
		return
	var left = GameState.add_item(item_id, count, true)
	var got = count - left
	if got > 0:
		GameState.item_gained.emit(item_id, got)
	if item_id == "arrow" or item_id == "ash_arrow":
		GameState.bump("arrows_recovered", got)
	Audio.sfx("pickup", -4.0, 0.08)
	if left > 0:
		count = left
		return
	_taken = true
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.2, 0.2), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(queue_free)
