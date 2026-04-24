## Base class for card containers.
##
## Manages an internal [code]cards[/code] array, layout computation via [ContainerShape],
## and provides the registration interface used by [method Card.move_to].
## [br][br]
## Subclass [CardHand], [CardPile], or [CardSlot] for specific behavior.
## For custom containers, extend this class and override the virtual callbacks.
@abstract @icon("uid://bhxu665rvmfng")
class_name CardContainer extends Panel


#region Signals

## Emitted when a card is added to this container.
signal card_added(card: Card, index: int)
## Emitted when a card is removed from this container.
signal card_removed(card: Card, index: int)
## Emitted when the last card is removed.
signal container_empty()
## Emitted when [member max_cards] is reached.
signal container_full()

#endregion


#region Exports

## Layout shape. If [code]null[/code], cards stack at the origin.
@export var shape: ContainerShape:
	set(value):
		shape = value
		if !cards.is_empty():
			arrange()

## Maximum number of cards allowed. [code]-1[/code] = unlimited.
@export var max_cards: int = -1

## Default tween duration for cards settling into position.
@export var card_move_duration: float = 0.3

#endregion


## Internal card array. Use queries or [method Card.move_to] — do not modify directly.
var cards: Array[Card] = []
var _card_positions: Array[Vector2] = []
var _card_rotations: Array[float] = []
## Guard flag — when [code]true[/code], [method _on_child_exiting] skips auto-cleanup.
var _suppress_auto_remove: bool = false
## When [code]true[/code], [method _register_card] skips layout computation.
## Used by bulk operations to defer layout to one call at the end.
var _batch_mode: bool = false


func _ready() -> void:
	if Engine.is_editor_hint(): return
	child_exiting_tree.connect(_on_child_exiting)
	_container_ready()


#region Queries

## Returns the number of cards in this container.
func get_card_count() -> int:
	return cards.size()


## Returns [code]true[/code] if the container has no cards.
func is_empty() -> bool:
	return cards.is_empty()


## Returns [code]true[/code] if the container has reached [member max_cards].
func is_full() -> bool:
	if max_cards < 0: return false
	return cards.size() >= max_cards


## Returns [code]true[/code] if the container holds the given card.
func has_card(card: Card) -> bool:
	return cards.has(card)


## Returns the card at [param index], or [code]null[/code] if out of bounds.
## Negative indices count from the end ([code]-1[/code] = last / top).
func get_card_at(index: int) -> Card:
	if index < 0: index = cards.size() + index
	if index < 0 or index >= cards.size(): return null
	return cards[index]


## Returns a copy of the internal card array. Safe to read and modify.
func get_cards() -> Array[Card]:
	return cards.duplicate()


## Returns the index of a card, or [code]-1[/code] if not found.
func get_card_index(card: Card) -> int:
	return cards.find(card)


## Returns remaining slots before [member max_cards]. [code]-1[/code] if unlimited.
func get_remaining_space() -> int:
	if max_cards < 0: return -1
	return max(0, max_cards - cards.size())

#endregion


#region Registration — called by Card.move_to

## Returns [code]true[/code] if this container would accept the card.
func can_accept_card(card: Card) -> bool:
	if cards.has(card): return false
	if is_full(): return false
	return _check_conditions(card)


## Registers a card in internal state. Does NOT reparent or animate the card.
## [br]Computes layout and settles existing cards (unless in batch mode).
func _register_card(card: Card, index: int = -1) -> void:
	if index < 0 or index > cards.size():
		cards.append(card)
		index = cards.size() - 1
	else:
		cards.insert(index, card)
	
	_connect_card_signals(card)
	_apply_card_state(card)
	
	if not _batch_mode:
		_compute_layout()
		
		for c in cards:
			if c == card: continue
			if c.holding: continue
			_settle_card(c, card_move_duration)
	
	_on_card_added(card, index)
	card_added.emit(card, index)
	if is_full():
		container_full.emit()
		_on_container_full()


