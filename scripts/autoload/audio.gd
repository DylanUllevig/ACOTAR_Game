extends Node
## Sound: one-shot effects (flat or positioned in the world), a looping music
## track with crossfades, and a looping ambience bed. Sounds are looked up by
## name under res://assets/audio/<kind>/ and res://assets/final/audio/<kind>/
## (final wins). A name can have variants: step_snow_0.ogg, step_snow_1.ogg ...
## one is picked at random each time. A missing sound is simply silent, so the
## game runs before every file exists.

const ROOTS := ["res://assets/final/audio/", "res://assets/audio/"]
const EXTS := ["ogg", "wav", "mp3"]
const POOL := 18
const POOL_2D := 14
const MAX_VARIANTS := 8

var _streams := {}               # "kind/name" -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _players_2d: Array[AudioStreamPlayer2D] = []
var _next := 0
var _next_2d := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_name := ""
var _last_play := {}             # name -> process frame, to stop the same sound stacking
var _tweens := {}                # player instance id -> the fade running on it
var _quitting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX", "Ambience", "UI"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL:
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in POOL_2D:
		var p2 = AudioStreamPlayer2D.new()
		p2.bus = "SFX"
		p2.max_distance = 1800.0
		p2.attenuation = 1.6
		p2.panning_strength = 0.8
		add_child(p2)
		_players_2d.append(p2)
	_music_a = _loop_player("Music")
	_music_b = _loop_player("Music")
	_amb_a = _loop_player("Ambience")
	_amb_b = _loop_player("Ambience")
	# the window's close button goes through quit_game too, so sounds stop first
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func _loop_player(bus: String) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


# --------------------------------------------------------------- lookups
func _find(kind: String, name: String) -> Array:
	var key = kind + "/" + name
	if _streams.has(key):
		return _streams[key]
	var found: Array = []
	for root in ROOTS:
		for ext in EXTS:
			var p = "%s%s/%s.%s" % [root, kind, name, ext]
			if ResourceLoader.exists(p):
				found.append(load(p))
				break
		if found.is_empty():
			for v in MAX_VARIANTS:
				var hit = false
				for ext in EXTS:
					var pv = "%s%s/%s_%d.%s" % [root, kind, name, v, ext]
					if ResourceLoader.exists(pv):
						found.append(load(pv))
						hit = true
						break
				if not hit:
					break
		if not found.is_empty():
			break
	_streams[key] = found
	return found


func has_sound(kind: String, name: String) -> bool:
	return not _find(kind, name).is_empty()


func _pick(kind: String, name: String) -> AudioStream:
	var list = _find(kind, name)
	if list.is_empty():
		return null
	return list[randi() % list.size()]


## The same sound twice within two frames (about 30 ms at 60 fps) plays once.
## Counted in frames, not wall-clock time, so a run at a fixed frame rate (the
## automated tests) makes the same calls, and draws the same random numbers,
## every time.
func _too_soon(name: String) -> bool:
	var now = Engine.get_process_frames()
	if now - int(_last_play.get(name, -1000)) < 2:
		return true
	_last_play[name] = now
	return false


# --------------------------------------------------------------- effects
func sfx(name: String, vol_db := 0.0, pitch_var := 0.0) -> void:
	var s = _pick("sfx", name)
	if s == null or _too_soon(name):
		return
	var p = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## Positioned in the world: pans with the camera and fades with distance.
func sfx_at(name: String, pos: Vector2, vol_db := 0.0, pitch_var := 0.06) -> void:
	var s = _pick("sfx", name)
	if s == null or _too_soon(name):
		return
	var p = _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _players_2d.size()
	p.stream = s
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func ui(name: String, vol_db := 0.0) -> void:
	var s = _pick("ui", name)
	if s == null:
		s = _pick("sfx", name)
	if s == null or _too_soon("ui:" + name):
		return
	var p = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.bus = "UI"
	p.volume_db = vol_db
	p.pitch_scale = 1.0
	p.play()


# ----------------------------------------------------------------- music
func music(name: String, fade := 2.0) -> void:
	if name == _music_name and (_music_a.playing or _music_b.playing):
		return
	var s = _pick("music", name)
	_music_name = name
	_crossfade(_music_a, _music_b, s, fade, -4.0)
	if s != null:
		var t = _music_a
		_music_a = _music_b
		_music_b = t


func music_stop(fade := 2.0) -> void:
	_music_name = ""
	for p in [_music_a, _music_b]:
		_fade_out(p, fade)


func current_music() -> String:
	return _music_name


func ambience(name: String, fade := 2.5) -> void:
	if name == _amb_name and (_amb_a.playing or _amb_b.playing):
		return
	var s = _pick("ambience", name)
	_amb_name = name
	_crossfade(_amb_a, _amb_b, s, fade, -6.0)
	if s != null:
		var t = _amb_a
		_amb_a = _amb_b
		_amb_b = t


func ambience_stop(fade := 2.0) -> void:
	_amb_name = ""
	for p in [_amb_a, _amb_b]:
		_fade_out(p, fade)


## 'from' is the player now sounding; 'to' takes the new stream and fades in.
func _crossfade(from: AudioStreamPlayer, to: AudioStreamPlayer, s: AudioStream, fade: float, vol: float) -> void:
	_fade_out(from, fade)
	if s == null:
		return
	_set_loop(s)
	_kill_fade(to)
	to.stream = s
	to.volume_db = -40.0
	to.play()
	var tw = create_tween()
	tw.tween_property(to, "volume_db", vol, max(0.05, fade)).set_trans(Tween.TRANS_SINE)
	_tweens[to.get_instance_id()] = tw


func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	_kill_fade(p)
	if not p.playing:
		return
	var tw = create_tween()
	tw.tween_property(p, "volume_db", -60.0, max(0.05, fade)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(p.stop)
	_tweens[p.get_instance_id()] = tw


func _kill_fade(p: AudioStreamPlayer) -> void:
	var old = _tweens.get(p.get_instance_id())
	if old != null and (old as Tween).is_valid():
		(old as Tween).kill()
	_tweens.erase(p.get_instance_id())


func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = int(w.get_length() * w.mix_rate)
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true


# ------------------------------------------------------------------ quitting
## Stops every player and drops the cache.
func shutdown() -> void:
	for p in [_music_a, _music_b, _amb_a, _amb_b]:
		_kill_fade(p)
	var all: Array = []
	all.append_array(_players)
	all.append_array(_players_2d)
	all.append_array([_music_a, _music_b, _amb_a, _amb_b])
	for p in all:
		p.stop()
		p.stream = null
	_streams.clear()
	_music_name = ""
	_amb_name = ""


## Quitting while sounds play leaves their playbacks alive when the engine frees
## its resources, which shows up as errors at exit. Stop everything, give the
## mixer a moment (real time, not game time) to let go, then quit.
func quit_game(code := 0) -> void:
	if _quitting:
		return
	_quitting = true
	shutdown()
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 150:
		await get_tree().process_frame
	get_tree().quit(code)
