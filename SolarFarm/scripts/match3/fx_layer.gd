class_name FxLayer
extends Node2D
## Pooled particle bursts and short-lived effect sprites for the board.
## Everything here is skipped or simplified when "effects" are set to low.

const POOL_SIZE := 14

var high_quality := true
var _pool: Array[CPUParticles2D] = []
var _next := 0
var _sparkle: Texture2D
var _circle: Texture2D
var _leaf: Texture2D


func _ready() -> void:
	high_quality = GameManager.effects_high()
	_sparkle = load("res://assets/fx/sparkle.png")
	_circle = load("res://assets/fx/soft_circle.png")
	_leaf = load("res://assets/fx/leaf.png")
	if not high_quality:
		return
	for i in POOL_SIZE:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 10
		p.lifetime = 0.55
		p.texture = _sparkle
		p.spread = 180.0
		p.gravity = Vector2(0, 600)
		p.initial_velocity_min = 140.0
		p.initial_velocity_max = 320.0
		p.scale_amount_min = 0.25
		p.scale_amount_max = 0.55
		p.angular_velocity_min = -200
		p.angular_velocity_max = 200
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0))
		p.scale_amount_curve = curve
		add_child(p)
		_pool.append(p)


func burst(pos: Vector2, color: Color, amount: int = 10, leaf := false) -> void:
	if not high_quality or _pool.is_empty():
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.position = pos
	p.color = color
	p.amount = amount
	p.texture = _leaf if leaf else _sparkle
	p.restart()
	p.emitting = true


func flash(pos: Vector2, color: Color, radius: float, duration: float = 0.35) -> void:
	var s := Sprite2D.new()
	s.texture = _circle
	s.modulate = color
	s.position = pos
	s.scale = Vector2.ONE * 0.2
	add_child(s)
	var t := s.create_tween().set_parallel(true)
	t.tween_property(s, "scale", Vector2.ONE * (radius / 32.0), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, duration)
	t.chain().tween_callback(s.queue_free)


func beam(from: Vector2, to: Vector2, color: Color, width: float, duration: float = 0.3) -> void:
	var l := Line2D.new()
	l.points = PackedVector2Array([from, to])
	l.width = width
	l.default_color = color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "width", 0.0, duration).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(l, "modulate:a", 0.0, duration)
	t.tween_callback(l.queue_free)


func flying_sprite(tex: Texture2D, from: Vector2, to: Vector2, size: float, duration: float, rot: float = 0.0) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = from
	s.rotation = rot
	s.scale = Vector2.ONE * (size / tex.get_width())
	add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "position", to, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(s.queue_free)


func float_text(text: String, pos: Vector2, color: Color, size: int = 44) -> void:
	var l := UIKit.title_label(text, size, color.darkened(0.4))
	l.add_theme_color_override("font_color", color.lightened(0.5))
	l.size = Vector2(500, 80)
	l.position = pos - Vector2(250, 40)
	l.pivot_offset = Vector2(250, 40)
	add_child(l)
	UIKit.pop_in(l)
	var t := l.create_tween()
	t.tween_interval(0.5)
	t.tween_property(l, "position:y", l.position.y - 60, 0.6)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	t.tween_callback(l.queue_free)
