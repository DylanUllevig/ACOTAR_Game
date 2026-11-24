class_name Encounter
extends Node
## A stand-up fight with one or more Fighters (the naga at the snare, the
## puca in the woods). Waves come out of the trees one after another; the
## boss bar shows what is left of them all. Story beats fire like a hunt's
## (a "scene" freezes the fight, a "bark" plays over it). The fight ends when
## every foe is down, or when 'rescue_after' seconds have passed and the
## region's rescue scene takes over (someone arrives and finishes it).
##
## Defined under "encounters" in data/enemies.json.

signal finished(won: bool)

var region: Node
var player: Node2D
var def := {}
var max_attackers := 1
var spawn_points: Array = []      # world positions the foes step out from
var ward: Node2D = null           # someone the foes may go for instead of Feyre
var fighters: Array = []
var over := false
var elapsed := 0.0
var wave := 0
var _total_hp := 0
var _fired := {}
var _queue: Array = []
var _busy := false


func start(r: Node, id: String, points: Array, ward_node: Node2D = null) -> void:
	region = r
	player = r.player
	def = DB.encounter(id)
	max_attackers = int(def.get("max_attackers", 1))
	spawn_points = points
	ward = ward_node
	for w in def.get("waves", []):
		for e in w:
			_total_hp += int(DB.enemies.get(String(e), {}).get("max_hp", 1))
	player.died.connect(_on_player_died)
	UI.boss_show(String(def.get("name", "")), _total_hp)
	if def.has("music"):
		Audio.music(String(def.music), 1.2)
	_spawn_wave(0)
	_fire("start")


func _spawn_wave(i: int) -> void:
	var waves: Array = def.get("waves", [])
	if i >= waves.size():
		return
	wave = i
	var list: Array = waves[i]
	for k in list.size():
		var f = Fighter.new()
		f.setup(String(list[k]))
		f.encounter = self
		f.rng.seed = hash(String(def.get("name", "")) + str(i) + str(k))
		var at: Vector2 = spawn_points[(k + i * 2) % spawn_points.size()]
		f.position = at
		region.world.add_child(f)
		f.emerge(at + (at - player.global_position).normalized() * 120.0)
		if ward != null and float(def.get("ward_bias", 0.0)) > 0.0 and f.rng.randf() < float(def.ward_bias):
			f.target = ward
		f.died.connect(_on_fighter_died)
		fighters.append(f)
	if i > 0:
		_fire("wave_%d" % i)


func alive() -> Array:
	return fighters.filter(func(f): return is_instance_valid(f) and not f.dead)


func _hp_left() -> int:
	var hp = 0
	for f in alive():
		hp += f.hp
	# foes still to come count in full
	var waves: Array = def.get("waves", [])
	for i in range(wave + 1, waves.size()):
		for e in waves[i]:
			hp += int(DB.enemies.get(String(e), {}).get("max_hp", 1))
	return hp


func _frozen() -> bool:
	return Dialogue.active or UI.modal_open or Router.busy


func _process(delta: float) -> void:
	if over:
		return
	if not _frozen() and not _queue.is_empty() and not _busy:
		_run(_queue.pop_front())
	UI.boss_update(_hp_left(), _total_hp, false, false)
	if _frozen():
		return
	elapsed += delta
	if alive().is_empty():
		if wave + 1 < def.get("waves", []).size():
			_spawn_wave(wave + 1)
		else:
			_win()
		return
	if def.has("rescue_after") and elapsed >= float(def.rescue_after):
		_rescue()
		return
	if float(_hp_left()) < _total_hp * 0.5:
		_fire("half")
	if GameState.hp < GameState.max_hp * 0.35:
		_fire("player_low")
	# foes sent after the ward turn on Feyre when she stands in their way
	for f in alive():
		if f.target == ward and ward != null and f.global_position.distance_to(player.global_position) < 150.0:
			f.target = null


func on_fighter_hit(_f: Node, _dmg: int, _hit: Dictionary) -> void:
	_fire("first_blood")


func _on_fighter_died(_f: Node) -> void:
	GameState.bump("foes_slain")
	_fire("first_kill")


func _win() -> void:
	if over:
		return
	over = true
	GameState.bump("fights_won")
	await get_tree().create_timer(1.0, true, false, true).timeout
	UI.boss_hide()
	var tr = _trigger("victory")
	if tr.has("scene"):
		await Dialogue.play(String(tr.scene))
	finished.emit(true)


## Help arrives: the region's rescue scene plays and the rest of the foes are
## gone when it ends.
func _rescue() -> void:
	if over:
		return
	over = true
	UI.boss_hide()
	var tr = _trigger("rescue")
	if tr.has("scene"):
		await Dialogue.play(String(tr.scene))
	for f in alive():
		f.hp = 0
		f._die({"dir": Vector2.ZERO})
	finished.emit(true)


func _on_player_died() -> void:
	if over:
		return
	over = true
	UI.boss_hide()
	Audio.music_stop(1.5)
	finished.emit(false)


# --------------------------------------------------------------- triggers
func _trigger(when: String) -> Dictionary:
	for tr in def.get("triggers", []):
		if String(tr.when) == when:
			return tr
	return {}


func _fire(when: String) -> void:
	if _fired.has(when) or over:
		return
	var tr = _trigger(when)
	if tr.is_empty():
		return
	_fired[when] = true
	_queue.append(tr)


func _run(tr: Dictionary) -> void:
	_busy = true
	if tr.has("bark"):
		var b: Dictionary = tr.bark
		Dialogue.bark(String(b.get("s", "feyre")), String(b.get("e", "neutral")), String(b.get("t", "")))
	elif tr.has("scene"):
		await Dialogue.play(String(tr.scene))
	_busy = false
