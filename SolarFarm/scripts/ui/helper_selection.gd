extends ScreenBase
## «Помощники»: helper gallery with abilities and charges, plus first-steps
## tasks whose rewards are new helper charges.

var _task_box: VBoxContainer
var _charge_labels := {}


func _init() -> void:
	title_text = "Помощники"
	back_target = "menu"


func build() -> void:
	AudioManager.play_music("farm")
	if GameManager.previous_scene_name in ["farm", "menu"]:
		back_target = GameManager.previous_scene_name
	var intro := UIKit.label("Помощников мало — используй их с умом! Они не тратят ходы. Новые заряды дают уровни, три звезды и задания.", 24)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	for h in HelperManager.order:
		grid.add_child(_helper_card(h))
	var shop := UIKit.button("Магазин помощников", UIKit.C_SKY, Vector2(0, 92), 32, load("res://assets/ui/icon_shop.png"))
	shop.pressed.connect(func(): GameManager.goto("shop"))
	content.add_child(shop)
	content.add_child(UIKit.title_label("Задания", 44, UIKit.C_GREEN_DARK))
	_task_box = VBoxContainer.new()
	_task_box.add_theme_constant_override("separation", 12)
	content.add_child(_task_box)
	_build_tasks()
	HelperManager.charges_changed.connect(func(id, c):
		if _charge_labels.has(id):
			_charge_labels[id].text = "Заряды: %d" % c)


func _helper_card(h: String) -> Control:
	var def: Dictionary = HelperManager.defs[h]
	var card := UIKit.card(UIKit.C_CREAM, 32)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)
	var ic := UIKit.icon(HelperManager.icon(h), 150)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var name_l := UIKit.label(def.name, 27, Color(def.color).darkened(0.35))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(name_l)
	var d := UIKit.label(def.description, 21)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size = Vector2(250, 0)
	vb.add_child(d)
	var c := UIKit.label("Заряды: %d" % HelperManager.charges(h), 26, UIKit.C_ORANGE.darkened(0.25))
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(c)
	_charge_labels[h] = c
	return card


func _build_tasks() -> void:
	for c in _task_box.get_children():
		c.queue_free()
	for t in AchievementManager.tasks:
		_task_box.add_child(_task_row(t))


func _task_row(t: Dictionary) -> Control:
	var done := AchievementManager.is_done(t)
	var claimed := AchievementManager.is_claimed(t)
	var card := UIKit.card(Color("eaf7d8") if done else UIKit.C_CREAM, 28)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	card.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	vb.add_child(UIKit.label(t.title, 28))
	var tl := UIKit.label(t.text, 22, UIKit.C_TEXT.lightened(0.2))
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(tl)
	var bar := ProgressBar.new()
	bar.max_value = int(t.target)
	bar.value = AchievementManager.progress(t)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	bar.add_theme_stylebox_override("background", UIKit.style(UIKit.C_CREAM_DARK, 11, 0, Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", UIKit.style(UIKit.C_GREEN, 11, 0, Color.TRANSPARENT, 0))
	vb.add_child(bar)
	var reward := HBoxContainer.new()
	reward.add_theme_constant_override("separation", 6)
	vb.add_child(reward)
	reward.add_child(UIKit.label("Награда:", 22, UIKit.C_TEXT.lightened(0.2)))
	if t.reward.has("coins"):
		reward.add_child(UIKit.icon(load("res://assets/ui/coin.png"), 34))
		reward.add_child(UIKit.label(str(int(t.reward.coins)), 22))
	for h in t.reward.get("helpers", {}):
		reward.add_child(UIKit.icon(HelperManager.icon(h), 40))
		reward.add_child(UIKit.label("+%d" % int(t.reward.helpers[h]), 22))
	if claimed:
		var ok := UIKit.icon(load("res://assets/ui/icon_check.png"), 64)
		ok.modulate = UIKit.C_GREEN
		hb.add_child(ok)
	else:
		var b := UIKit.button("Забрать" if done else "%d/%d" % [AchievementManager.progress(t), int(t.target)],
			UIKit.C_ORANGE if done else UIKit.C_GREY, Vector2(170, 80), 26)
		b.disabled = not done
		b.pressed.connect(func():
			b.disabled = true
			var r := AchievementManager.claim(t.id)
			if not r.is_empty():
				AudioManager.play("purchase")
				GameManager.toast("Награда получена!", UIKit.C_GREEN)
				_build_tasks())
		hb.add_child(b)
	return card
