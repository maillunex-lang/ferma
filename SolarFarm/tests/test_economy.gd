extends TestCase
## Coins, helper charges, free test purchases, farm upgrades, tasks.


func test_coins() -> void:
	fresh_profile()
	var eco := autoload("EconomyManager")
	var start: int = eco.coins()
	check(not eco.spend_coins(start + 1), "cannot spend more than balance")
	eq(eco.coins(), start, "balance unchanged after failed spend")
	check(eco.spend_coins(50), "spend ok")
	eq(eco.coins(), start - 50, "balance reduced")
	check(not eco.spend_coins(-5), "negative spend rejected")
	eco.add_coins(-10000)
	eq(eco.coins(), 0, "balance never negative")


func test_helper_charges() -> void:
	fresh_profile()
	var hm := autoload("HelperManager")
	eq(hm.charges("rooster"), 2, "rooster starts with 2")
	eq(hm.charges("squirrel"), 2, "squirrel starts with 2")
	eq(hm.charges("hedgehog"), 1, "hedgehog starts with 1")
	eq(hm.charges("bee"), 1, "bee starts with 1")
	check(hm.consume("bee"), "consume bee")
	eq(hm.charges("bee"), 0, "one charge spent")
	check(not hm.consume("bee"), "cannot consume empty helper")
	eq(hm.charges("bee"), 0, "never negative")
	hm.add_charges("rooster", 500)
	eq(hm.charges("rooster"), 99, "capped at 99")


func test_free_purchase_and_double_tap() -> void:
	fresh_profile()
	var eco := autoload("EconomyManager")
	var hm := autoload("HelperManager")
	var before: int = hm.charges("squirrel")
	check(eco.provider.is_test_mode(), "test provider active")
	check(eco.purchase("pack_squirrel"), "purchase started")
	check(not eco.purchase("pack_squirrel"), "second tap while pending is ignored")
	check(not eco.purchase("pack_squirrel"), "third tap ignored")
	await tree.process_frame
	await tree.process_frame
	eq(hm.charges("squirrel"), before + 3, "exactly one grant of 3 charges")
	check(eco.purchase("pack_squirrel"), "next purchase allowed after completion")
	await tree.process_frame
	await tree.process_frame
	eq(hm.charges("squirrel"), before + 6, "second grant")
	# persisted
	autoload("SaveManager").load_game()
	eq(hm.charges("squirrel"), before + 6, "charges saved locally")
	eq(int(autoload("SaveManager").data.stats.test_purchases), 2, "purchases logged")


func test_purchase_cap() -> void:
	fresh_profile()
	var eco := autoload("EconomyManager")
	var hm := autoload("HelperManager")
	hm.add_charges("bee", 97)
	eq(hm.charges("bee"), 98, "98 bees")
	eco.purchase("pack_bee")
	await tree.process_frame
	await tree.process_frame
	eq(hm.charges("bee"), 99, "capped at 99")
	eq(eco.can_purchase("pack_bee").reason, "max", "maxed product reports max")
	check(not eco.purchase("pack_bee"), "cannot buy maxed product")
	check(eco.can_purchase("pack_bundle").ok, "bundle still available (other helpers not maxed)")
	eco.purchase("pack_bundle")
	await tree.process_frame
	await tree.process_frame
	eq(hm.charges("bee"), 99, "bundle respects cap")
	eq(hm.charges("rooster"), 4, "bundle adds 2 rooster")


func test_farm_upgrades() -> void:
	fresh_profile()
	var farm := autoload("FarmProgression")
	var eco := autoload("EconomyManager")
	eco.add_coins(-10000)
	check(not farm.upgrade("house"), "no upgrade without coins")
	eq(farm.level_of("house"), 0, "house unchanged")
	eco.add_coins(100)
	check(farm.upgrade("house"), "upgrade with enough coins")
	eq(farm.level_of("house"), 1, "house level 1")
	eq(eco.coins(), 0, "cost deducted")
	eco.add_coins(10000)
	check(not farm.upgrade("windmill"), "locked plot (needs level 6) cannot be built")
	check(not farm.upgrade("festival"), "reward decor is not for sale")
	for i in 5:
		farm.upgrade("house")
	eq(farm.level_of("house"), 3, "house maxes out at level 3")
	eq(farm.next_cost("house"), -1, "no cost when maxed")
	autoload("SaveManager").load_game()
	eq(farm.level_of("house"), 3, "farm state saved")


func test_tasks_claim_once() -> void:
	fresh_profile()
	var am := autoload("AchievementManager")
	var hm := autoload("HelperManager")
	var before: int = hm.charges("rooster")
	check(am.claim("first_match").is_empty(), "cannot claim unfinished task")
	am.notify("match", 1)
	eq(am.claimable_count(), 1, "one claimable")
	check(not am.claim("first_match").is_empty(), "claim ok")
	check(am.claim("first_match").is_empty(), "second claim rejected")
	eq(hm.charges("rooster"), before + 1, "reward given once")
