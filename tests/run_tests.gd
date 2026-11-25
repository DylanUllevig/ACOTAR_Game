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
	if only == "" or only == "spring":
		await test_spring()
	if only == "" or only == "home":
		await test_home()
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
			if not line.has("s") or bool(DB.characters.get(String(line.s), {}).get("voice_only", false)):
				continue
			if Art.portrait(String(line.s), String(line.get("e", "neutral"))) == null:
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
	# a tree she walks behind fades so she never vanishes, and comes back after
	var tree = r._tall[0]
	r.player.global_position = Vector2(tree[1].get_center().x, tree[2] - 40.0)
	await frames(30)
	check(tree[0].modulate.a < 0.5, "a tree she stands behind fades (alpha %.2f)" % tree[0].modulate.a)
	r.player.global_position = Vector2(tree[1].get_center().x, tree[2] + 60.0)
	await frames(30)
	check(tree[0].modulate.a > 0.99, "it comes back when she steps out in front (alpha %.2f)" % tree[0].modulate.a)
	# the wolf is far bigger than she is: where he stands in front of her, her
	# outline shows through him; never while he hides in the brush, or behind her
	var w = r.wolf
	var w_home = w.global_position
	w.process_mode = Node.PROCESS_MODE_DISABLED
	var spot: Vector2 = r.spawns["start"]
	r.player.global_position = spot
	w.global_position = spot + Vector2(0, 30)
	await frames(20)
	check(r.player.silhouette_strength() == 0.0, "no silhouette through the wolf while he is hidden in the brush")
	w.sprite.modulate.a = 1.0
	await frames(20)
	check(r.player.silhouette_strength() > 0.9, "her outline shows through the wolf in front of her (%.2f)" % r.player.silhouette_strength())
	w.global_position = r.player.global_position + Vector2(0, -30)
	await frames(20)
	check(r.player.silhouette_strength() == 0.0, "and not while he stands behind her (%.2f)" % r.player.silhouette_strength())
	w.sprite.modulate.a = 0.0
	w.global_position = w_home
	w.process_mode = Node.PROCESS_MODE_INHERIT
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
	ok = await wait_until(func(): return region() != null and region().name == "Region_spring_manor" and GameState.chapter == 6 and idle(), 60 * 150)
	check(ok, "the ride ends at the Wall, and she wakes at the Spring Court's gate in chapter 6")
	check(GameState.journal.has("lore_wall") and GameState.places.has("spring_manor"), "the Wall's journal entry and the Spring Court on the map")
	check(not GameState.has_item("bow") and not GameState.has_item("hunting_knife"), "her knife and bow are gone when she wakes")
	var path = SaveSystem.export_carryover("user://test_carry.json")
	var carry = SaveSystem.read_carryover("user://test_carry.json")
	check(path != "" and int(carry.get("tier", -1)) == GameState.tier and Array(carry.get("inventory", [])).size() == GameState.inv_size(), "the carry-over export holds her tier and satchel")
	var canon: Dictionary = carry.get("canon_choices", {})
	check(bool(canon.get("doe_saved", false)) and bool(canon.get("has_paint_tins", false)) and bool(canon.get("ch03_acolyte_done", false)), "carry-over keeps her canon choices (%s)" % str(canon.keys()))


# ================================================================ spring
## Waits until she is in this region in this chapter with nothing playing,
## then a little longer, in case a scene's jump to the next place is queued.
func _in(rname: String, ch: int, frames_max := 60 * 240) -> bool:
	var ok = await wait_until(func(): return region() != null and region().name == "Region_" + rname and GameState.chapter == ch and idle(), frames_max)
	await _settle()
	ok = ok and region() != null and region().name == "Region_" + rname and GameState.chapter == ch
	if not ok:
		printerr("  waited for %s in ch %d, but she is%s" % [rname, ch, _where()])
	return ok


