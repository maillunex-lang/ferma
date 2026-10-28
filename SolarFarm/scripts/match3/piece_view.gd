class_name PieceView
extends Sprite2D
## Visual for one board piece (fruit or booster). Boosters get a rotating
## glow aura; every piece knows how to pop, squash and flash.

const TEX_SPECIAL := {
	BoardModel.Special.ROCKET_H: "res://assets/tiles/rocket.png",
	BoardModel.Special.ROCKET_V: "res://assets/tiles/rocket.png",
	BoardModel.Special.BASKET: "res://assets/tiles/basket.png",
	BoardModel.Special.RAINBOW: "res://assets/tiles/rainbow.png",
}
const AURA_COLOR := {
	BoardModel.Special.ROCKET_H: Color(1.0, 0.55, 0.35, 0.75),
	BoardModel.Special.ROCKET_V: Color(1.0, 0.55, 0.35, 0.75),
	BoardModel.Special.BASKET: Color(1.0, 0.85, 0.35, 0.8),
	BoardModel.Special.RAINBOW: Color(0.85, 0.6, 1.0, 0.85),
}

var piece_id := 0
var color := -1
var special := BoardModel.Special.NONE
var cell_size := 80.0
var _idle: Tween
var _aura: Sprite2D
var _aura_tween: Tween


func setup(id: int, c: int, sp: int, cs: float) -> void:
	piece_id = id
	cell_size = cs
	set_kind(c, sp)


func set_kind(c: int, sp: int) -> void:
	color = c
	special = sp
	if _idle:
		_idle.kill()
		_idle = null
	rotation = 0.0
	if sp == BoardModel.Special.NONE:
		texture = LevelManager.color_texture(c)
	else:
		texture = load(TEX_SPECIAL[sp])
	scale = base_scale()
	if sp == BoardModel.Special.ROCKET_V:
		rotation = -PI / 2
	_update_aura()
	if sp != BoardModel.Special.NONE:
		# Boosters gently breathe so they stand out on the board.
		var s := base_scale()
		_idle = create_tween().set_loops()
		_idle.tween_property(self, "scale", s * 1.08, 0.5).set_trans(Tween.TRANS_SINE)
		_idle.tween_property(self, "scale", s, 0.5).set_trans(Tween.TRANS_SINE)


func _update_aura() -> void:
	if _aura_tween:
		_aura_tween.kill()
		_aura_tween = null
	if special == BoardModel.Special.NONE or not GameManager.effects_high():
		if _aura:
			_aura.visible = false
		return
	if _aura == null:
		_aura = Sprite2D.new()
		_aura.texture = load("res://assets/fx/glow.png")
		_aura.material = FxLayer.add_material()
		_aura.show_behind_parent = true
		add_child(_aura)
	_aura.visible = true
	_aura.modulate = AURA_COLOR[special]
	_aura.scale = Vector2.ONE * 2.4
	_aura_tween = _aura.create_tween().set_loops()
	_aura_tween.tween_property(_aura, "modulate:a", AURA_COLOR[special].a * 0.45, 0.7).set_trans(Tween.TRANS_SINE)
	_aura_tween.tween_property(_aura, "modulate:a", AURA_COLOR[special].a, 0.7).set_trans(Tween.TRANS_SINE)


func base_scale() -> Vector2:
	var s := cell_size * 0.9 / 256.0
	return Vector2(s, s)


func stop_idle() -> void:
	if _idle:
		_idle.kill()
		_idle = null
	scale = base_scale()


## Clear animation: bright flash, squash-pop, then shrink away.
func pop_out(t: Tween, delay: float) -> void:
	var b := base_scale()
	t.tween_property(self, "modulate", Color(2.2, 2.2, 2.2, 1.0), 0.06).set_delay(delay)
	t.tween_property(self, "scale", b * 1.32, 0.09).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ZERO, 0.14).set_delay(delay + 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(self, "rotation", rotation + randf_range(-0.6, 0.6), 0.2).set_delay(delay)
	t.tween_property(self, "modulate:a", 0.0, 0.1).set_delay(delay + 0.14)
	t.tween_callback(queue_free).set_delay(delay + 0.26)
