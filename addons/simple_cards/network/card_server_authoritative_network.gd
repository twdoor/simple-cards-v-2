## Server-authoritative multiplayer coordinator for Simple Cards.
##
## Add this as a scene node, commonly named CardNetwork, in multiplayer scenes.
## It registers itself through CG and routes card/container commands through a
## single authoritative server.
## @experimental: Multiplayer support may change before it is considered stable.
class_name CardServerAuthoritativeNetwork extends CardNetworkManager


class PendingCommand extends RefCounted:
	signal completed(result: Dictionary)


const COMMAND_MOVE_CARD := "MOVE_CARD"
const COMMAND_MOVE_CARDS := "MOVE_CARDS"
const COMMAND_DEAL_TO := "DEAL_TO"
const COMMAND_REORDER_HAND := "REORDER_HAND"
const COMMAND_SHUFFLE_PILE := "SHUFFLE_PILE"
const COMMAND_FLIP_CARD := "FLIP_CARD"
const COMMAND_SLOT_DROP := "SLOT_DROP"
const COMMAND_SLOT_SWAP := "SLOT_SWAP"
const COMMAND_SET_CARD_DATA := "SET_CARD_DATA"
const COMMAND_SET_CONTAINER_ORDER := "SET_CONTAINER_ORDER"
const COMMAND_REQUEST_SNAPSHOT := "REQUEST_SNAPSHOT"

const SERVER_PEER_ID := 1
const MAX_COMMAND_CARDS := 256
const REVISION_TOLERANCE := 512


@export_group("Multiplayer (Experimental)")
## Card data affects authoritative game rules in many games, so remote mutation
## must be explicitly enabled by the game.
## @experimental: Multiplayer support may change before it is considered stable.
@export var allow_remote_card_data_updates: bool = false
@export_group("")


var _cards_by_id: Dictionary = {}
var _containers_by_id: Dictionary = {}
var _resources_by_id: Dictionary = {}
var _next_card_sequence: int = 1
var _routing_suppression: int = 0
var _server_command_depth: int = 0
var _applying_remote_state: bool = false
var _broadcast_queued: bool = false
var _next_command_sequence: int = 1
var _pending_commands: Dictionary = {}


func _ready() -> void:
	super._ready()
	if multiplayer and not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if multiplayer and not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _exit_tree() -> void:
	_cancel_pending_commands("manager_exited")
	if multiplayer and multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if multiplayer and multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	super._exit_tree()


func is_applying_remote_state() -> bool:
	return _applying_remote_state or _routing_suppression > 0


func begin_apply_remote_state() -> void:
	_routing_suppression += 1
	_applying_remote_state = true


func end_apply_remote_state() -> void:
	_routing_suppression = maxi(0, _routing_suppression - 1)
	if _routing_suppression == 0:
		_applying_remote_state = false


func begin_suppressed_routing() -> void:
	_routing_suppression += 1


func end_suppressed_routing() -> void:
	_routing_suppression = maxi(0, _routing_suppression - 1)


func should_route_move(_card: Card, _target: CardContainer) -> bool:
	return _should_route_client_command()


func should_route_container_command(_source: CardContainer, _target: CardContainer = null) -> bool:
	return _should_route_client_command()


func should_route_container_order(_container: CardContainer) -> bool:
	return _should_route_client_command()


func should_route_pile_command(_pile: CardPile) -> bool:
	return _should_route_client_command()


func should_route_slot_command(_slot: CardSlot, _card: Card = null) -> bool:
	return _should_route_client_command()


func should_broadcast_local_action() -> bool:
	return enabled and is_server_peer() and not is_applying_remote_state() and _server_command_depth == 0


func _should_route_client_command() -> bool:
	if not enabled:
		return false
	if is_applying_remote_state():
		return false
	return not is_server_peer()


func register_container(container: CardContainer) -> void:
	if not is_instance_valid(container):
		return
	ensure_container_id(container)
	_containers_by_id[String(container.network_id)] = container


func unregister_container(container: CardContainer) -> void:
	if not container:
		return
	var id := String(container.network_id)
	if _containers_by_id.get(id) == container:
		_containers_by_id.erase(id)


