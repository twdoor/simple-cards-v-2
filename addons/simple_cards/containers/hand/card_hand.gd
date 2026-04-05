## A card container that arranges cards in a visual hand layout.
##
## Provides drag-based reordering, focus chain management, and z-index stacking.
## For game-specific behavior (selection, validation, multi-drag), extend this class
## and override [method _on_card_added], [method _on_card_removed], or
## [method _handle_clicked_card].
@icon("uid://b5yeseh7avtmy")
class_name CardHand extends CardContainer


#region Signals

## Emitted when cards are reordered.
signal cards_reordered(new_order: Array[Card])
## Emitted when a specific card changes position in hand.
signal card_position_changed(card: Card, old_index: int, new_index: int)

#endregion


#region Exports

## If [code]true[/code] the hand will reorder cards during drag.
@export var enable_reordering: bool = true
## If [code]true[/code], dragging a card also drags all cards below it as a visual stack.
## Disables single-card reordering while followers are active.
## Override [method _get_drag_companions] to control which cards become followers.
@export var enable_pile_drag: bool = false

#endregion


var _dragged_card: Card = null
var _drag_start_index: int = -1
var _last_reorder_index: int = -1
var _original_drag_index: int = -1
var _drag_followers: Array[Card] = []
var _follower_shape_offsets: Array[Vector2] = []


#region Setup

func _container_ready() -> void:
	if !shape:
		shape = LineShape.new()
		push_warning("CardHand: No shape selected, using default LineShape")

	CG.dropped_card.connect(_on_card_dropped)
	CG.holding_card.connect(_on_holding_card)

	for child in get_children():
		if child is Card and !cards.has(child):
			cards.append(child)
			_connect_card_signals(child)

	if !cards.is_empty():
		arrange(0)

	set_process(false)


func _exit_tree() -> void:
	if CG.dropped_card.is_connected(_on_card_dropped):
		CG.dropped_card.disconnect(_on_card_dropped)
	if CG.holding_card.is_connected(_on_holding_card):
		CG.holding_card.disconnect(_on_holding_card)

#endregion


#region Layout Overrides

func _compute_layout() -> void:
	super._compute_layout()
	if !cards.is_empty():
		_update_z_indices()
		_update_focus_chain()


func _settle_card(card: Card, duration: float) -> void:
	if card == _dragged_card: return
	if _drag_followers.has(card): return
	super._settle_card(card, duration)

#endregion


#region Reordering

func _process(delta: float) -> void:
	if _drag_followers.is_empty():
		_update_card_reordering()
	_update_drag_followers(delta)


func _update_card_reordering() -> void:
	if not _dragged_card or _drag_start_index == -1:
		return
	if not _dragged_card.holding:
		return

	var cursor_pos = CG.get_cursor_position()
	var new_index = _find_insertion_index(cursor_pos)

	if new_index != -1 and new_index != _drag_start_index:
		cards.remove_at(_drag_start_index)
		cards.insert(new_index, _dragged_card)

		card_position_changed.emit(_dragged_card, _drag_start_index, new_index)

		_drag_start_index = new_index
		_last_reorder_index = new_index

		_compute_layout()
		for card in cards:
			if card == _dragged_card: continue
			if card.holding: continue
			_settle_card(card, card_move_duration)


func _find_insertion_index(cursor_pos: Vector2) -> int:
	if cards.size() <= 1:
		return 0

	if _card_positions.is_empty():
		return _drag_start_index

	var local_cursor = cursor_pos - global_position

	var best_index := _drag_start_index
	var best_dist := INF

	for i in range(_card_positions.size()):
		var dist = local_cursor.distance_squared_to(_card_positions[i])
		if dist < best_dist:
			best_dist = dist
			best_index = i

	return best_index


## Moves follower cards during a pile drag using shape-relative step offsets.
## Each follower chains from the previous card, preserving the snake/trail effect.
func _update_drag_followers(delta: float) -> void:
	if _dragged_card == null or _drag_followers.is_empty(): return
	if not _dragged_card.holding: return

	var lerp_weight = 1.0 - exp(delta * _dragged_card.drag_coef)
	for i in _drag_followers.size():
		var leader: Card = _dragged_card if i == 0 else _drag_followers[i - 1]
		var prev = Vector2.ZERO if i == 0 else _follower_shape_offsets[i - 1]
		var step = get_global_transform().basis_xform(_follower_shape_offsets[i] - prev)
		_drag_followers[i].global_position = lerp(
			_drag_followers[i].global_position,
			leader.global_position + step,
			lerp_weight)

