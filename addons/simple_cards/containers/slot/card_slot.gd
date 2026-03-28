## A single-card container that detects when a held card is dropped on it.
##
## Supports locking, swap-on-drop, abandon-on-empty-space, and custom placement rules.
## Override [method check_conditions] to add game-specific validation.
@tool
@icon("uid://campsjrxwba25")
class_name CardSlot extends CardContainer


#region Signals

## Emitted when a held card starts hovering over this slot.
signal card_entered(card: Card)
## Emitted when a held card stops hovering over this slot.
signal card_exited(card: Card)
## Emitted when a card is dropped on this slot.
signal card_dropped_on(card: Card)
## Emitted when the slot's locked state changes.
signal slot_lock_changed(is_locked: bool)
## Emitted when mouse enters slot area.
signal slot_hovered()
## Emitted when mouse exits slot area.
signal slot_unhovered()
## Emitted when cards are swapped.
signal slot_swapped(old_card: Card, new_card: Card)
## Emitted when a card is rejected.
signal card_rejected(card: Card, reason: String)
## Emitted when a card is abandoned (dropped on empty space with abandon enabled).
signal card_abandoned(card: Card)

#endregion


#region Exports

## When true, prevents cards from being dragged out of or placed into this slot.
@export var slot_locked: bool = false:
	set(value):
		slot_locked = value
		slot_lock_changed.emit(slot_locked)

## When false, dropping a card on an occupied slot is rejected instead of swapping.
@export var allow_swap: bool = true

## When true, cards dropped on empty space will be removed from the slot.
@export var abandon_on_empty_space: bool = false

## The node to reparent abandoned cards to. If null, uses this slot's parent.
@export var abandon_reparent_target: Node = null

#endregion


var _card_over: bool = false
var _card_currently_over: Card = null
var _card_originated_from_this_slot: bool = false


#region Setup

