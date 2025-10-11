##Resource for holding and managing decks of cards
@icon("uid://u56pws80lkxh")
class_name CardDeck extends Resource

##Emitted when a card is drawn from the deck
signal card_drawn(card: CardResource)
##Emitted when the deck becomes empty
signal deck_empty
##Emitted when the deck is shuffled
signal deck_shuffled
##Emitted when a card is added to the deck
signal card_added(card: CardResource)
##Emitted when a card is removed from the deck
signal card_removed(card: CardResource)
##Emitted when the discard pile is shuffled back into the deck
signal discard_shuffled_in

##Name of the deck
@export var deck_name: StringName = ""
##The original card list (template for resetting)
@export var cards: Array[CardResource] = []

##Current draw pile
var draw_pile: Array[CardResource] = []
##Discard pile
var discard_pile: Array[CardResource] = []

##If [code]true[/code], automatically shuffle discard pile back into deck when empty
@export var auto_reshuffle: bool = false


##Initialize the deck, copying cards to draw pile
func initialize() -> void:
	draw_pile.clear()
	discard_pile.clear()
	draw_pile = cards.duplicate()


##Shuffle the current draw pile
func shuffle() -> void:
	draw_pile.shuffle()
	deck_shuffled.emit()


##Draw a single card from the top of the deck. Returns null if deck is empty.
func draw_card() -> CardResource:
	if draw_pile.is_empty():
		if auto_reshuffle and not discard_pile.is_empty():
			shuffle_discard_into_deck()
		else:
			deck_empty.emit()
			return null
	
	var card = draw_pile.pop_front()
	card_drawn.emit(card)
	return card


##Draw multiple cards from the deck. Returns an array of CardResources.
func draw_cards(count: int) -> Array[CardResource]:
	var drawn_cards: Array[CardResource] = []
	
	for i in count:
		var card = draw_card()
		if card == null:
			break
		drawn_cards.append(card)
	
	return drawn_cards


##Peek at the top card without removing it. Returns null if deck is empty.
func peek_top() -> CardResource:
	if draw_pile.is_empty():
		return null
	return draw_pile.front()


##Peek at multiple cards from the top without removing them.
func peek_top_cards(count: int) -> Array[CardResource]:
	var peeked: Array[CardResource] = []
	var peek_count = min(count, draw_pile.size())
	
	for i in peek_count:
		peeked.append(draw_pile[i])
	
	return peeked


##Peek at the bottom card without removing it. Returns null if deck is empty.
func peek_bottom() -> CardResource:
	if draw_pile.is_empty():
		return null
	return draw_pile.back()


##Add a card to the top of the deck
func add_to_top(card: CardResource) -> void:
	draw_pile.push_front(card)
	card_added.emit(card)


##Add a card to the bottom of the deck
func add_to_bottom(card: CardResource) -> void:
	draw_pile.push_back(card)
	card_added.emit(card)


##Add a card at a random position in the deck
func add_random(card: CardResource) -> void:
	if draw_pile.is_empty():
		draw_pile.append(card)
	else:
		var pos = randi() % (draw_pile.size() + 1)
		draw_pile.insert(pos, card)
	card_added.emit(card)


##Add multiple cards to the deck at specified position (top/bottom/random)
func add_cards(card_array: Array[CardResource], position: AddPosition = AddPosition.BOTTOM) -> void:
	for card in card_array:
		match position:
			AddPosition.TOP:
				add_to_top(card)
			AddPosition.BOTTOM:
				add_to_bottom(card)
			AddPosition.RANDOM:
				add_random(card)


##Remove a specific card from the deck. Returns true if found and removed.
func remove_card(card: CardResource) -> bool:
	var index = draw_pile.find(card)
	if index != -1:
		draw_pile.remove_at(index)
		card_removed.emit(card)
		return true
	return false


##Remove all instances of a specific card from the deck. Returns the count removed.
func remove_all_instances(card: CardResource) -> int:
	var removed_count = 0
	while draw_pile.has(card):
		if remove_card(card):
			removed_count += 1
	return removed_count


##Add a card to the discard pile
func discard(card: CardResource) -> void:
	discard_pile.append(card)


##Add multiple cards to the discard pile
func discard_cards(card_array: Array[CardResource]) -> void:
	for card in card_array:
		discard_pile.append(card)


##Shuffle the discard pile back into the draw pile
func shuffle_discard_into_deck() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle()
	discard_shuffled_in.emit()


##Clear the discard pile without shuffling back
func clear_discard() -> void:
	discard_pile.clear()


##Reset the deck to its original state (from the cards array)
func reset() -> void:
	draw_pile.clear()
	discard_pile.clear()

	for card in cards:
		draw_pile.append(card)
	shuffle()


##Get the number of cards remaining in the draw pile
func get_draw_pile_size() -> int:
	return draw_pile.size()


##Get the number of cards in the discard pile
func get_discard_pile_size() -> int:
	return discard_pile.size()


##Check if the draw pile is empty
func is_empty() -> bool:
	return draw_pile.is_empty()


##Get total number of cards (draw + discard)
func get_total_cards() -> int:
	return draw_pile.size() + discard_pile.size()


##Add multiple copies of a card to the original deck template
func add_card_copies(card: CardResource, count: int) -> void:
	for i in count:
		cards.append(card)


##Merge another deck into this one (adds to original template)
func merge_deck(other_deck: CardDeck) -> void:
	cards.append_array(other_deck.cards)


##Get a copy of the current draw pile (for inspection without modifying)
func get_draw_pile_copy() -> Array[CardResource]:
	return draw_pile.duplicate()


##Get a copy of the discard pile (for inspection without modifying)
func get_discard_pile_copy() -> Array[CardResource]:
	return discard_pile.duplicate()


##Count how many of a specific card are in the draw pile
func count_card_in_draw(card: CardResource) -> int:
	return draw_pile.count(card)


enum AddPosition {
	TOP,
	BOTTOM,
	RANDOM
}
