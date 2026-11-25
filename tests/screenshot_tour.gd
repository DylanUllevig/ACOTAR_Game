extends Node
## Plays Chapters 1 to 6 by itself and saves screenshots along the way, then
## visits the Spring Court's set pieces through Chapter 27 (each opened at its
## point in the story, as a save from there would be) and ends on the end of
## Milestone 2. The full Chapter 6 to 27 playthrough is the spring test.
##   xvfb-run godot --path . --resolution 1920x1080 -- --shots <dir>
## With --autotest instead of --shots it plays through without saving images
## and exits non-zero if the slice does not reach the end. main.gd starts this
## instead of the title screen when either flag is given.
##
## It drives the game the way the headless tests do: the hunt bot plays the
## wolf fight through the real input actions (Feyre takes no damage here, the
## tour is not a balance test), prompts are used with the interact key, and
## dialogue is advanced as if the player pressed through it.

const Bot := preload("res://tests/hunt_bot.gd")
const Forest := preload("res://scripts/world/regions/forest.gd")
const Wolf := preload("res://scripts/combat/wolf.gd")
const Spring := preload("res://scripts/world/regions/spring_manor.gd")
const Woods := preload("res://scripts/world/regions/spring_woods.gd")

var out_dir := ""
var shots := 0
var auto_dialogue := true
var _frame := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		out_dir = args[i + 1]
		DirAccess.make_dir_recursive_absolute(out_dir)
	UI.auto = true
	SaveSystem.set_dir("user://tour_saves/")
	_run()


func _process(_d: float) -> void:
	_frame += 1
	if not auto_dialogue or not Dialogue.active or _frame % 3 != 0:
		return
	if Dialogue.choices_box.get_child_count() > 0:
		if Dialogue._choice_made < 0:
			Dialogue._choice_made = 0
	else:
		Dialogue._press()


func shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	await RenderingServer.frame_post_draw
	shots += 1
	if out_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("%02d_%s.png" % [shots, name]))
	print("shot ", name)


## Real seconds, since the tour runs at the normal frame rate.
func wait_until(cond: Callable, timeout := 30.0, what := "") -> bool:
	var t0 = Time.get_ticks_msec()
	while not cond.call():
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > timeout * 1000.0:
			printerr("TOUR: timed out waiting for %s" % what)
			return false
	return true


func region() -> Node:
	return Router.current_region


func idle() -> bool:
	return not Dialogue.active and not Router.busy and not UI.modal_open


func fail(why: String) -> void:
	printerr("TOUR FAILED: " + why)
	Audio.quit_game(1)


func press(action: String) -> void:
	for down in [true, false]:
		var ev = InputEventAction.new()
		ev.action = action
		ev.pressed = down
		ev.strength = 1.0 if down else 0.0
		Input.parse_input_event(ev)
		await get_tree().process_frame


## Puts Feyre beside the prompt with this label and presses the interact key.
func use_prompt(label: String, wait_done := true) -> bool:
	var spots = get_tree().get_nodes_in_group("interactable").filter(func(n): return n.is_inside_tree() and n.enabled and n.label == label)
	if spots.is_empty():
		printerr("TOUR: no prompt '%s'" % label)
		return false
	var p = region().player
	var spot = spots[0]
	for off in [Vector2(0, 48), Vector2(0, -48), Vector2(48, 0), Vector2(-48, 0), Vector2.ZERO]:
		p.global_position = spot.global_position + off
		for i in 4:
			await get_tree().physics_frame
		if p._near == spot:
			break
	if p._near != spot:
		printerr("TOUR: could not stand at '%s'" % label)
		return false
	await press("interact")
	if wait_done:
		await wait_until(func(): return Dialogue.active or UI.modal_open, 2.0, label)
		await wait_until(idle, 60.0, label)
	return true


