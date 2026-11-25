extends Region
## Chapter 29: the old cottage in summer, three miles west of the new house.
## The thatch has gone to moss and a hole has opened in it; Elain's flower bed
## has run wild across the front; the ward-marks are still cut into the
## doorstep, and someone has hung a new door where the beast broke the old
## one. The road runs past the yard, and from the door her old path goes
## south across it, over the field, to the tree line: her forest, which is
## only trees now.

const COTTAGE := Vector2(1240, 780)          # foot of the front wall
const DOOR := Vector2(1258, 790)
const ROAD_Y := 1180.0
const TREES_Y := 1640.0                      # where the forest begins

var npc := {}


func build() -> void:
	surface = "grass"
	combat_allowed = false
	map_title = "The Old Cottage"
	map_base = Color(0.66, 0.74, 0.5)
	bounds = Rect2(0, 0, 2600, 2000)
	spawns = {"start": Vector2(2440, ROAD_Y), "road": Vector2(2440, ROAD_Y), "door": DOOR + Vector2(0, 90)}
	pixel_ground(["grass", "meadow", "forest_floor", "dirt"], 29)
	_ground()
	enclose_bounds()
	add_sun(-35.0, Color(1.0, 0.95, 0.84), 0.52)
	_cottage()
	_yard()
	_forest()
	_field()
	_critters()
	terrain.smooth_edges = true
	terrain.build()
	add_rays(Color(1.0, 0.94, 0.78), 0.16, -0.3)
	set_post({"vignette": 0.3, "lift": Vector3(0.014, 0.012, 0.016), "gain": Vector3(1.0, 1.0, 0.98), "saturation": 1.04, "grain": 0.0})


func _ready() -> void:
	super._ready()
	add_light(Vector2(0, -30), Color(0.8, 0.82, 1.0), 0.26, 2.6, false, player)
	map_exit(Vector2(2560, ROAD_Y), "The road east")
	Audio.ambience("spring_day")
	Audio.music("cottage", 3.0)


func on_enter() -> void:
	if not GameState.has_flag("ch29_cottage"):
		await Dialogue.play("ch29_cottage")


func sun_shadow(h: float) -> Vector4:
	var a = deg_to_rad(lerpf(-62.0, 62.0, clampf((h - 6.0) / 14.0, 0.0, 1.0)))
	var length = 0.4 + 0.75 * (1.0 - sin(clampf((h - 6.0) / 14.0, 0.0, 1.0) * PI))
	var alpha = 0.3 * smoothstep(5.5, 7.0, h) * (1.0 - smoothstep(19.5, 20.5, h))
	return Vector4(sin(a), -cos(a), length, alpha)


func grade_for_hour(h: float) -> Dictionary:
	return Region.lerp_grade([
		[6.0, {"mod": Color(0.5, 0.45, 0.52), "sun": Color(1.0, 0.72, 0.55), "sun_energy": 0.32, "rays": 0.2, "exposure": Color(1.0, 0.97, 0.96)}],
		[9.0, {"mod": Color(0.68, 0.67, 0.66), "sun": Color(1.0, 0.93, 0.8), "sun_energy": 0.46, "rays": 0.14, "exposure": Color(0.99, 0.98, 0.96)}],
		[13.0, {"mod": Color(0.72, 0.72, 0.7), "sun": Color(1.0, 0.97, 0.88), "sun_energy": 0.48, "rays": 0.12, "exposure": Color(0.99, 0.98, 0.96)}],
		[17.0, {"mod": Color(0.7, 0.64, 0.58), "sun": Color(1.0, 0.86, 0.62), "sun_energy": 0.55, "rays": 0.22, "exposure": Color(1.0, 0.97, 0.94)}],
		[19.4, {"mod": Color(0.54, 0.44, 0.48), "sun": Color(1.0, 0.64, 0.42), "sun_energy": 0.48, "rays": 0.26, "exposure": Color(1.0, 0.96, 0.95)}],
		[21.0, {"mod": Color(0.3, 0.31, 0.5), "sun": Color(0.55, 0.55, 0.85), "sun_energy": 0.06, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
	], h)


func _road() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-120, ROAD_Y + 30), Vector2(700, ROAD_Y + 10), Vector2(1500, ROAD_Y - 6), Vector2(2720, ROAD_Y + 8)])


