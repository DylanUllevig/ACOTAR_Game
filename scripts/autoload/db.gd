extends Node
## Loads every content file in res://data. The game reads canon, items,
## creatures and dialogue from here; nothing story-specific is hard-coded in
## scripts.

const DATA := "res://data/"
const BOOK := "res://data/book1/"
const DIALOGUE_FILES := ["ch01", "ch02", "ch03", "ch04", "ch05", "hunt"]
## Every action a dialogue line may run (see Dialogue._run_action).
const ACTIONS := ["chapter_card", "objective", "journal", "place", "set_flag", "item", "take_item", "coins",
	"heal", "heal_full", "unlock_tier", "open_shop", "sell_hides", "leave_coins", "save_checkpoint", "time",
	"shake", "sfx", "music", "region_call", "door_burst", "fade_to_black", "start_hunt", "goto", "game_over",
	"wall_cinematic", "end_slice"]

var enemies = {}
var items = {}
var inventory_size = 30
var hotbar_size = 10
var starting_inventory: Array = []
var tiers: Array = []
var shops = {}
var hide_prices = {}
var chapters: Array = []
var characters = {}
var locations = {}
var flavor_courts = {}
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
	enemies = load_json(DATA + "enemies.json").get("enemies", {})
	var it: Dictionary = load_json(DATA + "items.json")
	items = it.get("items", {})
	inventory_size = int(it.get("inventory_size", 30))
	hotbar_size = int(it.get("hotbar_size", 10))
	starting_inventory = it.get("starting_inventory", [])
	tiers = load_json(DATA + "power_tiers.json").get("tiers", [])
	var sh: Dictionary = load_json(DATA + "shops.json")
	shops = sh.get("shops", {})
	hide_prices = sh.get("hide_prices", {})
	chapters = load_json(BOOK + "chapters.json").get("chapters", [])
	characters = load_json(BOOK + "characters.json").get("characters", {})
	var loc: Dictionary = load_json(BOOK + "locations.json")
	locations = loc.get("regions", {})
	flavor_courts = loc.get("flavor_courts", {})
	quotes = load_json(BOOK + "quotes.json").get("quotes", {})
	lore = load_json(BOOK + "lore.json").get("entries", {})
	scenes.clear()
	for f in DIALOGUE_FILES:
		var d: Dictionary = load_json(BOOK + "dialogue/" + f + ".json")
		for k in d.get("scenes", {}):
			if scenes.has(k):
				errors.append("Duplicate dialogue scene id: " + k)
			scenes[k] = d.scenes[k]
	for e in errors:
		push_error(e)


func item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return String(items.get(id, {}).get("name", id))


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
	var uses = ["knife", "bow", "eat"]
	for id in items:
		var d: Dictionary = items[id]
		for k in ["name", "kind", "icon", "stack", "text"]:
			if not d.has(k):
				problems.append("item %s is missing '%s'" % [id, k])
		if d.has("use") and not String(d.use) in uses:
			problems.append("item %s has unknown use %s" % [id, d.use])
		if d.get("use", "") == "bow" and not items.has(String(d.get("ammo", ""))):
			problems.append("item %s fires unknown ammo %s" % [id, d.get("ammo", "")])
		if d.get("use", "") == "eat" and int(d.get("heal", 0)) <= 0:
			problems.append("food %s heals nothing" % id)
	for e in starting_inventory:
		if not items.has(String(e.id)):
			problems.append("starting inventory has unknown item " + String(e.id))
		if int(e.slot) < 0 or int(e.slot) >= inventory_size:
			problems.append("starting inventory slot out of range: %d" % int(e.slot))
	for eid in enemies:
		var e: Dictionary = enemies[eid]
		for tr in e.get("triggers", []):
			if tr.has("scene") and not scenes.has(tr.scene):
				problems.append("enemy %s trigger references unknown scene %s" % [eid, tr.scene])
			if tr.has("bark") and not characters.has(String(tr.bark.get("s", ""))):
				problems.append("enemy %s bark uses unknown speaker" % eid)
		for dr in e.get("drops", []):
			if not items.has(String(dr.id)):
				problems.append("enemy %s drops unknown item %s" % [eid, dr.id])
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
				if String(ch.get("t", "")).contains("(Canon)"):
					problems.append("scene %s choice still carries a (Canon) tag" % sid)
			for key in ["if_item", "if_not_item"]:
				if line.has(key) and not items.has(String(line[key])):
					problems.append("scene %s checks unknown item %s" % [sid, line[key]])
			var acts: Array = line.get("do", [])
			for ch in line.get("choices", []):
				acts += ch.get("do", [])
			for a in acts:
				var t = String(a.get("type", ""))
				if not t in ACTIONS:
					problems.append("scene %s uses unknown action %s" % [sid, t])
					continue
				match t:
					"item", "take_item":
						if not items.has(String(a.get("id", ""))):
							problems.append("scene %s uses unknown item %s" % [sid, a.get("id", "")])
					"journal":
						if not lore.has(String(a.get("id", ""))):
							problems.append("scene %s unlocks unknown lore %s" % [sid, a.get("id", "")])
					"open_shop":
						if not shops.has(String(a.get("shop", ""))):
							problems.append("scene %s opens unknown shop %s" % [sid, a.get("shop", "")])
					"place":
						if not locations.has(String(a.get("id", ""))):
							problems.append("scene %s reveals unknown place %s" % [sid, a.get("id", "")])
					"unlock_tier":
						if tier(int(a.get("tier", -1))).is_empty():
							problems.append("scene %s unlocks unknown tier %s" % [sid, a.get("tier", "")])
					"region_call":
						if String(a.get("method", "")) == "":
							problems.append("scene %s region_call has no method" % sid)
					"goto":
						if not a.has("region"):
							problems.append("scene %s goto has no region" % sid)
						if not a.has("chapter"):
							problems.append("scene %s changes region without setting the chapter" % sid)
	for sid in shops:
		for c in shops[sid].get("sells", []):
			if not items.has(String(c.id)):
				problems.append("shop %s sells unknown item %s" % [sid, c.id])
		for c in shops[sid].get("buys", []):
			if not items.has(String(c)):
				problems.append("shop %s buys unknown item %s" % [sid, c])
	for k in hide_prices:
		if not items.has(String(k)):
			problems.append("hide price for unknown item %s" % k)
	if chapters.size() != 46:
		problems.append("expected 46 chapters, found %d" % chapters.size())
	return problems
