extends CanvasLayer
## Dialogue: painted portraits slide in over the world, typewriter text in a
## box at the bottom, choices, and the story actions that scenes trigger.
## Also "barks": a short line with a small portrait that plays over a fight
## without stopping it. Content comes from data/book1/dialogue/*.json.
##
## Voice rules (so every scene reads the same way):
##   n     Feyre's narration, first person, past tense. Shown in italics.
##   s/t   a line spoken aloud by that character (e = portrait expression).
##   hint  a game tip, shown on its own gold card, never in Feyre's voice.

signal line_finished
signal scene_finished(id: String)

const TYPE_SPEED := 52.0  # characters per second at "Normal"

var active = false
var _queue_after: Array[Callable] = []
var _box_tw: Tween
var _skip = false
var _advance = false
var _choice_made = -1

var root: Control
var catcher: Control
var box: PanelContainer
var name_plate: PanelContainer
var name_label: Label
var text_label: RichTextLabel
var more: TextureRect
var tip_plate: PanelContainer
var choices_box: VBoxContainer
var left_portrait: TextureRect
var right_portrait: TextureRect
var _left_char = ""
var _right_char = ""
var dim: ColorRect
var _box_sb: StyleBox
var _tip_sb: StyleBox

var _bark_panel: PanelContainer
var _bark_face: Medallion
var _bark_name: Label
var _bark_text: Label
var _barks: Array = []
var _bark_busy = false
var _more_t := 0.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Art.theme()
	add_child(root)

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	left_portrait = _make_portrait(true)
	right_portrait = _make_portrait(false)

	# a click anywhere on screen advances, like the box itself
	catcher = Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catcher.gui_input.connect(_on_box_input)
	root.add_child(catcher)

	box = PanelContainer.new()
	_box_sb = Art.card_style("card", Vector4(52, 38, 56, 26))
	_tip_sb = Art.card_style("card_tip", Vector4(52, 38, 56, 26))
	box.add_theme_stylebox_override("panel", _box_sb)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -770
	box.offset_right = 770
	box.offset_top = -250
	box.offset_bottom = -34
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
	text_label.add_theme_font_override("bold_font", Art.font("bold"))
	text_label.add_theme_font_size_override("normal_font_size", 36)
	text_label.add_theme_font_size_override("italics_font_size", 36)
	text_label.add_theme_font_size_override("bold_font_size", 36)
	text_label.add_theme_color_override("default_color", Art.TEXT)
	text_label.add_theme_constant_override("line_separation", 4)
	box.add_child(text_label)

	name_plate = _plate(Art.ROSE_DEEP, Art.HONEY)
	name_label = Art.label("", 24, Art.PAPER, "caps_wide")
	name_plate.add_child(name_label)
	root.add_child(name_plate)

	tip_plate = _plate(Art.HONEY, Art.HONEY_DEEP)
	tip_plate.add_child(Art.label("TIP", 22, Art.PAPER, "caps_wide"))
	root.add_child(tip_plate)

	# a rose chevron that bobs when the line is done
	more = TextureRect.new()
	more.texture = Art.tex_ui("chevron")
	more.anchor_left = 0.5
	more.anchor_top = 1.0
	more.anchor_right = 0.5
	more.anchor_bottom = 1.0
	more.offset_left = 712
	more.offset_right = 736
	more.offset_top = -78
	more.offset_bottom = -62
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(more)

	choices_box = VBoxContainer.new()
	choices_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choices_box.anchor_left = 0.5
	choices_box.anchor_right = 0.5
	choices_box.anchor_top = 1.0
	choices_box.anchor_bottom = 1.0
	choices_box.offset_left = -520
	choices_box.offset_right = 520
	choices_box.offset_top = -640
	choices_box.offset_bottom = -290
	choices_box.alignment = BoxContainer.ALIGNMENT_END
	choices_box.add_theme_constant_override("separation", 12)
	root.add_child(choices_box)

	_build_bark()
	box.visible = false
	box.modulate.a = 0.0
	name_plate.visible = false
	tip_plate.visible = false
	more.visible = false


func _process(delta: float) -> void:
	if more.visible:
		_more_t += delta
		var y = -80.0 + sin(_more_t * 5.0) * 3.0
		more.offset_top = y
		more.offset_bottom = y + 16.0
	else:
		_more_t = 0.0


