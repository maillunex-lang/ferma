extends TestCase
## Match-3 rules: matches, invalid swaps, boosters, combos, cascades,
## shuffling, weeds, helpers and board invariants.

const S := BoardModel.Special


## Base layout without any match: colour(x, y) = (x + 2y) % 6.
func base_rows() -> Array:
	var rows := []
	for y in 8:
		var r := ""
		for x in 8:
			r += str((x + 2 * y) % 6)
		rows.append(r)
	return rows


func board_with(changes: Dictionary, rows: Array = []) -> BoardModel:
	var b := BoardModel.new()
	if rows.is_empty():
		rows = base_rows()
	for p in changes:
		var r: String = rows[p.y]
		rows[p.y] = r.substr(0, p.x) + str(changes[p]) + r.substr(p.x + 1)
	b.load_layout(rows)
	return b


func playable(b: BoardModel) -> int:
	var n := 0
	for x in 8:
		for y in 8:
			if b.is_playable(x, y):
				n += 1
	return n


func cleared_cells(res: Dictionary) -> Array:
	var out := []
	for c in res.phases[0].cleared:
		out.append(c.pos)
	return out


func test_initial_boards_are_clean() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	for level in data.levels:
		for seed_value in 25:
			var b := BoardModel.new()
			b.setup(level.colors, level.mask, level.weeds, seed_value)
			check(b.find_matches().is_empty(), "level %d seed %d starts with a match" % [level.id, seed_value])
			check(b.has_moves(), "level %d seed %d starts without moves" % [level.id, seed_value])
			eq(b.piece_count(), playable(b), "level %d full board" % level.id)


func test_base_layout_has_no_matches() -> void:
	check(board_with({}).find_matches().is_empty(), "base layout must be clean")


func test_simple_match() -> void:
	var b := board_with({Vector2i(0, 3): 1, Vector2i(2, 4): 1})
	check(b.find_matches().is_empty(), "no match before swap")
	var res := b.try_swap(Vector2i(2, 3), Vector2i(2, 4))
	check(res.valid, "swap creating a line of 3 is valid")
	var cells := cleared_cells(res)
	eq(cells.size(), 3, "three pieces cleared")
	for p in [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)]:
		check(cells.has(p), "cleared %s" % p)
	eq(b.piece_count(), 64, "board refilled")
	check(b.find_matches().is_empty(), "no leftover matches after resolution")


func test_invalid_swap_is_reverted() -> void:
	var b := board_with({})
	var before := b.grid.duplicate(true)
	var res := b.try_swap(Vector2i(0, 0), Vector2i(1, 0))
	check(not res.valid, "swap without match is invalid")
	eq(b.grid, before, "board unchanged after invalid swap")
	check(not b.try_swap(Vector2i(0, 0), Vector2i(2, 0)).valid, "non-adjacent swap rejected")
	check(not b.try_swap(Vector2i(0, 0), Vector2i(1, 1)).valid, "diagonal swap rejected")
	check(not b.try_swap(Vector2i(7, 7), Vector2i(8, 7)).valid, "out of bounds rejected")
	eq(b.grid, before, "board still unchanged")


func test_four_in_line_creates_rocket() -> void:
	var b := board_with({Vector2i(0, 3): 1, Vector2i(1, 3): 1, Vector2i(3, 3): 1, Vector2i(2, 4): 1})
	check(b.find_matches().is_empty(), "clean before swap")
	var res := b.try_swap(Vector2i(2, 3), Vector2i(2, 4))
	var created: Array = res.phases[0].created
	eq(created.size(), 1, "one booster created")
	eq(int(created[0].special), S.ROCKET_H, "horizontal four -> horizontal rocket")
	eq(created[0].pos, Vector2i(2, 3), "rocket appears where the piece was moved")


func test_vertical_four_creates_vertical_rocket() -> void:
	var rows := base_rows()
	var b := board_with({Vector2i(3, 0): 0, Vector2i(3, 1): 0, Vector2i(3, 3): 0, Vector2i(4, 2): 0}, rows)
	check(b.find_matches().is_empty(), "clean before swap")
	var res := b.try_swap(Vector2i(3, 2), Vector2i(4, 2))
	check(res.valid, "valid")
	eq(int(res.phases[0].created[0].special), S.ROCKET_V, "vertical four -> vertical rocket")


func test_l_shape_creates_basket() -> void:
	var b := board_with({Vector2i(0, 3): 1, Vector2i(1, 3): 1, Vector2i(2, 4): 1, Vector2i(2, 5): 1, Vector2i(3, 3): 1})
	check(b.find_matches().is_empty(), "clean before swap")
	var res := b.try_swap(Vector2i(2, 3), Vector2i(3, 3))
	check(res.valid, "valid")
	eq(int(res.phases[0].created[0].special), S.BASKET, "L shape -> basket")
	eq(res.phases[0].created[0].pos, Vector2i(2, 3), "basket at the corner")


