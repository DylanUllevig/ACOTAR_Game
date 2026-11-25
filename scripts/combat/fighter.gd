class_name Fighter
extends Creature
## A melee fighter for the woods' fights (the naga, the puca). It closes on
## its target, rears back (a clear tell, the moment to step aside or strike
## first), lunges with its claws, then stands open for a moment before it
## comes again. Several in one fight keep apart and take turns, so a crowd
## reads as a dance rather than a pile. A hard enough hit during the rear-back
## staggers it and cancels the lunge.
##
## Tuned in data/enemies.json ("attack", speeds, "stagger_damage") and drawn
## from a pixel sheet with the animations walk, rear, lunge, hurt and dead.

signal struck(target: Node)

var target: Node2D = null          # who it goes for; Feyre if none
var encounter: Node = null
var state := "approach"
var _t := 0.0
var _dir := Vector2.RIGHT
var _hit_done := false
var _strafe := 1.0
var _strafe_t := 0.0
var _cool := 0.0
var _emerge := 0.0


func setup(id: String) -> void:
	super.setup(id)
	var art: Dictionary = def.get("art", {})
	hurt_radius = float(art.get("hurt_radius", 30))
	var ho: Array = art.get("hurt_offset", [0, -42])
	hurt_offset = Vector2(float(ho[0]), float(ho[1]))
	feet_radius = float(art.get("feet_radius", 16))


func build_visual() -> void:
	var art: Dictionary = def.get("art", {})
	var rel = String(art.get("sprite", "actors/naga.png"))
	if not use_pixel_sheet(rel):
		sprite.texture = Art.lit(rel)
	shadow.scale = Vector2(float(art.get("shadow", 1.0)), float(art.get("shadow", 1.0)) * 0.45)
	_strafe = 1.0 if rng.randf() < 0.5 else -1.0
	_cool = rng.randf_range(0.4, 1.4)
	px_play("walk", 0.0)
	# by night a faint cold light clings to it, so a dark shape still reads
	# against the dark ground
	if Region.night_amount(GameState.hour) > 0.5:
		var l = PointLight2D.new()
		l.texture = Art.soft_light_texture()
		l.position = hurt_offset
		l.color = Color(0.74, 0.8, 1.0)
		l.energy = 0.6
		l.texture_scale = 1.2
		body.add_child(l)


## Slides out of hiding (from under the trees) before it acts.
func emerge(from: Vector2, time := 0.9) -> void:
	var to = global_position
	global_position = from
	_emerge = time
	body.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", to, time).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body, "modulate:a", 1.0, time * 0.6)


func _target() -> Node2D:
	if target != null and is_instance_valid(target) and not ("dead" in target and target.dead):
		return target
	var r = Router.current_region
	return r.player if r != null else null


func _attack() -> Dictionary:
	return def.get("attack", {})


## No more than the encounter allows may be rearing or lunging at once.
func _may_attack() -> bool:
	var limit = int(def.get("max_attackers", 1))
	if encounter != null and "max_attackers" in encounter:
		limit = encounter.max_attackers
	var busy = 0
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != self and not f.dead and (f.state == "windup" or f.state == "strike"):
			busy += 1
	return busy < limit


## Keeps fighters from walking through each other.
func _separation() -> Vector2:
	var push = Vector2.ZERO
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self or f.dead:
			continue
		var d = global_position - f.global_position
		var l = d.length()
		if l < 110.0 and l > 0.01:
			push += d / l * (110.0 - l) / 110.0
	return push


