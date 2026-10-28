class_name PurchaseProvider
extends RefCounted
## Interface between the shop and a payment backend.
##
## The shipped game uses FreeTestProvider (no money, no network). A future
## store integration (e.g. a Google Play Billing plugin) only needs to
## implement this class and be passed to EconomyManager.set_provider() —
## shop UI, rewards and saves stay unchanged.


## Human-readable price label for the product card.
func price_label(product: Dictionary) -> String:
	return "%d ₽" % int(product.get("price_rub", 0))


## True when no real money is involved.
func is_test_mode() -> bool:
	return true


## Starts a purchase. Must eventually call `done` exactly once with
## {"ok": bool, "error": String}.
func purchase(product: Dictionary, done: Callable) -> void:
	done.call({"ok": false, "error": "not_implemented"})
