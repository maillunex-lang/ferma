extends TestCase
## All ten levels: winnable without helpers (bot), rewards, unlocking.

const GAMES := 8


func test_every_level_is_winnable_without_helpers() -> void:
	var levels: Array = autoload("LevelManager").levels
	for level in levels:
		var wins := 0
		var best_stars := 0
		for i in GAMES:
			var r := Match3Bot.play_level(level, 500 + i * 13)
			if r.won:
				wins += 1
				best_stars = maxi(best_stars, r.stars)
		print("    level %d: bot wins %d/%d, best stars %d" % [level.id, wins, GAMES, best_stars])
		check(wins >= GAMES / 2, "level %d must be winnable without helpers (wins %d/%d)" % [level.id, wins, GAMES])
		check(best_stars == 3 or int(level.id) >= 9, "level %d: three stars reachable (best %d)" % [level.id, best_stars])


func test_progression_and_rewards() -> void:
	fresh_profile()
	var lm := autoload("LevelManager")
	var eco := autoload("EconomyManager")
	var hm := autoload("HelperManager")
	var farm := autoload("FarmProgression")
	check(lm.is_unlocked(1), "level 1 open")
	check(not lm.is_unlocked(2), "level 2 locked")
	var coins0: int = eco.coins()
	var lose: Dictionary = lm.record_result(1, false, 0, 0)
	eq(eco.coins(), coins0, "a loss gives nothing")
	check(not lm.is_completed(1), "loss does not complete")
	var r: Dictionary = lm.record_result(1, true, 3, 9)
	eq(int(r.coins), 100, "level 1 pays 100")
	eq(int(r.bonus_coins), 45, "5 coins per remaining move")
	eq(eco.coins(), coins0 + 145, "coins added")
	check(lm.is_unlocked(2), "level 2 unlocked")
	eq(lm.stars(1), 3, "stars saved")
	check(r.new_three_star, "three star reward paid")
	var again: Dictionary = lm.record_result(1, true, 1, 0)
	eq(lm.stars(1), 3, "best stars kept")
	check(not again.new_three_star, "three-star reward not repeated")
	# Helper rewards on first clears of levels 3, 5, 7, 9.
	var expected := {3: "rooster", 5: "squirrel", 7: "hedgehog", 9: "bee"}
	for id in range(2, 11):
		var before: Dictionary = {}
		for h in hm.order:
			before[h] = hm.charges(h)
		var res: Dictionary = lm.record_result(id, true, 1, 0)
		if expected.has(id):
			eq(hm.charges(expected[id]), before[expected[id]] + 1, "level %d gives %s" % [id, expected[id]])
		check(lm.is_unlocked(mini(id + 1, 10)), "next unlocked after %d" % id)
	eq(farm.level_of("festival"), 1, "level 10 unlocks the festival decor")
	eq(lm.completed_count(), 10, "all levels completed")
	eq(int(autoload("AchievementManager")._store().progress.levels_completed), 10, "achievement progress updated")
	check(farm.is_unlocked("windmill") and farm.is_unlocked("pen"), "expansion plots unlocked")
