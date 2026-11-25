class_name ItemSlot
extends Control
## One inventory cell: frame, icon, stack count, optional key number. Draws
## itself (no child nodes), so the hotbar and inventory stay cheap and crisp.
## Emits clicks; what a click means is up to the screen that owns it.

signal slot_pressed(slot: ItemSlot, button: int)
signal slot_released(slot: ItemSlot, button: int)
signal slot_hovered(slot: ItemSlot, on: bool)

var index := -1
var key_label := ""          # "1".."0" on the hotbar
var selected := false
var hovered := false
var dimmed := false
var stack: Variant = null    # {id, n} or null; set by refresh()
var _pop := 0.0


func _init(i := -1, px := 84, key := "") -> void:
	index = i
	key_label = key
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	mouse_entered.connect(func():
		hovered = true
		slot_hovered.emit(self, true)
		queue_redraw())
	mouse_exited.connect(func():
		hovered = false
		slot_hovered.emit(self, false)
		queue_redraw())
	refresh()


func refresh() -> void:
	var s = GameState.slot(index)
	var was = stack
	stack = null if s == null else {"id": String(s.id), "n": int(s.n)}
	if stack != null and (was == null or was.id != stack.id or int(was.n) < int(stack.n)):
		_pop = 1.0
		set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_pop = max(0.0, _pop - delta * 5.0)
	queue_redraw()
	if _pop <= 0.0:
		set_process(false)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if ev.pressed:
				slot_pressed.emit(self, ev.button_index)
			else:
				slot_released.emit(self, ev.button_index)
			accept_event()


func _box(bg: Color, rad: int, border := 0, bc := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(rad)
	b.corner_detail = 10
	b.anti_aliasing = true
	if border > 0:
		b.border_color = bc
		b.set_border_width_all(border)
	return b


func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	var rad = int(size.x * 0.17)
	if selected:
		# lifted and ringed in rose, with a soft glow
		var glow = _box(Color(1.0, 0.98, 0.93), rad + 2, 3, Art.ROSE)
		glow.shadow_color = Color(Art.ROSE, 0.45)
		glow.shadow_size = 10
		draw_style_box(glow, r.grow(2))
	else:
		var bg = Color("efe1c6") if not hovered else Color("f7ecd8")
		draw_style_box(_box(bg, rad, 2, Color("cdb38a") if not hovered else Art.TEXT_SOFT), r)
		# recessed: a shaded inner lip along the top
		var lip = _box(Color(0, 0, 0, 0), rad - 2)
		lip.border_width_top = 3
		lip.border_color = Color(0.42, 0.27, 0.14, 0.13)
		draw_style_box(lip, r.grow(-2))
	if stack != null:
		var d: Dictionary = DB.item(stack.id)
		var tex: Texture2D = Art.tex(String(d.get("icon", "")))
		if tex:
			var pad = size.x * 0.13 - _pop * size.x * 0.06
			var ir = Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)
			# a soft shadow under the icon so it sits on the paper
			draw_texture_rect(tex, Rect2(ir.position + Vector2(0, 3), ir.size), false, Color(0.25, 0.12, 0.08, 0.22 if not dimmed else 0.1))
			draw_texture_rect(tex, ir, false, Color(1, 1, 1, 0.45 if dimmed else 1.0))
		if int(stack.n) > 1:
			var f = Art.font("bold")
			var fs = int(size.x * 0.28)
			var txt = str(stack.n)
			var w = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos = Vector2(size.x - w - 8, size.y - 8)
			draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(Art.PAPER, 0.95))
			draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.TEXT)
	if key_label != "":
		var f2 = Art.font("bold")
		var ks = int(size.x * 0.24)
		var kc = Art.ROSE if selected else Color(Art.TEXT_SOFT, 0.8)
		draw_string_outline(f2, Vector2(9, ks + 4), key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, ks, 4, Color(Art.PAPER, 0.9))
		draw_string(f2, Vector2(9, ks + 4), key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, ks, kc)
