##The global singleton calls used by the SimpleCards plugin. [color=red]Do not instantiate[/color]
##
##[b]Improved Layout Detection:[/b] Uses metadata stored in .tscn files.
##Scans entire project for layouts marked with [color=yellow]metadata/is_layout = true[/color]
class_name CardGlobal extends Control

##Emited when a card starts being held/dragged
signal holding_card(card: Card)
##Emited when a card stops being held/dragged
signal dropped_card
##Emitted when a new layout is discovered and registered
signal layout_discovered(layout_id: String, tags: Array)
##Emitted when layouts have been refreshed
signal layouts_refreshed


const DEFAULT_LAYOUT = "res://addons/simple_cards/card/card_layout/default_card_layout.tscn"
const DEFAULT_BACK_LAYOUT = "res://addons/simple_cards/card/card_layout/default_card_back_layout.tscn"

##Default front layout ID used. [color=blue]Set[/color] this to the layout ID you want in your scene
var def_front_layout: StringName = &"default":
	set(value):
		if value.is_empty() or value in _layouts:
			def_front_layout = value
		else:
			push_warning("CardGlobal: Layout ID '%s' not found" % value)

##Default back layout ID used.
var def_back_layout: StringName = &"default_back":
	set(value):
		if value.is_empty() or value in _layouts:
			def_back_layout = value
		else:
			push_warning("CardGlobal: Layout ID '%s' not found" % value)

##Dictionary: {layout_id: path} - All discovered layouts
var _layouts: Dictionary = {}
##Dictionary: {layout_id: tags} - Tags for each layout
var _layouts_by_id: Dictionary = {}
##Dictionary: {tag: [layout_ids]} - Layouts grouped by tags
var _layouts_by_tag: Dictionary = {}

##Use in the _init function of the [Card]. Makes sure every card instantiated has a unique name.
var card_index: int
##General held item system. Makes possible dragging and holding only one card
var current_held_item: Card = null:
	set(value):
		current_held_item = value
		if value:
			holding_card.emit(value)
		else:
			dropped_card.emit()


##Global function to get cursor position
##TODO make controller supported
func get_cursor_position() -> Vector2:
	return get_global_mouse_position()


func get_local_cursor_position(node: Node) -> Vector2:
	return node.get_local_mouse_position()


func _init() -> void:
	_discover_layouts()


##Scan the entire project for scenes marked with [member metadata/is_layout].
##Recursively searches all folders except [color=yellow].addons[/color] and hidden folders.
func _discover_layouts() -> void:
	_layouts.clear()
	_layouts_by_id.clear()
	_layouts_by_tag.clear()
	
	print("CardGlobal: Scanning project for layouts...")
	var count = _scan_directory_recursive("res://")

	if ResourceLoader.exists(DEFAULT_LAYOUT):
		_register_layout_entry("default", DEFAULT_LAYOUT, [])
	
	if ResourceLoader.exists(DEFAULT_BACK_LAYOUT):
		_register_layout_entry("default_back", DEFAULT_BACK_LAYOUT, [])
	
	print("CardGlobal: Found %d layouts:" % _layouts.size())
	for layout_id in _layouts:
		var path = _layouts[layout_id]
		var tags = _layouts_by_id.get(layout_id, [])
		if tags.is_empty():
			print(" - %s | path: %s" % [layout_id, path])
		else:
			print(" - %s (tags: %s) | path: %s" % [layout_id, ", ".join(tags), path])
	
	layouts_refreshed.emit()


##Recursively scan a directory for layout scenes.
##Skips .addons and folders starting with dot.
func _scan_directory_recursive(path: String) -> int:
	var count = 0
	
	if not DirAccess.dir_exists_absolute(path):
		return count
	
	var dir = DirAccess.open(path)
	if not dir:
		return count
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + file_name
		
		if dir.current_is_dir():
			if not file_name.begins_with(".") and file_name != "addons":
				count += _scan_directory_recursive(full_path + "/")
		
		elif file_name.ends_with(".tscn"):
			var layout_info = _extract_layout_info(full_path)
			if not layout_info.is_empty():
				_register_layout_entry(layout_info["layout_id"], full_path, layout_info["tags"])
				count += 1
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return count


##Extract layout metadata from a scene file.
##Returns: {layout_id, tags} or empty dict if not a layout
func _extract_layout_info(scene_path: String) -> Dictionary:
	var scene = load(scene_path)
	if not scene or not scene.can_instantiate():
		return {}
	
	var instance = scene.instantiate()
	if not instance.has_meta("is_layout") or not instance.get_meta("is_layout"):
		instance.queue_free()
		return {}
	
	var layout_id = instance.get_meta("layout_id", "")
	var tags = instance.get_meta("tags", [])
	
	instance.queue_free()
	
	if layout_id.is_empty():
		return {}
	
	return {
		"layout_id": layout_id,
		"tags": tags
	}


##Register a layout in internal dictionaries.
func _register_layout_entry(layout_id: String, path: String, tags: Array) -> void:
	_layouts[layout_id] = path
	_layouts_by_id[layout_id] = tags
	
	for tag in tags:
		if tag not in _layouts_by_tag:
			_layouts_by_tag[tag] = []
		_layouts_by_tag[tag].append(layout_id)
	
	layout_discovered.emit(layout_id, tags)


##Returns all available layout IDs
func get_available_layouts() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _layouts.keys():
		result.append(StringName(key))
	return result


##Get layouts by tag.
func get_layouts_by_tag(tag: String) -> Array[StringName]:
	var result: Array[StringName] = []
	if tag in _layouts_by_tag:
		for layout_id in _layouts_by_tag[tag]:
			result.append(StringName(layout_id))
	return result


##Get all tags that have layouts
func get_all_layout_tags() -> Array[String]:
	var result: Array[String] = []
	for tag in _layouts_by_tag.keys():
		result.append(String(tag))
	return result


##Get tags for a specific layout
func get_layout_tags(layout_id: StringName) -> Array:
	return _layouts_by_id.get(layout_id, [])


##Given a layout ID, instantiate and return the layout. 
##If empty or invalid, returns the default front layout.
func create_layout(layout_id: StringName = &"") -> CardLayout:
	var path: String
	
	if layout_id.is_empty() or layout_id not in _layouts:
		path = _layouts.get(def_front_layout, DEFAULT_LAYOUT)
	else:
		path = _layouts[layout_id]
	
	if not ResourceLoader.exists(path):
		push_error("CardGlobal: Layout not found at " + path)
		return null
	
	var scene = load(path)
	if not scene:
		push_error("CardGlobal: Failed to load scene at " + path)
		return null
	
	var instance = scene.instantiate()
	if not instance is CardLayout:
		push_error("CardGlobal: Scene at %s does not extend CardLayout" % path)
		instance.queue_free()
		return null
	
	return instance


##Scan the project again to discover any new layouts
func refresh_layouts() -> void:
	_discover_layouts()