func test_five_in_line_creates_rainbow() -> void:
	var b := board_with({Vector2i(0, 3): 1, Vector2i(1, 3): 1, Vector2i(3, 3): 1, Vector2i(4, 3): 1, Vector2i(2, 4): 1})
	check(b.find_matches().is_empty(), "clean before swap")
	var res := b.try_swap(Vector2i(2, 3), Vector2i(2, 4))
	eq(int(res.phases[0].created[0].special), S.RAINBOW, "five in line -> rainbow berry")


func test_rocket_clears_row() -> void:
	var b := board_with({Vector2i(3, 4): "R"})
	var res := b.try_swap(Vector2i(3, 4), Vector2i(3, 5))
	check(res.valid, "swapping a booster is always valid")
	var cells := cleared_cells(res)
	for x in 8:
		check(cells.has(Vector2i(x, 5)), "row 5 cell %d cleared by rocket" % x)
	eq(int(res.phases[0].rockets_activated), 1, "rocket activation counted")


func test_tap_activates_booster() -> void:
	var b := board_with({Vector2i(3, 4): "C"})
	var res := b.activate_at(Vector2i(3, 4))
	check(res.valid, "tap on rocket is valid")
	var cells := cleared_cells(res)
	for y in 8:
		check(cells.has(Vector2i(3, y)), "column cell %d cleared" % y)
	check(not b.activate_at(Vector2i(0, 0)).valid or b.piece_at(Vector2i(0, 0)).special != S.NONE, "tap on fruit does nothing")


func test_basket_explodes_5x5() -> void:
	var b := board_with({Vector2i(4, 4): "B"})
	var res := b.activate_at(Vector2i(4, 4))
	var cells := cleared_cells(res)
	eq(cells.size(), 25, "basket clears a 5x5 area")


func test_rainbow_with_fruit_clears_colour() -> void:
	var b := board_with({Vector2i(4, 4): "*"})
	var target_color := b.color_at(5, 4)
	var count := 0
	for x in 8:
		for y in 8:
			if b.color_at(x, y) == target_color:
				count += 1
	var res := b.try_swap(Vector2i(4, 4), Vector2i(5, 4))
	var cleared: Array = res.phases[0].cleared
	var of_color := 0
	for c in cleared:
		if c.color == target_color:
			of_color += 1
	eq(of_color, count, "every piece of the swapped colour removed")


func test_booster_combos() -> void:
	var b := board_with({Vector2i(3, 3): "R", Vector2i(4, 3): "C"})
	var res := b.try_swap(Vector2i(3, 3), Vector2i(4, 3))
	check(res.combo, "two boosters -> combo")
	eq(cleared_cells(res).size(), 15, "rocket + rocket clears a cross (8 + 8 - 1)")
	b = board_with({Vector2i(3, 3): "B", Vector2i(4, 3): "B"})
	res = b.try_swap(Vector2i(3, 3), Vector2i(4, 3))
	eq(cleared_cells(res).size(), 49, "basket + basket clears 7x7")
	b = board_with({Vector2i(3, 3): "*", Vector2i(4, 3): "*"})
	res = b.try_swap(Vector2i(3, 3), Vector2i(4, 3))
	eq(cleared_cells(res).size(), 64, "rainbow + rainbow clears the whole board")
	b = board_with({Vector2i(3, 3): "R", Vector2i(4, 3): "B"})
	res = b.try_swap(Vector2i(3, 3), Vector2i(4, 3))
	eq(cleared_cells(res).size(), 39, "rocket + basket clears 3 rows and 3 columns")
	b = board_with({Vector2i(3, 3): "*", Vector2i(4, 3): "R"})
	res = b.try_swap(Vector2i(3, 3), Vector2i(4, 3))
	check(not res.phases[0].converted.is_empty(), "rainbow + rocket converts pieces into rockets")


func test_chain_reaction_of_boosters() -> void:
	# A rocket in row 2 fires and hits a basket, which must explode as well.
	var b := board_with({Vector2i(0, 2): "R", Vector2i(5, 2): "B"})
	var res := b.activate_at(Vector2i(0, 2))
	var kinds := []
	for e in res.phases[0].effects:
		kinds.append(e.kind)
	check(kinds.has("rocket_h") and kinds.has("blast"), "rocket triggers basket (%s)" % str(kinds))


