extends CanvasLayer
## HUD, fades, toasts and every modal screen (rewards, shop, upgrade, journal,
## deck, game over, end of slice). Built in code so it stays readable as text.

var root: Control
var hud: Control
var fade: ColorRect
var toasts: VBoxContainer
var modal_layer: Control
var modal_open = false
## Set by the screenshot tour / autotest: modal screens auto-pick their default after a moment.
var auto := false

var _hp_bar: ProgressBar
var _hp_label: Label
var _coin_label: Label
var _tier_label: Label
var _power_bar: ProgressBar
var _chapter_label: Label
var _objective_label: Label
var _collection_label: Label
var _prompt: Label


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)
	toasts = VBoxContainer.new()
	toasts.anchor_left = 0.5
	toasts.anchor_right = 0.5
	toasts.offset_left = -500
	toasts.offset_right = 500
	toasts.offset_top = 150
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 8)
	root.add_child(toasts)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	GameState.changed.connect(_refresh_hud)
	GameState.toast.connect(toast)
	show_hud(false)


# --------------------------------------------------------------------- HUD
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	var left = PanelContainer.new()
	left.add_theme_stylebox_override("panel", Art.panel_style(Color(0.06, 0.05, 0.08, 0.78), Art.GOLD_DIM, 10))
	left.position = Vector2(28, 24)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(left)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	left.add_child(v)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	v.add_child(top)
	top.add_child(Art.label("FEYRE", 26, Art.GOLD, "caps"))
	_hp_label = Art.label("", 24)
	top.add_child(_hp_label)
	_coin_label = Art.label("", 24, Color(0.95, 0.82, 0.5))
	top.add_child(_coin_label)
	_hp_bar = _bar(Color(0.68, 0.14, 0.16), 360, 14)
	v.add_child(_hp_bar)
	_tier_label = Art.label("", 20, Art.PARCHMENT, "italic")
	v.add_child(_tier_label)
	_power_bar = _bar(Art.GOLD, 360, 8)
	v.add_child(_power_bar)

	var right = PanelContainer.new()
	right.add_theme_stylebox_override("panel", Art.panel_style(Color(0.06, 0.05, 0.08, 0.78), Art.GOLD_DIM, 10))
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -620
	right.offset_right = -28
	right.offset_top = 24
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(right)
	var rv = VBoxContainer.new()
	right.add_child(rv)
	_chapter_label = Art.label("", 24, Art.GOLD, "caps")
	rv.add_child(_chapter_label)
	_objective_label = Art.label("", 24)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(560, 0)
	rv.add_child(_objective_label)
	_collection_label = Art.label("", 18, Art.GOLD_DIM, "italic")
	rv.add_child(_collection_label)

	var hint = Art.label("E  interact    J  journal    Tab  deck    Shift  hurry", 20, Color(1, 1, 1, 0.55), "caps")
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 30
	hint.offset_top = -46
	hud.add_child(hint)

	_prompt = Art.label("", 28, Art.PARCHMENT, "caps")
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = -140
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(_prompt)


func _bar(col: Color, w: int, h: int) -> ProgressBar:
	var b = ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.05, 0.9)
	bg.set_corner_radius_all(4)
	bg.border_color = Color(0, 0, 0, 0.6)
	bg.set_border_width_all(1)
	var fg = StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _refresh_hud() -> void:
	_hp_label.text = "%d / %d" % [GameState.hp, GameState.max_hp]
	_hp_bar.max_value = GameState.max_hp
	_hp_bar.value = GameState.hp
	_coin_label.text = "%d coin" % GameState.coins
	var t = DB.tier(GameState.tier)
	_tier_label.text = "Tier %d  ·  %s  ·  power %d" % [GameState.tier, t.get("name", "?"), GameState.power_score()]
	_power_bar.value = GameState.tier_progress() * 100.0
	var ch = DB.chapter(GameState.chapter)
	_chapter_label.text = "Chapter %d  ·  %s" % [GameState.chapter, ch.get("title", "")]
	_objective_label.text = GameState.objective
	var cp = GameState.collection_progress()
	_collection_label.text = "Cards %d/%d   Relics %d/%d   Journal %d/%d" % [cp.cards, cp.cards_total, cp.relics, cp.relics_total, cp.lore, cp.lore_total]


