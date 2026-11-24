class_name Region
extends Node2D
## Base for every overworld area. Subclasses override build() and on_enter().
## Provides: lit sprites with normal maps and shadow occluders, the player,
## day/night grading, HDR glow, snow, fog, god rays and the post grade, the
## world-space overlay for combat numbers, and what the map screen draws
## (props, paths and points of interest, under the fog of war).

const Player := preload("res://scripts/world/player.gd")
const Interactable := preload("res://scripts/world/interactable.gd")

var world: Node2D           # y-sorted actors and props
var ground: Node2D
var player: CharacterBody2D
var camera: Camera2D
var canvas_mod: CanvasModulate
var sun: DirectionalLight2D
var env: WorldEnvironment
var fx_layer: CanvasLayer
var overlay: CanvasLayer         # world-space, above the colour grade: damage numbers, slashes
var post: ColorRect
var _post_gain := Vector3.ONE    # set_post's gain
var _exposure := Color.WHITE     # grade_for_hour's optional per-channel exposure
var rays: ColorRect
var spawns = {}
var bounds = Rect2(0, 0, 3000, 2000)
var interior = false
var snow_amount = 0.0
var _snow_near: CPUParticles2D
var _snow_far: CPUParticles2D
var time_scale = 1.0 / 180.0   # game hours per real second (1 hour per 3 minutes)
var _triggers: Array = []
var shadow_layer: Node2D
var _casters: Array = []        # [Sprite2D, scale]
var surface := "snow"           # footstep sound set: snow, mud, wood
var combat_allowed := false     # weapons only come out where it makes sense
var hunt: Node = null           # the running fight, if any
## Map screen data. Marks: [kind, position, extra]. Shapes: {type, ...} in world space.
var map_title := ""
var map_base := Color(0.9, 0.9, 0.93)
var map_marks: Array = []
var map_shapes: Array = []
var reveal_radius := 560.0
var _reveal_t := 0.0
var camera_zoom := 0.0          # 0: the usual zoom for an interior or the outdoors
var pixel_scale := 0            # screen pixels per art pixel at 1080p; 0: the usual for an interior or the outdoors
var terrain: PixelGround = null # pixel-art ground, when the region paints one
var _tall: Array = []           # [sprite, crown rect, base y] for props that can hide someone
var _npcs: Array = []           # [holder, sprite] of pixel people, who face Feyre when she is near

const SEE_THROUGH_MIN_H := 190.0   # props at least this tall (trees, houses) fade
const SEE_THROUGH_ALPHA := 0.42


func _ready() -> void:
	y_sort_enabled = false
	ground = Node2D.new()
	ground.name = "Ground"
	ground.z_index = -10
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(ground)
	shadow_layer = Node2D.new()
	shadow_layer.name = "CastShadows"
	shadow_layer.z_index = -9
	shadow_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(shadow_layer)
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(world)
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_CANVAS
	# No glow: without HDR 2D it blooms the brightest snow into a grey haze, and
	# the Compatibility renderer (browser build) has none, so the two would differ.
	e.glow_enabled = false
	e.glow_intensity = 0.9
	e.glow_strength = 1.05
	e.glow_bloom = 0.08
	e.glow_hdr_threshold = 0.95
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.set_glow_level(1, 1.0)
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.8)
	e.set_glow_level(4, 0.6)
	e.set_glow_level(5, 0.4)
	env.environment = e
	add_child(env)
	fx_layer = CanvasLayer.new()
	fx_layer.layer = 5
	add_child(fx_layer)
	overlay = CanvasLayer.new()
	overlay.layer = 6
	overlay.follow_viewport_enabled = true
	add_child(overlay)
	_build_post()
	build()
	_spawn_player()
	_apply_time()


# ------------------------------------------------------------ overridables
func build() -> void:
	pass


func on_enter() -> void:
	pass


func grade_for_hour(_h: float) -> Dictionary:
	## Returns {mod: Color, sun: Color, sun_energy: float, rays: float}
	return {"mod": Color(1, 1, 1), "sun": Color(1, 1, 1), "sun_energy": 0.0, "rays": 0.0}


# ----------------------------------------------------------------- helpers
## Starts the pixel-art ground: 'layers' are terrain names, the base first.
## Paint with terrain.paint_*() and the region's build() ends by drawing it.
func pixel_ground(layers: Array, seed := 7, tile_world := 0.0) -> PixelGround:
	terrain = PixelGround.new()
	terrain.name = "PixelGround"
	terrain.setup(bounds.grow(200), layers, seed, tile_world)
	ground.add_child(terrain)
	return terrain


