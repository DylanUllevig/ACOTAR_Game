class_name Meter
extends Control
## A smooth pill-shaped bar: the fill eases to the new value, and a pale
## "ghost" of the old value drains after it, so damage reads at a glance.
## Optional centred text. Drawn by hand so it stays sharp at any size.

var value := 1.0
var max_value := 1.0
var fill_color := Color("c0384f")
var ghost_color := Color("f3cf8e")
var back_color := Color("dcc7a4")
var border_color := Art.ROSEWOOD
var text := ""
var font_size := 18
var pulse := 0.0             # 0..1: brighten the fill (e.g. healing)
var _shown := 1.0
var _ghost := 1.0
var _ghost_hold := 0.0


func _init(w := 360, h := 16) -> void:
	custom_minimum_size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(v: float, m: float, instant := false) -> void:
	var old_frac = value / max(0.001, max_value)
	value = v
	max_value = max(0.001, m)
	var frac = value / max_value
	if instant:
		_shown = frac
		_ghost = frac
	elif frac < old_frac:
		_ghost = max(_ghost, old_frac)
		_ghost_hold = 0.45
	queue_redraw()


func _process(delta: float) -> void:
	var frac = clampf(value / max_value, 0.0, 1.0)
	_shown = lerpf(_shown, frac, 1.0 - exp(-14.0 * delta))
	if _ghost_hold > 0.0:
		_ghost_hold -= delta
	elif _ghost > _shown:
		_ghost = max(_shown, _ghost - delta * 0.6)
	else:
		_ghost = _shown
	queue_redraw()


func _box(c: Color, rad: int, border := 0, bc := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(rad)
	b.corner_detail = 10
	b.anti_aliasing = true
	if border > 0:
		b.border_color = bc
		b.set_border_width_all(border)
	return b


func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	var rad = int(ceil(size.y / 2.0))
	var bw = 2 if size.y >= 12 else 1
	draw_style_box(_box(back_color, rad, bw, border_color), r)
	var inner = r.grow(-(bw + 1))
	var irad = maxi(1, int(ceil(inner.size.y / 2.0)))
	# a soft shade along the top of the groove
	draw_style_box(_box(Color(0.35, 0.2, 0.12, 0.12), irad), Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.5)))
	if _ghost > _shown + 0.002:
		var gw = maxf(inner.size.y, inner.size.x * clampf(_ghost, 0, 1))
		draw_style_box(_box(ghost_color, irad), Rect2(inner.position, Vector2(gw, inner.size.y)))
	if _shown > 0.002:
		var c = fill_color.lightened(0.25 * pulse)
		var fr = Rect2(inner.position, Vector2(maxf(inner.size.y, inner.size.x * clampf(_shown, 0, 1)), inner.size.y))
		draw_style_box(_box(c, irad), fr)
		# a glossy highlight along the top, and a darker underside
		if fr.size.y >= 8:
			var hi = Rect2(fr.position + Vector2(fr.size.y * 0.35, 1.5), Vector2(maxf(0.0, fr.size.x - fr.size.y * 0.7), fr.size.y * 0.32))
			if hi.size.x > 2:
				draw_style_box(_box(Color(1, 1, 1, 0.28), int(hi.size.y / 2.0) + 1), hi)
	if text != "":
		var fnt = Art.font("bold")
		var w = fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var p = Vector2((size.x - w) / 2.0, size.y / 2.0 + font_size * 0.32)
		draw_string_outline(fnt, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.25, 0.08, 0.1, 0.9))
		draw_string(fnt, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Art.PAPER)
