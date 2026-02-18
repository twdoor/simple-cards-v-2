## A container for cards that can function as an invisible holder or a visual pile.
##
## CardPile is the building block for deck systems. It holds [Card] nodes as children
## and provides draw, add, shuffle, and arrangement operations.
@icon("uid://1g0jb8x0i516")
class_name CardPile extends Control


#region Signals

## Emitted when a card is added to the pile.
signal card_added(card: Card, index: int)
## Emitted when a card is removed from the pile.
signal card_removed(card: Card)
## Emitted when the pile becomes empty.
signal pile_emptied()
## Emitted when the pile is shuffled.
signal pile_shuffled()
## Emitted when the pile size changes.
signal pile_changed(new_size: int)

#endregion


#region Exports

## Optional shape for visual arrangement.
@export var shape: CardHandShape:
	set(value):
		shape = value
		if is_inside_tree() and not _cards.is_empty():
			arrange()

## If [code]true[/code], card nodes are visible in the pile.
@export var show_cards: bool = false:
	set(value):
		show_cards = value
		_update_visibility()

## Whether cards in this pile should show their front face.
@export var face_up: bool = false

#endregion


## Internal card tracking array. Order matches child order.
var _cards: Array[Card] = []
## Cached positions from the last arrangement, used for minimum size calculation.
var _card_positions: Array[Vector2] = []
## Guard flag to prevent child_exiting_tree from firing during intentional bulk operations.
var _suppress_auto_remove: bool = false


func _ready() -> void:
	child_exiting_tree.connect(_on_card_child_exiting)


#region Core API

## Returns the number of cards in the pile.
func get_card_count() -> int:
	return _cards.size()


## Returns [code]true[/code] if the pile has no cards.
func is_empty() -> bool:
	return _cards.is_empty()


## Returns the internal card array. Do not modify directly — use add/remove methods.
func get_cards() -> Array[Card]:
	return _cards


## Returns the card at the given index, or [code]null[/code] if out of bounds.
func get_card_at(index: int) -> Card:
	if index < 0:
		index = _cards.size() + index
	if index < 0 or index >= _cards.size():
		return null
	return _cards[index]

#endregion


#region Adding Cards

## Adds a card to the top of the pile.
func add_card(card: Card) -> void:
	_take_card(card)
	_cards.append(card)
	_apply_pile_state(card)
	_on_card_added(card, _cards.size() - 1)
	card_added.emit(card, _cards.size() - 1)
	pile_changed.emit(_cards.size())
	arrange()


## Adds a card at a specific index. 0 = bottom, -1 = top.
func add_card_at(card: Card, index: int) -> void:
	_take_card(card)

	var actual_index = index
	if actual_index < 0:
		actual_index = _cards.size() + actual_index + 1
	actual_index = clampi(actual_index, 0, _cards.size())

	_cards.insert(actual_index, card)
	move_child(card, actual_index)
	_apply_pile_state(card)
	_on_card_added(card, actual_index)
	card_added.emit(card, actual_index)
	pile_changed.emit(_cards.size())
	arrange()


## Adds multiple cards to the top of the pile.
func add_cards(card_array: Array[Card]) -> void:
	for card in card_array:
		_take_card(card)
		_cards.append(card)
		_apply_pile_state(card)
		_on_card_added(card, _cards.size() - 1)
		card_added.emit(card, _cards.size() - 1)

	pile_changed.emit(_cards.size())
	arrange()

#endregion


#region Drawing / Removing Cards

## Draws the top card from the pile. Returns [code]null[/code] if empty.
func draw_card() -> Card:
	if _cards.is_empty():
		pile_emptied.emit()
		return null

	var card = _cards.back()
	var stored_pos = card.global_position
	remove_child(card)
	card.global_position = stored_pos
	return card


## Draws multiple cards from the top. Returns cards in draw order (top first).
func draw_cards(count: int) -> Array[Card]:
	var drawn: Array[Card] = []
	for i in count:
		var card = draw_card()
		if card:
			drawn.append(card)
		else:
			break
	return drawn


## Draws a card at a specific index. Returns [code]null[/code] if out of bounds.
func draw_card_at(index: int) -> Card:
	if index < 0:
		index = _cards.size() + index
	if index < 0 or index >= _cards.size():
		return null

	var card = _cards[index]
	var stored_pos = card.global_position
	remove_child(card)
	card.global_position = stored_pos
	return card


## Removes a specific card from the pile. Returns the card if found and removed.
## [color=red]Does NOT free the card.[/color]
func remove_card(card: Card) -> Card:
	if not _cards.has(card):
		return null

	if card.get_parent() == self:
		var stored_pos = card.global_position
		remove_child(card)
		card.global_position = stored_pos
	else:

		_on_card_child_exiting(card)
	
	return card

