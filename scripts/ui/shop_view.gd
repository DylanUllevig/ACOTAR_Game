class_name ShopView
extends VBoxContainer
## A market stall: what the keeper sells on the left, what of yours they will
## buy on the right. Prices come from data/shops.json and data/items.json.

signal done

var shop_id := ""
var _def := {}
var _coin_l: Label
var _sell_list: VBoxContainer
var _buy_list: VBoxContainer
var _bought := {}             # id -> times bought this visit (for 'limit')
var _msg: Label


func setup(id: String) -> void:
	shop_id = id
	_def = DB.shops.get(id, {})


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var greet = Art.label("“%s”" % String(_def.get("greeting", "")), 28, Art.PARCHMENT, "italic")
	greet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	greet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(greet)
	var keeper = Art.label(String(_def.get("keeper", "")), 22, Art.GOLD_DIM, "italic")
	keeper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(keeper)
	_coin_l = Art.label("", 30, Color(0.96, 0.84, 0.52), "caps")
	_coin_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_coin_l)
	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cols)
	cols.add_child(_column("For sale", true))
	cols.add_child(_column("They'll buy", false))
	_msg = Art.label("", 24, Art.GOLD, "italic")
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_msg)
	var leave = Art.button("Leave", 28)
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.custom_minimum_size = Vector2(260, 0)
	leave.pressed.connect(func(): done.emit())
	add_child(leave)
	GameState.inventory_changed.connect(_refresh)
	GameState.changed.connect(_refresh_coins)
	_refresh()


func _column(title: String, selling: bool) -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.panel_style(Color(0.09, 0.07, 0.08, 0.95), Art.GOLD_DIM, 12, 2))
	p.custom_minimum_size = Vector2(700, 470)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Art.label(title, 26, Art.GOLD, "caps"))
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	v.add_child(list)
	if selling:
		_sell_list = list
	else:
		_buy_list = list
	return p


func _refresh_coins() -> void:
	if is_instance_valid(_coin_l):
		_coin_l.text = "%d coin" % GameState.coins


func _refresh() -> void:
	_refresh_coins()
	for c in _sell_list.get_children():
		c.queue_free()
	for c in _buy_list.get_children():
		c.queue_free()
	for e in _def.get("sells", []):
		_sell_list.add_child(_sell_row(e))
	var any = false
	for id in _def.get("buys", []):
		var n = GameState.count(String(id))
		if n > 0:
			any = true
			_buy_list.add_child(_buy_row(String(id), n))
	if not any:
		var l = Art.label("Nothing in your satchel they want.", 24, Color(0.6, 0.58, 0.55), "italic")
		_buy_list.add_child(l)


func _row(id: String, label: String) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var icon = TextureRect.new()
	icon.texture = Art.tex(String(DB.item(id).get("icon", "")))
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = String(DB.item(id).get("text", ""))
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(icon)
	var l = Art.label(label, 26)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


func _sell_row(e: Dictionary) -> Control:
	var id = String(e.id)
	var bundle = int(e.get("bundle", 1))
	var price = int(e.price)
	var title = DB.item_name(id) + ("  ×%d" % bundle if bundle > 1 else "")
	var h = _row(id, title)
	var b = Art.button("Buy  %d" % price, 22)
	b.custom_minimum_size = Vector2(150, 0)
	var limit = int(e.get("limit", 0))
	var sold_out = limit > 0 and (int(_bought.get(id, 0)) >= limit or GameState.has_item(id))
	b.disabled = sold_out or GameState.coins < price
	if sold_out:
		b.text = "Sold"
	b.pressed.connect(func(): _buy(id, bundle, price))
	h.add_child(b)
	return h


func _buy_row(id: String, n: int) -> Control:
	var each = int(DB.item(id).get("sell", 1))
	var h = _row(id, "%s  ×%d" % [DB.item_name(id), n])
	var b = Art.button("Sell 1  +%d" % each, 22)
	b.custom_minimum_size = Vector2(150, 0)
	b.pressed.connect(func(): _sell(id, 1, each))
	h.add_child(b)
	if n > 1:
		var b2 = Art.button("All  +%d" % (each * n), 22)
		b2.custom_minimum_size = Vector2(120, 0)
		b2.pressed.connect(func(): _sell(id, GameState.count(id), each))
		h.add_child(b2)
	return h


func _buy(id: String, bundle: int, price: int) -> void:
	if GameState.coins < price:
		_msg.text = "Not enough coin."
		return
	if GameState.space_for(id) < bundle:
		_msg.text = "No room in your satchel."
		return
	GameState.coins -= price
	GameState.add_item(id, bundle)
	_bought[id] = int(_bought.get(id, 0)) + 1
	_msg.text = "Bought %s." % DB.item_name(id)
	Audio.ui("coin", -4.0)
	GameState.changed.emit()


func _sell(id: String, n: int, each: int) -> void:
	if n <= 0 or not GameState.remove_item(id, n):
		return
	GameState.coins += each * n
	_msg.text = "Sold for %d coin." % (each * n)
	Audio.ui("coin", -4.0)
	GameState.changed.emit()
	_refresh()
