extends Node
## Chapter 10: the Bogge. Lucien has told her not to look, whatever she
## hears. Something cold circles them in the brush; every so often it leans
## close on one side and its voice drags at her eyes. Push the other way
## (left if it pulls right, right if it pulls left) before her gaze slides
## round to it. Each pull she fails to fight, or turns into, fills the dread;
## full dread means she looked, and once she has seen it, it is real.
## After enough pulls it loses interest and slides off into the trees.

signal finished(ok: bool)

const PULLS := 8
const GAP := 2.4             # seconds between pulls
const WINDOW := 1.2          # seconds to push back against a pull
const WORDS := ["Eyes ahead", "It's pulling at you", "You looked"]
const WHISPERS := ["Look at me.", "I will grind your bones to dust. Look at me.", "I am what you fear. Look.",
	"Turn your head, little thing.", "I am so close now. Look at me.", "I will drink your marrow. Look.",
	"Just once. Look at me.", "You want to see. Look at me."]

var region: Node
var player: Node2D
var dread := 0.0
var pulls := 0
var side := 0                # -1: it pulls to the left, 1: to the right, 0: no pull
var t := 0.0
var over := false
var _shimmer: Sprite2D
var _cold: PointLight2D


func start(r: Node) -> void:
	region = r
	player = r.player
	player.locked = true
	player.facing = 3
	UI.stealth_show(true, WORDS)
	GameState.set_objective("Don't look at it. When it pulls your eyes to one side, push the other way.")
	Audio.music_stop(2.5)
	Audio.ambience("bogge", 2.0)
	_shimmer = Sprite2D.new()
	_shimmer.texture = Art.soft_light_texture()
	_shimmer.modulate = Color(0.04, 0.06, 0.1, 0.0)
	_shimmer.scale = Vector2(2.6, 1.5)
	_shimmer.z_index = 40
	region.world.add_child(_shimmer)
	_cold = region.add_light(Vector2.ZERO, Color(0.5, 0.62, 1.0), 0.0, 2.2, false, _shimmer)
	Dialogue.bark("bogge", "neutral", "Look at me.")
	t = -1.5


func _frozen() -> bool:
	return Dialogue.active or UI.modal_open or Router.busy


func _process(delta: float) -> void:
	if over or player == null:
		return
	if _frozen():
		return
	t += delta
	if side == 0:
		# the cold drifts behind them between pulls
		_shimmer.global_position = _shimmer.global_position.lerp(player.global_position + Vector2(0, 140), delta * 1.5)
		_shimmer.modulate.a = move_toward(_shimmer.modulate.a, 0.16, delta * 0.3)
		if t >= GAP:
			_pull()
	else:
		var want = player.global_position + Vector2(side * 230.0, -30.0)
		_shimmer.global_position = _shimmer.global_position.lerp(want, delta * 3.0)
		_shimmer.modulate.a = move_toward(_shimmer.modulate.a, 0.55, delta * 0.8)
		var push_away = Input.is_action_pressed("move_right") if side < 0 else Input.is_action_pressed("move_left")
		var turn_to = Input.is_action_pressed("move_left") if side < 0 else Input.is_action_pressed("move_right")
		if turn_to:
			_end_pull(0.5)
		elif push_away:
			_end_pull(-0.06)
		elif t >= WINDOW:
			_end_pull(0.36)
	UI.stealth_update(side == 0, clampf(dread, 0.0, 1.0), false)
	if dread >= 1.0:
		_looked()
	elif pulls >= PULLS and side == 0 and t >= 1.0:
		_gone()


## It leans in on one side and calls: her eyes start to slide that way.
func _pull() -> void:
	side = -1 if randf() < 0.5 else 1
	t = 0.0
	player.facing = 1 if side < 0 else 2
	_cold.energy = 0.5
	Audio.sfx("bogge_whisper", -4.0)
	Dialogue.bark("bogge", "neutral", WHISPERS[pulls % WHISPERS.size()])
	if player.camera != null:
		create_tween().tween_property(player.camera, "offset", Vector2(side * 70.0, 0), 0.6).set_trans(Tween.TRANS_SINE)


## The pull ends: fought off (dread falls a little), let go or turned into
## (dread rises).
func _end_pull(d: float) -> void:
	dread = maxf(0.0, dread + d)
	pulls += 1
	side = 0
	t = 0.0
	player.facing = 3
	_cold.energy = 0.15
	if player.camera != null:
		create_tween().tween_property(player.camera, "offset", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE)
	if d > 0.0:
		UI.shake(3.0)


func _looked() -> void:
	if over:
		return
	over = true
	UI.stealth_update(false, 1.0, true)
	Audio.sfx("bogge_whisper", 2.0)
	var tw = create_tween()
	tw.tween_property(_shimmer, "modulate", Color(0.0, 0.0, 0.02, 0.95), 0.6)
	tw.parallel().tween_property(_shimmer, "scale", Vector2(5.0, 3.2), 0.6)
	await tw.finished
	_cleanup()
	finished.emit(false)


func _gone() -> void:
	if over:
		return
	over = true
	var tw = create_tween()
	tw.tween_property(_shimmer, "global_position", _shimmer.global_position + Vector2(-600, -300), 2.0)
	tw.parallel().tween_property(_shimmer, "modulate:a", 0.0, 2.0)
	await tw.finished
	_cleanup()
	finished.emit(true)


func _cleanup() -> void:
	UI.stealth_show(false)
	if player != null:
		player.locked = false
		if player.camera != null:
			player.camera.offset = Vector2.ZERO
	GameState.set_objective("")
	if is_instance_valid(_shimmer):
		_shimmer.queue_free()
