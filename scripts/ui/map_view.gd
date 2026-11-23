class_name MapView
extends VBoxContainer
## Two maps. "This area" is drawn from the live region (its props, paths and
## points of interest) under a fog of war that lifts as Feyre explores.
## "Prythian" is a schematic of the wider world: only places she has visited or
## heard of are named. The map image the user supplied is reference only and
## is not shipped.

const PARCHMENT := Color(0.86, 0.8, 0.67)
const INK := Color(0.2, 0.15, 0.11)
const REGION_FOR := {"forest": "mortal_forest", "cottage": "archeron_cottage", "village": "mortal_village", "wall_ride": "the_wall"}

var mode := 0                 # 0 this area, 1 Prythian
var _canvas: Control
var _btn_area: Button
var _btn_world: Button
var _fog_tex: ImageTexture
var _t := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var head = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 16)
	add_child(head)
	_btn_area = Art.button("This area", 24)
	_btn_area.toggle_mode = true
	_btn_area.pressed.connect(func(): set_mode(0))
	head.add_child(_btn_area)
	_btn_world = Art.button("Prythian", 24)
	_btn_world.toggle_mode = true
	_btn_world.pressed.connect(func(): set_mode(1))
	head.add_child(_btn_world)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(1380, 620)
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)
	set_mode(0 if Router.current_region != null else 1)


func set_mode(m: int) -> void:
	mode = m
	_btn_area.button_pressed = m == 0
	_btn_world.button_pressed = m == 1
	if m == 0:
		_build_fog()
	_canvas.queue_redraw()
	Audio.ui("page", -8.0)


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		_canvas.queue_redraw()


func _draw_map() -> void:
	var r = Rect2(Vector2.ZERO, _canvas.size)
	_canvas.draw_rect(r, PARCHMENT, true)
	# soft darkened edges, like old paper
	for i in 6:
		_canvas.draw_rect(r.grow(-i * 4.0), Color(0.45, 0.35, 0.22, 0.05), false, 8.0)
	if mode == 0:
		_draw_area(r.grow(-30))
	else:
		_draw_world(r.grow(-30))
	_canvas.draw_rect(r, Art.GOLD_DIM, false, 3.0)


# -------------------------------------------------------------- this area
func _fit(b: Rect2, into: Rect2) -> Transform2D:
	var s = min(into.size.x / b.size.x, into.size.y / b.size.y)
	var off = into.position + (into.size - b.size * s) / 2.0 - b.position * s
	return Transform2D(0.0, Vector2(s, s), 0.0, off)


func _build_fog() -> void:
	var reg = Router.current_region
	if reg == null:
		_fog_tex = null
		return
	var b: Rect2 = reg.bounds
	var cells = Vector2i(ceili(b.size.x / GameState.MAP_CELL), ceili(b.size.y / GameState.MAP_CELL))
	var g = GameState.explored_grid(GameState.region, cells)
	var img = Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	for y in cells.y:
		for x in cells.x:
			# soften: a cell is partly clear if its neighbours are explored
			var seen = 0.0
			var tot = 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx = clampi(x + dx, 0, cells.x - 1)
					var yy = clampi(y + dy, 0, cells.y - 1)
					var w = 2.0 if dx == 0 and dy == 0 else 1.0
					seen += w * float(g[yy * cells.x + xx])
					tot += w
			var a = 1.0 - seen / tot
			img.set_pixel(x, y, Color(0.8, 0.74, 0.6, a * 0.97))
	_fog_tex = ImageTexture.create_from_image(img)


