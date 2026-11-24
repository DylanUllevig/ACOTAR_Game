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

## The interface: warm paper cards with a rosewood rim, ink-brown text and a
## rose accent (assets/ui, drawn by tools/ui/make_ui.py). Text over the world
## or a dark backdrop keeps PARCHMENT and GOLD with a shadow (label_lit).
const PAPER := Color("fbf4e6")
const PAPER_SHADE := Color("efe2c9")
const PAPER_DEEP := Color("e2cfae")
const ROSEWOOD := Color("6e3434")
const TEXT := Color("3b2620")
const TEXT_SOFT := Color("7d5d50")
const ROSE := Color("b23e57")
const ROSE_DEEP := Color("7c2238")
const HONEY := Color("c8973f")
const HONEY_DEEP := Color("8f6420")
const LEAF := Color("4f7a3e")
## Card textures: SHADOW px of baked shadow round the card, corners CARD_EDGE
## px from the texture's edge (see tools/ui/make_ui.py).
const CARD_SHADOW := 18
const CARD_EDGE := 44

static var _cache = {}
static var _font_cache = {}
static var _theme: Theme = null
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
		"caps_wide":
			var fw = FontVariation.new()
			fw.base_font = load("res://assets/fonts/Cinzel.ttf")
			fw.variation_opentype = {"wght": 700}
			fw.spacing_glyph = 2
			f = fw
		"italic":
			var fv2 = FontVariation.new()
			fv2.base_font = load("res://assets/fonts/CormorantGaramond-Italic.ttf")
			fv2.variation_opentype = {"wght": 500}
			f = fv2
		"bold":
			# lining figures: numbers in the interface stand as tall as capitals
			var fv3 = FontVariation.new()
			fv3.base_font = load("res://assets/fonts/CormorantGaramond.ttf")
			fv3.variation_opentype = {"wght": 700}
			fv3.opentype_features = {"lnum": 1}
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
	s.corner_detail = 12
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 10
	return s


## A paper card ("card", or "card_tip" for the honey-rimmed tip card): a
## nine-patch with its shadow baked in, drawn so the card's edge is the
## control's edge. pad is the space inside: left, top, right, bottom.
static func card_style(kind := "card", pad := Vector4(28, 22, 28, 22)) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = tex_ui(kind)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, CARD_EDGE)
		sb.set_expand_margin(side, CARD_SHADOW)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


## A recessed paper well for lists and detail panes inside a card.
static func inset_style(pad := Vector4(20, 16, 20, 16)) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = tex_ui("inset")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 18)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


## A rounded pill: buttons, tabs, chips, name plates.
static func pill_style(bg: Color, border: Color, radius := 22, width := 2, shadow := 0.28) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.anti_aliasing = true
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	if shadow > 0.0:
		s.shadow_color = Color(0.11, 0.05, 0.04, shadow)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 3)
	return s


static func tex_ui(name: String) -> Texture2D:
	var p = "res://assets/ui/%s.png" % name
	if _cache.has(p):
		return _cache[p]
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_cache[p] = t
	return t


## Text on paper: ink, no shadow.
static func label(text: String, size := 26, color := TEXT, which := "serif") -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_override("font", font(which))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Text over the world or a dark backdrop: light, with a soft shadow.
static func label_lit(text: String, size := 28, color := PARCHMENT, which := "serif") -> Label:
	var l = label(text, size, color, which)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


## A heading on paper with the flourish under it.
static func heading(text: String, size := 40) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t = label(text, size, ROSE_DEEP, "bold")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(flourish())
	return v


static func flourish(width := 300.0) -> TextureRect:
	var f = TextureRect.new()
	f.texture = tex_ui("flourish")
	f.custom_minimum_size = Vector2(width, 22)
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


static func icon(name: String, px := 28.0) -> TextureRect:
	var t = TextureRect.new()
	t.texture = tex_ui(name)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A keyboard key: a small rose cap with the key's name on it.
