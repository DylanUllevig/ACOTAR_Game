extends Node
## Boot + title screen. Router mounts regions and battles under this node.

var title: Control


func _ready() -> void:
	Router.root = self
	Router.current_region = null
	Router.battle = null
	Dialogue.active = false
	UI.modal_open = false
	if OS.is_debug_build():
		var problems = DB.validate()
		for p in problems:
			push_error("DATA: " + p)
	var args = OS.get_cmdline_user_args()
	if "--autotest" in args or "--shots" in args:
		var t = Node.new()
		t.set_script(load("res://tests/screenshot_tour.gd"))
		add_child(t)
		return
	_show_title()
	await UI.fade_in(0.8)


func _show_title() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	title = Control.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(title)
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/fog.gdshader")
	m.set_shader_parameter("fog_color", Color(0.75, 0.2, 0.28))
	m.set_shader_parameter("density", 0.55)
	m.set_shader_parameter("world_scale", 0.0018)
	bg.material = m
	var base = ColorRect.new()
	base.color = Color(0.05, 0.04, 0.07)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(base)
	title.add_child(bg)
	var snow = CPUParticles2D.new()
	snow.amount = 200
	snow.lifetime = 10
	snow.preprocess = 10
	snow.texture = Art.tex("fx/snowflake.png")
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(1100, 10)
	snow.position = Vector2(960, -20)
	snow.gravity = Vector2(8, 20)
	snow.initial_velocity_min = 20
	snow.initial_velocity_max = 50
	snow.scale_amount_min = 0.3
	snow.scale_amount_max = 1.1
	title.add_child(snow)
	var v = VBoxContainer.new()
	# centre on screen whatever the window size: anchors at the middle, offsets
	# around it, growing both ways. (Setting a preset and then a pixel position
	# breaks once the parent is resized, which pushed the title off screen.)
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -500
	v.offset_right = 500
	v.offset_top = -300
	v.offset_bottom = 300
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	title.add_child(v)
	var t1 = Art.label("A COURT OF", 46, Art.GOLD_DIM, "caps")
	var t2 = Art.label("THORNS AND ROSES", 92, Art.GOLD, "caps")
	var t3 = Art.label("Book One  ·  a personal fan project, not for distribution", 28, Art.PARCHMENT, "italic")
	for l in [t1, t2, t3]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	v.add_child(spacer)
	var b_new = Art.button("New Game", 34)
	b_new.pressed.connect(_new_game)
	v.add_child(b_new)
	var b_cont = Art.button("Continue", 34)
	b_cont.disabled = not SaveSystem.has_slot("auto")
	b_cont.pressed.connect(_continue)
	v.add_child(b_cont)
	var b_quit = Art.button("Quit", 34)
	b_quit.pressed.connect(func(): get_tree().quit())
	v.add_child(b_quit)
	b_new.grab_focus.call_deferred()
	var ver = Art.label("Milestone 1 vertical slice  ·  v%s  ·  placeholder art" % ProjectSettings.get_setting("application/config/version"), 20, Color(1, 1, 1, 0.4), "caps")
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 30
	ver.offset_top = -50
	title.add_child(ver)


func _new_game() -> void:
	GameState.new_game()
	await UI.fade_out(0.6)
	title.get_parent().queue_free()  # the title CanvasLayer
	await Router.goto_region("forest", "start")


func _continue() -> void:
	if not SaveSystem.load_slot("auto"):
		return
	await UI.fade_out(0.6)
	title.get_parent().queue_free()  # the title CanvasLayer
	await Router.continue_game()
