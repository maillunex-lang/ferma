extends Control
## Win / lose screen: animated stars, coin shower, rewards summary.

var res: Dictionary
var _coins_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	res = LevelManager.last_result
	if res.is_empty():
		res = {"level_id": 1, "won": false, "stars": 0, "coins": 0, "bonus_coins": 0, "helpers": {}, "moves_left": 0}
	var level := LevelManager.get_level(int(res.level_id))
	var bg := TextureRect.new()
	bg.texture = load("res://assets/bg/menu.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.2, 0.05, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	if res.won:
		_sunburst()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := UIKit.card(UIKit.C_CREAM, 44)
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	card.add_child(vb)
	vb.add_child(UIKit.title_label("Победа!" if res.won else "Не получилось", 64,
		UIKit.C_GREEN_DARK if res.won else UIKit.C_CORAL.darkened(0.3)))
	var sub := UIKit.label("Уровень %d — %s" % [int(res.level_id), level.get("name", "")], 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 10)
	stars_row.custom_minimum_size.y = 150
	vb.add_child(stars_row)
	var stars_nodes := []
	for i in 3:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(140, 140)
		stars_row.add_child(holder)
		var empty := UIKit.icon(load("res://assets/ui/star_empty.png"), 130 if i == 1 else 110)
		empty.position = Vector2(5, 0 if i == 1 else 20)
		holder.add_child(empty)
		var full := UIKit.icon(load("res://assets/ui/star.png"), 130 if i == 1 else 110)
		full.position = empty.position
		full.pivot_offset = full.custom_minimum_size / 2
		full.visible = false
		holder.add_child(full)
		stars_nodes.append(full)

	if res.won:
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 8)
		vb.add_child(info)
		var coin_row := HBoxContainer.new()
		coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
		coin_row.add_theme_constant_override("separation", 10)
		info.add_child(coin_row)
		coin_row.add_child(UIKit.icon(load("res://assets/ui/coin.png"), 64))
		_coins_label = UIKit.title_label("+0", 52, Color("b86a00"))
		coin_row.add_child(_coins_label)
		var detail := UIKit.label("Награда: %d  •  Бонус за %d ходов: %d" % [int(res.coins), int(res.moves_left), int(res.bonus_coins)], 24)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_child(detail)
		if not res.first_clear:
			var rp := UIKit.label("Повторное прохождение: уменьшенная награда", 22, UIKit.C_TEXT.lightened(0.3))
			rp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			info.add_child(rp)
		if not res.helpers.is_empty():
			var hl := UIKit.label("Новые заряды помощников:", 26, UIKit.C_GREEN_DARK)
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			info.add_child(hl)
			var hrow := HBoxContainer.new()
			hrow.alignment = BoxContainer.ALIGNMENT_CENTER
			hrow.add_theme_constant_override("separation", 18)
			info.add_child(hrow)
			for h in res.helpers:
				var box := VBoxContainer.new()
				box.add_child(UIKit.icon(HelperManager.icon(h), 96))
				var l := UIKit.label("+%d" % int(res.helpers[h]), 30, UIKit.C_ORANGE.darkened(0.2))
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				box.add_child(l)
				hrow.add_child(box)
				UIKit.pop_in(box, 1.2)
		if res.get("unlock", "") != "":
			var ul := UIKit.label("Новый декор фермы: Праздничное пугало!", 28, UIKit.C_PURPLE.darkened(0.2))
			ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			info.add_child(ul)
		if res.stars < 3:
			var extra: Dictionary = level.stars.extra
			var tip := UIKit.label("Для 3 звёзд: оставь %d ходов и %s." % [int(level.stars.three), extra.text.to_lower()], 22, UIKit.C_TEXT.lightened(0.2))
			tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tip.custom_minimum_size.x = 540
			info.add_child(tip)
	else:
		var l := UIKit.label("Ходы закончились. Попробуй ещё раз — ферма ждёт!", 28)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 540
		vb.add_child(l)
		var helper_tip := UIKit.label("Подсказка: помощники не тратят ходы, а Пчёлка Жужа добавляет 3 хода.", 24, UIKit.C_GREEN_DARK)
		helper_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		helper_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		helper_tip.custom_minimum_size.x = 540
		vb.add_child(helper_tip)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	vb.add_child(buttons)
	var id := int(res.level_id)
	if res.won and id < LevelManager.count():
		var nb := UIKit.button("Следующий уровень", UIKit.C_ORANGE, Vector2(520, 100), 36)
		nb.pressed.connect(func(): GameManager.play_level(id + 1))
		buttons.add_child(nb)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	buttons.add_child(row)
	var again := UIKit.button("Ещё раз", UIKit.C_SKY, Vector2(250, 90), 30, load("res://assets/ui/icon_refresh.png"))
	again.pressed.connect(func(): GameManager.play_level(id))
	row.add_child(again)
	var farm := UIKit.button("На ферму", UIKit.C_GREEN, Vector2(250, 90), 30, load("res://assets/ui/icon_home.png"))
	farm.pressed.connect(func(): GameManager.goto("farm"))
	row.add_child(farm)
	card.pivot_offset = Vector2(310, 400)
	UIKit.pop_in(card)
	_helper_reaction(card)

	if res.won:
		AudioManager.play_music("menu")
		_animate_rewards(stars_nodes)
	else:
		AudioManager.play("lose")


