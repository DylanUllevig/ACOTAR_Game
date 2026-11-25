extends "res://scripts/world/regions/manor_in.gd"
## Chapters 28 to 31: inside her father's new house across the Wall. It runs on
## the manor's machinery (manor_in.gd): every chateau_* region id is a room of
## this script, the room being the part after "chateau_".
##   hall      the front hall: white and gold, the stairs, doors all round
##   ballroom  the ballroom, full for the ball in her honor (Chapter 31)
##   dining    where the family takes lunch
##   study     Father's study, its window over Elain's garden
##   studio    the morning room, where she teaches Nesta to paint (Chapter 30)
##   landing   the upstairs hall
##   bedroom   her room: a canopy bed with pale blue hangings

const C_ROOMS := {
	"hall": {"w": 1500.0, "end": 660.0, "wall": "wall_chateau", "floor": "marble", "name": "The Front Hall",
		"doors": [["s", 750.0, "out", "Out to the front steps"], ["w", 470.0, "dining", "The dining room"],
			["e", 470.0, "study", "Father's study"], ["n", 1240.0, "ballroom", "The ballroom"], ["n", 260.0, "studio", "The morning room"]]},
	"ballroom": {"w": 1900.0, "end": 760.0, "wall": "wall_chateau", "floor": "marble", "name": "The Ballroom",
		"doors": [["s", 950.0, "hall", "Out to the front hall"]]},
	"dining": {"w": 1160.0, "end": 620.0, "wall": "wall_manor_rose", "floor": "parquet", "name": "The Dining Room",
		"doors": [["e", 450.0, "hall", "The front hall"]]},
	"study": {"w": 1100.0, "end": 600.0, "wall": "wall_chateau_blue", "floor": "parquet", "name": "Father's Study",
		"doors": [["w", 450.0, "hall", "The front hall"]]},
	"studio": {"w": 1000.0, "end": 560.0, "wall": "wall_manor_rose", "floor": "planks", "name": "The Morning Room",
		"doors": [["s", 500.0, "hall", "The front hall"]]},
	"landing": {"w": 1300.0, "end": 460.0, "wall": "wall_chateau", "floor": "parquet", "name": "The Upstairs Hall",
		"doors": [["w", 330.0, "hall", "Down the stairs"], ["n", 760.0, "bedroom", "Your room"]]},
	"bedroom": {"w": 1140.0, "end": 640.0, "wall": "wall_chateau_blue", "floor": "parquet", "name": "Your Room",
		"doors": [["s", 570.0, "landing", "Out to the upstairs hall"]]},
}

## [room, chapter, flag that must be set, flag that must not be, scene]: see
## manor_in.gd's BEATS.
const C_BEATS := [
	["hall", 28, "ch28_arrived", "ch28_father", "ch28_father"],
	["bedroom", 28, "ch28_father", "ch28_room", "ch28_room"],
	["study", 29, "ch29_elain", "ch29_study", "ch29_study"],
	["studio", 30, "", "ch30_lesson", "ch30_lesson"],
	["landing", 30, "ch30_lessons_done", "ch30_landing", "ch30_landing"],
	["bedroom", 30, "ch30_landing", "ch30_dress", "ch30_dress"],
	["ballroom", 31, "", "ch31_ball", "ch31_ball"],
	["dining", 31, "ch31_late", "ch31_lunch", "ch31_lunch"],
	["bedroom", 31, "ch31_lunch", "ch31_change", "ch31_change"],
]

const BALL_C := Vector2(980, 520)          # the middle of the dance floor
var _dancers: Array = []                   # [a, b, phase, radius]
var _ball_t := 0.0


func rooms() -> Dictionary:
	return C_ROOMS


func beats() -> Array:
	return C_BEATS


func prefix() -> String:
	return "chateau_"


func outside() -> Array:
	return ["chateau", "door"]


func house_name() -> String:
	return "Father's House"


func _wrecked() -> bool:
	return false


func _build_room() -> void:
	match room:
		"hall": _c_hall()
		"ballroom": _c_ballroom()
		"dining": _c_dining()
		"study": _c_study()
		"studio": _c_studio()
		"landing": _c_landing()
		"bedroom": _c_bedroom()


func _audio() -> void:
	var night = _night()
	if room == "ballroom" and GameState.chapter == 31:
		Audio.ambience("hearth")
		Audio.music("ball", 2.0)
		return
	Audio.ambience("hearth" if night else "spring_day")
	Audio.music("chateau", 3.0)


