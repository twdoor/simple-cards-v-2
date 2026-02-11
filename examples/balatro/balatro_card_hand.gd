## CardHand with multi-card selection. Click cards to select/deselect them.
## Selected cards get visually bumped upward. Used in the Balatro example.
##
## Important: always duplicate the selected array before moving cards to another
## container, because remove_card cleans up the array as cards leave the hand.
class_name BalatroHand extends CardHand

@export var max_selected: int = 5
var selected: Array[Card] = []


func _handle_clicked_card(card: Card) -> void:
	toggle_select(card)


func toggle_select(card: Card) -> void:
	if selected.has(card):
		selected.erase(card)
		deselect(card)
	elif selected.size() < max_selected:
		selected.append(card)
		select(card)


func select(card: Card) -> void:
	card.position_offset = Vector2(0, -40)
	arrange_cards()


func deselect(card: Card) -> void:
	card.position_offset = Vector2.ZERO
	arrange_cards()


## Clean up selection when a card is removed from the hand (played, discarded, etc.)
func remove_card(card: Card, new_parent: Node = null) -> void:
	if selected.has(card):
		selected.erase(card)
		card.position_offset = Vector2.ZERO
	super.remove_card(card, new_parent)


## Sort by suit first, then by value within the same suit.
func sort_by_suit() -> void:
	sort_cards(func(a: Card, b: Card) -> bool:
		if a.card_data.card_suit != b.card_data.card_suit:
			return a.card_data.card_suit < b.card_data.card_suit
		return a.card_data.value < b.card_data.value)


## Sort by value (high to low), then by suit as tiebreaker.
func sort_by_value() -> void:
	sort_cards(func(a: Card, b: Card) -> bool:
		if a.card_data.value != b.card_data.value:
			return a.card_data.value > b.card_data.value
		return a.card_data.card_suit < b.card_data.card_suit)


## Sorts selected array by hand position (left to right) so played cards
## keep their visual order.
func sort_selected() -> void:
	selected.sort_custom(func(a: Card, b: Card) -> bool:
		return get_card_index(a) < get_card_index(b))


func clear_selected() -> void:
	for card in selected:
		card.position_offset = Vector2.ZERO
	selected.clear()
	arrange_cards()
