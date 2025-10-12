extends CanvasLayer

@onready var card_deck_manager: CardDeckManager = $CardDeckManager
@onready var card_hand: CardHand = $CardHand

var hand_size: int = 6

func _ready() -> void:
	CG.def_front_layout = "tcg_style"
	
	card_deck_manager.setup()
	
	deal(hand_size)

func deal(count: int):
	var to_deal: int = min(count, card_hand.get_remaining_space())
	if card_deck_manager.get_draw_pile_size() >= to_deal:
		card_hand.add_cards(card_deck_manager.draw_cards(to_deal))
		
	elif card_deck_manager.get_draw_pile_size() < to_deal:
		var overflow := to_deal - card_deck_manager.get_draw_pile_size()
		card_hand.add_cards(card_deck_manager.draw_cards(card_deck_manager.get_draw_pile_size()))
		card_deck_manager.reshuffle_discard_and_shuffle()
		if card_deck_manager.get_draw_pile_size() >= overflow:
			card_hand.add_cards(card_deck_manager.draw_cards(overflow))
	
