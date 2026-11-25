extends Region
## Chapter 31: the ride north to the Wall, through the summer forest, and the
## search along it for a way through. She rides up a forest track until the
## birds stop and the horse will not take another step; from there she leads
## the horse east along the Wall, touching it now and then to be sure it is
## still there. Night in a clearing by a fire, with eyes in the dark. Late
## on the second day, two standing stones with spirals cut in them: a gate.
##
## The Wall itself is invisible: a band of cool air that stops a hand like
## glass, and shimmers where she touches it.

const WALL_Y := 640.0
const CAMP := Vector2(2600, 980)
const GATE := Vector2(4400, 640)
const CAMP_R := 430.0                       # how far she strays from the fire at night
const HORSE_REL := "actors/mare.png"

var _mounted := false
var _horse: Node2D = null                   # the led horse, when she is on foot
var _horse_spr: Sprite2D = null
var _ride_spr: Sprite2D = null              # the horse under her, when she rides
var _fire: Node2D = null
var _fire_light: PointLight2D = null
var _fire_core: PointLight2D = null
var _toast_cd := 0.0
var _fire_boost := 0.0
var _eyes: Array = []
var _shimmer: ColorRect = null
var _flash: ColorRect = null
var _last_flip := false


func build() -> void:
	surface = "grass"
	combat_allowed = false
	map_title = "The Wall"
	map_base = Color(0.5, 0.62, 0.42)
	bounds = Rect2(0, 0, 5000, 2600)
	spawns = {"start": Vector2(820, 2380), "south": Vector2(820, 2380), "wall": Vector2(900, WALL_Y + 150),
		"camp": CAMP + Vector2(-80, 60), "gate": GATE + Vector2(-260, 260)}
	pixel_ground(["forest_floor", "grass", "meadow", "dirt"], 31)
	_ground()
	enclose_bounds()
	# the Wall: nothing north of it can be reached
	add_wall(Rect2(-200, -200, bounds.size.x + 400, WALL_Y + 200))
	add_sun(-35.0, Color(1.0, 0.95, 0.84), 0.5)
	_forest()
	_gate()
	_shimmer_band()
	terrain.smooth_edges = true
	terrain.build()
	add_rays(Color(1.0, 0.94, 0.78), 0.2, -0.4)
	add_fog(bounds.grow(400), Color(0.86, 0.92, 0.84), 0.05, 50, 0.002)
	set_post({"vignette": 0.34, "lift": Vector3(0.01, 0.014, 0.014), "gain": Vector3(0.99, 1.0, 0.98), "saturation": 1.04, "grain": 0.0})


func _ready() -> void:
	super._ready()
	add_light(Vector2(0, -30), Color(0.8, 0.84, 1.0), 0.3, 2.6, false, player)
	map_line(PackedVector2Array([Vector2(0, WALL_Y), Vector2(bounds.size.x, WALL_Y)]), Color(0.78, 0.86, 1.0), 24.0)
	_flash_layer()
	_story()
	_audio()


func _audio() -> void:
	if not GameState.has_flag("ch31_wall"):
		Audio.ambience("spring_day")
		Audio.music("night_ride", 3.0)
	elif GameState.has_flag("ch31_camp") and not GameState.has_flag("ch31_dawn"):
		Audio.ambience("night_wind")
		Audio.music_stop(3.0)
	else:
		# no birds, no insects: the quiet near the Wall
		Audio.ambience("forest_wind")
		Audio.music_stop(3.0)


func on_enter() -> void:
	if not GameState.has_flag("ch31_ride"):
		await Dialogue.play("ch31_ride")


func sun_shadow(h: float) -> Vector4:
	var a = deg_to_rad(lerpf(-62.0, 62.0, clampf((h - 6.0) / 14.0, 0.0, 1.0)))
	var length = 0.45 + 0.75 * (1.0 - sin(clampf((h - 6.0) / 14.0, 0.0, 1.0) * PI))
	var alpha = 0.3 * smoothstep(5.5, 7.0, h) * (1.0 - smoothstep(19.5, 20.5, h))
	return Vector4(sin(a), -cos(a), length, alpha)


