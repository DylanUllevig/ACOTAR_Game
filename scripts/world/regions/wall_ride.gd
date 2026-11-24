extends Region
## Chapter 5: the night ride north and the crossing. In the book Feyre is put to
## sleep before the Wall, so the crossing itself is a dream-like cinematic.

var beast: Node2D
var mare: Sprite2D
var _cine_layer: CanvasLayer
var _ride_t := 0.0

const RIDE_ART := "actors/mare_ride.png"


func build() -> void:
	surface = "snow"
	combat_allowed = false
	map_title = "The Road North"
	map_base = Color(0.78, 0.82, 0.9)
	bounds = Rect2(0, 0, 1600, 4200)
	spawns = {"start": Vector2(800, 3950)}
	pixel_ground(["snow", "trodden", "dirt"], 5)
	# the old road north, a pale trodden band with frozen ruts down its middle
	var road = PackedVector2Array()
	for i in 24:
		var y = 4500.0 - i * 210.0
		road.append(Vector2(800.0 + sin(i * 0.9) * 26.0, y))
	terrain.paint_path("trodden", road, 230.0, 34.0)
	terrain.paint_path("dirt", road, 60.0, 10.0)
	enclose_bounds()
	var rng = RandomNumberGenerator.new()
	rng.seed = 55
	for i in 130:
		var p = Vector2(rng.randf_range(40, 1560), rng.randf_range(100, 4150))
		if abs(p.x - 800) < 280:
			continue
		var r = rng.randf()
		if r < 0.8:
			add_prop("props/pine_%d.png" % [0, 0, 1, 2, 3][rng.randi_range(0, 4)], p, 1.0, Vector2(16, 7), Vector2(28, 18), rng.randf() < 0.5)
		elif r < 0.9:
			add_prop("props/bare_tree_0.png", p, 1.0, Vector2(12, 6), Vector2(22, 16), rng.randf() < 0.5)
		else:
			add_prop("props/rock_0.png", p, 1.0, Vector2(46, 18), Vector2(90, 40), rng.randf() < 0.5)
	for i in 50:
		var p = Vector2(rng.randf_range(80, 1520), rng.randf_range(120, 4150))
		if abs(p.x - 800) < 170:
			continue
		add_prop(["props/snow_mound.png", "props/grass_tuft.png", "props/branch.png", "props/stump.png"][rng.randi_range(0, 3)], p, 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)
	# moonlight
	add_sun(-160.0, Color(0.6, 0.7, 1.0), 0.5)
	# the beast pads north ahead of her, seen from behind
	if Art.is_pixel("actors/beast.png"):
		beast = Node2D.new()
		beast.position = Vector2(800, 3650)
		var bs = Sprite2D.new()
		var m = Art.pixel_meta("actors/beast.png")
		var g: Array = m.get("grid", [1, 1])
		bs.texture = Art.lit("actors/beast.png")
		bs.hframes = int(g[0])
		bs.vframes = int(g[1])
		bs.frame = int(m.get("anims", {}).get("rear", [0])[0])
		bs.scale = Art.sprite_scale("actors/beast.png")
		bs.offset = Vector2(0, -bs.texture.get_height() / (2.0 * bs.vframes))
		beast.add_child(bs)
		world.add_child(beast)
		# his golden coat holds a little of the moon
		add_light(Vector2(0, -110), Color(1.0, 0.85, 0.6), 0.3, 1.0, false, beast)
	elif Art.resolve("actors/beast.png").begins_with(Art.FINAL):
		beast = add_prop("actors/beast.png", Vector2(800, 3650), 1.2, Vector2(45, 18))
		var eye = add_light(Vector2(-29, -183) * 1.2, Color(0.4, 1.0, 0.6), 0.6, 0.35, false, beast)
		add_flicker(eye, 0.2, 2.0)
	else:
		beast = add_prop("actors/beast.png", Vector2(800, 3650), 1.5, Vector2(60, 20))
		var eye = add_light(Vector2(80, -130), Color(0.4, 1.0, 0.6), 0.6, 0.35, false, beast)
		add_flicker(eye, 0.2, 2.0)
	terrain.build()
	add_snow(160, Vector2(-20, 0))
	add_fog(bounds.grow(400), Color(0.5, 0.6, 0.85), 0.18, 50, 0.002)
	set_post({"vignette": 0.5, "lift": Vector3(0.01, 0.02, 0.06), "gain": Vector3(0.95, 0.98, 1.08), "saturation": 0.92, "grain": 0.0})
	add_trigger(Rect2(Vector2(0, 0), Vector2(1600, 1400)), func(): await Dialogue.play("ch05_sleep"))


