## Simple card with basic drag and drop functionality.
@tool
@icon("res://addons/simple_cards/card/icon_card.png")
class_name Card extends Button

## Emitted when card is pressed but not dragged.
signal card_clicked(card: Card)
## Emitted when mouse enters card area.
signal card_hovered()
## Emitted when mouse exits card area.
signal card_unhovered()
## Emitted when drag threshold exceeded.
signal drag_started(card: Card)
## Emitted when drag completes.
signal drag_ended(card: Card)
## Emitted when [method flip] is called.
signal card_flipped(is_front_face: bool)
## Emitted when card gains focus.
signal card_focused()
## Emitted when card loses focus.
signal card_unfocused()
## Emitted when layout switches.
signal layout_changed(layout_name: StringName)
## Emitted when [member card_data] is set.
signal card_data_changed(new_data: CardResource)
## Emitted when [method move_to] finishes (after tween completes or instant snap).
signal move_completed(card: Card)

## Default card size used for editor preview when no layout is loaded.
const EDITOR_DEFAULT_SIZE := Vector2(80, 112)

## Smoothing coefficient for drag movement. Uses exponential interpolation.
## [br]Values closer to [code]0[/code] feel floatier, larger negative values feel snappier.
## [br]Default [code]-30[/code] gives a responsive but smooth follow.
@export var drag_coef: float = -30
## Max angle the card will swing when moving.
@export var max_card_rotation_deg: float = 25
## Distance in px the cursor must move when pressed to trigger dragging.
@export var drag_threshold: float = 10

## Center position of the card.
var center_pos: Vector2
## True when the card is being dragged.
var holding: bool = false
## True when the card has focus.
var focused: bool = false

var _cursor_down_pos: Vector2
var _last_pos: Vector2
var _dragging_offset: Vector2 = Vector2.ZERO
var _released: bool = true

## Used to add custom offsets in containers (e.g. selected bump in a hand).
var position_offset: Vector2 = Vector2.ZERO
## Used to add custom rotation offsets in containers.
var rotation_offset: float = 0
## Stored origin global position for batch moves. Reset after tween starts.
var _move_origin: Vector2 = Vector2.INF
## Stored MoveConfig for batch moves. Reset after settle.
var _move_config: MoveConfig

var _scale_tween: Tween
var _rotation_tween: Tween
var _pos_tween: Tween
var _layout_switching: bool = false
var _pending_layout_switch: bool = false

## If true, disables drag function.
@export var undraggable: bool = false

## Holds the reference to the card resource.
@export var card_data: CardResource:
	set(value):
		card_data = value
		if _layout:
			_layout.card_resource = value
		card_data_changed.emit(value)
		if Engine.is_editor_hint() and is_node_ready():
			_editor_setup_layout()

## Front face layout ID. Resolved to [member CardGlobal.def_front_layout] if empty at runtime.
@export var front_layout_name: StringName = &"":
	set(value):
		front_layout_name = value
		if Engine.is_editor_hint() and is_node_ready():
			_editor_setup_layout()

## Back face layout ID. Resolved to [member CardGlobal.def_back_layout] if empty at runtime.
@export var back_layout_name: StringName = &"":
	set(value):
		back_layout_name = value

var _layout: CardLayout
## Requested layout ID for the active face. On setter, layout is updated.
var layout_name: StringName = &"":
	set(value):
		layout_name = value
		if !Engine.is_editor_hint() and is_node_ready():
			_setup_layout()

## Resolved layout ID currently displayed after fallback rules are applied.
var current_layout_name: StringName = &""

## If true uses front_layout else uses back_layout.
var is_front_face: bool = true:
	set(value):
		if is_front_face == value: return
		is_front_face = value
		if value: layout_name = front_layout_name
		else: layout_name = back_layout_name


func _validate_property(property: Dictionary) -> void:
	if property.name == "front_layout_name" or property.name == "back_layout_name":
		var options: String = ",".join(LayoutID.get_all())
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = options

func _init(card_resource: CardResource = null) -> void:
	if Engine.is_editor_hint(): return
	name = "card_" + str(CG.card_index)
	CG.card_index += 1
	if card_resource:
		card_data = card_resource


