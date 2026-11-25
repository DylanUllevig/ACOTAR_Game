class_name Hud
extends Control
## The in-world HUD: Feyre's health and coin (top left), chapter, clock and
## objective (top right), the hunt's boss bar and stealth eye (top centre),
## the hotbar with the selected item's name and the interact prompt (bottom
## centre), pickup notices (bottom left), the bow-draw ring at the cursor and
## the red edge when she is hurt. Everything at the bottom steps aside while a
## dialogue box is up.

const SLOT_PX := 84
const SLOT_GAP := 8
const MARGIN := 24
## Feyre's face in her painted portrait (portraits/feyre/neutral.png), for
## the medallion.
const FEYRE_FACE := Rect2(270, 62, 272, 272)
const KEYS := [["WASD", "Move"], ["Click", "Use item"], ["E", "Interact"], ["Wheel", "Hotbar"], ["Tab", "Satchel"], ["M", "Map"], ["J", "Journal"], ["Esc", "Menu"]]

var _left_card: PanelContainer
var _hp: Meter
var _hp_l: Label
var _face: Medallion
var _tier_l: Label
var _coin_l: Label
var _chapter_l: Label
var _clock_l: Label
var _sky_icon: TextureRect
var _objective_l: Label
var _objective_rule: ColorRect
var _hotbar_panel: PanelContainer
var _slots: Array[ItemSlot] = []
var _item_row: HBoxContainer
var _item_pill: PanelContainer
var _item_name: Label
var _item_name_t := 0.0
var _prompt_box: HBoxContainer
var _prompt_key: Label
var _prompt_l: Label
var _notices: VBoxContainer
var _notice_rows := {}           # item id -> [row, label, count, time_left]
var _hint: PanelContainer
var _hint_t := 60.0
var _bottom: Array[Control] = []
var _vignette: ColorRect
var _vig_mat: ShaderMaterial
var _hurt := 0.0
var _reticle: Control

var _boss: PanelContainer
var _boss_name: Label
var _boss_bar: Meter
var _boss_status: Label
var _stealth: HBoxContainer
var _eye: Control
var _stealth_l: Label
var _noise: Meter
var _eye_state := 0              # 0 hidden, 1 exposed, 2 seen
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_vignette()
	_build_left()
	_build_right()
	_build_boss()
	_build_hotbar()
	_build_hint()
	_build_notices()
	_reticle = Control.new()
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_draw_reticle)
	add_child(_reticle)
	GameState.changed.connect(refresh)
	GameState.inventory_changed.connect(_refresh_slots)
	GameState.hotbar_changed.connect(_on_hotbar_changed)
	GameState.item_gained.connect(notice_item)
	GameState.hp_changed.connect(func(_o, _n): refresh())
	refresh()


# ------------------------------------------------------------------ build
func _card(pad := Vector4(24, 16, 24, 16)) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.card_style("card", pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _pill(pad := Vector4(18, 4, 22, 6)) -> PanelContainer:
	var p = PanelContainer.new()
	var sb = Art.pill_style(Art.PAPER, Art.ROSEWOOD, 22)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = load("res://shaders/vignette.gdshader")
	_vignette.material = _vig_mat
	add_child(_vignette)


func _build_left() -> void:
	# her medallion, name and standing, health and purse
	var p = _card(Vector4(16, 14, 26, 14))
	p.position = Vector2(MARGIN, MARGIN)
	add_child(p)
	_left_card = p
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	_face = Medallion.new(92)
	_face.set_face(Art.portrait("feyre", "neutral"), FEYRE_FACE)
	h.add_child(_face)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var nm = Art.label("Feyre", 30, Art.ROSE_DEEP, "bold")
	top.add_child(nm)
	_tier_l = Art.label("", 21, Art.TEXT_SOFT, "italic")
	_tier_l.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_tier_l)
	var hp_row = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	v.add_child(hp_row)
	hp_row.add_child(Art.icon("heart", 28))
	_hp = Meter.new(214, 18)
	_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp)
	_hp_l = Art.label("", 21, Art.TEXT, "bold")
	_hp_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_l)
	var coin_row = HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 8)
	v.add_child(coin_row)
	var coin = TextureRect.new()
	coin.texture = Art.tex("items/coin.png")
	coin.custom_minimum_size = Vector2(28, 28)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_row.add_child(coin)
	_coin_l = Art.label("", 22, Art.HONEY_DEEP, "bold")
	_coin_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_row.add_child(_coin_l)