func register_card(card: Card) -> void:
	if not is_instance_valid(card):
		return
	ensure_card_id(card)
	_cards_by_id[String(card.network_id)] = card
	if card.card_data:
		register_resource(card.card_data)


func unregister_card(card: Card) -> void:
	if not card:
		return
	var id := String(card.network_id)
	if _cards_by_id.get(id) == card:
		_cards_by_id.erase(id)


func register_resource(resource: CardResource) -> void:
	if not resource:
		return
	var id := String(resource.get_network_resource_id())
	if id.is_empty():
		return
	_resources_by_id[id] = resource


func get_card(card_id: StringName) -> Card:
	var card = _cards_by_id.get(String(card_id))
	if card and is_instance_valid(card):
		return card as Card
	_cards_by_id.erase(String(card_id))
	return null


func get_container(container_id: StringName) -> CardContainer:
	var container = _containers_by_id.get(String(container_id))
	if container and is_instance_valid(container):
		return container as CardContainer
	_containers_by_id.erase(String(container_id))
	return null


func get_resource(resource_id: StringName) -> CardResource:
	var resource = _resources_by_id.get(String(resource_id))
	if resource and is_instance_valid(resource):
		return resource as CardResource
	_resources_by_id.erase(String(resource_id))
	return null


func ensure_card_id(card: Card) -> StringName:
	if not card:
		return &""
	if not card.network_id.is_empty():
		return card.network_id
	if card.is_inside_tree() and card.owner:
		var scene_id := StringName("sc_scene_card:%s" % card.get_path())
		card.set_network_id(scene_id)
		return scene_id
	var id := StringName("sc_card_%s_%d_%d" % [
		Time.get_unix_time_from_system(),
		multiplayer.get_unique_id() if multiplayer else 0,
		_next_card_sequence
	])
	_next_card_sequence += 1
	card.set_network_id(id)
	return id


func assign_card_id(card: Card) -> StringName:
	return ensure_card_id(card)


func ensure_container_id(container: CardContainer) -> StringName:
	if not container:
		return &""
	if not container.network_id.is_empty():
		return container.network_id
	if container.is_inside_tree():
		container.network_id = StringName(str(container.get_path()))
	else:
		container.network_id = StringName("sc_container_%d" % container.get_instance_id())
	return container.network_id


func request_move(card: Card, target: CardContainer, config: Card.MoveConfig = null) -> void:
	if not card or not target:
		return
	var source := card.get_parent() as CardContainer
	var command := _build_command(COMMAND_MOVE_CARD, source, target, [card], config)
	_send_or_apply_command(command)
	_handle_prediction_after_request([card], source, target, config)


func request_move_cards(cards: Array[Card], source: CardContainer, target: CardContainer, config: Card.MoveConfig = null) -> int:
	if not source or not target:
		return 0
	var command := _build_command(COMMAND_MOVE_CARDS, source, target, cards, config)
	_handle_prediction_after_request(cards, source, target, config)
	var result := await _send_or_apply_command(command, true)
	return int(result.get("value", 0)) if result.get("accepted", false) else 0


func request_deal(source: CardContainer, target: CardContainer, count: int, config: Card.MoveConfig = null) -> int:
	if not source or not target:
		return 0
	var command := _build_command(COMMAND_DEAL_TO, source, target, [], config)
	command.metadata["count"] = count
	_handle_prediction_after_request([], source, target, config)
	var result := await _send_or_apply_command(command, true)
	return int(result.get("value", 0)) if result.get("accepted", false) else 0


func request_reorder(container: CardContainer, ordered_cards: Array[Card]) -> void:
	if not container:
		return
	var command := _build_command(COMMAND_REORDER_HAND, container, container, ordered_cards, null)
	_send_or_apply_command(command)


func request_set_container_order(container: CardContainer) -> void:
	if not container:
		return
	var command := _build_command(COMMAND_SET_CONTAINER_ORDER, container, container, container.cards, null)
	_send_or_apply_command(command)


