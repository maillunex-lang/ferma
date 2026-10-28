class_name UIKit
extends RefCounted
## Shared look & feel: palette, fonts, rounded "3D" buttons, cards, labels
## and small animation helpers. All UI is built from these pieces so every
## screen shares one consistent sunny style.

const C_GREEN := Color("5cc93b")
const C_GREEN_DARK := Color("3a9a22")
const C_YELLOW := Color("ffc93c")
const C_SKY := Color("4fc3f7")
const C_CORAL := Color("ff6f61")
const C_ORANGE := Color("ff9f1c")
const C_CREAM := Color("fff6e0")
const C_CREAM_DARK := Color("f2deb0")
const C_TEXT := Color("5a3a1a")
const C_PURPLE := Color("b06cff")
const C_GREY := Color("b8b2a6")

const FONT_BOLD := "res://assets/fonts/Nunito-ExtraBold.ttf"
const FONT_BLACK := "res://assets/fonts/Nunito-Black.ttf"


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load(FONT_BOLD)
	t.default_font_size = 30
	t.set_color("font_color", "Label", C_TEXT)
	var empty := StyleBoxEmpty.new()
	t.set_stylebox("focus", "Button", empty)
	t.set_stylebox("panel", "PanelContainer", style(C_CREAM, 32))
	# Scrollbars: slim and rounded.
	var grab := style(Color(0.35, 0.25, 0.1, 0.35), 8, 0, Color.TRANSPARENT, 0)
	grab.content_margin_left = 6
	grab.content_margin_right = 6
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", empty)
	# Sliders
	var track := style(C_CREAM_DARK, 12, 0, Color.TRANSPARENT, 0)
	track.content_margin_top = 10
	track.content_margin_bottom = 10
	t.set_stylebox("slider", "HSlider", track)
	var fill := style(C_GREEN, 12, 0, Color.TRANSPARENT, 0)
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _circle_icon(44, C_YELLOW))
	t.set_icon("grabber_highlight", "HSlider", _circle_icon(48, C_YELLOW.lightened(0.2)))
	return t


static func _circle_icon(d: int, c: Color) -> Texture2D:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for x in d:
		for y in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if dist <= r - 0.5:
				var col := c if dist < r - 5 else c.darkened(0.35)
				img.set_pixel(x, y, col)
			elif dist <= r + 0.5:
				img.set_pixel(x, y, Color(c.darkened(0.35), r + 0.5 - dist))
	return ImageTexture.create_from_image(img)


static func style(color: Color, radius: int = 24, border: int = 0, border_color: Color = Color.TRANSPARENT,
		shadow: int = 6, bottom: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	if bottom > 0:
		s.border_width_bottom = bottom
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 14
	s.content_margin_bottom = 14 + bottom
	if shadow > 0:
		s.shadow_color = Color(0.25, 0.17, 0.05, 0.28)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.6)
	s.anti_aliasing = true
	return s


static func button(text: String, color: Color = C_GREEN, min_size: Vector2 = Vector2(280, 96), font_size: int = 34,
		icon_tex: Texture2D = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", load(FONT_BLACK))
	b.add_theme_font_size_override("font_size", font_size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
	b.add_theme_color_override("font_outline_color", color.darkened(0.45))
	b.add_theme_constant_override("outline_size", 8)
	var dark := color.darkened(0.3)
	b.add_theme_stylebox_override("normal", style(color, 30, 4, color.lightened(0.25), 6, 10))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.08), 30, 4, color.lightened(0.3), 6, 10))
	var pressed := style(color.darkened(0.08), 30, 4, color.lightened(0.15), 2, 4)
	pressed.content_margin_top = 20
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", style(C_GREY, 30, 4, C_GREY.lightened(0.25), 4, 10))
	var n: StyleBoxFlat = b.get_theme_stylebox("normal")
	n.border_color = color.lightened(0.25)
	n.border_width_bottom = 10
	n.border_color = dark
	for k in ["normal", "hover", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(k)
		sb.border_width_left = 0
		sb.border_width_right = 0
		sb.border_width_top = 0
		sb.border_color = dark if k != "disabled" else C_GREY.darkened(0.3)
	var ps: StyleBoxFlat = b.get_theme_stylebox("pressed")
	ps.border_width_left = 0
	ps.border_width_right = 0
	ps.border_width_top = 0
	ps.border_color = dark
	if icon_tex:
		b.icon = icon_tex
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", int(font_size * 1.4))
		b.add_theme_constant_override("h_separation", 12)
	b.button_down.connect(func():
		b.pivot_offset = b.size / 2.0
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(0.94, 0.94), 0.06))
	b.button_up.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.pressed.connect(func(): AudioManager.play("click"))
	return b


## Round icon button (pause, settings, back, ...).
static func round_button(icon_tex: Texture2D, color: Color = C_SKY, d: int = 96) -> Button:
	var b := button("", color, Vector2(d, d), 20)
	for k in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(k)
		sb.set_corner_radius_all(d / 2)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 8 if k != "pressed" else 2
	b.icon = icon_tex
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(d * 0.5))
	return b


static func label(text: String, size: int = 30, color: Color = C_TEXT, outline: int = 0,
		outline_color: Color = Color(0, 0, 0, 0.5)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	return l


## Big chunky title: white text with a coloured outline and a soft shadow.
static func title_label(text: String, size: int = 52, outline_color: Color = Color("c2611a")) -> Label:
	var l := label(text, size, Color.WHITE, 14, outline_color)
	l.add_theme_font_override("font", load(FONT_BLACK))
	l.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.0, 0.35))
	l.add_theme_constant_override("shadow_offset_y", 5)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func card(color: Color = C_CREAM, radius: int = 36) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(color, radius, 6, color.darkened(0.12), 10)
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 26
	s.content_margin_bottom = 30
	p.add_theme_stylebox_override("panel", s)
	return p


static func icon(tex: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Pill showing a resource counter (coins / stars).
static func counter_pill(tex: Texture2D, value: String, color: Color = Color(0.25, 0.15, 0.05, 0.35)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(color, 30, 0, Color.TRANSPARENT, 0)
	s.content_margin_left = 10
	s.content_margin_right = 22
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	p.add_child(hb)
	hb.add_child(icon(tex, 52))
	var l := label(value, 32, Color.WHITE, 8, Color(0.3, 0.18, 0.05))
	l.name = "Value"
	hb.add_child(l)
	return p


static func set_pill_value(pill: Control, value: String) -> void:
	var l: Label = pill.find_child("Value", true, false)
	if l:
		l.text = value


static func pop_in(node: CanvasItem, delay: float = 0.0) -> void:
	node.scale = Vector2(0.6, 0.6)
	node.modulate.a = 0.0
	var t := node.create_tween().set_parallel(true)
	t.tween_property(node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(node, "modulate:a", 1.0, 0.2).set_delay(delay)


static func pulse(node: CanvasItem, amount: float = 0.06, period: float = 0.9) -> Tween:
	var t := node.create_tween().set_loops()
	t.tween_property(node, "scale", Vector2.ONE * (1.0 + amount), period / 2).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2.ONE, period / 2).set_trans(Tween.TRANS_SINE)
	return t


## Small red badge with a number/mark, placed at the top-right of `parent`.
static func badge(parent: Control, text: String) -> Control:
	var p := PanelContainer.new()
	var s := style(C_CORAL, 22, 3, Color.WHITE, 2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 0
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, 24, Color.WHITE, 4, C_CORAL.darkened(0.4))
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.name = "Badge"
	parent.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.position = Vector2(-26, -14)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -30
	p.offset_top = -14
	return p