func _build_right() -> void:
	# the chapter and the hour, and what she means to do next
	var p = _card(Vector4(26, 16, 26, 18))
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -560
	p.offset_right = -MARGIN
	p.offset_top = MARGIN
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	p.add_child(v)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_chapter_l = Art.label("", 18, Art.ROSE, "caps_wide")
	_chapter_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chapter_l.clip_text = true
	row.add_child(_chapter_l)
	_sky_icon = Art.icon("sun", 26)
	row.add_child(_sky_icon)
	_clock_l = Art.label("", 22, Art.TEXT, "bold")
	_clock_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_clock_l)
	_objective_rule = ColorRect.new()
	_objective_rule.color = Color(Art.HONEY, 0.55)
	_objective_rule.custom_minimum_size = Vector2(0, 2)
	_objective_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_objective_rule)
	_objective_l = Art.label("", 24, Art.TEXT)
	_objective_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_l.custom_minimum_size = Vector2(486, 0)
	v.add_child(_objective_l)


func _build_boss() -> void:
	_boss = _card(Vector4(30, 14, 30, 16))
	_boss.anchor_left = 0.5
	_boss.anchor_right = 0.5
	# 680 wide so it clears the side cards at the narrowest canvas (1920)
	_boss.offset_left = -340
	_boss.offset_right = 340
	_boss.offset_top = MARGIN
	_boss.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss.visible = false
	add_child(_boss)
	var bv = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	_boss.add_child(bv)
	_boss_name = Art.label("", 24, Art.ROSE_DEEP, "caps_wide")
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_boss_name)
	_boss_bar = Meter.new(620, 18)
	_boss_bar.fill_color = Color("9e1f2e")
	_boss_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(_boss_bar)
	_boss_status = Art.label("", 21, Art.TEXT_SOFT, "italic")
	_boss_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_boss_status)
	_stealth = HBoxContainer.new()
	_stealth.alignment = BoxContainer.ALIGNMENT_CENTER
	_stealth.add_theme_constant_override("separation", 12)
	_stealth.visible = false
	bv.add_child(_stealth)
	_eye = Control.new()
	_eye.custom_minimum_size = Vector2(54, 30)
	_eye.draw.connect(_draw_eye)
	_stealth.add_child(_eye)
	var sv = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 3)
	_stealth.add_child(sv)
	_stealth_l = Art.label("", 21, Art.TEXT, "bold")
	sv.add_child(_stealth_l)
	_noise = Meter.new(220, 9)
	_noise.fill_color = Art.HONEY
	_noise.ghost_color = Color(0, 0, 0, 0)
	sv.add_child(_noise)


func _build_hotbar() -> void:
	var n = GameState.hotbar_size()
	var width = n * SLOT_PX + (n - 1) * SLOT_GAP + 32
	var tray_h = SLOT_PX + 28
	_hotbar_panel = _card(Vector4(16, 14, 16, 14))
	_hotbar_panel.anchor_left = 0.5
	_hotbar_panel.anchor_right = 0.5
	_hotbar_panel.anchor_top = 1.0
	_hotbar_panel.anchor_bottom = 1.0
	_hotbar_panel.offset_left = -width / 2.0
	_hotbar_panel.offset_right = width / 2.0
	_hotbar_panel.offset_top = -MARGIN - tray_h
	_hotbar_panel.offset_bottom = -MARGIN
	_hotbar_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_hotbar_panel)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", SLOT_GAP)
	_hotbar_panel.add_child(row)
	for i in n:
		var key = str((i + 1) % 10)
		var s = ItemSlot.new(i, SLOT_PX, key)
		s.slot_pressed.connect(_on_slot_pressed)
		row.add_child(s)
		_slots.append(s)
	var above = -MARGIN - tray_h - 14
	# the selected item's name, briefly, in a little pill over the tray
	_item_row = _centered_row(above - 46, above)
	_item_pill = _pill()
	_item_name = Art.label("", 24, Art.TEXT, "bold")
	_item_pill.add_child(_item_name)
	_item_row.add_child(_item_pill)
	_item_pill.modulate.a = 0.0
	# what E does here
	_prompt_box = _centered_row(above - 110, above - 58)
	_prompt_box.visible = false
	var pp = _pill(Vector4(10, 6, 26, 8))
	_prompt_box.add_child(pp)
	var ph = HBoxContainer.new()
	ph.add_theme_constant_override("separation", 12)
	pp.add_child(ph)
	var cap = Art.keycap("E", 22)
	_prompt_key = cap.get_child(0)
	ph.add_child(cap)
	_prompt_l = Art.label("", 26, Art.TEXT, "bold")
	_prompt_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(_prompt_l)
	_bottom = [_hotbar_panel, _item_row, _prompt_box]


