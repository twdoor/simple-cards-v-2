## Simple card with basic drag and drop functionality.
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
## Emitted when a tween starts.
signal tween_started(tween_type: String)
## Emitted when a tween completes.
signal tween_completed(tween_type: String)
## Emitted when [member card_data] is set.
signal card_data_changed(new_data: CardResource)
## Emitted when [method move_to] finishes (after tween completes or instant snap).
signal move_completed(card: Card)

## Coefficient used in lerp movement functions.
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

var _scale_tween: Tween
var _rotation_tween: Tween
var _pos_tween: Tween

## If true, disables drag function.
@export var undraggable: bool = false

## Holds the reference to the card resource.
@export var card_data: CardResource:
	set(value):
		card_data = value
		if _layout:
			_layout.card_resource = value
		card_data_changed.emit(value)

@export var front_layout_name: StringName = CG.def_front_layout
@export var back_layout_name: StringName = CG.def_back_layout

var _layout: CardLayout
## Name of current layout. On setter, layout is updated.
var layout_name: String = "":
	set(value):
		layout_name = value
		if is_node_ready():
			_setup_layout()

## If true uses front_layout else uses back_layout.
var is_front_face: bool = true:
	set(value):
		if is_front_face == value: return
		is_front_face = value
		if value: layout_name = front_layout_name
		else: layout_name = back_layout_name


func _init(card_resource: CardResource = null) -> void:
	name = "card_" + str(CG.card_index)
	CG.card_index += 1
	if card_resource:
		card_data = card_resource


func _ready() -> void:
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


func set_card_size():
	if !_layout: return
	if size != _layout.size:
		size = _layout.size
		custom_minimum_size = size

	self_modulate.a = 0
	center_pos = Vector2(size.x / 2, size.y / 2)
	pivot_offset = center_pos


func _process(delta: float) -> void:
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

## Moves this card into a [CardContainer]. Handles reparenting, registration,
## and animation in one call.
## [br][br]
## [param duration]: Tween duration. [code]-1[/code] uses the target's default.
## [code]0[/code] snaps instantly.
## [br][param index]: Insertion index. [code]-1[/code] appends to end.
func move_to(target: CardContainer, duration: float = -1, index: int = -1) -> void:
	if !target: return
	if !target.can_accept_card(self): return
	
	var from_global = global_position

	_reparent_to(target)
	target._register_card(self, index)
	kill_all_tweens()
	global_position = from_global
	
	if target._batch_mode:
		_move_origin = from_global
		return
	
	var dur: float = duration if duration >= 0.0 else target.card_move_duration
	
	var target_pos = target.get_card_target_position(self)
	var target_rot = target.get_card_target_rotation(self)
	
	if dur <= 0.0:
		position = target_pos
		rotation_degrees = target_rot
		move_completed.emit(self)
	else:
		tween_position(target_pos, dur)
		rotation_degrees = target_rot
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

func _check_for_hold() -> bool:
	if !_released and !holding:
		var current_cursor_pos = CG.get_cursor_position()
		var drag_distance = _cursor_down_pos.distance_to(current_cursor_pos)
		
		if drag_distance > drag_threshold and !undraggable:
			rotation = 0
			holding = true
			_dragging_offset = center_pos
			CG.current_held_item = self
			drag_started.emit(self)
			return true
	return false

func _on_focus_entered() -> void:
	if _layout:
		await _layout._focus_in()
	focused = true
	card_focused.emit()
	set_process(true)

func _on_focus_exited() -> void:
	if _layout:
		await _layout._focus_out()
	focused = false
	card_unfocused.emit()
	if !holding: set_process(false)


func _on_mouse_entered() -> void:
	card_hovered.emit()
	if !CG.current_held_item:
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
	tween_started.emit("scale")
	_scale_tween.finished.connect(func(): tween_completed.emit("scale"))

## Tween the rotation.
func tween_rotation(desired_rotation: float = 0, duration: float = 0.2) -> void:
	if _rotation_tween:
		_rotation_tween.kill()
	_rotation_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_rotation_tween.tween_property(self, "rotation_degrees", desired_rotation, duration)
	tween_started.emit("rotation")
	_rotation_tween.finished.connect(func(): tween_completed.emit("rotation"))

## Tween the position. If [param global] is true, tweens [code]global_position[/code].
func tween_position(desired_position: Vector2, duration: float = .3, global: bool = false) -> void:
	if _pos_tween:
		_pos_tween.kill()
	_pos_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_started.emit("position")
	if global:
		_pos_tween.tween_property(self, "global_position", desired_position, duration)
	else:
		_pos_tween.tween_property(self, "position", desired_position, duration)
	_pos_tween.finished.connect(func(): tween_completed.emit("position"))

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
	if _layout:
		if !no_animations:
			await _layout._flip_out()
		_layout.queue_free()
		_layout = null

	if is_front_face:
		_layout = CG.create_layout(front_layout_name)
	else:
		_layout = CG.create_layout(back_layout_name)
	
	if not _layout:
		push_error("Card: Failed to create layout")
		return
	
	add_child(_layout)
	_layout.setup(self, card_data)
	if !no_animations:
		await _layout._flip_in()
	
	_layout.anchors_preset = Control.PRESET_FULL_RECT
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	_layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_layout.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	
	layout_changed.emit(layout_name)


## Sets the layout of either the front or back face.
func set_layout(new_layout_name: String, is_front: bool = true) -> void:
	if is_front:
		front_layout_name = new_layout_name
	else:
		back_layout_name = new_layout_name
	_setup_layout()

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

## Called at the end of [method _ready]. Override for subclass setup.
func _card_ready() -> void:
	pass


func _exit_tree() -> void:
	kill_all_tweens()
