## Run from the Script Editor using File > Run (Ctrl+Shift+X).
@tool
extends EditorScript

const ValidationRunner = preload("res://tests/validation_runner.gd")
const RUNNER_NAME = "SimpleCardsValidation"


func _run() -> void:
	var editor := EditorInterface.get_base_control()
	if editor.has_node(NodePath(RUNNER_NAME)):
		print("SimpleCards validation is already running.")
		return
	# Keep the asynchronous runner alive after this EditorScript returns.
	var runner := ValidationRunner.new()
	runner.name = RUNNER_NAME
	editor.add_child(runner)