func _enter_tree() -> void:
	if Engine.is_editor_hint() and is_node_ready() and not _layout:
		_editor_setup_layout()

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_ready()
		return

	# Resolve empty layout names to CG defaults at runtime.
	if front_layout_name.is_empty():
		front_layout_name = CG.def_front_layout
	if back_layout_name.is_empty():
		back_layout_name = CG.def_back_layout

	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	if card_data and CG.get_available_layouts().has(card_data.front_layout_name):
		front_layout_name = card_data.front_layout_name
	if card_data and CG.get_available_layouts().has(card_data.back_layout_name):
		back_layout_name = card_data.back_layout_name

	_setup_layout(true)
	set_card_size()
	set_process(false)
	_card_ready()


#region Editor

## Editor-only: sets up the card with a static layout preview.
func _editor_ready() -> void:
	set_process(false)
	_editor_setup_layout()

## Editor-only: (re)loads the layout scene and adds it as a child.
## Called on ready, and when card_data or front_layout_name changes in inspector.
func _editor_setup_layout() -> void:
	if _layout:
		if _layout.card_size_changed.is_connected(_on_layout_size_changed):
			_layout.card_size_changed.disconnect(_on_layout_size_changed)
		_layout.queue_free()
		_layout = null

	var layout_id: StringName = front_layout_name
	if card_data and !card_data.front_layout_name.is_empty():
		layout_id = card_data.front_layout_name

	_layout = _editor_create_layout(layout_id)
	if not _layout:
		size = EDITOR_DEFAULT_SIZE
		custom_minimum_size = EDITOR_DEFAULT_SIZE
		pivot_offset = EDITOR_DEFAULT_SIZE / 2.0
		return

	# Read card size — prefer layout.card_size, fall back to SubViewport.size.
	var card_size := EDITOR_DEFAULT_SIZE
	if _layout.card_size != Vector2i.ZERO:
		card_size = Vector2(_layout.card_size)
	else:
		var sub_vp = _layout.get_node_or_null("SubViewport")
		if sub_vp and sub_vp is SubViewport:
			var vp_size := Vector2(sub_vp.size)
			if vp_size != Vector2.ZERO:
				card_size = vp_size

	size = card_size
	custom_minimum_size = card_size
	pivot_offset = size / 2.0
	self_modulate.a = 0

	add_child(_layout)
	_layout.card_size_changed.connect(_on_layout_size_changed)
	_layout.anchors_preset = Control.PRESET_FULL_RECT
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Only call setup() if the layout script is @tool — non-@tool scripts become
	# placeholder instances in the editor and cannot receive method calls.
	# Placeholder layouts still render their baked-in scene visuals (panels, borders, etc.).
	var script = _layout.get_script()
	if script and script.is_tool():
		_layout.setup(self, card_data)


## Editor-only: creates a CardLayout by reading layout_cache.json directly,
## bypassing CG (which may not be available in editor context).
## Reuses LayoutCache (already @tool) to avoid duplicating JSON logic.
func _editor_create_layout(layout_id: StringName) -> CardLayout:
	var cache := LayoutCache.new()
	var path := cache.get_layout_path(layout_id, LayoutID.DEFAULT)

	if not ResourceLoader.exists(path):
		push_warning("Card: Editor layout not found at " + path)
		return null

	var scene = load(path)
	if not scene:
		return null

	var instance = scene.instantiate()
	if not instance is CardLayout:
		instance.queue_free()
		return null

	return instance

#endregion


func set_card_size():
	if !_layout: return
	var new_size = Vector2(_layout.card_size) if _layout.card_size != Vector2i.ZERO else _layout.size
	if size != new_size:
		size = new_size
		custom_minimum_size = size

	self_modulate.a = 0
	center_pos = size / 2.0
	pivot_offset = center_pos


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	_drag(delta)
	_check_for_hold()


func _drag(delta: float) -> void:
	if !holding: return

	global_position = lerp(
		global_position,
		CG.get_cursor_position() - _dragging_offset,
		1 - exp(delta * drag_coef))
	_set_movement_rotation(delta)


#region Movement

