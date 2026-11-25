extends Region
## Chapter 30: the village in high summer. The same square with its dry
## fountain, the same roads in from the west and out to the east, but green
## now, with flowers in the window boxes. Down at the bottom of the village
## runs the poor lane, where the roofs sag and the mud never quite dries:
## four doors there get a purse of silver. Tomas Mandray holds court at the
## fountain; Isaac Hale comes round the corner with his bride.

const SQUARE := Vector2(1500, 860)
const LANE_Y := 1640.0                       # the poor lane
const POOR_DOORS := [Vector2(330, 1556), Vector2(640, 1548), Vector2(950, 1560), Vector2(1250, 1552)]
const PURSE_IDS := ["a", "b", "c", "d"]

var npc := {}
var _doors := {}


func build() -> void:
	surface = "grass"
	combat_allowed = false
	map_title = "The Village"
	map_base = Color(0.68, 0.76, 0.52)
	bounds = Rect2(0, 0, 3000, 2000)
	spawns = {"start": Vector2(150, 930), "west": Vector2(150, 930), "east": Vector2(2860, 880)}
	pixel_ground(["grass", "lawn", "mud", "dirt", "cobble"], 30)
	_ground()
	enclose_bounds()
	add_sun(-35.0, Color(1.0, 0.95, 0.84), 0.5)
	_houses()
	_square()
	_poor_lane()
	_details()
	_trees()
	_people()
	_critters()
	terrain.smooth_edges = true
	terrain.build()
	add_rays(Color(1.0, 0.94, 0.8), 0.14, -0.25)
	set_post({"vignette": 0.28, "lift": Vector3(0.014, 0.012, 0.016), "gain": Vector3(1.01, 1.0, 0.98), "saturation": 1.06, "grain": 0.0})


func _ready() -> void:
	super._ready()
	map_exit(Vector2(2940, 880), "Home to the chateau")
	map_poi(SQUARE, "Market square")
	map_poi(Vector2(960, LANE_Y), "The poor lane")
	Audio.ambience("village")
	Audio.music("village", 3.0)


func on_enter() -> void:
	if not GameState.has_flag("ch30_village"):
		await Dialogue.play("ch30_village")


func sun_shadow(h: float) -> Vector4:
	var a = deg_to_rad(lerpf(-62.0, 62.0, clampf((h - 6.0) / 14.0, 0.0, 1.0)))
	var length = 0.4 + 0.75 * (1.0 - sin(clampf((h - 6.0) / 14.0, 0.0, 1.0) * PI))
	var alpha = 0.28 * smoothstep(5.5, 7.0, h) * (1.0 - smoothstep(19.5, 20.5, h))
	return Vector4(sin(a), -cos(a), length, alpha)


func grade_for_hour(h: float) -> Dictionary:
	return Region.lerp_grade([
		[6.0, {"mod": Color(0.5, 0.45, 0.52), "sun": Color(1.0, 0.72, 0.55), "sun_energy": 0.3, "rays": 0.2, "exposure": Color(1.0, 0.97, 0.96)}],
		[9.0, {"mod": Color(0.67, 0.67, 0.66), "sun": Color(1.0, 0.93, 0.8), "sun_energy": 0.44, "rays": 0.14, "exposure": Color(0.99, 0.98, 0.96)}],
		[13.0, {"mod": Color(0.72, 0.72, 0.7), "sun": Color(1.0, 0.97, 0.88), "sun_energy": 0.46, "rays": 0.12, "exposure": Color(0.99, 0.98, 0.96)}],
		[17.0, {"mod": Color(0.7, 0.64, 0.58), "sun": Color(1.0, 0.86, 0.62), "sun_energy": 0.52, "rays": 0.2, "exposure": Color(1.0, 0.97, 0.94)}],
		[19.4, {"mod": Color(0.54, 0.44, 0.48), "sun": Color(1.0, 0.64, 0.42), "sun_energy": 0.46, "rays": 0.24, "exposure": Color(1.0, 0.96, 0.95)}],
		[21.0, {"mod": Color(0.3, 0.31, 0.5), "sun": Color(0.55, 0.55, 0.85), "sun_energy": 0.06, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
	], h)


func _road_w() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-200, 935), Vector2(400, 940), Vector2(800, 925), Vector2(SQUARE.x - 420, 890)])