func _draw_area(into: Rect2) -> void:
	var reg = Router.current_region
	if reg == null:
		_canvas.draw_string(Art.font("italic"), into.get_center() - Vector2(200, 0), "No map here.", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, INK)
		return
	var b: Rect2 = reg.bounds
	var xf = _fit(b, into.grow(-20))
	var area = Rect2(xf * b.position, b.size * xf.get_scale())
	_canvas.draw_rect(area, reg.map_base if "map_base" in reg else Color(0.9, 0.9, 0.92), true)
	_canvas.draw_set_transform_matrix(xf)
	var sc = xf.get_scale().x
	for sh in reg.map_shapes:
		match String(sh.type):
			"rect":
				_canvas.draw_rect(sh.rect, sh.color, true)
			"line":
				_canvas.draw_polyline(sh.pts, sh.color, float(sh.width), true)
			"poly":
				_canvas.draw_colored_polygon(sh.pts, sh.color)
	for m in reg.map_marks:
		var kind: String = m[0]
		var p: Vector2 = m[1]
		match kind:
			"pine":
				var s1 = 26.0
				_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s1 * 1.6), p + Vector2(s1, 0), p + Vector2(-s1, 0)]), Color(0.24, 0.36, 0.3, 0.9))
			"tree":
				_canvas.draw_circle(p + Vector2(0, -14), 20.0, Color(0.42, 0.36, 0.3, 0.75))
			"rock":
				_canvas.draw_circle(p, 30.0, Color(0.5, 0.5, 0.52, 0.85))
			"bramble":
				_canvas.draw_circle(p, 34.0, Color(0.35, 0.28, 0.3, 0.85))
			"rose":
				_canvas.draw_circle(p, 18.0, Color(0.62, 0.18, 0.2, 0.9))
			"house":
				_canvas.draw_rect(Rect2(p - Vector2(120, 110), Vector2(240, 120)), Color(0.45, 0.33, 0.25, 0.95), true)
				_canvas.draw_rect(Rect2(p - Vector2(120, 110), Vector2(240, 120)), INK, false, 6.0)
			"stall":
				_canvas.draw_rect(Rect2(p - Vector2(80, 50), Vector2(160, 50)), Color(0.6, 0.25, 0.22, 0.95), true)
			"fountain":
				_canvas.draw_circle(p, 70.0, Color(0.55, 0.62, 0.7, 0.95))
			"furniture":
				_canvas.draw_rect(m[2], Color(0.42, 0.3, 0.2, 0.9), true)
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	if _fog_tex:
		_canvas.draw_texture_rect(_fog_tex, area, false)
	# points of interest she has seen, and the ways out
	var f = Art.font("italic")
	var fc = Art.font("caps")
	var cells = Vector2i(ceili(b.size.x / GameState.MAP_CELL), ceili(b.size.y / GameState.MAP_CELL))
	var g = GameState.explored_grid(GameState.region, cells)
	for m in reg.map_marks:
		if m[0] != "poi" and m[0] != "exit":
			continue
		var wp: Vector2 = m[1]
		var cx = clampi(int((wp.x - b.position.x) / GameState.MAP_CELL), 0, cells.x - 1)
		var cy = clampi(int((wp.y - b.position.y) / GameState.MAP_CELL), 0, cells.y - 1)
		if g[cy * cells.x + cx] == 0:
			continue
		var sp = xf * wp
		if m[0] == "poi":
			_canvas.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -9), sp + Vector2(9, 0), sp + Vector2(0, 9), sp + Vector2(-9, 0)]), Color(0.72, 0.5, 0.15))
			_canvas.draw_string(f, sp + Vector2(14, 8), String(m[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
		else:
			_canvas.draw_circle(sp, 10.0, Color(0.55, 0.12, 0.14))
			_canvas.draw_string(fc, sp + Vector2(16, 8), String(m[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.45, 0.08, 0.1))
	# Feyre
	if reg.player:
		var pp = xf * reg.player.global_position
		var ring = 16.0 + 6.0 * sin(_t * 4.0)
		_canvas.draw_arc(pp, ring, 0, TAU, 32, Color(0.6, 0.08, 0.1, 0.7), 3.0, true)
		var dir = [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP][reg.player.facing]
		var side = dir.orthogonal()
		_canvas.draw_colored_polygon(PackedVector2Array([pp + dir * 14.0, pp - dir * 8.0 + side * 9.0, pp - dir * 8.0 - side * 9.0]), Color(0.6, 0.08, 0.1))
	# title and compass
	var title = String(reg.map_title) if "map_title" in reg else ""
	_canvas.draw_string(fc, into.position + Vector2(8, 30), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	var pct = _explored_percent(g)
	_canvas.draw_string(f, into.position + Vector2(8, 62), "%d%% explored" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.35, 0.28, 0.2))
	_compass(into.position + Vector2(into.size.x - 60, 70))


func _explored_percent(g: PackedByteArray) -> int:
	if g.is_empty():
		return 0
	var n = 0
	for v in g:
		n += 1 if v != 0 else 0
	return int(round(100.0 * n / g.size()))


func _compass(c: Vector2) -> void:
	var col = Color(0.35, 0.25, 0.15)
	_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -36), c + Vector2(8, 0), c + Vector2(-8, 0)]), Color(0.55, 0.12, 0.14))
	_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 36), c + Vector2(8, 0), c + Vector2(-8, 0)]), col)
	_canvas.draw_arc(c, 22.0, 0, TAU, 32, col, 2.0, true)
	_canvas.draw_string(Art.font("caps"), c + Vector2(-8, -42), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)


