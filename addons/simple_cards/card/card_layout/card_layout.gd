##This will represent the visual basis for a card face.
##
##[color=green]Use the "Card Layouts" tab at the bottom for a quick setup![/color][br]
##Alone is pretty much useless. Use other nodes to build your best layout for the cards that need to be made.[br]
##The Subviewport required by this node will also give the card size. (Subviewport.size = card.size)
@icon("uid://dfeet1bp3au3l")
class_name CardLayout extends SubViewportContainer


signal layout_ready ##Emited at the end of the setup function.
##Emitted when layout is initialized
signal layout_initialized(card: Card, resource: CardResource)
##Emitted after display is updated
signal display_updated()
##Emitted when flip in animation starts
signal flip_in_started()
##Emitted when flip in animation completes
signal flip_in_completed()
##Emitted when flip out animation starts
signal flip_out_started()
##Emitted when flip out animation completes
signal flip_out_completed()
##Emitted when focus in animation starts
signal focus_in_started()
##Emitted when focus in animation completes
signal focus_in_completed()
##Emitted when focus out animation starts
signal focus_out_started()
##Emitted when focus out animation completes
signal focus_out_completed()


##Refrence to the [CardResource] used to initialize the layout. Use it to further customize the layout. 
@export var card_resource: CardResource:
	set(value):
		card_resource = value
		if is_node_ready():
			_update_display()

@export_group("Animation Resources")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "Animation Resources") var anim_group_checked:= false
@export var focus_in_animation: CardAnimationResource
@export var focus_out_animation: CardAnimationResource
@export var flip_in_animation: CardAnimationResource
@export var flip_out_animation: CardAnimationResource


##Refrence to the [Card] used to initialize the layout.
var card_instance: Card

##Triggered on setup or on changing the [CardResource]. [color=red]Overwrite[/color] it to implement custom visuals.
func _update_display() -> void:
	display_updated.emit()


##Triggered on adding the layout to a [Card]. Use a CardAnimationResource or [color=red]Overwrite[/color] it to implement transition animations.
func _flip_in():
	flip_in_started.emit()
	if flip_in_animation: 
		await flip_in_animation.play_animation(self)
	flip_in_completed.emit()

##Triggered on removing the layout from a [Card]. Use a CardAnimationResource or [color=red]Overwrite[/color] it to implement transition animations.
func _flip_out():
	flip_out_started.emit()
	if flip_out_animation: 
		await flip_out_animation.play_animation(self)
	flip_out_completed.emit()

##Triggered on a [Card] entering focus. Use a CardAnimationResource or [color=red]Overwrite[/color] it to implement custom behaviour.
func _focus_in():
	focus_in_started.emit()
	if focus_in_animation: 
		await focus_in_animation.play_animation(self)
	focus_in_completed.emit()

##Triggered on a [Card] leaving focus. Use a CardAnimationResource or [color=red]Overwrite[/color] it to implement custom behaviour.
func _focus_out():
	focus_out_started.emit()
	if focus_out_animation: 
		await focus_out_animation.play_animation(self)
	focus_out_completed.emit()
	

##Used when a [Card] initializes a layout, set the refrence of the card its resource and emits [member CardLayout.layout_ready] at the end.
func setup(card: Card, resource: CardResource) -> void:
	card_instance = card
	card_resource = resource
	_update_display()
	layout_initialized.emit(card, resource)
	layout_ready.emit()
