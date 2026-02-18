## A card container used to dynamically store and arrange cards.
##
## CardHand manages [Card] nodes as children and provides add, remove, arrange,
## and reorder operations. It uses a [CardHandShape] to compute visual layout.
## [br][br]
## For game-specific behavior (selection, validation, multi-drag), extend this class
## and override [method _on_card_added], [method _on_card_removed], or
## [method _handle_clicked_card].
@icon("uid://b5yeseh7avtmy")
class_name CardHand extends Control  


#region Signals

## Emitted when a card is added to the hand.
signal card_added(card: Card, index: int)
## Emitted when a card is removed from the hand.
signal card_removed(card: Card, index: int)
## Emitted when the last card is removed.
signal hand_empty()
## Emitted when [member max_hand_size] is reached.
signal hand_full()
## Emitted when [method clear_hand] or [method clear_and_free] is called.
signal hand_cleared()
## Emitted when cards are reordered.
signal cards_reordered(new_order: Array[Card])
## Emitted when a specific card changes position in hand.
signal card_position_changed(card: Card, old_index: int, new_index: int)
## Emitted before [method arrange_cards].
signal arrangement_started()
## Emitted after [method arrange_cards] completes.
signal arrangement_completed()

#endregion


#region Exports

## Shape of card spread.
@export var shape: CardHandShape:
	set(value):
		shape = value
		if !cards.is_empty():
			arrange_cards()

## If [code]true[/code] the hand will reorder cards during drag.
@export var enable_reordering: bool = true

## Maximum number of cards allowed in the hand. Set to -1 for no limit.
@export var max_hand_size: int = -1

#endregion


## Stores the cards in the hand.
var cards: Array[Card] = []
var _card_positions: Array[Vector2] = []
var _dragged_card: Card = null
var _drag_start_index: int = -1
var _last_reorder_index: int = -1
## Guard flag to prevent child_exiting_tree from firing during intentional bulk operations.
var _suppress_auto_remove: bool = false


func _ready() -> void:
	if !shape:
		shape = LineHandShape.new()
		push_warning("No shape selected, using default")
	
	child_exiting_tree.connect(_on_card_child_exiting)
	
	var children = get_children()
	for child in children:
		if child is Card:
			add_card(child)
	CG.dropped_card.connect(_on_card_dropped)
	CG.holding_card.connect(_on_holding_card)

	
	set_process(false)


func _process(_delta: float) -> void:
	_update_card_reordering()


func _exit_tree() -> void:
	CG.dropped_card.disconnect(_on_card_dropped)
	CG.holding_card.disconnect(_on_holding_card)


#region Adding Cards

## Adds a card to the hand. Returns [code]true[/code] if successful.
func add_card(card: Card) -> bool:
	if max_hand_size >= 0 and cards.size() >= max_hand_size:
		hand_full.emit()
		return false
	
	if cards.has(card):
		return false
	
	_take_card(card)
	cards.append(card)
	_connect_card_signals(card)
	_on_card_added(card, cards.size() - 1)
	card_added.emit(card, cards.size() - 1)
	
	if max_hand_size >= 0 and cards.size() >= max_hand_size:
		hand_full.emit()
	
	arrange_cards()
	return true


## Adds multiple cards to the hand. Returns the number of cards successfully added.
func add_cards(card_array: Array[Card]) -> int:
	var added_count = 0
	
	for card in card_array:
		if max_hand_size >= 0 and cards.size() >= max_hand_size:
			hand_full.emit()
			break
		
		if cards.has(card):
			continue
		
		_take_card(card)
		cards.append(card)
		_connect_card_signals(card)
		_on_card_added(card, cards.size() - 1)
		card_added.emit(card, cards.size() - 1)
		added_count += 1
	
	if added_count > 0:
		if max_hand_size >= 0 and cards.size() >= max_hand_size:
			hand_full.emit()
		arrange_cards()
	
	return added_count

#endregion


#region Removing Cards

## Removes a specific card from the hand. Returns the card if found and removed.
## [color=red]Does NOT free the card.[/color]
func remove_card(card: Card) -> Card:
	if not cards.has(card):
		return null
	
	if card.get_parent() == self:
		var stored_global_pos = card.global_position
		remove_child(card)
		card.global_position = stored_global_pos
	else:
		_on_card_child_exiting(card)
	
	return card


