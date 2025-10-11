## Idea by u/siwoku
##
## Contributors:
##   - You don't have to select text to create a function u/newold25
##   - Consider editor settings's indentation type u/NickHatBoecker
##   - Added shortcuts (configurable in editor settings) u/NickHatBoecker

@tool
extends EditorPlugin

## Editor setting for the function shortcut
const FUNCTION_SHORTCUT: StringName = "function_shortcut"
## Editor setting for the get/set variable shortcut
const GET_SET_SHORTCUT: StringName = "get_set_shortcut"

const DEFAULT_SHORTCUT_FUNCTION = KEY_BRACKETLEFT
const DEFAULT_SHORTCUT_GET_SET = KEY_APOSTROPHE

const CALLBACK_CODE_INDEX = 1500
enum INDENTATION_TYPES { TABS, SPACES }

var script_editor: ScriptEditor
var current_popup: PopupMenu

var function_shortcut: Shortcut
var get_set_shortcut: Shortcut


func _enter_tree():
	script_editor = EditorInterface.get_script_editor()
	script_editor.connect("editor_script_changed", _on_script_changed)
	_setup_current_script()
	_init_shortcuts()


func _exit_tree():
	if script_editor and script_editor.is_connected("editor_script_changed", _on_script_changed):
		script_editor.disconnect("editor_script_changed", _on_script_changed)
	_cleanup_current_script()


func _on_script_changed(_script):
	_setup_current_script()


func _setup_current_script():
	_cleanup_current_script()
	var current_editor = script_editor.get_current_editor()
	if current_editor:
		var code_edit = _find_code_edit(current_editor)
		if code_edit:
			current_popup = _find_popup_menu(current_editor)
			if current_popup:
				current_popup.connect("about_to_popup", _on_popup_about_to_show)


func _cleanup_current_script():
	if current_popup and current_popup.is_connected("about_to_popup", _on_popup_about_to_show):
		current_popup.disconnect("about_to_popup", _on_popup_about_to_show)
	current_popup = null


