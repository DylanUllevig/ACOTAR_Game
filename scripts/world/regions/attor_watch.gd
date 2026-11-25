extends Node
## Chapter 19: the thing in the rose garden. Tamlin has told her to stay
## hidden. She has a few seconds to get behind one of the hedges on the
## garden's north side before it comes; then it talks with Tamlin and Lucien
## by the fountain and noses about the garden. It cannot be seen, only a
## shimmer where the light bends round it. Moving while it is near makes the
## gravel and the leaves talk; stepping out from behind the hedge while it is
## in the garden is the end of her.
##
## start(region, pos, cover, watchers): pos is where it lands, cover the
## Rect2s behind the hedges, watchers the two males facing it.

signal finished(ok: bool)

const GRACE := 7.0           # seconds to get behind a hedge
const STAY := 32.0           # seconds it spends in the garden
const NEAR := 640.0          # within this, her moving is heard
const OPEN_GRACE := 0.45     # seconds in the open (after it comes) before it sees her
const WORDS := ["Hidden", "In the open", "It heard you"]

var region: Node
var player: Node2D
var cover: Array = []
var watchers: Array = []
var land := Vector2.ZERO
var t := 0.0
var noise := 0.0
var over := false
var arrived := false
var _open_t := 0.0
var _body: Node2D
var _spr: Sprite2D
var _anim_t := 0.0
var _route: Array = []
var _route_i := 0
var _barks: Array = []        # [time, speaker, expression, text]


func start(r: Node, pos: Vector2, cover_rects: Array, who: Array) -> void:
	region = r
	player = r.player
	land = pos
	cover = cover_rects
	watchers = who.filter(func(w): return w != null and is_instance_valid(w))
	UI.stealth_show(true, WORDS)
	GameState.set_objective("Get behind a hedge on the garden's north side, and keep still.")
	Audio.music_stop(2.0)
	Audio.ambience("spring_night")
	Dialogue.bark("tamlin", "angry", "Stay hidden. Not a sound.")
	# where it noses about: the fountain, then along the hedges, then back
	_route = [pos, pos + Vector2(-260, -160), pos + Vector2(-330, -560), pos + Vector2(0, -470), pos + Vector2(330, -560),
		pos + Vector2(240, -150), pos + Vector2(40, 30)]
	_barks = [
		[GRACE + 2.5, "attor", "neutral", "The High Lord is busy today. Busy, busy. She wonders why."],
		[GRACE + 8.0, "lucien", "angry", "Say what you came to say, and go."],
		[GRACE + 13.0, "attor", "neutral", "Something sweet on the wind. Something warm."],
		[GRACE + 18.5, "tamlin", "angry", "Tell her I am sick of the trash she dumps on my borders."],
		[GRACE + 24.0, "attor", "neutral", "Such a heart of stone, High Lord. And so much fear inside it."],
		[GRACE + 29.0, "lucien", "angry", "Burn in hell."],
	]


func in_cover(p: Vector2) -> bool:
	for c in cover:
		if (c as Rect2).has_point(p):
			return true
	return false


func _frozen() -> bool:
	return Dialogue.active or UI.modal_open or Router.busy


func _process(delta: float) -> void:
	if over or player == null:
		return
	if _frozen():
		return
	t += delta
	var hidden = in_cover(player.global_position)
	if not arrived:
		UI.stealth_update(hidden, 0.0, false)
		if t >= GRACE:
			_arrive()
			if not hidden:
				_caught("seen")
		return
	_move_body(delta)
	for w in watchers:
		if is_instance_valid(w):
			var d = _body.position - w.position
			var f = 2 if d.x > 0 else 1
			if absf(d.y) > absf(d.x):
				f = 0 if d.y > 0 else 3
			w.set_meta("facing", f)
	while not _barks.is_empty() and t >= float(_barks[0][0]):
		var b = _barks.pop_front()
		Dialogue.bark(String(b[1]), String(b[2]), String(b[3]))
	var dist = _body.global_position.distance_to(player.global_position)
	var moving = player.velocity.length() > 24.0
	if moving and dist < NEAR:
		var k = 1.0 - dist / NEAR
		noise += delta * (0.9 + 2.4 * k) * (2.2 if player.is_sprinting() else 1.0)
	else:
		noise = maxf(0.0, noise - delta * 0.28)
	if not hidden:
		_open_t += delta
	else:
		_open_t = 0.0
	UI.stealth_update(hidden, clampf(noise, 0.0, 1.0), false)
	if noise >= 1.0:
		_caught("heard")
		return
	if _open_t > OPEN_GRACE:
		_caught("seen")
		return
	if t >= GRACE + STAY:
		_leave()


