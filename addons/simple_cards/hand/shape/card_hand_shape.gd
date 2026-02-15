@abstract @icon("uid://bg3fht552vtas")
##Abstract base class for card hand arrangement shapes.
class_name CardHandShape extends Resource


##Computes the final card positions and rotations. Does NOT move any cards.
##[br]Returns a Dictionary with:
##[br]- [code]positions[/code]: Array[Vector2] of final center positions (bounding-box adjusted)
##[br]- [code]rotations[/code]: Array[float] of card rotations in radians
func compute_layout(cards: Array[Card], hand: CardHand) -> Dictionary:
	var card_count = cards.size()
	if card_count == 0:
		return { "positions": [] as Array[Vector2], "rotations": [] as Array[float] }
	
	var raw_data = _compute_raw_cards(cards, hand)
	var raw_positions: Array[Vector2] = raw_data.positions
	var raw_rotations: Array[float] = raw_data.rotations
	var min_bounds = Vector2(INF, INF)
	
	for i in card_count:
		var half_size = cards[i].size / 2.0
		var pos = raw_positions[i]
		min_bounds = Vector2(min(min_bounds.x, pos.x - half_size.x), min(min_bounds.y, pos.y - half_size.y))
	
	var offset = -min_bounds
	
	var final_positions: Array[Vector2] = []
	for i in card_count:
		final_positions.append(raw_positions[i] + offset)
	
	return { "positions": final_positions, "rotations": raw_rotations }


##Applies positions and rotations to cards by tweening. Skipped cards are not moved.
func apply_layout(cards: Array[Card], layout: Dictionary, skipped_cards: Array[Card] = []) -> void:
	var positions: Array[Vector2] = layout.positions
	var rotations: Array[float] = layout.rotations
	
	for i in cards.size():
		var card = cards[i]
		if !skipped_cards.is_empty() and skipped_cards.has(card):
			continue
		
		var pos = positions[i]
		var rotation = rotations[i]
		var final_pos = pos - card.pivot_offset
		var tweened_pos = final_pos + (card.position_offset.rotated(rotation))
		card.tween_position(tweened_pos)
		card.rotation = rotation + card.rotation_offset


##Computes raw card center positions and rotations before bounding box adjustment.
##[br]Must return a Dictionary with:
##[br]- [code]positions[/code]: Array[Vector2] of raw center positions
##[br]- [code]rotations[/code]: Array[float] of card rotations in radians
@abstract func _compute_raw_cards(cards: Array[Card], hand: CardHand) -> Dictionary
