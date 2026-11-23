extends Region
## Chapter 1: the winter forest. A trodden path winds north-east from the
## south edge to a clearing by a half-frozen brook, where a starving doe strips
## bark and something far too large waits in the brush. Hares, wild roses and a
## few old hunter's leavings along the way. The hunt itself is real time: see
## scripts/combat/hunt.gd.

const Wolf := preload("res://scripts/combat/wolf.gd")
const Hare := preload("res://scripts/combat/hare.gd")
const Doe := preload("res://scripts/combat/doe.gd")
const Hunt := preload("res://scripts/combat/hunt.gd")

const CLEARING := Vector2(3050, 900)
const BRAMBLES := Vector2(2640, 1180)
const WOLF_START := CLEARING + Vector2(-330, -170)
const DOE_POS := CLEARING + Vector2(40, -30)
const EXIT := Vector2(760, 2630)
const HARES := [Vector2(1320, 2180), Vector2(1960, 1820), Vector2(560, 1480), Vector2(2900, 2060), Vector2(3640, 1720)]
const ROSES := [Vector2(1010, 2040), Vector2(1720, 1690), Vector2(2280, 1430), Vector2(1330, 1330), Vector2(3420, 1530)]

var wolf: Node2D = null
var doe: Node2D = null
var cover: Array = []          # Rect2 thickets that hide her
var _rose_props := {}
var _rose_spots := {}
var _aftermath_done := false
var _skin_spot: Area2D
var _doe_spot: Area2D


func build() -> void:
	bounds = Rect2(0, 0, 4200, 2700)
	spawns = {"start": Vector2(760, 2300), "brambles": BRAMBLES + Vector2(0, -14)}
	surface = "snow"
	combat_allowed = true
	map_title = "The Winter Forest"
	map_base = Color(0.92, 0.93, 0.96)
	add_ground_tile("terrain/snow.png", bounds)
	enclose_bounds()
	add_sun(-37.0, Color(1, 0.92, 0.8), 0.55)
	_build_path()
	_build_brook()
	_scatter_trees()
	_build_clearing()
	_build_points_of_interest()
	_build_roses()
	add_snow(260, Vector2(50, 0))
	add_fog(bounds.grow(400), Color(0.84, 0.88, 0.98), 0.14, 50, 0.0018)
	add_rays(Color(1.0, 0.88, 0.7), 0.16, -0.5)
	set_post({"vignette": 0.55, "lift": Vector3(0.02, 0.03, 0.06), "gain": Vector3(0.98, 1.0, 1.05), "saturation": 0.9, "grain": 0.02})


func _ready() -> void:
	super._ready()
	# soft cool fill that follows Feyre so she reads at dusk and night
	add_light(Vector2(0, -30), Color(0.65, 0.75, 1.0), 0.35, 3.0, false, player)
	_spawn_creatures()
	Audio.ambience("forest_wind")
	Audio.music("forest", 3.0)


## Low winter sun in the south: shadows fall north (up the screen), swinging
## from north-west in the morning to north-east by late afternoon, lengthening
## toward dusk and fading out as the light goes.
func sun_shadow(h: float) -> Vector4:
	var a = deg_to_rad(lerpf(-55.0, 60.0, clampf((h - 8.0) / 9.0, 0.0, 1.0)))
	var length = 0.45 + 0.8 * smoothstep(13.0, 16.8, h)
	var alpha = 0.3 * (1.0 - smoothstep(17.0, 17.6, h)) * smoothstep(7.0, 8.0, h)
	return Vector4(sin(a), -cos(a), length, alpha)


