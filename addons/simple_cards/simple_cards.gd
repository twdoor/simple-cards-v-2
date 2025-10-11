@tool
extends EditorPlugin

const CARD_GLOBAL = "CG"
const CARD_GLOBAL_FILE_PATH = "res://addons/simple_cards/card_global.gd"

const LAYOUT_FOLDER = "res://card_layouts/"
const DEFAULT_LAYOUT_PATH = "res://addons/simple_cards/card/card_layout/default_card_layout.tscn"

var create_layout_dialog: ConfirmationDialog
var layout_name_input: LineEdit

func _enter_tree():
	add_autoload_singleton(CARD_GLOBAL, CARD_GLOBAL_FILE_PATH)
	add_tool_menu_item("Create New Card Layout", _on_create_layout_pressed)
	
	_setup_create_dialog()
	
func _exit_tree():
	remove_autoload_singleton(CARD_GLOBAL)
	remove_tool_menu_item("Create New Card Layout")
	
	if create_layout_dialog:
		create_layout_dialog.queue_free()
	
func _setup_create_dialog():
	create_layout_dialog = ConfirmationDialog.new()
	create_layout_dialog.title = "Create New Card Layout"
	create_layout_dialog.size = Vector2i(400, 150)
	
	var vbox = VBoxContainer.new()
	
	var label = Label.new()
	label.text = "Enter a name for your new card layout:"
	vbox.add_child(label)

	layout_name_input = LineEdit.new()
	layout_name_input.placeholder_text = "my_custom_layout"
	layout_name_input.text = "my_custom_layout"
	vbox.add_child(layout_name_input)
	
	create_layout_dialog.add_child(vbox)
	create_layout_dialog.confirmed.connect(_on_dialog_confirmed)
	
	get_editor_interface().get_base_control().add_child(create_layout_dialog)

func _on_create_layout_pressed():
	create_layout_dialog.popup_centered()
	layout_name_input.grab_focus()
	layout_name_input.select_all()

func _on_dialog_confirmed():
	var layout_name = layout_name_input.text.strip_edges()
	
	if layout_name.is_empty():
		push_error("Layout name cannot be empty")
		return
	
	layout_name = layout_name.to_lower().replace(" ", "_")
	layout_name = layout_name.validate_filename()
	
	if not DirAccess.dir_exists_absolute(LAYOUT_FOLDER):
		var err = DirAccess.make_dir_recursive_absolute(LAYOUT_FOLDER)
		if err != OK:
			push_error("Failed to create card_layouts folder: " + error_string(err))
			return
		print("Created card_layouts folder at: " + LAYOUT_FOLDER)
	
	var new_layout_path = LAYOUT_FOLDER + layout_name + ".tscn"
	
	if FileAccess.file_exists(new_layout_path):
		push_warning("Layout '%s' already exists. Opening existing file." % layout_name)
		_open_scene(new_layout_path)
		return

	if not FileAccess.file_exists(DEFAULT_LAYOUT_PATH):
		push_error("Default layout not found at: " + DEFAULT_LAYOUT_PATH)
		return
	
	var err = DirAccess.copy_absolute(DEFAULT_LAYOUT_PATH, new_layout_path)
	if err != OK:
		push_error("Failed to copy layout: " + error_string(err))
		return
	
	print("Created new card layout: " + new_layout_path)
	
	get_editor_interface().get_resource_filesystem().scan()

	await get_tree().process_frame
	_open_scene(new_layout_path)

func _open_scene(scene_path: String):
	get_editor_interface().open_scene_from_path(scene_path)
	print("Opened scene: " + scene_path)
