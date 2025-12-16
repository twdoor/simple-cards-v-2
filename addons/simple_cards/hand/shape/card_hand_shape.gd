@abstract @icon("uid://bg3fht552vtas")
##Abstract base class for card hand arrangement shapes.
class_name CardHandShape extends Resource

##Arranges the cards in the hand according to the shape's logic. Need to return an array of the card positions. 
##[br]- [code]cards[/code]: Array of cards to arrange
##[br]- [code]hand[/code]: The hand container
##[br]- [code]skipped_cards[/code]: Optional cards to skip during arrangement (used for drag reordering)
@abstract func arrange_cards(cards: Array[Card], hand: CardHand, skipped_cards: Array[Card] = []) -> Array[Vector2]
