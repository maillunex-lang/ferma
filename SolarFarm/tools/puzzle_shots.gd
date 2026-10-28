extends SceneTree
## Visual QA for the puzzle: plays a few bot moves on a level and saves
## screenshots (including a board with every booster type).
## Usage: xvfb-run godot --path . --rendering-driver opengl3 -s tools/puzzle_shots.gd -- <out_dir> <level>

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var lvl := int(args[1]) if args.size() > 1 else 7
	root.get_node("LevelManager").current_level_id = lvl
	root.get_node("GameManager").goto("puzzle")
	for i in 25:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("puzzle_intro.png"))
	for i in 40:
		await process_frame
	root.get_node("GameManager").close_dialog()
	var c = current_scene
	c.busy = false
	for m in 3:
		var mv := Match3Bot.choose_move(c.model, c.goals)
		if mv.kind == "swap":
			c._request_swap(mv.a, mv.b)
		else:
			c._do_activate(mv.a)
		for i in 12:
			await process_frame
		if m == 1:
			root.get_texture().get_image().save_png(out.path_join("puzzle_anim2.png"))
		if m == 0:
			root.get_texture().get_image().save_png(out.path_join("puzzle_anim.png"))
		while c.busy and not c.finished:
			await process_frame
	root.get_texture().get_image().save_png(out.path_join("puzzle_play.png"))
	c.model.load_layout([".0123450.".substr(1, 8), "1R230C12", "2B3*4501", "34501234", "45##2345", "50123450", "01234501", "12345012"])
	c.model.ice[2][6] = 1
	c.model.ice[3][6] = 2
	c.model.ice[4][6] = 1
	c._build_board()
	c._select(Vector2i(0, 0))
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("puzzle_specials.png"))
	c._deselect()
	c._request_swap(Vector2i(1, 1), Vector2i(1, 2))
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("puzzle_combo0.png"))
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("puzzle_combo.png"))
	quit()
