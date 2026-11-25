extends Area2D
## Something Feyre can use with E. The player picks the nearest one in range.

var label = ""
var callback: Callable
var radius = 90.0
var enabled = true


func setup(text: String, cb: Callable, r := 90.0) -> void:
	label = text
	callback = cb
	radius = r
	monitoring = false
	monitorable = false
	add_to_group("interactable")


func activate() -> void:
	if enabled and callback.is_valid():
		await callback.call()
