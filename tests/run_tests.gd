extends Node
## Headless test suite:
##   godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
## --fixed-fps lets game time run as fast as the CPU allows, so the scripted
## hunts take seconds. Saves go to a scratch folder, never the player's slots.
## Exits 0 when everything passes, 1 otherwise.

const Bot := preload("res://tests/hunt_bot.gd")
const Forest := preload("res://scripts/world/regions/forest.gd")
const SCRATCH := "user://test_saves/"

var failures = 0
var passes = 0
var auto_dialogue := true
var choice := 0
var unreadable: Array[String] = []   # lines shown while the dialogue box was invisible
var _frame := 0
var _box_wait := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: " + what)


func _ready() -> void:
	await get_tree().process_frame
	UI.auto = true
	Router.root = self
	SaveSystem.set_dir(SCRATCH)
	var only = ""
	var args = OS.get_cmdline_user_args()
	if args.has("--only"):
		only = args[args.find("--only") + 1]
	var unit = ["compile", "data", "inventory", "progression", "save", "migration", "map", "time"]
	for t in unit:
		if only == "" or only == t:
			await call("test_" + t)
	if only == "" or only == "chapter_one":
		await test_chapter_one()
	if only == "" or only == "defeat":
		await test_defeat()
	if only == "" or only == "story":
		await test_story()
	if only == "" or only == "balance":
		await test_balance()
	check(unreadable.is_empty(), "every dialogue line shows in a visible box (%d did not, first: %s)" % [unreadable.size(), "" if unreadable.is_empty() else unreadable[0]])
	_wipe_scratch()
	print("\n%d passed, %d failed" % [passes, failures])
	Audio.quit_game(1 if failures > 0 else 0)


func _process(_d: float) -> void:
	_frame += 1
	if not auto_dialogue or not Dialogue.active:
		return
	if Dialogue.choices_box.get_child_count() > 0:
		if Dialogue._choice_made < 0:
			Dialogue._choice_made = min(choice, Dialogue.choices_box.get_child_count() - 1)
		return
	# Every line has to be readable: wait for the box to fade in before
	# pressing on, and count a line whose box never shows as a failure.
	if Dialogue.more.visible and (not Dialogue.box.visible or Dialogue.box.modulate.a < 0.99):
		_box_wait += 1
		if _box_wait < 40:
			return
		unreadable.append(Dialogue.text_label.get_parsed_text().left(48))
	_box_wait = 0
	if _frame % 2 == 0:
		Dialogue._press()


func _wipe_scratch() -> void:
	var d = DirAccess.open(SCRATCH)
	if d:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_carry.json"))