func _animate_rewards(stars_nodes: Array) -> void:
	await get_tree().create_timer(0.45).timeout
	for i in int(res.stars):
		var s: Control = stars_nodes[i]
		s.visible = true
		s.scale = Vector2(2.2, 2.2)
		s.modulate.a = 0.0
		var t := s.create_tween().set_parallel(true)
		t.tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "modulate:a", 1.0, 0.2)
		AudioManager.play("star", 1.0 + i * 0.15)
		await get_tree().create_timer(0.38).timeout
	var total := int(res.coins) + int(res.bonus_coins)
	_coin_shower(mini(24, 6 + total / 25))
	var steps := 20
	for k in steps + 1:
		_coins_label.text = "+%d" % int(round(float(total) * k / steps))
		if k % 3 == 0:
			AudioManager.play("coin", 1.0 + k * 0.01)
		await get_tree().create_timer(0.04).timeout


func _coin_shower(n: int) -> void:
	var tex: Texture2D = load("res://assets/ui/coin.png")
	for i in n:
		var c := Sprite2D.new()
		c.texture = tex
		c.scale = Vector2.ONE * randf_range(0.4, 0.65)
		c.position = Vector2(randf_range(40, get_viewport_rect().size.x - 40), -60 - randf() * 300)
		add_child(c)
		var t := c.create_tween()
		t.tween_property(c, "position:y", get_viewport_rect().size.y + 80, randf_range(1.1, 1.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(c, "rotation", randf_range(-6, 6), 1.6)
		t.tween_callback(c.queue_free)


## A helper friend cheers (win) or comforts the player (loss).
func _helper_reaction(card: Control) -> void:
	var order: Array = HelperManager.order
	var h: String = order[int(res.level_id) % order.size()]
	var img := UIKit.icon(HelperManager.icon(h), 170)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(img)
	await get_tree().process_frame
	img.position = card.global_position + Vector2(card.size.x - 150, -120)
	img.pivot_offset = Vector2(85, 170)
	var t := img.create_tween().set_loops()
	if res.won:
		t.tween_property(img, "position:y", img.position.y - 34, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(img, "position:y", img.position.y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_interval(0.35)
		AudioManager.play(HelperManager.defs[h].sfx)
	else:
		img.modulate = Color(0.92, 0.92, 1.0)
		t.tween_property(img, "rotation", 0.12, 0.9).set_trans(Tween.TRANS_SINE)
		t.tween_property(img, "rotation", -0.12, 0.9).set_trans(Tween.TRANS_SINE)


func _sunburst() -> void:
	var rays := Node2D.new()
	var vs := get_viewport_rect().size
	rays.position = Vector2(vs.x / 2, vs.y * 0.32)
	add_child(rays)
	for i in 12:
		var poly := Polygon2D.new()
		var a := i * TAU / 12
		poly.polygon = PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a) * 1400, Vector2.from_angle(a + 0.22) * 1400])
		poly.color = Color(1, 1, 0.8, 0.18)
		rays.add_child(poly)
	var t := rays.create_tween().set_loops()
	t.tween_property(rays, "rotation", TAU, 30.0).from(0.0)


func on_back() -> void:
	GameManager.goto("map")
