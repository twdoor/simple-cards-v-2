##Manages a [CardDeck].
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

@export var draw_pile: Node
@export var discard_pile: Node

##Sets necessary 
func setup(deck: CardDeck = starting_deck):
	_setup_piles()
	
	if starting_deck:
		initialize_from_deck(deck)
		if shuffle_on_ready:
			shuffle()


func _setup_piles() -> void:
	if !draw_pile:
		draw_pile = Node.new()
		draw_pile.name = "DrawPile"
		add_child(draw_pile)

	if !discard_pile:
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


##Adds a card to the draw pile. [br]If the card is already a child [CardHand] the [member CardHand.remove_card] is used to reparent the card.
func add_card_to_draw_pile(card: Card) -> void:
	# Kill all tweens before reparenting
	card.kill_all_tweens()
	
	if card.get_parent():
		if card.get_parent() is CardHand:
			card.get_parent().remove_card(card, draw_pile)
		else:
			card.reparent(draw_pile)
	else:
		draw_pile.add_child(card)

	_handle_card_reparanting(card, draw_pile.global_position if draw_pile is Control else Vector2.ZERO)

##Adds a card to the discard pile. [br]If the card is already a child [CardHand] the [member CardHand.remove_card] is used to reparent the card.
func add_card_to_discard_pile(card: Card) -> void:
	# Kill all tweens before reparenting
	card.kill_all_tweens()
	
	if card.get_parent():
		if card.get_parent() is CardHand:
			card.get_parent().remove_card(card, discard_pile)
		else:
			card.reparent(discard_pile)
	else:
		discard_pile.add_child(card)
	
	_handle_card_reparanting(card, discard_pile.global_position if discard_pile is Control else Vector2.ZERO)


func _handle_card_reparanting(card: Card, des_position: Vector2 = Vector2.ZERO):
	card.rotation = 0
	card.tween_position(des_position, .2, true)
	card.visible = show_cards
	card.disabled = true


##Draws a card from the top of the draw pile. Returns null if draw pile is empty.
func draw_card() -> Card:
	if draw_pile.get_child_count() == 0:
		return null
	
	var card = draw_pile.get_child(draw_pile.get_child_count() - 1)
	# Store global position before removing
	var stored_global_pos = card.global_position if card is Control else Vector2.ZERO
	
	draw_pile.remove_child(card)
	
	# Restore global position after removing
	if card is Control:
		card.global_position = stored_global_pos
	
	card.visible = true
	card.disabled = false
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
	
	for child in draw_pile.get_children():
		if child is Card:
			cards_array.append(child)
	
	# Remove all cards first
	for card in cards_array:
		draw_pile.remove_child(card)
	
	cards_array.shuffle()
	
	# Re-add in shuffled order
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
		var stored_global_pos = card.global_position if card is Control else Vector2.ZERO
		draw_pile.remove_child(card)
		if card is Control:
			card.global_position = stored_global_pos
		return true
	return false


##Removes a specific card from the discard pile.
func remove_card_from_discard_pile(card: Card) -> bool:
	if card.get_parent() == discard_pile:
		var stored_global_pos = card.global_position if card is Control else Vector2.ZERO
		discard_pile.remove_child(card)
		if card is Control:
			card.global_position = stored_global_pos
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
