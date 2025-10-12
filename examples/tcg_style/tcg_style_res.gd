class_name TCGStyleResource extends CardResource

@export var card_name: StringName
@export var art: Texture2D
@export var is_full_art: bool = false
@export var card_type: type = type.OBJECT

enum type{
	OBJECT,
	RESOURCE,
}