func show_hud(v: bool) -> void:
	hud.visible = v
	_refresh_hud()


func set_prompt(text: String) -> void:
	_prompt.text = text


# ------------------------------------------------------------ transitions
func fade_out(t := 0.4) -> void:
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw = create_tween()
	tw.tween_property(fade, "color:a", 1.0, t)
	await tw.finished


func fade_in(t := 0.5) -> void:
	var tw = create_tween()
	tw.tween_property(fade, "color:a", 0.0, t)
	await tw.finished
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash_to_battle() -> void:
	fade.color = Color(1, 0.95, 0.85, 0)
	var tw = create_tween()
	tw.tween_property(fade, "color:a", 0.9, 0.08)
	tw.tween_property(fade, "color", Color(0, 0, 0, 1), 0.35)
	shake(14)
	await tw.finished


func shake(strength := 10.0) -> void:
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return
	var tw = create_tween()
	for i in 8:
		var off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - i / 8.0)
		tw.tween_property(cam, "offset", off, 0.035)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)


func toast(text: String) -> void:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.panel_style(Color(0.18, 0.06, 0.09, 0.92), Art.GOLD, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l = Art.label(text, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.modulate.a = 0.0
	toasts.add_child(p)
	var tw = create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func chapter_card(n: int) -> void:
	var ch = DB.chapter(n)
	var c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	var a = Art.label("CHAPTER %d" % n, 40, Art.GOLD_DIM, "caps")
	var b = Art.label(ch.get("title", ""), 84, Art.PARCHMENT, "caps")
	for l in [a, b]:
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_child(l)
	a.offset_top = -120
	a.offset_bottom = -120
	c.modulate.a = 0.0
	modal_layer.add_child(c)
	var tw = create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.6)
	tw.tween_property(c, "modulate:a", 0.0, 0.7)
	await tw.finished
	c.queue_free()
	_refresh_hud()


func fade_to_black_card(text: String) -> void:
	await fade_out(1.0)
	var l = Art.label(text, 40, Art.PARCHMENT, "italic")
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0
	root.add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	await tw.finished
	l.queue_free()
	await fade_in(1.0)


# -------------------------------------------------------------- modal kit
func _modal(title: String, width := 1500, height := 860) -> Array:
	## Returns [overlay, content VBox]. Caller frees overlay.
	modal_open = true
	_place_toasts(true)
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.panel_style(Color(0.07, 0.055, 0.08, 0.97), Art.GOLD, 16, 3))
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -width / 2.0
	p.offset_right = width / 2.0
	p.offset_top = -height / 2.0
	p.offset_bottom = height / 2.0
	overlay.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var t = Art.label(title, 44, Art.GOLD, "caps")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	overlay.modulate.a = 0.0
	modal_layer.add_child(overlay)
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.2)
	return [overlay, v]


func _close_modal(overlay: Control) -> void:
	var tw = create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	await tw.finished
	overlay.queue_free()
	modal_open = modal_layer.get_child_count() > 1
	_place_toasts(modal_open)


## Toasts sit under the HUD normally, and drop to the bottom edge while a modal
## is open so they never cover the modal's title or its buttons.
func _place_toasts(bottom: bool) -> void:
	toasts.anchor_top = 1.0 if bottom else 0.0
	toasts.anchor_bottom = toasts.anchor_top
	toasts.offset_top = -100 if bottom else 150
	toasts.offset_bottom = -40 if bottom else 150
	toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END


func _card_row(cards: Array, descs: Array = []) -> Array:
	## Returns [ScrollContainer, Array[CardView]]
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var flow = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 26)
	flow.add_theme_constant_override("v_separation", 26)
	sc.add_child(flow)
	var views: Array = []
	for i in cards.size():
		var holder = MarginContainer.new()
		holder.add_theme_constant_override("margin_top", 16)
		holder.add_theme_constant_override("margin_left", 14)
		var cv = CardView.new()
		cv.setup(cards[i], descs[i] if i < descs.size() else "")
		holder.add_child(cv)
		flow.add_child(holder)
		views.append(cv)
		cv.hovered.connect(func(view, on): view.scale = Vector2(1.06, 1.06) if on else Vector2.ONE)
	return [sc, views]


