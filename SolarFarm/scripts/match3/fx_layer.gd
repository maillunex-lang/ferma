class_name FxLayer
extends Node2D
## Pooled particles and short-lived glow effects for the board: additive
## glows, shockwave rings, star bursts, light beams, sparkle trails, confetti.
## With "effects: low" particles, glows and shakes are skipped.

const POOL_SIZE := 18

static var additive: CanvasItemMaterial

var high_quality := true
var _pool: Array[CPUParticles2D] = []
var _next := 0
var tex_sparkle: Texture2D
var tex_star: Texture2D
var tex_glow: Texture2D
var tex_ring: Texture2D
var tex_beam: Texture2D
var tex_leaf: Texture2D
var tex_shard: Texture2D
var tex_confetti: Texture2D


static func add_material() -> CanvasItemMaterial:
	if additive == null:
		additive = CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return additive


func _ready() -> void:
	high_quality = GameManager.effects_high()
	tex_sparkle = load("res://assets/fx/sparkle.png")
	tex_star = load("res://assets/fx/star.png")
	tex_glow = load("res://assets/fx/glow.png")
	tex_ring = load("res://assets/fx/ring.png")
	tex_beam = load("res://assets/fx/beam.png")
	tex_leaf = load("res://assets/fx/leaf.png")
	tex_shard = load("res://assets/fx/shard.png")
	tex_confetti = load("res://assets/fx/confetti.png")
	if not high_quality:
		return
	for i in POOL_SIZE:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 10
		p.lifetime = 0.6
		p.spread = 180.0
		p.gravity = Vector2(0, 520)
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 330.0
		p.scale_amount_min = 0.18
		p.scale_amount_max = 0.42
		p.angular_velocity_min = -260
		p.angular_velocity_max = 260
		p.damping_min = 40
		p.damping_max = 120
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(0.7, 0.8))
		curve.add_point(Vector2(1, 0))
		p.scale_amount_curve = curve
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = grad
		add_child(p)
		_pool.append(p)


## Star / sparkle burst. kind: "star", "sparkle", "leaf", "shard"
func burst(pos: Vector2, color: Color, amount: int = 10, kind: String = "star", speed: float = 1.0) -> void:
	if not high_quality or _pool.is_empty():
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.position = pos
	p.color = color
	p.amount = amount
	p.initial_velocity_min = 120.0 * speed
	p.initial_velocity_max = 330.0 * speed
	match kind:
		"leaf":
			p.texture = tex_leaf
			p.material = null
		"shard":
			p.texture = tex_shard
			p.material = null
		"sparkle":
			p.texture = tex_sparkle
			p.material = add_material()
		_:
			p.texture = tex_star
			p.material = add_material()
	p.restart()
	p.emitting = true


