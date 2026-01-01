class_name BalatroStyleResource extends CardResource

@export var name: String
@export var top_texture: Texture2D
@export var current_modifier: Modifier = Modifier.NONE
@export var card_suit: Suit = Suit.ALL
@export var value: int = 1

enum Modifier {
	NONE,
	GOLD,
	STEEL,
}

enum Suit{
	CLUBS,
	DIAMOND,
	HEART,
	SPADE,
	ALL,
}
