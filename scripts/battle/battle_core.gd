class_name BattleCore
extends RefCounted
## Pure battle rules. No nodes, no rendering: the battle scene drives this and
## animates the events it emits. Tests run it headless (tests/run_tests.gd).

const NEAR := "near"
const FAR := "far"

var rng = RandomNumberGenerator.new()
var turn = 0
var current_range = FAR
var player = {}
var enemy = {}
var enemy_def = {}
var draw_pile: Array = []
var hand: Array = []
var discard: Array = []
var exhaust: Array = []
var hand_size = 5
var intent = {}
var intent_key = ""
var last_move = ""
var gimmick = {}
var relic_ids: Array = []
var relic_used = {}
var fired = {}
var events: Array = []
var over = false
var won = false
var cards_played_this_turn = 0
var total_damage_dealt = 0
var in_enemy_turn = false


# ------------------------------------------------------------------ setup
## deck: Array of {uid, id, up}; stats: {hp, max_hp, energy, hand_size, strength}
func setup(enemy_id: String, deck: Array, stats: Dictionary, relics: Array, seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	enemy_def = DB.enemies[enemy_id]
	enemy = {
		"id": enemy_id, "name": enemy_def.get("name", enemy_id), "hp": int(enemy_def.max_hp),
		"max_hp": int(enemy_def.max_hp), "block": 0, "statuses": {}, "fae": bool(enemy_def.get("fae", false)),
	}
	for s in enemy_def.get("start_statuses", {}):
		enemy.statuses[s] = int(enemy_def.start_statuses[s])
	player = {
		"hp": int(stats.hp), "max_hp": int(stats.max_hp), "block": 0, "energy": 0,
		"max_energy": int(stats.energy), "statuses": {},
	}
	if int(stats.get("strength", 0)) > 0:
		player.statuses["strength"] = int(stats.strength)
	hand_size = int(stats.hand_size)
	relic_ids = relics.duplicate()
	current_range = enemy_def.get("start_range", FAR)
	draw_pile = []
	for c in deck:
		draw_pile.append(c.duplicate())
	_shuffle(draw_pile)
	# innate cards go on top
	var innate: Array = draw_pile.filter(func(c): return bool(card_def(c).get("innate", false)))
	for c in innate:
		draw_pile.erase(c)
		draw_pile.push_back(c)
	if enemy_def.get("gimmick", "") == "stalker":
		var gp: Dictionary = enemy_def.get("gimmick_params", {})
		gimmick = {
			"type": "stalker", "noise": 0, "alerted": false, "doe_threat": 0, "doe": "grazing",
			"noise_to_alert": int(gp.get("noise_to_alert", 3)), "doe_threat_to_pounce": int(gp.get("doe_threat_to_pounce", 2)),
		}
		player.statuses["hidden"] = 1


func start() -> Array:
	events = []
	_trigger("battle_start")
	for r in relic_ids:
		var rd: Dictionary = DB.relics.get(r, {})
		if rd.get("trigger", "") == "battle_start":
			_emit({"t": "relic", "id": r})
			_run_effects(rd.effects, "player", {})
	_start_player_turn()
	return _flush()


# ---------------------------------------------------------------- queries
func card_def(c: Dictionary) -> Dictionary:
	return DB.card_effective(c.id, c.get("up", false))


func card_cost(c: Dictionary) -> int:
	return int(card_def(c).get("cost", 1))


func can_play(index: int) -> String:
	if over:
		return "Battle is over."
	if index < 0 or index >= hand.size():
		return "No such card."
	var c: Dictionary = hand[index]
	var d = card_def(c)
	if card_cost(c) > player.energy:
		return "Not enough energy."
	if d.get("range", "any") == NEAR and current_range != NEAR:
		return "Too far. Move to Near range first."
	return ""


func is_alerted() -> bool:
	return gimmick.is_empty() or gimmick.get("alerted", true)


func enemy_hp_ratio() -> float:
	return float(enemy.hp) / float(enemy.max_hp)


func describe_card(c: Dictionary) -> String:
	## Fill {dmg}/{block} with live numbers (strength, range, ambush shown).
	var d = card_def(c)
	var text: String = d.get("text", "")
	for e in d.get("effects", []):
		if e.type == "damage" and text.contains("{dmg}"):
			text = text.replace("{dmg}", str(preview_damage(d, e)))
		elif e.type == "block" and text.contains("{block}"):
			text = text.replace("{block}", str(int(e.amount)))
	return text


func preview_damage(d: Dictionary, e: Dictionary) -> int:
	return _player_attack_amount(d, e, false)


# ---------------------------------------------------------------- actions
func play_card(index: int) -> Array:
	events = []
	var why = can_play(index)
	if why != "":
		_emit({"t": "log", "text": why})
		return _flush()
	var c: Dictionary = hand[index]
	var d = card_def(c)
	hand.remove_at(index)
	player.energy -= card_cost(c)
	cards_played_this_turn += 1
	_emit({"t": "play", "card": c, "name": d.name})
	var ctx = {"card": d}
	_run_effects(d.get("effects", []), "player", ctx)
	if d.get("type", "") == "move" and not gimmick.is_empty():
		_add_noise(1)
	if "knife" in d.get("tags", []) and player.statuses.has("rough_hands"):
		_gain_block("player", int(player.statuses.rough_hands))
	if d.get("type", "") == "power":
		pass  # powers vanish after play (their status persists)
	elif bool(d.get("exhaust", false)):
		exhaust.append(c)
		_emit({"t": "exhaust", "card": c})
	else:
		discard.append(c)
	_check_end()
	return _flush()


func use_item(item_id: String) -> Array:
	events = []
	var it: Dictionary = DB.items.get(item_id, {})
	if it.is_empty() or over:
		return _flush()
	_emit({"t": "item", "id": item_id, "name": it.name})
	_run_effects(it.effects, "player", {"card": {"tags": ["item"]}})
	_check_end()
	return _flush()


func end_turn() -> Array:
	events = []
	if over:
		return _flush()
	# discard hand
	for c in hand:
		discard.append(c)
	hand.clear()
	_tick_down("player", ["weak", "vulnerable"])
	_enemy_turn()
	if not over:
		_start_player_turn()
	return _flush()


# --------------------------------------------------------------- turn flow
func _start_player_turn() -> void:
	turn += 1
	cards_played_this_turn = 0
	player.block = 0
	_tick_bleed("player")
	if _check_end():
		return
	if player.statuses.has("vow"):
		_gain_block("player", int(player.statuses.vow))
	player.energy = player.max_energy
	_draw(hand_size)
	_trigger("turn", turn)
	_choose_intent()
	_emit({"t": "turn", "n": turn})


func _enemy_turn() -> void:
	in_enemy_turn = true
	_enemy_turn_inner()
	in_enemy_turn = false


func _enemy_turn_inner() -> void:
	enemy.block = 0
	_tick_bleed("enemy")
	if _check_end():
		return
	if enemy.statuses.has("regen") and not enemy.statuses.has("ash_struck") and enemy.hp < enemy.max_hp:
		var amt: int = min(int(enemy.statuses.regen), enemy.max_hp - enemy.hp)
		enemy.hp += amt
		_emit({"t": "heal", "target": "enemy", "amount": amt, "text": "Fae Vigor"})
	var move: Dictionary = intent
	if move.is_empty():
		return
	_emit({"t": "enemy_move", "key": intent_key, "label": move.get("label", intent_key)})
	_run_effects(move.get("effects", []), "enemy", {"move": move})
	last_move = intent_key
	_tick_down("enemy", ["weak", "vulnerable"])
	_check_end()


func _choose_intent() -> void:
	var ai: Dictionary = enemy_def.get("ai", {})
	var moves: Dictionary = enemy_def.get("moves", {})
	var key = ""
	if gimmick.get("type", "") == "stalker" and not gimmick.alerted:
		key = "pounce_doe" if gimmick.doe_threat >= gimmick.doe_threat_to_pounce else "stalk"
	else:
		var options: Array = []
		var total = 0
		for o in ai.get("hunting", []):
			var m: Dictionary = moves.get(o.move, {})
			if o.has("if_hp_below") and enemy_hp_ratio() >= float(o.if_hp_below):
				continue
			if o.has("if_range") and current_range != o.if_range:
				continue
			if m.has("requires_range") and current_range != m.requires_range:
				continue
			if bool(o.get("no_repeat", false)) and last_move == o.move:
				continue
			options.append(o)
			total += int(o.weight)
		if options.is_empty():
			key = "lunge" if moves.has("lunge") else moves.keys()[0]
		else:
			var roll = rng.randi_range(1, total)
			for o in options:
				roll -= int(o.weight)
				if roll <= 0:
					key = o.move
					break
	intent_key = key
	intent = moves.get(key, {})
	_emit({"t": "intent", "key": key})


func intent_summary() -> Dictionary:
	## For the UI: kind, label, damage per hit after modifiers, hits.
	var out = {"kind": intent.get("intent", "unknown"), "label": intent.get("label", ""), "damage": 0, "hits": 0, "block": 0}
	for e in intent.get("effects", []):
		if e.type == "damage":
			out.hits = int(e.get("hits", 1))
			out.damage = _enemy_attack_amount(e)
		elif e.type == "block":
			out.block = int(e.amount)
	return out


# ----------------------------------------------------------------- effects
func _run_effects(effects: Array, source: String, ctx: Dictionary) -> void:
	for e in effects:
		if over:
			return
		match e.type:
			"damage":
				if source == "player":
					_player_hits(ctx.get("card", {}), e)
				else:
					for i in int(e.get("hits", 1)):
						_enemy_hits_player(e)
						if over:
							return
			"block":
				_gain_block(source, int(e.amount))
			"draw":
				_draw(int(e.amount))
			"energy":
				player.energy += int(e.amount)
				_emit({"t": "energy", "amount": int(e.amount)})
			"heal":
				_heal(source, int(e.amount))
			"lose_hp":
				_lose_hp(source, int(e.amount))
			"apply":
				var tgt: String = e.target
				var who = source if tgt == "self" else ("enemy" if source == "player" else "player")
				_apply_status(who, e.status, int(e.stacks), bool(e.get("force", false)))
			"hide_or_block":
				if not gimmick.is_empty() and not gimmick.alerted:
					_apply_status("player", "hidden", 1, true)
				else:
					_gain_block("player", int(e.block))
			"move":
				if current_range != e.to:
					current_range = e.to
					_emit({"t": "range", "range": current_range})
			"noise":
				_add_noise(int(e.amount))
			"quiet":
				if not gimmick.is_empty():
					gimmick.noise = max(0, gimmick.noise - int(e.amount))
					_emit({"t": "noise", "value": gimmick.noise})
			"doe_threat":
				gimmick.doe_threat += int(e.amount)
				_emit({"t": "doe_threat", "value": gimmick.doe_threat})
			"kill_doe":
				if gimmick.doe == "grazing":
					gimmick.doe = "ruined"
					_emit({"t": "doe", "state": "ruined"})
					_trigger("doe_killed")
				_alert()
			_:
				push_warning("Unknown effect: %s" % e.type)


func _player_attack_amount(card: Dictionary, e: Dictionary, consume: bool) -> int:
	var base = float(e.amount)
	if e.has("execute_below") and enemy_hp_ratio() < float(e.execute_below):
		base = float(e.execute_amount)
	if e.has("fae_amount") and enemy.fae:
		base = float(e.fae_amount)
	var tags: Array = card.get("tags", [])
	if not "item" in tags:
		base += int(player.statuses.get("strength", 0))
	if "bow" in tags and current_range == NEAR:
		base = floor(base * 0.5)
	if player.statuses.has("weak"):
		base = floor(base * 0.75)
	if player.statuses.has("hidden") and not "item" in tags:
		base *= 2.0
	var mult = 1.0
	if enemy.statuses.has("vulnerable"):
		mult += 0.5
	if enemy.statuses.has("ash_struck") and enemy.fae:
		mult += 0.5 if mult == 1.0 else 0.25
	return int(floor(base * mult))


func _player_hits(card: Dictionary, e: Dictionary) -> void:
	var dmg = _player_attack_amount(card, e, true)
	var ambush = player.statuses.has("hidden") and not "item" in card.get("tags", [])
	if ambush:
		player.statuses.erase("hidden")
		_emit({"t": "status", "target": "player", "status": "hidden", "stacks": 0})
	var blocked: int = min(enemy.block, dmg)
	enemy.block -= blocked
	var real = dmg - blocked
	enemy.hp = max(0, enemy.hp - real)
	total_damage_dealt += real
	_emit({"t": "damage", "target": "enemy", "amount": real, "blocked": blocked, "ambush": ambush})
	if not gimmick.is_empty() and not gimmick.alerted:
		if gimmick.doe == "grazing":
			gimmick.doe = "safe"
			_emit({"t": "doe", "state": "safe"})
		_alert()
	_check_enemy_thresholds()
	_check_end()


func _enemy_attack_amount(e: Dictionary) -> int:
	var base = float(e.amount) + int(enemy.statuses.get("strength", 0))
	if enemy.statuses.has("weak"):
		base = floor(base * 0.75)
	if player.statuses.has("vulnerable"):
		base = floor(base * 1.5)
	if "iron_bracelet" in relic_ids and enemy.fae:
		base -= 1
	return int(max(0, base))


func _enemy_hits_player(e: Dictionary) -> void:
	if player.statuses.has("evade"):
		player.statuses.evade -= 1
		if player.statuses.evade <= 0:
			player.statuses.erase("evade")
		_emit({"t": "evade"})
		return
	var dmg = _enemy_attack_amount(e)
	var blocked: int = min(player.block, dmg)
	player.block -= blocked
	var real = dmg - blocked
	var before: int = player.hp
	player.hp = max(0, player.hp - real)
	_emit({"t": "damage", "target": "player", "amount": real, "blocked": blocked})
	_after_player_hp_loss(before)
	_check_end()


func _after_player_hp_loss(before: int) -> void:
	var half = player.max_hp / 2.0
	if before >= half and player.hp < half and player.hp > 0:
		for r in relic_ids:
			var rd: Dictionary = DB.relics.get(r, {})
			if rd.get("trigger", "") == "first_below_half_hp" and not relic_used.has(r):
				relic_used[r] = true
				_emit({"t": "relic", "id": r})
				_run_effects(rd.effects, "player", {})
	for tr in enemy_def.get("dialogue_triggers", []):
		if tr.when == "player_hp_below" and float(player.hp) / player.max_hp < float(tr.value):
			_fire_trigger(tr)


func _gain_block(who: String, amount: int) -> void:
	var t: Dictionary = player if who == "player" else enemy
	t.block += amount
	_emit({"t": "block", "target": who, "amount": amount})


func _heal(who: String, amount: int) -> void:
	var t: Dictionary = player if who == "player" else enemy
	var real: int = min(amount, t.max_hp - t.hp)
	t.hp += real
	_emit({"t": "heal", "target": who, "amount": real})


func _lose_hp(who: String, amount: int) -> void:
	var t: Dictionary = player if who == "player" else enemy
	var before: int = t.hp
	t.hp = max(0, t.hp - amount)
	_emit({"t": "damage", "target": who, "amount": amount, "blocked": 0, "self": true})
	if who == "player":
		_after_player_hp_loss(before)
	_check_end()


func _apply_status(who: String, status: String, stacks: int, force := false) -> void:
	var t: Dictionary = player if who == "player" else enemy
	if status == "hidden" and not force and not gimmick.is_empty() and gimmick.alerted:
		return
	if status == "hidden":
		t.statuses["hidden"] = 1
	else:
		t.statuses[status] = int(t.statuses.get(status, 0)) + stacks
	_emit({"t": "status", "target": who, "status": status, "stacks": t.statuses[status]})
	if who == "enemy":
		_trigger("status_applied", status)


func _tick_down(who: String, names: Array) -> void:
	var t: Dictionary = player if who == "player" else enemy
	for n in names:
		if t.statuses.has(n):
			t.statuses[n] -= 1
			if t.statuses[n] <= 0:
				t.statuses.erase(n)


func _tick_bleed(who: String) -> void:
	var t: Dictionary = player if who == "player" else enemy
	if t.statuses.has("bleed"):
		var amt: int = t.statuses.bleed
		var before: int = t.hp
		t.hp = max(0, t.hp - amt)
		_emit({"t": "damage", "target": who, "amount": amt, "blocked": 0, "bleed": true})
		if who == "player":
			_after_player_hp_loss(before)
		else:
			total_damage_dealt += amt
			_check_enemy_thresholds()
		t.statuses.bleed -= 1
		if t.statuses.bleed <= 0:
			t.statuses.erase("bleed")


func _add_noise(n: int) -> void:
	if gimmick.is_empty() or gimmick.alerted:
		return
	gimmick.noise += n
	_emit({"t": "noise", "value": gimmick.noise})
	if gimmick.noise >= gimmick.noise_to_alert:
		if gimmick.doe == "grazing":
			gimmick.doe = "fled"
			_emit({"t": "doe", "state": "fled"})
		_alert()


func _alert() -> void:
	if gimmick.is_empty() or gimmick.alerted:
		return
	gimmick.alerted = true
	player.statuses.erase("hidden")
	_emit({"t": "alerted"})
	_trigger("alerted")
	# a found hunter faces a new intent immediately (if it's still the player's turn)
	if not over and not in_enemy_turn:
		_choose_intent()


func _draw(n: int) -> void:
	for i in n:
		if hand.size() >= 10:
			return
		if draw_pile.is_empty():
			if discard.is_empty():
				return
			draw_pile = discard.duplicate()
			discard.clear()
			_shuffle(draw_pile)
			_emit({"t": "reshuffle"})
		var c: Dictionary = draw_pile.pop_back()
		hand.append(c)
		_emit({"t": "draw", "card": c})


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# ---------------------------------------------------------------- triggers
func _check_enemy_thresholds() -> void:
	for tr in enemy_def.get("dialogue_triggers", []):
		if tr.when == "enemy_hp_below" and enemy_hp_ratio() < float(tr.value) and enemy.hp > 0:
			_fire_trigger(tr)


func _trigger(when: String, value: Variant = null) -> void:
	for tr in enemy_def.get("dialogue_triggers", []):
		if tr.when != when:
			continue
		if when == "turn" and int(tr.value) != int(value):
			continue
		if when == "status_applied" and tr.status != value:
			continue
		_fire_trigger(tr)


func _fire_trigger(tr: Dictionary) -> void:
	var key: String = tr.scene
	if fired.has(key):
		return
	fired[key] = true
	_emit({"t": "dialogue", "scene": key})


func _check_end() -> bool:
	if over:
		return true
	if enemy.hp <= 0:
		over = true
		won = true
		_trigger("victory")
		_emit({"t": "victory"})
		return true
	if player.hp <= 0:
		over = true
		won = false
		_emit({"t": "defeat"})
		return true
	return false


func doe_saved() -> bool:
	return gimmick.get("doe", "") == "safe"


func _emit(ev: Dictionary) -> void:
	events.append(ev)


func _flush() -> Array:
	var out = events
	events = []
	return out
