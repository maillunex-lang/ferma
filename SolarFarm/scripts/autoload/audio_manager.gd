extends Node
## Music with cross-fade + a small pool of SFX players. Separate "Music" and
## "SFX" buses so volumes can be adjusted independently in Settings.

const SFX_DIR := "res://audio/sfx/"
const MUSIC := {
	"menu": "res://audio/music/menu_theme.ogg",
	"farm": "res://audio/music/farm_theme.ogg",
	"puzzle": "res://audio/music/puzzle_theme.ogg",
}
const POOL_SIZE := 10

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_track := ""
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}
var _last_played := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	for i in POOL_SIZE:
		_pool.append(_make_player("SFX"))
	apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _make_player(bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return p


func apply_volumes() -> void:
	var s: Dictionary = SaveManager.data.get("settings", {})
	_set_bus_volume("Music", float(s.get("music", 0.7)))
	_set_bus_volume("SFX", float(s.get("sfx", 0.9)))


func _set_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.001, 1.0)))


func play_music(track: String) -> void:
	if track == _current_track or not MUSIC.has(track):
		return
	_current_track = track
	var stream: AudioStream = load(MUSIC[track])
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_music_a.stream = stream
	_music_a.volume_db = -30.0
	_music_a.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(_music_a, "volume_db", 0.0, 0.8)
	t.tween_property(_music_b, "volume_db", -40.0, 0.8)
	t.chain().tween_callback(_music_b.stop)


func play(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	# Avoid stacking the same sound many times in one frame (big cascades).
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sfx_name, -1000)) < 40:
		return
	_last_played[sfx_name] = now
	var stream := _get_stream(sfx_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.volume_db = volume_db
			p.play()
			return


func _get_stream(sfx_name: String) -> AudioStream:
	if not _cache.has(sfx_name):
		var path := SFX_DIR + sfx_name + ".ogg"
		_cache[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sfx_name]
