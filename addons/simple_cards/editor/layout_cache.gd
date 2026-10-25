@tool
class_name LayoutCache extends RefCounted

const CACHE_PATH = "res://addons/simple_cards/editor/layout_cache.json"
const LAYOUTS_ENUM_PATH = "res://addons/simple_cards/layout_ids.gd"
const DEFAULT_LAYOUT_PATH = "res://addons/simple_cards/card/card_layout/default_card_layout.tscn"
const DEFAULT_BACK_LAYOUT_PATH = "res://addons/simple_cards/card/card_layout/default_card_back_layout.tscn"
const DEBUG_LOG: bool = false

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
		if error == OK and json.data is Dictionary:
			layouts = json.data
			for path in layouts.keys():
				var message := LayoutValidation.entry_error(str(path), layouts[path])
				if not message.is_empty():
					push_warning("LayoutCache: %s: %s" % [path, message])
					layouts.erase(path)
		else:
			push_warning("LayoutCache: Failed to parse cache, starting fresh")
			layouts = {}
	else:
		layouts = {}


func save_cache() -> void:
	var problems := LayoutValidation.errors(layouts)
	if not problems.is_empty():
		push_warning("LayoutCache: Fix layout metadata before saving:\n" + "\n".join(problems))
		return
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_sorted_layouts(), "\t"))
	
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
	
	var ids: Array[String] = []
	for path in layouts.keys():
		var data = layouts[path]
		if data.get("enabled", true):
			var layout_id: String = data.layout_id
			if not layout_id.is_empty() and layout_id not in ids:
				ids.append(layout_id)
	
	ids.sort()

	var const_names: Dictionary = {}
	var emitted_const_names: Array[String] = []
	
	for id in ids:
		var const_name = _layout_id_to_const_name(id)
		if const_name in const_names:
			push_error("LayoutCache: Layout IDs '%s' and '%s' both generate constant '%s'" % [const_names[const_name], id, const_name])
			continue
		const_names[const_name] = id
		emitted_const_names.append(const_name)
		lines.append('const %s: StringName = &"%s"' % [const_name, id])
	
	lines.append("")
	lines.append("")
	lines.append("## Returns all available layout IDs")
	lines.append("static func get_all() -> Array[StringName]:")
	lines.append("\treturn [")
	for i in range(emitted_const_names.size()):
		var comma = "," if i < emitted_const_names.size() - 1 else ""
		lines.append("\t\t%s%s" % [emitted_const_names[i], comma])
	lines.append("\t]")
	
	lines.append("")
	lines.append("")
	lines.append("## Check if a layout ID is valid")
	lines.append("static func is_valid(id: StringName) -> bool:")
	lines.append("\treturn id in get_all()")
	
	# Avoid needless script reloads when startup scanning changes no IDs.
	var content := "\n".join(lines)
	if FileAccess.file_exists(LAYOUTS_ENUM_PATH) and FileAccess.get_file_as_string(LAYOUTS_ENUM_PATH) == content:
		return
	var file = FileAccess.open(LAYOUTS_ENUM_PATH, FileAccess.WRITE)
	if file:
		file.store_string(content)
		if DEBUG_LOG: print("LayoutCache: Generated %s with %d layouts" % [LAYOUTS_ENUM_PATH, ids.size()])
	else:
		push_error("LayoutCache: Failed to write layout IDs file")

#endregion


#region Scanning

## Non-destructive startup sync: removes only entries whose files are deleted from disk, and adds any new layouts found.
func sync_cache() -> void:
	if DEBUG_LOG: print("LayoutCache: Syncing cache...")
	
	var paths_to_remove: Array[String] = []
	for path in layouts.keys():
		if not FileAccess.file_exists(path):
			paths_to_remove.append(path)
	
	for path in paths_to_remove:
		layouts.erase(path)
	
	var found_paths: Array[String] = []
	_scan_directory_recursive("res://", found_paths)
	
	_ensure_default_layouts()
	
	save_cache()
	cache_updated.emit()
	if DEBUG_LOG: print("LayoutCache: %d layouts after sync" % layouts.size())


