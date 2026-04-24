class_name ScaleCardAnimation extends CardAnimationResource

@export_custom(PROPERTY_HINT_LINK, "") var scale_value: Vector2 = Vector2.ONE
@export var custom_z_index: int = 0
@export var duration: float = 0.2


func play_animation(layout: CardLayout) -> void:
	layout.pivot_offset = layout.size / 2

	var scale_tween: Tween = layout.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	scale_tween.tween_property(layout, "scale", scale_value, duration)
	layout.card_instance.z_index += custom_z_index
	await scale_tween.finished
