extends CanvasLayer


@onready var card_deck_manager: CardDeckManager = $CardDeckManager
@onready var card_hand: CardHand = $CardHand
@onready var played_hand: CardHand = $PlayedHand



@onready var gold_button: Button = %GoldButton
@onready var silv_button: Button = %SilvButton
@onready var none_button: Button = %NoneButton

@onready var discard_button: Button = %DiscardButton
@onready var play_button: Button = %PlayButton

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
	
	CG.def_front_layout = "balatro_style"
	
	hand_size = card_hand.max_hand_size
	card_deck_manager.setup()
	deal()
	
	


func _on_gold_pressed() -> void:
	for card in card_hand.selected:
		card.card_data.current_modiffier = 1
		card._layout._update_display()
	card_hand.clear_selected()
	
func _on_silv_pressed() -> void:
	for card in card_hand.selected:
		card.card_data.current_modiffier = 2
		card._layout._update_display()
	card_hand.clear_selected()
	
func _on_none_pressed() -> void:
	for card: Card in card_hand.selected:
		card.card_data.current_modiffier = 0
		card._layout._update_display()
	card_hand.clear_selected()



func _on_discard_pressed() -> void:
	for card in card_hand.selected:
		card_deck_manager.add_card_to_discard_pile(card)
	card_hand.clear_selected()
	
	deal()


func _on_play_button() -> void:
	card_hand.sort_selected()
	played_hand.add_cards(card_hand.selected)
	card_hand.clear_selected()
	

	await get_tree().create_timer(2).timeout ##Replace with VFX/Logic
	
	for card in played_hand.cards:
		card_deck_manager.add_card_to_discard_pile(card)

	played_hand.clear_hand()
	deal()
	

func deal():
	var to_deal: int = min(hand_size, card_hand.get_remaining_space())
	if card_deck_manager.get_draw_pile_size() >= to_deal:
		card_hand.add_cards(card_deck_manager.draw_cards(to_deal))
		
	elif card_deck_manager.get_draw_pile_size() < to_deal:
		var overflow := to_deal - card_deck_manager.get_draw_pile_size()
		card_hand.add_cards(card_deck_manager.draw_cards(card_deck_manager.get_draw_pile_size()))
		card_deck_manager.reshuffle_discard_and_shuffle()
		if card_deck_manager.get_draw_pile_size() >= overflow:
			card_hand.add_cards(card_deck_manager.draw_cards(overflow))
	
	if sort_by_suit: card_hand.sort_by_suit()
	else: card_hand.sort_by_value()


func _on_sort_suit_pressed() -> void:
	sort_by_suit = true
	card_hand.sort_by_suit()

func _on_sort_value_pressed() -> void:
	sort_by_suit = false
	card_hand.sort_by_value()
