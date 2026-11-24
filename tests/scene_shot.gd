extends Node
## Opens one region and saves a screenshot, for checking art and lighting:
##   godot --path . --resolution 1920x1080 -- --scene-shot cottage --chapter 2
##         --hour 17.4 --spawn door --flags ch02_arrived --at 600,700 --wait 2 --out shot.png
## Dialogue that starts on arrival is pressed through. main.gd starts this
## instead of the title screen when --scene-shot is given.


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
	await Router.goto_region(region_id, _arg(a, "--spawn", ""), false)
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
	var at = _arg(a, "--at", "")
	if at != "" and Router.current_region != null:
		var xy = at.split(",")
		Router.current_region.player.global_position = Vector2(float(xy[0]), float(xy[1]))
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
