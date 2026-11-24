extends Region
## Chapters 2 and 4: the Archeron cottage. Two rooms, one hearth. The light here
## is all firelight against the blue cold leaking through the shutters.

const HEARTH := Vector2(520, 170)
const TABLE := Vector2(620, 520)
const DOOR := Vector2(560, 900)

var npc = {}
var hearth_light: PointLight2D
var door_light: PointLight2D
var beast: Node2D
var doe_on_table: Node2D


func build() -> void:
	interior = true
	surface = "wood"
	combat_allowed = false
	map_title = "The Archeron Cottage"
	map_base = Color(0.42, 0.33, 0.26)
	reveal_radius = 3000.0
	bounds = Rect2(0, 0, 1500, 980)
	spawns = {"door": DOOR + Vector2(0, -70), "hearth": HEARTH + Vector2(140, 200), "start": DOOR + Vector2(0, -70)}
	add_ground_tile("terrain/planks.png", Rect2(60, 60, 1380, 860))
	map_rect(Rect2(60, 60, 1380, 860), Color(0.62, 0.48, 0.34))
	_walls()
	enclose_bounds()
	_hearth()
	_furniture()
	_painted_details()
	_windows()
	_people()
	set_post({"vignette": 0.75, "lift": Vector3(0.03, 0.01, 0.0), "gain": Vector3(1.05, 0.98, 0.9), "saturation": 0.95, "grain": 0.03})


func grade_for_hour(_h: float) -> Dictionary:
	return {"mod": Color(0.45, 0.39, 0.42), "sun": Color.WHITE, "sun_energy": 0.0, "rays": 0.0}


func _wall_rect(r: Rect2, col := Color(0.32, 0.28, 0.26)) -> void:
	var c = Polygon2D.new()
	c.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	c.color = col
	c.z_index = -9
	add_child(c)
	add_wall(r)
	add_occluder_rect(r)
	map_rect(r, Color(0.25, 0.2, 0.17))


func _walls() -> void:
	_wall_rect(Rect2(40, 40, 1420, 70))              # north wall
	_wall_rect(Rect2(40, 900, 470, 40))              # south wall left of door
	_wall_rect(Rect2(620, 900, 840, 40))             # south wall right of door
	_wall_rect(Rect2(40, 40, 30, 900))               # west
	_wall_rect(Rect2(1430, 40, 30, 900))             # east
	_wall_rect(Rect2(1000, 40, 30, 330))             # partition to bedroom (top)
	_wall_rect(Rect2(1000, 520, 30, 380))            # partition (bottom), doorway between
	# door
	var d = Polygon2D.new()
	d.polygon = PackedVector2Array([Vector2(510, 900), Vector2(620, 900), Vector2(620, 940), Vector2(510, 940)])
	d.color = Color(0.3, 0.2, 0.13)
	d.z_index = -8
	d.name = "Door"
	add_child(d)


func _hearth() -> void:
	var stones = Polygon2D.new()
	stones.polygon = PackedVector2Array([Vector2(-110, -70), Vector2(110, -70), Vector2(130, 40), Vector2(-130, 40)])
	stones.color = Color(0.38, 0.35, 0.33)
	stones.position = HEARTH
	stones.z_index = -7
	add_child(stones)
	var fire = ColorRect.new()
	fire.size = Vector2(150, 90)
	fire.position = HEARTH + Vector2(-75, -70)
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/hearth.gdshader")
	fire.material = m
	fire.z_index = -6
	add_child(fire)
	hearth_light = add_light(HEARTH + Vector2(0, 60), Color(1.0, 0.62, 0.3), 1.9, 5.5, true)
	# warm bounce light so the far corners read; no shadows so it never pools oddly
	add_light(Vector2(700, 480), Color(1.0, 0.7, 0.45), 0.5, 8.0, false)
	add_flicker(hearth_light, 0.22, 10.0)
	var ember = add_light(HEARTH + Vector2(0, 20), Color(1.0, 0.4, 0.15), 0.8, 1.2, false)
	add_flicker(ember, 0.4, 16.0)
	add_interactable(HEARTH + Vector2(0, 90), "Sit by the hearth", func(): await Dialogue.play("ch02_hearth"), 110, "Hearth")
	map_marks.append(["furniture", HEARTH, Rect2(HEARTH - Vector2(130, 70), Vector2(260, 110))])
	# woodpile: five logs
	for i in 5:
		var lg = Polygon2D.new()
		lg.polygon = PackedVector2Array([Vector2(0, 0), Vector2(60, 0), Vector2(60, 16), Vector2(0, 16)])
		lg.color = Color(0.36, 0.24, 0.16)
		lg.position = Vector2(700 + (i % 3) * 8, 140 + i * 14)
		add_child(lg)
	add_interactable(Vector2(730, 190), "The woodpile", func(): await Dialogue.play("ch02_woodpile"), 80, "Woodpile")


