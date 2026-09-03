##The basic data containers for the card class.
##
##Extend this resource to fit your card needs.
##[br][br]Subclasses should add [code]@tool[/code] so the layout name enum appears in the inspector.

@abstract @tool @icon("uid://cvwcyhqx6fvdk")
class_name CardResource extends Resource

##If valid, the layout will be used instead of the default front layout.
@export var front_layout_name: StringName = ""
@export var back_layout_name: StringName = ""
@export_group("Multiplayer (Experimental)")
## Stable resource ID used when synchronizing visible card data.
## @experimental: Multiplayer support may change before it is considered stable.
@export var network_resource_id: StringName = &""
@export_group("")


func _validate_property(property: Dictionary) -> void:
	if property.name == "front_layout_name" or property.name == "back_layout_name":
		var options: String = ",".join(LayoutID.get_all())
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = options


## Returns this resource's stable network ID.
## Defaults to [member resource_path] so peers can load the same local resource.
## @experimental: Multiplayer support may change before it is considered stable.
func get_network_resource_id() -> StringName:
	if not network_resource_id.is_empty():
		return network_resource_id
	if not resource_path.is_empty():
		return StringName(resource_path)
	return StringName(str(get_instance_id()))


## Serializes exported/stored Variant-safe values for network transfer.
## Object, Resource, RID, Callable, Signal, and nested values containing them are skipped.
## @experimental: Multiplayer support may change before it is considered stable.
func to_network_data(_for_peer_id: int = 0) -> Dictionary:
	var data: Dictionary = {}
	for property in get_property_list():
		var name := String(property.get("name", ""))
		if name.is_empty() or name.begins_with("_"):
			continue
		if name in ["script", "resource_path", "resource_name", "resource_scene_unique_id", "resource_local_to_scene", "network_resource_id"]:
			continue
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var value = get(name)
		if _is_network_safe_value(value):
			data[name] = value
	return data


## Applies data produced by [method to_network_data].
## @experimental: Multiplayer support may change before it is considered stable.
func apply_network_data(data: Dictionary) -> void:
	var allowed := _get_network_property_names()
	for key in data.keys():
		var name := String(key)
		if not allowed.has(name):
			continue
		var value = data[key]
		if _is_network_safe_value(value):
			set(name, value)


func _get_network_property_names() -> Dictionary:
	var result: Dictionary = {}
	for property in get_property_list():
		var name := String(property.get("name", ""))
		if name.is_empty() or name.begins_with("_"):
			continue
		if name in ["script", "resource_path", "resource_name", "resource_scene_unique_id", "resource_local_to_scene", "network_resource_id"]:
			continue
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_STORAGE) != 0:
			result[name] = true
	return result


func _is_network_safe_value(value, depth: int = 0) -> bool:
	if depth > 8:
		return false

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I:
			return true
		TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I:
			return true
		TYPE_PLANE, TYPE_QUATERNION, TYPE_AABB, TYPE_BASIS, TYPE_TRANSFORM2D, TYPE_TRANSFORM3D, TYPE_PROJECTION:
			return true
		TYPE_COLOR, TYPE_NODE_PATH:
			return true
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			return true
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return true
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return true
		TYPE_ARRAY:
			for item in value:
				if not _is_network_safe_value(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value.keys():
				if not _is_network_safe_value(key, depth + 1):
					return false
				if not _is_network_safe_value(value[key], depth + 1):
					return false
			return true
		_:
			return false
