##A UI panel slot that detects when a held card is hovering over it and places dropped cards in its center
@icon("uid://campsjrxwba25")
class_name CardSlot extends Panel

##Emitted when a card starts hovering over this slot
signal card_entered(card: Card)
##Emitted when a card stops hovering over this slot
signal card_exited(card: Card)
##Emitted when a card is dropped on this slot
signal card_dropped(card: Card)

var held_card: Card = null

var _card_over: bool = false
var _card_currently_over: Card = null
var _held_card_on_drop: Card = null

func _ready() -> void:
	CG.holding_card.connect(_on_card_held)
	CG.dropped_card.connect(_on_card_dropped)


func _process(_delta: float) -> void:
	if CG.current_held_item == null:
		return
	
	var cursor_pos = CG.get_cursor_position()
	var is_over = get_global_rect().has_point(cursor_pos)
	
	if is_over and not _card_over:
		_card_over = true
		_card_currently_over = CG.current_held_item
		_held_card_on_drop = CG.current_held_item
		card_entered.emit(_card_currently_over)
	
	elif not is_over and _card_over:
		_card_over = false
		if _card_currently_over:
			card_exited.emit(_card_currently_over)
		_card_currently_over = null


func _on_card_held(card: Card) -> void:
	_card_over = false


func _on_card_dropped() -> void:
	if _card_over and _card_currently_over:
		_handle_card_drop(_card_currently_over)
	else:
		_return_card_to_parent(_held_card_on_drop)
	
	_card_over = false
	_card_currently_over = null
	_held_card_on_drop = null


#region Signal Management
func _connect_card_signals(card: Card) -> void:
	card.card_clicked.connect(_on_card_clicked)

func _disconnect_card_signals(card: Card) -> void:
	if card.card_clicked.is_connected(_on_card_clicked):
		card.card_clicked.disconnect(_on_card_clicked)

##Used when the card in the slot is clicked. [color=red]Overwrite[/color] to implement card action.
func _on_card_clicked(card: Card) -> void:
	print("Card clicked in slot: ", card.name)

#endregion


##Handles placing a card in this slot. If slot is occupied, swaps with the occupant.
func _handle_card_drop(incoming_card: Card) -> void:
	var current_card = held_card
	var incoming_card_parent = incoming_card.get_parent()
	
	if not current_card:
		_place_card(incoming_card)
		return
	
	var original_parent = incoming_card_parent
	var original_slot: CardSlot = null if original_parent is not CardSlot else original_parent
	var incoming_was_in_hand = original_parent is CardHand
	var incoming_was_in_slot = original_parent is CardSlot
	_disconnect_card_signals(current_card)

	if incoming_was_in_hand:
		original_parent.remove_card(incoming_card, self)
	elif incoming_was_in_slot:
		original_parent._disconnect_card_signals(incoming_card)
		original_parent.held_card = null
		incoming_card.reparent(self)
	else:
		if incoming_card.get_parent():
			incoming_card.reparent(self)
		else:
			add_child(incoming_card)
	
	held_card = incoming_card
	_connect_card_signals(incoming_card)
	_position_card_in_center(incoming_card)
	
	if incoming_was_in_hand:
		original_parent.add_card(current_card)
	elif incoming_was_in_slot:
		current_card.reparent(original_slot)
		original_slot.held_card = current_card
		original_slot._connect_card_signals(current_card)
		original_slot._position_card_in_center(current_card)
	
	card_dropped.emit(incoming_card)


##Returns a card to its original parent/location if dropped on invalid spot
func _return_card_to_parent(card: Card) -> void:
	if not card:
		return
	
	var parent = card.get_parent()
	
	if parent is CardHand:
		_disconnect_card_signals(card)
		parent.refresh_arrangement()
	elif parent is CardSlot:
		parent._position_card_in_center(card)


##Positions a card at the center of this slot
func _position_card_in_center(card: Card) -> void:
	card.kill_all_tweens()
	card.rotation = 0.0
	card.scale = Vector2.ONE
	var slot_rect = get_global_rect()
	var slot_center = slot_rect.get_center()
	var card_pivot = card.pivot_offset
	card.global_position = slot_center - card_pivot


##Places a card in an empty slot
func _place_card(card: Card) -> void:
	if card.get_parent() == self:
		_position_card_in_center(card)
		return
	
	var current_parent = card.get_parent()
	if current_parent is CardSlot:
		current_parent._disconnect_card_signals(card)
		current_parent.held_card = null
		card.reparent(self)
	elif current_parent is CardHand:
		current_parent.remove_card(card, self)
	else:
		if current_parent:
			card.reparent(self)
		else:
			add_child(card)

	held_card = card
	_connect_card_signals(card)
	_position_card_in_center(card)
	card_dropped.emit(card)
