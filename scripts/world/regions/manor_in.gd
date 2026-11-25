extends Region
## Chapters 6 to 32: inside the Spring Court manor. One script, eight rooms,
## each its own region (Router.REGIONS maps every manor_* id here, and the
## room is the part after "manor_"):
##   hall     the entrance hall: checkered marble and the grand staircase
##   dining   the dining room and its long table
##   study    the library, where she teaches herself to read, and the mural
##   gallery  the long gallery Tamlin opens for her
##   studio   the empty room Alis gives her to paint in
##   landing  the upper hall: her door, Lucien's door, the stairs
##   bedroom  her room: the bed, the bath, the window over the garden
##   kitchen  the great kitchen, burned out (Chapter 32 only: Alis's tale)
##
## In Chapters 31 and 32 the house has been sacked: the hall and the dining
## room are wrecked, and the rest of it is shut.
##
## chateau_in.gd extends this for her father's house across the Wall: it
## overrides rooms(), beats() and prefix(), and builds its own rooms.
##
## Laid out on the people's pixel density (1.5 world units per art pixel).
## The back wall's face runs from the top of the room down to WALL_H, where
## the floor starts; 'end' is the front wall. A door is [wall, where along
## it, the room it leads to, prompt]: going through puts her in that room at
## the spawn named after this one. The hall's front doors lead outside.

const WALL_H := 168.0
const BAND := 24.0

const ROOMS := {
	"hall": {"w": 1560.0, "end": 660.0, "wall": "wall_manor", "floor": "marble", "name": "The Entrance Hall",
		"doors": [["s", 780.0, "out", "Out to the gardens"], ["w", 470.0, "dining", "The dining room"],
			["e", 470.0, "study", "The library"], ["n", 190.0, "gallery", "The gallery"]]},
	"dining": {"w": 1260.0, "end": 640.0, "wall": "wall_manor_rose", "floor": "parquet", "name": "The Dining Room",
		"doors": [["e", 470.0, "hall", "The entrance hall"]]},
	"study": {"w": 1320.0, "end": 680.0, "wall": "wall_manor_study", "floor": "parquet", "name": "The Library",
		"doors": [["w", 480.0, "hall", "The entrance hall"]]},
	"gallery": {"w": 1760.0, "end": 560.0, "wall": "wall_manor", "floor": "parquet", "name": "The Gallery",
		"doors": [["w", 400.0, "hall", "The entrance hall"], ["e", 400.0, "studio", "Your painting room"]]},
	"studio": {"w": 900.0, "end": 540.0, "wall": "wall_manor_rose", "floor": "parquet", "name": "The Painting Room",
		"doors": [["w", 380.0, "gallery", "The gallery"]]},
	"landing": {"w": 1400.0, "end": 460.0, "wall": "wall_manor", "floor": "marble", "name": "The Upper Hall",
		"doors": [["w", 330.0, "hall", "Down the stairs"], ["n", 520.0, "bedroom", "Your room"]]},
	"bedroom": {"w": 1140.0, "end": 640.0, "wall": "wall_manor", "floor": "parquet", "name": "Your Room",
		"doors": [["s", 570.0, "landing", "Out to the upper hall"]]},
	"kitchen": {"w": 1200.0, "end": 620.0, "wall": "wall_kitchen_burnt", "floor": "flagstone", "name": "The Kitchens",
		"doors": [["e", 430.0, "hall", "Up to the hall"]]},
}

## The scene waiting in a room: [room, chapter, flag that must be set ("" for
## none), flag that must not be, scene]. The scene sets the second flag
## itself, first thing, so it plays once.
const BEATS := [
	["hall", 6, "", "ch06_hall", "ch06_hall"],
	["dining", 6, "ch06_hall", "ch06_feast", "ch06_feast"],
	["bedroom", 6, "ch06_feast", "ch06_bath", "ch06_bath"],
	["dining", 7, "", "ch07_dined", "ch07_dinner"],
	["bedroom", 7, "ch07_dined", "ch07_morning", "ch07_morning"],
	["dining", 8, "ch08_mapped", "ch08_dinner", "ch08_dinner"],
	["bedroom", 8, "ch08_dinner", "ch08_satchel", "ch08_satchel"],
	["dining", 10, "", "ch10_dinner", "ch10_dinner"],
	["bedroom", 10, "ch10_dinner", "ch10_room", "ch10_room"],
	["hall", 12, "", "ch12_night", "ch12_night"],
	["study", 13, "", "ch13_study", "ch13_study"],
	["bedroom", 16, "", "ch16_bath", "ch16_bath"],
	["dining", 16, "ch16_bath", "ch16_dinner", "ch16_dinner"],
	["bedroom", 17, "", "ch17_wake", "ch17_wake"],
	["hall", 17, "ch17_wake", "ch17_done", "ch17_screams"],
	["bedroom", 18, "", "ch18_morning", "ch18_morning"],
	["gallery", 19, "", "ch19_gallery", "ch19_gallery"],
	["studio", 19, "ch19_gallery", "ch19_studio", "ch19_studio"],
	["hall", 20, "", "ch20_tamlin", "ch20_tamlin"],
	["bedroom", 20, "ch20_tamlin", "ch20_sneak", "ch20_room"],
	["hall", 21, "", "ch21_hall", "ch21_hall"],
	["bedroom", 21, "ch21_hall", "ch21_wait", "ch21_wait"],
	["hall", 21, "ch21_wait", "ch21_bite", "ch21_bite"],
	["landing", 21, "ch21_wait", "ch21_bite", "ch21_bite"],
	["bedroom", 22, "", "ch22_wake", "ch22_wake"],
	["dining", 22, "ch22_wake", "ch22_lunch", "ch22_lunch"],
	["bedroom", 22, "ch22_lunch", "ch22_gown", "ch22_gown"],
	["dining", 22, "ch22_gown", "ch22_dinner", "ch22_dinner"],
	["studio", 22, "ch22_dinner", "ch22_paintings", "ch22_paintings"],
	["bedroom", 24, "", "ch24_wake", "ch24_wake"],
	["dining", 24, "ch24_wake", "ch24_dining", "ch24_dining"],
	["dining", 26, "", "ch26_rhys", "ch26_lunch"],
	["bedroom", 27, "", "ch27_night", "ch27_night"],
	["bedroom", 28, "", "ch28_dress", "ch28_dress"],
	["hall", 28, "ch28_dress", "ch28_hall", "ch28_hall"],
	["hall", 31, "", "ch31_wreck", "ch31_wreck"],
	["dining", 32, "ch32_clues", "ch32_dining", "ch32_dining"],
	["kitchen", 32, "", "ch32_kitchen", "ch32_kitchen"],
]

## Chapter 32: the signs in the wrecked hall, read in any order.
const CLUES := [["ch32_clue_blood", Vector2(420, 520), "The blood"], ["ch32_clue_glass", Vector2(990, 600), "The broken glass"],
	["ch32_clue_doors", Vector2(640, 610), "The front doors"], ["ch32_clue_bodies", Vector2(1180, 360), "The far end of the hall"]]

