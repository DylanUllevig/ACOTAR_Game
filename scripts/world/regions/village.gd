extends Region
## Chapter 3: market day in the village. Grey, trampled snow, a broken fountain.

const SQUARE := Vector2(1400, 900)


func build() -> void:
	surface = "mud"
	combat_allowed = false
	map_title = "The Village"
	map_base = Color(0.74, 0.7, 0.66)
	bounds = Rect2(0, 0, 2800, 1800)
	spawns = {"road": Vector2(200, 960), "start": Vector2(200, 960)}
	add_ground_tile("terrain/mud_snow.png", bounds, Color.WHITE, true, true)
	# the cobbled square, its edges lost under trodden snow
	add_ground_patch("terrain/cobbles.png", Rect2(SQUARE - Vector2(560, 400), Vector2(1120, 800)), 120.0, 70.0)
	map_rect(Rect2(SQUARE - Vector2(520, 360), Vector2(1040, 720)), Color(0.6, 0.58, 0.56))
	map_line(PackedVector2Array([Vector2(0, 960), Vector2(SQUARE.x - 520, 960)]), Color(0.55, 0.46, 0.38), 60.0)
	map_line(PackedVector2Array([Vector2(SQUARE.x + 520, 900), Vector2(2800, 960)]), Color(0.55, 0.46, 0.38), 60.0)
	if Art.tex("terrain/road_mud.png") != null:
		# the roads in, churned to mud; they run on past the edges of the map and
		# fade out on the square's cobbles
		add_strip("terrain/road_mud.png", PackedVector2Array([Vector2(-300, 962), Vector2(420, 966), Vector2(SQUARE.x - 430, 952)]), 220.0, -9, 220.0)
		add_strip("terrain/road_mud.png", PackedVector2Array([Vector2(SQUARE.x + 430, 905), Vector2(2300, 944), Vector2(3100, 962)]), 220.0, -9, 220.0)
	enclose_bounds()
	add_sun(-30.0, Color(0.9, 0.92, 1.0), 0.3)
	_houses()
	_square()
	_people()
	add_snow(110, Vector2(20, 0))
	add_fog(bounds.grow(400), Color(0.78, 0.8, 0.86), 0.16, 50, 0.002)
	add_rays(Color(0.9, 0.92, 1.0), 0.12, -0.2)
	set_post({"vignette": 0.6, "lift": Vector3(0.03, 0.03, 0.04), "gain": Vector3(0.97, 0.98, 1.0), "saturation": 0.75, "grain": 0.025})


## Overcast market day: short, soft shadows that barely move.
func sun_shadow(h: float) -> Vector4:
	var alpha = 0.18 * (1.0 - smoothstep(16.5, 17.5, h)) * smoothstep(7.5, 8.5, h)
	return Vector4(0.3, -1.0, 0.4, alpha)


func grade_for_hour(h: float) -> Dictionary:
	return Region.lerp_grade([
		[8.0, {"mod": Color(0.6, 0.62, 0.7), "sun": Color(0.9, 0.9, 1.0), "sun_energy": 0.2, "rays": 0.08}],
		[11.0, {"mod": Color(0.78, 0.79, 0.84), "sun": Color(0.95, 0.95, 1.0), "sun_energy": 0.32, "rays": 0.12}],
		[16.0, {"mod": Color(0.66, 0.62, 0.68), "sun": Color(1.0, 0.8, 0.65), "sun_energy": 0.3, "rays": 0.1}],
		[18.0, {"mod": Color(0.25, 0.27, 0.42), "sun": Color(0.5, 0.5, 0.8), "sun_energy": 0.0, "rays": 0.0}],
	], h)


## Chimney top and lit window of each painted house, from its base at scale 1.4.
const HOUSE_DETAIL := {
	"props/house_a.png": [Vector2(80, -273), Vector2(-72, -84)],
	"props/house_b.png": [Vector2(74, -254), Vector2(-60, -66)],
}


