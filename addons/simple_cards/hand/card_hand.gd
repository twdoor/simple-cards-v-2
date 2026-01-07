##A card container used to dynamicaly store cards.
@icon("uid://1g0jb8x0i516")
class_name CardHand extends Control


##Shape of card spread. 
@export var shape: CardHandShape 
##If [code]true[/code] the hand will reorder after any change in the cards.
@export var enable_reordering: bool = true
##Maximum number of cards allowed in the hand. Set to -1 for no limit.
@export var max_hand_size: int = -1


var _cards: Array[Card] = []
##Stores the cards in the hand. Getter returns a duplicate of the array
var cards: Array[Card]:
	get:
		return _cards.duplicate()
var _card_positions: Array[Vector2] = []
var _dragged_card: Card = null
var _drag_start_index: int = -1
var _last_reorder_index: int = -1

func _ready() -> void:
	if !shape:
		shape = LineHandShape.new()
		push_warning("No shape selected, using default")
	
	var children = get_children()
	for child in children:
		if child is Card:
			add_card(child)
	CG.dropped_card.connect(_on_card_dropped)
	CG.holding_card.connect(_on_holding_card)

func _process(_delta: float) -> void:
	if enable_reordering and _dragged_card:
		_update_card_reordering()


func _exit_tree() -> void:
	CG.dropped_card.disconnect(_on_card_dropped)
	CG.holding_card.disconnect(_on_holding_card)


##Adds a card to the hand. The card get reparented as a child of the hand. Returns [code]true[/code] if successful. [br]If the card is already a child of the hand the [member CardHand.remove_card] is used to reparent the card.
func add_card(card: Card) -> bool:
	if max_hand_size >= 0 and _cards.size() >= max_hand_size:
		return false
	
	if card.get_parent() != self:
		if card.get_parent():
			if card.get_parent() is CardHand:
				card.get_parent().remove_card(card, self)
			else:
				card.reparent(self)
		else:
			add_child(card)
	
	if !_cards.has(card):
		_cards.append(card)
		_connect_card_signals(card)
	
	_arrange_cards()
	return true


##Removes specific card from hand. [color=red]DOES NOT FREE THE CARD[/color]
func remove_card(card: Card, new_parent: Node = null) -> void:
	if _cards.has(card):
		_disconnect_card_signals(card)
		_cards.erase(card)
		
		if card.get_parent() == self:
			if new_parent:
				card.reparent(new_parent)
			else:
				var stored_global_pos = card.global_position
				remove_child(card)
				card.global_position = stored_global_pos

		_arrange_cards()


##Empties hand. [color=red]DOES NOT FREE THE CARD[/color]
func clear_hand() -> void:
	var cards_copy = _cards.duplicate()
	_cards.clear()
	_card_positions.clear()
	
	for card in cards_copy:
		_disconnect_card_signals(card)
		if card.get_parent() == self:
			var stored_global_pos = card.global_position
			remove_child(card)
			card.global_position = stored_global_pos


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
	if _dragged_card and _dragged_card.get_parent() != self:
		if _cards.has(_dragged_card):
			_disconnect_card_signals(_dragged_card)
			_cards.erase(_dragged_card)
	
	_arrange_cards()
	_dragged_card = null
	_drag_start_index = -1
	_last_reorder_index = -1


func _on_holding_card(card: Card) -> void:
	if _cards.has(card):
		_dragged_card = card
		_drag_start_index = get_card_index(card)
		_last_reorder_index = _drag_start_index
	else:
		_dragged_card = null
		_drag_start_index = -1
		_last_reorder_index = -1


##Used when a card from hand is clicked. [color=red]Overwrite[/color] to implement card action.
func _handle_clicked_card(card: Card) -> void:
	print("%s: %s was clicked" %[self.name, card.name])

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
		_cards.remove_at(_drag_start_index)
		_cards.insert(new_index, _dragged_card)
		_drag_start_index = new_index
		_last_reorder_index = new_index
		
		_arrange_cards_except_dragged()


