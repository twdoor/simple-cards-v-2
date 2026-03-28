## A container for cards that can function as an invisible holder or a visual pile.
##
## CardPile is the building block for deck systems. It manages [Card] nodes and
## provides shuffle, peek, and visibility controls.
## Cards in a pile are disabled and optionally hidden.
@icon("uid://1g0jb8x0i516")
class_name CardPile extends CardContainer


#region Signals

## Emitted when the pile is shuffled.
signal pile_shuffled()

#endregion


#region Exports

## If [code]true[/code], card nodes are visible in the pile.
@export var show_cards: bool = false:
	set(value):
		show_cards = value
		_update_visibility()

## Whether cards in this pile should show their front face.
@export var face_up: bool = false

#endregion


#region State Overrides

func _apply_card_state(card: Card) -> void:
	card.is_front_face = face_up
	card.visible = show_cards
	card.disabled = true
	card.rotation = 0


func _restore_card_state(card: Card) -> void:
	card.visible = true
	card.disabled = false

#endregion


#region Pile Operations

## Shuffles the card order randomly.
func shuffle() -> void:
	cards.shuffle()
	for card in cards:
		move_child(card, -1)
	pile_shuffled.emit()
	arrange()


## Returns the top card without removing it. Returns [code]null[/code] if empty.
func peek_top() -> Card:
	if cards.is_empty(): return null
	return cards.back()


## Returns [param count] cards without removing them, starting from [param index].
## [br]Positive [param index] (default [code]1[/code]): counts from the top. 
## Collects downward (toward bottom).
## [br]Negative [param index]: counts from the bottom. Collects upward (toward top).
## [br][br]Examples (pile bottom→top: A B C D E F G):
## [br]- [code]peek_cards(3)[/code] → G, F, E (top 3)
## [br]- [code]peek_cards(4, 5)[/code] → C, B, A (5th from top, 4 requested, 3 available)
## [br]- [code]peek_cards(3, -1)[/code] → A, B, C (bottom 3)
## [br]- [code]peek_cards(2, -3)[/code] → C, D (3rd from bottom, 2 upward)
func peek_cards(count: int, index: int = 1) -> Array[Card]:
	var result: Array[Card] = []
	if cards.is_empty() or count <= 0 or index == 0: return result
	
	if index > 0:
		var start = cards.size() - index
		if start < 0: return result
		var n = mini(count, start + 1)
		for i in n:
			result.append(cards[start - i])
	else:
		var start = (-index) - 1
		if start >= cards.size(): return result
		var n = mini(count, cards.size() - start)
		for i in n:
			result.append(cards[start + i])
	
	return result

#endregion

#region Internal

func _update_visibility() -> void:
	for card in cards:
		card.visible = show_cards

#endregion