var room := "hall"
var W := 1560.0
var END := 660.0
var npc := {}
var fire_light: PointLight2D
var _table_ends: Array = []          # the dining table's outer lengths (gone from Ch 22)
var _table_wall: StaticBody2D
var _chairs: Array = []
var _clue_spots := {}                # flag -> its interactable (Ch 32)
var _worktable: Node2D               # the kitchen's overturned table (Ch 32)


## The rooms, the scenes waiting in them, and the region ids' prefix: what a
## house built on this script overrides.
func rooms() -> Dictionary:
	return ROOMS


func beats() -> Array:
	return BEATS


func prefix() -> String:
	return "manor_"


## Where the front doors lead: [region, spawn].
func outside() -> Array:
	return ["spring_manor", "door"]


func house_name() -> String:
	return "The Manor"


## Chapters 31 and 32: the manor after the sack.
func _wrecked() -> bool:
	return GameState.chapter == 31 or GameState.chapter == 32


func build() -> void:
	room = String(GameState.region).trim_prefix(prefix())
	if not rooms().has(room):
		room = "hall"
	var r: Dictionary = rooms()[room]
	W = float(r.w)
	END = float(r.end)
	interior = true
	surface = "stone" if String(r.floor) in ["marble", "flagstone"] else "wood"
	combat_allowed = false
	map_title = house_name() + ": " + String(r.name).trim_prefix("The ")
	map_base = Color(0.86, 0.82, 0.74)
	reveal_radius = 3000.0
	bounds = Rect2(0, -40, W, END + 140)
	spawns = {}
	_backdrop()
	_floor(String(r.floor))
	var wall = String(r.wall)
	if _wrecked() and room in ["hall", "dining"]:
		wall = "wall_manor_wreck"
	_walls(wall)
	for d in r.doors:
		_door(d)
	_build_room()
	if not spawns.has("start"):
		spawns.start = spawns[spawns.keys()[0]]
	enclose_bounds()
	_people()
	set_post({"vignette": 0.34, "lift": Vector3(0.012, 0.01, 0.006), "gain": Vector3(1.02, 1.0, 0.97), "saturation": 1.04, "grain": 0.0})


func _build_room() -> void:
	match room:
		"hall":
			if _wrecked():
				_hall_wreck()
			else:
				_hall()
		"dining":
			if _wrecked():
				_dining_wreck()
			else:
				_dining()
		"study": _study()
		"gallery": _gallery()
		"studio": _studio()
		"landing": _landing()
		"bedroom": _bedroom()
		"kitchen": _kitchen()


func _ready() -> void:
	super._ready()
	add_light(Vector2(0, -30), Color(1.0, 0.92, 0.82), 0.22, 2.2, false, player)
	_audio()


func _audio() -> void:
	var night = Region.night_amount(GameState.hour) > 0.5
	if _wrecked():
		# no birds, no servants: only the wind through the broken windows
		Audio.ambience("forest_wind")
		Audio.music("wreck", 4.0)
		return
	Audio.ambience("hearth" if night else "spring_day")
	if GameState.chapter != 26 or GameState.has_flag("ch26_rhys"):
		Audio.music("spring_night" if night else "spring_manor", 3.0)


## Daylight through tall windows; at night, candles and the fire.
func grade_for_hour(h: float) -> Dictionary:
	var n = Region.night_amount(h)
	return {"mod": Color(0.9, 0.88, 0.84).lerp(Color(0.4, 0.4, 0.55), n), "sun": Color.WHITE, "sun_energy": 0.0, "rays": 0.0}


func _night() -> bool:
	return Region.night_amount(GameState.hour) > 0.5


# ------------------------------------------------------------------ shell
func _backdrop() -> void:
	var b = Polygon2D.new()
	var e = bounds.grow(4000)
	b.polygon = PackedVector2Array([e.position, Vector2(e.end.x, e.position.y), e.end, Vector2(e.position.x, e.end.y)])
	b.color = Color(0.05, 0.045, 0.05)
	b.light_mask = 0
	b.z_index = -20
	add_child(b)


func _floor(kind: String) -> void:
	var f = Rect2(BAND, WALL_H, W - BAND * 2, END - WALL_H)
	_strip("terrain/%s_pattern.png" % kind, f, ground)
	map_rect(f, Color(0.9, 0.88, 0.8) if kind == "marble" else Color(0.74, 0.56, 0.38))


## A strip of a repeating texture (floor, wall face or wall top) over rect.
func _strip(rel: String, rect: Rect2, parent: Node, z := 0) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = Art.tex(rel)
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size / Art.PX)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * Art.PX
	s.position = rect.position
	s.z_index = z
	parent.add_child(s)
	return s


## A flat picture (a painting, a window, a rug), centred on pos.
func _flat_tex(rel: String, pos: Vector2, z := 0, flip := false) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = Art.tex(rel)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * Art.PX
	s.position = pos
	s.flip_h = flip
	s.z_index = z
	ground.add_child(s)
	return s


func _walls(wall_rel: String) -> void:
	_strip("interior/%s.png" % wall_rel, Rect2(BAND, 0, W - BAND * 2, WALL_H), ground)
	var top = "interior/wall_top_manor.png"
	_strip(top, Rect2(0, -BAND, W, BAND), ground)
	var gaps := {"w": [], "e": [], "s": []}
	for d in rooms()[room].doors:
		if gaps.has(String(d[0])):
			gaps[String(d[0])].append(float(d[1]))
	for side in ["w", "e"]:
		var x = 0.0 if side == "w" else W - BAND
		var y0 = -BAND
		var cuts: Array = gaps[side]
		cuts.sort()
		for c in cuts:
			_strip(top, Rect2(x, y0, BAND, c - 50.0 - y0), ground, 2)
			y0 = c + 40.0
		_strip(top, Rect2(x, y0, BAND, END + BAND - y0), ground, 2)
	var x0 = 0.0
	var front: Array = gaps.s
	front.sort()
	for c in front:
		_strip(top, Rect2(x0, END, c - 40.0 - x0, BAND), ground, 2)
		x0 = c + 40.0
	_strip(top, Rect2(x0, END, W - x0, BAND), ground, 2)
	add_wall(Rect2(0, 0, W, WALL_H + 6))
	add_wall(Rect2(0, 0, BAND, END))
	add_wall(Rect2(W - BAND, 0, BAND, END))
	add_wall(Rect2(0, END - 4, W, 40))
	var wall_c = Color(0.36, 0.46, 0.34)
	map_rect(Rect2(0, 0, W, WALL_H), wall_c)
	map_rect(Rect2(0, END, W, BAND), wall_c)


func _rect_poly(r: Rect2, color: Color, z := 1) -> Polygon2D:
	var p = Polygon2D.new()
	p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	p.color = color
	p.z_index = z
	ground.add_child(p)
	return p


