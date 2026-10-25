@tool
extends Control

var editor_interface: EditorInterface

var cache: LayoutCache
var layout_list: VBoxContainer
var layout_scroll: ScrollContainer
var search_box: LineEdit
var tag_filter: OptionButton
var validation_label: Label
var refresh_button: Button
var create_button: Button
var details_panel: VBoxContainer
var layout_split: SplitContainer
var details_scroll: ScrollContainer
var details_content: BoxContainer
var empty_details: Label
var empty_list: Label
var _editor_scale: float = 1.0

var id_edit: LineEdit
var tags_edit: LineEdit
var path_label: Label
var delete_button: Button

var preview_texture: TextureRect
var _preview_cache: Dictionary = {}

var selected_path: String = ""
var selected_item: Control = null

var create_dialog: ConfirmationDialog
var create_id_input: LineEdit
var create_tags_input: LineEdit
var create_path_input: LineEdit
var create_error_label: Label
var create_type_picker: OptionButton
var create_type_description: Label
var _layout_types: Array[Dictionary] = []
var _preview_pending: Dictionary = {}

var delete_dialog: ConfirmationDialog

var open_icon: Texture2D
var delete_icon: Texture2D
var refresh_icon: Texture2D
var new_icon: Texture2D

func _ready() -> void:
	cache = LayoutCache.new()
	cache.cache_updated.connect(_on_cache_updated)

	if editor_interface:
		var base_control = editor_interface.get_base_control()
		open_icon = base_control.get_theme_icon("Load", "EditorIcons")
		delete_icon = base_control.get_theme_icon("Remove", "EditorIcons")
		refresh_icon = base_control.get_theme_icon("RotateRight", "EditorIcons")
		new_icon = base_control.get_theme_icon("Add", "EditorIcons")

	_build_ui()
	_build_create_dialog()
	_build_delete_dialog()
	cache.sync_cache()


func _build_ui() -> void:
	if editor_interface:
		_editor_scale = editor_interface.get_editor_scale()
	custom_minimum_size = Vector2(240, 200) * _editor_scale
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(8 * _editor_scale))

	layout_split = SplitContainer.new()
	margin.add_child(layout_split)
	var library = VBoxContainer.new()
	library.custom_minimum_size = Vector2(200, 100) * _editor_scale
	library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout_split.add_child(library)

	search_box = LineEdit.new()
	search_box.placeholder_text = "Search layouts..."
	search_box.clear_button_enabled = true
	search_box.text_changed.connect(_on_search_changed)
	library.add_child(search_box)

	var toolbar = HBoxContainer.new()
	library.add_child(toolbar)
	validation_label = Label.new()
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library.add_child(validation_label)
	tag_filter = OptionButton.new()
	tag_filter.fit_to_longest_item = false
	tag_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_filter.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tag_filter.tooltip_text = "Filter by tag"
	tag_filter.item_selected.connect(_on_tag_filter_changed)
	toolbar.add_child(tag_filter)

	refresh_button = Button.new()
	refresh_button.icon = refresh_icon
	refresh_button.tooltip_text = "Rescan project for layouts"
	refresh_button.pressed.connect(_on_refresh_pressed)
	toolbar.add_child(refresh_button)

	create_button = Button.new()
	create_button.icon = new_icon
	create_button.text = "New"
	create_button.tooltip_text = "Create a new layout"
	create_button.pressed.connect(_on_create_pressed)
	toolbar.add_child(create_button)

	layout_scroll = ScrollContainer.new()
	layout_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	library.add_child(layout_scroll)
	layout_list = VBoxContainer.new()
	layout_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_scroll.add_child(layout_list)

	empty_list = Label.new()
	empty_list.text = "No layouts match your search."
	empty_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_list.visible = false
	library.add_child(empty_list)

	var details = VBoxContainer.new()
	details.custom_minimum_size = Vector2(200, 80) * _editor_scale
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout_split.add_child(details)

	empty_details = Label.new()
	empty_details.text = "Select a layout to edit its details."
	empty_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(empty_details)

	details_scroll = ScrollContainer.new()
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(details_scroll)
	details_panel = VBoxContainer.new()
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(details_panel)
	_build_details_panel()
	_set_details_visible(false)
	resized.connect(_update_responsive_layout)
	details_scroll.resized.connect(_update_details_layout)
	_update_responsive_layout()


