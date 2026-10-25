## Visual layout for a StandardCardResource. Shows the suit icon, card value,
## and tints the background based on the card's modifier (Gold, Steel, or None).
## Shared by both the Balatro and Solitaire examples.
##
## Expects these unique-name nodes in the scene:
## %CardColor, %Texture1, %Texture2, %Texture, %Value1, %Value2
@tool
extends CardViewportLayout

@onready var card_color: PanelContainer = %CardColor
@onready var value_1: Label = %Value1
@onready var value_2: Label = %Value2
@onready var texture_1: TextureRect = %Texture1
@onready var texture_2: TextureRect = %Texture2
@onready var texture: TextureRect = %Texture

@export var enable_perspective_hover := true
@export_range(0.0, 45.0, 0.5, "suffix:degrees") var max_tilt_degrees := 15.0
@export_range(1.0, 30.0, 0.5) var follow_speed := 12.0
var _rotation: Vector2

var res: StandardCardResource

const textures: Dictionary[StandardCardResource.Suit, String] = {
	StandardCardResource.Suit.CLUBS: "uid://d13a1tcqjxkas",
	StandardCardResource.Suit.DIAMOND: "uid://bfi67t37l1qlp",
	StandardCardResource.Suit.HEART: "uid://clwd04qm16woo",
	StandardCardResource.Suit.SPADE: "uid://ral2awpcmpdv",
}


func _update_display() -> void:
	res = card_resource as StandardCardResource
	if not res: return


	live_effects = res.is_shiny
	set_color()
	set_texture(res.card_suit)
	set_value()
	set_shiny()
	set_perspective()



## Tints the card background based on the modifier.
func set_color() -> void:
	match res.current_modifier:
		res.Modifier.NONE:
			card_color.self_modulate = Color("ffe1d1ff")
		res.Modifier.GOLD:
			card_color.self_modulate = Color("ffd3a3")
		res.Modifier.STEEL:
			card_color.self_modulate = Color("d3e5f0c0")


## Converts numeric value to display text (A, J, Q, K for face cards).
func set_value() -> void:
	var text: String = ""

	match res.value:
		11:
			text = "J"
		12:
			text = "Q"
		13:
			text = "K"
		14:
			text = "A"
		_:
			text = str(res.value)

	value_1.text = text
	value_2.text = text


## Sets the suit icon on all three texture nodes (center + corners).
func set_texture(suit: StandardCardResource.Suit) -> void:
	var suit_texture: Texture2D = load(textures[suit])
	texture.texture = suit_texture
	texture_1.texture = suit_texture
	texture_2.texture = suit_texture

func set_shiny() -> void:
	if res == null: return
	set_shader_enabled(&"shine", res.is_shiny)


func set_perspective() -> void:
	set_shader_enabled(&"persp" ,enable_perspective_hover)
	set_process(enable_perspective_hover)
	if enable_perspective_hover:
		_rotation = Vector2(
			get_shader_parameter(&"persp", "x_rot"),
			get_shader_parameter(&"persp", "y_rot")
		)
	else:
		_reset_perspective()


func _process(delta: float) -> void:
	# Hover can end without focus exiting (pressed cards and drag companions).
	# Always flatten the shared layout instead of leaving its last angles behind.
	if Engine.is_editor_hint() or not is_instance_valid(card_instance) or not card_resource:
		_reset_perspective()
		return
	if not enable_perspective_hover or card_instance.disabled or not is_visible_in_tree() or not card_instance.is_hovered():
		_reset_perspective()
		return
	if size.x <= 0.0 or size.y <= 0.0:
		_reset_perspective()
		return
	var target: Vector2

	var local_mouse:= get_local_mouse_position()
	var offset := local_mouse / size * 2.0 - Vector2.ONE
	offset = offset.clamp(-Vector2.ONE, Vector2.ONE)
	target = Vector2(-offset.y, offset.x) * max_tilt_degrees
	_rotation = _rotation.lerp(target, 1.0 - exp(-follow_speed * delta))
	if target == Vector2.ZERO and _rotation.length_squared() < 0.0001:
		_rotation = Vector2.ZERO
	set_shader_parameter(&"persp", "x_rot", _rotation.x)
	set_shader_parameter(&"persp", "y_rot", _rotation.y)

func _focus_out() -> void:
	super._focus_out()
	_reset_perspective()


func _reset_perspective() -> void:
	if _rotation == Vector2.ZERO:
		return
	_rotation = Vector2.ZERO
	set_shader_parameter(&"persp", "x_rot", 0.0)
	set_shader_parameter(&"persp", "y_rot", 0.0)
