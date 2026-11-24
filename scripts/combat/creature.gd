class_name Creature
extends CharacterBody2D
## Base for anything that can be hurt in the world (the wolf, hares). Handles
## hp, hit reactions (flash, knockback, numbers, blood), freezing while a
## dialogue or menu is open, a hurtbox that arrows ray-cast against, arrows
## that stick in the hide and later fall out, and dropping loot on death.
## Subclasses override think() for behaviour and animate() for the look.

signal died(c: Node)
signal damaged(amount: int, hit: Dictionary)

const Pickup := preload("res://scripts/combat/pickup.gd")
const LAYER_CREATURE := 4
const LAYER_HURTBOX := 16

var enemy_id := ""
var def := {}
var hp := 1
var max_hp := 1
var fae := false
var dead := false
var weight := 1.0
var body: Node2D             # visual root, flipped to face left or right
var sprite: Sprite2D
var shadow: Sprite2D
var hurtbox: Area2D
var hurt_radius := 30.0
var hurt_offset := Vector2(0, -30)
var feet_radius := 16.0
var knock := Vector2.ZERO
var flash := 0.0
var facing_left := false
var stuck_arrows: Array = []  # [Sprite2D, ammo_id, seconds left, break_chance]
var ash_struck := false
## Gameplay randomness (choices, drops, where arrows fall) comes from the
## creature's own generator. Cosmetic effects (particles, flicker, sound
## variation) draw from the global one, so they can never change how a fight
## plays out, and a test can seed this to replay a fight exactly.
var rng := RandomNumberGenerator.new()
var _flash_mat: ShaderMaterial


func setup(id: String) -> void:
	enemy_id = id
	def = DB.enemies.get(id, {})
	max_hp = int(def.get("max_hp", 1))
	hp = max_hp
	fae = bool(def.get("fae", false))
	weight = float(def.get("weight", 1.0))


func _ready() -> void:
	collision_layer = LAYER_CREATURE
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("creatures")
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = feet_radius
	cs.shape = c
	add_child(cs)
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("fx/shadow.png")
	shadow.modulate = Color(0.05, 0.06, 0.12, 0.45)
	shadow.z_index = -1
	add_child(shadow)
	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	sprite = Sprite2D.new()
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = load("res://shaders/flash.gdshader")
	sprite.material = _flash_mat
	body.add_child(sprite)
	hurtbox = Area2D.new()
	hurtbox.collision_layer = LAYER_HURTBOX
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	var hs = CollisionShape2D.new()
	var hc = CircleShape2D.new()
	hc.radius = hurt_radius
	hs.shape = hc
	hs.position = hurt_offset
	hurtbox.add_child(hs)
	add_child(hurtbox)
	build_visual()


# -------------------------------------------------------------- overridables
func build_visual() -> void:
	pass


func think(_delta: float) -> void:
	velocity = Vector2.ZERO


func animate(_delta: float) -> void:
	pass


## Called before damage is applied; returns the final amount.
func modify_damage(dmg: int, _hit: Dictionary) -> int:
	return dmg


func on_hit(_dmg: int, _hit: Dictionary) -> void:
	pass


func on_death(_hit: Dictionary) -> void:
	pass


# ------------------------------------------------------------------- core
func frozen() -> bool:
	return Dialogue.active or UI.modal_open or Router.busy