func _settle() -> void:
	for i in 3:
		await frames(4)
		await wait_until(idle, 60 * 240)


## Through each door in turn (by its prompt), waiting for each room to load.
func _through(labels: Array) -> bool:
	for l in labels:
		var before = region().get_instance_id() if region() != null else 0
		if not await _approach(String(l)):
			printerr("  no prompt: " + String(l) + " in " + String(region().name))
			return false
		_press_action("interact")
		_release_action("interact")
		var moved = await wait_until(func(): return region() != null and region().get_instance_id() != before and idle(), 60 * 120)
		await _settle()
		if not moved:
			printerr("  the door did not open: " + String(l))
			return false
	return true


## Where she is and what is running, for a failure message.
func _where() -> String:
	var r = region()
	return " [in %s, ch %d at %.1fh, dialogue %s, busy %s, modal %s, objective '%s']" % [String(r.name) if r != null else "nowhere", GameState.chapter, GameState.hour, Dialogue.active, Router.busy, UI.modal_open, GameState.objective]


## Puts her on a spot and lets the region's trigger there fire, then waits
## for its scene to finish.
func _step_on(p: Vector2) -> void:
	region().player.global_position = p
	region().player.velocity = Vector2.ZERO
	await wait_until(func(): return Dialogue.active or not idle(), 240)
	await _settle()