## A bright summer house: white walls, tall windows, and the ballroom lit
## like day by its chandeliers.
func grade_for_hour(h: float) -> Dictionary:
	var n = Region.night_amount(h)
	if room == "ballroom":
		return {"mod": Color(0.95, 0.92, 0.86).lerp(Color(0.8, 0.72, 0.66), n), "sun": Color.WHITE, "sun_energy": 0.0, "rays": 0.0}
	return {"mod": Color(0.95, 0.94, 0.9).lerp(Color(0.46, 0.44, 0.58), n), "sun": Color.WHITE, "sun_energy": 0.0, "rays": 0.0}


## From the end of the painting lessons the house is dressed for the ball.
func _dressed() -> bool:
	return (GameState.chapter == 30 and GameState.has_flag("ch30_lessons_done")) or GameState.chapter == 31


# ------------------------------------------------------------------ doors
func _door_shut(to: String) -> String:
	var ch = GameState.chapter
	match ch:
		28:
			if to == "out":
				return "Not now. " + String(GameState.objective)
			if to != "landing" and to != "hall" and to != "bedroom":
				return "Later. I could barely keep my eyes open."
		29:
			match to:
				"ballroom":
					return "Shut up under dust sheets until Father's ball."
				"studio":
					return "The morning room, full of light. Elain had put an easel in there for me. I couldn't face it."
				"dining":
					return "Lunch was hours away yet."
				"out":
					if GameState.has_flag("ch29_elain") and not GameState.has_flag("ch29_study"):
						return "Father first. " + String(GameState.objective)
		30:
			if not GameState.has_flag("ch30_lessons_done"):
				return "Nesta was waiting at her easel."
			if to in ["out", "dining", "study", "ballroom", "studio"]:
				return "Not now. I had to dress for the ball."
		31:
			if to == "out" and not GameState.has_flag("ch31_change"):
				return "Not now. " + String(GameState.objective)
			if to in ["study", "studio", "ballroom"]:
				return "No time. Not now."
			if to == "dining" and GameState.has_flag("ch31_lunch"):
				return "No time. Not now."
	return ""


func _go_door(to: String) -> void:
	# the ball: she can't slip away until she's found Nesta
	if room == "ballroom" and to == "hall" and GameState.chapter == 31 and not GameState.has_flag("ch31_late"):
		await Dialogue.play("ch31_late" if GameState.has_flag("ch31_suitor") else "ch31_not_yet")
		return
	await super._go_door(to)


func _pending_here_or_inside() -> bool:
	return false


# ------------------------------------------------------------------ rooms
## A chandelier hanging over the floor: drawn high above its spot, lit.
func _hanging(pos: Vector2, lift := 220.0) -> void:
	var h = add_prop("props/chandelier.png", pos, 1.0, Vector2.ZERO, Vector2.ZERO)
	for c in h.get_children():
		if c is Sprite2D:
			c.position.y = -lift
	add_light(pos + Vector2(0, -lift - 20), Color(1.0, 0.86, 0.6), 0.7, 2.2, false)
	var l2 = add_light(pos + Vector2(0, -60), Color(1.0, 0.84, 0.58), 0.35, 3.0, false)
	add_flicker(l2, 0.05, 3.0)


func _garland(pos: Vector2) -> void:
	add_prop("props/flower_arch.png", pos, 1.0, Vector2.ZERO, Vector2.ZERO)


func _c_hall() -> void:
	_piece("props/staircase.png", Vector2(750, 398), Vector2(200, 170), false, "stairs")
	add_interactable(Vector2(750, 424), "Up the stairs", func(): await _go_door("landing"), 70, "Stairs")
	spawns.landing = Vector2(750, 452)
	spawns.stairs = spawns.landing
	_window(470)
	_window(1030)
	_painting(4, 600)
	_painting(1, 900, true)
	_flat_tex("props/chandelier.png", Vector2(750, 46), 2)
	add_light(Vector2(750, 120), Color(1.0, 0.88, 0.62), 0.45, 2.0, false)
	_piece("props/vase_pedestal.png", Vector2(612, 384), Vector2(36, 16))
	_piece("props/vase_pedestal.png", Vector2(888, 384), Vector2(36, 16), true)
	_piece("props/grandfather_clock.png", Vector2(1390, 186), Vector2(40, 16))
	_piece("props/mirror_gilded.png", Vector2(1110, 200), Vector2(40, 14))
	_piece("props/palm.png", Vector2(84, 214), Vector2(40, 18))
	_piece("props/bench_marble.png", Vector2(400, 238), Vector2(60, 16))
	for y in [480.0, 546.0, 612.0]:
		_rug(Vector2(750, y))
	_piece("props/orange_tree.png", Vector2(300, 620), Vector2(46, 18))
	_piece("props/orange_tree.png", Vector2(1200, 620), Vector2(46, 18), true)
	_candles(Vector2(540, 580))
	_candles(Vector2(960, 580))
	if _dressed():
		# garlands of every flower there is, wound round every archway
		_garland(Vector2(260, WALL_H + 8))
		_garland(Vector2(1240, WALL_H + 8))
		_piece("props/vase_pedestal.png", Vector2(160, 560), Vector2(36, 16))
		_piece("props/vase_pedestal.png", Vector2(1340, 560), Vector2(36, 16), true)
		_piece("props/vase_pedestal.png", Vector2(560, 400), Vector2(36, 16))
		_piece("props/vase_pedestal.png", Vector2(940, 400), Vector2(36, 16), true)


