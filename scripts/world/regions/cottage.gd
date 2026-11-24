extends Region
## Chapters 2 and 4: the Archeron cottage. Two rooms, one hearth. The room is a
## single painting seen from above at a slant, its front wall folded down
## (rooms/cottage.png). Walls, furniture, people and lights are laid over it
## from measurements on a 1500 x 1000 grid of the painting; S turns grid units
## into world pixels. Furniture that someone can stand behind is cut out of the
## painting and sorted with the people (_stand_up), so it hides their legs.
## The light is firelight against the blue cold leaking through the shutters.

const ROOM_ART := "rooms/cottage.png"
const GRID := Vector2(1500, 1000)
const S := 0.4                         # world pixels per grid unit

# Places on the grid
const HEARTH := Vector2(465, 420)      # the rug in front of the fire
const FIRE := Vector2(465, 235)        # the flames in the painting
const WOODPILE := Vector2(650, 380)
const TABLE := Vector2(430, 545)       # behind the table, clear of the flowers
const FOXGLOVE := Vector2(737, 772)    # painted on the table's front leg
const BED := Vector2(1170, 605)
const DOOR := Vector2(527, 790)        # where the floor meets the door
const WINDOWS := [Vector2(215, 805), Vector2(840, 805)]

# Solid ground: walls, then furniture (the floor each piece covers, as drawn)
const WALLS := [
	Rect2(0, 0, 1040, 305),            # back wall
	Rect2(0, 0, 40, 1000),             # west wall
	Rect2(1460, 0, 40, 1000),          # east wall
	Rect2(0, 830, 1500, 170),          # front wall, folded down
	Rect2(1036, 0, 52, 500),           # partition, north of the bedroom doorway
	Rect2(1046, 636, 44, 194),         # partition, south of it
]
const FURNITURE := {
	"settle": Rect2(40, 140, 258, 245),
	"hearth": Rect2(300, 0, 305, 350),
	"woodpile": Rect2(598, 190, 106, 145),
	"bucket": Rect2(832, 220, 86, 128),
	"broom": Rect2(960, 290, 76, 62),
	"table": Rect2(350, 584, 450, 151),
	"bench_w": Rect2(240, 560, 93, 175),
	"bench_e": Rect2(817, 560, 93, 175),
	"bed": Rect2(1088, 0, 372, 560),
	"dresser": Rect2(1250, 528, 210, 262),
}
# What stands up from the floor and can hide someone behind it: its outline in
# the painting, and the line where it meets the floor, which it is sorted by.
const STAND_UP := {
	"table": [[Vector2(364, 470), Vector2(786, 470), Vector2(799, 615), Vector2(797, 627), Vector2(350, 627), Vector2(348, 612)], 742.0],
	"bench_w": [[Vector2(274, 499), Vector2(334, 499), Vector2(310, 684), Vector2(314, 690), Vector2(314, 751), Vector2(246, 751), Vector2(241, 690), Vector2(238, 684)], 751.0],
	"bench_e": [[Vector2(816, 499), Vector2(871, 499), Vector2(912, 684), Vector2(906, 690), Vector2(904, 749), Vector2(839, 749), Vector2(842, 690), Vector2(845, 684)], 749.0],
	"dresser": [[Vector2(1253, 529), Vector2(1453, 529), Vector2(1463, 592), Vector2(1460, 784), Vector2(1256, 784), Vector2(1256, 592)], 784.0],
	"post_n": [[Vector2(1038, 0), Vector2(1084, 0), Vector2(1084, 502), Vector2(1038, 502)], 502.0],
	"post_s": [[Vector2(1048, 633), Vector2(1090, 633), Vector2(1090, 792), Vector2(1048, 792)], 792.0],
}

var npc = {}
var hearth_light: PointLight2D
var door_light: PointLight2D
var beast: Node2D
var doe_on_table: Node2D
var _room_tex: Texture2D
var _cutouts = {}


