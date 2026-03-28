@abstract
## Abstract base class for card container arrangement shapes.
##
## Computes positions and rotations for cards in a [CardContainer].
## Subclass and override [method _compute_raw_cards] to define custom layouts.
class_name ContainerShape extends Resource


## Computes the final card positions and rotations with bounding-box adjustment.
## [br]Returns a Dictionary with:
## [br]- [code]positions[/code]: Array[Vector2] of final center positions
## [br]- [code]rotations[/code]: Array[float] of card rotations in radians
func compute_layout(cards: Array[Card]) -> Dictionary:
	var card_count = cards.size()
	if card_count == 0:
		return { "positions": [] as Array[Vector2], "rotations": [] as Array[float] }
	
	var raw_data = _compute_raw_cards(cards)
	var raw_positions: Array[Vector2] = raw_data.positions
	var raw_rotations: Array[float] = raw_data.rotations
	var min_bounds = Vector2(INF, INF)
	
	for i in card_count:
		var half_size = cards[i].size / 2.0
		var pos = raw_positions[i]
		min_bounds.x = min(min_bounds.x, pos.x - half_size.x)
		min_bounds.y = min(min_bounds.y, pos.y - half_size.y)
	
	var offset = -min_bounds
	
	var final_positions: Array[Vector2] = []
	for i in card_count:
		final_positions.append(raw_positions[i] + offset)
	
	return { "positions": final_positions, "rotations": raw_rotations }


## Computes raw card center positions and rotations before bounding box adjustment.
## [br]Must return a Dictionary with:
## [br]- [code]positions[/code]: Array[Vector2] of raw center positions
## [br]- [code]rotations[/code]: Array[float] of card rotations in radians
@abstract func _compute_raw_cards(cards: Array[Card]) -> Dictionary
