class_name CardView
extends Control
## One card, drawn in code. Used in the hand, rewards, shop and deck screens.

signal clicked(view: CardView)
signal hovered(view: CardView, on: bool)

const SIZE := Vector2(250, 350)
const TYPE_COLORS := {
	"attack": Color(0.42, 0.1, 0.12),
	"skill": Color(0.1, 0.22, 0.32),
	"move": Color(0.16, 0.3, 0.18),
	"power": Color(0.32, 0.18, 0.4),
}

var card: Dictionary = {}      # instance {uid,id,up}
var def: Dictionary = {}
var playable = true
var desc_override = ""
var base_position = Vector2.ZERO
var base_rotation = 0.0
var hovering = false

var _frame: Panel
var _art: TextureRect
var _name: Label
var _cost: Label
var _type: Label
var _text: RichTextLabel
var _cost_bg: Panel


func setup(c: Dictionary, description := "") -> CardView:
	card = c
	def = DB.card_effective(c.id, c.get("up", false))
	desc_override = description
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	return self


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var tcol: Color = TYPE_COLORS.get(def.get("type", "skill"), Color(0.2, 0.2, 0.2))
	_frame = Panel.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = tcol.darkened(0.35)
	sb.border_color = Art.GOLD if def.get("rarity", "") in ["rare", "canon"] else Art.GOLD_DIM
	sb.set_border_width_all(4 if def.get("rarity", "") in ["rare", "canon"] else 3)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	_frame.add_theme_stylebox_override("panel", sb)
	_frame.size = SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_art = TextureRect.new()
	_art.texture = Art.tex("cards/%s.png" % def.id)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.position = Vector2(14, 48)
	_art.size = Vector2(SIZE.x - 28, 120)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	_name = Art.label(def.get("name", "?"), 24, Art.PARCHMENT if not card.get("up", false) else Color(0.6, 1.0, 0.6), "caps")
	_name.position = Vector2(44, 10)
	_name.size = Vector2(SIZE.x - 54, 32)
	_name.clip_text = true
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 20 if def.get("name", "").length() > 14 else 23)
	add_child(_name)

	_cost_bg = Panel.new()
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.12, 0.1, 0.06)
	cs.border_color = Art.GOLD
	cs.set_border_width_all(3)
	cs.set_corner_radius_all(22)
	_cost_bg.add_theme_stylebox_override("panel", cs)
	_cost_bg.position = Vector2(-10, -10)
	_cost_bg.size = Vector2(48, 48)
	_cost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_bg)
	_cost = Art.label(str(int(def.get("cost", 0))), 30, Art.GOLD, "caps")
	_cost.position = Vector2(-10, -12)
	_cost.size = Vector2(48, 48)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_cost)

	var tline = String(def.get("type", "")).to_upper()
	var tags: Array = def.get("tags", [])
	if "bow" in tags:
		tline += "  ·  BOW"
	elif "knife" in tags:
		tline += "  ·  KNIFE"
	if def.get("range", "any") == "near":
		tline += "  ·  NEAR"
	_type = Art.label(tline, 15, Art.GOLD_DIM, "caps")
	_type.position = Vector2(0, 172)
	_type.size = Vector2(SIZE.x, 20)
	_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_type)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.fit_content = false
	_text.add_theme_font_override("normal_font", Art.font("serif"))
	_text.add_theme_font_override("bold_font", Art.font("bold"))
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_font_size_override("bold_font_size", 19)
	_text.add_theme_color_override("default_color", Art.PARCHMENT)
	_text.position = Vector2(14, 196)
	_text.size = Vector2(SIZE.x - 28, SIZE.y - 200)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.text = "[center]" + _fmt(desc_override if desc_override != "" else _static_text()) + "[/center]"
	add_child(_text)
	set_playable(playable)


func _static_text() -> String:
	var t: String = def.get("text", "")
	for e in def.get("effects", []):
		if e.type == "damage":
			t = t.replace("{dmg}", str(int(e.amount)))
		elif e.type == "block":
			t = t.replace("{block}", str(int(e.amount)))
	return t


func _fmt(t: String) -> String:
	for kw in ["Exhaust", "Innate", "Hidden", "Evade", "Block", "Bleed", "Vulnerable", "Strength", "Ash-Struck", "Noise", "Near", "Far"]:
		t = t.replace(kw, "[b]" + kw + "[/b]")
	return t


func set_playable(v: bool) -> void:
	playable = v
	modulate = Color(1, 1, 1, 1) if v else Color(0.55, 0.55, 0.6, 1)


func update_text(description: String) -> void:
	desc_override = description
	if _text:
		_text.text = "[center]" + _fmt(description) + "[/center]"


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovering = true
		hovered.emit(self, true)
	elif what == NOTIFICATION_MOUSE_EXIT:
		hovering = false
		hovered.emit(self, false)
