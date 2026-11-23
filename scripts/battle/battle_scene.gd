extends Node2D
## The battle screen: lit painted combatants over a dedicated arena, a fanned
## hand of cards, readable enemy intent and the gimmick panel. All rules live in
## BattleCore; this file only presents and animates its events.

const FEYRE_POS := Vector2(470, 760)
const ENEMY_FAR := Vector2(1450, 640)
const ENEMY_NEAR := Vector2(1180, 660)
const DOE_POS := Vector2(1640, 760)
const DRAW_POS := Vector2(110, 1000)
const DISCARD_POS := Vector2(1810, 1000)

var core: BattleCore
var enemy_id = ""
var finished = false
var busy = false

var ui: CanvasLayer
var hand_root: Control
var views = {}               # uid -> CardView
var feyre: Sprite2D
var enemy_sprite: Sprite2D
var doe: Sprite2D
var brambles: Node2D
var camera: Camera2D
var key_light: PointLight2D

var p_hp_bar: ProgressBar
var p_hp_label: Label
var p_block: Label
var p_status: HBoxContainer
var e_hp_bar: ProgressBar
var e_hp_label: Label
var e_block: Label
var e_status: HBoxContainer
var intent_panel: PanelContainer
var intent_label: Label
var energy_label: Label
var draw_label: Label
var discard_label: Label
var log_label: Label
var gimmick_label: RichTextLabel
var range_label: Label
var end_button: Button
var items_box: VBoxContainer
var turn_label: Label


func run(eid: String) -> Dictionary:
	enemy_id = eid
	core = BattleCore.new()
	core.setup(eid, GameState.deck, {"hp": GameState.hp, "max_hp": GameState.max_hp, "energy": GameState.energy,
		"hand_size": GameState.hand_size, "strength": GameState.strength}, GameState.relics)
	_build_arena()
	_build_ui()
	_refresh()
	await get_tree().create_timer(0.3).timeout
	await _process_events(core.start())
	_refresh()
	while not core.over:
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	var result = {"won": core.won, "doe_saved": core.doe_saved()}
	GameState.stats.cards_played += 0
	GameState.stats.damage_dealt += core.total_damage_dealt
	if core.won:
		GameState.hp = max(1, core.player.hp)
		GameState.stats.battles_won += 1
		await _victory()
	else:
		GameState.hp = GameState.max_hp
	GameState.changed.emit()
	return result


