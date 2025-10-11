@tool
extends CardHand

var selected: Array[Card]


func _handle_clicked_card(card: Card) -> void:
	if selected.has(card):
		selected.erase(card)
	else:
		selected.append(card)
	update_selected()

func update_selected():
	for card in cards:
		if card in selected:
			card.modulate.a = .4
		else:
			card.modulate.a = 1
