## Solitaire example.
##
## Demonstrates dealing, draw/waste pile cycling, click-to-auto-move,
## drag-and-drop via CardMat areas, win detection, and animated card collection.
##
## Scene nodes:
## - CardDeckManager: manages the 52-card deck and draw pile
## - DrawCard: clickable Card that acts as the stock pile
## - deal_hand: SolitaireHand (SIMPLE) — the waste pile
## - foundations: 4x SolitaireHand (SUIT_MATCH) — Ace to King by suit
## - tableau_piles: 7x SolitaireHand (COLOR_MATCH) — alternating color, descending
## - Button: restarts the game
extends CanvasLayer

@onready var deck_manager: CardDeckManager = $CardDeckManager
@onready var draw_card: Card = $MarginContainer/HBoxContainer/DrawCard
@export var reset_button: Button
@onready var undo_manager: SolitaireUndo = $SolitaireUndo
@export var undo_button: Button


@export var deal_hand: SolitaireHand
@export var deal_hand_num: int = 3 ## Cards drawn per click (1 = easy, 3 = hard)

@export var foundations: Array[SolitaireHand] = []
@export var tableau_piles: Array[SolitaireHand] = []
var all_piles: Array[SolitaireHand] = []


func _ready() -> void:
	reset_button.pressed.connect(set_match)

	all_piles = foundations + tableau_piles

	for hand in [deal_hand] + all_piles:
		hand.set_solitaire_signals()
		hand.go_to_pile.connect(handle_card_transport)
		hand.card_dropped_from_drag.connect(_on_drag_move_completed)

	draw_card.card_clicked.connect(_on_draw_clicked)

	# Undo system setup.
	undo_manager.deal_hand = deal_hand
	undo_manager.starting_pile = deck_manager.starting_pile
	undo_button.pressed.connect(func(): undo_manager.undo())
	undo_manager.undo_stack_changed.connect(func(can: bool): undo_button.disabled = not can)
	undo_button.disabled = true

	set_match()


## Stock pile click: if empty, recycle deal hand back to draw (reversed).
## Otherwise draw cards to the deal hand.
func _on_draw_clicked(_card: Card) -> void:
	if deck_manager.starting_pile.is_empty():
		var original_order: Array[Card] = deal_hand.cards.duplicate()
		draw_card.disabled = true
		var hand_cards: Array[Card] = deal_hand.cards.duplicate()
		hand_cards.reverse()
		deal_hand.move_cards_to(hand_cards, deck_manager.starting_pile, .1, .02)
		await deal_hand.container_empty
		draw_card.disabled = false
		undo_manager.record_recycle(original_order)
		return

	var pre_deal_count: int = deal_hand.cards.size()
	deck_manager.starting_pile.deal_to(deal_hand, deal_hand_num)
	var drawn: Array[Card] = deal_hand.cards.slice(pre_deal_count)
	undo_manager.record_draw(drawn)


## Auto-move: tries to place the clicked card on the first valid pile.
## Single cards can go to foundations or tableau; stacks only go to tableau.
func handle_card_transport(origin_hand: SolitaireHand, card: Card) -> void:
	for hand in all_piles:
		if not hand.can_accept_card(card):
			continue

		if card == origin_hand.cards.back():
			@warning_ignore("confusable_local_declaration")
			var src_idx: int = origin_hand.cards.find(card)
			@warning_ignore("confusable_local_declaration")
			var flip_card: Card = _get_flip_candidate(origin_hand, src_idx)
			card.move_to(hand)
			undo_manager.record_card_move([card], origin_hand, src_idx, hand, flip_card)
			if check_for_win():
				finish_game()
			return

		if foundations.has(hand):
			continue

		var cards_to_move = _get_valid_pile(origin_hand, card)
		if cards_to_move.is_empty():
			continue

		var src_idx: int = origin_hand.cards.find(card)
		var flip_card: Card = _get_flip_candidate(origin_hand, src_idx)
		await origin_hand.move_cards_to(cards_to_move, hand, -1, 0.1)
		undo_manager.record_card_move(cards_to_move, origin_hand, src_idx, hand, flip_card)

		if check_for_win():
			finish_game()
		return


## Gets the stack from card to the bottom of the pile, but only if every
## consecutive pair is a valid sequence. Returns empty if the chain is broken.
func _get_valid_pile(origin_hand: SolitaireHand, card: Card) -> Array[Card]:
	var pile: Array[Card] = origin_hand.cards.slice(origin_hand.cards.find(card))

	for i in range(1, pile.size()):
		if not origin_hand.check_cards_form_sequence(pile[i - 1], pile[i]):
			return []

	return pile


## New game: clear everything, reset the deck, deal tableau piles.
## Each pile i gets i+1 cards. Cards come from pile face-down.
## Rules are applied after each pile is fully dealt.
func set_match() -> void:
	undo_manager.clear()

	for pile in [deal_hand] + all_piles:
		pile.clear_and_free()

	if deck_manager.starting_pile:
		deck_manager.starting_pile.clear_and_free()
	deck_manager.setup()

	for i in tableau_piles.size():
		tableau_piles[i].auto_update = false
		await deck_manager.starting_pile.deal_to(tableau_piles[i], i + 1, 0.5, 0.05)
		tableau_piles[i].auto_update = true
		tableau_piles[i].apply_rules()


## Win condition: draw pile empty, deal hand empty, and all cards face-up.
func check_for_win() -> bool:
	if not deck_manager.starting_pile.is_empty() or not deal_hand.cards.is_empty():
		return false

	for pile in all_piles:
		for card in pile.cards:
			if not card.is_front_face:
				return false

	return true


func finish_game() -> void:
	undo_manager.clear()

	for pile in all_piles:
		pile.set_process_input(false)

	_animate_card_collection()


## Recursively moves face-up cards into their matching foundations, one at a time.
## Tries tableau first, then the deal hand. Stops when nothing can move.
func _animate_card_collection() -> void:
	for pile in tableau_piles:
		if pile.cards.is_empty() or not pile.cards.back().is_front_face:
			continue

		var card = pile.cards.back()
		for foundation in foundations:
			if foundation.can_accept_card(card):
				card.move_to(foundation, .1)
				await card.move_completed
				_animate_card_collection()
				return

	if not deal_hand.cards.is_empty() and deal_hand.cards.back().is_front_face:
		var card = deal_hand.cards.back()
		for foundation in foundations:
			if foundation.can_accept_card(card):
				card.move_to(foundation, .1)
				await card.move_completed
				_animate_card_collection()
				return

	_on_game_finished()


func _on_game_finished() -> void:
	for pile in all_piles:
		pile.set_process_input(true)

	print("Game finished!")


#region Undo Helpers

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and event.ctrl_pressed:
			if undo_manager.can_undo():
				undo_manager.undo()
				get_viewport().set_input_as_handled()


## Returns the card that would be auto-flipped face-up when the card at
## [param card_index] leaves [param pile]. Returns null if no flip would occur.
func _get_flip_candidate(pile: SolitaireHand, card_index: int) -> Card:
	if card_index <= 0:
		return null
	var candidate: Card = pile.cards[card_index - 1]
	if not candidate.is_front_face:
		return candidate
	return null


## Called when a drag-and-drop move completes on any SolitaireHand.
func _on_drag_move_completed(
	source: CardContainer,
	_target: SolitaireHand,
	cards: Array[Card],
	source_index: int,
	flipped_card: Card
) -> void:
	undo_manager.record_card_move(cards, source, source_index, _target, flipped_card)

#endregion
