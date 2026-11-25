extends Region
## Chapters 6 to 27: the grounds of the Spring Court manor. The house stands
## at the top of the lawns, veiled in roses and ivy, a terrace before it and a
## gravel drive running south to the iron gate in the hedge where Feyre first
## arrives. West of the drive lies the formal rose garden (a fountain in a ring
## of gravel, beds of roses, statues, hedges and topiary); east, the reflecting
## pool under the blossom trees, the iris beds round the heron fountain and the
## stable yard. Past the birches on the west edge, the woods.
##
## What happens here depends on the chapter: see _story() and on_enter().
## Chapter 28: a gilded carriage at the steps, and goodbye. Chapter 31: she
## comes back to silent grounds, bent gates and a door torn off its hinge.

const Attor := preload("res://scripts/world/regions/attor_watch.gd")

const MANOR := Vector2(2200, 900)          # foot of the front steps
const DOOR := Vector2(2200, 925)
const GATE := Vector2(2200, 3250)
const RG := Vector2(1000, 1760)            # the rose garden's fountain
const POOL := Vector2(3380, 1760)          # the reflecting pool
const HERON := Vector2(2900, 2440)         # the heron fountain among the irises
const STABLES := Vector2(3800, 1160)
const WOODS_Y := 2000.0                     # where the path leaves for the woods (west edge)
const HILL := Vector2(3100, 420)           # the rise behind the east wing, for the dawn
## The open lawn south of the pool, where Midsummer is danced: no trees stand
## on it, so no crown hides the ring, the maypole or the bonfire.
const LAWN := Rect2(2580, 2190, 1670, 890)
## The wide meadow south of the rose garden, where the will-o'-the-wisps come
## out at Midsummer: long grass and wildflowers, no trees.
const MEADOW := Rect2(480, 2420, 1400, 660)

var npc := {}
var cover: Array = []                       # Rect2s behind the north hedges, where she hides in Ch 19
var _attor: Node = null
var _solstice := false
var _wisps: Array = []
var _carriage: Node2D = null                  # Ch 28: the carriage at the steps
const CARRIAGE_AT := Vector2(1960, 1236)


## Chapters 31 and 32: the court is gone, the house sacked.
func _empty() -> bool:
	return GameState.chapter == 31 or GameState.chapter == 32


func build() -> void:
	surface = "grass"
	# Chapter 11: the thing at the gates is a fight
	combat_allowed = GameState.chapter == 11 and not GameState.has_flag("ch11_puca_done")
	map_title = "The Spring Court Manor"
	map_base = Color(0.72, 0.82, 0.6)
	bounds = Rect2(0, 0, 4400, 3320)
	spawns = {
		"start": GATE + Vector2(0, -190), "gate": GATE + Vector2(0, -190),
		"door": DOOR + Vector2(0, 80), "woods": Vector2(130, WOODS_Y),
		"stables": STABLES + Vector2(-220, 140), "below_window": Vector2(1760, 1010),
		"garden": RG + Vector2(0, 300), "pool": POOL + Vector2(0, 330), "heron": HERON + Vector2(0, 170),
		"hill": HILL + Vector2(0, 60), "meadow": MEADOW.get_center() + Vector2(-60, 30),
	}
	_solstice = GameState.chapter == 25 and not GameState.has_flag("ch25_dawn")
	pixel_ground(["lawn", "meadow", "forest_floor", "gravel", "terrace", "water"], 31)
	_ground()
	enclose_bounds()
	add_sun(-35.0, Color(1.0, 0.96, 0.86), 0.5)
	_manor()
	_drive()
	_rose_garden()
	_pool()
	_heron()
	_stables()
	_borders()
	_trees()
	_flowers()
	if not _empty():
		_critters()
	if _solstice:
		_solstice_dressing()
	terrain.build()
	add_rays(Color(1.0, 0.95, 0.8), 0.14, -0.3)
	set_post({"vignette": 0.26, "lift": Vector3(0.012, 0.012, 0.02), "gain": Vector3(1.0, 1.0, 0.99), "saturation": 1.08, "grain": 0.0})


func _ready() -> void:
	super._ready()
	# a soft fill that follows Feyre, so she reads at night
	add_light(Vector2(0, -30), Color(0.75, 0.8, 1.0), 0.3, 2.6, false, player)
	map_exit(Vector2(60, WOODS_Y), "The woods")
	map_exit(GATE, "The gate")
	_story()
	var night = Region.night_amount(GameState.hour) > 0.5
	if _empty():
		# no birdsong, no servants, no music from the house: wind in the hedges
		Audio.ambience("forest_wind")
		Audio.music("wreck", 4.0)
		set_post({"vignette": 0.34, "lift": Vector3(0.01, 0.01, 0.02), "gain": Vector3(0.98, 0.98, 1.0), "saturation": 0.82, "grain": 0.0})
		return
	Audio.ambience("spring_night" if night else "spring_day")
	Audio.music("solstice" if _solstice else ("spring_night" if night else "spring_manor"), 3.0)


## The sun swings over the house from the south-east to the south-west:
## shadows fall north, long in the morning and evening.
func sun_shadow(h: float) -> Vector4:
	var a = deg_to_rad(lerpf(-60.0, 60.0, clampf((h - 6.5) / 13.0, 0.0, 1.0)))
	var length = 0.4 + 0.7 * (1.0 - sin(clampf((h - 6.5) / 13.0, 0.0, 1.0) * PI))
	var alpha = 0.28 * smoothstep(6.0, 7.5, h) * (1.0 - smoothstep(19.0, 20.0, h))
	return Vector4(sin(a), -cos(a), length, alpha)