## Removes all cards from the hand. [color=red]Does NOT free the cards.[/color]
func clear_hand() -> void:
	_suppress_auto_remove = true
	var cards_copy = cards.duplicate()
	cards.clear()
	_card_positions.clear()
	
	for card in cards_copy:
		_disconnect_card_signals(card)
		if card.get_parent() == self:
			var stored_global_pos = card.global_position
			remove_child(card)
			card.global_position = stored_global_pos
	
	_suppress_auto_remove = false
	update_minimum_size()
	hand_cleared.emit()
	hand_empty.emit()


## Removes all cards from the hand and frees them.
func clear_and_free() -> void:
	_suppress_auto_remove = true
	for card in cards:
		_disconnect_card_signals(card)
		card.queue_free()
	cards.clear()
	_card_positions.clear()
	_suppress_auto_remove = false
	update_minimum_size()
	hand_cleared.emit()
	hand_empty.emit()

#endregion


#region Queries

## Returns the card at the given index, or [code]null[/code] if out of bounds.
func get_card(index: int) -> Card:
	if index >= 0 and index < cards.size():
		return cards[index]
	return null


## Returns the number of cards in the hand.
func get_card_count() -> int:
	return cards.size()


## Returns the index of a card in the hand, or -1 if not found.
func get_card_index(card: Card) -> int:
	return cards.find(card)


## Returns [code]true[/code] if the hand contains the given card.
func has_card(card: Card) -> bool:
	return cards.has(card)


## Returns [code]true[/code] if the hand is full (has reached [member max_hand_size]).
func is_hand_full() -> bool:
	if max_hand_size < 0:
		return false
	return cards.size() >= max_hand_size


## Returns the number of remaining slots. Returns -1 if there is no limit.
func get_remaining_space() -> int:
	if max_hand_size < 0:
		return -1
	return max(0, max_hand_size - cards.size())


## Sort cards using a custom comparison function.
func sort_cards(compare_func: Callable) -> void:
	cards.sort_custom(compare_func)
	arrange_cards()

#endregion


#region Arrangement

func arrange_cards() -> void:
	if cards.is_empty():
		_card_positions.clear()
		update_minimum_size()
		return
	
	arrangement_started.emit()
	
	var layout = shape.compute_layout(cards)
	_card_positions = layout.positions
	
	_update_z_indices()
	_update_focus_chain()
	update_minimum_size()
	
	shape.apply_layout(cards, layout)
	
	cards_reordered.emit(cards)
	arrangement_completed.emit()


func _arrange_cards_except_dragged(skipped_cards: Array[Card]) -> void:
	if cards.is_empty():
		return
	
	arrangement_started.emit()
	
	var layout = shape.compute_layout(cards)
	_card_positions = layout.positions
	
	_update_z_indices()
	_update_focus_chain()
	
	shape.apply_layout(cards, layout, skipped_cards)
	
	arrangement_completed.emit()


func _get_minimum_size() -> Vector2:
	if cards.is_empty() or _card_positions.is_empty():
		return Vector2.ZERO

	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF

	for i in cards.size():
		var card_position = _card_positions[i]
		var card_size = cards[i].size
		var card_top_left = card_position - card_size / 2
		var card_bottom_right = card_position + card_size / 2

		min_x = min(min_x, card_top_left.x)
		min_y = min(min_y, card_top_left.y)
		max_x = max(max_x, card_bottom_right.x)
		max_y = max(max_y, card_bottom_right.y)

	return Vector2(max_x - min_x, max_y - min_y)

#endregion


#region Reordering

func _update_card_reordering() -> void:
	if not _dragged_card or _drag_start_index == -1:
		return
	
	if not _dragged_card.holding:
		return
	
	var cursor_pos = CG.get_cursor_position()
	var new_index = _find_insertion_index(cursor_pos)
	
	if new_index != -1 and new_index != _drag_start_index:
		cards.remove_at(_drag_start_index)
		cards.insert(new_index, _dragged_card)
		
		card_position_changed.emit(_dragged_card, _drag_start_index, new_index)
		
		_drag_start_index = new_index
		_last_reorder_index = new_index
		
		_arrange_cards_except_dragged([_dragged_card])


