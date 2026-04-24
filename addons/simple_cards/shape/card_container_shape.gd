@abstract
## Abstract base class for card container arrangement shapes.
##
## Computes positions and rotations for cards in a [CardContainer].
## Subclass and override [method _compute_raw_cards] to define custom layouts.
class_name ContainerShape extends Resource


## Holds the computed positions and rotations for a set of cards.
class LayoutResult:
	var positions: Array[Vector2] = []
	var rotations: Array[float] = []

	func _init(pos: Array[Vector2] = [], rot: Array[float] = []) -> void:
		positions = pos
		rotations = rot


## Computes the final card positions and rotations with bounding-box adjustment.
func compute_layout(cards: Array[Card]) -> LayoutResult:
	var card_count = cards.size()
	if card_count == 0:
		return LayoutResult.new()

	var raw: LayoutResult = _compute_raw_cards(cards)
	var min_bounds = Vector2(INF, INF)

	for i in card_count:
		var half_size = cards[i].size / 2.0
		var pos = raw.positions[i]
		min_bounds.x = min(min_bounds.x, pos.x - half_size.x)
		min_bounds.y = min(min_bounds.y, pos.y - half_size.y)

	var offset = -min_bounds

	var final_positions: Array[Vector2] = []
	for i in card_count:
		final_positions.append(raw.positions[i] + offset)

	return LayoutResult.new(final_positions, raw.rotations)


## Computes raw card center positions and rotations before bounding box adjustment.
## [br]Override this method to define custom layout shapes.
@abstract func _compute_raw_cards(cards: Array[Card]) -> LayoutResult