## The footstep surface under a world position, from the pixel ground.
func surface_at(p: Vector2) -> String:
	if terrain == null:
		return surface
	match terrain.at(p):
		"snow", "trodden", "ice":
			return "snow"
		"dirt", "mud":
			return "mud"
		"grass", "lawn", "meadow", "forest_floor":
			return "grass"
		"gravel":
			return "gravel"
		"terrace", "marble":
			return "stone"
		"planks", "parquet":
			return "wood"
		"water":
			return "water"
		"cobble", "flagstone":
			return "mud" if surface == "mud" else ("stone" if surface in ["grass", "gravel", "stone"] else surface)
	return surface

## A ground texture repeated over rect. 'vary' hides the repeat over a large
## area (shaders/ground_vary.gdshader).
func add_ground_tile(rel: String, rect: Rect2, tint := Color(1, 1, 1), lit := true, vary := false) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = Art.lit(rel) if lit else Art.tex(rel)
	s.centered = false
	s.region_enabled = true
	# finer textures (density below 1) repeat over more pixels, drawn smaller
	var k = Art.density(rel)
	s.region_rect = Rect2(Vector2.ZERO, rect.size / k)
	s.scale = Vector2(k, k)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.position = rect.position
	s.modulate = tint
	if vary:
		var m = ShaderMaterial.new()
		m.shader = load("res://shaders/ground_vary.gdshader")
		m.set_shader_parameter("seed", Vector2(float(rel.length()) * 3.7, rect.size.x * 0.001))
		s.material = m
	ground.add_child(s)
	return s


## A tiled ground patch whose edges fray into the ground beneath it (a cobbled
## square in trodden snow) rather than ending on a straight line.
func add_ground_patch(rel: String, rect: Rect2, feather := 90.0, ragged := 50.0) -> Sprite2D:
	var s = add_ground_tile(rel, rect)
	var k = Art.density(rel)   # the shader works in texture pixels
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/ground_patch.gdshader")
	m.set_shader_parameter("patch_size", rect.size / k)
	m.set_shader_parameter("feather", feather / k)
	m.set_shader_parameter("ragged", ragged / k)
	m.set_shader_parameter("noise_scale", 0.011 * k)
	m.set_shader_parameter("seed", rect.position / k)
	s.material = m
	return s


## A painted strip (a trodden path, a frozen brook, a muddy road) laid along a
## smooth curve through pts. The texture repeats along the curve and its height
## spans the strip's width; its top and bottom rows fade out in the art itself,
## and the two ends fade over 'fade' pixels.
func add_strip(rel: String, pts: PackedVector2Array, width: float, z := -9, fade := 120.0) -> Line2D:
	var line = Line2D.new()
	line.points = smooth_curve(pts, 20.0)
	line.width = width
	line.texture = Art.lit(rel)
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	var length := 0.0
	for i in range(line.points.size() - 1):
		length += line.points[i].distance_to(line.points[i + 1])
	var f = clampf(fade / maxf(length, 1.0), 0.0, 0.45)
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, f, 1.0 - f, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	line.gradient = g
	line.z_index = z
	add_child(line)
	return line


## Catmull-Rom curve through pts, sampled about every 'step' pixels.
static func smooth_curve(pts: PackedVector2Array, step := 20.0) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out = PackedVector2Array()
	var last = pts.size() - 1
	for i in last:
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		var d: Vector2 = pts[mini(i + 2, last)]
		var n = maxi(1, ceili(b.distance_to(c) / step))
		for k in n:
			out.append(b.cubic_interpolate(c, a, d, float(k) / n))
	out.append(pts[last])
	return out


