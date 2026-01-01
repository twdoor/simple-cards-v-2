##Line arrangement shape for card hands.
class_name LineHandShape extends CardHandShape

##Angle in deg of the line orientation
@export var line_rotation: float = 0.0
##How long the line is.
@export var max_width: float = 600.0
##The maximum distance between the cards
@export var card_spacing: float = 50

func _init(rot: float = 0, width = 600, spacing: float = 50) -> void:
	line_rotation = rot
	max_width = width
	card_spacing = spacing

func arrange_cards(cards: Array[Card], hand: CardHand, skipped_cards: Array[Card] = []) -> Array[Vector2]:
	var card_count = cards.size()
	var card_positions: Array[Vector2]
	if card_count == 0:
		return []
	
	var card_size = cards[0].size
	var total_width = (card_count - 1) * card_spacing + card_size.x
	var actual_spacing = card_spacing
	if total_width > max_width:
		actual_spacing = (max_width - card_size.x) / max(1, card_count - 1)
	
	var start_x = -(card_count - 1) * actual_spacing / 2.0
	
	for i in card_count:
		var card = cards[i]
		var x_pos = start_x + i * actual_spacing
		var y_pos = 0.0
		var rotated_pos = Vector2(x_pos, y_pos).rotated(deg_to_rad(line_rotation))
		var final_pos = rotated_pos - card.pivot_offset
		
		card_positions.append(final_pos + card.pivot_offset)
		if !skipped_cards.is_empty() and skipped_cards.has(card):
			continue
		
		var pos = final_pos + (card.position_offset.rotated(deg_to_rad(line_rotation)))
		card.tween_position(pos + hand.global_position, .2 , true)
		card.rotation = deg_to_rad(line_rotation) + card.rotation_offset
		
	return card_positions
