extends Control
## Match3Board scene: connects BoardModel (logic), LevelGoals (objectives),
## Match3Hud (interface) and the animated board view. Handles input, helper
## abilities, pause, win/lose flow.

const SWAP_TIME := 0.15
const CLEAR_TIME := 0.2
const PRAISE := ["Отлично!", "Супер!", "Восхитительно!", "Невероятно!"]

var level: Dictionary
var model := BoardModel.new()
var goals := LevelGoals.new()
var hud: Match3Hud
var cs := 80.0
var board_root: Node2D
var board_clip: Control
var pieces_layer: Node2D
var weeds_layer: Node2D
var fx: FxLayer
var views := {}
var weed_views := {}
var ice_views := {}
var ice_layer: Node2D
var busy := true
var finished := false
var helper_lock := false
var target_helper := ""
var selected := Vector2i(-1, -1)
var _press_cell := Vector2i(-1, -1)
var _press_pos := Vector2.ZERO
var _drag_done := false
var _select_ring: Sprite2D
var _hint_time := 0.0
var _hint_tweens: Array = []
var _target_banner: Control
var _shop_layer: CanvasLayer
var _safe := {}


class CellsDrawer:
	extends Node2D
	## Draws the board in the level's shape: soft shadow, rounded frame that
	## follows the active cells, and light glossy cells.
	var model: BoardModel
	var cs := 80.0
	const FRAME := Color("5b4a86")
	const CELL_A := Color("f4f8ff")
	const CELL_B := Color("dde9f8")

	func _box(color: Color, radius: float) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = color
		s.set_corner_radius_all(int(radius))
		s.anti_aliasing = true
		return s

	func _draw() -> void:
		var shadow := _box(Color(0.12, 0.08, 0.25, 0.28), cs * 0.32)
		var frame := _box(FRAME, cs * 0.3)
		var rim := _box(FRAME.lightened(0.35), cs * 0.24)
		var cell_a := _box(CELL_A, cs * 0.16)
		var cell_b := _box(CELL_B, cs * 0.16)
		var shine := _box(Color(1, 1, 1, 0.45), cs * 0.12)
		var cells := []
		for x in BoardModel.W:
			for y in BoardModel.H:
				if model.active[x][y]:
					cells.append(Vector2(x, y) * cs)
		for p in cells:
			shadow.draw(get_canvas_item(), Rect2(p + Vector2(-12, -4), Vector2(cs + 24, cs + 24)))
		for p in cells:
			frame.draw(get_canvas_item(), Rect2(p - Vector2(11, 11), Vector2(cs + 22, cs + 22)))
		for p in cells:
			rim.draw(get_canvas_item(), Rect2(p - Vector2(4, 4), Vector2(cs + 8, cs + 8)))
		for p in cells:
			var cx := int(p.x / cs)
			var cy := int(p.y / cs)
			var box: StyleBoxFlat = cell_a if (cx + cy) % 2 == 0 else cell_b
			box.draw(get_canvas_item(), Rect2(p + Vector2(2, 2), Vector2(cs - 4, cs - 4)))
			shine.draw(get_canvas_item(), Rect2(p + Vector2(cs * 0.12, cs * 0.08), Vector2(cs * 0.76, cs * 0.14)))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("puzzle")
	level = LevelManager.get_level(LevelManager.current_level_id)
	if level.is_empty():
		level = LevelManager.get_level(1)
	model.setup(level.colors, level.get("mask", []), level.get("weeds", []), -1, level.get("ice", []))
	goals.setup(level)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/bg/puzzle.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_add_motes()
	_safe = GameManager.safe_margins()
	board_root = Node2D.new()
	add_child(board_root)
	hud = Match3Hud.new()
	add_child(hud)
	hud.build(level, goals, _safe)
	hud.helper_pressed.connect(_on_helper_pressed)
	hud.pause_pressed.connect(_pause)
	await get_tree().process_frame
	_build_board()
	resized.connect(_relayout)
	_start_level()


func _start_level() -> void:
	await _intro_drop()
	var key := "tip_%d" % int(level.id)
	if str(level.get("tip", "")) != "" and not SaveManager.data.tutorial.get(key, false):
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 16)
		var helper_id: String = HelperManager.order[(int(level.id) - 1) % HelperManager.order.size()]
		content.add_child(UIKit.icon(HelperManager.icon(helper_id), 150))
		var tip := UIKit.label(level.tip, 28)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size.x = 380
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(tip)
		GameManager.show_dialog("Уровень %d. %s" % [int(level.id), level.name], _goals_text(), [
			{"text": "Начать!", "color": UIKit.C_ORANGE, "callback": func():
				SaveManager.data.tutorial[key] = true
				SaveManager.save_game()
				busy = false},
		], content)
	else:
		_goal_banner()
		busy = false


## Short non-blocking banner with the level goals.
func _goal_banner() -> void:
	var title := "Сложный уровень %d!" % int(level.id) if level.get("hard", false) else "Уровень %d" % int(level.id)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -4)
	var t := UIKit.title_label(title, 56, UIKit.C_CORAL.darkened(0.3) if level.get("hard", false) else Color("5b4a86"))
	box.add_child(t)
	var g := UIKit.label(_goals_text(), 28, Color.WHITE, 8, Color("5b4a86"))
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.custom_minimum_size.x = size.x - 60
	box.add_child(g)
	add_child(box)
	box.size = Vector2(size.x - 40, 160)
	box.position = Vector2(20, board_root.position.y + cs * 3)
	box.pivot_offset = box.size / 2
	UIKit.pop_in(box)
	var tw := box.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)


