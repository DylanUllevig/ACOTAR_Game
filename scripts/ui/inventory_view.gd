class_name InventoryView
extends HBoxContainer
## The satchel: the hotbar row (keys 1 to 0) above twenty bag slots, and a
## detail card for whatever is under the cursor. Click a stack to pick it up,
## click a slot to put it down (swapping or merging), or drag it there.
## Right-click takes half a stack, or puts down one at a time.

const SLOT_PX := 96
const GAP := 10

var _slots: Array[ItemSlot] = []
var held: Variant = null        # {id, n} on the cursor
var held_from := -1
var _press_slot := -1
var _hover := -1
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_kind: Label
var _detail_text: RichTextLabel
var _eat_btn: Button
var _held_view: Control
var _stats_l: Label


func _ready() -> void:
	add_theme_constant_override("separation", 36)
	var left = VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	left.add_child(_caption("Hotbar  ·  keys 1 to 0, or the mouse wheel"))
	left.add_child(_row(0, GameState.hotbar_size()))
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	left.add_child(sp)
	left.add_child(_caption("Satchel"))
	var bag_rows = int(ceil(float(GameState.inv_size() - GameState.hotbar_size()) / 10.0))
	for r in bag_rows:
		var start = GameState.hotbar_size() + r * 10
		left.add_child(_row(start, min(10, GameState.inv_size() - start)))
	var help = Art.label("Click to pick up, click a slot to place, swap or stack. Drag works too. Right click takes half.", 20, Art.GOLD_DIM, "italic")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(10 * SLOT_PX + 9 * GAP, 0)
	left.add_child(help)
	_stats_l = Art.label("", 22, Art.PARCHMENT, "caps")
	left.add_child(_stats_l)
	add_child(_build_detail())
	_held_view = Control.new()
	_held_view.top_level = true
	_held_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_view.z_index = 100
	_held_view.draw.connect(_draw_held)
	add_child(_held_view)
	GameState.inventory_changed.connect(_refresh)
	_refresh()


func _caption(t: String) -> Label:
	return Art.label(t, 20, Art.GOLD_DIM, "caps")


func _row(start: int, n: int) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", GAP)
	for i in n:
		var idx = start + i
		var key = str((idx + 1) % 10) if idx < GameState.hotbar_size() else ""
		var s = ItemSlot.new(idx, SLOT_PX, key)
		s.slot_pressed.connect(_on_pressed)
		s.slot_released.connect(_on_released)
		s.slot_hovered.connect(_on_hovered)
		h.add_child(s)
		_slots.append(s)
	return h


func _build_detail() -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.panel_style(Color(0.09, 0.07, 0.08, 0.95), Art.GOLD_DIM, 12, 2))
	p.custom_minimum_size = Vector2(380, 520)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(140, 140)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(_detail_icon)
	_detail_name = Art.label("", 32, Art.GOLD, "caps")
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_detail_name)
	_detail_kind = Art.label("", 20, Art.GOLD_DIM, "caps")
	v.add_child(_detail_kind)
	_detail_text = RichTextLabel.new()
	_detail_text.bbcode_enabled = true
	_detail_text.fit_content = true
	_detail_text.scroll_active = false
	_detail_text.custom_minimum_size = Vector2(340, 0)
	_detail_text.add_theme_font_override("normal_font", Art.font("serif"))
	_detail_text.add_theme_font_override("italics_font", Art.font("italic"))
	_detail_text.add_theme_font_override("bold_font", Art.font("caps"))
	_detail_text.add_theme_font_size_override("normal_font_size", 24)
	_detail_text.add_theme_font_size_override("italics_font_size", 24)
	_detail_text.add_theme_font_size_override("bold_font_size", 20)
	_detail_text.add_theme_color_override("default_color", Art.PARCHMENT)
	v.add_child(_detail_text)
	_eat_btn = Art.button("Eat one", 24)
	_eat_btn.visible = false
	_eat_btn.pressed.connect(_eat_hovered)
	v.add_child(_eat_btn)
	return p


