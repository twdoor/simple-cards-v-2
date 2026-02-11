##Manages a [CardDeck] by creating and managing Card node instances.
@icon("uid://u56pws80lkxh")
class_name CardDeckManager extends Node

##Emitted when deck is initialized
signal deck_initialized(deck: CardDeck)
##Emitted after piles are synchronized
signal piles_synchronized()
##Emitted when a card instance is created
signal card_instance_created(card: Card, resource: CardResource)
##Emitted when a card instance is destroyed
signal card_instance_destroyed(card: Card)
##Emitted when cards are drawn
signal cards_drawn(cards: Array[Card], count: int, from_pile: CardDeck.Pile)
##Emitted when draw from empty pile is attempted
signal draw_failed(pile: CardDeck.Pile)
##Emitted when preview is shown
signal preview_shown(preview_hand: CardHand, pile: CardDeck.Pile)
##Emitted when preview is hidden
signal preview_hidden()
##Emitted when deck state is saved
signal deck_state_saved(state: Dictionary)
##Emitted when deck state is loaded
signal deck_state_loaded(state: Dictionary)

##The deck resource being managed
@export var deck: CardDeck

##If true, automatically calls setup() when ready
@export var auto_setup: bool = false

##If true, shuffles the deck when setup() is called
@export var shuffle_on_ready: bool = true

##Dictionary mapping piles to their container nodes
@export var pile_nodes: Dictionary[CardDeck.Pile, Node] = {}
##Dictionary mapping piles to their preffered card face
@export var front_face_in_pile: Dictionary[CardDeck.Pile, bool]

##If true, cards in piles are visible
@export var show_cards: bool = false:
	set(value):
		show_cards = value
		_update_card_visibility()


var _pile_preview_hand: CardHand


func _ready() -> void:
	if auto_setup:
		setup.call_deferred()


#region Setup and Initialization

##Sets up the deck manager and initializes the deck
func setup(starting_deck: CardDeck = deck) -> void:
	if starting_deck:
		deck = starting_deck
	
	_set_up_front_faces()
	_setup_piles()
	
	if deck:
		if deck.is_pile_empty(CardDeck.Pile.DRAW) and deck.is_pile_empty(CardDeck.Pile.DISCARD):
			deck.reset_to_draw()
		
		if shuffle_on_ready:
			for pile in deck.piles:
				deck.shuffle_pile(pile)
		
		_sync_from_deck()
		deck_initialized.emit(deck)


func _setup_piles() -> void:
	for pile in CardDeck.Pile.values():
		if not pile_nodes.has(pile) or pile_nodes[pile] == null:
			var pile_node = Node.new()
			pile_node.name = CardDeck.Pile.keys()[pile]
			add_child(pile_node)
			pile_nodes[pile] = pile_node


func _set_up_front_faces():
	for pile in CardDeck.Pile.values():
		if !front_face_in_pile.has(pile):
			front_face_in_pile.set(pile, false)

##Synchronizes visual Card nodes from the deck's state
func _sync_from_deck() -> void:
	if not deck:
		return
	
	_clear_piles()
	
	for pile in pile_nodes:
		for card_resource in deck.get_pile(pile):
			var card = Card.new(card_resource)
			card.is_front_face = front_face_in_pile[pile]
			card.visible = show_cards
			card.disabled = true
			pile_nodes[pile].add_child(card)
			card_instance_created.emit(card, card_resource)
	
	piles_synchronized.emit()

#endregion

#region Drawing Cards