## A doorway, its prompt, and the spawn just inside it named for the room
## beyond (the front doors' is "front").
func _door(d: Array) -> void:
	var side = String(d[0])
	var at = float(d[1])
	var to = String(d[2])
	var label = String(d[3])
	var wood = Color(0.36, 0.23, 0.15)
	var gold = Color(0.78, 0.62, 0.32)
	var spot: Vector2
	var sp: Vector2
	match side:
		"w", "e":
			var x = 0.0 if side == "w" else W - BAND
			_rect_poly(Rect2(x, at - 50, BAND, 90), Color(0.1, 0.08, 0.07), 1)
			_rect_poly(Rect2(x + (BAND - 4 if side == "w" else 0), at - 50, 4, 90), gold, 2)
			spot = Vector2(BAND + 34 if side == "w" else W - BAND - 34, at)
			sp = Vector2(BAND + 56 if side == "w" else W - BAND - 56, at + 12)
		"n":
			_rect_poly(Rect2(at - 40, WALL_H - 132, 80, 132), gold, 1)
			_rect_poly(Rect2(at - 34, WALL_H - 126, 68, 126), wood, 1)
			_rect_poly(Rect2(at - 2, WALL_H - 126, 4, 126), wood.darkened(0.3), 1)
			_rect_poly(Rect2(at + 18, WALL_H - 66, 6, 6), gold, 1)
			_rect_poly(Rect2(at - 24, WALL_H - 66, 6, 6), gold, 1)
			spot = Vector2(at, WALL_H + 30)
			sp = Vector2(at, WALL_H + 60)
		_:
			_rect_poly(Rect2(at - 40, END, 80, BAND), wood, 1)
			_rect_poly(Rect2(at - 40, END, 80, 4), gold, 2)
			spot = Vector2(at, END - 26)
			sp = Vector2(at, END - 50)
	add_interactable(spot, label, func(): await _go_door(to), 70)
	spawns["front" if to == "out" else to] = sp
	map_exit(spot, label)


func _go_door(to: String) -> void:
	var why = _door_shut(to)
	if why != "":
		UI.toast(why)
		return
	if to == "out":
		Router.goto_region(String(outside()[0]), String(outside()[1]))
	else:
		Router.goto_region(prefix() + to, room)


## Why a door won't do just now ("" when it will).
func _door_shut(to: String) -> String:
	var ch = GameState.chapter
	if _wrecked():
		return _door_shut_wrecked(to)
	if ch == 28:
		# the morning she leaves: dressed, down the stairs, out to the carriage
		if to == "out":
			return "" if GameState.has_flag("ch28_hall") else "Not now. " + String(GameState.objective)
		if to in ["dining", "study", "gallery", "studio"]:
			return "No time for that. The carriage is waiting."
		return ""
	if ch == 6 and not GameState.has_flag("ch06_feast"):
		return "" if to == "dining" else "Food first, then a way out. The smell came from a door on the left."
	match to:
		"gallery":
			if ch < 19:
				return "Locked. This wing has been shut up a long while."
		"studio":
			if not GameState.has_flag("ch19_gallery"):
				return "Locked."
		"out":
			if ch == 20 and GameState.has_flag("ch20_sneak"):
				return ""
			if ch == 25:
				return ""
			if _pending_here_or_inside():
				return "Not now. " + String(GameState.objective)
			if _night():
				return "The grounds belong to other things after dark. I stayed in."
	return ""


## Chapters 31 and 32: only the trail is open.
func _door_shut_wrecked(to: String) -> String:
	match to:
		"out":
			return "Not yet. Whatever happened here, the answer is inside."
		"dining":
			if GameState.chapter == 32 and not GameState.has_flag("ch32_clues"):
				return "Not yet. " + String(GameState.objective)
			return ""
		"hall":
			if room == "dining" and GameState.has_flag("ch32_prints") and not GameState.has_flag("ch32_hide"):
				return "Whatever it is, it's coming this way. Hide!"
			if room == "kitchen":
				return "Alis hasn't finished. And I needed to hear all of it."
			return ""
		"landing":
			return "Not upstairs. The tracks don't go that way."
	return "Nothing in there but ashes and broken glass."


## True while the chapter's next scene waits somewhere in the house.
func _pending_here_or_inside() -> bool:
	var ch = GameState.chapter
	for b in beats():
		if int(b[1]) != ch:
			continue
		if String(b[2]) != "" and not GameState.has_flag(String(b[2])):
			continue
		if not GameState.has_flag(String(b[3])):
			return true
	if ch == 13 and not GameState.has_flag("ch13_lucien"):
		return true
	if ch == 10 and not GameState.has_flag("ch10_window"):
		return true
	return false


## Furniture standing on the floor, its base at pos, with a soft contact
## shadow and a solid footprint. Returns its holder.
func _piece(rel: String, pos: Vector2, solid: Vector2, flip := false, mark := "") -> Node2D:
	var h = add_prop(rel, pos, 1.0, Vector2.ZERO, solid, flip)
	var sh = Sprite2D.new()
	sh.texture = Art.tex("fx/shadow_l.png")
	var tw = Art.tex(rel).get_width() if Art.tex(rel) else 30
	sh.scale = Vector2(maxf(1.0, roundf(tw * 0.9 / 30.0)), 1.0) * Art.PX
	sh.position = Vector2(0, -2)
	sh.light_mask = 0
	sh.z_index = -1
	h.add_child(sh)
	h.move_child(sh, 0)
	if mark != "":
		var r = Rect2(pos - Vector2(solid.x / 2.0, solid.y), solid)
		map_marks.append(["furniture", r.get_center(), r])
	return h


## A tall window in the back wall, with the light it lets in.
func _window(x: float) -> void:
	var night = _night()
	_flat_tex("interior/%s.png" % ("window_manor_night" if night else "window_day"), Vector2(x, 84), 1)
	if night:
		add_light(Vector2(x, WALL_H + 70), Color(0.5, 0.6, 1.0), 0.28, 1.1, false)
	else:
		add_light(Vector2(x, WALL_H + 80), Color(1.0, 0.92, 0.74), 0.5, 1.5, false)


func _painting(k: int, x: float, flip := false) -> void:
	_flat_tex("interior/painting_%d.png" % (k % 6), Vector2(x, 70), 1, flip)


func _candles(pos: Vector2) -> void:
	_piece("props/candelabra_table.png", pos, Vector2(30, 14))
	add_glow_lights("props/candelabra_table.png", pos, Color(1.0, 0.74, 0.44), 0.7, 0.6, false, 40.0, null, 0.06)


## A fireplace against the back wall: banked by day, roaring at night.
func _fireplace(x: float) -> void:
	var pos = Vector2(x, WALL_H + 24)
	_piece("props/fireplace.png", pos, Vector2(100, 30), false, "hearth")
	fire_light = add_light(pos + Vector2(0, -20), Color(1.0, 0.62, 0.3), 1.0 if _night() else 0.4, 2.4, false)
	add_flicker(fire_light, 0.18, 9.0)


func _rug(pos: Vector2) -> void:
	_flat_tex("interior/rug_manor.png", pos)


## A large carpet (tools/pixel/make_carpets.py), centred on pos.
func _carpet(name: String, pos: Vector2) -> void:
	_flat_tex("interior/carpet_%s.png" % name, pos)