## Full project rescan — finds all layouts and removes entries whose files exist but no longer carry layout metadata.  Only call this from an explicit user action (e.g. the Refresh button), never on startup.
func scan_project() -> void:
	if DEBUG_LOG: print("LayoutCache: Scanning project for layouts...")
	
	var found_paths: Array[String] = []
	_scan_directory_recursive("res://", found_paths)
	
	var paths_to_remove: Array[String] = []
	for path in layouts.keys():
		if not FileAccess.file_exists(path):
			paths_to_remove.append(path)
		elif path not in found_paths and not _is_default_layout(path):
			paths_to_remove.append(path)
	
	for path in paths_to_remove:
		layouts.erase(path)
	
	_ensure_default_layouts()
	
	save_cache()
	cache_updated.emit()
	if DEBUG_LOG: print("LayoutCache: Found %d layouts" % layouts.size())


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
			var mod_time = FileAccess.get_modified_time(full_path)
			var cached = layouts.get(full_path, {})
			var cached_time = cached.get("last_modified", -1)

			if full_path in layouts and mod_time == cached_time:
				found_paths.append(full_path)
			else:
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
	
	var content := _root_section(file.get_as_text())
	var is_layout := false
	var result := {
		"layout_id": "",
		"tags": [],
		"last_modified": FileAccess.get_modified_time(scene_path)
	}
	for line in content.split("\n"):
		var assignment := line.split("=", true, 1)
		if assignment.size() != 2:
			continue
		match assignment[0].strip_edges():
			"metadata/is_layout":
				is_layout = assignment[1].strip_edges() == "true"
			"metadata/layout_id":
				var value = str_to_var(assignment[1])
				if value is String:
					result.layout_id = value
			"metadata/tags":
				var value = str_to_var(assignment[1])
				if value is Array:
					for tag in value:
						if tag is String:
							result.tags.append(tag)
	return result if is_layout else {}



