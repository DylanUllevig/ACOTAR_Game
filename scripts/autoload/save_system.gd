extends Node
## Versioned save format, designed so Book 2 can import Book 1's ending state.
##
## File layout (JSON):
## {
##   "format": "acotar-save",       # constant; lets later games recognise the file
##   "schema": 1,                   # bump + add a migration step when the shape changes
##   "game": "acotar_book1",        # which game wrote it
##   "game_version": "0.1.0",
##   "saved_at": "2026-11-23T19:00:00",
##   "carry_over": {...},           # power tier, stats, deck, relics, items, journal, canon choices
##   "progress": {...}              # chapter, region, flags, hp (book-specific)
## }
## A carry-over export ("acotar-carryover") holds only the carry_over block plus
## the book it came from. Book 2 reads that and ignores progress entirely.

const FORMAT := "acotar-save"
const CARRY_FORMAT := "acotar-carryover"
const SCHEMA := 1
const DIR := "user://saves/"

signal saved(slot: String)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func slot_path(slot: String) -> String:
	return DIR + slot + ".json"


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
		schema += 1
		d.schema = schema
	return d


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
