extends CardLayout

@onready var card_color: PanelContainer = %CardColor
@onready var texture_rect: TextureRect = %TextureRect

func _update_display() -> void:
	set_color()
	texture_rect.texture = (card_resource as BalatroStyleResource).top_texture
	
func set_color():
	match (card_resource as BalatroStyleResource).current_modiffier:
		(card_resource as BalatroStyleResource).modiffier.NONE:
			card_color.self_modulate = Color.BISQUE
		(card_resource as BalatroStyleResource).modiffier.GOLD:
			card_color.self_modulate = Color.GOLD
		(card_resource as BalatroStyleResource).modiffier.STEEL:
			card_color.self_modulate = Color.LIGHT_STEEL_BLUE
