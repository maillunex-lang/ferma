extends SceneTree
## Headless test runner.
## Usage: godot --headless --path . -s tests/run_tests.gd [-- suite_name ...]

const SUITES := [
	"res://tests/test_board_model.gd",
	"res://tests/test_level_goals.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_save.gd",
	"res://tests/test_resources.gd",
	"res://tests/test_levels.gd",
	"res://tests/test_scenes.gd",
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_cmdline_user_args()
	var total_checks := 0
	var all_failures := []
	var t0 := Time.get_ticks_msec()
	for path in SUITES:
		var suite_name: String = path.get_file().get_basename()
		if not only.is_empty() and not only.has(suite_name):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			all_failures.append("%s: script failed to load" % suite_name)
			continue
		var suite: TestCase = script.new()
		suite.tree = self
		var methods := []
		for m in suite.get_method_list():
			if str(m.name).begins_with("test_"):
				methods.append(m.name)
		var t := Time.get_ticks_msec()
		for m in methods:
			suite.current = "%s.%s" % [suite_name, m]
			if OS.has_environment("TEST_VERBOSE"):
				print("  > ", suite.current)
			await suite.call(m)
		total_checks += suite.checks
		all_failures.append_array(suite.failures)
		print("[%s] %d tests, %d checks, %d failures (%d ms)" % [suite_name, methods.size(), suite.checks, suite.failures.size(), Time.get_ticks_msec() - t])
	# Restore the player's real save location after tests.
	for p in ["user://test_save.json", "user://test_save_backup.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("")
	for f in all_failures:
		print("FAIL ", f)
	print("TOTAL: %d checks, %d failures, %.1f s" % [total_checks, all_failures.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	print("RESULT: %s" % ("PASS" if all_failures.is_empty() else "FAIL"))
	quit(0 if all_failures.is_empty() else 1)
