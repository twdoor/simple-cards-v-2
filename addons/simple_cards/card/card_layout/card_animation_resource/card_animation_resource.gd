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


## Completes finite animation awaits even when their layout leaves the tree.
func _await_tween(layout: CardLayout, tween: Tween) -> void:
	# Each invocation needs its own callable, including overlapping animations
	# using the same resource. Finish while the layout's awaiters are still alive.
	var interrupted := func() -> void: _finish_interrupted_tween(tween)
	layout.tree_exiting.connect(interrupted, CONNECT_ONE_SHOT)
	await tween.finished
	if is_instance_valid(layout) and layout.tree_exiting.is_connected(interrupted):
		layout.tree_exiting.disconnect(interrupted)


func _finish_interrupted_tween(tween: Tween) -> void:
	tween.kill()
	# Killing a tween does not emit finished. Resolve callers during tree exit,
	# so an animation's coroutine cannot retain a canceled tween or caller.
	tween.finished.emit()
