class_name Critter
extends Node2D
## Small life that makes a place feel lived in. Birds peck and hop about and
## burst into the air when Feyre comes close; squirrels, rabbits and foxes sit,
## eat or doze and run off; butterflies wander and never mind her. Anything
## that has fled comes back a while later, once she is out of the way.
## Sheets come from tools/pixel/build_assets.py (frames face right).

const KINDS := {
	# shy: how near she may come; speed: how fast it leaves (world units a second)
	"crow": {"shy": 170.0, "speed": 230.0, "flies": true, "idle": ["idle", "peck"], "flee": "fly", "shadow": "shadow_s"},
	"robin": {"shy": 120.0, "speed": 240.0, "flies": true, "idle": ["idle", "peck"], "flee": "fly", "shadow": "shadow_s"},
	"bluebird": {"shy": 120.0, "speed": 240.0, "flies": true, "idle": ["idle", "peck"], "flee": "fly", "shadow": "shadow_s"},
	"squirrel": {"shy": 160.0, "speed": 260.0, "flies": false, "idle": ["sit", "eat"], "flee": "run", "shadow": "shadow_s"},
	"rabbit": {"shy": 170.0, "speed": 250.0, "flies": false, "idle": ["sit", "eat"], "flee": "hop", "shadow": "shadow_s"},
	"fox": {"shy": 260.0, "speed": 190.0, "flies": false, "idle": ["sleep", "sit"], "flee": "trot", "shadow": "shadow_m"},
	"stag": {"shy": 320.0, "speed": 260.0, "flies": false, "idle": ["graze", "stand"], "flee": "walk", "shadow": "shadow_l"},
	"butterfly_white": {"shy": 0.0, "speed": 40.0, "flies": true, "idle": ["flap"], "flee": "flap", "shadow": ""},
	"butterfly_yellow": {"shy": 0.0, "speed": 40.0, "flies": true, "idle": ["flap"], "flee": "flap", "shadow": ""},
}

var kind := "crow"
var spec := {}
var meta := {}
var sprite: Sprite2D
var shadow: Sprite2D
var home := Vector2.ZERO
var state := "idle"            # idle, flee, away, back
var rng := RandomNumberGenerator.new()
var _anim := ""
var _t := 0.0                  # animation clock
var _timer := 0.0              # time left in the current idle pose
var _vel := Vector2.ZERO
var _lift := 0.0               # height above the ground while flying
var _hop := Vector2.ZERO       # a short hop in progress: target
var _region: Node


## kind: a key of KINDS; pos: where it lives; seed: keeps each one's timing apart.
func setup(k: String, pos: Vector2, seed_value: int, region: Node) -> Critter:
	kind = k
	spec = KINDS.get(k, KINDS["crow"])
	home = pos
	position = pos
	_region = region
	rng.seed = seed_value
	var rel = "actors/%s.png" % _sheet_name()
	meta = Art.pixel_meta(rel)
	sprite = Sprite2D.new()
	sprite.texture = Art.lit(rel)
	if sprite.texture == null:
		return self
	var g: Array = meta.get("grid", [1, 1])
	sprite.hframes = int(g[0])
	sprite.vframes = int(g[1])
	sprite.scale = Art.sprite_scale(rel)
	sprite.offset = Vector2(0, -sprite.texture.get_height() / (2.0 * sprite.vframes))
	sprite.flip_h = rng.randf() < 0.5
	if String(spec.get("shadow", "")) != "":
		shadow = Sprite2D.new()
		shadow.texture = Art.tex("fx/%s.png" % spec["shadow"])
		shadow.scale = Vector2.ONE * Art.PX
		shadow.light_mask = 0
		shadow.z_index = -1
		add_child(shadow)
	add_child(sprite)
	_timer = rng.randf_range(0.3, 2.0)
	_play(String(spec["idle"][0]))
	return self


func _sheet_name() -> String:
	if kind.begins_with("butterfly"):
		return "butterfly"
	return kind


func _anims() -> Dictionary:
	var a: Dictionary = meta.get("anims", {})
	if kind == "butterfly_yellow":
		return {"flap": a.get("yellow", [0])}
	if kind == "butterfly_white":
		return {"flap": a.get("white", [0])}
	return a


func _play(anim: String) -> void:
	if anim != _anim:
		_anim = anim
		_t = 0.0