func _ready() -> void:
	super._ready()
	# Feyre rides the white mare: painted from behind, riding north, when there
	# is art for it; otherwise her standing sprite sits on the side-on mare
	mare = Sprite2D.new()
	if Art.is_pixel("actors/mare.png"):
		# the pixel mare seen from behind, Feyre on her back
		var m = Art.pixel_meta("actors/mare.png")
		var g: Array = m.get("grid", [1, 1])
		mare.texture = Art.lit("actors/mare.png")
		mare.hframes = int(g[0])
		mare.vframes = int(g[1])
		mare.frame = int(m.get("anims", {}).get("ride_rear", [0])[0])
		mare.scale = Art.sprite_scale("actors/mare.png")
		mare.offset = Vector2(0, -mare.texture.get_height() / (2.0 * mare.vframes))
		player.sprite.visible = false
		player.footprints = false
	elif Art.tex(RIDE_ART) != null:
		mare.texture = Art.lit(RIDE_ART)
		mare.scale = Vector2.ONE * Art.density(RIDE_ART)
		mare.offset = Vector2(0, -mare.texture.get_height() / 2.0)
		player.sprite.visible = false
		player.footprints = false
	else:
		mare.texture = Art.lit("actors/mare.png")
		mare.scale = Vector2(1.2, 1.2) * Art.density("actors/mare.png")
		mare.offset = Vector2(0, -40) / Art.density("actors/mare.png")
		# sit her up on the mare's back (30 layout pixels above her usual feet)
		player.sprite.offset = Vector2(0, -player.sprite.texture.get_height() / 8.0 - 30.0 / Art.density("actors/feyre.png"))
	player.add_child(mare)
	player.move_child(mare, 0)
	var bi = Interactable.new()
	bi.setup("Speak to the beast", func(): await Dialogue.play("ch05_ask"), 260)
	beast.add_child(bi)
	add_light(Vector2(0, -40), Color(0.6, 0.7, 1.0), 0.3, 3.0, false, player)
	map_line(PackedVector2Array([Vector2(800, 4200), Vector2(800, 0)]), Color(0.55, 0.5, 0.45), 80.0)
	map_exit(Vector2(800, 120), "North")
	Audio.ambience("night_wind")
	Audio.music("night_ride", 3.0)


func on_enter() -> void:
	if not GameState.has_flag("ch05_ride_started"):
		GameState.set_flag("ch05_ride_started")
		await Dialogue.play("ch05_ride")


## Moonlight from behind the riders: long, faint shadows pointing north.
func sun_shadow(_h: float) -> Vector4:
	return Vector4(0.15, -1.0, 0.9, 0.16)


func grade_for_hour(_h: float) -> Dictionary:
	return {"mod": Color(0.3, 0.34, 0.55), "sun": Color(0.6, 0.7, 1.0), "sun_energy": 0.5, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.04)}


func _physics_process(delta: float) -> void:
	if beast == null or player == null:
		return
	# the beast keeps a fixed lead, padding north whenever she follows
	var target_y = player.position.y - 300.0
	if beast.position.y > target_y:
		beast.position.y = move_toward(beast.position.y, target_y, 200.0 * delta)
	player.position.x = move_toward(player.position.x, 800.0, 40.0 * delta)
	# a slow walking sway while the mare moves
	if player.sprite.visible == false and mare != null:
		var spd = player.velocity.length()
		_ride_t += delta * clampf(spd / 120.0, 0.0, 1.5) * 5.0
		var bob = absf(sin(_ride_t)) * 3.0 * clampf(spd / 60.0, 0.0, 1.0)
		if mare.hframes > 1:
			mare.position.y = -roundf(bob / Art.PX) * Art.PX
		else:
			mare.position.y = -bob
			mare.rotation = sin(_ride_t * 0.5) * 0.015 * clampf(spd / 60.0, 0.0, 1.0)


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
	_cine_layer.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # taller windows show more canvas
	var seam = ColorRect.new()
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/wall.gdshader")
	m.set_shader_parameter("reveal", 0.0)
	seam.material = m
	_cine_layer.add_child(seam)
	seam.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rider = Sprite2D.new()
	var rider_art = RIDE_ART if Art.tex(RIDE_ART) != null else "actors/mare.png"
	rider.texture = Art.tex(rider_art)
	rider.position = Vector2(960, 1000)
	rider.scale = Vector2(1.6, 1.6) * Art.density(rider_art)
	rider.modulate = Color(0.25, 0.3, 0.45)
	_cine_layer.add_child(rider)
	var text = Art.label_lit("", 40, Art.PARCHMENT, "italic")
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
	gold.color = Color(1.0, 0.88, 0.6, 0.0)
	_cine_layer.add_child(gold)
	gold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var t4 = create_tween()
	t4.tween_property(gold, "color:a", 1.0, 1.4)
	await t4.finished
	# Prythian at last: the Spring Court manor (final art if there is any)
	bg.color = Color(0.55, 0.72, 0.42)
	seam.visible = false
	rider.visible = false
	var manor_art = Art.tex("backgrounds/spring_manor.png")
	if manor_art != null:
		var pic = TextureRect.new()
		pic.texture = manor_art
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_cine_layer.add_child(pic)
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_cine_layer.move_child(pic, 1)
	else:
		var hedge = ColorRect.new()
		hedge.color = Color(0.22, 0.4, 0.2)
		hedge.position = Vector2(0, 360)
		hedge.size = Vector2(bg.size.x, 260)
		_cine_layer.add_child(hedge)
		_cine_layer.move_child(hedge, 1)
		var gate = ColorRect.new()
		gate.color = Color(0.3, 0.3, 0.32)
		gate.position = Vector2(bg.size.x * 0.5 - 100, 330)
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
		var ph = Art.label_lit("PLACEHOLDER: the Spring Court manor (manifest: bg.spring_manor)", 24, Color(1, 1, 1, 0.7), "caps")
		ph.position = Vector2(40, 30)   # top left, clear of the end-of-slice window and its toasts
		_cine_layer.add_child(ph)
	set_post({"blackout": 0.0})
	var t5 = create_tween()
	t5.tween_property(gold, "color:a", 0.25, 1.6)
	await t5.finished