func _find_insertion_index(cursor_pos: Vector2) -> int:
	if cards.size() <= 1:
		return 0
	
	if _card_positions.is_empty():
		return _drag_start_index

	var local_cursor = cursor_pos - global_position
	
	var best_index := _drag_start_index
	var best_dist := INF
	
	for i in range(_card_positions.size()):
		var dist = local_cursor.distance_squared_to(_card_positions[i])
		if dist < best_dist:
			best_dist = dist
			best_index = i
	
	return best_index

#endregion


#region Overridable Callbacks

## Called when a card is added to the hand. Override to implement custom behavior.
func _on_card_added(card: Card, index: int) -> void:
	pass


## Called when a card is removed from the hand. Override to implement custom behavior.
func _on_card_removed(card: Card, index: int) -> void:
	pass


## Called when a card in the hand is clicked. Override to implement custom behavior.
func _handle_clicked_card(card: Card) -> void:
	pass

#endregion


#region Signal Management

func _connect_card_signals(card: Card) -> void:
	if not card.focus_entered.is_connected(_on_card_focused):
		card.focus_entered.connect(_on_card_focused.bind(card))
	if not card.focus_exited.is_connected(_on_card_unfocused):
		card.focus_exited.connect(_on_card_unfocused.bind(card))
	if not card.card_clicked.is_connected(_handle_clicked_card):
		card.card_clicked.connect(_handle_clicked_card)


func _disconnect_card_signals(card: Card) -> void:
	if card.focus_entered.is_connected(_on_card_focused):
		card.focus_entered.disconnect(_on_card_focused)
	if card.focus_exited.is_connected(_on_card_unfocused):
		card.focus_exited.disconnect(_on_card_unfocused)
	if card.card_clicked.is_connected(_handle_clicked_card):
		card.card_clicked.disconnect(_handle_clicked_card)


func _on_card_focused(card: Card) -> void:
	if _dragged_card != null:
		return
	card.z_index = 900
	

func _on_card_unfocused(card: Card) -> void:
	if _dragged_card != null:
		return
	_update_z_indices()


func _on_card_dropped() -> void:
	_finish_card_drop.call_deferred()


func _finish_card_drop() -> void:
	arrange_cards()
	_dragged_card = null
	_drag_start_index = -1
	_last_reorder_index = -1
	set_process(false)


func _on_holding_card(card: Card) -> void:
	if cards.has(card):
		_dragged_card = card
		_drag_start_index = get_card_index(card)
		_last_reorder_index = _drag_start_index
		
		if enable_reordering:
			set_process(true)
	else:
		_dragged_card = null
		_drag_start_index = -1
		_last_reorder_index = -1
		
		set_process(false)

#endregion


#region Internal Helpers

func _update_z_indices() -> void:
	for i in cards.size():
		if cards[i] != _dragged_card:
			cards[i].z_index = i


func _update_focus_chain() -> void:
	var card_count = cards.size()
	if card_count == 0:
		return
	
	for i in card_count:
		var card = cards[i]
		
		var prev_index = (i - 1 + card_count) % card_count
		card.focus_neighbor_left = card.get_path_to(cards[prev_index])
		card.focus_previous = card.get_path_to(cards[prev_index])
		
		var next_index = (i + 1) % card_count
		card.focus_neighbor_right = card.get_path_to(cards[next_index])
		card.focus_next = card.get_path_to(cards[next_index])


func _take_card(card: Card) -> void:
	card.kill_all_tweens()
	var parent = card.get_parent()
	
	if parent == self:
		return
	
	if parent:
		card.reparent(self, true)
	else:
		var stored_pos = card.global_position
		add_child(card)
		card.global_position = stored_pos
	
	card.rotation = 0


func _on_card_child_exiting(node: Node) -> void:
	if _suppress_auto_remove:
		return
	if not node is Card:
		return
	var card: Card = node as Card
	if not cards.has(card):
		return
	
	var index = cards.find(card)
	cards.remove_at(index)
	_disconnect_card_signals(card)
	
	_on_card_removed(card, index)
	card_removed.emit(card, index)
	
	if cards.is_empty():
		hand_empty.emit()
	
	arrange_cards()

#endregion
