# card_global.gd

##The global singleton calls used by the SimpleCards plugin. [color=red]Do not instantiate[/color]
class_name CardGlobal extends Control

##Emitted when a card starts being held/dragged
signal holding_card(card: Card)
##Emitted when a card stops being held/dragged
signal dropped_card
##Emitted when layouts have been loaded
signal layouts_loaded
##Emitted when a layout is registered
signal layout_registered(layout_id: StringName)
##Emitted when a layout is unregistered
signal layout_unregistered(layout_id: StringName)
##Emitted when layouts are refreshed
signal layouts_refreshed()


const DEFAULT_LAYOUT = "res://addons/simple_cards/card/card_layout/default_card_layout.tscn"
const DEFAULT_BACK_LAYOUT = "res://addons/simple_cards/card/card_layout/default_card_back_layout.tscn"
const CACHE_PATH = "res://addons/simple_cards/editor/layout_cache.json"

##Default front layout ID used. [color=blue]Set[/color] this to the layout ID you want in your scene
var def_front_layout: StringName = LayoutID.DEFAULT:
	set(value):
		if value.is_empty() or value in _layouts:
			def_front_layout = value
		else:
			push_warning("CardGlobal: Layout ID '%s' not found" % value)

##Default back layout ID used.
var def_back_layout: StringName = LayoutID.DEFAULT_BACK:
	set(value):
		if value.is_empty() or value in _layouts:
			def_back_layout = value
		else:
			push_warning("CardGlobal: Layout ID '%s' not found" % value)

##Dictionary: {layout_id: path} - All enabled layouts
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
func get_cursor_position() -> Vector2:
	return get_global_mouse_position()


func get_local_cursor_position(node: Node) -> Vector2:
	return node.get_local_mouse_position()


func _init() -> void:
	_load_layouts_from_cache()


##Load layouts from the editor-generated cache file
func _load_layouts_from_cache() -> void:
	_layouts.clear()
	_layouts_by_id.clear()
	_layouts_by_tag.clear()
	
	if not FileAccess.file_exists(CACHE_PATH):
		print("CardGlobal: No layout cache found, using defaults only")
		_register_default_layouts()
		layouts_loaded.emit()
		return
	
	var file = FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not file:
		print("CardGlobal: Failed to read layout cache, using defaults only")
		_register_default_layouts()
		layouts_loaded.emit()
		return
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		print("CardGlobal: Failed to parse layout cache, using defaults only")
		_register_default_layouts()
		layouts_loaded.emit()
		return
	
	var cache_data: Dictionary = json.data
	
	for path in cache_data.keys():
		var layout_data = cache_data[path]
		
		# Skip disabled layouts
		if not layout_data.get("enabled", true):
			continue
		
		var layout_id = layout_data.get("layout_id", "")
		var tags = layout_data.get("tags", [])
		
		if layout_id.is_empty():
			continue
		
		_register_layout_entry(layout_id, path, tags)
	
	# Ensure defaults are registered
	_register_default_layouts()
	
	print("CardGlobal: Loaded %d layouts from cache" % _layouts.size())
	layouts_loaded.emit()


func _register_default_layouts() -> void:
	if "default" not in _layouts and ResourceLoader.exists(DEFAULT_LAYOUT):
		_register_layout_entry("default", DEFAULT_LAYOUT, [])
	
	if "default_back" not in _layouts and ResourceLoader.exists(DEFAULT_BACK_LAYOUT):
		_register_layout_entry("default_back", DEFAULT_BACK_LAYOUT, [])


##Register a layout in internal dictionaries.
func _register_layout_entry(layout_id: String, path: String, tags: Array) -> void:
	_layouts[layout_id] = path
	_layouts_by_id[layout_id] = tags
	layout_registered.emit(StringName(layout_id))
	
	for tag in tags:
		if tag not in _layouts_by_tag:
			_layouts_by_tag[tag] = []
		_layouts_by_tag[tag].append(layout_id)


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


##Reload layouts from cache (useful if cache was updated externally)
func refresh_layouts() -> void:
	_load_layouts_from_cache()
	layouts_refreshed.emit()
