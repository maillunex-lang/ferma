extends TestCase
## Every referenced resource exists; scenes load; no networking code.


func _files(dir: String, exts: Array) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if exts.has(f.get_extension()):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		out.append_array(_files(dir.path_join(sub), exts))
	return out


func test_referenced_paths_exist() -> void:
	var re := RegEx.new()
	re.compile("res://[A-Za-z0-9_./-]+\\.(gdshader|png|ogg|tscn|gd|json|ttf)")
	var missing := []
	var n := 0
	for f in _files("res://scripts", ["gd"]) + _files("res://data", ["json"]) + _files("res://scenes", ["tscn"]) + ["res://project.godot"]:
		var text := FileAccess.get_file_as_string(f)
		for m in re.search_all(text):
			var p := m.get_string()
			n += 1
			if not ResourceLoader.exists(p) and not FileAccess.file_exists(p):
				missing.append("%s -> %s" % [f, p])
	check(n > 50, "found resource references (%d)" % n)
	eq(missing, [], "missing resources")


func test_formatted_paths_exist() -> void:
	# Paths assembled at runtime from data.
	for i in 4:
		check(ResourceLoader.exists("res://assets/farm/house_%d.png" % i), "house %d" % i)
	for name in ["prop_tree", "prop_bush", "prop_bush_flowers", "prop_rock", "prop_flowers", "prop_grass", "prop_sign",
			"animal_chicken", "animal_duck", "animal_cow", "animal_sheep", "animal_pig"]:
		check(ResourceLoader.exists("res://assets/farm/%s.png" % name), name)
	for i in 3:
		check(ResourceLoader.exists("res://assets/farm/fence_%d.png" % i), "fence %d" % i)
	for icon in ["music", "sound", "pause", "home", "back", "close", "check", "lock", "gear", "shop", "hammer", "map", "paw", "play", "refresh"]:
		check(ResourceLoader.exists("res://assets/ui/icon_%s.png" % icon), "icon " + icon)


func test_sound_names_exist() -> void:
	var re := RegEx.new()
	re.compile("AudioManager\\.play\\(\"([a-z_]+)\"")
	var names := {}
	for f in _files("res://scripts", ["gd"]):
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			names[m.get_string(1)] = true
	var helpers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/helpers.json")).helpers
	for h in helpers:
		names[helpers[h].sfx] = true
	check(names.size() > 15, "sound names collected (%d)" % names.size())
	for n in names:
		check(ResourceLoader.exists("res://audio/sfx/%s.ogg" % n), "sound %s exists" % n)
	for track in ["menu_theme", "farm_theme", "puzzle_theme"]:
		check(ResourceLoader.exists("res://audio/music/%s.ogg" % track), "music " + track)


func test_scenes_instantiate() -> void:
	for f in _files("res://scenes", ["tscn"]):
		var ps: PackedScene = load(f)
		check(ps != null, "scene loads: " + f)
		check(ps.can_instantiate(), "scene instantiable: " + f)
	for s in ["MainMenu", "Farm", "LevelMap", "Match3Board", "LevelResult", "HelperSelection", "Shop", "Settings"]:
		check(FileAccess.file_exists("res://scenes/%s.tscn" % s), "required scene " + s)


func test_no_network_code() -> void:
	var banned := ["HTTPRequest", "HTTPClient", "StreamPeerTCP", "WebSocketPeer", "PacketPeerUDP", "ENetMultiplayerPeer", "OS.shell_open", "JavaScriptBridge"]
	for f in _files("res://scripts", ["gd"]):
		var text := FileAccess.get_file_as_string(f)
		for b in banned:
			check(not text.contains(b), "%s uses %s" % [f, b])


func test_level_data_matches_spec() -> void:
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json")).levels
	eq(levels.size(), 10, "ten hand-made levels")
	var moves := [20, 22, 23, 22, 25, 25, 26, 28, 28, 32]
	var coins := [100, 120, 140, 160, 180, 200, 220, 250, 280, 500]
	for i in 10:
		eq(int(levels[i].moves), moves[i], "level %d moves" % (i + 1))
		eq(int(levels[i].reward.coins), coins[i], "level %d coins" % (i + 1))


func test_all_500_levels_valid() -> void:
	var lm := autoload("LevelManager")
	eq(lm.count(), 500, "500 levels in total")
	var shapes := {}
	for id in range(1, 501):
		var lv: Dictionary = lm.get_level(id)
		check(not lv.is_empty(), "level %d exists" % id)
		if lv.is_empty():
			continue
		check(int(lv.moves) >= 12 and int(lv.moves) <= 50, "level %d moves in range (%d)" % [id, int(lv.moves)])
		check(lv.goals.size() >= 1 and lv.goals.size() <= 6, "level %d has goals" % id)
		check(lv.colors.size() >= 4, "level %d colours" % id)
		check(int(lv.stars.three) > int(lv.stars.two), "level %d star thresholds" % id)
		var active: int = 64 - lv.mask.size()
		check(active >= 40, "level %d playable area (%d)" % [id, active])
		shapes[str(lv.mask)] = true
		var masked := {}
		for c in lv.mask:
			masked[Vector2i(c[0], c[1])] = true
		for c in lv.weeds + lv.get("ice", []):
			check(not masked.has(Vector2i(c[0], c[1])), "level %d obstacle on a hole" % id)
		for g in lv.goals:
			if g.type == "weeds":
				eq(int(g.target), lv.weeds.size(), "level %d weed goal" % id)
			if g.type == "ice":
				eq(int(g.target), lv.get("ice", []).size(), "level %d ice goal" % id)
	check(shapes.size() >= 15, "many different board shapes (%d)" % shapes.size())