## Green shade under summer leaves; a long gold evening; a deep blue night
## lit only by the fire.
func grade_for_hour(h: float) -> Dictionary:
	return Region.lerp_grade([
		[4.0, {"mod": Color(0.16, 0.19, 0.34), "sun": Color(0.4, 0.45, 0.75), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.05)}],
		[5.6, {"mod": Color(0.36, 0.36, 0.48), "sun": Color(0.9, 0.7, 0.6), "sun_energy": 0.2, "rays": 0.14, "exposure": Color(1.0, 0.98, 1.0)}],
		[7.5, {"mod": Color(0.58, 0.6, 0.58), "sun": Color(1.0, 0.9, 0.76), "sun_energy": 0.42, "rays": 0.2, "exposure": Color(0.99, 0.99, 0.97)}],
		[13.0, {"mod": Color(0.66, 0.68, 0.62), "sun": Color(1.0, 0.96, 0.86), "sun_energy": 0.46, "rays": 0.18, "exposure": Color(0.99, 0.99, 0.97)}],
		[17.0, {"mod": Color(0.64, 0.58, 0.52), "sun": Color(1.0, 0.84, 0.6), "sun_energy": 0.52, "rays": 0.26, "exposure": Color(1.0, 0.97, 0.94)}],
		[19.2, {"mod": Color(0.46, 0.38, 0.44), "sun": Color(1.0, 0.62, 0.42), "sun_energy": 0.42, "rays": 0.26, "exposure": Color(1.0, 0.96, 0.96)}],
		[20.6, {"mod": Color(0.22, 0.24, 0.4), "sun": Color(0.5, 0.52, 0.85), "sun_energy": 0.04, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.05)}],
		[23.9, {"mod": Color(0.16, 0.19, 0.34), "sun": Color(0.4, 0.45, 0.75), "sun_energy": 0.0, "rays": 0.0, "exposure": Color(1.0, 1.0, 1.05)}],
	], h)


# ------------------------------------------------------------------ layout
func _track() -> PackedVector2Array:
	return PackedVector2Array([Vector2(820, 2700), Vector2(760, 2100), Vector2(900, 1600), Vector2(820, 1100), Vector2(900, WALL_Y + 160)])


func _trail() -> PackedVector2Array:
	return PackedVector2Array([Vector2(700, WALL_Y + 170), Vector2(1600, WALL_Y + 190), Vector2(2200, WALL_Y + 230), CAMP + Vector2(0, -60),
		Vector2(3100, WALL_Y + 220), Vector2(3800, WALL_Y + 190), GATE + Vector2(0, 170), Vector2(5200, WALL_Y + 180)])


func _ground() -> void:
	terrain.paint_rect("grass", Rect2(-200, 1300, 5400, 1500), 120.0)
	for c in [Vector2(1900, 1700), Vector2(3300, 1900), Vector2(4300, 1500), Vector2(500, 1500)]:
		terrain.paint_ellipse("meadow", c, Vector2(380, 220), 60.0)
	terrain.paint_ellipse("meadow", CAMP, Vector2(460, 300), 50.0)
	terrain.paint_ellipse("grass", GATE + Vector2(0, 180), Vector2(420, 220), 40.0)
	terrain.paint_path("dirt", _track(), 110.0, 16.0)
	terrain.paint_path("dirt", _trail(), 64.0, 12.0)
	map_line(Region.smooth_curve(_track(), 20.0), Color(0.6, 0.48, 0.34), 60.0)
	map_line(Region.smooth_curve(_trail(), 20.0), Color(0.6, 0.48, 0.34), 40.0)


func _open(p: Vector2) -> bool:
	for line in [_track(), _trail()]:
		for k in range(line.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, line[k], line[k + 1]).distance_to(p) < 150.0:
				return true
	if p.distance_to(CAMP) < 520.0 or p.distance_to(GATE + Vector2(0, 160)) < 420.0:
		return true
	return false


func _clearing(p: Vector2) -> bool:
	return p.distance_to(CAMP) < 520.0 or p.distance_to(GATE + Vector2(0, 160)) < 420.0