## It drops out of the sky by the fountain: a gust, and a bend in the light.
func _arrive() -> void:
	arrived = true
	Audio.sfx("wings", -2.0)
	UI.shake(4.0)
	_body = Node2D.new()
	_body.position = land + Vector2(0, -40)
	_spr = Sprite2D.new()
	var rel = "actors/attor.png"
	_spr.texture = Art.lit(rel)
	if _spr.texture != null:
		var m = Art.pixel_meta(rel)
		var g: Array = m.get("grid", [1, 1])
		_spr.hframes = int(g[0])
		_spr.vframes = int(g[1])
		_spr.frame = int(m.get("anims", {}).get("crouch", [0])[0])
		_spr.scale = Art.sprite_scale(rel)
		_spr.offset = Vector2(0, -_spr.texture.get_height() / (2.0 * _spr.vframes))
	# all but invisible: a faint, cold shimmer where it stands
	_spr.modulate = Color(0.7, 0.8, 1.0, 0.0)
	_spr.light_mask = 0
	_body.add_child(_spr)
	region.world.add_child(_body)
	var tw = create_tween()
	tw.tween_property(_spr, "modulate:a", 0.16, 0.8)
	tw.parallel().tween_property(_body, "position", land, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var wobble = _spr.create_tween().set_loops()
	wobble.tween_property(_spr, "modulate:a", 0.1, 0.9).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(_spr, "modulate:a", 0.2, 0.9).set_trans(Tween.TRANS_SINE)
	# a cold breath of air where it walks
	region.add_light(Vector2(0, -30), Color(0.55, 0.65, 1.0), 0.25, 1.0, false, _body)


## Prowls its route at a crawl, pausing at each point to sniff.
func _move_body(delta: float) -> void:
	if _body == null:
		return
	var target: Vector2 = _route[_route_i]
	var d = target - _body.position
	var m = Art.pixel_meta("actors/attor.png").get("anims", {})
	if d.length() < 4.0:
		_anim_t += delta
		_spr.frame = int(m.get("crouch", [4])[0])
		if _anim_t > 2.2:
			_anim_t = 0.0
			_route_i = (_route_i + 1) % _route.size()
		return
	_body.position += d.normalized() * minf(d.length(), 70.0 * delta)
	_anim_t += delta * 6.0
	var crawl: Array = m.get("crawl", [0, 1, 2, 3])
	_spr.frame = int(crawl[int(_anim_t) % crawl.size()])
	_spr.flip_h = d.x < 0


func _caught(how: String) -> void:
	if over:
		return
	over = true
	UI.stealth_update(false, 1.0, true)
	if _spr != null:
		_spr.frame = int(Art.pixel_meta("actors/attor.png").get("anims", {}).get("snarl", [5])[0])
		create_tween().tween_property(_spr, "modulate:a", 0.55, 0.3)
	Audio.sfx("hiss", 0.0)
	Dialogue.bark("attor", "neutral", "There you are." if how == "heard" else "Ahh. What has the High Lord been hiding?")
	await get_tree().create_timer(1.2, true, false, true).timeout
	UI.stealth_show(false)
	finished.emit(false)


func _leave() -> void:
	if over:
		return
	over = true
	Audio.sfx("wings", -2.0)
	UI.shake(3.0)
	if _spr != null:
		var fly: Array = Art.pixel_meta("actors/attor.png").get("anims", {}).get("fly", [6, 7])
		_spr.frame = int(fly[0])
		var tw = create_tween()
		tw.tween_property(_body, "position", _body.position + Vector2(-200, -700), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_spr, "modulate:a", 0.0, 1.4)
		tw.tween_callback(_body.queue_free)
	UI.stealth_show(false)
	GameState.set_objective("")
	await get_tree().create_timer(1.6, true, false, true).timeout
	finished.emit(true)
