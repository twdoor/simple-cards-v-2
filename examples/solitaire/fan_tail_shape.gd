## Fan tail arrangement — cards stack tightly, with the last few fanned out.
##
## Useful for solitaire waste/deal piles where you want to see the top N cards.
class_name FanTailShape extends ContainerShape

## Number of cards visible in the fanned tail.
@export var visible_count: int = 3
## Spacing between the tightly stacked cards.
@export var stack_spacing: float = 2.0
## Spacing between the fanned tail cards.
@export var fan_spacing: float = 30.0
## Maximum total length. Stack spacing shrinks to fit. [code]-1[/code] = no limit.
@export var max_length: float = -1.0
## If true, fans horizontally. If false, fans vertically.
@export var horizontal: bool = true


func _compute_raw_cards(cards: Array[Card]) -> Dictionary:
	var card_count = cards.size()
	var positions: Array[Vector2] = []
	var rotations: Array[float] = []
	
	var tail_start = max(0, card_count - visible_count)
	var tail_count = card_count - tail_start
	var fan_total = max(0, tail_count - 1) * fan_spacing
	
	var actual_stack_spacing = stack_spacing
	if max_length > 0 and tail_start > 0:
		var available_for_stack = max_length - fan_total
		var needed_for_stack = tail_start * stack_spacing
		if needed_for_stack > available_for_stack:
			actual_stack_spacing = available_for_stack / tail_start
	
	for i in card_count:
		var offset: float
		if i < tail_start:
			offset = i * actual_stack_spacing
		else:
			var tail_index = i - tail_start
			offset = tail_start * actual_stack_spacing + tail_index * fan_spacing
		
		var pos = Vector2(offset, 0.0) if horizontal else Vector2(0.0, offset)
		positions.append(pos)
		rotations.append(0.0)
	
	return { "positions": positions, "rotations": rotations }
