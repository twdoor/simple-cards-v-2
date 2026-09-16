@tool
extends EditorExportPlugin

const CACHE_PATH := "res://addons/simple_cards/editor/layout_cache.json"

func _get_name() -> String:
	return "SimpleCardsLayouts"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	# JSON is not a Godot resource and is otherwise omitted by default exports.
	if FileAccess.file_exists(CACHE_PATH):
		add_file(CACHE_PATH, FileAccess.get_file_as_bytes(CACHE_PATH), false)
