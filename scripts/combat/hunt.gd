extends Node
## Runs one hunt from the first stalk to the last breath: stealth and noise,
## the mid-fight story beats (a full dialogue freezes the fight, a bark plays
## over it), the boss bar, victory and defeat. Lives under the region for the
## length of the fight.

signal finished(won: bool)

var region: Node
var player: Node2D
var wolf: Node
var doe: Node
var cover: Array = []          # Array of Rect2: brambles to hide in
var noise := 0.0
var noise_max := 3.0
var sight := 520.0
var sprint_noise := 0.8
var over := false
var hidden := true
var _fired := {}
var _queue: Array = []         # trigger keys waiting for the screen to be free
var _busy := false
var _out_of_arrows_said := false


func start(r: Node, w: Node, d: Node, cover_rects: Array) -> void:
	region = r
	player = r.player
	wolf = w
	doe = d
	cover = cover_rects
	var st: Dictionary = wolf.def.get("stealth", {})
	noise_max = float(st.get("noise_to_alert", 3))
	sight = float(st.get("sight_radius", 520))
	sprint_noise = float(st.get("sprint_noise_per_sec", 0.8))
	wolf.hunt = self
	wolf.emerge()
	wolf.became_alerted.connect(func(_reason): _fire("alerted"))
	wolf.killed_doe.connect(func(): _fire("doe_killed"))
	wolf.ash_hit.connect(_on_ash_hit)
	wolf.regen_noticed.connect(func(): _fire("regen_noticed"))
	wolf.damaged.connect(_on_wolf_damaged)
	wolf.died.connect(_on_wolf_died)
	player.shot_fired.connect(_on_shot)
	player.died.connect(_on_player_died)
	UI.boss_show(wolf.def.get("name", "?"), wolf.max_hp)
	UI.stealth_show(true)
	Audio.music("hunt", 2.0)
	_fire("start")


func in_cover(p: Vector2) -> bool:
	for r in cover:
		if (r as Rect2).has_point(p):
			return true
	return false


func _frozen() -> bool:
	return Dialogue.active or UI.modal_open or Router.busy


func _process(delta: float) -> void:
	if over:
		return
	if not _frozen() and not _queue.is_empty() and not _busy:
		_run_trigger(_queue.pop_front())
	UI.boss_update(wolf.hp, wolf.max_hp, wolf.ash_struck, wolf.regenerating)
	if _frozen():
		return
	var in_c = in_cover(player.global_position)
	if not wolf.alerted:
		if player.is_sprinting():
			noise += sprint_noise * delta
		elif noise > 0.0:
			noise = max(0.0, noise - 0.06 * delta)
		var d = player.global_position.distance_to(wolf.global_position)
		if not in_c and d < sight:
			wolf.become_alerted("seen")
		elif d < 140.0:
			wolf.become_alerted("close")
		elif noise >= noise_max:
			wolf.become_alerted("noise")
	hidden = in_c and not wolf.alerted
	UI.stealth_update(hidden, clampf(noise / noise_max, 0.0, 1.0), wolf.alerted)
	# health beats
	if wolf.hp < wolf.max_hp * 0.5:
		_fire_value("enemy_hp_below", float(wolf.hp) / float(wolf.max_hp))
	if GameState.hp < GameState.max_hp * 0.35:
		_fire_value("player_hp_below", float(GameState.hp) / float(GameState.max_hp))
	if wolf.alerted and not _out_of_arrows_said and GameState.count("arrow") == 0 and GameState.count("ash_arrow") == 0:
		_out_of_arrows_said = true
		_fire("out_of_arrows")


func _on_ash_hit() -> void:
	# an ash arrow from hiding: its own beat covers him turning on her
	GameState.set_flag("ash_from_hiding", not wolf.alerted)
	if not wolf.alerted:
		_fired["alerted"] = true
	_fire("ash_struck")


func _on_shot(_ammo: String) -> void:
	if not wolf.alerted:
		noise += 1.0
		if noise >= noise_max:
			wolf.become_alerted("noise")


func _on_wolf_damaged(_amount: int, _hit: Dictionary) -> void:
	if not wolf.alerted:
		# an arrow in the side gives her away at once. Deferred, so an ash hit's
		# own beat (queued by the same arrow, just after this) plays first.
		noise = noise_max
		wolf.call_deferred("become_alerted", "hurt")


func _on_wolf_died(_w: Node) -> void:
	if over:
		return
	over = true
	GameState.bump("hunts_won")
	UI.stealth_show(false)
	Audio.music_stop(3.0)
	await get_tree().create_timer(1.6, true, false, true).timeout
	UI.boss_hide()
	var tr = _trigger_for("victory")
	if not tr.is_empty() and tr.has("scene"):
		await Dialogue.play(tr.scene)
	finished.emit(true)


func _on_player_died() -> void:
	if over:
		return
	over = true
	UI.stealth_show(false)
	UI.boss_hide()
	Audio.music_stop(1.5)
	finished.emit(false)


# --------------------------------------------------------------- triggers
func _trigger_for(when: String) -> Dictionary:
	for tr in wolf.def.get("triggers", []):
		if String(tr.when) == when:
			return tr
	return {}


func _fire(when: String) -> void:
	if _fired.has(when) or over:
		return
	var tr = _trigger_for(when)
	if tr.is_empty():
		return
	_fired[when] = true
	_queue.append(tr)


func _fire_value(when: String, frac: float) -> void:
	if _fired.has(when):
		return
	var tr = _trigger_for(when)
	if tr.is_empty() or frac >= float(tr.get("value", 0.0)):
		return
	_fire(when)


func _run_trigger(tr: Dictionary) -> void:
	_busy = true
	if tr.has("bark"):
		var b: Dictionary = tr.bark
		Dialogue.bark(String(b.get("s", "feyre")), String(b.get("e", "neutral")), String(b.get("t", "")))
	elif tr.has("scene") and String(tr.when) != "victory":
		await Dialogue.play(String(tr.scene))
	_busy = false
