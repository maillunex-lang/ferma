extends TestCase
## Integration: real scenes, a full puzzle played through the controller,
## helper double-tap protection, Android back button.


func _wait(frames: int) -> void:
	for i in frames:
		await tree.process_frame


func _goto(name: String) -> Node:
	autoload("GameManager").goto(name)
	await _wait(25)
	return tree.current_scene


func test_all_scenes_open() -> void:
	fresh_profile()
	for name in ["menu", "map", "farm", "helpers", "shop", "settings", "puzzle", "result"]:
		autoload("GameManager").close_dialog()
		var s: Node = await _goto(name)
		check(s != null, "scene %s opened" % name)
		eq(s.scene_file_path, autoload("GameManager").SCENES[name], "scene %s path" % name)
	autoload("GameManager").close_dialog()


func test_full_puzzle_playthrough() -> void:
	fresh_profile()
	autoload("LevelManager").current_level_id = 1
	var c: Node = await _goto("puzzle")
	autoload("GameManager").close_dialog()
	c.busy = false
	var guard := 0
	while not c.finished and guard < 60:
		guard += 1
		while c.busy and not c.finished:
			await tree.process_frame
		if c.finished:
			break
		if autoload("GameManager").has_dialog():
			break  # out of moves dialog
		var mv := Match3Bot.choose_move(c.model, c.goals)
		if mv.kind == "swap":
			c._request_swap(mv.a, mv.b)
		else:
			c._do_activate(mv.a)
		await tree.process_frame
		check(c.model.find_matches().is_empty() or c.busy, "no idle matches")
	check(c.finished, "level finished by playing through the scene")
	await _wait(150)
	eq(autoload("GameManager").current_scene_name, "result", "result screen shown")
	check(autoload("LevelManager").is_completed(1), "level 1 recorded as completed")
	check(autoload("LevelManager").last_result.won, "win recorded")


func test_helper_double_tap_spends_one_charge() -> void:
	fresh_profile()
	autoload("LevelManager").current_level_id = 2
	var c: Node = await _goto("puzzle")
	autoload("GameManager").close_dialog()
	c.busy = false
	var hm := autoload("HelperManager")
	var before: int = hm.charges("rooster")
	c._use_helper("rooster")
	c._use_helper("rooster")
	c._use_helper("rooster")
	await _wait(5)
	eq(hm.charges("rooster"), before - 1, "rapid taps spend exactly one charge")
	while c.busy:
		await tree.process_frame
	eq(c.goals.moves_left, c.goals.moves_total, "helper does not spend a move")
	check(c.goals.helpers_used == 1, "helper use recorded for the star rule")
	# Bee adds three moves.
	var bee_before: int = hm.charges("bee")
	c._use_helper("bee")
	await _wait(5)
	while c.busy:
		await tree.process_frame
	eq(hm.charges("bee"), bee_before - 1, "bee charge spent")
	eq(c.goals.moves_left, c.goals.moves_total + 3, "bee adds 3 moves")
	# Squirrel needs a target: entering target mode must not spend a charge.
	var sq_before: int = hm.charges("squirrel")
	c._use_helper("squirrel")
	eq(hm.charges("squirrel"), sq_before, "no charge spent before choosing a cell")
	c._cancel_target()
	eq(hm.charges("squirrel"), sq_before, "cancel keeps the charge")
	c._use_helper("squirrel")
	c._apply_target_helper(Vector2i(3, 3))
	c._apply_target_helper(Vector2i(4, 4))
	await _wait(5)
	eq(hm.charges("squirrel"), sq_before - 1, "squirrel spends one charge")
	while c.busy:
		await tree.process_frame
	# Empty helper: no charge, nothing happens.
	hm.add_charges("hedgehog", -99)
	c._use_helper("hedgehog")
	c._apply_target_helper(Vector2i(2, 2))
	eq(hm.charges("hedgehog"), 0, "empty helper stays at zero")
	c._cancel_target()
	c.finished = true


func test_back_button() -> void:
	fresh_profile()
	var gm := autoload("GameManager")
	gm.close_dialog()
	await _goto("farm")
	gm.go_back()
	await _wait(25)
	eq(gm.current_scene_name, "menu", "back from farm returns to menu")
	gm.go_back()
	await _wait(3)
	check(gm.has_dialog(), "back on main menu asks before exiting")
	gm.go_back()
	await _wait(3)
	check(not gm.has_dialog(), "back closes the dialog")
	autoload("LevelManager").current_level_id = 1
	var c: Node = await _goto("puzzle")
	gm.close_dialog()
	c.busy = false
	gm.go_back()
	await _wait(3)
	check(gm.has_dialog(), "back in the puzzle opens pause")
	gm.close_dialog()
	c.finished = true
	await _goto("menu")
