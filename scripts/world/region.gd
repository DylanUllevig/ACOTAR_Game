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


func _ready() -> void:
	y_sort_enabled = false
	ground = Node2D.new()
	ground.name = "Ground"
	ground.z_index = -10
	add_child(ground)
	shadow_layer = Node2D.new()
	shadow_layer.name = "CastShadows"
	shadow_layer.z_index = -9
	add_child(shadow_layer)
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
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
func add_ground_tile(rel: String, rect: Rect2, tint := Color(1, 1, 1), lit := true) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = Art.lit(rel) if lit else Art.tex(rel)
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.position = rect.position
	s.modulate = tint
	ground.add_child(s)
	return s


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
	s.scale = Vector2(scl, scl)
	holder.add_child(s)
	var mk = _map_kind(rel)
	if mk != "":
		map_marks.append([mk, pos, scl])
	if foot != Vector2.ZERO and s.texture:
		_add_caster(rel, pos, scl, flip)
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


func add_wall(rect: Rect2) -> void:
	var body = StaticBody2D.new()
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = rect.size
	cs.shape = rs
	cs.position = rect.get_center()
	body.add_child(cs)
	add_child(body)


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
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1400, 40)
	p.direction = Vector2(0.2, 1)
	p.spread = 15.0
	p.gravity = Vector2(wind.x * 0.3, fall * 0.3)
	p.initial_velocity_min = fall * 0.6
	p.initial_velocity_max = fall * 1.2
	p.scale_amount_min = 0.25 * size_scale
	p.scale_amount_max = 0.7 * size_scale
	p.color = Color(1.0, 1.0, 1.0, 0.85)
	p.position = Vector2(0, -760)
	p.local_coords = false
	add_child(p)
	return p


func add_rays(color: Color, intensity: float, angle := -0.35) -> void:
	rays = ColorRect.new()
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/post.gdshader")
	post.material = m
	post_layer.add_child(post)


func set_post(params: Dictionary) -> void:
	for k in params:
		(post.material as ShaderMaterial).set_shader_parameter(k, params[k])


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
	s.scale = Vector2(scl, scl)
	s.offset = Vector2(0, -32)
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
	# idle breathing
	var tw = create_tween().set_loops()
	tw.tween_property(s, "scale", Vector2(scl, scl * 1.02), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "scale", Vector2(scl, scl), 1.2).set_trans(Tween.TRANS_SINE)
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
	camera.zoom = Vector2(1.15, 1.15) if not interior else Vector2(1.45, 1.45)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	player.add_child(camera)
	camera.make_current()
	player.camera = camera
	if _snow_near:
		_snow_near.reparent(player, false)
		_snow_far.reparent(player, false)


func _process(delta: float) -> void:
	if not Dialogue.active and not UI.modal_open and not interior:
		GameState.hour = fmod(GameState.hour + delta * time_scale, 24.0)
	_apply_time()
	_poll_triggers()
	_reveal_t -= delta
	if _reveal_t <= 0.0 and player != null:
		_reveal_t = 0.2
		GameState.reveal(GameState.region, bounds, player.global_position, reveal_radius)


func _apply_time() -> void:
	var g = grade_for_hour(GameState.hour)
	canvas_mod.color = g.mod
	if sun:
		sun.color = g.sun
		sun.energy = g.sun_energy
	_update_casters()
	if rays:
		(rays.material as ShaderMaterial).set_shader_parameter("intensity", g.rays)


## Puts Feyre at a named spawn point (cutscenes use this behind a fade).
func place_player(spawn_name: String) -> void:
	if spawns.has(spawn_name) and player:
		player.global_position = spawns[spawn_name]
		player.velocity = Vector2.ZERO


static func lerp_grade(keys: Array, h: float) -> Dictionary:
	## keys: [[hour, {mod, sun, sun_energy, rays}], ...] sorted by hour.
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
			}
	return keys[keys.size() - 1][1]
