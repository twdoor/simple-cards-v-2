@abstract @icon("uid://dlme71gg5pusd")
##Abstract class used to make reuseable animations for layouts.
class_name CardAnimationResource extends Resource

##If true, the animation loops until [method stop_animation] is called.
@export var looping: bool = false

##Plays the animation when triggered
@abstract func play_animation(layout: CardLayout) -> void

##Stops a looping animation. Override in subclasses that support it.
func stop_animation(layout: CardLayout) -> void:
	pass
