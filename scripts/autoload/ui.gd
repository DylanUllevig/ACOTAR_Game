extends CanvasLayer
## Everything drawn over the world: the HUD, the pause menu (satchel, map,
## journal, options), market stalls, popups, toasts, chapter cards, fades,
## screen shake and the hurt flash. Built in code so it stays readable as text.

var root: Control
var hud: Hud
var fade: ColorRect
var toasts: VBoxContainer
var modal_layer: Control
var modal_open := false
var menu: GameMenu = null
## Set by the screenshot tour / autotest: popups and shops close themselves.
var auto := false

var _shake := 0.0
var _modals: Array = []           # [overlay, cancel Callable] for each open popup


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hud = Hud.new()
	root.add_child(hud)
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)
	toasts = VBoxContainer.new()
	toasts.anchor_left = 0.5
	toasts.anchor_right = 0.5
	toasts.offset_left = -520
	toasts.offset_right = 520
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 8)
	root.add_child(toasts)
	_place_toasts(false)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	GameState.toast.connect(toast)
	show_hud(false)


# --------------------------------------------------------------------- HUD
func show_hud(v: bool) -> void:
	hud.visible = v
	hud.refresh()
	if not v:
		hud.set_prompt("")
		hud.boss_hide()
		hud.stealth_show(false)


func set_prompt(text: String, key := "E") -> void:
	hud.set_prompt(text, key)


func boss_show(boss_name: String, max_hp: int) -> void:
	hud.boss_show(boss_name, max_hp)


func boss_update(hp: int, max_hp: int, ash_struck: bool, regenerating: bool) -> void:
	hud.boss_update(hp, max_hp, ash_struck, regenerating)


func boss_hide() -> void:
	hud.boss_hide()


func stealth_show(v: bool) -> void:
	hud.stealth_show(v)


func stealth_update(hidden: bool, noise_frac: float, alerted: bool) -> void:
	hud.stealth_update(hidden, noise_frac, alerted)


func hurt_flash() -> void:
	hud.hurt_flash()


## Adds trauma; the camera reads it back each frame with take_shake().
func shake(strength := 10.0) -> void:
	_shake = max(_shake, strength * float(Settings.get_v("screen_shake")))


func take_shake(delta: float) -> float:
	var s = _shake
	_shake = max(0.0, _shake - delta * (22.0 + _shake * 5.0))
	return s


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


func toast(text: String) -> void:
	var p = PanelContainer.new()
	var sb = Art.panel_style(Color(0.14, 0.06, 0.08, 0.93), Art.GOLD, 10, 2)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l = Art.label(text, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(min(900, 60 + text.length() * 13), 0)
	p.add_child(l)
	p.modulate.a = 0.0
	toasts.add_child(p)
	while toasts.get_child_count() > 4:
		toasts.get_child(0).free()
	var tw = create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4 + text.length() * 0.02)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func chapter_card(n: int) -> void:
	var ch = DB.chapter(n)
	var c = Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	var a = Art.label("CHAPTER %d" % n, 40, Art.GOLD_DIM, "caps")
	var b = Art.label(ch.get("title", ""), 84, Art.PARCHMENT, "caps")
	for l in [a, b]:
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_child(l)
	a.offset_top = -120
	a.offset_bottom = -120
	c.modulate.a = 0.0
	modal_layer.add_child(c)
	Audio.ui("chapter", -2.0)
	var tw = create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.6)
	tw.tween_property(c, "modulate:a", 0.0, 0.7)
	await tw.finished
	c.queue_free()
	hud.refresh()


func fade_to_black_card(text: String) -> void:
	await fade_out(1.0)
	var l = Art.label(text, 40, Art.PARCHMENT, "italic")
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.offset_left = 200
	l.offset_right = -200
	l.modulate.a = 0.0
	root.add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	await tw.finished
	l.queue_free()
	await fade_in(1.0)


# ------------------------------------------------------------------ menus
func can_open_menu() -> bool:
	return Router.current_region != null and not Router.busy and not Dialogue.active and _modals.is_empty() and menu == null and hud.visible


func open_menu(tab := "inventory") -> void:
	if menu != null:
		menu.show_tab(tab)
		return
	menu = GameMenu.new()
	modal_layer.add_child(menu)
	menu.show_tab(tab)
	menu.closed.connect(_on_menu_closed)
	modal_open = true
	get_tree().paused = true
	hud.set_prompt("")
	Audio.ui("open", -6.0)


func close_menu() -> void:
	if menu != null:
		await menu.close()


func _on_menu_closed() -> void:
	menu = null
	get_tree().paused = false
	_update_modal()


func _update_modal() -> void:
	modal_open = menu != null or not _modals.is_empty()
	_place_toasts(modal_open)


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	if not _modals.is_empty():
		if ev.is_action_pressed("pause"):
			var top: Array = _modals[_modals.size() - 1]
			var cancel: Callable = top[1]
			if cancel.is_valid():
				get_viewport().set_input_as_handled()
				cancel.call()
		return
	if menu != null or not can_open_menu():
		return
	var tab = ""
	if ev.is_action_pressed("pause"):
		tab = "game"
	elif ev.is_action_pressed("inventory"):
		tab = "inventory"
	elif ev.is_action_pressed("map"):
		tab = "map"
	elif ev.is_action_pressed("journal"):
		tab = "journal"
	if tab != "":
		get_viewport().set_input_as_handled()
		open_menu(tab)


# -------------------------------------------------------------- modal kit
## Opens a centred window. Returns [overlay, content VBox]. 'cancel' runs on Esc.
func _modal(title: String, width := 1500, height := 860, cancel := Callable()) -> Array:
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 0.74)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	if title != "":
		var t = Art.label(title, 44, Art.GOLD, "caps")
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	overlay.modulate.a = 0.0
	modal_layer.add_child(overlay)
	_modals.append([overlay, cancel])
	_update_modal()
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.18)
	return [overlay, v]


