extends CanvasLayer
## Dialogue pop-ups: painted portraits slide in over the world (or the battle),
## typewriter text, choices, and story actions. Content comes from
## data/book1/dialogue/*.json via DB.scenes.

signal line_finished
signal scene_finished(id: String)

const TYPE_SPEED := 55.0  # characters per second

var active = false
var _queue_after: Array[Callable] = []
var _skip = false
var _advance = false
var _choice_made = -1

var root: Control
var box: PanelContainer
var name_label: Label
var text_label: RichTextLabel
var more: Label
var choices_box: VBoxContainer
var left_portrait: TextureRect
var right_portrait: TextureRect
var _left_char = ""
var _right_char = ""
var dim: ColorRect


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	left_portrait = _make_portrait(true)
	right_portrait = _make_portrait(false)

	box = PanelContainer.new()
	var sb = Art.panel_style(Color(0.06, 0.05, 0.08, 0.93), Art.GOLD_DIM, 14, 2)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 34
	sb.content_margin_bottom = 26
	box.add_theme_stylebox_override("panel", sb)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -760
	box.offset_right = 760
	box.offset_top = -290
	box.offset_bottom = -36
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(_on_box_input)
	root.add_child(box)

	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = false
	text_label.scroll_active = false
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_override("normal_font", Art.font("serif"))
	text_label.add_theme_font_override("italics_font", Art.font("italic"))
	text_label.add_theme_font_size_override("normal_font_size", 36)
	text_label.add_theme_font_size_override("italics_font_size", 36)
	text_label.add_theme_color_override("default_color", Art.PARCHMENT)
	box.add_child(text_label)

	name_label = Art.label("", 30, Art.GOLD, "caps")
	name_label.position = Vector2(box.offset_left + 36, box.offset_top - 26)
	var name_bg = PanelContainer.new()
	var nsb = Art.panel_style(Color(0.24, 0.07, 0.1, 0.97), Art.GOLD, 6, 2)
	nsb.content_margin_top = 4
	nsb.content_margin_bottom = 4
	name_bg.add_theme_stylebox_override("panel", nsb)
	name_bg.anchor_left = 0.5
	name_bg.anchor_top = 1.0
	name_bg.anchor_right = 0.5
	name_bg.anchor_bottom = 1.0
	name_bg.offset_left = -730
	name_bg.offset_top = -318
	name_bg.offset_right = -730
	name_bg.offset_bottom = -272
	name_bg.grow_horizontal = Control.GROW_DIRECTION_END
	name_bg.name = "NamePlate"
	name_bg.add_child(name_label)
	name_label.position = Vector2.ZERO
	root.add_child(name_bg)

	more = Art.label("»", 34, Art.GOLD)
	more.anchor_left = 0.5
	more.anchor_top = 1.0
	more.anchor_right = 0.5
	more.anchor_bottom = 1.0
	more.offset_left = 710
	more.offset_top = -88
	root.add_child(more)

	choices_box = VBoxContainer.new()
	choices_box.anchor_left = 0.5
	choices_box.anchor_right = 0.5
	choices_box.anchor_top = 1.0
	choices_box.anchor_bottom = 1.0
	choices_box.offset_left = -560
	choices_box.offset_right = 560
	choices_box.offset_top = -620
	choices_box.offset_bottom = -320
	choices_box.alignment = BoxContainer.ALIGNMENT_END
	choices_box.add_theme_constant_override("separation", 12)
	root.add_child(choices_box)

	_set_visible(false)


func _make_portrait(left: bool) -> TextureRect:
	var t = TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	t.size = Vector2(600, 900)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.anchor_top = 1.0
	t.anchor_bottom = 1.0
	if left:
		t.anchor_left = 0.0
		t.anchor_right = 0.0
		t.offset_left = 40
		t.offset_right = 640
	else:
		t.anchor_left = 1.0
		t.anchor_right = 1.0
		t.offset_left = -640
		t.offset_right = -40
		# no flip: final portraits are painted facing the right way (style guide),
		# and flipping would mirror their lighting and any text
	t.offset_top = -960
	t.offset_bottom = -60
	t.modulate.a = 0.0
	root.add_child(t)
	return t


func _set_visible(v: bool) -> void:
	box.visible = v
	root.get_node("NamePlate").visible = v and name_label.text != ""
	more.visible = false
	if not v:
		for c in choices_box.get_children():
			c.queue_free()
		_hide_portrait(left_portrait)
		_hide_portrait(right_portrait)
		_left_char = ""
		_right_char = ""
		create_tween().tween_property(dim, "color:a", 0.0, 0.25)