func _forest() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 3131
	var trees = ["props/oak.png", "props/oak_s.png", "props/birch.png", "props/birch_s.png", "props/oak_summer.png", "props/oak_s.png"]
	var placed: Array[Vector2] = []
	var tries = 0
	while placed.size() < 150 and tries < 9000:
		tries += 1
		var p = Vector2(rng.randf_range(20, bounds.size.x - 20), rng.randf_range(60, bounds.size.y - 20))
		if p.y > WALL_Y - 40 and _open(p):
			continue
		# a crown stands some 300 above its trunk: keep it off the camp and the gate
		if _clearing(p - Vector2(0, 150)) or _clearing(p - Vector2(0, 280)):
			continue
		var ok = true
		for q in placed:
			if q.distance_to(p) < 210:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var rel: String = trees[rng.randi_range(0, trees.size() - 1)]
		if p.y < WALL_Y and rel == "props/oak_summer.png":
			rel = "props/oak.png"
		add_prop(rel, p, 1.0, Vector2(22, 9), Vector2(38, 20), rng.randf() < 0.5)
	var under = ["props/fern_spring.png", "props/tall_grass.png", "props/mossy_rock.png", "props/bramble_summer.png", "props/mossy_log.png", "props/toadstool.png", "props/fern_spring.png"]
	for i in 170:
		var p = Vector2(rng.randf_range(40, bounds.size.x - 40), rng.randf_range(WALL_Y + 40, bounds.size.y - 40))
		if p.distance_to(CAMP) < 300.0 or absf(p.x - GATE.x) < 200.0 and p.y < GATE.y + 360.0:
			continue
		var rel: String = under[rng.randi_range(0, under.size() - 1)]
		var solid = Vector2(40, 16) if rel.contains("rock") or rel.contains("log") else Vector2.ZERO
		if _open(p) and solid != Vector2.ZERO:
			continue
		add_prop(rel, p, 1.0, Vector2.ZERO, solid, rng.randf() < 0.5)
	var wild = ["props/daisies.png", "props/buttercups.png", "props/bluebells.png", "props/poppies.png"]
	for i in 40:
		var p = Vector2(rng.randf_range(100, bounds.size.x - 100), rng.randf_range(1250, bounds.size.y - 80))
		for k in rng.randi_range(1, 3):
			add_prop(wild[rng.randi_range(0, 3)], p + Vector2(rng.randf_range(-40, 40), rng.randf_range(-20, 20)), 1.0, Vector2.ZERO, Vector2.ZERO, rng.randf() < 0.5)
	# the summer forest hums with life, south of the Wall's quiet
	for p in [Vector2(700, 1900), Vector2(1100, 2200), Vector2(1900, 1700), Vector2(500, 1500)]:
		add_critter("butterfly_yellow" if int(p.x) % 2 == 0 else "butterfly_white", p)
	for p in [Vector2(600, 2000), Vector2(1200, 1800), Vector2(1000, 1400)]:
		add_critter("bluebird", p)
	add_critter("stag", Vector2(1700, 2300))
	add_critter("rabbit", Vector2(400, 2250))


func _gate() -> void:
	add_prop("props/whorl_stone.png", GATE + Vector2(-130, 70), 1.0, Vector2(30, 10), Vector2(70, 26))
	add_prop("props/whorl_stone.png", GATE + Vector2(130, 70), 1.0, Vector2(30, 10), Vector2(70, 26), true)
	add_prop("props/whorl_stone_s.png", GATE + Vector2(-300, 150), 1.0, Vector2(24, 8), Vector2(50, 20))
	add_prop("props/mossy_rock.png", GATE + Vector2(290, 160), 1.0, Vector2(20, 8), Vector2(40, 16), true)
	for p in [GATE + Vector2(-60, 120), GATE + Vector2(70, 110)]:
		add_prop("props/fern_spring.png", p, 1.0, Vector2.ZERO, Vector2.ZERO, p.x > GATE.x)


## A faint, cool shimmer along the Wall's line: only there if she looks.
func _shimmer_band() -> void:
	_shimmer = ColorRect.new()
	_shimmer.position = Vector2(-200, WALL_Y - 160)
	_shimmer.size = Vector2(bounds.size.x + 400, 190)
	var m = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = """shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float strength = 0.05;
void fragment() {
	float band = smoothstep(0.0, 0.85, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	float wave = 0.5 + 0.5 * sin(UV.x * 220.0 + TIME * 0.7 + sin(UV.y * 9.0 + TIME) * 2.0);
	float glint = pow(0.5 + 0.5 * sin(UV.x * 37.0 - TIME * 0.4), 18.0);
	COLOR = vec4(vec3(0.75, 0.85, 1.0) * band * (0.5 * wave + 1.5 * glint) * strength, 1.0);
}"""
	m.shader = sh
	_shimmer.material = m
	_shimmer.z_index = 40
	_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shimmer)


