extends Node
## Level definitions, progress, deterministic star results and rewards.
## First-clear and three-star rewards are paid exactly once per level.

signal progress_changed

var levels: Array = []
var color_defs: Array = []
var current_level_id := 1
var last_result: Dictionary = {}


func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	levels = d.levels
	color_defs = d.colors


func count() -> int:
	return levels.size()


func get_level(id: int) -> Dictionary:
	for l in levels:
		if int(l.id) == id:
			return l
	return {}


func _rec(id: int) -> Dictionary:
	return SaveManager.data.levels.get(str(id), {})


func is_completed(id: int) -> bool:
	return bool(_rec(id).get("completed", false))


func stars(id: int) -> int:
	return int(_rec(id).get("stars", 0))


func is_unlocked(id: int) -> bool:
	return id == 1 or is_completed(id - 1)


func total_stars() -> int:
	var s := 0
	for l in levels:
		s += stars(int(l.id))
	return s


func completed_count() -> int:
	var n := 0
	for l in levels:
		if is_completed(int(l.id)):
			n += 1
	return n


## Highest unlocked level that is not yet completed (or the last one).
func next_level_id() -> int:
	for l in levels:
		if not is_completed(int(l.id)):
			return int(l.id)
	return int(levels[-1].id)


func color_texture(c: int) -> Texture2D:
	return load(color_defs[c].texture)


func color_tint(c: int) -> Color:
	return Color(color_defs[c].tint) if c >= 0 and c < color_defs.size() else Color.WHITE


## Records a finished attempt and pays rewards. Returns a summary used by
## the result screen. `won`, `stars_earned`, `moves_left` come from LevelGoals.
func record_result(id: int, won: bool, stars_earned: int, moves_left: int) -> Dictionary:
	var level := get_level(id)
	var st: Dictionary = SaveManager.data.stats
	st.games_played = int(st.get("games_played", 0)) + 1
	var res := {"level_id": id, "won": won, "stars": stars_earned, "moves_left": moves_left,
		"coins": 0, "bonus_coins": 0, "helpers": {}, "first_clear": false, "new_three_star": false,
		"unlock": "", "next_unlocked": false, "best_stars": stars(id)}
	if not won:
		SaveManager.save_game()
		last_result = res
		return res
	st.games_won = int(st.get("games_won", 0)) + 1
	var rec: Dictionary = _rec(id).duplicate()
	var reward: Dictionary = level.reward
	var first := not bool(rec.get("completed", false))
	res.first_clear = first
	if first:
		res.coins = int(reward.coins)
		for h in reward.get("helpers", {}):
			res.helpers[h] = int(res.helpers.get(h, 0)) + int(reward.helpers[h])
		if reward.has("unlock"):
			res.unlock = reward.unlock
			FarmProgression.grant_reward_object(reward.unlock)
		res.next_unlocked = id < count()
	else:
		res.coins = int(round(float(reward.coins) * 0.25))  # replay reward
	res.bonus_coins = moves_left * 5
	if stars_earned >= 3 and not bool(rec.get("three_star_claimed", false)):
		rec.three_star_claimed = true
		res.new_three_star = true
		for h in reward.get("three_star", {}):
			res.helpers[h] = int(res.helpers.get(h, 0)) + int(reward.three_star[h])
	rec.completed = true
	rec.stars = maxi(int(rec.get("stars", 0)), stars_earned)
	rec.best_moves_left = maxi(int(rec.get("best_moves_left", 0)), moves_left)
	SaveManager.data.levels[str(id)] = rec
	res.best_stars = rec.stars
	EconomyManager.add_coins(res.coins + res.bonus_coins, false)
	for h in res.helpers:
		HelperManager.add_charges(h, res.helpers[h], false)
	AchievementManager.notify("level_won")
	AchievementManager.set_value("stars_total", total_stars())
	AchievementManager.set_value("levels_completed", completed_count())
	SaveManager.save_game()
	last_result = res
	progress_changed.emit()
	return res
