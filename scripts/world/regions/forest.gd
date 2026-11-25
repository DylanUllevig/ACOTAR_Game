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
const APPROACH := Rect2(CLEARING - Vector2(700, 500), Vector2(1400, 1000))
const HARES := [Vector2(1320, 2180), Vector2(1960, 1820), Vector2(560, 1480), Vector2(2900, 2060), Vector2(3640, 1720)]
const ROSES := [Vector2(1010, 2040), Vector2(1720, 1690), Vector2(2280, 1430), Vector2(1330, 1330), Vector2(3420, 1530)]
# places to search: deer sign, the old snare, the fallen log, the creek bank
const POIS := [Vector2(1180, 1880), Vector2(1560, 1600), Vector2(2060, 1530), Vector2(3900, 1180)]

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
	pixel_ground(["snow", "trodden", "dirt", "ice"], 11)
	enclose_bounds()
	add_sun(-37.0, Color(1, 0.92, 0.8), 0.55)
	_build_path()
	_build_brook()
	_scatter_trees()
	_build_clearing()
	_build_points_of_interest()
	_build_roses()
	_scatter_undergrowth()
	_add_critters()
	terrain.build()
	add_snow(260, Vector2(50, 0))
	add_fog(bounds.grow(400), Color(0.84, 0.88, 0.98), 0.14, 50, 0.0018)
	add_rays(Color(1.0, 0.88, 0.7), 0.16, -0.5)
	set_post({"vignette": 0.32, "lift": Vector3(0.01, 0.015, 0.03), "gain": Vector3(1.0, 1.0, 1.02), "saturation": 1.06, "grain": 0.0})


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


