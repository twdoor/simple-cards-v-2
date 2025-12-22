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

@export var front_face_in_draw: bool = true
@export var front_face_in_discrd: bool = true

var pile_preview_hand: CardHand

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
		add_card_to_pile(card)
	
	_update_card_visibility()


##Adds a card to the draw pile. [br]If the card is already a child [CardHand] the [member CardHand.remove_card] is used to reparent the card.
##If is_discard true uses discard pile instead.
func add_card_to_pile(card: Card, is_discard: bool = false) -> void:
	# Kill all tweens before reparenting
	card.kill_all_tweens()
	card.is_front_face = front_face_in_discrd if is_discard else front_face_in_draw
	
	var pile = discard_pile if is_discard else draw_pile
	
	if card.get_parent():
		if card.get_parent() is CardHand:
			card.get_parent().remove_card(card, pile)
		else:
			card.reparent(pile)
	else:
		pile.add_child(card)

	_handle_card_reparanting(card, pile.global_position if pile is Control else Vector2.ZERO)


func _handle_card_reparanting(card: Card, des_position: Vector2 = Vector2.ZERO):
	card.rotation = 0
	card.tween_position(des_position, .2, true)
	card.visible = show_cards
	card.disabled = true


##Draws a card from the top of the draw pile. Returns null if draw pile is empty.
##If is_discard true uses discard pile instead.
func draw_card(is_discard: bool = false) -> Card:
	var pile = discard_pile if is_discard else draw_pile
	if pile.get_child_count() == 0:
		return null
	
	var card = pile.get_child(pile.get_child_count() - 1)
	# Store global position before removing
	var stored_global_pos = card.global_position if card is Control else Vector2.ZERO
	
	pile.remove_child(card)
	
	# Restore global position after removing
	if card is Control:
		card.global_position = stored_global_pos
	
	card.visible = true
	card.disabled = false
	return card


##Draws multiple cards from the draw pile. Returns an array of cards.
##If is_discard true uses discard pile instead.
func draw_cards(count: int, is_discard: bool = false) -> Array[Card]:
	var drawn_cards: Array[Card] = []
	
	for i in count:
		var card = draw_card(is_discard)
		if card:
			drawn_cards.append(card)
		else:
			break
	
	return drawn_cards


##Shuffles the draw pile randomly.
##If is_discard true uses discard pile instead.
func shuffle(is_discard: bool = false) -> void:
	var pile = discard_pile if is_discard else draw_pile
	var cards_array: Array[Card] = []
	
	for child in pile.get_children():
		if child is Card:
			cards_array.append(child)
	
	# Remove all cards first
	for card in cards_array:
		pile.remove_child(card)
	
	cards_array.shuffle()
	
	# Re-add in shuffled order
	for card in cards_array:
		pile.add_child(card)
		card.position = Vector2.ZERO


##Moves all cards from discard pile back to draw pile.
func reshuffle_discard_into_draw() -> void:
	var cards_to_move: Array[Card] = []
	
	for child in discard_pile.get_children():
		if child is Card:
			cards_to_move.append(child)
	
	for card in cards_to_move:
		add_card_to_pile(card)


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


##Removes the first specific card from the draw pile.
##If is_discard true uses discard pile instead.
func remove_card_from_pile(card: Card, is_discard: bool = false) -> bool:
	var pile = discard_pile if is_discard else draw_pile
	
	if card.get_parent() == pile:
		var stored_global_pos = card.global_position if card is Control else Vector2.ZERO
		pile.remove_child(card)
		if card is Control:
			card.global_position = stored_global_pos
		return true
	return false



##Returns the number of cards in the draw pile.
##If is_discard true returns discard pile instead.
func get_pile_size(is_discard: bool = false) -> int:
	if is_discard:
		return discard_pile.get_child_count()
	else:
		return draw_pile.get_child_count()


##Returns the total number of cards in both piles.
func get_total_card_count() -> int:
	return get_pile_size() + get_pile_size(true)


##Clears both draw and discard piles, freeing all cards.
func clear_deck() -> void:
	for child in draw_pile.get_children():
		child.queue_free()
	
	for child in discard_pile.get_children():
		child.queue_free()


##Returns true if the draw pile is empty. 
##If is_discard true checks discard pile instead.
func is_pile_empty(is_discard: bool = false) -> bool:
	if is_discard:
		return discard_pile.get_child_count() == 0
	else:
		return draw_pile.get_child_count() == 0


func _update_card_visibility() -> void:
	if not draw_pile or not discard_pile:
		return
	
	for child in draw_pile.get_children():
		if child is Card:
			child.visible = show_cards
	
	for child in discard_pile.get_children():
		if child is Card:
			child.visible = show_cards


##Inserts a card at a specific position in the draw pile (0 = bottom, -1 = top).
##If from_discard if true it will insert it the discard pile instead.
func add_card_to_pile_at(card: Card, index: int, from_discard: bool = false) -> void:
	card.kill_all_tweens()
	
	var pile = discard_pile if from_discard else draw_pile
	
	if card.get_parent():
		if card.get_parent() is CardHand:
			card.get_parent().remove_card(card, pile)
		else:
			card.reparent(pile)
	else:
		pile.add_child(card)
		
	var clamped_index = clampi(index, 0, pile.get_child_count() - 1)
	pile.move_child(card, clamped_index)
	
	_handle_card_reparanting(card, pile.global_position if pile is Control else Vector2.ZERO)


##Inserts a card at a specific position counting from top of the draw pile.
##If from_discard if true it will insert it the discard pile instead.
func add_card_to_pile_from_top_at(card: Card, position: int, from_discard: bool = false) -> void:
	var pile = discard_pile if from_discard else draw_pile
	var total_cards = pile.get_child_count()
	var index = max(0, total_cards - position)
	add_card_to_pile_at(card, index, from_discard)


##Shows a fanned preview of the draw pile using the provided CardHand.
##If preview_discard is true it will show the discard pile instead.
func show_pile_preview_hand(preview_hand: CardHand, preview_discard: bool = false) -> void:
	pile_preview_hand = preview_hand
	_update_pile_preview_hand(preview_discard)


func _update_pile_preview_hand(preview_discard: bool = false) -> void:
	if not pile_preview_hand:
		return
	
	pile_preview_hand.clear_hand()
	
	var preview_card = discard_pile.get_children() if preview_discard else draw_pile.get_children()
	for child in preview_card:
		if child is Card:
			var card_proxy: Card = Card.new(child.card_data)
			card_proxy.name = child.name + "_preview"
			card_proxy.set_meta("source_card", child)
			pile_preview_hand.add_card(card_proxy)


##Hides the draw pile preview
func hide_pile_preview_hand() -> void:
	if pile_preview_hand:
		pile_preview_hand.clear_hand()
	pile_preview_hand = null
