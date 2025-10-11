@tool
extends CardHand

var selected: Array[Card]

func _handle_clicked_card(card: Card) -> void:
	toggle_select(card)

func toggle_select(card: Card):
	if selected.has(card):
		selected.erase(card)
		deselect(card)
	else:
		selected.append(card)
		select(card)
	

func select(card: Card):
	card.position_offset = Vector2(0, -40)
	_arrange_cards()

func deselect(card: Card):
	card.position_offset = Vector2.ZERO
	_arrange_cards()
	
func sort_by_suit():
	cards.sort_custom(func(a: Card, b: Card):
		return a.card_data.card_suit > b.card_data.card_suit)
	_arrange_cards()


func clear_selected():
	for card in selected:
		deselect(card)
	selected.clear()
	
