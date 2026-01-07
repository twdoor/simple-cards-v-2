##A UI panel slot that detects when a held card is hovering over it and places dropped cards in its center
@icon("uid://campsjrxwba25")
class_name CardSlot extends Panel

##Emitted when a card starts hovering over this slot
signal card_entered(card: Card)
##Emitted when a card stops hovering over this slot
signal card_exited(card: Card)
##Emitted when a card is dropped on this slot
signal card_dropped(card: Card)
##Emitted when a card is abandoned (dropped on empty space with abandon_on_empty_space enabled)
signal card_abandoned(card: Card)
##Emitted when the slot's locked state changes
signal slot_lock_changed(is_locked: bool)


##When true, prevents cards from being dragged out of or swapped into this slot
@export var slot_locked: bool = false:
	set(value):
		slot_locked = value
		slot_lock_changed.emit(slot_locked)

##When false, dropping a card on an occupied slot will be rejected instead of swapping
@export var allow_swap: bool = true

##When true, cards dropped on empty space will be removed from the slot instead of returning to center
@export var abandon_on_empty_space: bool = false
##The node to reparent abandoned cards to. If null, defaults to this slot's parent
@export var abandon_reparent_target: Node = null

var placement_duration: float = 0.15

var held_card: Card = null

var _card_over: bool = false
var _card_currently_over: Card = null
## Tracks the original parent of the card when dragging started (for returning cards)
var _card_origin_parent: Node = null
## Tracks if the card being dragged originated from THIS slot
var _card_originated_from_this_slot: bool = false

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
		card_entered.emit(_card_currently_over)
	
	elif not is_over and _card_over:
		_card_over = false
		if _card_currently_over:
			card_exited.emit(_card_currently_over)
		_card_currently_over = null


##Locks the slot, preventing cards from being dragged out or swapped in
func lock() -> void:
	slot_locked = true


##Unlocks the slot, allowing normal card interactions
func unlock() -> void:
	slot_locked = false


##Returns whether the slot is currently locked
func is_locked() -> bool:
	return slot_locked


##Adds a card to this slot via code. Returns [code]true[/code] if successful. [br]Fails if slot is occupied or locked. Handles reparenting from CardHand or other CardSlot.
func add_card(card: Card) -> bool:
	if slot_locked:
		return false
	if held_card != null:
		return false
	
	var current_parent = card.get_parent()
	
	if current_parent is CardSlot and current_parent.slot_locked:
		return false
	
	if current_parent is CardSlot:
		current_parent._disconnect_card_signals(card)
		current_parent.held_card = null
		card.reparent(self)
	elif current_parent is CardHand:
		current_parent.remove_card(card, self)
	elif current_parent:
		card.reparent(self)
	else:
		add_child(card)
	
	held_card = card
	_connect_card_signals(card)
	_position_card_in_center(card)
	card_dropped.emit(card)
	return true


##Removes the card from this slot. [color=red]DOES NOT FREE THE CARD[/color] [br]Returns the removed card, or [code]null[/code] if slot was empty or locked.
func remove_card(new_parent: Node = null) -> Card:
	if slot_locked:
		return null
	if held_card == null:
		return null
	
	var card = held_card
	_disconnect_card_signals(card)
	held_card = null
	
	if card.get_parent() == self:
		if new_parent:
			card.reparent(new_parent)
		else:
			var stored_global_pos = card.global_position
			remove_child(card)
			card.global_position = stored_global_pos
	
	return card


##Clears the slot, removing any held card. [color=red]DOES NOT FREE THE CARD[/color] [br]Returns the removed card, or [code]null[/code] if slot was empty. [br]If [param force] is [code]true[/code], clears even if locked.
func clear_slot(force: bool = false) -> Card:
	if slot_locked and not force:
		return null
	if held_card == null:
		return null
	
	var card = held_card
	_disconnect_card_signals(card)
	held_card = null
	
	if card.get_parent() == self:
		var stored_global_pos = card.global_position
		remove_child(card)
		card.global_position = stored_global_pos
	
	return card


##Returns [code]true[/code] if the slot is empty (no card held).
func is_empty() -> bool:
	return held_card == null


##Swaps cards between this slot and another slot. Returns [code]true[/code] if successful. [br]Fails if either slot is locked.
func swap_with(other_slot: CardSlot) -> bool:
	if slot_locked or other_slot.slot_locked:
		return false
	
	var this_card = held_card
	var other_card = other_slot.held_card
	
	if this_card:
		_disconnect_card_signals(this_card)
	if other_card:
		other_slot._disconnect_card_signals(other_card)
	
	if this_card:
		this_card.reparent(other_slot)
	if other_card:
		other_card.reparent(self)
	
	held_card = other_card
	other_slot.held_card = this_card

	if held_card:
		_connect_card_signals(held_card)
		_position_card_in_center(held_card)
	if other_slot.held_card:
		other_slot._connect_card_signals(other_slot.held_card)
		other_slot._position_card_in_center(other_slot.held_card)
	
	return true


