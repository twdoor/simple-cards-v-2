## A CardHand representing a single pile in Solitaire.
##
## Three pile types:
## - SIMPLE: Deal/waste pile. Only the top card is clickable.
## - SUIT_MATCH: Foundation piles. Same suit, ascending order (Ace → King).
## - COLOR_MATCH: Tableau piles. Alternating colors, descending (King → Ace).
##
## Set hand_type and optionally drop_area in the inspector,
## then call set_solitaire_signals() during setup.
class_name SolitaireHand extends CardHand

## Emitted when a card is clicked. The main scene handles finding the right destination.
signal go_to_pile(origin_hand: SolitaireHand, card: Card)

enum type {
	SIMPLE,      ## Deal/waste pile
	SUIT_MATCH,  ## Foundation (same suit, Ace → King)
	COLOR_MATCH, ## Tableau (alternating colors, King → Ace)
}

@export var hand_type: type = type.SIMPLE

## Optional CardMat for drag-and-drop. Cards dropped here get validated and added.
@export var drop_area: CardMat


## Call this once during scene setup to wire up the pile's signals.
func set_solitaire_signals() -> void:
	arrangement_completed.connect(_on_card_modified)
	if drop_area:
		drop_area.card_dropped.connect(add_card_to_pile)


## After any arrangement change, update which cards are interactable.
## SIMPLE/SUIT_MATCH: only the top card is enabled.
## COLOR_MATCH: only the top card is draggable (others stay clickable for stack moves).
func _on_card_modified() -> void:
	if cards.is_empty():
		return

	match hand_type:
		type.SIMPLE, type.SUIT_MATCH:
			for card in cards:
				card.disabled = true

			cards.back().disabled = false
			cards.back().is_front_face = true
		type.COLOR_MATCH:
			for card in cards:
				card.undraggable = true

			cards.back().undraggable = false
			cards.back().is_front_face = true


## Validates and adds a dropped card. Connected to drop_area's card_dropped signal.
func add_card_to_pile(card: Card) -> void:
	if check_card_conditions(card):
		add_card(card)


func _is_alternating_color(suit1: StandardCardResource.Suit, suit2: StandardCardResource.Suit) -> bool:
	var blacks = [StandardCardResource.Suit.CLUBS, StandardCardResource.Suit.SPADE]
	var reds = [StandardCardResource.Suit.HEART, StandardCardResource.Suit.DIAMOND]
	return (blacks.has(suit1) and reds.has(suit2)) or (reds.has(suit1) and blacks.has(suit2))


## Checks if card can legally follow after_card based on pile rules.
func _is_valid_follow(after_card: Card, card: Card) -> bool:
	var after_data = after_card.card_data as StandardCardResource
	var card_data = card.card_data as StandardCardResource

	match hand_type:
		type.SUIT_MATCH:
			return card_data.card_suit == after_data.card_suit and card_data.value == after_data.value + 1
		type.COLOR_MATCH:
			return _is_alternating_color(after_data.card_suit, card_data.card_suit) and card_data.value == after_data.value - 1
	return false


## Can this card be placed on this pile?
## Empty pile: Aces start foundations, Kings start tableau.
## Otherwise delegates to _is_valid_follow.
func check_card_conditions(card: Card) -> bool:
	if cards.is_empty():
		var card_data = card.card_data as StandardCardResource
		match hand_type:
			type.SUIT_MATCH:
				return card_data.value == 1
			type.COLOR_MATCH:
				return card_data.value == 13
		return false
	return _is_valid_follow(cards.back(), card)


## Checks if two cards form a valid consecutive pair. Used to validate stack moves.
func check_cards_form_sequence(card1: Card, card2: Card) -> bool:
	return _is_valid_follow(card1, card2)


func _handle_clicked_card(card: Card) -> void:
	go_to_pile.emit(self, card)
