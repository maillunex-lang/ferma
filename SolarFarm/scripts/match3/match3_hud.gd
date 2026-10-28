class_name Match3Hud
extends Control
## Puzzle HUD: level number, goals, moves (top) and helpers + pause (bottom).

signal helper_pressed(helper_id: String)
signal pause_pressed

var goals: LevelGoals
var level: Dictionary
var top_panel: PanelContainer
var bottom_bar: HBoxContainer
var _goal_items: Array = []
var _moves_label: Label
var _moves_bubble: PanelContainer
var _helper_buttons := {}
var _star_label: Label
var _moves_pulse: Tween
var _bottom_offset := 168.0


func build(level_data: Dictionary, g: LevelGoals, safe: Dictionary) -> void:
	level = level_data
	goals = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	top_panel = UIKit.card(Color(1, 0.98, 0.92, 0.95), 34)
	top_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(top_panel)
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 16
	top_panel.offset_right = -16
	top_panel.offset_top = 10 + safe.top
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	top_panel.add_child(vb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var lvl_box := VBoxContainer.new()
	lvl_box.add_theme_constant_override("separation", -6)
	lvl_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lvl_box)
	lvl_box.add_child(UIKit.label("Уровень %d" % int(level.id), 34, UIKit.C_ORANGE.darkened(0.2), 0))
	var name_l := UIKit.label(level.name, 24, UIKit.C_TEXT)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size.x = 150
	lvl_box.add_child(name_l)
	var goals_box := HBoxContainer.new()
	goals_box.add_theme_constant_override("separation", 8)
	goals_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(goals_box)
	var compact := goals.goals.size() > 3
	goals_box.add_theme_constant_override("separation", 2 if compact else 8)
	for i in goals.goals.size():
		goals_box.add_child(_make_goal(i, compact))
	_moves_bubble = PanelContainer.new()
	var ms := UIKit.style(UIKit.C_SKY, 60, 5, Color.WHITE, 6)
	ms.content_margin_left = 10
	ms.content_margin_right = 10
	ms.content_margin_top = 4
	ms.content_margin_bottom = 6
	_moves_bubble.add_theme_stylebox_override("panel", ms)
	_moves_bubble.custom_minimum_size = Vector2(112, 112)
	row.add_child(_moves_bubble)
	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_theme_constant_override("separation", -10)
	_moves_bubble.add_child(mv)
	_moves_label = UIKit.title_label(str(goals.moves_left), 50, UIKit.C_SKY.darkened(0.45))
	mv.add_child(_moves_label)
	var ml := UIKit.label("ходов", 20, Color.WHITE)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(ml)
	_star_label = UIKit.label("", 21, UIKit.C_TEXT.lightened(0.15))
	_star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_star_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_star_label)

	bottom_bar = HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 12)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_bar)
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -168 - safe.bottom
	bottom_bar.offset_bottom = -14 - safe.bottom
	_bottom_offset = 168 + safe.bottom
	for h in HelperManager.order:
		var b := _make_helper_button(h)
		bottom_bar.add_child(b)
		_helper_buttons[h] = b
	var pause := UIKit.round_button(load("res://assets/ui/icon_pause.png"), UIKit.C_CORAL, 104)
	pause.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause.pressed.connect(func(): pause_pressed.emit())
	bottom_bar.add_child(pause)
	refresh()
	HelperManager.charges_changed.connect(func(_id, _c): refresh_helpers())


func top_height() -> float:
	return top_panel.offset_top + top_panel.get_combined_minimum_size().y + 10


func bottom_height() -> float:
	return _bottom_offset + 4


