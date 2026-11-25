extends Region
## Chapter 3: market day in the village. A cobbled square with a broken
## fountain and two stalls, muddy roads in from the west and out to the east,
## snug houses with lit windows and smoking chimneys, and birds on the square.

const SQUARE := Vector2(1400, 900)

## Chimney tops and lit windows of each building, in art pixels from the
## middle of its base (see assets/pixel/props).
const HOUSE_PX := {
	"props/house_a.png": {"chimney": Vector2(48, -156), "windows": [Vector2(-23, -80), Vector2(31, -80), Vector2(-42, -34), Vector2(45, -35)], "lamp": Vector2(2, -44)},
	"props/house_b.png": {"chimney": Vector2(43, -137), "windows": [Vector2(-42, -42), Vector2(42, -42)], "lamp": Vector2(0, -57)},
	"props/barn.png": {"chimney": Vector2(48, -160), "windows": [Vector2(-50, -36), Vector2(47, -36)], "lamp": Vector2(0, -56)},
	"props/cottage_small.png": {"chimney": Vector2(11, -88), "windows": []},
}


func build() -> void:
	surface = "mud"
	combat_allowed = false
	map_title = "The Village"
	map_base = Color(0.86, 0.87, 0.9)
	bounds = Rect2(0, 0, 2800, 1800)
	spawns = {"road": Vector2(200, 960), "start": Vector2(200, 960)}
	pixel_ground(["snow", "trodden", "mud", "cobble"], 21)
	_ground()
	enclose_bounds()
	add_sun(-30.0, Color(1.0, 0.95, 0.86), 0.42)
	_houses()
	_square()
	_details()
	_trees()
	_people()
	_critters()
	terrain.build()
	add_snow(70, Vector2(20, 0))
	add_fog(bounds.grow(400), Color(0.86, 0.88, 0.94), 0.1, 50, 0.002)
	add_rays(Color(1.0, 0.94, 0.82), 0.12, -0.2)
	set_post({"vignette": 0.3, "lift": Vector3(0.01, 0.015, 0.03), "gain": Vector3(1.0, 1.0, 1.01), "saturation": 1.04, "grain": 0.0})


## Crisp, bright winter market morning; gold toward evening.
func sun_shadow(h: float) -> Vector4:
	var a = deg_to_rad(lerpf(-45.0, 50.0, clampf((h - 8.0) / 9.0, 0.0, 1.0)))
	var alpha = 0.26 * (1.0 - smoothstep(16.8, 17.6, h)) * smoothstep(7.5, 8.5, h)
	return Vector4(sin(a), -cos(a), 0.45 + 0.5 * smoothstep(13.0, 16.8, h), alpha)


func grade_for_hour(h: float) -> Dictionary:
	return Region.lerp_grade([
		[7.0, {"mod": Color(0.4, 0.42, 0.56), "sun": Color(0.9, 0.8, 0.7), "sun_energy": 0.15, "rays": 0.04, "exposure": Color(0.98, 0.98, 1.02)}],
		[9.0, {"mod": Color(0.6, 0.62, 0.7), "sun": Color(1.0, 0.92, 0.8), "sun_energy": 0.4, "rays": 0.12, "exposure": Color(0.97, 0.97, 0.98)}],
		[12.0, {"mod": Color(0.64, 0.67, 0.75), "sun": Color(1.0, 0.96, 0.88), "sun_energy": 0.42, "rays": 0.12, "exposure": Color(0.97, 0.97, 0.98)}],
		[15.5, {"mod": Color(0.58, 0.57, 0.63), "sun": Color(1.0, 0.86, 0.66), "sun_energy": 0.48, "rays": 0.16, "exposure": Color(0.96, 0.95, 0.95)}],
		[17.0, {"mod": Color(0.46, 0.42, 0.48), "sun": Color(1.0, 0.7, 0.46), "sun_energy": 0.45, "rays": 0.18, "exposure": Color(0.97, 0.95, 0.95)}],
		[18.5, {"mod": Color(0.26, 0.28, 0.44), "sun": Color(0.5, 0.5, 0.8), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}],
	], h)


func _road_w() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-300, 962), Vector2(260, 966), Vector2(600, 975), Vector2(SQUARE.x - 470, 950)])


