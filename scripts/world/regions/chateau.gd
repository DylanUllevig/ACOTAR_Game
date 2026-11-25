extends Region
## Chapters 28 to 31: her father's new estate, across the Wall. A white house
## under green roofs at the head of a long gravel drive, lined with hedges
## clipped into green flames and irises crowded along its edges. Elain's
## little walled garden lies under the study window, east of the house, with
## the glasshouse beyond it; the lawn runs south to the old mulberry tree at
## its edge, and past it the flat green fields. The road west leads to the
## old cottage.
##
## Chapter 28: the carriage brings her here asleep, and her sisters come out.
## Chapter 29: Elain's garden, Nesta under the tree, and the walk west.
## Chapter 30: digging Elain's new bed by the glasshouse; what Nesta knew.
## Chapter 31: Elain at the steps with a saddled horse.

const HOUSE := Vector2(1700, 720)            # foot of the front steps
const DOOR := Vector2(1700, 742)
const DRIVE_Y := 1060.0
const COURT := Rect2(1250, 740, 900, 420)    # the gravel forecourt
const CARRIAGE_AT := Vector2(1900, 1066)     # Ch 28: pulled up facing the house's east wing
const GARDEN := Vector2(2530, 900)           # Elain's garden, under the study window
const STUDY_WINDOW := Vector2(2147, 760)     # the east wing's lower window
const GLASS := Vector2(3200, 800)            # the glasshouse
const PLOT := Vector2(3130, 1050)            # Ch 30: the new bed by the glasshouse
const MULBERRY := Vector2(2760, 1640)
const FIELDS_Y := 1880.0                     # where the lawn ends and the fields begin
const HORSE_AT := Vector2(1480, 940)         # Ch 31: the saddled horse
const DIG_SPOTS := [Vector2(-110, -30), Vector2(40, -46), Vector2(-60, 56), Vector2(110, 40)]

var npc := {}
var _carriage: Node2D = null
var _horse: Node2D = null
var _horse_spr: Sprite2D = null
var _dig_spots := {}


func build() -> void:
	surface = "grass"
	combat_allowed = false
	map_title = "Father's Estate"
	map_base = Color(0.66, 0.78, 0.52)
	bounds = Rect2(0, 0, 3800, 2700)
	spawns = {
		"start": DOOR + Vector2(0, 90), "door": DOOR + Vector2(0, 90), "steps": DOOR + Vector2(0, 90),
		"drive": Vector2(1600, 900), "garden": GARDEN + Vector2(-150, 150),
		"plot": PLOT + Vector2(-190, 70), "west": Vector2(170, DRIVE_Y),
	}
	pixel_ground(["grass", "dirt", "lawn", "meadow", "gravel", "terrace"], 41)
	_ground()
	enclose_bounds()
	add_sun(-35.0, Color(1.0, 0.95, 0.84), 0.52)
	_house()
	_drive()
	_garden()
	_glasshouse()
	_lawn()
	_fields()
	_trees()
	_flowers()
	_critters()
	terrain.smooth_edges = true
	terrain.build()
	add_rays(Color(1.0, 0.94, 0.78), 0.16, -0.3)
	set_post({"vignette": 0.24, "lift": Vector3(0.014, 0.012, 0.016), "gain": Vector3(1.01, 1.0, 0.98), "saturation": 1.1, "grain": 0.0})


func _ready() -> void:
	super._ready()
	# a soft fill that follows Feyre, so she reads at dusk
	add_light(Vector2(0, -30), Color(0.8, 0.82, 1.0), 0.26, 2.6, false, player)
	map_exit(Vector2(60, DRIVE_Y), "The road west")
	_story()
	var night = Region.night_amount(GameState.hour) > 0.5
	Audio.ambience("spring_night" if night else "spring_day")
	Audio.music("chateau", 3.0)


## High summer: the sun swings from the east over the house to the west;
## shadows fall north, long at either end of the day.
func sun_shadow(h: float) -> Vector4:
	var a = deg_to_rad(lerpf(-62.0, 62.0, clampf((h - 6.0) / 14.0, 0.0, 1.0)))
	var length = 0.4 + 0.75 * (1.0 - sin(clampf((h - 6.0) / 14.0, 0.0, 1.0) * PI))
	var alpha = 0.3 * smoothstep(5.5, 7.0, h) * (1.0 - smoothstep(19.5, 20.5, h))
	return Vector4(sin(a), -cos(a), length, alpha)