func _update_responsive_layout() -> void:
	var stacked := size.x < 620 * _editor_scale
	if layout_split.vertical != stacked:
		layout_split.vertical = stacked
		# Offsets from the other orientation would squash one of the panes.
		layout_split.split_offset = 0
	_update_details_layout()


func _update_details_layout() -> void:
	details_content.vertical = details_scroll.size.x < 380 * _editor_scale


func _build_details_panel() -> void:
	var title_bar = HBoxContainer.new()
	details_panel.add_child(title_bar)
	var title = Label.new()
	title.text = "Layout Details"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	delete_button = Button.new()
	delete_button.pressed.connect(_on_delete_pressed)
	delete_button.icon = delete_icon
	title_bar.add_child(delete_button)
	details_panel.add_child(HSeparator.new())

	details_content = BoxContainer.new()
	details_content.add_theme_constant_override("separation", roundi(12 * _editor_scale))
	details_panel.add_child(details_content)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", roundi(6 * _editor_scale))
	details_content.add_child(info)

	var id_title = Label.new()
	id_title.text = "Layout ID"
	info.add_child(id_title)
	id_edit = LineEdit.new()
	id_edit.tooltip_text = "Press Enter to save the layout ID"
	id_edit.text_submitted.connect(_on_id_submitted)
	info.add_child(id_edit)

	var tags_title = Label.new()
	tags_title.text = "Tags"
	info.add_child(tags_title)
	tags_edit = LineEdit.new()
	tags_edit.placeholder_text = "poker, fantasy, ..."
	tags_edit.tooltip_text = "Comma-separated tags. Press Enter to save."
	tags_edit.text_submitted.connect(_on_tags_submitted)
	info.add_child(tags_edit)

	var path_title = Label.new()
	path_title.text = "Scene"
	info.add_child(path_title)
	path_label = Label.new()
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(path_label)

	preview_texture = TextureRect.new()
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = Vector2(80, 112) * _editor_scale
	preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	details_content.add_child(preview_texture)


func _build_create_dialog() -> void:
	create_dialog = ConfirmationDialog.new()
	create_dialog.title = "Create New Card Layout"
	create_dialog.size = Vector2i(500, 420) * _editor_scale
	add_child(create_dialog)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var type_label = Label.new()
	type_label.text = "Layout type"
	vbox.add_child(type_label)
	create_type_picker = OptionButton.new()
	create_type_picker.fit_to_longest_item = false
	create_type_picker.item_selected.connect(_on_layout_type_selected)
	vbox.add_child(create_type_picker)
	create_type_description = Label.new()
	create_type_description.custom_minimum_size.x = 440 * _editor_scale
	create_type_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(create_type_description)

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
	create_tags_input.placeholder_text = "poker, tarot, style"
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
	details_scroll.visible = visible
	empty_details.visible = not visible


#region Layout List Item

func _create_layout_item(layout_data: Dictionary) -> Control:
	var path: String = layout_data.path
	var layout_id: String = layout_data.layout_id
	var enabled: bool = layout_data.get("enabled", true)
	var is_default: bool = cache._is_default_layout(path)

	var item = HBoxContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.set_meta("path", path)

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
	label_button.toggle_mode = true
	label_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label_button.tooltip_text = layout_id + "\n" + path
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
		layout_list.remove_child(child)
		child.queue_free()
	selected_item = null

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

	empty_list.visible = layout_list.get_child_count() == 0


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
	path_label.tooltip_text = path
	id_edit.text = data.layout_id
	tags_edit.text = ", ".join(data.tags)

	id_edit.editable = not is_default
	tags_edit.editable = not is_default
	delete_button.disabled = is_default
	delete_button.tooltip_text = "Default layouts cannot be deleted" if is_default else "Delete this layout"

	_request_preview(path)
	_set_details_visible(true)


