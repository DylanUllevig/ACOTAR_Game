extends Node
## Owns what is on screen: one region (overworld) or the battle. Keeps the
## region alive but detached during a battle so the player returns exactly
## where they were.

signal region_changed(id: String)

const REGIONS := {
	"forest": "res://scripts/world/regions/forest.gd",
	"cottage": "res://scripts/world/regions/cottage.gd",
	"village": "res://scripts/world/regions/village.gd",
	"wall_ride": "res://scripts/world/regions/wall_ride.gd",
}

var root: Node = null          # set by main.gd
var current_region: Node = null
var battle: Node = null
var busy = false


func goto_region(id: String, spawn := "", on_enter := "") -> void:
	if not REGIONS.has(id):
		push_error("Unknown region " + id)
		return
	busy = true
	await UI.fade_out(0.45)
	if current_region:
		current_region.queue_free()
		current_region = null
	GameState.region = id
	if spawn != "":
		GameState.spawn = spawn
	var r: Node2D = Node2D.new()
	r.set_script(load(REGIONS[id]))
	r.name = "Region_" + id
	root.add_child(r)
	current_region = r
	region_changed.emit(id)
	UI.show_hud(true)
	await get_tree().process_frame
	await UI.fade_in(0.6)
	busy = false
	if on_enter != "":
		await Dialogue.play(on_enter)
	elif r.has_method("on_enter"):
		await r.on_enter()


func start_battle(enemy_id: String, on_win := "", on_lose := "") -> void:
	busy = true
	await UI.flash_to_battle()
	if current_region:
		root.remove_child(current_region)
	UI.show_hud(false)
	var b = Node2D.new()
	b.set_script(load("res://scripts/battle/battle_scene.gd"))
	b.name = "Battle"
	root.add_child(b)
	battle = b
	await UI.fade_in(0.35)
	busy = false
	var result: Dictionary = await b.run(enemy_id)
	# stay busy until the outcome scene starts, so region triggers the player is
	# still standing in cannot fire during the fade back
	busy = true
	await UI.fade_out(0.5)
	b.queue_free()
	battle = null
	if result.get("won", false):
		if current_region:
			root.add_child(current_region)
		UI.show_hud(true)
		await UI.fade_in(0.5)
		busy = false
		if on_win != "":
			await Dialogue.play(on_win)
	else:
		if current_region:
			root.add_child(current_region)
		UI.show_hud(true)
		await UI.fade_in(0.3)
		busy = false
		if on_lose != "":
			await Dialogue.play(on_lose)


func continue_game() -> void:
	await goto_region(GameState.region, GameState.spawn, "")