## Grid to world.
static func gp(v: Vector2) -> Vector2:
	return v * S


static func grect(rect: Rect2) -> Rect2:
	return Rect2(rect.position * S, rect.size * S)


func build() -> void:
	interior = true
	surface = "wood"
	combat_allowed = false
	camera_zoom = 2.0
	map_title = "The Archeron Cottage"
	map_base = Color(0.42, 0.33, 0.26)
	reveal_radius = 3000.0
	bounds = Rect2(Vector2.ZERO, GRID * S)
	spawns = {"door": gp(Vector2(527, 776)), "hearth": gp(Vector2(690, 440)), "start": gp(Vector2(527, 776))}
	_backdrop()
	_room_tex = Art.lit(ROOM_ART)
	if _room_tex != null:
		_room()
	else:
		_placeholder_room()
	for w in WALLS:
		add_wall(grect(w))
		map_rect(grect(w), Color(0.25, 0.2, 0.17))
	for k in FURNITURE:
		add_wall(grect(FURNITURE[k]))
		if k in ["settle", "hearth", "table", "bench_w", "bench_e", "bed", "dresser"]:
			map_marks.append(["furniture", gp(FURNITURE[k].get_center()), grect(FURNITURE[k])])
	# the partition stops the firelight; it reaches the bedroom through the doorway
	add_occluder_rect(grect(Rect2(1040, 0, 46, 500)))
	add_occluder_rect(grect(Rect2(1050, 636, 38, 156)))
	enclose_bounds()
	_firelight()
	_windows()
	_places()
	_people()
	set_post({"vignette": 0.75, "lift": Vector3(0.03, 0.01, 0.0), "gain": Vector3(1.05, 0.98, 0.9), "saturation": 0.95, "grain": 0.03})


func grade_for_hour(_h: float) -> Dictionary:
	return {"mod": Color(0.56, 0.5, 0.52), "sun": Color.WHITE, "sun_energy": 0.0, "rays": 0.0}


## The dark the room floats in when it is smaller than the screen.
func _backdrop() -> void:
	var b = Polygon2D.new()
	var e = bounds.grow(4000)
	b.polygon = PackedVector2Array([e.position, Vector2(e.end.x, e.position.y), e.end, Vector2(e.position.x, e.end.y)])
	b.color = Color(0.035, 0.028, 0.026)
	b.light_mask = 0
	b.z_index = -20
	add_child(b)


func _room() -> void:
	var s = Sprite2D.new()
	s.texture = _room_tex
	s.centered = false
	s.scale = Vector2.ONE * (GRID.x * S / _room_tex.get_width())
	ground.add_child(s)
	map_rect(grect(Rect2(40, 300, 1420, 530)), Color(0.62, 0.48, 0.34))
	for k in STAND_UP:
		_cutouts[k] = _stand_up(STAND_UP[k][0], STAND_UP[k][1])


## A piece of the painting cut out along 'outline' and put among the people,
## sorted by base_y (where it stands on the floor): someone north of that line
## is drawn behind it. It is lit the same as the painting under it, so it only
## shows where it covers someone.
func _stand_up(outline: Array, base_y: float) -> Polygon2D:
	var poly = Polygon2D.new()
	poly.texture = _room_tex
	var k = _room_tex.get_width() / GRID.x
	var base = gp(Vector2(0, base_y))
	var pts = PackedVector2Array()
	var uv = PackedVector2Array()
	for v in outline:
		pts.append(gp(v) - base)
		uv.append(v * k)
	poly.polygon = pts
	poly.uv = uv
	poly.position = base
	world.add_child(poly)
	return poly