##Draws a card from the top of a pile. Returns null if pile is empty.
func draw_card(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> Card:
	if not deck or not pile_nodes.has(pile):
		draw_failed.emit(pile)
		return null
	
	var pile_node = pile_nodes[pile]
	
	var card_resource = deck.draw_from_pile(pile)
	if not card_resource:
		draw_failed.emit(pile)
		return null
	
	if pile_node.get_child_count() == 0:
		draw_failed.emit(pile)
		return null
	
	var card = pile_node.get_child(pile_node.get_child_count() - 1)
	var stored_global_pos = card.global_position if card is Control else Vector2.ZERO
	
	pile_node.remove_child(card)
	
	if card is Control:
		card.global_position = stored_global_pos
	
	card.visible = true
	card.disabled = false
	
	cards_drawn.emit([card], 1, pile)
	return card


##Draws multiple cards from a pile
func draw_cards(count: int, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> Array[Card]:
	var drawn_cards: Array[Card] = []
	
	for i in count:
		var card = draw_card(pile)
		if card:
			drawn_cards.append(card)
		else:
			break
	
	return drawn_cards


##Peeks at the top card of a pile without removing it. Returns null if pile is empty.
func peek_top_card(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> Card:
	if not pile_nodes.has(pile):
		return null
	
	var pile_node = pile_nodes[pile]
	
	if pile_node.get_child_count() == 0:
		return null
	
	return pile_node.get_child(pile_node.get_child_count() - 1)


##Peeks at the top N cards of a pile without removing them. Returns array in draw order (top card first).
func peek_top_cards(count: int, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> Array[Card]:
	if not pile_nodes.has(pile):
		return []
	
	var pile_node = pile_nodes[pile]
	var peeked_cards: Array[Card] = []
	
	var pile_size = pile_node.get_child_count()
	var start_index = max(0, pile_size - count)
	
	for i in range(pile_size - 1, start_index - 1, -1):
		peeked_cards.append(pile_node.get_child(i))
	
	return peeked_cards

#endregion

#region Adding Cards to Piles

##Adds a card to a pile
func add_card_to_pile(card: Card, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> void:
	if not deck or not pile_nodes.has(pile):
		return
	
	var pile_node = pile_nodes[pile]
	
	if card.get_parent():
		if card.get_parent() is CardHand:
			card.get_parent().remove_card(card, pile_node)
		elif card.get_parent():
			card.reparent(pile_node)
	else:
		pile_node.add_child(card)
	
	deck.add_to_pile(card.card_data, pile)
	
	_handle_card_reparenting(card, pile_node.global_position if pile_node is Control else Vector2.ZERO)


##Adds a card to a pile at a specific index (0 = bottom, -1 = top)
func add_card_to_pile_at(card: Card, index: int, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> void:
	if not deck or not pile_nodes.has(pile):
		return
	
	var pile_node = pile_nodes[pile]
	
	if card.get_parent():
		if card.get_parent() is CardHand:
			card.get_parent().remove_card(card, pile_node)
		elif card.get_parent():
			card.reparent(pile_node)
	else:
		pile_node.add_child(card)
	
	pile_node.move_child(card, index)
	
	var pile_array = deck.get_pile(pile)
	
	var actual_index = index
	if actual_index < 0:
		actual_index = pile_array.size() + actual_index + 1
	
	if actual_index < 0 or actual_index >= pile_array.size():
		pile_array.append(card.card_data)
	else:
		pile_array.insert(actual_index, card.card_data)
	
	_handle_card_reparenting(card, pile_node.global_position if pile_node is Control else Vector2.ZERO)


func _handle_card_reparenting(card: Card, desired_position: Vector2 = Vector2.ZERO) -> void:
	card.rotation = 0
	card.tween_position(desired_position, 0.2, true)
	card.visible = show_cards
	card.disabled = true

#endregion

#region Removing Cards

##Removes a specific card from a pile. Returns true if successful.
func remove_card_from_pile(card: Card, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> bool:
	if not deck or not card or not pile_nodes.has(pile):
		return false
	
	var pile_node = pile_nodes[pile]
	
	if card.get_parent() != pile_node:
		return false
	
	var stored_global_pos = card.global_position if card is Control else Vector2.ZERO
	pile_node.remove_child(card)
	
	if card is Control:
		card.global_position = stored_global_pos

	var pile_array = deck.get_pile(pile)
	var index = pile_array.find(card.card_data)
	if index != -1:
		pile_array.remove_at(index)
		card_instance_destroyed.emit(card)
		return true
	
	return false


##Removes a card from a pile at a specific index (0 = bottom, -1 or pile_size-1 = top). Returns the removed card or null.
func remove_card_from_pile_at(index: int, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> Card:
	if not deck or not pile_nodes.has(pile):
		return null
	
	var pile_node = pile_nodes[pile]
	
	if pile_node.get_child_count() == 0:
		return null
	
	
	var actual_index = index
	if actual_index < 0:
		actual_index = pile_node.get_child_count() + actual_index
	
	if actual_index < 0 or actual_index >= pile_node.get_child_count():
		return null
	
	var card = pile_node.get_child(actual_index)
	var stored_global_pos = card.global_position if card is Control else Vector2.ZERO
	pile_node.remove_child(card)
	
	if card is Control:
		card.global_position = stored_global_pos
	
	var pile_array = deck.get_pile(pile)
	if actual_index < pile_array.size():
		pile_array.remove_at(actual_index)
	
	card.visible = true
	card.disabled = false
	card_instance_destroyed.emit(card)
	return card

#endregion

#region Pile Operations
func shuffle(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> void:
	if not deck or not pile_nodes.has(pile):
		return
	
	var pile_node = pile_nodes[pile]
	
	deck.shuffle_pile(pile)
	
	var cards_array: Array[Card] = []
	for child in pile_node.get_children():
		if child is Card:
			cards_array.append(child)
	
	for card in cards_array:
		pile_node.remove_child(card)
	
	cards_array.shuffle()
	
	for card in cards_array:
		pile_node.add_child(card)
		card.position = Vector2.ZERO


##Moves all cards from discard pile back to draw pile
func reshuffle_discard_into_draw() -> void:
	if not deck or not pile_nodes.has(CardDeck.Pile.DRAW) or not pile_nodes.has(CardDeck.Pile.DISCARD):
		return
	
	deck.move_discard_to_draw()
	
	var cards_to_move: Array[Card] = []
	for child in pile_nodes[CardDeck.Pile.DISCARD].get_children():
		if child is Card:
			cards_to_move.append(child)
	
	for card in cards_to_move:
		card.is_front_face = front_face_in_pile[CardDeck.Pile.DRAW]
		card.reparent(pile_nodes[CardDeck.Pile.DRAW])


##Moves all cards from discard to draw and shuffles
func reshuffle_discard_and_shuffle() -> void:
	reshuffle_discard_into_draw()
	shuffle(CardDeck.Pile.DRAW)

#endregion

#region Pile Queries

##Returns the number of cards in a pile
func get_pile_size(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> int:
	if not deck:
		return 0
	return deck.get_pile_size(pile)


##Returns true if a pile is empty
func is_pile_empty(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> bool:
	if not deck:
		return true
	return deck.is_pile_empty(pile)


##Returns the total number of cards in both piles
func get_total_card_count() -> int:
	if not deck:
		return 0
	return deck.get_total_card_count()

#endregion

#region Cleanup

##Clears piles, freeing all Card nodes
func clear_deck() -> void:
	_clear_piles()
	
	if deck:
		for pile in CardDeck.Pile.values():
			deck.get_pile(pile).clear()


func _clear_piles() -> void:
	for pile in CardDeck.Pile.values():
		if pile_nodes.has(pile) and pile_nodes[pile]:
			for child in pile_nodes[pile].get_children():
				child.queue_free()


func _update_card_visibility() -> void:
	for pile in CardDeck.Pile.values():
		if pile_nodes.has(pile) and pile_nodes[pile]:
			for child in pile_nodes[pile].get_children():
				if child is Card:
					child.visible = show_cards

#endregion

#region Preview Functions

##Shows a preview of a pile in a CardHand
func show_pile_preview_hand(preview_hand: CardHand, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> void:
	_pile_preview_hand = preview_hand
	_update_pile_preview_hand(pile)
	preview_shown.emit(preview_hand, pile)


func _update_pile_preview_hand(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> void:
	if not _pile_preview_hand or not pile_nodes.has(pile):
		return
	
	_pile_preview_hand.clear_hand()
	var preview_cards: Array[Card] = []
	var preview_card = pile_nodes[pile].get_children() 
	
	for child in preview_card:
		if child is Card:
			var card_proxy: Card = Card.new(child.card_data)
			card_proxy.name = child.name + "_preview"
			card_proxy.set_meta("source_card", child)
			preview_cards.append(card_proxy)
	
	_pile_preview_hand.add_cards(preview_cards)


##Hides the pile preview
func hide_pile_preview_hand() -> void:
	if _pile_preview_hand:
		_pile_preview_hand.clear_hand()
	_pile_preview_hand = null
	preview_hidden.emit()


#endregion

#region Save/Load

##Saves the current deck state to a dictionary
func save_deck_state() -> Dictionary:
	if not deck:
		return {}
	var state = deck.save_state()
	deck_state_saved.emit(state)
	return state


##Loads deck state from a dictionary and rebuilds visual state
func load_deck_state(state: Dictionary) -> void:
	if not deck:
		return
	
	deck.load_state(state)
	_sync_from_deck()
	deck_state_loaded.emit(state)
	
#endregion