func _c_ballroom() -> void:
	for x in [300.0, 640.0, 1320.0, 1660.0]:
		_window(x)
	_garland(Vector2(980, WALL_H + 8))
	_painting(0, 470)
	_painting(2, 1490, true)
	_piece("props/pianoforte.png", Vector2(300, 262), Vector2(100, 30))
	_piece("props/harp.png", Vector2(460, 262), Vector2(40, 16))
	_piece("props/banquet_table.png", Vector2(1560, 300), Vector2(170, 46))
	for y in [330.0, 430.0, 530.0, 630.0]:
		_piece("props/chair_gilded.png", Vector2(76, y), Vector2(26, 12))
		_piece("props/chair_gilded.png", Vector2(W - 76, y), Vector2(26, 12), true)
	for p in [Vector2(150, 230), Vector2(W - 150, 230), Vector2(150, 700), Vector2(W - 150, 700)]:
		_piece("props/vase_pedestal.png", p, Vector2(36, 16), p.x > W / 2.0)
	for p in [Vector2(820, 236), Vector2(1140, 236)]:
		_candles(p)
	for x in [560.0, 980.0, 1400.0]:
		_hanging(Vector2(x, 470))
	spawns.floor = Vector2(980, 690)
	# a soft wash of candlelight over the whole floor
	add_light(BALL_C, Color(1.0, 0.86, 0.66), 0.4, 6.0, false)


func _c_dining() -> void:
	_fireplace(190)
	_window(470)
	_window(690)
	_painting(5, 900)
	_piece("props/dresser.png", Vector2(1010, 198), Vector2(80, 20))
	_piece("props/palm.png", Vector2(1100, 212), Vector2(40, 18), true)
	_carpet("dining", Vector2(580, 410))
	# the long table: three lengths end to end, a carved chair at either end
	for x in [450.0, 580.0, 710.0]:
		add_prop("props/dining_table.png", Vector2(x, 444), 1.0, Vector2.ZERO, Vector2.ZERO)
	var r = Rect2(382, 336, 396, 104)
	add_wall(r)
	map_marks.append(["furniture", r.get_center(), r])
	_piece("props/chair_carved.png", Vector2(354, 430), Vector2(30, 14))
	_piece("props/chair_carved.png", Vector2(806, 430), Vector2(30, 14), true)
	# a tea table by the window for the ladies, and the painted screen
	_piece("props/lunch_table.png", Vector2(160, 560), Vector2(90, 34))
	_piece("props/screen_painted.png", Vector2(1060, 596), Vector2(80, 20), true)
	_piece("props/vase_pedestal.png", Vector2(930, 590), Vector2(36, 16), true)
	_candles(Vector2(340, 600))
	spawns.lunch = Vector2(840, 470)


func _c_study() -> void:
	for x in [110.0, 200.0, 900.0, 990.0]:
		_piece("props/bookcase.png", Vector2(x, 188), Vector2(84, 22), x > 500.0, "books" if x == 110.0 else "")
	_window(550)
	add_interactable(Vector2(550, 214), "The window", func(): await Dialogue.play("home_study_window"), 70, "Window")
	_carpet("desk", Vector2(550, 450))
	_piece("props/desk_gems.png", Vector2(550, 452), Vector2(110, 40), false, "desk")
	_piece("props/armchair.png", Vector2(780, 470), Vector2(50, 16), true)
	_piece("props/grandfather_clock.png", Vector2(330, 188), Vector2(36, 16))
	_piece("props/palm.png", Vector2(1040, 540), Vector2(40, 18), true)
	_candles(Vector2(300, 520))
	spawns.desk = Vector2(550, 520)