func _plate(bg: Color, border: Color) -> PanelContainer:
	var p = PanelContainer.new()
	var sb = Art.pill_style(bg, border, 20, 2, 0.3)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 5
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.anchor_left = 0.5
	p.anchor_top = 1.0
	p.anchor_right = 0.5
	p.anchor_bottom = 1.0
	p.offset_left = -726
	p.offset_top = -274
	p.offset_right = -726
	p.offset_bottom = -230
	p.grow_horizontal = Control.GROW_DIRECTION_END
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _make_portrait(left: bool) -> TextureRect:
	var t = TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.anchor_top = 1.0
	t.anchor_bottom = 1.0
	if left:
		t.anchor_left = 0.0
		t.anchor_right = 0.0
		t.offset_left = 30
		t.offset_right = 670
	else:
		t.anchor_left = 1.0
		t.anchor_right = 1.0
		t.offset_left = -670
		t.offset_right = -30
	t.offset_top = -990
	t.offset_bottom = -40
	t.modulate.a = 0.0
	root.add_child(t)
	return t


# ------------------------------------------------------------------ public
func play(scene_id: String) -> void:
	if not DB.scenes.has(scene_id):
		push_error("Unknown dialogue scene: " + scene_id)
		return
	var was_active = active
	active = true
	if not was_active:
		_open()
	var _stop = await _run_scene(scene_id)
	if not was_active:
		await _close()
		active = false
		scene_finished.emit(scene_id)
		await get_tree().process_frame
		var pending = _queue_after.duplicate()
		_queue_after.clear()
		for c in pending:
			await c.call()


func _open() -> void:
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	create_tween().tween_property(dim, "color:a", 0.28, 0.25)
	UI.set_prompt("")


func _close() -> void:
	catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in choices_box.get_children():
		c.queue_free()
	_hide_portrait(left_portrait)
	_hide_portrait(right_portrait)
	_left_char = ""
	_right_char = ""
	name_plate.visible = false
	tip_plate.visible = false
	more.visible = false
	var tw = create_tween()
	tw.tween_property(dim, "color:a", 0.0, 0.25)
	_fade_box(0.0, 0.18)
	await tw.finished
	if box.modulate.a < 0.01:
		# A closed box holds no text, so the next scene's opening actions (a
		# chapter card, say) cannot bring back this scene's last line, or show
		# the box before its first line has faded it in.
		box.visible = false
		text_label.text = ""
		name_label.text = ""


## Fades the dialogue box. A newer fade replaces an older one, so a line that
## starts while the box is fading out brings it back.
func _fade_box(to: float, t: float) -> void:
	if _box_tw != null and _box_tw.is_valid():
		_box_tw.kill()
	_box_tw = create_tween()
	_box_tw.tween_property(box, "modulate:a", to, t)


## Returns true if a terminal action ended the scene early.
func _run_scene(scene_id: String) -> bool:
	var lines: Array = DB.scenes[scene_id].get("lines", [])
	for line in lines:
		if not cond_ok(line):
			continue
		if line.has("do"):
			for a in line.do:
				if await _run_action(a):
					return true
		if line.has("n"):
			await _show_line("", "", String(line.n))
		elif line.has("hint"):
			if Settings.get_v("show_hints"):
				await _show_line("", "tip", String(line.hint))
		elif line.has("t") and line.has("s"):
			await _show_line(String(line.s), String(line.get("e", "neutral")), String(line.t))
		if line.has("choices"):
			var opts: Array = line.choices.filter(func(c): return cond_ok(c))
			if not opts.is_empty():
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


func cond_ok(d: Dictionary) -> bool:
	if d.has("if_flag") and not GameState.has_flag(d.if_flag):
		return false
	if d.has("if_not_flag") and GameState.has_flag(d.if_not_flag):
		return false
	if d.has("if_item") and not GameState.has_item(d.if_item):
		return false
	if d.has("if_not_item") and GameState.has_item(d.if_not_item):
		return false
	if d.has("if_chapter") and GameState.chapter != int(d.if_chapter):
		return false
	return true


# ------------------------------------------------------------------- lines
func _show_line(speaker: String, expr: String, text: String) -> void:
	if not box.visible or box.modulate.a < 1.0:
		box.visible = true
		_fade_box(1.0, 0.18)
	var tip = expr == "tip"
	box.add_theme_stylebox_override("panel", _tip_sb if tip else _box_sb)
	tip_plate.visible = tip
	if speaker == "":
		name_label.text = ""
		name_plate.visible = false
		text_label.text = text if tip else "[i][color=#5a3f35]" + text + "[/color][/i]"
		if not tip:
			_focus(null)
	else:
		name_label.text = DB.character_name(speaker).to_upper()
		name_plate.visible = true
		text_label.text = text
		_set_portrait(speaker, expr)
	text_label.visible_characters = 0
	more.visible = false
	_skip = false
	_advance = false
	var total = text_label.get_total_character_count()
	var shown = 0.0
	var speed = TYPE_SPEED * float(Settings.get_v("text_speed"))
	while shown < total and not _skip:
		shown += speed * get_process_delta_time() * (1.0 if not Input.is_action_pressed("sprint") else 4.0)
		text_label.visible_characters = int(shown)
		await get_tree().process_frame
	text_label.visible_characters = -1
	more.visible = true
	_advance = false
	while not _advance:
		await get_tree().process_frame
	more.visible = false
	Audio.ui("dialogue_next", -14.0)
	line_finished.emit()