func request_shuffle(pile: CardPile) -> void:
	if not pile:
		return
	var command := _build_command(COMMAND_SHUFFLE_PILE, pile, pile, [], null)
	_send_or_apply_command(command)


func request_flip(card: Card) -> void:
	if not card:
		return
	var source := card.get_parent() as CardContainer
	var command := _build_command(COMMAND_FLIP_CARD, source, source, [card], null)
	_send_or_apply_command(command)


func request_slot_drop(slot: CardSlot, incoming: Card) -> void:
	if not slot or not incoming:
		return
	var source := incoming.get_parent() as CardContainer
	var command := _build_command(COMMAND_SLOT_DROP, source, slot, [incoming], null)
	_send_or_apply_command(command)
	_handle_prediction_after_request([incoming], source, slot, null)


func request_slot_swap(slot: CardSlot, other_slot: CardSlot) -> bool:
	if not slot or not other_slot:
		return false
	var cards: Array[Card] = []
	if slot.get_card():
		cards.append(slot.get_card())
	if other_slot.get_card():
		cards.append(other_slot.get_card())
	var command := _build_command(COMMAND_SLOT_SWAP, slot, other_slot, cards, null)
	var result := await _send_or_apply_command(command, true)
	return bool(result.get("value", false)) if result.get("accepted", false) else false


func request_set_card_data(card: Card) -> void:
	if not card:
		return
	var source := card.get_parent() as CardContainer
	var command := _build_command(COMMAND_SET_CARD_DATA, source, source, [card], null)
	command.metadata["card_state"] = card.get_network_state(SERVER_PEER_ID)
	_send_or_apply_command(command)


func bump_revision_and_broadcast(animation_duration: float = 0.0) -> void:
	if not enabled or not is_server_peer():
		return
	state_revision += 1
	broadcast_state(animation_duration)


func queue_revision_broadcast() -> void:
	if _broadcast_queued:
		return
	_broadcast_queued = true
	_deferred_revision_broadcast.call_deferred()


func broadcast_state(animation_duration: float = 0.0) -> void:
	if not enabled or not is_server_peer():
		return
	_cleanup_registries()
	if multiplayer.has_multiplayer_peer():
		for peer_id in multiplayer.get_peers():
			_send_snapshot_to_peer(peer_id, false, animation_duration)
	state_revision_applied.emit(state_revision)


func build_snapshot_for_peer(peer_id: int = 0, animation_duration: float = 0.0) -> Dictionary:
	_cleanup_registries()
	for container in _containers_by_id.values():
		if not is_instance_valid(container):
			continue
		for card in (container as CardContainer).cards:
			register_card(card)
	var live_cards: Array[Card] = []
	for id in _cards_by_id.keys():
		var card := get_card(StringName(id))
		if card:
			live_cards.append(card)

	var wire_ids: Dictionary = {}
	for card in live_cards:
		var canonical_id := String(card.network_id)
		wire_ids[canonical_id] = canonical_id if can_peer_see_card(card, peer_id) else String(make_hidden_wire_card_id(peer_id))

	var containers: Array[Dictionary] = []
	for id in _containers_by_id.keys():
		var container := get_container(StringName(id))
		if not container:
			continue
		var card_order := PackedStringArray()
		for card in container.cards:
			ensure_card_id(card)
			var canonical_id := String(card.network_id)
			if not wire_ids.has(canonical_id):
				wire_ids[canonical_id] = canonical_id if can_peer_see_card(card, peer_id) else String(make_hidden_wire_card_id(peer_id))
			card_order.append(String(wire_ids[canonical_id]))
		containers.append({
			"container_id": container.network_id,
			"node_path": str(container.get_path()) if container.is_inside_tree() else "",
			"owner_peer_id": container.network_owner_peer_id,
			"visibility_policy": int(container.network_visibility_policy),
			"allow_remote_commands": container.allow_remote_commands,
			"card_order": card_order,
		})

	var cards: Array[Dictionary] = []
	for card in live_cards:
		var state := card.get_network_state(peer_id)
		state["card_id"] = StringName(wire_ids[String(card.network_id)])
		cards.append(state)

	return {
		"revision": state_revision,
		"animation_duration": animation_duration,
		"containers": containers,
		"cards": cards,
	}