# ------------------------------------------------------------------ arena
func _build_arena() -> void:
	var cm = CanvasModulate.new()
	cm.color = Color(0.62, 0.62, 0.78)
	add_child(cm)
	var envn = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_hdr_threshold = 0.95
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	envn.environment = e
	add_child(envn)
	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	add_child(camera)
	camera.make_current()
	# sky gradient
	var sky = Polygon2D.new()
	sky.polygon = PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, 620), Vector2(0, 620)])
	sky.vertex_colors = PackedColorArray([Color(0.3, 0.34, 0.5), Color(0.55, 0.5, 0.6), Color(0.78, 0.72, 0.76), Color(0.7, 0.72, 0.84)])
	sky.z_index = -20
	add_child(sky)
	# far treeline silhouettes
	for i in 16:
		var t = Sprite2D.new()
		t.texture = Art.tex("props/pine_%d.png" % (i % 3))
		t.position = Vector2(-40 + i * 130, 560 + (i % 3) * 10)
		t.scale = Vector2(0.9, 0.9) * (0.8 + (i % 4) * 0.12)
		t.modulate = Color(0.32, 0.36, 0.5)
		t.z_index = -15
		add_child(t)
	var gnd = Sprite2D.new()
	gnd.texture = Art.lit("terrain/snow.png")
	gnd.centered = false
	gnd.region_enabled = true
	gnd.region_rect = Rect2(0, 0, 1920, 520)
	gnd.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	gnd.position = Vector2(0, 580)
	gnd.z_index = -12
	add_child(gnd)
	# combatants: painted art, lit by the key and rim lights (normal maps)
	feyre = Sprite2D.new()
	feyre.texture = _lit_tex(Art.portrait("feyre", "determined"), "portraits/feyre/determined.png")
	feyre.position = FEYRE_POS
	feyre.scale = Vector2(0.95, 0.95)
	add_child(feyre)
	var edef: Dictionary = DB.enemies[enemy_id]
	enemy_sprite = Sprite2D.new()
	enemy_sprite.texture = Art.lit("battle/%s.png" % enemy_id)
	enemy_sprite.position = ENEMY_FAR
	enemy_sprite.scale = Vector2(0.85, 0.85)
	add_child(enemy_sprite)
	if not core.gimmick.is_empty():
		doe = Sprite2D.new()
		doe.texture = Art.lit("actors/doe.png")
		doe.position = DOE_POS
		doe.scale = Vector2(1.6, 1.6)
		doe.flip_h = true
		add_child(doe)
		brambles = Node2D.new()
		for i in 4:
			var b = Sprite2D.new()
			b.texture = Art.lit("props/bramble.png")
			b.position = FEYRE_POS + Vector2(-260 + i * 170, 300 + (i % 2) * 20)
			b.scale = Vector2(1.9, 1.9)
			brambles.add_child(b)
		brambles.z_index = 5
		add_child(brambles)
	key_light = PointLight2D.new()
	key_light.texture = Art.soft_light_texture()
	key_light.position = Vector2(700, 200)
	key_light.texture_scale = 9.0
	key_light.energy = 0.9
	key_light.color = Color(1.0, 0.86, 0.7)
	key_light.height = 120
	add_child(key_light)
	var rim = PointLight2D.new()
	rim.texture = Art.soft_light_texture()
	rim.position = Vector2(1850, 420)
	rim.texture_scale = 7.0
	rim.energy = 0.7
	rim.color = Color(0.55, 0.7, 1.0)
	rim.height = 60
	add_child(rim)
	if edef.get("fae", false):
		# Fae menace: a faint golden glow behind the wolf's head
		var fae = PointLight2D.new()
		fae.texture = Art.soft_light_texture()
		fae.position = Vector2(200, -110)
		fae.texture_scale = 1.4
		fae.energy = 0.9
		fae.color = Color(1.0, 0.8, 0.35)
		enemy_sprite.add_child(fae)
	# weather
	var snow = CPUParticles2D.new()
	snow.amount = 220
	snow.lifetime = 8
	snow.preprocess = 8
	snow.texture = Art.tex("fx/snowflake.png")
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(1100, 20)
	snow.position = Vector2(960, -40)
	snow.direction = Vector2(0.2, 1)
	snow.gravity = Vector2(10, 18)
	snow.initial_velocity_min = 20
	snow.initial_velocity_max = 60
	snow.scale_amount_min = 0.3
	snow.scale_amount_max = 1.0
	snow.z_index = 10
	add_child(snow)
	var fog = ColorRect.new()
	fog.size = Vector2(2400, 500)
	fog.position = Vector2(-200, 520)
	var fm = ShaderMaterial.new()
	fm.shader = load("res://shaders/fog.gdshader")
	fm.set_shader_parameter("density", 0.28)
	fm.set_shader_parameter("world_scale", 0.003)
	fog.material = fm
	fog.z_index = 8
	add_child(fog)
	var fx = CanvasLayer.new()
	fx.layer = 5
	add_child(fx)
	var rays = ColorRect.new()
	rays.size = Vector2(1920, 1080)
	var rm = ShaderMaterial.new()
	rm.shader = load("res://shaders/god_rays.gdshader")
	rm.set_shader_parameter("intensity", 0.3)
	rm.set_shader_parameter("angle", -0.5)
	rays.material = rm
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(rays)
	var post_l = CanvasLayer.new()
	post_l.layer = 9
	add_child(post_l)
	var post = ColorRect.new()
	post.size = Vector2(1920, 1080)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm = ShaderMaterial.new()
	pm.shader = load("res://shaders/post.gdshader")
	pm.set_shader_parameter("vignette", 0.7)
	pm.set_shader_parameter("saturation", 0.9)
	post.material = pm
	post_l.add_child(post)
	# idle breathing
	var tw = create_tween().set_loops()
	tw.tween_property(enemy_sprite, "scale", Vector2(0.85, 0.87), 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(enemy_sprite, "scale", Vector2(0.85, 0.85), 1.4).set_trans(Tween.TRANS_SINE)
	var tw2 = create_tween().set_loops()
	tw2.tween_property(feyre, "position:y", FEYRE_POS.y - 5, 1.8).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(feyre, "position:y", FEYRE_POS.y, 1.8).set_trans(Tween.TRANS_SINE)


func _lit_tex(fallback: Texture2D, rel: String) -> Texture2D:
	var t = Art.lit(rel)
	return t if t else fallback


# --------------------------------------------------------------------- UI
func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size = Vector2(1920, 1080)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# player panel
	var pp = _panel(Vector2(30, 24), Vector2(560, 0))
	root.add_child(pp)
	var pv = VBoxContainer.new()
	pp.add_child(pv)
	var ph = HBoxContainer.new()
	ph.add_theme_constant_override("separation", 16)
	pv.add_child(ph)
	ph.add_child(Art.label("FEYRE", 30, Art.GOLD, "caps"))
	p_hp_label = Art.label("", 28)
	ph.add_child(p_hp_label)
	p_block = Art.label("", 28, Color(0.6, 0.8, 1.0), "caps")
	ph.add_child(p_block)
	p_hp_bar = UI._bar(Color(0.7, 0.14, 0.16), 500, 18)
	pv.add_child(p_hp_bar)
	p_status = HBoxContainer.new()
	p_status.add_theme_constant_override("separation", 8)
	pv.add_child(p_status)

	# enemy panel
	var ep = _panel(Vector2(1330, 24), Vector2(560, 0))
	root.add_child(ep)
	var ev = VBoxContainer.new()
	ep.add_child(ev)
	var eh = HBoxContainer.new()
	eh.add_theme_constant_override("separation", 16)
	ev.add_child(eh)
	eh.add_child(Art.label(core.enemy.name.to_upper(), 30, Color(1.0, 0.75, 0.6), "caps"))
	e_hp_label = Art.label("", 28)
	eh.add_child(e_hp_label)
	e_block = Art.label("", 28, Color(0.6, 0.8, 1.0), "caps")
	eh.add_child(e_block)
	e_hp_bar = UI._bar(Color(0.75, 0.3, 0.12), 500, 18)
	ev.add_child(e_hp_bar)
	e_status = HBoxContainer.new()
	e_status.add_theme_constant_override("separation", 8)
	ev.add_child(e_status)

	# intent above the enemy
	intent_panel = _panel(Vector2(1200, 200), Vector2(500, 0))
	intent_panel.add_theme_stylebox_override("panel", Art.panel_style(Color(0.25, 0.05, 0.06, 0.9), Color(1.0, 0.55, 0.4), 10, 2))
	root.add_child(intent_panel)
	intent_label = Art.label("", 30, Color(1, 0.92, 0.85), "caps")
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent_panel.add_child(intent_label)

	# gimmick + range, top centre
	var gp = _panel(Vector2(640, 24), Vector2(640, 0))
	root.add_child(gp)
	var gv = VBoxContainer.new()
	gp.add_child(gv)
	turn_label = Art.label("", 22, Art.GOLD_DIM, "caps")
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(turn_label)
	range_label = Art.label("", 26, Art.PARCHMENT, "caps")
	range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(range_label)
	gimmick_label = RichTextLabel.new()
	gimmick_label.bbcode_enabled = true
	gimmick_label.fit_content = true
	gimmick_label.scroll_active = false
	gimmick_label.custom_minimum_size = Vector2(600, 0)
	gimmick_label.add_theme_font_override("normal_font", Art.font("serif"))
	gimmick_label.add_theme_font_override("bold_font", Art.font("caps"))
	gimmick_label.add_theme_font_size_override("normal_font_size", 24)
	gimmick_label.add_theme_font_size_override("bold_font_size", 22)
	gimmick_label.mouse_filter = Control.MOUSE_FILTER_PASS
	gimmick_label.tooltip_text = DB.enemies[enemy_id].get("gimmick_text", "")
	gv.add_child(gimmick_label)

	# energy orb
	var orb = Panel.new()
	var os = StyleBoxFlat.new()
	os.bg_color = Color(0.35, 0.2, 0.05, 0.95)
	os.border_color = Art.GOLD
	os.set_border_width_all(4)
	os.set_corner_radius_all(60)
	os.shadow_color = Color(1.0, 0.7, 0.3, 0.5)
	os.shadow_size = 18
	orb.add_theme_stylebox_override("panel", os)
	orb.position = Vector2(50, 760)
	orb.size = Vector2(120, 120)
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(orb)
	energy_label = Art.label("", 44, Color(1, 0.92, 0.7), "caps")
	energy_label.size = Vector2(120, 120)
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	orb.add_child(energy_label)

	draw_label = Art.label("", 24, Art.PARCHMENT, "caps")
	draw_label.position = Vector2(40, 900)
	root.add_child(draw_label)
	discard_label = Art.label("", 24, Art.PARCHMENT, "caps")
	discard_label.position = Vector2(1650, 900)
	discard_label.size = Vector2(240, 80)
	discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(discard_label)

	end_button = Art.button("End Turn  (R)", 30)
	end_button.position = Vector2(1640, 790)
	end_button.size = Vector2(250, 70)
	end_button.pressed.connect(_on_end_turn)
	root.add_child(end_button)

	items_box = VBoxContainer.new()
	items_box.position = Vector2(30, 470)
	items_box.add_theme_constant_override("separation", 8)
	root.add_child(items_box)

	log_label = Art.label("", 28, Art.PARCHMENT, "italic")
	log_label.position = Vector2(360, 640)
	log_label.size = Vector2(1200, 50)
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(log_label)

	hand_root = Control.new()
	hand_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_root.size = Vector2(1920, 1080)
	hand_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hand_root)


