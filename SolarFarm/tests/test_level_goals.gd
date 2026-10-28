extends TestCase
## Goal tracking and deterministic star rating.


func level() -> Dictionary:
	return {"id": 99, "moves": 20, "goals": [{"type": "collect", "colors": [0], "target": 3}],
		"stars": {"two": 5, "three": 8, "extra": {"type": "no_helpers", "target": 0, "text": ""}}}


func phase_clearing(color: int, n: int) -> Dictionary:
	var cleared := []
	for i in n:
		cleared.append({"id": i, "pos": Vector2i(i, 0), "color": color, "special": 0})
	return {"cascade": 0, "cleared": cleared, "weeds": [], "effects": [], "created": [], "converted": [],
		"moves": [], "spawns": [], "groups": 1, "rockets_activated": 0}


func test_collect_goal_progress() -> void:
	var g := LevelGoals.new()
	g.setup(level())
	check(not g.is_complete(), "not complete at start")
	g.apply_result({"phases": [phase_clearing(1, 3)]})
	eq(g.goal_remaining(0), 3, "other colours do not count")
	g.apply_result({"phases": [phase_clearing(0, 2)]})
	eq(g.goal_remaining(0), 1, "two collected")
	g.apply_result({"phases": [phase_clearing(0, 5)]})
	check(g.is_complete(), "complete")
	eq(g.goal_remaining(0), 0, "remaining never negative")


func test_stars_are_deterministic() -> void:
	for case in [[0, false, 1], [4, false, 1], [5, false, 2], [8, false, 3], [12, true, 2], [8, true, 2]]:
		var g := LevelGoals.new()
		g.setup(level())
		g.apply_result({"phases": [phase_clearing(0, 3)]})
		g.moves_left = case[0]
		if case[1]:
			g.note_helper_used()
		for repeat in 3:
			eq(g.stars(), case[2], "moves_left=%d helpers=%s" % [case[0], case[1]])


func test_no_stars_when_failed() -> void:
	var g := LevelGoals.new()
	g.setup(level())
	for i in 20:
		g.use_move()
	eq(g.moves_left, 0, "moves run out")
	check(g.is_failed(), "failed")
	eq(g.stars(), 0, "no stars")
	g.use_move()
	eq(g.moves_left, 0, "moves never negative")


func test_extra_conditions() -> void:
	var lv := level()
	lv.stars.extra = {"type": "cascade", "target": 3, "text": ""}
	var g := LevelGoals.new()
	g.setup(lv)
	g.apply_result({"phases": [phase_clearing(0, 3), phase_clearing(1, 3)]})
	check(not g.extra_done(), "2 waves < 3")
	g.apply_result({"phases": [phase_clearing(2, 3), phase_clearing(1, 3), phase_clearing(1, 3), {"shuffle": []}]})
	check(g.extra_done(), "3 waves reached (shuffle ignored)")
	lv.stars.extra = {"type": "booster_combo", "target": 1, "text": ""}
	g = LevelGoals.new()
	g.setup(lv)
	g.apply_result({"phases": [phase_clearing(0, 3)], "combo": true})
	check(g.extra_done(), "combo counted")


func test_weeds_rockets_rainbow_goals() -> void:
	var lv := {"id": 98, "moves": 10, "goals": [{"type": "weeds", "target": 2}, {"type": "rockets", "target": 1}, {"type": "rainbow", "target": 1}],
		"stars": {"two": 1, "three": 2, "extra": {"type": "no_helpers", "target": 0, "text": ""}}}
	var g := LevelGoals.new()
	g.setup(lv)
	var ph := phase_clearing(0, 1)
	ph.weeds = [{"pos": Vector2i(1, 1), "hp": 0}, {"pos": Vector2i(2, 1), "hp": 1}]
	ph.rockets_activated = 1
	ph.created = [{"id": 1, "pos": Vector2i(0, 0), "special": BoardModel.Special.RAINBOW, "color": 0}]
	g.apply_result({"phases": [ph]})
	eq(g.goal_remaining(0), 1, "only destroyed weeds count")
	eq(g.goal_remaining(1), 0, "rocket counted")
	eq(g.goal_remaining(2), 0, "rainbow counted")