func _find_code_edit(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for child in node.get_children():
		var result = _find_code_edit(child)
		if result:
			return result
	return null


func _find_popup_menu(node: Node) -> PopupMenu:
	if node is PopupMenu:
		return node
	for child in node.get_children():
		var result = _find_popup_menu(child)
		if result:
			return result
	return null


func _on_popup_about_to_show():
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return

	var code_edit = _find_code_edit(current_editor)
	if not code_edit:
		return

	var selected_text = code_edit.get_selected_text().strip_edges()

	if selected_text.is_empty():
		selected_text = _get_word_under_cursor(code_edit)

	if selected_text.is_empty():
		return

	if _should_show_create_function(code_edit, selected_text):
		current_popup.add_separator()
		var menu_text = "Create function: " + selected_text
		current_popup.add_item(menu_text, CALLBACK_CODE_INDEX)

		if current_popup.is_connected("id_pressed", _on_menu_item_pressed):
			current_popup.disconnect("id_pressed", _on_menu_item_pressed)

		current_popup.connect("id_pressed", _on_menu_item_pressed.bind(selected_text, code_edit, CALLBACK_CODE_INDEX))


func _get_word_under_cursor(code_edit: CodeEdit) -> String:
	var caret_line = code_edit.get_caret_line()
	var caret_column = code_edit.get_caret_column()
	var line_text = code_edit.get_line(caret_line)

	var start = caret_column
	while start > 0 and line_text[start - 1].is_subsequence_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"):
		start -= 1

	var end = caret_column
	while end < line_text.length() and line_text[end].is_subsequence_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"):
		end += 1

	return line_text.substr(start, end - start)


func _should_show_create_function(code_edit: CodeEdit, text: String) -> bool:
	var script_text = code_edit.text

	var regex = RegEx.new()
	regex.compile("^[a-zA-Z_][a-zA-Z0-9_]*$")
	if not regex.search(text):
		return false

	if _function_exists_anywhere(script_text, text):
		return false

	if _global_variable_exists(script_text, text):
		return false

	if _local_variable_exists_in_current_function(code_edit, text):
		return false

	if _is_in_comment(code_edit, text):
		return false

	return true


func _function_exists_anywhere(script_text: String, func_name: String) -> bool:
	var regex = RegEx.new()
	regex.compile("func\\s+" + func_name + "\\s*\\(")
	return regex.search(script_text) != null


func _global_variable_exists(script_text: String, var_name: String) -> bool:
	var lines = script_text.split("\n")
	var inside_function = false

	for i in range(lines.size()):
		var line = lines[i]
		var trimmed = line.strip_edges()

		if trimmed.begins_with("func "):
			inside_function = true
			continue

		if not inside_function:
			var regex = RegEx.new()
			regex.compile("^var\\s+" + var_name + "\\b")
			if regex.search(trimmed):
				return true
		else:
			if trimmed.is_empty():
				continue
			elif not line.begins_with("\t") and not line.begins_with(" ") and trimmed != "":
				inside_function = false
				var regex = RegEx.new()
				regex.compile("^var\\s+" + var_name + "\\b")
				if regex.search(trimmed):
					return true

	return false


func _local_variable_exists_in_current_function(code_edit: CodeEdit, var_name: String) -> bool:
	var script_text = code_edit.text
	var current_line = code_edit.get_caret_line()

	var function_start = -1
	var function_end = -1
	var lines = script_text.split("\n")

	for i in range(current_line, -1, -1):
		if i < lines.size():
			var line = lines[i].strip_edges()
			if line.begins_with("func "):
				function_start = i
				break

	if function_start == -1:
		return false

	for i in range(function_start + 1, lines.size()):
		var line = lines[i].strip_edges()
		if line.begins_with("func ") or (line != "" and not lines[i].begins_with("\t") and not lines[i].begins_with(" ")):
			function_end = i - 1
			break

	if function_end == -1:
		function_end = lines.size() - 1

	for i in range(function_start, function_end + 1):
		if i < lines.size():
			var line = lines[i].strip_edges()

			var regex = RegEx.new()
			regex.compile("^var\\s+" + var_name + "\\b")
			if regex.search(line):
				return true

			if i == function_start:
				var param_regex = RegEx.new()
				param_regex.compile("func\\s+\\w+\\s*\\([^)]*\\b" + var_name + "\\b")
				if param_regex.search(line):
					return true

	return false


func _is_in_comment(code_edit: CodeEdit, selected_text: String) -> bool:
	var caret_line = code_edit.get_caret_line()
	var line_text = code_edit.get_line(caret_line)
	var selection_start = code_edit.get_selection_from_column()

	var comment_pos = line_text.find("#")
	if comment_pos != -1 and comment_pos < selection_start:
		return true

	return false


func _on_menu_item_pressed(id: int, original_text: String, code_edit: CodeEdit, target_index: int):
	if id == target_index:
		_create_function(original_text, code_edit)


func _create_function(function_name: String, code_edit: CodeEdit):
	code_edit.deselect()

	var indentation_character: String = _get_indentation_character()
	var new_function = "\n\nfunc " + function_name + "() -> void:\n%spass" % indentation_character

	code_edit.text = code_edit.text + new_function

	var line_count = code_edit.get_line_count()
	var pass_line = line_count - 1

	code_edit.set_caret_line(pass_line)
	code_edit.set_caret_column(1)

	code_edit.select(pass_line, 1, pass_line, 5)
	code_edit.text_changed.emit()


## Process the user defined shortcuts
func _shortcut_input(event: InputEvent) -> void:
	if !event.is_pressed() || event.is_echo():
		return

	if function_shortcut.matches_event(event):
		## Function
		get_viewport().set_input_as_handled()
		var code_edit: CodeEdit = _get_code_edit()
		var function_name = _get_word_under_cursor(code_edit)
		if _should_show_create_function(code_edit, function_name):
			_create_function(function_name, code_edit)
	elif get_set_shortcut.matches_event(event):
		## Get/set variable
		get_viewport().set_input_as_handled()
		var code_edit: CodeEdit = _get_code_edit()
		var variable_name = _get_word_under_cursor(code_edit)
		_create_get_set_variable(variable_name, code_edit)


func _create_get_set_variable(variable_name: String, code_edit: CodeEdit) -> void:
	var current_line : int = code_edit.get_caret_line()
	var line_text : String = code_edit.get_line(current_line)
	var end_column : int = line_text.length()
	var indentation_character: String = _get_indentation_character()

	var code_text: String = ":\n%sget:\n%sreturn %s\n%sset(value):\n%s%s = value" % [
		indentation_character,
		indentation_character.repeat(2),
		variable_name,
		indentation_character,
		indentation_character.repeat(2),
		variable_name
	]
	code_edit.deselect()
	code_edit.insert_text(code_text, current_line, end_column)


func _get_editor_settings() -> EditorSettings:
	return EditorInterface.get_editor_settings()


## Initializes all shortcuts.
## Every shortcut can be changed while this plugin is active, which will override them.
func _init_shortcuts():
	var editor_settings: EditorSettings = _get_editor_settings()

	if !editor_settings.has_setting(_get_shortcut_path(FUNCTION_SHORTCUT)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.command_or_control_autoremap = true
		event.keycode = DEFAULT_SHORTCUT_FUNCTION

		shortcut.events = [ event ]
		editor_settings.set_setting(_get_shortcut_path(FUNCTION_SHORTCUT), shortcut)

	if !editor_settings.has_setting(_get_shortcut_path(GET_SET_SHORTCUT)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.command_or_control_autoremap = true
		event.keycode = DEFAULT_SHORTCUT_GET_SET

		shortcut.events = [ event ]
		editor_settings.set_setting(_get_shortcut_path(GET_SET_SHORTCUT), shortcut)

	function_shortcut = editor_settings.get_setting(_get_shortcut_path(FUNCTION_SHORTCUT))
	get_set_shortcut = editor_settings.get_setting(_get_shortcut_path(GET_SET_SHORTCUT))


## This is the editor window, where code lines can be selected.
func _get_code_edit() -> CodeEdit:
	return get_editor_interface().get_script_editor().get_current_editor().get_base_editor()


## Tab or spaces
func _get_indentation_character() -> String:
	var settings: EditorSettings = _get_editor_settings()

	var indentation_type = settings.get_setting("text_editor/behavior/indent/type")
	var indentation_character: String = "\t"

	if indentation_type != INDENTATION_TYPES.TABS:
		var indentation_size = settings.get_setting("text_editor/behavior/indent/size")
		indentation_character = " ".repeat(indentation_size)

	return indentation_character


func _get_shortcut_path(parameter: String) -> String:
	var script_path: String = (self.get_script() as GDScript).resource_path
	var script_path_parts: Array = script_path.split("/")
	script_path_parts.remove_at(script_path_parts.size() - 1)
	var addon_path: String = "/".join(script_path_parts)

	return "%s%s" % [addon_path, parameter]
