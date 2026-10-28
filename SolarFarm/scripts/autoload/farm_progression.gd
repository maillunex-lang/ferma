extends Node
## Farm objects and their upgrade levels. Each level has its own artwork so
## every upgrade visibly changes the farm.

signal upgraded(object_id: String, level: int)

var config: Dictionary = {}
var objects: Array = []


func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/farm.json"))
	objects = config.objects


func get_object(id: String) -> Dictionary:
	for o in objects:
		if o.id == id:
			return o
	return {}


func level_of(id: String) -> int:
	return int(SaveManager.data.farm.get(id, 0))


func max_level(id: String) -> int:
	return get_object(id).levels.size() - 1


func is_maxed(id: String) -> bool:
	return level_of(id) >= max_level(id)


func is_unlocked(id: String) -> bool:
	var o := get_object(id)
	var req := int(o.get("requires_level", 0))
	return req <= 0 or LevelManager.is_completed(req)


## Cost of the next upgrade, or -1 if nothing to buy.
func next_cost(id: String) -> int:
	var o := get_object(id)
	if o.kind == "reward" or is_maxed(id):
		return -1
	return int(o.costs[level_of(id)])


func can_upgrade(id: String) -> bool:
	var cost := next_cost(id)
	return cost >= 0 and is_unlocked(id) and EconomyManager.coins() >= cost


## Spends coins and raises the level. Never spends if coins are insufficient.
func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var lvl := level_of(id) + 1
	if not EconomyManager.spend_coins(next_cost(id)):
		return false
	SaveManager.data.farm[id] = lvl
	AchievementManager.notify("farm_upgrade")
	SaveManager.save_game()
	upgraded.emit(id, lvl)
	return true


## Reward objects (festival decor) are granted by levels, not bought.
func grant_reward_object(id: String) -> void:
	if level_of(id) < max_level(id):
		SaveManager.data.farm[id] = max_level(id)
		upgraded.emit(id, max_level(id))


func available_upgrades() -> int:
	var n := 0
	for o in objects:
		if can_upgrade(o.id):
			n += 1
	return n


## 0..1 — how restored the farm is; drives the ground colour.
func progress_ratio() -> float:
	var total := 0
	var have := 0
	for o in objects:
		total += o.levels.size() - 1
		have += level_of(o.id)
	return float(have) / maxf(1.0, float(total))