## Shows cards; returns picked index or -1 (skip/close).
func pick_card(title: String, cards: Array, subtitle := "", skip_text := "Skip") -> int:
	var m = _modal(title)
	var overlay: Control = m[0]
	var v: VBoxContainer = m[1]
	if subtitle != "":
		var s = Art.label(subtitle, 26, Art.PARCHMENT, "italic")
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	var row = _card_row(cards)
	v.add_child(row[0])
	var result = [-2]
	for i in row[1].size():
		var idx = i
		row[1][i].clicked.connect(func(_cv): result[0] = idx)
	var b = Art.button(skip_text, 26)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): result[0] = -1)
	v.add_child(b)
	var waited = 0.0
	while result[0] == -2:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if auto and waited > 1.2:
			result[0] = 0 if cards.size() > 0 else -1
	await _close_modal(overlay)
	return result[0]


func _roll_cards(pools: Array, n := 3) -> Array:
	var out: Array = []
	var used = {}
	for i in n:
		var pool_name: String = pools[min(i, pools.size() - 1)]
		if randf() < 0.12:
			pool_name = "hunter_rare"
		var pool: Array = DB.card_pools.get(pool_name, []).filter(func(id):
			return not used.has(id) and int(DB.cards[id].get("min_tier", 0)) <= GameState.tier)
		if pool.is_empty():
			pool = DB.card_pools.get("hunter_common", []).filter(func(id): return not used.has(id))
		if pool.is_empty():
			continue
		var id: String = pool[randi() % pool.size()]
		used[id] = true
		out.append({"uid": 0, "id": id, "up": false})
	return out


func card_reward(pools: Array) -> void:
	var cards = _roll_cards(pools)
	for c in cards:
		GameState.seen_cards[c.id] = true
	var i = await pick_card("Choose a card", cards, "Add one to your deck, or skip to keep it lean.")
	if i >= 0:
		GameState.add_card(cards[i].id)


func upgrade_picker() -> void:
	var options: Array = GameState.deck.filter(func(c): return not c.up and DB.cards[c.id].has("upgrade"))
	if options.is_empty():
		toast("Nothing left to sharpen.")
		return
	var previews: Array = []
	for c in options:
		previews.append({"uid": c.uid, "id": c.id, "up": true})
	var i = await pick_card("Sharpen a card", previews, "Upgraded versions shown. Choose one to keep.", "Not now")
	if i >= 0:
		GameState.upgrade_card_uid(int(options[i].uid))


func remove_picker() -> bool:
	var i = await pick_card("Remove a card", GameState.deck, "Thin the deck. The card is gone for good.", "Cancel")
	if i >= 0:
		var c: Dictionary = GameState.deck[i]
		GameState.remove_card_uid(int(c.uid))
		toast("Removed: " + DB.card_effective(c.id, c.up).name)
		return true
	return false


func open_deck() -> void:
	if modal_open:
		return
	await pick_card("Your deck (%d cards)" % GameState.deck.size(), GameState.deck, "Tab to close.", "Close")


# -------------------------------------------------------------- popups
func relic_popup(id: String) -> void:
	var r: Dictionary = DB.relics[id]
	var m = _modal("Relic", 900, 560)
	var v: VBoxContainer = m[1]
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	var icon = TextureRect.new()
	icon.texture = Art.tex("relics/%s.png" % id)  # final art in assets/final/relics wins
	icon.custom_minimum_size = Vector2(160, 160)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)
	var tv = VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(Art.label(r.name, 40, Art.GOLD, "caps"))
	var e = Art.label(r.text, 30)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(e)
	var f = Art.label(r.get("flavor", ""), 26, Art.GOLD_DIM, "italic")
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(f)
	await _ok_button(v, m[0])


func tier_popup(n: int) -> void:
	var t = DB.tier(n)
	var m = _modal("Power rises", 1000, 600)
	var v: VBoxContainer = m[1]
	var name_l = Art.label("Tier %d  ·  %s" % [n, t.name], 46, Art.PARCHMENT, "caps")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var c = Art.label(t.get("canon", ""), 28, Art.GOLD_DIM, "italic")
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var s = Art.label("Max HP %d    Energy %d    Hand %d    Unlocks: %s" % [t.max_hp, t.energy, t.hand_size, ", ".join(t.get("unlocks", []))], 30)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var bar = _bar(Art.GOLD, 800, 18)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.value = 0
	v.add_child(bar)
	var road = Art.label("Book 1 power curve: Tier %d of %d. Made Fae waits at the end." % [n, DB.tiers.size() - 1], 22, Art.GOLD_DIM, "italic")
	road.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(road)
	create_tween().tween_property(bar, "value", GameState.tier_progress() * 100.0, 1.2).set_trans(Tween.TRANS_CUBIC)
	await _ok_button(v, m[0])


