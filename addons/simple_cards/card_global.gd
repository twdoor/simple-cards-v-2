class_name CardGlobal extends Control

signal holding_card(card: Card)
signal dropped_card

const LAYOUT_FOLDER = "res://card_layouts/"
const DEFAULT_LAYOUT = "res://addons/simple_cards/card/card_layout/default_card_layout.tscn"
const DEFAULT_BACK_LAYOUT = "res://addons/simple_cards/card/card_layout/default_card_back_layout.tscn"

var def_front_layout: StringName
var def_back_layout: StringName

var _available_layouts: Dictionary = {}
var _default_layout_path: String = DEFAULT_LAYOUT

var card_index: int
var current_held_item: Card = null:
	set(value):
		current_held_item = value
		if value:
			holding_card.emit(value)
		else:
			dropped_card.emit()


func get_cursor_position() -> Vector2:
	return get_global_mouse_position()
 

func _ready() -> void: 
	_discover_layouts()

func _discover_layouts() -> void:
	_available_layouts.clear()
	
	if ResourceLoader.exists(DEFAULT_LAYOUT):
		_available_layouts["Default"] = DEFAULT_LAYOUT
		def_front_layout = "Default"
		
	if ResourceLoader.exists(DEFAULT_BACK_LAYOUT):
		_available_layouts["Default_Back"] = DEFAULT_BACK_LAYOUT
		def_back_layout = "Default_Back"
	
	if DirAccess.dir_exists_absolute(LAYOUT_FOLDER):
		var dir = DirAccess.open(LAYOUT_FOLDER)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".tscn"):
					var full_path = LAYOUT_FOLDER + file_name
					var layout_name = file_name.get_basename()
					_available_layouts[layout_name] = full_path
				
				file_name = dir.get_next()
			
			dir.list_dir_end()
	
	print("CardLayoutManager: Found %d layouts" % _available_layouts.size())
	for layout_name in _available_layouts:
		print("  - %s: %s" % [layout_name, _available_layouts[layout_name]])


func get_available_layouts() -> Array:
	return _available_layouts.keys()


func create_layout(layout_name: String = "") -> CardLayout:
	var layout_path: String
	
	if layout_name.is_empty() or not _available_layouts.has(layout_name):
		layout_path = _default_layout_path
	else:
		layout_path = _available_layouts[layout_name]
	
	if not ResourceLoader.exists(layout_path):
		push_error("CardLayoutManager: Layout not found at " + layout_path)
		return null
	
	var scene = load(layout_path)
	var instance = scene.instantiate()
	
	if not instance is CardLayout:
		push_error("CardLayoutManager: Scene at %s does not extend CardLayout" % layout_path)
		instance.queue_free()
		return null
	
	return instance


func refresh_layouts() -> void:
	_discover_layouts()
