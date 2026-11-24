class_name PixelGround
extends Node2D
## Pixel-art ground. A region paints terrain names onto a grid of tile
## corners; the base terrain covers everything, and every terrain above it is
## its own tile layer. Each tile of a layer is picked from the terrain's atlas
## by which of its four corners that terrain covers (16 shapes, made by
## tools/pixel/tiles.py), so edges are soft, wobbly and continuous from tile
## to tile instead of following the grid. A terrain counts as covering the
## corners of every terrain above it in the list, so it runs on underneath
## their edges.

var origin := Vector2.ZERO      # world position of corner (0, 0)
var cols := 0                   # corners across and down
var rows := 0
var step := 48.0                # world units per tile
var layers: Array = []          # terrain names, base first
var _rank := {}
var _c := PackedByteArray()     # corner terrain rank, row-major
var _noise := FastNoiseLite.new()


## tile_world: world units per tile (default Art.TILE_WORLD, the scenery
## density; rooms use half that so the floor matches the people's pixels).
func setup(rect: Rect2, terrain_layers: Array, seed := 7, tile_world := 0.0) -> void:
	step = tile_world if tile_world > 0.0 else Art.TILE_WORLD
	origin = (rect.position / step).floor() * step - Vector2(step, step)
	cols = int(ceil((rect.end.x - origin.x) / step)) + 2
	rows = int(ceil((rect.end.y - origin.y) / step)) + 2
	layers = terrain_layers
	_rank.clear()
	for i in layers.size():
		_rank[layers[i]] = i
	_c.resize(cols * rows)
	_c.fill(0)
	_noise.seed = seed
	_noise.frequency = 0.012
	_noise.fractal_octaves = 3


func rank(name: String) -> int:
	return int(_rank.get(name, 0))


func corner_pos(i: int, j: int) -> Vector2:
	return origin + Vector2(i, j) * step


func set_corner(i: int, j: int, r: int) -> void:
	if i >= 0 and j >= 0 and i < cols and j < rows:
		_c[j * cols + i] = r


func get_corner(i: int, j: int) -> int:
	if i < 0 or j < 0 or i >= cols or j >= rows:
		return 0
	return _c[j * cols + i]


## Paints every corner for which f(world position) is true.
func paint_where(name: String, area: Rect2, f: Callable) -> void:
	var r = rank(name)
	var a = Vector2i(((area.position - origin) / step).floor())
	var b = Vector2i(((area.end - origin) / step).ceil())
	for j in range(maxi(a.y, 0), mini(b.y + 1, rows)):
		for i in range(maxi(a.x, 0), mini(b.x + 1, cols)):
			if f.call(corner_pos(i, j)):
				_c[j * cols + i] = r


func paint_rect(name: String, rect: Rect2, wobble := 0.0) -> void:
	paint_where(name, rect.grow(wobble), func(p: Vector2) -> bool:
		var w = _noise.get_noise_2dv(p) * wobble
		return rect.grow(w).has_point(p))


func paint_circle(name: String, c: Vector2, radius: float, wobble := 0.0) -> void:
	var box = Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2).grow(wobble)
	paint_where(name, box, func(p: Vector2) -> bool:
		return p.distance_to(c) <= radius + _noise.get_noise_2dv(p) * wobble)


func paint_ellipse(name: String, c: Vector2, radii: Vector2, wobble := 0.0) -> void:
	var box = Rect2(c - radii, radii * 2).grow(wobble)
	paint_where(name, box, func(p: Vector2) -> bool:
		var d = (p - c) / radii
		return d.length() <= 1.0 + _noise.get_noise_2dv(p) * wobble / maxf(radii.x, radii.y))