func _ok_button(v: VBoxContainer, overlay: Control, text := "Continue") -> void:
	var done = [false]
	var b = Art.button(text, 28)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): done[0] = true)
	v.add_child(b)
	b.grab_focus.call_deferred()
	var waited = 0.0
	while not done[0]:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if auto and waited > 1.2:
			done[0] = true
	await _close_modal(overlay)


# ------------------------------------------------------------------ shop
func open_shop(shop_id: String) -> void:
	var s: Dictionary = DB.shops[shop_id]
	var m = _modal(s.name, 1640, 940)
	var overlay: Control = m[0]
	var v: VBoxContainer = m[1]
	var coin_l = Art.label("", 30, Color(0.95, 0.82, 0.5))
	coin_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(coin_l)
	var refresh = func(): coin_l.text = "You have %d coin   ·   satchel %d/%d" % [GameState.coins, GameState.item_count(), DB.item_slots]
	refresh.call()
	var cards_row = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 30)
	v.add_child(cards_row)
	for entry in s.get("cards", []):
		var col = VBoxContainer.new()
		var cv = CardView.new()
		cv.setup({"uid": 0, "id": entry.id, "up": false})
		col.add_child(cv)
		var b = Art.button("Buy  %d" % entry.price, 24)
		var e: Dictionary = entry
		b.pressed.connect(func():
			if GameState.coins >= e.price:
				GameState.add_coins(-e.price)
				GameState.add_card(e.id)
				b.disabled = true
				b.text = "Bought"
				refresh.call()
			else:
				toast("Not enough coin."))
		col.add_child(b)
		cards_row.add_child(col)
	var goods = HBoxContainer.new()
	goods.alignment = BoxContainer.ALIGNMENT_CENTER
	goods.add_theme_constant_override("separation", 20)
	v.add_child(goods)
	for entry in s.get("items", []):
		var it: Dictionary = DB.items[entry.id]
		var b2 = Art.button("%s  ·  %d" % [it.name, entry.price], 22)
		b2.tooltip_text = it.text
		var e2: Dictionary = entry
		b2.pressed.connect(func():
			if GameState.coins < e2.price:
				toast("Not enough coin.")
			elif GameState.add_item(e2.id, 1):
				GameState.add_coins(-e2.price)
				refresh.call())
		goods.add_child(b2)
	for entry in s.get("relics", []):
		var r: Dictionary = DB.relics[entry.id]
		var b3 = Art.button("Relic: %s  ·  %d" % [r.name, entry.price], 22)
		b3.tooltip_text = r.text
		var e3: Dictionary = entry
		b3.disabled = GameState.has_relic(e3.id)
		b3.pressed.connect(func():
			if GameState.coins >= e3.price and not GameState.has_relic(e3.id):
				GameState.add_coins(-e3.price)
				GameState.add_relic(e3.id)
				b3.disabled = true
				refresh.call()
			else:
				toast("Not enough coin."))
		goods.add_child(b3)
	var desc = Art.label("Iron Bracelet: take 1 less damage from each hit by a Fae enemy.   Iron Nail: 9 damage to a Fae.", 22, Art.GOLD_DIM, "italic")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 30)
	v.add_child(bottom)
	var rem = Art.button("%s  ·  %d" % [s.get("remove_label", "Remove a card"), s.get("remove_price", 8)], 24)
	var used = [false]
	rem.pressed.connect(func():
		if used[0]:
			return
		if GameState.coins < int(s.remove_price):
			toast("Not enough coin.")
			return
		overlay.visible = false
		var ok: bool = await remove_picker()
		overlay.visible = true
		if ok:
			GameState.add_coins(-int(s.remove_price))
			used[0] = true
			rem.disabled = true
			refresh.call())
	bottom.add_child(rem)
	var done = [false]
	var leave = Art.button("Leave", 26)
	leave.pressed.connect(func(): done[0] = true)
	bottom.add_child(leave)
	var waited = 0.0
	while not done[0]:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if auto and waited > 1.5:
			done[0] = true
	await _close_modal(overlay)