func _physics_process(delta: float) -> void:
	if frozen():
		return
	if flash > 0.0:
		flash = max(0.0, flash - delta * 7.0)
		_flash_mat.set_shader_parameter("flash", flash)
	if not dead:
		think(delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	# knockback is added for the move only, so it never builds up in the
	# creature's own speed (states that ease velocity would keep it otherwise)
	var own = velocity
	velocity = own + knock
	move_and_slide()
	velocity = own
	knock = knock.move_toward(Vector2.ZERO, 2200.0 * delta)
	_update_stuck(delta)
	animate(delta)


func face(dx: float) -> void:
	if absf(dx) > 6.0:
		facing_left = dx < 0.0
		body.scale.x = -absf(body.scale.x) if facing_left else absf(body.scale.x)


func hurt_center() -> Vector2:
	return global_position + hurt_offset


func take_hit(hit: Dictionary) -> int:
	if dead:
		return 0
	var dmg = modify_damage(int(hit.get("damage", 1)), hit)
	hp = max(0, hp - dmg)
	flash = 1.0
	_flash_mat.set_shader_parameter("flash", flash)
	var dir: Vector2 = hit.get("dir", Vector2.ZERO)
	knock += dir * float(hit.get("knockback", 120.0)) * weight
	var at: Vector2 = hit.get("at", hurt_center())
	Fx.number(self, at, dmg, Color(1.0, 0.85, 0.5) if hit.get("ambush", false) else Color(1, 0.92, 0.85), hit.get("ambush", false))
	Fx.burst(self, at, dir, Color(0.62, 0.05, 0.08), 10 + dmg, 220.0, 0.9)
	Fx.blood_decals(self, global_position, dir, 2 + int(dmg / 6.0))
	GameState.bump("damage_dealt", dmg)
	damaged.emit(dmg, hit)
	on_hit(dmg, hit)
	if hp <= 0:
		_die(hit)
	return dmg


func _die(hit: Dictionary) -> void:
	dead = true
	hurtbox.set_deferred("monitorable", false)
	hurtbox.collision_layer = 0
	collision_layer = 0
	on_death(hit)
	drop_arrows()
	for dr in def.get("drops", []):
		spawn_pickup(String(dr.id), int(dr.get("n", 1)), global_position + Vector2(rng.randf_range(-30, 30), rng.randf_range(10, 30)))
	died.emit(self)


func spawn_pickup(id: String, n: int, at: Vector2) -> void:
	var p = Pickup.new()
	p.setup(id, n, at)
	var r = Fx.region_of(self)
	if r != null and r.world != null:
		r.world.add_child(p)
	else:
		get_parent().add_child(p)


# ---------------------------------------------------------- stuck arrows
func stick_arrow(ammo_id: String, at: Vector2, angle: float, break_chance: float) -> void:
	if dead:
		# a corpse keeps nothing: drop it straight away
		spawn_pickup(ammo_id, 1, global_position + Vector2(rng.randf_range(-40, 40), rng.randf_range(0, 30)))
		return
	var s = Sprite2D.new()
	var rel = "fx/ash_arrow.png" if ammo_id == "ash_arrow" else "fx/arrow.png"
	var k = Art.density(rel)
	s.texture = Art.tex(rel)
	s.scale = Vector2(k, k)
	s.position = body.to_local(at)
	# body may be mirrored; keep the shaft pointing back along its flight
	s.rotation = angle if not facing_left else PI - angle
	s.offset = Vector2(-18, 0) / k
	s.z_index = 1
	body.add_child(s)
	# ordinary arrows work loose after a few seconds; ash stays in until the end
	var life = 999.0 if ammo_id == "ash_arrow" else rng.randf_range(3.5, 6.0)
	stuck_arrows.append([s, ammo_id, life, break_chance])


func _update_stuck(delta: float) -> void:
	for i in range(stuck_arrows.size() - 1, -1, -1):
		var e: Array = stuck_arrows[i]
		e[2] -= delta
		if e[2] <= 0.0:
			var s: Sprite2D = e[0]
			var at = s.global_position
			s.queue_free()
			stuck_arrows.remove_at(i)
			if rng.randf() < float(e[3]):
				Fx.burst(self, at, Vector2.ZERO, Color(0.55, 0.42, 0.3), 6, 80.0, 0.5)
				Audio.sfx_at("arrow_break", at, -6.0)
			else:
				spawn_pickup(String(e[1]), 1, global_position + Vector2(rng.randf_range(-50, 50), rng.randf_range(0, 40)))


## Every arrow still in the hide drops beside the body (used on death).
func drop_arrows() -> void:
	for e in stuck_arrows:
		var s: Sprite2D = e[0]
		s.queue_free()
		spawn_pickup(String(e[1]), 1, global_position + Vector2(rng.randf_range(-60, 60), rng.randf_range(5, 45)))
	stuck_arrows.clear()


## A body lying on its side touches the snow along its whole length, so its
## shadow runs under all of it; with only a shadow at the feet a painted carcass
## reads as leaping, not lying. Returns [scale, position] for fx/shadow.png
## under 'spr', whose origin is the bottom middle of the picture.
static func lying_shadow(spr: Sprite2D) -> Array:
	var w = spr.texture.get_width() * absf(spr.scale.x)
	var h = spr.texture.get_height() * absf(spr.scale.y)
	var sh: Texture2D = Art.tex("fx/shadow.png")
	return [Vector2(w * 0.95 / sh.get_width(), h * 0.8 / sh.get_height()), spr.position + Vector2(0, -h * 0.36)]
