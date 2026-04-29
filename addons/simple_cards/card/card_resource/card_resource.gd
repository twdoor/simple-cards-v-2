##The basic data containers for the card class.
##
##Extend this resource to fit your card needs.
##[br][br]Subclasses should add [code]@tool[/code] so the layout name enum appears in the inspector.

@abstract @tool @icon("uid://cvwcyhqx6fvdk")
class_name CardResource extends Resource

##If valid, the layout will be used instead of the default front layout.
@export var front_layout_name: StringName = ""
@export var back_layout_name: StringName = ""


func _validate_property(property: Dictionary) -> void:
	if property.name == "front_layout_name" or property.name == "back_layout_name":
		var options: String = ",".join(LayoutID.get_all())
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = options
