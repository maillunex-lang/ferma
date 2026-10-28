extends SceneTree
## Visual QA: farm at start, half restored and fully restored.
## Usage: xvfb-run godot --path . --rendering-driver opengl3 -s tools/farm_shots.gd -- <out_dir>

func _init() -> void:
	_run.call_deferred()


func _shot(out: String, name: String, cam_pos: Vector2, zoom: float) -> void:
	var c = current_scene
	c.camera.position_smoothing_enabled = false
	c.camera.position = cam_pos
	c.camera.zoom = Vector2(zoom, zoom)
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name))


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sm = root.get_node("SaveManager")
	sm.save_path = "user://shot_save.json"
	sm.backup_path = "user://shot_backup.json"
	sm.data = sm.default_data()
	var gm = root.get_node("GameManager")
	gm.goto("farm")
	for i in 30:
		await process_frame
	await _shot(out, "farm_0_top.png", Vector2(800, 900), 0.55)
	await _shot(out, "farm_0_bottom.png", Vector2(800, 1900), 0.55)
	for l in 10:
		sm.data.levels[str(l + 1)] = {"completed": true, "stars": 3}
	for o in root.get_node("FarmProgression").objects:
		sm.data.farm[o.id] = o.levels.size() - 1
	gm.goto("farm")
	for i in 30:
		await process_frame
	await _shot(out, "farm_full_top.png", Vector2(800, 900), 0.55)
	await _shot(out, "farm_full_bottom.png", Vector2(800, 1900), 0.55)
	current_scene.select_object("house")
	await _shot(out, "farm_select.png", Vector2(600, 800), 0.8)
	current_scene._toggle_upgrades()
	await _shot(out, "farm_upgrades.png", Vector2(600, 800), 0.8)
	for p in ["user://shot_save.json", "user://shot_backup.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	quit()