func _panel(pos: Vector2, min_size: Vector2) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.panel_style(Color(0.06, 0.05, 0.08, 0.85), Art.GOLD_DIM, 10))
	p.position = pos
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _status_chip(name_id: String, stacks: int) -> Control:
	var info: Dictionary = DB.statuses.get(name_id, {"name": name_id, "good": true, "text": ""})
	var p = PanelContainer.new()
	var good: bool = info.get("good", true)
	p.add_theme_stylebox_override("panel", Art.panel_style(Color(0.1, 0.2, 0.14, 0.95) if good else Color(0.3, 0.08, 0.08, 0.95), Art.GOLD_DIM, 6, 1))
	var l = Art.label("%s %s" % [info.name, str(stacks) if not name_id in ["hidden", "ash_struck"] else ""], 20, Art.PARCHMENT, "caps")
	p.add_child(l)
	p.tooltip_text = info.get("text", "")
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


# --------------------------------------------------------------- refresh
func _refresh() -> void:
	var pl: Dictionary = core.player
	var en: Dictionary = core.enemy
	p_hp_label.text = "%d / %d" % [pl.hp, pl.max_hp]
	p_hp_bar.max_value = pl.max_hp
	create_tween().tween_property(p_hp_bar, "value", float(pl.hp), 0.25)
	p_block.text = ("Block %d" % pl.block) if pl.block > 0 else ""
	e_hp_label.text = "%d / %d" % [en.hp, en.max_hp]
	e_hp_bar.max_value = en.max_hp
	create_tween().tween_property(e_hp_bar, "value", float(en.hp), 0.25)
	e_block.text = ("Block %d" % en.block) if en.block > 0 else ""
	for c in p_status.get_children():
		c.queue_free()
	for s in pl.statuses:
		p_status.add_child(_status_chip(s, int(pl.statuses[s])))
	for c in e_status.get_children():
		c.queue_free()
	for s in en.statuses:
		e_status.add_child(_status_chip(s, int(en.statuses[s])))
	energy_label.text = "%d/%d" % [pl.energy, pl.max_energy]
	draw_label.text = "Draw  %d" % core.draw_pile.size()
	discard_label.text = "Discard  %d\nExhaust  %d" % [core.discard.size(), core.exhaust.size()]
	turn_label.text = "Turn %d" % core.turn
	range_label.text = ("Range:  [ FAR ]   near" if core.current_range == "far" else "Range:  far   [ NEAR ]")
	_refresh_intent()
	_refresh_gimmick()
	_refresh_items()
	_layout_hand()
	if brambles:
		brambles.modulate.a = 1.0 if pl.statuses.has("hidden") else 0.35
	feyre.modulate = Color(0.55, 0.6, 0.75) if pl.statuses.has("hidden") else Color(1, 1, 1)
	end_button.disabled = core.over or busy