## A lit prop with a shadow-casting footprint. 'foot' is the occluder ellipse
## size at the base (0 = no shadow). Origin of the sprite is its base center.
func add_prop(rel: String, pos: Vector2, scl := 1.0, foot := Vector2(40, 14), solid := Vector2.ZERO, flip := false) -> Node2D:
	var holder = Node2D.new()
	holder.position = pos
	var s = Sprite2D.new()
	s.texture = Art.lit(rel)
	s.centered = true
	s.flip_h = flip
	if s.texture:
		s.offset = Vector2(0, -s.texture.get_height() / 2.0)
	s.scale = Art.sprite_scale(rel, scl)
	var k = s.scale.x / scl
	holder.add_child(s)
	if rel.begins_with("props/") and s.texture and s.texture.get_height() * s.scale.y >= SEE_THROUGH_MIN_H:
		# the opaque middle of the picture: crowns and roofs taper, so leave the edges
		var w = s.texture.get_width() * s.scale.x
		var h = s.texture.get_height() * s.scale.y
		_tall.append([s, Rect2(pos.x - w * 0.3, pos.y - h * 0.96, w * 0.6, h * 0.96), pos.y])
	var mk = _map_kind(rel)
	if mk != "":
		map_marks.append([mk, pos, scl])
	if foot != Vector2.ZERO and s.texture:
		_add_caster(rel, pos, scl * k, flip)
	if foot != Vector2.ZERO:
		var occ = LightOccluder2D.new()
		var poly = OccluderPolygon2D.new()
		var pts = PackedVector2Array()
		for i in 12:
			var a = TAU * i / 12.0
			pts.append(Vector2(cos(a) * foot.x, sin(a) * foot.y - foot.y * 0.5) * scl)
		poly.polygon = pts
		occ.occluder = poly
		holder.add_child(occ)
	if solid != Vector2.ZERO:
		var body = StaticBody2D.new()
		var cs = CollisionShape2D.new()
		var rs = RectangleShape2D.new()
		rs.size = solid * scl
		cs.shape = rs
		cs.position = Vector2(0, -solid.y * scl * 0.5)
		body.add_child(cs)
		holder.add_child(body)
	world.add_child(holder)
	return holder


static func _map_kind(rel: String) -> String:
	for pair in [["props/pine", "pine"], ["props/bare_tree", "tree"], ["props/rock", "rock"], ["props/bramble", "bramble"],
			["props/rose_bush", "rose"], ["props/house", "house"], ["props/barn", "house"], ["props/cottage", "house"],
			["props/stall", "stall"], ["props/fountain", "fountain"]]:
		if rel.begins_with(pair[0]):
			return pair[1]
	return ""


## A pond: water painted on the pixel ground (an ellipse that wobbles a
## little) and a solid edge just inside it, so Feyre walks round it.
func add_pond(c: Vector2, radii: Vector2, wobble := 18.0) -> void:
	terrain.paint_ellipse("water", c, radii, wobble)
	var pts = PackedVector2Array()
	for i in 24:
		var a = TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * (radii.x - 34.0), sin(a) * (radii.y - 30.0)))
	_solid_poly(pts)
	map_shapes.append({"type": "poly", "pts": pts, "color": Color(0.45, 0.68, 0.8)})


## A brook along pts: painted water 'width' across, solid except within
## 'gap' of each crossing point (stepping stones, a ford).
func add_brook(pts: PackedVector2Array, width: float, crossings: Array = [], gap := 70.0) -> void:
	terrain.paint_path("water", pts, width, 14.0)
	var curve = Region.smooth_curve(pts, 24.0)
	for k in range(curve.size() - 1):
		var a: Vector2 = curve[k]
		var b: Vector2 = curve[k + 1]
		var mid = (a + b) * 0.5
		var near_crossing = false
		for c in crossings:
			if mid.distance_to(c) < gap:
				near_crossing = true
				break
		if near_crossing:
			continue
		var body = StaticBody2D.new()
		var cs = CollisionShape2D.new()
		var rs = RectangleShape2D.new()
		rs.size = Vector2(a.distance_to(b) + 6.0, maxf(8.0, width - 56.0))
		cs.shape = rs
		cs.position = mid
		cs.rotation = (b - a).angle()
		body.add_child(cs)
		add_child(body)
	map_line(curve, Color(0.45, 0.68, 0.8), width * 0.8)


func _solid_poly(pts: PackedVector2Array) -> void:
	var body = StaticBody2D.new()
	var cp = CollisionPolygon2D.new()
	cp.polygon = pts
	body.add_child(cp)
	add_child(body)


## A labelled point on the map screen (shown once the spot has been explored).
func map_poi(pos: Vector2, label: String) -> void:
	map_marks.append(["poi", pos, label])


func map_exit(pos: Vector2, label: String) -> void:
	map_marks.append(["exit", pos, label])