func _validate_property(property: Dictionary) -> void:
	if property.name in ["max_cards", "shape"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _container_ready() -> void:
	max_cards = 1
	card_move_duration = 0.15
	
	CG.holding_card.connect(_on_card_held)
	CG.dropped_card.connect(_on_card_dropped)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	for child in get_children():
		if child is Card and !cards.has(child):
			cards.append(child)
			_connect_card_signals(child)
	
	if !cards.is_empty():
		arrange(0)
	
	set_process(false)


func _exit_tree() -> void:
	if Engine.is_editor_hint(): return
	if CG.holding_card.is_connected(_on_card_held):
		CG.holding_card.disconnect(_on_card_held)
	if CG.dropped_card.is_connected(_on_card_dropped):
		CG.dropped_card.disconnect(_on_card_dropped)

#endregion


#region Public API

## Locks the slot, preventing cards from being placed or removed.
func lock() -> void:
	slot_locked = true

## Unlocks the slot.
func unlock() -> void:
	slot_locked = false

## Returns whether the slot is currently locked.
func is_locked() -> bool:
	return slot_locked

## Returns the card in this slot, or [code]null[/code] if empty.
func get_card() -> Card:
	return get_card_at(-1)


## Swaps cards between this slot and another slot. Returns [code]true[/code] if successful.
## Fails if either slot is locked or empty.
func swap_with(other_slot: CardSlot) -> bool:
	if slot_locked or other_slot.slot_locked: return false
	if is_empty() or other_slot.is_empty(): return false
	
	var this_card = cards[0]
	var other_card = other_slot.cards[0]
	var this_global = this_card.global_position
	var other_global = other_card.global_position
	
	_suppress_auto_remove = true
	other_slot._suppress_auto_remove = true
	
	_raw_unregister(this_card)
	other_slot._raw_unregister(other_card)
	
	this_card._reparent_to(other_slot)
	other_card._reparent_to(self)
	
	_raw_register(other_card)
	_compute_layout()
	other_slot._raw_register(this_card)
	other_slot._compute_layout()
	
	_suppress_auto_remove = false
	other_slot._suppress_auto_remove = false
	
	other_card.kill_all_tweens()
	other_card.global_position = other_global
	_settle_card(other_card, card_move_duration)
	
	this_card.kill_all_tweens()
	this_card.global_position = this_global
	other_slot._settle_card(this_card, other_slot.card_move_duration)
	
	slot_swapped.emit(this_card, other_card)
	other_slot.slot_swapped.emit(other_card, this_card)
	return true

#endregion


#region Acceptance Override

func can_accept_card(card: Card) -> bool:
	if cards.has(card): return false
	
	if slot_locked:
		card_rejected.emit(card, "slot_locked")
		return false
	
	if !check_conditions(card):
		card_rejected.emit(card, "failed_conditions")
		return false
	
	if is_full() and allow_swap:
		return true
	
	if is_full():
		card_rejected.emit(card, "slot_full")
		return false
	
	return true


## Override to add custom placement rules. Called by [method can_accept_card].
func check_conditions(card: Card) -> bool:
	return true

#endregion


#region Layout Override

## Centers the card in the slot.
func get_card_target_position(card: Card) -> Vector2:
	var slot_center = get_global_rect().get_center()
	var target_global = slot_center - card.pivot_offset
	return target_global - global_position


func get_card_target_rotation(_card: Card) -> float:
	return 0.0


## Also resets scale when settling (cards may be scaled from drag/focus).
func _settle_card(card: Card, duration: float) -> void:
	super._settle_card(card, duration)
	card.tween_scale(Vector2.ONE, duration)

#endregion


#region Drop Detection

func _process(_delta: float) -> void:
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


func _on_card_held(card: Card) -> void:
	if slot_locked and cards.has(card):
		_force_return_card.call_deferred(card)
		return
	
	_card_originated_from_this_slot = cards.has(card)
	_card_over = false
	set_process(true)


func _on_card_dropped() -> void:
	if _card_over and _card_currently_over:
		_handle_drop(_card_currently_over)
	elif _card_originated_from_this_slot and !cards.is_empty():
		var card = cards[0]
		if card.get_parent() == self:
			if abandon_on_empty_space:
				_abandon_card(card)
			else:
				_settle_card(card, card_move_duration)
	
	_card_over = false
	_card_currently_over = null
	_card_originated_from_this_slot = false
	set_process(false)

#endregion


#region Drop Handling

func _handle_drop(incoming: Card) -> void:
	if !can_accept_card(incoming):
		_return_to_source(incoming)
		return
	
	var source = incoming.get_parent()
	
	if source == self and cards.has(incoming):
		_settle_card(incoming, card_move_duration)
		card_dropped_on.emit(incoming)
		return
	
	if cards.is_empty():
		incoming.move_to(self)
		card_dropped_on.emit(incoming)
		return
	
	if allow_swap:
		_swap_cards(incoming, source)
		card_dropped_on.emit(incoming)
		return
	
	_return_to_source(incoming)


## Swaps the incoming card with the current occupant.
## The old card goes to the incoming card's source container.
func _swap_cards(incoming: Card, source: Node) -> void:
	var old_card = cards[0]
	var old_global = old_card.global_position
	var incoming_global = incoming.global_position
	
	_suppress_auto_remove = true
	if source is CardContainer:
		source._suppress_auto_remove = true
	
	_raw_unregister(old_card)
	if source is CardContainer:
		source._raw_unregister(incoming)
	
	incoming._reparent_to(self)
	old_card._reparent_to(source)
	
	_raw_register(incoming)
	_compute_layout()
	
	if source is CardContainer:
		source._raw_register(old_card)
		source._compute_layout()
		source._suppress_auto_remove = false
		for c in source.cards:
			if c.holding: continue
			source._settle_card(c, source.card_move_duration)
	
	_suppress_auto_remove = false
	
	old_card.kill_all_tweens()
	old_card.global_position = old_global
	incoming.kill_all_tweens()
	incoming.global_position = incoming_global
	
	_settle_card(incoming, card_move_duration)
	if source is CardContainer:
		source._settle_card(old_card, source.card_move_duration)
	
	card_added.emit(incoming, 0)
	card_removed.emit(old_card, 0)
	slot_swapped.emit(old_card, incoming)


## Returns a card to its source container for re-settling.
func _return_to_source(card: Card) -> void:
	var parent = card.get_parent()
	if parent is CardContainer:
		parent.arrange()


## Forces a card back to this slot (used when dragging from a locked slot).
func _force_return_card(card: Card) -> void:
	if cards.has(card):
		card.holding = false
		_settle_card(card, card_move_duration)
		if CG.current_held_item == card:
			CG.current_held_item = null


## Removes the card from the slot and reparents it to [member abandon_reparent_target].
func _abandon_card(card: Card) -> void:
	if !card: return
	var target = abandon_reparent_target if abandon_reparent_target else get_parent()
	if target and card.get_parent() == self:
		card.kill_all_tweens()
		card.reparent(target, true)  # triggers _unregister via child_exiting_tree
	card.rotation = 0.0
	card.scale = Vector2.ONE
	card_abandoned.emit(card)

#endregion


#region Signal Management

func _connect_card_signals(card: Card) -> void:
	if not card.card_clicked.is_connected(_on_card_clicked):
		card.card_clicked.connect(_on_card_clicked)


func _disconnect_card_signals(card: Card) -> void:
	if card.card_clicked.is_connected(_on_card_clicked):
		card.card_clicked.disconnect(_on_card_clicked)


## Called when the card in the slot is clicked. Override to implement custom action.
func _on_card_clicked(card: Card) -> void:
	pass


func _on_mouse_entered() -> void:
	slot_hovered.emit()


func _on_mouse_exited() -> void:
	slot_unhovered.emit()

#endregion
