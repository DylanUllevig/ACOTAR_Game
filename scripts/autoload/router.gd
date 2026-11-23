extends Node
## Owns what is on screen: one region at a time. Fades between them, saves on
## arrival, and lets the region decide which story beat plays on entry (so a
## loaded save resumes the same way a fresh arrival does).

signal region_changed(id: String)

const REGIONS := {
	"forest": "res://scripts/world/regions/forest.gd",
	"cottage": "res://scripts/world/regions/cottage.gd",
	"village": "res://scripts/world/regions/village.gd",
	"wall_ride": "res://scripts/world/regions/wall_ride.gd",
}

var root: Node = null          # set by main.gd
var current_region: Node = null
var busy = false


func goto_region(id: String, spawn := "", autosave := true) -> void:
	if not REGIONS.has(id):
		push_error("Unknown region " + id)
		return
	busy = true
	await UI.fade_out(0.45)
	if current_region:
		current_region.queue_free()
		current_region = null
	if GameState.region != id:
		GameState.pos = null
	GameState.region = id
	if spawn != "":
		GameState.spawn = spawn
		GameState.pos = null
	var r: Node2D = Node2D.new()
	r.set_script(load(REGIONS[id]))
	r.name = "Region_" + id
	root.add_child(r)
	current_region = r
	region_changed.emit(id)
	UI.show_hud(true)
	await get_tree().process_frame
	if autosave:
		SaveSystem.save_slot("auto")
	await UI.fade_in(0.6)
	busy = false
	if r.has_method("on_enter"):
		await r.on_enter()


func continue_game() -> void:
	await goto_region(GameState.region, "", false)
