##Simple card with basic drag and drop functionality.
@icon("res://addons/simple_cards/card/icon_card.png")
class_name Card extends Button

##Emitted when cards is pressed but not dragged
signal card_clicked(card: Card)

##Coefficient used in lerp movenment functions
@export var drag_coef: float = -30
##Max angle the card will swing when moving
@export var max_card_rotation_deg: float = 25
##Distance in px the cursor has to move when card is pressed to trigger dragging
@export var drag_threshold: float = 10

##Center position of the card
var center_pos: Vector2
##Used in the drag functions
var holding: bool = false
##True when card is focused
var focused: bool = false

var _cursor_down_pos: Vector2
var _last_pos: Vector2
var _dragging_offset: Vector2 = Vector2.ZERO
var _released: bool = true

##Used to add custom offsets in [CardHand]
var position_offset: Vector2 = Vector2.ZERO
##Used to add custom offsets in [CardHand]
var rotation_offset: float = 0

var _scale_tween: Tween
var _rotation_tween: Tween
var _pos_tween: Tween

#If true, disables drag function
@export var undraggable: bool = false

##Holds the refrence to the card resource
@export var card_data: CardResource:
	set(value):
		card_data = value
		if _layout:
			_layout.card_resource = value

@export var front_layout_name: StringName  = CG.def_front_layout
@export var back_layout_name: StringName = CG.def_back_layout

var _layout: CardLayout
##Name of current layout. On setter, layout is updated
var layout_name: String = "":
	set(value):
		layout_name = value
		if is_node_ready():
			_setup_layout()

##If true uses front_layout else uses back_layout
var is_front_face: bool = true:
	set(value):
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
	
	if card_data and CG.get_available_layouts().has(card_data.custom_layout_name):
			front_layout_name = card_data.custom_layout_name
	
	
	_setup_layout(true)
	set_card_size()
	set_process(false)


func set_card_size():
	if !_layout: return
	if size != _layout.size:
		size = _layout.size
	self_modulate.a = 0
	center_pos = Vector2(size.x/2 , size.y/2)
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


#region signal connections

func _on_button_down() -> void:
	_released = false
	_cursor_down_pos = CG.get_cursor_position()

func _on_button_up() -> void:
	_released = true
	if holding:
		holding = false 
		set_process(false)
		CG.current_held_item = null
		
		if !_is_owened():
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
			return true
	return false
			
func _on_focus_entered() -> void:
	if _layout:
		await _layout._focus_in()
	focused = true
	set_process(true)

func _on_focus_exited() -> void:
	if _layout:
		await _layout._focus_out()
	focused = false
	if !holding: set_process(false)


func _on_mouse_entered() -> void:
	if !CG.current_held_item:
		grab_focus()

func _on_mouse_exited() -> void:
	if !holding and !CG.current_held_item and has_focus():
		release_focus()

#endregion

#region transform functions

##Tween the scale
func tween_scale(desired_scale: Vector2 = Vector2.ONE, duration: float = 0.2) -> void:
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_scale_tween.tween_property(self, "scale", desired_scale, duration)

##Tween the rotation
func tween_rotation(desired_rotation: float = 0, duration: float = 0.2) -> void:
	if _rotation_tween:
		_rotation_tween.kill()
	_rotation_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_rotation_tween.tween_property(self, "rotation_degrees", desired_rotation, duration)

##Tween the position. If global is true it uses global_position else postion.
func tween_position(desired_position: Vector2, duration: float = 0.2, global: bool = false) -> void:
	if _pos_tween:
		_pos_tween.kill()
	_pos_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if global:
		_pos_tween.tween_property(self, "global_position", desired_position, duration)
	else:
		_pos_tween.tween_property(self, "position", desired_position, duration)

func _set_movement_rotation(delta: float) -> void:
	var desired_rotation: float = clamp(
		(global_position- _last_pos).x,
		-max_card_rotation_deg,
		max_card_rotation_deg)
		
	rotation_degrees = lerp(
		rotation_degrees,
		 desired_rotation,
		 1 - exp(drag_coef *delta))

	_last_pos = global_position 

##Does what it says :[rb]
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

#region layout funcs

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


##Sets the layout of either the front or back layout depanding on the value of is_front
func set_layout(new_layout_name: String, is_front: bool = true) -> void:
	if is_front:
		front_layout_name = new_layout_name
	else:
		back_layout_name = new_layout_name
	_setup_layout()

func get_layout() -> CardLayout:
	return _layout
	
##Refreshes layout
func refresh_layout() -> void:
	if _layout:
		_layout._update_display()

##Flips the card face
func flip() -> void:
	is_front_face = !is_front_face
#endregion

func _is_owened() -> bool:
	var parent = get_parent()
	return parent is CardHand or parent is CardSlot

func _exit_tree() -> void:
	kill_all_tweens()
