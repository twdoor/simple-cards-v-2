class_name BalatroHand extends CardHand

@export var max_selected: int
var selected: Array[Card] = []

func _handle_clicked_card(card: Card) -> void:
	toggle_select(card)

func toggle_select(card: Card):
	if selected.has(card):
		selected.erase(card)
		deselect(card)
	elif selected.size() < max_selected:
		selected.append(card)
		select(card)
	

func select(card: Card):
	card.position_offset = Vector2(0, -40)
	arrange_cards()

func deselect(card: Card):
	card.position_offset = Vector2.ZERO
	arrange_cards()
	
func sort_by_suit():
	sort_cards(func(a: Card, b: Card):
		return a.card_data.card_suit < b.card_data.card_suit)

func sort_selected():
	selected.sort_custom(func(a: Card, b: Card):
		return get_card_index(a) < get_card_index(b))

func sort_by_value():
	sort_cards(func(a: Card, b: Card):
		return a.card_data.value > b.card_data.value)



func clear_selected():
	for card in selected:
		deselect(card)
	selected.clear()
