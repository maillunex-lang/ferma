class_name Match3Bot
extends RefCounted
## Greedy auto-player. Used by the automated level tests to prove that every
## level can be finished without helpers, and to estimate difficulty.


static func choose_move(board: BoardModel, goals: LevelGoals) -> Dictionary:
	var best := {}
	var best_score := -INF
	var wanted := goals.wanted_colors()
	var candidates := []
	for m in board.find_possible_moves():
		candidates.append({"kind": "swap", "a": m[0], "b": m[1]})
	for x in BoardModel.W:
		for y in BoardModel.H:
			var p = board.grid[x][y]
			if p != null and p.special != BoardModel.Special.NONE:
				candidates.append({"kind": "tap", "a": Vector2i(x, y)})
	for c in candidates:
		var sim := board.clone()
		sim.rng.randomize()  # the bot must not foresee future refills
		var res: Dictionary
		if c.kind == "swap":
			res = sim.try_swap(c.a, c.b)
		else:
			res = sim.activate_at(c.a)
		if not res.valid:
			continue
		var score := _score(res, goals, wanted) + randf() * 0.5
		if c.kind == "tap":
			score -= 6.0  # prefer saving boosters for combos unless they help a lot
		if score > best_score:
			best_score = score
			best = c
	return best


static func _score(res: Dictionary, goals: LevelGoals, wanted: Array) -> float:
	var s := 0.0
	var need_weeds := goals.needs("weeds")
	var need_rockets := goals.needs("rockets")
	var need_rainbow := goals.needs("rainbow")
	if res.get("combo", false):
		s += 12.0
	for ph in res.phases:
		if ph.has("shuffle"):
			continue
		for c in ph.cleared:
			s += 10.0 if wanted.has(c.color) else 1.0
		for w in ph.weeds:
			s += 14.0 if need_weeds else 1.0
		s += ph.rockets_activated * (18.0 if need_rockets else 2.0)
		for cr in ph.created:
			match int(cr.special):
				BoardModel.Special.RAINBOW:
					s += 60.0 if need_rainbow else 25.0
				BoardModel.Special.BASKET:
					s += 12.0
				_:
					s += 14.0 if need_rockets else 8.0
	return s


## Plays a full level and returns {won, stars, moves_left, stats}.
static func play_level(level: Dictionary, seed_value: int, max_moves_guard: int = 200) -> Dictionary:
	seed(seed_value)
	var board := BoardModel.new()
	board.setup(level.colors, level.get("mask", []), level.get("weeds", []), seed_value)
	var goals := LevelGoals.new()
	goals.setup(level)
	var guard := 0
	while goals.moves_left > 0 and not goals.is_complete() and guard < max_moves_guard:
		guard += 1
		var mv := choose_move(board, goals)
		if mv.is_empty():
			goals.apply_result({"phases": [board.shuffle()]})
			continue
		var res: Dictionary
		if mv.kind == "swap":
			res = board.try_swap(mv.a, mv.b)
		else:
			res = board.activate_at(mv.a)
		goals.use_move()
		goals.apply_result(res)
	return {"won": goals.is_complete(), "stars": goals.stars(), "moves_left": goals.moves_left, "stats": goals.stats,
		"weeds_left": board.weed_count()}
