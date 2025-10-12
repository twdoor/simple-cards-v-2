@tool @icon("uid://1g0jb8x0i516")
class_name CardHand extends Control


enum _HandShape {
	##Line
	LINE,
	##Arc
	ARC,
}

##Shape of card spread. Its either a line shape or a circle arc
@export var shape: _HandShape = _HandShape.ARC:
	set(value):
		shape = value
		notify_property_list_changed()
		_arrange_cards()
##The maximum distance between the cards
@export var card_spacing: float = 20.0:
	set(value):
		card_spacing = value
		_arrange_cards()
##If [code]true[/code] the hand will reorder after and change in the cards.
@export var enable_reordering: bool = true
##Maximum number of cards allowed in the hand. Set to -1 for no limit.
@export var max_hand_size: int = -1


@export_group("Arc Settings")
@export var arc_radius: float = 400.0:
	set(value):
		arc_radius = value
		_arrange_cards()
@export_range(0.0, 360.0, 1) var arc_angle: float = 60.0:
	set(value):
		arc_angle = value
		_arrange_cards()
@export_range(0.0, 360.0, 5) var arc_orientation: float = 270.0:
	set(value):
		arc_orientation = value
		_arrange_cards()


@export_group("Line Settings")
@export var line_rotation: float = 0.0:
	set(value):
		line_rotation = value
		_arrange_cards()
@export var max_width: float = 600.0:
	set(value):
		max_width = value
		_arrange_cards()


var cards: Array[Card] = []
var card_positions: Array[Vector2] = []
var dragged_card: Card = null
var drag_start_index: int = -1

func _ready() -> void:
	var children = get_children()
	for child in children:
		if child is Card:
			add_card(child)
	CG.dropped_card.connect(_on_card_dropped)
	CG.holding_card.connect(_on_holding_card)

func _process(_delta: float) -> void:
	if enable_reordering and dragged_card:
		_update_card_reordering()


func _validate_property(property: Dictionary) -> void:
	if property.name in ["arc_radius", "arc_angle", "arc_orientation"]:
		if shape != _HandShape.ARC:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name in ["line_rotation", "max_width"]:
		if shape != _HandShape.LINE:
			property.usage = PROPERTY_USAGE_NO_EDITOR


##Adds a card to the hand. The card get reparented as a child of the hand. Returns [code]true[/code] if successful.
func add_card(card: Card) -> bool:
	if max_hand_size >= 0 and cards.size() >= max_hand_size:
		return false
	
	if card.get_parent() != self:
		if card.get_parent() is CardHand:
			card.get_parent().remove_card(card)
		elif card.get_parent():
			card.get_parent().remove_child(card)
		add_child(card)
	
	if not cards.has(card):
		cards.append(card)
		_connect_card_signals(card)
	
	_arrange_cards()
	return true


##Removes specific card from hand. [color=red]DOES NOT FREE THE CARD[/color]
func remove_card(card: Card) -> void:
	if cards.has(card):
		_disconnect_card_signals(card)
		cards.erase(card)
		if card.get_parent() == self:
			remove_child(card)
		_arrange_cards()


##Empties hand. [color=red]DOES NOT FREE THE CARD[/color]
func clear_hand() -> void:
	for card in cards:
		_disconnect_card_signals(card)
		if card.get_parent() == self:
			remove_child(card)
	cards.clear()
	card_positions.clear()


#region Signal Management

func _connect_card_signals(card: Card) -> void:
	if not card.focus_entered.is_connected(_on_card_focused):
		card.focus_entered.connect(_on_card_focused.bind(card))
	if not card.focus_exited.is_connected(_on_card_unfocused):
		card.focus_exited.connect(_on_card_unfocused.bind(card))
	if not card.card_clicked.is_connected(_handle_clicked_card):
		card.card_clicked.connect(_handle_clicked_card)


func _disconnect_card_signals(card: Card) -> void:
	if card.focus_entered.is_connected(_on_card_focused):
		card.focus_entered.disconnect(_on_card_focused)
	if card.focus_exited.is_connected(_on_card_unfocused):
		card.focus_exited.disconnect(_on_card_unfocused)
	if card.card_clicked.is_connected(_handle_clicked_card):
		card.card_clicked.disconnect(_handle_clicked_card)


func _on_card_focused(card: Card) -> void:
	var focus_z = 900
	card.z_index = focus_z


func _on_card_unfocused(card: Card) -> void:
	_update_z_indices()


##Used when a card fron hand is clicked. [color=red]Overwrite[/color] to implement card action.
func _handle_clicked_card(card: Card) -> void:
	print("%s: %s was clicked" %[self.name, card.name])


func _on_card_dropped() -> void:
	_arrange_cards()
	dragged_card = null


func _on_holding_card(card: Card) -> void:
	dragged_card = card
	drag_start_index = get_card_index(card)

#endregion


func _update_card_reordering() -> void:
	if not dragged_card or drag_start_index == -1:
		return
	
	if not dragged_card.holding:
		return
	
	var cursor_pos = get_local_mouse_position()
	var closest_index = _find_closest_card_position(cursor_pos)
	
	if closest_index != -1 and closest_index != drag_start_index:
		cards.remove_at(drag_start_index)
		cards.insert(closest_index, dragged_card)
		drag_start_index = closest_index
		
		_arrange_cards_except_dragged()


