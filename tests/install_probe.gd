extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if not is_instance_valid(CardGlobal) or get_tree().root.get_node_or_null("CardGlobal") != CardGlobal or not CardGlobal.has_layout(&"default") or not CardGlobal.has_layout(&"default_back"):
		push_error("Addon installation did not register default layouts")
		get_tree().quit(1)
		return
	var card := Card.new()
	add_child(card)
	if not card.get_layout():
		push_error("Installed addon could not create a card face")
		get_tree().quit(1)
		return
	card.queue_free()
	await get_tree().process_frame
	print("Installation fixture passed.")
	get_tree().quit()