func _path() -> PackedVector2Array:
	return PackedVector2Array([DOOR + Vector2(0, 40), Vector2(DOOR.x + 30, ROAD_Y), Vector2(DOOR.x - 40, 1420), Vector2(DOOR.x + 20, TREES_Y + 120)])


func _ground() -> void:
	# the yard and the field have gone to meadow; the forest floor under the trees
	terrain.paint_rect("meadow", Rect2(200, 300, 2200, 1300), 90.0)
	terrain.paint_rect("forest_floor", Rect2(-200, TREES_Y, 3000, 600), 60.0)
	terrain.paint_rect("forest_floor", Rect2(-200, -200, 3000, 380), 60.0)
	terrain.paint_path("dirt", _road(), 150.0, 14.0)
	# her old path, half grown over
	terrain.paint_path("dirt", _path(), 56.0, 10.0)
	terrain.paint_ellipse("dirt", DOOR + Vector2(0, 40), Vector2(120, 50), 12.0)
	var road_c = Color(0.62, 0.5, 0.36)
	map_line(Region.smooth_curve(_road(), 20.0), road_c, 80.0)
	map_line(Region.smooth_curve(_path(), 20.0), road_c, 30.0)
	map_rect(Rect2(0, TREES_Y, 2600, 400), Color(0.36, 0.5, 0.32))


func _cottage() -> void:
	var rel = "props/cottage_family_summer.png"
	add_prop(rel, COTTAGE, 1.0, Vector2(150, 30), Vector2.ZERO)
	add_wall(Rect2(COTTAGE.x - 214, COTTAGE.y - 300, 428, 292))
	map_rect(Rect2(COTTAGE.x - 234, COTTAGE.y - 420, 468, 420), Color(0.72, 0.6, 0.42))
	add_interactable(DOOR + Vector2(0, 20), "The door", func(): await Dialogue.play("ch29_door"), 80, "The cottage")
	add_interactable(DOOR + Vector2(0, 70), "The doorstep", func(): await Dialogue.play("ch29_threshold"), 70)
	add_interactable(COTTAGE + Vector2(-150, 40), "Elain's flower bed", func(): await Dialogue.play("ch29_flowers"), 90)
	add_interactable(COTTAGE + Vector2(130, 30), "The cracked window", func(): await Dialogue.play("ch29_window_crack"), 80)
	# the ward-marks: little cuts in the stone, still there
	for i in 3:
		var m = Line2D.new()
		var x = DOOR.x - 16 + i * 14
		m.points = PackedVector2Array([Vector2(x, DOOR.y + 22), Vector2(x + 6, DOOR.y + 34)])
		m.width = 2.0
		m.default_color = Color(0.3, 0.26, 0.22, 0.8)
		m.z_index = 1
		ground.add_child(m)


func _yard() -> void:
	# Elain's bed run riot along the front, choked in bramble
	for p in [Vector2(-170, 40), Vector2(-120, 64), Vector2(-210, 70), Vector2(-60, 56)]:
		add_prop("props/foxgloves.png", COTTAGE + p, 1.0, Vector2.ZERO, Vector2.ZERO, p.x < -150)
	for p in [Vector2(-150, 90), Vector2(-90, 96), Vector2(-200, 100)]:
		add_prop("props/poppies.png", COTTAGE + p, 1.0, Vector2.ZERO, Vector2.ZERO)
	add_prop("props/bramble_summer.png", COTTAGE + Vector2(-260, 20), 1.0, Vector2(30, 8), Vector2(60, 18))
	add_prop("props/bramble_summer.png", COTTAGE + Vector2(250, 10), 1.0, Vector2(30, 8), Vector2(60, 18), true)
	add_prop("props/woodshed_summer.png", COTTAGE + Vector2(330, -40), 1.0, Vector2(50, 14), Vector2(130, 34))
	add_prop("props/fence_summer.png", COTTAGE + Vector2(-420, 160), 1.0, Vector2(50, 8), Vector2(170, 18))
	add_prop("props/fence_summer.png", COTTAGE + Vector2(430, 170), 1.0, Vector2(50, 8), Vector2(170, 18), true)
	add_prop("props/mossy_log.png", COTTAGE + Vector2(-380, -60), 1.0, Vector2(30, 8), Vector2(80, 20))
	add_prop("props/buckets_summer.png", COTTAGE + Vector2(260, 70), 1.0, Vector2.ZERO, Vector2(40, 14))
	var rng = RandomNumberGenerator.new()
	rng.seed = 2929
	for i in 34:
		var p = Vector2(rng.randf_range(160, 2440), rng.randf_range(360, TREES_Y - 60))
		if p.distance_to(COTTAGE + Vector2(0, -100)) < 360.0 or absf(p.y - ROAD_Y) < 110.0 or absf(p.x - DOOR.x) < 90.0:
			continue
		var rel = ["props/tall_grass.png", "props/daisies.png", "props/buttercups.png", "props/poppies.png", "props/tall_grass.png"][rng.randi_range(0, 4)]
		for k in rng.randi_range(1, 3):
			add_prop(rel, p + Vector2(rng.randf_range(-40, 40), rng.randf_range(-20, 20)), 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)


