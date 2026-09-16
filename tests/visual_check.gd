## Optional rendered smoke capture; run without --headless.
extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected scene path and screenshot output path.")
		get_tree().quit(1)
		return
	var game: Node = (load(args[0]) as PackedScene).instantiate()
	add_child(game)
	await get_tree().create_timer(3.0).timeout
	# Exercise keyboard focus and responsive layout before capturing the board.
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await get_tree().process_frame
	tab = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = false
	Input.parse_input_event(tab)
	get_window().size = Vector2i(1024, 640)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[1])
	game.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	print("Rendered capture passed.")
	get_tree().quit()
