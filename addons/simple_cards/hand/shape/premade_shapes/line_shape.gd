##Line arrangement shape for card hands.
class_name LineHandShape extends CardHandShape

##Alignment of the cards within the line.
enum Alignment { BEGIN, CENTER, END }

##Angle in deg of the line orientation
@export_range(0, 360, 1) var line_rotation: float = 0.0
##How long the line is.
@export var max_width: float = 600.0
##The maximum distance between the cards
@export var card_spacing: float = 50
##Alignment of cards within the max_width. BEGIN starts from the left, END pushes to the right.
@export var alignment: Alignment = Alignment.CENTER
##Rotation of cards in the pile
@export_range(0, 360, 1)var card_rotation_angle: float = 0

func _init(rot: float = line_rotation, width = max_width, spacing: float = card_spacing) -> void:
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
	
	var start_x: float
	match alignment:
		Alignment.BEGIN:
			start_x = -max_width / 2.0 + card_size.x / 2.0
		Alignment.CENTER:
			start_x = -(card_count - 1) * actual_spacing / 2.0
		Alignment.END:
			start_x = max_width / 2.0 - card_size.x / 2.0 - (card_count - 1) * actual_spacing
	
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
		card.rotation = deg_to_rad(card_rotation_angle) + card.rotation_offset
		
	return card_positions
