##The basic data containers for the card class. 
##
##Extend this resource to fit your card needs.
@abstract @icon("uid://cvwcyhqx6fvdk")
class_name CardResource extends Resource

signal proprety_changed


##If valid, the layout will be used instead of the default front layout.
@export var custom_layout_name: StringName = ""


##Creates a deep copy of this card resource that can be modified independently
func duplicate_card() -> CardResource:
	return self.duplicate(true)


##Modify a property on this card resource. Returns true if successful.
func modify_property(property_name: StringName, value: Variant) -> bool:
	if property_name in self:
		self.set(property_name, value)
		return true
	else:
		push_warning("CardResource: Property '%s' does not exist" % property_name)
		return false


##Get the current value of a property. Returns null if property doesn't exist.
func get_property_value(property_name: StringName) -> Variant:
	if property_name in self:
		return self.get(property_name)
	else:
		push_warning("CardResource: Property '%s' does not exist" % property_name)
		return null