# ---------------------------------------------------------------- refresh
func _refresh() -> void:
	for s in _slots:
		s.selected = s.index == GameState.hotbar_index
		s.refresh()
	_stats_l.text = "Health %d / %d     Coin %d     Power %d" % [GameState.hp, GameState.max_hp, GameState.coins, GameState.power_score()]
	_show_detail()


func _show_detail() -> void:
	var st: Variant = held
	if st == null and _hover >= 0:
		st = GameState.slot(_hover)
	if st == null:
		_detail_icon.texture = null
		_detail_name.text = ""
		_detail_kind.text = ""
		_detail_text.text = "[i]Hover over an item to read about it.[/i]"
		_eat_btn.visible = false
		return
	var id = String(st.id)
	var d: Dictionary = DB.item(id)
	_detail_icon.texture = Art.tex(String(d.get("icon", "")))
	_detail_name.text = String(d.get("name", id))
	var kind = String(d.get("kind", ""))
	_detail_kind.text = {"weapon": "Weapon", "ammo": "Ammunition", "food": "Food", "material": "Goods", "keepsake": "Keepsake"}.get(kind, kind.capitalize())
	if d.get("key", false):
		_detail_kind.text += "  ·  can't be thrown away"
	_detail_text.text = String(d.get("text", "")) + "\n\n" + item_stats(id)
	_eat_btn.visible = held == null and d.get("use", "") == "eat"
	_eat_btn.disabled = GameState.hp >= GameState.max_hp


static func item_stats(id: String) -> String:
	var d: Dictionary = DB.item(id)
	var lines: Array = []
	match String(d.get("use", "")):
		"knife":
			lines.append("[b]Damage[/b]  %d" % int(round(float(d.get("damage", 0)) * GameState.damage_mult)))
			lines.append("[b]Reach[/b]  %d   ·   [b]Swing[/b]  %.2f s" % [int(d.get("reach", 0)), float(d.get("cooldown", 0))])
		"bow":
			if id == "bow":
				lines.append("[b]Damage[/b]  %d to %d at full draw" % [int(round(float(d.get("min_damage", 0)) * GameState.damage_mult)), int(round(float(d.get("max_damage", 0)) * GameState.damage_mult))])
				lines.append("[b]Draw[/b]  %.2f s   ·   [b]Arrows[/b]  %d" % [float(d.get("draw_time", 0.8)) / GameState.draw_mult, GameState.count("arrow")])
			else:
				if d.has("bonus_damage"):
					lines.append("[b]Bonus damage[/b]  +%d" % int(d.bonus_damage))
				lines.append("[b]Carried[/b]  %d" % GameState.count(id))
		"eat":
			lines.append("[b]Restores[/b]  %d health" % int(d.get("heal", 0)))
	if d.has("sell"):
		lines.append("[b]Worth[/b]  about %d coin" % int(d.sell))
	return "\n".join(lines)


# ------------------------------------------------------------ interaction
func _slot_under_mouse() -> int:
	var m = get_global_mouse_position()
	for s in _slots:
		if s.get_global_rect().has_point(m):
			return s.index
	return -1


func _on_hovered(slot: ItemSlot, on: bool) -> void:
	_hover = slot.index if on else (-1 if _hover == slot.index else _hover)
	_show_detail()


func _on_pressed(slot: ItemSlot, button: int) -> void:
	var i = slot.index
	var s = GameState.slot(i)
	if button == MOUSE_BUTTON_LEFT:
		if held == null:
			if s != null:
				held = {"id": String(s.id), "n": int(s.n)}
				held_from = i
				_press_slot = i
				GameState.set_slot(i, null)
				Audio.ui("pick", -6.0)
		else:
			_place_all(i)
			_press_slot = -1
	elif button == MOUSE_BUTTON_RIGHT:
		if held == null:
			if s != null:
				var take = int(ceil(int(s.n) / 2.0))
				held = {"id": String(s.id), "n": take}
				held_from = i
				var rest = int(s.n) - take
				GameState.set_slot(i, null if rest <= 0 else {"id": String(s.id), "n": rest})
				Audio.ui("pick", -6.0)
		else:
			_place_one(i)
		_press_slot = -1
	_show_detail()
	_held_view.queue_redraw()


