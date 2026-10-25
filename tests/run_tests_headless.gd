## Run after import: godot --headless --path . --script tests/run_tests_headless.gd
extends SceneTree

const ValidationRunner = preload("res://tests/validation_runner.gd")


func _initialize() -> void:
	var runner := ValidationRunner.new()
	runner.finished.connect(func(passed: bool): quit(0 if passed else 1))
	root.add_child.call_deferred(runner)
