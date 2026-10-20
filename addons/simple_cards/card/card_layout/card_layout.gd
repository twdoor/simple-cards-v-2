## Base container for a card face, rendered directly in the surrounding canvas.
## Add Controls as children to build the face. Use [CardViewportLayout] when a
## shader needs a texture containing the entire face.
@tool
@icon("uid://dfeet1bp3au3l")
class_name CardLayout extends Container

##Emitted from _layout_ready() after ready-time initialization.
signal layout_ready()
##Emitted when layout is initialized
signal layout_initialized(card: Card, resource: CardResource)
##Emitted after display is updated
signal display_updated()
##Emitted when [member card_size] changes. Connected by [Card] to reactively update its size.
signal card_size_changed(new_size: Vector2i)
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
##Emitted at the end of setup()
signal setup_completed(card: Card, resource: CardResource)

## Size of the card in pixels. Sizes the layout and notifies its parent [Card].
## Zero initializes from the scene's size, falling back to 80 by 112 pixels.
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var card_size: Vector2i = Vector2i.ZERO:
	set(value):
		if card_size == value: return
		card_size = value
		_apply_card_size()


##Reference to the [CardResource] used to initialize the layout. Use it to further customize the layout.
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


##Reference to the [Card] used to initialize the layout.
var card_instance: Card

##Triggered on setup or on changing the [CardResource]. [color=red]Override[/color] it to implement custom visuals.
func _update_display() -> void:
	display_updated.emit()


##Triggered on adding the layout to a [Card]. Use a CardAnimationResource or [color=red]Override[/color] it to implement transition animations.
func _flip_in() -> void:
	flip_in_started.emit()
	if flip_in_animation:
		await flip_in_animation.play_animation(self)
	flip_in_completed.emit()

##Triggered on removing the layout from a [Card]. Use a CardAnimationResource or [color=red]Override[/color] it to implement transition animations.
func _flip_out() -> void:
	flip_out_started.emit()
	if flip_out_animation:
		await flip_out_animation.play_animation(self)
	flip_out_completed.emit()

##Triggered on a [Card] entering focus. Use a CardAnimationResource or [color=red]Override[/color] it to implement custom behaviour.
func _focus_in() -> void:
	focus_in_started.emit()
	if focus_in_animation:
		await focus_in_animation.play_animation(self)
	focus_in_completed.emit()

##Triggered on a [Card] leaving focus. Use a CardAnimationResource or [color=red]Override[/color] it to implement custom behaviour.
func _focus_out() -> void:
	focus_out_started.emit()
	if focus_out_animation:
		await focus_out_animation.play_animation(self)

	focus_out_completed.emit()
## Triggered at the end of [code]_ready()[/code]. [color=red]Override[/color] it to implement custom behaviour.
func _layout_ready() -> void:
	layout_ready.emit()

func _ready() -> void:
	if card_size == Vector2i.ZERO:
		card_size = _get_initial_card_size()
	else:
		_apply_card_size()
	_layout_ready()


func _get_initial_card_size() -> Vector2i:
	return Vector2i(size) if size.x > 0 and size.y > 0 else Vector2i(80, 112)


## Applies the face dimensions and notifies the parent card.
func _apply_card_size() -> void:
	if not is_inside_tree() or card_size == Vector2i.ZERO:
		return
	custom_minimum_size = Vector2(card_size)
	size = Vector2(card_size)
	queue_sort()
	card_size_changed.emit(card_size)


## Fits direct child Controls to the card face. Nest containers for other arrangements.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for child in get_children():
			if child is Control and not child.is_set_as_top_level():
				fit_child_in_rect(child, Rect2(Vector2.ZERO, size))


## Scene used by the editor's New Layout dialog for this layout type.
## Override to provide a custom node hierarchy. Called before entering the tree.
func get_layout_template() -> PackedScene:
	return load("res://addons/simple_cards/card/card_layout/default_card_layout.tscn")


##Used when a [Card] initializes a layout, sets the card/resource references, updates the display,
##and emits [member CardLayout.setup_completed] at the end.
func setup(card: Card, resource: CardResource) -> void:
	card_instance = card
	card_resource = resource
	_update_display()
	layout_initialized.emit(card, resource)
	setup_completed.emit(card, resource)