## Bright, clear winter light (the pixel world reads best well lit), warm low
## sun against cool shade, a golden hour before dusk and a blue night that
## stays readable. 'exposure' is a per-channel gain applied after the lights.
func grade_for_hour(h: float) -> Dictionary:
	return Region.lerp_grade([
		[6.0, {"mod": Color(0.22, 0.25, 0.42), "sun": Color(0.4, 0.45, 0.7), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
		[8.0, {"mod": Color(0.5, 0.5, 0.62), "sun": Color(1.0, 0.78, 0.6), "sun_energy": 0.45, "rays": 0.12, "exposure": Color(0.96, 0.95, 0.97)}],
		[13.0, {"mod": Color(0.62, 0.66, 0.76), "sun": Color(1.0, 0.95, 0.86), "sun_energy": 0.42, "rays": 0.14, "exposure": Color(0.97, 0.97, 0.98)}],
		[15.5, {"mod": Color(0.58, 0.57, 0.64), "sun": Color(1.0, 0.86, 0.66), "sun_energy": 0.48, "rays": 0.2, "exposure": Color(0.96, 0.95, 0.95)}],
		[16.6, {"mod": Color(0.5, 0.46, 0.48), "sun": Color(1.0, 0.72, 0.46), "sun_energy": 0.55, "rays": 0.28, "exposure": Color(0.97, 0.95, 0.94)}],
		[17.4, {"mod": Color(0.3, 0.32, 0.5), "sun": Color(0.6, 0.55, 0.85), "sun_energy": 0.15, "rays": 0.04, "exposure": Color(0.96, 0.96, 1.0)}],
		[19.0, {"mod": Color(0.22, 0.25, 0.42), "sun": Color(0.4, 0.45, 0.7), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
	], h)


# ------------------------------------------------------------------ layout
func _path_points() -> Array:
	return [Vector2(760, 2700), Vector2(760, 2300), Vector2(1100, 1900), Vector2(1500, 1600), Vector2(2000, 1500), Vector2(2400, 1300), BRAMBLES + Vector2(-60, 60), CLEARING + Vector2(-120, 60)]


## The brook's course, west to east, from where it comes out from under the
## snow to the edge of the map.
func _brook_points() -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in 30:
		var t = i / 29.0
		pts.append(Vector2(2300 + t * 1900, 400 + t * 900 + sin(t * 9.0) * 70))
	return pts


func _build_path() -> void:
	# the trodden way home; it runs on past the south edge so it does not end
	# where she leaves
	var pts = PackedVector2Array(_path_points())
	map_line(Region.smooth_curve(pts, 20.0), Color(0.66, 0.56, 0.44, 0.75), 30.0)
	pts.insert(0, Vector2(760, 2950))
	terrain.paint_path("trodden", pts, 150.0, 30.0)
	# worn down to frozen earth along the middle, where most feet go
	terrain.paint_path("dirt", pts, 78.0, 14.0)


func _build_brook() -> void:
	# a half-frozen brook between muddy banks; it runs on past the east edge
	var pts = _brook_points()
	map_line(pts, Color(0.45, 0.6, 0.8, 0.9), 60.0)
	var run = PackedVector2Array(pts)
	var last = pts[pts.size() - 1]
	run.append(last + (last - pts[pts.size() - 2]).normalized() * 320.0)
	terrain.paint_path("dirt", run, 205.0, 46.0)
	terrain.paint_path("ice", run, 140.0, 26.0)


func _scatter_trees() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 1600
	var placed: Array[Vector2] = []
	var brook = _brook_points()
	var tries = 0
	while placed.size() < 150 and tries < 4000:
		tries += 1
		var p = Vector2(rng.randf_range(40, bounds.size.x - 40), rng.randf_range(60, bounds.size.y - 20))
		if p.distance_to(CLEARING) < 520:
			continue
		if p.distance_to(BRAMBLES) < 240:
			continue
		# nor just south of the thicket, where its crown would stand in front
		# of where she hides
		if absf(p.x - BRAMBLES.x) < 360.0 and p.y > BRAMBLES.y and p.y - BRAMBLES.y < 480.0:
			continue
		if _near_path(p, 150) or _near_line(brook, p, 170):
			continue
		var near_spot = false
		for q in HARES + ROSES:
			if p.distance_to(q) < 110:
				near_spot = true
		# nor just in front of a rose bush or a place to search, where its
		# crown would hide it (a pine stands up to 460 px tall and 300 wide)
		for q in ROSES + POIS:
			if absf(q.x - p.x) < 120.0 and p.y > q.y and p.y - q.y < 420.0:
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
			# mostly tall pines, with younger ones among them
			var kind = [0, 0, 0, 1, 1, 2, 3, 4][rng.randi_range(0, 7)]
			add_prop("props/pine_%d.png" % kind, p, rng.randf_range(0.9, 1.35), Vector2(16, 7), Vector2(28, 18), rng.randf() < 0.5)
		elif r < 0.92:
			add_prop("props/bare_tree_%d.png" % rng.randi_range(0, 1), p, rng.randf_range(0.9, 1.2), Vector2(12, 6), Vector2(22, 16), rng.randf() < 0.5)
		else:
			add_prop("props/rock_%d.png" % rng.randi_range(0, 1), p, rng.randf_range(0.8, 1.3), Vector2(46, 18), Vector2(90, 40))


func _near_path(p: Vector2, d: float) -> bool:
	return _near_line(PackedVector2Array(_path_points()), p, d)


static func _near_line(pts: PackedVector2Array, p: Vector2, d: float) -> bool:
	for i in range(pts.size() - 1):
		var c = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		if c.distance_to(p) < d:
			return true
	return false


func _build_clearing() -> void:
	# deer have trampled the snow where the doe feeds
	terrain.paint_ellipse("trodden", CLEARING + Vector2(-40, -20), Vector2(360, 230), 70.0)
	# the thicket she hides in: thorny, slow to push through, but it hides her
	if Art.is_pixel("props/bramble.png"):
		for i in 2:
			add_prop("props/bramble.png", BRAMBLES + Vector2(-105 + i * 210, -36), 1.0, Vector2.ZERO, Vector2.ZERO, i == 1)
		add_prop("props/bramble.png", BRAMBLES + Vector2(10, 26), 1.0, Vector2.ZERO, Vector2.ZERO, true)
	else:
		for i in 5:
			add_prop("props/bramble.png", BRAMBLES + Vector2(-150 + i * 75, (i % 2) * 18), 1.15, Vector2.ZERO)
		for i in 3:
			add_prop("props/bramble.png", BRAMBLES + Vector2(-110 + i * 110, -52), 1.0, Vector2.ZERO, Vector2.ZERO, i == 1)
	cover = [Rect2(BRAMBLES + Vector2(-200, -90), Vector2(400, 130))]
	map_poi(BRAMBLES, "Bramble thicket")
	map_poi(CLEARING, "The clearing")


## Logs, stumps, holly, rocks, ferns and dead grass between the trees, kept
## off the path, the brook and the places she needs to reach; reeds along the
## brook; small finds (pine cones, a fallen branch) scattered about.
func _scatter_undergrowth() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 2207
	var brook = _brook_points()
	var kinds = [["props/stump.png", Vector2(30, 10), Vector2(50, 22)], ["props/log.png", Vector2(60, 12), Vector2(120, 26)],
		["props/holly.png", Vector2(40, 12), Vector2.ZERO], ["props/rock_1.png", Vector2(30, 10), Vector2(56, 22)],
		["props/holly.png", Vector2(40, 12), Vector2.ZERO], ["props/root_stump.png", Vector2(40, 12), Vector2(70, 24)],
		["props/fern.png", Vector2.ZERO, Vector2.ZERO], ["props/snow_mound.png", Vector2.ZERO, Vector2.ZERO],
		["props/rose_bush_bare.png", Vector2(30, 10), Vector2.ZERO]]
	var n = 0
	var tries = 0
	while n < 60 and tries < 3000:
		tries += 1
		var p = Vector2(rng.randf_range(80, bounds.size.x - 80), rng.randf_range(120, bounds.size.y - 60))
		if p.distance_to(CLEARING) < 430 or p.distance_to(BRAMBLES) < 260:
			continue
		if _near_path(p, 120) or _near_line(brook, p, 150):
			continue
		var blocked = false
		for q in HARES + ROSES + POIS:
			if p.distance_to(q) < 150:
				blocked = true
		if blocked:
			continue
		var k = kinds[rng.randi_range(0, kinds.size() - 1)]
		if not Art.is_pixel(k[0]):
			continue
		add_prop(k[0], p, 1.0, k[1], k[2], rng.randf() < 0.5)
		n += 1
	# ground litter that never blocks the way: tufts, cones, a branch here and there
	var litter = ["props/grass_tuft.png", "props/grass_tuft.png", "props/pinecones.png", "props/branch.png"]
	for i in 70:
		var p = Vector2(rng.randf_range(60, bounds.size.x - 60), rng.randf_range(80, bounds.size.y - 40))
		if p.distance_to(CLEARING) < 300 or _near_line(brook, p, 110):
			continue
		var rel = litter[rng.randi_range(0, litter.size() - 1)]
		if Art.is_pixel(rel):
			add_prop(rel, p, 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)
	# reeds where the banks are soft
	for i in range(2, brook.size() - 1, 3):
		var a: Vector2 = brook[i]
		var side = 1.0 if i % 2 == 0 else -1.0
		var q = a + Vector2(rng.randf_range(-30, 30), side * rng.randf_range(95, 120))
		if Art.is_pixel("props/reeds.png") and not _near_path(q, 90):
			add_prop("props/reeds.png", q, 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)


## Birds, squirrels and a sleeping fox: the wood is hungry but not empty.
func _add_critters() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 909
	var spots: Array[Vector2] = []
	for i in 40:
		var p = Vector2(rng.randf_range(150, bounds.size.x - 150), rng.randf_range(150, bounds.size.y - 120))
		if p.distance_to(CLEARING) < 600 or p.distance_to(BRAMBLES) < 400:
			continue   # nothing to startle the doe or spoil the hunt
		spots.append(p)
	for i in range(mini(spots.size(), 12)):
		var kind = ["crow", "crow", "robin", "squirrel", "robin", "crow"][i % 6]
		add_critter(kind, spots[i])
	if spots.size() > 12:
		add_critter("fox", spots[12])


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
	add_interactable(POIS[0], "Read the signs", func(): await Dialogue.play("ch01_tracks"), 90.0, "Deer sign")
	add_prop("props/rock_1.png", POIS[1] + Vector2(0, -40), 0.9, Vector2(40, 14), Vector2(80, 30))
	add_interactable(POIS[1], "Check the old snare", func(): await Dialogue.play("ch01_snare"), 90.0, "Old snare")
	add_interactable(POIS[2], "Rest a moment", func(): await Dialogue.play("ch01_ash_lore"), 90.0, "Fallen log")
	add_interactable(POIS[3], "Search the creek bank", func(): await Dialogue.play("ch01_wire"), 110.0, "Creek bank")
	map_exit(EXIT, "Home")
	# the approach: at the clearing's edge she sees the doe, and the eyes. Kept
	# clear of the rose bushes, the fallen log and the creek bank, so those can
	# be found before the hunt without being pulled into it.
	add_trigger(APPROACH, func():
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
	spr.scale *= Art.density("props/rose_bush_bare.png") / Art.density("props/rose_bush.png")
	spr.texture = Art.lit("props/rose_bush_bare.png")
	spr.offset = Vector2(0, -spr.texture.get_height() / 2.0)
	(_rose_spots[i] as Area2D).enabled = false
	if not GameState.has_flag("hint_rose_hips"):
		GameState.set_flag("hint_rose_hips")
		# they land in the first free slot, which is usually on the hotbar
		var at := -1
		for s in GameState.hotbar_size():
			var st = GameState.slot(s)
			if st != null and st.id == "rose_hips":
				at = s
				break
		if at >= 0:
			UI.toast("Rose hips heal a little. Choose them on the hotbar (key %d) and click to eat." % ((at + 1) % 10))
		else:
			UI.toast("Rose hips heal a little. Move them to the hotbar in the satchel (Tab), then click to eat.")


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
		if Art.tex("actors/wolf_dead.png") != null:
			# lying on his side: a shadow under his whole length, not a cast
			# silhouette, which would stand him up again
			var carcass = add_prop("actors/wolf_dead.png", at, 1.45, Vector2.ZERO)
			var spr: Sprite2D = carcass.get_child(0)
			spr.modulate = Color(0.86, 0.84, 0.88)
			var fit = Creature.lying_shadow(spr)
			var sh = Sprite2D.new()
			sh.texture = Art.tex("fx/shadow.png")
			sh.modulate = Color(0.05, 0.06, 0.12, 0.75)
			sh.z_index = -1
			sh.scale = fit[0]
			sh.position = fit[1]
			carcass.add_child(sh)
		else:
			var body = add_prop("actors/wolf.png", at, 1.45, Vector2(50, 14))
			var spr: Sprite2D = body.get_child(0)
			spr.scale.y *= 0.62
			spr.modulate = Color(0.62, 0.6, 0.66)
		# the blood pools under his body, not below his paws
		for i in 7:
			Fx.blood_decals(self, at + Vector2(randf_range(-90, 90), randf_range(-60, -10)), Vector2.ZERO, 1)
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