## Without the painting: the same room in flat shapes, so nothing else changes.
func _placeholder_room() -> void:
	add_ground_tile("terrain/planks.png", grect(Rect2(40, 300, 1420, 530)))
	map_rect(grect(Rect2(40, 300, 1420, 530)), Color(0.62, 0.48, 0.34))
	for w in WALLS:
		_flat(w, Color(0.32, 0.28, 0.26), -9)
	for k in FURNITURE:
		_flat(FURNITURE[k], Color(0.42, 0.3, 0.2), -8)
	var ph = Label.new()
	ph.text = "PLACEHOLDER ROOM (manifest: room.cottage)"
	ph.position = gp(Vector2(60, 310))
	ph.scale = Vector2.ONE * 0.5
	ph.modulate = Color(1, 1, 1, 0.7)
	ph.z_index = -7
	add_child(ph)


func _flat(rect: Rect2, col: Color, z: int) -> void:
	var c = Polygon2D.new()
	var rr = grect(rect)
	c.polygon = PackedVector2Array([rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)])
	c.color = col
	c.z_index = z
	add_child(c)


func _firelight() -> void:
	# the painted flames, kept moving
	var fire = ColorRect.new()
	fire.position = gp(FIRE + Vector2(-62, -72))
	fire.size = gp(Vector2(124, 120))
	fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/hearth.gdshader")
	m.set_shader_parameter("power", 0.55)
	fire.material = m
	fire.z_index = -6
	add_child(fire)
	hearth_light = add_light(gp(Vector2(465, 300)), Color(1.0, 0.62, 0.3), 1.2, 3.0, true)
	add_flicker(hearth_light, 0.18, 10.0)
	var ember = add_light(gp(FIRE + Vector2(0, 30)), Color(1.0, 0.42, 0.15), 0.7, 0.9, false)
	add_flicker(ember, 0.4, 16.0)
	# warm bounce off the floor and walls, so the corners read; no shadows
	add_light(gp(Vector2(600, 560)), Color(1.0, 0.72, 0.48), 0.22, 3.5, false)
	# the bedroom, lit only by what comes through the doorway and a little spill
	add_light(gp(Vector2(1260, 430)), Color(0.85, 0.66, 0.52), 0.24, 1.8, false)


func _windows() -> void:
	# moonlight through the gaps in the shutters
	for w in WINDOWS:
		add_light(gp(w), Color(0.45, 0.55, 1.0), 0.45, 0.9, false)
	door_light = add_light(gp(DOOR + Vector2(0, -20)), Color(0.5, 0.6, 1.0), 0.0, 3.0, true)


func _places() -> void:
	add_interactable(gp(HEARTH), "Sit by the hearth", func(): await Dialogue.play("ch02_hearth"), 50, "Hearth")
	add_interactable(gp(WOODPILE), "The woodpile", func(): await Dialogue.play("ch02_woodpile"), 40, "Woodpile")
	add_interactable(gp(TABLE), "Sit down to eat", _table_action, 55, "Table")
	add_interactable(gp(FOXGLOVE), "The painted foxglove", func(): await Dialogue.play("ch02_foxglove"), 40)
	add_interactable(gp(BED), "The ironwood bed", _bed_action, 60, "Bed")
	if GameState.chapter == 2 and not GameState.has_flag("ch02_dinner_done"):
		_doe_on_table()


## The carcass Feyre carried home, laid across the table. It belongs to the
## table's cut-out so it is drawn on the tabletop, in front of anyone behind.
func _doe_on_table() -> void:
	var rel = "actors/doe_dead.png" if Art.tex("actors/doe_dead.png") != null else "actors/doe.png"
	var on_top = Vector2(575, 612)   # the middle of the tabletop's front edge
	if _cutouts.has("table"):
		var s = Sprite2D.new()
		s.texture = Art.lit(rel)
		s.scale = Vector2.ONE * 1.1 * Art.density(rel)
		s.offset = Vector2(0, -s.texture.get_height() / 2.0)
		var t: Node2D = _cutouts.table
		s.position = gp(on_top) - t.position
		t.add_child(s)
		doe_on_table = s
	else:
		doe_on_table = add_prop(rel, gp(on_top), 1.1, Vector2.ZERO)


