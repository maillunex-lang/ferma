class_name PieceView
extends Sprite2D
## Visual for one board piece (fruit or booster).

const TEX_SPECIAL := {
	BoardModel.Special.ROCKET_H: "res://assets/tiles/rocket.png",
	BoardModel.Special.ROCKET_V: "res://assets/tiles/rocket.png",
	BoardModel.Special.BASKET: "res://assets/tiles/basket.png",
	BoardModel.Special.RAINBOW: "res://assets/tiles/rainbow.png",
}

var piece_id := 0
var color := -1
var special := BoardModel.Special.NONE
var cell_size := 80.0
var _idle: Tween


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
	var s := cell_size * 0.92 / 256.0
	scale = Vector2(s, s)
	if sp == BoardModel.Special.ROCKET_V:
		rotation = -PI / 2
	if sp != BoardModel.Special.NONE:
		# Boosters gently breathe so they stand out on the board.
		_idle = create_tween().set_loops()
		_idle.tween_property(self, "scale", Vector2(s, s) * 1.08, 0.5).set_trans(Tween.TRANS_SINE)
		_idle.tween_property(self, "scale", Vector2(s, s), 0.5).set_trans(Tween.TRANS_SINE)


func base_scale() -> Vector2:
	var s := cell_size * 0.92 / 256.0
	return Vector2(s, s)


func stop_idle() -> void:
	if _idle:
		_idle.kill()
		_idle = null
	scale = base_scale()
