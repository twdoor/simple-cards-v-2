##The basic data containers for the card class. 
##
##Extend this resource to fit your card needs.
@abstract @icon("uid://cvwcyhqx6fvdk")
class_name CardResource extends Resource

signal property_changed(property: StringName, value: Variant)

##If valid, the layout will be used instead of the default front layout.
@export var custom_layout_name: StringName = ""
