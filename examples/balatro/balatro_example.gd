## Balatro-style card game example.
##
## Shows off: drawing from a deck, selecting and playing cards, discarding,
## applying visual modifiers (Gold/Steel), sorting, and previewing pile contents.
##
## Scene nodes:
## - CardDeckManager: manages the deck and draw/discard pile nodes
## - BalatroHand: player's hand (arc shape, max 7, click to select)
## - PlayedHand: staging area for played cards (line shape)
## - PreviewHand: grid display for previewing pile contents
extends CanvasLayer

@onready var card_deck_manager: CardDeckManager = $CardDeckManager
@onready var balatro_hand: BalatroHand = $BalatroHand
@onready var played_hand: CardHand = $PlayedHand
@onready var preview_hand: CardHand = %PreviewHand

@onready var gold_button: Button = %GoldButton
@onready var silv_button: Button = %SilvButton
@onready var none_button: Button = %NoneButton

@onready var discard_button: Button = %DiscardButton
@onready var play_button: Button = %PlayButton
@onready var preview_discard_button: Button = %PreviewDiscardButton
@onready var preview_draw_button: Button = %PreviewDrawButton

@onready var sort_suit_button: Button = %SortSuitButton
@onready var sort_value_button: Button = %SortValueButton

var preview_visible: bool = false
var current_preview_pile: Variant = null ## Which CardDeck.Pile is being previewed, or null

var sort_by_suit: bool = false
var hand_size: int