func _flash_layer() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(0.92, 0.96, 1.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)


# ------------------------------------------------------------------- story
func _story() -> void:
	if not GameState.has_flag("ch31_wall"):
		_mount()
		add_trigger(Rect2(300, WALL_Y, 1300, 320), func():
			if not GameState.has_flag("ch31_wall"):
				await Dialogue.play("ch31_wall")
				_after_wall())
	else:
		_horse = _make_horse(player.global_position + Vector2(-110, 6))
		if GameState.has_flag("ch31_camp") and not GameState.has_flag("ch31_dawn"):
			_make_fire(true)
			eyes_come()
			_horse.position = CAMP + Vector2(330, -80)
			_horse.set_meta("hobbled", true)
			_horse_spr.flip_h = true
		elif GameState.has_flag("ch31_camp"):
			_make_fire(false)
	for x in [1500, 2100, 3300, 3900]:
		add_interactable(Vector2(x, WALL_Y + 50), "Reach out", func(): await _tap(), 110)
	add_trigger(Rect2(CAMP - Vector2(300, 260), Vector2(600, 520)), func():
		if GameState.has_flag("ch31_wall") and not GameState.has_flag("ch31_camp"):
			await _camp())
	add_trigger(Rect2(GATE - Vector2(420, -40), Vector2(840, 420)), func():
		if GameState.has_flag("ch31_dawn") and not GameState.has_flag("ch31_gate"):
			await Dialogue.play("ch31_gate")
			_gate_prompt())
	if GameState.has_flag("ch31_gate"):
		_gate_prompt()
	add_trigger(Rect2(-60, 0, 120, bounds.size.y), func():
		UI.toast("West only led back the way I'd come.")
		player.position.x = maxf(player.position.x, 140.0), false)


func _process(delta: float) -> void:
	super._process(delta)
	if player == null:
		return
	# the day goes by as she goes: noon at the Wall, dusk at the clearing,
	# and late on the second day at the stones
	var x = player.global_position.x
	if not GameState.has_flag("ch31_wall"):
		GameState.hour = maxf(GameState.hour, lerpf(9.0, 14.0, clampf((2380.0 - player.global_position.y) / 1600.0, 0.0, 1.0)))
	elif not GameState.has_flag("ch31_camp"):
		GameState.hour = maxf(GameState.hour, lerpf(14.5, 20.2, clampf((x - 900.0) / (CAMP.x - 500.0 - 900.0), 0.0, 1.0)))
	elif GameState.has_flag("ch31_dawn") and not GameState.has_flag("ch31_through"):
		GameState.hour = maxf(GameState.hour, lerpf(6.0, 17.5, clampf((x - CAMP.x) / (GATE.x - 400.0 - CAMP.x), 0.0, 1.0)))
	if GameState.has_flag("ch31_camp") and not GameState.has_flag("ch31_dawn"):
		_keep_by_fire()
	_update_horse(delta)
	if _fire_light != null and is_instance_valid(_fire_light):
		# firelight: a flicker, and a flare each time she feeds it
		_fire_boost = maxf(0.0, _fire_boost - delta * 0.25)
		var t = Time.get_ticks_msec() / 1000.0
		var f = 1.0 + 0.2 * (sin(t * 9.0) * 0.5 + sin(t * 20.7) * 0.3) + randf_range(-0.04, 0.04)
		_fire_light.energy = (1.15 + _fire_boost) * f
		if _fire_core != null and is_instance_valid(_fire_core):
			_fire_core.energy = (0.9 + _fire_boost * 0.6) * f
	if _shimmer != null:
		# the shimmer shows a little more when she is close to it
		var near = 1.0 - clampf((player.global_position.y - WALL_Y) / 500.0, 0.0, 1.0)
		(_shimmer.material as ShaderMaterial).set_shader_parameter("strength", 0.03 + 0.07 * near)


func _keep_by_fire() -> void:
	_toast_cd = maxf(0.0, _toast_cd - get_process_delta_time())
	var d = player.global_position - CAMP
	if d.length() > CAMP_R and not Dialogue.active:
		player.global_position = CAMP + d.normalized() * (CAMP_R - 6.0)
		player.velocity = Vector2.ZERO
		if _toast_cd <= 0.0:
			_toast_cd = 3.0
			UI.toast("Not out there. Not in the dark.")


