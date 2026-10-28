extends ScreenBase
## Local helper shop. In this version every product is a FREE TEST grant:
## no payments, no bank data, no network. Prices are shown only as examples
## of future pricing.

## When true the shop is shown as an overlay inside the puzzle and "back"
## simply closes it.
var embedded := false
var _buttons := {}


func _init() -> void:
	title_text = "Магазин"
	back_target = "farm"


func build() -> void:
	if not embedded:
		AudioManager.play_music("farm")
		back_target = GameManager.previous_scene_name if GameManager.previous_scene_name in ["farm", "helpers", "menu"] else "farm"
	EconomyManager.purchase_finished.connect(_on_purchase_finished)
	var note := UIKit.card(Color("e3f6ff"), 28)
	var nl := UIKit.label("Тестовый режим: все наборы выдаются бесплатно. Реальные платежи не подключены, данные карты не запрашиваются, интернет не нужен.", 24, Color("1f5f7a"))
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_child(nl)
	content.add_child(note)
	for p in EconomyManager.products:
		content.add_child(_make_card(p))
	_refresh()


func _make_card(p: Dictionary) -> Control:
	var card := UIKit.card(UIKit.C_CREAM, 34)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	card.add_child(hb)
	var art := Control.new()
	art.custom_minimum_size = Vector2(150, 150)
	hb.add_child(art)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.style(Color("fff0c2"), 75, 0, Color.TRANSPARENT, 0))
	bg.size = Vector2(150, 150)
	art.add_child(bg)
	if p.icon != "":
		var ic := UIKit.icon(load(p.icon), 140)
		ic.position = Vector2(5, 5)
		art.add_child(ic)
	else:
		var k := 0
		for h in HelperManager.order:
			var ic := UIKit.icon(HelperManager.icon(h), 80)
			ic.position = Vector2(4 + (k % 2) * 64, 4 + (k / 2) * 64)
			art.add_child(ic)
			k += 1
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)
	vb.add_child(UIKit.label(p.title, 32, UIKit.C_TEXT))
	var desc := ""
	if p.grant.size() == 1:
		var hid: String = p.grant.keys()[0]
		desc = HelperManager.defs[hid].description
	else:
		desc = "Все четыре помощника для сложных уровней."
	var dl := UIKit.label(desc, 22, UIKit.C_TEXT.lightened(0.2))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(dl)
	vb.add_child(UIKit.label(p.description, 24, UIKit.C_GREEN_DARK))
	var price := UIKit.label("Будущая цена: %s (пример)" % EconomyManager.provider.price_label(p), 22, UIKit.C_TEXT.lightened(0.35))
	vb.add_child(price)
	var owned := UIKit.label("", 22, UIKit.C_ORANGE.darkened(0.3))
	owned.name = "Owned"
	owned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(owned)
	var btn := UIKit.button("Получить бесплатно", UIKit.C_GREEN, Vector2(0, 76), 26)
	btn.pressed.connect(_on_buy.bind(p.id))
	vb.add_child(btn)
	_buttons[p.id] = {"button": btn, "owned": owned, "product": p}
	return card


func _refresh() -> void:
	for id in _buttons:
		var e: Dictionary = _buttons[id]
		var parts := []
		for h in e.product.grant:
			parts.append("%s: %d" % [HelperManager.defs[h].short, HelperManager.charges(h)])
		e.owned.text = "Сейчас: " + ", ".join(parts)
		var check := EconomyManager.can_purchase(id)
		var btn: Button = e.button
		btn.disabled = not check.ok
		if check.reason == "max":
			btn.text = "Максимум (%d)" % EconomyManager.max_charges
		elif check.reason == "pending":
			btn.text = "Выдаём…"
		else:
			btn.text = "Получить бесплатно"


func _on_buy(id: String) -> void:
	if EconomyManager.purchase(id):
		_refresh()


func _on_purchase_finished(id: String, ok: bool, message: String) -> void:
	if not is_inside_tree():
		return
	_refresh()
	if ok:
		AudioManager.play("purchase")
		var p := EconomyManager.get_product(id)
		GameManager.toast(message, UIKit.C_GREEN, load(p.icon) if p.icon != "" else load("res://assets/ui/icon_check.png"))
	else:
		GameManager.toast(message, UIKit.C_CORAL)


func on_back() -> void:
	if embedded:
		queue_free()
	else:
		super.on_back()
