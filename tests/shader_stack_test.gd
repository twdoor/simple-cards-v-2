extends Node

var failures: Array[String] = []
var rendered := "--rendered" in OS.get_cmdline_user_args()


func _ready() -> void:
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _effect(name: String, operation := "", premultiplied := false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nrender_mode %s, unshaded;\nuniform float amount = 1.0;\nvoid fragment() { vec4 color = texture(TEXTURE, UV); %s COLOR = color; }" % [
		"blend_premul_alpha" if premultiplied else "blend_mix", operation]
	var effect := ShaderMaterial.new()
	effect.resource_name = name
	effect.shader = shader
	# The headless dummy renderer does not expose shader uniform defaults.
	effect.set_shader_parameter("amount", 1.0)
	return effect


func _layout(effects: Array[ShaderMaterial]) -> CardViewportLayout:
	var layout := CardViewportLayout.new()
	layout.card_size = Vector2i(32, 32)
	layout.effect_padding = 4
	layout.shader_stack = effects
	var source := SubViewport.new()
	source.name = "SubViewport"
	source.size = Vector2i(32, 32)
	layout.add_child(source)
	var face := ColorRect.new()
	face.name = "Face"
	face.color = Color(0.8, 0.4, 0.2, 0.5)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	source.add_child(face)
	return layout


func _viewports(layout: CardViewportLayout) -> Array[SubViewport]:
	var result: Array[SubViewport] = []
	for child in layout.get_children(true):
		if child is SubViewport:
			result.append(child)
	return result


func _settle() -> void:
	# Visibility discovery must reach every link on the first rendered frame chain.
	for i in (18 if rendered else 2):
		await get_tree().process_frame
	if rendered:
		await RenderingServer.frame_post_draw


func _sample(capture: SubViewport, pixel: Vector2i) -> Color:
	return capture.get_texture().get_image().get_pixelv(pixel)


func _near(actual: Color, expected: Color, message: String) -> void:
	if actual.a < 0.001 and expected.a < 0.001:
		return
	var distance := Vector4(actual.r, actual.g, actual.b, actual.a).distance_to(
		Vector4(expected.r, expected.g, expected.b, expected.a))
	expect(distance < 0.035, "%s: got %s, expected %s" % [message, actual, expected])