func grade_for_hour(h: float) -> Dictionary:
	return Region.lerp_grade([
		[6.0, {"mod": Color(0.12, 0.14, 0.26), "sun": Color(0.4, 0.45, 0.7), "sun_energy": 0.0, "rays": 0.0}],
		[8.0, {"mod": Color(0.42, 0.44, 0.58), "sun": Color(1.0, 0.75, 0.6), "sun_energy": 0.5, "rays": 0.12}],
		[13.0, {"mod": Color(0.6, 0.65, 0.8), "sun": Color(1.0, 0.95, 0.86), "sun_energy": 0.7, "rays": 0.16}],
		[15.5, {"mod": Color(0.55, 0.55, 0.7), "sun": Color(1.0, 0.82, 0.62), "sun_energy": 0.78, "rays": 0.22}],
		[16.6, {"mod": Color(0.42, 0.38, 0.54), "sun": Color(1.0, 0.58, 0.36), "sun_energy": 0.75, "rays": 0.3}],
		[17.4, {"mod": Color(0.22, 0.24, 0.4), "sun": Color(0.6, 0.55, 0.85), "sun_energy": 0.15, "rays": 0.04}],
		[19.0, {"mod": Color(0.12, 0.14, 0.26), "sun": Color(0.4, 0.45, 0.7), "sun_energy": 0.0, "rays": 0.0}],
	], h)


# ------------------------------------------------------------------ layout
func _path_points() -> Array:
	return [Vector2(760, 2700), Vector2(760, 2300), Vector2(1100, 1900), Vector2(1500, 1600), Vector2(2000, 1500), Vector2(2400, 1300), BRAMBLES + Vector2(-60, 60), CLEARING + Vector2(-120, 60)]


func _build_path() -> void:
	# a trodden line through the snow, a shade bluer and flatter than the drifts
	var pts = PackedVector2Array(_path_points())
	var curve = Curve2D.new()
	for p in pts:
		curve.add_point(p)
	var smooth = PackedVector2Array()
	for i in range(pts.size() - 1):
		for k in 8:
			smooth.append(pts[i].lerp(pts[i + 1], k / 8.0) + Vector2(sin(i * 3.1 + k) * 6.0, cos(i * 2.3 + k) * 6.0))
	smooth.append(pts[pts.size() - 1])
	var line = Line2D.new()
	line.points = smooth
	line.width = 84
	line.default_color = Color(0.74, 0.8, 0.92, 0.32)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = -9
	add_child(line)
	map_line(smooth, Color(0.66, 0.56, 0.44, 0.75), 30.0)


func _build_brook() -> void:
	var line = Line2D.new()
	line.width = 70
	line.default_color = Color(0.72, 0.84, 0.98, 0.85)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var pts = PackedVector2Array()
	for i in 30:
		var t = i / 29.0
		pts.append(Vector2(2300 + t * 1900, 400 + t * 900 + sin(t * 9.0) * 70))
	line.points = pts
	line.z_index = -8
	add_child(line)
	var edge = line.duplicate() as Line2D
	edge.width = 96
	edge.default_color = Color(0.55, 0.62, 0.75, 0.5)
	edge.z_index = -9
	add_child(edge)
	map_line(pts, Color(0.45, 0.6, 0.8, 0.9), 60.0)
	# holes in the ice: dark water glints
	for i in 6:
		var p = pts[4 + i * 4]
		var hole = Polygon2D.new()
		var poly = PackedVector2Array()
		for k in 10:
			var a = TAU * k / 10.0
			poly.append(Vector2(cos(a) * 16, sin(a) * 8))
		hole.polygon = poly
		hole.color = Color(0.1, 0.16, 0.26)
		hole.position = p + Vector2(randf_range(-10, 10), 0)
		hole.z_index = -7
		add_child(hole)


func _scatter_trees() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 1600
	var placed: Array[Vector2] = []
	var tries = 0
	while placed.size() < 150 and tries < 4000:
		tries += 1
		var p = Vector2(rng.randf_range(40, bounds.size.x - 40), rng.randf_range(60, bounds.size.y - 20))
		if p.distance_to(CLEARING) < 520:
			continue
		if p.distance_to(BRAMBLES) < 240:
			continue
		if _near_path(p, 150):
			continue
		var near_spot = false
		for q in HARES + ROSES:
			if p.distance_to(q) < 110:
				near_spot = true
		if near_spot:
			continue
		var ok = true
		for q in placed:
			if q.distance_to(p) < 120:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var r = rng.randf()
		if r < 0.78:
			add_prop("props/pine_%d.png" % rng.randi_range(0, 2), p, rng.randf_range(0.9, 1.35), Vector2(16, 7), Vector2(28, 18), rng.randf() < 0.5)
		elif r < 0.92:
			add_prop("props/bare_tree_%d.png" % rng.randi_range(0, 1), p, rng.randf_range(0.9, 1.2), Vector2(12, 6), Vector2(22, 16), rng.randf() < 0.5)
		else:
			add_prop("props/rock_%d.png" % rng.randi_range(0, 1), p, rng.randf_range(0.8, 1.3), Vector2(46, 18), Vector2(90, 40))