func _centered_row(top: float, bottom: float) -> HBoxContainer:
	var r = HBoxContainer.new()
	r.anchor_left = 0.5
	r.anchor_right = 0.5
	r.anchor_top = 1.0
	r.anchor_bottom = 1.0
	r.offset_left = -560
	r.offset_right = 560
	r.offset_top = top
	r.offset_bottom = bottom
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _build_hint() -> void:
	# the keys, for the first minute of play, in the bottom-right corner
	_hint = _card(Vector4(24, 14, 26, 16))
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_right = -MARGIN
	_hint.offset_bottom = -MARGIN
	_hint.offset_left = -MARGIN
	_hint.offset_top = -MARGIN
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_hint)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_hint.add_child(v)
	v.add_child(Art.label("Controls", 17, Art.ROSE, "caps_wide"))
	var g = GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 7)
	v.add_child(g)
	for k in KEYS:
		var cap = Art.keycap(k[0], 17)
		cap.size_flags_horizontal = Control.SIZE_SHRINK_END
		g.add_child(cap)
		var l = Art.label(k[1], 21, Art.TEXT)
		l.custom_minimum_size = Vector2(92, 0)
		g.add_child(l)
	_hint.modulate.a = 0.0


func _build_notices() -> void:
	_notices = VBoxContainer.new()
	_notices.anchor_top = 1.0
	_notices.anchor_bottom = 1.0
	_notices.offset_left = MARGIN + 6
	_notices.offset_right = 480
	_notices.offset_top = -440
	_notices.offset_bottom = -MARGIN - 4
	_notices.alignment = BoxContainer.ALIGNMENT_END
	_notices.add_theme_constant_override("separation", 8)
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notices)


# ---------------------------------------------------------------- refresh
func refresh() -> void:
	_hp.set_values(GameState.hp, GameState.max_hp)
	_hp_l.text = "%d / %d" % [GameState.hp, GameState.max_hp]
	var t = DB.tier(GameState.tier)
	_tier_l.text = String(t.get("name", ""))
	_coin_l.text = str(GameState.coins)
	var ch = DB.chapter(GameState.chapter)
	_chapter_l.text = "Chapter %d · %s" % [GameState.chapter, ch.get("title", "")]
	_objective_l.text = GameState.objective
	_objective_l.visible = GameState.objective != ""
	_objective_rule.visible = _objective_l.visible
	_refresh_slots()


func _refresh_slots() -> void:
	for s in _slots:
		s.selected = s.index == GameState.hotbar_index
		s.refresh()


func _on_hotbar_changed(_i: int) -> void:
	_refresh_slots()
	var id = GameState.selected_item_id()
	_item_name.text = DB.item_name(id) if id != "" else ""
	_item_name_t = 1.6


func _on_slot_pressed(slot: ItemSlot, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT and not (Dialogue.active or UI.modal_open):
		GameState.select_hotbar(slot.index)


static func clock_text(h: float) -> String:
	var hh = int(floor(h)) % 24
	var mm = int(floor((h - floor(h)) * 60.0 / 10.0)) * 10
	var ampm = "AM" if hh < 12 else "PM"
	var h12 = hh % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, ampm]


