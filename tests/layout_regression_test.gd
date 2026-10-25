extends Node

var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	_validation()
	var panel = load("res://addons/simple_cards/editor/layout_panel.gd").new()
	var tags: Array[String] = ["test"]
	for type in ["card_layout", "card_viewport_layout"]:
		var path := "res://tests/generated_%s.tscn" % type
		var script := "res://addons/simple_cards/card/card_layout/%s.gd" % type
		expect(panel._save_new_layout(script, path, "test_" + type, tags) == OK,
			"Could not create " + type)
		var scene := load(path) as PackedScene
		expect(scene != null, "Created layout is not a scene")
		if not scene:
			continue
		var cache := LayoutCache.new()
		var metadata := cache._parse_scene_file(path)
		expect(metadata.get("layout_id") == "test_" + type and metadata.get("tags") == ["test"],
			"Scanner did not read created layout metadata")
		var layout := scene.instantiate() as CardLayout
		add_child(layout)
		expect(layout.get_meta("layout_id") == "test_" + type, "Layout metadata lost")
		layout.card_size = Vector2i(96, 140)
		if layout is CardViewportLayout:
			expect(layout.get_node("SubViewport").size == Vector2i(96, 140), "Viewport size did not follow face")
		else:
			expect(not layout.has_node("SubViewport"), "Direct face created a viewport")
		layout.queue_free()
		DirAccess.remove_absolute(path)
	panel.free()
	var card := Card.new()
	add_child(card)
	card.flip()
	await get_tree().process_frame
	expect(card.current_layout_name == LayoutID.DEFAULT_BACK, "Flip did not use back face")
	card.flip()
	await get_tree().process_frame
	expect(card.current_layout_name == LayoutID.DEFAULT, "Flip did not restore front face")
	card.queue_free()
	await get_tree().process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("Layout regression tests passed.")
	get_tree().quit(0 if failures.is_empty() else 1)


func _validation() -> void:
	var entries := {"res://a.tscn": {"layout_id": "foil"}}
	expect(not LayoutValidation.id_error("foil", entries).is_empty(), "Duplicate ID accepted")
	expect(not LayoutValidation.id_error("FOIL", entries).is_empty(), "Constant collision accepted")
	expect(LayoutValidation.id_error("foil", entries, "res://a.tscn").is_empty(), "Unchanged ID rejected")
	expect(not LayoutValidation.id_error("bad id", {}).is_empty(), "Invalid identifier accepted")
	expect(not LayoutValidation.entry_error("res://a.tscn", {"layout_id": "a", "tags": 12}).is_empty(),
		"Malformed cache tags accepted")
	var missing := {"res://missing_layout.tscn": {"layout_id": "missing"}}
	expect(LayoutValidation.errors(missing).size() == 1, "Missing scene not diagnosed")
	var invalid := PackedScene.new()
	var node := Node.new()
	invalid.pack(node)
	node.free()
	expect(LayoutValidation.instantiate_layout(invalid) == null, "Non-layout template accepted")
	var cache := LayoutCache.new()
	var child_only := '[gd_scene format=3]\n[node name="Root" type="Node"]\n[node name="Child" type="Node" parent="."]\nmetadata/is_layout = true\nmetadata/layout_id = "child"\nmetadata/tags = []\n'
	var path := "res://tests/generated_metadata.tscn"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(child_only)
	file.close()
	expect(cache._parse_scene_file(path).is_empty(), "Child metadata registered a root layout")
	var tags := ['quote"tag', "slash\\tag"]
	var rewritten := cache._upsert_layout_metadata(child_only, {"layout_id": "root", "tags": tags})
	expect(rewritten.ends_with('metadata/layout_id = "child"\nmetadata/tags = []\n'), "Root edit changed child metadata")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(rewritten)
	file.close()
	var metadata := cache._parse_scene_file(path)
	expect(metadata.get("layout_id") == "root" and metadata.get("tags") == tags,
		"Escaped metadata did not roundtrip")
	var typed := rewritten.replace('metadata/tags = ' + JSON.stringify(tags),
		'metadata/tags = Array[String](["old]tag"])')
	var updated := cache._upsert_layout_metadata(typed, {"layout_id": "root", "tags": ["new"]})
	expect(updated.count("metadata/tags = ") == 2 and 'Array[String]' not in updated,
		"Typed tag edit duplicated root metadata or retained the old value")
	DirAccess.remove_absolute(path)
