extends Region
## Chapters 2 and 4: the Archeron cottage, in pixel art. One low room: the
## hearth in the middle of the back wall, the cupboard and shelf, the table
## with its benches, and the sisters' bed pushed into the east end. The light
## is firelight against the blue cold leaking through the shutters.
##
## Laid out in world units on the people's pixel density (1.5 world units per
## art pixel, a 16-pixel floor tile = 24 units). The back wall's face runs
## from the top of the room down to WALL_H, where the floor starts.

const W := 840.0                       # inside wall to inside wall, plus the side walls
const WALL_H := 144.0                  # back wall face, top to floor
const FLOOR_END := 456.0               # where the front wall stands
const BAND := 24.0                     # wall tops seen from above
const TILE := 24.0

# Places
const HEARTH := Vector2(262, 286)      # the rug in front of the fire
const FIRE := Vector2(268, 128)        # the flames in the hearth
const WOODPILE := Vector2(192, 196)    # the basket of logs by the hearth
const TABLE := Vector2(282, 432)       # her place at the table, south side
const FOXGLOVE := Vector2(356, 410)    # painted on the table's front leg
const BED := Vector2(716, 330)         # the foot of the sisters' bed
const DOOR := Vector2(420, 456)        # the door in the front wall
const WINDOWS := [Vector2(556, 84), Vector2(642, 84)]

var npc = {}
var hearth_light: PointLight2D
var door_light: PointLight2D
var beast: Node2D
var doe_on_table: Node2D
var _table: Node2D


func build() -> void:
	interior = true
	surface = "wood"
	combat_allowed = false
	map_title = "The Archeron Cottage"
	map_base = Color(0.42, 0.33, 0.26)
	reveal_radius = 3000.0
	bounds = Rect2(0, -40, W, 600)
	spawns = {"door": DOOR + Vector2(0, -40), "hearth": Vector2(352, 262), "start": DOOR + Vector2(0, -40)}
	_backdrop()
	_floor()
	_walls()
	_furniture()
	enclose_bounds()
	_firelight()
	_windows()
	_places()
	_people()
	set_post({"vignette": 0.45, "lift": Vector3(0.02, 0.01, 0.0), "gain": Vector3(1.04, 1.0, 0.95), "saturation": 1.0, "grain": 0.0})


func grade_for_hour(_h: float) -> Dictionary:
	return {"mod": Color(0.6, 0.54, 0.56), "sun": Color.WHITE, "sun_energy": 0.0, "rays": 0.0}


## The dark the room floats in when it is smaller than the screen.
func _backdrop() -> void:
	var b = Polygon2D.new()
	var e = bounds.grow(4000)
	b.polygon = PackedVector2Array([e.position, Vector2(e.end.x, e.position.y), e.end, Vector2(e.position.x, e.end.y)])
	b.color = Color(0.035, 0.028, 0.026)
	b.light_mask = 0
	b.z_index = -20
	add_child(b)


func _floor() -> void:
	var f = Rect2(BAND, WALL_H, W - BAND * 2, FLOOR_END - WALL_H)
	var tex = Art.tex("terrain/planks_pattern.png")
	var s = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, f.size / Art.PX)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * Art.PX
	s.position = f.position
	ground.add_child(s)
	map_rect(f, Color(0.62, 0.48, 0.34))
	# the rug before the hearth and the mat inside the door lie flat on the boards
	_flat("props/rug.png", HEARTH + Vector2(0, -8))
	_flat_tex("interior/doormat.png", DOOR + Vector2(0, -12))


## A piece laid flat on the floor (drawn under everyone), centred on pos.
func _flat(rel: String, pos: Vector2) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = Art.lit(rel)
	s.scale = Art.sprite_scale(rel)
	s.position = pos
	ground.add_child(s)
	return s


func _flat_tex(rel: String, pos: Vector2) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = Art.tex(rel)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * Art.PX
	s.position = pos
	ground.add_child(s)
	return s


## A strip of a repeating texture (wall face or wall top) over rect.
func _strip(rel: String, rect: Rect2, parent: Node, z := 0) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = Art.tex(rel)
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size / Art.PX)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * Art.PX
	s.position = rect.position
	s.z_index = z
	parent.add_child(s)
	return s


