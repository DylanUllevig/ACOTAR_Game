class_name JournalView
extends VBoxContainer
## Feyre's journal: what she has learned (lore), how strong she is on the
## book's power curve, and a tally of the hunt.

var _pages: Array[Control] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var head = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 16)
	add_child(head)
	var names = ["Entries", "Power", "Record"]
	for i in names.size():
		var b = Art.button(names[i], 24)
		b.toggle_mode = true
		var idx = i
		b.pressed.connect(func(): _show(idx))
		head.add_child(b)
		_buttons.append(b)
	_pages = [_lore_page(), _power_page(), _record_page()]
	for p in _pages:
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(p)
	_show(0)


func _show(i: int) -> void:
	for k in _pages.size():
		_pages[k].visible = k == i
		_buttons[k].button_pressed = k == i
	Audio.ui("page", -8.0)


func _lore_page() -> Control:
	var h = HSplitContainer.new()
	var list = ItemList.new()
	list.custom_minimum_size = Vector2(460, 600)
	list.add_theme_font_override("font", Art.font("serif"))
	list.add_theme_font_size_override("font_size", 26)
	list.add_theme_color_override("font_color", Art.PARCHMENT)
	list.add_theme_color_override("font_disabled_color", Color(0.45, 0.43, 0.42))
	list.add_theme_stylebox_override("panel", Art.panel_style(Color(0.08, 0.065, 0.07, 0.9), Art.GOLD_DIM, 8, 1))
	h.add_child(list)
	var detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_override("normal_font", Art.font("serif"))
	detail.add_theme_font_override("italics_font", Art.font("italic"))
	detail.add_theme_font_override("bold_font", Art.font("caps"))
	detail.add_theme_font_size_override("normal_font_size", 30)
	detail.add_theme_font_size_override("italics_font_size", 30)
	detail.add_theme_font_size_override("bold_font_size", 34)
	detail.add_theme_color_override("default_color", Art.PARCHMENT)
	h.add_child(detail)
	var ids: Array = []
	for id in DB.lore:
		ids.append(id)
		var e: Dictionary = DB.lore[id]
		if id in GameState.journal:
			list.add_item("%s  ·  %s" % [e.category, e.title])
		else:
			list.add_item("Not yet written  (chapter %d)" % int(e.chapter))
			list.set_item_disabled(list.item_count - 1, true)
	list.item_selected.connect(func(i):
		var e: Dictionary = DB.lore[ids[i]]
		var q = ""
		if e.get("quote") != null and DB.quotes.has(e.quote):
			q = "\n\n[i]“%s”[/i]" % DB.quotes[e.quote].text
		detail.text = "[b]%s[/b]\n[i]Chapter %d  ·  %s[/i]\n\n%s%s" % [e.title, int(e.chapter), e.category, e.text, q])
	if GameState.journal.is_empty():
		detail.text = "[i]Nothing written yet.[/i]"
	else:
		var last = ids.find(GameState.journal[GameState.journal.size() - 1])
		if last >= 0:
			list.select(last)
			list.item_selected.emit(last)
	return h


func _power_page() -> Control:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var t = DB.tier(GameState.tier)
	v.add_child(Art.label("Power %d   ·   Health %d   ·   Damage ×%.2f   ·   Speed ×%.2f   ·   Draw ×%.2f" % [GameState.power_score(), GameState.max_hp, GameState.damage_mult, GameState.speed_mult, GameState.draw_mult], 26, Art.GOLD, "caps"))
	var canon = Art.label(String(t.get("canon", "")), 26, Art.PARCHMENT, "italic")
	canon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(canon)
	var best = 1
	for tt in DB.tiers:
		best = max(best, GameState.score_for(tt))
	for tt in DB.tiers:
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		var cur = int(tt.tier) == GameState.tier
		var reached = int(tt.tier) <= GameState.tier
		var nm = Art.label("%s %d  %s" % ["»" if cur else "  ", int(tt.tier), tt.name], 26, Art.GOLD if cur else (Art.PARCHMENT if reached else Color(0.5, 0.5, 0.52)), "caps")
		nm.custom_minimum_size = Vector2(560, 0)
		h.add_child(nm)
		var bar = Meter.new(520, 16)
		bar.fill_color = Art.GOLD if reached else Color(0.35, 0.33, 0.3)
		bar.set_values(GameState.score_for(tt), best, true)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		h.add_child(Art.label("Ch %d  ·  HP %d" % [int(tt.chapter), int(tt.max_hp)], 22, Color(0.75, 0.72, 0.65)))
		v.add_child(h)
	v.add_child(Art.label("Power follows the book. It falls Under the Mountain, and climbs far past mortal when she is Made.", 22, Art.GOLD_DIM, "italic"))
	return v


func _record_page() -> Control:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var s = GameState.stats
	var rows = [
		["Hunts won", s.get("hunts_won", 0)], ["Hares taken", s.get("hares_hunted", 0)],
		["Arrows loosed", s.get("arrows_shot", 0)], ["Arrows recovered", s.get("arrows_recovered", 0)],
		["Damage dealt", s.get("damage_dealt", 0)], ["Food eaten", s.get("food_eaten", 0)],
		["Rose hips picked", s.get("rose_hips_picked", 0)],
		["Time on the road", _time(GameState.playtime)],
	]
	for r in rows:
		var h = HBoxContainer.new()
		var a = Art.label(String(r[0]), 28)
		a.custom_minimum_size = Vector2(420, 0)
		h.add_child(a)
		h.add_child(Art.label(str(r[1]), 28, Art.GOLD, "caps"))
		v.add_child(h)
	return v


static func _time(sec: float) -> String:
	var m = int(sec / 60.0)
	return "%d h %02d m" % [m / 60, m % 60] if m >= 60 else "%d min" % m