func _houses() -> void:
	var spots = [
		[Vector2(500, 420), "props/house_a.png"], [Vector2(850, 380), "props/house_b.png"], [Vector2(1250, 360), "props/house_a.png"],
		[Vector2(1700, 380), "props/house_b.png"], [Vector2(2100, 400), "props/house_a.png"], [Vector2(2500, 460), "props/house_b.png"],
		[Vector2(480, 1600), "props/house_b.png"], [Vector2(900, 1640), "props/house_a.png"], [Vector2(1900, 1640), "props/house_b.png"],
		[Vector2(2350, 1620), "props/barn.png"],
	]
	for s in spots:
		var h = add_prop(s[1], s[0], 1.4, Vector2(110, 26), Vector2(220, 70))
		# warm window glow and chimney smoke, where the painting has them
		var detail = HOUSE_DETAIL.get(s[1]) if Art.resolve(s[1]).begins_with(Art.FINAL) else [Vector2(60, -300), Vector2(-60, -150)]
		if detail == null:
			continue    # the barn: no hearth, no lit window
		add_light(s[0] + detail[1], Color(1.0, 0.7, 0.4), 0.45, 0.8, false)
		var smoke = CPUParticles2D.new()
		smoke.position = detail[0]
		smoke.amount = 14
		smoke.lifetime = 5.0
		smoke.preprocess = 5.0
		smoke.texture = Art.soft_light_texture()
		smoke.direction = Vector2(0.3, -1)
		smoke.spread = 10
		smoke.initial_velocity_min = 20
		smoke.initial_velocity_max = 40
		smoke.scale_amount_min = 0.15
		smoke.scale_amount_max = 0.35
		smoke.color = Color(0.5, 0.5, 0.55, 0.25)
		h.add_child(smoke)


## Where a stall's lantern hangs, from its base at scale 1.3: in the painting,
## or over the middle of the placeholder.
func _lantern(rel: String, painted: Vector2) -> Vector2:
	return painted if Art.resolve(rel).begins_with(Art.FINAL) else Vector2(0, -150)


func _square() -> void:
	add_prop("props/fountain_broken.png", SQUARE, 1.3, Vector2(90, 30), Vector2(240, 90))
	var charm = add_prop("props/stall_red.png", SQUARE + Vector2(-380, -200), 1.3, Vector2(70, 18), Vector2(180, 50))
	add_light(_lantern("props/stall_red.png", Vector2(-67, -96)), Color(1.0, 0.68, 0.35), 0.9, 1.0, true, charm)
	add_interactable(SQUARE + Vector2(-380, -130), "Browse the charm stall", func(): await Dialogue.play("ch03_charms"), 120, "Charm stall")
	var cob = add_prop("props/stall_blue.png", SQUARE + Vector2(380, -220), 1.3, Vector2(70, 18), Vector2(180, 50))
	add_light(_lantern("props/stall_blue.png", Vector2(-38, -83)), Color(1.0, 0.68, 0.35), 0.7, 1.0, true, cob)
	add_interactable(SQUARE + Vector2(380, -150), "The cobbler", func(): await Dialogue.play("ch03_cobbler"), 120, "Cobbler")
	# exit east
	add_trigger(Rect2(Vector2(2660, 760), Vector2(140, 400)), func():
		if GameState.has_flag("ch03_hides_sold"):
			await Dialogue.play("ch03_exit")
		else:
			await Dialogue.play("ch03_exit_locked")
			player.position.x -= 90, false)


func _people() -> void:
	# "a mountain of a woman": drawn a head taller than the villagers
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
	var rng = RandomNumberGenerator.new()
	rng.seed = 3
	for i in 6:
		var p = Vector2(rng.randf_range(800, 2200), rng.randf_range(700, 1200))
		var v = add_npc("villager", p, "", Callable(), rng.randi_range(0, 3), 1.6)
		var tw = create_tween().set_loops()
		var d = Vector2(rng.randf_range(-160, 160), rng.randf_range(-60, 60))
		tw.tween_property(v, "position", p + d, rng.randf_range(4.0, 7.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(v, "position", p, rng.randf_range(4.0, 7.0)).set_trans(Tween.TRANS_SINE)


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
