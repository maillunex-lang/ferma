extends Node2D
## The player's farm: top-down world with pan / pinch-zoom camera, upgradable
## objects (each level has its own artwork), wandering animals and the
## upgrades UI. On first launch the farm looks abandoned; every upgrade makes
## it greener and brighter.

const OUTLINE := preload("res://assets/shaders/outline.gdshader")

var cfg: Dictionary
var world_size := Vector2(1600, 2600)
var camera: Camera2D
var ground: Sprite2D
var paths_root: Node2D
var objects_root: Node2D
var animals_root: Node2D
var markers_root: Node2D
var sprites := {}       # object id -> Sprite2D
var blades: Sprite2D
var ui: CanvasLayer
var info_panel: PanelContainer
var upgrades_panel: Control
var selected_id := ""
var _touches := {}
var _drag_dist := 0.0
var _pinch_start := 0.0
var _zoom_start := 1.0
var _coins_pill: Control
var _stars_pill: Control
var _bottom: HBoxContainer
var _upgrade_badge: Control
var _safe := {}


func _ready() -> void:
	AudioManager.play_music("farm")
	cfg = FarmProgression.config
	world_size = Vector2(cfg.world[0], cfg.world[1])
	_safe = GameManager.safe_margins()
	ground = Sprite2D.new()
	ground.texture = load("res://assets/bg/grass.png")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(Vector2(-400, -400), world_size + Vector2(800, 800))
	ground.centered = false
	ground.position = Vector2(-400, -400)
	add_child(ground)
	paths_root = Node2D.new()
	add_child(paths_root)
	objects_root = Node2D.new()
	objects_root.y_sort_enabled = true
	add_child(objects_root)
	animals_root = objects_root
	markers_root = Node2D.new()
	add_child(markers_root)
	_build_props()
	_build_paths()
	_build_objects()
	_refresh_ground()
	camera = Camera2D.new()
	camera.limit_left = -200
	camera.limit_top = -200
	camera.limit_right = int(world_size.x) + 200
	camera.limit_bottom = int(world_size.y) + 260
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	var vw := get_viewport_rect().size.x
	camera.zoom = Vector2.ONE * clampf(vw / 1320.0, _min_zoom(), 1.4)
	camera.position = Vector2(800, 1000)
	camera.make_current()
	_build_ui()
	_refresh_markers()
	FarmProgression.upgraded.connect(_on_upgraded)
	EconomyManager.coins_changed.connect(func(_c): _refresh_ui())


func _min_zoom() -> float:
	return get_viewport_rect().size.x / (world_size.x + 300)


# ------------------------------------------------------------------ world building

func _build_props() -> void:
	for p in cfg.props:
		var s := Sprite2D.new()
		s.texture = load("res://assets/farm/%s.png" % p[0])
		s.position = Vector2(p[1], p[2])
		s.scale = Vector2.ONE * float(p[3])
		s.offset = Vector2(0, -s.texture.get_height() / 2.0 + 20)
		objects_root.add_child(s)
		if p[0] == "prop_tree" and GameManager.effects_high():
			var t := s.create_tween().set_loops()
			t.tween_property(s, "skew", 0.025, 2.0 + randf()).set_trans(Tween.TRANS_SINE)
			t.tween_property(s, "skew", -0.025, 2.0 + randf()).set_trans(Tween.TRANS_SINE)


func _build_paths() -> void:
	for c in paths_root.get_children():
		c.queue_free()
	var lvl := FarmProgression.level_of("paths")
	var tex: Texture2D = load(["res://assets/bg/path_dirt.png", "res://assets/bg/path_dirt.png", "res://assets/bg/path_stone.png"][lvl])
	for seg in cfg.paths:
		var pts := PackedVector2Array([Vector2(seg[0][0], seg[0][1]), Vector2(seg[1][0], seg[1][1])])
		var border := Line2D.new()
		border.points = pts
		border.width = 104 if lvl > 0 else 96
		border.default_color = [Color(0.55, 0.48, 0.3, 0.55), Color("b98a4a"), Color("8a8478")][lvl]
		border.begin_cap_mode = Line2D.LINE_CAP_ROUND
		border.end_cap_mode = Line2D.LINE_CAP_ROUND
		paths_root.add_child(border)
		var l := Line2D.new()
		l.points = pts
		l.width = 84
		l.texture = tex
		l.texture_mode = Line2D.LINE_TEXTURE_TILE
		l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		l.default_color = Color(1, 1, 1)
		if lvl == 0:
			l.modulate = Color(0.75, 0.72, 0.55, 0.7)
		paths_root.add_child(l)
		if lvl == 0:
			# Overgrown: grass tufts creeping over the trail.
			var a := pts[0]
			var b := pts[1]
			var n := int(a.distance_to(b) / 70.0)
			for i in n:
				var g := Sprite2D.new()
				g.texture = load("res://assets/farm/prop_grass.png")
				g.position = a.lerp(b, (i + 0.5) / n) + Vector2(randf_range(-30, 30), randf_range(-20, 20))
				g.scale = Vector2.ONE * randf_range(0.8, 1.3)
				paths_root.add_child(g)


