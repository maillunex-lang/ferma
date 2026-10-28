extends ScreenBase
## Settings: separate music / sound volume, effects quality, FPS limit,
## hints, progress reset and asset credits.


func _init() -> void:
	title_text = "Настройки"
	back_target = "menu"


func build() -> void:
	var s: Dictionary = SaveManager.data.settings
	var card := UIKit.card(UIKit.C_CREAM, 34)
	content.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	card.add_child(vb)
	vb.add_child(_slider_row("Музыка", "res://assets/ui/icon_music.png", "music"))
	vb.add_child(_slider_row("Звуки", "res://assets/ui/icon_sound.png", "sfx"))
	vb.add_child(_choice_row("Эффекты", "effects", [["high", "Полные"], ["low", "Простые"]],
		"Простые эффекты отключают частицы и тряску — для слабых устройств."))
	vb.add_child(_choice_row("Частота кадров", "fps", [[60, "60 FPS"], [30, "30 FPS"]], "30 FPS экономит батарею."))
	vb.add_child(_choice_row("Подсказки ходов", "hints", [[true, "Вкл"], [false, "Выкл"]], ""))

	var about := UIKit.card(UIKit.C_CREAM, 34)
	content.add_child(about)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 10)
	about.add_child(av)
	av.add_child(UIKit.label("Об игре", 32))
	var txt := UIKit.label("«Солнечная ферма» v%s. Игра работает полностью офлайн: без рекламы, аналитики, аккаунтов и сетевых запросов. Прогресс хранится только на этом устройстве.\n\nГрафика игры нарисована специально для проекта. Звуки и музыка — Kenney.nl, OpenGameArt (CC0). Шрифт Nunito (SIL OFL 1.1). Подробности — в файле ASSETS_LICENSES.md." % ProjectSettings.get_setting("application/config/version"), 22, UIKit.C_TEXT.lightened(0.15))
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	av.add_child(txt)
	var reset := UIKit.button("Сбросить прогресс", UIKit.C_CORAL, Vector2(0, 84), 28)
	reset.pressed.connect(_confirm_reset)
	content.add_child(reset)


func _slider_row(title: String, icon_path: String, key: String) -> Control:
	var s: Dictionary = SaveManager.data.settings
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var ic := UIKit.icon(load(icon_path), 54)
	ic.modulate = UIKit.C_TEXT
	hb.add_child(ic)
	var l := UIKit.label(title, 30)
	l.custom_minimum_size.x = 150
	hb.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(s.get(key, 0.8))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.custom_minimum_size.y = 50
	sl.value_changed.connect(func(v):
		s[key] = v
		AudioManager.apply_volumes())
	sl.drag_ended.connect(func(_c):
		SaveManager.save_game()
		if key == "sfx":
			AudioManager.play("coin"))
	hb.add_child(sl)
	return hb


func _choice_row(title: String, key: String, options: Array, hint: String) -> Control:
	var s: Dictionary = SaveManager.data.settings
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	var l := UIKit.label(title, 30)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var buttons := []
	for o in options:
		var b := UIKit.button(o[1], UIKit.C_GREEN, Vector2(150, 70), 24)
		hb.add_child(b)
		buttons.append(b)
	var update := func():
		for i in options.size():
			var on: bool = str(s.get(key)) == str(options[i][0])
			var c := UIKit.C_GREEN if on else UIKit.C_GREY
			for k in ["normal", "hover", "pressed"]:
				(buttons[i].get_theme_stylebox(k) as StyleBoxFlat).bg_color = c
	for i in options.size():
		var val = options[i][0]
		buttons[i].pressed.connect(func():
			s[key] = val
			SaveManager.save_game()
			GameManager.apply_settings()
			update.call())
	update.call()
	if hint != "":
		var hl := UIKit.label(hint, 20, UIKit.C_TEXT.lightened(0.3))
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(hl)
	return vb


func _confirm_reset() -> void:
	GameManager.show_dialog("Сбросить прогресс?", "Уровни, монеты, заряды помощников и ферма вернутся к началу. Это действие нельзя отменить.", [
		{"text": "Отмена", "color": UIKit.C_GREEN},
		{"text": "Сбросить", "color": UIKit.C_CORAL, "callback": func():
			SaveManager.reset_progress()
			GameManager.toast("Прогресс сброшен", UIKit.C_CORAL)
			GameManager.goto("menu")},
	])