## A hot, clear summer: bright and warm by day, a long gold evening.
func grade_for_hour(h: float) -> Dictionary:
	return Region.lerp_grade([
		[4.5, {"mod": Color(0.27, 0.3, 0.48), "sun": Color(0.45, 0.5, 0.8), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
		[6.0, {"mod": Color(0.5, 0.45, 0.52), "sun": Color(1.0, 0.72, 0.55), "sun_energy": 0.32, "rays": 0.2, "exposure": Color(1.0, 0.97, 0.96)}],
		[8.5, {"mod": Color(0.68, 0.67, 0.66), "sun": Color(1.0, 0.93, 0.8), "sun_energy": 0.46, "rays": 0.14, "exposure": Color(0.99, 0.98, 0.96)}],
		[13.0, {"mod": Color(0.74, 0.73, 0.7), "sun": Color(1.0, 0.97, 0.88), "sun_energy": 0.48, "rays": 0.12, "exposure": Color(0.99, 0.98, 0.96)}],
		[17.0, {"mod": Color(0.7, 0.64, 0.58), "sun": Color(1.0, 0.86, 0.62), "sun_energy": 0.55, "rays": 0.22, "exposure": Color(1.0, 0.97, 0.94)}],
		[19.4, {"mod": Color(0.54, 0.44, 0.48), "sun": Color(1.0, 0.64, 0.42), "sun_energy": 0.48, "rays": 0.26, "exposure": Color(1.0, 0.96, 0.95)}],
		[20.8, {"mod": Color(0.32, 0.32, 0.5), "sun": Color(0.55, 0.55, 0.85), "sun_energy": 0.08, "rays": 0.02, "exposure": Color(1.0, 1.0, 1.04)}],
		[22.0, {"mod": Color(0.27, 0.3, 0.48), "sun": Color(0.45, 0.5, 0.8), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
	], h)


# ------------------------------------------------------------------ layout
func _drive_pts() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-120, DRIVE_Y + 14), Vector2(500, DRIVE_Y + 4), Vector2(1000, DRIVE_Y - 6), Vector2(COURT.position.x + 60, DRIVE_Y)])


func _mulberry_walk() -> PackedVector2Array:
	return PackedVector2Array([Vector2(HOUSE.x + 120, COURT.end.y - 20), Vector2(HOUSE.x + 260, 1420), Vector2(2300, 1600), MULBERRY + Vector2(-200, 90)])


func _ground() -> void:
	# the kept lawn round the house, down to the fields; rough grass at the edges
	terrain.paint_rect("lawn", Rect2(260, 330, 3300, FIELDS_Y - 330), 60.0)
	# the fields: green rows on brown earth in the middle, a hay meadow to the
	# east, mown strips to the west
	terrain.paint_rect("dirt", Rect2(1290, FIELDS_Y + 90, 1200, 900), 0.0)
	for y in range(int(FIELDS_Y) + 130, 2800, 144):
		terrain.paint_rect("lawn", Rect2(1330, y, 1120, 54), 0.0)
		terrain.paint_rect("lawn", Rect2(-100, y + 40, 1260, 70), 0.0)
	terrain.paint_rect("meadow", Rect2(2620, FIELDS_Y + 90, 1300, 900), 50.0)
	# gravel: the drive, the forecourt, the walks to the garden, the glasshouse and the tree
	terrain.paint_path("gravel", _drive_pts(), 170.0, 6.0)
	terrain.paint_rect("gravel", COURT, 0.0)
	terrain.paint_path("gravel", PackedVector2Array([Vector2(COURT.end.x - 40, 930), Vector2(2280, 930), GARDEN + Vector2(-170, 30)]), 96.0, 4.0)
	terrain.paint_path("gravel", PackedVector2Array([GARDEN + Vector2(330, 30), Vector2(2990, 940), GLASS + Vector2(-60, 60)]), 90.0, 6.0)
	terrain.paint_path("gravel", _mulberry_walk(), 90.0, 8.0)
	# paving before the steps, and the cross walks in Elain's garden
	terrain.paint_rect("terrace", Rect2(HOUSE.x - 560, HOUSE.y - 40, 1120, 120), 0.0)
	terrain.paint_rect("terrace", Rect2(GARDEN.x - 300, GARDEN.y - 20, 600, 80), 0.0)
	terrain.paint_rect("terrace", Rect2(GARDEN.x - 40, GARDEN.y - 200, 80, 400), 0.0)
	var gravel_c = Color(0.84, 0.78, 0.62)
	map_line(Region.smooth_curve(_drive_pts(), 20.0), gravel_c, 100.0)
	map_line(Region.smooth_curve(_mulberry_walk(), 20.0), gravel_c, 50.0)
	map_rect(COURT, gravel_c)
	map_rect(Rect2(1290, FIELDS_Y + 90, 1200, 600), Color(0.56, 0.44, 0.3))
	map_rect(Rect2(2620, FIELDS_Y + 90, 1180, 600), Color(0.72, 0.78, 0.46))


func _house() -> void:
	var rel = "props/chateau.png"
	add_prop(rel, HOUSE, 1.0, Vector2(320, 40), Vector2.ZERO)
	# solid from the foot of the steps back: nothing behind the house is reachable
	add_wall(Rect2(HOUSE.x - 524, -200, 1048, HOUSE.y - 8 + 200))
	add_glow_lights(rel, HOUSE, Color(1.0, 0.8, 0.48), 0.5, 0.55, false, 40.0, null, 0.05)
	map_rect(Rect2(HOUSE.x - 534, HOUSE.y - 600, 1068, 600), Color(0.96, 0.94, 0.88))
	add_interactable(DOOR, "Go inside", _go_inside, 110, "Front doors")
	for x in [-250, 250]:
		add_prop("props/urn.png", HOUSE + Vector2(x, 70), 1.0, Vector2(30, 10), Vector2(60, 26), x > 0)
	for x in [-470, 470]:
		add_prop("props/topiary_flame.png", HOUSE + Vector2(x, 90), 1.0, Vector2(26, 9), Vector2(40, 18), x > 0)
	for p in [Vector2(COURT.position.x + 40, COURT.end.y - 20), Vector2(COURT.end.x - 40, COURT.end.y - 20)]:
		add_prop("props/lamp_post_summer.png", p, 1.0, Vector2(12, 5), Vector2(20, 14), p.x < HOUSE.x)
		var l = add_night_light(p + Vector2(10.0 * (-1.0 if p.x < HOUSE.x else 1.0), -112), Color(1.0, 0.78, 0.46), 0.6, 0.8, null, 0.04)
		add_flicker(l, 0.08, 6.0)
	add_interactable(STUDY_WINDOW, "The study window", _study_window, 100, "Father's study")


## The drive: green flames of clipped yew down both sides, irises in drifts
## at their feet, and from the night of the ball, coloured lanterns.
func _drive() -> void:
	var i = 0
	for x in range(240, 1200, 210):
		for side in [-1, 1]:
			add_prop("props/topiary_flame.png", Vector2(x, DRIVE_Y + side * 150), 1.0, Vector2(26, 9), Vector2(40, 18), side > 0)
			add_prop("props/irises.png", Vector2(x + 92, DRIVE_Y + side * 122), 1.0, Vector2.ZERO, Vector2.ZERO, (i + side) % 2 == 0)
			add_prop("props/irises.png", Vector2(x + 138, DRIVE_Y + side * 134), 1.0, Vector2.ZERO, Vector2.ZERO, (i + side) % 2 != 0)
		i += 1
	if GameState.chapter >= 31 or GameState.has_flag("ch30_lessons_done"):
		for x in range(345, 1200, 420):
			for side in [-1, 1]:
				_lantern(Vector2(x, DRIVE_Y + side * 112))
	# the estate's edge: a hedge down the west side, open where the road comes in
	for y in range(160, 2000, 210):
		if absf(y - DRIVE_Y) < 220:
			continue
		add_prop("props/hedge.png", Vector2(40, y), 1.0, Vector2(80, 16), Vector2(210, 46), (y / 210) % 2 == 1)
	add_prop("props/signpost_summer.png", Vector2(150, DRIVE_Y - 150), 1.0, Vector2(14, 5), Vector2(20, 14))
	add_trigger(Rect2(-80, DRIVE_Y - 230, 140, 460), _road_west, false)


## A post hung with coloured glass lanterns, left over from the ball.
func _lantern(p: Vector2) -> void:
	add_prop("props/lantern_post.png", p, 1.0, Vector2(12, 5), Vector2(20, 12))
	var cols = [Color(1.0, 0.5, 0.42), Color(0.5, 0.7, 1.0), Color(1.0, 0.82, 0.4)]
	add_night_light(p + Vector2(0, -95), cols[int(absf(p.x)) % 3], 0.55, 0.7, null, 0.02)


func _garden() -> void:
	var g = GARDEN
	# low stone walls on three sides, open toward the house and the forecourt
	for x in [-260, -110, 110, 260]:
		add_prop("props/stone_wall_summer.png", g + Vector2(x, 250), 1.0, Vector2(60, 10), Vector2(140, 30), x > 0)
	for y in [-120, 40, 170]:
		add_prop("props/stone_wall_summer.png", g + Vector2(350, y), 1.0, Vector2(60, 10), Vector2(140, 30))
	# tulip beds in the four quarters, every bulb hers
	var k = 0
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for q in [Vector2(100, 90), Vector2(190, 90), Vector2(280, 100), Vector2(120, 160), Vector2(230, 170)]:
				if sy < 0 and q.y > 120:
					continue
				add_prop("props/tulips_elain.png", g + Vector2(q.x * sx, q.y * sy + (0 if sy > 0 else 40)), 1.0, Vector2.ZERO, Vector2.ZERO, k % 2 == 1)
				k += 1
	add_prop("props/fountain_summer.png", g + Vector2(0, 20), 1.0, Vector2(60, 18), Vector2(150, 50))
	add_prop("props/bench_iron.png", g + Vector2(-150, -150), 1.0, Vector2(34, 10), Vector2(90, 24))
	add_prop("props/flower_barrel.png", g + Vector2(300, -160), 1.0, Vector2(26, 8), Vector2(50, 20))
	add_prop("props/flower_barrel.png", g + Vector2(-300, 200), 1.0, Vector2(26, 8), Vector2(50, 20), true)
	for p in [Vector2(-330, -40), Vector2(-320, 60), Vector2(330, -40)]:
		add_prop("props/foxgloves.png", g + p, 1.0, Vector2.ZERO, Vector2.ZERO, p.y > 0)
	add_prop("props/basket_post.png", g + Vector2(200, -170), 1.0, Vector2(12, 5), Vector2(20, 12))
	add_prop("props/buckets_summer.png", g + Vector2(250, 200), 1.0, Vector2.ZERO, Vector2(40, 14))
	map_poi(g, "Elain's garden")
	map_rect(Rect2(g - Vector2(330, 200), Vector2(660, 420)), Color(0.82, 0.62, 0.66))


func _glasshouse() -> void:
	add_prop("props/glasshouse.png", GLASS, 1.0, Vector2(80, 20), Vector2(180, 50))
	add_night_light(GLASS + Vector2(0, -130), Color(0.9, 1.0, 0.8), 0.35, 0.8, null, 0.0)
	add_prop("props/wheelbarrow_summer.png", GLASS + Vector2(170, 40), 1.0, Vector2(30, 8), Vector2(60, 18), true)
	add_prop("props/crates_summer.png", GLASS + Vector2(-190, 10), 1.0, Vector2(40, 12), Vector2(110, 30))
	add_prop("props/barrels_summer.png", GLASS + Vector2(250, -40), 1.0, Vector2(30, 10), Vector2(80, 24))
	map_poi(GLASS, "Glasshouse")
	map_rect(Rect2(GLASS - Vector2(100, 160), Vector2(200, 160)), Color(0.8, 0.9, 0.88))


## The lawn south of the house: flower beds, a statue or two, benches.
func _lawn() -> void:
	for p in [Vector2(1300, 1350), Vector2(2100, 1340)]:
		add_prop("props/statue.png", p, 1.0, Vector2(20, 8), Vector2(40, 22), p.x > HOUSE.x)
		for d in [Vector2(-130, 40), Vector2(130, 40)]:
			add_prop("props/tulip_bed.png", p + d, 1.0, Vector2(30, 10), Vector2(76, 24), d.x > 0)
	for p in [Vector2(1560, 1560), Vector2(1860, 1560)]:
		add_prop("props/rose_pink.png" if p.x < HOUSE.x else "props/rose_white.png", p, 1.0, Vector2(40, 12), Vector2(80, 26), p.x > HOUSE.x)
	add_prop("props/bench_marble.png", Vector2(1700, 1640), 1.0, Vector2(34, 10), Vector2(76, 22))
	# the old mulberry at the lawn's edge, over the fields
	add_prop("props/mulberry.png", MULBERRY, 1.0, Vector2(40, 14), Vector2(70, 26))
	map_poi(MULBERRY, "Mulberry tree")
	# split-rail fence between the lawn and the fields, with gaps for the farm tracks
	for x in range(80, 3800, 126):
		if absf(x - 1260) < 130 or absf(x - 2570) < 130:
			continue
		add_prop("props/rail_fence_summer.png", Vector2(x, FIELDS_Y), 1.0, Vector2(50, 8), Vector2(126, 16))
	map_line(PackedVector2Array([Vector2(0, FIELDS_Y), Vector2(3800, FIELDS_Y)]), Color(0.58, 0.44, 0.3), 16.0)


func _fields() -> void:
	# hay drying in the meadow, a cart left at the gap in the fence
	for p in [Vector2(2900, 2200), Vector2(3120, 2310), Vector2(3420, 2180), Vector2(3260, 2500), Vector2(3600, 2420)]:
		add_prop("props/hay_bales_summer.png", p, 1.0, Vector2(40, 12), Vector2(100, 34), int(p.x) % 2 == 0)
	add_prop("props/cart_summer.png", Vector2(2700, 1990), 1.0, Vector2(50, 14), Vector2(140, 36), true)
	add_prop("props/wheelbarrow_summer.png", Vector2(1380, 1990), 1.0, Vector2(30, 8), Vector2(60, 18))
	# hedgerow oaks between the fields
	for p in [Vector2(1240, 2340), Vector2(2560, 2620), Vector2(640, 2660)]:
		add_prop("props/oak_summer.png", p, 1.0, Vector2(40, 14), Vector2(60, 26), int(p.y) % 2 == 0)


func _blocked(p: Vector2) -> bool:
	if Rect2(1060, -100, 1280, 1300).has_point(p):              # the house and forecourt
		return true
	if absf(p.y - DRIVE_Y) < 260.0 and p.x < 1300:               # the drive
		return true
	if Rect2(GARDEN - Vector2(420, 280), Vector2(840, 580)).has_point(p):
		return true
	if Rect2(GLASS - Vector2(330, 360), Vector2(660, 760)).has_point(p):
		return true
	if Rect2(1150, 1250, 1100, 500).has_point(p):                # the lawn's beds
		return true
	if p.distance_to(MULBERRY) < 420.0 or p.y > FIELDS_Y - 140.0:
		return true
	for k in range(_mulberry_walk().size() - 1):
		var line = _mulberry_walk()
		if Geometry2D.get_closest_point_to_segment(p, line[k], line[k + 1]).distance_to(p) < 150.0:
			return true
	return false


func _trees() -> void:
	# a screen of big oaks behind the house
	for p in [Vector2(980, 420), Vector2(2420, 380), Vector2(560, 200), Vector2(2950, 260), Vector2(3550, 420), Vector2(250, 640)]:
		add_prop("props/oak_summer.png", p, 1.0, Vector2(40, 14), Vector2(60, 26), int(p.x) % 3 == 0)
	var rng = RandomNumberGenerator.new()
	rng.seed = 2828
	var placed: Array[Vector2] = []
	var tries = 0
	while placed.size() < 26 and tries < 4000:
		tries += 1
		var p = Vector2(rng.randf_range(200, 3700), rng.randf_range(360, FIELDS_Y - 160))
		# the crown stands a good 300 above the trunk: keep it off the drive,
		# the forecourt and the garden too, not just the trunk
		if _blocked(p) or _blocked(p - Vector2(0, 140)) or _blocked(p - Vector2(0, 280)):
			continue
		var ok = true
		for q in placed:
			if q.distance_to(p) < 300:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var rel = ["props/oak.png", "props/oak_s.png", "props/birch.png", "props/birch_s.png", "props/oak_s.png"][rng.randi_range(0, 4)]
		add_prop(rel, p, 1.0, Vector2(22, 9), Vector2(38, 20), rng.randf() < 0.5)


func _flowers() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 2929
	var wild = ["props/poppies.png", "props/daisies.png", "props/buttercups.png", "props/daisies.png"]
	for i in 70:
		var p = Vector2(rng.randf_range(120, 3700), rng.randf_range(380, 2640))
		if _blocked(p) and p.y < FIELDS_Y + 40:
			continue
		if p.y > FIELDS_Y and p.x > 1250 and p.x < 2560:
			continue   # nothing grows wild in the tilled field
		var c = wild[rng.randi_range(0, wild.size() - 1)]
		for k in rng.randi_range(1, 3):
			add_prop(c, p + Vector2(rng.randf_range(-50, 50), rng.randf_range(-24, 24)), 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)
	for i in 16:
		var p = Vector2(rng.randf_range(2650, 3750), rng.randf_range(FIELDS_Y + 120, 2650))
		add_prop("props/tall_grass.png", p, 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)


func _critters() -> void:
	for p in [GARDEN + Vector2(-200, 120), GARDEN + Vector2(220, -60), Vector2(1400, 1450), Vector2(3000, 2300), Vector2(600, 1400), MULBERRY + Vector2(-160, 120)]:
		add_critter("butterfly_white" if int(p.x) % 2 == 0 else "butterfly_yellow", p)
	for p in [Vector2(900, 1500), Vector2(2300, 1250), Vector2(3400, 1300)]:
		add_critter("bluebird", p)
	for p in [Vector2(800, 2200), Vector2(3300, 2400), Vector2(2000, 2550)]:
		add_critter("rabbit", p)
	add_critter("crow", Vector2(1800, 2300))


# ------------------------------------------------------------------- story
func _story() -> void:
	var ch = GameState.chapter
	var night = Region.night_amount(GameState.hour) > 0.5
	if not night and ch != 31:
		npc.footman = add_npc("footman", DOOR + Vector2(-150, 80), "Footman", func(): await Dialogue.play("home_footman"), 0)
	match ch:
		28:
			if not GameState.has_flag("ch28_arrived"):
				_carriage = add_prop("props/carriage.png", CARRIAGE_AT, 1.0, Vector2(200, 20), Vector2(640, 60), true)
				npc.footman_b = add_npc("footman", spawns.drive + Vector2(-120, -10), "", Callable(), 2)
				npc.footman_c = add_npc("footman", DOOR + Vector2(150, 80), "", Callable(), 0)
		29:
			npc.elain = add_npc("elain_rich", GARDEN + Vector2(-80, -110), "Elain", _elain, 0)
			npc.nesta = add_npc("nesta_rich", MULBERRY + Vector2(40, 80), "Nesta", func(): await Dialogue.play("ch29_nesta_tree"), 0)
			npc.nesta.set_meta("aloof", true)
			npc.gardener = add_npc("villager_summer", GLASS + Vector2(-140, 110), "Gardener", func(): await Dialogue.play("home_gardener"), 1)
		30:
			_ch30_plot()
		31:
			if GameState.has_flag("ch31_change") and not GameState.has_flag("ch31_away"):
				npc.elain = add_npc("elain_rich", HORSE_AT + Vector2(170, -10), "Elain", _elain, 1)
				_horse = _make_horse(HORSE_AT, false)
				if GameState.has_flag("ch31_elain"):
					_mount_prompt()


func on_enter() -> void:
	var ch = GameState.chapter
	if ch == 28 and not GameState.has_flag("ch28_arrived"):
		await Dialogue.play("ch28_arrive")
		_sisters_go_in()
	elif ch == 29 and not GameState.has_flag("ch29_garden"):
		await Dialogue.play("ch29_garden")
	elif ch == 30 and not GameState.has_flag("ch30_dig"):
		await Dialogue.play("ch30_dig")
		_gardener_flees()
	elif ch == 30 and _n_dug() >= 4 and not GameState.has_flag("ch30_nesta"):
		await _nesta_comes()
	elif ch == 31 and GameState.has_flag("ch31_change") and not GameState.has_flag("ch31_elain"):
		await Dialogue.play("ch31_elain")
		_mount_prompt()


func _go_inside() -> void:
	var why = _door_shut()
	if why != "":
		UI.toast(why)
		return
	Router.goto_region("chateau_hall", "front")


func _door_shut() -> String:
	match GameState.chapter:
		29:
			if not GameState.has_flag("ch29_elain"):
				return "Not yet. " + String(GameState.objective)
		30:
			return "Not with the bed half dug. " + String(GameState.objective)
		31:
			if not GameState.has_flag("ch31_away"):
				return "I'd said every goodbye I could bear to. " + String(GameState.objective)
	return ""


func _road_west() -> void:
	var ch = GameState.chapter
	if ch == 29 and GameState.has_flag("ch29_study"):
		Router.goto_region("cottage_yard", "road")
		return
	if ch == 29:
		UI.toast("Not yet. " + String(GameState.objective))
	elif ch == 31:
		UI.toast("Not on foot. " + String(GameState.objective))
	else:
		UI.toast("Not now. " + String(GameState.objective))
	player.position.x = maxf(player.position.x, 150.0)


func _study_window() -> void:
	if GameState.chapter == 29:
		await Dialogue.play("ch29_window")
	else:
		await Dialogue.play("home_study_window_out")


func _elain() -> void:
	var ch = GameState.chapter
	if ch == 29 and not GameState.has_flag("ch29_elain"):
		await Dialogue.play("ch29_elain")
		return
	if ch == 31:
		await Dialogue.play("home_elain_horse")
		return
	await Dialogue.play("home_elain")


# --------------------------------------------------------- Ch 28: arrival
## region_call (ch28_arrive): the front doors burst open and her sisters come
## down the steps toward the carriage.
func sisters_come() -> void:
	var e = add_npc("elain_rich", DOOR + Vector2(-20, 20), "", Callable(), 0)
	var n = add_npc("nesta_rich", DOOR + Vector2(30, 20), "", Callable(), 0)
	npc.elain = e
	npc.nesta = n
	Audio.sfx("door_thud", -12.0)
	player.facing = 3
	walk_npc(n, spawns.drive + Vector2(150, -120), 150.0)
	await walk_npc(e, spawns.drive + Vector2(80, -60), 150.0)
	e.set_meta("facing", 1)
	n.set_meta("facing", 1)


## region_call (ch28_arrive): the carriage turns on the gravel and rolls away
## west down the drive, back toward the Wall.
func carriage_goes() -> void:
	var from = CARRIAGE_AT
	if _carriage != null and is_instance_valid(_carriage):
		from = _carriage.position
		var old = _carriage
		var fade = old.create_tween()
		fade.tween_property(old, "modulate:a", 0.0, 0.5)
		fade.tween_callback(old.queue_free)
	var trot = add_prop("props/carriage_trot.png", from, 1.0, Vector2.ZERO, Vector2.ZERO)
	_carriage = trot
	trot.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(trot, "modulate:a", 1.0, 0.5)
	tw.tween_property(trot, "position", Vector2(-600, DRIVE_Y + 20), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(trot, "modulate:a", 0.0, 1.5).set_delay(7.5)
	tw.tween_callback(trot.queue_free)
	player.facing = 1
	await get_tree().create_timer(0.8, true, false, true).timeout


## After the scene: Elain goes in ahead of her; Nesta lingers, then follows.
func _sisters_go_in() -> void:
	for k in ["footman_b"]:
		if npc.has(k) and is_instance_valid(npc[k]):
			_walk_in(npc[k], 0.0)
	if npc.has("elain") and is_instance_valid(npc.elain):
		_walk_in(npc.elain, 0.0)
	if npc.has("nesta") and is_instance_valid(npc.nesta):
		_walk_in(npc.nesta, 2.5)


## Someone goes up the steps and in at the front doors.
func _walk_in(h: Node2D, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, true, false, true).timeout
	if not is_instance_valid(h):
		return
	var t = h.position.distance_to(DOOR) / 150.0
	var tw = h.create_tween()
	tw.tween_property(h, "position", DOOR + Vector2(0, 10), t)
	tw.parallel().tween_property(h, "modulate:a", 0.0, 0.6).set_delay(maxf(0.0, t - 0.6))
	tw.tween_callback(h.queue_free)


# ---------------------------------------------------- Ch 29: the garden
## region_call (ch29_elain): Elain glances over at Nesta under the tree.
func look_at_nesta() -> void:
	if not (npc.has("nesta") and is_instance_valid(npc.nesta)):
		return
	player.facing = 0
	if npc.has("elain") and is_instance_valid(npc.elain):
		npc.elain.set_meta("facing", 0)
	await look_toward(npc.nesta.global_position, 0.55, 1.6)


# --------------------------------------------- Ch 30: the bed, and Nesta
func _ch30_plot() -> void:
	# the turf pegged out with string, the spade waiting in it
	var done = GameState.has_flag("ch30_nesta")
	add_prop("props/dug_plot.png", PLOT + Vector2(0, -100), 1.0, Vector2(16, 6), Vector2(30, 14))
	for i in 4:
		var k = i + 1
		var at: Vector2 = PLOT + DIG_SPOTS[i]
		if GameState.has_flag("ch30_dug_%d" % k):
			_dug_patch(at)
			continue
		if GameState.has_flag("ch30_dig"):
			_dig_spot(k, at)
	if not GameState.has_flag("ch30_dig"):
		npc.gardener = add_npc("villager_summer", PLOT + Vector2(-60, 120), "", Callable(), 1)
	if not done:
		npc.nesta = add_npc("nesta_rich", MULBERRY + Vector2(40, 80), "", Callable(), 0)
		npc.nesta.set_meta("aloof", true)


func _dig_spot(k: int, at: Vector2) -> void:
	var a = add_interactable(at, "Dig", func(): await _dig(k, at), 80)
	_dig_spots[k] = a
	# a peg and a turned-up corner mark where to cut next
	var peg = Polygon2D.new()
	peg.polygon = PackedVector2Array([at + Vector2(-3, -14), at + Vector2(3, -14), at + Vector2(3, 0), at + Vector2(-3, 0)])
	peg.color = Color(0.62, 0.48, 0.3)
	peg.z_index = 1
	ground.add_child(peg)
	_dig_spots["peg_%d" % k] = peg


func _dig(k: int, at: Vector2) -> void:
	if GameState.has_flag("ch30_dug_%d" % k):
		return
	GameState.set_flag("ch30_dug_%d" % k)
	for key in [k, "peg_%d" % k]:
		if _dig_spots.has(key) and is_instance_valid(_dig_spots[key]):
			_dig_spots[key].queue_free()
		_dig_spots.erase(key)
	player.facing = 2 if at.x > player.global_position.x else 1
	Audio.sfx("forage", -6.0)
	UI.shake(2.0)
	_dug_patch(at)
	var n = _n_dug()
	await Dialogue.play("ch30_dig_%d" % n)
	if n < 4:
		GameState.set_objective("Dig out the new bed by the glasshouse. (%d/4)" % n)
	else:
		GameState.set_objective("")
		await _nesta_comes()


func _n_dug() -> int:
	var n = 0
	for i in 4:
		if GameState.has_flag("ch30_dug_%d" % (i + 1)):
			n += 1
	return n


## A cut of turned earth where the turf came up.
func _dug_patch(at: Vector2) -> void:
	var patch = add_ground_patch("terrain/dirt_pattern.png", Rect2(at - Vector2(90, 50), Vector2(180, 100)), 30.0, 18.0)
	patch.z_index = 1
	var rng = RandomNumberGenerator.new()
	rng.seed = int(at.x * 7.0 + at.y)
	for i in 5:
		var c = at + Vector2(rng.randf_range(-70, 70), rng.randf_range(-36, 36))
		var clod = Polygon2D.new()
		var r = rng.randf_range(5.0, 9.0)
		clod.polygon = PackedVector2Array([c + Vector2(-r, 0), c + Vector2(-r * 0.4, -r * 0.6), c + Vector2(r * 0.5, -r * 0.5), c + Vector2(r, 0), c + Vector2(0, r * 0.5)])
		clod.color = Color(0.36, 0.26, 0.17) if i % 2 == 0 else Color(0.38, 0.52, 0.24)
		clod.z_index = 2
		ground.add_child(clod)


## She comes over from her tree without a sound.
func _nesta_comes() -> void:
	if not (npc.has("nesta") and is_instance_valid(npc.nesta)):
		npc.nesta = add_npc("nesta_rich", MULBERRY + Vector2(40, 80), "", Callable(), 0)
	var n: Node2D = npc.nesta
	var to = player.global_position + Vector2(-130, 40)
	if to.distance_to(n.position) < 40.0:
		to = player.global_position + Vector2(130, 40)
	await walk_npc(n, to, 170.0)
	if not is_instance_valid(n):
		return
	n.set_meta("facing", 2 if player.global_position.x > n.position.x else 1)
	n.set_meta("aloof", false)
	player.facing = 1 if n.position.x < player.global_position.x else 2
	await Dialogue.play("ch30_nesta")


func _gardener_flees() -> void:
	if npc.has("gardener") and is_instance_valid(npc.gardener):
		var g: Node2D = npc.gardener
		npc.erase("gardener")
		var tw = g.create_tween()
		tw.tween_property(g, "position", GLASS + Vector2(-60, 40), g.position.distance_to(GLASS) / 190.0)
		tw.tween_property(g, "modulate:a", 0.0, 0.5)
		tw.tween_callback(g.queue_free)
	for i in 4:
		var k = i + 1
		if not GameState.has_flag("ch30_dug_%d" % k) and not _dig_spots.has(k):
			_dig_spot(k, PLOT + DIG_SPOTS[i])


## region_call (ch30_nesta): she tosses a splinter of painted wood on the earth.
func drop_chip() -> void:
	var at = player.global_position + Vector2(-34, 22)
	var chip = Node2D.new()
	chip.position = at
	chip.z_index = 3
	var wood = Polygon2D.new()
	wood.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(-9, -4), Vector2(12, -3), Vector2(16, 1), Vector2(9, 4), Vector2(-10, 3)])
	wood.color = Color(0.55, 0.38, 0.22)
	chip.add_child(wood)
	var vine = Polygon2D.new()
	vine.polygon = PackedVector2Array([Vector2(-6, -2), Vector2(4, -2), Vector2(6, 0), Vector2(-4, 1)])
	vine.color = Color(0.42, 0.56, 0.86)
	chip.add_child(vine)
	world.add_child(chip)
	Audio.sfx("dry_click", -10.0)
	if npc.has("nesta") and is_instance_valid(npc.nesta):
		npc.nesta.set_meta("facing", 2 if player.global_position.x > npc.nesta.position.x else 1)
	player.facing = 0
	await get_tree().create_timer(0.4, true, false, true).timeout


