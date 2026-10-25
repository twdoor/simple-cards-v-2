## Composes a card face and applies [member shader_stack] from top to bottom.
## Build visuals inside the child SubViewport. Card interaction stays on [Card].
@tool
@icon("res://addons/simple_cards/card/card_layout/icon_card_layout.png")
class_name CardViewportLayout extends CardLayout

## Straight-alpha shaders use ordinary blend_mix. Premultiplied shaders must
## preserve premultiplied colors and use blend_premul_alpha; no conversion passes.
enum ShaderAlphaMode { STRAIGHT, PREMULTIPLIED }

@export_group("Shader Stack")
## Use each material's Resource Name to access it by name. Runtime materials are
## copied per layout; use get_shader_material() to animate the live instance.
@export var shader_stack: Array[ShaderMaterial] = []:
	set(value):
		shader_stack = value
		_queue_rebuild()
## Applies to every entry. Mixed alpha conventions in one stack are unsupported.
@export var shader_alpha_mode: ShaderAlphaMode = ShaderAlphaMode.STRAIGHT:
	set(value):
		shader_alpha_mode = value
		_queue_rebuild()
## Extra drawing space for outlines/displacement; does not change card hit bounds.
@export_range(0, 128, 1, "suffix:px") var effect_padding: int = 0:
	set(value):
		effect_padding = maxi(value, 0)
		_queue_rebuild()
## Lower values trade texture detail for smaller render targets.
@export_range(0.25, 2.0, 0.05) var render_scale: float = 1.0:
	set(value):
		render_scale = clampf(value, 0.25, 2.0)
		_queue_rebuild()

@export_group("Capture Updates")
## Disable for static face content. Call request_render() after changing visuals.
@export var live_source: bool = true:
	set(value):
		live_source = value
		request_render()
## Disable for static intermediate effects. The final shader draws directly in
## the main canvas, so its TIME uniform and vertex stage still run every frame.
@export var live_effects: bool = true:
	set(value):
		live_effects = value
		_request_effects_render()

const STRAIGHT_ALPHA_SHADER = preload("res://addons/simple_cards/card/card_layout/straight_alpha.gdshader")

var _templates: Array[ShaderMaterial] = []
var _materials: Array[ShaderMaterial] = []
var _disabled: Dictionary[int, bool] = {}
var _passes: Array[SubViewport] = []
var _effect_pass_starts: Dictionary[ShaderMaterial, int] = {}
var _output: TextureRect
var _rebuild_pending := false
var _watched_shaders: Dictionary[ShaderMaterial, Shader] = {}
var _watched_code: Array[Shader] = []
var _target_size := Vector2i.ZERO
var _build_revision := 0


## Select an effect by its array index or unique material Resource Name.
## The returned material belongs to this layout at runtime. Shader resources
## remain shared; editing shader code intentionally affects all its users.
func get_shader_material(effect: Variant) -> ShaderMaterial:
	_sync_materials()
	var index := _effect_index(effect)
	return _materials[index] if index >= 0 else null


func get_shader(effect: Variant) -> Shader:
	var effect_material := get_shader_material(effect)
	return effect_material.shader if effect_material else null


func get_shader_parameter(effect: Variant, parameter: StringName) -> Variant:
	var effect_material := get_shader_material(effect)
	return _parameter_value(effect_material, parameter)


## Returns false for an unknown effect or parameter; does not rebuild the stack.
func set_shader_parameter(effect: Variant, parameter: StringName, value: Variant) -> bool:
	var effect_material := get_shader_material(effect)
	if not effect_material or not effect_material.shader:
		return false
	for uniform in effect_material.shader.get_shader_uniform_list():
		if StringName(uniform.name) == parameter:
			effect_material.set_shader_parameter(parameter, value)
			_request_shader_render(effect_material)
			return true
	return false


## All exposed uniforms and their current values, including shader defaults.
func get_shader_parameters(effect: Variant) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	var effect_material := get_shader_material(effect)
	if effect_material and effect_material.shader:
		for uniform in effect_material.shader.get_shader_uniform_list():
			if not (int(uniform.usage) & PROPERTY_USAGE_GROUP):
				result[StringName(uniform.name)] = _parameter_value(effect_material, StringName(uniform.name))
	return result


func _parameter_value(effect: ShaderMaterial, parameter: StringName) -> Variant:
	if not effect or not effect.shader:
		return null
	var value: Variant = effect.get_shader_parameter(parameter)
	if value == null:
		value = RenderingServer.shader_get_parameter_default(effect.shader.get_rid(), parameter)
	return value


## Disabled effects allocate no passes and keep their parameters for re-enabling.
func set_shader_enabled(effect: Variant, enabled: bool) -> bool:
	_sync_materials()
	var index := _effect_index(effect)
	if index < 0:
		return false
	if enabled:
		_disabled.erase(index)
	else:
		_disabled[index] = true
	_queue_rebuild()
	return true


