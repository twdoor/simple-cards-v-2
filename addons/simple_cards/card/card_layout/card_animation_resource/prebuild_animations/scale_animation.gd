class_name ScaleCardAnimation extends CardAnimationResource

@export_custom(PROPERTY_HINT_LINK, "") var scale_value: Vector2 = Vector2.ONE
@export var custom_z_index: int = 0
@export var duration: float = 0.2

func play_animation(layout: CardLayout):
	layout.card_instance.z_index = custom_z_index
	layout.card_instance.tween_scale(scale_value, duration)