func _close_modal(overlay: Control) -> void:
	for i in range(_modals.size() - 1, -1, -1):
		if _modals[i][0] == overlay:
			_modals.remove_at(i)
	var tw = create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	await tw.finished
	overlay.queue_free()
	_update_modal()


## Toasts sit under the HUD normally, and drop to the bottom edge while a
## window is open so they never cover its title or buttons.
func _place_toasts(bottom: bool) -> void:
	toasts.anchor_top = 1.0 if bottom else 0.0
	toasts.anchor_bottom = toasts.anchor_top
	toasts.offset_top = -100 if bottom else 210
	toasts.offset_bottom = -40 if bottom else 210
	toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END


func _wait_until(flag: Array, auto_after := 1.4) -> void:
	var waited = 0.0
	while not flag[0]:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if auto and waited > auto_after:
			flag[0] = true


func _ok_button(v: VBoxContainer, overlay: Control, text := "Continue") -> void:
	var done = [false]
	var b = Art.button(text, 28)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(280, 0)
	b.pressed.connect(func(): done[0] = true)
	v.add_child(b)
	b.grab_focus.call_deferred()
	for m in _modals:
		if m[0] == overlay:
			m[1] = func(): done[0] = true
	await _wait_until(done)
	await _close_modal(overlay)


# ------------------------------------------------------------------ shops
func open_shop(shop_id: String) -> void:
	var s: Dictionary = DB.shops.get(shop_id, {})
	var done = [false]
	var m = _modal(String(s.get("name", "Market")), 1560, 900, func(): done[0] = true)
	var sv = ShopView.new()
	sv.setup(shop_id)
	sv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.done.connect(func(): done[0] = true)
	m[1].add_child(sv)
	await _wait_until(done, 1.6)
	await _close_modal(m[0])


# ----------------------------------------------------------------- popups
func tier_popup(n: int) -> void:
	var t = DB.tier(n)
	var m = _modal("Stronger", 1080, 560)
	var v: VBoxContainer = m[1]
	var name_l = Art.label("Tier %d  ·  %s" % [n, t.get("name", "")], 46, Art.PARCHMENT, "caps")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var c = Art.label(String(t.get("canon", "")), 28, Art.GOLD_DIM, "italic")
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var s = Art.label("Health %d   ·   Damage ×%.2f   ·   Speed ×%.2f   ·   Draw ×%.2f" % [int(t.get("max_hp", 0)), float(t.get("damage", 1)), float(t.get("speed", 1)), float(t.get("draw", 1))], 28)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var bar = Meter.new(800, 18)
	bar.fill_color = Art.GOLD
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.set_values(0.0, 1.0, true)
	v.add_child(bar)
	var road = Art.label("Book 1 power curve: tier %d of %d. Made Fae waits at the end." % [n, DB.tiers.size() - 1], 22, Art.GOLD_DIM, "italic")
	road.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(road)
	bar.set_values(GameState.tier_progress(), 1.0)
	Audio.ui("tier", -2.0)
	await _ok_button(v, m[0])


func game_over() -> void:
	Fx.reset_time()
	var choice = [0]
	var m = _modal("The snow keeps falling", 1000, 520)
	var v: VBoxContainer = m[1]
	var l = Art.label("Feyre does not come home.", 32, Art.PARCHMENT, "italic")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var tip = Art.label("Stay hidden for the first shot. Watch for his eyes flaring before he lunges, and step aside.", 24, Art.GOLD_DIM, "italic")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	var b1 = Art.button("Try again", 30)
	b1.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b1.custom_minimum_size = Vector2(420, 0)
	b1.pressed.connect(func(): choice[0] = 1)
	var b2 = Art.button("Return to title", 30)
	b2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b2.custom_minimum_size = Vector2(420, 0)
	b2.pressed.connect(func(): choice[0] = 2)
	v.add_child(b1)
	v.add_child(b2)
	b1.grab_focus.call_deferred()
	var waited = 0.0
	while choice[0] == 0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if auto and waited > 1.5:
			choice[0] = 1
	await _close_modal(m[0])
	if choice[0] == 1 and SaveSystem.load_slot("auto"):
		await Router.continue_game()
	else:
		quit_to_title()


func end_slice() -> void:
	SaveSystem.save_slot("slice_complete")
	var m = _modal("End of Milestone 1", 1300, 680)
	var v: VBoxContainer = m[1]
	var t = DB.tier(GameState.tier)
	var lines = [
		"Feyre has crossed the Wall into Prythian.",
		"Power: tier %d, %s  (power %d)" % [GameState.tier, t.get("name", ""), GameState.power_score()],
		"Coin: %d   ·   Journal: %d of %d entries" % [GameState.coins, GameState.journal.size(), DB.lore.size()],
		"The doe: %s" % ("carried home whole" if GameState.has_flag("doe_saved") else "torn by the wolf"),
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
			return
	await _close_modal(m[0])
	quit_to_title()


## Back to the title screen from anywhere: unpauses, stops the music and
## reloads the main scene (autoload state is reset by the title or New Game).
func quit_to_title() -> void:
	await fade_out(0.5)
	get_tree().paused = false
	Fx.reset_time()
	Audio.music_stop(0.5)
	Audio.ambience_stop(0.5)
	show_hud(false)
	for m in _modals:
		(m[0] as Control).queue_free()
	_modals.clear()
	if menu != null:
		menu.queue_free()
		menu = null
	_update_modal()
	Router.current_region = null
	get_tree().reload_current_scene()