func _process(delta: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	var fps = 6.0
	match state:
		"idle":
			_idle(delta)
		"flee":
			fps = 12.0
			_flee(delta)
		"away":
			_away(delta)
		"back":
			_back(delta)
	_t += delta * fps
	var frames: Array = _anims().get(_anim, [])
	if not frames.is_empty():
		sprite.frame = int(frames[int(_t) % frames.size()])
	sprite.position.y = -_lift
	if shadow:
		shadow.visible = _lift < 30.0
		shadow.modulate.a = sprite.modulate.a * clampf(1.0 - _lift / 30.0, 0.0, 1.0)


func _threat() -> Vector2:
	## The nearest thing that scares it (Feyre), as an offset from it, or ZERO.
	if _region == null or _region.get("player") == null:
		return Vector2.ZERO
	var p: Node2D = _region.player
	if not is_instance_valid(p):
		return Vector2.ZERO
	return p.global_position - global_position


func _idle(delta: float) -> void:
	if kind.begins_with("butterfly"):
		_flutter(delta)
		return
	var d = _threat()
	if d != Vector2.ZERO and d.length() < float(spec["shy"]):
		_start_flee(d)
		return
	if _hop != Vector2.ZERO:
		# a little hop: a few pixels along the ground with a tiny arc
		var step = _hop - position
		var mv = minf(step.length(), 70.0 * delta)
		position += step.normalized() * mv
		_lift = sin(clampf(1.0 - step.length() / 22.0, 0.0, 1.0) * PI) * 4.0
		if step.length() < 1.0:
			_hop = Vector2.ZERO
			_lift = 0.0
		return
	_timer -= delta
	if _timer <= 0.0:
		var poses: Array = spec["idle"]
		_play(String(poses[rng.randi_range(0, poses.size() - 1)]))
		_timer = rng.randf_range(0.5, 2.4)
		if spec["flies"] and rng.randf() < 0.35:
			# hop a step or two, staying near home
			var dir = Vector2(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5)).normalized()
			if position.distance_to(home) > 40.0:
				dir = (home - position).normalized()
			_hop = position + dir * rng.randf_range(10.0, 22.0)
			sprite.flip_h = dir.x < 0.0


func _flutter(delta: float) -> void:
	# a butterfly's wandering, looping path around home, bobbing up and down
	var t = Time.get_ticks_msec() / 1000.0 + float(rng.seed % 100)
	var target = home + Vector2(sin(t * 0.37) * 90.0 + sin(t * 1.3) * 20.0, cos(t * 0.29) * 50.0)
	var dv = target - position
	position += dv * clampf(delta * 1.5, 0.0, 1.0)
	_lift = 34.0 + sin(t * 3.1) * 8.0
	if absf(dv.x) > 2.0:
		sprite.flip_h = dv.x < 0.0
	z_index = 30


func _start_flee(threat: Vector2) -> void:
	state = "flee"
	_play(String(spec["flee"]))
	var away = -threat.normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	if spec["flies"]:
		away = (away + Vector2(0, -0.6)).normalized()
	_vel = away * float(spec["speed"]) * rng.randf_range(0.9, 1.15)
	sprite.flip_h = _vel.x < 0.0
	_timer = 1.6 if spec["flies"] else 1.3
	if kind == "fox":
		_timer = 2.4
	if spec["flies"]:
		z_index = 40
		Audio.sfx_at("wings", global_position, -12.0, 0.15)


func _flee(delta: float) -> void:
	position += _vel * delta
	if spec["flies"]:
		_lift += 90.0 * delta
	_timer -= delta
	if _timer < 0.6:
		sprite.modulate.a = maxf(0.0, _timer / 0.6)
	if _timer <= 0.0:
		state = "away"
		visible = false
		_timer = rng.randf_range(9.0, 18.0)


func _away(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var d = _threat()
	# come back only while she is well away from the spot
	if d != Vector2.ZERO and (_region.player.global_position - home).length() < 520.0:
		_timer = 3.0
		return
	position = home + Vector2(rng.randf_range(-20, 20), rng.randf_range(-10, 10))
	_lift = 40.0 if spec["flies"] else 0.0
	state = "back"
	visible = true
	sprite.modulate.a = 0.0
	_play(String(spec["flee"]) if spec["flies"] else String(spec["idle"][0]))


func _back(delta: float) -> void:
	sprite.modulate.a = minf(1.0, sprite.modulate.a + delta * 1.5)
	if spec["flies"]:
		_lift = maxf(0.0, _lift - 50.0 * delta)
		if _lift > 0.0:
			return
	if sprite.modulate.a >= 1.0:
		state = "idle"
		z_index = 0
		_play(String(spec["idle"][0]))
		_timer = rng.randf_range(0.5, 2.0)