##Transfers the card from this slot to a CardHand. Returns [code]true[/code] if successful.
func transfer_to_hand(hand: CardHand) -> bool:
	if slot_locked:
		return false
	if held_card == null:
		return false
	
	var card = held_card
	_disconnect_card_signals(card)
	held_card = null
	
	return hand.add_card(card)


##Gets the card in this slot without removing it. Returns [code]null[/code] if empty.
func get_card() -> Card:
	return held_card


func _on_card_held(card: Card) -> void:
	if slot_locked and card.get_parent() == self:
		_force_return_card.call_deferred(card)
		return

	if card.get_parent() == self:
		_card_originated_from_this_slot = true
		_card_origin_parent = self
	else:
		_card_originated_from_this_slot = false
		_card_origin_parent = card.get_parent()
	
	_card_over = false


##Forces a card back to this slot (used when trying to drag from a locked slot)
func _force_return_card(card: Card) -> void:
	if held_card == card:
		card.holding = false
		_position_card_in_center(card)
		if CG.current_held_item == card:
			CG.current_held_item = null


func _on_card_dropped() -> void:
	if _card_over and _card_currently_over:
		_handle_card_drop(_card_currently_over)
	elif _card_originated_from_this_slot and held_card:
		if held_card.get_parent() == self:
			if abandon_on_empty_space: _abandon_card(held_card)
			else: _position_card_in_center(held_card)
	
	# Reset state
	_card_over = false
	_card_currently_over = null
	_card_originated_from_this_slot = false
	_card_origin_parent = null


##Removes the card from the slot and reparents it to abandon_reparent_target (or slot's parent)
func _abandon_card(card: Card) -> void:
	if not card:
		return
	
	_disconnect_card_signals(card)
	held_card = null
	
	var target = abandon_reparent_target if abandon_reparent_target else get_parent()
	if target and card.get_parent() == self:
		card.reparent(target)
	
	card.rotation = 0.0
	card.scale = Vector2.ONE
	
	card_abandoned.emit(card)


#region Signal Management
func _connect_card_signals(card: Card) -> void:
	if not card.card_clicked.is_connected(_on_card_clicked):
		card.card_clicked.connect(_on_card_clicked)

func _disconnect_card_signals(card: Card) -> void:
	if card.card_clicked.is_connected(_on_card_clicked):
		card.card_clicked.disconnect(_on_card_clicked)

##Used when the card in the slot is clicked. [color=red]Overwrite[/color] to implement card action.
func _on_card_clicked(card: Card) -> void:
	print("Card clicked in slot: ", card.name)

#endregion


##Handles placing a card in this slot. If slot is occupied, swaps with the occupant (if allow_swap is true).
func _handle_card_drop(incoming_card: Card) -> void:
	if slot_locked:
		_return_card_to_parent(incoming_card)
		return
	
	if !check_conditions(incoming_card):
		_return_card_to_parent(incoming_card)
		return
	
	var incoming_card_parent = incoming_card.get_parent()
	if incoming_card_parent == self and held_card == incoming_card:
		_position_card_in_center(incoming_card)
		return
	
	var current_card = held_card
	
	if incoming_card_parent is CardSlot and incoming_card_parent.slot_locked:
		_return_card_to_parent(incoming_card)
		return
	
	if not current_card:
		_place_card(incoming_card)
		return
	
	if not allow_swap:
		_return_card_to_parent(incoming_card)
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
		parent.refresh_arrangement()
	elif parent is CardSlot:
		parent._position_card_in_center(card)


##Positions a card at the center of this slot
func _position_card_in_center(card: Card) -> void:
	card.kill_all_tweens()
	
	var slot_rect = get_global_rect()
	var slot_center = slot_rect.get_center()
	var target_global_position = slot_center - card.pivot_offset
	

	var target_local_position = target_global_position - global_position
	card.tween_position(target_local_position, placement_duration, false)
	card.tween_rotation(0, placement_duration)
	card.tween_scale(Vector2.ONE, placement_duration)



##Places a card in an empty slot
func _place_card(card: Card) -> void:
	if slot_locked:
		_return_card_to_parent(card)
		return
	
	if card.get_parent() == self:
		_position_card_in_center(card)
		return
	
	var current_parent = card.get_parent()
	
	if current_parent is CardSlot and current_parent.slot_locked:
		_return_card_to_parent(card)
		return
	
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

##Triggered when a card tried to be placed in the slot. [color=red]Overwrite[/color] to implement custom rules.
func check_conditions(card: Card) -> bool:
	return true