## Refreshes the face and all effect captures without recreating viewports.
## Use after changing child visuals; uniform-only changes use request_shader_render().
func request_render() -> void:
	if not is_inside_tree():
		return
	var source := get_node_or_null("SubViewport") as SubViewport
	if source:
		source.render_target_update_mode = _update_mode(live_source)
	_request_effects_render()


## Refreshes only this effect and its downstream captures, keeping the source
## and upstream captures cached. Useful after direct material edits/tweens when
## live_effects is false. The final canvas shader needs no capture refresh.
func request_shader_render(effect: Variant) -> bool:
	var effect_material := get_shader_material(effect)
	if not effect_material:
		return false
	_request_shader_render(effect_material)
	return true


func _request_shader_render(effect: ShaderMaterial) -> void:
	if not is_inside_tree() or not _effect_pass_starts.has(effect):
		return
	for i in range(_effect_pass_starts[effect], _passes.size()):
		_passes[i].render_target_update_mode = _update_mode(live_effects)


func _request_effects_render() -> void:
	for viewport in _passes:
		viewport.render_target_update_mode = _update_mode(live_effects)


## Unshaded face texture. The final stack effect is drawn directly to the canvas,
## so there is deliberately no extra texture containing the final shaded result.
func get_source_texture() -> Texture2D:
	var source := get_node_or_null("SubViewport") as SubViewport
	return source.get_texture() if source else null


## Local visual bounds including padding. Input and container sizing use card_size.
func get_rendered_rect() -> Rect2:
	var padding := Vector2.ONE * effect_padding
	return Rect2(-padding, size + padding * 2.0)


func _ready() -> void:
	super._ready()
	visibility_changed.connect(request_render)
	resized.connect(_update_output_rect)
	display_updated.connect(request_render)
	_queue_rebuild()


func _enter_tree() -> void:
	_queue_rebuild()


func setup(card: Card, resource: CardResource) -> void:
	super.setup(card, resource)
	request_render()


func _get_initial_card_size() -> Vector2i:
	var source := get_node_or_null("SubViewport") as SubViewport
	if source:
		return source.size_2d_override if source.size_2d_override != Vector2i.ZERO else source.size
	return super._get_initial_card_size()


func _apply_card_size() -> void:
	# Keep an unpadded viewport at the logical size until the deferred build.
	var source := get_node_or_null("SubViewport") as SubViewport
	if source and card_size != Vector2i.ZERO:
		source.size_2d_override = card_size
		source.size = card_size.max(Vector2i(2, 2))
	super._apply_card_size()
	_queue_rebuild()


func _effect_index(effect: Variant) -> int:
	if effect is int:
		return effect if effect >= 0 and effect < _materials.size() else -1
	if effect is String or effect is StringName:
		# Names must be unique; ambiguous names do not silently select an effect.
		var found := -1
		for i in _materials.size():
			if _materials[i] and _materials[i].resource_name == str(effect):
				if found >= 0 or str(effect).is_empty():
					return -1
				found = i
		return found
	return -1


func _sync_materials() -> void:
	var materials: Array[ShaderMaterial] = []
	var disabled: Dictionary[int, bool] = {}
	for i in shader_stack.size():
		var original := shader_stack[i]
		var previous := i if i < _templates.size() and _templates[i] == original else _templates.find(original)
		if previous >= 0:
			materials.append(_materials[previous])
			if _disabled.has(previous):
				disabled[i] = true
		else:
			materials.append(original if Engine.is_editor_hint() or not original else original.duplicate() as ShaderMaterial)
	_templates = shader_stack.duplicate()
	_materials = materials
	_disabled = disabled


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_pending:
		return
	_rebuild_pending = true
	_rebuild_stack.call_deferred()


