## Internal shared rules for editor metadata, generated IDs, and runtime cache data.
@tool
class_name LayoutValidation extends RefCounted


static func id_error(layout_id: String, entries: Dictionary, exclude_path: String = "") -> String:
	if layout_id.is_empty():
		return "Layout ID cannot be empty"
	if layout_id != layout_id.strip_edges() or not layout_id.is_valid_identifier():
		return "Layout ID must be a valid identifier without surrounding whitespace"
	for path in entries:
		if path == exclude_path or not entries[path] is Dictionary:
			continue
		var other = entries[path].get("layout_id", "")
		if not other is String:
			continue
		if other == layout_id:
			return "Layout ID '%s' already exists" % layout_id
		if constant_name(other) == constant_name(layout_id):
			return "Layout IDs '%s' and '%s' generate the same constant" % [layout_id, other]
	return ""


static func entry_error(path: String, data: Variant) -> String:
	if not data is Dictionary:
		return "Cache entry must be a dictionary"
	if not path.begins_with("res://") or not path.ends_with(".tscn"):
		return "Layout path must be a project .tscn scene"
	if not data.get("layout_id") is String:
		return "Layout ID must be a string"
	if not data.get("tags", []) is Array:
		return "Layout tags must be an array"
	for tag in data.get("tags", []):
		if not tag is String:
			return "Layout tags must contain strings"
	if not data.get("enabled", true) is bool:
		return "Layout enabled flag must be a boolean"
	return ""


static func errors(entries: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for path in entries:
		var message := entry_error(str(path), entries[path])
		if message.is_empty():
			message = id_error(entries[path].layout_id, entries, str(path))
		if message.is_empty() and not ResourceLoader.exists(str(path)):
			message = "Layout scene is missing"
		if not message.is_empty():
			result.append("%s: %s" % [path, message])
	result.sort()
	return result


## Instantiate without entering the tree; callers own the returned node.
static func instantiate_layout(scene: PackedScene) -> CardLayout:
	if not scene or not scene.can_instantiate():
		return null
	var instance := scene.instantiate()
	if instance is CardLayout:
		return instance
	instance.free()
	return null


static func constant_name(layout_id: String) -> String:
	var sanitized := ""
	for character in layout_id.to_upper():
		var code := character.unicode_at(0)
		var valid := (code >= 65 and code <= 90) or (code >= 48 and code <= 57) or character == "_"
		sanitized += character if valid else "_"
	if sanitized.is_empty():
		sanitized = "LAYOUT"
	if sanitized.unicode_at(0) >= 48 and sanitized.unicode_at(0) <= 57:
		sanitized = "LAYOUT_" + sanitized
	return sanitized
