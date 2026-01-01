@tool
extends EditorPlugin

const CARD_GLOBAL = "CG"
const CARD_GLOBAL_FILE_PATH = "res://addons/simple_cards/card_global.gd"
const LayoutPanel = preload("res://addons/simple_cards/editor/layout_panel.gd")

var layout_panel: Control = null


func _enter_tree():
	add_autoload_singleton(CARD_GLOBAL, CARD_GLOBAL_FILE_PATH)
	
	layout_panel = LayoutPanel.new()
	layout_panel.editor_interface = get_editor_interface()
	add_control_to_bottom_panel(layout_panel, "Card Layouts")


func _exit_tree():
	remove_autoload_singleton(CARD_GLOBAL)
	
	if layout_panel:
		remove_control_from_bottom_panel(layout_panel)
		layout_panel.queue_free()
		layout_panel = null
