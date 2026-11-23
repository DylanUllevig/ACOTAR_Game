class_name Meter
extends Control
## A smooth bar: the fill eases to the new value, and a pale "ghost" of the
## old value drains after it, so damage reads at a glance. Optional centred
## text. Drawn by hand so it stays sharp at any size.

var value := 1.0
var max_value := 1.0
var fill_color := Color(0.7, 0.13, 0.15)
var ghost_color := Color(1.0, 0.86, 0.7, 0.75)
var back_color := Color(0.05, 0.035, 0.045, 0.92)
var border_color := Color(0.0, 0.0, 0.0, 0.7)
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


func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	var rad = min(6, int(size.y / 2.0))
	var bg = StyleBoxFlat.new()
	bg.bg_color = back_color
	bg.border_color = border_color
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(rad)
	draw_style_box(bg, r)
	var inner = r.grow(-2)
	if _ghost > _shown + 0.002:
		var g = StyleBoxFlat.new()
		g.bg_color = ghost_color
		g.set_corner_radius_all(max(1, rad - 1))
		draw_style_box(g, Rect2(inner.position, Vector2(inner.size.x * clampf(_ghost, 0, 1), inner.size.y)))
	if _shown > 0.002:
		var f = StyleBoxFlat.new()
		f.bg_color = fill_color.lightened(0.25 * pulse)
		f.set_corner_radius_all(max(1, rad - 1))
		var fr = Rect2(inner.position, Vector2(max(inner.size.y, inner.size.x * clampf(_shown, 0, 1)), inner.size.y))
		draw_style_box(f, fr)
		# glossy top highlight
		draw_rect(Rect2(fr.position + Vector2(2, 1), Vector2(fr.size.x - 4, fr.size.y * 0.35)), Color(1, 1, 1, 0.12), true)
	if text != "":
		var fnt = Art.font("caps")
		var w = fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var p = Vector2((size.x - w) / 2.0, size.y / 2.0 + font_size * 0.36)
		draw_string_outline(fnt, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.85))
		draw_string(fnt, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Art.PARCHMENT)