func can_peer_see_card(card: Card, peer_id: int) -> bool:
	if peer_id == 0 or peer_id == SERVER_PEER_ID:
		return true
	if not card:
		return false
	if card.network_owner_peer_id != 0 and card.network_owner_peer_id == peer_id:
		return true

	var container := card.get_parent() as CardContainer
	if not container:
		return true
	if container.network_owner_peer_id != 0 and container.network_owner_peer_id == peer_id:
		return true

	match container.network_visibility_policy:
		VisibilityPolicy.PUBLIC:
			return true
		VisibilityPolicy.OWNER_ONLY:
			return false
		VisibilityPolicy.FACE_UP_PUBLIC:
			return card.is_front_face
		VisibilityPolicy.HIDDEN:
			return false
	return true


func resolve_resource_from_payload(payload: Dictionary) -> CardResource:
	if not payload.get("known", false):
		return null
	var resource_id := String(payload.get("resource_id", ""))
	if not resource_id.is_empty():
		var registered := get_resource(StringName(resource_id))
		if registered:
			return registered
	var resource_path := String(payload.get("resource_path", ""))
	if not resource_path.is_empty() and ResourceLoader.exists(resource_path):
		var loaded = load(resource_path)
		if loaded is CardResource:
			register_resource(loaded)
			return loaded
	return null


@rpc("any_peer", "reliable")
func _request_card_command(command: Dictionary) -> void:
	if not enabled:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = SERVER_PEER_ID
	await _handle_command_on_server(command, sender_id)


@rpc("authority", "reliable")
func _apply_card_delta(delta: Dictionary) -> void:
	_apply_snapshot_payload(delta)


@rpc("authority", "reliable")
func _apply_full_snapshot(snapshot: Dictionary) -> void:
	_apply_snapshot_payload(snapshot)


@rpc("any_peer", "reliable")
func _request_full_snapshot() -> void:
	if not enabled or not is_server_peer():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = SERVER_PEER_ID
	if sender_id == SERVER_PEER_ID:
		return
	_send_snapshot_to_peer(sender_id, true)


@rpc("authority", "reliable")
func _command_rejected_remote(command: Dictionary, reason: String) -> void:
	command_rejected.emit(command, reason)
	_resolve_pending_command(StringName(command.get("command_id", &"")), {
		"accepted": false,
		"value": null,
		"reason": reason,
	})
	if enabled and not is_server_peer():
		_request_full_snapshot.rpc_id(SERVER_PEER_ID)


@rpc("authority", "reliable")
func _command_completed_remote(command_id: StringName, value: Variant) -> void:
	_resolve_pending_command(command_id, {
		"accepted": true,
		"value": value,
		"reason": "",
	})


func _build_command(
	type: String,
	source: CardContainer,
	target: CardContainer,
	cards: Array[Card],
	config: Card.MoveConfig
) -> Dictionary:
	var ids := PackedStringArray()
	for card in cards:
		if not card:
			continue
		ids.append(String(ensure_card_id(card)))

	var source_id := &""
	if source:
		source_id = ensure_container_id(source)
	var target_id := source_id
	if target:
		target_id = ensure_container_id(target)

	var duration := default_move_duration
	var target_index := -1
	var batch := false
	if config:
		duration = config.duration
		target_index = config.index
		batch = config.batch

	return {
		"type": type,
		"command_id": &"",
		"revision": state_revision,
		"card_ids": ids,
		"source_container_id": source_id,
		"target_container_id": target_id,
		"target_index": target_index,
		"duration": duration,
		"batch": batch,
		"metadata": {},
	}


