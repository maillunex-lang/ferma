class_name FreeTestProvider
extends PurchaseProvider
## Test-mode provider: every product is granted for free, locally and offline.
## No payment data is requested and nothing is sent anywhere.


func is_test_mode() -> bool:
	return true


func purchase(product: Dictionary, done: Callable) -> void:
	# Deferred to mimic an asynchronous store and to exercise the UI lock.
	done.call_deferred({"ok": true, "error": "", "product_id": product.get("id", "")})
