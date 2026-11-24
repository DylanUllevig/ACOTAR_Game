class_name Art
extends RefCounted
## Asset lookup. All art goes through here so placeholder → final art is a file
## swap: drop a file at the same path (or under res://assets/final/ with the same
## relative path) and it is picked up, along with its _n.png normal map.

const PH := "res://assets/placeholder/"
const FINAL := "res://assets/final/"

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
	## rel like "props/pine_0.png". Final art wins over placeholder.
	if ResourceLoader.exists(FINAL + rel):
		return FINAL + rel
	return PH + rel


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
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