func _on_released(_slot: ItemSlot, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT or _press_slot < 0 or held == null:
		_press_slot = -1
		return
	var j = _slot_under_mouse()
	if j >= 0 and j != _press_slot:
		_place_all(j)    # a drag from one slot to another
	_press_slot = -1
	_held_view.queue_redraw()


func _place_all(i: int) -> void:
	var s = GameState.slot(i)
	if s == null:
		GameState.set_slot(i, held)
		held = null
	elif String(s.id) == String(held.id):
		var lim = GameState.stack_limit(String(held.id))
		var put = min(int(held.n), lim - int(s.n))
		if put > 0:
			GameState.set_slot(i, {"id": String(s.id), "n": int(s.n) + put})
			held.n = int(held.n) - put
			if int(held.n) <= 0:
				held = null
		else:
			# full stack of the same thing: swap the two
			GameState.set_slot(i, held)
			held = {"id": String(s.id), "n": int(s.n)}
	else:
		GameState.set_slot(i, held)
		held = {"id": String(s.id), "n": int(s.n)}
		held_from = i
	Audio.ui("place", -6.0)


func _place_one(i: int) -> void:
	var s = GameState.slot(i)
	if s == null:
		GameState.set_slot(i, {"id": String(held.id), "n": 1})
	elif String(s.id) == String(held.id) and int(s.n) < GameState.stack_limit(String(s.id)):
		GameState.set_slot(i, {"id": String(s.id), "n": int(s.n) + 1})
	else:
		return
	held.n = int(held.n) - 1
	if int(held.n) <= 0:
		held = null
	Audio.ui("place", -8.0)


func _eat_hovered() -> void:
	var i = _hover
	var s = GameState.slot(i)
	if s == null:
		return
	var d: Dictionary = DB.item(String(s.id))
	if d.get("use", "") != "eat" or GameState.hp >= GameState.max_hp:
		return
	var rest = int(s.n) - 1
	GameState.set_slot(i, null if rest <= 0 else {"id": String(s.id), "n": rest})
	GameState.heal(int(d.get("heal", 0)))
	GameState.bump("food_eaten")
	Audio.sfx("eat", -4.0)
	_refresh()


## Puts whatever is on the cursor back: its old slot, then anywhere it fits,
## and as a last resort on the ground at Feyre's feet.
func return_held() -> void:
	if held == null:
		return
	var id = String(held.id)
	var n = int(held.n)
	held = null
	var s = GameState.slot(held_from)
	if held_from >= 0 and s == null:
		GameState.set_slot(held_from, {"id": id, "n": n})
		return
	var left = GameState.add_item(id, n, true)
	if left > 0:
		var r = Router.current_region
		if r != null and r.player != null:
			var p = load("res://scripts/combat/pickup.gd").new()
			p.setup(id, left, r.player.global_position + Vector2(0, 30))
			r.world.add_child(p)
			UI.toast("No room: %s left on the ground." % DB.item_name(id))


func _process(_delta: float) -> void:
	if held != null:
		_held_view.queue_redraw()


func _draw_held() -> void:
	if held == null:
		return
	var m = _held_view.get_global_mouse_position()
	var tex: Texture2D = Art.tex(String(DB.item(String(held.id)).get("icon", "")))
	var sz = Vector2(SLOT_PX, SLOT_PX) * 0.85
	if tex:
		_held_view.draw_texture_rect(tex, Rect2(m - sz * 0.35, sz), false)
	if int(held.n) > 1:
		var f = Art.font("caps")
		var p = m + Vector2(sz.x * 0.42, sz.y * 0.62)
		_held_view.draw_string_outline(f, p, str(held.n), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color(0, 0, 0, 0.9))
		_held_view.draw_string(f, p, str(held.n), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Art.PARCHMENT)