func wait_until(cond: Callable, frames := 3600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func region() -> Node:
	return Router.current_region


func idle() -> bool:
	return not Dialogue.active and not Router.busy and not UI.modal_open


# =================================================================== unit
func test_compile() -> void:
	var files: Array[String] = []
	_collect("res://scripts", files)
	_collect("res://tests", files)
	var bad = 0
	for f in files:
		var s = load(f)
		if s == null or not (s as GDScript).can_instantiate():
			printerr("  does not compile: " + f)
			bad += 1
	check(bad == 0, "every script compiles (%d of %d failed)" % [bad, files.size()])


func _collect(dir: String, out: Array[String]) -> void:
	var d = DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_collect(dir + "/" + sub, out)


func test_data() -> void:
	var problems = DB.validate()
	for p in problems:
		printerr("  data: " + p)
	check(problems.is_empty(), "data validates (%d problems)" % problems.size())
	check(DB.tiers.size() == 8, "8 power tiers through Made Fae")
	check(int(DB.tiers[7].max_hp) >= 3 * int(DB.tiers[0].max_hp), "Made Fae is clearly stronger than Tier 0")
	# art every item, creature and line of dialogue needs
	for id in DB.items:
		check(Art.tex(String(DB.items[id].icon)) != null, "icon for %s exists" % id)
	for eid in DB.enemies:
		var spr = String(DB.enemies[eid].get("art", {}).get("sprite", ""))
		check(Art.tex(spr) != null, "sprite for %s exists" % eid)
	for t in ["fx/dot.png", "fx/slash.png", "fx/shadow.png", "fx/arrow.png", "fx/ash_arrow.png", "fx/knife.png", "fx/bow.png",
			"props/rose_bush.png", "props/rose_bush_bare.png", "actors/hare.png", "items/coin.png"]:
		check(Art.tex(t) != null, "texture %s exists" % t)
	var missing_faces = {}
	for sid in DB.scenes:
		for line in DB.scenes[sid].get("lines", []):
			if line.has("s") and Art.portrait(String(line.s), String(line.get("e", "neutral"))) == null:
				missing_faces[String(line.s)] = true
	check(missing_faces.is_empty(), "every speaker has a portrait (missing: %s)" % ", ".join(missing_faces.keys()))
	# every region_call names a method some region has; every goto names a region
	var methods = {}
	for rid in Router.REGIONS:
		for m in (load(Router.REGIONS[rid]) as GDScript).get_script_method_list():
			methods[m.name] = true
	for sid in DB.scenes:
		for line in DB.scenes[sid].get("lines", []):
			var acts: Array = line.get("do", [])
			for ch in line.get("choices", []):
				acts = acts + ch.get("do", [])
			for a in acts:
				if a.type == "region_call":
					check(methods.has(String(a.method)), "scene %s calls a real region method %s" % [sid, a.method])
				if a.type == "goto":
					check(Router.REGIONS.has(String(a.region)), "scene %s goes to a real region %s" % [sid, a.region])
	# every sound the code asks for by name resolves (or is a known optional one)
	var wanted = _sound_names()
	var missing: Array = []
	for k in wanted:
		var parts = k.split("/")
		if not Audio.has_sound(parts[0], parts[1]) and not (parts[0] == "ui" and Audio.has_sound("sfx", parts[1])):
			missing.append(k)
	check(missing.is_empty(), "every sound used exists (missing: %s)" % ", ".join(missing))


## Collects "kind/name" for every literal Audio.sfx/sfx_at/ui/music/ambience call
## in the scripts and every sfx/music action in the dialogue data.
func _sound_names() -> Dictionary:
	var out = {}
	var re = RegEx.new()
	re.compile("Audio\\.(sfx_at|sfx|ui|music|ambience)\\(\"([a-z0-9_]+)\"")
	var files: Array[String] = []
	_collect("res://scripts", files)
	for f in files:
		var text = FileAccess.get_file_as_string(f)
		for m in re.search_all(text):
			if m.get_string(2).ends_with("_"):
				continue  # a prefix completed at run time, e.g. "step_" + surface
			var kind = m.get_string(1)
			kind = "sfx" if kind == "sfx_at" else kind
			out[kind + "/" + m.get_string(2)] = true
	var step_re = RegEx.new()
	step_re.compile("surface := \"([a-z]+)\"|surface = \"([a-z]+)\"")
	for f in files:
		for m in step_re.search_all(FileAccess.get_file_as_string(f)):
			var sname = m.get_string(1) if m.get_string(1) != "" else m.get_string(2)
			out["sfx/step_" + sname] = true
	for sid in DB.scenes:
		for line in DB.scenes[sid].get("lines", []):
			for a in line.get("do", []):
				if a.type == "sfx":
					out["sfx/" + String(a.name)] = true
				elif a.type == "music" and String(a.name) != "":
					out["music/" + String(a.name)] = true
	return out


func test_inventory() -> void:
	GameState.new_game()
	check(GameState.inventory.size() == 30 and GameState.hotbar_size() == 10, "30 slots, first 10 are the hotbar")
	check(GameState.slot(0).id == "hunting_knife" and GameState.slot(1).id == "bow" and GameState.slot(2).id == "ash_arrow", "knife, bow and the ash arrow start on the hotbar")
	check(GameState.count("arrow") == 2 and GameState.slot(10).id == "arrow", "two ordinary arrows in the bag (canon)")
	check(GameState.ammo_for("bow") == 2 and GameState.ammo_for("hunting_knife") == 0, "the bow fires ordinary arrows")
	# stacking: tops up the existing stack before opening a new slot
	var left = GameState.add_item("arrow", 35, true)
	check(left == 0 and GameState.slot(10).n == 30 and GameState.count("arrow") == 37, "arrows stack to 30 then spill into a new slot")
	check(GameState.slot(3) != null and GameState.slot(3).id == "arrow" and GameState.slot(3).n == 7, "the overflow lands in the first empty slot")
	check(GameState.space_for("ash_arrow") == 25, "space_for counts empty slots by stack limit (got %d)" % GameState.space_for("ash_arrow"))
	# removal takes from the bag before the hotbar
	GameState.new_game()
	GameState.set_slot(3, {"id": "rose_hips", "n": 4})
	GameState.set_slot(12, {"id": "rose_hips", "n": 4})
	GameState.remove_item("rose_hips", 5)
	check(GameState.slot(12) == null and GameState.slot(3).n == 3, "eating takes from the bag first, the hotbar last")
	check(not GameState.remove_item("rose_hips", 99) and GameState.count("rose_hips") == 3, "removing more than you have removes nothing")
	# move: merge like stacks, swap unlike ones
	GameState.set_slot(14, {"id": "rose_hips", "n": 19})
	GameState.move_slot(3, 14)
	check(GameState.slot(14).n == 20 and GameState.slot(3).n == 2, "merge fills the target to its stack limit")
	GameState.move_slot(0, 14)
	check(GameState.slot(0).id == "rose_hips" and GameState.slot(14).id == "hunting_knife", "unlike stacks swap")
	# a full satchel
	GameState.new_game()
	for i in GameState.inventory.size():
		if GameState.slot(i) == null:
			GameState.set_slot(i, {"id": "wolf_pelt", "n": 1})
	check(GameState.add_item("bread", 2, true) == 2, "a full satchel takes nothing and reports the leftover")
	# hotbar selection wraps both ways
	GameState.new_game()
	GameState.select_hotbar(-1)
	check(GameState.hotbar_index == 9, "scrolling left from slot 1 wraps to slot 10")
	GameState.select_hotbar(10)
	check(GameState.hotbar_index == 0, "scrolling right from slot 10 wraps to slot 1")


func test_progression() -> void:
	GameState.new_game()
	check(GameState.max_hp == 30 and GameState.tier == 0, "start weak: 30 HP, tier 0")
	var p0 = GameState.power_score()
	GameState.apply_tier(1, false)
	check(GameState.max_hp == 36 and GameState.damage_mult > 1.0, "tier 1 raises HP and damage")
	GameState.apply_tier(7, false)
	check(GameState.power_score() > p0 * 3, "Made Fae power more than triples the start (%d vs %d)" % [GameState.power_score(), p0])


func test_save() -> void:
	GameState.new_game()
	GameState.add_item("venison_strip", 2, true)
	GameState.add_item("paint_tins", 1, true)
	GameState.set_flag("doe_saved")
	GameState.apply_tier(1, false)
	GameState.add_coins(17)
	GameState.select_hotbar(4)
	GameState.reveal("forest", Rect2(0, 0, 4200, 2700), Vector2(760, 2300), 400.0)
	var before = SaveSystem.build_save()
	check(SaveSystem.save_slot("test_slot"), "save writes")
	GameState.new_game()
	check(SaveSystem.load_slot("test_slot"), "save loads")
	var after = SaveSystem.build_save()
	check(JSON.stringify(before.carry_over) == JSON.stringify(after.carry_over), "carry_over round-trips (inventory, coins, tier)")
	check(JSON.stringify(before.progress.flags) == JSON.stringify(after.progress.flags), "flags round-trip")
	check(before.progress.explored == after.progress.explored, "explored map round-trips")
	check(GameState.hotbar_index == 4, "hotbar selection round-trips")
	var path = SaveSystem.export_carryover("user://test_carry.json")
	check(path != "", "carry-over export writes")
	var co = SaveSystem.read_carryover("user://test_carry.json")
	check(int(co.get("tier", -1)) == 1, "carry-over import reads power")
	var has_tins = false
	for s in co.get("inventory", []):
		if s != null and s.id == "paint_tins":
			has_tins = true
	check(has_tins, "carry-over import keeps keepsakes")
	check(co.get("canon_choices", {}).get("doe_saved", false) == true, "canon choices carry over")


func test_migration() -> void:
	# a schema 1 save from the card-battle build, chapter 3, wolf killed and hides unsold
	var old = {"format": "acotar-save", "schema": 1, "game": "acotar_book1",
		"carry_over": {"tier": 1, "max_hp": 36, "coins": 3, "deck": [{"uid": 1, "id": "ash_arrow"}, {"uid": 2, "id": "brace"}],
			"relics": ["elains_paint_tins"], "items": {"venison_strip": 2}, "journal": ["lore_hunt"], "canon_choices": {"doe_saved": true}},
		"progress": {"chapter": 3, "region": "village", "flags": {"wolf_killed": true, "doe_saved": true}, "hp": 30}}
	var m = SaveSystem.migrate(old.duplicate(true))
	check(int(m.schema) == SaveSystem.SCHEMA, "schema 1 migrates to %d" % SaveSystem.SCHEMA)
	GameState.new_game()
	SaveSystem.apply_save(m)
	check(GameState.has_item("hunting_knife") and GameState.has_item("bow"), "migrated save keeps knife and bow")
	check(GameState.has_item("ash_arrow"), "the ash arrow survives before chapter 4")
	check(GameState.count("venison_strip") == 2 and GameState.has_item("paint_tins"), "items and relics become inventory")
	check(GameState.has_item("wolf_pelt") and GameState.has_item("doe_hide"), "unsold hides are restored from flags")
	check(GameState.chapter == 3 and GameState.region == "village" and GameState.tier == 1, "story position and power carry")
	var old0 = {"tier": 1, "chapter": 2, "flags": {}}
	var m0 = SaveSystem.migrate(old0)
	check(int(m0.schema) == SaveSystem.SCHEMA and m0.has("carry_over"), "schema 0 migrates all the way")


func test_map() -> void:
	GameState.new_game()
	var b = Rect2(0, 0, 640, 640)
	check(GameState.reveal("t", b, Vector2(320, 320), 100.0), "revealing new ground reports a change")
	check(not GameState.reveal("t", b, Vector2(320, 320), 100.0), "revealing it again does not")
	var g: PackedByteArray = GameState.explored["t"]
	var seen = 0
	for v in g:
		seen += v
	check(seen > 0 and seen < g.size(), "only cells near Feyre are revealed (%d of %d)" % [seen, g.size()])
	check(g[0] == 0, "far corner stays dark")


func test_time() -> void:
	# overlapping hit-stop and slow motion must always end at normal speed
	Fx.hitstop(self, 0.05)
	Fx.slowmo(self, 0.1, 0.3)
	Fx.hitstop(self, 0.02)
	await get_tree().create_timer(0.3, true, false, true).timeout
	check(is_equal_approx(Engine.time_scale, 1.0), "time scale returns to 1 after overlapping hit-stops (got %f)" % Engine.time_scale)


# ============================================================== scenarios
## New game into the forest, then straight to the hunt.
func _start_hunt(skip_intro := true) -> bool:
	GameState.new_game()
	if skip_intro:
		GameState.set_flag("ch01_intro_done")
	await Router.goto_region("forest", "start")
	await wait_until(idle, 600)
	var r = region()
	r.player.global_position = Forest.BRAMBLES + Vector2(0, -14)
	return await wait_until(func(): return r.hunt != null and idle(), 1800)


func test_chapter_one() -> void:
	GameState.new_game()
	await Router.goto_region("forest", "start")
	check(region() != null and region().name == "Region_forest", "forest loads")
	await wait_until(idle, 1200)
	check(GameState.has_flag("ch01_intro_done") and GameState.objective != "", "intro plays and sets the objective")
	var r = region()
	check(r.wolf != null and r.wolf.lurking and r.wolf.hurtbox.collision_layer == 0, "the wolf waits hidden and cannot be hit before the hunt")
	# pick one rose bush on the way
	r.player.global_position = Forest.ROSES[0] + Vector2(0, 40)
	await frames(6)
	r._pick_roses(0)
	check(GameState.count("rose_hips") == 3 and GameState.has_flag("rose_0"), "rose hips can be picked")
	# walk into the approach: the brambles scene, then the hunt
	r.player.global_position = Forest.BRAMBLES + Vector2(0, -14)
	var started = await wait_until(func(): return r.hunt != null and idle(), 1800)
	check(started, "the approach starts the hunt")
	if not started:
		return
	check(SaveSystem.has_slot("auto"), "a checkpoint is saved before the hunt")
	check(not r.wolf.lurking and r.hunt.hidden, "the wolf steps out; Feyre starts hidden in the brambles")
	var bot = Bot.new()
	bot.region = r
	bot.god = true
	add_child(bot)
	var f0 = Engine.get_physics_frames()
	var won = await wait_until(func(): return GameState.has_flag("wolf_killed"), 60 * 90)
	print("  story hunt: %s after %.1fs of game time; lunges %d; arrows shot %d; damage dealt %d" % [
		"won" if won else "not won", (Engine.get_physics_frames() - f0) / 60.0, bot.lunges_seen,
		int(GameState.stats.get("arrows_shot", 0)), int(GameState.stats.get("damage_dealt", 0))])
	check(won, "the hunt can be won (wolf hp %d)" % (r.wolf.hp if r.wolf else -1))
	check(bot.ash_from_hiding, "the opening shot was the ash arrow from hiding")
	check(r.wolf.ash_struck, "the ash arrow struck")
	check(GameState.has_flag("doe_saved"), "striking first saves the doe")
	bot.stop()
	await wait_until(idle, 1200)
	check(GameState.has_item("ash_arrow") or _pickup_count("ash_arrow") > 0, "the ash arrow comes out of the body to be recovered")
	check(GameState.journal.has("lore_wolf"), "the wolf's journal entry unlocks")
	# collect the arrows lying around
	for pk in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(pk):
			r.player.global_position = pk.global_position
			await frames(4)
	await frames(10)
	check(GameState.has_item("ash_arrow"), "picking up the ash arrow returns it to the satchel")
	# skin the wolf and take the doe through the real interact prompt
	var spots = get_tree().get_nodes_in_group("interactable").filter(func(n): return n.label == "Skin the wolf")
	check(spots.size() == 1, "aftermath: skin the wolf")
	if spots.size() == 1:
		r.player.global_position = spots[0].global_position
		await frames(4)
		_press_action("interact")
		await wait_until(func(): return GameState.has_flag("wolf_skinned") and idle(), 1200)
	var takes = get_tree().get_nodes_in_group("interactable").filter(func(n): return n.label == "Take the doe" and n.enabled)
	check(takes.size() == 1, "aftermath: take the doe")
	if takes.size() == 1:
		r.player.global_position = takes[0].global_position
		await frames(4)
		_press_action("interact")
		await wait_until(func(): return GameState.has_flag("doe_taken") and idle(), 1200)
	check(GameState.has_item("wolf_pelt") and GameState.has_item("doe_hide"), "pelt and whole hide in the satchel")
	# eat a rose hip from the hotbar while hurt
	GameState.set_hp(20)
	var hips = -1
	for i in 10:
		if GameState.slot(i) != null and GameState.slot(i).id == "rose_hips":
			hips = i
	if hips < 0:
		for i in range(10, 30):
			if GameState.slot(i) != null and GameState.slot(i).id == "rose_hips":
				GameState.move_slot(i, 5)
				hips = 5
	GameState.select_hotbar(hips)
	await frames(2)
	_press_action("use_item")
	await frames(3)
	_release_action("use_item")
	await frames(120)
	check(GameState.hp == 25 and GameState.count("rose_hips") == 2, "eating a rose hip heals 5 over a moment (hp %d)" % GameState.hp)
	# home
	r.player.global_position = Forest.EXIT + Vector2(0, -20)
	var home = await wait_until(func(): return region() != null and region().name == "Region_cottage" and idle(), 2400)
	check(home and GameState.chapter == 2, "the path home leads to the cottage in chapter 2")


func _pickup_count(id: String) -> int:
	var n = 0
	for pk in get_tree().get_nodes_in_group("pickups"):
		if pk.item_id == id:
			n += 1
	return n


func _press_action(a: String) -> void:
	var ev = InputEventAction.new()
	ev.action = a
	ev.pressed = true
	ev.strength = 1.0
	Input.parse_input_event(ev)


func _release_action(a: String) -> void:
	var ev = InputEventAction.new()
	ev.action = a
	ev.pressed = false
	Input.parse_input_event(ev)


func test_defeat() -> void:
	var ok = await _start_hunt()
	check(ok, "defeat test: hunt starts")
	if not ok:
		return
	var r = region()
	# step out of cover and stand there
	r.player.global_position = Forest.CLEARING + Vector2(-300, 200)
	var bot = Bot.new()
	bot.region = r
	bot.passive = true
	add_child(bot)
	var died = await wait_until(func(): return UI.modal_open and GameState.hp <= 0, 60 * 60)
	check(died, "standing in the open gets Feyre killed")
	check(r.wolf.alerted, "she was seen")
	bot.stop()
	# the game over screen picks Try again (UI.auto) and reloads the checkpoint
	var old_id = r.get_instance_id()
	r = null
	var back = await wait_until(func(): return region() != null and region().get_instance_id() != old_id and region().hunt != null and idle(), 60 * 30)
	check(back, "Try again returns to the hunt")
	if back:
		check(GameState.hp == GameState.max_hp, "full health after Try again")
		check(region().wolf.hp == region().wolf.max_hp and not region().wolf.dead, "the wolf is back at full strength")
		check(region().hunt.hidden, "she starts hidden again")


## Chapters 2 to 5 through the same prompts and triggers a player uses: the
## evening at the cottage, the village, the beast at the door, the ride north.
func test_story() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.slot_path("slice_complete")))
	GameState.new_game()
	# where Chapter 1 leaves her: the wolf dead and skinned, the doe carried whole
	for f in ["ch01_intro_done", "wolf_killed", "ash_from_hiding", "doe_saved", "wolf_skinned", "doe_taken"]:
		GameState.set_flag(f)
	GameState.add_item("wolf_pelt", 1, true)
	GameState.add_item("doe_hide", 1, true)
	GameState.hour = 17.0
	await Router.goto_region("forest", "start")
	await wait_until(idle, 600)
	region().player.global_position = Forest.EXIT + Vector2(0, -20)
	var ok = await wait_until(func(): return region() != null and region().name == "Region_cottage" and idle(), 2400)
	check(ok and GameState.chapter == 2, "chapter 2 begins at the cottage")
	if not ok:
		return
	check(GameState.has_flag("ch02_arrived") and GameState.objective.contains("Father"), "the family is waiting and the objective names them")
	check(await _interact_with("Sit down to eat"), "the table has a prompt")
	check(not GameState.has_flag("ch02_dinner_done"), "dinner waits until she has spoken to everyone")
	for who in ["Talk to Father", "Talk to Nesta", "Talk to Elain"]:
		check(await _interact_with(who), "cottage prompt: " + who)
	check(GameState.has_flag("ch02_father_talked") and GameState.has_flag("ch02_nesta_talked") and GameState.has_flag("ch02_elain_talked"), "all three conversations count")
	var max0 = GameState.max_hp
	var food0 = GameState.count("venison_strip")
	await _interact_with("Sit down to eat")
	check(GameState.has_flag("ch02_dinner_done") and GameState.tier == 1, "dinner brings tier 1 (tier %d)" % GameState.tier)
	check(GameState.max_hp > max0 and GameState.hp == GameState.max_hp, "tier 1 raises and fills her health (%d/%d)" % [GameState.hp, GameState.max_hp])
	check(GameState.count("venison_strip") == food0 + 3, "venison strips go into the satchel")
	await _interact_with("The painted foxglove")
	check(GameState.has_item("paint_tins") and GameState.has_flag("has_paint_tins"), "Elain's paint tins")
	await _interact_with("The ironwood bed")
	ok = await wait_until(func(): return region() != null and region().name == "Region_village" and idle(), 2400)
	check(ok and GameState.chapter == 3, "chapter 3 begins in the village")
	if not ok:
		return
	# the east road stays closed until the hides are sold
	region().player.global_position = Vector2(2730, 960)
	await wait_until(func(): return Dialogue.active, 120)
	await wait_until(idle, 1200)
	check(region().name == "Region_village" and GameState.chapter == 3, "the road home waits until the hides are sold")
	region().player.global_position = Vector2(500, 900)
	await wait_until(func(): return Dialogue.active, 120)
	await wait_until(idle, 1200)
	check(GameState.has_flag("ch03_acolyte_done") and GameState.journal.has("lore_children"), "the acolytes in the lane")
	var coins0 = GameState.coins
	await _interact_with("Speak with the mercenary")
	check(GameState.has_flag("ch03_hides_sold") and not GameState.has_item("wolf_pelt") and not GameState.has_item("doe_hide"), "the mercenary buys the pelt and the hide")
	check(GameState.coins == coins0 + int(DB.hide_prices.wolf_pelt) + int(DB.hide_prices.doe_hide), "a whole hide fetches the full price (%d coin)" % GameState.coins)
	# the charm stall: buy a bundle of arrows while the stall is open
	var arrows0 = GameState.count("arrow")
	var coins1 = GameState.coins
	check(await _approach("Browse the charm stall"), "the charm stall has a prompt")
	_press_action("interact")
	_release_action("interact")
	var sv = null
	for i in 600:
		await get_tree().physics_frame
		var found = get_tree().root.find_children("*", "ShopView", true, false)
		if not found.is_empty():
			sv = found[0]
			break
	check(sv != null, "the charm stall opens a shop")
	if sv != null:
		sv._buy("arrow", 3, 6)
		check(GameState.count("arrow") == arrows0 + 3 and GameState.coins == coins1 - 6, "buying a bundle of arrows (%d arrows, %d coin)" % [GameState.count("arrow"), GameState.coins])
	await wait_until(idle, 1200)
	await _interact_with("Talk to Elain")
	check(GameState.has_flag("ch03_coin_given"), "Elain asks for coin")
	await _interact_with("Isaac Hale")
	check(GameState.has_flag("ch03_isaac_done"), "Isaac Hale")
	region().player.global_position = Vector2(2730, 960)
	# Chapter 4 plays out at the door on its own (every choice leads on), then the road north
	ok = await wait_until(func(): return region() != null and region().name == "Region_wall_ride" and idle(), 60 * 120)
	check(ok and GameState.chapter == 5, "the beast at the door, then chapter 5 on the road north")
	if not ok:
		return
	check(GameState.has_flag("ch04_done") and GameState.journal.has("lore_life_for_life"), "the bargain is struck")
	check(not GameState.has_item("ash_arrow"), "the ash arrow burns away")
	check(GameState.coins == 0, "she leaves her coin for the family")
	check(await _interact_with("Speak to the beast"), "she can speak to the beast on the ride")
	region().player.global_position = Vector2(800, 1300)
	ok = await wait_until(func(): return SaveSystem.has_slot("slice_complete"), 60 * 90)
	check(ok, "the ride ends at the Wall and the slice completes")
	check(GameState.journal.has("lore_wall") and GameState.places.has("spring_manor"), "the Wall's journal entry and the Spring Court on the map")
	var path = SaveSystem.export_carryover("user://test_carry.json")
	var carry = SaveSystem.read_carryover("user://test_carry.json")
	check(path != "" and int(carry.get("tier", -1)) == GameState.tier and Array(carry.get("inventory", [])).size() == GameState.inv_size(), "the carry-over export holds her tier and satchel")
	var canon: Dictionary = carry.get("canon_choices", {})
	check(bool(canon.get("doe_saved", false)) and bool(canon.get("has_paint_tins", false)) and bool(canon.get("ch03_acolyte_done", false)), "carry-over keeps her canon choices (%s)" % str(canon.keys()))
	# close the end-of-slice window the way its button would, without the
	# return to the title (that reloads the scene, which here is the test runner)
	await wait_until(func(): return UI.modal_open, 300)
	for m in UI._modals.duplicate():
		await UI._close_modal(m[0])
	check(idle(), "the end-of-slice window closes")


