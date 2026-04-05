## A CardHand representing a single pile in Solitaire.
##
## Three pile types:
## - SIMPLE: Deal/waste pile. Only the top card is clickable.
## - SUIT_MATCH: Foundation piles. Same suit, ascending order (Ace → King).
## - COLOR_MATCH: Tableau piles. Alternating colors, descending (King → Ace).
##
## Supports multi-card drag on COLOR_MATCH piles: grabbing a face-up card
## mid-tableau drags the entire valid sequence below it as a visual stack.
## Drop targets receive the full stack via [method get_drag_stack].
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
	if drop_area:
		drop_area.card_dropped.connect(_on_mat_card_dropped)


## When [code]true[/code], card interactability and face state are updated after every
## layout change. Set to [code]false[/code] during animated dealing, then call
## [method apply_rules] when finished.
var auto_update: bool = true


func _container_ready() -> void:
	enable_pile_drag = true
	super._container_ready()


## After any layout change, update which cards are interactable.
## SIMPLE/SUIT_MATCH: only the top card is enabled.
## COLOR_MATCH: face-up cards are interactive, face-down cards are locked.
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
				card.undraggable = !card.is_front_face
				card.disabled = !card.is_front_face
			cards.back().is_front_face = true
			cards.back().undraggable = false
			cards.back().disabled = false


## Manually applies pile rules. Call after dealing with [member auto_update] off.
func apply_rules() -> void:
	_on_card_modified()


## Fires _on_card_modified after every layout recomputation (if auto_update is on).
func _compute_layout() -> void:
	super._compute_layout()
	if auto_update:
		_on_card_modified()


#region Pile Drag

## Solitaire: only COLOR_MATCH piles drag stacks,
## and only face-up cards forming a valid alternating sequence are companions.
func _get_drag_companions(card: Card) -> Array[Card]:
	if hand_type != type.COLOR_MATCH: return []
	if not card.is_front_face: return []

	var idx = cards.find(card)
	var result: Array[Card] = []
	var prev = card
	for follower in cards.slice(idx + 1):
		if not follower.is_front_face: break
		if not _is_valid_follow(prev, follower): break
		result.append(follower)
		prev = follower
	return result

#endregion


#region Drop Handling

## Called when a card is dropped on this hand's CardMat.
## Conditions are checked automatically by [method Card.move_to].
func _on_mat_card_dropped(card: Card) -> void:
	card.move_to(self)

#endregion


#region Validation

## Hooks solitaire rules into CardContainer's acceptance check.
## This makes [method Card.move_to] respect pile rules automatically.
## Bypassed when [member auto_update] is off (setup/dealing mode).
func _check_conditions(card: Card) -> bool:
	if not auto_update: return true
	match hand_type:
		type.SIMPLE:
			return true
		type.SUIT_MATCH, type.COLOR_MATCH:
			if cards.is_empty():
				var card_data = card.card_data as StandardCardResource
				match hand_type:
					type.SUIT_MATCH:
						return card_data.value == 14
					type.COLOR_MATCH:
						return card_data.value == 13
			return _is_valid_follow(cards.back(), card)
	return false


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
			var cond_1: bool = card_data.card_suit == after_data.card_suit
			var cond_2: bool = card_data.value == after_data.value + 1
			var cond_3: bool = card_data.value == 2 and after_data.value == 14
			var cond_4: bool = cond_2 or cond_3
			return cond_1 and cond_4
		type.COLOR_MATCH:
			var cond_1: bool = _is_alternating_color(after_data.card_suit, card_data.card_suit)
			var cond_2: bool = card_data.value == after_data.value - 1
			var cond_3: bool = after_data.value != 14
			var cond_4: bool = cond_2 and cond_3
			return cond_1 and cond_4
	return false


## Checks if two cards form a valid consecutive pair. Used to validate stack moves.
func check_cards_form_sequence(card1: Card, card2: Card) -> bool:
	return _is_valid_follow(card1, card2)

#endregion


func _handle_clicked_card(card: Card) -> void:
	go_to_pile.emit(self, card)
