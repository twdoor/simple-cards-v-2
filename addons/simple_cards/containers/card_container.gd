## Base class for card containers.
##
## Manages an internal [code]cards[/code] array, layout computation via [ContainerShape],
## and provides the registration interface used by [method Card.move_to].
## [br][br]
## Subclass [CardHand], [CardPile], or [CardSlot] for specific behavior.
## For custom containers, extend this class and override the virtual callbacks.
@tool @abstract @icon("uid://bhxu665rvmfng")
class_name CardContainer extends Panel


const PREVIEW_DEFAULT_CARD_COUNT := 7
const PREVIEW_CONTAINER_BOUNDS_COLOR := Color(0.35, 0.65, 1.0, 0.45)
const PREVIEW_SHAPE_BOUNDS_COLOR := Color(1.0, 0.75, 0.25, 0.75)
const PREVIEW_CARD_FILL_COLOR := Color(1.0, 1.0, 1.0, 0.12)
const PREVIEW_CARD_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.55)


#region Signals

## Emitted when a card is added to this container.
signal card_added(card: Card, index: int)
## Emitted when a card is removed from this container.
signal card_removed(card: Card, index: int)
## Emitted when the last card is removed.
signal container_empty()
## Emitted when [member max_cards] is reached.
signal container_full()

#endregion


#region Exports

## Layout shape. If [code]null[/code], cards stack at the origin.
@export var shape: ContainerShape:
	set(value):
		if shape and shape.changed.is_connected(_on_shape_changed):
			shape.changed.disconnect(_on_shape_changed)
		shape = value
		if shape and !shape.changed.is_connected(_on_shape_changed):
			shape.changed.connect(_on_shape_changed)
		if !cards.is_empty():
			arrange()
		if Engine.is_editor_hint():
			_queue_preview_layout_update()

## Maximum number of cards allowed. [code]-1[/code] = unlimited.
@export var max_cards: int = -1:
	set(value):
		max_cards = _clamp_max_cards(value)
		if Engine.is_editor_hint():
			_queue_preview_layout_update()

## Default tween duration for cards settling into position.
@export var card_move_duration: float = 0.3

## If [code]false[/code], all cards in this container have keyboard/controller focus disabled
## (via [constant Control.FOCUS_BEHAVIOR_DISABLED]). Mouse interaction and dragging are
## unaffected. Useful for piles or stacked containers where directional focus makes no sense.
@export var cards_focusable: bool = true:
	set(value):
		cards_focusable = value
		if !cards.is_empty():
			_update_focus_chain()

## Idle animation looped on all cards while in this container (e.g. bobbing).
@export var idle_animation: CardAnimationResource
@export_group("Multiplayer (Experimental)")
## Stable ID used by [CardNetworkManager]. Empty IDs are assigned from the scene path.
## @experimental: Multiplayer support may change before it is considered stable.
@export var network_id: StringName = &""
## Peer allowed to command this container. [code]0[/code] means shared/public.
## @experimental: Multiplayer support may change before it is considered stable.
@export var network_owner_peer_id: int = 0
## Controls which peers receive card identity/data for cards in this container.
## @experimental: Multiplayer support may change before it is considered stable.
@export_enum("PUBLIC", "OWNER_ONLY", "FACE_UP_PUBLIC", "HIDDEN") var network_visibility_policy: int = 0
## If [code]false[/code], non-server peers cannot command this container.
## @experimental: Multiplayer support may change before it is considered stable.
@export var allow_remote_commands: bool = false

@export_group("Preview")
## Editor-only shape preview toggle.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "Preview") var preview_enabled: bool = false:
	set(value):
		preview_enabled = value
		_queue_preview_layout_update()
## Layout ID used to determine ghost card size in the editor preview.
@export var preview_layout_name: StringName = LayoutID.DEFAULT:
	set(value):
		preview_layout_name = value
		if Engine.is_editor_hint():
			_get_editor_preview()._preview_card_size = _get_editor_preview()._editor_get_layout_card_size(preview_layout_name)
		_queue_preview_layout_update()
## Editor preview count. [code]0[/code] auto-uses [member max_cards] or a default count.
@export_range(0, 100, 1) var preview_card_count: int = 0:
	set(value):
		preview_card_count = value
		_queue_preview_layout_update()