func _rebuild_stack() -> void:
	_rebuild_pending = false
	if not is_inside_tree():
		return
	_build_revision += 1
	if is_instance_valid(_output):
		_output.texture = null
	for viewport in _passes:
		remove_child(viewport)
		viewport.queue_free()
	_passes.clear()
	_effect_pass_starts.clear()
	_sync_materials()
	_watch_materials()
	var source := get_node_or_null("SubViewport") as SubViewport
	if not source:
		update_configuration_warnings()
		return
	var logical_size := Vector2(card_size) + Vector2.ONE * effect_padding * 2.0
	_target_size = Vector2i((logical_size * render_scale).ceil()).max(Vector2i(2, 2))
	source.size = _target_size
	# Preserve face anchors/layout dimensions while capturing scaled padding.
	source.size_2d_override = card_size
	source.size_2d_override_stretch = false
	var capture_scale := Vector2(_target_size) / logical_size
	source.canvas_transform = Transform2D(0.0, capture_scale, 0.0, Vector2.ONE * effect_padding * capture_scale)
	source.disable_3d = true
	source.transparent_bg = true
	source.gui_disable_input = true

	var effects: Array[ShaderMaterial] = []
	for i in _materials.size():
		var effect := _materials[i]
		if not _disabled.has(i) and effect and effect.shader and effect.shader.get_mode() == Shader.MODE_CANVAS_ITEM:
			effects.append(effect)
	var input: Texture2D = source.get_texture()
	for i in effects.size():
		if shader_alpha_mode == ShaderAlphaMode.STRAIGHT:
			var conversion := ShaderMaterial.new()
			conversion.shader = STRAIGHT_ALPHA_SHADER
			input = _make_pass(input, conversion).get_texture()
		# This shader consumes the current input unchanged. Its parameter edits
		# invalidate its output and later stages, not its input conversion.
		if not _effect_pass_starts.has(effects[i]):
			_effect_pass_starts[effects[i]] = _passes.size()
		if i < effects.size() - 1:
			input = _make_pass(input, effects[i]).get_texture()
	if not is_instance_valid(_output):
		_output = TextureRect.new()
		_output.name = "ShaderOutput"
		_output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_output, false, Node.INTERNAL_MODE_FRONT)
	_output.texture = input
	if effects.is_empty():
		var premultiplied := CanvasItemMaterial.new()
		premultiplied.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		_output.material = premultiplied
	else:
		_output.material = effects.back()
	_update_output_rect()
	request_render()
	_prime_captures()
	update_configuration_warnings()


func _prime_captures() -> void:
	if not is_visible_in_tree() or DisplayServer.get_name() == "headless":
		return
	# Prime every dependency together rather than waiting for texture visibility
	# to propagate through a long chain over successive frames.
	var revision := _build_revision
	get_node("SubViewport").render_target_update_mode = SubViewport.UPDATE_ONCE
	for viewport in _passes:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if is_inside_tree() and revision == _build_revision:
		request_render()


func _make_pass(input: Texture2D, effect: ShaderMaterial) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "ShaderPass%d" % _passes.size()
	viewport.size = _target_size
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.handle_input_locally = false
	add_child(viewport, false, Node.INTERNAL_MODE_BACK)
	_passes.append(viewport)
	var image := TextureRect.new()
	image.texture = input
	image.material = effect
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	image.size = Vector2(_target_size)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(image)
	return viewport


func _update_output_rect() -> void:
	if is_instance_valid(_output):
		var rect := get_rendered_rect()
		_output.position = rect.position
		_output.size = rect.size


func _update_mode(live: bool) -> SubViewport.UpdateMode:
	if not is_visible_in_tree():
		return SubViewport.UPDATE_DISABLED
	return SubViewport.UPDATE_WHEN_VISIBLE if live else SubViewport.UPDATE_ONCE


func _watch_materials() -> void:
	for effect in _watched_shaders:
		var callback := _on_material_changed.bind(effect)
		if effect.changed.is_connected(callback):
			effect.changed.disconnect(callback)
	for shader in _watched_code:
		if shader.changed.is_connected(_on_shader_changed):
			shader.changed.disconnect(_on_shader_changed)
	_watched_shaders.clear()
	_watched_code.clear()
	for effect in _materials:
		if not effect or _watched_shaders.has(effect):
			continue
		_watched_shaders[effect] = effect.shader
		effect.changed.connect(_on_material_changed.bind(effect))
		if effect.shader and not _watched_code.has(effect.shader):
			_watched_code.append(effect.shader)
			effect.shader.changed.connect(_on_shader_changed)


func _on_material_changed(effect: ShaderMaterial) -> void:
	if effect.shader != _watched_shaders[effect]:
		_queue_rebuild()
		return
	_request_shader_render(effect)


func _on_shader_changed() -> void:
	_queue_rebuild()


func _exit_tree() -> void:
	# Release resource callbacks even when callers retain a material after teardown.
	for effect in _watched_shaders:
		var callback := _on_material_changed.bind(effect)
		if effect.changed.is_connected(callback):
			effect.changed.disconnect(callback)
	for shader in _watched_code:
		if shader.changed.is_connected(_on_shader_changed):
			shader.changed.disconnect(_on_shader_changed)
	_watched_shaders.clear()
	_watched_code.clear()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_node_or_null("SubViewport") is SubViewport:
		warnings.append("Add a child SubViewport containing the card face Controls.")
	var names: Dictionary[String, bool] = {}
	for i in shader_stack.size():
		var effect := shader_stack[i]
		if not effect:
			continue
		if effect.shader and effect.shader.get_mode() != Shader.MODE_CANVAS_ITEM:
			warnings.append("Shader Stack entry %d needs a canvas_item shader; it is skipped." % i)
		if not effect.resource_name.is_empty():
			if names.has(effect.resource_name):
				warnings.append("Shader Stack Resource Name '%s' is duplicated; use unique names or array indices." % effect.resource_name)
			names[effect.resource_name] = true
	return warnings


func get_layout_template() -> PackedScene:
	return load("res://addons/simple_cards/card/card_layout/viewport_card_layout.tscn")