## Unregisters a card from internal state. Triggered by [signal child_exiting_tree].
func _unregister_card(card: Card) -> void:
	var index = cards.find(card)
	if index == -1: return
	
	cards.remove_at(index)
	_disconnect_card_signals(card)
	_restore_card_state(card)
	_compute_layout()
	
	for c in cards:
		if c.holding: continue
		_settle_card(c, card_move_duration)
	
	_on_card_removed(card, index)
	card_removed.emit(card, index)
	if cards.is_empty(): 
		container_empty.emit()
		_on_container_empty()

## Registers a card without triggering layout or signals.
## Used for atomic multi-card operations like swaps.
func _raw_register(card: Card) -> void:
	cards.append(card)
	_connect_card_signals(card)
	_apply_card_state(card)


## Unregisters a card without triggering layout or signals.
## Used for atomic multi-card operations like swaps.
func _raw_unregister(card: Card) -> void:
	cards.erase(card)
	_disconnect_card_signals(card)
	_restore_card_state(card)

#endregion


#region Layout

## Computes [member _card_positions] and [member _card_rotations] from the [member shape].
## If no shape is assigned, all cards stack at the pivot origin.
func _compute_layout() -> void:
	if cards.is_empty():
		_card_positions.clear()
		_card_rotations.clear()
		update_minimum_size()
		return
	
	if shape:
		var result: ContainerShape.LayoutResult = shape.compute_layout(cards)
		_card_positions = result.positions
		_card_rotations = result.rotations
	else:
		_card_positions.clear()
		_card_rotations.clear()
		for card in cards:
			_card_positions.append(card.pivot_offset)
			_card_rotations.append(0.0)
	
	update_minimum_size()


## Returns the local position a card should occupy after layout.
func get_card_target_position(card: Card) -> Vector2:
	var i = cards.find(card)
	if i == -1 or i >= _card_positions.size(): return Vector2.ZERO
	var rot = _card_rotations[i] if i < _card_rotations.size() else 0.0
	return _card_positions[i] - card.pivot_offset + card.position_offset.rotated(rot)


## Returns the rotation (in degrees) a card should have after layout.
func get_card_target_rotation(card: Card) -> float:
	var i = cards.find(card)
	if i == -1 or i >= _card_rotations.size(): return 0.0
	return rad_to_deg(_card_rotations[i]) + card.rotation_offset


## Recomputes layout and tweens all cards to their positions.
func arrange(duration: float = -1) -> void:
	if duration < 0: duration = card_move_duration
	_compute_layout()
	for card in cards:
		if card.holding: continue
		_settle_card(card, duration)


## Tweens a single card to its layout position. Rotation is set directly.
## If the card has a stored [code]_move_origin[/code] (from a batch move), 
## restores the card's global position to that origin before tweening.
func _settle_card(card: Card, duration: float) -> void:
	if card._move_origin != Vector2.INF:
		card.global_position = card._move_origin
		card._move_origin = Vector2.INF
	card.tween_position(get_card_target_position(card), duration)
	card.rotation_degrees = get_card_target_rotation(card)

#endregion


#region Bulk Operations

## Moves the top [param count] cards to [param target].
## Returns how many were moved. If [param stagger] > 0, awaits between each card.
## [br][br]
## If [param batch] is [code]true[/code], layout computation is deferred until all
## cards are placed, then a single [method arrange] is called at the end.
## Automatically enabled when [param duration] is [code]0[/code].
func deal_to(target: CardContainer, count: int, duration: float = -1, stagger: float = 0.0, batch: bool = false) -> int:
	var use_batch = batch or duration == 0
	if use_batch:
		target._batch_mode = true

	var dealt: int = 0
	for i in count:
		if cards.is_empty(): break
		var card = cards.back()
		if !target.can_accept_card(card): break
		card.move_to(target, duration)
		dealt += 1
		if stagger > 0.0 and i < count - 1:
			await get_tree().create_timer(stagger).timeout

	if use_batch and dealt > 0:
		target._batch_mode = false
		var settle_dur: float = duration if duration >= 0.0 else target.card_move_duration
		target.arrange(settle_dur)
	elif use_batch:
		target._batch_mode = false

	return dealt