func _c_studio() -> void:
	_window(300)
	_window(700)
	_painting(4, 500)
	_piece("props/easel_paints.png", Vector2(360, 372), Vector2(100, 24), false, "easel")
	_piece("props/easel_paints.png", Vector2(660, 372), Vector2(100, 24), true)
	_piece("props/chaise.png", Vector2(840, 480), Vector2(100, 24), true)
	_piece("props/vase_pedestal.png", Vector2(110, 230), Vector2(36, 16))
	_piece("props/palm.png", Vector2(930, 210), Vector2(40, 18), true)
	_piece("props/stool.png", Vector2(300, 430), Vector2(22, 12))
	_carpet("studio", Vector2(500, 440))
	add_interactable(Vector2(360, 410), "Your easel", _easel, 70, "Easel")
	spawns.easel = Vector2(380, 450)


func _c_landing() -> void:
	_painting(2, 200)
	_window(560)
	_painting(0, 1000, true)
	_piece("props/vase_pedestal.png", Vector2(450, 200), Vector2(36, 16))
	_piece("props/mirror_gilded.png", Vector2(1150, 200), Vector2(40, 14))
	_piece("props/bench_marble.png", Vector2(900, 214), Vector2(60, 16))
	_piece("props/palm.png", Vector2(1240, 220), Vector2(40, 18), true)
	_carpet("landing", Vector2(700, 330))
	if _dressed():
		_piece("props/vase_pedestal.png", Vector2(640, 200), Vector2(36, 16), true)


func _c_bedroom() -> void:
	_fireplace(250)
	_piece("props/armchair.png", Vector2(372, 330), Vector2(50, 16), true)
	_piece("props/wardrobe_white.png", Vector2(470, 198), Vector2(84, 24), false, "wardrobe")
	_window(640)
	_window(780)
	add_interactable(Vector2(710, 214), "The window", func(): await Dialogue.play("home_window"), 70, "Window")
	spawns.window = Vector2(710, 250)
	_piece("props/bed_white.png", Vector2(940, 340), Vector2(100, 110), false, "bed")
	add_interactable(Vector2(940, 364), "The bed", _bed, 64, "Bed")
	spawns.bed = Vector2(940, 392)
	_piece("props/vanity.png", Vector2(1066, 198), Vector2(84, 22), true, "vanity")
	_piece("props/mirror_gilded.png", Vector2(120, 470), Vector2(40, 14))
	_carpet("bedroom", Vector2(600, 430))
	_piece("props/washstand.png", Vector2(72, 300), Vector2(40, 16))
	_piece("props/chaise.png", Vector2(720, 560), Vector2(100, 24))
	_candles(Vector2(860, 590))
	_piece("props/vase_pedestal.png", Vector2(1080, 600), Vector2(36, 16), true)


# ------------------------------------------------------------------ people
func _people() -> void:
	var ch = GameState.chapter
	var beat = _beat()
	match room:
		"hall":
			if ch == 28 and beat == "ch28_father":
				npc.father = add_npc("father_rich", Vector2(750, 500), "", Callable(), 0)
				npc.elain = add_npc("elain_rich", Vector2(600, 560), "", Callable(), 2)
			elif ch == 29:
				add_npc("maid", Vector2(1150, 560), "", Callable(), 1)
				add_npc("footman", Vector2(870, 600), "", Callable(), 3)
			elif ch == 30 and _dressed():
				var m = add_npc("maid", Vector2(400, 560), "", Callable(), 2)
				_stroll(m, Vector2(1100, 560), 70.0)
				add_npc("footman", Vector2(1150, 330), "", Callable(), 0)
			elif ch == 31:
				add_npc("footman", Vector2(870, 600), "", Callable(), 3)
		"study":
			if ch == 29:
				npc.father = add_npc("father_rich", Vector2(550, 390), "Father", _father, 0)
		"studio":
			if ch == 30:
				npc.nesta = add_npc("nesta_rich", Vector2(660, 430), "Nesta", func(): await Dialogue.play("home_nesta"), 3)
		"landing":
			if beat == "ch30_landing":
				npc.nesta = add_npc("nesta_rich", Vector2(480, 380), "", Callable(), 2)
		"bedroom":
			if beat == "ch30_dress":
				npc.maid = add_npc("maid", Vector2(560, 440), "", Callable(), 1)
			elif beat == "ch31_change":
				npc.nesta = add_npc("nesta_rich", Vector2(560, 440), "", Callable(), 1)
		"dining":
			if ch == 31 and beat == "ch31_lunch":
				npc.father = add_npc("father_rich", Vector2(322, 470), "", Callable(), 2)
				npc.nesta = add_npc("nesta_rich", Vector2(520, 306), "", Callable(), 0)
				npc.elain = add_npc("elain_rich", Vector2(650, 306), "", Callable(), 0)
		"ballroom":
			if ch == 31:
				_ball_people()