func _build_objects() -> void:
	for o in FarmProgression.objects:
		var id: String = o.id
		match o.kind:
			"fence":
				_build_fence()
			"path":
				pass
			_:
				var s := Sprite2D.new()
				s.position = Vector2(o.pos[0], o.pos[1])
				s.scale = Vector2.ONE * float(o.scale)
				objects_root.add_child(s)
				sprites[id] = s
				if o.kind == "windmill":
					blades = Sprite2D.new()
					blades.texture = load("res://assets/farm/windmill_blades.png")
					blades.position = Vector2(0, -150)
					blades.z_index = 1
					s.add_child(blades)
					var t := blades.create_tween().set_loops()
					t.tween_property(blades, "rotation", TAU, 8.0).from(0.0)
				_apply_object_visual(id)


func _build_fence() -> void:
	var lvl := FarmProgression.level_of("fence")
	for c in objects_root.get_children():
		if c.has_meta("fence"):
			c.queue_free()
	var tex: Texture2D = load("res://assets/farm/fence_%d.png" % lvl)
	var x := 60.0
	var y := 960.0
	while x < 1560:
		if x > 690 and x < 900:
			x += 230
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.position = Vector2(x + 115, y)
		s.set_meta("fence", true)
		objects_root.add_child(s)
		x += 230


func _apply_object_visual(id: String) -> void:
	var o := FarmProgression.get_object(id)
	var s: Sprite2D = sprites.get(id)
	if s == null:
		return
	var lvl := FarmProgression.level_of(id)
	var tex_path: String = o.textures[lvl]
	for c in s.get_children():
		if c.has_meta("sign"):
			c.queue_free()
	var locked := not FarmProgression.is_unlocked(id)
	if tex_path == "" or (locked and o.kind != "sprite"):
		s.texture = load("res://assets/farm/prop_sign.png")
		var l := Label.new()
		l.text = ("После уровня %d" % int(o.requires_level)) if locked else o.name
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_constant_override("outline_size", 10)
		l.add_theme_color_override("font_outline_color", Color(0.3, 0.18, 0.05))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(320, 40)
		l.position = Vector2(-160, 110)
		l.set_meta("sign", true)
		s.add_child(l)
		if blades and s == sprites.get("windmill"):
			blades.visible = false
	else:
		s.texture = load(tex_path)
		if blades and id == "windmill":
			blades.visible = lvl >= 1
	s.modulate = Color(0.85, 0.85, 0.85) if locked else Color.WHITE
	_refresh_animals()


func _refresh_ground() -> void:
	var r := FarmProgression.progress_ratio()
	ground.modulate = Color(0.88, 0.8, 0.52).lerp(Color.WHITE, clampf(r * 1.4, 0.0, 1.0))


func _refresh_animals() -> void:
	if not is_inside_tree():
		return
	for c in objects_root.get_children():
		if c.has_meta("animal"):
			c.queue_free()
	if FarmProgression.level_of("barn") >= 1:
		for i in 3:
			_spawn_animal("animal_chicken", Rect2(960, 820, 440, 90), 0.8)
	if FarmProgression.level_of("barn") >= 3:
		_spawn_animal("animal_pig", Rect2(1300, 720, 160, 120), 0.8)
	if FarmProgression.level_of("pond") >= 2:
		for i in 2:
			_spawn_animal("animal_duck", Rect2(300, 1860, 220, 80), 0.75, false)
	if FarmProgression.level_of("pen") >= 1:
		_spawn_animal("animal_cow", Rect2(620, 2330, 200, 90), 0.75)
		_spawn_animal("animal_sheep", Rect2(820, 2330, 160, 90), 0.75)
		_spawn_animal("animal_sheep", Rect2(680, 2400, 200, 60), 0.7)
	if FarmProgression.level_of("orchard") >= 2:
		_spawn_animal("animal_chicken", Rect2(1000, 1300, 300, 60), 0.7)