func _furniture() -> void:
	# the rickety table: dining area, workspace and kitchen
	var table = Polygon2D.new()
	table.polygon = PackedVector2Array([Vector2(-170, -70), Vector2(170, -70), Vector2(170, 70), Vector2(-170, 70)])
	table.color = Color(0.45, 0.3, 0.2)
	table.position = TABLE
	world.add_child(table)
	var body = StaticBody2D.new()
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(340, 140)
	cs.shape = rs
	body.add_child(cs)
	body.position = TABLE
	add_child(body)
	map_marks.append(["furniture", TABLE, Rect2(TABLE - Vector2(170, 70), Vector2(340, 140))])
	add_interactable(TABLE + Vector2(0, 100), "Sit down to eat", _table_action, 130, "Table")
	add_interactable(TABLE + Vector2(-190, 0), "The painted foxglove", func(): await Dialogue.play("ch02_foxglove"), 90)
	if GameState.chapter == 2 and not GameState.has_flag("ch02_dinner_done"):
		doe_on_table = add_prop("actors/doe.png", TABLE + Vector2(0, 20), 1.0, Vector2.ZERO)
	# ironwood bed in the second room
	var bed = Polygon2D.new()
	bed.polygon = PackedVector2Array([Vector2(-150, -110), Vector2(150, -110), Vector2(150, 110), Vector2(-150, 110)])
	bed.color = Color(0.22, 0.16, 0.14)
	bed.position = Vector2(1240, 300)
	bed.z_index = -5
	add_child(bed)
	var quilt = Polygon2D.new()
	quilt.polygon = PackedVector2Array([Vector2(-140, -40), Vector2(140, -40), Vector2(140, 100), Vector2(-140, 100)])
	quilt.color = Color(0.48, 0.42, 0.38)
	quilt.position = Vector2(1240, 300)
	quilt.z_index = -4
	add_child(quilt)
	add_interactable(Vector2(1240, 460), "The ironwood bed", _bed_action, 120, "Bed")
	map_marks.append(["furniture", Vector2(1240, 300), Rect2(Vector2(1090, 190), Vector2(300, 220))])
	# dresser with painted drawers
	var dresser = Polygon2D.new()
	dresser.polygon = PackedVector2Array([Vector2(0, 0), Vector2(160, 0), Vector2(160, 60), Vector2(0, 60)])
	dresser.color = Color(0.36, 0.26, 0.2)
	dresser.position = Vector2(1100, 700)
	add_child(dresser)
	var cot = Polygon2D.new()
	cot.polygon = PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 70), Vector2(0, 70)])
	cot.color = Color(0.3, 0.26, 0.22)
	cot.position = Vector2(150, 330)
	cot.z_index = -5
	add_child(cot)


func _painted_details() -> void:
	# Feyre's chipped paintwork: vines along the walls, flames on the hearthstones,
	# violets/roses, flames and stars on the dresser drawers.
	var cols = [Color(0.75, 0.22, 0.22), Color(0.85, 0.75, 0.25), Color(0.25, 0.35, 0.75)]
	var vine = Line2D.new()
	vine.width = 4
	vine.default_color = Color(0.35, 0.5, 0.3, 0.8)
	for i in 40:
		vine.add_point(Vector2(90 + i * 22, 112 + sin(i * 0.9) * 6))
	vine.z_index = -8
	add_child(vine)
	for i in 20:
		var dot = Polygon2D.new()
		var r = 5.0
		dot.polygon = PackedVector2Array([Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(0, r)])
		dot.color = cols[i % 3]
		dot.position = Vector2(100 + i * 44, 112 + sin(i * 2.0) * 6)
		dot.z_index = -7
		add_child(dot)
	for i in 6:
		var flame = Polygon2D.new()
		flame.polygon = PackedVector2Array([Vector2(-6, 6), Vector2(0, -10), Vector2(6, 6)])
		flame.color = Color(0.85, 0.4, 0.15)
		flame.position = HEARTH + Vector2(-100 + i * 40, 34)
		flame.z_index = -6
		add_child(flame)
	for i in 3:
		var knob = Polygon2D.new()
		knob.polygon = PackedVector2Array([Vector2(-8, 0), Vector2(0, -8), Vector2(8, 0), Vector2(0, 8)])
		knob.color = [Color(0.8, 0.4, 0.6), Color(0.9, 0.45, 0.15), Color(0.95, 0.85, 0.3)][i]
		knob.position = Vector2(1130 + i * 50, 730)
		add_child(knob)
	# the foxglove pillar on the table edge: too dark, too blue
	for i in 6:
		var bell = Polygon2D.new()
		bell.polygon = PackedVector2Array([Vector2(-6, -4), Vector2(6, -4), Vector2(4, 6), Vector2(-4, 6)])
		bell.color = Color(0.3, 0.3, 0.62)
		bell.position = TABLE + Vector2(-162, -50 + i * 18)
		world.add_child(bell)


