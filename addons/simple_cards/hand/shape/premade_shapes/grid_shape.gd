##Grid arrangement shape for card hands.
class_name GridHandShape extends CardHandShape

##Number of columns in the grid
@export var num_of_cols: int = 3
##Number of rows in the grid
@export var num_of_rows: int = 3
##Horizontal distance between card centers
@export var col_offset: float = 120.0
##Vertical distance between card centers
@export var row_offset: float = 150.0
##If true, arrange cards by rows (left to right, then down). If false, arrange by columns (top to bottom, then right)
@export var arrange_by_rows: bool = true

func _init(cols: int = num_of_cols, rows: int = num_of_rows, col_spacing: float = col_offset, row_spacing: float = row_offset, by_rows: bool = arrange_by_rows) -> void:
	num_of_cols = cols
	num_of_rows = rows
	col_offset = col_spacing
	row_offset = row_spacing
	arrange_by_rows = by_rows


func arrange_cards(cards: Array[Card], hand: CardHand, skipped_cards: Array[Card] = []) -> Array[Vector2]:
	var card_count = cards.size()
	var card_positions: Array[Vector2]
	if card_count == 0:
		return []

	var actual_cols = num_of_cols
	var actual_rows = num_of_rows
	
	if arrange_by_rows:
		actual_rows = ceili(float(card_count) / float(num_of_cols))
	else:
		actual_cols = ceili(float(card_count) / float(num_of_rows))
	
	var total_width = (actual_cols - 1) * col_offset
	var total_height = (actual_rows - 1) * row_offset
	var start_x = -total_width / 2.0
	var start_y = -total_height / 2.0
	
	for i in card_count:
		var card = cards[i]
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
		var grid_pos = Vector2(x_pos, y_pos)
		
		var final_pos = grid_pos - card.pivot_offset
		
		card_positions.append(grid_pos)
		if !skipped_cards.is_empty() and skipped_cards.has(card):
			continue
		
		var pos = final_pos + card.position_offset
		card.tween_position(pos + hand.global_position, .2, true)
		card.rotation = card.rotation_offset
	
	return card_positions
