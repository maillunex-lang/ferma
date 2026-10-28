class_name ScreenBase
extends Control
## Common layout for menu-like screens: sunny background, safe-area aware
## top bar (back button, title, coin counter) and a scrollable content column.

var top_bar: HBoxContainer
var content: VBoxContainer
var scroll: ScrollContainer
var coin_pill: PanelContainer
var title_text := ""
var back_target := "menu"
var background_path := "res://assets/bg/puzzle.png"
var use_scroll := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load(background_path)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var safe := GameManager.safe_margins()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 16 + safe.top
	root.offset_bottom = -16 - safe.bottom
	root.offset_left = 20 + safe.left
	root.offset_right = -20 - safe.right
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	root.add_child(top_bar)
	var back := UIKit.round_button(load("res://assets/ui/icon_back.png"), UIKit.C_CORAL, 88)
	back.pressed.connect(on_back)
	top_bar.add_child(back)
	var title := UIKit.title_label(title_text, 46)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)
	coin_pill = UIKit.counter_pill(load("res://assets/ui/coin.png"), str(EconomyManager.coins()))
	coin_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(coin_pill)
	EconomyManager.coins_changed.connect(_on_coins)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if use_scroll:
		scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		root.add_child(scroll)
		scroll.add_child(content)
	else:
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(content)
	build()


func _on_coins(c: int) -> void:
	UIKit.set_pill_value(coin_pill, str(c))


## Override in subclasses to fill `content`.
func build() -> void:
	pass


func on_back() -> void:
	AudioManager.play("back")
	GameManager.goto(back_target)