func map_line(pts: PackedVector2Array, color: Color, width: float) -> void:
	map_shapes.append({"type": "line", "pts": pts, "color": color, "width": width})


func map_rect(r: Rect2, color: Color) -> void:
	map_shapes.append({"type": "rect", "rect": r, "color": color})


## Projected silhouette shadow: the prop's own image flattened onto the ground
## along the sun direction. Length and direction follow the time of day.
func _add_caster(rel: String, pos: Vector2, scl: float, flip: bool) -> void:
	var sh = Sprite2D.new()
	sh.texture = Art.tex(rel)
	sh.centered = true
	sh.flip_h = flip
	sh.offset = Vector2(0, -sh.texture.get_height() / 2.0)
	sh.light_mask = 0
	sh.modulate = Color(0.02, 0.03, 0.1, 0.0)
	sh.position = pos
	shadow_layer.add_child(sh)
	_casters.append([sh, scl])


## Override per region: x,y = shadow direction (screen space), z = length factor, w = opacity.
func sun_shadow(_h: float) -> Vector4:
	return Vector4(0.3, 1.0, 0.4, 0.0)


func _update_casters() -> void:
	if _casters.is_empty():
		return
	var s4: Vector4 = sun_shadow(GameState.hour)
	var d = Vector2(s4.x, s4.y).normalized()
	for c in _casters:
		var sp: Sprite2D = c[0]
		var scl: float = c[1]
		var p = sp.position
		# texture 'up' is local -y, so the y basis is -d: the top of the prop lands along d.
		sp.transform = Transform2D(Vector2(scl, 0), -d * s4.z * scl, p)
		sp.modulate.a = s4.w


func add_occluder_rect(rect: Rect2) -> void:
	var occ = LightOccluder2D.new()
	var poly = OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	occ.occluder = poly
	add_child(occ)


func add_wall(rect: Rect2) -> StaticBody2D:
	var body = StaticBody2D.new()
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = rect.size
	cs.shape = rs
	cs.position = rect.get_center()
	body.add_child(cs)
	add_child(body)
	return body


func enclose_bounds() -> void:
	var t = 200.0
	add_wall(Rect2(bounds.position.x - t, bounds.position.y - t, bounds.size.x + t * 2, t))
	add_wall(Rect2(bounds.position.x - t, bounds.end.y, bounds.size.x + t * 2, t))
	add_wall(Rect2(bounds.position.x - t, bounds.position.y, t, bounds.size.y))
	add_wall(Rect2(bounds.end.x, bounds.position.y, t, bounds.size.y))


func add_light(pos: Vector2, color: Color, energy := 1.0, scl := 2.0, shadows := true, parent: Node = null) -> PointLight2D:
	var l = PointLight2D.new()
	l.texture = Art.soft_light_texture()
	l.position = pos
	l.color = color
	l.energy = energy
	l.texture_scale = scl
	l.shadow_enabled = shadows
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.shadow_filter_smooth = 3.0
	l.height = 40.0
	(parent if parent else world).add_child(l)
	return l


func add_flicker(l: PointLight2D, amount := 0.25, speed := 9.0) -> void:
	var base = l.energy
	var t = Timer.new()
	t.wait_time = 0.05
	t.autostart = true
	l.add_child(t)
	var phase = randf() * 10.0
	t.timeout.connect(func():
		phase += 0.05 * speed
		l.energy = base * (1.0 + amount * (sin(phase) * 0.5 + sin(phase * 2.3) * 0.3 + randf_range(-0.2, 0.2))))


func add_sun(angle_deg: float, color: Color, energy: float) -> void:
	sun = DirectionalLight2D.new()
	sun.rotation_degrees = angle_deg
	sun.color = color
	sun.energy = energy
	sun.height = 0.45
	sun.shadow_enabled = false  # sun shadows are projected silhouettes (see _add_caster)
	sun.shadow_color = Color(0.1, 0.12, 0.25, 0.55)
	sun.shadow_filter = Light2D.SHADOW_FILTER_PCF13
	sun.shadow_filter_smooth = 6.0
	sun.max_distance = 1600.0
	add_child(sun)


func add_fog(rect: Rect2, color: Color, density: float, z := 50, scale_w := 0.0025) -> ColorRect:
	var f = ColorRect.new()
	f.position = rect.position
	f.size = rect.size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/fog.gdshader")
	m.set_shader_parameter("fog_color", color)
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("world_scale", scale_w)
	f.material = m
	f.z_index = z
	add_child(f)
	return f


