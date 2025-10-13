##Resource for holding and managing decks of cards
@icon("uid://u56pws80lkxh")
class_name CardDeck extends Resource

##Name of the deck
@export var deck_name: StringName = ""
##The original card list (template for resetting)
@export var cards: Array[CardResource] = []

##Everyone knows what a horse is!
var horse
