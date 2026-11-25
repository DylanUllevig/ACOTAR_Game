extends Region
## The woods west of the manor, in eternal spring: oak and birch, bluebells
## and ferns, a clear brook running north to south with a footbridge where
## the trail crosses. Up the trail to the north-east, a glen with a pool and
## an old willow; west, past a stream, an arc of young birches (where she
## snares the Suriel); south-west, a hollow under the hills with a cave in
## its side, where the bonfires burn on Calanmai.
##
## Chapters 9 and 10: the ride with Lucien, and the Bogge (bogge_watch.gd).
## 14 and 15: the Suriel and the naga. 18 and 23: the glen. 20: Calanmai.

const Bogge := preload("res://scripts/world/regions/bogge_watch.gd")

const EAST := Vector2(5060, 1700)          # where the trail comes in from the manor
const TRAIL := Vector2(4200, 1660)         # the ride stops here when the cold comes
const CROSSING := Vector2(2640, 1600)      # the footbridge
const GROVE := Vector2(1150, 760)          # the clearing in the young birches
const GLEN := Vector2(3800, 700)           # the pool under the willow
const HOLLOW := Vector2(1400, 2700)        # Calanmai: the bonfire, the drums, the cave

var npc := {}
var _bogge: Node = null
var _suriel: Node2D = null
var _snare: Node2D = null
var _calanmai := false
var _revelers: Array = []


func build() -> void:
	surface = "grass"
	combat_allowed = true
	map_title = "The Spring Woods"
	map_base = Color(0.6, 0.74, 0.5)
	bounds = Rect2(0, 0, 5200, 3400)
	spawns = {
		"start": EAST, "manor": EAST, "trail": TRAIL, "grove": GROVE + Vector2(60, 300),
		"glen": GLEN + Vector2(-60, 330), "hollow": HOLLOW + Vector2(620, -380), "tree": GROVE + Vector2(-250, -120),
	}
	_calanmai = GameState.chapter == 20 and GameState.has_flag("ch20_sneak") and not GameState.has_flag("ch20_bonfire")
	pixel_ground(["forest_floor", "meadow", "lawn", "dirt", "water"], 53)
	_ground()
	enclose_bounds()
	add_sun(-30.0, Color(1.0, 0.95, 0.84), 0.5)
	_brook()
	_glen()
	_grove()
	_hollow()
	_trees()
	_undergrowth()
	_critters()
	terrain.build()
	add_rays(Color(1.0, 0.96, 0.8), 0.18, -0.45)
	set_post({"vignette": 0.3, "lift": Vector3(0.01, 0.014, 0.012), "gain": Vector3(0.99, 1.0, 0.98), "saturation": 1.07, "grain": 0.0})


func _ready() -> void:
	super._ready()
	add_light(Vector2(0, -30), Color(0.75, 0.8, 1.0), 0.3, 2.6, false, player)
	map_exit(EAST, "To the manor")
	add_trigger(Rect2(5150, 1350, 200, 700), _to_manor, false)
	_story()
	var night = Region.night_amount(GameState.hour) > 0.5
	if _calanmai:
		Audio.ambience("spring_night")
		Audio.music("calanmai", 2.0)
	else:
		Audio.ambience("spring_night" if night else "spring_day")
		Audio.music("spring_night" if night else "spring_woods", 3.0)


func sun_shadow(h: float) -> Vector4:
	var a = deg_to_rad(lerpf(-60.0, 60.0, clampf((h - 6.5) / 13.0, 0.0, 1.0)))
	var length = 0.4 + 0.7 * (1.0 - sin(clampf((h - 6.5) / 13.0, 0.0, 1.0) * PI))
	var alpha = 0.3 * smoothstep(6.0, 7.5, h) * (1.0 - smoothstep(19.0, 20.0, h))
	return Vector4(sin(a), -cos(a), length, alpha)


