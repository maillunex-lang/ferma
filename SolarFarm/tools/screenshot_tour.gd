extends SceneTree
## Visual QA helper: opens each scene and saves a screenshot.
## Usage: xvfb-run godot --path . --rendering-driver opengl3 -s tools/screenshot_tour.gd -- <out_dir> [scene ...]

var out_dir := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred(args.slice(1))


func _run(names: Array) -> void:
	if names.is_empty():
		names = ["menu", "map", "puzzle", "farm", "helpers", "shop", "settings", "result"]
	for n in names:
		var gm = root.get_node("GameManager")
		if n == "result":
			root.get_node("LevelManager").last_result = {"level_id": 3, "won": true, "stars": 2, "coins": 140, "bonus_coins": 35,
				"helpers": {"rooster": 1}, "moves_left": 7, "first_clear": true, "unlock": ""}
		gm.goto(n)
		for i in 90:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(out_dir.path_join(n + ".png"))
		print("shot ", n)
	quit()
