@tool
extends Control

var editor_interface: EditorInterface

var cache: LayoutCache
var layout_list: VBoxContainer
var layout_scroll: ScrollContainer
var search_box: LineEdit
var tag_filter: OptionButton
var refresh_button: Button
var create_button: Button
var details_panel: VBoxContainer

var id_edit: LineEdit
var tags_edit: LineEdit
var path_label: Label
var delete_button: Button

var selected_path: String = ""
var selected_item: Control = null

var create_dialog: ConfirmationDialog
var create_id_input: LineEdit
var create_tags_input: LineEdit
var create_path_input: LineEdit
var create_error_label: Label

var delete_dialog: ConfirmationDialog

var open_icon: Texture2D
var delete_icon: Texture2D


func _ready() -> void:
	cache = LayoutCache.new()
	cache.cache_updated.connect(_on_cache_updated)
	
	if editor_interface:
		var base_control = editor_interface.get_base_control()
		open_icon = base_control.get_theme_icon("Load", "EditorIcons")
		delete_icon = base_control.get_theme_icon("Remove", "EditorIcons")
	
	_build_ui()
	_build_create_dialog()
	_build_delete_dialog()
	cache.scan_project()


func _build_ui() -> void:
	var hsplit = HSplitContainer.new()
	hsplit.anchor_right = 1.0
	hsplit.anchor_bottom = 1.0
	add_child(hsplit)
	
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 350
	hsplit.add_child(left_panel)
	
	var toolbar = HBoxContainer.new()
	left_panel.add_child(toolbar)
	
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search layouts..."
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.text_changed.connect(_on_search_changed)
	toolbar.add_child(search_box)
	
	tag_filter = OptionButton.new()
	tag_filter.custom_minimum_size.x = 100
	tag_filter.item_selected.connect(_on_tag_filter_changed)
	toolbar.add_child(tag_filter)
	
	refresh_button = Button.new()
	refresh_button.text = "↻"
	refresh_button.tooltip_text = "Rescan project for layouts"
	refresh_button.pressed.connect(_on_refresh_pressed)
	toolbar.add_child(refresh_button)
	
	create_button = Button.new()
	create_button.text = "New"
	create_button.pressed.connect(_on_create_pressed)
	toolbar.add_child(create_button)
	
	layout_scroll = ScrollContainer.new()
	layout_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(layout_scroll)
	
	layout_list = VBoxContainer.new()
	layout_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_scroll.add_child(layout_list)
	
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(right_scroll)
	
	details_panel = VBoxContainer.new()
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(details_panel)
	
	_build_details_panel()
	_set_details_visible(false)


func _build_details_panel() -> void:
	var title = Label.new()
	title.text = "Layout Details"
	title.add_theme_font_size_override("font_size", 18)
	details_panel.add_child(title)
	
	details_panel.add_child(HSeparator.new())
	
	var path_section = VBoxContainer.new()
	details_panel.add_child(path_section)
	var path_title = Label.new()
	path_title.text = "Path:"
	path_section.add_child(path_title)
	path_label = Label.new()
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	path_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	path_section.add_child(path_label)
	
	details_panel.add_child(HSeparator.new())
	
	var id_section = VBoxContainer.new()
	details_panel.add_child(id_section)
	var id_title = Label.new()
	id_title.text = "Layout ID:"
	id_section.add_child(id_title)
	id_edit = LineEdit.new()
	id_edit.text_submitted.connect(_on_id_submitted)
	id_section.add_child(id_edit)
	
	var tags_section = VBoxContainer.new()
	details_panel.add_child(tags_section)
	var tags_title = Label.new()
	tags_title.text = "Tags (comma-separated):"
	tags_section.add_child(tags_title)
	tags_edit = LineEdit.new()
	tags_edit.text_submitted.connect(_on_tags_submitted)
	tags_section.add_child(tags_edit)
	
	details_panel.add_child(HSeparator.new())
	
	delete_button = Button.new()
	delete_button.text = "Delete Layout"
	delete_button.pressed.connect(_on_delete_pressed)
	if delete_icon:
		delete_button.icon = delete_icon
	details_panel.add_child(delete_button)


