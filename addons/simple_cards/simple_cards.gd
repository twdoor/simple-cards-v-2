@tool
extends EditorPlugin

const CARD_GLOBAL = "CG"
const CARD_GLOBAL_FILE_PATH = "res://addons/simple_cards/card_global.gd"

const DEFAULT_LAYOUT_PATH = "res://addons/simple_cards/card/card_layout/default_card_layout.tscn"

var create_layout_dialog: ConfirmationDialog
var layout_name_input: LineEdit
var layout_tags_input: LineEdit
var layout_location_path: LineEdit
var create_button: Button
var error_label: Label

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
	create_layout_dialog.size = Vector2i(500, 280)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var name_label = Label.new()
	name_label.text = "Layout ID: (required)"
	vbox.add_child(name_label)
	layout_name_input = LineEdit.new()
	layout_name_input.placeholder_text = "my_custom_layout"
	layout_name_input.text = "my_custom_layout"
	vbox.add_child(layout_name_input)
	
	var tags_label = Label.new()
	tags_label.text = "Tags (optional, comma-separated):"
	vbox.add_child(tags_label)
	layout_tags_input = LineEdit.new()
	layout_tags_input.placeholder_text = "poker, dark, games"
	vbox.add_child(layout_tags_input)
	
	var location_label = Label.new()
	location_label.text = "Save Scene As:"
	vbox.add_child(location_label)
	
	var location_hbox = HBoxContainer.new()
	location_hbox.add_theme_constant_override("separation", 5)
	
	layout_location_path = LineEdit.new()
	layout_location_path.placeholder_text = "res://my_layout.tscn"
	layout_location_path.text = ""
	layout_location_path.editable = true
	layout_location_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location_hbox.add_child(layout_location_path)
	
	var browse_button = Button.new()
	browse_button.text = "Browse..."
	browse_button.pressed.connect(_on_browse_location)
	location_hbox.add_child(browse_button)
	vbox.add_child(location_hbox)
	
	create_layout_dialog.add_child(vbox)
	create_layout_dialog.confirmed.connect(_on_dialog_confirmed)
	
	create_button = create_layout_dialog.get_ok_button()
	create_button.text = "Create"
	
	error_label = Label.new()
	error_label.add_theme_color_override("font_color", Color.INDIAN_RED)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(error_label)
	_update_error_label()
	
	layout_name_input.text_changed.connect(_on_input_changed)
	layout_tags_input.text_changed.connect(_on_input_changed)
	layout_location_path.text_changed.connect(_on_input_changed)
	
	get_editor_interface().get_base_control().add_child(create_layout_dialog)


func _on_input_changed(_text: String = "") -> void:
	_update_error_label()


func _update_error_label() -> void:
	var layout_id = layout_name_input.text.strip_edges()
	var new_layout_path = layout_location_path.text.strip_edges()
	var error_msg = ""
	
	if layout_id.is_empty():
		error_msg = "Layout ID cannot be empty"
	elif not layout_id.is_valid_identifier():
		error_msg = "Layout ID must be alphanumeric with underscores only"
	elif _layout_id_exists_in_project(layout_id):
		error_msg = "Layout ID '%s' already exists in the project" % layout_id
	
	if error_msg.is_empty() and new_layout_path.is_empty():
		error_msg = "Please select a save location"
	elif error_msg.is_empty() and FileAccess.file_exists(new_layout_path):
		error_msg = "File '%s' already exists" % new_layout_path.get_file()
	
	if error_msg.is_empty():
		error_label.text = ""
		create_button.disabled = false
	else:
		error_label.text = error_msg
		create_button.disabled = true


func _on_create_layout_pressed():
	create_layout_dialog.popup_centered()
	layout_name_input.grab_focus()
	layout_name_input.select_all()


func _on_browse_location() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.title = "Save Layout Scene As"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.current_dir = "res://"
	file_dialog.exclusive = false  # Don't make it modal
	file_dialog.add_filter("*.tscn ; Scene Files")
	
	var default_name = layout_name_input.text.strip_edges()
	if default_name.is_empty():
		default_name = "new_layout"
	default_name = default_name.to_lower().replace(" ", "_")
	file_dialog.current_file = default_name + ".tscn"
	
	var callback = func(path: String):
		var final_path = path
		if not final_path.ends_with(".tscn"):
			final_path += ".tscn"
		
		layout_location_path.text = final_path
		_update_error_label()
		file_dialog.queue_free()
	
	file_dialog.file_selected.connect(callback)
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)
	
	get_editor_interface().get_base_control().add_child(file_dialog)
	await get_tree().process_frame
	file_dialog.popup_centered_ratio(0.6)