func _process(delta: float) -> void:
	_t += delta
	_clock_l.text = clock_text(GameState.hour)
	var day = GameState.hour >= 6.0 and GameState.hour < 18.5
	var sky = Art.tex_ui("sun" if day else "moon")
	if _sky_icon.texture != sky:
		_sky_icon.texture = sky
	# the HUD steps back while a window (satchel, shop, popup) is open, and
	# the bottom row makes way for the dialogue box
	modulate.a = move_toward(modulate.a, 0.0 if UI.modal_open else 1.0, delta * 8.0)
	var talk = Dialogue.active
	for c in _bottom:
		c.modulate.a = move_toward(c.modulate.a, 0.0 if talk else 1.0, delta * 6.0)
	# Feyre's portrait slides in on the left while she speaks: her card makes way
	var her = talk and Dialogue.left_portrait.modulate.a > 0.05
	_left_card.modulate.a = move_toward(_left_card.modulate.a, 0.0 if her else 1.0, delta * 6.0)
	_hotbar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if talk else Control.MOUSE_FILTER_STOP
	if _item_name_t > 0.0:
		_item_name_t -= delta
		_item_pill.modulate.a = clampf(_item_name_t / 0.4, 0.0, 1.0) if _item_name.text != "" else 0.0
	else:
		_item_pill.modulate.a = 0.0
	var hint_a = 0.0
	if _hint_t > 0.0 and Settings.get_v("show_hints"):
		# the minute counts only while she is out in the world
		if is_visible_in_tree() and not talk and not UI.modal_open:
			_hint_t -= delta
		hint_a = clampf(_hint_t / 3.0, 0.0, 1.0) * clampf((60.0 - _hint_t) / 0.8, 0.0, 1.0)
	_hint.modulate.a = hint_a * _hotbar_panel.modulate.a
	_hint.visible = _hint.modulate.a > 0.01
	# damage flash on top of a slow pulse when health is low
	_hurt = max(0.0, _hurt - delta * 1.8)
	var low = 0.0
	var frac = float(GameState.hp) / float(max(1, GameState.max_hp))
	if visible and frac < 0.3 and GameState.hp > 0:
		low = (0.3 - frac) / 0.3 * (0.35 + 0.2 * sin(_t * 4.0))
	_vig_mat.set_shader_parameter("amount", clampf(max(_hurt, low), 0.0, 1.0))
	_vig_mat.set_shader_parameter("aspect", size.x / max(1.0, size.y))
	for id in _notice_rows.keys():
		var e: Array = _notice_rows[id]
		e[3] -= delta
		var row: Control = e[0]
		if e[3] < 0.5:
			row.modulate.a = max(0.0, e[3] / 0.5)
		if e[3] <= 0.0:
			row.queue_free()
			_notice_rows.erase(id)
	if _boss.visible:
		_boss_bar.pulse = 0.5 + 0.5 * sin(_t * 5.0) if _boss_status.text.begins_with("Heal") else 0.0
	_reticle.queue_redraw()


# ---------------------------------------------------------------- prompt
func set_prompt(text: String, key := "E") -> void:
	if text == "":
		_prompt_box.visible = false
		return
	_prompt_key.text = key
	_prompt_l.text = text
	_prompt_box.visible = true


# ---------------------------------------------------------------- notices
func notice_item(id: String, n: int) -> void:
	if not visible:
		return
	if _notice_rows.has(id):
		var e: Array = _notice_rows[id]
		e[2] = int(e[2]) + n
		e[3] = 3.0
		(e[0] as Control).modulate.a = 1.0
		(e[1] as Label).text = _notice_text(id, int(e[2]))
		return
	var row = _pill(Vector4(8, 3, 22, 5))
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var icon = TextureRect.new()
	icon.texture = Art.tex(String(DB.item(id).get("icon", "")))
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)
	var l = Art.label(_notice_text(id, n), 23, Art.TEXT, "bold")
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	_notices.add_child(row)
	_notice_rows[id] = [row, l, n, 3.0]


func _notice_text(id: String, n: int) -> String:
	var total = GameState.count(id)
	var nm = DB.item_name(id)
	return "+%d  %s   (%d)" % [n, nm, total] if total > n else "+%d  %s" % [n, nm]