# ------------------------------------------------------------------ rooms
func _hall() -> void:
	# the grand staircase rising into the back wall, roses either side
	_piece("props/staircase.png", Vector2(780, 398), Vector2(200, 170), false, "stairs")
	add_interactable(Vector2(780, 424), "Up the stairs", func(): await _go_door("landing"), 70, "Stairs")
	spawns.landing = Vector2(780, 452)
	spawns.stairs = spawns.landing
	_piece("props/vase_roses.png", Vector2(642, 384), Vector2(40, 18))
	_piece("props/vase_roses.png", Vector2(918, 384), Vector2(40, 18), true)
	_painting(0, 340)
	_window(470)
	_painting(1, 600)
	add_interactable(Vector2(600, 210), "The still life", _still_life, 60)
	_painting(2, 960, true)
	_window(1090)
	_painting(3, 1220)
	_piece("props/grandfather_clock.png", Vector2(1340, 186), Vector2(40, 16))
	_piece("props/palm.png", Vector2(1470, 196), Vector2(40, 18), true)
	_piece("props/palm.png", Vector2(86, 214), Vector2(40, 18))
	# a runner from the doors to the stairs, potted trees and candles by the doors
	for y in [480.0, 546.0, 612.0]:
		_rug(Vector2(780, y))
	_piece("props/orange_tree.png", Vector2(300, 620), Vector2(46, 18))
	_piece("props/orange_tree.png", Vector2(1260, 620), Vector2(46, 18), true)
	_candles(Vector2(560, 580))
	_candles(Vector2(1000, 580))
	_piece("props/bench_marble.png", Vector2(340, 238), Vector2(60, 16))
	_piece("props/bench_marble.png", Vector2(1220, 238), Vector2(60, 16), true)
	if GameState.chapter == 17 and not GameState.has_flag("ch17_done"):
		# the foyer table, cleared for the faerie they carried in
		_piece("props/stretcher.png", Vector2(780, 560), Vector2(110, 40))


func _dining() -> void:
	_fireplace(190)
	for x in [480.0, 630.0, 780.0]:
		_window(x)
	_painting(5, 1000)
	_piece("props/palm.png", Vector2(1150, 204), Vector2(40, 18), true)
	_piece("props/dresser.png", Vector2(900, 198), Vector2(80, 20))
	_carpet("dining", Vector2(630, 410))
	# the long table: three lengths end to end, a carved chair at either end.
	# From the dinner in Chapter 22 on, only the middle length is left: he
	# sent the rest somewhere between, and they never brought it back.
	var short = _short_table()
	for x in [500.0, 630.0, 760.0]:
		if short and x != 630.0:
			continue
		var t = add_prop("props/dining_table.png", Vector2(x, 444), 1.0, Vector2.ZERO, Vector2.ZERO)
		if x != 630.0:
			_table_ends.append(t)
	var r = Rect2(562, 336, 136, 104) if short else Rect2(432, 336, 396, 104)
	_table_wall = add_wall(r)
	map_marks.append(["furniture", r.get_center(), r])
	_chairs = [_piece("props/chair_carved.png", Vector2(534 if short else 404, 430), Vector2(30, 14)),
		_piece("props/chair_carved.png", Vector2(726 if short else 856, 430), Vector2(30, 14), true)]
	_candles(Vector2(140, 580))
	_candles(Vector2(1120, 580))
	_piece("props/harp.png", Vector2(1120, 330), Vector2(40, 16), true)
	spawns.seat = Vector2(760 if short else 900, 470)
	add_interactable(Vector2(760 if short else 900, 452), "The table", _table, 70, "Table")


## True once the long table has been cut down to one length (Ch 22's dinner;
## the scene sets its flag as it starts, after the room is built).
func _short_table() -> bool:
	var ch = GameState.chapter
	return ch > 22 or (ch == 22 and GameState.has_flag("ch22_dinner"))


## region_call (Ch 22): "You're so far away." The table's outer lengths are
## simply gone, and the two of them sit a couple of feet apart.
func table_shrinks() -> void:
	for t in _table_ends:
		if is_instance_valid(t):
			var tw = create_tween()
			tw.tween_property(t, "modulate:a", 0.0, 0.35)
			tw.tween_callback(t.queue_free)
	_table_ends.clear()
	if _table_wall != null and is_instance_valid(_table_wall):
		_table_wall.queue_free()
	_table_wall = add_wall(Rect2(562, 336, 136, 104))
	Audio.sfx("wings", -16.0)
	if _chairs.size() == 2:
		create_tween().tween_property(_chairs[0], "position:x", 534.0, 0.35).set_trans(Tween.TRANS_CUBIC)
		create_tween().tween_property(_chairs[1], "position:x", 726.0, 0.35).set_trans(Tween.TRANS_CUBIC)
	if npc.has("tamlin") and is_instance_valid(npc.tamlin):
		create_tween().tween_property(npc.tamlin, "position", Vector2(502, 470), 0.35).set_trans(Tween.TRANS_CUBIC)
	create_tween().tween_property(player, "global_position", Vector2(760, 470), 0.35).set_trans(Tween.TRANS_CUBIC)
	player.facing = 1
	UI.shake(2.0)
	await get_tree().create_timer(0.5, true, false, true).timeout


func _study() -> void:
	for x in [120.0, 210.0, 300.0, 390.0, 930.0, 1020.0, 1110.0, 1200.0]:
		_piece("props/bookcase.png", Vector2(x, 188), Vector2(84, 22), x > 600.0, "books" if x == 120.0 or x == 930.0 else "")
	_piece("props/grandfather_clock.png", Vector2(1268, 188), Vector2(36, 16))
	# the mural: the history of Prythian, hung on the wall between the shelves
	var m = Sprite2D.new()
	m.texture = Art.lit("props/tapestry.png")
	m.scale = Art.sprite_scale("props/tapestry.png")
	m.position = Vector2(660, 88)
	ground.add_child(m)
	add_interactable(Vector2(660, 214), "The mural", _mural, 70, "Mural")
	_candles(Vector2(556, 206))
	_candles(Vector2(764, 206))
	# her writing desk, its chair behind it
	_piece("props/armchair.png", Vector2(420, 400), Vector2(50, 16))
	_carpet("desk", Vector2(420, 470))
	_piece("props/desk.png", Vector2(420, 472), Vector2(104, 40), false, "desk")
	add_interactable(Vector2(420, 500), "The writing desk", _desk, 64, "Writing desk")
	spawns.desk = Vector2(420, 530)
	# a reading corner
	_carpet("library", Vector2(950, 530))
	_piece("props/bookcase.png", Vector2(96, 652), Vector2(84, 22))
	_piece("props/chaise.png", Vector2(1000, 520), Vector2(100, 24))
	_piece("props/armchair.png", Vector2(840, 506), Vector2(50, 16), true)
	_piece("props/palm.png", Vector2(76, 236), Vector2(40, 18))
	_piece("props/vase_roses.png", Vector2(1250, 620), Vector2(36, 16))