func _set_portrait(speaker: String, expr: String) -> void:
	var left = speaker == "feyre"
	var tr = left_portrait if left else right_portrait
	var tex = Art.portrait(speaker, expr)
	var current = _left_char if left else _right_char
	tr.texture = tex
	var base_l = 30.0 if left else -670.0
	if current != speaker:
		var from = base_l - 160.0 if left else base_l + 160.0
		tr.offset_left = from
		tr.offset_right = from + 640
		tr.modulate.a = 0.0
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(tr, "offset_left", base_l, 0.35)
		tw.tween_property(tr, "offset_right", base_l + 640, 0.35)
		tw.tween_property(tr, "modulate:a", 1.0, 0.3)
		if left:
			_left_char = speaker
		else:
			_right_char = speaker
	else:
		var tw2 = create_tween()
		tw2.tween_property(tr, "offset_top", -1004.0, 0.08)
		tw2.tween_property(tr, "offset_top", -990.0, 0.12)
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
		var b = Art.button(str(i + 1) + ".  " + String(o.t), 28)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# roomier pills; the choice the keys will take is rose, like the one
		# under the mouse (styles come from the theme: the button has no
		# parent yet to inherit them from)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb: StyleBoxFlat = Art.theme().get_stylebox("hover" if st == "focus" else st, "Button").duplicate()
			sb.content_margin_left = 30
			sb.content_margin_right = 30
			sb.content_margin_top = 10
			sb.content_margin_bottom = 12
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_focus_color", Art.PAPER)
		var idx = i
		b.pressed.connect(func(): _choice_made = idx)
		b.modulate.a = 0.0
		choices_box.add_child(b)
		create_tween().tween_property(b, "modulate:a", 1.0, 0.15).set_delay(0.05 * i)
		i += 1
	if choices_box.get_child_count() > 0:
		(choices_box.get_child(0) as Button).grab_focus.call_deferred()
	while _choice_made < 0:
		await get_tree().process_frame
	for c in choices_box.get_children():
		c.queue_free()
	Audio.ui("choice", -8.0)
	return _choice_made


# ------------------------------------------------------------------- input
func _on_box_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and active:
		if choices_box.get_child_count() == 0:
			_press()


func _unhandled_input(ev: InputEvent) -> void:
	if not active:
		return
	if ev.is_action_pressed("interact") or ev.is_action_pressed("advance") or ev.is_action_pressed("use_item"):
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


# ------------------------------------------------------------------- barks
func _build_bark() -> void:
	_bark_panel = PanelContainer.new()
	_bark_panel.add_theme_stylebox_override("panel", Art.card_style("card", Vector4(16, 14, 30, 14)))
	_bark_panel.anchor_left = 0.5
	_bark_panel.anchor_right = 0.5
	_bark_panel.anchor_top = 1.0
	_bark_panel.anchor_bottom = 1.0
	_bark_panel.offset_left = -470
	_bark_panel.offset_right = 470
	_bark_panel.offset_top = -420
	_bark_panel.offset_bottom = -290
	_bark_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bark_panel.visible = false
	root.add_child(_bark_panel)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_bark_panel.add_child(h)
	_bark_face = Medallion.new(100)
	_bark_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_bark_face)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	_bark_name = Art.label("", 20, Art.ROSE_DEEP, "caps_wide")
	v.add_child(_bark_name)
	_bark_text = Art.label("", 28, Art.TEXT, "serif")
	_bark_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_bark_text)


## A line over the action: the fight does not stop for it. Barks wait for a
## full scene to finish. A scene that starts while one is showing ends it,
## along with any queued before the scene, since the moment they spoke to has
## passed.
func bark(speaker: String, expr: String, text: String) -> void:
	_barks.append([speaker, expr, text])
	if _bark_busy:
		return
	_bark_busy = true
	while not _barks.is_empty():
		while active:
			await get_tree().process_frame
		if _barks.is_empty():
			break
		var b: Array = _barks.pop_front()
		_bark_name.text = DB.character_name(b[0]).to_upper()
		_bark_text.text = String(b[2])
		var ptex = Art.portrait(String(b[0]), String(b[1]))
		# a voice with no face (the Bogge, someone in the crowd) gets no
		# empty frame
		_bark_face.visible = ptex != null
		if ptex != null:
			_bark_face.set_face(ptex, Medallion.default_region(ptex))
		_bark_panel.visible = true
		_bark_panel.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(_bark_panel, "modulate:a", 1.0, 0.2)
		var hold = 2.4 + String(b[2]).length() * 0.045
		var t = 0.0
		while t < hold and not active:
			await get_tree().process_frame
			t += get_process_delta_time()
		if active:
			tw.kill()
			_bark_panel.visible = false
			_barks.clear()
			continue
		var tw2 = create_tween()
		tw2.tween_property(_bark_panel, "modulate:a", 0.0, 0.3)
		await tw2.finished
	_bark_panel.visible = false
	_bark_busy = false


