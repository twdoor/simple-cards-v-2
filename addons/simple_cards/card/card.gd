@icon("res://addons/simple_cards/card/icon_card.png")
class_name Card extends Button

signal card_clicked(card: Card)

const drag_coef: float = -30
const max_card_rotation_deg: float = 25
const drag_threshold: float = 10

var cursol_down_pos: Vector2
var center_pos: Vector2
var last_pos: Vector2
var holding: bool = false
var dragging_offset: Vector2 = Vector2.ZERO
var released: bool = true
var focused: bool = false

var position_offset: Vector2 = Vector2.ZERO
var rotation_offset: float = 0

@export var card_data: CardResource:
	set(value):
		card_data = value
		if _layout:
			_layout.card_resource = value

@export var front_layout_name: StringName  = CG.def_front_layout
@export var back_layout_name: StringName = CG.def_back_layout

var _layout: CardLayout
var layout_name: String = "":
	set(value):
		layout_name = value
		if is_node_ready():
			_setup_layout()


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
		if CG.get_available_layouts().has(card_data.custom_layout_name):
			front_layout_name = card_data.custom_layout_name


func _ready() -> void:
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	_setup_layout()
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
		CG.get_cursor_position() - dragging_offset, 
		1 - exp(delta * drag_coef))
	_set_movement_rotation(delta)


#region signal connections

func _on_button_down() -> void:
	released = false
	cursol_down_pos = CG.get_cursor_position()

func _on_button_up() -> void:
	released = true
	if holding:
		holding = false 
		CG.current_held_item = null
	else:
		card_clicked.emit(self)

func _check_for_hold() -> bool:
	if !released and !holding:
		var current_cursor_pos = CG.get_cursor_position()
		var drag_distance = cursol_down_pos.distance_to(current_cursor_pos)
		
		if drag_distance > drag_threshold:
			rotation = 0
			holding = true
			dragging_offset = center_pos
			CG.current_held_item = self
			return true
	return false
			
func _on_focus_entered() -> void:
	_set_scale(Vector2.ONE * 1.2)
	focused = true

func _on_focus_exited() -> void:
	_set_scale()
	focused = false


func _on_mouse_entered() -> void:
	if !CG.current_held_item:
		grab_focus()

func _on_mouse_exited() -> void: 
	if !holding and !CG.current_held_item:
		get_viewport().gui_release_focus()

#endregion

#region transform functions

func _set_scale(desired_scale: Vector2 = Vector2.ONE, duration: float = 0.2) -> void:
	var scale_tween: Tween
	if scale_tween:
		scale_tween.kill()
	scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	scale_tween.tween_property(self, "scale", desired_scale, duration)


func _set_rotation(desired_rotation: float = 0, duration: float = 0.2) -> void:
	var rotation_tween: Tween
	if rotation_tween:
		rotation_tween.kill()
	rotation_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	rotation_tween.tween_property(self, "rotation_degrees", desired_rotation, duration)

func _set_position(desired_position: Vector2, duration: float = 0.2, global: bool = false) -> void:
	var pos_tween: Tween
	if pos_tween:
		pos_tween.kill()
	pos_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if global:
		pos_tween.tween_property(self, "global_position", desired_position, duration)
	else:
		pos_tween.tween_property(self, "position", desired_position, duration)

func _set_movement_rotation(delta: float) -> void:
	var desired_rotation: float = clamp(
		(global_position- last_pos).x,
		-max_card_rotation_deg,
		max_card_rotation_deg)
		
	rotation_degrees = lerp(
		rotation_degrees,
		 desired_rotation,
		 1 - exp(drag_coef *delta))

	last_pos = global_position 

#endregion

#region layout funcs

func _setup_layout() -> void:
	if _layout:
		_layout._flip_out()
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
	_layout._flip_in()
	
	_layout.anchors_preset = Control.PRESET_FULL_RECT
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	_layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_layout.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED



func set_layout(new_layout_name: String, is_front: bool = true) -> void:
	if is_front:
		front_layout_name = new_layout_name
	else:
		back_layout_name = new_layout_name


func refresh_layout() -> void:
	if _layout:
		_layout._update_display()


func flip() -> void:
	is_front_face = !is_front_face
#endregion
