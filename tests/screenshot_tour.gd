extends Node
## Plays the whole slice by itself and saves screenshots along the way.
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
	print("TOUR COMPLETE: %d shots; tier %d, coin %d, journal %d, doe_saved %s" % [shots, GameState.tier, GameState.coins, GameState.journal.size(), GameState.has_flag("doe_saved")])
	for f in DirAccess.get_files_at("user://tour_saves/"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tour_saves/" + f))
	Audio.quit_game(0)