func add_snow(amount: int, wind := Vector2(40, 0)) -> void:
	snow_amount = amount
	_snow_far = _make_snow(amount, 0.5, 30.0, wind * 0.6)
	_snow_far.z_index = 40
	_snow_near = _make_snow(int(amount * 0.4), 1.3, 70.0, wind)
	_snow_near.z_index = 60


func _make_snow(amount: int, size_scale: float, fall: float, wind: Vector2) -> CPUParticles2D:
	var p = CPUParticles2D.new()
	p.amount = max(1, amount)
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.texture = Art.tex("fx/snowflake.png")
	if Art.is_pixel("fx/snowflake.png"):
		# square flakes a whole number of pixels across, like the rest of the world
		var k = Art.PX * (2.0 if size_scale < 1.0 else 3.0) / float(p.texture.get_width())
		p.scale_amount_min = k
		p.scale_amount_max = k
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1400, 40)
	p.direction = Vector2(0.2, 1)
	p.spread = 15.0
	p.gravity = Vector2(wind.x * 0.3, fall * 0.3)
	p.initial_velocity_min = fall * 0.6
	p.initial_velocity_max = fall * 1.2
	if not Art.is_pixel("fx/snowflake.png"):
		p.scale_amount_min = 0.25 * size_scale
		p.scale_amount_max = 0.7 * size_scale
	p.color = Color(1.0, 1.0, 1.0, 0.85)
	p.position = Vector2(0, -760)
	p.local_coords = false
	add_child(p)
	return p


func add_rays(color: Color, intensity: float, angle := -0.35) -> void:
	rays = ColorRect.new()
	rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/god_rays.gdshader")
	m.set_shader_parameter("ray_color", color)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("angle", angle)
	rays.material = m
	fx_layer.add_child(rays)


func _build_post() -> void:
	var post_layer = CanvasLayer.new()
	post_layer.layer = 9
	add_child(post_layer)
	post = ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/post.gdshader")
	post.material = m
	post_layer.add_child(post)


func set_post(params: Dictionary) -> void:
	for k in params:
		if k == "gain":
			_post_gain = params[k]
			_apply_gain()
		else:
			(post.material as ShaderMaterial).set_shader_parameter(k, params[k])


## The region's own colour gain, times the time-of-day exposure from its grade.
func _apply_gain() -> void:
	var e: Color = _exposure
	(post.material as ShaderMaterial).set_shader_parameter("gain", _post_gain * Vector3(e.r, e.g, e.b))


func add_interactable(pos: Vector2, label: String, callback: Callable, radius := 90.0, map_label := "") -> Area2D:
	var a: Area2D = Interactable.new()
	a.setup(label, callback, radius)
	a.position = pos
	world.add_child(a)
	if map_label != "":
		map_poi(pos, map_label)
	return a


func add_trigger(rect: Rect2, callback: Callable, once := true) -> void:
	var a = Area2D.new()
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = rect.size
	cs.shape = rs
	cs.position = rect.get_center()
	a.add_child(cs)
	a.collision_layer = 0   # arrows ray-cast against layer 1; triggers must not stop them
	a.collision_mask = 2
	a.monitoring = true
	add_child(a)
	# state: [fired, player_inside]. Entering while a dialogue or fade is running
	# queues the trigger; it fires as soon as the player is free, if still inside.
	var st = [false, false]
	a.body_entered.connect(func(b):
		if b == player:
			st[1] = true)
	a.body_exited.connect(func(b):
		if b == player:
			st[1] = false)
	_triggers.append([st, callback, once])


func _poll_triggers() -> void:
	if Dialogue.active or Router.busy or UI.modal_open:
		return
	for t in _triggers:
		var st: Array = t[0]
		if st[1] and not (t[2] and st[0]):
			st[0] = true
			st[1] = false  # repeatable triggers need the player to step out and back in
			t[1].call()
			return