func _update_layout_entry(path: String, info: Dictionary) -> void:
	if path in layouts:
		var was_enabled = layouts[path].get("enabled", true)
		layouts[path] = {
			"layout_id": _normalize_layout_id(info.layout_id),
			"tags": _normalize_tags(info.tags),
			"enabled": was_enabled,
			"last_modified": info.last_modified
		}
	else:
		# New layout
		layouts[path] = {
			"layout_id": _normalize_layout_id(info.layout_id),
			"tags": _normalize_tags(info.tags),
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
	for path in _get_sorted_paths():
		var info = layouts[path].duplicate()
		info["path"] = path
		result.append(info)
	return result


func get_enabled_layouts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in _get_sorted_paths():
		if layouts[path].get("enabled", true):
			var info = layouts[path].duplicate()
			info["path"] = path
			result.append(info)
	return result


func get_enabled_layout_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for layout in get_enabled_layouts():
		var layout_id := String(layout.get("layout_id", ""))
		if not layout_id.is_empty():
			result.append(StringName(layout_id))
	return result


func has_layout(layout_id: StringName, include_disabled: bool = false) -> bool:
	if layout_id.is_empty():
		return false
	return not _find_layout_path(str(layout_id), include_disabled).is_empty()


func get_layout_path(layout_id: StringName, fallback_id: StringName = &"", include_disabled: bool = false) -> String:
	var requested := str(layout_id)
	if not requested.is_empty():
		var path := _find_layout_path(requested, include_disabled)
		if not path.is_empty():
			return path

	var fallback := str(fallback_id)
	if not fallback.is_empty():
		var fallback_path := _find_layout_path(fallback, include_disabled)
		if not fallback_path.is_empty():
			return fallback_path
		if fallback == str(LayoutID.DEFAULT_BACK) and ResourceLoader.exists(DEFAULT_BACK_LAYOUT_PATH):
			return DEFAULT_BACK_LAYOUT_PATH

	if ResourceLoader.exists(DEFAULT_LAYOUT_PATH):
		return DEFAULT_LAYOUT_PATH
	return ""


func get_layout_info(layout_id: StringName, include_disabled: bool = false) -> Dictionary:
	var path := _find_layout_path(str(layout_id), include_disabled)
	if path.is_empty() or path not in layouts:
		return {}
	var info: Dictionary = layouts[path].duplicate()
	info["path"] = path
	return info


func set_layout_enabled(path: String, enabled: bool) -> void:
	if path in layouts:
		layouts[path].enabled = enabled
		save_cache()
		cache_updated.emit()


func set_layout_id(path: String, new_id: String) -> bool:
	if path not in layouts:
		return false

	new_id = _normalize_layout_id(new_id)
	var message := LayoutValidation.id_error(new_id, layouts, path)
	if not message.is_empty():
		push_error("LayoutCache: " + message)
		return false

	layouts[path].layout_id = new_id
	_write_metadata_to_scene(path)
	save_cache()
	cache_updated.emit()
	return true


func set_layout_tags(path: String, new_tags: Array) -> void:
	if path not in layouts:
		return
	
	layouts[path].tags = _normalize_tags(new_tags)
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
	
	if DEBUG_LOG: print("LayoutCache: Deleted layout at %s" % path)
	return true


func _write_metadata_to_scene(scene_path: String) -> void:
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		push_error("LayoutCache: Cannot read scene file: %s" % scene_path)
		return
	
	var content = file.get_as_text()
	file = null
	
	var layout_data = layouts[scene_path]
	
	
	var metadata: Dictionary = {
		"is_layout": true,
		"layout_id": _normalize_layout_id(layout_data.layout_id),
		"tags": _normalize_tags(layout_data.tags)
	}
	layout_data.layout_id = metadata.layout_id
	layout_data.tags = metadata.tags
	content = _upsert_layout_metadata(content, metadata)

	var out_file = FileAccess.open(scene_path, FileAccess.WRITE)
	if out_file:
		out_file.store_string(content)
		layouts[scene_path].last_modified = FileAccess.get_modified_time(scene_path)
	else:
		push_error("LayoutCache: Cannot write scene file: %s" % scene_path)


func _root_section(content: String) -> String:
	var start := content.find("[node ")
	if start < 0:
		return ""
	var end := content.find("\n[", start)
	return content.substr(start, end - start) if end >= 0 else content.substr(start)


func _upsert_layout_metadata(content: String, metadata: Dictionary) -> String:
	var root := _root_section(content)
	if root.is_empty():
		return content
	return content.replace(root, _upsert_root_metadata(root, metadata))


func _upsert_root_metadata(content: String, metadata: Dictionary) -> String:
	var values := {
		"metadata/layout_id": JSON.stringify(String(metadata.layout_id)),
		"metadata/tags": JSON.stringify(metadata.tags),
		"metadata/is_layout": "true"
	}
	var lines := content.split("\n")
	for i in lines.size():
		var key := lines[i].get_slice("=", 0).strip_edges()
		if key in values:
			lines[i] = "%s = %s" % [key, values[key]]
			values.erase(key)
	for key in values:
		lines.insert(1, "%s = %s" % [key, values[key]])
	return "\n".join(lines)



func _normalize_layout_id(layout_id: String) -> String:
	return layout_id.strip_edges()


func _normalize_tags(tags: Array) -> Array[String]:
	var result: Array[String] = []
	for tag in tags:
		var cleaned := String(tag).strip_edges()
		if cleaned.is_empty(): continue
		if cleaned in result: continue
		result.append(cleaned)
	result.sort()
	return result


func _layout_id_to_const_name(layout_id: String) -> String:
	return LayoutValidation.constant_name(layout_id)


func _find_layout_path(layout_id: String, include_disabled: bool = false) -> String:
	for path in _get_sorted_paths():
		var data: Dictionary = layouts[path]
		if data.get("layout_id", "") != layout_id:
			continue
		if not include_disabled and not data.get("enabled", true):
			continue
		return path
	return ""


func _get_sorted_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in layouts.keys():
		paths.append(path)
	paths.sort_custom(func(a: String, b: String) -> bool:
		var a_id := String(layouts[a].get("layout_id", ""))
		var b_id := String(layouts[b].get("layout_id", ""))
		if a_id == b_id:
			return a < b
		return a_id < b_id
	)
	return paths


func _sorted_layouts() -> Dictionary:
	var result := {}
	for path in _get_sorted_paths():
		result[path] = layouts[path]
	return result


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