## Presses through narration and stops on the next line someone speaks, so a
## screenshot shows a portrait. Dialogue stays held until auto_dialogue is set.
func hold_dialogue(timeout := 20.0) -> bool:
	auto_dialogue = false
	var t0 = Time.get_ticks_msec()
	var n = 0
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		await get_tree().process_frame
		if Dialogue.active and Dialogue.box.visible and Dialogue.name_label.text != "" and Dialogue.choices_box.get_child_count() == 0:
			return true
		n += 1
		if Dialogue.active and n % 3 == 0:
			if Dialogue.choices_box.get_child_count() > 0:
				if Dialogue._choice_made < 0:
					Dialogue._choice_made = 0
			else:
				Dialogue._press()
	printerr("TOUR: no spoken line within %.0fs" % timeout)
	return false


## Presses through dialogue (taking the first choice) until a line is showing
## for which pred is true, finishes typing it, and holds it for a screenshot.
func hold_until(pred: Callable, timeout := 60.0, what := "a line") -> bool:
	auto_dialogue = false
	var t0 = Time.get_ticks_msec()
	var n = 0
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		await get_tree().process_frame
		if Dialogue.active and Dialogue.box.visible and Dialogue.choices_box.get_child_count() == 0 and pred.call():
			if not Dialogue.more.visible:
				Dialogue._press()   # finishes the typing; does not move on
			return true
		n += 1
		if Dialogue.active and n % 3 == 0:
			if Dialogue.choices_box.get_child_count() > 0:
				if Dialogue._choice_made < 0:
					Dialogue._choice_made = 0
			else:
				Dialogue._press()
	printerr("TOUR: never reached %s" % what)
	return false


func line_has(text: String) -> Callable:
	return func(): return Dialogue.text_label.get_parsed_text().contains(text)


func speaker_is(id: String) -> Callable:
	var shown = DB.character_name(id).to_upper()
	return func(): return Dialogue.name_label.text == shown


func in_region(id: String) -> bool:
	return region() != null and region().name == "Region_" + id


## Until nothing has run for a moment, so no queued scene or journey is left.
func settle(timeout := 90.0) -> bool:
	auto_dialogue = true
	var t0 = Time.get_ticks_msec()
	var quiet = 0
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		await get_tree().process_frame
		quiet = quiet + 1 if idle() else 0
		if quiet > 90:
			return true
	printerr("TOUR: never settled")
	return false


## Opens a region at a point in the story, as a save from there would: the
## chapter, the hour, the flags its earlier scenes set. A scene that plays on
## arrival is pressed through, or with hold, left for hold_until.
func stage(region_id: String, spawn: String, ch: int, hour: float, flags: Array, objective := "", hold := false) -> bool:
	if not await settle():
		return false
	GameState.chapter = ch
	GameState.hour = hour
	GameState.outfit = "feyre_spring"
	for f in flags:
		GameState.set_flag(f)
	GameState.set_objective(objective)
	auto_dialogue = not hold
	var before = region().get_instance_id() if region() != null else 0
	Router.goto_region(region_id, spawn)
	return await wait_until(func(): return in_region(region_id) and region().get_instance_id() != before and not Router.busy, 30.0, region_id)


func _key(action: String, down: bool) -> void:
	var ev = InputEventAction.new()
	ev.action = action
	ev.pressed = down
	ev.strength = 1.0 if down else 0.0
	Input.parse_input_event(ev)


## The Bogge drags at her one way; she leans the other, as a player would.
func resist_bogge(timeout := 120.0) -> void:
	var t0 = Time.get_ticks_msec()
	while in_region("spring_woods") and region()._bogge != null and Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var bg = region()._bogge
		_key("move_left", false)
		_key("move_right", false)
		if bg.side != 0 and bg.t > 0.3:
			_key("move_right" if bg.side < 0 else "move_left", true)
		await get_tree().physics_frame
		await get_tree().physics_frame
	_key("move_left", false)
	_key("move_right", false)