func add_npc(sheet: String, pos: Vector2, label: String, callback: Callable, facing := 0, scl := 1.7) -> Node2D:
	var holder = Node2D.new()
	holder.position = pos
	var s = Sprite2D.new()
	s.texture = Art.lit("actors/%s.png" % sheet)
	s.hframes = 4
	s.vframes = 4
	s.frame = facing * 4
	# 4 x 4 sheet: the feet sit on the bottom of each frame
	var rel = "actors/%s.png" % sheet
	s.scale = Art.sprite_scale(rel, scl)
	var k = s.scale.x / scl
	s.offset = Vector2(0, -s.texture.get_height() / 8.0) if s.texture else Vector2(0, -32)
	holder.add_child(s)
	var body = StaticBody2D.new()
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 16
	cs.shape = c
	body.add_child(cs)
	holder.add_child(body)
	world.add_child(holder)
	if label != "":
		var a: Area2D = Interactable.new()
		a.setup(label, callback, 110.0)
		holder.add_child(a)
	if Art.is_pixel(rel):
		# pixel people turn to look at Feyre when she comes near
		holder.set_meta("facing", facing)
		_npcs.append([holder, s])
		return holder
	# idle breathing
	var tw = s.create_tween().set_loops()
	tw.tween_property(s, "scale", Vector2(scl, scl * 1.02) * k, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "scale", Vector2(scl, scl) * k, 1.2).set_trans(Tween.TRANS_SINE)
	return holder


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Feyre"
	var sp: Vector2 = spawns.get(GameState.spawn, spawns.get("start", bounds.get_center()))
	if GameState.pos is Vector2 and bounds.grow(-20).has_point(GameState.pos):
		sp = GameState.pos
	GameState.pos = null
	player.position = sp
	world.add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * _zoom_for_view()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	player.add_child(camera)
	camera.make_current()
	player.camera = camera
	_fit_camera_limits()
	get_viewport().size_changed.connect(_fit_camera_limits)
	if _snow_near:
		_snow_near.reparent(player, false)
		_snow_far.reparent(player, false)


## The camera stops at the region's edges. Where the region is narrower or
## shorter than the view (a small room), the limits are set a view's width or
## height apart around its centre instead, which holds the camera there: the
## room sits in the middle of the screen rather than against one edge.
## Pixel regions: the zoom that keeps art pixels whole on this screen.
## Painted regions (none left by default) keep their old fixed zoom.
func _zoom_for_view() -> float:
	if camera_zoom > 0.0 and pixel_scale == 0 and terrain == null:
		return camera_zoom
	var per = pixel_scale if pixel_scale > 0 else (Art.PX_SCREEN_IN if interior else Art.PX_SCREEN_OUT)
	return Art.pixel_zoom(get_viewport(), per)


func _fit_camera_limits() -> void:
	if camera == null:
		return
	camera.zoom = Vector2.ONE * _zoom_for_view()
	var view = get_viewport().get_visible_rect().size / camera.zoom
	var c = bounds.get_center()
	if bounds.size.x < view.x:
		camera.limit_left = floori(c.x - view.x / 2.0)
		camera.limit_right = ceili(c.x + view.x / 2.0)
	else:
		camera.limit_left = int(bounds.position.x)
		camera.limit_right = int(bounds.end.x)
	if bounds.size.y < view.y:
		camera.limit_top = floori(c.y - view.y / 2.0)
		camera.limit_bottom = ceili(c.y + view.y / 2.0)
	else:
		camera.limit_top = int(bounds.position.y)
		camera.limit_bottom = int(bounds.end.y)


func _process(delta: float) -> void:
	if not Dialogue.active and not UI.modal_open and not interior:
		GameState.hour = fmod(GameState.hour + delta * time_scale, 24.0)
	_apply_time()
	_poll_triggers()
	_reveal_t -= delta
	if _reveal_t <= 0.0 and player != null:
		_reveal_t = 0.2
		GameState.reveal(GameState.region, bounds, player.global_position, reveal_radius)
	_update_see_through(delta)
	_update_npcs()