func _walls() -> void:
	# the back wall's face, the windows in it, then the tops of the side and
	# front walls, seen from above as dark timber
	_strip("interior/wall_cottage.png", Rect2(BAND, 0, W - BAND * 2, WALL_H), ground)
	for w in WINDOWS:
		var s = _flat_tex("interior/window_night.png", w)
		s.z_index = 1
	_strip("interior/wall_top.png", Rect2(0, -BAND, W, BAND), ground)
	_strip("interior/wall_top.png", Rect2(0, -BAND, BAND, FLOOR_END + BAND * 2), ground, 2)
	_strip("interior/wall_top.png", Rect2(W - BAND, -BAND, BAND, FLOOR_END + BAND * 2), ground, 2)
	# the front wall: its top, with the door in it
	_strip("interior/wall_top.png", Rect2(0, FLOOR_END, DOOR.x - 36, BAND), ground, 2)
	_strip("interior/wall_top.png", Rect2(DOOR.x + 36, FLOOR_END, W - DOOR.x - 36, BAND), ground, 2)
	var door = Polygon2D.new()
	door.polygon = PackedVector2Array([Vector2(DOOR.x - 36, FLOOR_END), Vector2(DOOR.x + 36, FLOOR_END), Vector2(DOOR.x + 36, FLOOR_END + BAND), Vector2(DOOR.x - 36, FLOOR_END + BAND)])
	door.color = Color(0.36, 0.24, 0.16)
	door.z_index = 1
	ground.add_child(door)
	# solid: back wall, side walls, front wall (the door stays shut)
	add_wall(Rect2(0, 0, W, WALL_H + 6))
	add_wall(Rect2(0, 0, BAND, FLOOR_END))
	add_wall(Rect2(W - BAND, 0, BAND, FLOOR_END))
	add_wall(Rect2(0, FLOOR_END - 4, W, 40))
	map_rect(Rect2(0, 0, W, WALL_H), Color(0.25, 0.2, 0.17))
	map_rect(Rect2(0, FLOOR_END, W, BAND), Color(0.25, 0.2, 0.17))


## A piece of furniture standing on the floor, its base at pos, with a soft
## contact shadow and a solid footprint. Returns its holder.
func _piece(rel: String, pos: Vector2, solid: Vector2, flip := false, mark := "") -> Node2D:
	var h = add_prop(rel, pos, 1.0, Vector2.ZERO, solid, flip)
	var sh = Sprite2D.new()
	sh.texture = Art.tex("fx/shadow_l.png")
	var tw = Art.tex(rel).get_width() if Art.tex(rel) else 30
	sh.scale = Vector2(maxf(1.0, roundf(tw * 0.9 / 30.0)), 1.0) * Art.PX
	sh.position = Vector2(0, -2)
	sh.light_mask = 0
	sh.z_index = -1
	h.add_child(sh)
	h.move_child(sh, 0)
	if mark != "":
		var r = Rect2(pos - Vector2(solid.x / 2.0, solid.y), solid)
		map_marks.append(["furniture", r.get_center(), r])
	return h


func _furniture() -> void:
	_piece("props/shelf.png", Vector2(104, 164), Vector2(96, 26), false, "shelf")
	_piece("props/hearth.png", Vector2(268, 166), Vector2(108, 30), false, "hearth")
	_piece("props/dresser.png", Vector2(452, 166), Vector2(88, 26), false, "dresser")
	_piece("props/washstand.png", Vector2(780, 410), Vector2(64, 24), true)
	# the table, with a bench either side and a stool at each end
	_piece("props/bench_in.png", Vector2(318, 340), Vector2(96, 16))
	_table = _piece("props/table.png", Vector2(318, 392), Vector2(86, 40), false, "table")
	_piece("props/stool.png", Vector2(240, 396), Vector2(26, 14))
	_piece("props/stool.png", Vector2(396, 396), Vector2(26, 14), true)
	# the bed the three sisters share: two frames pushed together
	_piece("props/bed_patch.png", Vector2(680, 286), Vector2(70, 110), false, "bed")
	_piece("props/bed_rose.png", Vector2(752, 286), Vector2(70, 110))
	_piece("props/chest.png", Vector2(716, 340), Vector2(62, 22))


func _firelight() -> void:
	hearth_light = add_light(FIRE + Vector2(0, 30), Color(1.0, 0.64, 0.32), 1.15, 2.6, false)
	add_flicker(hearth_light, 0.18, 10.0)
	var ember = add_light(FIRE + Vector2(0, 14), Color(1.0, 0.45, 0.16), 0.8, 0.7, false)
	add_flicker(ember, 0.4, 16.0)
	# warm bounce off the floor and walls, so the corners read
	add_light(Vector2(420, 330), Color(1.0, 0.74, 0.5), 0.28, 3.4, false)
	add_light(Vector2(720, 280), Color(0.9, 0.7, 0.55), 0.22, 1.8, false)
	# sparks rising off the fire
	var sparks = CPUParticles2D.new()
	sparks.position = FIRE + Vector2(0, 8)
	sparks.amount = 10
	sparks.lifetime = 1.4
	sparks.texture = Art.tex("interior/ember.png")
	sparks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(16, 4)
	sparks.direction = Vector2(0, -1)
	sparks.spread = 18
	sparks.gravity = Vector2(0, -10)
	sparks.initial_velocity_min = 16
	sparks.initial_velocity_max = 34
	sparks.scale_amount_min = Art.PX
	sparks.scale_amount_max = Art.PX
	var ramp = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	ramp.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	sparks.color_ramp = ramp
	sparks.z_index = 3
	add_child(sparks)


func _windows() -> void:
	# moonlight through the gaps in the shutters
	for w in WINDOWS:
		add_light(w + Vector2(0, 60), Color(0.45, 0.55, 1.0), 0.4, 0.9, false)
	door_light = add_light(DOOR + Vector2(0, -20), Color(0.5, 0.6, 1.0), 0.0, 3.0, false)


