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

## Vertical offset between cards in a dragged stack (in pixels).
@export var stack_drag_offset: float = 30.0

## The cards following the dragged card (not including the lead card itself).
var _drag_followers: Array[Card] = []


## Call this once during scene setup to wire up the pile's signals.
func set_solitaire_signals() -> void:
	arrangement_completed.connect(_on_card_modified)
	if drop_area:
		drop_area.card_dropped.connect(_on_mat_card_dropped)


## After any arrangement change, update which cards are interactable.
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

#region Multi-Drag Stack

## Override: keep drag followers at high z_index during drag so they render above the hand.
func _update_z_indices() -> void:
	for i in cards.size():
		if cards[i] == _dragged_card:
			continue
		if _drag_followers.has(cards[i]):
			cards[i].z_index = 900 + _drag_followers.find(cards[i])
			continue
		cards[i].z_index = i


## Override: exclude drag followers from arrangement so they don't snap back to hand positions.
func arrange_cards() -> void:
	if _drag_followers.is_empty():
		super.arrange_cards()
		return

	if cards.is_empty():
		update_minimum_size()
		return

	arrangement_started.emit()

	var layout = shape.compute_layout(cards)
	_card_positions = layout.positions

	_update_z_indices()
	_update_focus_chain()
	update_minimum_size()

	var skipped: Array[Card] = [_dragged_card]
	skipped.append_array(_drag_followers)
	shape.apply_layout(cards, layout, skipped)

	cards_reordered.emit(cards)
	arrangement_completed.emit()


## Override: when a card from this hand starts being held, build the drag stack.
func _on_holding_card(card: Card) -> void:
	_drag_followers.clear()

	super._on_holding_card(card)

	if not cards.has(card):
		return
	if hand_type != type.COLOR_MATCH:
		return
	if not card.is_front_face:
		return

	var card_index = cards.find(card)
	var potential_followers = cards.slice(card_index + 1)

	var prev_card = card
	for follower in potential_followers:
		if not follower.is_front_face:
			break
		if not _is_valid_follow(prev_card, follower):
			break
		_drag_followers.append(follower)
		prev_card = follower

	if _drag_followers.is_empty():
		return

	for follower in _drag_followers:
		follower.disabled = true
		follower.z_index = 900


	set_process(true)



## Override _process: skip reordering when dragging a stack, only update followers.
func _process(delta: float) -> void:
	if _drag_followers.is_empty():
		_update_card_reordering()
	_update_drag_followers(delta)


## Moves follower cards in a chain — each follows the one above it, creating a trailing effect.
func _update_drag_followers(delta: float) -> void:
	if _dragged_card == null or _drag_followers.is_empty():
		return
	if not _dragged_card.holding:
		return

	var lerp_weight = 1 - exp(delta * _dragged_card.drag_coef)

	for i in _drag_followers.size():
		var follower = _drag_followers[i]
		var leader = _dragged_card if i == 0 else _drag_followers[i - 1]
		var target_pos = leader.global_position + Vector2(0, stack_drag_offset)
		follower.global_position = lerp(
			follower.global_position,
			target_pos,
			lerp_weight)


## Override: handle drop cleanup and transfer followers to the receiving hand.
func _finish_card_drop() -> void:
	var had_followers = not _drag_followers.is_empty()
	var followers_copy = _drag_followers.duplicate()
	var lead_card = _dragged_card
	
	for follower in _drag_followers:
		follower.disabled = false



	_drag_followers.clear()


	_dragged_card = null

	
	super._finish_card_drop()
	
	if had_followers and lead_card and lead_card.get_parent() != self:
		var target = lead_card.get_parent()
		if target is CardHand:
			for follower in followers_copy:
				target.add_card(follower)


## Returns the current drag stack (lead card + followers).
## Drop targets use this to receive the full sequence on drop.
func get_drag_stack() -> Array[Card]:
	if _dragged_card == null:
		return []
	var stack: Array[Card] = [_dragged_card]
	stack.append_array(_drag_followers)
	return stack

#endregion


#region Drop Handling

## Called when a card is dropped on this hand's CardMat.
## Checks the source for a drag stack and adds the full valid sequence.
func _on_mat_card_dropped(card: Card) -> void:
	if not check_card_conditions(card):
		return

	var source_hand = card.get_parent()
	if source_hand is SolitaireHand and source_hand.hand_type == type.COLOR_MATCH:
		var stack = source_hand.get_drag_stack()
		if stack.size() > 1 and stack[0] == card:
			for stack_card in stack:
				add_card(stack_card)
			return

	add_card(card)

#endregion


#region Validation

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

#endregion


func _handle_clicked_card(card: Card) -> void:
	go_to_pile.emit(self, card)