func _road_e() -> PackedVector2Array:
	return PackedVector2Array([Vector2(SQUARE.x + 470, 905), Vector2(2200, 930), Vector2(2600, 955), Vector2(3100, 962)])


func _ground() -> void:
	# the square: cobbles, their edges lost under trampled snow
	terrain.paint_ellipse("trodden", SQUARE, Vector2(700, 470), 60.0)
	terrain.paint_ellipse("cobble", SQUARE, Vector2(560, 370), 50.0)
	# the roads in, churned to mud down the middle
	for road in [_road_w(), _road_e()]:
		terrain.paint_path("trodden", road, 230.0, 36.0)
		terrain.paint_path("mud", road, 120.0, 22.0)
	# paths trodden to the doors
	for d in [Vector2(300, 520), Vector2(820, 480), Vector2(1320, 470), Vector2(1830, 460), Vector2(2330, 500)]:
		terrain.paint_path("trodden", PackedVector2Array([d, Vector2(d.x, 560), Vector2(lerpf(d.x, SQUARE.x, 0.25), 700)]), 80.0, 18.0)
	for d in [Vector2(380, 1700), Vector2(1900, 1700), Vector2(2420, 1700)]:
		terrain.paint_path("trodden", PackedVector2Array([d, Vector2(d.x, 1500), Vector2(lerpf(d.x, SQUARE.x, 0.3), 1220)]), 80.0, 18.0)
	map_rect(Rect2(SQUARE - Vector2(520, 340), Vector2(1040, 680)), Color(0.62, 0.6, 0.6))
	map_line(Region.smooth_curve(_road_w(), 20.0), Color(0.55, 0.46, 0.38), 60.0)
	map_line(Region.smooth_curve(_road_e(), 20.0), Color(0.55, 0.46, 0.38), 60.0)


func _house(rel: String, base: Vector2, flip := false) -> Node2D:
	var h = add_prop(rel, base, 1.0, Vector2(110, 26), Vector2(300, 90), flip)
	var d: Dictionary = HOUSE_PX.get(rel, {})
	var k = Art.PX * Art.pixel_mult(rel)
	var fx = -1.0 if flip else 1.0
	if d.has("chimney"):
		var c: Vector2 = d["chimney"]
		add_smoke(Vector2(c.x * fx, c.y) * k, h)
	for w in d.get("windows", []):
		add_light(base + Vector2(w.x * fx, w.y) * k, Color(1.0, 0.74, 0.4), 0.4, 0.45, false)
	if d.has("lamp"):
		var l: Vector2 = d["lamp"]
		var lamp = add_light(base + Vector2(l.x * fx, l.y) * k, Color(1.0, 0.7, 0.38), 0.55, 0.7, false)
		add_flicker(lamp, 0.12, 7.0)
	return h


func _houses() -> void:
	_house("props/house_a.png", Vector2(300, 520))
	_house("props/house_b.png", Vector2(820, 480))
	_house("props/house_a.png", Vector2(1320, 470), true)
	_house("props/house_b.png", Vector2(1830, 460), true)
	_house("props/house_a.png", Vector2(2330, 500))
	add_prop("props/shed.png", Vector2(2690, 540), 1.0, Vector2(70, 20), Vector2(220, 70))
	_house("props/house_b.png", Vector2(380, 1790))
	_house("props/cottage_small.png", Vector2(900, 1770))
	_house("props/house_a.png", Vector2(1900, 1790), true)
	_house("props/barn.png", Vector2(2420, 1790))


