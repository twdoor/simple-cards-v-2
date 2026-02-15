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
@onready var button: Button = $MarginContainer/Button


@export var deal_hand: SolitaireHand
@export var deal_hand_num: int = 1 ## Cards drawn per click (1 = easy, 3 = hard)

@export var foundations: Array[SolitaireHand] = []
@export var tableau_piles: Array[SolitaireHand] = []
var all_piles: Array[SolitaireHand] = []


func _ready() -> void:
	CG.def_front_layout = LayoutID.STANDARD_LAYOUT
	CG.def_back_layout = LayoutID.STANDARD_BACK_LAYOUT

	button.pressed.connect(set_match)

	all_piles = foundations + tableau_piles

	for hand in [deal_hand] + all_piles:
		hand.set_solitaire_signals()
		hand.go_to_pile.connect(handle_card_transport)

	draw_card.card_clicked.connect(_on_draw_clicked)

	set_match.call_deferred()


## Stock pile click: if empty, recycle deal hand back to draw (reversed).
## Otherwise draw cards to the deal hand.
func _on_draw_clicked(_card: Card) -> void:
	if deck_manager.deck.is_pile_empty(CardDeck.Pile.DRAW):
		var hand = deal_hand.cards.duplicate()
		hand.reverse()
		for card in hand:
			deal_hand.remove_card(card)
			deck_manager.add_card_to_pile(card, CardDeck.Pile.DRAW)
		return
	var cards = deck_manager.draw_cards(deal_hand_num)
	deal_hand.add_cards(cards)


## Auto-move: tries to place the clicked card on the first valid pile.
## Single cards can go to foundations or tableau; stacks only go to tableau.
func handle_card_transport(origin_hand: SolitaireHand, card: Card) -> void:
	for hand in all_piles:
		if not hand.check_card_conditions(card):
			continue

		# Top card — can go to any valid pile
		if card == origin_hand.cards.back():
			hand.add_card(card)
			if check_for_win():
				finish_game()
			return

		# Foundations only take single cards
		if foundations.has(hand):
			continue

		# Stack move — validate the whole sequence first
		var cards_to_move = _get_valid_pile(origin_hand, card)
		if cards_to_move.is_empty():
			continue

		for c in cards_to_move:
			hand.add_card(c)
			await get_tree().create_timer(.1).timeout

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
## Each pile i gets i+1 cards, all face-down. The pile's _on_card_modified
## callback flips the top card face-up automatically.
func set_match() -> void:
	for pile in [deal_hand] + all_piles:
		pile.clear_hand()

	deck_manager.clear_deck()
	deck_manager.setup()

	for i in tableau_piles.size():
		var cards = deck_manager.draw_cards(i + 1)

		for card in cards:
			if card.is_front_face:
				card.flip()
		tableau_piles[i].add_cards(cards)


## Win condition: draw pile empty, deal hand empty, and all cards face-up.
func check_for_win() -> bool:
	if not deck_manager.deck.is_pile_empty() or not deal_hand.cards.is_empty():
		return false

	for pile in all_piles:
		for card in pile.cards:
			if not card.is_front_face:
				return false

	return true


func finish_game() -> void:
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
			if foundation.check_card_conditions(card):
				foundation.add_card(card)
				await get_tree().create_timer(0.1).timeout
				_animate_card_collection()
				return

	if not deal_hand.cards.is_empty() and deal_hand.cards.back().is_front_face:
		var card = deal_hand.cards.back()
		for foundation in foundations:
			if foundation.check_card_conditions(card):
				foundation.add_card(card)
				await get_tree().create_timer(0.1).timeout
				_animate_card_collection()
				return

	_on_game_finished()


func _on_game_finished() -> void:
	for pile in all_piles:
		pile.set_process_input(true)

	print("Game finished!")