func think(delta: float) -> void:
	if _emerge > 0.0:
		_emerge -= delta
		velocity = Vector2.ZERO
		return
	var tgt = _target()
	if tgt == null:
		velocity = Vector2.ZERO
		return
	var atk = _attack()
	var to: Vector2 = tgt.global_position - global_position
	var d = to.length()
	var speed = float(def.get("speed", 150))
	_cool -= delta
	match state:
		"approach":
			var rng_atk = float(atk.get("range", 170))
			if d < rng_atk and _cool <= 0.0 and _may_attack():
				state = "windup"
				_t = float(atk.get("windup", 0.55))
				_dir = to.normalized()
				Audio.sfx_at(String(def.get("windup_sfx", "")), global_position, -4.0)
				face(to.x)
				return
			_strafe_t -= delta
			if _strafe_t <= 0.0:
				_strafe_t = rng.randf_range(1.2, 2.6)
				if rng.randf() < 0.4:
					_strafe = -_strafe
			var want: Vector2
			if d > rng_atk * 0.9:
				want = to.normalized() + to.normalized().orthogonal() * 0.35 * _strafe
			else:
				# in range but waiting its turn: circle at a wary distance
				want = to.normalized().orthogonal() * _strafe - to.normalized() * clampf((rng_atk * 0.8 - d) / 80.0, 0.0, 1.0)
			want += _separation() * 1.6
			var spd = speed if d > rng_atk * 0.9 else speed * 0.55
			velocity = velocity.move_toward(want.normalized() * spd, 900.0 * delta)
			face(velocity.x if absf(velocity.x) > 20.0 else to.x)
		"windup":
			velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
			_dir = _dir.slerp(to.normalized(), clampf(float(atk.get("turn", 1.2)) * delta, 0.0, 1.0))
			face(_dir.x)
			_t -= delta
			if _t <= 0.0:
				state = "strike"
				_t = float(atk.get("time", 0.3))
				_hit_done = false
				Audio.sfx_at(String(def.get("strike_sfx", "knife_swing")), global_position, -4.0, 0.1)
		"strike":
			velocity = _dir * float(atk.get("speed", 520))
			_t -= delta
			if not _hit_done:
				_try_hit(tgt, atk)
			if _t <= 0.0:
				state = "recover"
				_t = float(atk.get("recover", 0.7))
		"recover":
			velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
			_t -= delta
			if _t <= 0.0:
				state = "approach"
				_cool = float(atk.get("cooldown", 0.9)) * rng.randf_range(0.8, 1.3)
		"stagger":
			velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
			_t -= delta
			if _t <= 0.0:
				state = "approach"
				_cool = 0.3


func _try_hit(tgt: Node2D, atk: Dictionary) -> void:
	var reach = float(atk.get("reach", 70))
	var tip = global_position + _dir * reach * 0.7
	if tip.distance_to(tgt.global_position) > reach * 0.75 + 18.0:
		return
	_hit_done = true
	var dmg = int(atk.get("damage", 6))
	if tgt.has_method("take_damage"):
		tgt.take_damage(dmg, global_position, _dir * float(atk.get("knockback", 320)), self)
	struck.emit(tgt)


func on_hit(dmg: int, hit: Dictionary) -> void:
	Fx.hitstop(self, 0.04)
	var stag = int(def.get("stagger_damage", 9))
	# a hit while it rears back, or a heavy one at any time, knocks it off balance
	if state == "windup" or dmg >= stag:
		state = "stagger"
		_t = float(def.get("stagger_time", 0.45))
		Audio.sfx_at(String(def.get("hurt_sfx", "")), global_position, -4.0)
	if encounter != null and encounter.has_method("on_fighter_hit"):
		encounter.on_fighter_hit(self, dmg, hit)


func on_death(_hit: Dictionary) -> void:
	state = "dead"
	velocity = Vector2.ZERO
	remove_from_group("fighters")
	Audio.sfx_at(String(def.get("death_sfx", "")), global_position, -2.0)
	if pixel():
		px_play("dead", 0.0)
	var tw = create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(body, "modulate:a", 0.0, 1.5)
	tw.tween_callback(queue_free)


func animate(delta: float) -> void:
	if dead or not pixel():
		return
	match state:
		"approach":
			if velocity.length() > 12.0:
				px_play("walk", delta, clampf(velocity.length() / 24.0, 4.0, 10.0))
			else:
				px_play("walk", 0.0)
		"windup":
			px_play("rear", delta)
		"strike":
			px_play("lunge", delta)
		"recover":
			px_play("rear" if _t > 0.35 else "walk", delta, 2.0)
		"stagger":
			px_play("hurt", delta)


func _ready() -> void:
	super._ready()
	add_to_group("fighters")
