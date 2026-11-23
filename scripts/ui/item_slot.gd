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


func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.11, 0.085, 0.09, 0.92) if not dimmed else Color(0.07, 0.06, 0.07, 0.8)
	bg.set_corner_radius_all(8)
	bg.border_color = Color(0.36, 0.28, 0.2, 0.95)
	bg.set_border_width_all(2)
	bg.shadow_color = Color(0, 0, 0, 0.35)
	bg.shadow_size = 3
	draw_style_box(bg, r)
	# inner bevel for a little depth
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(1, 1, 1, 0.025), true)
	if stack != null:
		var d: Dictionary = DB.item(stack.id)
		var tex: Texture2D = Art.tex(String(d.get("icon", "")))
		if tex:
			var pad = size.x * 0.12 - _pop * size.x * 0.06
			var ir = Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)
			draw_texture_rect(tex, ir, false, Color(1, 1, 1, 0.45 if dimmed else 1.0))
		if int(stack.n) > 1:
			var f = Art.font("caps")
			var fs = int(size.x * 0.27)
			var txt = str(stack.n)
			var w = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos = Vector2(size.x - w - 7, size.y - 8)
			draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.05, 0.03, 0.03, 0.95))
			draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.PARCHMENT)
	if key_label != "":
		var f2 = Art.font("caps")
		var ks = int(size.x * 0.2)
		draw_string_outline(f2, Vector2(7, ks + 3), key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, ks, 5, Color(0, 0, 0, 0.8))
		draw_string(f2, Vector2(7, ks + 3), key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, ks, Color(1, 1, 1, 0.55))
	if hovered:
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(1.0, 0.9, 0.7, 0.08), true)
	if selected:
		var sel = StyleBoxFlat.new()
		sel.bg_color = Color(0, 0, 0, 0)
		sel.border_color = Art.GOLD
		sel.set_border_width_all(4)
		sel.set_corner_radius_all(9)
		sel.shadow_color = Color(1.0, 0.8, 0.4, 0.35)
		sel.shadow_size = 8
		draw_style_box(sel, r.grow(2))
