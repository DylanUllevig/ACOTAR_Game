extends Region
## Chapter 5: the night ride north and the crossing. In the book Feyre is put to
## sleep before the Wall, so the crossing itself is a dream-like cinematic.

var beast: Node2D
var mare: Sprite2D
var _cine_layer: CanvasLayer


func build() -> void:
	bounds = Rect2(0, 0, 1600, 4200)
	spawns = {"start": Vector2(800, 3950)}
	add_ground_tile("terrain/snow.png", bounds)
	enclose_bounds()
	var rng = RandomNumberGenerator.new()
	rng.seed = 55
	for i in 110:
		var p = Vector2(rng.randf_range(40, 1560), rng.randf_range(100, 4150))
		if abs(p.x - 800) < 260:
			continue
		add_prop("props/pine_%d.png" % rng.randi_range(0, 2), p, rng.randf_range(1.0, 1.4), Vector2(16, 7), Vector2(28, 18))
	# moonlight
	add_sun(-160.0, Color(0.55, 0.65, 1.0), 0.45)
	beast = add_prop("actors/beast.png", Vector2(800, 3650), 1.5, Vector2(60, 20))
	var eye = add_light(Vector2(80, -130), Color(0.4, 1.0, 0.6), 0.6, 0.35, false, beast)
	add_flicker(eye, 0.2, 2.0)
	add_snow(160, Vector2(-20, 0))
	add_fog(bounds.grow(400), Color(0.45, 0.55, 0.8), 0.25, 50, 0.002)
	set_post({"vignette": 0.85, "lift": Vector3(0.0, 0.02, 0.08), "gain": Vector3(0.9, 0.95, 1.1), "saturation": 0.7, "grain": 0.03})
	add_trigger(Rect2(Vector2(0, 0), Vector2(1600, 1400)), func(): await Dialogue.play("ch05_sleep"))


func _ready() -> void:
	super._ready()
	# Feyre rides the white mare
	mare = Sprite2D.new()
	mare.texture = Art.lit("actors/mare.png")
	mare.scale = Vector2(1.2, 1.2)
	mare.offset = Vector2(0, -40)
	player.add_child(mare)
	player.move_child(mare, 0)
	player.sprite.offset = Vector2(0, -62)
	var bi = Interactable.new()
	bi.setup("Speak to the beast", func(): await Dialogue.play("ch05_ask"), 260)
	beast.add_child(bi)
	add_light(Vector2(0, -40), Color(0.6, 0.7, 1.0), 0.3, 3.0, false, player)


## Moonlight from behind the riders: long, faint shadows pointing north.
func sun_shadow(_h: float) -> Vector4:
	return Vector4(0.15, -1.0, 0.9, 0.16)


func grade_for_hour(_h: float) -> Dictionary:
	return {"mod": Color(0.2, 0.24, 0.42), "sun": Color(0.55, 0.65, 1.0), "sun_energy": 0.45, "rays": 0.0}


func _physics_process(delta: float) -> void:
	if beast == null or player == null:
		return
	# the beast keeps a fixed lead, padding north whenever she follows
	var target_y = player.position.y - 300.0
	if beast.position.y > target_y:
		beast.position.y = move_toward(beast.position.y, target_y, 200.0 * delta)
	player.position.x = move_toward(player.position.x, 800.0, 40.0 * delta)


func wall_cinematic() -> void:
	player.locked = true
	set_post({"blackout": 0.0})
	var tw = create_tween()
	tw.tween_method(func(v): set_post({"blackout": v}), 0.0, 1.0, 1.6)
	await tw.finished
	UI.show_hud(false)
	_cine_layer = CanvasLayer.new()
	_cine_layer.layer = 30
	add_child(_cine_layer)
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07)
	bg.size = Vector2(1920, 1080)
	_cine_layer.add_child(bg)
	var seam = ColorRect.new()
	seam.size = Vector2(1920, 1080)
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/wall.gdshader")
	m.set_shader_parameter("reveal", 0.0)
	seam.material = m
	_cine_layer.add_child(seam)
	var rider = Sprite2D.new()
	rider.texture = Art.tex("actors/mare.png")
	rider.position = Vector2(960, 1000)
	rider.scale = Vector2(1.6, 1.6)
	rider.modulate = Color(0.25, 0.3, 0.45)
	_cine_layer.add_child(rider)
	var text = Art.label("", 40, Art.PARCHMENT, "italic")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.anchor_right = 1.0
	text.offset_left = 200
	text.offset_right = -200
	text.offset_top = 180
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cine_layer.add_child(text)
	var lines = [
		"Two days north. She does not wake.",
		"The Wall is nothing you can see: a seam in the world, raised by the Treaty five centuries ago.",
		"Somewhere in her sleep, the cold changes.",
	]
	var t2 = create_tween()
	t2.tween_method(func(v): m.set_shader_parameter("reveal", v), 0.0, 1.0, 2.5)
	t2.parallel().tween_property(rider, "position", Vector2(960, 520), 9.0)
	for l in lines:
		text.text = l
		text.modulate.a = 0.0
		var t3 = create_tween()
		t3.tween_property(text, "modulate:a", 1.0, 0.8)
		t3.tween_interval(2.0)
		t3.tween_property(text, "modulate:a", 0.0, 0.6)
		await t3.finished
	UI.shake(6)
	# golden spring light floods in
	var gold = ColorRect.new()
	gold.size = Vector2(1920, 1080)
	gold.color = Color(1.0, 0.88, 0.6, 0.0)
	_cine_layer.add_child(gold)
	var t4 = create_tween()
	t4.tween_property(gold, "color:a", 1.0, 1.4)
	await t4.finished
	# a simple placeholder for the Spring Court gate
	bg.color = Color(0.55, 0.72, 0.42)
	seam.visible = false
	rider.visible = false
	var hedge = ColorRect.new()
	hedge.color = Color(0.22, 0.4, 0.2)
	hedge.position = Vector2(0, 360)
	hedge.size = Vector2(1920, 260)
	_cine_layer.add_child(hedge)
	_cine_layer.move_child(hedge, 1)
	var gate = ColorRect.new()
	gate.color = Color(0.3, 0.3, 0.32)
	gate.position = Vector2(860, 330)
	gate.size = Vector2(200, 300)
	_cine_layer.add_child(gate)
	_cine_layer.move_child(gate, 2)
	for i in 18:
		var rose = ColorRect.new()
		rose.color = Color(0.85, 0.3, 0.4)
		rose.size = Vector2(18, 18)
		rose.position = Vector2(60 + i * 105, 380 + (i % 3) * 60)
		_cine_layer.add_child(rose)
		_cine_layer.move_child(rose, 3)
	var ph = Art.label("PLACEHOLDER: Spring Court gate (manifest: bg.spring_gate)", 24, Color(1, 1, 1, 0.7), "caps")
	ph.position = Vector2(40, 1020)
	_cine_layer.add_child(ph)
	set_post({"blackout": 0.0})
	var t5 = create_tween()
	t5.tween_property(gold, "color:a", 0.25, 1.6)
	await t5.finished
