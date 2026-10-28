extends SceneTree
## Two-process persistence check (simulates a forced close and relaunch).
##   phase "write":  win level 1, buy a free pack, upgrade the house, then the
##                   process kills itself without a normal shutdown.
##   phase "verify": a new process loads the save and checks everything is there.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var phase: String = OS.get_cmdline_user_args()[0]
	var sm = root.get_node("SaveManager")
	sm.save_path = "user://restart_check.json"
	sm.backup_path = "user://restart_check_backup.json"
	if phase == "write":
		for p in [sm.save_path, sm.backup_path]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		sm.load_game()
		root.get_node("LevelManager").record_result(1, true, 3, 6)
		root.get_node("EconomyManager").purchase("pack_bee")
		await process_frame
		await process_frame
		root.get_node("FarmProgression").upgrade("house")
		print("WRITE coins=%d bee=%d house=%d" % [sm.data.coins, sm.data.helpers.bee, sm.data.farm.house])
		OS.kill(OS.get_process_id())  # no clean exit: simulates a force close
	else:
		sm.load_game()
		var ok: bool = sm.load_source == "main" and bool(sm.data.levels["1"].completed) and int(sm.data.levels["1"].stars) == 3 \
			and int(sm.data.helpers.bee) == 4 and int(sm.data.farm.house) == 1
		print("VERIFY source=%s coins=%d bee=%d house=%d level1=%s -> %s" % [sm.load_source, sm.data.coins, sm.data.helpers.bee,
			sm.data.farm.house, str(sm.data.levels.get("1", {})), "OK" if ok else "FAIL"])
		for p in [sm.save_path, sm.backup_path]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		quit(0 if ok else 1)