func _near_path(p: Vector2, d: float) -> bool:
	var pts = _path_points()
	for i in range(pts.size() - 1):
		var c = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		if c.distance_to(p) < d:
			return true
	return false


func _build_clearing() -> void:
	# the thicket she hides in: thorny, slow to push through, but it hides her
	for i in 5:
		add_prop("props/bramble.png", BRAMBLES + Vector2(-150 + i * 75, (i % 2) * 18), 1.15, Vector2.ZERO)
	for i in 3:
		add_prop("props/bramble.png", BRAMBLES + Vector2(-110 + i * 110, -52), 1.0, Vector2.ZERO, Vector2.ZERO, i == 1)
	cover = [Rect2(BRAMBLES + Vector2(-200, -90), Vector2(400, 130))]
	map_poi(BRAMBLES, "Bramble thicket")
	map_poi(CLEARING, "The clearing")


func _spawn_creatures() -> void:
	for p in HARES:
		var h = Hare.new()
		h.setup("snow_hare")
		h.position = p
		world.add_child(h)
	if GameState.has_flag("wolf_killed"):
		_build_aftermath(false)
		return
	doe = Doe.new()
	doe.position = DOE_POS
	world.add_child(doe)
	wolf = Wolf.new()
	wolf.setup("andras_wolf")
	wolf.position = WOLF_START
	world.add_child(wolf)
	wolf.hide_in_brush()
	wolf.face(10.0)


func _build_points_of_interest() -> void:
	add_interactable(Vector2(1180, 1880), "Read the signs", func(): await Dialogue.play("ch01_tracks"), 90.0, "Deer sign")
	add_prop("props/rock_1.png", Vector2(1560, 1560), 0.9, Vector2(40, 14), Vector2(80, 30))
	add_interactable(Vector2(1560, 1600), "Check the old snare", func(): await Dialogue.play("ch01_snare"), 90.0, "Old snare")
	add_interactable(Vector2(2060, 1530), "Rest a moment", func(): await Dialogue.play("ch01_ash_lore"), 90.0, "Fallen log")
	add_interactable(Vector2(3900, 1180), "Search the creek bank", func(): await Dialogue.play("ch01_wire"), 110.0, "Creek bank")
	map_exit(EXIT, "Home")
	# the approach: anywhere near the clearing she sees the doe, and the eyes
	add_trigger(Rect2(CLEARING - Vector2(1000, 700), Vector2(2000, 1400)), func():
		if not GameState.has_flag("wolf_killed") and hunt == null:
			await Dialogue.play("ch01_brambles"), false)
	add_trigger(Rect2(Vector2(560, 2560), Vector2(420, 140)), _try_leave, false)


func _build_roses() -> void:
	for i in ROSES.size():
		var picked = GameState.has_flag("rose_%d" % i)
		var prop = add_prop("props/rose_bush_bare.png" if picked else "props/rose_bush.png", ROSES[i], 1.0, Vector2(26, 9))
		_rose_props[i] = prop
		var idx = i
		var spot: Area2D = add_interactable(ROSES[i] + Vector2(0, 16), "Pick rose hips", func(): _pick_roses(idx), 80.0)
		spot.enabled = not picked
		_rose_spots[i] = spot


func _pick_roses(i: int) -> void:
	if GameState.has_flag("rose_%d" % i):
		return
	if GameState.add_item("rose_hips", 3) >= 3:
		return
	GameState.set_flag("rose_%d" % i)
	GameState.bump("rose_hips_picked", 3)
	Audio.sfx("forage", -4.0, 0.08)
	var spr: Sprite2D = (_rose_props[i] as Node2D).get_child(0)
	spr.texture = Art.lit("props/rose_bush_bare.png")
	(_rose_spots[i] as Area2D).enabled = false
	if not GameState.has_flag("hint_rose_hips"):
		GameState.set_flag("hint_rose_hips")
		UI.toast("Rose hips heal a little. Put them on the hotbar and click to eat.")