func _gallery() -> void:
	var k = 0
	for x in range(150, 1640, 125):
		if x in [400, 900, 1400]:
			_window(float(x))
		else:
			_painting(k, float(x), k % 4 == 3)
			k += 1
	add_interactable(Vector2(780, 214), "The paintings", func(): await Dialogue.play("spring_gallery"), 90, "Paintings")
	_piece("props/chaise.png", Vector2(620, 470), Vector2(100, 24))
	_piece("props/chaise.png", Vector2(1140, 470), Vector2(100, 24), true)
	_piece("props/harp.png", Vector2(1640, 240), Vector2(40, 16), true)
	_piece("props/palm.png", Vector2(84, 206), Vector2(40, 18))
	_piece("props/palm.png", Vector2(1690, 536), Vector2(40, 18), true)
	_candles(Vector2(400, 520))
	_candles(Vector2(1380, 520))
	_carpet("gallery", Vector2(880, 380))
	# clear of the doors, so no one coming in stands behind them
	_piece("props/statue.png", Vector2(290, 545), Vector2(30, 14))
	_piece("props/statue.png", Vector2(1470, 545), Vector2(30, 14), true)


func _studio() -> void:
	_window(320)
	_window(580)
	_painting(4, 760)
	_piece("props/easel.png", Vector2(450, 390), Vector2(80, 20), false, "easel")
	_piece("props/paint_table.png", Vector2(570, 410), Vector2(56, 20))
	_piece("props/easel_canvas.png", Vector2(700, 270), Vector2(40, 16))
	_piece("props/easel_canvas.png", Vector2(800, 280), Vector2(40, 16), true)
	if GameState.chapter >= 22:
		# more of her work leaning against the walls now
		_piece("props/easel_canvas.png", Vector2(160, 280), Vector2(40, 16))
		_piece("props/easel_canvas.png", Vector2(240, 290), Vector2(40, 16), true)
	_carpet("studio", Vector2(470, 430))
	_piece("props/stool.png", Vector2(440, 450), Vector2(22, 12))
	_piece("props/shelf.png", Vector2(112, 198), Vector2(70, 18))
	_piece("props/chest.png", Vector2(190, 508), Vector2(46, 20))
	_candles(Vector2(820, 470))
	add_interactable(Vector2(450, 430), "Paint", func(): await Dialogue.play("spring_paint"), 70, "Easel")
	spawns.easel = Vector2(450, 470)


func _landing() -> void:
	_painting(2, 250)
	_candles(Vector2(360, 200))
	_piece("props/vase_roses.png", Vector2(660, 200), Vector2(36, 16))
	_window(800)
	_piece("props/grandfather_clock.png", Vector2(930, 188), Vector2(36, 16))
	_painting(0, 1020, true)
	_painting(3, 1290)
	_piece("props/palm.png", Vector2(1340, 210), Vector2(40, 18), true)
	# Lucien's door, in the east wing's end
	_door_face(1150.0)
	add_interactable(Vector2(1150, WALL_H + 30), "Lucien's room", _lucien_door, 70, "Lucien's room")
	spawns.lucien = Vector2(1150, WALL_H + 60)
	_carpet("landing", Vector2(720, 330))
	_piece("props/bench_marble.png", Vector2(250, 214), Vector2(60, 16))


func _door_face(at: float) -> void:
	var gold = Color(0.78, 0.62, 0.32)
	var wood = Color(0.42, 0.2, 0.12)
	_rect_poly(Rect2(at - 40, WALL_H - 132, 80, 132), gold, 1)
	_rect_poly(Rect2(at - 34, WALL_H - 126, 68, 126), wood, 1)
	_rect_poly(Rect2(at - 2, WALL_H - 126, 4, 126), wood.darkened(0.3), 1)


func _bedroom() -> void:
	_fireplace(260)
	_rug(Vector2(260, 262))
	_piece("props/armchair.png", Vector2(372, 330), Vector2(50, 16), true)
	_piece("props/wardrobe.png", Vector2(450, 198), Vector2(84, 24), false, "wardrobe")
	_piece("props/vase_roses.png", Vector2(548, 200), Vector2(36, 16))
	_window(630)
	_window(770)
	add_interactable(Vector2(700, 214), "The window", _window_action, 70, "Window")
	spawns.window = Vector2(700, 250)
	_piece("props/bed_canopy.png", Vector2(930, 332), Vector2(100, 110), false, "bed")
	add_interactable(Vector2(930, 356), "The bed", _bed, 64, "Bed")
	spawns.bed = Vector2(930, 384)
	_piece("props/vanity.png", Vector2(1058, 198), Vector2(84, 22), true, "vanity")
	# the bath behind its painted screen
	_piece("props/bathtub.png", Vector2(140, 560), Vector2(96, 40), false, "bath")
	_piece("props/screen_painted.png", Vector2(290, 520), Vector2(110, 20))
	spawns.bath = Vector2(170, 600)
	_carpet("bedroom", Vector2(600, 420))
	_piece("props/washstand.png", Vector2(72, 470), Vector2(40, 16))
	_piece("props/chaise.png", Vector2(720, 560), Vector2(100, 24))
	_candles(Vector2(860, 590))
	_piece("props/palm.png", Vector2(1080, 600), Vector2(40, 18), true)


# ------------------------------------------------------------------ people
## Who is in the room, for the scene waiting here.
func _people() -> void:
	var ch = GameState.chapter
	var beat = _beat()
	match room:
		"dining":
			if beat != "" and beat != "ch06_feast":
				var short = _short_table()
				npc.tamlin = add_npc("lord_gold", Vector2(502 if short else 372, 470), "", Callable(), 2)
				if beat != "ch10_dinner":
					npc.lucien = add_npc("courtier_red", Vector2(650 if short else 690, 306), "", Callable(), 0)
		"hall":
			if beat == "ch17_screams":
				npc.tamlin = add_npc("lord_gold", Vector2(700, 540), "", Callable(), 2)
				npc.lucien = add_npc("courtier_red", Vector2(880, 520), "", Callable(), 1)
			elif beat == "ch21_hall":
				npc.lucien = add_npc("courtier_red", spawns.front + Vector2(80, -30), "", Callable(), 1)
			elif beat == "ch28_hall":
				# at the foot of the stairs, with the doors open behind him
				npc.lucien = add_npc("courtier_red", spawns.landing + Vector2(110, 40), "", Callable(), 1)
		"kitchen":
			npc.alis = add_npc("bark_servant", Vector2(760, 440), "", Callable(), 1)
		"bedroom":
			if beat == "ch28_dress":
				npc.alis = add_npc("bark_servant", Vector2(560, 420), "", Callable(), 1)
			elif beat in ["ch06_bath", "ch07_morning", "ch16_bath", "ch08_satchel", "ch22_gown"]:
				npc.alis = add_npc("housekeeper", Vector2(560, 420), "", Callable(), 1)
			elif beat == "ch24_wake":
				npc.alis = add_npc("bark_servant", Vector2(560, 420), "", Callable(), 1)
			elif beat == "ch27_night":
				npc.tamlin = add_npc("lord_gold", spawns.landing + Vector2(0, -40), "", Callable(), 3)
		"gallery":
			if beat == "ch19_gallery":
				npc.tamlin = add_npc("lord_gold", spawns.hall + Vector2(70, -40), "", Callable(), 2)
		"studio":
			if beat == "ch22_paintings":
				npc.tamlin = add_npc("lord_gold", Vector2(300, 440), "", Callable(), 2)
	if ch >= 8 and ch != 17 and ch < 29 and room == "hall" and not _night() and beat == "":
		var sheet = "bark_servant" if ch >= 24 else "housekeeper"
		npc.alis = add_npc(sheet, Vector2(1180, 560), "Alis", func(): await _alis(), 1)


