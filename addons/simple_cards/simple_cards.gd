@tool
extends EditorPlugin

const CARD_GLOBAL = "CardGlobal"
const CARD_GLOBAL_FILE_PATH = "res://addons/simple_cards/card_global.gd"
const CARD_GLOBAL_BOOTSTRAP = "res://addons/simple_cards/editor/card_global_bootstrap.tscn"
const LAYOUT_PANEL_PATH = "res://addons/simple_cards/editor/layout_panel.gd"

var layout_panel: Control = null
var layout_dock: EditorDock
var layout_export_plugin: EditorExportPlugin


func _enter_tree():
	# Register before loading editor scripts that depend on runtime card types.
	if not _register_card_global():
		return
	layout_export_plugin = preload("res://addons/simple_cards/editor/layout_export_plugin.gd").new()
	add_export_plugin(layout_export_plugin)

	layout_panel = load(LAYOUT_PANEL_PATH).new()
	layout_panel.editor_interface = EditorInterface
	layout_dock = EditorDock.new()
	layout_dock.name = "CardLayouts"
	layout_dock.title = "Card Layouts"
	layout_dock.layout_key = "SimpleCardsLayouts"
	layout_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	layout_dock.available_layouts = EditorDock.DOCK_LAYOUT_ALL
	layout_dock.icon_name = &"Control"
	layout_dock.add_child(layout_panel)
	add_dock(layout_dock)


func _exit_tree():
	if layout_export_plugin:
		remove_export_plugin(layout_export_plugin)
		layout_export_plugin = null

	if layout_dock:
		remove_dock(layout_dock)
		layout_dock.queue_free()
		layout_dock = null
		layout_panel = null


func _disable_plugin() -> void:
	if _is_card_global_autoload(ProjectSettings.get_setting("autoload/%s" % CARD_GLOBAL, "")):
		remove_autoload_singleton(CARD_GLOBAL)
		ProjectSettings.save()


func _register_card_global() -> bool:
	var key := "autoload/%s" % CARD_GLOBAL
	if ProjectSettings.has_setting(key) and not _is_card_global_autoload(ProjectSettings.get_setting(key)):
		push_error("SimpleCards: Autoload name '%s' is already used by another script. Rename that autoload before enabling SimpleCards." % CARD_GLOBAL)
		return false
	if not ProjectSettings.has_setting(key):
		# Godot loads an autoload before registering its global name. Register a
		# plain node first, then compile the real script while the name exists.
		add_autoload_singleton(CARD_GLOBAL, CARD_GLOBAL_BOOTSTRAP)
		ProjectSettings.set_setting(key, "*" + CARD_GLOBAL_FILE_PATH)
		load(CARD_GLOBAL_FILE_PATH)
		add_autoload_singleton(CARD_GLOBAL, CARD_GLOBAL_FILE_PATH)
		ProjectSettings.save()
	return true


static func _is_card_global_autoload(value: String) -> bool:
	if not value.begins_with("*"):
		return false
	var path := value.trim_prefix("*")
	if path.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(path)
		if not ResourceUID.has_id(uid):
			return false
		path = ResourceUID.get_id_path(uid)
	return path == CARD_GLOBAL_FILE_PATH
