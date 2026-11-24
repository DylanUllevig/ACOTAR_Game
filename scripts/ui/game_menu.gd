class_name GameMenu
extends Control
## The pause menu. One window with tabs: Satchel, Map, Journal, Options, Game.
## The world is paused while it is open. Tab/I, M and J jump straight to their
## page (and close it again); Esc always closes.

signal closed

const TABS := [
	["inventory", "Satchel", "Tab"],
	["map", "Map", "M"],
	["journal", "Journal", "J"],
	["options", "Options", ""],
	["game", "Game", "Esc"],
]

var current := ""
var _tab_buttons := {}
var _pages := {}
var _content: Control
var _panel: PanelContainer
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Art.panel_style(Color(0.07, 0.055, 0.075, 0.97), Art.GOLD, 16, 3))
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -780
	_panel.offset_right = 780
	_panel.offset_top = -470
	_panel.offset_bottom = 470
	add_child(_panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_panel.add_child(v)
	var tabs = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	for t in TABS:
		var b = Art.button(t[1] if t[2] == "" else "%s   %s" % [t[1], t[2]], 24)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(230, 54)
		var id: String = t[0]
		b.pressed.connect(func(): show_tab(id))
		tabs.add_child(b)
		_tab_buttons[id] = b
	var sep = ColorRect.new()
	sep.color = Color(Art.GOLD_DIM, 0.5)
	sep.custom_minimum_size = Vector2(0, 2)
	v.add_child(sep)
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("margin_left", 16)
	_content.add_theme_constant_override("margin_right", 16)
	v.add_child(_content)
	modulate.a = 0.0
	scale = Vector2(1, 1)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.16)


func show_tab(id: String) -> void:
	if current == id:
		_tab_buttons[id].button_pressed = true
		return
	if current == "inventory" and _pages.has("inventory"):
		_pages.inventory.return_held()
	current = id
	for k in _tab_buttons:
		_tab_buttons[k].button_pressed = k == id
	for k in _pages:
		_pages[k].visible = k == id
	if not _pages.has(id):
		var page: Control
		match id:
			"inventory":
				page = InventoryView.new()
			"map":
				page = MapView.new()
			"journal":
				page = JournalView.new()
			"options":
				page = OptionsView.new()
			"game":
				page = _game_page()
		_pages[id] = page
		_content.add_child(page)
	elif id == "map":
		_pages.map.set_mode(_pages.map.mode)
	Audio.ui("page", -6.0)


func _input(ev: InputEvent) -> void:
	if _closing or not is_visible_in_tree():
		return
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	if ev.is_action_pressed("pause"):
		accept_event_now()
		close()
	elif ev.is_action_pressed("inventory"):
		accept_event_now()
		if current == "inventory":
			close()
		else:
			show_tab("inventory")
	elif ev.is_action_pressed("map"):
		accept_event_now()
		if current == "map":
			close()
		else:
			show_tab("map")
	elif ev.is_action_pressed("journal"):
		accept_event_now()
		if current == "journal":
			close()
		else:
			show_tab("journal")


func accept_event_now() -> void:
	get_viewport().set_input_as_handled()


func close() -> void:
	if _closing:
		return
	_closing = true
	if _pages.has("inventory"):
		_pages.inventory.return_held()
	Audio.ui("close", -6.0)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	await tw.finished
	closed.emit()
	queue_free()


# ------------------------------------------------------------- game page
func _hunting() -> bool:
	var r = Router.current_region
	return r != null and "hunt" in r and r.hunt != null and is_instance_valid(r.hunt) and not r.hunt.over


func _game_page() -> Control:
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	var ch = DB.chapter(GameState.chapter)
	var title = Art.label("Chapter %d  ·  %s" % [GameState.chapter, ch.get("title", "")], 34, Art.GOLD, "caps")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var parts := PackedStringArray()
	if GameState.objective != "":
		parts.append(GameState.objective)
	parts.append("%s played" % JournalView._time(GameState.playtime))
	var sub = Art.label("   ·   ".join(parts), 24, Art.PARCHMENT, "italic")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var status = Art.label("", 22, Art.GOLD_DIM, "italic")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.custom_minimum_size = Vector2(520, 0)
	v.add_child(buttons)
	var resume = Art.button("Resume", 30)
	resume.pressed.connect(close)
	buttons.add_child(resume)
	var save = Art.button("Save game", 30)
	var hunting = _hunting()
	save.disabled = hunting or Router.current_region == null
	if hunting:
		status.text = "You can't save in the middle of a hunt."
	save.pressed.connect(func():
		if SaveSystem.save_slot("auto"):
			status.text = "Saved."
			Audio.ui("save", -4.0)
		else:
			status.text = "Could not write the save file.")
	buttons.add_child(save)
	var opts = Art.button("Options", 30)
	opts.pressed.connect(func(): show_tab("options"))
	buttons.add_child(opts)
	var title_b = Art.button("Quit to title", 30)
	title_b.pressed.connect(func():
		await close()
		UI.quit_to_title())
	buttons.add_child(title_b)
	var quit = Art.button("Quit game", 30)
	quit.pressed.connect(func(): Audio.quit_game())
	buttons.add_child(quit)
	v.add_child(status)
	var note = Art.label("The game also saves itself at every new area and before each fight.", 22, Art.GOLD_DIM, "italic")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	resume.grab_focus.call_deferred()
	return v
