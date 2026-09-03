extends TextureRect

@export var num_of_card_label: Label


func set_player_info(player_label: String, card_count: int, is_turn: bool = false) -> void:
	if not num_of_card_label:
		return

	num_of_card_label.text = "%s\n%d card%s" % [
		player_label,
		card_count,
		"" if card_count == 1 else "s",
	]
	self_modulate = Color(1.0, 0.92, 0.65, 1.0) if is_turn else Color.WHITE