## Dappled green light by day, gold in the evening, a deep blue night.
func grade_for_hour(h: float) -> Dictionary:
	return Region.lerp_grade([
		[4.5, {"mod": Color(0.22, 0.26, 0.42), "sun": Color(0.45, 0.5, 0.8), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
		[6.0, {"mod": Color(0.42, 0.42, 0.5), "sun": Color(1.0, 0.72, 0.56), "sun_energy": 0.3, "rays": 0.2, "exposure": Color(1.0, 0.97, 0.97)}],
		[8.0, {"mod": Color(0.6, 0.63, 0.62), "sun": Color(1.0, 0.93, 0.8), "sun_energy": 0.45, "rays": 0.18, "exposure": Color(0.99, 0.99, 0.97)}],
		[13.0, {"mod": Color(0.66, 0.69, 0.66), "sun": Color(1.0, 0.97, 0.88), "sun_energy": 0.45, "rays": 0.16, "exposure": Color(0.98, 0.99, 0.97)}],
		[17.0, {"mod": Color(0.62, 0.6, 0.56), "sun": Color(1.0, 0.86, 0.64), "sun_energy": 0.5, "rays": 0.24, "exposure": Color(0.99, 0.97, 0.95)}],
		[19.2, {"mod": Color(0.46, 0.4, 0.46), "sun": Color(1.0, 0.66, 0.45), "sun_energy": 0.42, "rays": 0.26, "exposure": Color(1.0, 0.96, 0.95)}],
		[20.6, {"mod": Color(0.27, 0.29, 0.47), "sun": Color(0.55, 0.55, 0.85), "sun_energy": 0.06, "rays": 0.02, "exposure": Color(1.0, 1.0, 1.04)}],
		[22.0, {"mod": Color(0.22, 0.26, 0.42), "sun": Color(0.45, 0.5, 0.8), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
	], h)


# ------------------------------------------------------------------ layout
func _trail_pts() -> PackedVector2Array:
	return PackedVector2Array([Vector2(5400, 1700), EAST, Vector2(4600, 1640), TRAIL, Vector2(3600, 1720), Vector2(3100, 1600), CROSSING, Vector2(2200, 1560)])


func _grove_pts() -> PackedVector2Array:
	return PackedVector2Array([Vector2(2200, 1560), Vector2(1800, 1300), Vector2(1500, 1060), GROVE + Vector2(160, 160)])


func _glen_pts() -> PackedVector2Array:
	return PackedVector2Array([Vector2(3600, 1720), Vector2(3700, 1300), Vector2(3760, 1050), GLEN + Vector2(-40, 300)])


func _hollow_pts() -> PackedVector2Array:
	return PackedVector2Array([Vector2(2200, 1560), Vector2(2050, 2000), Vector2(1900, 2350), HOLLOW + Vector2(380, -160)])


func _brook_pts() -> PackedVector2Array:
	return PackedVector2Array([Vector2(2380, -200), Vector2(2460, 500), Vector2(2560, 1100), CROSSING, Vector2(2580, 2200), Vector2(2700, 2900), Vector2(2640, 3600)])


func _stream_pts() -> PackedVector2Array:
	return PackedVector2Array([Vector2(300, -200), Vector2(700, 300), Vector2(1100, 480), Vector2(1560, 760), Vector2(2000, 1100), Vector2(2470, 1200)])


func _ground() -> void:
	# glades of meadow among the trees; soft lawn round the pool in the glen
	terrain.paint_ellipse("meadow", GLEN, Vector2(620, 440), 80.0)
	terrain.paint_ellipse("lawn", GLEN, Vector2(470, 330), 40.0)
	terrain.paint_ellipse("meadow", GROVE, Vector2(400, 330), 60.0)
	terrain.paint_ellipse("meadow", HOLLOW, Vector2(640, 420), 70.0)
	terrain.paint_ellipse("dirt", HOLLOW, Vector2(330, 210), 30.0)
	terrain.paint_ellipse("meadow", Vector2(4300, 2700), Vector2(600, 380), 90.0)
	terrain.paint_ellipse("meadow", Vector2(800, 1900), Vector2(420, 300), 80.0)
	for pts in [_trail_pts(), _grove_pts(), _glen_pts(), _hollow_pts()]:
		terrain.paint_path("dirt", pts, 92.0, 12.0)
		map_line(Region.smooth_curve(pts, 20.0), Color(0.72, 0.6, 0.44), 56.0)


func _brook() -> void:
	add_brook(_brook_pts(), 150.0, [CROSSING, Vector2(2575, 2200)], 80.0)
	add_brook(_stream_pts(), 96.0, [Vector2(1560, 760), Vector2(2000, 1100)], 70.0)
	add_prop("props/footbridge.png", CROSSING + Vector2(0, 60), 1.0, Vector2.ZERO, Vector2.ZERO)
	add_prop("props/stepping_stones.png", Vector2(2575, 2200), 1.0, Vector2.ZERO, Vector2.ZERO)
	add_prop("props/stepping_stones.png", Vector2(1560, 760), 1.0, Vector2.ZERO, Vector2.ZERO, true)
	add_prop("props/stepping_stones.png", Vector2(2000, 1100), 1.0, Vector2.ZERO, Vector2.ZERO)
	for p in [Vector2(2470, 640), Vector2(2650, 900), Vector2(2470, 1900), Vector2(2700, 2600), Vector2(900, 420), Vector2(1800, 960)]:
		add_prop("props/reeds.png", p, 1.0, Vector2.ZERO, Vector2.ZERO, int(p.x) % 2 == 0)


func _glen() -> void:
	# the pool in the glen, ringed by oaks; the willow leans over its north end
	add_pond(GLEN, Vector2(300, 170), 16.0)
	add_prop("props/willow.png", GLEN + Vector2(-200, -230), 1.0, Vector2(30, 12), Vector2(50, 24))
	for p in [Vector2(-160, -20), Vector2(120, 40), Vector2(40, -60)]:
		add_prop("props/lily_pads.png", GLEN + p, 1.0, Vector2.ZERO, Vector2.ZERO, p.x > 0)
	for p in [Vector2(-520, 120), Vector2(520, 60), Vector2(380, -330), Vector2(-560, -260), Vector2(600, 330)]:
		add_prop("props/oak.png", GLEN + p, 1.0, Vector2(22, 9), Vector2(38, 20), p.x > 0)
	# starlight in the water: motes of every colour that drift and wink
	var motes = CPUParticles2D.new()
	motes.position = GLEN
	motes.amount = 40
	motes.lifetime = 3.0
	motes.preprocess = 3.0
	motes.texture = Art.tex("fx/mote.png")
	motes.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(220, 100)
	motes.gravity = Vector2(0, -4)
	motes.initial_velocity_min = 2
	motes.initial_velocity_max = 8
	motes.scale_amount_min = Art.PX
	motes.scale_amount_max = Art.PX
	var ramp = Gradient.new()
	ramp.set_color(0, Color(0.8, 0.9, 1.0, 0.0))
	ramp.add_point(0.3, Color(1.0, 0.85, 0.95, 0.9))
	ramp.add_point(0.7, Color(0.75, 1.0, 0.9, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 1.0, 0.8, 0.0))
	motes.color_ramp = ramp
	motes.z_index = -4
	add_child(motes)
	add_interactable(GLEN + Vector2(0, 220), "The pool", func(): await Dialogue.play("spring_pool_glen"), 110, "The glen")


func _grove() -> void:
	# young birches, tall and straight as pillars, in an arc round the back
	# and sides of the clearing. It is open to the south, so no crown roofs
	# over the snare or the fight with the naga.
	for i in 8:
		if i == 2:
			continue   # the big oak stands there
		var a = PI * 0.94 + PI * 1.12 * i / 7.0
		var p = GROVE + Vector2(cos(a) * 380, sin(a) * 250)
		add_prop("props/birch_s.png" if i % 3 == 1 else "props/birch.png", p, 1.0, Vector2(16, 7), Vector2(26, 14), i % 2 == 0)
	# the big oak she waits in
	add_prop("props/oak.png", GROVE + Vector2(-250, -180), 1.0, Vector2(22, 9), Vector2(38, 20))
	add_interactable(GROVE, "The birch grove", _grove_action, 120, "Birch grove")


func _hollow() -> void:
	add_prop("props/cave_mouth.png", HOLLOW + Vector2(-470, -150), 1.0, Vector2(60, 16), Vector2(160, 50))
	for i in 7:
		var a = PI * 0.15 + PI * 0.7 * i / 6.0
		add_prop("props/standing_stone.png", HOLLOW + Vector2(cos(a) * 520, -sin(a) * 300 + 120), 1.0, Vector2(14, 6), Vector2(30, 14), i % 2 == 0)
	map_poi(HOLLOW, "The hollow")
	if _calanmai or GameState.chapter == 19:
		# Fire Night: the great fire, the drums, and the dancers
		var fire = HOLLOW + Vector2(200, 40)
		add_prop("props/bonfire.png", fire, 1.0, Vector2(30, 10), Vector2(90, 30))
		if _calanmai:
			add_glow_lights("props/bonfire.png", fire, Color(1.0, 0.62, 0.3), 1.0, 1.0, false, 40.0, null, 1.0)
			var l = add_light(fire + Vector2(0, -60), Color(1.0, 0.58, 0.28), 1.2, 4.0, false)
			add_flicker(l, 0.22, 8.0)
			add_smoke(fire + Vector2(0, -150), null, 14)
		for p in [Vector2(-220, 140), Vector2(-110, 190), Vector2(0, 210)]:
			add_prop("props/drum.png", HOLLOW + p, 1.0, Vector2(14, 6), Vector2(30, 16))
	else:
		add_prop("props/campfire.png", HOLLOW + Vector2(200, 40), 1.0, Vector2.ZERO, Vector2(50, 20))


func _blocked(p: Vector2) -> bool:
	if p.distance_to(GLEN) < 560.0 or p.distance_to(GROVE) < 360.0 or p.distance_to(HOLLOW) < 620.0:
		return true
	for line in [_trail_pts(), _grove_pts(), _glen_pts(), _hollow_pts(), _brook_pts(), _stream_pts()]:
		for k in range(line.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, line[k], line[k + 1]).distance_to(p) < 130.0:
				return true
	return p.x > 5050.0 and absf(p.y - 1700.0) < 260.0


func _trees() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 7171
	var placed: Array[Vector2] = []
	var tries = 0
	while placed.size() < 150 and tries < 6000:
		tries += 1
		var p = Vector2(rng.randf_range(40, bounds.size.x - 40), rng.randf_range(60, bounds.size.y - 30))
		if _blocked(p):
			continue
		var ok = true
		for q in placed:
			if q.distance_to(p) < 200:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var r = rng.randf()
		var rel: String
		if p.x < 1900.0 and r < 0.6:
			rel = ["props/birch.png", "props/birch_s.png"][rng.randi_range(0, 1)]
		elif r < 0.18:
			rel = ["props/blossom_white.png", "props/blossom_pink_s.png", "props/blossom_white_s.png"][rng.randi_range(0, 2)]
		else:
			rel = ["props/oak.png", "props/oak_s.png", "props/oak.png"][rng.randi_range(0, 2)]
		var flip = rng.randf() < 0.5
		if _roofs_grove(p):
			continue
		add_prop(rel, p, 1.0, Vector2(22, 9), Vector2(38, 20), flip)


## A crown standing south of the grove would roof over the clearing where the
## Suriel is snared and the naga come out, and hide the fight. Those trees are
## left out; their places still count, so the rest of the wood keeps its shape.
func _roofs_grove(p: Vector2) -> bool:
	return absf(p.x - GROVE.x) < 540.0 and p.y > GROVE.y - 160.0 and p.y < GROVE.y + 780.0


func _undergrowth() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 4242
	var kinds = ["props/fern_spring.png", "props/bluebells.png", "props/tall_grass.png", "props/fern_spring.png", "props/mushroom_ring.png",
		"props/mossy_rock.png", "props/toadstool.png", "props/daisies.png", "props/bluebells.png", "props/flower_log.png", "props/root_stump.png"]
	for i in 230:
		var p = Vector2(rng.randf_range(40, bounds.size.x - 40), rng.randf_range(60, bounds.size.y - 30))
		if p.distance_to(GLEN) < 340.0 or p.distance_to(GROVE) < 150.0 or p.distance_to(HOLLOW) < 360.0:
			continue
		var on_path = false
		for line in [_trail_pts(), _grove_pts(), _glen_pts(), _hollow_pts()]:
			for k in range(line.size() - 1):
				if Geometry2D.get_closest_point_to_segment(p, line[k], line[k + 1]).distance_to(p) < 70.0:
					on_path = true
		if on_path:
			continue
		var rel: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var solid = Vector2(40, 16) if rel.contains("rock") or rel.contains("log") or rel.contains("stump") else Vector2.ZERO
		add_prop(rel, p, 1.0, Vector2.ZERO, solid, rng.randf() < 0.5)
	# bluebells thick round the glen
	for i in 18:
		var a = rng.randf() * TAU
		add_prop("props/bluebells.png", GLEN + Vector2(cos(a) * rng.randf_range(380, 520), sin(a) * rng.randf_range(260, 360)), 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)


func _critters() -> void:
	for p in [Vector2(3300, 900), Vector2(4500, 1300), Vector2(1600, 1900), Vector2(3900, 2600), GLEN + Vector2(300, 260)]:
		add_critter("butterfly_white" if int(p.y) % 2 == 0 else "butterfly_yellow", p)
	for p in [Vector2(4700, 1200), Vector2(3000, 2500), Vector2(900, 1500)]:
		add_critter("bluebird", p)
	for p in [Vector2(4000, 900), Vector2(1700, 2200)]:
		add_critter("robin", p)
	for p in [Vector2(3300, 1300), Vector2(800, 2400), Vector2(4600, 2900)]:
		add_critter("squirrel", p)
	for p in [Vector2(4300, 2700), Vector2(700, 1900)]:
		add_critter("rabbit", p)
	add_critter("fox", Vector2(3500, 3000))
	add_critter("stag", Vector2(4500, 600))


# ------------------------------------------------------------------- story
func _story() -> void:
	var ch = GameState.chapter
	if ch in [9, 10] and not GameState.has_flag("ch10_bogge_done"):
		npc.lucien = add_npc("courtier_red", TRAIL + Vector2(-110, 10), "", Callable(), 3)
		_horse(TRAIL + Vector2(160, -150), false)
		_horse(TRAIL + Vector2(330, -120), true)
	if ch == 18 and not GameState.has_flag("ch18_glen"):
		npc.tamlin = add_npc("lord_gold", GLEN + Vector2(80, 280), "", Callable(), 1)
		npc.lucien = add_npc("courtier_red", GLEN + Vector2(-260, 340), "", Callable(), 2)
	if ch == 23 and not GameState.has_flag("ch23_glen"):
		npc.tamlin = add_npc("lord_gold", GLEN + Vector2(40, 300), "", Callable(), 1)
	if ch == 14 and GameState.has_flag("ch14_snare") and not GameState.has_flag("ch15_naga_done"):
		# back after a fall: the snare is sprung, the Suriel caught in it
		_set_snare()
		_suriel_in_snare()
	if _calanmai:
		_calanmai_crowd()
		add_trigger(Rect2(HOLLOW - Vector2(700, 500), Vector2(1400, 900)), func(): await Dialogue.play("ch20_bonfire"))


func on_enter() -> void:
	var ch = GameState.chapter
	if ch in [9, 10] and not GameState.has_flag("ch10_bogge_done"):
		if not GameState.has_flag("ch09_rode"):
			await Dialogue.play("ch09_ride")
		else:
			start_bogge()
	elif ch == 14 and GameState.has_flag("ch14_snare") and not GameState.has_flag("ch15_naga_done"):
		start_fight("naga_snare")
	elif ch == 18 and not GameState.has_flag("ch18_glen"):
		await Dialogue.play("ch18_glen")
	elif ch == 20 and _calanmai and not GameState.has_flag("ch20_woods"):
		GameState.set_flag("ch20_woods")
		await Dialogue.play("ch20_woods")
	elif ch == 23 and not GameState.has_flag("ch23_glen"):
		await Dialogue.play("ch23_glen")


func _to_manor() -> void:
	if GameState.chapter in [9, 10] and not GameState.has_flag("ch10_bogge_done"):
		return
	if hunt != null:
		return
	Router.goto_region("spring_manor", "woods")


## A horse standing tethered (the white mare's sheet, its standing frame).
func _horse(pos: Vector2, flip: bool) -> void:
	var rel = "actors/mare.png"
	var s = Sprite2D.new()
	s.texture = Art.lit(rel)
	if s.texture == null:
		return
	var m = Art.pixel_meta(rel)
	var g: Array = m.get("grid", [1, 1])
	s.hframes = int(g[0])
	s.vframes = int(g[1])
	s.frame = int(m.get("anims", {}).get("stand", [0])[0])
	s.scale = Art.sprite_scale(rel)
	s.offset = Vector2(0, -s.texture.get_height() / (2.0 * s.vframes))
	s.flip_h = flip
	var h = Node2D.new()
	h.position = pos
	h.add_child(s)
	world.add_child(h)


# ---------------------------------------------------- chapters 9 and 10
## The cold comes through the brush: see bogge_watch.gd.
func start_bogge() -> void:
	if _bogge != null:
		return
	GameState.set_flag("ch09_rode")
	SaveSystem.save_slot("auto")
	place_player("trail")
	_bogge = Bogge.new()
	add_child(_bogge)
	_bogge.finished.connect(_on_bogge_done)
	_bogge.start(self)


func _on_bogge_done(ok: bool) -> void:
	_bogge = null
	if not ok:
		await get_tree().create_timer(0.8, true, false, true).timeout
		await UI.game_over("She Looked", "The moment she saw it, it was real. And then it was on her.", "Keep your eyes ahead. When the cold drags at one side, push the other way before your gaze slides round to it.")
		return
	GameState.set_flag("ch10_bogge_done")
	await Dialogue.play("ch10_after")


# ---------------------------------------------------- chapters 14 and 15
func _grove_action() -> void:
	var ch = GameState.chapter
	if ch == 14 and not GameState.has_flag("ch14_snare"):
		if not GameState.has_item("chicken"):
			await Dialogue.play("ch14_no_bait")
			return
		await Dialogue.play("ch14_snare")
		return
	await Dialogue.play("spring_grove")


## The double-loop snare, the hen laid out as if it had blundered in.
func _set_snare() -> void:
	if _snare != null:
		return
	_snare = add_prop("props/snare.png", GROVE + Vector2(20, 30), 1.0, Vector2.ZERO, Vector2.ZERO)
	add_prop("props/dead_chicken.png", GROVE + Vector2(-30, 40), 1.0, Vector2.ZERO, Vector2.ZERO)


## region_call: she lays the snare, then climbs the oak and waits; the
## afternoon wears on, and something walks into it (the scene plays its scream).
func snare_and_wait() -> void:
	_set_snare()
	await UI.fade_out(0.8)
	place_player("tree")
	player.facing = 2
	GameState.hour = 16.5
	_suriel_in_snare()
	await get_tree().create_timer(0.6, true, false, true).timeout
	await UI.fade_in(0.9)


func _suriel_in_snare() -> void:
	if _suriel != null:
		return
	var rel = "actors/suriel.png"
	var s = Sprite2D.new()
	s.texture = Art.lit(rel)
	if s.texture == null:
		return
	var m = Art.pixel_meta(rel)
	var g: Array = m.get("grid", [1, 1])
	s.hframes = int(g[0])
	s.vframes = int(g[1])
	s.frame = int(m.get("anims", {}).get("snared", [2])[0])
	s.scale = Art.sprite_scale(rel)
	s.offset = Vector2(0, -s.texture.get_height() / (2.0 * s.vframes))
	_suriel = Node2D.new()
	_suriel.position = GROVE + Vector2(0, 40)
	_suriel.add_child(s)
	world.add_child(_suriel)
	_suriel.set_meta("spr", s)


## region_call: the Suriel turns its face to her and speaks.
func suriel_speaks() -> void:
	if _suriel == null:
		return
	var s: Sprite2D = _suriel.get_meta("spr")
	s.frame = int(Art.pixel_meta("actors/suriel.png").get("anims", {}).get("speak", [1])[0])
	place_player("grove")
	player.facing = 3


## region_call: her arrow cuts the tether and it is gone like a shadow.
func suriel_flees() -> void:
	if _suriel == null:
		return
	Audio.sfx("bow_release", -4.0)
	if _snare != null:
		_snare.queue_free()
		_snare = null
	var tw = create_tween()
	tw.tween_property(_suriel, "modulate", Color(0.1, 0.1, 0.15, 0.0), 0.5)
	tw.parallel().tween_property(_suriel, "position", _suriel.position + Vector2(-300, -120), 0.5)
	await tw.finished
	_suriel.queue_free()
	_suriel = null


## A stand-up fight here: the naga come out of the birches.
func start_fight(id: String) -> void:
	if hunt != null:
		return
	SaveSystem.save_slot("auto")
	var pts = [GROVE + Vector2(-320, -60), GROVE + Vector2(300, -120), GROVE + Vector2(-200, 260), GROVE + Vector2(320, 220)]
	hunt = Encounter.new()
	hunt.name = "Fight"
	add_child(hunt)
	hunt.finished.connect(_on_fight_done.bind(id))
	hunt.start(self, id, pts)


func _on_fight_done(won: bool, id: String) -> void:
	hunt = null
	if not won:
		await get_tree().create_timer(1.4, true, false, true).timeout
		await UI.game_over("Bled Slow", "The naga had their sport after all.", "Watch for the rear-back before they lunge, and keep moving so only one can reach you. A hard hit while one rears up staggers it.")
		return
	if id == "naga_snare":
		GameState.set_flag("ch15_naga_done")
		await Dialogue.play("ch15_after")


# ------------------------------------------------------------ chapter 20
## Masked dancers round the fire, drummers at the drums.
func _calanmai_crowd() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20
	var c = HOLLOW + Vector2(200, 60)
	for i in 12:
		var a = TAU * i / 12.0
		var p = c + Vector2(cos(a) * 260, sin(a) * 140)
		var r = add_npc("fae_reveler", p, "", Callable(), rng.randi_range(0, 3))
		_revelers.append(r)
		var q = c + Vector2(cos(a + 0.8) * 260, sin(a + 0.8) * 140)
		var tw = r.create_tween().set_loops()
		tw.tween_property(r, "position", q, rng.randf_range(1.8, 2.8)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(r, "position", p, rng.randf_range(1.8, 2.8)).set_trans(Tween.TRANS_SINE)
	for p in [Vector2(-220, 100), Vector2(-110, 150), Vector2(0, 170)]:
		add_npc("fae_reveler", HOLLOW + p + Vector2(0, -30), "", Callable(), 0)


## region_call: three of them peel away from the dancing and close in.
func faeries_close_in() -> void:
	var p = player.global_position
	var spots = [p + Vector2(-90, 10), p + Vector2(90, 10), p + Vector2(0, 80)]
	for i in 3:
		var f = add_npc("fae_reveler", p + (spots[i] - p) * 3.0, "", Callable(), 0)
		npc["faerie_%d" % i] = f
		walk_npc(f, spots[i], 200.0)
	await get_tree().create_timer(0.9, true, false, true).timeout


## region_call: a stranger's arm round her shoulders; the three melt away.
func stranger_arrives() -> void:
	var p = player.global_position
	npc.rhys = add_npc("lord_night", p + Vector2(-70, -10), "", Callable(), 2)
	npc.rhys.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(npc.rhys, "modulate:a", 1.0, 0.4)
	for i in 3:
		var k = "faerie_%d" % i
		if npc.has(k) and is_instance_valid(npc[k]):
			var f: Node2D = npc[k]
			var tw = create_tween()
			tw.tween_property(f, "position", f.position + (f.position - p).normalized() * 400.0, 0.9)
			tw.parallel().tween_property(f, "modulate:a", 0.0, 0.9)
			tw.tween_callback(f.queue_free)
	await get_tree().create_timer(0.6, true, false, true).timeout


## region_call: he is simply gone.
func stranger_leaves() -> void:
	if npc.has("rhys") and is_instance_valid(npc.rhys):
		var tw = create_tween()
		tw.tween_property(npc.rhys, "modulate", Color(0.2, 0.15, 0.3, 0.0), 0.5)
		await tw.finished
		npc.rhys.queue_free()
		npc.erase("rhys")


# ------------------------------------------------------------ chapter 23
var _halo: PointLight2D = null

## region_call: he kisses her eyelids and the glen shows itself as it is.
## The colour deepens, the air glitters, and he shines.
func faerie_sight() -> void:
	var m := post.material as ShaderMaterial
	create_tween().tween_method(func(v): m.set_shader_parameter("saturation", v), 1.07, 1.32, 2.4)
	var glints = CPUParticles2D.new()
	glints.position = player.global_position + Vector2(0, -40)
	glints.amount = 70
	glints.lifetime = 4.0
	glints.preprocess = 2.0
	glints.texture = Art.tex("fx/mote.png")
	glints.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glints.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	glints.emission_rect_extents = Vector2(620, 360)
	glints.gravity = Vector2(0, -3)
	glints.initial_velocity_min = 1
	glints.initial_velocity_max = 6
	glints.scale_amount_min = Art.PX
	glints.scale_amount_max = Art.PX
	var ramp = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.92, 0.75, 0.9))
	ramp.add_point(0.7, Color(0.8, 1.0, 0.85, 0.7))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	glints.color_ramp = ramp
	glints.z_index = 30
	add_child(glints)
	if npc.has("tamlin") and is_instance_valid(npc.tamlin):
		_halo = add_light(Vector2(0, -70), Color(1.0, 0.84, 0.46), 0.0, 1.6, false, npc.tamlin)
		create_tween().tween_property(_halo, "energy", 1.2, 2.0)
	await get_tree().create_timer(1.2, true, false, true).timeout


## region_call: he wills his glamour back into place. The glen keeps its new
## colour; only his light goes out.
func glamour_back() -> void:
	if _halo != null and is_instance_valid(_halo):
		create_tween().tween_property(_halo, "energy", 0.0, 0.5)