## The scene waiting in this room for this chapter, if any.
func _beat() -> String:
	var ch = GameState.chapter
	for b in beats():
		if String(b[0]) != room or int(b[1]) != ch:
			continue
		if String(b[2]) != "" and not GameState.has_flag(String(b[2])):
			continue
		if GameState.has_flag(String(b[3])):
			continue
		return String(b[4])
	return ""


func on_enter() -> void:
	var s = _beat()
	if s != "":
		await Dialogue.play(s)
	# Chapter 31's last scene runs straight on into 32: the signs to read appear
	if room == "hall" and _wrecked() and GameState.chapter == 32 and _clue_spots.is_empty():
		_clues()


func _alis() -> void:
	var key = "alis_cake_%d" % GameState.chapter
	if not GameState.has_flag(key):
		GameState.set_flag(key)
		await Dialogue.play("spring_alis_cake")
	else:
		await Dialogue.play("spring_alis")


# ------------------------------------------------------------------ things
func _still_life() -> void:
	if GameState.chapter == 7 and not GameState.has_flag("ch07_painting"):
		await Dialogue.play("ch07_painting")
	else:
		await Dialogue.play("spring_painting")


## Something from the table, once a chapter: she eats her fill and wraps a
## couple of honey cakes for later.
func _table() -> void:
	var key = "table_%d" % GameState.chapter
	if GameState.has_flag(key):
		await Dialogue.play("spring_table")
		return
	GameState.set_flag(key)
	GameState.set_hp(GameState.max_hp)
	GameState.add_item("honey_cake", 2)
	Audio.sfx("eat", -6.0)
	UI.toast("You eat your fill, and wrap two honey cakes for later.")


func _desk() -> void:
	if GameState.chapter == 13 and not GameState.has_flag("ch13_read"):
		await Dialogue.play("ch13_read")
		return
	await Dialogue.play("spring_desk")


func _mural() -> void:
	if GameState.chapter == 13 and GameState.has_flag("ch13_read") and not GameState.has_flag("ch13_mural"):
		await Dialogue.play("ch13_mural")
		if npc.has("tamlin") and is_instance_valid(npc.tamlin):
			await walk_npc(npc.tamlin, spawns.hall, 160.0)
			npc.tamlin.queue_free()
			npc.erase("tamlin")
		return
	await Dialogue.play("spring_mural")


func _lucien_door() -> void:
	if GameState.chapter == 13 and GameState.has_flag("ch13_mural") and not GameState.has_flag("ch13_lucien"):
		await Dialogue.play("ch13_lucien")
		return
	await Dialogue.play("spring_lucien_door")


func _window_action() -> void:
	if GameState.chapter == 10 and GameState.has_flag("ch10_room") and not GameState.has_flag("ch10_window"):
		await Dialogue.play("ch10_window")
		return
	await Dialogue.play("spring_window_night" if _night() else "spring_window")


func _bed() -> void:
	await Dialogue.play("spring_bed")


## region_call (spring_bed): she lies down a while and wakes rested. At night,
## with nothing waiting for her in the house, she sleeps through to morning
## (the grounds are closed after dark, and the house keeps no time of its own).
func rest() -> void:
	await UI.fade_out(0.8)
	var slept = _night() and not _pending_here_or_inside()
	if slept:
		GameState.hour = 7.5
		GameState.changed.emit()
	GameState.set_hp(GameState.max_hp)
	await get_tree().create_timer(0.6, true, false, true).timeout
	await UI.fade_in(0.8)
	UI.toast("You sleep through to morning." if slept else "You rest a while, and wake refreshed.")


# ------------------------------------------------- staging (region_call)
## The beast comes in at the door and pads up to (x, y).
func beast_arrives(x: float, y: float) -> void:
	var rel = "actors/beast.png"
	var b = Node2D.new()
	var from: Vector2 = spawns.get("hall", spawns.get("front", Vector2(W / 2.0, END - 60)))
	if room == "hall":
		from = Vector2(1200, WALL_H + 40)
	b.position = from
	var s = Sprite2D.new()
	s.texture = Art.lit(rel)
	if s.texture != null:
		var m = Art.pixel_meta(rel)
		var g: Array = m.get("grid", [1, 1])
		s.hframes = int(g[0])
		s.vframes = int(g[1])
		s.frame = int(m.get("anims", {}).get("side", [1])[0])
		s.scale = Art.sprite_scale(rel)
		s.offset = Vector2(0, -s.texture.get_height() / (2.0 * s.vframes))
		s.flip_h = x > from.x
	b.add_child(s)
	world.add_child(b)
	npc.beast = b
	var tw = create_tween()
	tw.tween_property(b, "position", Vector2(x, y), from.distance_to(Vector2(x, y)) / 140.0)
	await tw.finished


## A flash of white light, and where the beast stood is a golden-haired male.
func beast_shifts() -> void:
	var at: Vector2 = npc.beast.position if npc.has("beast") and is_instance_valid(npc.beast) else Vector2(W / 2.0, 420)
	var flash = add_light(at + Vector2(0, -60), Color(1.0, 0.98, 0.9), 0.0, 3.0, false)
	var tw = create_tween()
	tw.tween_property(flash, "energy", 3.0, 0.15)
	await tw.finished
	Audio.sfx("ash_strike", -10.0)
	if npc.has("beast") and is_instance_valid(npc.beast):
		npc.beast.queue_free()
	npc.erase("beast")
	if not (npc.has("tamlin") and is_instance_valid(npc.tamlin)):
		npc.tamlin = add_npc("lord_gold", at, "", Callable(), 0)
	var tw2 = create_tween()
	tw2.tween_property(flash, "energy", 0.0, 0.6)
	await tw2.finished
	flash.queue_free()


## Someone comes in at the door and walks to (x, y).
func walk_in(sheet: String, key: String, x: float, y: float) -> void:
	var from: Vector2 = spawns.get("hall", spawns.get("front", spawns.get("landing", Vector2(W / 2.0, END - 60))))
	var h = add_npc(sheet, from, "", Callable(), 3)
	npc[key] = h
	await walk_npc(h, Vector2(x, y), 150.0)


## Someone walks out of the room.
func walk_out(key: String) -> void:
	if not npc.has(key) or not is_instance_valid(npc[key]):
		return
	var to: Vector2 = spawns.get("hall", spawns.get("front", spawns.get("landing", Vector2(W / 2.0, END - 60))))
	await walk_npc(npc[key], to, 170.0)
	if is_instance_valid(npc[key]):
		npc[key].queue_free()
	npc.erase(key)


## Someone is simply gone: stepped through the world (or out of the scene).
func vanish(key: String) -> void:
	if not npc.has(key) or not is_instance_valid(npc[key]):
		return
	var h: Node2D = npc[key]
	var tw = create_tween()
	tw.tween_property(h, "modulate", Color(0.2, 0.15, 0.3, 0.0), 0.5)
	await tw.finished
	h.queue_free()
	npc.erase(key)


