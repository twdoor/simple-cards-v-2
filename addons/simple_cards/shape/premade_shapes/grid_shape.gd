## Grid arrangement shape for card containers.
class_name GridShape extends ContainerShape

## Number of columns in the grid.
@export var num_of_cols: int = 3
## Number of rows in the grid.
@export var num_of_rows: int = 3
## Horizontal distance between card centers.
@export var col_offset: float = 120.0
## Vertical distance between card centers.
@export var row_offset: float = 150.0
## If true, arrange cards by rows (left to right, then down). If false, by columns.
@export var arrange_by_rows: bool = true


func _init(cols: int = num_of_cols, rows: int = num_of_rows, col_spacing: float = col_offset, row_spacing: float = row_offset, by_rows: bool = arrange_by_rows) -> void:
	num_of_cols = cols
	num_of_rows = rows
	col_offset = col_spacing
	row_offset = row_spacing
	arrange_by_rows = by_rows


func _compute_raw_cards(cards: Array[Card]) -> LayoutResult:
	var card_count = cards.size()
	var positions: Array[Vector2] = []
	var rotations: Array[float] = []

	var actual_cols = maxi(1, num_of_cols)
	var actual_rows = maxi(1, num_of_rows)

	if arrange_by_rows:
		actual_rows = ceili(float(card_count) / float(actual_cols))
	else:
		actual_cols = ceili(float(card_count) / float(actual_rows))

	var total_width = (actual_cols - 1) * col_offset
	var total_height = (actual_rows - 1) * row_offset
	var start_x = -total_width / 2.0
	var start_y = -total_height / 2.0

	for i in card_count:
		var grid_x: int
		var grid_y: int

		if arrange_by_rows:
			grid_x = i % actual_cols
			grid_y = i / actual_cols
		else:
			grid_x = i / actual_rows
			grid_y = i % actual_rows

		var x_offset = 0.0
		var y_offset = 0.0

		if arrange_by_rows:
			if grid_y == actual_rows - 1:
				var cards_in_last_row = card_count - (grid_y * actual_cols)
				if cards_in_last_row < actual_cols:
					x_offset = (actual_cols - cards_in_last_row) * col_offset / 2.0
		else:
			if grid_x == actual_cols - 1:
				var cards_in_last_col = card_count - (grid_x * actual_rows)
				if cards_in_last_col < actual_rows:
					y_offset = (actual_rows - cards_in_last_col) * row_offset / 2.0

		var x_pos = start_x + grid_x * col_offset + x_offset
		var y_pos = start_y + grid_y * row_offset + y_offset
		positions.append(Vector2(x_pos, y_pos))
		rotations.append(0.0)

	return LayoutResult.new(positions, rotations)


func get_focus_neighbor(index: int, direction: String, card_count: int) -> int:
	if index < 0 or index >= card_count:
		return -1

	var actual_cols = maxi(1, num_of_cols)
	var actual_rows = maxi(1, num_of_rows)
	if arrange_by_rows:
		actual_rows = ceili(float(card_count) / float(actual_cols))
	else:
		actual_cols = ceili(float(card_count) / float(actual_rows))

	var grid_x: int
	var grid_y: int
	if arrange_by_rows:
		grid_x = index % actual_cols
		grid_y = index / actual_cols
	else:
		grid_x = index / actual_rows
		grid_y = index % actual_rows

	var target_x = grid_x
	var target_y = grid_y
	match direction:
		"left":  target_x -= 1
		"right": target_x += 1
		"up":    target_y -= 1
		"down":  target_y += 1
		_: return -1

	if target_x < 0 or target_x >= actual_cols: return -1
	if target_y < 0 or target_y >= actual_rows: return -1

	var target_index: int
	if arrange_by_rows:
		target_index = target_y * actual_cols + target_x
	else:
		target_index = target_x * actual_rows + target_y

	if target_index < 0 or target_index >= card_count: return -1
	return target_index
