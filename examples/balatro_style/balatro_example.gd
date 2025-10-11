extends CanvasLayer


@onready var card_deck_manager: CardDeckManager = $CardDeckManager
@onready var card_hand: CardHand = $CardHand


@onready var gold_button: Button = %GoldButton
@onready var silv_button: Button = %SilvButton
@onready var none_button: Button = %NoneButton

@onready var discard_button: Button = %DiscardButton
@onready var sort_button: Button = %SortButton
@onready var play_button: Button = %PlayButton


var hand_size:= 7

func _ready() -> void:
	gold_button.pressed.connect(_on_gold_pressed)
	silv_button.pressed.connect(_on_silv_pressed)
	none_button.pressed.connect(_on_none_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	sort_button.pressed.connect(_on_sort_pressed)
	play_button.pressed.connect(_on_play_button)
	
	CG.def_front_layout = "balatro_style"
	
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
		card_hand.remove_card(card)
		card_deck_manager.add_card_to_discard_pile(card)
	card_hand.clear_selected()
	
	deal()


func _on_play_button() -> void:
	pass


func _on_sort_pressed() -> void:
	card_hand.sort_by_suit()


func deal():
	if card_deck_manager.is_draw_pile_empty():
		card_deck_manager.reshuffle_discard_and_shuffle()
	
	var to_deal: int = min(hand_size, card_hand.get_remaining_space())
	card_hand.add_cards(card_deck_manager.draw_cards(to_deal))
	card_hand.sort_by_suit()