# ---------------------------------------------------------------- Prythian
func _to_px(xy: Array, r: Rect2) -> Vector2:
	# map_xy covers a tall portrait map; fit the x 0.4..0.95, y 0.25..0.9 band.
	var nx = (float(xy[0]) - 0.4) / 0.55
	var ny = (float(xy[1]) - 0.25) / 0.65
	return r.position + Vector2(nx * r.size.x, ny * r.size.y)


func _draw_world(r: Rect2) -> void:
	var f = Art.font("caps")
	var fi = Art.font("italic")
	# the Wall: a pale seam across the land
	var wy = _to_px([0.6, 0.795], r).y
	_canvas.draw_rect(Rect2(Vector2(r.position.x, wy - 8), Vector2(r.size.x, 16)), Color(0.35, 0.42, 0.55, 0.55), true)
	_canvas.draw_string(f, Vector2(r.position.x + 14, wy - 16), "THE WALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.15, 0.18, 0.25))
	_canvas.draw_string(fi, Vector2(r.position.x + 14, wy + 40), "The mortal lands", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
	_canvas.draw_string(fi, Vector2(r.position.x + 14, wy - 46), "Prythian", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
	var here: String = REGION_FOR.get(GameState.region, "")
	for id in DB.locations:
		var loc: Dictionary = DB.locations[id]
		var known = GameState.places.has(id)
		var p = _to_px(loc.map_xy, r)
		if not known:
			continue
		draw_place(p, String(loc.name), id == here, f)
	for id in DB.flavor_courts:
		var p2 = _to_px(DB.flavor_courts[id].map_xy, r)
		if r.has_point(p2) and GameState.places.has(id):
			_canvas.draw_string(fi, p2, DB.flavor_courts[id].name, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.35, 0.3, 0.26))
	var n_known = 0
	for id in DB.locations:
		if GameState.places.has(id):
			n_known += 1
	_canvas.draw_string(fi, r.position + Vector2(8, r.size.y - 12), "%d of %d places known. The rest of the map fills in as the story goes north." % [n_known, DB.locations.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.35, 0.28, 0.2))


func draw_place(p: Vector2, label: String, here: bool, f: Font) -> void:
	_canvas.draw_circle(p, 9.0, Art.GOLD)
	_canvas.draw_arc(p, 11.0, 0, TAU, 24, Color(0.15, 0.1, 0.08), 2.0)
	if here:
		_canvas.draw_arc(p, 18.0 + 3.0 * sin(_t * 4.0), 0, TAU, 32, Color(0.7, 0.1, 0.12), 4.0)
	_canvas.draw_string(f, p + Vector2(16, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.18, 0.12, 0.1))