func _road_e() -> PackedVector2Array:
	return PackedVector2Array([Vector2(SQUARE.x + 420, 870), Vector2(2200, 880), Vector2(2600, 875), Vector2(3200, 880)])


func _lane_pts() -> PackedVector2Array:
	return PackedVector2Array([Vector2(SQUARE.x - 250, 1120), Vector2(1430, 1400), Vector2(1400, LANE_Y), Vector2(700, LANE_Y + 4), Vector2(200, LANE_Y + 10), Vector2(-120, LANE_Y + 20)])


func _ground() -> void:
	terrain.paint_rect("lawn", Rect2(150, 300, 2700, 1500), 80.0)
	terrain.paint_ellipse("dirt", SQUARE, Vector2(640, 400), 50.0)
	terrain.paint_ellipse("cobble", SQUARE, Vector2(520, 320), 40.0)
	for road in [_road_w(), _road_e()]:
		terrain.paint_path("dirt", road, 170.0, 14.0)
	# the poor lane: churned mud that never dries
	terrain.paint_path("dirt", _lane_pts(), 160.0, 20.0)
	terrain.paint_path("mud", _lane_pts(), 100.0, 18.0)
	terrain.paint_path("mud", PackedVector2Array([Vector2(160, LANE_Y), Vector2(1400, LANE_Y + 6)]), 130.0, 18.0)
	for d in POOR_DOORS:
		terrain.paint_ellipse("mud", d + Vector2(0, 50), Vector2(70, 40), 10.0)
	for d in [Vector2(330, 520), Vector2(860, 480), Vector2(1380, 470), Vector2(1900, 470), Vector2(2420, 500), Vector2(2000, 1450), Vector2(2560, 1460)]:
		terrain.paint_path("dirt", PackedVector2Array([d + Vector2(0, 20), Vector2(d.x, d.y + 120), Vector2(lerpf(d.x, SQUARE.x, 0.3), lerpf(d.y, SQUARE.y, 0.6))]), 70.0, 12.0)
	var road_c = Color(0.62, 0.5, 0.36)
	map_rect(Rect2(SQUARE - Vector2(520, 320), Vector2(1040, 640)), Color(0.66, 0.64, 0.62))
	map_line(Region.smooth_curve(_road_w(), 20.0), road_c, 70.0)
	map_line(Region.smooth_curve(_road_e(), 20.0), road_c, 70.0)
	map_line(Region.smooth_curve(_lane_pts(), 20.0), Color(0.48, 0.38, 0.3), 60.0)


func _houses() -> void:
	add_prop("props/house_a_summer.png", Vector2(330, 520), 1.0, Vector2(110, 26), Vector2(300, 90))
	add_prop("props/house_b_summer.png", Vector2(860, 480), 1.0, Vector2(110, 26), Vector2(300, 90))
	add_prop("props/house_a_summer.png", Vector2(1380, 470), 1.0, Vector2(110, 26), Vector2(300, 90), true)
	add_prop("props/barn_summer.png", Vector2(1900, 470), 1.0, Vector2(110, 26), Vector2(300, 90))
	add_prop("props/house_b_summer.png", Vector2(2420, 500), 1.0, Vector2(110, 26), Vector2(300, 90), true)
	add_prop("props/shed_summer.png", Vector2(2800, 540), 1.0, Vector2(70, 20), Vector2(220, 70))
	add_prop("props/house_a_summer.png", Vector2(2000, 1450), 1.0, Vector2(110, 26), Vector2(300, 90))
	add_prop("props/house_b_summer.png", Vector2(2560, 1460), 1.0, Vector2(110, 26), Vector2(300, 90), true)
	# a thin thread of smoke from the baker's
	add_smoke(Vector2(43, -137) * Art.PX * 2.0 + Vector2(860, 480), null, 6)


