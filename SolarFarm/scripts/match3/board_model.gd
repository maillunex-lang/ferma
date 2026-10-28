class_name BoardModel
extends RefCounted
## Pure match-3 logic: no nodes, no rendering. Every player action returns a
## list of "phases" describing what happened (cleared pieces, effects,
## created boosters, gravity moves, spawns) so the view can animate it and
## tests can verify it deterministically.

const W := 8
const H := 8
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## After this many cascade waves inside one move, refills stop producing
## ready-made matches, so chain reactions always terminate.
const ANTI_CASCADE_AFTER := 10
const MAX_CASCADES := 40

enum Special { NONE, ROCKET_H, ROCKET_V, BASKET, RAINBOW }

var grid: Array = []    # grid[x][y] -> piece Dictionary {id, color, special} or null
var active: Array = []  # active[x][y] -> bool, false for holes in shaped boards
var weeds: Array = []   # weeds[x][y] -> remaining hit points of a weed blocker
var ice: Array = []     # ice[x][y] -> ice layer under the piece (melts when the piece is cleared)
var colors: Array = [0, 1, 2, 3, 4, 5]
var rng := RandomNumberGenerator.new()

var _next_id := 1
var _cascade := 0


func setup(level_colors: Array, mask: Array = [], weed_cells: Array = [], seed_value: int = -1, ice_cells: Array = []) -> void:
	colors.clear()
	for c in level_colors:
		colors.append(int(c))
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	grid.clear()
	active.clear()
	weeds.clear()
	ice.clear()
	for x in W:
		grid.append([])
		active.append([])
		weeds.append([])
		ice.append([])
		for y in H:
			grid[x].append(null)
			active[x].append(true)
			weeds[x].append(0)
			ice[x].append(0)
	for c in mask:
		active[int(c[0])][int(c[1])] = false
	for c in weed_cells:
		weeds[int(c[0])][int(c[1])] = int(c[2]) if c.size() > 2 else 1
	for c in ice_cells:
		ice[int(c[0])][int(c[1])] = int(c[2]) if c.size() > 2 else 1
	fill_initial()


func fill_initial() -> void:
	for attempt in 300:
		for y in H:
			for x in W:
				grid[x][y] = _new_piece(_pick_color_no_match(x, y)) if is_playable(x, y) else null
		if find_matches().is_empty() and has_moves():
			return
	push_warning("BoardModel: initial fill fallback")


func clone() -> BoardModel:
	var b := BoardModel.new()
	b.grid = grid.duplicate(true)
	b.active = active.duplicate(true)
	b.weeds = weeds.duplicate(true)
	b.ice = ice.duplicate(true)
	b.colors = colors.duplicate()
	b.rng.seed = rng.seed
	b.rng.state = rng.state
	b._next_id = _next_id
	return b


# ------------------------------------------------------------------ queries

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H


