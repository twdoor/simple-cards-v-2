## Shared runner for the EditorScript and headless entry points.
@tool
extends Node

signal finished(passed: bool)

var source: String
var workspace: String
var processes: Array[Dictionary] = []
var sequence := 0
var include_rendered := (Engine.is_editor_hint() and DisplayServer.get_name() != "headless") or "--rendered" in OS.get_cmdline_user_args()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var version := Engine.get_version_info()
	if version.major != 4 or version.minor < 7 or (version.minor == 7 and version.patch < 2):
		push_error("Validation requires the Godot 4.7.2+ editor.")
		_finish(false)
		return
	print("Starting SimpleCards validation in temporary project copies...")
	source = ProjectSettings.globalize_path("res://")
	workspace = OS.get_temp_dir().path_join("simple-cards-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(workspace.path_join("logs"))
	var project := workspace.path_join("project")
	if not _copy_directory(source, project):
		_finish(false)
		return
	if not await _run_command(project, "Fresh import", ["--editor", "--import", "--quit"]):
		_finish(false)
		return
	for suite in [
		["CoreRegressionTest", "Core regression tests passed."],
		["LayoutRegressionTest", "Layout regression tests passed."],
		["ShaderStackTest", "Shader stack tests passed."],
		["MultiplayerRegressionTest", "Multiplayer regression tests passed."],
	]:
		if not await _run_command(project, suite[0],
			["res://tests/%s.tscn" % suite[0], "--quit-after", "1200"], suite[1]):
			_finish(false)
			return
	if not await _server_roundtrip(project) or not await _editor_check(project):
		_finish(false)
		return
	if include_rendered:
		if not await _run_command(project, "Rendered shader stack",
			["res://tests/ShaderStackTest.tscn", "--quit-after", "1200", "--", "--rendered"],
			"Shader stack tests passed.", false):
			_finish(false)
			return
	for scene in ["balatro/BalatroExample", "solitaire/SolitaireExample", "multiplayer/p2p_macau"]:
		if not await _run_command(project, scene, ["res://examples/%s.tscn" % scene, "--quit-after", "120"]):
			_finish(false)
			return
	var install := workspace.path_join("install")
	if not _copy_directory(source.path_join("addons/simple_cards"), install.path_join("addons/simple_cards")):
		_finish(false)
		return
	_write_file(install.path_join("project.godot"), 'config_version=5\n[application]\nconfig/name="Installation fixture"\n[editor_plugins]\nenabled=PackedStringArray("res://addons/simple_cards/plugin.cfg")\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
	if not await _run_command(install, "Addon-only import", ["--editor", "--import", "--quit"]):
		_finish(false)
		return
	var installed_config := ConfigFile.new()
	installed_config.load(install.path_join("project.godot"))
	var autoload := str(installed_config.get_value("autoload", "CardGlobal", ""))
	if not autoload.begins_with("*"):
		push_error("Installation did not persist the CardGlobal autoload.")
		_finish(false)
		return
	DirAccess.make_dir_recursive_absolute(install.path_join("tests"))
	for file in ["install_probe.gd", "InstallProbe.tscn"]:
		DirAccess.copy_absolute(source.path_join("tests/" + file), install.path_join("tests/" + file))
	var installed := await _run_command(install, "Addon-only runtime",
		["res://tests/InstallProbe.tscn", "--quit-after", "1200"], "Installation fixture passed.")
	_finish(installed)


func _spawn(project: String, label: String, arguments: Array, marker := "", headless := true) -> Dictionary:
	sequence += 1
	var log := workspace.path_join("logs/%02d-%s.log" % [sequence, label.validate_filename()])
	var args := PackedStringArray(["--audio-driver", "Dummy", "--path", project, "--log-file", log])
	if headless:
		args.append("--headless")
	args.append_array(PackedStringArray(arguments))
	var process := {"pid": OS.create_process(OS.get_executable_path(), args), "log": log,
		"label": label, "marker": marker}
	processes.append(process)
	return process


func _run_command(project: String, label: String, arguments: Array, marker := "", headless := true) -> bool:
	return await _wait(_spawn(project, label, arguments, marker, headless))


func _wait(process: Dictionary, timeout := 90.0) -> bool:
	if process.pid < 0:
		push_error("Could not start " + process.label)
		return false
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while OS.is_process_running(process.pid):
		if Time.get_ticks_msec() >= deadline:
			push_error("Timed out: " + process.label)
			OS.kill(process.pid)
			return false
		await get_tree().create_timer(0.05).timeout
	var code := OS.get_process_exit_code(process.pid)
	processes.erase(process)
	var output := FileAccess.get_file_as_string(process.log)
	var passed: bool = code == 0 and (process.marker.is_empty() or output.contains(process.marker))
	for line in output.split("\n"):
		if line.contains("ERROR:") and not line.contains("resources still in use at exit"):
			passed = false
	if not passed:
		push_error("FAIL %s (exit %d)\n%s" % [process.label, code, output])
	else:
		print("PASS " + process.label)
	if output.contains("leaked at exit") or output.contains("resources still in use at exit"):
		print("NOTICE %s: shutdown retention reported; see github/VALIDATION.md" % process.label)
	return passed


func _server_roundtrip(project: String) -> bool:
	var udp := PacketPeerUDP.new()
	if udp.bind(0, "127.0.0.1") != OK:
		push_error("Could not reserve a local UDP port.")
		return false
	var port := "--port=%d" % udp.get_local_port()
	udp.close()
	var scene := "res://tests/ServerRoundtripTest.tscn"
	var server := _spawn(project, "Live network server", [scene, "--", "--role=server", port], "Server roundtrip passed.")
	var deadline := Time.get_ticks_msec() + 10000
	while not FileAccess.file_exists(server.log) or not FileAccess.get_file_as_string(server.log).contains("ROUNDTRIP_READY"):
		if server.pid < 0 or not OS.is_process_running(server.pid) or Time.get_ticks_msec() >= deadline:
			push_error("Network server did not become ready; see " + server.log)
			return false
		await get_tree().create_timer(0.05).timeout
	if not await _run_command(project, "Live network client", [scene, "--", "--role=client", port], "Client roundtrip passed"):
		return false
	return await _wait(server, 10.0)


func _editor_check(project: String) -> bool:
	var probe := project.path_join("addons/validation_probe")
	DirAccess.make_dir_recursive_absolute(probe)
	DirAccess.copy_absolute(source.path_join("tests/editor_probe.gd"), probe.path_join("probe.gd"))
	_write_file(probe.path_join("plugin.cfg"), '[plugin]\nname="Validation probe"\ndescription="Editor regression checks"\nauthor="Tests"\nversion="1"\nscript="probe.gd"\n')
	var config_path := project.path_join("project.godot")
	var config := FileAccess.get_file_as_string(config_path).replace(
		'PackedStringArray("res://addons/simple_cards/plugin.cfg")',
		'PackedStringArray("res://addons/simple_cards/plugin.cfg", "res://addons/validation_probe/plugin.cfg")')
	_write_file(config_path, config)
	return await _run_command(project, "Editor example lifecycle", ["--editor"], "Editor lifecycle tests passed.")


func _copy_directory(from: String, to: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(to) != OK:
		push_error("Cannot create " + to)
		return false
	var directory := DirAccess.open(from)
	if not directory:
		push_error("Cannot read " + from)
		return false
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not name.begins_with(".") and name != "__pycache__":
			if directory.current_is_dir():
				if not _copy_directory(from.path_join(name), to.path_join(name)):
					return false
			elif DirAccess.copy_absolute(from.path_join(name), to.path_join(name)) != OK:
				push_error("Cannot copy " + from.path_join(name))
				return false
		name = directory.get_next()
	return true


func _write_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
	else:
		push_error("Cannot write " + path)


func _finish(passed: bool) -> void:
	for process in processes:
		if process.pid >= 0 and OS.is_process_running(process.pid):
			OS.kill(process.pid)
	processes.clear()
	if passed:
		_remove_directory(workspace)
		print("PASS: all validation checks")
	else:
		push_error("Validation failed. Project copies and logs retained at " + workspace)
	finished.emit(passed)
	queue_free()


func _remove_directory(path: String) -> void:
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):
		_remove_directory(path.path_join(name))
	DirAccess.remove_absolute(path)


func _exit_tree() -> void:
	for process in processes:
		if process.pid >= 0 and OS.is_process_running(process.pid):
			OS.kill(process.pid)