func _square() -> void:
	add_prop("props/fountain_summer.png", SQUARE, 1.0, Vector2(70, 22), Vector2(170, 56))
	add_interactable(SQUARE + Vector2(0, 90), "The fountain", func(): await Dialogue.play("home_fountain"), 110, "Fountain")
	add_prop("props/stall_red_summer.png", SQUARE + Vector2(-380, -210), 1.0, Vector2(60, 16), Vector2(150, 44))
	add_prop("props/stall_red_summer.png", SQUARE + Vector2(390, -220), 1.0, Vector2(60, 16), Vector2(150, 44), true)
	add_prop("props/well_summer.png", SQUARE + Vector2(-560, 240), 1.0, Vector2(50, 16), Vector2(120, 44))
	add_prop("props/barrels_summer.png", SQUARE + Vector2(-540, -170), 1.0, Vector2(36, 12), Vector2(100, 34))
	add_prop("props/crates_summer.png", SQUARE + Vector2(560, -180), 1.0, Vector2(40, 12), Vector2(130, 36))
	for p in [SQUARE + Vector2(-470, -300), SQUARE + Vector2(470, -300), SQUARE + Vector2(-470, 300), SQUARE + Vector2(470, 300)]:
		add_prop("props/lamp_post_summer.png", p, 1.0, Vector2(12, 5), Vector2(20, 14), p.x < SQUARE.x)
	add_prop("props/bench_summer.png", SQUARE + Vector2(-230, 250), 1.0, Vector2(36, 10), Vector2(100, 24))
	add_prop("props/bench_summer.png", SQUARE + Vector2(240, 250), 1.0, Vector2(36, 10), Vector2(100, 24), true)
	for p in [SQUARE + Vector2(-300, -330), SQUARE + Vector2(300, -330), SQUARE + Vector2(560, 300)]:
		add_prop("props/flower_barrel.png", p, 1.0, Vector2(26, 8), Vector2(50, 20), p.x > SQUARE.x)


## The poor lane at the bottom of the village: four sagging cottages, and
## four doors for the purses.
func _poor_lane() -> void:
	for i in POOR_DOORS.size():
		var d: Vector2 = POOR_DOORS[i]
		var rel = "props/cottage_small_summer.png" if i % 2 == 0 else "props/shed_summer.png"
		var c = add_prop(rel, d + Vector2(0, -10), 1.0, Vector2(70, 18), Vector2(200, 60), i == 1)
		# the roofs sag: a little lean, a little lower
		c.skew = 0.04 if i % 2 == 0 else -0.05
		var id: String = PURSE_IDS[i]
		if GameState.has_flag("ch30_purse_" + id):
			continue
		var at = d + Vector2(0, 30)
		var a = add_interactable(at, "Leave a purse", func(): await _purse(id), 80)
		_doors[id] = a
	for p in [Vector2(260, LANE_Y + 160), Vector2(1240, LANE_Y + 170)]:
		add_prop("props/woodshed_summer.png", p, 1.0, Vector2(50, 14), Vector2(130, 34), p.x > 700)
	add_prop("props/fence_summer.png", Vector2(620, LANE_Y + 190), 1.0, Vector2(50, 8), Vector2(170, 18))
	add_prop("props/fence_summer.png", Vector2(880, LANE_Y + 190), 1.0, Vector2(50, 8), Vector2(170, 18), true)
	add_prop("props/buckets_summer.png", Vector2(600, LANE_Y - 70), 1.0, Vector2.ZERO, Vector2(40, 14))
	add_prop("props/bramble_summer.png", Vector2(1660, LANE_Y - 120), 1.0, Vector2(30, 8), Vector2(60, 18), true)
	add_prop("props/trough_summer.png", Vector2(1720, LANE_Y + 120), 1.0, Vector2(40, 10), Vector2(100, 26))


