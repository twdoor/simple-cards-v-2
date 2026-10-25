## Run: godot --headless --path . --script tools/build_release_headless.gd
extends SceneTree

const ReleaseBuilder = preload("res://tools/release_builder.gd")

func _initialize() -> void:
	var output: String = ReleaseBuilder.new().build()
	quit(1 if output.is_empty() else 0)
