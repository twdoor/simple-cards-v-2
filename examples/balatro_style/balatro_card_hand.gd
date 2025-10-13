@tool
extends CardHand

@export var max_selected: int
var _selected: Array[Card]
var selected: Array[Card]:
	get:
		return _selected.duplicate()

func _handle_clicked_card(card: Card) -> void:
	toggle_select(card)

func toggle_select(card: Card):
	if _selected.has(card):
		_selected.erase(card)
		deselect(card)
	elif _selected.size() < max_selected:
		_selected.append(card)
		select(card)
	

func select(card: Card):
	card.position_offset = Vector2(0, -40)
	_arrange_cards()

func deselect(card: Card):
	card.position_offset = Vector2.ZERO
	_arrange_cards()
	
func sort_by_suit():
	_cards.sort_custom(func(a: Card, b: Card):
		return a.card_data.card_suit < b.card_data.card_suit)
	_arrange_cards()

func sort_selected():
	_selected.sort_custom(func(a: Card, b: Card):
		return get_card_index(a) < get_card_index(b))

func sort_by_value():
	_cards.sort_custom(func(a: Card, b: Card):
		return a.card_data.value > b.card_data.value)
	_arrange_cards()



func clear_selected():
	for card in _selected:
		deselect(card)
	_selected.clear()
	