func _ready() -> void:
	gold_button.pressed.connect(_on_gold_pressed)
	silv_button.pressed.connect(_on_silv_pressed)
	none_button.pressed.connect(_on_none_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	play_button.pressed.connect(_on_play_button)
	sort_suit_button.pressed.connect(_on_sort_suit_pressed)
	sort_value_button.pressed.connect(_on_sort_value_pressed)
	preview_discard_button.pressed.connect(_on_preview_discard_pressed)
	preview_draw_button.pressed.connect(_on_preview_draw_pressed)

	CG.def_front_layout = LayoutID.STANDARD_LAYOUT
	CG.def_back_layout = LayoutID.STANDARD_BACK_LAYOUT

	hand_size = balatro_hand.max_hand_size

	card_deck_manager.setup()
	deal()

	card_deck_manager.hide_pile_preview_hand()
	preview_visible = false


#region Modifier Buttons

func _on_gold_pressed() -> void:
	for card: Card in balatro_hand.selected:
		card.card_data.current_modifier = StandardCardResource.Modifier.GOLD
		card.refresh_layout()
	balatro_hand.clear_selected()


func _on_silv_pressed() -> void:
	for card: Card in balatro_hand.selected:
		card.card_data.current_modifier = StandardCardResource.Modifier.STEEL
		card.refresh_layout()
	balatro_hand.clear_selected()


func _on_none_pressed() -> void:
	for card: Card in balatro_hand.selected:
		card.card_data.current_modifier = StandardCardResource.Modifier.NONE
		card.refresh_layout()
	balatro_hand.clear_selected()

#endregion


#region Play and Discard

func _on_discard_pressed() -> void:
	if balatro_hand.selected.is_empty():
		return

	## Duplicate since remove_card modifies the selected array as cards move
	var cards_to_discard := balatro_hand.selected.duplicate()
	balatro_hand.selected.clear()
	for card in cards_to_discard:
		card_deck_manager.add_card_to_pile(card, CardDeck.Pile.DISCARD)

	_close_preview()
	deal()


func _on_play_button() -> void:
	if balatro_hand.selected.is_empty():
		return

	_close_preview()
	_set_interaction_enabled(false)

	## Duplicate since remove_card modifies the selected array as cards move
	balatro_hand.sort_selected()
	var cards_to_play := balatro_hand.selected.duplicate()
	balatro_hand.selected.clear()
	played_hand.add_cards(cards_to_play)

	await get_tree().create_timer(2).timeout ## Replace with VFX/Logic

	## Duplicate since the array changes as cards are removed
	for card in played_hand.cards.duplicate():
		card_deck_manager.add_card_to_pile(card, CardDeck.Pile.DISCARD)

	played_hand.clear_hand()
	deal()
	_set_interaction_enabled(true)

#endregion


#region Dealing

## Fills the hand back up to max size. If draw pile runs out mid-deal,
## reshuffles the discard pile and keeps drawing.
func deal() -> void:
	var remaining_space := balatro_hand.get_remaining_space()
	var to_deal: int = remaining_space if remaining_space >= 0 else hand_size

	if to_deal <= 0:
		return

	var pile_size: int = card_deck_manager.get_pile_size(CardDeck.Pile.DRAW)

	if pile_size >= to_deal:
		balatro_hand.add_cards(card_deck_manager.draw_cards(to_deal))
	else:
		var overflow := to_deal - pile_size
		if pile_size > 0:
			balatro_hand.add_cards(card_deck_manager.draw_cards(pile_size))
		card_deck_manager.reshuffle_discard_and_shuffle()
		var new_pile_size := card_deck_manager.get_pile_size(CardDeck.Pile.DRAW)
		if new_pile_size > 0:
			balatro_hand.add_cards(card_deck_manager.draw_cards(mini(overflow, new_pile_size)))

	for card in balatro_hand.cards:
		if not card.is_front_face:
			card.flip()

	_apply_sort()

#endregion


#region Sorting

func _on_sort_suit_pressed() -> void:
	sort_by_suit = true
	balatro_hand.sort_by_suit()


func _on_sort_value_pressed() -> void:
	sort_by_suit = false
	balatro_hand.sort_by_value()


## Re-applies whichever sort is currently active. Called after dealing.
func _apply_sort() -> void:
	if sort_by_suit:
		balatro_hand.sort_by_suit()
	else:
		balatro_hand.sort_by_value()

#endregion


#region Preview

## Preview buttons toggle their pile. Clicking the same one again closes it,
## clicking the other one switches to that pile.

func _on_preview_discard_pressed() -> void:
	if preview_visible and current_preview_pile == CardDeck.Pile.DISCARD:
		_close_preview()
		return

	if card_deck_manager.is_pile_empty(CardDeck.Pile.DISCARD):
		return

	_show_preview(CardDeck.Pile.DISCARD)


func _on_preview_draw_pressed() -> void:
	if preview_visible and current_preview_pile == CardDeck.Pile.DRAW:
		_close_preview()
		return

	if card_deck_manager.is_pile_empty(CardDeck.Pile.DRAW):
		return

	_show_preview(CardDeck.Pile.DRAW)


func _show_preview(pile: CardDeck.Pile) -> void:
	preview_visible = true
	current_preview_pile = pile
	_set_ui_enabled(false)
	card_deck_manager.show_pile_preview_hand(preview_hand, pile)
	_sort_preview(preview_hand)
	for card in preview_hand.cards:
		card.disabled = true


func _close_preview() -> void:
	if preview_visible:
		card_deck_manager.hide_pile_preview_hand()
	preview_visible = false
	current_preview_pile = null
	_set_ui_enabled(true)


func _sort_preview(hand: CardHand) -> void:
	hand.sort_cards(func(a: Card, b: Card) -> bool:
		if a.card_data.card_suit != b.card_data.card_suit:
			return a.card_data.card_suit < b.card_data.card_suit
		return a.card_data.value < b.card_data.value)

#endregion


#region UI State

## Hides/shows everything. Used by pile preview to take over the screen.
func _set_ui_enabled(enabled: bool) -> void:
	discard_button.disabled = not enabled
	play_button.disabled = not enabled
	sort_suit_button.disabled = not enabled
	sort_value_button.disabled = not enabled
	gold_button.disabled = not enabled
	silv_button.disabled = not enabled
	none_button.disabled = not enabled

	for pile in card_deck_manager.pile_nodes.values():
		pile.visible = enabled
	balatro_hand.visible = enabled


## Disables interaction without hiding anything, so card animations still play.
func _set_interaction_enabled(enabled: bool) -> void:
	discard_button.disabled = not enabled
	play_button.disabled = not enabled
	sort_suit_button.disabled = not enabled
	sort_value_button.disabled = not enabled
	gold_button.disabled = not enabled
	silv_button.disabled = not enabled
	none_button.disabled = not enabled

	for card in balatro_hand.cards:
		card.disabled = not enabled

#endregion
