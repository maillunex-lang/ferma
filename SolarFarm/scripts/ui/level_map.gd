extends ScreenBase
## Level selection: a winding garden path with 10 level stops.

const NODE_D := 140.0
const STEP_Y := 210.0

var _map: Control
var _current_node: Control


func _init() -> void:
	title_text = "Уровни"
	back_target = "menu"
	background_path = "res://assets/bg/puzzle.png"


func build() -> void:
	AudioManager.play_music("menu")
	var n := LevelManager.count()
	_map = Control.new()
	_map.custom_minimum_size = Vector2(640, STEP_Y * n + 80)
	_map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(_map)
	var path := Line2D.new()
	path.width = 46
	path.default_color = Color("e9cf96")
	path.joint_mode = Line2D.LINE_JOINT_ROUND
	path.begin_cap_mode = Line2D.LINE_CAP_ROUND
	path.end_cap_mode = Line2D.LINE_CAP_ROUND
	var border := Line2D.new()
	border.width = 62
	border.default_color = Color("b98a4a")
	border.joint_mode = Line2D.LINE_JOINT_ROUND
	border.begin_cap_mode = Line2D.LINE_CAP_ROUND
	border.end_cap_mode = Line2D.LINE_CAP_ROUND
	_map.add_child(border)
	_map.add_child(path)
	var pts := PackedVector2Array()
	for i in n:
		pts.append(_node_pos(i))
	var curve := Curve2D.new()
	for i in pts.size():
		var p := pts[i]
		var tangent := Vector2(0, STEP_Y * 0.45)
		curve.add_point(p, -tangent, tangent)
	var baked := curve.get_baked_points()
	path.points = baked
	border.points = baked
	for i in n:
		_map.add_child(_make_node(i))
	await get_tree().process_frame
	await get_tree().process_frame
	if _current_node:
		scroll.scroll_vertical = int(maxf(0.0, _current_node.position.y - scroll.size.y * 0.4))


func _node_pos(i: int) -> Vector2:
	var x := 320.0 + sin(i * 1.25) * 170.0
	return Vector2(x, 100 + i * STEP_Y)


func _make_node(i: int) -> Control:
	var lv: Dictionary = LevelManager.levels[i]
	var id := int(lv.id)
	var unlocked := LevelManager.is_unlocked(id)
	var completed := LevelManager.is_completed(id)
	var holder := Control.new()
	holder.position = _node_pos(i) - Vector2(NODE_D, NODE_D) / 2
	holder.size = Vector2(NODE_D, NODE_D + 50)
	var color := UIKit.C_GREEN if completed else (UIKit.C_ORANGE if unlocked else UIKit.C_GREY)
	var b := UIKit.button(str(id) if unlocked else "", color, Vector2(NODE_D, NODE_D), 56)
	for k in ["normal", "hover", "pressed", "disabled"]:
		(b.get_theme_stylebox(k) as StyleBoxFlat).set_corner_radius_all(int(NODE_D / 2))
	if not unlocked:
		b.icon = load("res://assets/ui/icon_lock.png")
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 60)
	b.pressed.connect(func(): _open_level(id))
	holder.add_child(b)
	var name_l := UIKit.label(lv.name, 24, Color.WHITE, 8, Color(0.25, 0.15, 0.05, 0.85))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(-80, NODE_D + 34)
	name_l.size = Vector2(NODE_D + 160, 30)
	holder.add_child(name_l)
	if completed:
		var stars := HBoxContainer.new()
		stars.add_theme_constant_override("separation", -6)
		stars.position = Vector2(4, NODE_D - 18)
		var s := LevelManager.stars(id)
		for k in 3:
			stars.add_child(UIKit.icon(load("res://assets/ui/star.png" if k < s else "res://assets/ui/star_empty.png"), 48))
		holder.add_child(stars)
	if unlocked and not completed:
		_current_node = holder
		b.ready.connect(func():
			b.pivot_offset = b.size / 2
			UIKit.pulse(b, 0.07, 1.0))
	return holder


func _open_level(id: int) -> void:
	if not LevelManager.is_unlocked(id):
		GameManager.toast("Сначала пройди уровень %d" % (id - 1), UIKit.C_CORAL)
		AudioManager.play("invalid")
		return
	var lv := LevelManager.get_level(id)
	var content_box := VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 12)
	var goals_row := HBoxContainer.new()
	goals_row.alignment = BoxContainer.ALIGNMENT_CENTER
	goals_row.add_theme_constant_override("separation", 18)
	content_box.add_child(goals_row)
	for g in lv.goals:
		var box := VBoxContainer.new()
		var tex := ""
		match g.type:
			"collect":
				tex = LevelManager.color_defs[int(g.colors[0])].texture
			"weeds":
				tex = "res://assets/tiles/weed.png"
			"rockets":
				tex = "res://assets/tiles/rocket.png"
			"rainbow":
				tex = "res://assets/tiles/rainbow.png"
		box.add_child(UIKit.icon(load(tex), 80))
		var l := UIKit.label("× %d" % int(g.target), 28)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		goals_row.add_child(box)
	var info := UIKit.label("Ходов: %d   •   Награда: %d монет" % [int(lv.moves), int(lv.reward.coins)], 26)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_box.add_child(info)
	if not lv.reward.get("helpers", {}).is_empty() and not LevelManager.is_completed(id):
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		for h in lv.reward.helpers:
			hb.add_child(UIKit.icon(HelperManager.icon(h), 60))
			hb.add_child(UIKit.label("+%d заряд в награду" % int(lv.reward.helpers[h]), 24, UIKit.C_GREEN_DARK))
		content_box.add_child(hb)
	var helpers_row := HBoxContainer.new()
	helpers_row.alignment = BoxContainer.ALIGNMENT_CENTER
	helpers_row.add_theme_constant_override("separation", 10)
	content_box.add_child(helpers_row)
	for h in HelperManager.order:
		var hv := VBoxContainer.new()
		hv.add_theme_constant_override("separation", -4)
		var ic := UIKit.icon(HelperManager.icon(h), 64)
		if HelperManager.charges(h) == 0:
			ic.modulate = Color(0.7, 0.7, 0.7, 0.7)
		hv.add_child(ic)
		var cl := UIKit.label(str(HelperManager.charges(h)), 24)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hv.add_child(cl)
		helpers_row.add_child(hv)
	var best := LevelManager.stars(id)
	var title := "Уровень %d" % id
	GameManager.show_dialog(title, "%s%s" % [lv.name, ("  •  лучший результат: %d зв." % best) if best > 0 else ""], [
		{"text": "Играть", "color": UIKit.C_ORANGE, "callback": func(): GameManager.play_level(id)},
		{"text": "Закрыть", "color": UIKit.C_CORAL},
	], content_box)
