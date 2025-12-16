##The global signelton calls used by the SimpleCards plugin. [color=red]Do not instantiate[/color]
class_name CardGlobal extends Control

##Emited when a card starts being held/dragged
signal holding_card(card: Card)
##Emited when a card stops being held/dragged
signal dropped_card

const LAYOUT_FOLDER = "res://card_layouts/"
const DEFAULT_LAYOUT = "res://addons/simple_cards/card/card_layout/default_card_layout.tscn"
const DEFAULT_BACK_LAYOUT = "res://addons/simple_cards/card/card_layout/default_card_back_layout.tscn"

##Default front layout name used. [color=blue]Set[/color] this to the layout name you want in wanted scene
var def_front_layout: StringName:
	set(value):
		def_front_layout = value
		if _available_layouts.has(value):
			_default_layout_path = _available_layouts[value]
##Default back layout name used. [color=blue]Set[/color] this to the layout name you want in wanted scene
var def_back_layout: StringName

##Dictionary used to store all layouts. The key is the file name while the value is the file paths
var _available_layouts: Dictionary = {}
var _default_layout_path: String = DEFAULT_LAYOUT

##Use in the _init function of the [Card]. Makes sure every card instantiated has a uninque name.
var card_index: int
##General held item system. Makes possible draggin and holding only one card
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


func _ready() -> void: 
	_discover_layouts()


##Will search the [member CardGlobal.LAYOUT_FOLDER] and add any valid layouts to the [member CardGlobal._available_layouts]. [br]Always adds the [color=yellow]"Default"[/color] and [color=yellow]"Default_Back"[/color] layouts.
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


##Returns all the keys of the available layouts
func get_available_layouts() -> Array:
	return _available_layouts.keys()

##Given a name, will try to instantiate the layout with that name. If empty or is not a valid layout, it generates the default layout
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

##Scans the folder again to grab the layouts
func refresh_layouts() -> void:
	_discover_layouts()