func _square() -> void:
	add_prop("props/fountain_broken.png", SQUARE, 1.0, Vector2(90, 30), Vector2(200, 70))
	var charm = add_prop("props/stall_red.png", SQUARE + Vector2(-380, -200), 1.0, Vector2(70, 18), Vector2(150, 50))
	add_light(Vector2(70, -110), Color(1.0, 0.68, 0.35), 0.8, 0.8, true, charm)
	add_interactable(SQUARE + Vector2(-380, -130), "Browse the charm stall", func(): await Dialogue.play("ch03_charms"), 120, "Charm stall")
	var cob = add_prop("props/stall_blue.png", SQUARE + Vector2(380, -220), 1.0, Vector2(70, 18), Vector2(150, 50), true)
	add_light(Vector2(-70, -110), Color(1.0, 0.68, 0.35), 0.7, 0.8, true, cob)
	add_interactable(SQUARE + Vector2(380, -150), "The cobbler", func(): await Dialogue.play("ch03_cobbler"), 120, "Cobbler")
	add_prop("props/barrels.png", SQUARE + Vector2(-530, -175), 1.0, Vector2(40, 12), Vector2(110, 40))
	add_prop("props/crates.png", SQUARE + Vector2(540, -190), 1.0, Vector2(40, 12), Vector2(130, 40))
	add_prop("props/well.png", SQUARE + Vector2(-560, 250), 1.0, Vector2(60, 18), Vector2(120, 50))
	for p in [SQUARE + Vector2(-470, -330), SQUARE + Vector2(470, -330), SQUARE + Vector2(-470, 330), SQUARE + Vector2(470, 330)]:
		add_prop("props/lamp_post.png", p, 1.0, Vector2(12, 5), Vector2(20, 14))
		var l = add_light(p + Vector2(10, -128), Color(1.0, 0.72, 0.42), 0.55, 0.9, false)
		add_flicker(l, 0.1, 6.0)
	add_prop("props/bench.png", SQUARE + Vector2(-220, 250), 1.0, Vector2(40, 10), Vector2(100, 24))
	add_prop("props/bench.png", SQUARE + Vector2(230, 250), 1.0, Vector2(40, 10), Vector2(100, 24), true)
	# exit east
	add_trigger(Rect2(Vector2(2660, 760), Vector2(140, 400)), func():
		if GameState.has_flag("ch03_hides_sold"):
			await Dialogue.play("ch03_exit")
		else:
			await Dialogue.play("ch03_exit_locked")
			player.position.x -= 90, false)


## Odds and ends of village life along the roads and around the houses.
func _details() -> void:
	add_prop("props/signpost.png", Vector2(150, 860), 1.0, Vector2(14, 5), Vector2(20, 14))
	add_prop("props/wreath_post.png", Vector2(420, 850), 1.0, Vector2(12, 5), Vector2(20, 14))
	add_prop("props/wreath_post.png", Vector2(420, 1090), 1.0, Vector2(12, 5), Vector2(20, 14), true)
	add_prop("props/cart.png", Vector2(640, 1130), 1.0, Vector2(60, 16), Vector2(160, 40))
	add_prop("props/hay_bales.png", Vector2(2150, 1650), 1.0, Vector2(50, 14), Vector2(110, 36))
	add_prop("props/trough.png", Vector2(2700, 1700), 1.0, Vector2(50, 12), Vector2(110, 30))
	add_prop("props/woodshed.png", Vector2(150, 1460), 1.0, Vector2(60, 14), Vector2(140, 36))
	add_prop("props/woodshed.png", Vector2(2090, 1730), 1.0, Vector2(60, 14), Vector2(140, 36), true)
	add_prop("props/wheelbarrow.png", Vector2(2580, 560), 1.0, Vector2(40, 10), Vector2(90, 24))
	add_prop("props/buckets.png", Vector2(2580, 1700), 1.0, Vector2(26, 8), Vector2(50, 18))
	add_prop("props/snowman.png", Vector2(1110, 1460), 1.0, Vector2(36, 10), Vector2(60, 24))
	add_prop("props/hay_bales.png", Vector2(2660, 1300), 1.0, Vector2(50, 14), Vector2(110, 36), true)
	for x in [560, 680]:
		add_prop("props/rail_fence.png", Vector2(x, 1560), 1.0, Vector2(50, 8), Vector2(110, 16))
	for x in [2120, 2240]:
		add_prop("props/rail_fence.png", Vector2(x, 1420), 1.0, Vector2(50, 8), Vector2(110, 16))
	for x in [40, 150]:
		add_prop("props/stone_wall.png", Vector2(x, 700), 1.0, Vector2(60, 10), Vector2(130, 30))
		add_prop("props/stone_wall.png", Vector2(x, 1240), 1.0, Vector2(60, 10), Vector2(130, 30))
	var rng = RandomNumberGenerator.new()
	rng.seed = 33
	for i in 22:
		var p = Vector2(rng.randf_range(60, 2740), rng.randf_range(560, 1760))
		if p.distance_to(SQUARE) < 640 or absf(p.y - 950) < 150:
			continue
		add_prop(["props/grass_tuft.png", "props/snow_mound.png", "props/branch.png"][rng.randi_range(0, 2)], p, 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)