## Configuration object for [method move_to] and bulk move operations.
## Bundles movement parameters into a single reusable object.
## [br][br]
## [b]position_callable[/b]: Override the default tween-based movement.
## Signature: [code](card: Card, target_pos: Vector2, duration: float) -> void[/code].
class MoveConfig:
	## Tween duration. [code]-1[/code] uses the target container's default.
	## [code]0[/code] snaps instantly.
	var duration: float = -1
	## Insertion index. [code]-1[/code] appends to end.
	var index: int = -1
	## Delay between each card in bulk operations.
	var stagger: float = 0.0
	## If [code]true[/code], defers layout computation until all cards are placed.
	var batch: bool = false
	## Custom movement callable. Signature: [code](card: Card, target_pos: Vector2, duration: float) -> void[/code].
	var position_callable: Callable

	func _init(p_duration: float = -1, p_index: int = -1, p_stagger: float = 0.0, p_batch: bool = false) -> void:
		duration = p_duration
		index = p_index
		stagger = p_stagger
		batch = p_batch


## Moves this card into a [CardContainer]. Handles reparenting, registration,
## and animation in one call.
func move_to(target: CardContainer, config: MoveConfig = null) -> void:
	if !target: return
	if !target.can_accept_card(self): return
	if !config: config = MoveConfig.new()

	var from_global = global_position

	_reparent_to(target)
	target._register_card(self, config.index)
	kill_all_tweens()
	global_position = from_global

	if target._batch_mode:
		_move_origin = from_global
		_move_config = config
		return

	var dur: float = config.duration if config.duration >= 0.0 else target.card_move_duration

	var target_pos = target.get_card_target_position(self)
	var target_rot = target.get_card_target_rotation(self)

	if dur <= 0.0:
		position = target_pos
		rotation_degrees = target_rot
		move_completed.emit(self)
	else:
		_apply_move(target, dur, config)
		rotation_degrees = target_rot
	target._update_card_layer_order()


## Applies movement using the config's position_callable or the default tween.
## Custom callables are responsible for emitting [signal move_completed] when done.
func _apply_move(target: CardContainer, dur: float, config: MoveConfig) -> void:
	var target_pos := target.get_card_target_position(self)
	if config.position_callable.is_valid():
		config.position_callable.call(self, target_pos, dur)
	else:
		tween_position(target_pos, dur)
		if _pos_tween:
			_pos_tween.finished.connect(func(): move_completed.emit(self), CONNECT_ONE_SHOT)


## Reparents this card to [param new_parent], preserving global position.
func _reparent_to(new_parent: Node) -> void:
	kill_all_tweens()
	var current = get_parent()
	if current == new_parent: return
	if current:
		reparent(new_parent, true)
	else:
		var stored_global = global_position
		new_parent.add_child(self)
		global_position = stored_global


## Returns [code]true[/code] if this card is inside a [CardContainer].
func _is_owned() -> bool:
	return get_parent() is CardContainer

#endregion

#region Signal Connections

func _on_button_down() -> void:
	_released = false
	_cursor_down_pos = CG.get_cursor_position()

func _on_button_up() -> void:
	_released = true
	if holding:
		holding = false
		set_process(false)
		CG.current_held_item = null
		drag_ended.emit(self)

		if !_is_owned():
			tween_rotation()
			tween_scale()

		_on_mouse_exited()
		_on_focus_exited()
		if is_hovered():
			_on_mouse_entered()
		if has_focus():
			_on_focus_entered()

	else:
		card_clicked.emit(self)

func _check_for_hold() -> void:
	if !_released and !holding:
		var current_cursor_pos = CG.get_cursor_position()
		var drag_distance = _cursor_down_pos.distance_to(current_cursor_pos)

		if drag_distance > drag_threshold and !undraggable:
			rotation = 0
			holding = true
			_dragging_offset = center_pos
			CG.current_held_item = self
			drag_started.emit(self)

func _on_focus_entered() -> void:
	if _layout:
		await _layout._focus_in()
	if !is_instance_valid(self) or !is_inside_tree(): return
	focused = true
	card_focused.emit()
	set_process(true)

func _on_focus_exited() -> void:
	if _layout:
		await _layout._focus_out()
	if !is_instance_valid(self) or !is_inside_tree(): return
	focused = false
	card_unfocused.emit()
	if !holding: set_process(false)


func _on_layout_size_changed(new_size: Vector2i) -> void:
	if new_size == Vector2i.ZERO: return
	size = Vector2(new_size)
	custom_minimum_size = size
	center_pos = size / 2.0
	pivot_offset = center_pos
	var parent = get_parent()
	if parent is CardContainer:
		parent.arrange()

func _on_mouse_entered() -> void:
	card_hovered.emit()
	if !CG.current_held_item and focus_mode != Control.FOCUS_NONE:
		grab_focus()

