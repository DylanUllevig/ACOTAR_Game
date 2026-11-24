class_name Art
extends RefCounted
## Asset lookup. All art goes through here so placeholder → final art is a file
## swap: drop a file at the same path (or under res://assets/final/ with the same
## relative path) and it is picked up, along with its _n.png normal map.

const PH := "res://assets/placeholder/"
const FINAL := "res://assets/final/"
const PIXEL := "res://assets/pixel/"

## The walkable world is pixel art. People and animals are drawn at one art
## pixel per PX world units; scenery (props, buildings, ground) is drawn twice
## as chunky, two of their pixels to one of the scenery's. The camera zoom keeps
## every art pixel a whole number of screen pixels (see pixel_zoom). Ground
## tiles are TILE_WORLD world units square.
const PX := 1.5
const SCENERY_PX := 2
const TILE_WORLD := 48.0
## Screen pixels per art pixel at 1920 x 1080, outdoors and indoors.
const PX_SCREEN_OUT := 2
const PX_SCREEN_IN := 3

const GOLD := Color(0.91, 0.77, 0.47)
const GOLD_DIM := Color(0.62, 0.5, 0.3)
const INK := Color(0.07, 0.06, 0.09)
const PARCHMENT := Color(0.95, 0.91, 0.82)
const WINE := Color(0.36, 0.09, 0.14)
const NIGHT := Color(0.08, 0.1, 0.17)

static var _cache = {}
static var _font_cache = {}
static var _density = null


static func resolve(rel: String) -> String:
	## rel like "props/pine_0.png". Pixel art wins over painted final art,
	## which wins over placeholder.
	if ResourceLoader.exists(PIXEL + rel):
		return PIXEL + rel
	if ResourceLoader.exists(FINAL + rel):
		return FINAL + rel
	return PH + rel


static func is_pixel(rel: String) -> bool:
	return resolve(rel).begins_with(PIXEL)


## Scale for a sprite showing 'rel': pixel art is always PX per art pixel (so
## its pixels stay square and whole); painted art keeps the layout scale.
static func sprite_scale(rel: String, scl := 1.0) -> Vector2:
	if is_pixel(rel):
		return Vector2.ONE * PX * pixel_mult(rel)
	var k = scl * density(rel)
	return Vector2(k, k)


static var _pixel_meta = null


## How many character art pixels one art pixel of this sprite covers: scenery
## is chunkier than people (meta "px", else by folder).
static func pixel_mult(rel: String) -> int:
	var m = pixel_meta(rel)
	if m.has("px"):
		return int(m.px)
	return SCENERY_PX if rel.begins_with("props/") or rel.begins_with("terrain/") else 1

## Frame layout and animations of a pixel sheet (assets/pixel/meta.json):
## {"grid": [cols, rows], "frame": [w, h], "anims": {name: [frames]}, ...}
static func pixel_meta(rel: String) -> Dictionary:
	if _pixel_meta == null:
		_pixel_meta = {}
		var path = PIXEL + "meta.json"
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				_pixel_meta = d
	if not is_pixel(rel):
		return {}
	return _pixel_meta.get(rel, {})


## Camera zoom at which one art pixel covers a whole number of screen pixels
## in this window: 'per_px' screen pixels at 1920 x 1080, the nearest whole
## number at other sizes (never below 2 on an ordinary screen).
static func pixel_zoom(vp: Viewport, per_px: int) -> float:
	var vis: Vector2 = vp.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if DisplayServer.get_name() == "headless" or win.x <= 0.0:
		win = vis
	# canvas_items stretch with 'expand': the canvas is scaled by the smaller ratio
	var s = minf(win.x / 1920.0, win.y / 1080.0)
	var d = maxi(1, roundi(per_px * s))
	if s >= 0.55:
		d = maxi(d, 2)
	var base = minf(win.x / vis.x, win.y / vis.y)
	return float(d) / (PX * base)


static func tex(rel: String) -> Texture2D:
	var p = resolve(rel)
	if _cache.has(p):
		return _cache[p]
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_cache[p] = t
	return t


## Final sprites are painted at a higher resolution than the size the game lays
## them out for. tools/fit_art.py records the ratio (layout size / pixel size)
## in assets/final/density.json; multiply a sprite's scale by it to keep its
## size on screen. Placeholders are 1.0.
static func density(rel: String) -> float:
	if _density == null:
		_density = {}
		var path = FINAL + "density.json"
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				_density = d
	if not resolve(rel).begins_with(FINAL):
		return 1.0
	return float(_density.get(rel, 1.0))


## Diffuse + normal map as a CanvasTexture so 2D lights shade it.
static func lit(rel: String) -> Texture2D:
	var key = "lit:" + rel
	if _cache.has(key):
		return _cache[key]
	var diffuse = tex(rel)
	if diffuse == null:
		return null
	var ct = CanvasTexture.new()
	ct.diffuse_texture = diffuse
	var nrel = rel.replace(".png", "_n.png")
	var np = resolve(nrel)
	if ResourceLoader.exists(np):
		ct.normal_texture = load(np)
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if is_pixel(rel) else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cache[key] = ct
	return ct


static func portrait(character: String, expr: String) -> Texture2D:
	for e in [expr, "neutral", "snarl"]:
		var t = tex("portraits/%s/%s.png" % [character, e])
		if t != null:
			return t
	return null


static func font(which := "serif") -> Font:
	if _font_cache.has(which):
		return _font_cache[which]
	var f: Font
	match which:
		"caps":
			var fv = FontVariation.new()
			fv.base_font = load("res://assets/fonts/Cinzel.ttf")
			fv.variation_opentype = {"wght": 600}
			f = fv
		"italic":
			var fv2 = FontVariation.new()
			fv2.base_font = load("res://assets/fonts/CormorantGaramond-Italic.ttf")
			fv2.variation_opentype = {"wght": 500}
			f = fv2
		"bold":
			var fv3 = FontVariation.new()
			fv3.base_font = load("res://assets/fonts/CormorantGaramond.ttf")
			fv3.variation_opentype = {"wght": 700}
			f = fv3
		_:
			var fv4 = FontVariation.new()
			fv4.base_font = load("res://assets/fonts/CormorantGaramond.ttf")
			fv4.variation_opentype = {"wght": 550}
			f = fv4
	_font_cache[which] = f
	return f


static func panel_style(bg := Color(0.07, 0.06, 0.09, 0.92), border := GOLD_DIM, radius := 10, width := 2) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 10
	return s


static func label(text: String, size := 28, color := PARCHMENT, which := "serif") -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_override("font", font(which))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func button(text: String, size := 28) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_override("font", font("caps"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PARCHMENT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.45))
	b.add_theme_stylebox_override("normal", panel_style(Color(0.1, 0.08, 0.1, 0.92), GOLD_DIM, 8))
	b.add_theme_stylebox_override("hover", panel_style(Color(0.2, 0.12, 0.12, 0.95), GOLD, 8))
	b.add_theme_stylebox_override("pressed", panel_style(Color(0.3, 0.14, 0.12, 0.95), GOLD, 8))
	b.add_theme_stylebox_override("disabled", panel_style(Color(0.08, 0.08, 0.08, 0.8), Color(0.3, 0.3, 0.3), 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func soft_light_texture() -> Texture2D:
	return tex("fx/light_soft.png")