func _refresh_intent() -> void:
	var s = core.intent_summary()
	var txt = ""
	match s.kind:
		"attack":
			txt = "%s   ATTACK %d%s" % [s.label, s.damage, (" × %d" % s.hits) if s.hits > 1 else ""]
		"defend":
			txt = "%s   BLOCK %d" % [s.label, s.block]
		"stalk":
			txt = "%s  (%d/%d)" % [s.label, core.gimmick.get("doe_threat", 0) + 1, core.gimmick.get("doe_threat_to_pounce", 2)]
		"special":
			txt = "%s !" % s.label
		_:
			txt = s.label
	intent_label.text = txt


func _refresh_gimmick() -> void:
	if core.gimmick.is_empty():
		gimmick_label.text = ""
		return
	var g: Dictionary = core.gimmick
	var pips = ""
	for i in g.noise_to_alert:
		pips += "|" if i < g.noise else "."
	var doe_txt = {"grazing": "grazing, unaware", "safe": "safe (meat and hide intact)", "ruined": "torn open by the wolf", "fled": "bolted into the trees"}[g.doe]
	var found = "[color=#ff8a6a]HE HAS FOUND YOU[/color]" if g.alerted else "[color=#9fd0ff]Hidden in the brambles[/color]"
	gimmick_label.text = "[center][b]THE HUNT[/b]   %s\nNoise %d / %d    Doe: %s[/center]" % [found, g.noise, g.noise_to_alert, doe_txt]


