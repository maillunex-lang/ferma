class_name TestCase
extends RefCounted
## Minimal assertion helpers for the headless test runner.

var tree: SceneTree
var failures: Array = []
var checks := 0
var current := ""


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(a, b, msg: String) -> void:
	check(a == b, "%s (expected %s, got %s)" % [msg, str(b), str(a)])


func root() -> Window:
	return tree.root


func autoload(n: String) -> Node:
	return tree.root.get_node(n)


## Points the save system at an isolated test file and starts a fresh profile.
func fresh_profile() -> void:
	var sm := autoload("SaveManager")
	sm.save_path = "user://test_save.json"
	sm.backup_path = "user://test_save_backup.json"
	for p in [sm.save_path, sm.backup_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	sm.load_game()