func _targeted_refresh() -> void:
	for premultiplied in [false, true]:
		var capture := SubViewport.new()
		capture.size = Vector2i(64, 64)
		capture.transparent_bg = true
		capture.disable_3d = true
		capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(capture)
		var alpha := " * color.a" if premultiplied else ""
		var effects: Array[ShaderMaterial] = [
			_effect("Red", "color.r += amount * 0.1%s;" % alpha, premultiplied),
			_effect("Green", "color.g += amount * 0.1%s;" % alpha, premultiplied),
			_effect("Final", "color.r *= amount;", premultiplied)]
		var layout := _layout(effects)
		layout.live_source = false
		layout.live_effects = false
		layout.position = Vector2(16, 16)
		if premultiplied:
			layout.shader_alpha_mode = CardViewportLayout.ShaderAlphaMode.PREMULTIPLIED
		capture.add_child(layout)
		await _settle()
		var targets := _viewports(layout)
		for target in targets:
			target.render_target_update_mode = SubViewport.UPDATE_DISABLED
		# This unrequested source edit must remain invisible after uniform changes.
		layout.get_node("SubViewport/Face").color = Color(0.2, 0.8, 0.4, 0.5)
		layout.set_shader_parameter(&"Green", &"amount", 2.0)
		var first_affected := 2 if premultiplied else 4
		for i in targets.size():
			var mode := SubViewport.UPDATE_DISABLED if i < first_affected else SubViewport.UPDATE_ONCE
			expect(targets[i].render_target_update_mode == mode, "Uniform update refreshed a source/upstream stage or missed a dependent stage")
		await _settle()
		if rendered:
			_near(_sample(capture, Vector2i(24, 24)), Color(0.45, 0.3, 0.1, 0.5), "Uniform update recaptured stale source content")
		for target in targets:
			target.render_target_update_mode = SubViewport.UPDATE_DISABLED
		layout.set_shader_parameter(&"Final", &"amount", 0.5)
		for target in targets:
			expect(target.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Final shader uniform refreshed a capture")
		await _settle()
		if rendered:
			_near(_sample(capture, Vector2i(24, 24)), Color(0.225, 0.3, 0.1, 0.5), "Final shader did not update directly in the canvas")
		var material := layout.get_shader_material(&"Green")
		material.set_shader_parameter("amount", 0.5)
		material.emit_changed()
		expect(targets[0].render_target_update_mode == SubViewport.UPDATE_DISABLED, "Material callback refreshed the source")
		await _settle()
		if rendered:
			_near(_sample(capture, Vector2i(24, 24)), Color(0.225, 0.225, 0.1, 0.5), "Material callback did not refresh effect captures")
		material.set_shader_parameter("amount", 0.75)
		expect(layout.request_shader_render(&"Green"), "Explicit shader refresh rejected a named effect")
		expect(not layout.request_shader_render(&"Missing"), "Explicit shader refresh accepted an unknown effect")
		await _settle()
		if rendered:
			_near(_sample(capture, Vector2i(24, 24)), Color(0.225, 0.2375, 0.1, 0.5), "Explicit shader refresh changed cached source content")
		layout.set_shader_parameter(&"Red", &"amount", 2.0)
		await _settle()
		if rendered:
			_near(_sample(capture, Vector2i(24, 24)), Color(0.25, 0.2375, 0.1, 0.5), "Upstream parameter update did not propagate to dependent captures")
		layout.request_render()
		await _settle()
		if rendered:
			_near(_sample(capture, Vector2i(24, 24)), Color(0.1, 0.4375, 0.2, 0.5), "Full refresh did not update the source and effect chain")
		capture.queue_free()
		await get_tree().process_frame


func _run() -> void:
	await _standard_hover_reset()
	await _targeted_refresh()
	var capture := SubViewport.new()
	capture.size = Vector2i(96, 96)
	capture.transparent_bg = true
	capture.disable_3d = true
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(capture)
	var effects: Array[ShaderMaterial] = []
	for i in 4:
		effects.append(_effect("Effect%d" % i))
	var layout := _layout(effects)
	layout.position = Vector2(16, 16)
	capture.add_child(layout)
	await _settle()
	expect(_viewports(layout).size() == 8, "Four straight-alpha effects should use eight targets")
	expect(layout.get_rendered_rect() == Rect2(-4, -4, 40, 40), "Padding changed visual/card bounds")
	expect(layout.size == Vector2(32, 32), "Padding changed card size")
	expect(layout.get_shader_material(&"Effect0") == layout.get_shader_material(0), "Named/indexed effect lookup disagreed")
	expect(layout.get_shader(0) == effects[0].shader, "Shader lookup lost its resource")
	expect(is_equal_approx(layout.get_shader_parameters(0).get(&"amount", -1.0), 1.0), "Parameter defaults were not exposed")
	expect(layout.get_shader_material(&"missing") == null and layout.get_shader_material(-1) == null,
		"Unknown effect selected a material")
	expect(not layout.set_shader_parameter(0, &"missing", 1.0), "Unknown parameter was accepted")
	if rendered:
		_near(_sample(capture, Vector2i(24, 24)), Color(0.4, 0.2, 0.1, 0.5), "Stack darkened translucent content")
		_near(_sample(capture, Vector2i(13, 13)), Color.TRANSPARENT, "Padding was not transparent")
		_near(_sample(capture, Vector2i(47, 47)), Color(0.4, 0.2, 0.1, 0.5), "Viewport padding changed anchored face dimensions")
		_near(_sample(capture, Vector2i(49, 49)), Color.TRANSPARENT, "Face content extended into padding")

	var other := _layout(effects)
	add_child(other)
	await _settle()
	var targets := _viewports(layout)
	expect(layout.set_shader_parameter(&"Effect0", &"amount", 0.25), "Named parameter update failed")
	await _settle()
	expect(layout.get_shader_parameter(0, &"amount") == 0.25, "Parameter update was lost")
	expect(other.get_shader_parameter(0, &"amount") == 1.0 and effects[0].get_shader_parameter("amount") == 1.0,
		"Changing one card modified another card or its source material")
	expect(_viewports(layout) == targets, "Parameter edit rebuilt render targets")
	var original_material := layout.get_shader_material(0)
	layout.shader_stack = [effects[1], effects[0], effects[2], effects[3]]
	await _settle()
	expect(layout.get_shader_material(&"Effect0") == original_material and layout.get_shader_parameter(&"Effect0", &"amount") == 0.25,
		"Reordering replaced a live material or lost its parameters")
	layout.shader_stack = effects
	await _settle()
	layout.set_shader_enabled(&"Effect1", false)
	await _settle()
	expect(_viewports(layout).size() == 6, "Disabled effect still consumed render targets")
	expect(layout.get_shader_parameter(0, &"amount") == 0.25, "Rebuild discarded live parameters")
	layout.set_shader_enabled(&"Effect1", true)
	await _settle()

	layout.live_source = false
	layout.live_effects = false
	if rendered:
		await _settle()
		layout.get_node("SubViewport/Face").color = Color(0.2, 0.8, 0.4, 0.5)
		await _settle()
		_near(_sample(capture, Vector2i(24, 24)), Color(0.4, 0.2, 0.1, 0.5), "Cached captures changed without a render request")
		layout.request_render()
		await _settle()
		_near(_sample(capture, Vector2i(24, 24)), Color(0.1, 0.4, 0.2, 0.5), "Render request did not refresh the full cached chain")
		layout.get_node("SubViewport/Face").color = Color(0.8, 0.4, 0.2, 0.5)
	layout.hide()
	for target in _viewports(layout):
		expect(target.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden face kept rendering")
	layout.show()
	expect(layout.get_node("SubViewport").render_target_update_mode == SubViewport.UPDATE_ONCE,
		"Showing a cached face did not request a refresh")
	layout.request_render()

	var premultiplied: Array[ShaderMaterial] = []
	for i in 4:
		premultiplied.append(_effect("Premult%d" % i, "", true))
	layout.shader_stack = premultiplied
	layout.shader_alpha_mode = CardViewportLayout.ShaderAlphaMode.PREMULTIPLIED
	await _settle()
	expect(_viewports(layout).size() == 4, "Four premultiplied effects should use four targets")
	if rendered:
		_near(_sample(capture, Vector2i(24, 24)), Color(0.4, 0.2, 0.1, 0.5), "Premultiplied stack changed alpha/color")

	# Addition followed by multiplication is deliberately not commutative.
	var ordered: Array[ShaderMaterial] = [
		_effect("Add", "color.r += amount * 0.1;"),
		_effect("Multiply", "color.r *= amount * 0.5;")]
	layout.shader_alpha_mode = CardViewportLayout.ShaderAlphaMode.STRAIGHT
	layout.shader_stack = ordered
	await _settle()
	if rendered:
		_near(_sample(capture, Vector2i(24, 24)), Color(0.225, 0.2, 0.1, 0.5), "Effects did not execute top to bottom")
	layout.render_scale = 0.5
	layout.card_size = Vector2i(64, 48)
	await _settle()
	expect(layout.get_node("SubViewport").size == Vector2i(36, 28), "Render scale/padding did not follow card resize")
	expect(layout.get_node("SubViewport").size_2d_override == Vector2i(64, 48), "Capture changed logical content size")

	layout.shader_stack = []
	await _settle()
	expect(_viewports(layout).size() == 1, "Empty stack allocated effect targets")
	if rendered:
		_near(_sample(capture, Vector2i(24, 24)), Color(0.4, 0.2, 0.1, 0.5), "Empty stack changed source colors")
	layout.shader_stack = [effects[0]]
	layout.render_scale = 1.0
	layout.card_size = Vector2i(32, 32)
	await _settle()
	# Shader code edits can activate an entry that was skipped as non-canvas.
	var live := layout.get_shader_material(0)
	live.shader = _effect("Replacement", "color.g = 0.0;").shader
	await _settle()
	if rendered:
		_near(_sample(capture, Vector2i(24, 24)), Color(0.4, 0.0, 0.1, 0.5), "Live shader replacement did not reach output")
		live.set_shader_parameter("amount", null)
		expect(layout.get_shader_parameters(0).get(&"amount") == 1.0, "Shader default was not exposed without an override")
	# Code edits can change the shader's type, not just its uniform values.
	live.shader.code = "shader_type spatial;"
	await _settle()
	expect(_viewports(layout).size() == 1, "Non-canvas shader still consumed passes")
	live.shader.code = _effect("CanvasAgain").shader.code
	await _settle()
	expect(_viewports(layout).size() == 2, "Canvas shader code edit did not reactivate its pass")
	var duplicate := _effect("Effect0")
	layout.shader_stack = [effects[0], duplicate]
	await _settle()
	expect(layout.get_shader_material(&"Effect0") == null, "Ambiguous name silently selected an effect")
	layout.shader_stack = [effects[0]]
	await _settle()
	var parent := layout.get_parent()
	parent.remove_child(layout)
	parent.add_child(layout)
	await _settle()
	expect(layout.get_shader_material(0).changed.has_connections(), "Re-entering tree did not restore material callbacks")
	live = layout.get_shader_material(0)
	capture.queue_free()
	other.queue_free()
	await _settle()
	expect(not live.changed.has_connections(), "Freed layout retained material callbacks")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("Shader stack tests passed.")
	get_tree().quit(0 if failures.is_empty() else 1)


func _standard_hover_reset() -> void:
	var capture := SubViewport.new()
	capture.size = Vector2i(320, 240)
	capture.disable_3d = true
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(capture)
	var card := Card.new(StandardCardResource.new())
	card.position = Vector2(24, 24)
	capture.add_child(card)
	var layout := card.get_layout() as CardViewportLayout
	await _settle()
	# A pressed/dragged card can retain focus after the pointer leaves. No
	# focus-out animation will reset the uniforms in this state.
	card.focused = true
	card.holding = true
	card._released = false
	layout.set("_rotation", Vector2(8.0, -6.0))
	layout.set_shader_parameter(&"persp", &"x_rot", 8.0)
	layout.set_shader_parameter(&"persp", &"y_rot", -6.0)
	layout._process(0.016)
	expect(layout.get_shader_parameter(&"persp", &"x_rot") == 0.0
		and layout.get_shader_parameter(&"persp", &"y_rot") == 0.0,
		"Non-hovered card retained perspective while drag focus stayed active")
	expect(layout.get("_rotation") == Vector2.ZERO, "Perspective reset retained stale rotation for the next hover")
	expect(card.focused, "Perspective reset changed card focus")
	card.focused = false
	card.holding = false
	card._released = true
	layout.set("_rotation", Vector2(5.0, 3.0))
	layout.set_shader_parameter(&"persp", &"x_rot", 5.0)
	layout.set_shader_parameter(&"persp", &"y_rot", 3.0)
	layout.set("enable_perspective_hover", false)
	layout.call("set_perspective")
	expect(layout.get_shader_parameter(&"persp", &"x_rot") == 0.0
		and layout.get_shader_parameter(&"persp", &"y_rot") == 0.0,
		"Disabling perspective retained shader angles")
	if rendered:
		card.undraggable = true
		layout.set("enable_perspective_hover", true)
		layout.call("set_perspective")
		var second := Card.new(StandardCardResource.new())
		second.position = Vector2(70, 80)
		capture.add_child(second)
		await _settle()
		var second_layout := second.get_layout() as CardViewportLayout
		# Move through overlapping cards using real GUI mouse events, then leave
		# while pressed. Hover loss must reset independently of retained focus.
		for pass_index in 3:
			var motion := InputEventMouseMotion.new()
			motion.position = Vector2(34, 34)
			capture.push_input(motion, true)
			await _settle()
			expect(card.is_hovered(), "GUI pointer did not enter first standard card")
			layout._process(0.1)
			expect(absf(layout.get_shader_parameter(&"persp", &"x_rot")) > 0.1,
				"Hovered standard card did not tilt")
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = motion.position
			capture.push_input(press, true)
			motion.position = Vector2(140, 170)
			capture.push_input(motion, true)
			await _settle()
			expect(not card.is_hovered() and second.is_hovered(), "GUI pointer did not transfer between overlapping cards")
			expect(layout.get_shader_parameter(&"persp", &"x_rot") == 0.0
				and layout.get_shader_parameter(&"persp", &"y_rot") == 0.0,
				"Leaving a pressed card for another card left its perspective tilted")
			motion.position = Vector2(300, 220)
			capture.push_input(motion, true)
			press.pressed = false
			press.position = motion.position
			capture.push_input(press, true)
			await _settle()
			expect(second_layout.get_shader_parameter(&"persp", &"x_rot") == 0.0
				and second_layout.get_shader_parameter(&"persp", &"y_rot") == 0.0,
				"Second standard card retained perspective after hover exit")
		# Finish the example's 0.2-second focus animations before freeing their nodes.
		await get_tree().create_timer(0.25).timeout
	# A standalone editor face can have a resource but no owning Card.
	var standalone = load("res://examples/cards/standard_deck/standard_layout.tscn").instantiate()
	capture.add_child(standalone)
	standalone.card_resource = StandardCardResource.new()
	standalone._process(0.016)
	await _settle()
	capture.queue_free()
	await get_tree().process_frame