func _send_or_apply_command(command: Dictionary, wait_for_result: bool = false) -> Dictionary:
	if not enabled:
		return {"accepted": false, "value": null, "reason": "disabled"}
	if is_server_peer():
		return await _handle_command_on_server(command, SERVER_PEER_ID)
	if not wait_for_result:
		_request_card_command.rpc_id(SERVER_PEER_ID, command)
		return {"accepted": true, "value": null, "reason": "submitted"}

	var command_id := _make_command_id()
	command["command_id"] = command_id
	var pending := PendingCommand.new()
	_pending_commands[String(command_id)] = pending
	var timer := get_tree().create_timer(command_timeout)
	timer.timeout.connect(_timeout_pending_command.bind(command_id, pending), CONNECT_ONE_SHOT)
	_request_card_command.rpc_id(SERVER_PEER_ID, command)
	return await pending.completed


func _handle_prediction_after_request(
	cards: Array[Card],
	source: CardContainer,
	target: CardContainer,
	config: Card.MoveConfig
) -> void:
	match prediction_mode:
		PredictionMode.NONE, PredictionMode.LOCAL_VISUAL_ONLY:
			if source:
				source.arrange()
		PredictionMode.OPTIMISTIC:
			begin_suppressed_routing()
			for card in cards:
				if card and target:
					card._move_to_local(target, config)
			end_suppressed_routing()


func _deferred_revision_broadcast() -> void:
	_broadcast_queued = false
	bump_revision_and_broadcast()


func _handle_command_on_server(command: Dictionary, sender_id: int) -> Dictionary:
	if not enabled or not is_server_peer():
		return {"accepted": false, "value": null, "reason": "not_server"}

	var validation_reason := _validate_command(command, sender_id)
	if not validation_reason.is_empty():
		_reject_command(command, validation_reason, sender_id)
		return {"accepted": false, "value": null, "reason": validation_reason}

	_server_command_depth += 1
	begin_suppressed_routing()
	var value: Variant = await _apply_command_local(command)
	end_suppressed_routing()
	_server_command_depth = maxi(0, _server_command_depth - 1)

	state_revision += 1
	var config := _get_move_config_from_command(command)
	broadcast_state(config.duration)
	var command_id := StringName(command.get("command_id", &""))
	if sender_id != SERVER_PEER_ID and not command_id.is_empty() and multiplayer.get_peers().has(sender_id):
		_command_completed_remote.rpc_id(sender_id, command_id, value)
	return {"accepted": true, "value": value, "reason": ""}


func _apply_command_local(command: Dictionary) -> Variant:
	var type := String(command.get("type", ""))
	var source := get_container(StringName(command.get("source_container_id", &"")))
	var target := get_container(StringName(command.get("target_container_id", &"")))
	var cards := _get_cards_from_command(command)
	var config := _get_move_config_from_command(command)

	match type:
		COMMAND_MOVE_CARD, COMMAND_MOVE_CARDS:
			if not target:
				return 0
			var index := config.index
			var moved := 0
			for card in cards:
				if not card:
					continue
				var move_config := Card.MoveConfig.new(config.duration, index, 0.0, config.batch)
				card._move_to_local(target, move_config)
				if target.cards.has(card):
					moved += 1
				if index >= 0:
					index += 1
			return moved
		COMMAND_DEAL_TO:
			if source and target:
				var count := int(command.get("metadata", {}).get("count", 0))
				return await source._deal_to_local(target, count, config)
			return 0
		COMMAND_REORDER_HAND, COMMAND_SET_CONTAINER_ORDER:
			if target:
				target.apply_network_card_order(_get_card_id_array(command), config.duration)
				return true
		COMMAND_SHUFFLE_PILE:
			if source and source is CardPile:
				(source as CardPile)._shuffle_local()
				return true
		COMMAND_FLIP_CARD:
			var flipped := 0
			for card in cards:
				if card:
					card._flip_local()
					flipped += 1
			return flipped
		COMMAND_SLOT_DROP:
			if target and target is CardSlot and not cards.is_empty():
				(target as CardSlot)._handle_drop_local(cards[0])
				return (target as CardSlot).cards.has(cards[0])
		COMMAND_SLOT_SWAP:
			if source and source is CardSlot and target and target is CardSlot:
				return (source as CardSlot)._swap_with_local(target as CardSlot)
		COMMAND_SET_CARD_DATA:
			var updated := 0
			for card in cards:
				if card and card.card_data:
					var state: Dictionary = command.get("metadata", {}).get("card_state", {})
					if state.has("card_data") and state.card_data is Dictionary:
						card.card_data.apply_network_data(state.card_data)
						card.refresh_layout()
						updated += 1
			return updated
	return false


