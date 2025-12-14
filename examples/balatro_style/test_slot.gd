extends CardSlot

func _ready() -> void:
	super()
	card_entered.connect(_on_card_entered)
	card_exited.connect(_on_card_exited)
	card_dropped.connect(_on_card_exited)
	
func _on_card_entered(_card):
	self_modulate = Color.GREEN
	
func _on_card_exited(_card):
	self_modulate = Color.WHITE
