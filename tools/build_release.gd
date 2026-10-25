## Open in Godot's Script Editor and use File > Run (Ctrl+Shift+X).
## Save all changes and run validation first. Does not publish or create a tag.
@tool
extends EditorScript

const ReleaseBuilder = preload("res://tools/release_builder.gd")

func _run() -> void:
	ReleaseBuilder.new().build()