# --------------------------------------------------- Ch 31: the horse
func _make_horse(pos: Vector2, flip: bool) -> Node2D:
	var rel = "actors/mare.png"
	var h = Node2D.new()
	h.position = pos
	var s = Sprite2D.new()
	s.texture = Art.lit(rel)
	if s.texture == null:
		world.add_child(h)
		return h
	var m = Art.pixel_meta(rel)
	var g: Array = m.get("grid", [1, 1])
	s.hframes = int(g[0])
	s.vframes = int(g[1])
	s.frame = int(m.get("anims", {}).get("stand", [0])[0])
	s.scale = Art.sprite_scale(rel)
	s.offset = Vector2(0, -s.texture.get_height() / (2.0 * s.vframes))
	s.flip_h = flip
	# a saddle-bay brown, not the white mare of the Spring Court's stables
	s.modulate = Color(0.78, 0.62, 0.5)
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
	_horse_spr = s
	return h


func _mount_prompt() -> void:
	if _horse == null or not is_instance_valid(_horse) or _horse.has_meta("prompt"):
		return
	var a: Area2D = Interactable.new()
	a.setup("Mount the horse", func(): await Dialogue.play("ch31_away"), 150.0)
	_horse.add_child(a)
	_horse.set_meta("prompt", true)


## region_call (ch31_away): she swings up and gallops away west down the
## drive, between the lanterns.
func ride_off() -> void:
	if _horse == null or not is_instance_valid(_horse) or _horse_spr == null:
		return
	for c in _horse.get_children():
		if c is Area2D or c is StaticBody2D:
			c.queue_free()
	var m = Art.pixel_meta("actors/mare.png")
	var fade = create_tween()
	fade.tween_property(player, "modulate:a", 0.0, 0.3)
	await fade.finished
	player.visible = false
	player.locked = true
	player.global_position = _horse.position + Vector2(0, -4)
	# the ride frame carries her own cloak and bow: no brown here
	_horse_spr.modulate = Color(1, 1, 1)
	_horse_spr.frame = int(m.get("anims", {}).get("ride_side", [6])[0])
	_horse_spr.flip_h = true
	if npc.has("elain") and is_instance_valid(npc.elain):
		npc.elain.set_meta("facing", 1)
	var to = Vector2(-500, DRIVE_Y + 10)
	var start = _horse.position
	var mid = Vector2(COURT.position.x + 20, DRIVE_Y)
	var tw = create_tween()
	tw.tween_property(_horse, "position", mid, start.distance_to(mid) / 260.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_horse, "position", to, mid.distance_to(to) / 520.0)
	tw.parallel().tween_property(_horse, "modulate:a", 0.0, 1.0).set_delay(maxf(0.0, mid.distance_to(to) / 520.0 - 1.0))
	var bob = _horse_spr.create_tween().set_loops(12)
	bob.tween_property(_horse_spr, "position:y", -4.0, 0.14).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_horse_spr, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	var hold = create_tween()
	hold.tween_method(func(_v): player.global_position = _horse.position + Vector2(0, -4), 0.0, 1.0, 4.0)
	await get_tree().create_timer(2.6, true, false, true).timeout
