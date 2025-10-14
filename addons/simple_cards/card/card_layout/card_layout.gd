##This will represent the visual basis for a card face.
##
##[color=green]Use the "Project>Tools>Create new card layout" for a quick setup![/color][br]
##[color=red]The global_script only searches for layouts in the [member CardGlobal._available_layouts] folder![/color][br]
##Alone is preaty much useless. Use other nodes to build your best layout for the cards that need to be made.[br]
##The Subviewport required by this node will also give the card size. (Subviewport.size = card.size)
@icon("uid://dfeet1bp3au3l")
class_name CardLayout extends SubViewportContainer


signal layout_ready ##Emited at the end of the setup function.


##Refrence to the [CardResource] used to initialize the layout. Use it to further customize the layout. 
@export var card_resource: CardResource:
	set(value):
		card_resource = value
		if is_node_ready():
			_update_display()

##Refrence to the [Card] used to initialize the layout.
var card_instance: Card

##Triggered on setup or on changing the [CardResource]. [color=red]Overwrite[/color] it to implement custom visuals.
func _update_display() -> void:
	pass


##Triggered on adding the layout to a [Card]. [color=red]Overwrite[/color] it to implement transition animations.
func _flip_in():
	pass

##Triggered on removing the layout from a [Card]. [color=red]Overwrite[/color] it to implement transition animations.
func _flip_out():
	pass

##Used when a [Card] initializes a layout, set the refrence of the card its resource and emits [member CardLayout.layout_ready] at the end.
func setup(card: Card, resource: CardResource) -> void:
	card_instance = card
	card_resource = resource
	_update_display()
	layout_ready.emit()
