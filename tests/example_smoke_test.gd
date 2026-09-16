extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var paths := OS.get_cmdline_user_args()
	for path in paths:
		var packed := load(path) as PackedScene
		for cycle in 2:
			var scene: Node = packed.instantiate()
			add_child(scene)
			await get_tree().create_timer(1.5).timeout
			scene.queue_free()
			await get_tree().process_frame
			await get_tree().create_timer(0.5).timeout
	print("Example teardown checks passed.")
	get_tree().quit()