## If true, draws the panel/container rect in the editor preview.
@export var preview_draw_container_bounds: bool = true:
	set(value):
		preview_draw_container_bounds = value
		queue_redraw()
## If true, draws the computed shape bounds in the editor preview.
@export var preview_draw_shape_bounds: bool = true:
	set(value):
		preview_draw_shape_bounds = value
		queue_redraw()

#endregion


## Internal card array. [b]Read-only[/b] — use [method Card.move_to] to add cards,
## [method get_cards] for a safe copy, or the query methods to inspect.
## [br]Direct mutation (append, insert, erase) bypasses registration and will
## cause layout, signal, and state tracking bugs.
var cards: Array[Card] = []
var _card_positions: Array[Vector2] = []
var _card_rotations: Array[float] = []
## Guard flag — when [code]true[/code], [method _on_child_exiting] skips auto-cleanup.
var _suppress_auto_remove: bool = false
## When [code]true[/code], [method _register_card] skips layout computation.
## Used by bulk operations to defer layout to one call at the end.
var _batch_mode: bool = false
var _idle_restart_gen: int = 0
var _editor_preview: RefCounted
var _snapshot: RefCounted


func _get_editor_preview() -> RefCounted:
	# Runtime containers never allocate editor preview state.
	if not _editor_preview:
		_editor_preview = load("res://addons/simple_cards/editor/container_editor_preview.gd").new()
	return _editor_preview


func _ready() -> void:
	if Engine.is_editor_hint():
		_get_editor_preview()._preview_card_size = _get_editor_preview()._editor_get_layout_card_size(preview_layout_name)
		_queue_preview_layout_update()
		return
	var net = _get_network_manager()
	if net and net.enabled:
		net.register_container(self)
	child_exiting_tree.connect(_on_child_exiting)
	_container_ready()
	if idle_animation and not cards.is_empty():
		_start_idle()