# ------------------------------------------------------------- the horse
func _horse_sprite() -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = Art.lit(HORSE_REL)
	var m = Art.pixel_meta(HORSE_REL)
	var g: Array = m.get("grid", [1, 1])
	s.hframes = int(g[0])
	s.vframes = int(g[1])
	s.scale = Art.sprite_scale(HORSE_REL)
	s.offset = Vector2(0, -s.texture.get_height() / (2.0 * s.vframes)) if s.texture else Vector2.ZERO
	return s


func _anim(name: String) -> Array:
	return Art.pixel_meta(HORSE_REL).get("anims", {}).get(name, [0])


## Up in the saddle: the horse is drawn under her and goes where she goes.
func _mount() -> void:
	if _ride_spr == null:
		_ride_spr = _horse_sprite()
		player.add_child(_ride_spr)
		player.move_child(_ride_spr, 0)
	_ride_spr.visible = true
	_ride_spr.frame = int(_anim("ride_side")[0])
	player.sprite.visible = false
	player.footprints = false
	player.terrain_mult = 1.6
	_mounted = true


func _dismount() -> void:
	_mounted = false
	if _ride_spr != null:
		_ride_spr.visible = false
	player.sprite.visible = true
	player.terrain_mult = 1.0


func _make_horse(pos: Vector2) -> Node2D:
	var h = Node2D.new()
	h.position = pos
	var sh = Sprite2D.new()
	sh.texture = Art.tex("fx/shadow.png")
	sh.modulate = Color(0.05, 0.06, 0.12, 0.4)
	sh.scale = Vector2(2.2, 0.6)
	sh.z_index = -1
	h.add_child(sh)
	_horse_spr = _horse_sprite()
	_horse_spr.frame = int(_anim("stand")[0])
	h.add_child(_horse_spr)
	world.add_child(h)
	h.add_to_group("see_through_figures")   # trees fade when the mare stands behind them
	return h


func _update_horse(delta: float) -> void:
	if _mounted and _ride_spr != null:
		var v = player.velocity
		if v.length() > 20.0:
			if v.y < -absf(v.x) * 1.2:
				_ride_spr.frame = int(_anim("ride_rear")[0])
				_ride_spr.flip_h = false
			else:
				_ride_spr.frame = int(_anim("ride_side")[0])
				if absf(v.x) > 10.0:
					_last_flip = v.x < 0.0
				_ride_spr.flip_h = _last_flip
			_ride_spr.position.y = -3.0 * absf(sin(Time.get_ticks_msec() / 110.0))
		else:
			if _ride_spr.frame == int(_anim("ride_rear")[0]):
				_ride_spr.frame = int(_anim("ride_side")[0])
			_ride_spr.position.y = 0.0
		return
	if _horse == null or not is_instance_valid(_horse) or _horse.has_meta("hobbled"):
		return
	# led on the reins: she walks a pace or two behind
	var to = player.global_position
	var d = to - _horse.position
	var gap = 120.0
	if d.length() > gap:
		var step = minf(d.length() - gap, maxf(150.0, player.velocity.length()) * delta * 1.05)
		_horse.position += d.normalized() * step
		var walk: Array = _anim("walk")
		var t = Time.get_ticks_msec() / 160.0
		if d.y < -absf(d.x) * 1.5:
			_horse_spr.frame = int(_anim("rear")[0])
			_horse_spr.flip_h = false
		else:
			_horse_spr.frame = int(walk[int(t) % walk.size()])
			_horse_spr.flip_h = d.x < 0.0
	else:
		_horse_spr.frame = int(_anim("stand")[0])


## region_call (ch31_wall): she throws up her head and won't go on.
func horse_balks() -> void:
	if _ride_spr == null:
		return
	var tw = create_tween()
	for i in 3:
		tw.tween_property(_ride_spr, "position:x", -6.0, 0.06)
		tw.tween_property(_ride_spr, "position:x", 6.0, 0.06)
	tw.tween_property(_ride_spr, "position:x", 0.0, 0.06)
	UI.shake(3.0)
	Audio.ambience_stop(1.5)
	Audio.music_stop(2.0)
	await tw.finished