func _validate_command(command: Dictionary, sender_id: int) -> String:
	var type := String(command.get("type", ""))
	if type.is_empty():
		return "missing_type"

	var revision := int(command.get("revision", 0))
	if revision < state_revision - REVISION_TOLERANCE:
		return "stale_revision"

	var card_ids: PackedStringArray = _get_card_id_array(command)
	if card_ids.size() > MAX_COMMAND_CARDS:
		return "too_many_cards"
	if _has_duplicate_card_ids(card_ids):
		return "duplicate_cards"

	var source := get_container(StringName(command.get("source_container_id", &"")))
	var target := get_container(StringName(command.get("target_container_id", &"")))
	var cards := _get_cards_from_command(command)
	if card_ids.size() > 0 and cards.size() != card_ids.size():
		return "missing_card"

	match type:
		COMMAND_REQUEST_SNAPSHOT:
			return ""
		COMMAND_SHUFFLE_PILE:
			if not source:
				return "missing_source"
			if not _sender_can_command_container(sender_id, source):
				return "source_not_allowed"
			return ""
		COMMAND_DEAL_TO:
			if not source:
				return "missing_source"
			if not target:
				return "missing_target"
			if not _sender_can_command_container(sender_id, source):
				return "source_not_allowed"
			if not _sender_can_command_container(sender_id, target):
				return "target_not_allowed"
			var count := int(command.get("metadata", {}).get("count", 0))
			if count < 0 or count > MAX_COMMAND_CARDS:
				return "invalid_count"
			if count > source.get_card_count():
				return "not_enough_cards"
			var remaining := target.get_remaining_space()
			if remaining >= 0 and count > remaining:
				return "target_full"
			return ""
		COMMAND_REORDER_HAND, COMMAND_SET_CONTAINER_ORDER:
			if not source:
				return "missing_source"
			if not _sender_can_command_container(sender_id, source):
				return "source_not_allowed"
			if card_ids.size() != source.get_card_count():
				return "order_size_mismatch"
			for card in cards:
				if not card or card.get_parent() != source or not source.cards.has(card):
					return "card_not_in_source"
			return ""
		COMMAND_SLOT_SWAP:
			if not source or not (source is CardSlot):
				return "missing_source_slot"
			if not target or not (target is CardSlot):
				return "missing_target_slot"
			if not _sender_can_command_container(sender_id, source):
				return "source_not_allowed"
			if not _sender_can_command_container(sender_id, target):
				return "target_not_allowed"
			var source_slot := source as CardSlot
			var target_slot := target as CardSlot
			if source_slot.slot_locked or target_slot.slot_locked:
				return "slot_locked"
			if source_slot.is_empty() or target_slot.is_empty():
				return "slot_empty"
			return ""
		COMMAND_SLOT_DROP:
			if not target or not (target is CardSlot):
				return "missing_target_slot"
			if not _sender_can_command_container(sender_id, target):
				return "target_not_allowed"
			if cards.is_empty():
				return "missing_card"
			var incoming := cards[0]
			if not incoming:
				return "missing_card"
			if not _sender_can_command_card(sender_id, incoming):
				return "card_not_allowed"
			var slot := target as CardSlot
			if slot.slot_locked:
				return "slot_locked"
			if not slot._check_conditions(incoming):
				return "failed_conditions"
			if slot.is_full() and not slot.allow_swap and incoming.get_parent() != slot:
				return "slot_full"
			return ""
		COMMAND_MOVE_CARD, COMMAND_MOVE_CARDS:
			if not source:
				return "missing_source"
			if not target:
				return "missing_target"
			if cards.is_empty():
				return "missing_cards"
			if not _sender_can_command_container(sender_id, source):
				return "source_not_allowed"
			if not _sender_can_command_container(sender_id, target):
				return "target_not_allowed"
			if source != target:
				var remaining := target.get_remaining_space()
				if remaining >= 0 and cards.size() > remaining:
					return "target_full"
			for card in cards:
				if not card:
					return "missing_card"
				if not source.cards.has(card):
					return "card_not_in_source"
				if not _sender_can_command_card(sender_id, card):
					return "card_not_allowed"
				if source != target and not target.can_accept_card(card):
					return "target_rejected"
			return ""
		COMMAND_FLIP_CARD:
			if cards.is_empty():
				return "missing_cards"
			for card in cards:
				if not card:
					return "missing_card"
				if not _sender_can_command_card(sender_id, card):
					return "card_not_allowed"
			return ""
		COMMAND_SET_CARD_DATA:
			if sender_id != SERVER_PEER_ID and not allow_remote_card_data_updates:
				return "card_data_updates_disabled"
			if cards.is_empty():
				return "missing_cards"
			for card in cards:
				if not card:
					return "missing_card"
				if not _sender_can_command_card(sender_id, card):
					return "card_not_allowed"
			return ""

	return "unsupported_command"


