## Shared Godot-only release packager. Uses the version in plugin.cfg.
@tool
extends RefCounted

const ADDON := "addons/simple_cards"
const PROJECT_DIRECTORIES := ["addons", "examples", "github", "tests", "tools", ".github"]
const PROJECT_FILES := ["project.godot", "README.md", "LICENSE", ".godotrc", ".gitignore", ".gitattributes", ".editorconfig"]


func build() -> String:
	var config := ConfigFile.new()
	if config.load("res://%s/plugin.cfg" % ADDON) != OK:
		push_error("Cannot read plugin.cfg")
		return ""
	var version := str(config.get_value("plugin", "version", ""))
	var pattern := RegEx.create_from_string("^[0-9]+(\\.[0-9]+)+$")
	if not pattern.search(version):
		push_error("Set a numeric release version in plugin.cfg before packaging.")
		return ""
	var destination := "res://.releases/" + version
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	var license := FileAccess.get_file_as_bytes("res://LICENSE")
	if license.is_empty():
		push_error("Root LICENSE is missing or empty.")
		return ""
	# Keep a license with the addon when it is copied directly from this checkout.
	var copy := FileAccess.open("res://%s/LICENSE" % ADDON, FileAccess.WRITE)
	if not copy:
		push_error("Cannot copy the addon license.")
		return ""
	copy.store_buffer(license)
	copy.close()
	var addon_files: Array[String] = []
	_collect(ADDON, addon_files)
	var project_files: Array[String] = []
	for directory in PROJECT_DIRECTORIES:
		_collect(directory, project_files)
	for path in PROJECT_FILES:
		if FileAccess.file_exists("res://" + path):
			project_files.append(path)
	project_files.sort()
	var store_name := version.replace(".", "v")
	var checksums: Array[String] = []
	for archive in [
		{"name": "addon.zip", "files": addon_files, "prefix": ""},
		{"name": "project.zip", "files": project_files, "prefix": ""},
		{"name": store_name + ".zip", "files": addon_files, "prefix": store_name + "/"},
	]:
		var output: String = destination.path_join(archive.name)
		if not _write_archive(output, archive.files, archive.prefix):
			return ""
		if not _verify_archive(output, archive.files, archive.prefix, license):
			return ""
		checksums.append("%s  %s" % [FileAccess.get_sha256(output), archive.name])
		print("Built and verified ", ProjectSettings.globalize_path(output))
	var checksum_file := FileAccess.open(destination.path_join("SHA256SUMS"), FileAccess.WRITE)
	if not checksum_file:
		push_error("Cannot write release checksums.")
		return ""
	checksum_file.store_string("\n".join(checksums) + "\n")
	checksum_file.close()
	print("Release archives ready: ", ProjectSettings.globalize_path(destination))
	return ProjectSettings.globalize_path(destination)


func _collect(directory: String, result: Array[String]) -> void:
	for file in DirAccess.get_files_at("res://" + directory):
		if file.begins_with(".") or file.ends_with("~"):
			continue
		result.append(directory.path_join(file))
	for child in DirAccess.get_directories_at("res://" + directory):
		if child.begins_with("."):
			continue
		_collect(directory.path_join(child), result)
	result.sort()


func _write_archive(path: String, files: Array[String], prefix: String) -> bool:
	var packer := ZIPPacker.new()
	if packer.open(ProjectSettings.globalize_path(path)) != OK:
		push_error("Cannot create " + path)
		return false
	for file in files:
		if packer.start_file(prefix + file) != OK or packer.write_file(FileAccess.get_file_as_bytes("res://" + file)) != OK or packer.close_file() != OK:
			push_error("Cannot package " + file)
			packer.close()
			return false
	if packer.close() != OK:
		push_error("Cannot finish " + path)
		return false
	return true


func _verify_archive(path: String, files: Array[String], prefix: String, license: PackedByteArray) -> bool:
	var reader := ZIPReader.new()
	if reader.open(ProjectSettings.globalize_path(path)) != OK:
		push_error("Cannot reopen " + path)
		return false
	# ZIPPacker also writes directory entries for nested file paths.
	var members: Array[String] = []
	for member in reader.get_files():
		if not member.ends_with("/"): members.append(member)
	var valid := members.size() == files.size()
	if not valid: push_error("Unexpected archive file count: " + path)
	for file in files:
		if not reader.file_exists(prefix + file) or reader.read_file(prefix + file) != FileAccess.get_file_as_bytes("res://" + file):
			push_error("Archive content mismatch: " + file)
			valid = false
	if reader.read_file(prefix + ADDON + "/LICENSE") != license:
		push_error("Archive is missing the canonical addon license: " + path)
		valid = false
	reader.close()
	return valid