func _purse(id: String) -> void:
	if GameState.has_flag("ch30_purse_" + id) or not GameState.has_flag("ch30_village"):
		return
	GameState.set_flag("ch30_purse_" + id)
	if _doors.has(id) and is_instance_valid(_doors[id]):
		_doors[id].queue_free()
	_doors.erase(id)
	GameState.remove_item("silver_purse", 1)
	Audio.sfx("pickup", -8.0)
	await Dialogue.play("ch30_purse_" + id)
	var n = 0
	for p in PURSE_IDS:
		if GameState.has_flag("ch30_purse_" + p):
			n += 1
	if n < 4:
		GameState.set_objective("Leave a purse of silver at each poor door. (%d/4)" % n)
	else:
		await Dialogue.play("ch30_purses_done")
		GameState.set_flag("ch30_purses_done")


func _details() -> void:
	add_prop("props/signpost_summer.png", Vector2(160, 830), 1.0, Vector2(14, 5), Vector2(20, 14))
	add_prop("props/signpost_summer.png", Vector2(2850, 770), 1.0, Vector2(14, 5), Vector2(20, 14), true)
	add_prop("props/cart_summer.png", Vector2(620, 1100), 1.0, Vector2(50, 14), Vector2(140, 36))
	add_prop("props/hay_bales_summer.png", Vector2(2200, 1650), 1.0, Vector2(40, 12), Vector2(100, 34))
	add_prop("props/hay_bales_summer.png", Vector2(2760, 1250), 1.0, Vector2(40, 12), Vector2(100, 34), true)
	add_prop("props/wheelbarrow_summer.png", Vector2(2640, 600), 1.0, Vector2(30, 8), Vector2(60, 18))
	add_prop("props/basket_post.png", Vector2(1120, 590), 1.0, Vector2(12, 5), Vector2(20, 12))
	for x in [40, 190]:
		add_prop("props/stone_wall_summer.png", Vector2(x, 700), 1.0, Vector2(60, 10), Vector2(140, 30))
		add_prop("props/stone_wall_summer.png", Vector2(x, 1200), 1.0, Vector2(60, 10), Vector2(140, 30), true)
	for x in [2140, 2266]:
		add_prop("props/rail_fence_summer.png", Vector2(x, 1260), 1.0, Vector2(50, 8), Vector2(126, 16))
	var rng = RandomNumberGenerator.new()
	rng.seed = 3030
	for i in 26:
		var p = Vector2(rng.randf_range(60, 2940), rng.randf_range(560, 1900))
		if p.distance_to(SQUARE) < 620 or absf(p.y - 900) < 140 or absf(p.y - LANE_Y) < 170:
			continue
		var rel = ["props/daisies.png", "props/buttercups.png", "props/poppies.png", "props/tall_grass.png"][rng.randi_range(0, 3)]
		add_prop(rel, p, 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)


func _trees() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 505
	for p in [Vector2(60, 360), Vector2(600, 260), Vector2(1120, 250), Vector2(1640, 240), Vector2(2160, 270), Vector2(2680, 300),
			Vector2(40, 1950), Vector2(1700, 1960), Vector2(2380, 1970), Vector2(2960, 1960), Vector2(2950, 1200)]:
		var rel = ["props/oak.png", "props/oak_s.png", "props/birch.png", "props/oak_summer.png"][rng.randi_range(0, 3)]
		add_prop(rel, p, 1.0, Vector2(22, 9), Vector2(38, 20), rng.randf() < 0.5)


