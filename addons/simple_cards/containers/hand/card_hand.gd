## A card container that arranges cards in a visual hand layout.
##
## Provides drag-based reordering, focus chain management, and z-index stacking.
## For game-specific behavior (selection, validation, multi-drag), extend this class
## and override [method _on_card_added], [method _on_card_removed], or
## [method _handle_clicked_card].
@icon("uid://b5yeseh7avtmy")
class_name CardHand extends CardContainer


#region Signals

## Emitted when cards are reordered.
signal cards_reordered(new_order: Array[Card])
## Emitted when a specific card changes position in hand.
signal card_position_changed(card: Card, old_index: int, new_index: int)

#endregion


#region Exports

## If [code]true[/code] the hand will reorder cards during drag.
@export var enable_reordering: bool = true

#endregion


var _dragged_card: Card = null
var _drag_start_index: int = -1
var _last_reorder_index: int = -1


#region Setup

func _container_ready() -> void:
	if !shape:
		shape = LineShape.new()
		push_warning("CardHand: No shape selected, using default LineShape")
	
	CG.dropped_card.connect(_on_card_dropped)
	CG.holding_card.connect(_on_holding_card)
	
	for child in get_children():
		if child is Card and !cards.has(child):
			cards.append(child)
			_connect_card_signals(child)
	
	if !cards.is_empty():
		arrange(0)
	
	set_process(false)


func _exit_tree() -> void:
	if CG.dropped_card.is_connected(_on_card_dropped):
		CG.dropped_card.disconnect(_on_card_dropped)
	if CG.holding_card.is_connected(_on_holding_card):
		CG.holding_card.disconnect(_on_holding_card)

#endregion


#region Layout Overrides

func _compute_layout() -> void:
	super._compute_layout()
	if !cards.is_empty():
		_update_z_indices()
		_update_focus_chain()


func _settle_card(card: Card, duration: float) -> void:
	if card == _dragged_card: return
	super._settle_card(card, duration)

#endregion


#region Reordering

func _process(_delta: float) -> void:
	_update_card_reordering()


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
		
		_compute_layout()
		for card in cards:
			if card == _dragged_card: continue
			if card.holding: continue
			_settle_card(card, card_move_duration)


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
	if _dragged_card != null: return
	card.z_index = 900
	

func _on_card_unfocused(card: Card) -> void:
	if _dragged_card != null: return
	_update_z_indices()


func _on_card_dropped() -> void:
	_finish_card_drop.call_deferred()


func _finish_card_drop() -> void:
	_dragged_card = null
	_drag_start_index = -1
	_last_reorder_index = -1
	set_process(false)
	arrange()


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


#region Overridable Callbacks

## Called when a card in the hand is clicked. Override to implement selection, etc.
func _handle_clicked_card(card: Card) -> void:
	pass

#endregion


#region Internal Helpers

func _update_z_indices() -> void:
	for i in cards.size():
		if cards[i] != _dragged_card:
			cards[i].z_index = i


func _update_focus_chain() -> void:
	var card_count = cards.size()
	if card_count == 0: return
	
	for i in card_count:
		var card = cards[i]
		
		var prev_index = (i - 1 + card_count) % card_count
		card.focus_neighbor_left = card.get_path_to(cards[prev_index])
		card.focus_previous = card.get_path_to(cards[prev_index])
		
		var next_index = (i + 1) % card_count
		card.focus_neighbor_right = card.get_path_to(cards[next_index])
		card.focus_next = card.get_path_to(cards[next_index])

#endregion