## Chapters 6 to 27 the way a player goes: through the doors, to the people
## and places the objectives name, choosing the first option every time. The
## two fights end with their rescues, she fights off the Bogge's pulls the way
## a player would, and she hides behind a hedge from the Attor.
func test_spring() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.slot_path("slice_complete")))
	GameState.new_game()
	choice = 0
	GameState.chapter = 6
	GameState.hour = 13.0
	await Router.goto_region("spring_manor", "gate")
	var ok = await _in("spring_manor", 6)
	check(ok and GameState.has_flag("ch06_arrived") and not GameState.has_item("bow"), "ch 6: she wakes at the gate, unarmed")
	if not ok:
		return
	# --- 6 and 7: the house, the feast, the bath; dinner, the morning, the garden
	check(await _interact_with("Go inside"), "ch 6: the front doors")
	ok = await _in("manor_hall", 6)
	check(ok and GameState.has_flag("ch06_hall"), "ch 6: the hall")
	check(await _through(["The dining room"]), "ch 6: to the dining room")
	ok = await _in("manor_bedroom", 7)
	check(ok and GameState.outfit == "feyre_spring" and GameState.has_flag("ch07_morning"), "ch 6-7: feast, bath, spring clothes, first dinner, the morning after")
	if not ok:
		return
	check(await _through(["Out to the upper hall", "Down the stairs", "Out to the gardens"]), "ch 7: out to the grounds")
	await _step_on(region().RG + Vector2(0, 300))
	check(GameState.chapter == 8 and GameState.journal.has("lore_blight"), "ch 7: the garden, and what the sickness is")
	# --- 8: map the grounds, dinner, the stolen knife
	for l in ["The fountain", "The reflecting pool", "The stables", "The gate"]:
		check(await _interact_with(l), "ch 8: " + l)
	await _settle()
	check(GameState.has_flag("ch08_mapped"), "ch 8: the grounds are mapped")
	check(await _through(["Go inside", "The dining room"]), "ch 8: in to dinner")
	ok = await _in("manor_bedroom", 9)
	check(ok and GameState.has_item("table_knife") and GameState.tier == 2, "ch 8: the table knife, and tier 2 (tier %d)" % GameState.tier)
	if not ok:
		return
	# --- 9 and 10: Lucien at the stables, the ride, the Bogge
	check(await _through(["Out to the upper hall", "Down the stairs", "Out to the gardens"]), "ch 9: out to the grounds")
	check(await _interact_with("Lucien"), "ch 9: Lucien at the stables")
	ok = await wait_until(func(): return region() != null and region().name == "Region_spring_woods" and region()._bogge != null and idle(), 60 * 240)
	check(ok and GameState.has_item("bow"), "ch 9: the ride, her bow back, and the cold in the brush")
	if not ok:
		return
	var pushed = 0
	while region() != null and region().name == "Region_spring_woods" and region()._bogge != null:
		var bg = region()._bogge
		_release_action("move_left")
		_release_action("move_right")
		if bg.side != 0 and bg.t > 0.3:
			_press_action("move_right" if bg.side < 0 else "move_left")
			pushed += 1
		await frames(2)
	_release_action("move_left")
	_release_action("move_right")
	ok = await _in("manor_bedroom", 10)
	check(ok and GameState.has_flag("ch10_bogge_done") and GameState.journal.has("lore_bogge"), "ch 10: she fights off the Bogge's pulls and it leaves")
	if not ok:
		return
	check(await _interact_with("The window"), "ch 10: watch from the window")
	ok = await _in("spring_manor", 11)
	check(ok, "ch 11: down the wisteria, into the night")
	if not ok:
		return
	# --- 11: the thing at the gates
	var f = region().npc.get("father")
	await _step_on(Vector2(1800, 1100))
	for i in 60 * 120:
		if Dialogue.active or region().hunt != null:
			break
		if is_instance_valid(f):
			region().player.global_position = f.position + Vector2(0, 90)
		await frames(1)
	ok = await wait_until(func(): return region().hunt != null and idle(), 60 * 60)
	check(ok and GameState.has_flag("ch11_follow"), "ch 11: she follows him to the gates, and it shows what it is")
	if ok:
		region().hunt._rescue()
	# the walk back ends in the hall at night (ch 12), which plays on arrival
	# and carries on to the library in the morning (ch 13)
	ok = await _in("manor_study", 13)
	check(ok and GameState.has_flag("ch11_puca_done") and GameState.journal.has("lore_puca"), "ch 11: the rescue and the walk back")
	check(ok and GameState.has_flag("ch12_night"), "ch 12: the night in the hall, then the library")
	if not ok:
		return
	check(await _interact_with("The writing desk"), "ch 13: the desk")
	check(await _interact_with("The mural"), "ch 13: the mural")
	check(GameState.has_flag("ch13_mural") and GameState.journal.has("lore_courts"), "ch 13: the seven courts")
	check(await _through(["The entrance hall", "Up the stairs"]), "ch 13: up to Lucien's wing")
	check(await _interact_with("Lucien's room"), "ch 13: Lucien's door")
	ok = await _in("spring_manor", 14)
	check(ok and GameState.has_item("fae_knife") and GameState.has_item("chicken"), "ch 13: a faerie knife and bait")
	if not ok:
		return
	# --- 14 and 15: the Suriel, the naga
	await _step_on(Vector2(30, region().WOODS_Y))
	ok = await _in("spring_woods", 14)
	check(ok, "ch 14: into the woods")
	if not ok:
		return
	check(await _interact_with("The birch grove"), "ch 14: the snare")
	ok = await wait_until(func(): return region().hunt != null and idle(), 60 * 120)
	check(ok and GameState.journal.has("lore_suriel") and GameState.journal.has("lore_hybern"), "ch 14: the Suriel talks, the naga come")
	if ok:
		region().hunt._rescue()
	ok = await _in("manor_bedroom", 16)
	check(ok and GameState.tier == 3 and GameState.journal.has("lore_naga"), "ch 15: the rescue, and tier 3 (tier %d)" % GameState.tier)
	if not ok:
		return
	# --- 16 to 18: dinner and the truth; the screams; the glen
	check(await _through(["Out to the upper hall", "Down the stairs", "The dining room"]), "ch 16: down to dinner")
	ok = await _in("manor_bedroom", 17)
	check(ok and GameState.has_flag("ch16_dinner") and GameState.journal.has("lore_lies"), "ch 16: faerie lies")
	if not ok:
		return
	check(await _through(["Out to the upper hall", "Down the stairs"]), "ch 17: down to the hall")
	ok = await _in("manor_bedroom", 18)
	check(ok and GameState.has_flag("ch17_done"), "ch 17: the faerie in the hall")
	if not ok:
		return
	check(await _through(["Out to the upper hall", "Down the stairs", "Out to the gardens"]), "ch 18: out to the pool")
	check(await _interact_with("Tamlin"), "ch 18: Tamlin by the pool")
	ok = await _in("manor_gallery", 19)
	check(ok and GameState.has_item("jeweled_knife"), "ch 18: the glen, and a jeweled knife")
	if not ok:
		return
	# --- 19: the painting room, the garden, the Attor
	check(await _through(["Your painting room"]), "ch 19: the painting room")
	check(GameState.has_flag("ch19_studio"), "ch 19: she paints")
	check(await _through(["The gallery", "The entrance hall", "Out to the gardens"]), "ch 19: out to the rose garden")
	region().player.global_position = region().RG + Vector2(0, 300)
	ok = await wait_until(func(): return region()._attor != null and idle(), 60 * 120)
	check(ok, "ch 19: the walk, the snare, the limericks, and then the voice")
	if ok:
		var hide: Rect2 = region().cover[0]
		while region() != null and region()._attor != null:
			region().player.global_position = hide.get_center()
			region().player.velocity = Vector2.ZERO
			await frames(2)
	ok = await _in("manor_hall", 20)
	check(ok and GameState.journal.has("lore_attor"), "ch 19: hidden behind the hedge, the Attor goes")
	if not ok:
		return
	# --- 20 and 21: Calanmai
	check(await _through(["Up the stairs", "Your room"]), "ch 20: to her room")
	check(GameState.has_flag("ch20_sneak"), "ch 20: the drums")
	check(await _through(["Out to the upper hall", "Down the stairs", "Out to the gardens"]), "ch 20: out at night")
	await _step_on(Vector2(30, region().WOODS_Y))
	ok = await _in("spring_woods", 20)
	check(ok and region()._calanmai, "ch 20: Fire Night in the woods")
	if not ok:
		return
	await _step_on(region().HOLLOW + Vector2(300, -200))
	ok = await _in("manor_hall", 21)
	check(ok and GameState.has_flag("ch20_bonfire"), "ch 20-21: the bonfire, the three, the stranger")
	if not ok:
		return
	check(await _through(["Up the stairs", "Your room"]), "ch 21: to her room")
	check(await _through(["Out to the upper hall"]), "ch 21: out for something to eat")
	ok = await _in("manor_bedroom", 22)
	check(ok and GameState.has_flag("ch21_bite") and GameState.tier == 4, "ch 21: the bite in the hall, and tier 4 (tier %d)" % GameState.tier)
	if not ok:
		return
	# --- 22: the bruise, the gown, the table, the paintings
	check(await _through(["Out to the upper hall", "Down the stairs", "The dining room"]), "ch 22: down to lunch")
	ok = await _in("manor_bedroom", 22)
	check(ok and GameState.has_flag("ch22_lunch"), "ch 22: faerie pig")
	check(GameState.has_flag("ch22_gown"), "ch 22: Alis and the gown")
	check(await _through(["Out to the upper hall", "Down the stairs", "The dining room"]), "ch 22: down to dinner")
	# dinner, the painting room, the willow (ch 23) and the morning after all
	# play on from here, each on arrival
	ok = await _in("manor_bedroom", 24)
	check(ok and GameState.has_flag("ch22_dinner") and GameState.has_flag("ch22_paintings"), "ch 22: the table, the painting room")
	check(ok and GameState.has_flag("ch23_glen") and GameState.has_flag("ch24_wake"), "ch 23-24: faerie sight, then Alis as she is")
	if not ok:
		return
	check(await _through(["Out to the upper hall", "Down the stairs", "The dining room"]), "ch 24: down to breakfast")
	check(GameState.has_flag("ch24_morning"), "ch 24: the morning after")
	check(await _through(["The entrance hall", "Out to the gardens"]), "ch 24: out with her paints")
	var before = region().get_instance_id()
	await _step_on(region().HERON + Vector2(0, 260))
	ok = await wait_until(func(): return region() != null and region().get_instance_id() != before and region().name == "Region_spring_manor" and GameState.chapter == 25 and idle(), 60 * 240)
	await _settle()
	check(ok and GameState.journal.has("lore_night_court"), "ch 24: the Night Court's calling card" + ("" if ok else _where() + " head %s" % GameState.has_flag("ch24_head")))
	if not ok:
		return
	# --- 25 to 27: Midsummer, Rhysand, thorns
	check(await _interact_with("Lucien"), "ch 25: Lucien and the wine")
	check(GameState.has_flag("ch25_wine"), "ch 25: she drinks it")
	# from the dance on, everything plays through: the dawn, lunch and
	# Rhysand (ch 26), and the last night (ch 27), which wakes her on the
	# morning she leaves (ch 28). So only press to talk to him here: waiting
	# for the house to go quiet (as _interact_with does) can sleep through
	# the whole of it, between one scene and the next.
	check(await _approach("Tamlin"), "ch 25: the fiddler")
	_press_action("interact")
	_release_action("interact")
	ok = await wait_until(func(): return region() != null and region().name == "Region_manor_dining" and GameState.chapter == 26, 60 * 400)
	check(ok and GameState.has_flag("ch25_dawn") and region()._short_table(), "ch 25: dancing, the wisps, the dawn; lunch at the little table" + ("" if ok else _where() + " dawn %s" % GameState.has_flag("ch25_dawn")))
	if not ok:
		return
	ok = await _in("manor_bedroom", 28, 60 * 300)
	check(ok and GameState.has_flag("ch26_rhys") and GameState.journal.has("lore_rhysand") and GameState.journal.has("lore_amarantha"), "ch 26: Rhysand at lunch")
	check(ok and GameState.has_flag("ch27_night") and GameState.has_flag("ch28_dress") and GameState.outfit == "feyre_finery", "ch 27: thorns and all; ch 28: dressed for the mortal world")


