## Balatro-style card game example.
##
## Shows off: drawing from a deck, selecting and playing cards, discarding,
## applying visual modifiers (Gold/Steel), sorting, and previewing pile contents.
##
## Scene nodes:
## - CardDeckManager: manages the deck, populates the draw pile
## - Draw (CardPile): the draw pile
## - Discard (CardPile): the discard pile
## - BalatroHand: player's hand (arc shape, max 7, click to select)
## - PlayedHand: staging area for played cards (line shape)
extends CanvasLayer

@export var deck: CardDeck
@export var use_stagger_draw: bool = true

@onready var card_deck_manager: CardDeckManager = $CardDeckManager
@onready var played_hand: CardHand = %PlayedHand
@onready var balatro_hand: BalatroHand = %BalatroHand


@onready var draw: CardPile = %Draw
@onready var discard: CardPile = %Discard

@onready var gold_button: Button = %GoldButton
@onready var silv_button: Button = %SilvButton
@onready var none_button: Button = %NoneButton

@onready var discard_button: Button = %DiscardButton
@onready var play_button: Button = %PlayButton

@onready var sort_suit_button: Button = %SortSuitButton
@onready var sort_value_button: Button = %SortValueButton

@onready var preview_hand: CardHand = %PreviewHand
@onready var preview_draw: Button = %PreviewDraw
@onready var preview_discard: Button = %PreviewDiscard
var preview_visible: bool = false
var current_preview_pile: CardPile

var sort_by_suit: bool = false


func _ready() -> void:
	gold_button.pressed.connect(_on_gold_pressed)
	silv_button.pressed.connect(_on_silv_pressed)
	none_button.pressed.connect(_on_none_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	play_button.pressed.connect(_on_play_button)
	sort_suit_button.pressed.connect(_on_sort_suit_pressed)
	sort_value_button.pressed.connect(_on_sort_value_pressed)
	preview_draw.pressed.connect(_on_preview_draw_pressed)
	preview_discard.pressed.connect(_on_preview_discard_pressed)

	CG.def_front_layout = LayoutID.STANDARD_LAYOUT
	CG.def_back_layout = LayoutID.STANDARD_BACK_LAYOUT

	card_deck_manager.setup()
	deal()


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
	
	var cards_to_discard := balatro_hand.selected.duplicate()
	balatro_hand.clear_selected()
	for card in cards_to_discard:
		discard.add_card(card)
	
	deal()


func _on_play_button() -> void:
	if balatro_hand.selected.is_empty():
		return
	
	_set_interaction_enabled(false)
	
	balatro_hand.sort_selected()
	var cards_to_play := balatro_hand.selected.duplicate()
	balatro_hand.clear_selected()
	staggered_draw(cards_to_play, played_hand)
	
	await get_tree().create_timer(2).timeout ## Replace with VFX/Logic
	
	for card in played_hand.cards.duplicate():
		discard.add_card(card)
	
	played_hand.clear_hand()
	deal()
	_set_interaction_enabled(true)

#endregion


#region Dealing

## Fills the hand back up to max size. If draw pile runs out mid-deal,
## reshuffles the discard pile into draw and keeps drawing.
func deal() -> void:
	var remaining_space := balatro_hand.get_remaining_space()
	var to_deal: int = remaining_space if remaining_space >= 0 else balatro_hand.max_hand_size
	
	if to_deal <= 0:
		return
	
	var pile_size: int = draw.get_card_count()
	
	if pile_size >= to_deal:
		staggered_draw(draw.draw_cards(to_deal))
	else:
		var overflow := to_deal - pile_size
		if pile_size > 0:
			staggered_draw(draw.draw_cards(pile_size))
	
		discard.move_all_to(draw)
		draw.shuffle()
	
		var new_pile_size := draw.get_card_count()
		if new_pile_size > 0:
			staggered_draw(draw.draw_cards(mini(overflow, new_pile_size)))
	
	for card in balatro_hand.cards:
		if !card.is_front_face:
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


func _apply_sort() -> void:
	if sort_by_suit:
		balatro_hand.sort_by_suit()
	else:
		balatro_hand.sort_by_value()


#endregion


#region UI State

## Hides/shows everything. Used by pile preview to take over the screen.
func _set_ui_enabled(enabled: bool) -> void:
	discard_button.disabled = !enabled
	play_button.disabled = !enabled
	sort_suit_button.disabled = !enabled
	sort_value_button.disabled = !enabled
	gold_button.disabled = !enabled
	silv_button.disabled = !enabled
	none_button.disabled = !enabled
	
	balatro_hand.visible = enabled


func _set_interaction_enabled(enabled: bool) -> void:
	discard_button.disabled = !enabled
	play_button.disabled = !enabled
	sort_suit_button.disabled = !enabled
	sort_value_button.disabled = !enabled
	gold_button.disabled = !enabled
	silv_button.disabled = !enabled
	none_button.disabled = !enabled
	
	for card in balatro_hand.cards:
		card.disabled = !enabled

#endregion

#region Preview Functions

func _on_preview_discard_pressed() -> void:
	if preview_visible and current_preview_pile == discard:
		_close_preview()
		return

	if discard.is_empty():
		return

	_show_preview(discard)


func _on_preview_draw_pressed() -> void:
	if preview_visible and current_preview_pile == draw:
		_close_preview()
		return

	if draw.is_empty():
		return

	_show_preview(draw)


func _show_preview(pile: CardPile) -> void:
	preview_visible = true
	current_preview_pile = pile
	_set_ui_enabled(false)
	show_pile_preview_hand(current_preview_pile.get_cards())
	_sort_preview(preview_hand)
	for card in preview_hand.cards:
		card.disabled = true


func _close_preview() -> void:
	if preview_visible:
		hide_pile_preview_hand()
	preview_visible = false
	current_preview_pile = null
	_set_ui_enabled(true)


func show_pile_preview_hand(cards: Array[Card]) -> void:
	_update_pile_preview_hand(cards)


func _update_pile_preview_hand(cards: Array[Card]) -> void:
	if cards.is_empty():
		return
	
	preview_hand.clear_hand()
	var preview_cards: Array[Card] = []
	var preview_card = cards
	
	for child in preview_card:
		if child is Card:
			var card_proxy: Card = Card.new(child.card_data)
			card_proxy.name = child.name + "_preview"
			card_proxy.set_meta("source_card", child)
			preview_cards.append(card_proxy)
	
	preview_hand.add_cards(preview_cards)
	_sort_preview(preview_hand)


func hide_pile_preview_hand() -> void:
	if preview_hand:
		preview_hand.clear_and_free()


func _sort_preview(hand: CardHand) -> void:
	hand.sort_cards(func(a: Card, b: Card) -> bool:
		if a.card_data.card_suit != b.card_data.card_suit:
			return a.card_data.card_suit < b.card_data.card_suit
		return a.card_data.value < b.card_data.value)


func staggered_draw(cards: Array[Card], hand: CardHand = balatro_hand, use_it: bool = use_stagger_draw):
	if use_it:
		for card in cards:
			hand.add_card(card)
			await get_tree().create_timer(.075).timeout
	else: hand.add_cards(cards)


#endregion
