@tool
class_name LayoutCache extends RefCounted

const CACHE_PATH = "res://addons/simple_cards/editor/layout_cache.json"
const LAYOUTS_ENUM_PATH = "res://addons/simple_cards/layout_ids.gd"
const DEFAULT_LAYOUT_PATH = "res://addons/simple_cards/card/card_layout/default_card_layout.tscn"
const DEFAULT_BACK_LAYOUT_PATH = "res://addons/simple_cards/card/card_layout/default_card_back_layout.tscn"

signal cache_updated


## Structure: { "path": { "layout_id": String, "tags": Array, "enabled": bool, "last_modified": int } }
var layouts: Dictionary = {}


func _init() -> void:
	load_cache()


#region Cache Persistence

func load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		layouts = {}
		return
	
	var file = FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			layouts = json.data
		else:
			push_warning("LayoutCache: Failed to parse cache, starting fresh")
			layouts = {}
	else:
		layouts = {}


func save_cache() -> void:
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(layouts, "\t"))
	
	_generate_layout_ids_file()

#endregion


#region Layout IDs Generation

func _generate_layout_ids_file() -> void:
	var lines: Array[String] = []
	
	lines.append("# AUTO-GENERATED FILE - DO NOT EDIT MANUALLY")
	lines.append("# This file is regenerated when layouts are modified in the Card Layouts panel")
	lines.append("")
	lines.append("class_name LayoutID")
	lines.append("")
	
	# Collect all enabled layout IDs
	var ids: Array[String] = []
	for path in layouts.keys():
		var data = layouts[path]
		if data.get("enabled", true):
			var layout_id: String = data.layout_id
			if not layout_id.is_empty() and layout_id not in ids:
				ids.append(layout_id)
	
	ids.sort()
	
	# Generate constants
	for id in ids:
		var const_name = id.to_upper()
		lines.append('const %s: StringName = &"%s"' % [const_name, id])
	
	lines.append("")
	lines.append("")
	lines.append("## Returns all available layout IDs")
	lines.append("static func get_all() -> Array[StringName]:")
	lines.append("\treturn [")
	for i in range(ids.size()):
		var comma = "," if i < ids.size() - 1 else ""
		lines.append("\t\t%s%s" % [ids[i].to_upper(), comma])
	lines.append("\t]")
	
	lines.append("")
	lines.append("")
	lines.append("## Check if a layout ID is valid")
	lines.append("static func is_valid(id: StringName) -> bool:")
	lines.append("\treturn id in get_all()")
	
	# Write file
	var file = FileAccess.open(LAYOUTS_ENUM_PATH, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))
		print("LayoutCache: Generated %s with %d layouts" % [LAYOUTS_ENUM_PATH, ids.size()])
	else:
		push_error("LayoutCache: Failed to write layout IDs file")

#endregion


#region Scanning

## Full project scan - finds all layouts by parsing .tscn files
func scan_project() -> void:
	print("LayoutCache: Scanning project for layouts...")
	
	var found_paths: Array[String] = []
	_scan_directory_recursive("res://", found_paths)
	
	# Remove layouts that no longer exist on disk
	var paths_to_remove: Array[String] = []
	for path in layouts.keys():
		if not FileAccess.file_exists(path):
			paths_to_remove.append(path)
		elif path not in found_paths and not _is_default_layout(path):
			# Scene exists but is no longer a layout (metadata removed)
			paths_to_remove.append(path)
	
	for path in paths_to_remove:
		layouts.erase(path)
	
	# Ensure defaults exist
	_ensure_default_layouts()
	
	save_cache()
	cache_updated.emit()
	print("LayoutCache: Found %d layouts" % layouts.size())


