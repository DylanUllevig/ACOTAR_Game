extends Node
## Everything about Feyre's run. Split into two halves on save:
##   carry_over: what a later book imports (power, deck, relics, journal, canon choices)
##   progress:   where she is in this book (chapter, region, flags, hp)

signal changed
signal toast(text: String)

const GAME_ID := "acotar_book1"
## Flags that are canon choices worth remembering in later books.
const CARRY_FLAGS := ["doe_saved", "ch02_snapped", "ch03_isaac_barn", "ch03_kindness", "ch03_acolyte_done", "has_paint_tins"]

var chapter = 1
var region = "forest"
var spawn = "start"
var hour = 13.0
var tier = 0
var max_hp = 30
var hp = 30
var energy = 3
var hand_size = 5
var strength = 0
var coins = 0
var deck: Array = []
var relics: Array = []
var items = {}
var flags = {}
var journal: Array = []
var seen_cards = {}
var objective = ""
var stats = {"battles_won": 0, "damage_dealt": 0, "cards_played": 0, "cards_gained": 0, "relics_found": 0}
var next_uid = 1
var playtime = 0.0


func _process(delta: float) -> void:
	playtime += delta


func new_game() -> void:
	chapter = 1
	region = "forest"
	spawn = "start"
	hour = 13.0
	coins = 0
	deck = []
	relics = []
	items = {}
	flags = {}
	journal = []
	seen_cards = {}
	objective = ""
	stats = {"battles_won": 0, "damage_dealt": 0, "cards_played": 0, "cards_gained": 0, "relics_found": 0}
	next_uid = 1
	playtime = 0.0
	apply_tier(0, false)
	hp = max_hp
	for id in DB.starter_deck:
		add_card(id, false, true)
	changed.emit()


# ------------------------------------------------------------------ power
func apply_tier(n: int, announce := true) -> void:
	var t = DB.tier(n)
	if t.is_empty():
		return
	var old_max = max_hp
	tier = n
	max_hp = int(t.max_hp)
	energy = int(t.energy)
	hand_size = int(t.hand_size)
	strength = int(t.strength)
	hp = clamp(hp + max(0, max_hp - old_max), 1, max_hp)
	for id in t.get("grants_cards", []):
		add_card(id)
	if announce:
		toast.emit("Power rises: %s (Tier %d). Max HP %d to %d." % [t.name, n, old_max, max_hp])
	changed.emit()


func tier_progress() -> float:
	## 0..1 position on the whole-book power curve, for the meter.
	var top = 0
	for t in DB.tiers:
		top = max(top, int(t.tier))
	return float(tier) / float(max(1, top))


func power_score() -> int:
	## A single number so the player can feel the gap between Tier 0 and Made Fae.
	return max_hp + energy * 10 + hand_size * 4 + strength * 8 + relics.size() * 5


# ------------------------------------------------------------------- deck
func add_card(id: String, upgraded := false, silent := false) -> void:
	deck.append({"uid": next_uid, "id": id, "up": upgraded})
	next_uid += 1
	seen_cards[id] = true
	if not silent:
		stats.cards_gained += 1
		toast.emit("New card: " + DB.card_effective(id, upgraded).name)
	changed.emit()


func remove_card_uid(uid: int) -> void:
	for i in deck.size():
		if int(deck[i].uid) == uid:
			deck.remove_at(i)
			changed.emit()
			return


func remove_card_id(id: String, all := false) -> int:
	var removed = 0
	for i in range(deck.size() - 1, -1, -1):
		if deck[i].id == id:
			deck.remove_at(i)
			removed += 1
			if not all:
				break
	changed.emit()
	return removed


func upgrade_card_uid(uid: int) -> void:
	for c in deck:
		if int(c.uid) == uid:
			c.up = true
			toast.emit("Upgraded: " + DB.card_effective(c.id, true).name)
	changed.emit()


# ---------------------------------------------------------- relics, items
func add_relic(id: String) -> void:
	if id in relics:
		return
	relics.append(id)
	stats.relics_found += 1
	toast.emit("Relic found: " + DB.relics[id].name)
	changed.emit()