## Flat behind the hedge while the thing in the garden goes by.
func hide_from_attor(timeout := 120.0) -> void:
	var hide: Rect2 = region().cover[0]
	var t0 = Time.get_ticks_msec()
	var taken = false
	while in_region("spring_manor") and region()._attor != null and Time.get_ticks_msec() - t0 < timeout * 1000.0:
		region().player.global_position = hide.get_center()
		region().player.velocity = Vector2.ZERO
		await get_tree().physics_frame
		if not taken and Time.get_ticks_msec() - t0 > 2500:
			taken = true
			await shot("hiding_from_the_attor", 0.0)


## Chapters 6 to 27. Returns false if a set piece never comes.
func _spring() -> bool:
	# --- 6 and 7: in at the front doors, the hall, the first feast, the morning after
	if not await use_prompt("Go inside", false):
		return false
	if not await wait_until(func(): return in_region("manor_hall"), 30.0, "the hall"):
		return false
	if await hold_dialogue():
		await shot("manor_hall", 1.2)
	auto_dialogue = true
	await settle()
	if not await use_prompt("The dining room", false):
		return false
	if not await wait_until(func(): return in_region("manor_dining"), 30.0, "the dining room"):
		return false
	if await hold_until(speaker_is("tamlin"), 60.0, "Tamlin at the feast"):
		await shot("first_feast", 1.2)
	auto_dialogue = true
	if not await wait_until(func(): return in_region("manor_bedroom") and GameState.chapter == 7 and idle(), 180.0, "the morning after"):
		return false
	await settle()
	await shot("bedroom_morning", 0.8)
	# --- 8: the grounds by day, and the rooms of the house
	if not await stage("spring_manor", "garden", 8, 11.0, ["ch07_garden"], "Explore the grounds: the fountain, the pool, the stables and the gate."):
		return false
	await shot("rose_garden", 1.6)
	for p in [[Spring.POOL + Vector2(-160, 330), "reflecting_pool"], [Spring.HERON + Vector2(0, 190), "heron_fountain"],
			[Spring.STABLES + Vector2(-220, 160), "stables"], [Spring.DOOR + Vector2(0, 240), "manor_front"]]:
		region().player.global_position = p[0]
		await shot(p[1], 1.4)
	for room in [["manor_study", "desk", "library"], ["manor_gallery", "hall", "gallery"],
			["manor_studio", "easel", "painting_room"], ["manor_landing", "stairs", "upper_hall"]]:
		if not await stage(room[0], room[1], 8, 11.0, []):
			return false
		await shot(room[2], 1.0)
	# --- 9 and 10: the ride, and the cold in the brush
	if not await stage("spring_woods", "trail", 9, 10.0, ["ch08_mapped", "ch08_dinner", "ch08_satchel", "ch09_morning", "ch09_tamlin"]):
		return false
	if await wait_until(func(): return region().get("_bogge") != null, 90.0, "the Bogge"):
		await shot("the_bogge", 2.5)
		await resist_bogge()
	await wait_until(func(): return in_region("manor_bedroom") and GameState.chapter == 10 and idle(), 120.0, "home from the Bogge")
	# --- 11: the thing at the gate
	if not await stage("spring_manor", "gate", 11, 1.5, ["ch10_bogge_done", "ch10_dinner", "ch10_room", "ch11_out", "ch11_follow"]):
		return false
	if await wait_until(func(): return region().hunt != null, 30.0, "the puca"):
		await shot("puca_at_the_gate", 2.5)
		region().hunt._rescue()
	await wait_until(func(): return in_region("manor_study") and GameState.chapter == 13 and idle(), 150.0, "the library in the morning")
	# --- 14 and 15: the Suriel, then the naga
	GameState.add_item("chicken", 1, true)
	GameState.add_item("fae_knife", 1, true)
	if not await stage("spring_woods", "grove", 14, 10.0, ["ch13_study", "ch13_mural", "ch13_lucien"]):
		return false
	if not await use_prompt("The birch grove", false):
		return false
	if await hold_until(speaker_is("suriel"), 90.0, "the Suriel"):
		await shot("the_suriel", 1.4)
	auto_dialogue = true
	if await wait_until(func(): return region().hunt != null and idle(), 120.0, "the naga"):
		await shot("the_naga", 2.5)
		region().hunt._rescue()
	await wait_until(func(): return in_region("manor_bedroom") and GameState.chapter == 16 and idle(), 150.0, "home from the naga")
	# --- 19: the walk in the rose garden, and the thing that comes
	if not await stage("spring_manor", "garden", 19, 16.0, ["ch16_bath", "ch16_dinner", "ch17_wake", "ch17_done", "ch18_morning", "ch18_glen", "ch19_gallery", "ch19_studio"]):
		return false
	if await wait_until(func(): return region().get("_attor") != null and idle(), 120.0, "the Attor"):
		await hide_from_attor()
	await wait_until(func(): return in_region("manor_hall") and GameState.chapter == 20 and idle(), 150.0, "the hall after the Attor")
	# --- 20: Fire Night
	if not await stage("spring_woods", "manor", 20, 21.5, ["ch19_attor_done", "ch20_tamlin", "ch20_sneak", "ch20_out"]):
		return false
	await settle()
	region().player.global_position = Woods.HOLLOW + Vector2(300, -200)
	if await hold_until(line_has("cave mouth"), 60.0, "the hollow"):
		await shot("fire_night", 1.4)
	if await hold_until(speaker_is("stranger"), 120.0, "the stranger"):
		await shot("fire_night_stranger", 1.4)
	auto_dialogue = true
	await wait_until(func(): return in_region("manor_hall") and GameState.chapter == 21 and idle(), 150.0, "home from Fire Night")
	# --- 22 and 23: the little table, the painting room, faerie sight at the willow
	if not await stage("manor_dining", "hall", 22, 19.5, ["ch21_hall", "ch21_wait", "ch21_bite", "ch22_wake", "ch22_lunch", "ch22_gown"], "", true):
		return false
	if await hold_until(line_has("Between."), 90.0, "the little table"):
		await shot("the_little_table", 1.2)
	if await hold_until(func(): return in_region("manor_studio") and speaker_is("tamlin").call(), 120.0, "the paintings"):
		await shot("her_paintings", 1.2)
	if await hold_until(func(): return in_region("spring_woods") and region().get("_halo") != null, 150.0, "faerie sight"):
		await shot("faerie_sight", 1.6)
	auto_dialogue = true
	await wait_until(func(): return in_region("manor_bedroom") and GameState.chapter == 24 and idle(), 150.0, "the morning after the willow")
	# --- 24: the court as it is, without the glamour
	if not await stage("spring_manor", "garden", 24, 10.0, ["ch23_glen", "ch24_wake", "ch24_dining"]):
		return false
	await shot("the_court_unglamoured", 1.6)
	# --- 25: Midsummer
	if not await stage("spring_manor", "pool", 25, 19.6, ["ch24_morning", "ch24_out", "ch24_head"], "Midsummer on the lawn. Find something to eat, then follow the music."):
		return false
	region().player.global_position = Spring.POOL + Vector2(-200, 740)
	await shot("midsummer_bonfire", 1.8)
	await use_prompt("Lucien")
	if not await use_prompt("Tamlin", false):
		return false
	if await hold_until(speaker_is("tamlin"), 60.0, "the fiddler"):
		await shot("the_fiddler", 1.2)
	if await hold_until(func(): return region().get("_wisps") is Array and not region()._wisps.is_empty() and speaker_is("tamlin").call(), 120.0, "the wisps"):
		await shot("will_o_the_wisps", 2.0)
	if await hold_until(line_has("happiest"), 120.0, "the dawn"):
		await shot("midsummer_dawn", 1.4)
	# --- 26 and 27: Rhysand at lunch; the last night
	if await hold_until(func(): return in_region("manor_dining") and speaker_is("rhysand").call(), 150.0, "Rhysand"):
		await shot("rhysand_at_lunch", 1.4)
	if await hold_until(line_has("Thorns and all"), 240.0, "the last night"):
		await shot("thorns_and_all", 1.6)
	auto_dialogue = true
	if not await wait_until(func(): return UI.modal_open and SaveSystem.has_slot("slice_complete"), 90.0, "the end of the milestone"):
		return false
	await shot("end_of_milestone_2", 0.8)
	return true


