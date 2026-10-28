extends Node
## First-steps tasks and achievements. Rewards (coins / helper charges) are
## claimed manually on the Helpers screen and can be claimed only once.

signal changed

var tasks: Array = []


func _ready() -> void:
	tasks = JSON.parse_string(FileAccess.get_file_as_string("res://data/achievements.json")).tasks


func _store() -> Dictionary:
	return SaveManager.data.achievements


## Adds `amount` to a counter event (match, rocket_created, ...).
func notify(event: String, amount: int = 1, save := false) -> void:
	var p: Dictionary = _store().progress
	p[event] = int(p.get(event, 0)) + amount
	if save:
		SaveManager.save_game()
	changed.emit()


## Sets an absolute value event (stars_total, levels_completed).
func set_value(event: String, value: int, save := false) -> void:
	var p: Dictionary = _store().progress
	p[event] = maxi(int(p.get(event, 0)), value)
	if save:
		SaveManager.save_game()
	changed.emit()


func progress(task: Dictionary) -> int:
	return mini(int(_store().progress.get(task.event, 0)), int(task.target))


func is_done(task: Dictionary) -> bool:
	return progress(task) >= int(task.target)


func is_claimed(task: Dictionary) -> bool:
	return bool(_store().claimed.get(task.id, false))


func claimable_count() -> int:
	var n := 0
	for t in tasks:
		if is_done(t) and not is_claimed(t):
			n += 1
	return n


func claim(id: String) -> Dictionary:
	for t in tasks:
		if t.id != id:
			continue
		if not is_done(t) or is_claimed(t):
			return {}
		_store().claimed[id] = true
		var r: Dictionary = t.reward
		if r.has("coins"):
			EconomyManager.add_coins(int(r.coins), false)
		for h in r.get("helpers", {}):
			HelperManager.add_charges(h, int(r.helpers[h]), false)
		SaveManager.save_game()
		changed.emit()
		return r
	return {}
