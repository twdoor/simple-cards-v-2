##Resource for holding and managing decks of cards
@icon("uid://u56pws80lkxh")
class_name CardDeck extends Resource

enum Pile {
	DRAW,
	DISCARD,
}


const KEY_DECK_NAME = "deck_name"
const KEY_CARD_LIST = "card_list"
const KEY_PILES = "piles"

##Name of the deck
@export var deck_name: StringName = ""

##The complete card composition (what cards make up this deck)
@export var card_list: Array[CardResource] = []


var piles: Dictionary[Pile, Array] = {}


func _init() -> void:
	for pile in Pile.values():
		piles[pile] = []


#region Initialization

##Moves all cards from card_list to the draw pile (resets the deck to initial state)
func reset_to_draw() -> void:
	for pile in Pile.values():
		piles[pile].clear()
	
	piles[Pile.DRAW] = card_list.duplicate()


##Shuffles a pile
func shuffle_pile(pile: Pile = Pile.DRAW) -> void:
	if piles.has(pile):
		piles[pile].shuffle()


#endregion

#region Deck Building

##Adds a card to the deck's card list
func add_card(card: CardResource) -> void:
	card_list.append(card)


##Removes a card from the deck's card list (removes first occurrence). Returns true if successful.
func remove_card(card: CardResource) -> bool:
	var index = card_list.find(card)
	if index != -1:
		card_list.remove_at(index)
		return true
	return false


##Returns how many copies of a card are in the card list
func get_card_count(card: CardResource) -> int:
	var count = 0
	for c in card_list:
		if c == card:
			count += 1
	return count


##Creates a duplicate of this deck
func duplicate_deck() -> CardDeck:
	var new_deck = CardDeck.new()
	new_deck.deck_name = deck_name
	new_deck.card_list = card_list.duplicate()
	
	for pile in Pile.values():
		if piles.has(pile):
			new_deck.piles[pile] = piles[pile].duplicate()
	
	return new_deck


##Gets the array for a specific pile
func get_pile(pile: Pile) -> Array:
	if not piles.has(pile):
		piles[pile] = []
	return piles[pile]

#endregion

#region State Queries

##Returns the number of cards in a pile
func get_pile_size(pile: Pile = Pile.DRAW) -> int:
	return get_pile(pile).size()


##Returns true if a pile is empty
func is_pile_empty(pile: Pile = Pile.DRAW) -> bool:
	return get_pile(pile).is_empty()


##Returns the total number of cards in all piles
func get_total_card_count() -> int:
	var total = 0
	for pile in Pile.values():
		total += get_pile_size(pile)
	return total

#endregion

#region State Manipulation (used by CardDeckManager)

##Draws a card from the top of a pile. Returns null if pile is empty.
func draw_from_pile(pile: Pile = Pile.DRAW) -> CardResource:
	var pile_array = get_pile(pile)
	if pile_array.is_empty():
		return null
	return pile_array.pop_back()


##Adds a card to a pile
func add_to_pile(card: CardResource, pile: Pile = Pile.DRAW) -> void:
	get_pile(pile).append(card)


##Moves a card from one pile to another. Returns true if successful.
func move_card(card: CardResource, from_pile: Pile, to_pile: Pile) -> bool:
	var from_array = get_pile(from_pile)
	var to_array = get_pile(to_pile)
	
	var index = from_array.find(card)
	if index == -1:
		return false
	
	from_array.remove_at(index)
	to_array.append(card)
	return true


##Moves all cards from one pile to another
func move_pile_to_pile(from_pile: Pile, to_pile: Pile) -> void:
	var from_array = get_pile(from_pile)
	var to_array = get_pile(to_pile)
	
	to_array.append_array(from_array)
	from_array.clear()


##Moves all cards from discard to draw pile (convenience method)
func move_discard_to_draw() -> void:
	move_pile_to_pile(Pile.DISCARD, Pile.DRAW)

#endregion

#region Serialization

##Saves the current deck state to a dictionary
func save_state() -> Dictionary:
	var state = {
		KEY_DECK_NAME: deck_name,
		KEY_CARD_LIST: card_list.map(func(c): return c.resource_path),
		KEY_PILES: {}
	}
	
	for pile in Pile.values():
		var pile_name = Pile.keys()[pile]
		state[KEY_PILES][pile_name] = get_pile(pile).map(func(c): return c.resource_path)
	
	return state


##Loads deck state from a dictionary
func load_state(state: Dictionary) -> void:
	deck_name = state.get(KEY_DECK_NAME, "")
	
	if state.has(KEY_CARD_LIST):
		card_list.clear()
		for path in state[KEY_CARD_LIST]:
			var card = load(path) as CardResource
			if card:
				card_list.append(card)
	
	if state.has(KEY_PILES):
		var piles_data = state[KEY_PILES]
		
		for pile in Pile.values():
			var pile_name = Pile.keys()[pile]
			
			if piles_data.has(pile_name):
				get_pile(pile).clear()
				for path in piles_data[pile_name]:
					var card = load(path) as CardResource
					if card:
						get_pile(pile).append(card)

#endregion