func _update_npcs() -> void:
	if _npcs.is_empty() or player == null:
		return
	for i in range(_npcs.size() - 1, -1, -1):
		if not is_instance_valid(_npcs[i][0]) or not is_instance_valid(_npcs[i][1]):
			_npcs.remove_at(i)
	var p = player.global_position
	var dt = get_process_delta_time()
	for e in _npcs:
		var h: Node2D = e[0]
		var spr: Sprite2D = e[1]
		# someone being moved (a tween, a scene) walks: face the way they go
		# and step through the walk frames
		var last: Vector2 = h.get_meta("last_pos", h.global_position)
		var mv = h.global_position - last
		h.set_meta("last_pos", h.global_position)
		if mv.length() > 0.2:
			var wf = 2 if mv.x > 0 else 1
			if absf(mv.y) > absf(mv.x):
				wf = 0 if mv.y > 0 else 3
			var wt = float(h.get_meta("walk_t", 0.0)) + dt * clampf(mv.length() / maxf(dt, 0.001) / 14.0, 3.0, 9.0)
			h.set_meta("walk_t", wt)
			spr.frame = wf * 4 + int(wt) % 4
			continue
		var d = p - h.global_position
		var f = int(h.get_meta("facing", 0))
		if d.length() < 220.0:
			f = 2 if d.x > 0 else 1
			if absf(d.y) > absf(d.x):
				f = 0 if d.y > 0 else 3
		spr.frame = f * 4


## A bird, squirrel, fox or other small animal living around pos (see Critter).
func add_critter(kind: String, pos: Vector2, seed_value := 0) -> Critter:
	var c = Critter.new()
	world.add_child(c)
	c.setup(kind, pos, seed_value if seed_value != 0 else int(pos.x * 31 + pos.y * 17), self)
	return c


## Pixel chimney smoke rising from pos (world), drifting with the wind.
func add_smoke(pos: Vector2, parent: Node = null, amount := 10) -> CPUParticles2D:
	var smoke = CPUParticles2D.new()
	smoke.position = pos
	smoke.amount = amount
	smoke.lifetime = 4.5
	smoke.preprocess = 4.5
	smoke.texture = Art.tex("fx/smoke.png")
	smoke.direction = Vector2(0.25, -1)
	smoke.spread = 8
	smoke.gravity = Vector2(12, -6)
	smoke.initial_velocity_min = 22
	smoke.initial_velocity_max = 34
	smoke.scale_amount_min = Art.PX * 2.0
	smoke.scale_amount_max = Art.PX * 2.0
	var ramp = Gradient.new()
	ramp.set_color(0, Color(0.92, 0.92, 0.96, 0.55))
	ramp.set_color(1, Color(0.85, 0.86, 0.92, 0.0))
	smoke.color_ramp = ramp
	smoke.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	smoke.z_index = 45
	(parent if parent != null else self).add_child(smoke)
	return smoke


## A tree or a building fades while Feyre, a creature or one of the people
## stands behind it, so nobody vanishes from sight in the woods or behind a house.
func _update_see_through(delta: float) -> void:
	if _tall.is_empty():
		return
	var figures: Array = []   # [feet, middle of the figure], in the world layer's space
	if player != null and is_instance_valid(player):
		var f = world.to_local(player.global_position)
		figures.append([f, f + Vector2(0, -50)])
	for c in get_tree().get_nodes_in_group("creatures"):
		if c is Node2D and (c as Node2D).visible and (c as Node2D).is_inside_tree():
			var f = world.to_local((c as Node2D).global_position)
			figures.append([f, f + Vector2(0, -30)])
	for e in _npcs:
		var h = e[0]
		if is_instance_valid(h) and (h as Node2D).visible:
			var f = world.to_local((h as Node2D).global_position)
			figures.append([f, f + Vector2(0, -50)])
	var step = delta * 3.0
	for t in _tall:
		var s = t[0]
		if not is_instance_valid(s):
			continue
		var crown: Rect2 = t[1]
		var behind = false
		for fig in figures:
			if fig[0].y < t[2] - 6.0 and (crown.has_point(fig[1]) or crown.has_point(fig[0])):
				behind = true
				break
		var a = SEE_THROUGH_ALPHA if behind else 1.0
		if s.modulate.a != a:
			s.modulate.a = move_toward(s.modulate.a, a, step)


func _apply_time() -> void:
	_update_night_lights()
	var g = grade_for_hour(GameState.hour)
	canvas_mod.color = g.mod
	var ex: Color = g.get("exposure", Color.WHITE)
	if ex != _exposure:
		_exposure = ex
		_apply_gain()
	if sun:
		sun.color = g.sun
		sun.energy = g.sun_energy
	_update_casters()
	if rays:
		(rays.material as ShaderMaterial).set_shader_parameter("intensity", g.rays)


## Lamps and lit windows that glow at night and fade by day: [light, energy].
var night_lights: Array = []