func _request_preview(path: String) -> void:
	if not preview_texture:
		return
	if path in _preview_cache:
		preview_texture.texture = _preview_cache[path]
		return
	preview_texture.texture = null
	if path in _preview_pending or not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if not scene:
		return
	var instance := scene.instantiate()
	if not instance is CardLayout:
		instance.free()
		return

	# A temporary capture viewport previews both direct and viewport-backed faces.
	# It is released after capture; direct runtime layouts do not need a viewport.
	var capture := SubViewport.new()
	capture.transparent_bg = true
	capture.disable_3d = true
	capture.gui_disable_input = true
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture.size = Vector2i(80, 112)
	_preview_pending[path] = true
	add_child(capture)
	capture.add_child(instance)
	capture.size = instance.card_size
	instance.position = Vector2.ZERO
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	if is_instance_valid(capture):
		var image := capture.get_texture().get_image()
		if image and not image.is_empty():
			var texture := ImageTexture.create_from_image(image)
			_preview_cache[path] = texture
			if is_instance_valid(preview_texture) and selected_path == path:
				preview_texture.texture = texture
		capture.queue_free()
	_preview_pending.erase(path)


func _highlight_item(item: Control) -> void:
	if is_instance_valid(selected_item):
		_set_item_selected(selected_item, false)
	selected_item = item
	_set_item_selected(item, true)


func _set_item_selected(item: Control, selected: bool) -> void:
	if not is_instance_valid(item):
		return
	# Find the selection action, including rows created before a tool-script reload.
	var select_action := _on_item_selected.bind(item, str(item.get_meta("path", "")))
	for child in item.get_children():
		if child is Button and child.pressed.is_connected(select_action):
			child.toggle_mode = true
			child.set_pressed_no_signal(selected)
			return

#endregion


#region Signal Handlers

func _on_cache_updated() -> void:
	var problems := LayoutValidation.errors(cache.layouts)
	validation_label.text = "\n".join(problems)
	validation_label.visible = not problems.is_empty()
	_preview_cache.clear()
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


func _populate_layout_types() -> void:
	_layout_types.clear()
	create_type_picker.clear()
	var classes: Dictionary = {}
	for entry in ProjectSettings.get_global_class_list():
		classes[str(entry.class)] = entry
	var names: Array = classes.keys()
	names.sort()
	# Built-ins first, followed by project-defined descendants (including indirect ones).
	names.erase("CardLayout")
	names.erase("CardViewportLayout")
	names.push_front("CardViewportLayout")
	names.push_front("CardLayout")
	for type_name in names:
		var ancestor: String = type_name
		var visited: Dictionary = {}
		while ancestor != "CardLayout" and ancestor in classes and ancestor not in visited:
			visited[ancestor] = true
			ancestor = str(classes[ancestor].base)
		if ancestor != "CardLayout" or type_name not in classes:
			continue
		var script := load(str(classes[type_name].path)) as Script
		if not script or script.is_abstract() or not _has_default_constructor(script):
			continue
		_layout_types.append({"name": type_name, "path": script.resource_path})
		create_type_picker.add_item(type_name)
	if not _layout_types.is_empty():
		create_type_picker.select(0)
		_on_layout_type_selected(0)


func _has_default_constructor(script: Script) -> bool:
	var current := script
	while current:
		for method in current.get_script_method_list():
			if method.name == "_init":
				return method.args.size() <= method.default_args.size()
		current = current.get_base_script()
	return true


