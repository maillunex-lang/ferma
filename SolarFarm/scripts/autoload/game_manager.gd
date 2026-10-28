extends Node
## Scene routing with fade transitions, global overlay (toasts, dialogs),
## Android back button, app pause/resume handling and global settings.

const SCENES := {
	"menu": "res://scenes/MainMenu.tscn",
	"farm": "res://scenes/Farm.tscn",
	"map": "res://scenes/LevelMap.tscn",
	"puzzle": "res://scenes/Match3Board.tscn",
	"result": "res://scenes/LevelResult.tscn",
	"helpers": "res://scenes/HelperSelection.tscn",
	"shop": "res://scenes/Shop.tscn",
	"settings": "res://scenes/Settings.tscn",
}

signal scene_changed(scene_name: String)

var current_scene_name := "menu"
var previous_scene_name := "menu"
var overlay: CanvasLayer
var _fade: ColorRect
var _toast_box: VBoxContainer
var _busy := false
var _dialog: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_quit_on_go_back(false)
	get_tree().set_auto_accept_quit(false)
	get_tree().root.theme = UIKit.make_theme()
	overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	_fade = ColorRect.new()
	_fade.color = Color(1.0, 0.96, 0.85, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_fade)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast_box.offset_top = 90
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	overlay.add_child(_toast_box)
	apply_settings()
	var cur := get_tree().current_scene
	if cur:
		for k in SCENES:
			if SCENES[k] == cur.scene_file_path:
				current_scene_name = k


func apply_settings() -> void:
	var s: Dictionary = SaveManager.data.settings
	Engine.max_fps = int(s.get("fps", 60))
	AudioManager.apply_volumes()


func effects_high() -> bool:
	return str(SaveManager.data.settings.get("effects", "high")) == "high"


func goto(scene_name: String) -> void:
	if _busy or not SCENES.has(scene_name):
		return
	_busy = true
	close_dialog()
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.18)
	await t.finished
	previous_scene_name = current_scene_name
	current_scene_name = scene_name
	get_tree().change_scene_to_file(SCENES[scene_name])
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.22)
	_busy = false
	scene_changed.emit(scene_name)


func play_level(id: int) -> void:
	LevelManager.current_level_id = id
	goto("puzzle")


func go_back() -> void:
	if _dialog != null:
		close_dialog()
		return
	var scene := get_tree().current_scene
	if scene and scene.has_method("on_back"):
		scene.on_back()
	elif current_scene_name == "menu":
		confirm_exit()
	else:
		goto("menu")


func confirm_exit() -> void:
	show_dialog("Выйти из игры?", "Весь прогресс сохранён на устройстве.", [
		{"text": "Остаться", "color": UIKit.C_GREEN},
		{"text": "Выйти", "color": UIKit.C_CORAL, "callback": func(): get_tree().quit()},
	])


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			SaveManager.save_game()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			SaveManager.save_game()
			var scene := get_tree().current_scene if is_inside_tree() else null
			if scene and scene.has_method("on_app_paused"):
				scene.on_app_paused()


## Safe-area margins (status bar, notches, gesture bar) in viewport units.
func safe_margins() -> Dictionary:
	var m := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if not OS.has_feature("mobile"):
		return m
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := DisplayServer.get_display_safe_area()
	var vp := get_viewport().get_visible_rect().size
	if screen.x <= 0 or screen.y <= 0:
		return m
	var k := vp.y / screen.y
	m.top = safe.position.y * k
	m.bottom = maxf(0.0, (screen.y - safe.end.y) * k)
	m.left = safe.position.x * k
	m.right = maxf(0.0, (screen.x - safe.end.x) * k)
	return m


# ------------------------------------------------------------------ toasts & dialogs

func toast(text: String, color: Color = UIKit.C_GREEN, icon: Texture2D = null) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.style(color, 30, 4, color.darkened(0.3), 8))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	if icon:
		hb.add_child(UIKit.icon(icon, 44))
	var l := UIKit.label(text, 28, Color.WHITE, 6, color.darkened(0.45))
	hb.add_child(l)
	_toast_box.add_child(p)
	p.modulate.a = 0.0
	p.pivot_offset = Vector2(200, 30)
	var t := p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.8)
	t.tween_property(p, "modulate:a", 0.0, 0.35)
	t.tween_callback(p.queue_free)


## Modal dialog. buttons: [{text, color, callback?}]
func show_dialog(title: String, text: String, buttons: Array, content: Control = null) -> Control:
	close_dialog()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := UIKit.card(UIKit.C_CREAM)
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	panel.add_child(vb)
	var tl := UIKit.title_label(title, 40)
	vb.add_child(tl)
	if text != "":
		var l := UIKit.label(text, 28, UIKit.C_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 540
		vb.add_child(l)
	if content:
		vb.add_child(content)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	vb.add_child(hb)
	for b in buttons:
		var btn := UIKit.button(b.text, b.get("color", UIKit.C_GREEN), Vector2(250, 90), 30)
		var cb: Callable = b.get("callback", Callable())
		btn.pressed.connect(func():
			close_dialog()
			if cb.is_valid():
				cb.call())
		hb.add_child(btn)
	overlay.add_child(root)
	overlay.move_child(root, overlay.get_child_count() - 2)  # keep toasts on top
	panel.pivot_offset = Vector2(300, 150)
	UIKit.pop_in(panel)
	_dialog = root
	return root


func close_dialog() -> void:
	if _dialog and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func has_dialog() -> bool:
	return _dialog != null and is_instance_valid(_dialog)
