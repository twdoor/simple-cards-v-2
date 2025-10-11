extends CanvasLayer

@onready var card_hand: CardHand = $CardHand

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_end"):
		card_hand.add_card(Card.new())