# -------------------------------------------------------------- the hunt
func boss_show(boss_name: String, max_hp: int) -> void:
	_boss.visible = true
	_boss_name.text = boss_name
	_boss_bar.set_values(max_hp, max_hp, true)
	_boss_status.text = ""
	_boss.modulate.a = 0.0
	create_tween().tween_property(_boss, "modulate:a", 1.0, 0.6)


func boss_update(hp: int, max_hp: int, ash_struck: bool, regenerating: bool) -> void:
	if not _boss.visible:
		return
	if hp != int(_boss_bar.value) or max_hp != int(_boss_bar.max_value):
		_boss_bar.set_values(hp, max_hp)
	if ash_struck:
		_boss_status.text = "Ash-struck: his wounds stay open"
		_boss_status.add_theme_color_override("font_color", Art.ROSE)
	elif regenerating:
		_boss_status.text = "Healing"
		_boss_status.add_theme_color_override("font_color", Art.HONEY_DEEP)
	else:
		_boss_status.text = ""


func boss_hide() -> void:
	if not _boss.visible:
		return
	var tw = create_tween()
	tw.tween_property(_boss, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): _boss.visible = false)


## The three states' words: hidden, in the open, found. The wolf hunt's by
## default; the spring's trials (the Bogge, the Attor) bring their own.
const STEALTH_WORDS := ["Hidden", "In the open", "He knows you're here"]
var _stealth_words: Array = STEALTH_WORDS


func stealth_show(v: bool, words: Array = []) -> void:
	_stealth.visible = v
	_stealth_words = words if words.size() == 3 else STEALTH_WORDS


func stealth_update(hidden: bool, noise_frac: float, alerted: bool) -> void:
	var st = 2 if alerted else (0 if hidden else 1)
	if st != _eye_state:
		_eye_state = st
		_eye.queue_redraw()
	_stealth_l.text = String(_stealth_words[st])
	_stealth_l.add_theme_color_override("font_color", [Color("4b6b55"), Art.TEXT, Art.ROSE][st])
	_noise.visible = not alerted
	_noise.set_values(noise_frac, 1.0)


func _draw_eye() -> void:
	var c = _eye.size / 2.0
	var col = [Color("5d7a64"), Art.TEXT, Art.ROSE][_eye_state]
	if _eye_state == 0:
		# closed: a lid line with lashes
		var pts = PackedVector2Array()
		for i in 13:
			var x = -22.0 + i * (44.0 / 12.0)
			pts.append(c + Vector2(x, 4.0 - 0.012 * (484.0 - x * x)))
		_eye.draw_polyline(pts, col, 3.0, true)
		for i in 4:
			var x2 = -13.0 + i * 8.7
			_eye.draw_line(c + Vector2(x2, 1.5), c + Vector2(x2 * 1.15, 8), col, 2.0, true)
		return
	var top = PackedVector2Array()
	var bot = PackedVector2Array()
	for i in 13:
		var x3 = -24.0 + i * 4.0
		var y = 0.02 * (576.0 - x3 * x3)
		top.append(c + Vector2(x3, -y * 0.9))
		bot.append(c + Vector2(x3, y * 0.9))
	_eye.draw_polyline(top, col, 3.0, true)
	_eye.draw_polyline(bot, col, 3.0, true)
	_eye.draw_circle(c, 7.5, col)
	_eye.draw_circle(c, 3.0, Art.PAPER)


# --------------------------------------------------------------- effects
func hurt_flash() -> void:
	_hurt = 0.75


func _draw_reticle() -> void:
	var r = Router.current_region
	if r == null or r.player == null or not visible:
		return
	var p = r.player
	if not p.drawing:
		return
	var f: float = p.draw_fraction()
	var m = _reticle.get_local_mouse_position()
	var rad = lerpf(34.0, 10.0, f)
	var col = Art.GOLD if f >= 1.0 else Color(1, 1, 1, 0.8)
	_reticle.draw_arc(m, rad, 0, TAU, 40, Color(0, 0, 0, 0.45), 4.0, true)
	_reticle.draw_arc(m, rad, -PI / 2.0, -PI / 2.0 + TAU * f, 40, col, 2.5, true)
	_reticle.draw_circle(m, 2.0, col)
