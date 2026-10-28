extends Control
## Title screen: logo, coin counter, 10-level progress, main navigation.

var _helpers_badge_parent: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("menu")
	var bg := TextureRect.new()
	bg.texture = load("res://assets/bg/menu.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var safe := GameManager.safe_margins()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 18 + safe.top
	root.offset_bottom = -24 - safe.bottom
	root.offset_left = 24
	root.offset_right = -24
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	var stars_pill := UIKit.counter_pill(load("res://assets/ui/star.png"), "%d/30" % LevelManager.total_stars())
	top.add_child(stars_pill)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var coins := UIKit.counter_pill(load("res://assets/ui/coin.png"), str(EconomyManager.coins()))
	top.add_child(coins)

	var logo_box := VBoxContainer.new()
	logo_box.add_theme_constant_override("separation", -26)
	root.add_child(logo_box)
	var l1 := UIKit.title_label("Солнечная", 92, Color("e0661a"))
	var l2 := UIKit.title_label("ферма", 104, Color("3a9a22"))
	logo_box.add_child(l1)
	logo_box.add_child(l2)
	l2.rotation_degrees = -3
	l2.pivot_offset = Vector2(336, 60)
	logo_box.pivot_offset = Vector2(336, 110)
	var t := logo_box.create_tween().set_loops()
	t.tween_property(logo_box, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(logo_box, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)

	# Helper friends hopping on the hill.
	var friends := HBoxContainer.new()
	friends.alignment = BoxContainer.ALIGNMENT_CENTER
	friends.add_theme_constant_override("separation", 6)
	friends.custom_minimum_size.y = 170
	root.add_child(friends)
	var i := 0
	for h in HelperManager.order:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(150, 160)
		friends.add_child(holder)
		var img := UIKit.icon(HelperManager.icon(h), 150)
		holder.add_child(img)
		img.pivot_offset = Vector2(75, 150)
		var ht := img.create_tween().set_loops()
		ht.tween_interval(i * 0.25)
		ht.tween_property(img, "position:y", -18.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ht.tween_property(img, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ht.tween_interval(1.4 - i * 0.25)
		i += 1

	# Progress over the 10 levels.
	var prog_card := UIKit.card(Color(1, 1, 1, 0.82), 30)
	root.add_child(prog_card)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	prog_card.add_child(pv)
	var done := LevelManager.completed_count()
	var pl := UIKit.label("Пройдено уровней: %d из %d" % [done, LevelManager.count()], 28)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pl)
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 6)
	pv.add_child(dots)
	for lv in LevelManager.levels:
		var id := int(lv.id)
		var tex := "res://assets/ui/star.png" if LevelManager.is_completed(id) else "res://assets/ui/star_empty.png"
		var d := UIKit.icon(load(tex), 50)
		if id == LevelManager.next_level_id() and not LevelManager.is_completed(id):
			d.pivot_offset = Vector2(25, 25)
			UIKit.pulse(d, 0.2, 0.8)
		dots.add_child(d)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(buttons)
	var play := UIKit.button("Играть", UIKit.C_ORANGE, Vector2(520, 124), 54, load("res://assets/ui/icon_play.png"))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func(): GameManager.goto("map"))
	buttons.add_child(play)
	play.ready.connect(func():
		play.pivot_offset = play.size / 2
		UIKit.pulse(play, 0.04, 1.2))
	var farm := UIKit.button("Моя ферма", UIKit.C_GREEN, Vector2(520, 104), 40, load("res://assets/ui/icon_home.png"))
	farm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	farm.pressed.connect(func(): GameManager.goto("farm"))
	buttons.add_child(farm)
	if FarmProgression.available_upgrades() > 0:
		UIKit.badge(farm, "!")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	buttons.add_child(row)
	var helpers := UIKit.button("Помощники", UIKit.C_SKY, Vector2(330, 96), 32, load("res://assets/ui/icon_paw.png"))
	helpers.pressed.connect(func(): GameManager.goto("helpers"))
	row.add_child(helpers)
	if AchievementManager.claimable_count() > 0:
		UIKit.badge(helpers, str(AchievementManager.claimable_count()))
	var settings := UIKit.button("Настройки", UIKit.C_PURPLE, Vector2(330, 96), 32, load("res://assets/ui/icon_gear.png"))
	settings.pressed.connect(func(): GameManager.goto("settings"))
	row.add_child(settings)

	if SaveManager.load_source == "backup":
		SaveManager.load_source = "backup_notified"
		GameManager.toast.call_deferred("Сохранение восстановлено из резервной копии", UIKit.C_SKY)


func on_back() -> void:
	GameManager.confirm_exit()