func _make_goal(i: int, compact := false) -> Control:
	var g: Dictionary = goals.goals[i]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	var holder := Control.new()
	var isz := 50.0 if compact else 66.0
	holder.custom_minimum_size = Vector2(isz + 4, isz)
	box.add_child(holder)
	var texs: Array = []
	match g.type:
		"collect":
			for c in g.colors:
				texs.append(LevelManager.color_texture(c))
		"weeds":
			texs.append(load("res://assets/tiles/weed.png"))
		"ice":
			texs.append(load("res://assets/tiles/ice_1.png"))
		"rockets":
			texs.append(load("res://assets/tiles/rocket.png"))
		"rainbow":
			texs.append(load("res://assets/tiles/rainbow.png"))
	for k in texs.size():
		var ic := UIKit.icon(texs[k], isz if texs.size() == 1 else isz * 0.76)
		ic.position = Vector2(2 + k * isz * 0.27, k * isz * 0.2)
		holder.add_child(ic)
	var check := UIKit.icon(load("res://assets/ui/icon_check.png"), 34)
	check.modulate = UIKit.C_GREEN
	check.position = Vector2(isz - 26, isz - 32)
	check.visible = false
	holder.add_child(check)
	var l := UIKit.label("", 22 if compact else 26, UIKit.C_TEXT, 6, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	_goal_items.append({"label": l, "check": check, "box": box, "done": false})
	return box


func goal_icon_global_pos(i: int) -> Vector2:
	var box: Control = _goal_items[i].box
	return box.global_position + Vector2(35, 30)


func moves_global_pos() -> Vector2:
	return _moves_bubble.global_position + _moves_bubble.size / 2


func helper_global_pos(id: String) -> Vector2:
	var b: Control = _helper_buttons[id]
	return b.global_position + b.size / 2


func refresh() -> void:
	for i in _goal_items.size():
		var item: Dictionary = _goal_items[i]
		var rem := goals.goal_remaining(i)
		item.label.text = str(rem) if rem > 0 else ""
		if rem == 0 and not item.done:
			item.done = true
			item.check.visible = true
			item.check.pivot_offset = Vector2(17, 17)
			UIKit.pop_in(item.check)
			AudioManager.play("star", 1.2)
	_moves_label.text = str(goals.moves_left)
	if goals.moves_left <= 5 and _moves_pulse == null:
		_moves_bubble.pivot_offset = _moves_bubble.size / 2
		var st: StyleBoxFlat = _moves_bubble.get_theme_stylebox("panel")
		st.bg_color = UIKit.C_CORAL
		_moves_pulse = UIKit.pulse(_moves_bubble, 0.08, 0.7)
	elif goals.moves_left > 5 and _moves_pulse != null:
		_moves_pulse.kill()
		_moves_pulse = null
		_moves_bubble.scale = Vector2.ONE
		var st: StyleBoxFlat = _moves_bubble.get_theme_stylebox("panel")
		st.bg_color = UIKit.C_SKY
	var extra: Dictionary = level.stars.extra
	var done: bool = goals.extra_done() and extra.type != "no_helpers"
	_star_label.text = "3 звезды: оставь %d ходов • %s%s" % [int(level.stars.three), extra.text.to_lower(), " — есть!" if done else ""]
	_star_label.add_theme_color_override("font_color", UIKit.C_GREEN_DARK if done else UIKit.C_TEXT.lightened(0.15))
	refresh_helpers()


func _make_helper_button(id: String) -> Button:
	var def: Dictionary = HelperManager.defs[id]
	var b := UIKit.round_button(HelperManager.icon(id), Color(def.color), 124)
	b.add_theme_constant_override("icon_max_width", 100)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): helper_pressed.emit(id))
	var badge := UIKit.badge(b, "0")
	badge.offset_left = -40
	badge.offset_top = -8
	return b


func refresh_helpers() -> void:
	for id in _helper_buttons:
		var b: Button = _helper_buttons[id]
		var n := HelperManager.charges(id)
		var badge: PanelContainer = b.get_node("Badge")
		var l: Label = badge.get_child(0)
		l.text = str(n) if n > 0 else "+"
		var st: StyleBoxFlat = badge.get_theme_stylebox("panel")
		st.bg_color = UIKit.C_CORAL if n > 0 else UIKit.C_GREEN
		# Empty helpers look inactive but stay tappable to offer the shop.
		b.modulate = Color.WHITE if n > 0 else Color(0.75, 0.75, 0.75, 0.85)


func set_helpers_enabled(on: bool) -> void:
	for id in _helper_buttons:
		_helper_buttons[id].disabled = not on