func is_playable(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and active[x][y] and weeds[x][y] == 0


func piece_at(p: Vector2i):
	return grid[p.x][p.y] if in_bounds(p) else null


func color_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return -1
	var p = grid[x][y]
	if p == null or p.special != Special.NONE:
		return -1
	return p.color


func weed_count() -> int:
	var n := 0
	for x in W:
		for y in H:
			if weeds[x][y] > 0:
				n += 1
	return n


func ice_count() -> int:
	var n := 0
	for x in W:
		for y in H:
			if ice[x][y] > 0:
				n += 1
	return n


func piece_count() -> int:
	var n := 0
	for x in W:
		for y in H:
			if grid[x][y] != null:
				n += 1
	return n


## Returns match groups. Each group: {cells, color, max_run, has_h, has_v, runs}
func find_matches() -> Array:
	var runs := []
	for y in H:
		var x := 0
		while x < W:
			var c := color_at(x, y)
			var x2 := x
			if c >= 0:
				while x2 + 1 < W and color_at(x2 + 1, y) == c:
					x2 += 1
				if x2 - x + 1 >= 3:
					var cells: Array[Vector2i] = []
					for i in range(x, x2 + 1):
						cells.append(Vector2i(i, y))
					runs.append({"cells": cells, "h": true, "color": c})
			x = x2 + 1
	for x in W:
		var y := 0
		while y < H:
			var c := color_at(x, y)
			var y2 := y
			if c >= 0:
				while y2 + 1 < H and color_at(x, y2 + 1) == c:
					y2 += 1
				if y2 - y + 1 >= 3:
					var cells: Array[Vector2i] = []
					for i in range(y, y2 + 1):
						cells.append(Vector2i(x, i))
					runs.append({"cells": cells, "h": false, "color": c})
			y = y2 + 1
	# Merge runs that share cells into groups (T / L shapes).
	var groups := []
	for run in runs:
		var merged := {"cells": {}, "color": run.color, "runs": [run]}
		for cell in run.cells:
			merged.cells[cell] = true
		var keep := []
		for g in groups:
			var touches := false
			for cell in run.cells:
				if g.cells.has(cell):
					touches = true
					break
			if touches:
				for cell in g.cells:
					merged.cells[cell] = true
				merged.runs.append_array(g.runs)
			else:
				keep.append(g)
		keep.append(merged)
		groups = keep
	var result := []
	for g in groups:
		var max_run := 0
		var has_h := false
		var has_v := false
		for r in g.runs:
			max_run = maxi(max_run, r.cells.size())
			if r.h:
				has_h = true
			else:
				has_v = true
		var cells: Array[Vector2i] = []
		for c in g.cells:
			cells.append(c)
		result.append({"cells": cells, "color": g.color, "runs": g.runs, "max_run": max_run, "has_h": has_h, "has_v": has_v})
	return result


func special_for_group(g: Dictionary) -> int:
	if g.max_run >= 5:
		return Special.RAINBOW
	if g.has_h and g.has_v:
		return Special.BASKET
	if g.max_run == 4:
		for r in g.runs:
			if r.cells.size() == 4:
				return Special.ROCKET_H if r.h else Special.ROCKET_V
	return Special.NONE


func _creates_match_at(p: Vector2i) -> bool:
	var c := color_at(p.x, p.y)
	if c < 0:
		return false
	var n := 1
	var x := p.x - 1
	while color_at(x, p.y) == c:
		n += 1
		x -= 1
	x = p.x + 1
	while color_at(x, p.y) == c:
		n += 1
		x += 1
	if n >= 3:
		return true
	n = 1
	var y := p.y - 1
	while color_at(p.x, y) == c:
		n += 1
		y -= 1
	y = p.y + 1
	while color_at(p.x, y) == c:
		n += 1
		y += 1
	return n >= 3


func is_valid_swap(a: Vector2i, b: Vector2i) -> bool:
	if not _swappable(a, b):
		return false
	var pa = grid[a.x][a.y]
	var pb = grid[b.x][b.y]
	if pa.special != Special.NONE or pb.special != Special.NONE:
		return true
	_swap_cells(a, b)
	var ok := _creates_match_at(a) or _creates_match_at(b)
	_swap_cells(a, b)
	return ok


func find_possible_moves() -> Array:
	var moves := []
	for x in W:
		for y in H:
			var a := Vector2i(x, y)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b: Vector2i = a + d
				if is_valid_swap(a, b):
					moves.append([a, b])
	return moves


func has_moves() -> bool:
	for x in W:
		for y in H:
			var a := Vector2i(x, y)
			if is_valid_swap(a, a + Vector2i(1, 0)) or is_valid_swap(a, a + Vector2i(0, 1)):
				return true
	return false


# ------------------------------------------------------------------ player actions

## Attempts to swap two neighbouring pieces. Returns {valid, phases, combo}.
## An invalid swap leaves the board untouched.
func try_swap(a: Vector2i, b: Vector2i) -> Dictionary:
	if not _swappable(a, b):
		return {"valid": false, "phases": [], "combo": false}
	var pa: Dictionary = grid[a.x][a.y]
	var pb: Dictionary = grid[b.x][b.y]
	_cascade = 0
	var combo := false
	var phase: Dictionary
	if pa.special != Special.NONE or pb.special != Special.NONE:
		_swap_cells(a, b)  # pa now at b, pb at a
		var forced := []
		if pa.special != Special.NONE and pb.special != Special.NONE:
			combo = true
			forced.append(_combo_activation(pa, b, pb, a))
		elif pa.special == Special.RAINBOW:
			forced.append({"kind": "rainbow", "pos": b, "piece": pa, "target_color": pb.color})
		elif pb.special == Special.RAINBOW:
			forced.append({"kind": "rainbow", "pos": a, "piece": pb, "target_color": pa.color})
		elif pa.special != Special.NONE:
			forced.append({"kind": "special", "pos": b, "piece": pa})
		else:
			forced.append({"kind": "special", "pos": a, "piece": pb})
		phase = _execute([], find_matches(), forced, [a, b])
	else:
		_swap_cells(a, b)
		var groups := find_matches()
		if groups.is_empty():
			_swap_cells(a, b)
			return {"valid": false, "phases": [], "combo": false}
		phase = _execute([], groups, [], [a, b])
	return {"valid": true, "phases": _cascades(phase), "combo": combo}


## Tapping a booster fires it in place (costs a move in the controller).
func activate_at(p: Vector2i) -> Dictionary:
	var piece = piece_at(p)
	if piece == null or piece.special == Special.NONE:
		return {"valid": false, "phases": []}
	_cascade = 0
	var forced := []
	if piece.special == Special.RAINBOW:
		forced.append({"kind": "rainbow", "pos": p, "piece": piece, "target_color": _most_common_color()})
	else:
		forced.append({"kind": "special", "pos": p, "piece": piece})
	return {"valid": true, "phases": _cascades(_execute([], [], forced, []))}


## Helper «Петя-Петушок»: removes up to `count` random ordinary pieces.
func helper_peck(count: int = 5) -> Dictionary:
	var normals := []
	for x in W:
		for y in H:
			var p = grid[x][y]
			if p != null and p.special == Special.NONE:
				normals.append(Vector2i(x, y))
	_shuffle_array(normals)
	var picked: Array[Vector2i] = []
	for i in mini(count, normals.size()):
		picked.append(normals[i])
	if picked.is_empty():
		return {"valid": false, "phases": []}
	_cascade = 0
	var phase := _execute(picked, [], [], [], false)
	phase.effects.append({"kind": "peck", "pos": picked[0], "cells": picked})
	return {"valid": true, "phases": _cascades(phase), "cells": picked}


## Helper «Белка Рыжуля»: removes the selected piece (or damages a weed).
func helper_remove(p: Vector2i) -> Dictionary:
	if not in_bounds(p) or not active[p.x][p.y]:
		return {"valid": false, "phases": []}
	if grid[p.x][p.y] == null and weeds[p.x][p.y] == 0:
		return {"valid": false, "phases": []}
	_cascade = 0
	var cells: Array[Vector2i] = [p]
	var phase := _execute(cells, [], [], [])
	phase.effects.append({"kind": "grab", "pos": p})
	return {"valid": true, "phases": _cascades(phase)}


## Helper «Ёжик Колючка»: 3x3 explosion around the selected cell.
func helper_blast(p: Vector2i) -> Dictionary:
	if not in_bounds(p) or not active[p.x][p.y]:
		return {"valid": false, "phases": []}
	_cascade = 0
	var cells: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := p + Vector2i(dx, dy)
			if in_bounds(c) and active[c.x][c.y]:
				cells.append(c)
	var phase := _execute(cells, [], [], [])
	phase.effects.append({"kind": "blast", "pos": p, "radius": 1})
	return {"valid": true, "phases": _cascades(phase)}


## Rearranges ordinary pieces so that no match is ready and a move exists.
func shuffle() -> Dictionary:
	var cells: Array[Vector2i] = []
	var pieces := []
	for x in W:
		for y in H:
			var p = grid[x][y]
			if p != null and p.special == Special.NONE:
				cells.append(Vector2i(x, y))
				pieces.append(p)
	var before := {}
	for i in cells.size():
		before[pieces[i].id] = cells[i]
	var ok := false
	for attempt in 200:
		_shuffle_array(pieces)
		for i in cells.size():
			grid[cells[i].x][cells[i].y] = pieces[i]
		if find_matches().is_empty() and has_moves():
			ok = true
			break
	if not ok:
		# Recolour ordinary pieces (keeps ids, so the view can animate it).
		for attempt in 200:
			for c in cells:
				grid[c.x][c.y].color = -99
			for c in cells:
				grid[c.x][c.y].color = _pick_color_no_match(c.x, c.y)
			if find_matches().is_empty() and has_moves():
				break
	var moves := []
	for c in cells:
		var p = grid[c.x][c.y]
		moves.append({"id": p.id, "from": before[p.id], "to": c, "color": p.color})
	return {"shuffle": moves}


# ------------------------------------------------------------------ resolution core

func _cascades(first: Dictionary) -> Array:
	var phases := [first]
	while _cascade < MAX_CASCADES:
		var groups := find_matches()
		if groups.is_empty():
			break
		_cascade += 1
		phases.append(_execute([], groups, [], []))
	if not has_moves():
		phases.append(shuffle())
	return phases


func _execute(seed_cells: Array, groups: Array, forced: Array, preferred: Array, seed_hits_weeds: bool = true) -> Dictionary:
	var phase := {
		"cascade": _cascade, "cleared": [], "weeds": [], "ice": [], "effects": [], "created": [], "converted": [],
		"moves": [], "spawns": [], "groups": groups.size(), "rockets_activated": 0,
	}
	var to_clear := {}
	var weed_hits := {}
	var activated := {}
	var reserved := {}
	var creations := []
	var queue := []

	for g in groups:
		for c in g.cells:
			to_clear[c] = true
			for d in DIRS:
				var n: Vector2i = c + d
				if in_bounds(n) and weeds[n.x][n.y] > 0:
					weed_hits[n] = true
		var sp := special_for_group(g)
		if sp != Special.NONE:
			var pos = _creation_pos(g, preferred, reserved)
			if pos != null:
				reserved[pos] = true
				creations.append({"pos": pos, "special": sp, "color": g.color})

	for c in seed_cells:
		if grid[c.x][c.y] != null:
			to_clear[c] = true
		elif seed_hits_weeds and weeds[c.x][c.y] > 0:
			weed_hits[c] = true

	for f in forced:
		queue.append(f)
		to_clear[f.pos] = true
		if f.has("piece"):
			activated[f.piece.id] = true
		if f.has("partner"):
			activated[f.partner.id] = true
			to_clear[f.partner_pos] = true

	for c in to_clear.keys():
		_queue_if_special(c, queue, activated)

	while not queue.is_empty():
		var a: Dictionary = queue.pop_front()
		var res := _activation_cells(a, phase)
		phase.effects.append(res.effect)
		for c in res.cells:
			if weeds[c.x][c.y] > 0:
				weed_hits[c] = true
			elif grid[c.x][c.y] != null and not to_clear.has(c):
				to_clear[c] = true
				_queue_if_special(c, queue, activated)
		for extra in res.get("queue", []):
			queue.append(extra)

	for c in weed_hits:
		weeds[c.x][c.y] -= 1
		phase.weeds.append({"pos": c, "hp": weeds[c.x][c.y]})
	for c in to_clear:
		var p = grid[c.x][c.y]
		if p == null:
			continue
		if ice[c.x][c.y] > 0:
			ice[c.x][c.y] -= 1
			phase.ice.append({"pos": c, "hp": ice[c.x][c.y]})
		phase.cleared.append({"id": p.id, "pos": c, "color": p.color, "special": p.special})
		grid[c.x][c.y] = null
	for cr in creations:
		var np := _new_piece(-1, cr.special)
		grid[cr.pos.x][cr.pos.y] = np
		phase.created.append({"id": np.id, "pos": cr.pos, "special": cr.special, "color": cr.color})
	_gravity(phase)
	return phase


func _queue_if_special(c: Vector2i, queue: Array, activated: Dictionary) -> void:
	var p = grid[c.x][c.y]
	if p == null or p.special == Special.NONE or activated.has(p.id):
		return
	activated[p.id] = true
	if p.special == Special.RAINBOW:
		queue.append({"kind": "rainbow", "pos": c, "piece": p, "target_color": _most_common_color()})
	else:
		queue.append({"kind": "special", "pos": c, "piece": p})


func _activation_cells(a: Dictionary, phase: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	var p: Vector2i = a.pos
	match a.kind:
		"special":
			match int(a.piece.special):
				Special.ROCKET_H:
					phase.rockets_activated += 1
					cells = _row(p.y)
					return {"cells": cells, "effect": {"kind": "rocket_h", "pos": p}}
				Special.ROCKET_V:
					phase.rockets_activated += 1
					cells = _col(p.x)
					return {"cells": cells, "effect": {"kind": "rocket_v", "pos": p}}
				Special.BASKET:
					cells = _square(p, 2)
					return {"cells": cells, "effect": {"kind": "blast", "pos": p, "radius": 2}}
		"rainbow":
			var col: int = a.target_color
			if col < 0:
				col = _most_common_color()
			for x in W:
				for y in H:
					if color_at(x, y) == col:
						cells.append(Vector2i(x, y))
			return {"cells": cells, "effect": {"kind": "rainbow", "pos": p, "targets": cells, "color": col}}
		"cross":
			phase.rockets_activated += 2
			cells = _row(p.y)
			cells.append_array(_col(p.x))
			return {"cells": cells, "effect": {"kind": "cross", "pos": p}}
		"big_cross":
			phase.rockets_activated += 1
			for d in range(-1, 2):
				if p.y + d >= 0 and p.y + d < H:
					cells.append_array(_row(p.y + d))
				if p.x + d >= 0 and p.x + d < W:
					cells.append_array(_col(p.x + d))
			return {"cells": cells, "effect": {"kind": "big_cross", "pos": p}}
		"mega_blast":
			cells = _square(p, 3)
			return {"cells": cells, "effect": {"kind": "blast", "pos": p, "radius": 3}}
		"all":
			for x in W:
				for y in H:
					if active[x][y]:
						cells.append(Vector2i(x, y))
			return {"cells": cells, "effect": {"kind": "rainbow_all", "pos": p}}
		"convert":
			# Rainbow + rocket/basket: every piece of the most common colour turns
			# into that booster and fires.
			var col := _most_common_color()
			var extra := []
			for x in W:
				for y in H:
					if color_at(x, y) == col:
						var piece: Dictionary = grid[x][y]
						var sp: int = a.to_special
						if sp == Special.ROCKET_H or sp == Special.ROCKET_V:
							sp = Special.ROCKET_H if rng.randi() % 2 == 0 else Special.ROCKET_V
						piece.special = sp
						piece.color = -1
						phase.converted.append({"id": piece.id, "pos": Vector2i(x, y), "special": sp})
						cells.append(Vector2i(x, y))
			return {"cells": cells, "effect": {"kind": "rainbow", "pos": p, "targets": cells, "color": col}, "queue": extra}
	return {"cells": cells, "effect": {"kind": "none", "pos": p}}


func _combo_activation(pa: Dictionary, pos_a: Vector2i, pb: Dictionary, pos_b: Vector2i) -> Dictionary:
	var sa: int = pa.special
	var sb: int = pb.special
	var base := {"pos": pos_a, "piece": pa, "partner": pb, "partner_pos": pos_b}
	var is_rocket := func(s: int) -> bool: return s == Special.ROCKET_H or s == Special.ROCKET_V
	if sa == Special.RAINBOW and sb == Special.RAINBOW:
		base.kind = "all"
	elif sa == Special.RAINBOW or sb == Special.RAINBOW:
		var other := sb if sa == Special.RAINBOW else sa
		base.kind = "convert"
		base.to_special = other
	elif is_rocket.call(sa) and is_rocket.call(sb):
		base.kind = "cross"
	elif sa == Special.BASKET and sb == Special.BASKET:
		base.kind = "mega_blast"
	else:
		base.kind = "big_cross"
	return base


func _creation_pos(g: Dictionary, preferred: Array, reserved: Dictionary):
	for p in preferred:
		if g.cells.has(p) and not reserved.has(p):
			return p
	if g.has_h and g.has_v:
		var hcells := {}
		for r in g.runs:
			if r.h:
				for c in r.cells:
					hcells[c] = true
		for r in g.runs:
			if not r.h:
				for c in r.cells:
					if hcells.has(c) and not reserved.has(c):
						return c
	var longest: Array = []
	for r in g.runs:
		if r.cells.size() > longest.size():
			longest = r.cells
	var mid: Vector2i = longest[longest.size() / 2]
	if not reserved.has(mid):
		return mid
	for c in g.cells:
		if not reserved.has(c):
			return c
	return null


func _gravity(phase: Dictionary) -> void:
	for x in W:
		var cells := []
		for y in H:
			if active[x][y] and weeds[x][y] == 0:
				cells.append(y)
		if cells.is_empty():
			continue
		var pieces := []
		for y in cells:
			if grid[x][y] != null:
				pieces.append({"p": grid[x][y], "y": y})
		for y in cells:
			grid[x][y] = null
		var idx := cells.size() - 1
		for i in range(pieces.size() - 1, -1, -1):
			var ty: int = cells[idx]
			var it: Dictionary = pieces[i]
			grid[x][ty] = it.p
			if it.y != ty:
				phase.moves.append({"id": it.p.id, "from": Vector2i(x, it.y), "to": Vector2i(x, ty)})
			idx -= 1
		var empties := idx + 1
		for k in range(idx, -1, -1):
			var y: int = cells[k]
			var color: int
			if _cascade >= ANTI_CASCADE_AFTER:
				color = _pick_color_no_match(x, y)
			else:
				color = colors[rng.randi() % colors.size()]
			var np := _new_piece(color)
			grid[x][y] = np
			phase.spawns.append({"id": np.id, "color": color, "to": Vector2i(x, y), "from_y": cells[0] + k - empties})


# ------------------------------------------------------------------ helpers

func _swappable(a: Vector2i, b: Vector2i) -> bool:
	if not in_bounds(a) or not in_bounds(b):
		return false
	if absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false
	return grid[a.x][a.y] != null and grid[b.x][b.y] != null


func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var t = grid[a.x][a.y]
	grid[a.x][a.y] = grid[b.x][b.y]
	grid[b.x][b.y] = t


func _new_piece(color: int, special: int = Special.NONE) -> Dictionary:
	var p := {"id": _next_id, "color": color, "special": special}
	_next_id += 1
	return p


func _pick_color_no_match(x: int, y: int) -> int:
	var options := []
	for c in colors:
		if color_at(x - 1, y) == c and color_at(x - 2, y) == c:
			continue
		if color_at(x + 1, y) == c and color_at(x + 2, y) == c:
			continue
		if color_at(x - 1, y) == c and color_at(x + 1, y) == c:
			continue
		if color_at(x, y - 1) == c and color_at(x, y - 2) == c:
			continue
		if color_at(x, y + 1) == c and color_at(x, y + 2) == c:
			continue
		if color_at(x, y - 1) == c and color_at(x, y + 1) == c:
			continue
		options.append(c)
	if options.is_empty():
		return colors[rng.randi() % colors.size()]
	return options[rng.randi() % options.size()]


func _most_common_color() -> int:
	var counts := {}
	for x in W:
		for y in H:
			var c := color_at(x, y)
			if c >= 0:
				counts[c] = counts.get(c, 0) + 1
	var best := -1
	var best_n := -1
	for c in counts:
		if counts[c] > best_n:
			best_n = counts[c]
			best = c
	return best


func _row(y: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in W:
		if active[x][y]:
			out.append(Vector2i(x, y))
	return out


func _col(x: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in H:
		if active[x][y]:
			out.append(Vector2i(x, y))
	return out


func _square(p: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var c := p + Vector2i(dx, dy)
			if in_bounds(c) and active[c.x][c.y]:
				out.append(c)
	return out


func _shuffle_array(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


## Debug/test helper: builds a board from rows of colour digits.
## '.' = empty hole, '#' = weed, 'R'/'C'/'B'/'*' = rocket H / rocket V / basket / rainbow.
func load_layout(rows: Array, level_colors: Array = [0, 1, 2, 3, 4, 5], seed_value: int = 1) -> void:
	colors = level_colors.duplicate()
	rng.seed = seed_value
	grid.clear()
	active.clear()
	weeds.clear()
	ice.clear()
	for x in W:
		grid.append([])
		active.append([])
		weeds.append([])
		ice.append([])
		for y in H:
			grid[x].append(null)
			active[x].append(true)
			weeds[x].append(0)
			ice[x].append(0)
	for y in H:
		var row: String = rows[y]
		for x in W:
			var ch := row[x]
			match ch:
				".":
					active[x][y] = false
				"#":
					weeds[x][y] = 1
				"R":
					grid[x][y] = _new_piece(-1, Special.ROCKET_H)
				"C":
					grid[x][y] = _new_piece(-1, Special.ROCKET_V)
				"B":
					grid[x][y] = _new_piece(-1, Special.BASKET)
				"*":
					grid[x][y] = _new_piece(-1, Special.RAINBOW)
				_:
					grid[x][y] = _new_piece(int(ch))
