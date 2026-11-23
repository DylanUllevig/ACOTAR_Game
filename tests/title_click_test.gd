extends SceneTree
## Clicks "New Game" on the real title screen with a synthetic mouse event and
## checks the forest loads. Run: godot --path . --script res://tests/title_click_test.gd
## (needs a display; use xvfb-run when headless). Exit code 0 = pass.

func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 90:
		await process_frame
	var main = current_scene
	var btn: Button = null
	for n in main.find_children("*", "Button", true, false):
		if n.text == "New Game":
			btn = n
	if btn == null:
		printerr("CLICKTEST: no New Game button"); quit(2); return
	var vp = main.get_viewport()
	var pos = btn.get_global_rect().get_center()
	# convert canvas position to window position for the input event
	var screen_pos = vp.get_final_transform() * pos
	var mv = InputEventMouseMotion.new(); mv.position = screen_pos; mv.global_position = screen_pos
	Input.parse_input_event(mv)
	await process_frame
	await process_frame
	var hovered = vp.gui_get_hovered_control()
	print("CLICKTEST: button at ", pos, " window ", screen_pos, " hovered: ", hovered, " path ", hovered.get_path() if hovered else "")
	for pressed in [true, false]:
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = pressed
		ev.position = screen_pos; ev.global_position = screen_pos
		Input.parse_input_event(ev)
		await process_frame
	for i in 240:
		await process_frame
		var router = root.get_node("Router")
		if router.current_region != null:
			print("CLICKTEST: title PASS, region ", router.current_region.name)
			await _battle_click(router)
			return
	printerr("CLICKTEST: FAIL, no region loaded"); quit(1)


func _skip_dialogue() -> void:
	var dlg = root.get_node("Dialogue")
	for i in 2000:
		await process_frame
		if not dlg.active:
			return
		if dlg.choices_box.get_child_count() > 0:
			if dlg._choice_made < 0:
				dlg._choice_made = 0
		elif dlg.more.visible:
			dlg._advance = true


## Then a battle: hover a card in hand with the real mouse path and click it.
func _battle_click(router) -> void:
	await _skip_dialogue()
	router.start_battle("andras_wolf")
	for i in 120:
		await process_frame
	await _skip_dialogue()
	for i in 60:
		await process_frame
	var b = router.battle
	var before = b.core.hand.size()
	var card: Control = null
	for n in b.find_children("*", "Control", true, false):
		if n.get_script() != null and n.get_script().resource_path.ends_with("card_view.gd") and n.visible:
			card = n
			break
	if card == null:
		printerr("CLICKTEST: FAIL, no card in hand"); quit(1); return
	var vp = card.get_viewport()
	var at = vp.get_final_transform() * (card.get_global_transform_with_canvas() * (card.size * 0.5))
	var mv = InputEventMouseMotion.new(); mv.position = at; mv.global_position = at
	Input.parse_input_event(mv)
	await process_frame
	await process_frame
	var hovered = vp.gui_get_hovered_control()
	print("CLICKTEST: card hovered: ", hovered.get_path() if hovered else "none")
	for pressed in [true, false]:
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = pressed
		ev.position = at; ev.global_position = at
		Input.parse_input_event(ev)
		await process_frame
	for i in 120:
		await process_frame
	var after = b.core.hand.size()
	if after < before or b.core.player.energy < 3:
		print("CLICKTEST: battle PASS, card played (hand %d -> %d)" % [before, after]); quit(0)
	else:
		printerr("CLICKTEST: FAIL, clicking a card did nothing"); quit(1)