func _spawn_animal(tex_name: String, area: Rect2, sc: float, bob := true) -> void:
	var a := Sprite2D.new()
	a.texture = load("res://assets/farm/%s.png" % tex_name)
	a.scale = Vector2.ONE * sc
	a.offset = Vector2(0, -a.texture.get_height() * 0.4)
	a.position = area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
	a.set_meta("animal", true)
	objects_root.add_child(a)
	_wander(a, area, bob)


func _wander(a: Sprite2D, area: Rect2, bob: bool) -> void:
	if not is_instance_valid(a) or not a.is_inside_tree():
		return
	var target := area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
	a.flip_h = target.x > a.position.x
	var d := a.position.distance_to(target)
	var t := a.create_tween()
	t.tween_interval(randf_range(0.5, 2.5))
	t.tween_property(a, "position", target, d / 60.0)
	if bob and GameManager.effects_high():
		var b := a.create_tween().set_loops(int(d / 25.0) + 1)
		b.tween_property(a, "offset:y", a.offset.y - 6, 0.12)
		b.tween_property(a, "offset:y", a.offset.y, 0.12)
	t.tween_callback(_wander.bind(a, area, bob))


func _refresh_markers() -> void:
	for c in markers_root.get_children():
		c.queue_free()
	for o in FarmProgression.objects:
		if not FarmProgression.can_upgrade(o.id):
			continue
		var m := Node2D.new()
		var pos := Vector2(o.pos[0], o.pos[1])
		if o.kind == "fence":
			pos = Vector2(240, 960)
		elif o.kind == "path":
			pos = Vector2(800, 1420)
		var s: Sprite2D = sprites.get(o.id)
		if s and s.texture:
			pos.y -= s.texture.get_height() * s.scale.y * 0.5 - 10
		m.position = pos
		var bubble := Sprite2D.new()
		bubble.texture = load("res://assets/fx/soft_circle.png")
		bubble.modulate = Color(1, 0.9, 0.3, 0.9)
		bubble.scale = Vector2.ONE * 1.5
		m.add_child(bubble)
		var ham := Sprite2D.new()
		ham.texture = load("res://assets/ui/icon_hammer.png")
		ham.modulate = Color("c2611a")
		ham.scale = Vector2.ONE * 0.5
		m.add_child(ham)
		markers_root.add_child(m)
		var t := m.create_tween().set_loops()
		t.tween_property(m, "position:y", pos.y - 16, 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(m, "position:y", pos.y, 0.5).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ input (pan, pinch, tap)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.has_dialog():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _over_ui(event.position):
				return
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_drag_dist = 0.0
			elif _touches.size() == 2:
				var p: Array = _touches.values()
				_pinch_start = (p[0] as Vector2).distance_to(p[1])
				_zoom_start = camera.zoom.x
		else:
			if not _touches.has(event.index):
				return
			if _touches.size() == 1 and _drag_dist < 18.0:
				_on_tap(get_canvas_transform().affine_inverse() * event.position)
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_drag_dist += event.relative.length()
			camera.position -= event.relative / camera.zoom
			_clamp_camera()
		elif _touches.size() == 2 and _pinch_start > 0.0:
			var p: Array = _touches.values()
			var d := (p[0] as Vector2).distance_to(p[1])
			_set_zoom(_zoom_start * d / _pinch_start)
			_drag_dist = 100.0
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(camera.zoom.x * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(camera.zoom.x / 1.1)


## True if a screen position is covered by the farm interface.
func _over_ui(p: Vector2) -> bool:
	if upgrades_panel and is_instance_valid(upgrades_panel):
		return true
	for c in [_bottom, info_panel, _coins_pill.get_parent().get_parent()]:
		if c and c.visible and c.get_global_rect().has_point(p):
			return true
	return false


func _set_zoom(z: float) -> void:
	z = clampf(z, _min_zoom(), 1.5)
	camera.zoom = Vector2(z, z)
	_clamp_camera()


func _clamp_camera() -> void:
	camera.position = camera.position.clamp(Vector2(100, 100), world_size - Vector2(100, 0))


func _on_tap(world_pos: Vector2) -> void:
	var best := ""
	var best_y := -INF
	for o in FarmProgression.objects:
		var r := _object_rect(o)
		if r.has_point(world_pos) and r.position.y + r.size.y > best_y:
			best = o.id
			best_y = r.position.y + r.size.y
	if best != "":
		select_object(best)
	else:
		select_object("")


func _object_rect(o: Dictionary) -> Rect2:
	match o.kind:
		"fence":
			return Rect2(40, 890, 1520, 130)
		"path":
			return Rect2(740, 880, 120, 1380)
	var s: Sprite2D = sprites.get(o.id)
	if s == null or s.texture == null:
		return Rect2()
	var sz := s.texture.get_size() * s.scale * 0.85
	return Rect2(s.position - sz / 2, sz)


func select_object(id: String, focus := false) -> void:
	if selected_id != "" and sprites.has(selected_id):
		sprites[selected_id].material = null
	selected_id = id
	if id == "":
		info_panel.visible = false
		return
	AudioManager.play("select")
	if sprites.has(id):
		var mat := ShaderMaterial.new()
		mat.shader = OUTLINE
		sprites[id].material = mat
		var t: Tween = sprites[id].create_tween().set_loops(3)
		t.tween_method(func(v): mat.set_shader_parameter("pulse", v), 1.0, 0.4, 0.3)
		t.tween_method(func(v): mat.set_shader_parameter("pulse", v), 0.4, 1.0, 0.3)
	if focus:
		var o := FarmProgression.get_object(id)
		camera.position = Vector2(o.pos[0], o.pos[1] + 120)
		_clamp_camera()
	_show_info(id)


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 16 + _safe.top
	top.offset_left = 20
	top.offset_right = -20
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var home := UIKit.round_button(load("res://assets/ui/icon_home.png"), UIKit.C_CORAL, 88)
	home.pressed.connect(func(): GameManager.goto("menu"))
	top.add_child(home)
	var title := UIKit.title_label("Моя ферма", 42, UIKit.C_GREEN_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var pills := VBoxContainer.new()
	pills.add_theme_constant_override("separation", 6)
	top.add_child(pills)
	_coins_pill = UIKit.counter_pill(load("res://assets/ui/coin.png"), "0")
	_stars_pill = UIKit.counter_pill(load("res://assets/ui/star.png"), "0")
	pills.add_child(_coins_pill)
	pills.add_child(_stars_pill)

	_bottom = HBoxContainer.new()
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_bottom = -18 - _safe.bottom
	_bottom.offset_top = -130 - _safe.bottom
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom.add_theme_constant_override("separation", 10)
	root.add_child(_bottom)
	var defs := [
		["Уровни", "icon_map", UIKit.C_ORANGE, func(): GameManager.goto("map")],
		["Улучшения", "icon_hammer", UIKit.C_GREEN, _toggle_upgrades],
		["Помощники", "icon_paw", UIKit.C_SKY, func(): GameManager.goto("helpers")],
		["Магазин", "icon_shop", UIKit.C_PURPLE, func(): GameManager.goto("shop")],
	]
	for d in defs:
		var b := _bottom_button(d[0], d[1], d[2])
		b.pressed.connect(d[3])
		_bottom.add_child(b)
		if d[0] == "Улучшения":
			_upgrade_badge = UIKit.badge(b, "0")
			_upgrade_badge.offset_left = -36
			_upgrade_badge.offset_top = -6

	info_panel = UIKit.card(UIKit.C_CREAM, 34)
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	info_panel.offset_left = 20
	info_panel.offset_right = -20
	info_panel.offset_bottom = -150 - _safe.bottom
	info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info_panel.visible = false
	root.add_child(info_panel)
	_refresh_ui()


func _bottom_button(text: String, icon_name: String, color: Color) -> Button:
	var b := UIKit.button("", color, Vector2(160, 112), 22)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", -2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var ic := UIKit.icon(load("res://assets/ui/%s.png" % icon_name), 50)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var l := UIKit.label(text, 22, Color.WHITE, 6, color.darkened(0.45))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	return b


func _refresh_ui() -> void:
	UIKit.set_pill_value(_coins_pill, str(EconomyManager.coins()))
	UIKit.set_pill_value(_stars_pill, str(LevelManager.total_stars()))
	var n := FarmProgression.available_upgrades()
	_upgrade_badge.visible = n > 0
	(_upgrade_badge.get_child(0) as Label).text = str(n)
	if selected_id != "" and info_panel.visible:
		_show_info(selected_id)


func _show_info(id: String) -> void:
	var o := FarmProgression.get_object(id)
	for c in info_panel.get_children():
		c.queue_free()
	info_panel.visible = true
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	info_panel.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	var lvl := FarmProgression.level_of(id)
	var maxl := FarmProgression.max_level(id)
	vb.add_child(UIKit.label(o.name, 32))
	vb.add_child(UIKit.label("%s  •  уровень %d из %d" % [o.levels[lvl], lvl, maxl], 22, UIKit.C_TEXT.lightened(0.2)))
	var cost := FarmProgression.next_cost(id)
	if o.kind == "reward":
		vb.add_child(UIKit.label("Награда за прохождение уровня %d" % int(o.requires_level), 24, UIKit.C_PURPLE.darkened(0.3)))
	elif cost < 0:
		vb.add_child(UIKit.label("Полностью восстановлено!", 24, UIKit.C_GREEN_DARK))
	elif not FarmProgression.is_unlocked(id):
		vb.add_child(UIKit.label("Участок откроется после уровня %d" % int(o.requires_level), 24, UIKit.C_CORAL.darkened(0.2)))
	else:
		vb.add_child(UIKit.label("Далее: %s" % o.levels[lvl + 1], 24, UIKit.C_GREEN_DARK))
		var b := UIKit.button("%d" % cost, UIKit.C_ORANGE if FarmProgression.can_upgrade(id) else UIKit.C_GREY,
			Vector2(200, 92), 34, load("res://assets/ui/coin.png"))
		b.add_theme_constant_override("icon_max_width", 46)
		b.disabled = not FarmProgression.can_upgrade(id)
		b.pressed.connect(func(): _do_upgrade(id))
		hb.add_child(b)
		if not FarmProgression.can_upgrade(id):
			vb.add_child(UIKit.label("Не хватает %d монет" % (cost - EconomyManager.coins()), 22, UIKit.C_CORAL.darkened(0.2)))
	var close := UIKit.round_button(load("res://assets/ui/icon_close.png"), UIKit.C_CORAL, 64)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func(): select_object(""))
	hb.add_child(close)


func _do_upgrade(id: String) -> void:
	if not FarmProgression.upgrade(id):
		AudioManager.play("invalid")
		GameManager.toast("Не хватает монет", UIKit.C_CORAL)


func _on_upgraded(id: String, lvl: int) -> void:
	var o := FarmProgression.get_object(id)
	var pos := Vector2(o.pos[0], o.pos[1])
	var s: Sprite2D = sprites.get(id)
	# Construction: dust clouds + hammer knocks, then the new look pops in.
	for i in 5:
		var puff := Sprite2D.new()
		puff.texture = load("res://assets/fx/puff.png")
		puff.position = pos + Vector2(randf_range(-160, 160), randf_range(-40, 120))
		puff.scale = Vector2.ONE * 0.4
		puff.modulate = Color(1, 0.97, 0.9, 0.95)
		puff.z_index = 5
		add_child(puff)
		var t := puff.create_tween().set_parallel(true)
		t.tween_property(puff, "scale", Vector2.ONE * randf_range(1.4, 2.2), 0.7).set_delay(i * 0.08)
		t.tween_property(puff, "modulate:a", 0.0, 0.7).set_delay(0.2 + i * 0.08)
		t.chain().tween_callback(puff.queue_free)
	for k in 3:
		get_tree().create_timer(k * 0.18).timeout.connect(func(): AudioManager.play("build_knock", 1.0 + k * 0.1))
	await get_tree().create_timer(0.45).timeout
	match o.kind:
		"fence":
			_build_fence()
		"path":
			_build_paths()
		_:
			_apply_object_visual(id)
			if s:
				var base := Vector2.ONE * float(o.scale)
				s.scale = base * 0.7
				var t := s.create_tween()
				t.tween_property(s, "scale", base * 1.08, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				t.tween_property(s, "scale", base, 0.15)
	AudioManager.play("build")
	_sparkles(pos)
	_refresh_ground()
	_refresh_animals()
	_refresh_markers()
	_refresh_ui()
	if o.kind != "reward":
		GameManager.toast("%s: %s!" % [o.name, o.levels[lvl]], UIKit.C_GREEN)


func _sparkles(pos: Vector2) -> void:
	if not GameManager.effects_high():
		return
	var p := CPUParticles2D.new()
	p.texture = load("res://assets/fx/sparkle.png")
	p.position = pos
	p.amount = 24
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 0.9
	p.spread = 180
	p.gravity = Vector2(0, 300)
	p.initial_velocity_min = 200
	p.initial_velocity_max = 420
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	p.color = Color(1, 0.92, 0.4)
	p.z_index = 6
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _toggle_upgrades() -> void:
	if upgrades_panel and is_instance_valid(upgrades_panel):
		upgrades_panel.queue_free()
		upgrades_panel = null
		return
	select_object("")
	upgrades_panel = UIKit.card(UIKit.C_CREAM, 36)
	upgrades_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrades_panel.offset_top = 150 + _safe.top
	upgrades_panel.offset_bottom = -150 - _safe.bottom
	upgrades_panel.offset_left = 20
	upgrades_panel.offset_right = -20
	ui.get_child(0).add_child(upgrades_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	upgrades_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := UIKit.title_label("Улучшения", 40, UIKit.C_GREEN_DARK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := UIKit.round_button(load("res://assets/ui/icon_close.png"), UIKit.C_CORAL, 70)
	close.pressed.connect(_toggle_upgrades)
	head.add_child(close)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	sc.add_child(list)
	for o in FarmProgression.objects:
		if o.kind == "reward" and FarmProgression.level_of(o.id) == 0:
			continue
		list.add_child(_upgrade_row(o))
	UIKit.pop_in(upgrades_panel)


func _upgrade_row(o: Dictionary) -> Control:
	var id: String = o.id
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIKit.style(Color(1, 1, 1, 0.75), 24, 0, Color.TRANSPARENT, 0))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	row.add_child(hb)
	var lvl := FarmProgression.level_of(id)
	var next_tex: String = o.textures[mini(lvl + 1, o.textures.size() - 1)]
	if next_tex == "":
		next_tex = "res://assets/farm/prop_sign.png"
	hb.add_child(UIKit.icon(load(next_tex), 96))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	vb.add_child(UIKit.label(o.name, 28))
	var stars := HBoxContainer.new()
	for k in FarmProgression.max_level(id):
		stars.add_child(UIKit.icon(load("res://assets/ui/star.png" if k < lvl else "res://assets/ui/star_empty.png"), 28))
	vb.add_child(stars)
	var cost := FarmProgression.next_cost(id)
	if cost < 0:
		vb.add_child(UIKit.label("Готово!", 22, UIKit.C_GREEN_DARK))
	elif not FarmProgression.is_unlocked(id):
		vb.add_child(UIKit.label("После уровня %d" % int(o.requires_level), 22, UIKit.C_CORAL.darkened(0.2)))
	else:
		vb.add_child(UIKit.label("Далее: %s" % o.levels[lvl + 1], 22, UIKit.C_TEXT.lightened(0.2)))
	var show := UIKit.button("", UIKit.C_SKY, Vector2(84, 84), 20)
	show.icon = load("res://assets/ui/icon_map.png")
	show.expand_icon = true
	show.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	show.pressed.connect(func():
		_toggle_upgrades()
		select_object(id, true))
	hb.add_child(show)
	if cost >= 0 and FarmProgression.is_unlocked(id):
		var b := UIKit.button(str(cost), UIKit.C_ORANGE if FarmProgression.can_upgrade(id) else UIKit.C_GREY,
			Vector2(150, 84), 28, load("res://assets/ui/coin.png"))
		b.add_theme_constant_override("icon_max_width", 40)
		b.disabled = not FarmProgression.can_upgrade(id)
		b.pressed.connect(func():
			_toggle_upgrades()
			select_object(id, true)
			_do_upgrade(id))
		hb.add_child(b)
	return row


func on_back() -> void:
	if upgrades_panel and is_instance_valid(upgrades_panel):
		_toggle_upgrades()
	elif selected_id != "":
		select_object("")
	else:
		GameManager.goto("menu")