func has_relic(id: String) -> bool:
	return id in relics


func item_count() -> int:
	var n = 0
	for k in items:
		n += int(items[k])
	return n


func add_item(id: String, n := 1, label := "") -> bool:
	if n > 0 and item_count() + n > DB.item_slots:
		toast.emit("Your satchel is full (%d slots)." % DB.item_slots)
		return false
	items[id] = int(items.get(id, 0)) + n
	if items[id] <= 0:
		items.erase(id)
	if n > 0:
		toast.emit("Gained: %s%s" % [label if label != "" else DB.items[id].name, "" if n == 1 else " x%d" % n])
	changed.emit()
	return true


func add_coins(n: int) -> void:
	coins = max(0, coins + n)
	if n != 0:
		toast.emit(("+%d" % n if n > 0 else "%d" % n) + " coin")
	changed.emit()


# ------------------------------------------------------------------ flags
func has_flag(f: String) -> bool:
	return bool(flags.get(f, false))


func set_flag(f: String, v := true) -> void:
	flags[f] = v
	changed.emit()


func unlock_lore(id: String) -> void:
	if id in journal or not DB.lore.has(id):
		return
	journal.append(id)
	toast.emit("Journal: " + DB.lore[id].title)
	changed.emit()


func set_objective(text: String) -> void:
	objective = text
	changed.emit()


func collection_progress() -> Dictionary:
	return {
		"cards": seen_cards.size(), "cards_total": DB.cards.size(),
		"relics": relics.size(), "relics_total": DB.relics.size(),
		"lore": journal.size(), "lore_total": DB.lore.size(),
	}


# ------------------------------------------------------------ persistence
func carry_over_dict() -> Dictionary:
	var canon = {}
	for f in CARRY_FLAGS:
		if flags.has(f):
			canon[f] = flags[f]
	return {
		"tier": tier, "max_hp": max_hp, "energy": energy, "hand_size": hand_size, "strength": strength,
		"coins": coins, "deck": deck.duplicate(true), "relics": relics.duplicate(), "items": items.duplicate(),
		"journal": journal.duplicate(), "seen_cards": seen_cards.keys(), "canon_choices": canon,
		"stats": stats.duplicate(), "next_uid": next_uid,
	}


func progress_dict() -> Dictionary:
	return {
		"chapter": chapter, "region": region, "spawn": spawn, "hour": hour, "hp": hp,
		"flags": flags.duplicate(), "objective": objective, "playtime": playtime,
	}


func load_from(carry: Dictionary, progress: Dictionary) -> void:
	tier = int(carry.get("tier", 0))
	max_hp = int(carry.get("max_hp", 30))
	energy = int(carry.get("energy", 3))
	hand_size = int(carry.get("hand_size", 5))
	strength = int(carry.get("strength", 0))
	coins = int(carry.get("coins", 0))
	deck = []
	for c in carry.get("deck", []):
		deck.append({"uid": int(c.uid), "id": String(c.id), "up": bool(c.get("up", false))})
	relics = Array(carry.get("relics", []))
	items = {}
	var raw_items: Dictionary = carry.get("items", {})
	for k in raw_items:
		items[k] = int(raw_items[k])
	journal = Array(carry.get("journal", []))
	seen_cards = {}
	for id in carry.get("seen_cards", []):
		seen_cards[id] = true
	var st: Dictionary = carry.get("stats", {})
	for k in st:
		stats[k] = int(st[k])
	next_uid = int(carry.get("next_uid", deck.size() + 1))
	chapter = int(progress.get("chapter", 1))
	region = String(progress.get("region", "forest"))
	spawn = String(progress.get("spawn", "start"))
	hour = float(progress.get("hour", 13.0))
	hp = int(progress.get("hp", max_hp))
	flags = progress.get("flags", {})
	objective = String(progress.get("objective", ""))
	playtime = float(progress.get("playtime", 0.0))
	changed.emit()