## Puts someone at a spot, facing a way (0 down, 1 left, 2 right, 3 up).
func put_npc(key: String, x: float, y: float, facing := 0) -> void:
	if npc.has(key) and is_instance_valid(npc[key]):
		npc[key].position = Vector2(x, y)
		npc[key].set_meta("facing", facing)


## Someone crosses the room to a spot.
func npc_walk(key: String, x: float, y: float) -> void:
	if npc.has(key) and is_instance_valid(npc[key]):
		await walk_npc(npc[key], Vector2(x, y), 140.0)


## Puts Feyre at a named spot (behind the curtains, by the bed...).
func put_feyre(x: float, y: float, facing := 0) -> void:
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO
	player.facing = facing


# ------------------------------------------------ the sack (Ch 31 and 32)
## The entrance hall after the attack: the same bones, everything broken.
func _hall_wreck() -> void:
	_piece("props/staircase.png", Vector2(780, 398), Vector2(200, 170), false, "stairs")
	add_interactable(Vector2(780, 424), "Up the stairs", func(): await _go_door("landing"), 70, "Stairs")
	spawns.landing = Vector2(780, 452)
	spawns.stairs = spawns.landing
	# torn hangings and blown-out windows along the back wall
	_flat_tex("props/wreck_tapestry.png", Vector2(340, 86), 1)
	_wreck_window(470)
	_flat_tex("props/wreck_tapestry.png", Vector2(612, 86), 1, true)
	_flat_tex("props/wreck_tapestry.png", Vector2(948, 86), 1)
	_wreck_window(1090)
	_flat_tex("props/wreck_tapestry.png", Vector2(1220, 86), 1, true)
	_piece("props/wreck_clock.png", Vector2(1350, 252), Vector2(84, 22))
	_piece("props/palm.png", Vector2(86, 214), Vector2(40, 18))
	_piece("props/bench_marble.png", Vector2(1220, 238), Vector2(60, 16), true)
	# the chandeliers where they fell, a statue in pieces, a smashed vase
	_piece("props/wreck_chandelier.png", Vector2(560, 470), Vector2(46, 16))
	_piece("props/wreck_chandelier.png", Vector2(1020, 500), Vector2(46, 16), true)
	_piece("props/wreck_statue.png", Vector2(250, 610), Vector2(96, 28))
	_piece("props/wreck_vase.png", Vector2(700, 560), Vector2(20, 8))
	_piece("props/wreck_chair.png", Vector2(1210, 480), Vector2(30, 12), true)
	_piece("props/wreck_door.png", Vector2(1440, 640), Vector2(60, 20), true)
	_rug(Vector2(780, 546))
	_gore(31, true)
	# boot prints: in at the front, out through the back, everywhere between
	_print_trail(Vector2(780, 640), Vector2(80, 470), 7)
	_print_trail(Vector2(760, 640), Vector2(780, 470), 8)
	_print_trail(Vector2(190, WALL_H + 30), Vector2(700, 600), 9)
	_print_trail(Vector2(1300, 620), Vector2(190, WALL_H + 40), 10)
	if GameState.chapter == 32:
		_clues()


## The dining room: the table in pieces, the windows smashed, and no blood.
func _dining_wreck() -> void:
	_piece("props/fireplace.png", Vector2(190, WALL_H + 24), Vector2(100, 30), false, "hearth")
	_wreck_window(480)
	_flat_tex("props/wreck_tapestry.png", Vector2(630, 86), 1)
	_wreck_window(780)
	_painting(5, 1000)
	_piece("props/palm.png", Vector2(1150, 204), Vector2(40, 18), true)
	_piece("props/dresser.png", Vector2(900, 198), Vector2(80, 20))
	_piece("props/wreck_table.png", Vector2(630, 450), Vector2(150, 50))
	_piece("props/wreck_chair.png", Vector2(460, 396), Vector2(30, 12))
	_piece("props/wreck_chair.png", Vector2(830, 484), Vector2(30, 12), true)
	_piece("props/wreck_chair.png", Vector2(540, 566), Vector2(30, 12))
	_piece("props/wreck_vase.png", Vector2(1010, 236), Vector2(20, 8))
	_piece("props/harp.png", Vector2(1120, 330), Vector2(40, 16), true)
	_gore(32, false)
	# two sets of large prints, side by side, from where the table stood to the door
	_print_trail(Vector2(610, 500), Vector2(W - 70, 474), 11, 1.25)
	_print_trail(Vector2(650, 512), Vector2(W - 70, 490), 12, 1.25)
	for i in 5:
		_print_trail(Vector2(W - 70, 440 + i * 22), Vector2(W - 260 + i * 30, 380 + i * 40), 20 + i)
	spawns.seat = Vector2(760, 520)
	spawns.hide = Vector2(W - BAND - 50, 352)
	if GameState.chapter == 32 and not GameState.has_flag("ch32_prints"):
		add_interactable(Vector2(860, 500), "The prints in the glass", func(): await Dialogue.play("ch32_prints"), 80, "Prints")
	if GameState.chapter == 32 and GameState.has_flag("ch32_prints") and not GameState.has_flag("ch32_hide"):
		add_interactable(spawns.hide, "Hide behind the door", _hide, 80)


## Chapter 32: the burned-out kitchen, where Alis tells her the truth.
func _kitchen() -> void:
	_piece("props/wreck_hearth.png", Vector2(600, WALL_H + 26), Vector2(90, 30), false, "hearth")
	var ember = add_light(Vector2(600, WALL_H - 6), Color(1.0, 0.45, 0.2), 0.55, 1.6, false)
	add_flicker(ember, 0.3, 4.0)
	add_smoke(Vector2(600, WALL_H - 40), null, 5)
	_piece("props/wreck_shelf.png", Vector2(260, WALL_H + 24), Vector2(80, 22))
	_piece("props/wreck_shelf.png", Vector2(930, WALL_H + 24), Vector2(80, 22), true)
	_wreck_window(1080)
	_piece("props/barrels_indoor.png", Vector2(110, 560), Vector2(70, 26))
	_piece("props/buckets_indoor.png", Vector2(210, 590), Vector2(40, 14))
	_piece("props/crates_indoor.png", Vector2(1080, 560), Vector2(60, 24), true)
	_worktable = _piece("props/wreck_worktable.png", Vector2(560, 452), Vector2(130, 40))
	_scorch()
	spawns.door = Vector2(W - BAND - 56, 442)
	add_interactable(Vector2(560, 500), "The worktable", _kitchen_table, 80, "Worktable")
	add_light(Vector2(W / 2.0, 420), Color(0.9, 0.85, 0.8), 0.25, 3.5, false)


func _wreck_window(x: float) -> void:
	_flat_tex("props/wreck_window.png", Vector2(x, 90), 1)
	add_light(Vector2(x, WALL_H + 80), Color(1.0, 0.9, 0.74), 0.45, 1.5, false)