static func keycap(key: String, size := 20) -> PanelContainer:
	var p = PanelContainer.new()
	var sb = pill_style(ROSE_DEEP, Color(0.36, 0.08, 0.15), 9, 0, 0.0)
	sb.border_width_bottom = 3
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l = label(key, size, PAPER, "bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func button(text: String, size := 28) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	return b


## The look of every control in the interface. Set on the root of each UI
## layer; anything a screen sets on a control itself still wins.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t = Theme.new()
	t.default_font = font("serif")
	t.default_font_size = 26
	t.set_color("font_color", "Label", TEXT)
	# buttons: paper pills that blush rose under the cursor
	t.set_font("font", "Button", font("bold"))
	t.set_stylebox("normal", "Button", pill_style(PAPER, ROSEWOOD))
	t.set_stylebox("hover", "Button", pill_style(ROSE, ROSE_DEEP))
	t.set_stylebox("pressed", "Button", pill_style(ROSE_DEEP, ROSE_DEEP, 22, 2, 0.18))
	t.set_stylebox("hover_pressed", "Button", pill_style(ROSE, ROSE_DEEP, 22, 2, 0.18))
	t.set_stylebox("disabled", "Button", pill_style(Color(PAPER_SHADE, 0.85), PAPER_DEEP, 22, 2, 0.0))
	var focus = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(ROSE, 0.85)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(26)
	focus.corner_detail = 12
	focus.set_expand_margin_all(4)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", PAPER)
	t.set_color("font_pressed_color", "Button", PAPER)
	t.set_color("font_hover_pressed_color", "Button", PAPER)
	t.set_color("font_disabled_color", "Button", Color(TEXT_SOFT, 0.6))
	# rich text (dialogue, journal, item cards)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font("serif"))
	t.set_font("italics_font", "RichTextLabel", font("italic"))
	t.set_font("bold_font", "RichTextLabel", font("bold"))
	# lists
	t.set_stylebox("panel", "ItemList", inset_style(Vector4(10, 10, 10, 10)))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	var sel = pill_style(ROSE, ROSE, 12, 0, 0.0)
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel)
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("hovered", "ItemList", pill_style(Color(PAPER_DEEP, 0.7), PAPER_DEEP, 12, 0, 0.0))
	t.set_font("font", "ItemList", font("serif"))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", PAPER)
	t.set_color("guide_color", "ItemList", Color(0, 0, 0, 0))
	t.set_constant("v_separation", "ItemList", 6)
	# sliders: a paper groove, a rose fill and a round knob
	var groove = pill_style(PAPER_DEEP, Color(ROSEWOOD, 0.6), 6, 1, 0.0)
	groove.content_margin_top = 5
	groove.content_margin_bottom = 5
	var fill = pill_style(ROSE, ROSE_DEEP, 6, 1, 0.0)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", groove)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", tex_ui("knob"))
	t.set_icon("grabber_highlight", "HSlider", tex_ui("knob_hi"))
	t.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	# scroll bars and split bars stay out of the way
	var bar = pill_style(Color(ROSEWOOD, 0.45), Color(0, 0, 0, 0), 5, 0, 0.0)
	bar.content_margin_left = 5
	bar.content_margin_right = 5
	t.set_stylebox("grabber", "VScrollBar", bar)
	t.set_stylebox("grabber_highlight", "VScrollBar", pill_style(ROSE, Color(0, 0, 0, 0), 5, 0, 0.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", pill_style(ROSE_DEEP, Color(0, 0, 0, 0), 5, 0, 0.0))
	var trough = StyleBoxEmpty.new()
	trough.content_margin_left = 5
	trough.content_margin_right = 5
	t.set_stylebox("scroll", "VScrollBar", trough)
	t.set_stylebox("scroll_focus", "VScrollBar", trough)
	t.set_constant("separation", "HSplitContainer", 28)
	t.set_constant("autohide", "HSplitContainer", 1)
	t.set_icon("grabber", "HSplitContainer", ImageTexture.new())
	t.set_icon("h_grabber", "HSplitContainer", ImageTexture.new())
	# tooltips
	var tip = pill_style(PAPER, ROSEWOOD, 12, 2, 0.3)
	tip.content_margin_left = 14
	tip.content_margin_right = 14
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font("font", "TooltipLabel", font("serif"))
	t.set_font_size("font_size", "TooltipLabel", 22)
	t.set_stylebox("panel", "PanelContainer", card_style())
	_theme = t
	return t


static func soft_light_texture() -> Texture2D:
	return tex("fx/light_soft.png")