func _sprite(tex: Texture2D, pos: Vector2, color: Color, additive_blend := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.modulate = color
	if additive_blend:
		s.material = add_material()
	add_child(s)
	return s


## Soft additive glow that blooms and fades.
func glow(pos: Vector2, color: Color, size: float, duration: float = 0.35) -> void:
	if not high_quality:
		return
	var s := _sprite(tex_glow, pos, color)
	var k := size / tex_glow.get_width()
	s.scale = Vector2.ONE * k * 0.4
	var t := s.create_tween().set_parallel(true)
	t.tween_property(s, "scale", Vector2.ONE * k, duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, duration * 0.7).set_delay(duration * 0.3)
	t.chain().tween_callback(s.queue_free)


## Expanding shockwave ring.
func ring(pos: Vector2, color: Color, radius: float, duration: float = 0.45) -> void:
	var s := _sprite(tex_ring, pos, color, high_quality)
	var k := radius * 2.0 / tex_ring.get_width()
	s.scale = Vector2.ONE * k * 0.15
	var t := s.create_tween().set_parallel(true)
	t.tween_property(s, "scale", Vector2.ONE * k, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(s.queue_free)


## Kept for compatibility with older calls: bright flash disc.
func flash(pos: Vector2, color: Color, radius: float, duration: float = 0.35) -> void:
	if high_quality:
		glow(pos, color, radius * 2.0, duration)
	else:
		ring(pos, color, radius, duration)


## Glowing light beam between two points (rocket lines, rainbow bolts).
func beam(from: Vector2, to: Vector2, color: Color, width: float, duration: float = 0.3) -> void:
	var s := _sprite(tex_beam, (from + to) / 2.0, color, high_quality)
	var len := from.distance_to(to)
	s.rotation = (to - from).angle()
	s.scale = Vector2(len / tex_beam.get_width(), width * 2.2 / tex_beam.get_height())
	var t := s.create_tween().set_parallel(true)
	t.tween_property(s, "scale:y", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(s, "modulate:a", 0.0, duration)
	t.chain().tween_callback(s.queue_free)


## Sprite flying along a straight line, optionally leaving a sparkle trail.
func flying_sprite(tex: Texture2D, from: Vector2, to: Vector2, size: float, duration: float, rot: float = 0.0, trail_color := Color(1, 0.8, 0.3)) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = from
	s.rotation = rot
	s.scale = Vector2.ONE * (size / tex.get_width())
	add_child(s)
	if high_quality:
		_attach_trail(s, trail_color)
	var t := s.create_tween()
	t.tween_property(s, "position", to, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(s.queue_free)


## Collected piece flying to its goal on a curved path with a glowing trail.
func fly_curve(tex: Texture2D, from: Vector2, to: Vector2, size: float, duration: float, color: Color) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = from
	s.scale = Vector2.ONE * (size / tex.get_width())
	s.z_index = 5
	add_child(s)
	if high_quality:
		var g := Sprite2D.new()
		g.texture = tex_glow
		g.material = add_material()
		g.modulate = Color(color, 0.8)
		g.scale = Vector2.ONE * 2.2
		g.show_behind_parent = true
		s.add_child(g)
		_attach_trail(s, color)
	var ctrl := (from + to) / 2.0 + Vector2(randf_range(-160, 160), -120)
	var t := s.create_tween()
	t.tween_method(func(v: float):
		var a := from.lerp(ctrl, v)
		var b := ctrl.lerp(to, v)
		s.position = a.lerp(b, v)
		s.scale = Vector2.ONE * (size / tex.get_width()) * lerpf(1.15, 0.55, v), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(s.queue_free)


func _attach_trail(node: Node2D, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.texture = tex_sparkle
	p.material = add_material()
	p.local_coords = false
	p.amount = 14
	p.lifetime = 0.35
	p.spread = 180
	p.initial_velocity_min = 10
	p.initial_velocity_max = 40
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	p.color = color
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	# Counter the parent's scale so particles keep their size.
	p.scale = Vector2.ONE / maxf(0.01, node.scale.x)
	node.add_child(p)
	p.emitting = true


func confetti(area: Rect2, amount: int = 60) -> void:
	if not high_quality:
		return
	var p := CPUParticles2D.new()
	p.texture = tex_confetti
	p.position = Vector2(area.get_center().x, area.position.y)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area.size.x / 2, 10)
	p.amount = amount
	p.lifetime = 2.2
	p.one_shot = true
	p.explosiveness = 0.6
	p.direction = Vector2(0, 1)
	p.spread = 30
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 80
	p.initial_velocity_max = 260
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.1
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	grad.colors = PackedColorArray([Color("ff4d6d"), Color("ffd23f"), Color("4cc9f0"), Color("5ed16a"), Color("b06cff"), Color("ff9f1c")])
	p.color_initial_ramp = grad
	add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


func float_text(text: String, pos: Vector2, color: Color, size: int = 52) -> void:
	var holder := Node2D.new()
	holder.position = pos
	holder.z_index = 10
	add_child(holder)
	if high_quality:
		var g := Sprite2D.new()
		g.texture = tex_glow
		g.material = add_material()
		g.modulate = Color(color, 0.55)
		g.scale = Vector2(4.2, 1.6)
		holder.add_child(g)
	var l := UIKit.title_label(text, size, color.darkened(0.45))
	l.add_theme_color_override("font_color", color.lightened(0.55))
	l.size = Vector2(560, 90)
	l.position = Vector2(-280, -45)
	holder.add_child(l)
	holder.scale = Vector2(0.3, 0.3)
	holder.rotation = -0.08
	var t := holder.create_tween()
	t.tween_property(holder, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(holder, "rotation", 0.0, 0.25)
	t.tween_property(holder, "scale", Vector2.ONE, 0.1)
	t.tween_interval(0.45)
	t.tween_property(holder, "position:y", pos.y - 70, 0.45).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(holder, "modulate:a", 0.0, 0.45)
	t.tween_callback(holder.queue_free)