func _find_closest_card_position(cursor_pos: Vector2) -> int:
	if card_positions.is_empty():
		return -1
	
	var closest_index = 0
	var closest_distance = cursor_pos.distance_to(card_positions[0])
	
	for i in range(1, card_positions.size()):
		var distance = cursor_pos.distance_to(card_positions[i])
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i
	
	return closest_index


#region Arrangement Management

func _arrange_cards() -> void:
	if cards.is_empty():
		return
	
	card_positions.clear()
	
	match shape:
		_HandShape.LINE:
			_arrange_line()
		_HandShape.ARC:
			_arrange_arc()
	
	_update_z_indices()
	_update_focus_chain()

func _arrange_cards_except_dragged() -> void:
	if cards.is_empty():
		return
	
	card_positions.clear()
	
	match shape:
		_HandShape.LINE:
			_arrange_line(true)
		_HandShape.ARC:
			_arrange_arc(true)
	
	_update_z_indices()
	_update_focus_chain()

func _arrange_line(skip_dragged: bool = false) -> void:
	var card_count = cards.size()
	if card_count == 0:
		return
	
	var card_size = cards[0].size
	var total_width = (card_count - 1) * card_spacing + card_size.x
	var actual_spacing = card_spacing
	if total_width > max_width:
		actual_spacing = (max_width - card_size.x) / max(1, card_count - 1)
	
	var start_x = -(card_count - 1) * actual_spacing / 2.0
	
	for i in card_count:
		var card = cards[i]
		var x_pos = start_x + i * actual_spacing
		var y_pos = 0.0
		var rotated_pos = Vector2(x_pos, y_pos).rotated(deg_to_rad(line_rotation))
		var final_pos = rotated_pos - card.pivot_offset
		
		card_positions.append(final_pos + card.pivot_offset)
		if skip_dragged and card == dragged_card:
			continue
		
		var pos = final_pos + (card.position_offset.rotated(deg_to_rad(line_rotation)))
		card._set_position(pos + global_position, .2 , true)
		card.rotation = deg_to_rad(line_rotation) + card.rotation_offset


func _arrange_arc(skip_dragged: bool = false) -> void:
	var card_count = cards.size()
	if card_count == 0:
		return
	
	var angle_between = 0.0
	if card_count > 1:
		var arc_length = (card_count - 1) * card_spacing
		var max_angle = min(arc_angle, rad_to_deg(arc_length / arc_radius))
		angle_between = max_angle / max(1, card_count - 1)
	
	var start_angle = arc_orientation - (angle_between * (card_count - 1)) / 2.0

	for i in card_count:
		var card = cards[i]
		var current_angle = start_angle + i * angle_between
		var angle_rad = deg_to_rad(current_angle)
		var x = arc_radius * cos(angle_rad)
		var y = arc_radius * sin(angle_rad)
		
		var final_pos = Vector2(x, y) - card.pivot_offset
		card_positions.append(Vector2(x, y))
		if skip_dragged and card == dragged_card:
			continue
		
		var pos = final_pos + (card.position_offset.rotated(angle_rad + deg_to_rad(90)))  
		card._set_position(pos)
		card.rotation = angle_rad + deg_to_rad(90) + card.rotation_offset

#endregion

func _update_z_indices() -> void:
	for i in cards.size():
		if cards[i] == dragged_card:
			cards[i].z_index = 1000
		else:
			cards[i].z_index = i


func _update_focus_chain() -> void:
	var card_count = cards.size()
	if card_count == 0:
		return
	
	for i in card_count:
		var card = cards[i]
		
		var prev_index = (i - 1 + card_count) % card_count
		card.focus_neighbor_left = card.get_path_to(cards[prev_index])
		card.focus_previous = card.get_path_to(cards[prev_index])
		
		var next_index = (i + 1) % card_count
		card.focus_neighbor_right = card.get_path_to(cards[next_index])
		card.focus_next = card.get_path_to(cards[next_index])


##Helper function to add a great number of cards into the hand. Returns the number of cards successfully added.
func add_cards(card_array: Array[Card]) -> int:
	var added_count = 0
	for card in card_array:
		# Check if hand is full
		if max_hand_size >= 0 and cards.size() >= max_hand_size:
			break
		
		if card.get_parent() != self:
			if card.get_parent() is CardHand:
				card.get_parent().remove_card(card)
			elif card.get_parent():
				card.get_parent().remove_child(card)
			add_child(card)
		
		if not cards.has(card):
			cards.append(card)
			_connect_card_signals(card)
			added_count += 1
	
	_arrange_cards()
	return added_count

##Helper function to get a card by its position index in the hand.
func get_card(index: int) -> Card:
	if index >= 0 and index < cards.size():
		return cards[index]
	return null

##Returns the number of cards in the hand.
func get_card_count() -> int:
	return cards.size()

##Helper function to get the index of a [Card]. Returns the index value as an [int].
func get_card_index(card: Card) -> int:
	return cards.find(card)

##Returns [code]true[/code] if the hand is full (has reached max_hand_size).
func is_hand_full() -> bool:
	if max_hand_size < 0:
		return false
	return cards.size() >= max_hand_size

##Returns the number of remaining slots in the hand. Returns -1 if there is no limit.
func get_remaining_space() -> int:
	if max_hand_size < 0:
		return -1
	return max(0, max_hand_size - cards.size())