# --------------------------------------------------------------- journal
func open_journal(tab := 0) -> void:
	if modal_open:
		return
	var m = _modal("Journal", 1700, 960)
	var overlay: Control = m[0]
	var v: VBoxContainer = m[1]
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_override("font", Art.font("caps"))
	tabs.add_theme_font_size_override("font_size", 24)
	v.add_child(tabs)
	tabs.add_child(_journal_tab())
	tabs.add_child(_collection_tab())
	tabs.add_child(_power_tab())
	var mp = MapView.new()
	mp.name = "Map"
	tabs.add_child(mp)
	tabs.current_tab = tab
	var done = [false]
	var b = Art.button("Close", 26)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): done[0] = true)
	v.add_child(b)
	var waited = 0.0
	while not done[0]:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if Input.is_action_just_pressed("journal") and not done[0]:
			done[0] = true
		if auto and waited > 1.5:
			done[0] = true
	await _close_modal(overlay)


func _journal_tab() -> Control:
	var h = HSplitContainer.new()
	h.name = "Lore"
	var list = ItemList.new()
	list.custom_minimum_size = Vector2(460, 0)
	list.add_theme_font_override("font", Art.font("serif"))
	list.add_theme_font_size_override("font_size", 28)
	h.add_child(list)
	var detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_override("normal_font", Art.font("serif"))
	detail.add_theme_font_override("italics_font", Art.font("italic"))
	detail.add_theme_font_override("bold_font", Art.font("caps"))
	detail.add_theme_font_size_override("normal_font_size", 32)
	detail.add_theme_font_size_override("italics_font_size", 32)
	detail.add_theme_font_size_override("bold_font_size", 36)
	h.add_child(detail)
	var ids: Array = []
	for id in DB.lore:
		ids.append(id)
		var e: Dictionary = DB.lore[id]
		if id in GameState.journal:
			list.add_item("%s  ·  %s" % [e.category, e.title])
		else:
			list.add_item("??  (Chapter %d)" % e.chapter)
			list.set_item_disabled(list.item_count - 1, true)
	list.item_selected.connect(func(i):
		var e: Dictionary = DB.lore[ids[i]]
		var q = ""
		if e.get("quote") != null and DB.quotes.has(e.quote):
			q = "\n\n[i]“%s”[/i]" % DB.quotes[e.quote].text
		detail.text = "[b]%s[/b]\n[i]Chapter %d · %s[/i]\n\n%s%s" % [e.title, e.chapter, e.category, e.text, q])
	if not GameState.journal.is_empty():
		var first = ids.find(GameState.journal[GameState.journal.size() - 1])
		if first >= 0:
			list.select(first)
			list.item_selected.emit(first)
	return h


func _collection_tab() -> Control:
	var sc = ScrollContainer.new()
	sc.name = "Collection"
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var cp = GameState.collection_progress()
	v.add_child(Art.label("Cards discovered %d / %d" % [cp.cards, cp.cards_total], 30, Art.GOLD, "caps"))
	var flow = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 18)
	v.add_child(flow)
	for id in DB.cards:
		if GameState.seen_cards.has(id):
			var cv = CardView.new()
			cv.setup({"uid": 0, "id": id, "up": false})
			cv.scale = Vector2(0.8, 0.8)
			var holder = Control.new()
			holder.custom_minimum_size = CardView.SIZE * 0.8
			holder.add_child(cv)
			flow.add_child(holder)
		else:
			var p = PanelContainer.new()
			p.custom_minimum_size = CardView.SIZE * 0.8
			p.add_theme_stylebox_override("panel", Art.panel_style(Color(0.1, 0.1, 0.12, 0.9), Color(0.3, 0.3, 0.3), 12))
			var q = Art.label("?", 70, Color(0.4, 0.4, 0.45), "caps")
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			p.add_child(q)
			flow.add_child(p)
	v.add_child(Art.label("Relics %d / %d" % [cp.relics, cp.relics_total], 30, Art.GOLD, "caps"))
	for rid in DB.relics:
		var r: Dictionary = DB.relics[rid]
		var have = GameState.has_relic(rid)
		var l = Art.label(("%s: %s" % [r.name, r.text]) if have else "??  (%s)" % r.rarity, 26, Art.PARCHMENT if have else Color(0.5, 0.5, 0.5))
		v.add_child(l)
	return sc