func _sender_can_command_container(sender_id: int, container: CardContainer) -> bool:
	if sender_id == SERVER_PEER_ID:
		return true
	if not container.allow_remote_commands:
		return false
	if container.network_owner_peer_id != 0 and container.network_owner_peer_id != sender_id:
		return false
	return true


func _sender_can_command_card(sender_id: int, card: Card) -> bool:
	if sender_id == SERVER_PEER_ID:
		return true
	if card.network_owner_peer_id != 0 and card.network_owner_peer_id != sender_id:
		return false
	var container := card.get_parent() as CardContainer
	if container:
		return _sender_can_command_container(sender_id, container)
	return true


func _reject_command(command: Dictionary, reason: String, sender_id: int) -> void:
	command_rejected.emit(command, reason)
	if sender_id != SERVER_PEER_ID and multiplayer.get_peers().has(sender_id):
		_command_rejected_remote.rpc_id(sender_id, command, reason)
		_send_snapshot_to_peer(sender_id, true)


func _send_snapshot_to_peer(peer_id: int, full_snapshot: bool, animation_duration: float = 0.0) -> void:
	if peer_id == SERVER_PEER_ID:
		return
	var snapshot := build_snapshot_for_peer(peer_id, animation_duration)
	if full_snapshot:
		_apply_full_snapshot.rpc_id(peer_id, snapshot)
	else:
		_apply_card_delta.rpc_id(peer_id, snapshot)