func _trees() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 404
	for p in [Vector2(40, 380), Vector2(560, 300), Vector2(1080, 280), Vector2(1580, 260), Vector2(2080, 300), Vector2(2560, 320),
			Vector2(60, 1500), Vector2(640, 1760), Vector2(1150, 1790), Vector2(1600, 1780), Vector2(2760, 1780), Vector2(2780, 700)]:
		var kind = rng.randi_range(0, 3)
		if kind < 3:
			add_prop("props/pine_%d.png" % [0, 1, 2][kind], p, 1.0, Vector2(16, 7), Vector2(28, 18), rng.randf() < 0.5)
		else:
			add_prop("props/bare_tree_0.png", p, 1.0, Vector2(12, 6), Vector2(22, 16), rng.randf() < 0.5)


func _people() -> void:
	var merc = add_npc("mercenary", SQUARE + Vector2(130, 70), "Speak with the mercenary", func(): await Dialogue.play("ch03_mercenary"), 1, 1.95)
	add_light(Vector2(0, -40), Color(0.9, 0.85, 0.8), 0.25, 0.6, false, merc)  # glint off her weapons
	add_npc("isaac", Vector2(1950, 640), "Isaac Hale", func(): await Dialogue.play("ch03_isaac"), 1)
	add_npc("elain", SQUARE + Vector2(-300, 120), "Talk to Elain", func(): await Dialogue.play("ch03_elain_coin"), 2)
	add_npc("nesta", SQUARE + Vector2(-360, 140), "", Callable(), 2)
	for i in 3:
		var a = add_npc("acolyte", Vector2(560 + i * 70, 860 + (i % 2) * 40), "", Callable(), 1)
		# silver bells: tiny cold glints
		add_light(Vector2(0, -30), Color(0.85, 0.9, 1.0), 0.6, 0.25, false, a)
	add_trigger(Rect2(Vector2(420, 700), Vector2(160, 420)), func():
		if not GameState.has_flag("ch03_acolyte_done"):
			await Dialogue.play("ch03_acolyte"))
	# villagers going about their business, to and fro across the square
	var rng = RandomNumberGenerator.new()
	rng.seed = 3
	for i in 7:
		var p = Vector2(rng.randf_range(850, 2150), rng.randf_range(680, 1200))
		var who = "villager" if i % 2 == 0 else "villager_woman"
		var v = add_npc(who, p, "", Callable(), rng.randi_range(0, 3))
		var tw = v.create_tween().set_loops()
		var d = Vector2(rng.randf_range(-260, 260), rng.randf_range(-90, 90))
		var t = d.length() / 55.0
		tw.tween_interval(rng.randf_range(1.0, 4.0))
		tw.tween_property(v, "position", p + d, t)
		tw.tween_interval(rng.randf_range(2.0, 5.0))
		tw.tween_property(v, "position", p, t)


func _critters() -> void:
	for p in [SQUARE + Vector2(-120, 160), SQUARE + Vector2(-80, 190), SQUARE + Vector2(200, -60), SQUARE + Vector2(260, 330)]:
		add_critter("crow", p)
	add_critter("robin", Vector2(700, 640))
	add_critter("robin", Vector2(2050, 1480))
	add_critter("squirrel", Vector2(1640, 330))
	add_critter("crow", Vector2(2400, 1250))


func _ready() -> void:
	super._ready()
	map_exit(Vector2(2740, 960), "Road home")
	map_poi(SQUARE, "Market square")
	Audio.ambience("village")
	Audio.music("village", 3.0)


func on_enter() -> void:
	if not GameState.has_flag("ch03_arrived"):
		GameState.set_flag("ch03_arrived")
		await Dialogue.play("ch03_arrive")