func _power_tab() -> Control:
	var v = VBoxContainer.new()
	v.name = "Power"
	v.add_theme_constant_override("separation", 8)
	v.add_child(Art.label("Power %d   ·   Strength %d   ·   Energy %d   ·   Hand %d" % [GameState.power_score(), GameState.strength, GameState.energy, GameState.hand_size], 30, Art.GOLD, "caps"))
	var best = 0
	for t in DB.tiers:
		best = max(best, int(t.max_hp) + int(t.energy) * 10 + int(t.hand_size) * 4 + int(t.strength) * 8)
	for t in DB.tiers:
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		var cur = int(t.tier) == GameState.tier
		var reached = int(t.tier) <= GameState.tier
		var name_l = Art.label("%s %d  %s" % ["»" if cur else " ", t.tier, t.name], 28, Art.GOLD if cur else (Art.PARCHMENT if reached else Color(0.5, 0.5, 0.52)), "caps")
		name_l.custom_minimum_size = Vector2(560, 0)
		h.add_child(name_l)
		var bar = _bar(Art.GOLD if reached else Color(0.35, 0.33, 0.3), 520, 16)
		bar.value = 100.0 * float(int(t.max_hp) + int(t.energy) * 10 + int(t.hand_size) * 4 + int(t.strength) * 8) / float(best)
		h.add_child(bar)
		h.add_child(Art.label("Ch %d  ·  HP %d" % [t.chapter, t.max_hp], 24, Color(0.75, 0.72, 0.65)))
		v.add_child(h)
	var note = Art.label("Power tracks canon. It drops Under the Mountain, and soars when she is Made.", 24, Art.GOLD_DIM, "italic")
	v.add_child(note)
	return v


# ----------------------------------------------------------- end states
func game_over() -> void:
	var m = _modal("The snow keeps falling", 1000, 500)
	var v: VBoxContainer = m[1]
	var l = Art.label("Feyre does not come home.", 32, Art.PARCHMENT, "italic")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var choice = [0]
	var b1 = Art.button("Try again from the checkpoint", 28)
	b1.pressed.connect(func(): choice[0] = 1)
	var b2 = Art.button("Return to title", 28)
	b2.pressed.connect(func(): choice[0] = 2)
	v.add_child(b1)
	v.add_child(b2)
	while choice[0] == 0:
		await get_tree().process_frame
	await _close_modal(m[0])
	if choice[0] == 1 and SaveSystem.load_slot("auto"):
		await Router.continue_game()
	else:
		get_tree().reload_current_scene()


func end_slice() -> void:
	SaveSystem.save_slot("slice_complete")
	var m = _modal("End of Milestone 1", 1300, 640)
	var v: VBoxContainer = m[1]
	var t = DB.tier(GameState.tier)
	var cp = GameState.collection_progress()
	var lines = [
		"Feyre has crossed the Wall into Prythian.",
		"Power: Tier %d, %s  (power %d)" % [GameState.tier, t.name, GameState.power_score()],
		"Deck: %d cards   ·   Relics: %d   ·   Coin: %d" % [GameState.deck.size(), GameState.relics.size(), GameState.coins],
		"Collection: cards %d/%d, relics %d/%d, journal %d/%d" % [cp.cards, cp.cards_total, cp.relics, cp.relics_total, cp.lore, cp.lore_total],
		"The doe: %s" % ("brought home whole" if GameState.has_flag("doe_saved") else "torn by the wolf"),
		"Next: Chapter 6, the Spring Court.",
	]
	for s in lines:
		var l = Art.label(s, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var path_l = Art.label("", 22, Art.GOLD_DIM, "italic")
	path_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	path_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var exp_b = Art.button("Export carry-over save for Book 2", 26)
	exp_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	exp_b.pressed.connect(func(): path_l.text = "Written to " + SaveSystem.export_carryover())
	v.add_child(exp_b)
	v.add_child(path_l)
	var done = [false]
	var b = Art.button("Return to title", 26)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): done[0] = true)
	v.add_child(b)
	var waited = 0.0
	while not done[0]:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if auto and waited > 2.0:
			done[0] = true
			return
	await _close_modal(m[0])
	get_tree().reload_current_scene()