func _build_create_dialog() -> void:
	create_dialog = ConfirmationDialog.new()
	create_dialog.title = "Create New Card Layout"
	create_dialog.size = Vector2i(500, 280)
	add_child(create_dialog)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var id_label = Label.new()
	id_label.text = "Layout ID (required):"
	vbox.add_child(id_label)
	create_id_input = LineEdit.new()
	create_id_input.placeholder_text = "my_custom_layout"
	create_id_input.text = "my_custom_layout"
	create_id_input.text_changed.connect(_on_create_input_changed)
	vbox.add_child(create_id_input)
	
	var tags_label = Label.new()
	tags_label.text = "Tags (optional, comma-separated):"
	vbox.add_child(tags_label)
	create_tags_input = LineEdit.new()
	create_tags_input.placeholder_text = "poker, tarrot, style"
	create_tags_input.text_changed.connect(_on_create_input_changed)
	vbox.add_child(create_tags_input)
	
	var path_label_title = Label.new()
	path_label_title.text = "Save Scene As:"
	vbox.add_child(path_label_title)
	
	var path_hbox = HBoxContainer.new()
	create_path_input = LineEdit.new()
	create_path_input.placeholder_text = "res://my_layout.tscn"
	create_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_path_input.text_changed.connect(_on_create_input_changed)
	path_hbox.add_child(create_path_input)
	
	var browse_btn = Button.new()
	browse_btn.text = "Browse..."
	browse_btn.pressed.connect(_on_browse_pressed)
	path_hbox.add_child(browse_btn)
	vbox.add_child(path_hbox)
	
	create_error_label = Label.new()
	create_error_label.add_theme_color_override("font_color", Color.INDIAN_RED)
	create_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(create_error_label)
	
	create_dialog.add_child(vbox)
	create_dialog.confirmed.connect(_on_create_confirmed)
	create_dialog.get_ok_button().text = "Create"


func _build_delete_dialog() -> void:
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "Delete Layout"
	delete_dialog.dialog_text = "Are you sure you want to delete this layout?\nThis will delete the scene file from disk."
	delete_dialog.get_ok_button().text = "Delete"
	delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_dialog)


func _set_details_visible(visible: bool) -> void:
	details_panel.visible = visible


#region Layout List Item

func _create_layout_item(layout_data: Dictionary) -> Control:
	var path: String = layout_data.path
	var layout_id: String = layout_data.layout_id
	var enabled: bool = layout_data.get("enabled", true)
	var is_default: bool = cache._is_default_layout(path)
	
	var item = HBoxContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.set_meta("path", path)
	
	# Checkbox
	var checkbox = CheckBox.new()
	checkbox.button_pressed = enabled
	checkbox.tooltip_text = "Enable/disable layout for runtime"
	checkbox.toggled.connect(_on_item_enabled_toggled.bind(path))
	if is_default:
		checkbox.disabled = true
		checkbox.tooltip_text = "Default layouts cannot be disabled"
	item.add_child(checkbox)
	
	var label_button = Button.new()
	label_button.text = layout_id
	label_button.flat = true
	label_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	label_button.pressed.connect(_on_item_selected.bind(item, path))
	
	if not enabled:
		label_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	
	item.add_child(label_button)
	
	var open_btn = Button.new()
	open_btn.flat = true
	open_btn.tooltip_text = "Open scene"
	if open_icon:
		open_btn.icon = open_icon
	else:
		open_btn.text = "→"
	open_btn.pressed.connect(_on_item_open_pressed.bind(path))
	item.add_child(open_btn)
	
	return item

#endregion


#region UI Population

func _populate_layout_list() -> void:
	for child in layout_list.get_children():
		child.queue_free()
	
	var search_text = search_box.text.to_lower()
	var selected_tag = ""
	if tag_filter.selected > 0:
		selected_tag = tag_filter.get_item_text(tag_filter.selected)
	
	var all_layouts = cache.get_all_layouts()
	
	for layout in all_layouts:
		var layout_id: String = layout.layout_id
		var tags: Array = layout.tags
		var path: String = layout.path
		
		if not search_text.is_empty():
			var matches = layout_id.to_lower().contains(search_text)
			matches = matches or path.to_lower().contains(search_text)
			for tag in tags:
				if tag.to_lower().contains(search_text):
					matches = true
					break
			if not matches:
				continue
		
		if not selected_tag.is_empty() and selected_tag not in tags:
			continue
		
		var item = _create_layout_item(layout)
		layout_list.add_child(item)
		
		if path == selected_path:
			_highlight_item(item)


