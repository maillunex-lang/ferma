extends SceneTree
## Balance simulation: plays every level with the greedy bot (no helpers).
## Usage: godot --headless --path . -s tests/sim_levels.gd -- [games] [level]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 20
	var only := int(args[1]) if args.size() > 1 else 0
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	for level in data.levels:
		if only > 0 and int(level.id) != only:
			continue
		var wins := 0
		var stars := [0, 0, 0, 0]
		var ml := 0.0
		var t := Time.get_ticks_msec()
		for i in games:
			var r := Match3Bot.play_level(level, 1000 + i)
			if r.won:
				wins += 1
				ml += r.moves_left
			stars[r.stars] += 1
		print("L%d %-22s win %3d%%  stars0-3 %s  avg_left %.1f  (%d ms)" % [level.id, level.name, wins * 100 / games, str(stars), ml / max(1, wins), Time.get_ticks_msec() - t])
	quit()
