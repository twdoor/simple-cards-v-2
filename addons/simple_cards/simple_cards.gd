@tool
extends EditorPlugin

const CARD_GLOBAL = "CG"
const CARD_GLOBAL_FILE_PATH = "res://addons/simple_cards/card_global.gd"
const LayoutPanel = preload("res://addons/simple_cards/editor/layout_panel.gd")

var layout_panel: Control = null
var layout_export_plugin: EditorExportPlugin


func _enter_tree():
	layout_export_plugin = preload("res://addons/simple_cards/editor/layout_export_plugin.gd").new()
	add_export_plugin(layout_export_plugin)
	if not ProjectSettings.has_setting("autoload/%s" % CARD_GLOBAL):
		add_autoload_singleton(CARD_GLOBAL, CARD_GLOBAL_FILE_PATH)
		ProjectSettings.save()
	elif ProjectSettings.get_setting("autoload/%s" % CARD_GLOBAL) != "*" + CARD_GLOBAL_FILE_PATH:
		push_warning("SimpleCards: Autoload name '%s' already exists; using the existing autoload." % CARD_GLOBAL)

	layout_panel = LayoutPanel.new()
	layout_panel.editor_interface = EditorInterface
	add_control_to_bottom_panel(layout_panel, "Card Layouts")


func _exit_tree():
	if layout_export_plugin:
		remove_export_plugin(layout_export_plugin)
		layout_export_plugin = null

	if layout_panel:
		remove_control_from_bottom_panel(layout_panel)
		layout_panel.queue_free()
		layout_panel = null


func _disable_plugin() -> void:
	if ProjectSettings.get_setting("autoload/%s" % CARD_GLOBAL, "") == "*" + CARD_GLOBAL_FILE_PATH:
		remove_autoload_singleton(CARD_GLOBAL)
		ProjectSettings.save()
