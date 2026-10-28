extends Node
## Local, offline persistence.
##
## File layout (user://save.json):
##   {"format": "solar_farm_save", "version": N, "checksum": sha256(payload), "payload": "<json>"}
## Writes are atomic (temp file + rename) and the previous good file is kept
## as user://save_backup.json. On load, a corrupted or tampered main file
## falls back to the backup, and then to a fresh profile.

signal saved
signal loaded(source: String)

const SAVE_VERSION := 1
const FORMAT := "solar_farm_save"

var save_path := "user://save.json"
var backup_path := "user://save_backup.json"
var data: Dictionary = {}
## Where the current data came from: "main", "backup", "new".
var load_source := "new"


func _ready() -> void:
	load_game()


func default_data() -> Dictionary:
	var helpers := {}
	var hdef: Dictionary = _read_json("res://data/helpers.json")
	for id in hdef.get("helpers", {}):
		helpers[id] = int(hdef.helpers[id].start)
	var farm := {}
	var fdef: Dictionary = _read_json("res://data/farm.json")
	for o in fdef.get("objects", []):
		farm[o.id] = 0
	return {
		"version": SAVE_VERSION,
		"coins": int(fdef.get("start_coins", 150)),
		"levels": {},
		"helpers": helpers,
		"farm": farm,
		"settings": {"music": 0.7, "sfx": 0.9, "effects": "high", "fps": 60, "hints": true},
		"achievements": {"progress": {}, "claimed": {}},
		"tutorial": {},
		"stats": {"games_played": 0, "games_won": 0, "test_purchases": 0},
		"purchase_log": [],
	}


func load_game() -> void:
	var main := _read_save(save_path)
	if not main.is_empty():
		data = _migrate(main)
		load_source = "main"
	else:
		var backup := _read_save(backup_path)
		if not backup.is_empty():
			data = _migrate(backup)
			load_source = "backup"
			push_warning("SaveManager: main save damaged, restored from backup")
			_write_file(save_path, _wrap(data))
		else:
			data = default_data()
			load_source = "new"
	_fill_missing(data, default_data())
	loaded.emit(load_source)


func save_game() -> bool:
	data.version = SAVE_VERSION
	var text := _wrap(data)
	# Keep the last good file as backup before replacing it.
	if FileAccess.file_exists(save_path) and not _read_save(save_path).is_empty():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup_path))
	var ok := _write_file(save_path, text)
	if ok and not FileAccess.file_exists(backup_path):
		_write_file(backup_path, text)
	saved.emit()
	return ok


func reset_progress() -> void:
	var settings: Dictionary = data.get("settings", {}).duplicate(true)
	data = default_data()
	if not settings.is_empty():
		data.settings = settings
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	save_game()


# ------------------------------------------------------------------ internals

func _wrap(d: Dictionary) -> String:
	var payload := JSON.stringify(d)
	return JSON.stringify({"format": FORMAT, "version": SAVE_VERSION, "checksum": payload.sha256_text(), "payload": payload})


## Returns the payload dictionary, or {} if missing / corrupted / tampered.
func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var outer = JSON.parse_string(text)
	if typeof(outer) != TYPE_DICTIONARY or outer.get("format", "") != FORMAT:
		return {}
	var payload = outer.get("payload", null)
	if typeof(payload) != TYPE_STRING or payload.sha256_text() != outer.get("checksum", ""):
		return {}
	var inner = JSON.parse_string(payload)
	if typeof(inner) != TYPE_DICTIONARY:
		return {}
	return inner


func _write_file(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s" % tmp)
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	return err == OK


## Upgrades older save formats. Version 1 is the first public format; future
## versions add their conversion steps here.
func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v < 1:
		d.version = 1
	return d


func _fill_missing(target: Dictionary, defaults: Dictionary) -> void:
	for k in defaults:
		if not target.has(k):
			target[k] = defaults[k]
		elif typeof(defaults[k]) == TYPE_DICTIONARY and typeof(target[k]) == TYPE_DICTIONARY:
			_fill_missing(target[k], defaults[k])


func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