func _refresh_items() -> void:
	for c in items_box.get_children():
		c.queue_free()
	for id in GameState.items:
		var it: Dictionary = DB.items.get(id, {})
		if it.is_empty() or not it.get("battle", false):
			continue
		var b = Art.button("%s ×%d" % [it.name, GameState.items[id]], 20)
		b.tooltip_text = it.text
		var iid: String = id
		b.pressed.connect(func(): _use_item(iid))
		b.disabled = core.over or busy
		items_box.add_child(b)


func _layout_hand() -> void:
	var present = {}
	for c in core.hand:
		present[int(c.uid)] = true
	for uid in views.keys():
		if not present.has(uid):
			var v: CardView = views[uid]
			views.erase(uid)
			_discard_anim(v)
	var n = core.hand.size()
	var spacing: float = min(190.0, 1100.0 / max(1, n))
	for i in n:
		var c: Dictionary = core.hand[i]
		var uid = int(c.uid)
		var v: CardView
		if views.has(uid):
			v = views[uid]
		else:
			v = CardView.new()
			v.setup(c, core.describe_card(c))
			v.position = DRAW_POS - CardView.SIZE / 2
			v.scale = Vector2(0.3, 0.3)
			v.clicked.connect(_on_card_clicked)
			v.hovered.connect(_on_card_hover)
			hand_root.add_child(v)
			views[uid] = v
		v.update_text(core.describe_card(c))
		v.set_playable(core.can_play(i) == "" and not busy)
		var t = (i - (n - 1) / 2.0)
		var pos = Vector2(960 + t * spacing, 1060 - abs(t) * abs(t) * 6.0) - Vector2(CardView.SIZE.x / 2, CardView.SIZE.y * 0.72)
		v.base_position = pos
		v.base_rotation = deg_to_rad(t * 3.5)
		v.z_index = i
		if not v.hovering:
			var tw = v.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(v, "position", pos, 0.25)
			tw.tween_property(v, "rotation", v.base_rotation, 0.25)
			tw.tween_property(v, "scale", Vector2.ONE, 0.25)


