class_name FadeCardAnimation extends CardAnimationResource

enum Fade{
	IN,
	OUT,
}

@export var fade_type: Fade
@export var fade_duration: float = 0.5

var fade_tween: Tween

func play_animation(layout: CardLayout):
	if fade_tween: fade_tween.kill()
	
	fade_tween = layout.create_tween()
	match fade_type:
		Fade.IN:
			fade_tween.tween_property(layout.card_instance, "modulate", Color.WHITE, fade_duration).from(Color.TRANSPARENT)
		Fade.OUT:
			fade_tween.tween_property(layout.card_instance, "modulate", Color.TRANSPARENT, fade_duration).from(Color.WHITE)
