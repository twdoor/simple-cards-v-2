@tool
## Stack arrangement shape, with optional stable position and rotation variation.
class_name StackShape extends ContainerShape


@export_group("Randomization")
## Gives each card a stable random offset and rotation for a naturally uneven stack.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "Randomization") var randomization_enabled: bool = false:
	set(value):
		if randomization_enabled == value: return
		randomization_enabled = value
		emit_changed()
## Maximum offset on each axis, in pixels. Offsets range from negative to positive.
@export_custom(PROPERTY_HINT_LINK, "suffix:px") var max_position_offset: Vector2 = Vector2(3, 3):
	set(value):
		value = value.abs()
		if max_position_offset == value: return
		max_position_offset = value
		emit_changed()
## Maximum clockwise or counterclockwise rotation, in degrees.
@export_range(0, 180, 0.1, "suffix:°") var max_rotation_degrees: float = 3.0:
	set(value):
		value = clampf(value, 0, 180)
		if max_rotation_degrees == value: return
		max_rotation_degrees = value
		emit_changed()
## Change to choose another pattern. Each card keeps its variation during rearrangement.
@export var random_seed: int = 0:
	set(value):
		if random_seed == value: return
		random_seed = value
		emit_changed()


func _compute_raw_cards(cards: Array[Card]) -> LayoutResult:
	var card_count = cards.size()
	var positions: Array[Vector2] = []
	var rotations: Array[float] = []
	var rng := RandomNumberGenerator.new()

	for i in card_count:
		var offset := Vector2.ZERO
		var rotation := 0.0
		if randomization_enabled:
			# Seed per card rather than per index, so adding/removing/reordering cards
			# does not reroll the other cards. No references or random state are retained.
			rng.seed = hash([random_seed, cards[i].get_instance_id()])
			offset = Vector2(
				rng.randf_range(-max_position_offset.x, max_position_offset.x),
				rng.randf_range(-max_position_offset.y, max_position_offset.y))
			rotation = deg_to_rad(rng.randf_range(-max_rotation_degrees, max_rotation_degrees))
		positions.append(cards[i].pivot_offset + offset)
		rotations.append(rotation)

	# Include rotated edges in the local rectangle used by parent containers
	# and mouse input, while keeping each card's relative variation intact.
	var origin_offset := _get_bounds_offset(cards, positions, rotations)
	for i in positions.size():
		positions[i] += origin_offset

	return LayoutResult.new(positions, rotations)


func get_focus_neighbor(_index: int, _direction: String, _card_count: int) -> int:
	return -1
