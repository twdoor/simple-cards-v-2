extends CanvasLayer

const BALATRO_DECK = preload("uid://u1x8i453q018")
@onready var card_hand: Control = $CardHand
@onready var gold_button: Button = %GoldButton
@onready var silv_button: Button = %SilvButton
@onready var none_button: Button = %NoneButton

@onready var discard_button: Button = %DiscardButton
@onready var deal_button: Button = %DealButton


var deck: CardDeck = BALATRO_DECK
var hand_size:= 7

func _ready() -> void:
	CG.def_front_layout = "balatro_style"
	deck.initialize()
	deck.shuffle()
	draw_from_deck_to_hand(hand_size)
	gold_button.pressed.connect(_on_gold_pressed)
	silv_button.pressed.connect(_on_silv_pressed)
	none_button.pressed.connect(_on_none_pressed)
	deal_button.pressed.connect(_on_deal_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	
func draw_from_deck_to_hand(count: int):
	var cards := deck.draw_cards(count)
	for card in cards:
		card_hand.add_card(Card.new(card))


func _on_gold_pressed() -> void:
	for card in card_hand.selected:
		card.card_data = card.card_data.duplicate_card()
		card.card_data.current_modiffier = 1
		card._layout._update_display()
	card_hand.selected.clear()
	card_hand.update_selected()

func _on_silv_pressed() -> void:
	for card in card_hand.selected:
		card.card_data = card.card_data.duplicate_card()
		card.card_data.current_modiffier = 2
		card._layout._update_display()
	card_hand.selected.clear()
	card_hand.update_selected()
		
func _on_none_pressed() -> void:
	for card: Card in card_hand.selected:
		card.card_data = card.card_data.duplicate_card()
		card.card_data.current_modiffier = 0
		card._layout._update_display()
	card_hand.selected.clear()
	card_hand.update_selected()



func _on_deal_pressed() -> void:
	pass

func _on_discard_pressed() -> void:
	pass
