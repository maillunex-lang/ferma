class_name LevelGoals
extends RefCounted
## Tracks level objectives, move limit, statistics and the deterministic star
## rating. Fed with the phases produced by BoardModel.

signal changed

var level: Dictionary
var goals: Array = []        # {type, colors, target, current}
var moves_total := 0
var moves_left := 0
var helpers_used := 0
var stats := {
	"specials_created": 0, "rockets_created": 0, "baskets_created": 0, "rainbows_created": 0,
	"rockets_activated": 0, "max_cascade": 0, "booster_combos": 0, "matches": 0, "weeds_cleared": 0, "ice_cleared": 0,
}


func setup(level_data: Dictionary) -> void:
	level = level_data
	goals.clear()
	for g in level_data.goals:
		var cols := []
		for c in g.get("colors", []):
			cols.append(int(c))
		goals.append({"type": g.type, "colors": cols, "target": int(g.target), "current": 0})
	moves_total = int(level_data.moves)
	moves_left = moves_total


func use_move() -> void:
	moves_left = maxi(0, moves_left - 1)
	changed.emit()


func add_moves(n: int) -> void:
	moves_left += n
	changed.emit()


func note_helper_used() -> void:
	helpers_used += 1


func apply_result(result: Dictionary) -> void:
	for ph in result.get("phases", []):
		if not ph.has("shuffle"):
			apply_phase(ph)
	finish_result(result)


## Per-move statistics (cascade depth, booster combos). Call once per move
## after its phases were applied with apply_phase().
func finish_result(result: Dictionary) -> void:
	if result.get("combo", false):
		stats.booster_combos += 1
	var waves := 0
	for ph in result.get("phases", []):
		if not ph.has("shuffle"):
			waves += 1
	stats.max_cascade = maxi(stats.max_cascade, waves)
	changed.emit()


func apply_phase(ph: Dictionary) -> void:
	stats.matches += int(ph.get("groups", 0))
	stats.rockets_activated += int(ph.get("rockets_activated", 0))
	for c in ph.get("cleared", []):
		if int(c.color) < 0:
			continue
		for g in goals:
			if g.type == "collect" and g.colors.has(c.color):
				g.current += 1
	for w in ph.get("weeds", []):
		if w.hp <= 0:
			stats.weeds_cleared += 1
	for i in ph.get("ice", []):
		if i.hp <= 0:
			stats.ice_cleared += 1
	for cr in ph.get("created", []):
		stats.specials_created += 1
		match int(cr.special):
			BoardModel.Special.ROCKET_H, BoardModel.Special.ROCKET_V:
				stats.rockets_created += 1
			BoardModel.Special.BASKET:
				stats.baskets_created += 1
			BoardModel.Special.RAINBOW:
				stats.rainbows_created += 1
	for g in goals:
		match g.type:
			"weeds":
				g.current = stats.weeds_cleared
			"ice":
				g.current = stats.ice_cleared
			"rockets":
				g.current = stats.rockets_activated
			"rainbow":
				g.current = stats.rainbows_created


func goal_remaining(i: int) -> int:
	return maxi(0, goals[i].target - goals[i].current)


func is_complete() -> bool:
	for g in goals:
		if g.current < g.target:
			return false
	return true


func is_failed() -> bool:
	return moves_left <= 0 and not is_complete()


func extra_done() -> bool:
	var extra: Dictionary = level.stars.extra
	var target := int(extra.get("target", 0))
	match extra.type:
		"no_helpers":
			return helpers_used == 0
		"specials_created":
			return stats.specials_created >= target
		"rockets_created":
			return stats.rockets_created >= target
		"baskets_created":
			return stats.baskets_created >= target
		"cascade":
			return stats.max_cascade >= target
		"booster_combo":
			return stats.booster_combos >= target
	return false


## 1 star: goals done; 2: with a reserve of moves; 3: bigger reserve AND the
## level's extra condition. Purely a function of the result — never random.
func stars() -> int:
	if not is_complete():
		return 0
	var s := 1
	if moves_left >= int(level.stars.two):
		s = 2
	if moves_left >= int(level.stars.three) and extra_done():
		s = 3
	return s


## Goal types that the remaining board cells still contribute to (used by the
## bot and by the hint system to prefer useful moves).
func wanted_colors() -> Array:
	var out := []
	for g in goals:
		if g.type == "collect" and g.current < g.target:
			for c in g.colors:
				if not out.has(c):
					out.append(c)
	return out


func needs(type: String) -> bool:
	for g in goals:
		if g.type == type and g.current < g.target:
			return true
	return false