func _populate_tag_filter() -> void:
	var current_selection = ""
	if tag_filter.selected > 0:
		current_selection = tag_filter.get_item_text(tag_filter.selected)
	
	tag_filter.clear()
	tag_filter.add_item("All Tags")
	
	var tags = cache.get_all_tags()
	for tag in tags:
		tag_filter.add_item(tag)
	
	if not current_selection.is_empty():
		for i in range(tag_filter.item_count):
			if tag_filter.get_item_text(i) == current_selection:
				tag_filter.select(i)
				break


func _populate_details(path: String) -> void:
	var layouts = cache.layouts
	if path not in layouts:
		_set_details_visible(false)
		return
	
	var data = layouts[path]
	var is_default = cache._is_default_layout(path)
	
	path_label.text = path
	id_edit.text = data.layout_id
	tags_edit.text = ", ".join(data.tags)
	
	id_edit.editable = not is_default
	tags_edit.editable = not is_default
	delete_button.disabled = is_default
	delete_button.tooltip_text = "Default layouts cannot be deleted" if is_default else "Delete this layout"
	
	_set_details_visible(true)


func _highlight_item(item: Control) -> void:
	if selected_item and is_instance_valid(selected_item):
		selected_item.modulate = Color.WHITE
	
	selected_item = item
	if item:
		item.modulate = Color(1.2, 1.2, 1.3)

#endregion


#region Signal Handlers

func _on_cache_updated() -> void:
	_populate_tag_filter()
	_populate_layout_list()
	
	if not selected_path.is_empty():
		_populate_details(selected_path)


func _on_search_changed(_text: String) -> void:
	_populate_layout_list()


func _on_tag_filter_changed(_index: int) -> void:
	_populate_layout_list()


func _on_refresh_pressed() -> void:
	cache.scan_project()


func _on_create_pressed() -> void:
	create_id_input.text = "my_custom_layout"
	create_tags_input.text = ""
	create_path_input.text = ""
	_validate_create_dialog()
	create_dialog.popup_centered()
	create_id_input.grab_focus()
	create_id_input.select_all()


func _on_item_selected(item: Control, path: String) -> void:
	selected_path = path
	_highlight_item(item)
	_populate_details(selected_path)


func _on_item_enabled_toggled(enabled: bool, path: String) -> void:
	cache.set_layout_enabled(path, enabled)


func _on_item_open_pressed(path: String) -> void:
	if editor_interface:
		editor_interface.open_scene_from_path(path)


func _on_id_submitted(new_id: String) -> void:
	if selected_path.is_empty():
		return
	
	new_id = new_id.strip_edges()
	if new_id.is_empty():
		push_error("Layout ID cannot be empty")
		return
	
	if not new_id.is_valid_identifier():
		push_error("Layout ID must be a valid identifier")
		return
	
	if not cache.set_layout_id(selected_path, new_id):
		# Revert to original
		_populate_details(selected_path)


func _on_tags_submitted(new_tags_str: String) -> void:
	if selected_path.is_empty():
		return
	
	var new_tags: Array = []
	for tag in new_tags_str.split(","):
		var cleaned = tag.strip_edges()
		if not cleaned.is_empty():
			new_tags.append(cleaned)
	
	cache.set_layout_tags(selected_path, new_tags)


func _on_delete_pressed() -> void:
	if selected_path.is_empty():
		return
	
	if cache._is_default_layout(selected_path):
		return
	
	delete_dialog.dialog_text = "Are you sure you want to delete this layout?\n\nFile: %s\n\nThis will delete the scene file from disk." % selected_path
	delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if selected_path.is_empty():
		return
	
	cache.delete_layout(selected_path)
	
	if editor_interface:
		editor_interface.get_resource_filesystem().scan()
	
	selected_path = ""
	selected_item = null
	_set_details_visible(false)