#endregion


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
	if _dragged_card != null: return
	card.z_index = 900


func _on_card_unfocused(card: Card) -> void:
	if _dragged_card != null: return
	_update_z_indices()


func _on_card_dropped() -> void:
	_finish_card_drop.call_deferred()


func _finish_card_drop() -> void:
	var had_followers = not _drag_followers.is_empty()
	var followers_copy: Array[Card] = _drag_followers.duplicate()
	var lead_card = _dragged_card

	if lead_card and cards.has(lead_card) and _last_reorder_index != _original_drag_index:
		cards_reordered.emit(cards)
		_handle_reordered_cards(cards)

	for follower in _drag_followers:
		follower.disabled = false

	_drag_followers.clear()
	_follower_shape_offsets.clear()
	_dragged_card = null
	_drag_start_index = -1
	_last_reorder_index = -1
	_original_drag_index = -1
	set_process(false)
	arrange()

	if had_followers and lead_card and lead_card.get_parent() != self:
		var target = lead_card.get_parent()
		if target is CardContainer:
			for follower in followers_copy:
				follower.move_to(target)


func _on_holding_card(card: Card) -> void:
	_drag_followers.clear()

	if cards.has(card):
		_dragged_card = card
		_drag_start_index = get_card_index(card)
		_last_reorder_index = _drag_start_index
		_original_drag_index = _drag_start_index
		if enable_reordering:
			set_process(true)
	else:
		_dragged_card = null
		_drag_start_index = -1
		_last_reorder_index = -1
		set_process(false)
		return

	if not enable_pile_drag:
		return

	_drag_followers = _get_drag_companions(card)
	if _drag_followers.is_empty():
		return

	_follower_shape_offsets = _get_companion_offsets(card, _drag_followers)

	var drag_hand_idx = cards.find(card)
	for i in _drag_followers.size():
		_drag_followers[i].kill_all_tweens()
		_drag_followers[i].disabled = true
		_drag_followers[i].rotation_degrees = 0.0
		var dist = abs(cards.find(_drag_followers[i]) - drag_hand_idx)
		_drag_followers[i].z_index = 900 + max(0, _drag_followers.size() - dist)

	_dragged_card.z_index = 900 + _drag_followers.size() + 1
	set_process(true)

#endregion


#region Overridable Callbacks

## Called when a card in the hand is clicked. Override to custom behavior.
func _handle_clicked_card(card: Card) -> void: pass

## Called while a cards are reordered. Override to custom behavior.
func _handle_reordered_cards(cards: Array[Card]) -> void: pass


## Returns the local offsets for each companion relative to [param dragged_card].
## Default: shape-defined positions (companions maintain their layout spacing).
## Override for custom drag formations (e.g. compact line, tight stack).
func _get_companion_offsets(dragged_card: Card, companions: Array[Card]) -> Array[Vector2]:
	var drag_pos = _card_positions[cards.find(dragged_card)]
	var result: Array[Vector2] = []
	for companion in companions:
		result.append(_card_positions[cards.find(companion)] - drag_pos)
	return result


## Returns the cards that should move with [param card] during a pile drag.
## Can include cards at any position in the hand — before or after [param card].
## Each companion will maintain its shape-defined offset relative to [param card].
## Default: all cards below [param card] in the hand array.
## Only called when [member enable_pile_drag] is [code]true[/code].
func _get_drag_companions(card: Card) -> Array[Card]:
	var idx = cards.find(card)
	if idx == -1: return []
	return cards.slice(idx + 1)


## Returns the held card plus all active followers.
## Returns an empty array if no card is being dragged.
func get_drag_stack() -> Array[Card]:
	if _dragged_card == null: return []
	var stack: Array[Card] = [_dragged_card]
	stack.append_array(_drag_followers)
	return stack

#endregion


#region Internal Helpers

func _update_z_indices() -> void:
	for i in cards.size():
		if cards[i] == _dragged_card: continue
		if _drag_followers.has(cards[i]):
			cards[i].z_index = 900 + _drag_followers.find(cards[i])
			continue
		cards[i].z_index = i


func _update_focus_chain() -> void:
	var card_count = cards.size()
	if card_count == 0: return

	for i in card_count:
		var card = cards[i]

		var prev_index = (i - 1 + card_count) % card_count
		card.focus_neighbor_left = card.get_path_to(cards[prev_index])
		card.focus_previous = card.get_path_to(cards[prev_index])

		var next_index = (i + 1) % card_count
		card.focus_neighbor_right = card.get_path_to(cards[next_index])
		card.focus_next = card.get_path_to(cards[next_index])

#endregion
