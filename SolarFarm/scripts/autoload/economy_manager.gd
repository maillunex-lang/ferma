extends Node
## Coins and the local helper shop. Purchases go through a PurchaseProvider;
## in this version it is FreeTestProvider (free test grants, no payments).

signal coins_changed(coins: int)
signal purchase_finished(product_id: String, ok: bool, message: String)

var products: Array = []
var max_charges := 99
var provider: PurchaseProvider = FreeTestProvider.new()
var _pending := {}


func _ready() -> void:
	var shop = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop.json"))
	products = shop.products
	max_charges = int(shop.get("max_charges", 99))


func set_provider(p: PurchaseProvider) -> void:
	provider = p


func coins() -> int:
	return int(SaveManager.data.coins)


func add_coins(amount: int, save := true) -> void:
	SaveManager.data.coins = maxi(0, coins() + amount)
	if save:
		SaveManager.save_game()
	coins_changed.emit(coins())


## Spends coins only if the balance is sufficient. Returns success.
func spend_coins(amount: int) -> bool:
	if amount < 0 or coins() < amount:
		return false
	SaveManager.data.coins = coins() - amount
	SaveManager.save_game()
	coins_changed.emit(coins())
	return true


func get_product(id: String) -> Dictionary:
	for p in products:
		if p.id == id:
			return p
	return {}


## {"ok": bool, "reason": String}
func can_purchase(id: String) -> Dictionary:
	var p := get_product(id)
	if p.is_empty():
		return {"ok": false, "reason": "unknown"}
	if _pending.has(id):
		return {"ok": false, "reason": "pending"}
	var any_room := false
	for h in p.grant:
		if HelperManager.charges(h) < max_charges:
			any_room = true
	if not any_room:
		return {"ok": false, "reason": "max"}
	return {"ok": true, "reason": ""}


## Starts a purchase. Repeated taps while a purchase is pending are ignored,
## so a double tap can never grant twice.
func purchase(id: String) -> bool:
	var check := can_purchase(id)
	if not check.ok:
		return false
	_pending[id] = true
	provider.purchase(get_product(id), _on_provider_done.bind(id))
	return true


func is_pending(id: String) -> bool:
	return _pending.has(id)


func _on_provider_done(result: Dictionary, id: String) -> void:
	if not _pending.has(id):
		return  # stale / duplicated callback
	_pending.erase(id)
	if not result.get("ok", false):
		purchase_finished.emit(id, false, "Покупка не выполнена")
		return
	var p := get_product(id)
	for h in p.grant:
		HelperManager.add_charges(h, int(p.grant[h]), false)
	var st: Dictionary = SaveManager.data.stats
	st.test_purchases = int(st.get("test_purchases", 0)) + 1
	var log: Array = SaveManager.data.purchase_log
	log.append({"id": id, "time": Time.get_datetime_string_from_system(), "test": provider.is_test_mode()})
	while log.size() > 50:
		log.pop_front()
	SaveManager.save_game()
	purchase_finished.emit(id, true, "Покупка успешно выполнена")
