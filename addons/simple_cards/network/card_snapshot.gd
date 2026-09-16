## Owns per-card snapshot resource bookkeeping and encodes/applies peer-visible state.
## Borrows the card per call; never retains its owning node.
extends RefCounted

var _data_is_local: bool = false
var _resource_path: String = ""


func reset_resource(resource: CardResource) -> void:
	_data_is_local = false
	_resource_path = resource.resource_path if resource else ""


func get_network_state(card: Card, for_peer_id: int = 0) -> Dictionary:
	var net = card._get_network_manager()
	if net:
		net.ensure_card_id(card)

	var container := card.get_parent() as CardContainer
	var container_id := &""
	var index := -1
	if container:
		container_id = container.network_id
		index = container.get_card_index(card)

	var known := true
	if net:
		known = net.can_peer_see_card(card, for_peer_id)

	var state: Dictionary = {
		"card_id": card.network_id,
		"container_id": container_id,
		"index": index,
		"owner_peer_id": card.network_owner_peer_id,
		"known": known,
		"is_front_face": card.is_front_face if known else false,
		"front_layout_name": card.front_layout_name if known else &"",
		"back_layout_name": card.back_layout_name,
	}

	if known and card.card_data:
		state["resource_id"] = card.card_data.get_network_resource_id()
		state["resource_path"] = card.card_data.resource_path if not card.card_data.resource_path.is_empty() else _resource_path
		state["card_data"] = card.card_data.to_network_data(for_peer_id)

	return state


func apply_network_state(card: Card, state: Dictionary, _config: Card.MoveConfig = null) -> void:
	if state.has("card_id"):
		card.set_network_id(StringName(state.get("card_id", &"")))
	card.network_owner_peer_id = int(state.get("owner_peer_id", card.network_owner_peer_id))
	card.back_layout_name = StringName(state.get("back_layout_name", card.back_layout_name))

	var known := bool(state.get("known", true))
	if known:
		card.front_layout_name = StringName(state.get("front_layout_name", card.front_layout_name))
		var net = card._get_network_manager()
		var resource = net.resolve_resource_from_payload(state) if net else null
		if resource:
			var resource_id := StringName(state.get("resource_id", resource.get_network_resource_id()))
			if not _data_is_local or not card.card_data or card.card_data.get_network_resource_id() != resource_id:
				# Resource IDs identify templates; mutable state belongs to each card.
				var local_resource := resource.duplicate(true) as CardResource
				local_resource.network_resource_id = resource_id
				card.card_data = local_resource
				_data_is_local = true
			var source_path := String(state.get("resource_path", resource.resource_path))
			if not source_path.is_empty():
				_resource_path = source_path
		if card.card_data and state.get("card_data", {}) is Dictionary:
			card.card_data.apply_network_data(state.get("card_data", {}))
			card.refresh_layout()
		card.is_front_face = bool(state.get("is_front_face", card.is_front_face))
	else:
		card.card_data = null
		card.is_front_face = false