func _on_create_input_changed(_text: String = "") -> void:
	_validate_create_dialog()


func _validate_create_dialog() -> void:
	var layout_id = create_id_input.text.strip_edges()
	var path = create_path_input.text.strip_edges()
	var error_msg = ""
	
	if layout_id.is_empty():
		error_msg = "Layout ID cannot be empty"
	elif not layout_id.is_valid_identifier():
		error_msg = "Layout ID must be alphanumeric with underscores only"
	elif cache.layout_id_exists(layout_id):
		error_msg = "Layout ID '%s' already exists" % layout_id
	
	if error_msg.is_empty() and path.is_empty():
		error_msg = "Please select a save location"
	elif error_msg.is_empty() and FileAccess.file_exists(path):
		error_msg = "File already exists: %s" % path.get_file()
	
	create_error_label.text = error_msg
	create_dialog.get_ok_button().disabled = not error_msg.is_empty()


func _on_browse_pressed() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.title = "Save Layout Scene As"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.current_dir = "res://"
	file_dialog.add_filter("*.tscn ; Scene Files")
	
	var default_name = create_id_input.text.strip_edges()
	if default_name.is_empty():
		default_name = "new_layout"
	file_dialog.current_file = default_name.to_lower().replace(" ", "_") + ".tscn"
	
	file_dialog.file_selected.connect(func(path: String):
		if not path.ends_with(".tscn"):
			path += ".tscn"
		create_path_input.text = path
		_validate_create_dialog()
		file_dialog.queue_free()
	)
	
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)
	
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)


func _on_create_confirmed() -> void:
	var layout_id = create_id_input.text.strip_edges()
	var tags_str = create_tags_input.text.strip_edges()
	var path = create_path_input.text.strip_edges()
	
	if not path.ends_with(".tscn"):
		path += ".tscn"
	
	var tags: Array[String] = []
	if not tags_str.is_empty():
		for tag in tags_str.split(","):
			var cleaned = tag.strip_edges()
			if not cleaned.is_empty():
				tags.append(cleaned)
	
	# Copy default layout
	var err = DirAccess.copy_absolute(LayoutCache.DEFAULT_LAYOUT_PATH, path)
	if err != OK:
		push_error("Failed to copy layout: %s" % error_string(err))
		return
	
	_prepare_new_scene(path, layout_id, tags)
	
	if editor_interface:
		editor_interface.get_resource_filesystem().scan()
	
	await get_tree().process_frame
	cache.scan_project()
	
	if editor_interface:
		editor_interface.open_scene_from_path(path)


func _prepare_new_scene(scene_path: String, layout_id: String, tags: Array[String]) -> void:
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		return
	
	var content = file.get_as_text()
	var lines = content.split("\n")
	
	for i in range(lines.size()):
		if "[gd_scene" in lines[i]:
			var line = lines[i]
			var uid_start = line.find("uid=")
			if uid_start != -1:
				var uid_end = line.find('"', uid_start + 5)
				if uid_end != -1:
					lines[i] = line.substr(0, uid_start) + line.substr(uid_end + 1)
					lines[i] = lines[i].replace("  ", " ").strip_edges()
			break
	
	var node_line_idx = -1
	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("[node"):
			node_line_idx = i
			break
	
	if node_line_idx != -1:
		var metadata_lines: Array[String] = []
		metadata_lines.append('metadata/is_layout = true')
		metadata_lines.append('metadata/layout_id = "%s"' % layout_id)
		
		var tags_str = "[]"
		if not tags.is_empty():
			var quoted = tags.map(func(t): return '"%s"' % t)
			tags_str = "[%s]" % ", ".join(quoted)
		metadata_lines.append('metadata/tags = %s' % tags_str)
		
		for i in range(metadata_lines.size()):
			lines.insert(node_line_idx + 1 + i, metadata_lines[i])
	
	var out_file = FileAccess.open(scene_path, FileAccess.WRITE)
	if out_file:
		out_file.store_string("\n".join(lines))

#endregion
