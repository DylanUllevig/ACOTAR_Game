extends Region
## Chapter 1: the winter forest. The full-quality landscape of Milestone 1.

const CLEARING := Vector2(3050, 900)
const BRAMBLES := Vector2(2640, 1180)

var wolf_node: Node2D
var doe_node: Node2D
var eyes: Sprite2D


func build() -> void:
	bounds = Rect2(0, 0, 4200, 2700)
	spawns = {"start": Vector2(760, 2300), "brambles": BRAMBLES + Vector2(-60, 80)}
	add_ground_tile("terrain/snow.png", bounds)
	enclose_bounds()
	add_sun(-37.0, Color(1, 0.92, 0.8), 0.55)
	_build_brook()
	_scatter_trees()
	_build_clearing()
	_build_points_of_interest()
	add_snow(260, Vector2(50, 0))
	add_fog(bounds.grow(400), Color(0.84, 0.88, 0.98), 0.14, 50, 0.0018)
	add_rays(Color(1.0, 0.88, 0.7), 0.16, -0.5)
	set_post({"vignette": 0.55, "lift": Vector3(0.02, 0.03, 0.06), "gain": Vector3(0.98, 1.0, 1.05), "saturation": 0.9, "grain": 0.02})


var _aftermath_shown = false


func _ready() -> void:
	super._ready()
	# soft cool fill that follows Feyre so she reads at dusk and night
	add_light(Vector2(0, -30), Color(0.65, 0.75, 1.0), 0.35, 3.0, false, player)
	GameState.changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	if GameState.has_flag("wolf_killed") and not _aftermath_shown:
		_show_aftermath()


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
		if p.distance_to(BRAMBLES) < 220:
			continue
		# keep a winding path from the start to the clearing and the south exit open
		if _near_path(p, 150):
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


func _path_points() -> Array:
	return [Vector2(760, 2650), Vector2(760, 2300), Vector2(1100, 1900), Vector2(1500, 1600), Vector2(2000, 1500), Vector2(2400, 1300), BRAMBLES, CLEARING]


func _near_path(p: Vector2, d: float) -> bool:
	var pts = _path_points()
	for i in range(pts.size() - 1):
		var c = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		if c.distance_to(p) < d:
			return true
	return false


func _build_clearing() -> void:
	for i in 5:
		add_prop("props/bramble.png", BRAMBLES + Vector2(-140 + i * 70, (i % 2) * 18), 1.1, Vector2.ZERO, Vector2(80, 30) if i != 2 else Vector2.ZERO)
	doe_node = add_prop("actors/doe.png", CLEARING + Vector2(40, -30), 1.3, Vector2(30, 10))
	wolf_node = add_prop("actors/wolf.png", CLEARING + Vector2(-300, -140), 1.25, Vector2(50, 14))
	wolf_node.modulate = Color(0.7, 0.72, 0.8)
	# golden eyes in the brush: emissive, they bloom through the HDR glow
	eyes = Sprite2D.new()
	eyes.texture = Art.soft_light_texture()
	eyes.scale = Vector2(0.06, 0.03)
	eyes.position = Vector2(70, -96)
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/fae_glow.gdshader")
	m.set_shader_parameter("glow_color", Color(1.0, 0.78, 0.25))
	m.set_shader_parameter("power", 3.0)
	eyes.material = m
	wolf_node.add_child(eyes)
	var eyelight = add_light(Vector2(70, -96), Color(1.0, 0.75, 0.3), 0.6, 0.35, false, wolf_node)
	eyelight.name = "EyeLight"
	if GameState.has_flag("wolf_killed"):
		_show_aftermath()


func _show_aftermath() -> void:
	if _aftermath_shown:
		return
	_aftermath_shown = true
	wolf_node.rotation_degrees = 90
	wolf_node.modulate = Color(0.45, 0.42, 0.45)
	if eyes:
		eyes.visible = false
	var el = wolf_node.get_node_or_null("EyeLight")
	if el:
		el.queue_free()
	doe_node.visible = false
	# blood in the snow
	for i in 7:
		var b = Polygon2D.new()
		var poly = PackedVector2Array()
		for k in 9:
			var a = TAU * k / 9.0
			poly.append(Vector2(cos(a), sin(a) * 0.5) * randf_range(10, 34))
		b.polygon = poly
		b.color = Color(0.55, 0.05, 0.07, 0.85)
		b.position = wolf_node.position + Vector2(randf_range(-90, 90), randf_range(-20, 30))
		b.z_index = -6
		add_child(b)


func _build_points_of_interest() -> void:
	add_interactable(Vector2(1180, 1880), "Read the signs", func(): await Dialogue.play("ch01_tracks"))
	add_prop("props/rock_1.png", Vector2(1560, 1560), 0.9, Vector2(40, 14), Vector2(80, 30))
	add_interactable(Vector2(1560, 1600), "Check the old snare", func(): await Dialogue.play("ch01_hare"))
	add_interactable(Vector2(2060, 1530), "Rest a moment and check your quiver", func(): await Dialogue.play("ch01_ash_lore"))
	add_interactable(Vector2(3900, 1180), "Search the creek bank", func(): await Dialogue.play("ch01_wire"), 110)
	add_trigger(Rect2(BRAMBLES - Vector2(260, 160), Vector2(520, 360)), func():
		if not GameState.has_flag("wolf_killed"):
			await Dialogue.play("ch01_brambles"), false)
	add_trigger(Rect2(Vector2(560, 2560), Vector2(420, 140)), func():
		if GameState.has_flag("wolf_killed"):
			await Dialogue.play("ch01_exit")
		else:
			await Dialogue.play("ch01_exit_locked")
			player.position.y -= 80, false)


func on_enter() -> void:
	if GameState.has_flag("wolf_killed"):
		_show_aftermath()
	if not GameState.has_flag("ch01_intro_done"):
		GameState.set_flag("ch01_intro_done")
		await Dialogue.play("ch01_intro")
