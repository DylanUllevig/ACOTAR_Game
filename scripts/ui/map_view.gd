class_name MapView
extends Control
## Schematic of Prythian drawn from data/book1/locations.json (map_xy). The
## supplied map image is reference only and is not shipped; this keeps the
## layout faithful without redistributing it.

const PLAYABLE := Color(0.91, 0.77, 0.47)
const LOCKED := Color(0.55, 0.52, 0.48)
const REGION_FOR := {"forest": "mortal_forest", "cottage": "archeron_cottage", "village": "mortal_village", "wall_ride": "the_wall"}


func _ready() -> void:
	custom_minimum_size = Vector2(800, 700)


func _to_px(xy: Array, r: Rect2) -> Vector2:
	# map_xy covers a tall portrait map; fit the x 0.4..0.95, y 0.25..0.9 band.
	var nx = (float(xy[0]) - 0.4) / 0.55
	var ny = (float(xy[1]) - 0.25) / 0.65
	return r.position + Vector2(nx * r.size.x, ny * r.size.y)


func _draw() -> void:
	var r = Rect2(Vector2(60, 20), Vector2(size.x - 120, size.y - 40))
	draw_rect(r, Color(0.86, 0.8, 0.68), true)
	draw_rect(r, Art.GOLD_DIM, false, 3.0)
	var f = Art.font("caps")
	var fi = Art.font("italic")
	# the Wall: horizontal band
	var wy = _to_px([0.6, 0.795], r).y
	draw_rect(Rect2(Vector2(r.position.x, wy - 10), Vector2(r.size.x, 20)), Color(0.25, 0.3, 0.38, 0.6), true)
	draw_string(f, Vector2(r.position.x + 14, wy - 16), "THE WALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.15, 0.18, 0.25))
	draw_string(fi, Vector2(r.position.x + 14, wy + 40), "Mortal Lands", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.2, 0.17, 0.14))
	draw_string(fi, Vector2(r.position.x + 14, wy - 46), "Prythian", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.2, 0.17, 0.14))
	var here: String = REGION_FOR.get(GameState.region, "")
	for id in DB.locations:
		var loc: Dictionary = DB.locations[id]
		var p = _to_px(loc.map_xy, r)
		var col = PLAYABLE if loc.get("playable_in_m1", false) else LOCKED
		draw_circle(p, 9.0, col)
		draw_arc(p, 11.0, 0, TAU, 24, Color(0.15, 0.1, 0.08), 2.0)
		if id == here:
			draw_arc(p, 20.0, 0, TAU, 32, Color(0.7, 0.1, 0.12), 4.0)
		draw_string(f, p + Vector2(16, 6), loc.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.18, 0.12, 0.1))
	var courts: Dictionary = DB.load_json(DB.BOOK + "locations.json").get("flavor_courts", {})
	for id in courts:
		var p2 = _to_px(courts[id].map_xy, r)
		if r.has_point(p2):
			draw_string(fi, p2, courts[id].name, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.35, 0.3, 0.26))