func _find_insertion_index(cursor_pos: Vector2) -> int:
	##Determine insertion index based on cursor passing card centers.
	if _cards.size() <= 1:
		return 0
	
	var other_cards: Array[Dictionary] = []
	for i in range(_cards.size()):
		var card = _cards[i]
		if card != _dragged_card:
			other_cards.append({
				"card": card,
				"index": i
			})
	
	if other_cards.is_empty():
		return 0
	
	var current_slot := 0
	for i in range(other_cards.size()):
		if other_cards[i].index > _drag_start_index:
			break
		current_slot = i + 1
	
	if current_slot > 0:
		var left_card: Card = other_cards[current_slot - 1].card
		var left_center_x = left_card.global_position.x + left_card.center_pos.x
		
		if cursor_pos.x < left_center_x:
			return other_cards[current_slot - 1].index
	
	if current_slot < other_cards.size():
		var right_card: Card = other_cards[current_slot].card
		var right_center_x = right_card.global_position.x + right_card.center_pos.x
		
		if cursor_pos.x > right_center_x:
			return other_cards[current_slot].index
	
	return _drag_start_index

#endregion


#region Arrangement Management


func _arrange_cards() -> void:
	if _cards.is_empty():
		return
	
	_card_positions.clear()
	
	_card_positions = shape.arrange_cards(_cards, self)
	
	_update_z_indices()
	_update_focus_chain()


func _arrange_cards_except_dragged() -> void:
	if _cards.is_empty():
		return
	
	_card_positions.clear()
	
	_card_positions = shape.arrange_cards(_cards, self, [_dragged_card])

	_update_z_indices()
	_update_focus_chain()

#endregion


func _update_z_indices() -> void:
	for i in _cards.size():
		if _cards[i] != _dragged_card:
			_cards[i].z_index = i


func _update_focus_chain() -> void:
	var card_count = _cards.size()
	if card_count == 0:
		return
	
	for i in card_count:
		var card = _cards[i]
		
		var prev_index = (i - 1 + card_count) % card_count
		card.focus_neighbor_left = card.get_path_to(_cards[prev_index])
		card.focus_previous = card.get_path_to(_cards[prev_index])
		
		var next_index = (i + 1) % card_count
		card.focus_neighbor_right = card.get_path_to(_cards[next_index])
		card.focus_next = card.get_path_to(_cards[next_index])


##Helper function to add a great number of cards into the hand. Returns the number of cards successfully added. [br]If the card is already a child of the hand the [member CardHand.remove_card] is used to reparent the card.
func add_cards(card_array: Array[Card]) -> int:
	var added_count = 0
	for card in card_array:
		if max_hand_size >= 0 and _cards.size() >= max_hand_size:
			break
		
		if card.get_parent() != self:
			if card.get_parent() is CardHand:
				card.get_parent().remove_card(card, self)
			elif card.get_parent():
				card.reparent(self)
			else:
				add_child(card)
		
		if not _cards.has(card):
			_cards.append(card)
			_connect_card_signals(card)
			added_count += 1
	
	_arrange_cards()
	return added_count


##Helper function to get a card by its position index in the hand.
func get_card(index: int) -> Card:
	if index >= 0 and index < _cards.size():
		return _cards[index]
	return null


##Returns the number of cards in the hand.
func get_card_count() -> int:
	return _cards.size()


##Helper function to get the index of a [Card]. Returns the index value as an [int].
func get_card_index(card: Card) -> int:
	return _cards.find(card)


##Returns [code]true[/code] if the hand is full (has reached max_hand_size).
func is_hand_full() -> bool:
	if max_hand_size < 0:
		return false
	return _cards.size() >= max_hand_size


##Returns the number of remaining slots in the hand. Returns -1 if there is no limit.
func get_remaining_space() -> int:
	if max_hand_size < 0:
		return -1
	return max(0, max_hand_size - _cards.size())


func refresh_arrangement() -> void:
	_arrange_cards()
