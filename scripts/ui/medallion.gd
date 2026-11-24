class_name Medallion
extends Control
## A round portrait: a crop of a painted portrait cut to a circle, in a
## rosewood ring with a honey hairline. The HUD shows Feyre in one; barks show
## whoever is speaking.

var face: TextureRect
var _mat: ShaderMaterial
var _ring: Control


func _init(px := 86.0) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	face = TextureRect.new()
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/circle_mask.gdshader")
	face.material = _mat
	add_child(face)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _layout() -> void:
	var inset = 4.0
	face.position = Vector2(inset, inset)
	face.size = size - Vector2(inset, inset) * 2.0
	_mat.set_shader_parameter("rect_size", face.size)
	_ring.position = Vector2.ZERO
	_ring.size = size
	queue_redraw()
	_ring.queue_redraw()


## Shows part of a portrait: region is the square to crop, in its pixels
## (the whole picture if empty).
func set_face(tex: Texture2D, region := Rect2()) -> void:
	if tex == null or region.size == Vector2.ZERO:
		face.texture = tex
		return
	var at = AtlasTexture.new()
	at.atlas = tex
	at.region = region
	face.texture = at


## The face square of a portrait for when nothing better is known: the top
## middle, where the painted portraits put the head.
static func default_region(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var w = float(tex.get_width())
	return Rect2(w * 0.18, w * 0.06, w * 0.64, w * 0.64)


func _draw() -> void:
	var c = size / 2.0
	var r = minf(size.x, size.y) / 2.0
	draw_circle(c + Vector2(0, 3), r + 1.0, Color(0.1, 0.05, 0.04, 0.28), true, -1.0, true)
	draw_circle(c, r, Art.ROSEWOOD, true, -1.0, true)
	draw_circle(c, r - 3.5, Art.PAPER_SHADE, true, -1.0, true)


func _draw_ring() -> void:
	var c = size / 2.0
	var r = minf(size.x, size.y) / 2.0
	_ring.draw_arc(c, r - 4.5, 0.0, TAU, 64, Color(Art.HONEY, 0.95), 1.5, true)
	_ring.draw_arc(c, r - 1.5, PI * 1.1, PI * 1.9, 32, Color(1, 0.85, 0.8, 0.35), 1.5, true)
