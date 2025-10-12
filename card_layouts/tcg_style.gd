extends CardLayout


@onready var name_label: Label = %NameLabel
@onready var full_art_rect: TextureRect = %FullArtRect
@onready var art_rect: TextureRect = %ArtRect


var tcg_res: TCGStyleResource

func _update_display() -> void:
	tcg_res = card_resource as TCGStyleResource
	name_label.text = tcg_res.card_name
	
	if tcg_res.is_full_art:
		full_art_rect.texture = tcg_res.art
	else:
		art_rect.texture = tcg_res.art
	