func _apply_snapshot_payload(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var incoming_revision := int(snapshot.get("revision", 0))
	if incoming_revision < state_revision:
		return

	begin_apply_remote_state()

	state_revision = incoming_revision
	var animation_duration := float(snapshot.get("animation_duration", 0.0))

	for container_state in snapshot.get("containers", []):
		if not container_state is Dictionary:
			continue
		_resolve_container_from_state(container_state)

	for card_state in snapshot.get("cards", []):
		if not card_state is Dictionary:
			continue
		var card := _get_or_create_card_from_state(card_state)
		if card:
			card.apply_network_state(card_state, Card.MoveConfig.new(animation_duration))

	for container_state in snapshot.get("containers", []):
		if not container_state is Dictionary:
			continue
		var container := get_container(StringName(container_state.get("container_id", &"")))
		if not container:
			continue
		container.network_owner_peer_id = int(container_state.get("owner_peer_id", 0))
		container.network_visibility_policy = int(container_state.get("visibility_policy", VisibilityPolicy.PUBLIC))
		container.allow_remote_commands = bool(container_state.get("allow_remote_commands", false))
		container.apply_network_card_order(container_state.get("card_order", PackedStringArray()), animation_duration)

	_remove_cards_missing_from_snapshot(snapshot)
	end_apply_remote_state()
	state_revision_applied.emit(state_revision)
	snapshot_applied.emit()


func _resolve_container_from_state(container_state: Dictionary) -> CardContainer:
	var id := StringName(container_state.get("container_id", &""))
	if id.is_empty():
		return null
	var container := get_container(id)
	if container:
		return container

	var node_path := String(container_state.get("node_path", ""))
	if not node_path.is_empty():
		var node := get_node_or_null(NodePath(node_path))
		if node and node is CardContainer:
			container = node as CardContainer
			container.network_id = id
			register_container(container)
			return container
	return null


func _get_or_create_card_from_state(card_state: Dictionary) -> Card:
	var id := StringName(card_state.get("card_id", &""))
	if id.is_empty():
		return null

	var card := get_card(id)
	if card:
		return card

	var resource := resolve_resource_from_payload(card_state)
	card = Card.new(resource)
	card.set_network_id(id)
	register_card(card)
	return card


func _get_move_config_from_command(command: Dictionary) -> Card.MoveConfig:
	var config := Card.MoveConfig.new()
	config.duration = float(command.get("duration", default_move_duration))
	config.index = int(command.get("target_index", -1))
	config.batch = bool(command.get("batch", false))
	return config


func _get_cards_from_command(command: Dictionary) -> Array[Card]:
	var result: Array[Card] = []
	for id in _get_card_id_array(command):
		var card := get_card(StringName(id))
		if card:
			result.append(card)
	return result


func _get_card_id_array(command: Dictionary) -> PackedStringArray:
	var raw = command.get("card_ids", PackedStringArray())
	if raw is PackedStringArray:
		return raw
	var result := PackedStringArray()
	if raw is Array:
		for value in raw:
			result.append(String(value))
	return result


func _has_duplicate_card_ids(card_ids: PackedStringArray) -> bool:
	var seen: Dictionary = {}
	for id in card_ids:
		if seen.has(id):
			return true
		seen[id] = true
	return false


func _make_command_id() -> StringName:
	var id := StringName("sc_command_%d_%d_%d" % [
		multiplayer.get_unique_id(),
		Time.get_ticks_usec(),
		_next_command_sequence,
	])
	_next_command_sequence += 1
	return id


func _timeout_pending_command(command_id: StringName, pending: PendingCommand) -> void:
	var key := String(command_id)
	if _pending_commands.get(key) != pending:
		return
	_pending_commands.erase(key)
	pending.completed.emit({
		"accepted": false,
		"value": null,
		"reason": "timeout",
	})


func _resolve_pending_command(command_id: StringName, result: Dictionary) -> void:
	if command_id.is_empty():
		return
	var pending := _pending_commands.get(String(command_id)) as PendingCommand
	if not pending:
		return
	_pending_commands.erase(String(command_id))
	pending.completed.emit(result)


func _remove_cards_missing_from_snapshot(snapshot: Dictionary) -> void:
	var incoming_ids: Dictionary = {}
	for card_state in snapshot.get("cards", []):
		if card_state is Dictionary:
			incoming_ids[String(card_state.get("card_id", &""))] = true

	for id in _cards_by_id.keys():
		if incoming_ids.has(String(id)):
			continue
		var card := get_card(StringName(id))
		_cards_by_id.erase(id)
		if not card:
			continue
		var container := card.get_parent() as CardContainer
		if container and container.cards.has(card):
			container._raw_unregister(card)
		card.queue_free()


func _cleanup_registries() -> void:
	for id in _cards_by_id.keys():
		if not is_instance_valid(_cards_by_id[id]):
			_cards_by_id.erase(id)
	for id in _containers_by_id.keys():
		if not is_instance_valid(_containers_by_id[id]):
			_containers_by_id.erase(id)
	for id in _resources_by_id.keys():
		if not is_instance_valid(_resources_by_id[id]):
			_resources_by_id.erase(id)


func _on_peer_connected(peer_id: int) -> void:
	if not enabled or not is_server_peer():
		return
	_send_snapshot_to_peer.call_deferred(peer_id, true)


func _on_server_disconnected() -> void:
	_cancel_pending_commands("server_disconnected")


func _cancel_pending_commands(reason: String) -> void:
	# Clear before emitting: awaiting callers may submit or tear down more state.
	var pending := _pending_commands.values()
	_pending_commands.clear()
	for command in pending:
		command.completed.emit({"accepted": false, "value": null, "reason": reason})
