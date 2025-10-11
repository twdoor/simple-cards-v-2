@icon("uid://u56pws80lkxh")
class_name CardDeckManager extends Node

##If [code]true[/code], cards in the deck will be visible.
@export var show_cards: bool = false:
	set(value):
		show_cards = value
		_update_card_visibility()

##The deck resource to initialize cards from on ready.
@export var starting_deck: CardDeck

##If [code]true[/code], the deck will be shuffled on ready.
@export var shuffle_on_ready: bool = true

var draw_pile: Node
var discard_pile: Node


func setup():
	_setup_piles()
	
	if starting_deck:
		initialize_from_deck(starting_deck)
		if shuffle_on_ready:
			shuffle()


func _setup_piles() -> void:
	# Create draw pile container
	draw_pile = Node.new()
	draw_pile.name = "DrawPile"
	add_child(draw_pile)
	
	# Create discard pile container
	discard_pile = Node.new()
	discard_pile.name = "DiscardPile"
	add_child(discard_pile)


##Initializes the deck from a CardDeck resource, creating Card instances.
func initialize_from_deck(deck: CardDeck) -> void:
	clear_deck()
	
	for card_resource in deck.cards:
		var card = Card.new(card_resource)
		add_card_to_draw_pile(card)
	
	_update_card_visibility()


##Adds a card to the draw pile.
func add_card_to_draw_pile(card: Card) -> void:
	if card.get_parent():
		card.get_parent().remove_child(card)
	
	draw_pile.add_child(card)
	card.position = Vector2.ZERO
	card.visible = show_cards


##Adds a card to the discard pile.
func add_card_to_discard_pile(card: Card) -> void:
	if card.get_parent():
		card.get_parent().remove_child(card)
	
	discard_pile.add_child(card)
	card.position = Vector2.ZERO
	card.visible = show_cards


##Draws a card from the top of the draw pile. Returns null if draw pile is empty.
func draw_card() -> Card:
	if draw_pile.get_child_count() == 0:
		return null
	
	var card = draw_pile.get_child(draw_pile.get_child_count() - 1)
	draw_pile.remove_child(card)
	card.visible = true
	return card


##Draws multiple cards from the draw pile. Returns an array of cards.
func draw_cards(count: int) -> Array[Card]:
	var drawn_cards: Array[Card] = []
	
	for i in count:
		var card = draw_card()
		if card:
			drawn_cards.append(card)
		else:
			break
	
	return drawn_cards


##Shuffles the draw pile randomly.
func shuffle() -> void:
	var cards_array: Array[Card] = []
	
	# Remove all cards from draw pile
	for child in draw_pile.get_children():
		if child is Card:
			cards_array.append(child)
			draw_pile.remove_child(child)
	
	# Shuffle array
	cards_array.shuffle()
	
	# Re-add cards in shuffled order
	for card in cards_array:
		draw_pile.add_child(card)
		card.position = Vector2.ZERO


##Moves all cards from discard pile back to draw pile.
func reshuffle_discard_into_draw() -> void:
	var cards_to_move: Array[Card] = []
	
	for child in discard_pile.get_children():
		if child is Card:
			cards_to_move.append(child)
	
	for card in cards_to_move:
		add_card_to_draw_pile(card)


##Moves all cards from discard pile to draw pile and shuffles.
func reshuffle_discard_and_shuffle() -> void:
	reshuffle_discard_into_draw()
	shuffle()


##Returns the top card of the draw pile without removing it. Returns null if empty.
func peek_top_card() -> Card:
	if draw_pile.get_child_count() == 0:
		return null
	
	return draw_pile.get_child(draw_pile.get_child_count() - 1) as Card


##Returns an array of the top N cards from the draw pile without removing them.
func peek_top_cards(count: int) -> Array[Card]:
	var peeked_cards: Array[Card] = []
	var child_count = draw_pile.get_child_count()
	var start_index = max(0, child_count - count)
	
	for i in range(start_index, child_count):
		var card = draw_pile.get_child(i)
		if card is Card:
			peeked_cards.append(card)
	
	return peeked_cards


##Removes a specific card from the draw pile.
func remove_card_from_draw_pile(card: Card) -> bool:
	if card.get_parent() == draw_pile:
		draw_pile.remove_child(card)
		return true
	return false


##Removes a specific card from the discard pile.
func remove_card_from_discard_pile(card: Card) -> bool:
	if card.get_parent() == discard_pile:
		discard_pile.remove_child(card)
		return true
	return false


##Returns the number of cards in the draw pile.
func get_draw_pile_size() -> int:
	return draw_pile.get_child_count()


##Returns the number of cards in the discard pile.
func get_discard_pile_size() -> int:
	return discard_pile.get_child_count()


##Returns the total number of cards in both piles.
func get_total_card_count() -> int:
	return get_draw_pile_size() + get_discard_pile_size()


##Clears both draw and discard piles, freeing all cards.
func clear_deck() -> void:
	for child in draw_pile.get_children():
		child.queue_free()
	
	for child in discard_pile.get_children():
		child.queue_free()


##Returns true if the draw pile is empty.
func is_draw_pile_empty() -> bool:
	return draw_pile.get_child_count() == 0


##Returns true if the discard pile is empty.
func is_discard_pile_empty() -> bool:
	return discard_pile.get_child_count() == 0


func _update_card_visibility() -> void:
	if not draw_pile or not discard_pile:
		return
	
	for child in draw_pile.get_children():
		if child is Card:
			child.visible = show_cards
	
	for child in discard_pile.get_children():
		if child is Card:
			child.visible = show_cards
