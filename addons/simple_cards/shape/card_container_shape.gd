@tool @abstract
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


## Computes the final card positions and rotations.
func compute_layout(cards: Array[Card]) -> LayoutResult:
	var card_count = cards.size()
	if card_count == 0:
		return LayoutResult.new()

	var raw: LayoutResult = _compute_raw_cards(cards)

	var final_positions: Array[Vector2] = []
	var final_rotations: Array[float] = []

	for i in card_count:
		final_positions.append(raw.positions[i] if i < raw.positions.size() else cards[i].pivot_offset)
		final_rotations.append(raw.rotations[i] if i < raw.rotations.size() else 0.0)

	return LayoutResult.new(final_positions, final_rotations)


## Returns the bounds represented by a computed layout.
## [br]Override when a shape has a logical layout region larger than its current cards.
func get_layout_bounds(cards: Array[Card], result: LayoutResult) -> Rect2:
	return _get_cards_bounds(cards, result.positions, result.rotations)


## Computes card center positions and rotations in container-local coordinates.
## [br]Override this method to define custom layout shapes.
@abstract func _compute_raw_cards(cards: Array[Card]) -> LayoutResult


## Returns the offset needed to place the given positioned cards at the local origin.
## [br]Subclasses can use this when they explicitly want bounds-fitted output.
func _get_bounds_offset(cards: Array[Card], positions: Array[Vector2], rotations: Array[float]) -> Vector2:
	var bounds := _get_cards_bounds(cards, positions, rotations)
	return -bounds.position if bounds.size != Vector2.ZERO else Vector2.ZERO


func _get_cards_bounds(cards: Array[Card], positions: Array[Vector2], rotations: Array[float]) -> Rect2:
	var min_bounds = Vector2(INF, INF)
	var max_bounds = Vector2(-INF, -INF)
	var has_bounds := false

	for i in mini(cards.size(), positions.size()):
		var half_size := cards[i].size / 2.0
		var pos := positions[i]
		var rot := rotations[i] if i < rotations.size() else 0.0
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
			max_bounds.x = max(max_bounds.x, rotated_corner.x)
			max_bounds.y = max(max_bounds.y, rotated_corner.y)
			has_bounds = true

	if !has_bounds:
		return Rect2()
	return Rect2(min_bounds, max_bounds - min_bounds)


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
