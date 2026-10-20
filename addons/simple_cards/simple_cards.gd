@tool
extends EditorPlugin

const CARD_GLOBAL = "CG"
const CARD_GLOBAL_FILE_PATH = "res://addons/simple_cards/card_global.gd"
const LayoutPanel = preload("res://addons/simple_cards/editor/layout_panel.gd")

var layout_panel: Control = null
var layout_dock: EditorDock
var layout_export_plugin: EditorExportPlugin


func _enter_tree():
	layout_export_plugin = preload("res://addons/simple_cards/editor/layout_export_plugin.gd").new()
	add_export_plugin(layout_export_plugin)
	if not ProjectSettings.has_setting("autoload/%s" % CARD_GLOBAL):
		add_autoload_singleton(CARD_GLOBAL, CARD_GLOBAL_FILE_PATH)
		ProjectSettings.save()
	elif not _is_card_global_autoload(ProjectSettings.get_setting("autoload/%s" % CARD_GLOBAL)):
		push_warning("SimpleCards: Autoload name '%s' already exists; using the existing autoload." % CARD_GLOBAL)

	layout_panel = LayoutPanel.new()
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