## The tree line to the south: her forest, in leaf. And trees behind the cottage.
func _forest() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 4141
	for i in 30:
		var p = Vector2(rng.randf_range(40, 2560), rng.randf_range(TREES_Y + 30, 1980))
		if absf(p.x - DOOR.x) < 130.0 and p.y < TREES_Y + 200:
			p.x += 260.0
		var rel = ["props/oak.png", "props/oak_s.png", "props/birch.png", "props/birch_s.png", "props/oak_summer.png"][rng.randi_range(0, 4)]
		add_prop(rel, p, 1.0, Vector2(22, 9), Vector2(38, 20), rng.randf() < 0.5)
	for i in 10:
		var p = Vector2(rng.randf_range(40, 2560), rng.randf_range(80, 330))
		if absf(p.x - COTTAGE.x) < 300.0:
			p.x += 600.0
		add_prop(["props/oak.png", "props/oak_s.png", "props/birch.png"][rng.randi_range(0, 2)], p, 1.0, Vector2(22, 9), Vector2(38, 20), rng.randf() < 0.5)
	add_prop("props/oak_summer.png", COTTAGE + Vector2(-520, -140), 1.0, Vector2(40, 14), Vector2(60, 26))
	add_interactable(Vector2(DOOR.x, TREES_Y - 40), "The tree line", func(): await _forest_view(), 150, "Her forest")
	add_interactable(Vector2(DOOR.x + 30, ROAD_Y - 90), "The old path", func(): await _forest_view(), 90)


func _field() -> void:
	for p in [Vector2(500, 1420), Vector2(1900, 1460)]:
		add_prop("props/hay_bales_summer.png", p, 1.0, Vector2(40, 12), Vector2(100, 34), p.x > 1000)
	add_prop("props/signpost_summer.png", Vector2(2330, ROAD_Y - 130), 1.0, Vector2(14, 5), Vector2(20, 14), true)
	add_prop("props/stone_wall_summer.png", Vector2(1800, ROAD_Y - 120), 1.0, Vector2(60, 10), Vector2(140, 30))
	add_prop("props/stone_wall_summer.png", Vector2(1950, ROAD_Y - 120), 1.0, Vector2(60, 10), Vector2(140, 30), true)
	add_prop("props/stone_wall_summer.png", Vector2(600, ROAD_Y - 120), 1.0, Vector2(60, 10), Vector2(140, 30))
	add_trigger(Rect2(2520, ROAD_Y - 240, 140, 480), _road_east, false)
	add_trigger(Rect2(-60, ROAD_Y - 240, 120, 480), func():
		UI.toast("The road west only runs on to strangers' farms.")
		player.position.x = maxf(player.position.x, 140.0), false)


func _critters() -> void:
	for p in [COTTAGE + Vector2(-160, 120), Vector2(800, 1400), Vector2(2000, 900)]:
		add_critter("butterfly_white" if int(p.x) % 2 == 0 else "butterfly_yellow", p)
	add_critter("bluebird", Vector2(1700, 700))
	add_critter("rabbit", Vector2(600, 1500))
	add_critter("crow", Vector2(1500, 1350))


func _forest_view() -> void:
	if GameState.has_flag("ch29_cottage_end"):
		await Dialogue.play("home_forest_again")
		return
	player.facing = 0
	await Dialogue.play("ch29_forest")


func _road_east() -> void:
	if not GameState.has_flag("ch29_cottage_end"):
		UI.toast("Not yet. " + String(GameState.objective))
		player.position.x = minf(player.position.x, 2460.0)
		return
	# on to the village with the purses: the next chapter starts there
	GameState.chapter = 30
	GameState.hour = maxf(GameState.hour, 14.5)
	Router.goto_region("village_summer", "west")
