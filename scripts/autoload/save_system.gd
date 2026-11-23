extends Node
## Versioned save format, designed so Book 2 can import Book 1's ending state.
##
## File layout (JSON):
## {
##   "format": "acotar-save",       # constant; lets later games recognise the file
##   "schema": 2,                   # bump + add a migration step when the shape changes
##   "game": "acotar_book1",        # which game wrote it
##   "game_version": "0.1.0",
##   "saved_at": "2026-11-23T19:00:00",
##   "carry_over": {...},           # power tier, stats, inventory, journal, canon choices, places
##   "progress": {...}              # chapter, region, flags, hp, explored map (book-specific)
## }
## A carry-over export ("acotar-carryover") holds only the carry_over block plus
## the book it came from. Book 2 reads that and ignores progress entirely.

const FORMAT := "acotar-save"
const CARRY_FORMAT := "acotar-carryover"
const SCHEMA := 2
const DIR := "user://saves/"

## Where slots live. The automated tests point this at a scratch folder so they
## never touch a player's real saves.
var dir := DIR

signal saved(slot: String)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(dir)


func slot_path(slot: String) -> String:
	return dir + slot + ".json"


func set_dir(d: String) -> void:
	dir = d
	DirAccess.make_dir_recursive_absolute(dir)


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func build_save() -> Dictionary:
	return {
		"format": FORMAT, "schema": SCHEMA, "game": GameState.GAME_ID,
		"game_version": ProjectSettings.get_setting("application/config/version", "0.0.0"),
		"saved_at": Time.get_datetime_string_from_system(),
		"carry_over": GameState.carry_over_dict(), "progress": GameState.progress_dict(),
	}


func save_slot(slot := "auto") -> bool:
	var f = FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(build_save(), "  "))
	f.close()
	saved.emit(slot)
	return true


func read_slot(slot: String) -> Dictionary:
	if not has_slot(slot):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("format", "") != FORMAT:
		push_error("Not an ACOTAR save: " + slot)
		return {}
	return migrate(parsed)


func load_slot(slot := "auto") -> bool:
	var d = read_slot(slot)
	if d.is_empty():
		return false
	apply_save(d)
	return true


func apply_save(d: Dictionary) -> void:
	GameState.load_from(d.get("carry_over", {}), d.get("progress", {}))


## Upgrade older saves step by step. Each step takes schema N to N+1.
func migrate(d: Dictionary) -> Dictionary:
	var schema = int(d.get("schema", 0))
	if schema > SCHEMA:
		push_warning("Save is from a newer version (schema %d); loading best-effort." % schema)
		return d
	while schema < SCHEMA:
		match schema:
			0:
				# schema 0 (pre-release) had no carry_over split; everything was flat.
				d = {"format": FORMAT, "schema": 1, "game": d.get("game", GameState.GAME_ID),
					"carry_over": d.get("carry_over", d), "progress": d.get("progress", d)}
			1:
				d = _migrate_1_to_2(d)
		schema += 1
		d.schema = schema
	return d


## Schema 1 was the card-battle build: a deck, relics and a 3-slot item pouch.
## Schema 2 has a 30-slot inventory. Cards are dropped; relics become keepsake
## items; Feyre keeps her knife and bow; story items follow the flags.
static func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	var c: Dictionary = d.get("carry_over", {})
	var p: Dictionary = d.get("progress", {})
	var flags: Dictionary = p.get("flags", {})
	var chapter = int(p.get("chapter", 1))
	var inv: Array = []
	inv.resize(30)
	var put = func(slot: int, id: String, n: int) -> void:
		if n > 0:
			inv[slot] = {"id": id, "n": n}
	put.call(0, "hunting_knife", 1)
	put.call(1, "bow", 1)
	var has_ash = false
	for card in c.get("deck", []):
		if String(card.get("id", "")) == "ash_arrow":
			has_ash = true
	if has_ash and chapter < 4:
		put.call(2, "ash_arrow", 1)
	put.call(10, "arrow", 2)
	var next = 11
	var old_items: Dictionary = c.get("items", {})
	var food = int(old_items.get("venison_strip", 0))
	if food > 0:
		put.call(3, "venison_strip", food)
	var relic_items = {"elains_paint_tins": "paint_tins", "snare_wire": "snare_wire", "iron_bracelet": "iron_bracelet"}
	for r in c.get("relics", []):
		if relic_items.has(String(r)):
			put.call(next, relic_items[String(r)], 1)
			next += 1
	if bool(flags.get("wolf_killed", false)) and not bool(flags.get("ch03_hides_sold", false)):
		put.call(next, "wolf_pelt", 1)
		next += 1
		put.call(next, "doe_hide" if bool(flags.get("doe_saved", false)) else "doe_hide_torn", 1)
		next += 1
	var out_carry = {
		"tier": int(c.get("tier", 0)), "max_hp": int(c.get("max_hp", 30)), "coins": int(c.get("coins", 0)),
		"inventory": inv, "journal": c.get("journal", []), "canon_choices": c.get("canon_choices", {}),
		"places": ["mortal_forest", "archeron_cottage", "mortal_village"], "stats": {},
	}
	var out_progress = p.duplicate(true)
	out_progress["explored"] = {}
	out_progress["hotbar_index"] = 0
	return {"format": FORMAT, "schema": 2, "game": d.get("game", GameState.GAME_ID),
		"game_version": d.get("game_version", ""), "saved_at": d.get("saved_at", ""),
		"carry_over": out_carry, "progress": out_progress}


## Writes the file a later game imports. Returns the absolute path.
func export_carryover(path := "user://acotar_book1_carryover.json") -> String:
	var payload = {
		"format": CARRY_FORMAT, "schema": SCHEMA, "from_game": GameState.GAME_ID,
		"exported_at": Time.get_datetime_string_from_system(),
		"ending_chapter": GameState.chapter, "carry_over": GameState.carry_over_dict(),
	}
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	return ProjectSettings.globalize_path(path)


## What a later game calls. Accepts a carry-over export or a full save.
static func read_carryover(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	if d.get("format", "") in [CARRY_FORMAT, FORMAT]:
		return d.get("carry_over", {})
	return {}
