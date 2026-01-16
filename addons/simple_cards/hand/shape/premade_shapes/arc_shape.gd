##Arc arrangement shape for card hands.
class_name ArcHandShape extends CardHandShape

##The radius of the circle used to create the arc
@export var arc_radius: float = 400.0
##The angle in deg of the arc
@export_range(0.0, 360.0, 1) var arc_angle: float = 60.0
##The angle where the circle of the arc is placed
@export_range(0.0, 360.0, 1) var arc_orientation: float = 270.0
##The maximum distance between the cards
@export var card_spacing: float = 50

func _init(radius: float = arc_radius, angle: float = arc_angle, orientation: float = arc_orientation, spacing: float = card_spacing) -> void:
	arc_radius = radius
	arc_angle = angle
	arc_orientation = orientation
	card_spacing = spacing


func arrange_cards(cards: Array[Card], hand: CardHand, skipped_cards: Array[Card] = []) -> Array[Vector2]:
	var card_count = cards.size()
	var card_positions: Array[Vector2]
	if card_count == 0:
		return []
	
	var angle_between = 0.0
	if card_count > 1:
		var arc_length = (card_count - 1) * card_spacing
		var max_angle = min(arc_angle, rad_to_deg(arc_length / arc_radius))
		angle_between = max_angle / max(1, card_count - 1)
	
	var start_angle = arc_orientation - (angle_between * (card_count - 1)) / 2.0

	for i in card_count:
		var card = cards[i]
		var current_angle = start_angle + i * angle_between
		var angle_rad = deg_to_rad(current_angle)
		var x = arc_radius * cos(angle_rad)
		var y = arc_radius * sin(angle_rad)
		
		var final_pos = Vector2(x, y) - card.pivot_offset
		card_positions.append(Vector2(x, y))
		if !skipped_cards.is_empty() and skipped_cards.has(card):
			continue
		
		var pos = final_pos + (card.position_offset.rotated(angle_rad + deg_to_rad(90)))  
		card.tween_position(pos)
		card.rotation = angle_rad + deg_to_rad(90) + card.rotation_offset
		
	return card_positions
