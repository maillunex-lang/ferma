extends TestCase
## Local saves: round trip, integrity check, backup recovery, versioning.


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_roundtrip() -> void:
	fresh_profile()
	var sm := autoload("SaveManager")
	sm.data.coins = 1234
	sm.data.levels["1"] = {"completed": true, "stars": 3}
	sm.data.farm.house = 2
	sm.data.settings.music = 0.25
	check(sm.save_game(), "save ok")
	check(not FileAccess.file_exists(sm.save_path + ".tmp"), "no temp file left (atomic write)")
	sm.data = {}
	sm.load_game()
	eq(sm.load_source, "main", "loaded from main file")
	eq(int(sm.data.coins), 1234, "coins")
	eq(int(sm.data.levels["1"].stars), 3, "stars")
	eq(int(sm.data.farm.house), 2, "farm")
	eq(float(sm.data.settings.music), 0.25, "settings")
	eq(int(sm.data.version), sm.SAVE_VERSION, "version stored")


func test_corrupted_main_uses_backup() -> void:
	fresh_profile()
	var sm := autoload("SaveManager")
	sm.data.coins = 500
	sm.save_game()
	sm.data.coins = 777
	sm.save_game()  # backup now holds 500, main holds 777
	_write(sm.save_path, "{this is not json")
	sm.load_game()
	eq(sm.load_source, "backup", "restored from backup")
	eq(int(sm.data.coins), 500, "backup data restored")
	# Main file is rewritten from the backup.
	sm.load_game()
	eq(sm.load_source, "main", "main repaired")


func test_tampered_checksum_rejected() -> void:
	fresh_profile()
	var sm := autoload("SaveManager")
	sm.data.coins = 300
	sm.save_game()
	sm.save_game()
	var outer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sm.save_path))
	outer.payload = str(outer.payload).replace("300", "999999")
	_write(sm.save_path, JSON.stringify(outer))
	sm.load_game()
	check(sm.load_source != "main", "tampered main file rejected")
	eq(int(sm.data.coins), 300, "valid backup used")


func test_both_corrupted_start_fresh() -> void:
	fresh_profile()
	var sm := autoload("SaveManager")
	_write(sm.save_path, "garbage")
	_write(sm.backup_path, "")
	sm.load_game()
	eq(sm.load_source, "new", "fresh profile")
	eq(int(sm.data.coins), 150, "default coins")
	eq(int(sm.data.helpers.rooster), 2, "default helpers")


func test_old_version_migrated_and_missing_keys_filled() -> void:
	fresh_profile()
	var sm := autoload("SaveManager")
	var old := {"version": 0, "coins": 42, "levels": {}}
	var payload := JSON.stringify(old)
	_write(sm.save_path, JSON.stringify({"format": sm.FORMAT, "version": 0, "checksum": payload.sha256_text(), "payload": payload}))
	sm.load_game()
	eq(int(sm.data.coins), 42, "old data kept")
	eq(int(sm.data.version), 1, "migrated to version 1")
	check(sm.data.has("settings") and sm.data.has("helpers") and sm.data.has("farm"), "missing sections filled with defaults")


func test_no_duplicate_rewards_after_reload() -> void:
	fresh_profile()
	var lm := autoload("LevelManager")
	var sm := autoload("SaveManager")
	var hm := autoload("HelperManager")
	var r1: Dictionary = lm.record_result(3, true, 2, 5)
	eq(int(r1.helpers.get("rooster", 0)), 1, "first clear gives rooster charge")
	var coins_after_first: int = int(sm.data.coins)
	var rooster_after_first: int = hm.charges("rooster")
	sm.load_game()  # simulate app restart
	var r2: Dictionary = lm.record_result(3, true, 2, 5)
	check(not r2.first_clear, "second win is not a first clear")
	eq(int(r2.helpers.get("rooster", 0)), 0, "no duplicate helper reward")
	eq(hm.charges("rooster"), rooster_after_first, "charges unchanged")
	eq(int(sm.data.coins), coins_after_first + 35 + 25, "only replay reward (25%) + move bonus")