func _scan_directory_recursive(path: String, found_paths: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	
	var dir = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + file_name
		
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_directory_recursive(full_path + "/", found_paths)
		
		elif file_name.ends_with(".tscn"):
			var layout_info = _parse_scene_file(full_path)
			if not layout_info.is_empty():
				found_paths.append(full_path)
				_update_layout_entry(full_path, layout_info)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


## Parse a .tscn file as text to extract metadata without instantiation
func _parse_scene_file(scene_path: String) -> Dictionary:
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		return {}
	
	var content = file.get_as_text()
	
	# Check for is_layout metadata
	if not "metadata/is_layout = true" in content:
		return {}
	
	var result = {
		"layout_id": "",
		"tags": [],
		"last_modified": FileAccess.get_modified_time(scene_path)
	}
	
	# Extract layout_id
	var id_regex = RegEx.new()
	id_regex.compile('metadata/layout_id\\s*=\\s*"([^"]*)"')
	var id_match = id_regex.search(content)
	if id_match:
		result.layout_id = id_match.get_string(1)
	
	# Extract tags
	var tags_regex = RegEx.new()
	tags_regex.compile('metadata/tags\\s*=\\s*\\[([^\\]]*)\\]')
	var tags_match = tags_regex.search(content)
	if tags_match:
		var tags_str = tags_match.get_string(1)
		# Parse individual tags from the array string
		var tag_regex = RegEx.new()
		tag_regex.compile('"([^"]*)"')
		var tag_matches = tag_regex.search_all(tags_str)
		for tag_match in tag_matches:
			result.tags.append(tag_match.get_string(1))
	
	return result


func _update_layout_entry(path: String, info: Dictionary) -> void:
	if path in layouts:
		# Preserve enabled state, update rest
		var was_enabled = layouts[path].get("enabled", true)
		layouts[path] = {
			"layout_id": info.layout_id,
			"tags": info.tags,
			"enabled": was_enabled,
			"last_modified": info.last_modified
		}
	else:
		# New layout
		layouts[path] = {
			"layout_id": info.layout_id,
			"tags": info.tags,
			"enabled": true,
			"last_modified": info.last_modified
		}


func _ensure_default_layouts() -> void:
	if DEFAULT_LAYOUT_PATH not in layouts:
		layouts[DEFAULT_LAYOUT_PATH] = {
			"layout_id": "default",
			"tags": [],
			"enabled": true,
			"last_modified": 0
		}
	
	if DEFAULT_BACK_LAYOUT_PATH not in layouts:
		layouts[DEFAULT_BACK_LAYOUT_PATH] = {
			"layout_id": "default_back",
			"tags": [],
			"enabled": true,
			"last_modified": 0
		}


func _is_default_layout(path: String) -> bool:
	return path == DEFAULT_LAYOUT_PATH or path == DEFAULT_BACK_LAYOUT_PATH

#endregion


#region Layout Management

func get_all_layouts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in layouts.keys():
		var info = layouts[path].duplicate()
		info["path"] = path
		result.append(info)
	return result


func get_enabled_layouts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in layouts.keys():
		if layouts[path].get("enabled", true):
			var info = layouts[path].duplicate()
			info["path"] = path
			result.append(info)
	return result


func set_layout_enabled(path: String, enabled: bool) -> void:
	if path in layouts:
		layouts[path].enabled = enabled
		save_cache()
		cache_updated.emit()


func set_layout_id(path: String, new_id: String) -> bool:
	if path not in layouts:
		return false
	
	for other_path in layouts.keys():
		if other_path != path and layouts[other_path].layout_id == new_id:
			push_error("LayoutCache: Layout ID '%s' already exists" % new_id)
			return false
	
	layouts[path].layout_id = new_id
	_write_metadata_to_scene(path)
	save_cache()
	cache_updated.emit()
	return true


func set_layout_tags(path: String, new_tags: Array) -> void:
	if path not in layouts:
		return
	
	layouts[path].tags = new_tags
	_write_metadata_to_scene(path)
	save_cache()
	cache_updated.emit()


func delete_layout(path: String) -> bool:
	if _is_default_layout(path):
		push_error("LayoutCache: Cannot delete default layouts")
		return false
	
	if path not in layouts:
		push_error("LayoutCache: Layout not found: %s" % path)
		return false
	
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(path)
		if err != OK:
			push_error("LayoutCache: Failed to delete file: %s (%s)" % [path, error_string(err)])
			return false
	
	layouts.erase(path)
	save_cache()
	cache_updated.emit()
	
	print("LayoutCache: Deleted layout at %s" % path)
	return true


func _write_metadata_to_scene(scene_path: String) -> void:
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		push_error("LayoutCache: Cannot read scene file: %s" % scene_path)
		return
	
	var content = file.get_as_text()
	file = null
	
	var layout_data = layouts[scene_path]
	
	
	var id_regex = RegEx.new()
	id_regex.compile('(metadata/layout_id\\s*=\\s*)"[^"]*"')
	content = id_regex.sub(content, '$1"%s"' % layout_data.layout_id)
	
	
	var tags_str = "[]"
	if not layout_data.tags.is_empty():
		var quoted_tags = layout_data.tags.map(func(t): return '"%s"' % t)
		tags_str = "[%s]" % ", ".join(quoted_tags)
	
	var tags_regex = RegEx.new()
	tags_regex.compile('(metadata/tags\\s*=\\s*)\\[[^\\]]*\\]')
	content = tags_regex.sub(content, '$1%s' % tags_str)
	
	
	var out_file = FileAccess.open(scene_path, FileAccess.WRITE)
	if out_file:
		out_file.store_string(content)
	else:
		push_error("LayoutCache: Cannot write scene file: %s" % scene_path)


func layout_id_exists(layout_id: String, exclude_path: String = "") -> bool:
	for path in layouts.keys():
		if path != exclude_path and layouts[path].layout_id == layout_id:
			return true
	return false


func get_all_tags() -> Array[String]:
	var tags_set: Dictionary = {}
	for path in layouts.keys():
		for tag in layouts[path].tags:
			tags_set[tag] = true
	
	var result: Array[String] = []
	for tag in tags_set.keys():
		result.append(tag)
	result.sort()
	return result

#endregion