# ----------------------------------------------------------------- actions
## Returns true when the action ends the current scene (goto, game over...).
func _run_action(a: Dictionary) -> bool:
	match String(a.type):
		"chapter_card":
			GameState.chapter = int(a.n)
			# the last chapter's task is done; the scene sets the next one
			GameState.set_objective("")
			_set_box_hidden(true)
			await UI.chapter_card(int(a.n))
			_set_box_hidden(false)
		"objective":
			GameState.set_objective(String(a.text))
		"journal":
			GameState.unlock_lore(String(a.id))
		"place":
			GameState.discover_place(String(a.id))
		"set_flag":
			GameState.set_flag(String(a.flag), a.get("value", true))
		"item":
			GameState.add_item(String(a.id), int(a.get("n", 1)))
		"take_item":
			var id: String = a.id
			var want = a.get("n", 1)
			var n = GameState.count(id) if typeof(want) == TYPE_STRING else min(int(want), GameState.count(id))
			if n > 0:
				GameState.remove_item(id, n)
				if a.has("toast"):
					UI.toast(String(a.toast))
		"coins":
			GameState.add_coins(int(a.n))
		"heal":
			GameState.heal(int(a.amount))
		"heal_full":
			GameState.set_hp(GameState.max_hp)
		"unlock_tier":
			GameState.apply_tier(int(a.tier), false)
			GameState.set_hp(GameState.max_hp)
			_set_box_hidden(true)
			await UI.tier_popup(int(a.tier))
			_set_box_hidden(false)
		"open_shop":
			_set_box_hidden(true)
			await UI.open_shop(String(a.shop))
			_set_box_hidden(false)
		"sell_hides":
			var total = 0
			for id2 in DB.hide_prices:
				var c = GameState.count(id2)
				if c > 0:
					GameState.remove_item(id2, c)
					total += int(DB.hide_prices[id2]) * c
			if total > 0:
				GameState.add_coins(total)
		"leave_coins":
			# Chapter 4: she leaves what she has for her family
			var left = GameState.coins
			if left > 0:
				GameState.coins = 0
				GameState.changed.emit()
				UI.toast("You leave %d coin on the dresser for them." % left)
		"save_checkpoint":
			SaveSystem.save_slot("auto")
			UI.toast("Saved.")
		"time":
			GameState.hour = float(a.hour)
			GameState.changed.emit()
		"shake":
			UI.shake(float(a.get("strength", 10)))
		"sfx":
			Audio.sfx(String(a.name), float(a.get("db", 0.0)))
		"music":
			if String(a.name) == "":
				Audio.music_stop(float(a.get("fade", 2.0)))
			else:
				Audio.music(String(a.name), float(a.get("fade", 2.0)))
		"region_call":
			var r = Router.current_region
			if r and r.has_method(String(a.method)):
				await r.callv(String(a.method), a.get("args", []))
		"outfit":
			GameState.outfit = String(a.id)
			var rp = Router.current_region
			if rp and "player" in rp and rp.player != null and rp.player.has_method("refresh_outfit"):
				rp.player.refresh_outfit()
		"start_fight":
			var fid: String = a.id
			_queue_after.append(func():
				if Router.current_region and Router.current_region.has_method("start_fight"):
					Router.current_region.start_fight(fid))
			return true
		"door_burst":
			if Router.current_region and Router.current_region.has_method("door_burst"):
				Router.current_region.door_burst()
		"fade_to_black":
			_set_box_hidden(true)
			await UI.fade_to_black_card(String(a.get("text", "")))
			_set_box_hidden(false)
		"start_hunt":
			_queue_after.append(func():
				if Router.current_region and Router.current_region.has_method("start_hunt"):
					Router.current_region.start_hunt())
			return true
		"goto":
			if a.has("chapter"):
				GameState.chapter = int(a.chapter)
			if a.has("hour"):
				GameState.hour = float(a.hour)
			var rg: String = a.region
			var sp: String = a.get("spawn", "")
			_queue_after.append(func(): await Router.goto_region(rg, sp))
			return true
		"game_over":
			var go_t = String(a.get("title", ""))
			var go_l = String(a.get("line", ""))
			var go_tip = String(a.get("tip", ""))
			_queue_after.append(func(): await UI.game_over(go_t, go_l, go_tip))
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
	box.visible = not h and text_label.text != ""
	if box.visible and box.modulate.a < 1.0:
		_fade_box(1.0, 0.12)
	name_plate.visible = not h and name_label.text != ""
	if h:
		tip_plate.visible = false
		more.visible = false