## A band 'width' wide along a smooth curve through pts.
func paint_path(name: String, pts: PackedVector2Array, width: float, wobble := 0.0) -> void:
	var r = rank(name)
	var curve = Region.smooth_curve(pts, 16.0)
	var half = width * 0.5
	for k in range(curve.size() - 1):
		var a: Vector2 = curve[k]
		var b: Vector2 = curve[k + 1]
		var box = Rect2(a, Vector2.ZERO).expand(b).grow(half + wobble)
		var g0 = Vector2i(((box.position - origin) / step).floor())
		var g1 = Vector2i(((box.end - origin) / step).ceil())
		for j in range(maxi(g0.y, 0), mini(g1.y + 1, rows)):
			for i in range(maxi(g0.x, 0), mini(g1.x + 1, cols)):
				var p = corner_pos(i, j)
				var w = half + _noise.get_noise_2dv(p) * wobble
				if p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= w * w:
					_c[j * cols + i] = r


func paint_poly(name: String, poly: PackedVector2Array) -> void:
	var box = Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	paint_where(name, box, func(p: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(p, poly))


## The terrain under a world position: the highest-ranked of the tile's
## corners that is at least half present there (bilinear weight).
func at(p: Vector2) -> String:
	var g = (p - origin) / step
	var i = int(floor(g.x))
	var j = int(floor(g.y))
	var u = g.x - i
	var v = g.y - j
	var w = {}
	for e in [[i, j, (1 - u) * (1 - v)], [i + 1, j, u * (1 - v)], [i, j + 1, (1 - u) * v], [i + 1, j + 1, u * v]]:
		var r = get_corner(e[0], e[1])
		# a corner of a higher terrain also counts for every terrain below it
		for k in range(r + 1):
			w[k] = float(w.get(k, 0.0)) + float(e[2])
	var best = 0
	for k in w:
		if float(w[k]) >= 0.5 and int(k) > best:
			best = int(k)
	return String(layers[best]) if best < layers.size() else String(layers[0])


func build() -> void:
	for ch in get_children():
		ch.queue_free()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# base: the base terrain's seamless pattern repeated under everything
	var base = Sprite2D.new()
	base.texture = Art.tex("terrain/%s_pattern.png" % layers[0])
	var base_atlas: Texture2D = Art.tex("terrain/%s.png" % layers[0])
	var bt = int(base_atlas.get_height() / 16) if base_atlas else 16
	base.centered = false
	base.region_enabled = true
	base.region_rect = Rect2(0, 0, (cols - 1) * bt, (rows - 1) * bt)
	base.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	base.scale = Vector2.ONE * step / bt
	base.position = origin
	add_child(base)
	for r in range(1, layers.size()):
		var tex: Texture2D = Art.tex("terrain/%s.png" % layers[r])
		if tex == null:
			continue
		var tp = int(tex.get_height() / 16)          # tile size in art pixels: 16 shapes down the atlas
		var per = int(tex.get_width() / tp)          # pattern positions across the atlas
		var span = int(round(sqrt(per)))             # pattern size in tiles
		var ts = TileSet.new()
		ts.tile_size = Vector2i(tp, tp)
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(tp, tp)
		ts.add_source(src, 0)
		var layer = TileMapLayer.new()
		layer.name = String(layers[r])
		layer.tile_set = ts
		layer.scale = Vector2.ONE * step / tp
		layer.position = origin
		var made = {}
		var any = false
		for j in range(rows - 1):
			for i in range(cols - 1):
				var idx = (1 if _c[j * cols + i] >= r else 0) \
					| (2 if _c[j * cols + i + 1] >= r else 0) \
					| (4 if _c[(j + 1) * cols + i] >= r else 0) \
					| (8 if _c[(j + 1) * cols + i + 1] >= r else 0)
				if idx == 0:
					continue
				var at_c = Vector2i((j % span) * span + (i % span), idx)
				if not made.has(at_c):
					src.create_tile(at_c)
					made[at_c] = true
				layer.set_cell(Vector2i(i, j), 0, at_c)
				any = true
		if any:
			add_child(layer)
		else:
			layer.free()