## Slow glowing motes drifting over the blurred garden background.
func _add_motes() -> void:
	if not GameManager.effects_high():
		return
	var p := CPUParticles2D.new()
	p.texture = load("res://assets/fx/mote.png")
	p.material = FxLayer.add_material()
	var vs := get_viewport_rect().size
	p.position = vs / 2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = vs / 2
	p.amount = 22
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.direction = Vector2(0, -1)
	p.spread = 60
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 8
	p.initial_velocity_max = 26
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.2
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	p.color_ramp = grad
	add_child(p)


func _goals_text() -> String:
	var parts := []
	for g in goals.goals:
		match g.type:
			"collect":
				var names := []
				for c in g.colors:
					names.append(LevelManager.color_defs[c].goal_name)
				parts.append("%d %s" % [g.target, " или ".join(names)])
			"weeds":
				parts.append("убрать %d сорняков" % g.target)
			"ice":
				parts.append("растопить %d льдинок" % g.target)
			"rockets":
				parts.append("запустить %d ракеты" % g.target)
			"rainbow":
				parts.append("создать радужную ягоду")
	return "Цель: %s. Ходов: %d." % [", ".join(parts), goals.moves_total]


# ------------------------------------------------------------------ board building

func _build_board() -> void:
	board_root.get_children().map(func(c): c.queue_free())
	views.clear()
	weed_views.clear()
	ice_views.clear()
	var vw := size.x
	var top := hud.top_height()
	var bottom := hud.bottom_height()
	var avail_h := size.y - top - bottom - 24
	cs = floorf(minf((vw - 44) / 8.0, avail_h / 8.0))
	var board_px := cs * 8
	board_root.position = Vector2(roundf((vw - board_px) / 2), roundf(top + (avail_h - board_px) / 2 + 12))

	var cells := CellsDrawer.new()
	cells.model = model
	cells.cs = cs
	board_root.add_child(cells)

	board_clip = Control.new()
	board_clip.clip_contents = true
	board_clip.size = Vector2(board_px, board_px)
	board_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	board_clip.gui_input.connect(_on_board_input)
	board_root.add_child(board_clip)
	pieces_layer = Node2D.new()
	board_clip.add_child(pieces_layer)
	ice_layer = Node2D.new()
	board_clip.add_child(ice_layer)
	weeds_layer = Node2D.new()
	board_clip.add_child(weeds_layer)

	_select_ring = Sprite2D.new()
	_select_ring.texture = load("res://assets/fx/ring.png")
	_select_ring.modulate = Color(1, 0.85, 0.2, 0.95)
	_select_ring.material = FxLayer.add_material()
	_select_ring.scale = Vector2.ONE * cs * 1.15 / 256.0
	_select_ring.visible = false
	pieces_layer.add_child(_select_ring)
	var rt := _select_ring.create_tween().set_loops()
	rt.tween_property(_select_ring, "scale", Vector2.ONE * cs * 1.28 / 256.0, 0.45).set_trans(Tween.TRANS_SINE)
	rt.tween_property(_select_ring, "scale", Vector2.ONE * cs * 1.12 / 256.0, 0.45).set_trans(Tween.TRANS_SINE)

	fx = FxLayer.new()
	board_root.add_child(fx)

	for x in BoardModel.W:
		for y in BoardModel.H:
			var p = model.grid[x][y]
			if p != null:
				_create_view(p.id, p.color, p.special, Vector2i(x, y))
			if model.weeds[x][y] > 0:
				_create_weed(Vector2i(x, y), model.weeds[x][y])
			if model.ice[x][y] > 0:
				_create_ice(Vector2i(x, y), model.ice[x][y])


## Pieces rain down column by column when the level starts.
func _intro_drop() -> void:
	var t := create_tween().set_parallel(true)
	for id in views:
		var v: PieceView = views[id]
		var target := v.position
		var col := int(target.x / cs)
		var row := int(target.y / cs)
		v.position = target - Vector2(0, cs * 9)
		t.tween_property(v, "position", target, 0.45).set_delay(col * 0.04 + (7 - row) * 0.035).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if views.is_empty():
		t.kill()
	else:
		await t.finished


func _create_ice(pos: Vector2i, hp: int) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/tiles/ice_%d.png" % clampi(hp, 1, 2))
	s.position = cell_center(pos)
	s.scale = Vector2.ONE * cs * 0.98 / 256.0
	ice_layer.add_child(s)
	ice_views[pos] = s


func _hit_ice(pos: Vector2i, hp: int) -> void:
	var s: Sprite2D = ice_views.get(pos)
	if s == null:
		return
	fx.burst(s.position, Color(0.85, 0.97, 1.0), 8, "shard", 0.8)
	AudioManager.play("star", 1.6, -4.0)
	if hp <= 0:
		ice_views.erase(pos)
		var t := s.create_tween().set_parallel(true)
		t.tween_property(s, "scale", s.scale * 1.25, 0.18)
		t.tween_property(s, "modulate:a", 0.0, 0.22)
		t.chain().tween_callback(s.queue_free)
	else:
		s.texture = load("res://assets/tiles/ice_1.png")


func _relayout() -> void:
	if busy or board_root == null:
		return
	_build_board()


func cell_center(p: Vector2i) -> Vector2:
	return Vector2((p.x + 0.5) * cs, (p.y + 0.5) * cs)


func _cell_at(local: Vector2) -> Vector2i:
	var c := Vector2i(floori(local.x / cs), floori(local.y / cs))
	return c if model.in_bounds(c) else Vector2i(-1, -1)