func _people() -> void:
	if GameState.chapter == 4:
		# gathered at the fire, facing the door
		npc.father = add_npc("father", gp(Vector2(300, 425)), "", Callable(), 0)
		npc.nesta = add_npc("nesta", gp(Vector2(420, 420)), "", Callable(), 0)
		npc.elain = add_npc("elain", gp(Vector2(545, 425)), "", Callable(), 0)
		return
	npc.father = add_npc("father", gp(Vector2(150, 450)), "Talk to Father", func(): await Dialogue.play("ch02_father"), 2)
	npc.nesta = add_npc("nesta", gp(Vector2(330, 420)), "Talk to Nesta", func(): await Dialogue.play("ch02_nesta"), 0)
	npc.elain = add_npc("elain", gp(Vector2(880, 420)), "Talk to Elain", func(): await Dialogue.play("ch02_elain"), 1)


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
	tw.tween_property(door_light, "energy", 2.0, 0.25)
	tw.tween_property(hearth_light, "energy", 0.7, 0.4)
	# the night outside, where the door was
	var night = Polygon2D.new()
	var d = grect(Rect2(432, 806, 190, 192))
	night.polygon = PackedVector2Array([d.position, Vector2(d.end.x, d.position.y), d.end, Vector2(d.position.x, d.end.y)])
	night.color = Color(0.05, 0.07, 0.13)
	night.light_mask = 0
	night.z_index = -8
	add_child(night)
	# cold air pouring in: an unlit blue wash over the floor inside the doorway
	# (the beast is drawn above it, lit by the door light, so his fur keeps its
	# colour instead of washing out to white)
	var cold = Sprite2D.new()
	cold.texture = Art.soft_light_texture()
	var cm = CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	cold.material = cm
	cold.position = gp(DOOR + Vector2(0, -50))
	cold.scale = Vector2(1.8, 1.3)
	cold.modulate = Color(0.22, 0.36, 0.9, 0.0)
	cold.z_index = 20
	add_child(cold)
	tw.tween_property(cold, "modulate:a", 0.9, 0.35)
	var burst = CPUParticles2D.new()
	burst.position = gp(DOOR + Vector2(0, 40))
	burst.amount = 140
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.lifetime = 1.8
	burst.texture = Art.tex("fx/snowflake.png")
	burst.direction = Vector2(0, -1)
	burst.spread = 60
	burst.initial_velocity_min = 140
	burst.initial_velocity_max = 360
	burst.damping_min = 120
	burst.damping_max = 200
	burst.scale_amount_min = 0.25
	burst.scale_amount_max = 0.7
	burst.z_index = 30
	add_child(burst)
	burst.emitting = true
	# he fills the doorway, seen from behind as he faces them; the placeholder
	# beast stands side-on
	var rear = Art.resolve("actors/beast.png").begins_with(Art.FINAL)
	var bs = 0.85 if rear else 0.9
	beast = add_prop("actors/beast.png", gp(Vector2(527, 985)), bs, Vector2.ZERO)
	beast.z_index = 21   # over the cold wash; he is the last thing in the room anyway
	var eye_at = Vector2(-29.5, -183) * bs if rear else Vector2(80, -130) * bs
	var eye = add_light(eye_at, Color(0.4, 1.0, 0.6), 0.7, 0.3, false, beast)
	add_flicker(eye, 0.15, 3.0)
	player.position = spawns.hearth
	player.facing = 0


func _ready() -> void:
	super._ready()
	map_exit(gp(DOOR), "Door")
	Audio.ambience("hearth")
	Audio.music("cottage", 3.0)


func on_enter() -> void:
	if GameState.chapter == 2 and not GameState.has_flag("ch02_arrived"):
		GameState.set_flag("ch02_arrived")
		await Dialogue.play("ch02_arrive")
	elif GameState.chapter == 4 and not GameState.has_flag("ch04_done"):
		await Dialogue.play("ch04_beast")
