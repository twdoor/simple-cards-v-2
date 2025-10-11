class_name BalatroStyleResource extends CardResource

@export var name: String
@export var top_texture: Texture2D
@export var current_modiffier: modiffier = modiffier.NONE

enum modiffier {
	NONE,
	GOLD,
	STEEL,
}
