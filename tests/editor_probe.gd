@tool
extends EditorPlugin

func _enter_tree() -> void:
	_run.call_deferred()

func _run() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	EditorInterface.open_scene_from_path("res://examples/balatro/BalatroExample.tscn")
	for i in 10:
		await get_tree().process_frame
	var scene := EditorInterface.get_edited_scene_root()
	if not scene:
		push_error("Editor did not open the Balatro example.")
		get_tree().quit(1)
		return
	var slot := CardSlot.new()
	scene.add_child(slot)
	if slot.is_processing():
		push_error("Editor slot enabled runtime drop detection.")
		get_tree().quit(1)
		return
	# Reproduce processing being re-enabled by a tool-script reload.
	slot.set_process(true)
	for i in 3:
		await get_tree().process_frame
	if slot.is_processing():
		push_error("Editor slot did not stop runtime processing after reactivation.")
		get_tree().quit(1)
		return
	slot.free()
	if not await _check_panel_layout():
		get_tree().quit(1)
		return
	# Registration must survive toggles without relying on a script class alias.
	EditorInterface.set_plugin_enabled("simple_cards", false)
	if ProjectSettings.has_setting("autoload/CardGlobal"):
		push_error("Disabling the plugin retained its CardGlobal autoload.")
		get_tree().quit(1)
		return
	EditorInterface.set_plugin_enabled("simple_cards", true)
	if not ProjectSettings.has_setting("autoload/CardGlobal"):
		push_error("Re-enabling the plugin did not restore CardGlobal.")
		get_tree().quit(1)
		return
	var plugin_script = load("res://addons/simple_cards/simple_cards.gd")
	var uid := ResourceLoader.get_resource_uid("res://addons/simple_cards/card_global.gd")
	if not plugin_script._is_card_global_autoload("*" + ResourceUID.id_to_text(uid)):
		push_error("Plugin did not recognize its UID-based autoload.")
		get_tree().quit(1)
		return
	print("Editor lifecycle tests passed.")
	get_tree().quit()


func _check_panel_layout() -> bool:
	var capture := SubViewport.new()
	capture.disable_3d = true
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture.size = Vector2i(320, 640)
	add_child(capture)
	var panel = load("res://addons/simple_cards/editor/layout_panel.gd").new()
	panel.editor_interface = EditorInterface
	panel.theme = EditorInterface.get_base_control().theme
	capture.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var artifacts := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="): artifacts = arg.trim_prefix("--artifacts=")
	for width in [320, 1000]:
		capture.size = Vector2i(width, 640)
		for i in 10: await get_tree().process_frame
		if panel.layout_split.vertical != (width < 620 * panel._editor_scale):
			push_error("Layout dock did not adapt at width %d." % width)
			capture.queue_free()
			return false
		if not artifacts.is_empty() and DisplayServer.get_name() != "headless":
			panel._populate_details("res://examples/cards/standard_deck/standard_layout.tscn")
			for i in 10: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(artifacts)
			capture.get_texture().get_image().save_png(artifacts.path_join("layout-dock-%d.png" % width))
	capture.queue_free()
	print("Layout dock narrow/wide checks passed.")
	return true
