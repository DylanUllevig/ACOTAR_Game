extends Node
## Loads every content file in res://data. The game reads canon, cards, enemies
## and dialogue from here; nothing story-specific is hard-coded in scripts.

const DATA := "res://data/"
const BOOK := "res://data/book1/"

var cards = {}
var card_pools = {}
var starter_deck: Array = []
var enemies = {}
var relics = {}
var items = {}
var item_slots = 3
var statuses = {}
var tiers: Array = []
var shops = {}
var hide_prices = {}
var chapters: Array = []
var characters = {}
var locations = {}
var quotes = {}
var lore = {}
var scenes = {}
var errors: Array[String] = []


func _ready() -> void:
	load_all()


func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("Missing data file: " + path)
		return {}
	var text = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		errors.append("Invalid JSON: " + path)
		return {}
	return parsed


func load_all() -> void:
	errors.clear()
	var c: Dictionary = load_json(DATA + "cards.json")
	cards.clear()
	for card in c.get("cards", []):
		cards[card.id] = card
	card_pools = c.get("pools", {})
	starter_deck = c.get("starter_deck", [])
	enemies = load_json(DATA + "enemies.json").get("enemies", {})
	relics = load_json(DATA + "relics.json").get("relics", {})
	var it: Dictionary = load_json(DATA + "items.json")
	items = it.get("items", {})
	item_slots = int(it.get("item_slots", 3))
	statuses = load_json(DATA + "statuses.json").get("statuses", {})
	tiers = load_json(DATA + "power_tiers.json").get("tiers", [])
	var sh: Dictionary = load_json(DATA + "shops.json")
	shops = sh.get("shops", {})
	hide_prices = sh.get("hide_prices", {})
	chapters = load_json(BOOK + "chapters.json").get("chapters", [])
	characters = load_json(BOOK + "characters.json").get("characters", {})
	locations = load_json(BOOK + "locations.json").get("regions", {})
	quotes = load_json(BOOK + "quotes.json").get("quotes", {})
	lore = load_json(BOOK + "lore.json").get("entries", {})
	scenes.clear()
	for f in ["ch01", "ch02", "ch03", "ch04", "ch05", "battle"]:
		var d: Dictionary = load_json(BOOK + "dialogue/" + f + ".json")
		for k in d.get("scenes", {}):
			if scenes.has(k):
				errors.append("Duplicate dialogue scene id: " + k)
			scenes[k] = d.scenes[k]
	for e in errors:
		push_error(e)


func card_effective(id: String, upgraded: bool) -> Dictionary:
	var base: Dictionary = cards.get(id, {})
	if base.is_empty():
		push_error("Unknown card: " + id)
		return {"id": id, "name": id, "cost": 9, "effects": [], "text": "MISSING"}
	if not upgraded or not base.has("upgrade"):
		return base
	var d = base.duplicate(true)
	for k in base.upgrade:
		d[k] = base.upgrade[k]
	d.name = base.name + "+"
	return d


func tier(n: int) -> Dictionary:
	for t in tiers:
		if int(t.tier) == n:
			return t
	return {}


func chapter(n: int) -> Dictionary:
	for c in chapters:
		if int(c.n) == n:
			return c
	return {}


func character_name(id: String) -> String:
	if characters.has(id):
		return characters[id].name
	return id.capitalize()


## Checks cross-references between data files. Used by tests and on boot in debug builds.
func validate() -> Array[String]:
	var problems: Array[String] = errors.duplicate()
	for id in starter_deck:
		if not cards.has(id):
			problems.append("starter_deck references unknown card " + id)
	for pool in card_pools:
		for id in card_pools[pool]:
			if not cards.has(id):
				problems.append("pool %s references unknown card %s" % [pool, id])
	for eid in enemies:
		var e: Dictionary = enemies[eid]
		for tr in e.get("dialogue_triggers", []):
			if not scenes.has(tr.scene):
				problems.append("enemy %s trigger references unknown scene %s" % [eid, tr.scene])
		for o in e.get("ai", {}).get("hunting", []):
			if not e.moves.has(o.move):
				problems.append("enemy %s ai references unknown move %s" % [eid, o.move])
	for rid in relics:
		if relics[rid].has("lore") and not lore.has(relics[rid].lore):
			problems.append("relic %s references unknown lore %s" % [rid, relics[rid].lore])
	for lid in lore:
		var q = lore[lid].get("quote")
		if q != null and not quotes.has(q):
			problems.append("lore %s references unknown quote %s" % [lid, q])
	for sid in scenes:
		for line in scenes[sid].get("lines", []):
			if line.has("s") and not characters.has(line.s):
				problems.append("scene %s uses unknown speaker %s" % [sid, line.s])
			if line.has("goto") and not scenes.has(line.goto):
				problems.append("scene %s goto unknown scene %s" % [sid, line.goto])
			for ch in line.get("choices", []):
				if ch.has("goto") and not scenes.has(ch.goto):
					problems.append("scene %s choice goto unknown scene %s" % [sid, ch.goto])
			var acts: Array = line.get("do", [])
			for ch in line.get("choices", []):
				acts += ch.get("do", [])
			for a in acts:
				match a.type:
					"start_battle":
						if not enemies.has(a.enemy):
							problems.append("scene %s battles unknown enemy %s" % [sid, a.enemy])
						for k in ["on_win", "on_lose"]:
							if a.has(k) and not scenes.has(a[k]):
								problems.append("scene %s %s unknown scene %s" % [sid, k, a[k]])
					"relic":
						if not relics.has(a.id):
							problems.append("scene %s gives unknown relic %s" % [sid, a.id])
					"item":
						if not items.has(a.id):
							problems.append("scene %s gives unknown item %s" % [sid, a.id])
					"journal":
						if not lore.has(a.id):
							problems.append("scene %s unlocks unknown lore %s" % [sid, a.id])
					"open_shop":
						if not shops.has(a.shop):
							problems.append("scene %s opens unknown shop %s" % [sid, a.shop])
					"goto":
						if a.has("on_enter") and not scenes.has(a.on_enter):
							problems.append("scene %s goto on_enter unknown scene %s" % [sid, a.on_enter])
						if not a.has("chapter"):
							problems.append("scene %s changes region without setting the chapter" % sid)
					"remove_card":
						if not cards.has(a.id):
							problems.append("scene %s removes unknown card %s" % [sid, a.id])
	for sid in shops:
		for c in shops[sid].get("cards", []):
			if not cards.has(c.id):
				problems.append("shop %s sells unknown card %s" % [sid, c.id])
		for c in shops[sid].get("items", []):
			if not items.has(c.id):
				problems.append("shop %s sells unknown item %s" % [sid, c.id])
		for c in shops[sid].get("relics", []):
			if not relics.has(c.id):
				problems.append("shop %s sells unknown relic %s" % [sid, c.id])
	if chapters.size() != 46:
		problems.append("expected 46 chapters, found %d" % chapters.size())
	return problems