# ------------------------------------------------------------------ public
func play(scene_id: String) -> void:
	if not DB.scenes.has(scene_id):
		push_error("Unknown dialogue scene: " + scene_id)
		return
	var was_active = active
	active = true
	if not was_active:
		create_tween().tween_property(dim, "color:a", 0.25, 0.25)
	var stop = await _run_scene(scene_id)
	if not was_active:
		active = false
		_set_visible(false)
		scene_finished.emit(scene_id)
		await get_tree().process_frame
		var pending = _queue_after.duplicate()
		_queue_after.clear()
		for c in pending:
			await c.call()
	elif stop:
		pass


## Returns true if a terminal action ended the scene early.
func _run_scene(scene_id: String) -> bool:
	var lines: Array = DB.scenes[scene_id].get("lines", [])
	for line in lines:
		if not _cond_ok(line):
			continue
		if line.has("do"):
			for a in line.do:
				if await _run_action(a):
					return true
		if line.has("n"):
			await _show_line("", "", line.n)
		elif line.has("t") and line.has("s"):
			await _show_line(line.s, line.get("e", "neutral"), line.t)
		if line.has("choices"):
			var opts: Array = line.choices.filter(func(c): return _cond_ok(c))
			var picked: int = await _ask(opts)
			var pick: Dictionary = opts[picked]
			for a in pick.get("do", []):
				if await _run_action(a):
					return true
			if pick.has("goto"):
				return await _run_scene(pick.goto)
		if line.has("goto"):
			return await _run_scene(line.goto)
	return false


func _cond_ok(d: Dictionary) -> bool:
	if d.has("if_flag") and not GameState.has_flag(d.if_flag):
		return false
	if d.has("if_not_flag") and GameState.has_flag(d.if_not_flag):
		return false
	return true


# ------------------------------------------------------------------- lines
func _show_line(speaker: String, expr: String, text: String) -> void:
	box.visible = true
	var plate: Control = root.get_node("NamePlate")
	if speaker == "":
		name_label.text = ""
		plate.visible = false
		text_label.text = "[i]" + text + "[/i]"
		_focus(null)
	else:
		name_label.text = DB.character_name(speaker).to_upper()
		plate.visible = true
		text_label.text = text
		_set_portrait(speaker, expr)
	text_label.visible_characters = 0
	more.visible = false
	_skip = false
	_advance = false
	var total = text_label.get_total_character_count()
	var shown = 0.0
	while shown < total and not _skip:
		shown += TYPE_SPEED * get_process_delta_time() * (1.0 if not Input.is_action_pressed("sprint") else 4.0)
		text_label.visible_characters = int(shown)
		await get_tree().process_frame
	text_label.visible_characters = -1
	more.visible = true
	_advance = false
	while not _advance:
		await get_tree().process_frame
	more.visible = false
	line_finished.emit()


func _set_portrait(speaker: String, expr: String) -> void:
	var left = speaker == "feyre"
	var tr = left_portrait if left else right_portrait
	var tex = Art.portrait(speaker, expr)
	var current = _left_char if left else _right_char
	tr.texture = tex
	if current != speaker:
		# slide in
		var base_l = 40.0 if left else -640.0
		var from = base_l - 160.0 if left else base_l + 160.0
		tr.offset_left = from
		tr.offset_right = from + 600
		tr.modulate.a = 0.0
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(tr, "offset_left", base_l, 0.35)
		tw.tween_property(tr, "offset_right", base_l + 600, 0.35)
		tw.tween_property(tr, "modulate:a", 1.0, 0.3)
		if left:
			_left_char = speaker
		else:
			_right_char = speaker
	else:
		# small emphasis pop on expression change
		var tw2 = create_tween()
		tr.scale = Vector2(1.0, 1.0)
		tw2.tween_property(tr, "offset_top", -975.0, 0.08)
		tw2.tween_property(tr, "offset_top", -960.0, 0.12)
	_focus(tr)


func _focus(tr: TextureRect) -> void:
	for p in [left_portrait, right_portrait]:
		if p.modulate.a <= 0.01 and p != tr:
			continue
		var target = Color(1, 1, 1, 1) if p == tr else Color(0.45, 0.45, 0.5, 1)
		create_tween().tween_property(p, "modulate", target, 0.18)


func _hide_portrait(tr: TextureRect) -> void:
	if tr.modulate.a > 0.0:
		create_tween().tween_property(tr, "modulate:a", 0.0, 0.25)


func _ask(opts: Array) -> int:
	more.visible = false
	_choice_made = -1
	for c in choices_box.get_children():
		c.queue_free()
	var i = 0
	for o in opts:
		var b = Art.button(str(i + 1) + ".  " + o.t, 28)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx = i
		b.pressed.connect(func(): _choice_made = idx)
		choices_box.add_child(b)
		i += 1
	if choices_box.get_child_count() > 0:
		(choices_box.get_child(0) as Button).grab_focus.call_deferred()
	while _choice_made < 0:
		await get_tree().process_frame
	for c in choices_box.get_children():
		c.queue_free()
	return _choice_made