func _on_dialog_confirmed():
	var layout_id = layout_name_input.text.strip_edges()
	var layout_tags_str = layout_tags_input.text.strip_edges()
	var new_layout_path = layout_location_path.text.strip_edges()
	
	if layout_id.is_empty():
		push_error("Layout ID cannot be empty")
		return
	
	if not layout_id.is_valid_identifier():
		push_error("Layout ID must be a valid identifier (alphanumeric, underscore)")
		return
	
	if new_layout_path.is_empty():
		push_error("Please select a save location")
		return
	
	if not new_layout_path.ends_with(".tscn"):
		new_layout_path += ".tscn"
	
	var tags: Array[String] = []
	if not layout_tags_str.is_empty():
		for tag in layout_tags_str.split(","):
			var cleaned_tag = tag.strip_edges()
			if not cleaned_tag.is_empty():
				tags.append(cleaned_tag)
	
	if FileAccess.file_exists(new_layout_path):
		var error_dialog = AcceptDialog.new()
		error_dialog.title = "File Already Exists"
		error_dialog.dialog_text = "The file '%s' already exists.\n\nOpening existing file." % new_layout_path.get_file()
		get_editor_interface().get_base_control().add_child(error_dialog)
		error_dialog.popup_centered_ratio(0.4)
		
		await error_dialog.confirmed
		error_dialog.queue_free()
		
		_open_scene(new_layout_path)
		return
	
	if _layout_id_exists_in_project(layout_id):
		push_error("Layout ID '%s' already exists in the project. Please use a different ID." % layout_id)
		return
	
	if not FileAccess.file_exists(DEFAULT_LAYOUT_PATH):
		push_error("Default layout not found at: " + DEFAULT_LAYOUT_PATH)
		return
	
	var err = DirAccess.copy_absolute(DEFAULT_LAYOUT_PATH, new_layout_path)
	if err != OK:
		push_error("Failed to copy layout: " + error_string(err))
		return
	
	_clear_scene_uid(new_layout_path)
	_add_metadata_to_scene(new_layout_path, layout_id, tags)
	
	print("Created new card layout: " + new_layout_path)
	
	get_editor_interface().get_resource_filesystem().scan()
	
	await get_tree().process_frame
	_open_scene(new_layout_path)


##Clear the UID from a scene file to avoid duplicates
func _clear_scene_uid(scene_path: String) -> void:
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return
	
	var content = file.get_as_text()
	var lines = content.split("\n")
	
	for i in range(lines.size()):
		if lines[i].contains("[gd_scene"):
			var line = lines[i]
			var uid_start = line.find("uid=")
			if uid_start != -1:
				var uid_end = line.find("\"", uid_start + 5)
				if uid_end != -1:
					lines[i] = line.substr(0, uid_start) + line.substr(uid_end + 1)
					lines[i] = lines[i].replace("  ", " ").strip_edges()
			break
	
	var output = FileAccess.open(scene_path, FileAccess.WRITE)
	if output != null:
		output.store_string("\n".join(lines))


##Check if a layout_id already exists anywhere in the project
func _layout_id_exists_in_project(layout_id: String) -> bool:
	return _scan_for_layout_id_recursive("res://", layout_id)


##Recursively scan the project for a layout_id
func _scan_for_layout_id_recursive(path: String, layout_id: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return false
	
	var dir = DirAccess.open(path)
	if not dir:
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + file_name
		if dir.current_is_dir():
			if not file_name.begins_with(".") and file_name != "addons":
				if _scan_for_layout_id_recursive(full_path + "/", layout_id):
					dir.list_dir_end()
					return true
		
		elif file_name.ends_with(".tscn"):
			var scene = load(full_path)
			if scene and scene.can_instantiate():
				var instance = scene.instantiate()
				if instance.has_meta("is_layout"):
					var existing_id = instance.get_meta("layout_id", "")
					if existing_id == layout_id:
						instance.queue_free()
						dir.list_dir_end()
						return true
				instance.queue_free()
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return false


##Add metadata to .tscn file as node properties
func _add_metadata_to_scene(scene_path: String, layout_id: String, tags: Array[String]) -> void:
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		push_error("Failed to read: " + scene_path)
		return
	
	var content = file.get_as_text()
	var lines = content.split("\n")
	var node_line_idx = -1
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		if line.begins_with("[node"):
			node_line_idx = i
			break
	
	if node_line_idx == -1:
		push_error("Could not find root node in: " + scene_path)
		return
	
	var insert_idx = node_line_idx + 1
	
	var metadata_lines = []
	metadata_lines.append("metadata/is_layout = true")
	metadata_lines.append("metadata/layout_id = \"%s\"" % layout_id)
	
	if not tags.is_empty():
		var tags_str = ", ".join(tags.map(func(tag): return "\"%s\"" % tag))
		metadata_lines.append("metadata/tags = [%s]" % tags_str)
	else:
		metadata_lines.append("metadata/tags = []")
	
	for i in range(metadata_lines.size()):
		lines.insert(insert_idx + i, metadata_lines[i])
	
	var output = FileAccess.open(scene_path, FileAccess.WRITE)
	if output == null:
		push_error("Failed to write: " + scene_path)
		return
	
	output.store_string("\n".join(lines))
	print("Added metadata to: " + scene_path)


func _open_scene(scene_path: String):
	get_editor_interface().open_scene_from_path(scene_path)
	print("Opened scene: " + scene_path)