func _on_mouse_exited() -> void:
	card_unhovered.emit()
	if !holding and !CG.current_held_item and has_focus():
		release_focus()

#endregion

#region Transform Functions

## Tween the scale.
func tween_scale(desired_scale: Vector2 = Vector2.ONE, duration: float = 0.2) -> void:
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_scale_tween.tween_property(self, "scale", desired_scale, duration)

## Tween the rotation.
func tween_rotation(desired_rotation: float = 0, duration: float = 0.2) -> void:
	if _rotation_tween:
		_rotation_tween.kill()
	_rotation_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_rotation_tween.tween_property(self, "rotation_degrees", desired_rotation, duration)

## Tween the position. If [param global] is true, tweens [code]global_position[/code].
func tween_position(desired_position: Vector2, duration: float = .3, global: bool = false) -> void:
	if _pos_tween:
		_pos_tween.kill()
	_pos_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if global:
		_pos_tween.tween_property(self, "global_position", desired_position, duration)
	else:
		_pos_tween.tween_property(self, "position", desired_position, duration)

func _set_movement_rotation(delta: float) -> void:
	var desired_rotation: float = clamp(
		(global_position - _last_pos).x,
		-max_card_rotation_deg,
		max_card_rotation_deg)

	rotation_degrees = lerp(
		rotation_degrees,
		 desired_rotation,
		 1 - exp(drag_coef * delta))

	_last_pos = global_position

## Kills all active tweens on this card.
func kill_all_tweens() -> void:
	if _scale_tween:
		_scale_tween.kill()
		_scale_tween = null
	if _rotation_tween:
		_rotation_tween.kill()
		_rotation_tween = null
	if _pos_tween:
		_pos_tween.kill()
		_pos_tween = null

#endregion

#region Layout Functions

func _setup_layout(no_animations: bool = false) -> void:
	if _layout_switching:
		_pending_layout_switch = true
		return
	_layout_switching = true

	if _layout:
		if _layout.card_size_changed.is_connected(_on_layout_size_changed):
			_layout.card_size_changed.disconnect(_on_layout_size_changed)
		if !no_animations:
			await _layout._flip_out()
		if !is_inside_tree():
			_layout_switching = false
			_pending_layout_switch = false
			return
		_layout.queue_free()
		_layout = null

	var requested_layout := _get_requested_layout_id()
	var fallback_layout := CG.def_front_layout if is_front_face else CG.def_back_layout
	current_layout_name = CG.resolve_layout_id(requested_layout, fallback_layout)
	_layout = CG.create_layout(requested_layout, fallback_layout)

	if not _layout:
		push_error("Card: Failed to create layout")
		_layout_switching = false
		_pending_layout_switch = false
		return

	add_child(_layout)
	_layout.card_size_changed.connect(_on_layout_size_changed)
	_layout.setup(self, card_data)
	if !no_animations:
		await _layout._flip_in()
	if !is_inside_tree():
		_layout_switching = false
		_pending_layout_switch = false
		return

	_layout.anchors_preset = Control.PRESET_FULL_RECT
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_layout.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED

	_layout_switching = false
	layout_changed.emit(current_layout_name)

	if _pending_layout_switch:
		_pending_layout_switch = false
		_setup_layout()


## Sets the layout of either the front or back face.
func set_layout(new_layout_name: String, is_front: bool = true) -> void:
	if is_front:
		front_layout_name = StringName(new_layout_name)
	else:
		back_layout_name = StringName(new_layout_name)
	if Engine.is_editor_hint(): return
	if is_front == is_front_face:
		layout_name = StringName(new_layout_name)
		return

func get_layout() -> CardLayout:
	return _layout

## Refreshes layout display.
func refresh_layout() -> void:
	if _layout:
		_layout._update_display()

## Flips the card face.
func flip() -> void:
	is_front_face = !is_front_face
	card_flipped.emit(is_front_face)

#endregion


func _get_requested_layout_id() -> StringName:
	if is_front_face:
		return front_layout_name
	return back_layout_name

## Called at the end of [method _ready]. Override for subclass setup.
func _card_ready() -> void:
	pass


func _exit_tree() -> void:
	if _layout and _layout.card_size_changed.is_connected(_on_layout_size_changed):
		_layout.card_size_changed.disconnect(_on_layout_size_changed)
	if Engine.is_editor_hint():
		if _layout:
			_layout.queue_free()
			_layout = null
		return
	kill_all_tweens()