func _places() -> void:
	add_interactable(HEARTH, "Sit by the hearth", func(): await Dialogue.play("ch02_hearth"), 50, "Hearth")
	add_interactable(WOODPILE, "The woodpile", func(): await Dialogue.play("ch02_woodpile"), 40, "Woodpile")
	add_interactable(TABLE, "Sit down to eat", _table_action, 50, "Table")
	add_interactable(FOXGLOVE, "The painted foxglove", func(): await Dialogue.play("ch02_foxglove"), 36)
	add_interactable(BED, "The ironwood bed", _bed_action, 60, "Bed")
	if GameState.chapter == 2 and not GameState.has_flag("ch02_dinner_done"):
		_doe_on_table()


## The carcass Feyre carried home, laid across the table: drawn as part of the
## table, so it is in front of anyone behind it.
func _doe_on_table() -> void:
	var rel = "actors/doe.png"
	var s = Sprite2D.new()
	s.texture = Art.lit(rel)
	if s.texture == null:
		return
	var m = Art.pixel_meta(rel)
	var g: Array = m.get("grid", [1, 1])
	s.hframes = int(g[0])
	s.vframes = int(g[1])
	s.frame = int(m.get("anims", {}).get("dead", [0])[0])
	s.scale = Art.sprite_scale(rel)
	s.offset = Vector2(0, -s.texture.get_height() / (2.0 * s.vframes))
	s.position = Vector2(0, -40)
	_table.add_child(s)
	doe_on_table = s


func _people() -> void:
	if GameState.chapter == 4:
		# gathered at the fire, facing the door
		npc.father = add_npc("father", Vector2(206, 262), "", Callable(), 0)
		npc.nesta = add_npc("nesta", Vector2(262, 252), "", Callable(), 0)
		npc.elain = add_npc("elain", Vector2(318, 262), "", Callable(), 0)
		return
	npc.father = add_npc("father", Vector2(150, 300), "Talk to Father", func(): await Dialogue.play("ch02_father"), 2)
	npc.nesta = add_npc("nesta", Vector2(392, 236), "Talk to Nesta", func(): await Dialogue.play("ch02_nesta"), 0)
	npc.elain = add_npc("elain", Vector2(600, 250), "Talk to Elain", func(): await Dialogue.play("ch02_elain"), 1)


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
	tw.tween_property(door_light, "energy", 1.8, 0.25)
	tw.tween_property(hearth_light, "energy", 0.7, 0.4)
	# the night outside, where the door was
	var night = Polygon2D.new()
	night.polygon = PackedVector2Array([Vector2(DOOR.x - 36, FLOOR_END - 2), Vector2(DOOR.x + 36, FLOOR_END - 2), Vector2(DOOR.x + 40, bounds.end.y), Vector2(DOOR.x - 40, bounds.end.y)])
	night.color = Color(0.06, 0.08, 0.16)
	night.light_mask = 0
	night.z_index = 3
	add_child(night)
	# cold air pouring in: an unlit blue wash over the floor inside the doorway
	var cold = Sprite2D.new()
	cold.texture = Art.soft_light_texture()
	var cm = CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	cold.material = cm
	cold.position = DOOR + Vector2(0, -60)
	cold.scale = Vector2(1.6, 1.1)
	cold.modulate = Color(0.22, 0.36, 0.9, 0.0)
	cold.z_index = 20
	add_child(cold)
	tw.tween_property(cold, "modulate:a", 0.75, 0.35)
	var burst = CPUParticles2D.new()
	burst.position = DOOR + Vector2(0, 10)
	burst.amount = 120
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.lifetime = 1.8
	burst.texture = Art.tex("fx/snowflake.png")
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.direction = Vector2(0, -1)
	burst.spread = 55
	burst.initial_velocity_min = 120
	burst.initial_velocity_max = 300
	burst.damping_min = 120
	burst.damping_max = 200
	var k = Art.PX * 2.0 / float(burst.texture.get_width()) if burst.texture else 1.0
	burst.scale_amount_min = k
	burst.scale_amount_max = k
	burst.z_index = 30
	add_child(burst)
	burst.emitting = true
	# he fills the doorway, seen from behind as he faces them
	var rel = "actors/beast.png"
	var b = Node2D.new()
	b.position = DOOR + Vector2(0, 92)
	var s = Sprite2D.new()
	s.texture = Art.lit(rel)
	var m = Art.pixel_meta(rel)
	var g: Array = m.get("grid", [1, 1])
	s.hframes = int(g[0])
	s.vframes = int(g[1])
	s.frame = int(m.get("anims", {}).get("rear", [0])[0])
	s.scale = Art.sprite_scale(rel)
	s.offset = Vector2(0, -s.texture.get_height() / (2.0 * s.vframes))
	b.add_child(s)
	b.z_index = 21   # over the cold wash and the wall; he is the last thing in the room anyway
	add_child(b)
	beast = b
	add_light(Vector2(0, -120), Color(1.0, 0.85, 0.55), 0.35, 1.2, false, b)
	player.position = spawns.hearth
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