## Puts Feyre beside the prompt with this label, close enough that it is the
## one her interact key would use. False when the region has no such prompt.
func _approach(label: String) -> bool:
	var spots = get_tree().get_nodes_in_group("interactable").filter(func(n): return n.is_inside_tree() and n.enabled and n.label == label)
	if spots.is_empty():
		return false
	var r = region()
	var spot = spots[0]
	for off in [Vector2(0, 48), Vector2(0, -48), Vector2(48, 0), Vector2(-48, 0), Vector2.ZERO]:
		r.player.global_position = spot.global_position + off
		await frames(4)
		if r.player._near == spot:
			return true
	return false


## Walks up to the prompt, presses the interact key and waits for the scene.
func _interact_with(label: String) -> bool:
	if not await _approach(label):
		return false
	_press_action("interact")
	_release_action("interact")
	await frames(3)
	await wait_until(idle, 3600)
	return true


func test_balance() -> void:
	var n = 24
	var args = OS.get_cmdline_user_args()
	if args.has("--runs"):
		n = int(args[args.find("--runs") + 1])
	var configs = [
		{"name": "careful (reads 85% of his tells)", "skill": 0.85, "n": n},
		{"name": "careless (reads 25%)", "skill": 0.25, "n": n},
	]
	for c in configs:
		var wins = 0
		var hp_left = 0
		var secs = 0.0
		var stalls = 0
		for i in int(c.n):
			var ok = await _start_hunt()
			if not ok:
				check(false, "balance: hunt starts")
				return
			var r = region()
			var rid = r.get_instance_id()
			var bot = Bot.new()
			bot.region = r
			bot.skill = float(c.skill)
			bot.rng.seed = 7000 + i
			# the wolf's choices (circle, chase, bite) and where arrows fall repeat run to run
			r.wolf.rng.seed = 9000 + i
			add_child(bot)
			var f0 = Engine.get_physics_frames()
			var ended = await wait_until(func(): return r.hunt.over, 60 * 120)
			secs += (Engine.get_physics_frames() - f0) / 60.0
			var won = ended and r.wolf.dead
			var hp_end = GameState.hp
			if args.has("--verbose"):
				print("    run %d: %s, hp %d, wolf hp %d, %.0fs" % [i, "win" if won else "loss", hp_end, r.wolf.hp, (Engine.get_physics_frames() - f0) / 60.0])
			bot.stop()
			if not ended:
				stalls += 1
			elif won:
				wins += 1
				hp_left += hp_end
				await wait_until(func(): return GameState.has_flag("wolf_killed") and idle(), 1200)
			else:
				r = null
				await wait_until(func(): return region() != null and region().get_instance_id() != rid and region().hunt != null and idle(), 60 * 30)
		print("  balance, %s: won %d/%d, avg HP left on a win %.1f/30, avg fight %.0fs, stalemates %d" % [c.name, wins, int(c.n), float(hp_left) / max(1, wins), secs / float(c.n), stalls])
		c["wins"] = wins
		c["hp"] = float(hp_left) / max(1, wins)
		check(stalls == 0, "no hunt stalls for two minutes (%s)" % c.name)
	check(int(configs[0].wins) >= int(n * 0.85), "a careful player wins (%d/%d)" % [int(configs[0].wins), n])
	check(float(configs[0].hp) >= 14.0, "a careful player keeps about half her health (%.1f/30)" % float(configs[0].hp))
	# Over 60 seeded runs: careful wins 90% with about 17 HP left, careless wins 70%
	# with about 7. The cap sits well above 70% so it catches a fight gone soft.
	check(int(configs[1].wins) <= int(n * 0.9), "a careless player loses some fights (%d/%d wins)" % [int(configs[1].wins), n])
	check(float(configs[0].hp) - float(configs[1].hp) >= 5.0, "reading his tells is worth real health (%.1f vs %.1f)" % [float(configs[0].hp), float(configs[1].hp)])
