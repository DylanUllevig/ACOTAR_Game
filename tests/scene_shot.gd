extends Node
## Opens one region and saves a screenshot, for checking art and lighting:
##   godot --path . --resolution 1920x1080 -- --scene-shot cottage --chapter 2
##         --hour 17.4 --spawn door --flags ch02_arrived --at 600,700 --wait 2 --out shot.png
## --call <method> runs a region method first (--call door_burst; arguments
## after colons, --call wisps:true). --wolf dx,dy[,face]
## brings the forest wolf out of the brush and freezes him at that offset from her;
## --facing 0-3 turns her (down, left, right, up).
## Dialogue that starts on arrival is pressed through. main.gd starts this
## instead of the title screen when --scene-shot is given.


var _pressing := false


func _arg(a: PackedStringArray, key: String, default: String) -> String:
	var i = a.find(key)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else default


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var region_id = _arg(a, "--scene-shot", "forest")
	var out = _arg(a, "--out", "user://scene_shot.png")
	UI.auto = true
	SaveSystem.set_dir("user://scene_shot_saves/")
	if a.has("--hdr-off"):
		get_viewport().use_hdr_2d = false
	GameState.new_game()
	GameState.chapter = int(_arg(a, "--chapter", "1"))
	GameState.hour = float(_arg(a, "--hour", "13"))
	for f in _arg(a, "--flags", "").split(",", false):
		GameState.set_flag(f)
	await UI.fade_in(0.05)
	# arrival scenes play inside goto_region (on_enter), so press them through
	# while it runs, or it never returns
	_pressing = true
	_press_through()
	await Router.goto_region(region_id, _arg(a, "--spawn", ""), false)
	_pressing = false
	var rg = Router.current_region
	# lighting experiments: switch parts of the pipeline off
	if rg != null:
		if a.has("--post-off"):
			rg.post.visible = false
		if a.has("--mod-off"):
			rg.canvas_mod.visible = false
		if a.has("--lights-off"):
			for l in rg.find_children("*", "Light2D", true, false):
				l.visible = false
		if a.has("--glow-off"):
			rg.env.environment.glow_enabled = false
		if a.has("--glow-intensity"):
			rg.env.environment.glow_intensity = float(_arg(a, "--glow-intensity", "0.9"))
		if a.has("--glow-threshold"):
			rg.env.environment.glow_hdr_threshold = float(_arg(a, "--glow-threshold", "0.95"))
	# a region method to run first, such as a cutscene beat: --call door_burst,
	# with arguments after colons: --call wisps:true
	var call_parts = _arg(a, "--call", "").split(":")
	var method = call_parts[0]
	if method != "" and rg != null and rg.has_method(method):
		var call_args: Array = []
		for p in call_parts.slice(1):
			call_args.append(true if p == "true" else (false if p == "false" else (float(p) if p.is_valid_float() else p)))
		rg.callv(method, call_args)
	var at = _arg(a, "--at", "")
	if at != "" and Router.current_region != null:
		var xy = at.split(",")
		Router.current_region.player.global_position = Vector2(float(xy[0]), float(xy[1]))
	# the wolf out of the brush, frozen at an offset from her, to check how the
	# two overlap: --wolf 0,30 stands him just in front of her
	var wolf_at = _arg(a, "--wolf", "")
	if wolf_at != "" and rg != null and "wolf" in rg and rg.wolf != null:
		var d = wolf_at.split(",")
		var w = rg.wolf
		w.emerge()
		w.sprite.modulate.a = 1.0
		w.shadow.modulate.a = 0.45
		w.global_position = rg.player.global_position + Vector2(float(d[0]), float(d[1]))
		if d.size() > 2:
			w.face(float(d[2]))
		w.process_mode = Node.PROCESS_MODE_DISABLED
	# which way she faces: 0 down, 1 left, 2 right, 3 up
	var facing = _arg(a, "--facing", "")
	if facing != "" and rg != null and rg.player != null:
		rg.player.facing = int(facing)
	var t0 = Time.get_ticks_msec()
	var wait = float(_arg(a, "--wait", "2.0"))
	while Time.get_ticks_msec() - t0 < wait * 1000.0 or Dialogue.active:
		await get_tree().process_frame
		if Dialogue.active and Engine.get_process_frames() % 3 == 0:
			Dialogue.auto_advance()
		if Time.get_ticks_msec() - t0 > 60000:
			break
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("SCENE SHOT ", out)
	Audio.quit_game(0)


func _press_through() -> void:
	while _pressing:
		await get_tree().process_frame
		if Dialogue.active and Engine.get_process_frames() % 3 == 0:
			Dialogue.auto_advance()
