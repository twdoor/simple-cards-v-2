@tool
## Line arrangement shape for card containers.
class_name LineShape extends ContainerShape

## Alignment of the cards within the line.
enum Alignment { BEGIN, CENTER, END }

## Angle in degrees of the line orientation.
@export_range(0, 360, 1) var line_rotation: float = 0.0
## Maximum width of the line.
@export var max_width: float = 600.0
## Maximum distance between card centers.
@export var card_spacing: float = 50
## Alignment of cards within the max_width.
@export var alignment: Alignment = Alignment.CENTER
## Rotation of each card in degrees.
@export_range(0, 360, 1) var card_rotation_angle: float = 0


func _init(rot: float = line_rotation, width: float = max_width, spacing: float = card_spacing) -> void:
	line_rotation = rot
	max_width = width
	card_spacing = spacing


func _compute_raw_cards(cards: Array[Card]) -> LayoutResult:
	var card_count = cards.size()
	var positions: Array[Vector2] = []
	var rotations: Array[float] = []

	var card_size = cards[0].size
	var total_width = (card_count - 1) * card_spacing + card_size.x
	var actual_spacing = card_spacing
	if total_width > max_width:
		actual_spacing = maxf(0.0, (max_width - card_size.x) / max(1, card_count - 1))

	var start_x: float
	match alignment:
		Alignment.BEGIN:
			start_x = -max_width / 2.0 + card_size.x / 2.0
		Alignment.CENTER:
			start_x = -(card_count - 1) * actual_spacing / 2.0
		Alignment.END:
			start_x = max_width / 2.0 - card_size.x / 2.0 - (card_count - 1) * actual_spacing

	var rot_rad = deg_to_rad(line_rotation)
	var card_rot = deg_to_rad(card_rotation_angle)
	var bounds_positions: Array[Vector2] = [
		Vector2(-max_width / 2.0 + card_size.x / 2.0, 0.0).rotated(rot_rad),
		Vector2(max_width / 2.0 - card_size.x / 2.0, 0.0).rotated(rot_rad)
	]
	var bounds_rotations: Array[float] = [card_rot, card_rot]
	var bounds_cards: Array[Card] = [cards[0], cards[0]]
	var origin_offset = _get_bounds_offset(bounds_cards, bounds_positions, bounds_rotations)

	for i in card_count:
		var x_pos = start_x + i * actual_spacing
		var rotated_pos = Vector2(x_pos, 0.0).rotated(rot_rad) + origin_offset
		positions.append(rotated_pos)
		rotations.append(card_rot)

	return LayoutResult.new(positions, rotations)


func get_layout_bounds(cards: Array[Card], _result: LayoutResult) -> Rect2:
	if cards.is_empty():
		return Rect2()

	var card_size = cards[0].size
	var rot_rad = deg_to_rad(line_rotation)
	var card_rot = deg_to_rad(card_rotation_angle)
	var bounds_positions: Array[Vector2] = [
		Vector2(-max_width / 2.0 + card_size.x / 2.0, 0.0).rotated(rot_rad),
		Vector2(max_width / 2.0 - card_size.x / 2.0, 0.0).rotated(rot_rad)
	]
	var bounds_rotations: Array[float] = [card_rot, card_rot]
	var bounds_cards: Array[Card] = [cards[0], cards[0]]
	var origin_offset = _get_bounds_offset(bounds_cards, bounds_positions, bounds_rotations)

	for i in bounds_positions.size():
		bounds_positions[i] += origin_offset

	return _get_cards_bounds(bounds_cards, bounds_positions, bounds_rotations)


func get_focus_neighbor(index: int, direction: String, card_count: int) -> int:
	var forward = Vector2.RIGHT.rotated(deg_to_rad(line_rotation))
	var step: int
	if absf(forward.x) >= absf(forward.y):
		match direction:
			"right": step = 1 if forward.x >= 0 else -1
			"left":  step = -1 if forward.x >= 0 else 1
			_: return -1
	else:
		match direction:
			"down": step = 1 if forward.y >= 0 else -1
			"up":   step = -1 if forward.y >= 0 else 1
			_: return -1

	var target = index + step
	if target < 0 or target >= card_count: return -1
	return target
