extends Node
## Helper characters and their charges. Charges never regenerate on a timer:
## they come from level rewards, three-star rewards, tasks and the test shop.

signal charges_changed(helper_id: String, charges: int)

var defs: Dictionary = {}
var order: Array = []
var max_charges := 99


func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/helpers.json"))
	defs = d.helpers
	order = d.order


func charges(id: String) -> int:
	return int(SaveManager.data.helpers.get(id, 0))


func add_charges(id: String, n: int, save := true) -> int:
	if not defs.has(id):
		return 0
	var before := charges(id)
	var after := clampi(before + n, 0, max_charges)
	SaveManager.data.helpers[id] = after
	if save:
		SaveManager.save_game()
	charges_changed.emit(id, after)
	return after - before


## Spends one charge. Returns false (and changes nothing) if empty.
func consume(id: String) -> bool:
	var c := charges(id)
	if c <= 0:
		return false
	SaveManager.data.helpers[id] = c - 1
	SaveManager.save_game()
	charges_changed.emit(id, c - 1)
	AchievementManager.notify("helper_used")
	return true


func icon(id: String) -> Texture2D:
	return load(defs[id].icon)


func title(id: String) -> String:
	return defs[id].name
