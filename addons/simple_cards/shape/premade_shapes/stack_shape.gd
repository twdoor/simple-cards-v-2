## Stack arrangement shape — all cards at the same position.
class_name StackShape extends ContainerShape


func _compute_raw_cards(cards: Array[Card]) -> Dictionary:
	var card_count = cards.size()
	var positions: Array[Vector2] = []
	var rotations: Array[float] = []
	
	for i in card_count:
		positions.append(Vector2.ZERO)
		rotations.append(0.0)
	
	return { "positions": positions, "rotations": rotations }