## Moves specific cards to [param target].
## Returns how many were moved. If [param stagger] > 0, awaits between each card.
## [br][br]
## If [param batch] is [code]true[/code], layout computation is deferred until all
## cards are placed, then a single [method arrange] is called at the end.
## Automatically enabled when [param duration] is [code]0[/code].
func move_cards_to(card_array: Array[Card], target: CardContainer, duration: float = -1, stagger: float = 0.0, batch: bool = false) -> int:
	var use_batch = batch or duration == 0
	if use_batch:
		target._batch_mode = true

	var moved: int = 0
	var to_move = card_array.duplicate()
	for i in to_move.size():
		var card = to_move[i]
		if !cards.has(card): continue
		if !target.can_accept_card(card): continue
		card.move_to(target, duration)
		moved += 1
		if stagger > 0.0 and i < to_move.size() - 1:
			await get_tree().create_timer(stagger).timeout

	if use_batch and moved > 0:
		target._batch_mode = false
		var settle_dur: float = duration if duration >= 0.0 else target.card_move_duration
		target.arrange(settle_dur)
	elif use_batch:
		target._batch_mode = false

	return moved


## Moves all cards to [param target].
## Returns how many were moved. If [param stagger] > 0, awaits between each card.
## [br][br]
## If [param batch] is [code]true[/code], layout computation is deferred until all
## cards are placed, then a single [method arrange] is called at the end.
## Automatically enabled when [param duration] is [code]0[/code].
func move_all_to(target: CardContainer, duration: float = -1, stagger: float = 0.0, batch: bool = false) -> int:
	return await move_cards_to(cards.duplicate(), target, duration, stagger, batch)


## Sorts cards using a custom comparison and re-arranges.
func sort_cards(compare_func: Callable) -> void:
	cards.sort_custom(compare_func)
	arrange()

#endregion


#region Clear

## Removes all cards and frees them.
func clear_and_free() -> void:
	_suppress_auto_remove = true
	for card in cards:
		_disconnect_card_signals(card)
		card.queue_free()
	cards.clear()
	_card_positions.clear()
	_card_rotations.clear()
	_suppress_auto_remove = false
	update_minimum_size()
	container_empty.emit()
	_on_container_empty()

#endregion


#region Overridable Callbacks

## Called at the end of [method _ready]. Override for subclass setup.
func _container_ready() -> void: pass

## Called after a card is registered. Override for custom behavior.
func _on_card_added(card: Card, index: int) -> void: pass

## Called after a card is unregistered. Override for custom behavior.
func _on_card_removed(card: Card, index: int) -> void: pass

## Called if container becomes empty. Override for custom behavior.
func _on_container_empty() -> void: pass

## Called if container becomes full. Override for custom behavior.
func _on_container_full() -> void: pass

## Override to apply container-specific state when a card enters (e.g. face down, disabled).
func _apply_card_state(card: Card) -> void: pass

## Override to restore card state when it leaves this container.
func _restore_card_state(card: Card) -> void: pass

## Override to add custom acceptance rules. Called by [method can_accept_card].
func _check_conditions(card: Card) -> bool: return true

## Override to connect custom signals when a card is registered.
func _connect_card_signals(card: Card) -> void: pass

## Override to disconnect custom signals when a card is unregistered.
func _disconnect_card_signals(card: Card) -> void: pass

#endregion


#region Internal

func _on_child_exiting(node: Node) -> void:
	if _suppress_auto_remove: return
	if not node is Card: return
	if not cards.has(node): return
	_unregister_card(node as Card)


func _get_minimum_size() -> Vector2:
	if cards.is_empty() or _card_positions.is_empty():
		return Vector2.ZERO

	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF

	for i in cards.size():
		if i >= _card_positions.size(): break
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