func _exit_tree() -> void:
	if _editor_preview:
		_editor_preview._clear_preview_visual_cards()
	if Engine.is_editor_hint(): return
	_stop_idle()
	var net = CardGlobal.get_instance().get_network_manager()
	if net:
		net.unregister_container(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_stop_idle()


func _validate_property(property: Dictionary) -> void:
	if property.name == "preview_layout_name":
		var options: String = ",".join(LayoutID.get_all())
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = options


#region Queries

## Returns the number of cards in this container.
func get_card_count() -> int:
	return cards.size()


## Returns [code]true[/code] if the container has no cards.
func is_empty() -> bool:
	return cards.is_empty()


## Returns [code]true[/code] if the container has reached [member max_cards].
func is_full() -> bool:
	if max_cards < 0: return false
	return cards.size() >= max_cards


## Returns [code]true[/code] if the container holds the given card.
func has_card(card: Card) -> bool:
	return cards.has(card)


## Returns the card at [param index], or [code]null[/code] if out of bounds.
## Negative indices count from the end ([code]-1[/code] = last / top).
func get_card_at(index: int) -> Card:
	if index < 0: index = cards.size() + index
	if index < 0 or index >= cards.size(): return null
	return cards[index]


## Returns a copy of the internal card array. Safe to read and modify.
func get_cards() -> Array[Card]:
	return cards.duplicate()


## Returns the index of a card, or [code]-1[/code] if not found.
func get_card_index(card: Card) -> int:
	return cards.find(card)


## Returns remaining slots before [member max_cards]. [code]-1[/code] if unlimited.
func get_remaining_space() -> int:
	if max_cards < 0: return -1
	return max(0, max_cards - cards.size())

#endregion


#region Registration — called by Card.move_to

## Returns [code]true[/code] if this container would accept the card.
func can_accept_card(card: Card) -> bool:
	if cards.has(card): return false
	if is_full(): return false
	return _check_conditions(card)


## Registers a card in internal state. Does NOT reparent or animate the card.
## [br]Computes layout and settles existing cards (unless in batch mode).
func _register_card(card: Card, index: int = -1) -> void:
	var net = _get_network_manager()
	if net and net.enabled:
		net.register_card(card)
	if index < 0 or index > cards.size():
		cards.append(card)
		index = cards.size() - 1
	else:
		cards.insert(index, card)

	_connect_card_signals(card)
	_apply_card_state(card)

	if not _batch_mode:
		_compute_layout()

		for c in cards:
			if c == card: continue
			if c.holding: continue
			_settle_card(c, card_move_duration)

		_start_card_idle(card, card_move_duration)

	_handle_card_added(card, index)
	card_added.emit(card, index)
	if is_full():
		container_full.emit()
		_handle_container_full()


## Unregisters a card from internal state. Triggered by [signal child_exiting_tree].
func _unregister_card(card: Card) -> void:
	var index = cards.find(card)
	if index == -1: return

	_stop_card_idle(card)

	cards.remove_at(index)
	_disconnect_card_signals(card)
	_restore_card_state(card)
	_compute_layout()

	for c in cards:
		if c.holding: continue
		_settle_card(c, card_move_duration)

	_handle_card_removed(card, index)
	card_removed.emit(card, index)
	if cards.is_empty():
		container_empty.emit()
		_handle_container_empty()

## Registers a card without triggering layout or signals.
## Used for atomic multi-card operations like swaps.
func _raw_register(card: Card, index: int = -1) -> void:
	var net = _get_network_manager()
	if net and net.enabled:
		net.register_card(card)
	if index < 0 or index > cards.size():
		cards.append(card)
	else:
		cards.insert(index, card)
	_connect_card_signals(card)
	_apply_card_state(card)


## Unregisters a card without triggering layout or signals.
## Used for atomic multi-card operations like swaps.
func _raw_unregister(card: Card) -> void:
	cards.erase(card)
	_disconnect_card_signals(card)
	_restore_card_state(card)

#endregion


#region Layout

## Computes [member _card_positions] and [member _card_rotations] from the [member shape].
## If no shape is assigned, all cards stack at the pivot origin.
func _compute_layout() -> void:
	if cards.is_empty():
		_card_positions.clear()
		_card_rotations.clear()
		update_minimum_size()
		return

	if shape:
		var result: ContainerShape.LayoutResult = shape.compute_layout(cards)
		_card_positions = result.positions
		_card_rotations = result.rotations
		_update_focus_chain()
	else:
		_card_positions.clear()
		_card_rotations.clear()
		for card in cards:
			_card_positions.append(card.pivot_offset)
			_card_rotations.append(0.0)
		_update_focus_chain()

	update_minimum_size()


## Applies focus state and directional neighbors to all cards based on the shape.
func _update_focus_chain() -> void:
	var card_count = cards.size()
	if card_count == 0: return

	if not cards_focusable:
		for card in cards:
			card.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
			card.focus_neighbor_left = ^""
			card.focus_neighbor_right = ^""
			card.focus_neighbor_top = ^""
			card.focus_neighbor_bottom = ^""
			card.focus_previous = ^""
			card.focus_next = ^""
		return

	for i in card_count:
		var card = cards[i]
		card.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED

		card.focus_neighbor_left = _neighbor_path(card, i, "left", card_count)
		card.focus_neighbor_right = _neighbor_path(card, i, "right", card_count)
		card.focus_neighbor_top = _neighbor_path(card, i, "up", card_count)
		card.focus_neighbor_bottom = _neighbor_path(card, i, "down", card_count)

		card.focus_previous = card.get_path_to(cards[i - 1]) if i > 0 else ^""
		card.focus_next = card.get_path_to(cards[i + 1]) if i < card_count - 1 else ^""


func _neighbor_path(card: Card, index: int, direction: String, card_count: int) -> NodePath:
	if not shape:
		match direction:
			"left":
				var left_index = index - 1
				return card.get_path_to(cards[left_index]) if left_index >= 0 else ^""
			"right":
				var right_index = index + 1
				return card.get_path_to(cards[right_index]) if right_index < card_count else ^""
			_:
				return ^""

	var target = shape.get_focus_neighbor(index, direction, card_count)
	if target == -1: return ^""
	return card.get_path_to(cards[target])


## Returns the local position a card should occupy after layout.
func get_card_target_position(card: Card) -> Vector2:
	var i = cards.find(card)
	if i == -1 or i >= _card_positions.size(): return Vector2.ZERO
	var rot = _card_rotations[i] if i < _card_rotations.size() else 0.0
	return _card_positions[i] - card.pivot_offset + card.position_offset.rotated(rot)


## Returns the rotation (in degrees) a card should have after layout.
func get_card_target_rotation(card: Card) -> float:
	var i = cards.find(card)
	if i == -1 or i >= _card_rotations.size(): return 0.0
	return rad_to_deg(_card_rotations[i]) + card.rotation_offset


## Recomputes layout and tweens all cards to their positions.
func arrange(duration: float = -1) -> void:
	if duration < 0: duration = card_move_duration
	_compute_layout()
	for card in cards:
		if card.holding: continue
		_settle_card(card, duration)
	_update_card_layer_order()


## Tweens a single card to its layout position. Rotation is set directly.
## If the card has a stored [code]_move_origin[/code] (from a batch move),
## restores the card's global position to that origin before tweening.
func _settle_card(card: Card, duration: float) -> void:
	if card._move_origin != Vector2.INF:
		card.global_position = card._move_origin
		card._move_origin = Vector2.INF

	var target_pos = get_card_target_position(card)
	var config: Card.MoveConfig = card._move_config
	card._move_config = null

	if config and config.position_callable.is_valid():
		card._queue_interaction_state_sync_on_move_completed()
		config.position_callable.call(card, target_pos, duration)
	else:
		card.tween_position(target_pos, duration)

	card.rotation_degrees = get_card_target_rotation(card)

#endregion


#region Idle Animation

## Plays the [member idle_animation] on every card in this container.
func _start_idle() -> void:
	if not idle_animation: return
	for card in cards:
		if card.holding: continue
		var layout = card.get_layout()
		if layout:
			idle_animation.play_animation(layout)


## Stops a looping [member idle_animation] on every card.
## Also cancels any pending restart scheduled by [method _schedule_idle_restart].
func _stop_idle() -> void:
	_idle_restart_gen += 1
	if not idle_animation or not idle_animation.looping: return
	for card in cards:
		var layout = card.get_layout()
		if layout:
			idle_animation.stop_animation(layout)


## Stops a looping [member idle_animation] on a single card.
func _stop_card_idle(card: Card) -> void:
	if not idle_animation or not idle_animation.looping: return
	var layout = card.get_layout()
	if layout:
		idle_animation.stop_animation(layout)


## Starts idle animation on a single card after a delay.
func _start_card_idle(card: Card, delay: float) -> void:
	if not idle_animation: return
	await get_tree().create_timer(maxf(delay, 0.001)).timeout
	if not is_inside_tree(): return
	if not is_instance_valid(card) or not cards.has(card): return
	if card.holding: return
	var layout = card.get_layout()
	if layout:
		idle_animation.play_animation(layout)


## Starts idle on all cards after [param duration] seconds. Used after batch operations.
## Subsequent calls cancel the previous timer via generation counter.
func _schedule_idle_restart(duration: float) -> void:
	if not idle_animation: return
	_idle_restart_gen += 1
	var gen = _idle_restart_gen
	await get_tree().create_timer(maxf(duration, 0.001)).timeout
	if not is_inside_tree(): return
	if gen != _idle_restart_gen: return
	_start_idle()

#endregion


#region Bulk Operations

## Moves the top [param count] cards to [param target].
## Returns how many were moved.
## [br][br]
## If [member Card.MoveConfig.batch] is [code]true[/code] (or [member Card.MoveConfig.duration]
## is [code]0[/code]), layout computation is deferred until all cards are placed.
func deal_to(target: CardContainer, count: int, config: Card.MoveConfig = null) -> int:
	var net = _get_network_manager()
	if net and net.should_route_container_command(self, target):
		return await net.request_deal(self, target, count, config)
	var broadcast_after: bool = net and net.should_broadcast_local_action()
	var animation_duration := config.duration if config else -1.0
	if broadcast_after:
		net.begin_suppressed_routing()
	var dealt := await _deal_to_local(target, count, config)
	if broadcast_after:
		net.end_suppressed_routing()
		net.bump_revision_and_broadcast(animation_duration)
	return dealt


## Local implementation for [method deal_to].
func _deal_to_local(target: CardContainer, count: int, config: Card.MoveConfig = null) -> int:
	if !config: config = Card.MoveConfig.new()
	var use_batch = config.batch or config.duration == 0
	if use_batch:
		target._batch_mode = true

	var dealt: int = 0
	for i in count:
		if cards.is_empty(): break
		var card = cards.back()
		if !target.can_accept_card(card): break
		card.move_to(target, config)
		dealt += 1
		if config.stagger > 0.0 and i < count - 1:
			await get_tree().create_timer(config.stagger).timeout

	if use_batch and dealt > 0:
		target._batch_mode = false
		var settle_dur: float = config.duration if config.duration >= 0.0 else target.card_move_duration
		target.arrange(settle_dur)
		target._schedule_idle_restart(settle_dur)
	elif use_batch:
		target._batch_mode = false

	return dealt


## Moves specific cards to [param target].
## Returns how many were moved.
## [br][br]
## If [member Card.MoveConfig.batch] is [code]true[/code] (or [member Card.MoveConfig.duration]
## is [code]0[/code]), layout computation is deferred until all cards are placed.
func move_cards_to(card_array: Array[Card], target: CardContainer, config: Card.MoveConfig = null) -> int:
	var net = _get_network_manager()
	if net and net.should_route_container_command(self, target):
		return await net.request_move_cards(card_array, self, target, config)
	var broadcast_after: bool = net and net.should_broadcast_local_action()
	var animation_duration := config.duration if config else -1.0
	if broadcast_after:
		net.begin_suppressed_routing()
	var moved := await _move_cards_to_local(card_array, target, config)
	if broadcast_after:
		net.end_suppressed_routing()
		net.bump_revision_and_broadcast(animation_duration)
	return moved


## Local implementation for [method move_cards_to].
func _move_cards_to_local(card_array: Array[Card], target: CardContainer, config: Card.MoveConfig = null) -> int:
	if !config: config = Card.MoveConfig.new()
	var use_batch = config.batch or config.duration == 0
	if use_batch:
		target._batch_mode = true

	var moved: int = 0
	var to_move = card_array.duplicate()
	for i in to_move.size():
		var card = to_move[i]
		if !cards.has(card): continue
		if !target.can_accept_card(card): continue
		card.move_to(target, config)
		moved += 1
		if config.stagger > 0.0 and i < to_move.size() - 1:
			await get_tree().create_timer(config.stagger).timeout

	if use_batch and moved > 0:
		target._batch_mode = false
		var settle_dur: float = config.duration if config.duration >= 0.0 else target.card_move_duration
		target.arrange(settle_dur)
		target._schedule_idle_restart(settle_dur)
	elif use_batch:
		target._batch_mode = false

	return moved


## Moves all cards to [param target].
## Returns how many were moved.
func move_all_to(target: CardContainer, config: Card.MoveConfig = null) -> int:
	return await move_cards_to(cards.duplicate(), target, config)


## Sorts cards using a custom comparison and re-arranges.
func sort_cards(compare_func: Callable) -> void:
	var net = _get_network_manager()
	if net and net.should_route_container_order(self):
		_sort_cards_local(compare_func)
		net.request_set_container_order(self)
		return
	_sort_cards_local(compare_func)
	if net and net.should_broadcast_local_action():
		net.bump_revision_and_broadcast(-1.0)


## Local implementation for [method sort_cards].
func _sort_cards_local(compare_func: Callable) -> void:
	cards.sort_custom(compare_func)
	arrange()


## Returns the current card order as network IDs.
## @experimental: Multiplayer support may change before it is considered stable.
func get_network_card_order() -> PackedStringArray:
	return _get_snapshot().get_network_card_order(self)


## Applies an authoritative card order by network ID.
## @experimental: Multiplayer support may change before it is considered stable.
func apply_network_card_order(card_ids: PackedStringArray, duration: float = 0.0) -> void:
	_get_snapshot().apply_network_card_order(self, card_ids, duration)


#endregion


#region Clear

## Removes all cards and frees them.
func clear_and_free() -> void:
	var net = _get_network_manager()
	_stop_idle()
	_suppress_auto_remove = true
	for card in cards:
		_disconnect_card_signals(card)
		if net:
			net.unregister_card(card)
		card.queue_free()
	cards.clear()
	_card_positions.clear()
	_card_rotations.clear()
	_suppress_auto_remove = false
	update_minimum_size()
	container_empty.emit()
	_handle_container_empty()
	if net and net.should_broadcast_local_action():
		net.bump_revision_and_broadcast()

#endregion


#region Overridable Callbacks

## Called at the end of [method _ready]. Override for subclass setup.
func _container_ready() -> void: pass

## Called after a card is registered. Override for custom behavior.
func _handle_card_added(card: Card, index: int) -> void: pass

## Called after a card is unregistered. Override for custom behavior.
func _handle_card_removed(card: Card, index: int) -> void: pass

## Called if container becomes empty. Override for custom behavior.
func _handle_container_empty() -> void: pass

## Called if container becomes full. Override for custom behavior.
func _handle_container_full() -> void: pass

## Override to constrain [member max_cards]. Called by the [member max_cards] setter.
## Return the value to actually store. Default: pass through unchanged.
func _clamp_max_cards(value: int) -> int: return value

## Override to apply container-specific state when a card enters (e.g. face down, disabled).
func _apply_card_state(card: Card) -> void: pass

## Override to restore card state when it leaves this container.
func _restore_card_state(card: Card) -> void: pass

## Override to add custom acceptance rules. Called by [method can_accept_card].
func _check_conditions(card: Card) -> bool: return true

## Override to connect custom signals when a card is registered.
func _connect_card_signals(card: Card) -> void: pass

## Override to disconnect custom signals when a card is unregistered.
func _disconnect_card_signals(card: Card) -> void: pass

#endregion


#region Internal

func _on_child_exiting(node: Node) -> void:
	if _suppress_auto_remove: return
	if not node is Card: return
	if not cards.has(node): return
	_unregister_card(node as Card)


func _on_shape_changed() -> void:
	if Engine.is_editor_hint():
		_queue_preview_layout_update()
		return
	if !cards.is_empty():
		arrange()


func _get_network_manager() -> CardNetworkManager:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	return CardGlobal.get_instance().get_network_manager()


func _queue_preview_layout_update() -> void:
	update_minimum_size()
	if Engine.is_editor_hint():
		_get_editor_preview()._update_preview_visual_cards(self)
	queue_redraw()


func _compute_preview_layout(preview_cards: Array[Card]) -> ContainerShape.LayoutResult:
	if shape:
		var script = shape.get_script()
		if script and script.is_tool():
			return shape.compute_layout(preview_cards)

	return _compute_stacked_preview_layout(preview_cards)


func _compute_stacked_preview_layout(preview_cards: Array[Card]) -> ContainerShape.LayoutResult:
	var positions: Array[Vector2] = []
	var rotations: Array[float] = []
	for card in preview_cards:
		positions.append(card.pivot_offset)
		rotations.append(0.0)
	return ContainerShape.LayoutResult.new(positions, rotations)


func _get_layout_bounds(layout_cards: Array[Card], positions: Array[Vector2], rotations: Array[float]) -> Rect2:
	if shape:
		var script = shape.get_script()
		if script and script.is_tool():
			return shape.get_layout_bounds(layout_cards, ContainerShape.LayoutResult.new(positions, rotations))

	return _get_raw_layout_bounds(layout_cards, positions, rotations)


func _get_raw_layout_bounds(layout_cards: Array[Card], positions: Array[Vector2], rotations: Array[float]) -> Rect2:
	if layout_cards.is_empty() or positions.is_empty():
		return Rect2()

	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var has_bounds := false

	for i in mini(layout_cards.size(), positions.size()):
		var card_position = positions[i]
		var half_size: Vector2 = layout_cards[i].size / 2.0
		var rot: float = rotations[i] if i < rotations.size() else 0.0
		var corners := [
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y)
		]
		for corner in corners:
			var rotated_corner: Vector2 = card_position + corner.rotated(rot)
			min_x = min(min_x, rotated_corner.x)
			max_x = max(max_x, rotated_corner.x)
			min_y = min(min_y, rotated_corner.y)
			max_y = max(max_y, rotated_corner.y)
			has_bounds = true

	if !has_bounds:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _get_minimum_size() -> Vector2:
	if Engine.is_editor_hint() and preview_enabled:
		return _get_editor_preview()._get_preview_bounds(self).size

	if cards.is_empty() or _card_positions.is_empty():
		return Vector2.ZERO

	return _get_layout_bounds(cards, _card_positions, _card_rotations).size

func _update_card_layer_order() -> void:
	for i in range(cards.size()):
		var card = cards[i]
		card.z_index = i

#endregion


func _draw() -> void:
	if Engine.is_editor_hint() and preview_enabled:
		_get_editor_preview()._draw(self)


func _enter_tree() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		_queue_preview_layout_update()


func _get_snapshot() -> RefCounted:
	# Lazy loading avoids a circular preload graph through the core node types.
	if not _snapshot:
		_snapshot = load("res://addons/simple_cards/network/container_snapshot.gd").new()
	return _snapshot
