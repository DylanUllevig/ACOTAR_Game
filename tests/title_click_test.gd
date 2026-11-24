extends SceneTree
## Plays the opening with synthetic mouse and key events sent through the real
## input path, the way a player would: clicks New Game on the title screen,
## clicks hotbar slots, slashes and shoots with clicks in the world, drags an
## item in the satchel, and clicks Resume on the pause menu. Run it at a few
## window sizes, since the stretch transform is what usually breaks the mouse.
## Needs a display (xvfb-run when headless):
##   godot --path . --resolution 1600x900 --script res://tests/title_click_test.gd
## Exit code 0 = pass.

var _fails: Array[String] = []
var _ui: Node
var _gs: Node
var _router: Node
var _dlg: Node


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Real-time wait for a condition; returns whether it came true.
func _until(cond: Callable, seconds := 10.0) -> bool:
	var t0 = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > seconds * 1000.0:
			return false
		await process_frame
	return true


func _check(ok: bool, what: String) -> void:
	print("CLICKTEST: %s  %s" % ["pass" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


## A position in the UI's canvas (a Control's global rect) to window pixels,
## which is what a real mouse event carries.
func _win(canvas_pos: Vector2) -> Vector2:
	return root.get_final_transform() * canvas_pos


## A point in the world to window pixels, through the camera.
func _win_world(world_pos: Vector2) -> Vector2:
	return _win(root.get_canvas_transform() * world_pos)


func _center(c: Control) -> Vector2:
	return _win(c.get_global_rect().get_center())


## Moves the pointer. The OS cursor is warped too, because the game reads the
## mouse position for aiming and for drops, and that comes from the OS.
func _move(at: Vector2, mask := 0) -> void:
	Input.warp_mouse(at)
	var mv = InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	mv.button_mask = mask
	Input.parse_input_event(mv)
	await _frames(3)


## Sends one button event. Returns whether `watch` held on any of the frames
## after it, for effects too short to check once the click is over.
func _button(at: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT, watch := Callable()) -> bool:
	var ev = InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.button_mask = (1 << (button - 1)) if pressed else 0
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)
	var seen = false
	for i in 3:
		await process_frame
		if watch.is_valid() and watch.call():
			seen = true
	return seen


func _click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await _move(at)
	await _button(at, true, button)
	await _button(at, false, button)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev = InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(3)


## Presses through dialogue with the keyboard: Enter for lines, 1 for choices.
func _press_through() -> void:
	var t0 = Time.get_ticks_msec()
	while _dlg.active and Time.get_ticks_msec() - t0 < 90000:
		if _dlg.choices_box.get_child_count() > 0:
			await _key(KEY_1)
		else:
			await _key(KEY_ENTER)


func _button_named(under: Node, text: String) -> Button:
	for n in under.find_children("*", "Button", true, false):
		if (n as Button).text == text and (n as Button).is_visible_in_tree():
			return n
	return null


func _slots_of(under: Node) -> Array:
	var out = []
	for n in under.find_children("*", "Control", true, false):
		if n.get_script() != null and n.get_script().resource_path.ends_with("item_slot.gd"):
			out.append(n)
	return out


func _run() -> void:
	await _frames(30)
	_ui = root.get_node_or_null("UI")
	_gs = root.get_node_or_null("GameState")
	_router = root.get_node_or_null("Router")
	_dlg = root.get_node_or_null("Dialogue")
	if _ui == null or _gs == null or _router == null or _dlg == null:
		return _finish("autoloads missing")
	root.get_node("SaveSystem").set_dir("user://clicktest_saves/")
	print("CLICKTEST: window %s, canvas %s" % [root.size, root.get_visible_rect().size])

	# --- the title screen
	var new_game: Button = null
	var t0 = Time.get_ticks_msec()
	while new_game == null and Time.get_ticks_msec() - t0 < 10000:
		await process_frame
		new_game = _button_named(current_scene, "New Game")
	if new_game == null:
		return _finish("no New Game button")
	await _frames(30)
	await _click(_center(new_game))
	var loaded = await _until(func(): return _router.current_region != null and not _router.busy, 20.0)
	_check(loaded, "clicking New Game loads the forest")
	if not loaded:
		return _finish()
	await _until(func(): return _dlg.active, 5.0)
	await _press_through()
	_check(not _dlg.active, "Enter and 1 press through the opening dialogue")
	await _frames(20)
	var p = _router.current_region.player
	var slots = _ui.hud._slots

	# --- the hotbar: click a slot, then the wheel over the world
	await _click(_center(slots[1]))
	_check(_gs.hotbar_index == 1, "clicking hotbar slot 2 selects the bow (index %d)" % _gs.hotbar_index)
	var aim = _win_world(p.global_position + Vector2(220, -140))
	await _move(aim)
	await _button(aim, true, MOUSE_BUTTON_WHEEL_UP)
	await _button(aim, false, MOUSE_BUTTON_WHEEL_UP)
	_check(_gs.hotbar_index == 0, "the mouse wheel moves along the hotbar (index %d)" % _gs.hotbar_index)

	# --- the knife: a left click in the world slashes toward the cursor
	await _move(aim)
	var slashed = await _button(aim, true, MOUSE_BUTTON_LEFT, func(): return p.slash_cd > 0.0)
	await _button(aim, false)
	_check(slashed, "a left click in the world slashes with the knife")
	_check(p.aim.x > 0.6 and p.aim.y < 0.0, "the slash aims at the cursor, up and to the right (aim %s)" % p.aim)

	# --- the bow: hold to draw, release to loose an arrow
	await _until(func(): return p.slash_cd <= 0.0, 3.0)
	await _click(_center(slots[1]))
	var arrows = _gs.count("arrow")
	await _move(aim)
	await _button(aim, true)
	var drew = await _until(func(): return p.drawing and p.draw_fraction() > 0.6, 8.0)
	_check(drew, "holding the left button draws the bow")
	await _button(aim, false)
	await _frames(10)
	_check(_gs.count("arrow") == arrows - 1, "releasing looses an arrow (%d -> %d)" % [arrows, _gs.count("arrow")])

	# --- the satchel: Tab opens it; drag a stack to the hotbar, then click it back
	await _key(KEY_TAB)
	var opened = await _until(func(): return _ui.menu != null and _ui.menu.current == "inventory", 5.0)
	_check(opened, "Tab opens the satchel")
	if opened:
		await _frames(20)
		var inv_slots = _slots_of(_ui.menu)
		var src = null
		var dst = null
		for s in inv_slots:
			if s.index >= _gs.hotbar_size() and src == null and _gs.slot(s.index) != null:
				src = s
			if s.index < _gs.hotbar_size() and dst == null and _gs.slot(s.index) == null:
				dst = s
		if src == null or dst == null:
			_check(false, "found a satchel stack and an empty hotbar slot")
		else:
			var si = src.index
			var di = dst.index
			var id = String(_gs.slot(si).id)
			var a = _center(src)
			var b = _center(dst)
			await _move(a)
			await _button(a, true)
			for k in range(1, 7):
				await _move(a.lerp(b, k / 6.0), MOUSE_BUTTON_MASK_LEFT)
			await _button(b, false)
			await _frames(5)
			var moved = _gs.slot(di) != null and String(_gs.slot(di).id) == id and _gs.slot(si) == null
			_check(moved, "dragging %s from satchel slot %d to hotbar slot %d moves it" % [id, si, di])
			# the view may rebuild its slots; find them again by index
			inv_slots = _slots_of(_ui.menu)
			for s in inv_slots:
				if s.index == di:
					dst = s
				if s.index == si:
					src = s
			await _click(_center(dst))
			await _click(_center(src))
			await _frames(5)
			var back = _gs.slot(si) != null and String(_gs.slot(si).id) == id and _gs.slot(di) == null
			_check(back, "click to pick up and click to place puts it back")
		await _key(KEY_ESCAPE)
		var closed = await _until(func(): return _ui.menu == null and not paused, 5.0)
		_check(closed, "Esc closes the satchel and unpauses")

	# --- the pause menu: Esc opens it, Resume closes it
	await _frames(10)
	await _key(KEY_ESCAPE)
	var paused_open = await _until(func(): return _ui.menu != null and _ui.menu.current == "game" and paused, 5.0)
	_check(paused_open, "Esc opens the pause menu and pauses the game")
	if paused_open:
		await _frames(20)
		var resume = _button_named(_ui.menu, "Resume")
		if resume == null:
			_check(false, "the pause menu has a Resume button")
		else:
			await _click(_center(resume))
			var resumed = await _until(func(): return _ui.menu == null and not paused, 5.0)
			_check(resumed, "clicking Resume closes the menu and unpauses")
	_finish()


func _finish(why := "") -> void:
	if why != "":
		_fails.append(why)
		printerr("CLICKTEST: FAIL  " + why)
	for f in DirAccess.get_files_at("user://clicktest_saves/"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://clicktest_saves/" + f))
	if _fails.is_empty():
		print("CLICKTEST: ALL PASSED")
	else:
		printerr("CLICKTEST: %d FAILED: %s" % [_fails.size(), ", ".join(_fails)])
	var audio = root.get_node_or_null("Audio")
	if audio != null:
		audio.quit_game(0 if _fails.is_empty() else 1)
	else:
		quit(0 if _fails.is_empty() else 1)
