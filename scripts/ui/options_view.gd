class_name OptionsView
extends HBoxContainer
## Sound, display and comfort options, plus the controls card. Every change
## applies and saves at once.

const SPEEDS := [[0.5, "Slow"], [1.0, "Normal"], [2.0, "Fast"], [99.0, "Instant"]]


func _ready() -> void:
	add_theme_constant_override("separation", 60)
	var left = VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.custom_minimum_size = Vector2(700, 0)
	add_child(left)
	left.add_child(_head("Sound"))
	left.add_child(_slider("Master", "master_volume"))
	left.add_child(_slider("Music", "music_volume"))
	left.add_child(_slider("Effects", "sfx_volume"))
	left.add_child(_slider("Ambience", "ambience_volume"))
	left.add_child(_slider("Interface", "ui_volume"))
	left.add_child(_head("Display and comfort"))
	left.add_child(_toggle("Fullscreen", "fullscreen"))
	left.add_child(_toggle("Vertical sync", "vsync"))
	left.add_child(_slider("Screen shake", "screen_shake"))
	left.add_child(_toggle("Damage numbers", "damage_numbers"))
	left.add_child(_toggle("Control hints", "show_hints"))
	left.add_child(_speed_row())
	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	right.add_child(_head("Controls"))
	for row in [
		["WASD or arrows", "Move"], ["Shift", "Hurry (louder)"], ["Left click or F", "Use the selected item"],
		["Hold, then release", "Draw and loose the bow"], ["Right click", "Cancel a draw, or interact"],
		["E or Space", "Interact, talk"], ["Wheel, 1 to 0", "Choose a hotbar slot"],
		["Tab or I", "Satchel"], ["M", "Map"], ["J", "Journal"], ["Esc", "Menu, back"],
		["Enter or click", "Next line of dialogue"],
	]:
		var h = HBoxContainer.new()
		var k = Art.label(row[0], 22, Art.GOLD, "caps")
		k.custom_minimum_size = Vector2(280, 0)
		h.add_child(k)
		h.add_child(Art.label(row[1], 24))
		right.add_child(h)


func _head(t: String) -> Label:
	return Art.label(t, 26, Art.GOLD, "caps")


func _slider(label: String, key: String) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var l = Art.label(label, 24)
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	var s = HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(340, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value = float(Settings.get_v(key))
	_style_slider(s)
	h.add_child(s)
	var pct = Art.label("%d%%" % int(round(s.value * 100)), 22, Art.PARCHMENT, "caps")
	pct.custom_minimum_size = Vector2(80, 0)
	h.add_child(pct)
	s.value_changed.connect(func(v):
		pct.text = "%d%%" % int(round(v * 100))
		Settings.set_v(key, float(v))
		if key != "music_volume" and key != "ambience_volume":
			Audio.ui("tick", -6.0))
	return h


func _style_slider(s: HSlider) -> void:
	var track = StyleBoxFlat.new()
	track.bg_color = Color(0.16, 0.12, 0.12)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill = StyleBoxFlat.new()
	fill.bg_color = Art.GOLD_DIM
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)


func _toggle(label: String, key: String) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var l = Art.label(label, 24)
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	var b = Art.button("On" if Settings.get_v(key) else "Off", 22)
	b.toggle_mode = true
	b.button_pressed = bool(Settings.get_v(key))
	b.custom_minimum_size = Vector2(120, 0)
	b.toggled.connect(func(on):
		b.text = "On" if on else "Off"
		Settings.set_v(key, on)
		Audio.ui("tick", -6.0))
	h.add_child(b)
	return h


func _speed_row() -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l = Art.label("Text speed", 24)
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	var group = ButtonGroup.new()
	var cur = float(Settings.get_v("text_speed"))
	for e in SPEEDS:
		var b = Art.button(e[1], 20)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = is_equal_approx(cur, e[0])
		var v: float = e[0]
		b.pressed.connect(func():
			Settings.set_v("text_speed", v)
			Audio.ui("tick", -6.0))
		h.add_child(b)
	return h