func test_random_play_invariants() -> void:
	# Many random games: cascades always terminate, board stays full, clean
	# and playable after every move.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for game in 60:
		var b := BoardModel.new()
		b.setup([0, 1, 2, 3, 4, 5] if game % 2 == 0 else [0, 1, 2, 3], [], [], game)
		for move in 30:
			var moves := b.find_possible_moves()
			if moves.is_empty():
				check(false, "no moves after resolution (game %d)" % game)
				break
			var m: Array = moves[rng.randi() % moves.size()]
			var res := b.try_swap(m[0], m[1])
			check(res.valid, "listed move is valid")
			check(res.phases.size() <= BoardModel.MAX_CASCADES + 2, "cascade terminates")
			eq(b.piece_count(), 64, "board full after move")
			check(b.find_matches().is_empty(), "no pending matches after move")
			check(b.has_moves(), "a move always exists after resolution")


func test_shuffle_when_stuck() -> void:
	var rows := ["01230123", "23012301", "01230123", "23012301", "01230123", "23012301", "01230123", "23012301"]
	var b := BoardModel.new()
	b.load_layout(rows, [0, 1, 2, 3])
	check(b.find_matches().is_empty(), "stuck board has no matches")
	check(not b.has_moves(), "stuck board has no moves")
	var colors_before := {}
	for x in 8:
		for y in 8:
			colors_before[b.color_at(x, y)] = colors_before.get(b.color_at(x, y), 0) + 1
	var ph := b.shuffle()
	check(ph.has("shuffle"), "shuffle phase returned")
	check(b.has_moves(), "after shuffle a move exists")
	check(b.find_matches().is_empty(), "after shuffle no ready match")
	eq(b.piece_count(), 64, "no pieces lost")


func test_weed_cleared_by_adjacent_match() -> void:
	var b := board_with({Vector2i(0, 3): 1, Vector2i(2, 4): 1, Vector2i(1, 2): "#"})
	eq(b.weed_count(), 1, "one weed")
	var res := b.try_swap(Vector2i(2, 3), Vector2i(2, 4))
	check(res.valid, "valid")
	eq(b.weed_count(), 0, "weed next to the match is cleared")
	eq(b.piece_count(), 64, "freed cell is refilled")


func test_rocket_hits_weeds_and_pieces_fall_past_weeds() -> void:
	var b := board_with({Vector2i(0, 6): "R", Vector2i(5, 6): "#", Vector2i(3, 4): "#"})
	var res := b.activate_at(Vector2i(0, 6))
	eq(b.weed_count(), 1, "rocket destroys the weed in its row only")
	# Column 3: the cell below the weed at (3,4) was cleared, so the piece above
	# the weed must have fallen through to below it.
	var passed := false
	for m in res.phases[0].moves:
		if m.from.x == 3 and m.from.y < 4 and m.to.y > 4:
			passed = true
	check(passed, "pieces fall past a weed")
	check(b.weeds[3][4] == 1, "weed stays in place")


func test_thick_weed_needs_two_hits() -> void:
	var b := board_with({})
	b.weeds[4][4] = 2
	b.grid[4][4] = null
	b.helper_remove(Vector2i(4, 4))
	eq(b.weeds[4][4], 1, "first hit")
	b.helper_remove(Vector2i(4, 4))
	eq(b.weeds[4][4], 0, "second hit clears")


func test_helpers() -> void:
	var b := board_with({Vector2i(7, 7): "R"})
	var res := b.helper_peck(5)
	var pecked := 0
	for c in res.phases[0].cleared:
		pecked += 1
		check(int(c.special) == S.NONE, "rooster eats only ordinary pieces")
	eq(pecked, 5, "rooster removes five pieces")
	b = board_with({})
	res = b.helper_remove(Vector2i(2, 2))
	eq(res.phases[0].cleared.size(), 1, "squirrel removes one piece")
	b = board_with({})
	res = b.helper_blast(Vector2i(4, 4))
	eq(res.phases[0].cleared.size(), 9, "hedgehog clears 3x3")
	b = board_with({})
	res = b.helper_blast(Vector2i(0, 0))
	eq(res.phases[0].cleared.size(), 4, "hedgehog in a corner clears 2x2")


func test_masked_board() -> void:
	var b := BoardModel.new()
	b.setup([0, 1, 2, 3, 4], [[0, 0], [7, 0], [0, 7], [7, 7]], [], 5)
	eq(b.piece_count(), 60, "holes stay empty")
	check(b.grid[0][0] == null, "corner hole is empty")
	for i in 20:
		var moves := b.find_possible_moves()
		var m: Array = moves[0]
		b.try_swap(m[0], m[1])
		eq(b.piece_count(), 60, "holes never get pieces")