## How dark it is: 0 by day, 1 at night, easing through dawn and dusk.
static func night_amount(h: float) -> float:
	if h < 12.0:
		return 1.0 - smoothstep(5.0, 7.5, h)
	return smoothstep(18.0, 20.5, h)


## A light that is only worth seeing in the dark: full strength at night, a
## hint of it by day.
func add_night_light(pos: Vector2, color: Color, energy: float, scl := 1.0, parent: Node = null, day := 0.12) -> PointLight2D:
	var l = add_light(pos, color, energy, scl, false, parent)
	night_lights.append([l, energy, day])
	return l


func _update_night_lights() -> void:
	if night_lights.is_empty():
		return
	var n = night_amount(GameState.hour)
	for e in night_lights:
		var l: PointLight2D = e[0]
		if is_instance_valid(l):
			l.energy = float(e[1]) * lerpf(float(e[2]), 1.0, n)


## Lights for the lit windows (or flames) of a prop, from the glow points
## tools/pixel/build_assets.py records in its meta: the points are pooled
## into cells 'cell' art pixels across, one light a cell, brighter for more
## glass. Night lights: they fade by day.
func add_glow_lights(rel: String, base: Vector2, color: Color, energy := 0.5, scl := 0.5, flip := false, cell := 40.0, parent: Node = null, day := 0.0) -> void:
	var k = Art.PX * Art.pixel_mult(rel)
	var cells := {}
	for w in Art.pixel_meta(rel).get("windows", []):
		var key = Vector2i(floori(float(w[0]) / cell), floori(float(w[1]) / cell))
		var e: Array = cells.get(key, [Vector2.ZERO, 0.0])
		var sz = float(w[2])
		e[0] += Vector2(float(w[0]), float(w[1])) * sz
		e[1] += sz
		cells[key] = e
	var fx = -1.0 if flip else 1.0
	for key in cells:
		var e: Array = cells[key]
		if e[1] < 4.0:
			continue
		var c: Vector2 = e[0] / e[1]
		var pos = Vector2(c.x * fx, c.y) * k
		if parent == null:
			pos += base
		add_night_light(pos, color, energy * clampf(sqrt(e[1]) / 6.0, 0.4, 1.6), scl * clampf(sqrt(e[1]) / 6.0, 0.6, 1.8), parent, day)


## Walks someone placed with add_npc to 'to' at 'speed' world units a second
## (they turn and step as they go); returns when they get there.
func walk_npc(h: Node2D, to: Vector2, speed := 120.0) -> void:
	if h == null or not is_instance_valid(h):
		return
	var d = h.position.distance_to(to)
	if d < 1.0:
		return
	var tw = create_tween()
	tw.tween_property(h, "position", to, d / speed)
	await tw.finished


## Leads Feyre along pts: they walk ahead and stop to wait whenever she
## falls more than 'wait' behind, and hold still while a scene is open.
## Returns at the last point.
func lead_npc(h: Node2D, pts: Array, speed := 110.0, wait := 340.0) -> void:
	for p in pts:
		while is_instance_valid(h) and h.position.distance_to(p) > 2.0:
			var dt = get_process_delta_time()
			if not (Dialogue.active or UI.modal_open or Router.busy) and player.global_position.distance_to(h.position) <= wait:
				h.position = h.position.move_toward(p, speed * dt)
			await get_tree().process_frame


## Puts Feyre at a named spawn point (cutscenes use this behind a fade).
func place_player(spawn_name: String) -> void:
	if spawns.has(spawn_name) and player:
		player.global_position = spawns[spawn_name]
		player.velocity = Vector2.ZERO


static func lerp_grade(keys: Array, h: float) -> Dictionary:
	## keys: [[hour, {mod, sun, sun_energy, rays, exposure?}], ...] sorted by hour.
	if h <= keys[0][0]:
		return keys[0][1]
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if h >= a[0] and h <= b[0]:
			var t: float = (h - a[0]) / max(0.001, b[0] - a[0])
			return {
				"mod": (a[1].mod as Color).lerp(b[1].mod, t),
				"sun": (a[1].sun as Color).lerp(b[1].sun, t),
				"sun_energy": lerpf(a[1].sun_energy, b[1].sun_energy, t),
				"rays": lerpf(a[1].rays, b[1].rays, t),
				"exposure": (a[1].get("exposure", Color.WHITE) as Color).lerp(b[1].get("exposure", Color.WHITE), t),
			}
	return keys[keys.size() - 1][1]