## region_call (ch31_wall): she slides down and reaches out. The air stops her hand.
func touch_wall() -> void:
	var at = player.global_position
	_dismount()
	_horse = _make_horse(at + Vector2(-110, 8))
	_horse_spr.flip_h = false
	var to = Vector2(at.x, WALL_Y + 34)
	player.facing = 3
	var tw = create_tween()
	tw.tween_property(player, "global_position", to, maxf(0.3, at.distance_to(to) / 160.0))
	await tw.finished
	player.facing = 3
	await _ripple(Vector2(to.x, WALL_Y - 30), 1.0)


func _after_wall() -> void:
	Audio.ambience("forest_wind", 3.0)


## "Reach out": still there, cool and smooth as glass.
func _tap() -> void:
	player.facing = 3
	_ripple(Vector2(player.global_position.x, WALL_Y - 30), 0.7)
	await Dialogue.play("ch31_tap")


## A ring of light spreading through the air where she touches the Wall.
func _ripple(at: Vector2, strength: float) -> void:
	Audio.sfx("ash_strike", -18.0, 0.1)
	var glow = CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var ring = Line2D.new()
	var pts = PackedVector2Array()
	for i in 41:
		var a = TAU * i / 40.0
		pts.append(Vector2(cos(a), sin(a) * 0.55) * 20.0)
	ring.points = pts
	ring.width = 3.0
	ring.default_color = Color(0.8, 0.9, 1.0, 0.9 * strength)
	ring.material = glow
	ring.position = at
	ring.z_index = 41
	add_child(ring)
	var l = add_light(at, Color(0.75, 0.86, 1.0), 0.9 * strength, 1.4, false)
	var tw = create_tween()
	tw.tween_property(ring, "scale", Vector2(9, 9), 1.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 1.4)
	tw.parallel().tween_property(l, "energy", 0.0, 1.4)
	tw.tween_callback(ring.queue_free)
	tw.tween_callback(l.queue_free)
	await get_tree().create_timer(0.6, true, false, true).timeout


# ------------------------------------------------------------- the night
func _camp() -> void:
	_make_fire(true)
	if _horse != null and is_instance_valid(_horse):
		var tw = _horse.create_tween()
		tw.tween_property(_horse, "position", CAMP + Vector2(330, -80), _horse.position.distance_to(CAMP + Vector2(330, -80)) / 150.0)
		_horse.set_meta("hobbled", true)
		_horse_spr.frame = int(_anim("stand")[0])
		_horse_spr.flip_h = true
	await Dialogue.play("ch31_camp")
	Audio.ambience("night_wind", 3.0)


func _make_fire(lit: bool) -> void:
	if _fire != null and is_instance_valid(_fire):
		return
	_fire = add_prop("props/fire_ring.png", CAMP, 1.0, Vector2(20, 8), Vector2(56, 20))
	add_prop("props/bedroll.png", CAMP + Vector2(-110, 40), 1.0, Vector2.ZERO, Vector2.ZERO)
	add_prop("props/mossy_log.png", CAMP + Vector2(90, 70), 1.0, Vector2(26, 8), Vector2(70, 18), true)
	if not lit:
		add_smoke(CAMP + Vector2(0, -20), null, 3)
		return
	_fire_light = add_light(CAMP + Vector2(0, -30), Color(1.0, 0.62, 0.32), 1.15, 4.2, false)
	_fire_core = add_light(CAMP + Vector2(0, -20), Color(1.0, 0.78, 0.42), 0.9, 0.8, false)
	add_smoke(CAMP + Vector2(0, -40), null, 8)
	add_interactable(CAMP + Vector2(0, 30), "Feed the fire", func(): await _feed(), 120, "Camp")


func _feed() -> void:
	if not GameState.has_flag("ch31_camp") or GameState.has_flag("ch31_dawn"):
		await Dialogue.play("home_fire_out")
		return
	var n = 1
	while GameState.has_flag("ch31_fed_%d" % n):
		n += 1
	if n > 3:
		return
	GameState.set_flag("ch31_fed_%d" % n)
	Audio.sfx("forage", -8.0)
	_fire_boost = 1.0
	await Dialogue.play("ch31_feed_%d" % n)
	# the night wears on
	GameState.hour = [22.6, 1.2, 3.6][n - 1]
	if n < 3:
		GameState.set_objective("Keep the fire burning until dawn. (%d/3)" % n)
	else:
		await Dialogue.play("ch31_dawn")
		_embers()


