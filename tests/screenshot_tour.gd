extends Node
## Plays the whole slice automatically and saves screenshots.
## xvfb-run godot --rendering-method gl_compatibility res://scenes/main.tscn -- --shots <dir>
## With --autotest instead of --shots it plays through without saving images and
## exits non-zero if the slice does not reach the end.

var out_dir := ""
var shots := 0
var auto_dialogue := true
var choice_index := 0
var done := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		out_dir = args[i + 1]
		DirAccess.make_dir_recursive_absolute(out_dir)
	UI.auto = true
	_run()


func _process(_d: float) -> void:
	if not auto_dialogue or not Dialogue.active:
		return
	if Dialogue.choices_box.get_child_count() > 0:
		if Dialogue._choice_made < 0:
			Dialogue._choice_made = min(choice_index, Dialogue.choices_box.get_child_count() - 1)
	elif Dialogue.more.visible:
		Dialogue._advance = true


func shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	shots += 1
	if out_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("%02d_%s.png" % [shots, name]))
	print("shot ", name)


func wait_until(cond: Callable, timeout := 30.0) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > timeout:
			printerr("TIMEOUT waiting in tour at line %s" % str(get_stack()[1].line if get_stack().size() > 1 else -1))
			return false
	return true


func region() -> Node:
	return Router.current_region


func _run() -> void:
	GameState.new_game()
	await UI.fade_in(0.1)
	# --- Chapter 1: forest, dialogue pop-up first
	auto_dialogue = false
	Router.goto_region("forest", "start")
	await wait_until(func(): return Dialogue.active and Dialogue.box.visible and Dialogue.name_label.text != "")
	await shot("forest_dialogue_popup", 1.2)
	auto_dialogue = true
	await wait_until(func(): return not Dialogue.active and not Router.busy)
	await shot("forest_midday", 1.0)
	UI.open_journal(3)
	await shot("journal_map", 0.8)
	await wait_until(func(): return not UI.modal_open)
	region().player.position = Vector2(1560, 1650)
	await Dialogue.play("ch01_hare")
	await wait_until(func(): return not UI.modal_open and not Dialogue.active)
	GameState.hour = 15.8
	region().player.position = Vector2(2300, 1350)
	await shot("forest_afternoon_light", 1.5)
	# walk into the brambles -> battle
	region().player.position = Vector2(2640, 1180)
	await wait_until(func(): return Router.battle != null, 20)
	auto_dialogue = false
	await wait_until(func(): return Dialogue.active and Dialogue.more.visible, 20)
	await shot("battle_mid_dialogue", 0.4)
	auto_dialogue = true
	await wait_until(func(): return not Dialogue.active)
	await shot("battle_hand", 1.0)
	var b: Node = Router.battle
	var ash := -1
	for k in b.core.hand.size():
		if b.core.hand[k].id == "ash_arrow":
			ash = k
	b._play_index(ash)
	await shot("battle_ash_hit", 0.45)
	await wait_until(func(): return not b.busy and not Dialogue.active)
	await shot("battle_after_ash", 0.8)
	# finish the fight with a simple policy (the tour is not a balance test:
	# keep Feyre alive so it reaches the later chapters)
	b.core.enemy.hp = min(b.core.enemy.hp, 22)
	var guard := 0
	while is_instance_valid(b) and not b.core.over and guard < 60:
		guard += 1
		await wait_until(func(): return not b.busy and not Dialogue.active)
		if b.core.over:
			break
		var played := false
		for k in b.core.hand.size():
			if b.core.can_play(k) == "":
				var d: Dictionary = b.core.card_def(b.core.hand[k])
				if d.type == "attack" or d.id in ["close_the_gap", "brace", "survivors_resolve"]:
					await b._play_index(k)
					played = true
					break
		if not played:
			b.core.player.hp = max(b.core.player.hp, 20)
			await b._on_end_turn()
		if guard == 6:
			await shot("battle_late", 0.3)
	await wait_until(func(): return UI.modal_open, 15)
	await shot("battle_card_reward", 0.6)
	await wait_until(func(): return Router.battle == null and not Dialogue.active and not Router.busy, 40)
	await wait_until(func(): return GameState.has_flag("wolf_killed") and not Dialogue.active, 30)
	await shot("forest_dusk_aftermath", 1.2)
	if not GameState.has_flag("wolf_killed"):
		printerr("TOUR: wolf not killed")
		get_tree().quit(1)
		return
	# --- Chapter 2: the cottage
	region().player.position = Vector2(760, 2600)
	await wait_until(func(): return region() != null and region().name == "Region_cottage" and not Router.busy, 20)
	await wait_until(func(): return GameState.has_flag("ch02_arrived") and not Dialogue.active and not Router.busy)
	await shot("cottage_hearth", 1.0)
	for sc in ["ch02_father", "ch02_elain", "ch02_nesta"]:
		await Dialogue.play(sc)
	Dialogue.play("ch02_foxglove")
	await wait_until(func(): return UI.modal_open)
	await shot("relic_popup", 0.5)
	await wait_until(func(): return not Dialogue.active)
	region()._table_action()
	await wait_until(func(): return UI.modal_open, 20)
	await shot("tier_up", 1.3)
	await wait_until(func(): return not Dialogue.active and not UI.modal_open)
	region()._bed_action()
	await wait_until(func(): return region().name == "Region_village" and not Router.busy, 20)
	await wait_until(func(): return not Dialogue.active)
	# --- Chapter 3: village
	await shot("village_market", 1.0)
	region().player.position = Vector2(600, 960)
	await wait_until(func(): return Dialogue.active, 5)
	await wait_until(func(): return not Dialogue.active)
	await Dialogue.play("ch03_mercenary")
	Dialogue.play("ch03_charms")
	await wait_until(func(): return UI.modal_open, 10)
	await shot("shop", 0.6)
	await wait_until(func(): return not Dialogue.active)
	region().player.position = Vector2(2700, 960)
	# --- Chapter 4: the beast (dialogue keeps auto-advancing until he speaks)
	await wait_until(func(): return region() != null and region().name == "Region_cottage" and Dialogue.active and Dialogue.name_label.text == DB.character_name("beast").to_upper(), 60)
	auto_dialogue = false
	await shot("beast_at_the_door", 0.8)
	auto_dialogue = true
	await wait_until(func(): return region() != null and region().name == "Region_wall_ride" and not Router.busy and not Dialogue.active, 60)
	# --- Chapter 5: the ride and the Wall
	await shot("night_ride", 1.0)
	region().player.position = Vector2(800, 1300)
	await wait_until(func(): return region()._cine_layer != null, 20)
	await shot("wall_cinematic", 4.5)
	await wait_until(func(): return UI.modal_open, 60)
	await shot("end_of_slice", 0.8)
	print("TOUR COMPLETE: deck %d, relics %s, tier %d, doe_saved %s" % [GameState.deck.size(), GameState.relics, GameState.tier, GameState.has_flag("doe_saved")])
	get_tree().quit(0)