## Blood, broken glass and splinters on the floor of the sacked house.
func _gore(seed_v: int, blood: bool) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_v
	if blood:
		for i in 16:
			var c = Vector2(rng.randf_range(140, W - 140), rng.randf_range(WALL_H + 40, END - 50))
			_splat(c, rng.randf_range(10, 30), rng, Color(0.36, 0.04, 0.05, 0.82))
		# spatter up the gouged walls
		for i in 9:
			var c2 = Vector2(rng.randf_range(80, W - 80), rng.randf_range(WALL_H - 64, WALL_H - 12))
			_splat(c2, rng.randf_range(5, 12), rng, Color(0.32, 0.03, 0.04, 0.78))
	for i in 110:
		var g = Vector2(rng.randf_range(60, W - 60), rng.randf_range(WALL_H + 16, END - 22))
		var sz = rng.randf_range(2.0, 4.5)
		var chip = Polygon2D.new()
		chip.polygon = PackedVector2Array([g + Vector2(-sz, 0), g + Vector2(0, -sz * 0.6), g + Vector2(sz, 0), g + Vector2(0, sz * 0.6)])
		var wood = rng.randf() < 0.3
		chip.color = Color(0.42, 0.28, 0.18, 0.9) if wood else Color(0.86, 0.92, 1.0, rng.randf_range(0.5, 0.9))
		chip.z_index = 2
		ground.add_child(chip)


## An irregular splash, snapped to the art's pixel grid, with droplets.
func _splat(c: Vector2, r: float, rng: RandomNumberGenerator, col: Color) -> void:
	var pts = PackedVector2Array()
	var n = 11
	for i in n:
		var a = TAU * i / n
		var rr = r * rng.randf_range(0.55, 1.15)
		pts.append(((c + Vector2(cos(a), sin(a) * 0.62) * rr) / 3.0).round() * 3.0)
	var p = Polygon2D.new()
	p.polygon = pts
	p.color = col
	p.z_index = 1
	ground.add_child(p)
	for k in rng.randi_range(2, 5):
		var a2 = rng.randf() * TAU
		var d = r * rng.randf_range(1.2, 2.2)
		var q = ((c + Vector2(cos(a2), sin(a2) * 0.62) * d) / 3.0).round() * 3.0
		var dr = Polygon2D.new()
		dr.polygon = PackedVector2Array([q, q + Vector2(3, 0), q + Vector2(3, 3), q + Vector2(0, 3)])
		dr.color = col
		dr.z_index = 1
		ground.add_child(dr)


## A line of boot prints from a to b, left and right in turn.
func _print_trail(a: Vector2, b: Vector2, seed_v: int, size := 1.0) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_v
	var d = b - a
	var steps = int(d.length() / (34.0 * size))
	var side = d.normalized().orthogonal()
	for i in steps:
		var t = (i + 0.5) / float(steps)
		var p = a + d * t + side * (7.0 * size if i % 2 == 0 else -7.0 * size) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		var boot = Polygon2D.new()
		var pts = PackedVector2Array()
		for k in 8:
			var ang = TAU * k / 8.0
			pts.append(Vector2(cos(ang) * 4.5, sin(ang) * 8.0) * size)
		boot.polygon = pts
		boot.rotation = d.angle() + PI / 2.0
		boot.position = p
		boot.color = Color(0.2, 0.12, 0.1, 0.42) if rng.randf() < 0.7 else Color(0.32, 0.05, 0.05, 0.5)
		boot.z_index = 1
		ground.add_child(boot)


## Soot on the kitchen's walls and floor, ash heaped by the hearth.
func _scorch() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	for i in 10:
		var c = Vector2(rng.randf_range(80, W - 80), rng.randf_range(10, WALL_H - 10))
		_splat(c, rng.randf_range(30, 70), rng, Color(0.06, 0.05, 0.05, 0.55))
	for i in 18:
		var c2 = Vector2(rng.randf_range(80, W - 80), rng.randf_range(WALL_H + 20, END - 30))
		_splat(c2, rng.randf_range(20, 60), rng, Color(0.08, 0.07, 0.07, 0.45))
	for i in 6:
		var c3 = Vector2(600 + rng.randf_range(-120, 120), WALL_H + rng.randf_range(40, 90))
		_splat(c3, rng.randf_range(10, 22), rng, Color(0.5, 0.48, 0.46, 0.7))


## The signs left in the hall, each read once.
func _clues() -> void:
	if GameState.has_flag("ch32_clues"):
		return
	for c in CLUES:
		var flag = String(c[0])
		if GameState.has_flag(flag):
			continue
		_clue_spots[flag] = add_interactable(c[1], String(c[2]), func(): await _read_clue(flag), 70)


func _read_clue(flag: String) -> void:
	if GameState.has_flag(flag):
		return
	await Dialogue.play(flag)
	if _clue_spots.has(flag) and is_instance_valid(_clue_spots[flag]):
		_clue_spots[flag].queue_free()
	var n = 0
	for c in CLUES:
		if GameState.has_flag(String(c[0])):
			n += 1
	if n < CLUES.size():
		GameState.set_objective("Read the signs in the hall. (%d/4)" % n)
		return
	GameState.set_flag("ch32_clues")
	await Dialogue.play("ch32_clues_done")


func _hide() -> void:
	if GameState.has_flag("ch32_hide"):
		return
	put_feyre(spawns.hide.x, spawns.hide.y, 1)
	await Dialogue.play("ch32_hide")


func _kitchen_table() -> void:
	if GameState.chapter == 32 and GameState.has_flag("ch32_kitchen") and not GameState.has_flag("ch32_table"):
		await Dialogue.play("ch32_table")
		return
	UI.toast("Scorched oak, and heavy as sin.")


## region_call (Ch 32): something moving out in the hall.
func debris_crunch() -> void:
	Audio.sfx("clatter", -8.0)
	UI.shake(2.0)
	if not GameState.has_flag("ch32_hide") and spawns.has("hide"):
		add_interactable(spawns.hide, "Hide behind the door", _hide, 80)
	await get_tree().create_timer(0.4, true, false, true).timeout


## region_call (Ch 32): a cloaked figure limps in from the hall, sniffing.
func limper_enters() -> void:
	var a = add_npc("bark_servant", Vector2(W - BAND - 56, 482), "", Callable(), 1)
	npc.alis = a
	await walk_npc(a, Vector2(880, 470), 60.0)
	a.set_meta("facing", 1)
	await get_tree().create_timer(0.5, true, false, true).timeout


func limper_turns() -> void:
	if npc.has("alis") and is_instance_valid(npc.alis):
		npc.alis.set_meta("facing", 2)
	await get_tree().create_timer(0.35, true, false, true).timeout


## region_call (Ch 32): the two of them heave the worktable back onto its feet.
func right_table() -> void:
	var at = Vector2(560, 452)
	if _worktable != null and is_instance_valid(_worktable):
		at = _worktable.position
		var tw = create_tween()
		tw.tween_property(_worktable, "modulate:a", 0.0, 0.3)
		await tw.finished
		_worktable.queue_free()
	var t = _piece("props/table.png", at, Vector2(110, 36))
	t.modulate = Color(0.62, 0.52, 0.46)
	_worktable = t
	Audio.sfx("door_thud", -10.0)
	UI.shake(2.0)
	await get_tree().create_timer(0.3, true, false, true).timeout