func _on_layout_type_selected(index: int) -> void:
	var type_name: String = _layout_types[index].name
	match type_name:
		"CardLayout":
			create_type_description.text = "Direct UI. A lightweight container for labels, artwork, and other Controls."
		"CardViewportLayout":
			create_type_description.text = "Viewport rendering with an ordered Shader Stack. Edit face visuals inside SubViewport."
		_:
			create_type_description.text = "Custom layout: %s" % _layout_types[index].path
	_validate_create_dialog()


func _on_create_pressed() -> void:
	_populate_layout_types()
	create_id_input.text = "my_custom_layout"
	create_tags_input.text = ""
	create_path_input.text = ""
	_validate_create_dialog()
	create_dialog.popup_centered(Vector2i(500, 420) * _editor_scale)
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

	if not cache.set_layout_id(selected_path, new_id):
		_populate_details(selected_path)


func _on_tags_submitted(new_tags_str: String) -> void:
	if selected_path.is_empty():
		return

	var new_tags: Array = []
	for tag in new_tags_str.split(","):
		var cleaned = tag.strip_edges()
		if not cleaned.is_empty():
			new_tags.append(cleaned)

	cache.set_layout_tags(selected_path, cache._normalize_tags(new_tags))


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

	if create_type_picker.selected < 0 or _layout_types.is_empty():
		error_msg = "No creatable layout types found"
	else:
		error_msg = LayoutValidation.id_error(layout_id, cache.layouts)

	if error_msg.is_empty() and path.is_empty():
		error_msg = "Please select a save location"
	elif error_msg.is_empty() and not path.begins_with("res://"):
		error_msg = "Path must be inside the project (res://)"
	elif error_msg.is_empty() and not path.ends_with(".tscn"):
		error_msg = "Layout scene must be a .tscn file"
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

	create_dialog.add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)


func _on_create_confirmed() -> void:
	_validate_create_dialog()
	if create_dialog.get_ok_button().disabled:
		return
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
	tags = cache._normalize_tags(tags)

	var err := _save_new_layout(_layout_types[create_type_picker.selected].path, path, layout_id, tags)
	if err != OK:
		create_error_label.text = "Could not create layout: %s" % error_string(err)
		create_dialog.popup_centered()
		return

	if editor_interface:
		editor_interface.get_resource_filesystem().scan()

	await get_tree().process_frame
	cache.scan_project()

	if editor_interface:
		editor_interface.open_scene_from_path(path)


func _save_new_layout(script_path: String, scene_path: String, layout_id: String, tags: Array[String]) -> Error:
	var script := load(script_path) as Script
	if not script or script.is_abstract() or not _has_default_constructor(script):
		return ERR_CANT_CREATE
	var prototype = script.new()
	if not prototype is CardLayout:
		if prototype is Node:
			prototype.free()
		return ERR_INVALID_DATA
	var template: PackedScene = prototype.get_layout_template()
	prototype.free()
	if not template:
		return ERR_CANT_CREATE
	var layout := LayoutValidation.instantiate_layout(template)
	if not layout:
		return ERR_INVALID_DATA
	var template_size := layout.card_size
	if layout.get_script() != script:
		layout.set_script(script)
		layout.card_size = template_size
	layout.name = "CardLayout"
	layout.set_meta("is_layout", true)
	layout.set_meta("layout_id", layout_id)
	# Keep metadata untyped so the cache's scene scanner can read its array syntax.
	var layout_tags: Array = []
	layout_tags.append_array(tags)
	layout.set_meta("tags", layout_tags)
	# Registered script classes are identified by their attached script. This
	# editor-only metadata expects a UID, not a resource path, and may be inherited
	# from a starter scene for a different type.
	layout.remove_meta("_custom_type_script")
	var packed := PackedScene.new()
	var error := packed.pack(layout)
	layout.free()
	if error != OK:
		return error
	return ResourceSaver.save(packed, scene_path)

#endregion
