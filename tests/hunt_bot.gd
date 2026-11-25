extends Node
## Plays the wolf hunt the way a careful player would, through the same input a
## person uses: number keys pick the hotbar slot, the use_item action is pressed
## and released, movement goes through the move actions. Only the aim is set
## directly (player.bot_aim), because a headless run has no real mouse.
## Used by the headless tests (story flow and balance) and the screenshot tour.

const Wolf := preload("res://scripts/combat/wolf.gd")

var region: Node
var god := false            # story-flow tests: Feyre takes no damage
var skill := 1.0            # chance to sidestep each telegraphed lunge
var passive := false        # stands still in the open and does nothing (defeat test)
var rng := RandomNumberGenerator.new()
var ash_from_hiding := false
var hits_taken := 0
var lunges_seen := 0
var lunges_dodged := 0

var _use_down := false
var _dodging := false
var _dodge_dir := Vector2.ZERO
var _seen_windup := false
var _last_hp := -1
var _moves := {"move_left": 0.0, "move_right": 0.0, "move_up": 0.0, "move_down": 0.0}
var _sprint := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func stop() -> void:
	_release_all()
	if region and is_instance_valid(region) and region.player:
		region.player.bot_aim = null
		region.player.god = false
	queue_free()


func _physics_process(delta: float) -> void:
	if region == null or not is_instance_valid(region) or region.player == null:
		return
	var p = region.player
	p.god = god
	if _last_hp >= 0 and GameState.hp < _last_hp:
		hits_taken += 1
	_last_hp = GameState.hp
	var w = region.wolf
	if passive or w == null or w.dead or p.dead or region.hunt == null or _frozen():
		_release_all()
		return
	p.bot_aim = w.hurt_center()
	var to_w: Vector2 = w.global_position - p.global_position
	var dist = to_w.length()
	if not w.alerted:
		_opening_shot(p)
		return
	# a telegraphed lunge: step off his line, sprinting, until he has sprung
	if w.s == Wolf.S.WINDUP:
		if not _seen_windup:
			_seen_windup = true
			lunges_seen += 1
			_dodging = rng.randf() < skill and dist < 460.0
			if _dodging:
				lunges_dodged += 1
				var side = Vector2(-to_w.y, to_w.x).normalized()
				if rng.randf() < 0.5:
					side = -side
				_dodge_dir = (side - to_w.normalized() * 0.25).normalized()
	elif w.s == Wolf.S.BITE_WINDUP:
		# his eyes flare for a snap: step back out of reach
		if not _seen_windup:
			_seen_windup = true
			_dodging = rng.randf() < skill
			if _dodging:
				_dodge_dir = -to_w.normalized()
	elif w.s != Wolf.S.LUNGE and w.s != Wolf.S.BITE:
		_seen_windup = false
		_dodging = false
	if _dodging:
		_use(false)
		_move(_dodge_dir, true)
		return
	# a careful hunter gets out of the thorns once he knows where she is
	if region.hunt.in_cover(p.global_position) and skill > 0.5:
		_move(Vector2(0.3, -1.0).normalized(), false)
		return
	# heal when it is safe enough and there is food
	if GameState.hp < GameState.max_hp * 0.45 and dist > 220.0:
		var food = _slot_of_kind("eat")
		if food >= 0:
			_select(food)
			_tap_use()
			_move(-to_w.normalized(), false)
			return
	var ammo = GameState.count("arrow")
	if ammo > 0 and dist > 300.0 and w.s != Wolf.S.LUNGE:
		_select(_slot_of("bow"))
		if dist < 380.0:
			_move(-to_w.normalized(), false)
		else:
			_move(Vector2.ZERO, false)
		if not p.drawing:
			_use(true)
		elif p.draw_fraction() >= 0.98:
			_use(false)
		return
	if p.drawing:
		# he closed the gap: loose whatever is drawn
		_use(false)
		return
	_select(_slot_of("hunting_knife"))
	var edge = p.global_position.distance_to(w.hurt_center()) - float(w.hurt_radius)
	if edge > 70.0:
		_move(to_w.normalized(), false)
	elif edge < 20.0:
		_move(-to_w.normalized(), false)
	else:
		_move(Vector2.ZERO, false)
	if edge <= 78.0 and p.slash_cd <= 0.0:
		_tap_use()


func _opening_shot(p: Node) -> void:
	_move(Vector2.ZERO, false)
	var ash = _slot_of("ash_arrow")
	if ash < 0:
		ash = _slot_of("bow")
	_select(ash)
	if not p.drawing:
		_use(true)
	elif p.draw_fraction() >= 1.0:
		ash_from_hiding = GameState.selected_item_id() == "ash_arrow"
		_use(false)


func _frozen() -> bool:
	return Dialogue.active or UI.modal_open or Router.busy


# ------------------------------------------------------------------ input
func _select(i: int) -> void:
	if i < 0 or i == GameState.hotbar_index:
		return
	var ev = InputEventKey.new()
	ev.keycode = KEY_0 if i == 9 else KEY_1 + i
	ev.physical_keycode = ev.keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	var up = ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _use(down: bool) -> void:
	if down == _use_down:
		return
	_use_down = down
	var ev = InputEventAction.new()
	ev.action = "use_item"
	ev.pressed = down
	ev.strength = 1.0 if down else 0.0
	Input.parse_input_event(ev)


func _tap_use() -> void:
	_use(false)
	_use(true)
	_use(false)


func _move(dir: Vector2, sprint: bool) -> void:
	var want = {"move_left": max(0.0, -dir.x), "move_right": max(0.0, dir.x), "move_up": max(0.0, -dir.y), "move_down": max(0.0, dir.y)}
	for a in want:
		if absf(want[a] - _moves[a]) > 0.01:
			_moves[a] = want[a]
			if want[a] > 0.0:
				Input.action_press(a, want[a])
			else:
				Input.action_release(a)
	if sprint != _sprint:
		_sprint = sprint
		if sprint:
			Input.action_press("sprint")
		else:
			Input.action_release("sprint")


func _release_all() -> void:
	_use(false)
	_move(Vector2.ZERO, false)


func _slot_of(id: String) -> int:
	for i in GameState.hotbar_size():
		var s = GameState.slot(i)
		if s != null and String(s.id) == id:
			return i
	return -1


func _slot_of_kind(use: String) -> int:
	for i in GameState.hotbar_size():
		var s = GameState.slot(i)
		if s != null and String(DB.item(String(s.id)).get("use", "")) == use:
			return i
	return -1