# ------------------------------------------------------------------- input
func _on_box_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_press()


func _unhandled_input(ev: InputEvent) -> void:
	if not active:
		return
	if ev.is_action_pressed("interact") or ev.is_action_pressed("advance"):
		if choices_box.get_child_count() == 0:
			_press()
			get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and not ev.echo and choices_box.get_child_count() > 0:
		var n: int = ev.keycode - KEY_1
		if n >= 0 and n < choices_box.get_child_count():
			_choice_made = n
			get_viewport().set_input_as_handled()


func _press() -> void:
	if more.visible:
		_advance = true
	else:
		_skip = true


## For automated tests / screenshots: advance whatever is showing.
func auto_advance() -> void:
	_press()
	if choices_box.get_child_count() > 0:
		_choice_made = 0


# ----------------------------------------------------------------- actions
## Returns true when the action ends the current scene (goto, battle...).
func _run_action(a: Dictionary) -> bool:
	match a.type:
		"chapter_card":
			GameState.chapter = int(a.n)
			await UI.chapter_card(int(a.n))
		"objective":
			GameState.set_objective(a.text)
		"journal":
			GameState.unlock_lore(a.id)
		"set_flag":
			GameState.set_flag(a.flag, a.get("value", true))
		"item":
			GameState.add_item(a.id, int(a.get("n", 1)), a.get("label", ""))
		"relic":
			GameState.add_relic(a.id)
			await UI.relic_popup(a.id)
		"coins":
			GameState.add_coins(int(a.n))
		"heal":
			GameState.hp = min(GameState.max_hp, GameState.hp + int(a.amount))
			GameState.changed.emit()
		"heal_full":
			GameState.hp = GameState.max_hp
			GameState.changed.emit()
		"unlock_tier":
			GameState.apply_tier(int(a.tier))
			await UI.tier_popup(int(a.tier))
		"card_reward":
			await UI.card_reward(a.get("pools", ["hunter_common"]))
		"open_upgrade":
			await UI.upgrade_picker()
			if a.has("flag"):
				GameState.set_flag(a.flag)
		"open_shop":
			_set_box_hidden(true)
			await UI.open_shop(a.shop)
			_set_box_hidden(false)
		"sell_hides":
			var p: Dictionary = DB.hide_prices
			var total = int(p.get("wolf_pelt", 0))
			total += int(p.get("doe_hide", 0)) if GameState.has_flag("doe_saved") else int(p.get("doe_hide_damaged", 0))
			GameState.add_coins(total)
		"remove_card":
			GameState.remove_card_id(a.id, bool(a.get("all", false)))
			if a.has("toast"):
				UI.toast(a.toast)
		"save_checkpoint":
			SaveSystem.save_slot("auto")
			UI.toast("Checkpoint saved.")
		"time":
			GameState.hour = float(a.hour)
			GameState.changed.emit()
		"shake":
			UI.shake(float(a.get("strength", 10)))
		"door_burst":
			if Router.current_region and Router.current_region.has_method("door_burst"):
				Router.current_region.door_burst()
		"fade_to_black":
			_set_box_hidden(true)
			await UI.fade_to_black_card(a.get("text", ""))
			_set_box_hidden(false)
		"start_battle":
			var e: String = a.enemy
			var w: String = a.get("on_win", "")
			var l: String = a.get("on_lose", "")
			_queue_after.append(func(): await Router.start_battle(e, w, l))
			return true
		"goto":
			if a.has("chapter"):
				GameState.chapter = int(a.chapter)
			if a.has("hour"):
				GameState.hour = float(a.hour)
			var r: String = a.region
			var s: String = a.get("spawn", "")
			var oe: String = a.get("on_enter", "")
			_queue_after.append(func(): await Router.goto_region(r, s, oe))
			return true
		"game_over":
			_queue_after.append(func(): await UI.game_over())
			return true
		"wall_cinematic":
			_queue_after.append(func():
				if Router.current_region and Router.current_region.has_method("wall_cinematic"):
					await Router.current_region.wall_cinematic()
				await play("ch05_wake"))
			return true
		"end_slice":
			_queue_after.append(func(): await UI.end_slice())
			return true
		_:
			push_warning("Unknown action " + str(a.type))
	return false


func _set_box_hidden(h: bool) -> void:
	box.visible = not h
	root.get_node("NamePlate").visible = not h and name_label.text != ""