func _people() -> void:
	var ch30 = GameState.chapter == 30
	if ch30 and not GameState.has_flag("ch30_tomas"):
		npc.tomas = add_npc("tomas", SQUARE + Vector2(70, 100), "", Callable(), 0)
		npc.crony_a = add_npc("villager_summer", SQUARE + Vector2(-60, 110), "", Callable(), 2)
		npc.crony_b = add_npc("villager_summer", SQUARE + Vector2(170, 70), "", Callable(), 1)
	# the band across the middle of the village that she has to cross going
	# home: Tomas at the fountain
	add_trigger(Rect2(SQUARE.x - 160, 0, 320, bounds.size.y), _tomas, false)
	# and round the corner on the east road, Isaac with his bride
	add_trigger(Rect2(2260, 0, 160, bounds.size.y), _isaac, false)
	add_trigger(Rect2(2900, 600, 140, 560), _home, false)
	add_trigger(Rect2(-60, 700, 120, 480), func():
		UI.toast("Not back that way. " + String(GameState.objective))
		player.position.x = maxf(player.position.x, 140.0), false)
	# villagers going about their business; they stop and stare as she passes
	var rng = RandomNumberGenerator.new()
	rng.seed = 30
	for i in 8:
		var p = Vector2(rng.randf_range(700, 2600), rng.randf_range(640, 1240))
		if p.distance_to(SQUARE) < 220:
			p.x += 400
		var who = "villager_summer" if i % 2 == 0 else "villager_woman_summer"
		var v = add_npc(who, p, "", Callable(), rng.randi_range(0, 3))
		var tw = v.create_tween().set_loops()
		var d = Vector2(rng.randf_range(-260, 260), rng.randf_range(-80, 80))
		var t = d.length() / 55.0
		tw.tween_interval(rng.randf_range(1.0, 4.0))
		tw.tween_property(v, "position", p + d, t)
		tw.tween_interval(rng.randf_range(2.0, 5.0))
		tw.tween_property(v, "position", p, t)
	add_npc("villager_woman_summer", POOR_DOORS[1] + Vector2(160, 90), "", Callable(), 1)


func _critters() -> void:
	for p in [SQUARE + Vector2(-140, 170), SQUARE + Vector2(-90, 200), SQUARE + Vector2(220, -60)]:
		add_critter("crow", p)
	add_critter("bluebird", Vector2(700, 640))
	add_critter("butterfly_yellow", Vector2(2050, 1300))
	add_critter("butterfly_white", Vector2(500, 1250))


func _tomas() -> void:
	if GameState.chapter != 30 or not GameState.has_flag("ch30_purses_done") or GameState.has_flag("ch30_tomas"):
		return
	if npc.has("tomas") and is_instance_valid(npc.tomas):
		npc.tomas.set_meta("facing", 2 if player.global_position.x > npc.tomas.position.x else 1)
	await Dialogue.play("ch30_tomas")


func _isaac() -> void:
	if GameState.chapter != 30 or not GameState.has_flag("ch30_tomas") or GameState.has_flag("ch30_isaac"):
		return
	# they come round the corner of the barn, arm in arm, laughing
	var at = player.global_position
	var isaac = add_npc("isaac_summer", at + Vector2(330, -20), "", Callable(), 1)
	var wife = add_npc("isaac_wife", at + Vector2(370, 26), "", Callable(), 1)
	walk_npc(wife, at + Vector2(150, 30), 120.0)
	await walk_npc(isaac, at + Vector2(110, -14), 120.0)
	player.facing = 2
	await Dialogue.play("ch30_isaac")
	# and walk on past her, into the village
	for h in [isaac, wife]:
		if is_instance_valid(h):
			var tw = h.create_tween()
			tw.tween_property(h, "position", h.position + Vector2(-900, 30), 900.0 / 110.0)
			tw.tween_property(h, "modulate:a", 0.0, 0.5)
			tw.tween_callback(h.queue_free)


func _home() -> void:
	if GameState.chapter != 30:
		return
	if not GameState.has_flag("ch30_isaac"):
		UI.toast("Not yet. " + String(GameState.objective))
		player.position.x = minf(player.position.x, 2860.0)
		return
	await Dialogue.play("ch30_home")
