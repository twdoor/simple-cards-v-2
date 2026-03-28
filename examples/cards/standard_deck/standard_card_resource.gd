## A standard playing card resource. Stores suit, value (1-13), a display texture,
## and an optional visual modifier. Used by both the Balatro and Solitaire examples.
class_name StandardCardResource extends CardResource

@export var name: String
@export var top_texture: Texture2D
@export var current_modifier: Modifier = Modifier.NONE
@export var card_suit: Suit = Suit.ALL
@export_range(2,14) var value: int = 2 ## 14 = Ace, 11 = Jack, 12 = Queen, 13 = King

## Changes the card's background color in the layout.
enum Modifier {
	NONE,
	GOLD,
	STEEL,
}

enum Suit {
	CLUBS,
	DIAMOND,
	HEART,
	SPADE,
	ALL, # Wildcard
}


##Set the layouts in the init of resource if you have multiple layout for multiple cards.
func _init() -> void:
	front_layout_name = LayoutID.STANDARD_LAYOUT
	back_layout_name = LayoutID.STANDARD_BACK_LAYOUT