func _windows() -> void:
	for x in [260.0, 880.0]:
		var w = Polygon2D.new()
		w.polygon = PackedVector2Array([Vector2(-36, 0), Vector2(36, 0), Vector2(36, 16), Vector2(-36, 16)])
		w.color = Color(0.35, 0.45, 0.75)
		w.position = Vector2(x, 900)
		w.z_index = -7
		add_child(w)
		add_light(Vector2(x, 880), Color(0.45, 0.55, 1.0), 0.55, 1.6, true)
	door_light = add_light(DOOR + Vector2(0, -20), Color(0.5, 0.6, 1.0), 0.0, 3.0, true)


func _people() -> void:
	var ch = GameState.chapter
	if ch == 4:
		npc.father = add_npc("father", HEARTH + Vector2(-140, 120), "", Callable(), 0)
		npc.nesta = add_npc("nesta", HEARTH + Vector2(-60, 90), "", Callable(), 0)
		npc.elain = add_npc("elain", HEARTH + Vector2(10, 90), "", Callable(), 0)
		return
	npc.father = add_npc("father", Vector2(260, 360), "Talk to Father", func(): await Dialogue.play("ch02_father"), 2)
	npc.nesta = add_npc("nesta", HEARTH + Vector2(-150, 110), "Talk to Nesta", func(): await Dialogue.play("ch02_nesta"), 0)
	npc.elain = add_npc("elain", TABLE + Vector2(220, -40), "Talk to Elain", func(): await Dialogue.play("ch02_elain"), 1)


func _table_action() -> void:
	if GameState.chapter != 2:
		return
	if GameState.has_flag("ch02_dinner_done"):
		await Dialogue.play("ch02_foxglove")
	elif GameState.has_flag("ch02_father_talked") and GameState.has_flag("ch02_nesta_talked") and GameState.has_flag("ch02_elain_talked"):
		await Dialogue.play("ch02_dinner")
		if is_instance_valid(doe_on_table):
			doe_on_table.queue_free()
	else:
		await Dialogue.play("ch02_table_early")


func _bed_action() -> void:
	if GameState.chapter != 2:
		return
	if GameState.has_flag("ch02_dinner_done"):
		await Dialogue.play("ch02_bed")
	else:
		await Dialogue.play("ch02_bed_early")


func door_burst() -> void:
	## Chapter 4: the beast breaks in. Cold floods the room.
	var tw = create_tween().set_parallel(true)
	tw.tween_property(door_light, "energy", 1.6, 0.25)
	tw.tween_property(hearth_light, "energy", 0.8, 0.4)
	var door = get_node_or_null("Door")
	if door:
		door.visible = false
	var burst = CPUParticles2D.new()
	burst.position = DOOR
	burst.amount = 160
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.lifetime = 2.2
	burst.texture = Art.tex("fx/snowflake.png")
	burst.direction = Vector2(0, -1)
	burst.spread = 70
	burst.initial_velocity_min = 200
	burst.initial_velocity_max = 520
	burst.damping_min = 120
	burst.damping_max = 200
	burst.scale_amount_min = 0.4
	burst.scale_amount_max = 1.2
	burst.z_index = 30
	add_child(burst)
	burst.emitting = true
	beast = add_prop("actors/beast.png", DOOR + Vector2(0, -60), 1.7, Vector2(60, 20))
	var eye = add_light(Vector2(90, -150), Color(0.4, 1.0, 0.6), 0.7, 0.4, false, beast)
	add_flicker(eye, 0.15, 3.0)
	player.position = HEARTH + Vector2(140, 240)
	player.facing = 0


func _ready() -> void:
	super._ready()
	map_exit(DOOR, "Door")
	Audio.ambience("hearth")
	Audio.music("cottage", 3.0)


func on_enter() -> void:
	if GameState.chapter == 2 and not GameState.has_flag("ch02_arrived"):
		GameState.set_flag("ch02_arrived")
		await Dialogue.play("ch02_arrive")
	elif GameState.chapter == 4 and not GameState.has_flag("ch04_done"):
		await Dialogue.play("ch04_beast")