func _embers() -> void:
	for l in [_fire_light, _fire_core]:
		if l != null and is_instance_valid(l):
			var tw = create_tween()
			tw.tween_property(l, "energy", 0.0, 2.0)
			tw.tween_callback(l.queue_free)
	_fire_light = null
	_fire_core = null
	if _horse != null and is_instance_valid(_horse):
		_horse.remove_meta("hobbled")
	Audio.ambience("forest_wind", 3.0)


## region_call (ch31_camp): eyes in the dark, out past the firelight.
func eyes_come() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 731
	var glow = CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in 9:
		var a = -PI * 0.1 + TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
		var r = rng.randf_range(560.0, 700.0)
		var at = CAMP + Vector2(cos(a) * r, sin(a) * r * 0.7) + Vector2(0, -40)
		var pair = Node2D.new()
		pair.position = at
		pair.z_index = 45
		pair.modulate.a = 0.0
		for sx in [-1, 1]:
			var e = Sprite2D.new()
			e.texture = Art.soft_light_texture()
			e.material = glow
			e.scale = Vector2(0.05, 0.04)
			e.position = Vector2(sx * 7, 0)
			e.modulate = [Color(1.0, 0.85, 0.3), Color(0.7, 1.0, 0.45), Color(1.0, 0.55, 0.3)][i % 3]
			pair.add_child(e)
		add_child(pair)
		_eyes.append(pair)
		var show = pair.create_tween()
		show.tween_interval(rng.randf_range(0.2, 3.0))
		show.tween_property(pair, "modulate:a", 1.0, 1.2)
		# blink, and drift in and out at the edge of the light
		var blink = pair.create_tween().set_loops()
		blink.tween_interval(rng.randf_range(1.5, 4.0))
		blink.tween_property(pair, "scale:y", 0.1, 0.07)
		blink.tween_property(pair, "scale:y", 1.0, 0.07)
		var drift = pair.create_tween().set_loops()
		var d = (CAMP - at).normalized() * rng.randf_range(40.0, 90.0)
		drift.tween_property(pair, "position", at + d, rng.randf_range(3.0, 5.0)).set_trans(Tween.TRANS_SINE)
		drift.tween_property(pair, "position", at, rng.randf_range(3.0, 5.0)).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.2, true, false, true).timeout


## region_call (ch31_dawn): with the grey light, they are gone.
func eyes_go() -> void:
	for e in _eyes:
		if is_instance_valid(e):
			var tw = e.create_tween()
			tw.tween_property(e, "modulate:a", 0.0, 1.6)
			tw.tween_callback(e.queue_free)
	_eyes.clear()
	_embers()


# -------------------------------------------------------------- the gate
func _gate_prompt() -> void:
	if has_meta("gate_prompt"):
		return
	set_meta("gate_prompt", true)
	add_interactable(GATE + Vector2(0, 190), "Ride between the stones", func(): await Dialogue.play("ch31_through"), 130, "The gate")


## region_call (ch31_through): up in the saddle, between the stones and
## through. Magic stings; she bucks once; and they are on the other side.
func ride_through() -> void:
	var start = GATE + Vector2(0, 220)
	await UI.fade_out(0.4)
	if _horse != null and is_instance_valid(_horse):
		_horse.queue_free()
		_horse = null
	player.global_position = start
	_mount()
	_ride_spr.frame = int(_anim("ride_rear")[0])
	_ride_spr.flip_h = false
	player.locked = true
	await UI.fade_in(0.4)
	var tw = create_tween()
	tw.tween_property(player, "global_position", Vector2(GATE.x, WALL_Y + 40), 1.4)
	await tw.finished
	# the crossing: a crackle, a buck, a flash of white
	Audio.sfx("ash_strike", -6.0)
	UI.shake(8.0)
	var buck = create_tween()
	buck.tween_property(_ride_spr, "position:y", -14.0, 0.12)
	buck.tween_property(_ride_spr, "position:y", 0.0, 0.18)
	var fl = create_tween()
	fl.tween_property(_flash, "color:a", 0.85, 0.12)
	fl.tween_property(_flash, "color:a", 0.0, 1.1)
	var on = create_tween()
	on.tween_property(player, "global_position", Vector2(GATE.x, WALL_Y - 260), 1.6)
	on.parallel().tween_property(player, "modulate:a", 0.0, 1.4).set_delay(0.3)
	await on.finished