func _on_card_hover(v: CardView, on: bool) -> void:
	if not is_instance_valid(v) or core.over:
		return
	var tw = v.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if on:
		v.z_index = 100
		tw.tween_property(v, "position", v.base_position + Vector2(0, -120), 0.12)
		tw.tween_property(v, "rotation", 0.0, 0.12)
		tw.tween_property(v, "scale", Vector2(1.15, 1.15), 0.12)
	else:
		v.z_index = core.hand.find_custom(func(c): return int(c.uid) == int(v.card.uid))
		tw.tween_property(v, "position", v.base_position, 0.15)
		tw.tween_property(v, "rotation", v.base_rotation, 0.15)
		tw.tween_property(v, "scale", Vector2.ONE, 0.15)


func _discard_anim(v: CardView) -> void:
	var tw = v.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(v, "position", DISCARD_POS - CardView.SIZE / 2, 0.3)
	tw.tween_property(v, "scale", Vector2(0.25, 0.25), 0.3)
	tw.tween_property(v, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(v.queue_free)


# ------------------------------------------------------------------ input
func _on_card_clicked(v: CardView) -> void:
	if busy or core.over:
		return
	var idx = -1
	for i in core.hand.size():
		if int(core.hand[i].uid) == int(v.card.uid):
			idx = i
	if idx < 0:
		return
	await _play_index(idx, v)


func _play_index(idx: int, v: CardView = null) -> void:
	var why = core.can_play(idx)
	if why != "":
		_log(why)
		if v:
			var tw = v.create_tween()
			for k in 4:
				tw.tween_property(v, "rotation", 0.06 * (1 if k % 2 == 0 else -1), 0.04)
			tw.tween_property(v, "rotation", v.base_rotation, 0.04)
		return
	busy = true
	var uid = int(core.hand[idx].uid)
	if v == null and views.has(uid):
		v = views[uid]
	if v:
		views.erase(uid)
		var tw = v.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		v.z_index = 200
		tw.tween_property(v, "position", Vector2(960, 380) - CardView.SIZE / 2, 0.18)
		tw.tween_property(v, "rotation", 0.0, 0.18)
		tw.tween_property(v, "scale", Vector2(1.25, 1.25), 0.18)
		await tw.finished
		var tw2 = v.create_tween().set_parallel(true)
		tw2.tween_property(v, "modulate:a", 0.0, 0.2)
		tw2.tween_property(v, "position:y", v.position.y - 60, 0.2)
		tw2.chain().tween_callback(v.queue_free)
	GameState.stats.cards_played += 1
	await _process_events(core.play_card(idx))
	busy = false
	_refresh()


func _on_end_turn() -> void:
	if busy or core.over:
		return
	busy = true
	_refresh()
	await _process_events(core.end_turn())
	busy = false
	_refresh()


func _use_item(id: String) -> void:
	if busy or core.over or int(GameState.items.get(id, 0)) <= 0:
		return
	busy = true
	GameState.add_item(id, -1)
	await _process_events(core.use_item(id))
	busy = false
	_refresh()


func _unhandled_input(ev: InputEvent) -> void:
	if Dialogue.active or UI.modal_open or busy or core == null or core.over:
		return
	if ev.is_action_pressed("end_turn"):
		_on_end_turn()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var n: int = ev.keycode - KEY_1
		if n >= 0 and n < core.hand.size():
			_play_index(n)


# ------------------------------------------------------------- feedback
func _process_events(evs: Array) -> void:
	for e in evs:
		match e.t:
			"damage":
				await _hit(e)
			"block":
				_float_text("+%d Block" % e.amount, _target_pos(e.target) + Vector2(0, -120), Color(0.6, 0.8, 1.0))
				_refresh()
			"heal":
				_float_text("+%d" % e.amount, _target_pos(e.target) + Vector2(0, -160), Color(0.5, 1.0, 0.6))
				_refresh()
			"evade":
				_float_text("EVADED", FEYRE_POS + Vector2(0, -200), Color(0.8, 0.95, 1.0), 48)
				var tw = create_tween()
				tw.tween_property(feyre, "position:x", FEYRE_POS.x - 60, 0.1)
				tw.tween_property(feyre, "position:x", FEYRE_POS.x, 0.2)
				await get_tree().create_timer(0.25).timeout
			"status":
				_refresh()
				if e.stacks > 0:
					var nm: String = DB.statuses.get(e.status, {}).get("name", e.status)
					_float_text(nm, _target_pos(e.target) + Vector2(0, -230), Color(1.0, 0.85, 0.5), 32)
			"enemy_move":
				_log(core.enemy.name + ": " + e.label)
				await _enemy_lunge(e.key)
			"intent":
				_refresh_intent()
			"range":
				var to = ENEMY_NEAR if e.range == "near" else ENEMY_FAR
				var tw2 = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw2.tween_property(enemy_sprite, "position", to, 0.35)
				_log("Range: " + String(e.range).to_upper())
				_refresh()
			"alerted":
				_float_text("HE HAS FOUND YOU", Vector2(960, 330), Color(1.0, 0.55, 0.4), 56)
				UI.shake(12)
				if brambles:
					create_tween().tween_property(brambles, "modulate:a", 0.35, 0.4)
				_refresh()
				await get_tree().create_timer(0.35).timeout
			"doe":
				_doe_anim(e.state)
			"noise":
				_refresh_gimmick()
			"doe_threat":
				_refresh_gimmick()
			"relic":
				UI.toast("Relic: " + DB.relics[e.id].name)
			"item":
				_log("Used " + e.name)
			"dialogue":
				_refresh()
				await Dialogue.play(e.scene)
			"draw", "reshuffle", "exhaust", "play", "turn", "energy":
				pass
			"log":
				_log(e.text)
			"victory":
				_float_text("VICTORY", Vector2(960, 420), Art.GOLD, 90)
				var tw3 = create_tween()
				tw3.tween_property(enemy_sprite, "modulate", Color(0.3, 0.3, 0.35, 0.0), 1.4)
			"defeat":
				_float_text("FALLEN", Vector2(960, 420), Color(0.8, 0.2, 0.2), 90)
				create_tween().tween_property(feyre, "modulate", Color(0.4, 0.2, 0.2, 0.5), 1.0)
	_refresh()


func _target_pos(t: String) -> Vector2:
	return FEYRE_POS if t == "player" else enemy_sprite.position


func _hit(e: Dictionary) -> void:
	var on_enemy: bool = e.target == "enemy"
	var spr: Sprite2D = enemy_sprite if on_enemy else feyre
	var pos = _target_pos(e.target)
	var amt: int = e.amount
	var txt = str(amt)
	if e.get("ambush", false):
		txt += "  AMBUSH"
	if e.get("blocked", 0) > 0:
		_float_text("-%d blocked" % e.blocked, pos + Vector2(-80, -60), Color(0.6, 0.8, 1.0), 28)
	var col = Color(1.0, 0.9, 0.6) if on_enemy else Color(1.0, 0.35, 0.3)
	_float_text(txt, pos + Vector2(randf_range(-30, 30), -140), col, 44 + min(40, amt * 2))
	if amt > 0:
		# flash, knockback, sparks, hit-stop, shake scaled to damage
		var orig = spr.modulate
		spr.modulate = Color(3.0, 2.6, 2.4) if on_enemy else Color(2.5, 0.6, 0.6)
		var kb = Vector2(40 if on_enemy else -40, 0) * clamp(amt / 8.0, 0.5, 2.0)
		var base = spr.position
		var tw = create_tween()
		tw.tween_property(spr, "position", base + kb, 0.05)
		tw.tween_property(spr, "position", base, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var tw2 = create_tween()
		tw2.tween_property(spr, "modulate", orig, 0.25)
		_sparks(pos + Vector2(0, -60), on_enemy, amt)
		UI.shake(clamp(amt * 0.9, 4.0, 22.0))
		Engine.time_scale = 0.15
		await get_tree().create_timer(0.07 * 0.15).timeout
		Engine.time_scale = 1.0
	_refresh()
	await get_tree().create_timer(0.18).timeout


func _sparks(pos: Vector2, on_enemy: bool, amt: int) -> void:
	var p = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = clamp(8 + amt * 2, 10, 60)
	p.lifetime = 0.6
	p.texture = Art.tex("fx/snowflake.png")
	p.direction = Vector2(1 if on_enemy else -1, -0.4)
	p.spread = 60
	p.initial_velocity_min = 180
	p.initial_velocity_max = 520
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.color = Color(1.6, 0.25, 0.25) if true else Color.WHITE
	p.z_index = 20
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _enemy_lunge(key: String) -> void:
	var base = enemy_sprite.position
	if key in ["stalk"]:
		var tw0 = create_tween()
		tw0.tween_property(enemy_sprite, "position", base + Vector2(30, 0), 0.4)
		tw0.tween_property(enemy_sprite, "position", base, 0.4)
		await tw0.finished
		return
	if key == "pounce_doe" and doe:
		var tw1 = create_tween()
		tw1.tween_property(enemy_sprite, "position", DOE_POS + Vector2(-120, -60), 0.2)
		tw1.tween_property(enemy_sprite, "position", base, 0.35)
		UI.shake(16)
		await tw1.finished
		return
	var tw = create_tween()
	tw.tween_property(enemy_sprite, "position", base + Vector2(-90, 10), 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(enemy_sprite, "position", base, 0.22).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(0.1).timeout


func _doe_anim(state: String) -> void:
	if doe == null:
		return
	match state:
		"ruined":
			var tw = create_tween().set_parallel(true)
			tw.tween_property(doe, "rotation_degrees", 90.0, 0.3)
			tw.tween_property(doe, "modulate", Color(0.6, 0.25, 0.25), 0.3)
		"fled":
			var tw2 = create_tween()
			tw2.tween_property(doe, "position", doe.position + Vector2(500, -40), 0.8)
		"safe":
			var tw3 = create_tween()
			tw3.tween_property(doe, "modulate", Color(1.2, 1.15, 1.0), 0.3)
	_refresh_gimmick()


func _float_text(text: String, pos: Vector2, col: Color, size := 44) -> void:
	var l = Art.label(text, size, col, "caps")
	l.position = pos - Vector2(300, 0)
	l.size = Vector2(600, 80)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(300, 40)
	l.scale = Vector2(0.6, 0.6)
	ui.add_child(l)
	var tw = l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", pos.y - 90, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func _log(t: String) -> void:
	log_label.text = t
	log_label.modulate.a = 1.0
	var tw = log_label.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(log_label, "modulate:a", 0.35, 0.8)


# ---------------------------------------------------------------- reward
func _victory() -> void:
	var rw: Dictionary = DB.enemies[enemy_id].get("rewards", {})
	var saved = core.doe_saved()
	GameState.set_flag("doe_saved", saved)
	var items: Dictionary = rw.get("items_if_doe_saved", {}) if saved else rw.get("items_if_doe_lost", {})
	for id in items:
		GameState.add_item(id, int(items[id]))
	if rw.has("lore"):
		GameState.unlock_lore(rw.lore)
	if core.enemy.fae:
		GameState.unlock_lore("lore_ash")
	await UI.card_reward(rw.get("card_pool", ["hunter_common"]))
