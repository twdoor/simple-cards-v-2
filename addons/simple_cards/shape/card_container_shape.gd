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
		if i >= raw.positions.size():
			continue
		var half_size := cards[i].size / 2.0
		var pos = raw.positions[i]
		var rot := raw.rotations[i] if i < raw.rotations.size() else 0.0
		var corners := [
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y)
		]
		for corner in corners:
			var rotated_corner: Vector2 = pos + corner.rotated(rot)
			min_bounds.x = min(min_bounds.x, rotated_corner.x)
			min_bounds.y = min(min_bounds.y, rotated_corner.y)

	var offset = -min_bounds

	var final_positions: Array[Vector2] = []
	for i in card_count:
		final_positions.append(raw.positions[i] + offset)

	return LayoutResult.new(final_positions, raw.rotations)


## Computes raw card center positions and rotations before bounding box adjustment.
## [br]Override this method to define custom layout shapes.
@abstract func _compute_raw_cards(cards: Array[Card]) -> LayoutResult


## Returns the focus neighbor index for [param index] in the given direction.
## [br]Direction is one of [code]"left"[/code], [code]"right"[/code], [code]"up"[/code], [code]"down"[/code].
## Returns [code]-1[/code] if there is no neighbor in that direction.
## [br]Default: 1D sequence (left = previous, right = next, up/down = none).
## Override for 2D layouts like grids.
func get_focus_neighbor(index: int, direction: String, card_count: int) -> int:
	match direction:
		"left":
			return index - 1 if index > 0 else -1
		"right":
			return index + 1 if index < card_count - 1 else -1
		_:
			return -1
