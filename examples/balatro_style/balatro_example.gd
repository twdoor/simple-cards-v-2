extends CanvasLayer


@onready var card_deck_manager: CardDeckManager = $CardDeckManager
@onready var balatro_hand: BalatroHand = $BalatroHand
@onready var played_hand: CardHand = $PlayedHand
@onready var preview_hand: CardHand = %PreviewHand

var preview_visible: bool = false


@onready var gold_button: Button = %GoldButton
@onready var silv_button: Button = %SilvButton
@onready var none_button: Button = %NoneButton

@onready var discard_button: Button = %DiscardButton
@onready var play_button: Button = %PlayButton
@onready var preview_discard_button: Button = %PreviewDiscardButton
@onready var preview_draw_button: Button = %PreviewDrawButton



@onready var sort_suit_button: Button = %SortSuitButton
@onready var sort_value_button: Button = %SortValueButton

var sort_by_suit: bool = false
var hand_size: int

func _init() -> void:
	CG.def_front_layout = "balatro_style"

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
	
	CG.def_front_layout = "balatro_style"

	hand_size = balatro_hand.max_hand_size
	
	card_deck_manager.setup()
	deal()
	
	card_deck_manager.hide_pile_preview_hand()
	preview_visible = false


func _on_gold_pressed() -> void:
	for card: Card in balatro_hand.selected:
		card.card_data.current_modiffier = 1
		card.refresh_layout()
	balatro_hand.clear_selected()
	
func _on_silv_pressed() -> void:
	for card: Card in balatro_hand.selected:
		card.card_data.current_modiffier = 2
		card.refresh_layout()
	balatro_hand.clear_selected()
	
func _on_none_pressed() -> void:
	for card: Card in balatro_hand.selected:
		card.card_data.current_modiffier = 0
		card.refresh_layout()
	balatro_hand.clear_selected()



func _on_discard_pressed() -> void:
	for card in balatro_hand.selected:
		card_deck_manager.add_card_to_discard_pile(card)
	balatro_hand.clear_selected()
	
	card_deck_manager.hide_pile_preview_hand()
	preview_visible = false
	
	deal()


func _on_play_button() -> void:
	card_deck_manager.hide_pile_preview_hand()
	preview_visible = false
	
	balatro_hand.sort_selected()
	played_hand.add_cards(balatro_hand.selected)
	balatro_hand.clear_selected()
	
	
	await get_tree().create_timer(2).timeout ##Replace with VFX/Logic
	
	for card in played_hand.cards:
		card_deck_manager.add_card_to_discard_pile(card)

	played_hand.clear_hand()
	deal()
	

func deal():
	var to_deal: int = min(hand_size, balatro_hand.get_remaining_space())
	if to_deal < 0:
		to_deal = 7
	
	if card_deck_manager.get_draw_pile_size() >= to_deal:
		balatro_hand.add_cards(card_deck_manager.draw_cards(to_deal))
		
	elif card_deck_manager.get_draw_pile_size() < to_deal:
		var overflow := to_deal - card_deck_manager.get_draw_pile_size()
		balatro_hand.add_cards(card_deck_manager.draw_cards(card_deck_manager.get_draw_pile_size()))
		card_deck_manager.reshuffle_discard_and_shuffle()
		if card_deck_manager.get_draw_pile_size() >= overflow:
			balatro_hand.add_cards(card_deck_manager.draw_cards(overflow))
	
	for card in balatro_hand.cards:
		if !card.is_front_face:
			card.flip()
	
	if sort_by_suit: balatro_hand.sort_by_suit()
	else: balatro_hand.sort_by_value()
	
	
func _on_sort_suit_pressed() -> void:
	sort_by_suit = true
	balatro_hand.sort_by_suit()

func _on_sort_value_pressed() -> void:
	sort_by_suit = false
	balatro_hand.sort_by_value()

func _on_preview_discard_pressed():
	preview_visible = !preview_visible
	
	if preview_visible:
		card_deck_manager.show_pile_preview_hand(preview_hand, true)
		complete_sort(preview_hand)
	else:
		card_deck_manager.hide_pile_preview_hand()
	
func _on_preview_draw_pressed():
	preview_visible = !preview_visible
	
	if preview_visible:
		card_deck_manager.show_pile_preview_hand(preview_hand, false)
		complete_sort(preview_hand)
	else:
		card_deck_manager.hide_pile_preview_hand()


func complete_sort(hand: CardHand) -> void:
	hand._cards.sort_custom(func(a: Card, b: Card) -> bool:
		if a.card_data.card_suit != b.card_data.card_suit:
			return a.card_data.card_suit < b.card_data.card_suit
		else:
			return a.card_data.value < b.card_data.value
	)
	hand._arrange_cards()