## Someone walking to and fro across the room, all day long.
func _stroll(h: Node2D, to: Vector2, speed: float) -> void:
	var from = h.position
	var t = from.distance_to(to) / speed
	var tw = h.create_tween().set_loops()
	tw.tween_interval(2.0)
	tw.tween_property(h, "position", to, t)
	tw.tween_interval(3.0)
	tw.tween_property(h, "position", from, t)


func _ball_people() -> void:
	# the dancers: couples turning slowly round the floor, Elain among them
	for i in 5:
		var a: Node2D
		if i == 0:
			a = add_npc("elain_gown", BALL_C, "Elain", func(): await Dialogue.play("ch31_elain_ball"), 0)
		else:
			a = add_npc("guest_lady", BALL_C, "", Callable(), 0)
		var b = add_npc("guest_gent", BALL_C, "", Callable(), 0)
		_dancers.append([a, b, TAU * i / 5.0, 200.0 + (i % 2) * 60.0])
	# Nesta by the windows, keeping the wolves at bay
	npc.nesta = add_npc("nesta_rich", Vector2(640, 300), "Nesta", _ball_nesta, 0)
	# Father holding court with his merchants by the banquet table
	npc.father = add_npc("father_rich", Vector2(1500, 420), "Father", func(): await Dialogue.play("ch31_father_ball"), 1)
	add_npc("guest_gent", Vector2(1420, 400), "", Callable(), 2)
	add_npc("guest_gent", Vector2(1430, 470), "", Callable(), 2)
	# two guests behind their fans, by the pianoforte
	add_npc("guest_lady", Vector2(420, 360), "Guests", func(): await Dialogue.play("ch31_guests"), 2)
	add_npc("guest_gent", Vector2(500, 380), "", Callable(), 1)
	add_npc("guest_gent", Vector2(300, 320), "", Callable(), 0)    # at the keys
	for x in [830.0, 1130.0]:
		add_npc("footman", Vector2(x, 700), "", Callable(), 3)
	_place_dancers(0.0)


func _ball_nesta() -> void:
	if not GameState.has_flag("ch31_suitor"):
		await Dialogue.play("ch31_suitor")
	else:
		await Dialogue.play("home_nesta")


func _place_dancers(t: float) -> void:
	for d in _dancers:
		if not (is_instance_valid(d[0]) and is_instance_valid(d[1])):
			continue
		# each couple circles the floor, and turns about itself as it goes
		var ang = float(d[2]) + t * 0.16
		var c = BALL_C + Vector2(cos(ang) * float(d[3]) * 1.5, sin(ang) * float(d[3]) * 0.55)
		var spin = t * 1.7 + float(d[2])
		var off = Vector2(cos(spin), sin(spin) * 0.5) * 20.0
		d[0].position = c + off
		d[1].position = c - off


func _process(delta: float) -> void:
	super._process(delta)
	if _dancers.is_empty():
		return
	# the music doesn't stop for a scene
	_ball_t += delta
	_place_dancers(_ball_t)


# ------------------------------------------------------------------ things
func _father() -> void:
	if GameState.chapter == 29 and not GameState.has_flag("ch29_study"):
		await Dialogue.play("home_father_busy")
		return
	await Dialogue.play("home_father")


## The lessons in the morning room (Chapter 30): one a day, three days.
func _easel() -> void:
	if GameState.chapter != 30 or GameState.has_flag("ch30_lessons_done"):
		await Dialogue.play("home_paint")
		return
	var n = 1
	if GameState.has_flag("ch30_l1"):
		n = 2
	if GameState.has_flag("ch30_l2"):
		n = 3
	if n < 3:
		GameState.set_flag("ch30_l%d" % n)
	await Dialogue.play("ch30_lesson_%d" % n)
	if n < 3:
		GameState.set_objective("Show Nesta how to paint. (%d/3)" % n)


func _bed() -> void:
	if GameState.chapter == 28 and GameState.has_flag("ch28_room"):
		await Dialogue.play("ch28_sleep")
		return
	await Dialogue.play("home_bed")
