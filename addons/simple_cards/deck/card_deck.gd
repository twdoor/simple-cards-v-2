## A deck definition resource containing the card list that makes up a deck.
##
## CardDeck is a pure data resource — it defines [i]what cards[/i] a deck contains,
## not where they are at runtime. Use [CardDeckManager] or [CardPile] to manage
## runtime state.
## [br][br]
## Example usage:
## [codeblock]
## # In the editor: create a .tres with 52 StandardCardResources
## # At runtime:
## var cards: Array[CardResource] = deck.get_cards()
## [/codeblock]
@icon("uid://u56pws80lkxh")
class_name CardDeck extends Resource


## Name of the deck.
@export var deck_name: StringName = ""

## The cards that make up this deck.
@export var cards: Array[CardResource] = []


## Returns a duplicate of the card list (safe to mutate without affecting the resource).
func get_cards() -> Array[CardResource]:
	return cards.duplicate()


## Returns the number of cards in the deck definition.
func get_size() -> int:
	return cards.size()


## Returns [code]true[/code] if the deck definition has no cards.
func is_empty() -> bool:
	return cards.is_empty()
