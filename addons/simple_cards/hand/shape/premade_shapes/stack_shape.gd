class_name StackHandShape extends CardHandShape

func _compute_raw_cards(cards: Array[Card]) -> Dictionary:
	var card_count = cards.size()
	var positions: Array[Vector2] = []
	var rotations: Array[float] = []
	
	for card in card_count:
		positions.append(Vector2.ZERO)
		rotations.append(0)
	
	return { "positions": positions, "rotations": rotations }