## Removes all cards from the pile. [color=red]Does NOT free the cards.[/color]
func clear_pile() -> void:
	_suppress_auto_remove = true
	var cards_copy = _cards.duplicate()
	_cards.clear()
	_card_positions.clear()

	for card in cards_copy:
		if card.get_parent() == self:
			var stored_pos = card.global_position
			remove_child(card)
			card.global_position = stored_pos

	_suppress_auto_remove = false
	update_minimum_size()
	pile_changed.emit(0)
	pile_emptied.emit()


## Removes all cards from the pile and frees them.
func clear_and_free() -> void:
	_suppress_auto_remove = true
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_card_positions.clear()
	_suppress_auto_remove = false
	update_minimum_size()
	pile_changed.emit(0)
	pile_emptied.emit()

#endregion


#region Pile Operations

## Shuffles the card order randomly.
func shuffle() -> void:
	_cards.shuffle()

	for card in _cards:
		move_child(card, -1)

	pile_shuffled.emit()
	arrange()


## Returns the top card without removing it. Returns [code]null[/code] if empty.
func peek_top() -> Card:
	if _cards.is_empty():
		return null
	return _cards.back()


## Returns the top N cards without removing them. Top card is first in the returned array.
func peek_top_cards(count: int) -> Array[Card]:
	var result: Array[Card] = []
	var start = max(0, _cards.size() - count)
	for i in range(_cards.size() - 1, start - 1, -1):
		result.append(_cards[i])
	return result


## Returns [code]true[/code] if the pile contains the given card.
func has_card(card: Card) -> bool:
	return _cards.has(card)


## Returns the index of a card in the pile, or -1 if not found.
func get_card_index(card: Card) -> int:
	return _cards.find(card)


## Moves all cards from this pile into another pile.
func move_all_to(target_pile: CardPile) -> void:
	_suppress_auto_remove = true
	var cards_copy = _cards.duplicate()
	_cards.clear()

	for card in cards_copy:
		if card.get_parent() == self:
			var stored_pos = card.global_position
			remove_child(card)
			card.global_position = stored_pos

	_suppress_auto_remove = false
	target_pile.add_cards(cards_copy)

	pile_changed.emit(0)
	pile_emptied.emit()

#endregion


#region Arrangement

## Arranges cards using the assigned shape, or stacks them at zero if no shape is set.
func arrange() -> void:
	if _cards.is_empty():
		_card_positions.clear()
		update_minimum_size()
		return

	if shape:
		_arrange_with_shape()
	else:
		_arrange_stacked()

	update_minimum_size()


func _arrange_with_shape() -> void:
	var layout = shape.compute_layout(_cards)
	_card_positions = layout.positions
	shape.apply_layout(_cards, layout)


func _arrange_stacked() -> void:
	_card_positions.clear()
	for card in _cards:
		card.position = Vector2.ZERO
		_card_positions.append(card.pivot_offset)


## Returns the minimum size needed to contain all cards at their current positions.
func _get_minimum_size() -> Vector2:
	if _cards.is_empty() or _card_positions.is_empty():
		return Vector2.ZERO

	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF

	for i in _cards.size():
		var card_position = _card_positions[i]
		var card_size = _cards[i].size
		var card_top_left = card_position - card_size / 2
		var card_bottom_right = card_position + card_size / 2

		min_x = min(min_x, card_top_left.x)
		min_y = min(min_y, card_top_left.y)
		max_x = max(max_x, card_bottom_right.x)
		max_y = max(max_y, card_bottom_right.y)

	return Vector2(max_x - min_x, max_y - min_y)

#endregion


#region Overridable Callbacks

## Called when a card is added to the pile. Override to implement custom behavior.
func _on_card_added(card: Card, index: int) -> void:
	pass


## Called when a card is removed from the pile. Override to implement custom behavior.
func _on_card_removed(card: Card) -> void:
	pass

#endregion


#region Internal Helpers

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


func _apply_pile_state(card: Card) -> void:
	card.is_front_face = face_up
	card.visible = show_cards
	card.disabled = true
	card.rotation = 0


func _update_visibility() -> void:
	for card in _cards:
		card.visible = show_cards


func _on_card_child_exiting(node: Node) -> void:
	if _suppress_auto_remove:
		return
	if not node is Card:
		return
	var card: Card = node as Card
	if not _cards.has(card):
		return
	
	_cards.erase(card)
	
	card.visible = true
	card.disabled = false
	_on_card_removed(card)
	card_removed.emit(card)
	pile_changed.emit(_cards.size())
	
	if _cards.is_empty():
		pile_emptied.emit()
	
	arrange()

#endregion