## Chapters 28 to 32 the way a player goes: the carriage, the chateau and its
## days, the cottage, the village, the ball, the ride to the Wall and the
## night by the fire, the empty manor, and Alis's tale, to the end of the
## milestone. Choosing the first option every time.
func test_home() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.slot_path("slice_complete")))
	GameState.new_game()
	choice = 0
	for f in ["ch24_wake", "ch25_dawn", "ch26_rhys", "ch27_night"]:
		GameState.set_flag(f)
	GameState.outfit = "feyre_spring"
	GameState.chapter = 28
	GameState.hour = 8.0
	await Router.goto_region("manor_bedroom", "bed")
	var ok = await _in("manor_bedroom", 28)
	check(ok and GameState.has_flag("ch28_dress") and GameState.outfit == "feyre_finery", "ch 28: Alis dresses her for the mortal world")
	if not ok:
		return
	check(await _through(["Out to the upper hall", "Down the stairs"]), "ch 28: down to the hall")
	check(GameState.has_flag("ch28_hall"), "ch 28: Lucien at the foot of the stairs")
	check(await _through(["Out to the gardens"]), "ch 28: out to the carriage")
	await _step_on(region().CARRIAGE_AT + Vector2(290, -120))
	ok = await _in("chateau", 28)
	check(ok and GameState.has_flag("ch28_carriage") and GameState.has_flag("ch28_arrived"), "ch 28: goodbye, the sleep, and her father's new house")
	if not ok:
		return
	check(await _through(["Go inside"]), "ch 28: inside with Elain")
	check(GameState.has_flag("ch28_father"), "ch 28: Father in the hall")
	check(await _through(["Up the stairs", "Your room"]), "ch 28: up to her new room")
	check(GameState.has_flag("ch28_room"), "ch 28: a room bigger than the cottage")
	check(await _interact_with("The bed"), "ch 28: rest")
	ok = await _in("chateau", 29)
	check(ok and GameState.has_flag("ch29_garden"), "ch 29: days in Elain's garden")
	if not ok:
		return
	check(await _interact_with("Elain"), "ch 29: Elain among her tulips")
	check(GameState.has_flag("ch29_elain"), "ch 29: what Elain says about Nesta")
	check(await _interact_with("Nesta"), "ch 29: Nesta under the mulberry")
	check(await _through(["Go inside", "Father's study"]), "ch 29: to Father's study")
	check(GameState.has_flag("ch29_study") and GameState.count("silver_purse") == 4, "ch 29: the fortune weighed, four purses of silver")
	check(await _through(["The front hall", "Out to the front steps"]), "ch 29: out again")
	await _step_on(Vector2(10, region().DRIVE_Y))
	ok = await _in("cottage_yard", 29)
	check(ok and GameState.has_flag("ch29_cottage"), "ch 29: the old cottage, so small now")
	if not ok:
		return
	for l in ["The door", "The doorstep", "Elain's flower bed", "The cracked window"]:
		check(await _interact_with(l), "ch 29: " + l)
	check(await _interact_with("The old path"), "ch 29: her forest, only trees")
	check(GameState.has_flag("ch29_cottage_end"), "ch 29: which of them was stronger")
	await _step_on(Vector2(2590, region().ROAD_Y))
	ok = await _in("village_summer", 30)
	check(ok and GameState.has_flag("ch30_village"), "ch 30: the village stares")
	if not ok:
		return
	for i in 4:
		check(await _interact_with("Leave a purse"), "ch 30: purse %d" % (i + 1))
	check(GameState.has_flag("ch30_purses_done") and GameState.count("silver_purse") == 0, "ch 30: four purses left at four doors")
	await _step_on(region().SQUARE + Vector2(0, 260))
	check(GameState.has_flag("ch30_tomas"), "ch 30: Tomas Mandray at the fountain")
	await _step_on(Vector2(2330, 880))
	check(GameState.has_flag("ch30_isaac"), "ch 30: Isaac and his bride")
	await _step_on(Vector2(2960, 880))
	ok = await _in("chateau", 30)
	check(ok and GameState.has_flag("ch30_home") and GameState.has_flag("ch30_dig") and GameState.outfit == "feyre_garden", "ch 30: home, and a spade by the glasshouse")
	if not ok:
		return
	for i in 4:
		check(await _interact_with("Dig"), "ch 30: dig %d" % (i + 1))
	ok = await _in("chateau_studio", 30)
	check(ok and GameState.has_flag("ch30_nesta") and GameState.outfit == "feyre_finery", "ch 30: what Nesta knew, then painting lessons")
	if not ok:
		return
	for i in 3:
		check(await _interact_with("Your easel"), "ch 30: lesson %d" % (i + 1))
	check(GameState.has_flag("ch30_lessons_done"), "ch 30: three days of lessons")
	check(await _through(["The front hall", "Up the stairs"]), "ch 30: up the stairs")
	check(GameState.has_flag("ch30_landing"), "ch 30: Nesta on the stairs: yes, I would have")
	check(await _through(["Your room"]), "ch 30: to dress")
	ok = await _in("chateau_ballroom", 31)
	check(ok and GameState.has_flag("ch31_ball") and GameState.outfit == "feyre_gown", "ch 31: the ball")
	if not ok:
		return
	check(await _interact_with("Nesta"), "ch 31: Nesta and the fifth suitor")
	check(GameState.has_flag("ch31_suitor"), "ch 31: the mustache")
	check(await _through(["Out to the front hall"]), "ch 31: slip away upstairs")
	ok = await _in("chateau_dining", 31)
	check(ok and GameState.has_flag("ch31_late") and GameState.has_flag("ch31_lunch") and GameState.journal.has("lore_beddors"), "ch 31: lunch, and the Beddors")
	if not ok:
		return
	check(await _through(["The front hall", "Up the stairs", "Your room"]), "ch 31: up to her room, Nesta following")
	check(GameState.has_flag("ch31_change") and GameState.outfit == "feyre_ride" and GameState.has_item("bow"), "ch 31: riding clothes, knives and a bow")
	check(await _through(["Out to the upstairs hall", "Down the stairs", "Out to the front steps"]), "ch 31: down to the steps")
	check(GameState.has_flag("ch31_elain"), "ch 31: Elain and a saddled horse")
	check(await _interact_with("Mount the horse"), "ch 31: mount")
	ok = await _in("summer_wall", 31)
	check(ok and GameState.has_flag("ch31_ride"), "ch 31: north through the summer forest")
	if not ok:
		return
	await _step_on(Vector2(900, region().WALL_Y + 150))
	check(GameState.has_flag("ch31_wall"), "ch 31: the Wall")
	await _step_on(region().CAMP)
	check(GameState.has_flag("ch31_camp"), "ch 31: a fire in the clearing")
	for i in 3:
		check(await _interact_with("Feed the fire"), "ch 31: feed the fire %d" % (i + 1))
	check(GameState.has_flag("ch31_dawn"), "ch 31: dawn")
	await _step_on(region().GATE + Vector2(0, 240))
	check(GameState.has_flag("ch31_gate"), "ch 31: the standing stones")
	check(await _interact_with("Ride between the stones"), "ch 31: through")
	ok = await _in("spring_manor", 31)
	check(ok and GameState.has_flag("ch31_return"), "ch 31: back in the silent grounds")
	if not ok:
		return
	await _step_on(region().DOOR + Vector2(0, 120))
	check(GameState.has_flag("ch31_doors"), "ch 31: the doors hang open")
	check(await _through(["Go inside"]), "ch 31: inside")
	ok = await _in("manor_hall", 32)
	check(ok and GameState.has_flag("ch31_wreck"), "ch 31: he was gone")
	if not ok:
		return
	for l in ["The blood", "The broken glass", "The front doors", "The far end of the hall"]:
		check(await _interact_with(l), "ch 32: " + l)
	check(GameState.has_flag("ch32_clues"), "ch 32: the signs read")
	check(await _through(["The dining room"]), "ch 32: follow the tracks")
	check(await _interact_with("The prints in the glass"), "ch 32: the prints")
	check(await _interact_with("Hide behind the door"), "ch 32: hide")
	ok = await _in("manor_kitchen", 32)
	check(ok and GameState.has_flag("ch32_hide") and GameState.has_flag("ch32_kitchen"), "ch 32: Alis, and the kitchens")
	if not ok:
		return
	check(GameState.journal.has("lore_curse") and GameState.journal.has("lore_clythia"), "ch 32: the tale of the curse")
	check(await _interact_with("The worktable"), "ch 32: the worktable")
	ok = await wait_until(func(): return SaveSystem.has_slot("slice_complete"), 60 * 300)
	check(ok and GameState.has_flag("ch32_table") and GameState.journal.has("lore_under_the_mountain"), "ch 32: as you wish, and Milestone 3 is complete")
	if not ok:
		return
	# close the end window the way its button would, without the return to
	# the title (that reloads the scene, which here is the test runner)
	await wait_until(func(): return UI.modal_open, 300)
	for m in UI._modals.duplicate():
		await UI._close_modal(m[0])
	check(idle(), "the end-of-milestone window closes")


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
	# a scene can lead straight into another a frame after it closes (the
	# last purse, the last clue): wait those out too
	await _settle()
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