func _run() -> void:
	await get_tree().process_frame
	await UI.fade_in(0.1)
	# --- the title screen
	var main = get_parent()
	if main.has_method("_show_title"):
		main._show_title()
		await shot("title", 2.0)
		var layer = main.title.get_parent()
		main.title = null
		layer.queue_free()
	GameState.new_game()
	# --- Chapter 1: the forest at midday
	Router.goto_region("forest", "start")
	await hold_dialogue()
	await shot("forest_intro_dialogue", 1.4)
	auto_dialogue = true
	if not await wait_until(func(): return idle() and region() != null, 60.0, "intro"):
		return fail("intro never finished")
	var r = region()
	# walk the trodden path so the map has something to show
	# (all outside Forest.APPROACH, which would start the hunt)
	for p in [Vector2(900, 2300), Vector2(1200, 1950), Vector2(1560, 1700), Vector2(1950, 1650), Vector2(2200, 1560)]:
		r.player.global_position = p
		await get_tree().create_timer(0.25).timeout
	r.player.global_position = Forest.ROSES[0] + Vector2(0, 70)
	await shot("forest_midday_hotbar", 1.2)
	r._pick_roses(0)
	await shot("rose_hips_picked", 0.5)
	await wait_until(idle, 10.0, "roses")
	UI.open_menu("inventory")
	await shot("inventory", 0.8)
	UI.menu.show_tab("map")
	await shot("map", 0.8)
	UI.menu.show_tab("journal")
	await shot("journal", 0.8)
	UI.menu.show_tab("game")
	await shot("pause_menu", 0.8)
	await UI.close_menu()
	await wait_until(idle, 10.0, "menu closed")
	GameState.hour = 15.8
	r.player.global_position = Vector2(2150, 1580)
	await shot("forest_afternoon_light", 1.5)
	# --- the approach and the hunt
	r.player.global_position = Forest.BRAMBLES + Vector2(0, -14)
	await hold_dialogue()
	await shot("brambles_dialogue", 1.0)
	auto_dialogue = true
	if not await wait_until(func(): return r.hunt != null and idle(), 60.0, "the hunt"):
		return fail("the hunt never started")
	await shot("hunt_hidden_in_brambles", 1.0)
	var bot = Bot.new()
	bot.region = r
	bot.god = true
	add_child(bot)
	if await wait_until(func(): return r.player.drawing and r.player.draw_fraction() > 0.7, 20.0, "the draw"):
		await shot("drawing_the_ash_arrow", 0.0)
	await wait_until(func(): return r.wolf.ash_struck, 30.0, "the ash arrow")
	auto_dialogue = false
	if await wait_until(func(): return Dialogue.active and Dialogue.box.visible, 10.0, "mid-fight dialogue"):
		await shot("mid_fight_dialogue", 1.2)
	auto_dialogue = true
	if await wait_until(func(): return r.wolf.s == Wolf.S.WINDUP and not Dialogue.active, 40.0, "a lunge tell"):
		await shot("wolf_lunge_tell", 0.1)
	if await wait_until(func(): return r.player.slash_cd > 0.2 and not Dialogue.active, 40.0, "a knife slash"):
		await shot("knife_slash", 0.02)
	if not await wait_until(func(): return r.wolf.dead, 120.0, "the wolf's death"):
		return fail("the wolf never died")
	await shot("wolf_down", 0.6)
	bot.stop()
	# the victory scene starts a moment after he falls; the aftermath follows it
	await wait_until(func(): return idle() and get_tree().get_nodes_in_group("interactable").any(func(n): return n.label == "Skin the wolf"), 60.0, "the aftermath")
	for pk in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(pk):
			r.player.global_position = pk.global_position
			await get_tree().create_timer(0.1).timeout
	await use_prompt("Skin the wolf")
	await shot("aftermath_dusk", 1.0)
	await use_prompt("Take the doe")
	if not GameState.has_flag("doe_taken"):
		return fail("the doe was not taken")
	# --- Chapter 2: the cottage
	r.player.global_position = Forest.EXIT + Vector2(0, -20)
	await wait_until(func(): return region() != null and region().name == "Region_cottage", 30.0, "the cottage")
	await hold_dialogue()
	await shot("cottage_family_dialogue", 1.4)
	auto_dialogue = true
	await wait_until(idle, 60.0, "arrival")
	await shot("cottage_hearth", 1.0)
	for who in ["Talk to Father", "Talk to Nesta", "Talk to Elain"]:
		await use_prompt(who)
	await use_prompt("Sit down to eat", false)
	if await wait_until(func(): return UI.modal_open, 60.0, "the tier popup"):
		await shot("tier_up", 0.8)
	await wait_until(idle, 60.0, "dinner")
	await use_prompt("The painted foxglove")
	await use_prompt("The ironwood bed", false)
	# --- Chapter 3: the village
	if not await wait_until(func(): return region() != null and region().name == "Region_village" and idle(), 60.0, "the village"):
		return fail("never reached the village")
	await shot("village_square", 1.2)
	await use_prompt("Speak with the mercenary")
	await use_prompt("Browse the charm stall", false)
	if await wait_until(func(): return UI.modal_open, 20.0, "the shop"):
		await shot("shop", 0.8)
	await wait_until(idle, 30.0, "the shop closing")
	region().player.global_position = Vector2(2730, 960)
	# --- Chapter 4: the beast at the door (dialogue keeps going until he speaks)
	if not await wait_until(func(): return region() != null and region().name == "Region_cottage" and Dialogue.active and Dialogue.name_label.text == DB.character_name("beast").to_upper(), 90.0, "the beast"):
		return fail("the beast never came")
	auto_dialogue = false
	await shot("beast_at_the_door", 1.0)
	auto_dialogue = true
	# --- Chapter 5: the ride and the Wall
	if not await wait_until(func(): return region() != null and region().name == "Region_wall_ride" and idle(), 90.0, "the ride"):
		return fail("the ride north never began")
	await shot("night_ride", 1.2)
	region().player.global_position = Vector2(800, 1300)
	if await wait_until(func(): return region()._cine_layer != null, 30.0, "the Wall"):
		await shot("wall_cinematic", 4.5)
	# --- Chapter 6: she wakes at the Spring Court's gate
	if not await wait_until(func(): return region() != null and region().name == "Region_spring_manor" and GameState.chapter == 6, 90.0, "the Spring Court"):
		return fail("the ride never reached the Spring Court")
	await hold_dialogue()
	await shot("spring_court_arrival", 1.2)
	auto_dialogue = true
	await wait_until(idle, 60.0, "the arrival")
	if not await _spring():
		return fail("the Spring Court tour stopped short")
	print("TOUR COMPLETE: %d shots; tier %d, coin %d, journal %d, doe_saved %s" % [shots, GameState.tier, GameState.coins, GameState.journal.size(), GameState.has_flag("doe_saved")])
	for f in DirAccess.get_files_at("user://tour_saves/"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tour_saves/" + f))
	Audio.quit_game(0)
