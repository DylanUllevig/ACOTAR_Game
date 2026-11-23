extends Node
## Headless test suite.  godot --headless res://tests/test_runner.tscn
## Exits 0 when everything passes, 1 otherwise.

var failures = 0
var passes = 0


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: " + what)


func _ready() -> void:
	await get_tree().process_frame
	test_data()
	test_battle_mechanics()
	test_battle_balance()
	test_save_roundtrip()
	test_progression()
	print("\n%d passed, %d failed" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func test_data() -> void:
	var problems = DB.validate()
	for p in problems:
		printerr("  data: " + p)
	check(problems.is_empty(), "data validates (%d problems)" % problems.size())
	check(DB.cards.size() >= 15, "card count")
	check(DB.tiers.size() == 8, "8 power tiers through Made Fae")
	check(int(DB.tiers[7].max_hp) >= 3 * int(DB.tiers[0].max_hp), "Made Fae is clearly stronger than Tier 0")


func _starter_core(seed_v: int):
	var deck: Array = []
	var uid = 1
	for id in DB.starter_deck:
		deck.append({"uid": uid, "id": id, "up": false})
		uid += 1
	var core = BattleCore.new()
	var t = DB.tier(0)
	core.setup("andras_wolf", deck, {"hp": t.max_hp, "max_hp": t.max_hp, "energy": t.energy, "hand_size": t.hand_size, "strength": 0}, [], seed_v)
	return core


func _find(core: BattleCore, id: String) -> int:
	for i in core.hand.size():
		if core.hand[i].id == id:
			return i
	return -1


func test_battle_mechanics() -> void:
	var core = _starter_core(7)
	core.start()
	check(core.player.statuses.has("hidden"), "starts hidden")
	check(_find(core, "ash_arrow") >= 0, "ash arrow is innate (in opening hand)")
	check(core.intent_key == "stalk", "wolf opens by stalking the doe")
	# knife unusable at far
	var k = _find(core, "knife_slash")
	if k >= 0:
		check(core.can_play(k) != "", "knife needs near range")
	# ambush with ash: 12 * 2 = 24, then ash-struck
	var hp0: int = core.enemy.hp
	core.play_card(_find(core, "ash_arrow"))
	check(hp0 - core.enemy.hp == 20, "ash arrow from hiding deals double (got %d)" % (hp0 - core.enemy.hp))
	check(core.enemy.statuses.has("ash_struck"), "ash-struck applied")
	check(core.gimmick.alerted, "being shot alerts the wolf")
	check(core.gimmick.doe == "safe", "striking first saves the doe")
	check(core.intent_key != "stalk", "alerted wolf re-targets Feyre")
	var hp1: int = core.enemy.hp
	core.end_turn()
	check(core.enemy.hp <= hp1, "no regeneration once ash-struck")

	# regen without ash, and pounce ruins the doe on turn 3
	var c2 = _starter_core(11)
	c2.start()
	c2.hand.clear()
	c2.enemy.hp -= 10
	c2.end_turn()   # stalk 1 + regen
	check(c2.enemy.hp == c2.enemy.max_hp - 6, "Fae Vigor regenerates 4 (hp %d)" % c2.enemy.hp)
	c2.hand.clear()
	c2.end_turn()   # stalk 2
	check(c2.intent_key == "pounce_doe", "pounce telegraphed after two stalks")
	c2.hand.clear()
	c2.end_turn()   # pounce
	check(c2.gimmick.doe == "ruined", "pounce ruins the doe")
	check(c2.gimmick.alerted, "pounce alerts")

	# noise: three moves alert and the doe bolts
	var c3 = _starter_core(3)
	c3.start()
	c3.player.energy = 10
	c3.hand = [{"uid": 900, "id": "fall_back", "up": false}, {"uid": 901, "id": "sidestep", "up": false}, {"uid": 902, "id": "sidestep", "up": false}]
	c3.play_card(0)
	c3.play_card(0)
	check(not c3.gimmick.alerted, "two noise not yet alerted")
	c3.play_card(0)
	check(c3.gimmick.alerted and c3.gimmick.doe == "fled", "three noise alerts, doe flees")

	# evade negates a hit
	var c4 = _starter_core(5)
	c4.start()
	c4.gimmick.alerted = true
	c4.intent_key = "lunge"
	c4.intent = DB.enemies.andras_wolf.moves.lunge
	c4.player.statuses["evade"] = 1
	var php: int = c4.player.hp
	c4.hand.clear()
	c4.end_turn()
	check(c4.player.hp == php, "evade negates the lunge")

	# paint tins trigger once below half
	var c5 = _starter_core(9)
	c5.relic_ids = ["elains_paint_tins"]
	c5.start()
	c5.gimmick.alerted = true
	c5.player.hp = 16
	c5.intent_key = "lunge"
	c5.intent = DB.enemies.andras_wolf.moves.lunge
	c5.hand.clear()
	c5.end_turn()
	check(c5.relic_used.has("elains_paint_tins"), "paint tins trigger below half HP")
	var lunge_dmg: int = int(DB.enemies.andras_wolf.moves.lunge.effects[1].amount)
	check(c5.player.hp == 16 - lunge_dmg + 5, "paint tins heal 5 (hp %d)" % c5.player.hp)

	# dialogue triggers fire once
	var c6 = _starter_core(1)
	var evs = c6.start()
	var starts = evs.filter(func(e): return e.t == "dialogue" and e.scene == "b_wolf_start")
	check(starts.size() == 1, "battle_start dialogue fires")


## A simple greedy bot. Not optimal; it measures that the fight is dangerous
## but winnable for a reasonable player.
func _bot_turn(core: BattleCore) -> void:
	var guard = 0
	while not core.over and guard < 20:
		guard += 1
		var best = -1
		var best_score = -999.0
		for i in core.hand.size():
			if core.can_play(i) != "":
				continue
			var d = core.card_def(core.hand[i])
			var s = 0.0
			match d.id:
				"ash_arrow": s = 100
				"ordinary_arrow": s = 40 if core.current_range == "far" else 10
				"knife_slash": s = 35
				"close_the_gap": s = 30 if core.current_range == "far" and core.is_alerted() else -1
				"brace": s = 20 if core.intent_summary().damage > 0 else 2
				"sidestep": s = 25 if core.intent_summary().damage >= 8 else 1
				"hold_still": s = 50 if not core.is_alerted() else 15
				"fall_back": s = 18 if core.current_range == "near" and core.intent_summary().damage > 0 else -1
				_: s = 12
			if s > best_score:
				best_score = s
				best = i
		if best < 0 or best_score < 0:
			break
		core.play_card(best)
	if not core.over:
		core.end_turn()


func test_battle_balance() -> void:
	var wins = 0
	var doe = 0
	var turns = 0
	var hp_left = 0
	var n = 400
	for s in n:
		var core = _starter_core(1000 + s)
		core.start()
		var guard = 0
		while not core.over and guard < 40:
			guard += 1
			_bot_turn(core)
		if core.won:
			wins += 1
			hp_left += core.player.hp
		if core.doe_saved():
			doe += 1
		turns += core.turn
	var wr = float(wins) / n
	print("Wolf balance (greedy bot, starter deck, Tier 0): win %.0f%%, doe saved %.0f%%, avg turns %.1f, avg HP left on win %.1f/30" % [wr * 100, 100.0 * doe / n, float(turns) / n, float(hp_left) / max(1, wins)])
	check(wr >= 0.6 and wr <= 0.97, "wolf is dangerous but winnable for a greedy bot (win rate %.2f)" % wr)
	# a careless player: plays random affordable cards
	var rwins := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for s in n:
		var core = _starter_core(5000 + s)
		core.start()
		var guard := 0
		while not core.over and guard < 40:
			guard += 1
			var g2 := 0
			while not core.over and g2 < 10:
				g2 += 1
				var playable: Array = []
				for i in core.hand.size():
					if core.can_play(i) == "":
						playable.append(i)
				if playable.is_empty() or rng.randf() < 0.15:
					break
				core.play_card(playable[rng.randi() % playable.size()])
			if not core.over:
				core.end_turn()
		if core.won:
			rwins += 1
	print("Wolf vs a random-play bot: win %.0f%%" % (100.0 * rwins / n))
	check(rwins < wins, "playing carelessly is punished")


func test_save_roundtrip() -> void:
	GameState.new_game()
	GameState.add_relic("elains_paint_tins")
	GameState.add_item("venison_strip", 2)
	GameState.set_flag("doe_saved")
	GameState.apply_tier(1, false)
	GameState.add_coins(17)
	var before = SaveSystem.build_save()
	check(SaveSystem.save_slot("test_slot"), "save writes")
	GameState.new_game()
	check(SaveSystem.load_slot("test_slot"), "save loads")
	var after = SaveSystem.build_save()
	check(JSON.stringify(before.carry_over) == JSON.stringify(after.carry_over), "carry_over round-trips")
	check(JSON.stringify(before.progress.flags) == JSON.stringify(after.progress.flags), "flags round-trip")
	var old = {"tier": 1, "deck": [{"uid": 1, "id": "brace", "up": false}], "chapter": 2, "flags": {}}
	var migrated = SaveSystem.migrate(old)
	check(int(migrated.schema) == SaveSystem.SCHEMA and migrated.has("carry_over"), "schema 0 migrates")
	var path = SaveSystem.export_carryover("user://test_carry.json")
	check(path != "", "carry-over export writes")
	var co = SaveSystem.read_carryover("user://test_carry.json")
	check(int(co.get("tier", -1)) == 1 and co.get("relics", []).has("elains_paint_tins"), "carry-over import reads power and relics")
	check(co.get("canon_choices", {}).get("doe_saved", false) == true, "canon choices carry over")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/test_slot.json"))


func test_progression() -> void:
	GameState.new_game()
	check(GameState.max_hp == 30 and GameState.tier == 0, "start weak: 30 HP tier 0")
	var p0 = GameState.power_score()
	GameState.apply_tier(1, false)
	check(GameState.max_hp == 36 and GameState.deck.any(func(c): return c.id == "survivors_resolve"), "tier 1 raises HP and grants a card")
	GameState.apply_tier(7, false)
	check(GameState.power_score() > p0 * 2, "Made Fae power more than double the start (%d vs %d)" % [GameState.power_score(), p0])
	GameState.new_game()
	var n = GameState.remove_card_id("ash_arrow", true)
	check(n == 1 and not GameState.deck.any(func(c): return c.id == "ash_arrow"), "beast burns the ash arrow")
