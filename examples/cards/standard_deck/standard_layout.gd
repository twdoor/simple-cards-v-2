## Visual layout for a StandardCardResource. Shows the suit icon, card value,
## and tints the background based on the card's modifier (Gold, Steel, or None).
## Shared by both the Balatro and Solitaire examples.
##
## Expects these unique-name nodes in the scene:
## %CardColor, %Texture1, %Texture2, %Texture, %Value1, %Value2
extends CardLayout

@onready var card_color: PanelContainer = %CardColor
@onready var texture_1: TextureRect = %Texture1
@onready var value_1: Label = %Value1
@onready var value_2: Label = %Value2
@onready var texture_2: TextureRect = %Texture2
@onready var texture: TextureRect = %Texture

var res: StandardCardResource


func _update_display() -> void:
	res = card_resource as StandardCardResource
	set_color()
	set_texture(res.top_texture)
	set_value()


## Tints the card background based on the modifier.
func set_color() -> void:
	match res.current_modifier:
		res.Modifier.NONE:
			card_color.self_modulate = Color.BISQUE
		res.Modifier.GOLD:
			card_color.self_modulate = Color.GOLD
		res.Modifier.STEEL:
			card_color.self_modulate = Color.LIGHT_STEEL_BLUE


## Converts numeric value to display text (A, J, Q, K for face cards).
func set_value() -> void:
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

	value_1.text = text
	value_2.text = text


## Sets the suit icon on all three texture nodes (center + corners).
func set_texture(suit_texture: Texture2D) -> void:
	texture.texture = suit_texture
	texture_1.texture = suit_texture
	texture_2.texture = suit_texture
