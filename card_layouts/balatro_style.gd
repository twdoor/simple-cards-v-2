extends CardLayout

@onready var card_color: PanelContainer = %CardColor
@onready var texture_rect: TextureRect = %TextureRect
@onready var value_label: Label = %ValueLabel

var res

func _update_display() -> void:
	res = card_resource as BalatroStyleResource
	set_color()
	texture_rect.texture = res.top_texture
	set_value()

func set_color():
	match res.current_modiffier:
		res.modiffier.NONE:
			card_color.self_modulate = Color.BISQUE
		res.modiffier.GOLD:
			card_color.self_modulate = Color.GOLD
		res.modiffier.STEEL:
			card_color.self_modulate = Color.LIGHT_STEEL_BLUE

func set_value():
	var text: String = ""
	
	match res.value:
		1:
			text = "A"
		11:
			text = "J"
		12:
			text = "Q"
		13:
			text = "K"
		_:
			text = str(res.value)
	
	value_label.text = text