## Spring light: a clear, warm day, honey-gold evenings, and a blue night
## that stays easy to read.
func grade_for_hour(h: float) -> Dictionary:
	return Region.lerp_grade([
		[4.5, {"mod": Color(0.25, 0.28, 0.46), "sun": Color(0.45, 0.5, 0.8), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
		[6.0, {"mod": Color(0.46, 0.42, 0.52), "sun": Color(1.0, 0.7, 0.55), "sun_energy": 0.3, "rays": 0.18, "exposure": Color(1.0, 0.97, 0.97)}],
		[8.0, {"mod": Color(0.64, 0.64, 0.66), "sun": Color(1.0, 0.92, 0.78), "sun_energy": 0.45, "rays": 0.14, "exposure": Color(0.99, 0.98, 0.97)}],
		[13.0, {"mod": Color(0.7, 0.71, 0.7), "sun": Color(1.0, 0.97, 0.88), "sun_energy": 0.45, "rays": 0.12, "exposure": Color(0.98, 0.98, 0.97)}],
		[17.0, {"mod": Color(0.66, 0.62, 0.6), "sun": Color(1.0, 0.86, 0.64), "sun_energy": 0.52, "rays": 0.2, "exposure": Color(0.99, 0.97, 0.95)}],
		[19.2, {"mod": Color(0.5, 0.42, 0.48), "sun": Color(1.0, 0.66, 0.45), "sun_energy": 0.45, "rays": 0.24, "exposure": Color(1.0, 0.96, 0.95)}],
		[20.6, {"mod": Color(0.3, 0.31, 0.5), "sun": Color(0.55, 0.55, 0.85), "sun_energy": 0.08, "rays": 0.02, "exposure": Color(1.0, 1.0, 1.04)}],
		[22.0, {"mod": Color(0.25, 0.28, 0.46), "sun": Color(0.45, 0.5, 0.8), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
	], h)


# ------------------------------------------------------------------ layout
func _drive_pts() -> PackedVector2Array:
	return PackedVector2Array([MANOR + Vector2(0, 200), Vector2(2200, 1500), Vector2(2190, 2200), Vector2(2205, 2800), Vector2(2200, 3420)])


func _woods_pts() -> PackedVector2Array:
	return PackedVector2Array([RG + Vector2(-560, 0), Vector2(300, RG.y + 120), Vector2(-140, WOODS_Y)])


func _ground() -> void:
	# wild meadow beyond the lawns; woodland floor under the trees at the edges
	terrain.paint_rect("meadow", Rect2(-200, 2560, 4800, 1000), 70.0)
	terrain.paint_rect("meadow", Rect2(4000, -200, 700, 3800), 60.0)
	terrain.paint_rect("forest_floor", Rect2(-200, -200, 470, 3800), 60.0)
	terrain.paint_rect("forest_floor", Rect2(-200, -200, 4800, 320), 50.0)
	# the terrace before the house
	terrain.paint_rect("terrace", Rect2(MANOR.x - 660, MANOR.y - 40, 1320, 240), 0.0)
	# gravel: the drive, and the walks to the gardens, the pool, the irises and the stables
	terrain.paint_path("gravel", _drive_pts(), 150.0, 8.0)
	terrain.paint_path("gravel", PackedVector2Array([RG + Vector2(560, 0), Vector2(1800, RG.y + 4), Vector2(MANOR.x, RG.y)]), 104.0, 6.0)
	terrain.paint_path("gravel", PackedVector2Array([Vector2(MANOR.x, POOL.y), Vector2(2700, POOL.y - 6), POOL + Vector2(-470, 0)]), 104.0, 6.0)
	terrain.paint_path("gravel", PackedVector2Array([MANOR + Vector2(660, 90), Vector2(3300, 1040), STABLES + Vector2(-140, 120)]), 96.0, 6.0)
	terrain.paint_path("gravel", PackedVector2Array([Vector2(MANOR.x, HERON.y), Vector2(2560, HERON.y + 6), HERON + Vector2(-150, 0)]), 96.0, 6.0)
	terrain.paint_path("gravel", _woods_pts(), 96.0, 10.0)
	# the rose garden: a ring of gravel round a lawn, the cross paths, paving at the fountain
	terrain.paint_ellipse("gravel", RG, Vector2(340, 250), 0.0)
	terrain.paint_ellipse("lawn", RG, Vector2(250, 165), 0.0)
	terrain.paint_path("gravel", PackedVector2Array([RG + Vector2(-560, 0), RG + Vector2(560, 0)]), 100.0)
	terrain.paint_path("gravel", PackedVector2Array([RG + Vector2(0, -520), RG + Vector2(0, 520)]), 100.0)
	terrain.paint_circle("terrace", RG, 150.0)
	# paving round the pool and the heron
	terrain.paint_ellipse("terrace", POOL, Vector2(480, 290), 0.0)
	terrain.paint_circle("terrace", HERON, 150.0)
	var gravel_c = Color(0.8, 0.74, 0.6)
	map_line(Region.smooth_curve(_drive_pts(), 20.0), gravel_c, 90.0)
	map_line(Region.smooth_curve(_woods_pts(), 20.0), gravel_c, 60.0)
	map_line(PackedVector2Array([RG + Vector2(560, 0), Vector2(MANOR.x, RG.y)]), gravel_c, 60.0)
	map_line(PackedVector2Array([Vector2(MANOR.x, POOL.y), POOL + Vector2(-470, 0)]), gravel_c, 60.0)
	map_line(PackedVector2Array([MANOR + Vector2(660, 90), Vector2(3300, 1040), STABLES + Vector2(-140, 120)]), gravel_c, 56.0)
	map_shapes.append({"type": "poly", "pts": _ellipse_pts(RG, Vector2(340, 250)), "color": gravel_c})
	map_rect(Rect2(MANOR.x - 660, MANOR.y - 40, 1320, 240), Color(0.86, 0.82, 0.74))


static func _ellipse_pts(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in 24:
		var a = TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _lamp(pos: Vector2) -> void:
	add_prop("props/garden_lamp.png", pos, 1.0, Vector2(10, 4), Vector2(18, 12))
	add_glow_lights("props/garden_lamp.png", pos, Color(1.0, 0.8, 0.5), 0.75, 0.75, false, 40.0, null, 0.04)


func _manor() -> void:
	var rel = "props/manor.png"
	add_prop(rel, MANOR, 1.0, Vector2(300, 40), Vector2.ZERO)
	# solid from the foot of the steps back: nothing behind the house is reachable
	add_wall(Rect2(MANOR.x - 528, -200, 1056, MANOR.y - 8 + 200))
	add_glow_lights(rel, MANOR, Color(1.0, 0.76, 0.44), 0.5, 0.55, false, 40.0, null, 0.06)
	map_rect(Rect2(MANOR.x - 528, MANOR.y - 330, 1056, 330), Color(0.95, 0.92, 0.86))
	add_interactable(DOOR, "Go inside", _go_inside, 110, "Front doors")
	for x in [-570, 570]:
		add_prop("props/urn.png", MANOR + Vector2(x, 160), 1.0, Vector2(30, 10), Vector2(60, 26))
	for x in [-330, 330]:
		_lamp(MANOR + Vector2(x, 180))
	for x in [-640, 640]:
		add_prop("props/rose_pink.png", MANOR + Vector2(x, 70), 1.0, Vector2(40, 12), Vector2(80, 26), x > 0)


func _drive() -> void:
	for y in [1300, 1800, 2300, 2800]:
		_lamp(Vector2(MANOR.x - 125, y))
		_lamp(Vector2(MANOR.x + 125, y + 30))


func _rose_garden() -> void:
	add_prop("props/fountain.png", RG, 1.0, Vector2(80, 26), Vector2(170, 56))
	add_interactable(RG + Vector2(0, 80), "The fountain", func(): await _landmark("fountain"), 120, "Rose garden")
	# hedges along the north and south sides, open where the path runs through
	for x in [-455, -245, 245, 455]:
		add_prop("props/hedge.png", RG + Vector2(x, -520), 1.0, Vector2(80, 16), Vector2(200, 46))
		add_prop("props/hedge.png", RG + Vector2(x, 540), 1.0, Vector2(80, 16), Vector2(200, 46), true)
		cover.append(Rect2(RG + Vector2(x - 96, -640), Vector2(192, 104)))
	add_prop("props/rose_arch.png", RG + Vector2(0, 548), 1.0, Vector2(60, 14), Vector2.ZERO)
	# clipped topiary down the west and east sides, open at the cross path
	for y in range(-440, 470, 110):
		if absf(y) < 120:
			continue
		add_prop("props/topiary.png", RG + Vector2(-570, y), 1.0, Vector2(30, 10), Vector2(64, 26))
		add_prop("props/topiary.png", RG + Vector2(570, y), 1.0, Vector2(30, 10), Vector2(64, 26), true)
	for e in [Vector2(-640, -100), Vector2(-640, 110), Vector2(640, -100), Vector2(640, 110)]:
		_lamp(RG + e)
	# statues and benches on the ring
	add_prop("props/statue.png", RG + Vector2(-245, -185), 1.0, Vector2(20, 8), Vector2(40, 22))
	add_prop("props/statue.png", RG + Vector2(245, -185), 1.0, Vector2(20, 8), Vector2(40, 22), true)
	add_prop("props/bench_marble.png", RG + Vector2(-250, 190), 1.0, Vector2(34, 10), Vector2(76, 22))
	add_prop("props/bench_marble.png", RG + Vector2(250, 190), 1.0, Vector2(34, 10), Vector2(76, 22), true)
	# rose beds in the four quarters
	var kinds = ["props/rose_red.png", "props/rose_pink.png", "props/rose_white.png"]
	var i = 0
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for q in [Vector2(170, 330), Vector2(320, 330), Vector2(470, 300), Vector2(170, 450), Vector2(320, 450), Vector2(470, 430)]:
				add_prop(kinds[i % 3], RG + Vector2(q.x * sx, q.y * sy), 1.0, Vector2(36, 12), Vector2(70, 24), (i % 2) == 1)
				i += 1
	for e in [Vector2(-455, -200), Vector2(455, -200), Vector2(-455, 200), Vector2(455, 200)]:
		add_prop("props/tulip_bed.png", RG + e, 1.0, Vector2(30, 10), Vector2(76, 24), e.x > 0)


func _pool() -> void:
	add_pond(POOL, Vector2(390, 210), 14.0)
	for p in [Vector2(-150, -50), Vector2(130, 30), Vector2(230, -70), Vector2(-40, 80), Vector2(-260, 40)]:
		add_prop("props/lily_pads.png", POOL + p, 1.0, Vector2.ZERO, Vector2.ZERO, p.x > 0)
	add_prop("props/blossom_pink.png", POOL + Vector2(-580, -300), 1.0, Vector2(24, 10), Vector2(40, 20))
	add_prop("props/blossom_white.png", POOL + Vector2(580, -320), 1.0, Vector2(24, 10), Vector2(40, 20), true)
	add_prop("props/blossom_white_s.png", POOL + Vector2(-560, 340), 1.0, Vector2(20, 8), Vector2(36, 18))
	add_prop("props/blossom_pink_s.png", POOL + Vector2(580, 330), 1.0, Vector2(20, 8), Vector2(36, 18), true)
	add_prop("props/bench_marble.png", POOL + Vector2(0, 330), 1.0, Vector2(34, 10), Vector2(76, 22))
	_lamp(POOL + Vector2(-520, 40))
	_lamp(POOL + Vector2(520, 40))
	add_interactable(POOL + Vector2(0, 270), "The reflecting pool", func(): await _landmark("pool"), 120, "Reflecting pool")


func _heron() -> void:
	add_prop("props/heron_fountain.png", HERON, 1.0, Vector2(70, 22), Vector2(170, 56))
	for p in [Vector2(-260, -60), Vector2(260, -60), Vector2(-240, 120), Vector2(240, 120)]:
		add_prop("props/tulip_bed.png", HERON + p, 1.0, Vector2(30, 10), Vector2(76, 24), p.x > 0)
	add_interactable(HERON + Vector2(0, 100), "The heron fountain", _heron_action, 120, "Heron fountain")


func _stables() -> void:
	add_prop("props/stable.png", STABLES, 1.0, Vector2(100, 24), Vector2(270, 90))
	add_night_light(STABLES + Vector2(118, -228), Color(1.0, 0.76, 0.42), 0.7, 0.6, null, 0.05)
	for k in 3:
		add_prop("props/rose_fence.png", STABLES + Vector2(-330 + k * 176, 290), 1.0, Vector2(50, 8), Vector2(170, 20), k == 1)
	_horse(STABLES + Vector2(300, 160), true)
	_horse(STABLES + Vector2(-300, 60), false)
	add_prop("props/well_roses.png", STABLES + Vector2(470, -30), 1.0, Vector2(40, 12), Vector2(110, 40))
	add_interactable(STABLES + Vector2(0, 170), "The stables", func(): await _landmark("stables"), 130, "Stables")


## A horse standing in the yard (the white mare's sheet, its standing frame).
func _horse(pos: Vector2, flip: bool) -> Node2D:
	var rel = "actors/mare.png"
	var h = Node2D.new()
	h.position = pos
	var s = Sprite2D.new()
	s.texture = Art.lit(rel)
	if s.texture == null:
		return h
	var m = Art.pixel_meta(rel)
	var g: Array = m.get("grid", [1, 1])
	s.hframes = int(g[0])
	s.vframes = int(g[1])
	s.frame = int(m.get("anims", {}).get("stand", [0])[0])
	s.scale = Art.sprite_scale(rel)
	s.offset = Vector2(0, -s.texture.get_height() / (2.0 * s.vframes))
	s.flip_h = flip
	var sh = Sprite2D.new()
	sh.texture = Art.tex("fx/shadow.png")
	sh.modulate = Color(0.05, 0.06, 0.12, 0.4)
	sh.scale = Vector2(2.2, 0.6)
	sh.z_index = -1
	h.add_child(sh)
	h.add_child(s)
	var body = StaticBody2D.new()
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(150, 34)
	cs.shape = rs
	cs.position = Vector2(0, -10)
	body.add_child(cs)
	h.add_child(body)
	world.add_child(h)
	return h


func _borders() -> void:
	# the hedge along the south, the iron gate in it
	for x in range(216, 2000, 210):
		add_prop("props/hedge.png", Vector2(x, 3250), 1.0, Vector2(80, 16), Vector2(210, 46), (x / 210) % 2 == 1)
	for x in range(2410, 4300, 210):
		add_prop("props/hedge.png", Vector2(x, 3250), 1.0, Vector2(80, 16), Vector2(210, 46), (x / 210) % 2 == 0)
	var gate = add_prop("props/gate_iron.png", GATE + Vector2(0, 10), 1.0, Vector2(80, 14), Vector2(230, 40))
	if _empty():
		# wrenched open by something with enormous hands
		gate.skew = 0.22
		gate.rotation = -0.05
	add_interactable(GATE + Vector2(0, -70), "The gate", func(): await _landmark("gate"), 110, "Gate")
	map_line(PackedVector2Array([Vector2(100, 3250), Vector2(4300, 3250)]), Color(0.3, 0.5, 0.28), 40.0)


func _blocked(p: Vector2) -> bool:
	if Rect2(1450, -100, 1500, 1260).has_point(p):            # the house and terrace
		return true
	if Rect2(360, 1150, 1290, 1240).has_point(p):             # the rose garden
		return true
	if Rect2(2700, 1330, 1300, 860).has_point(p):             # the pool
		return true
	if Rect2(2580, 2180, 640, 470).has_point(p):              # the heron
		return true
	if Rect2(3300, 700, 1000, 820).has_point(p):              # the stable yard
		return true
	if absf(p.x - 2200) < 300.0:                              # the drive
		return true
	if p.y > 3080:                                            # the hedge
		return true
	for line in [_woods_pts(), PackedVector2Array([Vector2(MANOR.x, HERON.y), HERON])]:
		for k in range(line.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, line[k], line[k + 1]).distance_to(p) < 170.0:
				return true
	if p.distance_to(HILL) < 200.0:
		return true
	return false


func _trees() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 6060
	var placed: Array[Vector2] = []
	var tries = 0
	while placed.size() < 78 and tries < 5000:
		tries += 1
		var p = Vector2(rng.randf_range(40, bounds.size.x - 40), rng.randf_range(80, 3060))
		if _blocked(p):
			continue
		var ok = true
		for q in placed:
			if q.distance_to(p) < 230:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var west = p.x < 340
		var r = rng.randf()
		var rel: String
		if west:
			rel = ["props/birch.png", "props/birch_s.png", "props/birch.png", "props/oak_s.png"][rng.randi_range(0, 3)]
		elif r < 0.34:
			rel = ["props/blossom_pink.png", "props/blossom_pink_s.png", "props/blossom_white.png", "props/blossom_white_s.png"][rng.randi_range(0, 3)]
		elif r < 0.8:
			rel = ["props/oak.png", "props/oak_s.png"][rng.randi_range(0, 1)]
		else:
			rel = ["props/birch.png", "props/birch_s.png"][rng.randi_range(0, 1)]
		var flip = rng.randf() < 0.5
		if LAWN.has_point(p) or MEADOW.has_point(p):
			continue   # its place still counts, so the rest of the grounds keep their shape
		add_prop(rel, p, 1.0, Vector2(22, 9), Vector2(38, 20), flip)
	# the old willow on the rise behind the east wing, where the dawn comes up
	add_prop("props/willow.png", HILL + Vector2(-260, -40), 1.0, Vector2(30, 12), Vector2(50, 24))


func _flowers() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 919
	var wild = ["props/poppies.png", "props/bluebells.png", "props/daisies.png", "props/buttercups.png"]
	for i in 120:
		var p = Vector2(rng.randf_range(60, bounds.size.x - 60), rng.randf_range(120, 3080))
		if _blocked(p) and not (p.y > 2500 and absf(p.x - 2200) > 240 and p.y < 3080):
			continue
		var c = wild[rng.randi_range(0, 3)]
		# flowers come in drifts: a few of a kind together
		for k in rng.randi_range(1, 3):
			add_prop(c, p + Vector2(rng.randf_range(-60, 60), rng.randf_range(-30, 30)), 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)
	var wood = ["props/fern_spring.png", "props/tall_grass.png", "props/mushroom_ring.png", "props/mossy_rock.png", "props/toadstool.png"]
	for i in 30:
		var p = Vector2(rng.randf_range(30, 300), rng.randf_range(120, 3060))
		if absf(p.y - WOODS_Y) < 120 or absf(p.y - RG.y - 120) < 110:
			continue
		var rel = wood[rng.randi_range(0, wood.size() - 1)]
		add_prop(rel, p, 1.0, Vector2.ZERO, Vector2(40, 16) if rel.contains("rock") else Vector2.ZERO, rng.randf() < 0.5)


func _critters() -> void:
	for p in [RG + Vector2(-330, 380), RG + Vector2(330, -330), RG + Vector2(420, 430), POOL + Vector2(-520, 200), Vector2(1400, 2800), Vector2(3000, 2900), HERON + Vector2(-220, 40)]:
		add_critter("butterfly_white" if int(p.x) % 2 == 0 else "butterfly_yellow", p)
	for p in [Vector2(1600, 1300), Vector2(2700, 1150), Vector2(1300, 2450), Vector2(3600, 2350)]:
		add_critter("bluebird", p)
	for p in [Vector2(800, 2800), Vector2(3500, 2800), Vector2(4150, 1900)]:
		add_critter("rabbit", p)
	add_critter("stag", Vector2(4200, 2600))


func _solstice_dressing() -> void:
	# ribbons and lanterns for midsummer: the poles on the lawn by the pool,
	# lanterns strung round the garden
	for p in [POOL + Vector2(-700, 420), POOL + Vector2(-260, 470), POOL + Vector2(260, 470), POOL + Vector2(700, 420)]:
		add_prop("props/ribbon_pole.png", p, 1.0, Vector2(16, 6), Vector2(30, 16))
		var l = add_light(p + Vector2(0, -260), Color(1.0, 0.72, 0.5), 0.5, 0.9, false)
		add_flicker(l, 0.15, 6.0)
	add_prop("props/maypole.png", POOL + Vector2(0, 560), 1.0, Vector2(30, 10), Vector2(50, 20))
	# the bonfire past the dancing ring, smoking into the dusk
	var fire = POOL + Vector2(0, 930)
	add_prop("props/bonfire.png", fire, 1.0, Vector2(30, 10), Vector2(90, 30))
	add_glow_lights("props/bonfire.png", fire, Color(1.0, 0.64, 0.32), 0.9, 1.0, false, 40.0, null, 0.6)
	var fl = add_light(fire + Vector2(0, -60), Color(1.0, 0.6, 0.3), 1.0, 3.6, false)
	add_flicker(fl, 0.2, 8.0)
	add_smoke(fire + Vector2(0, -150), null, 10)
	# the musicians' corner, south-west of the ring between the heron's
	# tulips and the fire, where he plays
	for p in [Vector2(-560, 930), Vector2(-500, 1030)]:
		add_prop("props/drum.png", POOL + p, 1.0, Vector2(14, 6), Vector2(30, 16))
	for p in [Vector2(-470, 860), Vector2(-300, 990)]:
		add_prop("props/stool.png", POOL + p, 1.0, Vector2.ZERO, Vector2(20, 10))
	# the food tables, east, under lanterns
	for p in [Vector2(640, 500), Vector2(800, 530)]:
		add_prop("props/table.png", POOL + p, 1.0, Vector2(40, 12), Vector2(90, 30))
		var lt = add_light(POOL + p + Vector2(0, -90), Color(1.0, 0.8, 0.55), 0.45, 0.8, false)
		add_flicker(lt, 0.1, 5.0)
	add_prop("props/barrels_summer.png", POOL + Vector2(930, 470), 1.0, Vector2(30, 10), Vector2(60, 24))


# ------------------------------------------------------------------ actions
func _go_inside() -> void:
	if GameState.chapter == 28:
		UI.toast("The carriage is waiting.")
		return
	if _empty():
		if not GameState.has_flag("ch31_doors"):
			await Dialogue.play("ch31_doors")
		Router.goto_region("manor_hall", "front")
		return
	if GameState.chapter == 6 and not GameState.has_flag("ch06_inside"):
		await Dialogue.play("ch06_door")
		return
	if _attor != null:
		return
	if GameState.chapter == 8 and not GameState.has_flag("ch08_dinner") and not _all_seen():
		await Dialogue.play("ch08_not_yet")
		return
	if GameState.chapter == 9 and not GameState.has_flag("ch09_ride"):
		await Dialogue.play("ch09_not_inside")
		return
	if GameState.chapter == 11 and not GameState.has_flag("ch11_puca_done"):
		await Dialogue.play("ch11_not_inside")
		return
	if GameState.chapter == 14 and not GameState.has_flag("ch15_naga_done"):
		await Dialogue.play("ch14_not_inside")
		return
	if GameState.chapter == 20 and GameState.has_flag("ch20_sneak"):
		await Dialogue.play("ch20_not_inside")
		return
	Router.goto_region("manor_hall", "front")


const LANDMARKS := ["fountain", "pool", "stables", "gate"]


func _all_seen() -> bool:
	for l in LANDMARKS:
		if not GameState.has_flag("ch08_seen_" + l):
			return false
	return true


## Chapter 8: she maps the grounds, one landmark at a time. Other days the
## places have a word or two of their own.
func _landmark(id: String) -> void:
	if GameState.chapter == 8 and not GameState.has_flag("ch08_seen_" + id) and not GameState.has_flag("ch08_dinner"):
		GameState.set_flag("ch08_seen_" + id)
		await Dialogue.play("ch08_" + id)
		if _all_seen():
			await Dialogue.play("ch08_mapped")
		return
	if id == "stables" and npc.has("lucien"):
		return
	await Dialogue.play("spring_" + id)


func _heron_action() -> void:
	if GameState.chapter == 24 and GameState.has_flag("ch24_morning") and not GameState.has_flag("ch24_head"):
		await Dialogue.play("ch24_head")
		return
	await Dialogue.play("spring_heron")


func _to_woods() -> void:
	if GameState.chapter >= 28:
		UI.toast("Not the woods. Not now.")
		player.position.x = maxf(player.position.x, 200.0)
		return
	if GameState.chapter < 11 or (GameState.chapter == 11 and not GameState.has_flag("ch11_follow")):
		await Dialogue.play("spring_woods_closed")
		player.position.x = maxf(player.position.x, 200.0)
		return
	if GameState.chapter == 20 and not GameState.has_flag("ch20_sneak"):
		await Dialogue.play("spring_woods_closed")
		player.position.x = maxf(player.position.x, 200.0)
		return
	Router.goto_region("spring_woods", "manor")


# ------------------------------------------------------------------- story
## Who is about, and what is waiting to happen, in this chapter.
func _story() -> void:
	add_trigger(Rect2(-120, WOODS_Y - 300, 190, 600), _to_woods, false)
	var ch = GameState.chapter
	if _empty():
		_ch31_ruin()
		return
	if ch >= 7 and ch != 11 and not (ch == 20 and GameState.has_flag("ch20_sneak")):
		npc.sentry_a = add_npc("sentry", GATE + Vector2(-190, -90), "Sentry", func(): await Dialogue.play("spring_sentry"), 0)
		npc.sentry_b = add_npc("sentry", GATE + Vector2(190, -90), "Sentry", func(): await Dialogue.play("spring_sentry"), 0)
	if ch >= 8 and ch != 28 and Region.night_amount(GameState.hour) < 0.5 and not _solstice:
		# from Chapter 24 she sees Alis as she is: bark-brown skin under the mask
		npc.alis = add_npc("bark_servant" if ch >= 24 else "housekeeper", MANOR + Vector2(-200, 110), "Alis", _alis, 0)
	if ch >= 24 and Region.night_amount(GameState.hour) < 0.5:
		# the glamour is failing: the servants show what they are
		add_npc("bark_servant", RG + Vector2(-330, 250), "", Callable(), 1)
		add_npc("bark_servant", POOL + Vector2(470, 120), "", Callable(), 1)
	match ch:
		7:
			if GameState.has_flag("ch07_dined") and not GameState.has_flag("ch07_garden"):
				add_trigger(Rect2(RG - Vector2(640, 600), Vector2(1280, 1200)), _ch07_garden)
		9:
			if not GameState.has_flag("ch09_tamlin"):
				add_trigger(Rect2(Vector2(2700, 860), Vector2(400, 420)), _ch09_tamlin)
			npc.lucien = add_npc("courtier_red", STABLES + Vector2(-60, 200), "Lucien", func(): await _ch09_lucien(), 0)
		11:
			if not GameState.has_flag("ch11_follow"):
				_ch11_father()
		18:
			if GameState.has_flag("ch18_morning") and not GameState.has_flag("ch18_glen"):
				npc.tamlin = add_npc("lord_gold", POOL + Vector2(-180, 300), "Tamlin", func(): await Dialogue.play("ch18_pool"), 2)
				npc.lucien = add_npc("courtier_red", POOL + Vector2(-300, 300), "", Callable(), 2)
		19:
			if GameState.has_flag("ch19_gallery") and not GameState.has_flag("ch19_attor_done"):
				npc.tamlin = add_npc("lord_gold", RG + Vector2(-90, 120), "", Callable(), 2)
				npc.lucien = add_npc("courtier_red", RG + Vector2(90, 120), "", Callable(), 1)
				add_trigger(Rect2(RG - Vector2(600, 560), Vector2(1200, 1100)), _ch19_attor)
		24:
			if GameState.has_flag("ch24_morning") and not GameState.has_flag("ch24_head"):
				# they come up behind her while she stares at it
				npc.tamlin = add_npc("lord_gold", HERON + Vector2(-110, 280), "", Callable(), 3)
				npc.lucien = add_npc("courtier_red", HERON + Vector2(110, 290), "", Callable(), 3)
				npc.tamlin.visible = false
				npc.lucien.visible = false
				add_trigger(Rect2(HERON - Vector2(320, 260), Vector2(640, 620)), _heron_action)
		25:
			if _solstice:
				_ch25_party()
		28:
			_ch28_carriage()


func on_enter() -> void:
	var ch = GameState.chapter
	if ch == 6 and not GameState.has_flag("ch06_arrived"):
		GameState.set_flag("ch06_arrived")
		var beast = _beast()
		await Dialogue.play("ch06_arrive")
		_beast_walks(beast)
	elif ch == 9 and not GameState.has_flag("ch09_morning"):
		GameState.set_flag("ch09_morning")
		await Dialogue.play("ch09_morning")
	elif ch == 11 and GameState.has_flag("ch11_follow") and not GameState.has_flag("ch11_puca_done"):
		# back from a fall in the fight: it is waiting at the gates
		start_fight("puca")
	elif ch == 11 and not GameState.has_flag("ch11_out"):
		GameState.set_flag("ch11_out")
		await Dialogue.play("ch11_out")
	elif ch == 20 and GameState.has_flag("ch20_sneak") and not GameState.has_flag("ch20_out"):
		GameState.set_flag("ch20_out")
		await Dialogue.play("ch20_out")
	elif ch == 24 and GameState.has_flag("ch24_morning") and not GameState.has_flag("ch24_head") and not GameState.has_flag("ch24_out"):
		GameState.set_flag("ch24_out")
		await Dialogue.play("ch24_out")
	elif ch == 31 and not GameState.has_flag("ch31_return"):
		await Dialogue.play("ch31_return")


## Chapter 6: the beast pads up the drive ahead of her, seen from behind,
## and goes in at the front doors.
func _beast() -> Node2D:
	var rel = "actors/beast.png"
	var b = Node2D.new()
	b.position = GATE + Vector2(0, -420)
	var s = Sprite2D.new()
	s.texture = Art.lit(rel)
	if s.texture != null:
		var m = Art.pixel_meta(rel)
		var g: Array = m.get("grid", [1, 1])
		s.hframes = int(g[0])
		s.vframes = int(g[1])
		s.frame = int(m.get("anims", {}).get("rear", [0])[0])
		s.scale = Art.sprite_scale(rel)
		s.offset = Vector2(0, -s.texture.get_height() / (2.0 * s.vframes))
	b.add_child(s)
	world.add_child(b)
	return b


func _beast_walks(b: Node2D) -> void:
	var pts = [Vector2(2200, 2500), Vector2(2195, 1800), Vector2(2200, 1150), DOOR + Vector2(0, 10)]
	var tw = create_tween()
	var from = b.position
	for p in pts:
		tw.tween_property(b, "position", p, from.distance_to(p) / 150.0)
		from = p
	tw.tween_property(b, "modulate:a", 0.0, 0.6)
	tw.tween_callback(b.queue_free)
	GameState.set_objective("Follow the beast up to the house.")


func _ch07_garden() -> void:
	npc.tamlin = add_npc("lord_gold", player.position + Vector2(260, 60), "", Callable(), 1)
	await Dialogue.play("ch07_garden")
	if is_instance_valid(npc.tamlin):
		await walk_npc(npc.tamlin, DOOR + Vector2(0, 40), 140.0)
		npc.tamlin.queue_free()


func _ch09_tamlin() -> void:
	npc.tamlin = add_npc("lord_gold", player.position + Vector2(-240, 40), "", Callable(), 2)
	await Dialogue.play("ch09_tamlin")
	if is_instance_valid(npc.tamlin):
		await walk_npc(npc.tamlin, DOOR + Vector2(0, 40), 150.0)
		npc.tamlin.queue_free()


func _ch09_lucien() -> void:
	if GameState.has_flag("ch09_tamlin"):
		await Dialogue.play("ch09_lucien")
	else:
		await Dialogue.play("ch09_lucien_early")


## Chapter 11: her father, or what looks like him, stands by the hedges
## below her window, then limps off down the drive toward the open gates.
## She follows. At the gates it shows her what it is.
func _ch11_father() -> void:
	var f = add_npc("father", Vector2(1500, 1090), "", Callable(), 2)
	npc.father = f
	add_trigger(Rect2(Vector2(1560, 880), Vector2(520, 420)), func():
		GameState.set_flag("ch11_follow")
		GameState.set_objective("Follow him.")
		await lead_npc(f, [Vector2(2000, 1240), Vector2(2190, 1700), Vector2(2200, 2500), GATE + Vector2(0, -130)], 120.0, 420.0)
		if not is_instance_valid(f):
			return
		await Dialogue.play("ch11_puca")
		if is_instance_valid(f):
			f.queue_free()
		start_fight("puca"))


## A stand-up fight (the puca at the gates): foes step out of the hedge.
func start_fight(id: String) -> void:
	if hunt != null:
		return
	SaveSystem.save_slot("auto")
	combat_allowed = true
	player.combat_allowed = true
	var pts = [GATE + Vector2(-300, -260), GATE + Vector2(300, -260), GATE + Vector2(0, -470)]
	hunt = Encounter.new()
	hunt.name = "Fight"
	add_child(hunt)
	hunt.finished.connect(_on_fight_done.bind(id))
	hunt.start(self, id, pts)


func _on_fight_done(won: bool, id: String) -> void:
	hunt = null
	if not won:
		await get_tree().create_timer(1.4, true, false, true).timeout
		await UI.game_over("Taken by the Puca", "It wore her father's face to the end.", "It rears back before it lunges: step aside, then strike while it recovers. Arrows hurt it before it closes.")
		return
	if id == "puca":
		GameState.set_flag("ch11_puca_done")
		await Dialogue.play("ch11_walk")


## Chapter 25: the night of dancing goes by in a blur; then the rise behind
## the east wing as the sky goes grey, where he takes her to watch the dawn.
func solstice_dawn() -> void:
	await UI.fade_out(1.2)
	GameState.hour = 4.9
	GameState.set_flag("ch25_dawn")
	place_player("hill")
	player.facing = 3
	if npc.has("tamlin") and is_instance_valid(npc.tamlin):
		npc.tamlin.position = spawns.hill + Vector2(64, 4)
		npc.tamlin.set_meta("facing", 3)
	await get_tree().create_timer(0.5, true, false, true).timeout
	await UI.fade_in(1.4)


## The sun comes up over the hills while the scene plays on.
func sunrise() -> void:
	create_tween().tween_property(GameState, "hour", 6.8, 10.0)


## region_call (Ch 25): he leads her off the dancing ground, by moonlight, to
## the wild meadow at the estate's east edge.
func to_meadow() -> void:
	await UI.fade_out(0.8)
	GameState.hour = 3.6
	place_player("meadow")
	player.facing = 2
	if npc.has("tamlin") and is_instance_valid(npc.tamlin):
		npc.tamlin.position = spawns.meadow + Vector2(70, 4)
		npc.tamlin.set_meta("facing", 1)
	await get_tree().create_timer(0.4, true, false, true).timeout
	await UI.fade_in(0.8)


## region_call (Ch 25): will-o'-the-wisps drift out over the long grass,
## slender slants of moonlight, and later are simply gone.
func wisps(on: bool) -> void:
	if not on:
		for w in _wisps:
			if is_instance_valid(w):
				var tw = w.create_tween()
				tw.tween_property(w, "modulate:a", 0.0, 1.4)
				tw.tween_callback(w.queue_free)
		_wisps.clear()
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = 2525
	var c: Vector2 = spawns.meadow
	# they glow by their own light: added on top of the night, not lit by it
	var glow = CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in 26:
		var w = Sprite2D.new()
		w.texture = Art.soft_light_texture()
		w.material = glow
		w.scale = Vector2(0.24, 0.46) * rng.randf_range(0.8, 1.3)
		w.modulate = Color(0.72, 0.86, 1.0, 0.0)
		var at = c + Vector2(rng.randf_range(-640, 640), rng.randf_range(-300, 280))
		if at.distance_to(c) < 170.0:
			at += (at - c).normalized() * 190.0
		w.position = at
		w.z_index = 30
		world.add_child(w)
		_wisps.append(w)
		# a bright heart in the haze
		var core = Sprite2D.new()
		core.texture = w.texture
		core.material = glow
		core.scale = Vector2(0.3, 0.3)
		core.modulate = Color(0.95, 0.98, 1.0, 0.9)
		w.add_child(core)
		var l = add_light(Vector2.ZERO, Color(0.74, 0.84, 1.0), 0.0, 0.9, false, w)
		var d = Vector2(rng.randf_range(-140, 140), rng.randf_range(-50, 50))
		var drift = w.create_tween().set_loops()
		drift.tween_property(w, "position", at + d, rng.randf_range(2.2, 3.8)).set_trans(Tween.TRANS_SINE)
		drift.tween_property(w, "position", at - d, rng.randf_range(2.2, 3.8)).set_trans(Tween.TRANS_SINE)
		var show = w.create_tween()
		show.tween_interval(rng.randf_range(0.0, 2.5))
		show.tween_property(w, "modulate:a", 0.95, 1.6)
		show.parallel().tween_property(l, "energy", 0.8, 1.6)
	await get_tree().create_timer(1.6, true, false, true).timeout


## Chapter 19: the walk in the rose garden, then the voice from nowhere.
func _ch19_attor() -> void:
	await Dialogue.play("ch19_garden")
	_attor = Attor.new()
	add_child(_attor)
	_attor.finished.connect(_on_attor_done)
	_attor.start(self, RG + Vector2(0, 160), cover, [npc.get("tamlin"), npc.get("lucien")])


func _on_attor_done(ok: bool) -> void:
	_attor = null
	if not ok:
		await get_tree().create_timer(0.8, true, false, true).timeout
		await UI.game_over("Seen", "The thing's whisper finds her behind the hedge.", "Get behind the hedges on the garden's north side before it comes, and keep still while it is near.")
		return
	await Dialogue.play("ch19_attor_after")
	for k in ["tamlin", "lucien"]:
		if npc.has(k) and is_instance_valid(npc[k]):
			walk_npc(npc[k], DOOR + Vector2(0, 40), 150.0)


## Chapter 25: midsummer on the lawn. Revellers dance round the poles; he
## finds her there, and they dance until the sky goes grey.
func _ch25_party() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 25
	for i in 10:
		var a = TAU * i / 10.0
		var c = POOL + Vector2(0, 600)
		var p = c + Vector2(cos(a) * 300, sin(a) * 140)
		var r = add_npc("fae_reveler", p, "", Callable(), rng.randi_range(0, 3))
		var tw = r.create_tween().set_loops()
		var q = c + Vector2(cos(a + 0.9) * 300, sin(a + 0.9) * 140)
		tw.tween_property(r, "position", q, rng.randf_range(2.2, 3.4)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(r, "position", p, rng.randf_range(2.2, 3.4)).set_trans(Tween.TRANS_SINE)
	# two more players beside him at the drums
	add_npc("fae_reveler", POOL + Vector2(-560, 980), "", Callable(), 2)
	add_npc("fae_reveler", POOL + Vector2(-500, 1080), "", Callable(), 2)
	npc.tamlin = add_npc("lord_gold", POOL + Vector2(-380, 900), "Tamlin", func(): await Dialogue.play("ch25_dance"), 2)
	npc.lucien = add_npc("courtier_red", POOL + Vector2(700, 600), "Lucien", func(): await Dialogue.play("ch25_lucien"), 1)


func _alis() -> void:
	var key = "alis_cake_%d" % GameState.chapter
	if not GameState.has_flag(key):
		GameState.set_flag(key)
		await Dialogue.play("spring_alis_cake")
	else:
		await Dialogue.play("spring_alis")


## region_call: someone steps out of the scene for a while, or back into it.
func npc_visible(key: String, on: bool) -> void:
	if npc.has(key) and is_instance_valid(npc[key]):
		npc[key].visible = on


## region_call: someone is suddenly at her side (he came up behind her).
func npc_beside(key: String) -> void:
	if not (npc.has(key) and is_instance_valid(npc[key])):
		return
	var h: Node2D = npc[key]
	h.position = player.global_position + Vector2(84, 6)
	h.set_meta("facing", 1)
	h.visible = true
	player.facing = 2


## region_call: someone walks off up to the house and goes in.
func npc_leave(key: String) -> void:
	if not (npc.has(key) and is_instance_valid(npc[key])):
		return
	var h: Node2D = npc[key]
	npc.erase(key)
	var t = h.position.distance_to(DOOR) / 170.0
	var tw = h.create_tween()
	tw.tween_property(h, "position", DOOR + Vector2(0, 40), t)
	tw.parallel().tween_property(h, "modulate:a", 0.0, 0.8).set_delay(maxf(0.0, t - 0.8))
	tw.tween_callback(h.queue_free)


## region_call (Ch 19): Tamlin and Lucien back by the fountain, where they
## face the thing that comes.
func watchers_ready() -> void:
	for k in ["tamlin", "lucien"]:
		if npc.has(k) and is_instance_valid(npc[k]):
			npc[k].position = RG + Vector2(-90 if k == "tamlin" else 90, 120)
			npc[k].visible = true


## Hours pass in a scene (Ch 25's night of dancing): fade, set the clock,
## put Feyre where the next beat is.
func pass_time(hour: float, spawn_name := "") -> void:
	await UI.fade_out(0.8)
	GameState.hour = hour
	if spawn_name != "":
		place_player(spawn_name)
	await get_tree().create_timer(0.4, true, false, true).timeout
	await UI.fade_in(0.8)


# --------------------------------------------------------- Ch 28: farewell
## The gilded carriage pulled up before the steps, six white horses facing
## the road, and Tamlin waiting at its door.
func _ch28_carriage() -> void:
	if GameState.has_flag("ch28_carriage"):
		return
	_carriage = add_prop("props/carriage.png", CARRIAGE_AT, 1.0, Vector2(200, 20), Vector2(640, 60))
	npc.tamlin = add_npc("lord_gold", CARRIAGE_AT + Vector2(250, 40), "", Callable(), 1)
	add_trigger(Rect2(CARRIAGE_AT + Vector2(80, -260), Vector2(420, 250)), func(): await Dialogue.play("ch28_carriage"))
	GameState.set_objective("Go out to the carriage.")


## region_call (ch28_carriage): Lucien comes out after her and shoulders past
## down the steps, to have it out with Tamlin.
func lucien_storms_past() -> void:
	var l = add_npc("courtier_red", DOOR + Vector2(0, 30), "", Callable(), 0)
	npc.lucien = l
	await walk_npc(l, CARRIAGE_AT + Vector2(150, 30), 230.0)
	l.set_meta("facing", 2)


## region_call (ch28_carriage): handed up into the carriage.
func board_carriage() -> void:
	var tw = create_tween()
	tw.tween_property(player, "modulate:a", 0.0, 0.4)
	await tw.finished
	player.visible = false
	player.locked = true
	player.global_position = CARRIAGE_AT + Vector2(240, -20)


## region_call (ch28_unsaid): the horses lean into the traces and the carriage
## rolls away west, toward the gate road, and is gone.
func carriage_leaves() -> void:
	if player.visible:
		await board_carriage()
	var from = CARRIAGE_AT
	if _carriage != null and is_instance_valid(_carriage):
		from = _carriage.position
		_carriage.queue_free()
	var trot = add_prop("props/carriage_trot.png", from, 1.0, Vector2.ZERO, Vector2.ZERO)
	_carriage = trot
	Audio.sfx("door_thud", -14.0)
	var tw = create_tween()
	tw.tween_property(trot, "position", from + Vector2(-1100, 40), 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v): player.global_position = v, player.global_position, player.global_position + Vector2(-1100, 40), 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(trot, "modulate:a", 0.0, 1.2).set_delay(2.8)
	if npc.has("tamlin") and is_instance_valid(npc.tamlin):
		npc.tamlin.set_meta("facing", 1)
	await tw.finished


# ----------------------------------------------------- Ch 31: the silence
## The grounds after the court was taken: nobody at the gate, nobody in the
## gardens, the front doors wide, debris on the terrace. Her horse waits
## inside the bent gates.
func _ch31_ruin() -> void:
	_horse(GATE + Vector2(-250, -130), false)
	add_prop("props/wreck_door.png", DOOR + Vector2(96, 30), 1.0, Vector2(30, 10), Vector2(60, 20), true)
	add_prop("props/wreck_vase.png", MANOR + Vector2(-260, 150), 1.0, Vector2.ZERO, Vector2.ZERO)
	add_prop("props/wreck_chair.png", MANOR + Vector2(310, 120), 1.0, Vector2(16, 6), Vector2(30, 12), true)
	add_prop("props/wreck_vase.png", MANOR + Vector2(420, 190), 1.0, Vector2.ZERO, Vector2.ZERO, true)
	var rng = RandomNumberGenerator.new()
	rng.seed = 3131
	# the hedges have gone shaggy: brambles and long grass pushing up along them
	for i in 26:
		var p = Vector2(rng.randf_range(240, 4200), 3190 + rng.randf_range(-30, 20))
		if absf(p.x - GATE.x) < 260:
			continue
		add_prop(["props/bramble.png", "props/tall_grass.png", "props/tall_grass.png"][rng.randi_range(0, 2)], p, 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)
	# glass and splinters out on the terrace, from the windows blown outward
	for i in 70:
		var g = MANOR + Vector2(rng.randf_range(-600, 600), rng.randf_range(-20, 190))
		var chip = Polygon2D.new()
		var sz = rng.randf_range(2.0, 4.0)
		chip.polygon = PackedVector2Array([g + Vector2(-sz, 0), g + Vector2(0, -sz * 0.6), g + Vector2(sz, 0), g + Vector2(0, sz * 0.6)])
		chip.color = Color(0.86, 0.92, 1.0, 0.8) if rng.randf() < 0.7 else Color(0.42, 0.28, 0.18, 0.9)
		chip.z_index = 1
		ground.add_child(chip)
	add_trigger(Rect2(DOOR + Vector2(-260, 30), Vector2(520, 220)), func():
		if not GameState.has_flag("ch31_doors"):
			await Dialogue.play("ch31_doors"))