func _create_view(id: int, color: int, special: int, pos: Vector2i) -> PieceView:
	var v := PieceView.new()
	v.setup(id, color, special, cs)
	v.position = cell_center(pos)
	pieces_layer.add_child(v)
	views[id] = v
	return v


func _create_weed(pos: Vector2i, hp: int) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/tiles/weed.png")
	s.position = cell_center(pos)
	_style_weed(s, hp)
	weeds_layer.add_child(s)
	weed_views[pos] = s


func _style_weed(s: Sprite2D, hp: int) -> void:
	var k := cs * (1.02 if hp > 1 else 0.94) / 256.0
	s.scale = Vector2(k, k)
	s.modulate = Color(0.72, 0.85, 0.62) if hp > 1 else Color.WHITE


func _view_at(p: Vector2i) -> PieceView:
	var piece = model.piece_at(p)
	return views.get(piece.id) if piece != null else null


# ------------------------------------------------------------------ input

func _on_board_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press_cell = _cell_at(ev.position)
			_press_pos = ev.position
			_drag_done = false
			_stop_hint()
		else:
			if not _drag_done and _press_cell.x >= 0:
				_on_tap(_press_cell)
			_press_cell = Vector2i(-1, -1)
	elif ev is InputEventMouseMotion and _press_cell.x >= 0 and not _drag_done:
		var d: Vector2 = ev.position - _press_pos
		if d.length() > cs * 0.32 and target_helper == "":
			_drag_done = true
			var dir := Vector2i(int(signf(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, int(signf(d.y)))
			_request_swap(_press_cell, _press_cell + dir)


func _on_tap(cell: Vector2i) -> void:
	if busy or finished:
		return
	if target_helper != "":
		_apply_target_helper(cell)
		return
	var p = model.piece_at(cell)
	if selected.x >= 0:
		if selected == cell:
			_deselect()
			return
		if absi(selected.x - cell.x) + absi(selected.y - cell.y) == 1:
			_request_swap(selected, cell)
			return
	if p != null and p.special != BoardModel.Special.NONE:
		_deselect()
		_do_activate(cell)
		return
	if p != null:
		_select(cell)


func _select(cell: Vector2i) -> void:
	_deselect()
	selected = cell
	AudioManager.play("select")
	_select_ring.position = cell_center(cell)
	_select_ring.visible = true
	var v := _view_at(cell)
	if v:
		var t := v.create_tween()
		t.tween_property(v, "scale", v.base_scale() * 1.15, 0.1)
		t.tween_property(v, "scale", v.base_scale() * 1.06, 0.1)


func _deselect() -> void:
	if selected.x >= 0:
		var v := _view_at(selected)
		if v and v.special == BoardModel.Special.NONE:
			v.scale = v.base_scale()
	selected = Vector2i(-1, -1)
	if _select_ring:
		_select_ring.visible = false


func _request_swap(a: Vector2i, b: Vector2i) -> void:
	if busy or finished or not model.in_bounds(b) or not model.in_bounds(a):
		return
	_deselect()
	_do_swap(a, b)


func _do_swap(a: Vector2i, b: Vector2i) -> void:
	var va := _view_at(a)
	var vb := _view_at(b)
	if va == null or vb == null:
		return
	busy = true
	var res := model.try_swap(a, b)
	if not res.valid:
		AudioManager.play("invalid")
		var t := create_tween().set_parallel(true)
		t.tween_property(va, "position", cell_center(b), SWAP_TIME)
		t.tween_property(vb, "position", cell_center(a), SWAP_TIME)
		t.chain().tween_property(va, "position", cell_center(a), SWAP_TIME)
		t.parallel().tween_property(vb, "position", cell_center(b), SWAP_TIME)
		await t.finished
		busy = false
		return
	goals.use_move()
	hud.refresh()
	AudioManager.play("swap")
	var t2 := create_tween().set_parallel(true)
	t2.tween_property(va, "position", cell_center(b), SWAP_TIME).set_trans(Tween.TRANS_QUAD)
	t2.tween_property(vb, "position", cell_center(a), SWAP_TIME).set_trans(Tween.TRANS_QUAD)
	await t2.finished
	if res.combo:
		fx.float_text("Суперкомбо!", Vector2(cs * 4, cell_center(b).y), UIKit.C_PURPLE)
	await _play_result(res)


func _do_activate(cell: Vector2i) -> void:
	busy = true
	var res := model.activate_at(cell)
	if not res.valid:
		busy = false
		return
	goals.use_move()
	hud.refresh()
	await _play_result(res)


# ------------------------------------------------------------------ animation of results

func _play_result(res: Dictionary) -> void:
	for ph in res.phases:
		if ph.has("shuffle"):
			await _anim_shuffle(ph)
			continue
		await _play_phase(ph)
		goals.apply_phase(ph)
		hud.refresh()
		_notify_achievements(ph)
	goals.finish_result(res)
	hud.refresh()
	_after_action()


func _play_phase(ph: Dictionary) -> void:
	var cascade: int = ph.cascade
	for cv in ph.converted:
		var v: PieceView = views.get(cv.id)
		if v:
			v.set_kind(-1, cv.special)
			fx.glow(v.position, Color(1, 0.9, 1.0, 0.9), cs * 1.6, 0.3)
	if not ph.converted.is_empty():
		await get_tree().create_timer(0.3).timeout
	# Delay per cell so rocket lines and explosions sweep across the board.
	var delays := {}
	for e in ph.effects:
		_play_effect(e)
		_effect_delays(e, delays)
	if not ph.effects.is_empty():
		await get_tree().create_timer(0.08).timeout
	var clusters := _clusters(ph.cleared)
	# Boosters are born by sliding the matched pieces into one cell.
	var merging := {}
	if not ph.created.is_empty():
		var mt := create_tween().set_parallel(true)
		for cr in ph.created:
			for cl in clusters:
				if cl.color == cr.color and cl.cells.has(cr.pos):
					for c in cl.items:
						var v: PieceView = views.get(c.id)
						if v and c.pos != cr.pos:
							merging[c.id] = true
							mt.tween_property(v, "position", cell_center(cr.pos), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		if merging.is_empty():
			mt.kill()
		else:
			await mt.finished
	var t := create_tween().set_parallel(true)
	var max_delay := 0.0
	var flown := 0
	var wanted := goals.wanted_colors()
	for c in ph.cleared:
		var v: PieceView = views.get(c.id)
		if v == null:
			continue
		views.erase(c.id)
		v.stop_idle()
		var d: float = delays.get(c.pos, 0.0)
		max_delay = maxf(max_delay, d)
		var col := LevelManager.color_tint(c.color) if c.color >= 0 else Color(1, 0.9, 0.5)
		if merging.has(c.id):
			t.tween_property(v, "modulate:a", 0.0, 0.08)
			t.tween_callback(v.queue_free).set_delay(0.09)
			continue
		v.pop_out(t, d)
		get_tree().create_timer(d).timeout.connect(_clear_fx.bind(v.position, col))
		if c.color >= 0 and wanted.has(c.color) and flown < 8:
			flown += 1
			get_tree().create_timer(d + 0.05).timeout.connect(_fly_to_goal.bind(v.texture, v.position, c.color))
	for cl in clusters:
		if cl.items.size() >= 3:
			fx.ring(cl.center, Color(LevelManager.color_tint(cl.color), 0.85), cs * (1.0 + cl.items.size() * 0.12), 0.4)
	for w in ph.weeds:
		_hit_weed(w.pos, w.hp)
	for i in ph.get("ice", []):
		get_tree().create_timer(delays.get(i.pos, 0.0)).timeout.connect(_hit_ice.bind(i.pos, i.hp))
	if not ph.cleared.is_empty():
		AudioManager.play("match", 1.0 + 0.07 * mini(cascade, 8))
	for cr in ph.created:
		var nv := _create_view(cr.id, -1, cr.special, cr.pos)
		nv.stop_idle()
		nv.scale = Vector2.ZERO
		t.tween_property(nv, "scale", nv.base_scale() * 1.45, 0.2).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(nv, "scale", nv.base_scale(), 0.14).set_delay(0.26)
		t.tween_callback(nv.set_kind.bind(-1, cr.special)).set_delay(0.42)
		var p := cell_center(cr.pos)
		fx.glow(p, Color(1, 0.95, 0.6, 1.0), cs * 2.6, 0.5)
		fx.ring(p, Color(1, 0.9, 0.5, 0.9), cs * 1.3, 0.45)
		fx.burst(p, Color(1, 0.9, 0.4), 16, "star", 1.2)
		AudioManager.play("special_create")
	if cascade >= 2:
		fx.float_text(PRAISE[mini(cascade - 2, PRAISE.size() - 1)], Vector2(cs * 4, cs * 3.5), [UIKit.C_ORANGE, UIKit.C_SKY, UIKit.C_PURPLE, UIKit.C_CORAL][cascade % 4])
		if cascade == 2:
			AudioManager.play("combo")
	if ph.cleared.is_empty() and ph.created.is_empty():
		t.kill()
	else:
		await get_tree().create_timer(max_delay + 0.3).timeout
		if t.is_valid() and t.is_running():
			await t.finished
	await _anim_fall(ph.moves, ph.spawns)


func _clear_fx(pos: Vector2, col: Color) -> void:
	fx.glow(pos, Color(col, 0.9), cs * 1.7, 0.32)
	fx.burst(pos, col.lightened(0.2), 7, "star", 0.9)


## Groups cleared pieces of the same colour that touch each other.
func _clusters(cleared: Array) -> Array:
	var by_pos := {}
	for c in cleared:
		if int(c.color) >= 0:
			by_pos[c.pos] = c
	var seen := {}
	var out := []
	for start in by_pos:
		if seen.has(start):
			continue
		var color: int = by_pos[start].color
		var stack := [start]
		var items := []
		var cells := []
		seen[start] = true
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			items.append(by_pos[p])
			cells.append(p)
			for dir in BoardModel.DIRS:
				var q: Vector2i = p + dir
				if by_pos.has(q) and not seen.has(q) and int(by_pos[q].color) == color:
					seen[q] = true
					stack.append(q)
		var center := Vector2.ZERO
		for p in cells:
			center += cell_center(p)
		out.append({"color": color, "items": items, "cells": cells, "center": center / cells.size()})
	return out


func _effect_delays(e: Dictionary, delays: Dictionary) -> void:
	var p: Vector2i = e.pos
	for x in BoardModel.W:
		for y in BoardModel.H:
			var c := Vector2i(x, y)
			var d := -1.0
			match e.kind:
				"rocket_h":
					if y == p.y:
						d = absi(x - p.x) * 0.035
				"rocket_v":
					if x == p.x:
						d = absi(y - p.y) * 0.035
				"cross", "big_cross":
					var w := 1 if e.kind == "big_cross" else 0
					if absi(y - p.y) <= w or absi(x - p.x) <= w:
						d = maxi(absi(x - p.x), absi(y - p.y)) * 0.035
				"blast":
					if maxi(absi(x - p.x), absi(y - p.y)) <= int(e.radius):
						d = Vector2(c - p).length() * 0.05
				"rainbow_all":
					d = Vector2(c - p).length() * 0.04
			if d >= 0.0:
				delays[c] = minf(delays.get(c, 99.0), d)
	if e.kind == "rainbow":
		var i := 0
		for c in e.targets:
			delays[c] = minf(delays.get(c, 99.0), 0.12 + i * 0.03)
			i += 1


func _fly_to_goal(tex: Texture2D, from: Vector2, color: int) -> void:
	for i in goals.goals.size():
		var g: Dictionary = goals.goals[i]
		if g.type == "collect" and g.colors.has(color):
			var target := fx.get_global_transform().affine_inverse() * hud.goal_icon_global_pos(i)
			fx.fly_curve(tex, from, target, cs * 0.75, 0.55, LevelManager.color_tint(color))
			return


func _play_effect(e: Dictionary) -> void:
	var p := cell_center(e.pos)
	var board_px := cs * 8
	var rocket: Texture2D = load("res://assets/tiles/rocket.png")
	var warm := Color(1.0, 0.75, 0.35, 0.95)
	match e.kind:
		"rocket_h", "rocket_v", "cross", "big_cross":
			AudioManager.play("rocket")
			var horizontal: bool = e.kind != "rocket_v"
			var vertical: bool = e.kind != "rocket_h"
			var offsets := [0] if e.kind != "big_cross" else [-1, 0, 1]
			fx.glow(p, warm, cs * 2.4, 0.4)
			for o in offsets:
				if horizontal:
					var y: float = p.y + o * cs
					fx.beam(Vector2(-cs, y), Vector2(board_px + cs, y), warm, cs * 0.5, 0.45)
					fx.flying_sprite(rocket, Vector2(p.x, y), Vector2(board_px + cs * 2, y), cs, 0.32, 0.0, warm)
					fx.flying_sprite(rocket, Vector2(p.x, y), Vector2(-cs * 2, y), cs, 0.32, PI, warm)
				if vertical:
					var x: float = p.x + o * cs
					fx.beam(Vector2(x, -cs), Vector2(x, board_px + cs), warm, cs * 0.5, 0.45)
					fx.flying_sprite(rocket, Vector2(x, p.y), Vector2(x, -cs * 2), cs, 0.32, -PI / 2, warm)
					fx.flying_sprite(rocket, Vector2(x, p.y), Vector2(x, board_px + cs * 2), cs, 0.32, PI / 2, warm)
			_shake(4.0)
		"blast":
			AudioManager.play("boom")
			var r: float = (int(e.radius) + 0.6) * cs
			fx.glow(p, Color(1, 0.8, 0.35, 1.0), r * 2.4, 0.5)
			fx.ring(p, Color(1, 0.9, 0.6, 1.0), r * 1.1, 0.5)
			fx.ring(p, Color(1, 0.6, 0.3, 0.8), r * 0.7, 0.35)
			fx.burst(p, Color(1, 0.75, 0.3), 20, "star", 1.6)
			fx.burst(p, Color(0.55, 0.85, 0.3), 10, "leaf", 1.3)
			_shake(6.0 + e.radius * 3)
		"rainbow":
			AudioManager.play("rainbow")
			fx.glow(p, Color(1, 1, 1, 1), cs * 3, 0.6)
			fx.ring(p, Color(0.9, 0.7, 1.0, 0.9), cs * 2, 0.5)
			var i := 0
			for c in e.targets:
				var col := Color.from_hsv(fmod(i * 0.13, 1.0), 0.55, 1.0, 0.95)
				get_tree().create_timer(i * 0.03).timeout.connect(fx.beam.bind(p, cell_center(c), col, cs * 0.16, 0.35))
				i += 1
		"rainbow_all":
			AudioManager.play("rainbow")
			AudioManager.play("boom")
			fx.glow(p, Color(1, 1, 1, 1), cs * 10, 0.8)
			fx.ring(p, Color(1, 0.9, 1.0, 1.0), cs * 6, 0.7)
			fx.confetti(Rect2(0, 0, board_px, board_px), 50)
			_shake(12.0)


func _hit_weed(pos: Vector2i, hp: int) -> void:
	var s: Sprite2D = weed_views.get(pos)
	if s == null:
		return
	fx.burst(s.position, Color(0.5, 0.85, 0.3), 9, "leaf")
	AudioManager.play("weed")
	if hp <= 0:
		weed_views.erase(pos)
		var t := s.create_tween().set_parallel(true)
		t.tween_property(s, "scale", s.scale * 1.3, 0.12)
		t.tween_property(s, "modulate:a", 0.0, 0.25).set_delay(0.08)
		t.tween_property(s, "rotation", 0.4, 0.25)
		t.chain().tween_callback(s.queue_free)
	else:
		_style_weed(s, hp)
		var t := s.create_tween()
		t.tween_property(s, "rotation", 0.2, 0.06)
		t.tween_property(s, "rotation", -0.2, 0.08)
		t.tween_property(s, "rotation", 0.0, 0.06)


func _anim_fall(moves: Array, spawns: Array) -> void:
	if moves.is_empty() and spawns.is_empty():
		return
	var t := create_tween().set_parallel(true)
	var landed: Array[PieceView] = []
	for m in moves:
		var v: PieceView = views.get(m.id)
		if v == null:
			continue
		var dist: int = m.to.y - m.from.y
		t.tween_property(v, "position", cell_center(m.to), 0.09 + 0.045 * absi(dist)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		landed.append(v)
	for s in spawns:
		var v := _create_view(s.id, s.color, BoardModel.Special.NONE, s.to)
		v.position = cell_center(Vector2i(s.to.x, s.from_y))
		var dist: int = s.to.y - s.from_y
		t.tween_property(v, "position", cell_center(s.to), 0.09 + 0.045 * dist).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		landed.append(v)
	await t.finished
	AudioManager.play("land", randf_range(0.9, 1.1), -6.0)
	if GameManager.effects_high():
		for v in landed:
			if is_instance_valid(v) and v.special == BoardModel.Special.NONE:
				var b := v.base_scale()
				var tw := v.create_tween()
				tw.tween_property(v, "scale", Vector2(b.x * 1.08, b.y * 0.88), 0.06)
				tw.tween_property(v, "scale", b, 0.1)


func _anim_shuffle(ph: Dictionary) -> void:
	fx.float_text("Перемешиваем!", Vector2(cs * 4, cs * 4), UIKit.C_SKY)
	AudioManager.play("swap", 0.8)
	var t := create_tween().set_parallel(true)
	for m in ph.shuffle:
		var v: PieceView = views.get(m.id)
		if v == null:
			continue
		v.set_kind(m.color, BoardModel.Special.NONE)
		t.tween_property(v, "position", cell_center(m.to), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished


func _shake(amount: float) -> void:
	if not GameManager.effects_high():
		return
	var base := board_root.position
	var t := create_tween()
	for i in 5:
		t.tween_property(board_root, "position", base + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.035)
	t.tween_property(board_root, "position", base, 0.05)


func _notify_achievements(ph: Dictionary) -> void:
	if int(ph.groups) > 0:
		AchievementManager.notify("match", int(ph.groups))
	var melted := 0
	for i in ph.get("ice", []):
		if int(i.hp) <= 0:
			melted += 1
	if melted > 0:
		AchievementManager.notify("ice_cleared", melted)
	for cr in ph.created:
		match int(cr.special):
			BoardModel.Special.ROCKET_H, BoardModel.Special.ROCKET_V:
				AchievementManager.notify("rocket_created")
			BoardModel.Special.BASKET:
				AchievementManager.notify("basket_created")
			BoardModel.Special.RAINBOW:
				AchievementManager.notify("rainbow_created")


# ------------------------------------------------------------------ flow

func _after_action() -> void:
	if finished:
		return
	if goals.is_complete():
		_win()
		return
	if goals.moves_left <= 0:
		_out_of_moves()
		return
	busy = false
	_hint_time = 0.0


func _win() -> void:
	finished = true
	busy = true
	hud.set_helpers_enabled(false)
	AudioManager.play("win")
	var banner := UIKit.title_label("Уровень пройден!", 64, UIKit.C_GREEN_DARK)
	banner.size = Vector2(size.x, 100)
	banner.position = Vector2(0, board_root.position.y + cs * 3.5)
	banner.pivot_offset = Vector2(size.x / 2, 50)
	add_child(banner)
	UIKit.pop_in(banner)
	fx.confetti(Rect2(-cs, -cs * 2, cs * 10, cs), 90)
	for i in 6:
		fx.burst(Vector2(randf() * cs * 8, randf() * cs * 8), Color.from_hsv(randf(), 0.7, 1.0), 14)
	await get_tree().create_timer(1.5).timeout
	LevelManager.record_result(int(level.id), true, goals.stars(), goals.moves_left)
	GameManager.goto("result")


func _lose() -> void:
	if finished:
		return
	finished = true
	busy = true
	AudioManager.play("lose")
	LevelManager.record_result(int(level.id), false, 0, 0)
	GameManager.goto("result")


func _out_of_moves() -> void:
	busy = true
	var remaining := []
	for i in goals.goals.size():
		var g: Dictionary = goals.goals[i]
		var rem := goals.goal_remaining(i)
		if rem <= 0:
			continue
		match g.type:
			"collect":
				var names := []
				for c in g.colors:
					names.append(LevelManager.color_defs[c].goal_name)
				remaining.append("%d %s" % [rem, " или ".join(names)])
			"weeds":
				remaining.append("%d сорняков" % rem)
			"ice":
				remaining.append("%d льдинок" % rem)
			"rockets":
				remaining.append("%d ракет" % rem)
			"rainbow":
				remaining.append("радужную ягоду")
	var text := "Осталось: %s." % ", ".join(remaining)
	var buttons := []
	if HelperManager.charges("bee") > 0:
		text += "\nПчёлка Жужа может добавить 3 хода (1 заряд)."
		buttons.append({"text": "+3 хода", "color": UIKit.C_YELLOW, "callback": func(): _use_bee_from_dialog()})
	else:
		text += "\nЗаряды Пчёлки Жужи можно получить в магазине."
		buttons.append({"text": "Магазин", "color": UIKit.C_SKY, "callback": func(): _open_shop(_out_of_moves)})
	buttons.append({"text": "Завершить", "color": UIKit.C_CORAL, "callback": _lose})
	GameManager.show_dialog("Ходы закончились!", text, buttons)


func _use_bee_from_dialog() -> void:
	if helper_lock:
		return
	helper_lock = true
	if HelperManager.consume("bee"):
		goals.note_helper_used()
		await _run_helper("bee", Vector2i.ZERO)
	else:
		_out_of_moves()
	helper_lock = false


func _pause() -> void:
	if finished or GameManager.has_dialog():
		return
	_cancel_target()
	var toggles := HBoxContainer.new()
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	toggles.add_theme_constant_override("separation", 20)
	var s: Dictionary = SaveManager.data.settings
	for kind in ["music", "sfx"]:
		var on := float(s.get(kind, 0.8)) > 0.01
		var b := UIKit.round_button(load("res://assets/ui/icon_%s.png" % ("music" if kind == "music" else "sound")),
			UIKit.C_GREEN if on else UIKit.C_GREY, 100)
		b.pressed.connect(func():
			var now_on := float(s.get(kind, 0.8)) > 0.01
			s[kind] = 0.0 if now_on else 0.8
			SaveManager.save_game()
			AudioManager.apply_volumes()
			var c := UIKit.C_GREY if now_on else UIKit.C_GREEN
			for k in ["normal", "hover", "pressed"]:
				(b.get_theme_stylebox(k) as StyleBoxFlat).bg_color = c)
		toggles.add_child(b)
	GameManager.show_dialog("Пауза", "Уровень %d: %s" % [int(level.id), level.name], [
		{"text": "Играть", "color": UIKit.C_GREEN},
		{"text": "Заново", "color": UIKit.C_SKY, "callback": func(): _confirm_leave(func(): GameManager.play_level(int(level.id)))},
		{"text": "Выйти", "color": UIKit.C_CORAL, "callback": func(): _confirm_leave(func(): GameManager.goto("map"))},
	], toggles)


func _confirm_leave(action: Callable) -> void:
	GameManager.show_dialog("Покинуть уровень?", "Прогресс текущей попытки будет потерян. Использованные заряды помощников не возвращаются.", [
		{"text": "Остаться", "color": UIKit.C_GREEN},
		{"text": "Да", "color": UIKit.C_CORAL, "callback": func():
			finished = true
			action.call()},
	])


func on_back() -> void:
	if _shop_layer:
		_close_shop()
	elif target_helper != "":
		_cancel_target()
	elif not finished:
		_pause()


func on_app_paused() -> void:
	if not finished and not GameManager.has_dialog() and not busy:
		_pause()


# ------------------------------------------------------------------ helpers

func _on_helper_pressed(id: String) -> void:
	if finished or helper_lock or (busy and target_helper == ""):
		return
	if target_helper != "":
		_cancel_target()
	var def: Dictionary = HelperManager.defs[id]
	var n := HelperManager.charges(id)
	if n <= 0:
		GameManager.show_dialog(def.name, "Заряды закончились. Новые заряды дают за прохождение уровней, три звезды и задания. Также их можно получить в магазине.", [
			{"text": "Магазин", "color": UIKit.C_SKY, "callback": func(): _open_shop()},
			{"text": "Закрыть", "color": UIKit.C_CORAL},
		])
		return
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.add_child(UIKit.icon(HelperManager.icon(id), 150))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(vb)
	var d := UIKit.label(def.description, 28)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 360
	vb.add_child(d)
	vb.add_child(UIKit.label("Стоимость: %d заряд\nОсталось зарядов: %d" % [int(def.cost), n], 26, UIKit.C_ORANGE.darkened(0.25)))
	if def.target == "cell":
		vb.add_child(UIKit.label("Ход не тратится.", 24, UIKit.C_GREEN_DARK))
	GameManager.show_dialog(def.name, "", [
		{"text": "Использовать", "color": UIKit.C_GREEN, "callback": func(): _use_helper(id)},
		{"text": "Отмена", "color": UIKit.C_CORAL},
	], content)


func _use_helper(id: String) -> void:
	if helper_lock or busy or finished:
		return
	var def: Dictionary = HelperManager.defs[id]
	if def.target == "cell":
		target_helper = id
		_show_target_banner(def)
		return
	helper_lock = true
	if HelperManager.consume(id):
		goals.note_helper_used()
		hud.refresh()
		await _run_helper(id, Vector2i.ZERO)
	helper_lock = false


func _apply_target_helper(cell: Vector2i) -> void:
	if helper_lock:
		return
	var id := target_helper
	if not model.active[cell.x][cell.y]:
		return
	if id == "squirrel" and model.piece_at(cell) == null and model.weeds[cell.x][cell.y] <= 0:
		return
	helper_lock = true
	_cancel_target()
	if HelperManager.consume(id):
		goals.note_helper_used()
		hud.refresh()
		await _run_helper(id, cell)
	helper_lock = false


func _run_helper(id: String, cell: Vector2i) -> void:
	busy = true
	_stop_hint()
	AudioManager.play(HelperManager.defs[id].sfx)
	var tex := HelperManager.icon(id)
	match id:
		"rooster":
			var res := model.helper_peck(5)
			var bird := _helper_sprite(tex, Vector2(-cs, -cs))
			for c in res.get("cells", []):
				var t := bird.create_tween()
				t.tween_property(bird, "position", cell_center(c) + Vector2(0, -cs * 0.3), 0.16).set_trans(Tween.TRANS_QUAD)
				await t.finished
				var v := _view_at_id_cell(c)
				if v:
					fx.burst(v.position, Color(1, 0.8, 0.4), 6)
			var out := bird.create_tween()
			out.tween_property(bird, "position", Vector2(cs * 9, -cs), 0.3)
			out.tween_callback(bird.queue_free)
			await _play_result(res)
		"squirrel":
			var res := model.helper_remove(cell)
			var sq := _helper_sprite(tex, cell_center(cell) + Vector2(0, cs * 2))
			var t := sq.create_tween()
			t.tween_property(sq, "position", cell_center(cell), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await t.finished
			var t2 := sq.create_tween()
			t2.tween_property(sq, "position", cell_center(cell) + Vector2(cs * 3, -cs * 3), 0.35).set_delay(0.15)
			t2.parallel().tween_property(sq, "modulate:a", 0.0, 0.35).set_delay(0.15)
			t2.tween_callback(sq.queue_free)
			await _play_result(res)
		"hedgehog":
			var res := model.helper_blast(cell)
			var hh := _helper_sprite(tex, Vector2(-cs, cell_center(cell).y))
			var t := hh.create_tween()
			t.tween_property(hh, "position", cell_center(cell), 0.3).set_trans(Tween.TRANS_QUAD)
			t.parallel().tween_property(hh, "rotation", TAU, 0.3)
			await t.finished
			hh.queue_free()
			fx.flash(cell_center(cell), Color(1, 0.8, 0.5, 0.9), cs * 1.6, 0.35)
			AudioManager.play("boom")
			_shake(8.0)
			await _play_result(res)
		"bee":
			var target := fx.get_global_transform().affine_inverse() * hud.moves_global_pos()
			var bee := _helper_sprite(tex, Vector2(cs * 4, cs * 9))
			var t := bee.create_tween()
			t.tween_property(bee, "position", Vector2(cs * 2, cs * 4), 0.3).set_trans(Tween.TRANS_SINE)
			t.tween_property(bee, "position", target, 0.35).set_trans(Tween.TRANS_SINE)
			await t.finished
			bee.queue_free()
			goals.add_moves(3)
			hud.refresh()
			AudioManager.play("star", 1.3)
			fx.float_text("+3 хода", target + Vector2(-80, 120), UIKit.C_YELLOW)
			_after_action()


func _view_at_id_cell(c: Vector2i) -> PieceView:
	for id in views:
		var v: PieceView = views[id]
		if v.position.distance_to(cell_center(c)) < 2.0:
			return v
	return null


func _helper_sprite(tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * (cs * 1.5 / tex.get_width())
	s.position = pos
	fx.add_child(s)
	return s


func _show_target_banner(def: Dictionary) -> void:
	_target_banner = UIKit.card(Color(1, 0.95, 0.75, 0.97), 28)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	_target_banner.add_child(hb)
	var l := UIKit.label("%s: коснись клетки на поле" % def.short, 28)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var cancel := UIKit.button("Отмена", UIKit.C_CORAL, Vector2(160, 70), 24)
	cancel.pressed.connect(_cancel_target)
	hb.add_child(cancel)
	add_child(_target_banner)
	_target_banner.position = Vector2(20, board_root.position.y - 110)
	_target_banner.size = Vector2(size.x - 40, 90)
	UIKit.pop_in(_target_banner)
	board_root.modulate = Color(1, 1, 1)
	var t := board_root.create_tween().set_loops()
	t.tween_property(board_root, "modulate", Color(1.1, 1.1, 0.85), 0.5)
	t.tween_property(board_root, "modulate", Color.WHITE, 0.5)
	_target_banner.set_meta("tween", t)


func _cancel_target() -> void:
	target_helper = ""
	if _target_banner and is_instance_valid(_target_banner):
		var t: Tween = _target_banner.get_meta("tween")
		if t:
			t.kill()
		_target_banner.queue_free()
	_target_banner = null
	if board_root:
		board_root.modulate = Color.WHITE


func _open_shop(on_close: Callable = Callable()) -> void:
	if _shop_layer:
		return
	_shop_layer = CanvasLayer.new()
	_shop_layer.layer = 50
	add_child(_shop_layer)
	var shop: Control = load("res://scenes/Shop.tscn").instantiate()
	shop.set("embedded", true)
	_shop_layer.add_child(shop)
	shop.tree_exited.connect(func():
		_shop_layer.queue_free()
		_shop_layer = null
		hud.refresh_helpers()
		if on_close.is_valid():
			on_close.call())


func _close_shop() -> void:
	if _shop_layer:
		for c in _shop_layer.get_children():
			c.queue_free()


# ------------------------------------------------------------------ hints

func _process(delta: float) -> void:
	if busy or finished or target_helper != "" or GameManager.has_dialog() or _shop_layer:
		return
	if not SaveManager.data.settings.get("hints", true):
		return
	_hint_time += delta
	var wait := 1.5 if int(level.id) == 1 and goals.moves_left == goals.moves_total else 6.0
	if _hint_time > wait and _hint_tweens.is_empty():
		_show_hint()


func _show_hint() -> void:
	var moves := model.find_possible_moves()
	if moves.is_empty():
		return
	var m: Array = moves[randi() % moves.size()]
	for p in m:
		var v := _view_at(p)
		if v == null:
			continue
		var dir := Vector2(m[1] - m[0]) * cs * 0.12 * (1 if p == m[0] else -1)
		var base := cell_center(p)
		var t := v.create_tween().set_loops()
		t.tween_property(v, "position", base + dir, 0.25).set_trans(Tween.TRANS_SINE)
		t.tween_property(v, "position", base, 0.25).set_trans(Tween.TRANS_SINE)
		t.tween_interval(0.4)
		_hint_tweens.append([t, v, base])


func _stop_hint() -> void:
	for h in _hint_tweens:
		h[0].kill()
		if is_instance_valid(h[1]):
			h[1].position = h[2]
	_hint_tweens.clear()
	_hint_time = 0.0


func _exit_tree() -> void:
	SaveManager.save_game()