# -------------------------------------------------------------------- hunt
func in_cover(p: Vector2) -> bool:
	for r in cover:
		if (r as Rect2).has_point(p):
			return true
	return false


func _physics_process(_delta: float) -> void:
	if player:
		player.terrain_mult = 0.62 if in_cover(player.global_position) else 1.0


## Called from the brambles scene: if she came at the clearing another way,
## she circles round to the thicket first.
func crouch_in_brambles() -> void:
	if in_cover(player.global_position):
		return
	await UI.fade_out(0.35)
	place_player("brambles")
	player.facing = 3
	await get_tree().process_frame
	await UI.fade_in(0.45)


func start_hunt() -> void:
	if hunt != null or wolf == null or GameState.has_flag("wolf_killed"):
		return
	hunt = Hunt.new()
	hunt.name = "Hunt"
	add_child(hunt)
	hunt.finished.connect(_on_hunt_finished)
	hunt.start(self, wolf, doe, cover)


func _on_hunt_finished(won: bool) -> void:
	if not won:
		await get_tree().create_timer(1.4, true, false, true).timeout
		await UI.game_over()
		return
	GameState.set_flag("wolf_killed")
	if doe != null and doe.alive:
		GameState.set_flag("doe_saved")
	GameState.unlock_lore("lore_wolf")
	GameState.set_objective("Skin the wolf, then take the doe.")
	_build_aftermath(true)
	SaveSystem.save_slot("auto")


## After the hunt (live, or rebuilt on a later visit): the body in the snow,
## blood, and what is left to do here.
func _build_aftermath(live: bool) -> void:
	if _aftermath_done:
		return
	_aftermath_done = true
	var at: Vector2 = wolf.global_position if live and wolf != null else CLEARING + Vector2(-160, -60)
	if not live:
		var body = add_prop("actors/wolf.png", at, 1.45, Vector2(50, 14))
		var spr: Sprite2D = body.get_child(0)
		spr.scale.y *= 0.62
		spr.modulate = Color(0.62, 0.6, 0.66)
		for i in 7:
			Fx.blood_decals(self, at + Vector2(randf_range(-80, 80), randf_range(-10, 30)), Vector2.ZERO, 1)
	if not GameState.has_flag("wolf_skinned"):
		_skin_spot = add_interactable(at + Vector2(0, 20), "Skin the wolf", _skin_wolf, 130.0)
	var doe_at = DOE_POS
	if live and doe != null:
		doe_at = doe.global_position
	elif not GameState.has_flag("doe_taken"):
		doe = Doe.new()
		doe.position = DOE_POS
		world.add_child(doe)
		if GameState.has_flag("doe_saved"):
			doe.freeze_in_fear()
		else:
			doe.lie_dead()
	if not GameState.has_flag("doe_taken"):
		_doe_spot = add_interactable(doe_at + Vector2(0, 20), "Take the doe", _take_doe, 120.0)
	elif doe != null:
		doe.visible = false


func _skin_wolf() -> void:
	await Dialogue.play("hunt_skin")
	if GameState.has_flag("wolf_skinned") and _skin_spot:
		_skin_spot.enabled = false
	_check_done()


func _take_doe() -> void:
	await Dialogue.play("hunt_take_doe")
	if GameState.has_flag("doe_taken"):
		if _doe_spot:
			_doe_spot.enabled = false
		if doe != null:
			var tw = doe.create_tween()
			tw.tween_property(doe, "modulate:a", 0.0, 0.6)
	_check_done()


func _check_done() -> void:
	if GameState.has_flag("wolf_skinned") and GameState.has_flag("doe_taken"):
		GameState.set_objective("Carry the doe home before full dark. Follow the path south.")


func _try_leave() -> void:
	if GameState.has_flag("wolf_skinned") and GameState.has_flag("doe_taken"):
		await Dialogue.play("ch01_exit")
		return
	if not GameState.has_flag("wolf_killed"):
		await Dialogue.play("ch01_exit_locked")
	else:
		await Dialogue.play("ch01_exit_unfinished")
	player.position.y -= 80


func on_enter() -> void:
	if not GameState.has_flag("ch01_intro_done"):
		GameState.set_flag("ch01_intro_done")
		await Dialogue.play("ch01_intro")
