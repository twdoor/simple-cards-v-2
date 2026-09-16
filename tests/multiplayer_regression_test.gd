extends Node


class TestIdleAnimation extends CardAnimationResource:
	var play_count: int = 0

	func _init() -> void:
		looping = true

	func play_animation(layout: CardLayout) -> void:
		play_count += 1
		if layout:
			layout.offset_top = 12.0
			layout.offset_bottom = 12.0


var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_server_snapshot_and_permissions()
	await _test_duplicate_resource_state()
	await _test_pending_command_cleanup()
	await _test_peer_to_peer_return_values()
	await _test_network_registry_cleans_up_exiting_nodes()
	await _test_network_card_order_restarts_idle_animation()

	if _failures.is_empty():
		print("Multiplayer regression tests passed.")
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)


func _test_server_snapshot_and_permissions() -> void:
	var scene := Node.new()
	scene.name = "ServerTestScene"
	add_child(scene)

	var hidden_pile := CardPile.new()
	hidden_pile.name = "HiddenPile"
	hidden_pile.network_id = &"hidden_pile"
	hidden_pile.network_visibility_policy = CardNetworkManager.VisibilityPolicy.HIDDEN
	hidden_pile.allow_remote_commands = false
	scene.add_child(hidden_pile)

	var player_hand := CardHand.new()
	player_hand.name = "PlayerHand"
	player_hand.shape = LineShape.new()
	player_hand.network_id = &"player_hand"
	player_hand.network_owner_peer_id = 2
	player_hand.allow_remote_commands = true
	scene.add_child(player_hand)
	var protected_slot := CardSlot.new()
	protected_slot.name = "ProtectedSlot"
	protected_slot.network_id = &"protected_slot"
	protected_slot.allow_remote_commands = false
	scene.add_child(protected_slot)
	await get_tree().process_frame

	var card := Card.new()
	card.name = "SceneCard"
	card._move_to_local(hidden_pile, Card.MoveConfig.new(0.0))
	card.owner = scene
	await get_tree().process_frame

	# Add the manager last to verify activation rescans existing scene nodes.
	var network := CardServerAuthoritativeNetwork.new()
	network.name = "CardNetwork"
	scene.add_child(network)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(not card.network_id.is_empty(), "Late manager activation did not assign a card ID.")
	_expect(String(card.network_id).begins_with("sc_scene_card:"), "Scene-authored card did not receive a deterministic scene ID.")
	_expect(network.get_card(card.network_id) == card, "Late manager activation did not register the existing card.")
	_expect(network.get_container(hidden_pile.network_id) == hidden_pile, "Late manager activation did not register the existing container.")

	var canonical_id := card.network_id
	var first_snapshot := network.build_snapshot_for_peer(2)
	var second_snapshot := network.build_snapshot_for_peer(2)
	var first_wire_id := _first_card_id(first_snapshot)
	var second_wire_id := _first_card_id(second_snapshot)
	_expect(not first_wire_id.is_empty(), "Hidden snapshot omitted its opaque card node.")
	_expect(first_wire_id != canonical_id, "Hidden snapshot exposed the canonical card ID.")
	_expect(first_wire_id != second_wire_id, "Hidden card ID remained trackable across snapshots.")
	_expect(_first_order_id(first_snapshot, hidden_pile.network_id) == first_wire_id, "Hidden card order did not use the peer-specific wire ID.")

	var hidden_state: Dictionary = first_snapshot.cards[0]
	_expect(not hidden_state.get("known", true), "Hidden card marked as known.")
	for field in ["resource_id", "resource_path", "card_data"]:
		_expect(not hidden_state.has(field), "Hidden snapshot exposed " + field)
	var stale := network._build_command("MOVE_CARD", hidden_pile, player_hand, [card], Card.MoveConfig.new(0.0))
	stale.revision = network.state_revision - CardServerAuthoritativeNetwork.REVISION_TOLERANCE - 1
	_expect(network._validate_command(stale, 2) == "stale_revision", "Stale command accepted.")

	var move_command := network._build_command("MOVE_CARD", hidden_pile, player_hand, [card], Card.MoveConfig.new(0.0))
	_expect(network._validate_command(move_command, 2) == "source_not_allowed", "Protected source accepted a remote move command.")

	card._move_to_local(player_hand, Card.MoveConfig.new(0.0))
	var slot_command := network._build_command("SLOT_DROP", player_hand, protected_slot, [card], null)
	_expect(network._validate_command(slot_command, 2) == "target_not_allowed", "Protected slot accepted a remote drop command.")
	var data_command := network._build_command("SET_CARD_DATA", player_hand, player_hand, [card], null)
	_expect(network._validate_command(data_command, 2) == "card_data_updates_disabled", "Remote card-data mutation was enabled by default.")

	var empty_snapshot := {
		"revision": network.state_revision + 1,
		"animation_duration": 0.0,
		"containers": [
			_container_state(hidden_pile, PackedStringArray()),
			_container_state(player_hand, PackedStringArray()),
			_container_state(protected_slot, PackedStringArray()),
		],
		"cards": [],
	}
	network._apply_snapshot_payload(empty_snapshot)
	await get_tree().process_frame
	_expect(hidden_pile.cards.is_empty() and player_hand.cards.is_empty(), "Snapshot deletion left a card registered in a container.")
	_expect(network.get_card(canonical_id) == null, "Snapshot deletion left the removed card in the network registry.")

	scene.queue_free()
	await get_tree().process_frame


func _test_peer_to_peer_return_values() -> void:
	var scene := Node.new()
	scene.name = "PeerTestScene"
	add_child(scene)

	var network := CardPeerToPeerNetwork.new()
	network.name = "CardNetwork"
	scene.add_child(network)

	var source := CardPile.new()
	source.name = "Source"
	source.network_id = &"source"
	source.allow_remote_commands = true
	scene.add_child(source)
	var target := CardHand.new()
	target.name = "Target"
	target.shape = LineShape.new()
	target.network_id = &"target"
	target.allow_remote_commands = true
	scene.add_child(target)
	var slot_a := CardSlot.new()
	slot_a.name = "SlotA"
	slot_a.network_id = &"slot_a"
	slot_a.allow_remote_commands = true
	scene.add_child(slot_a)
	var slot_b := CardSlot.new()
	slot_b.name = "SlotB"
	slot_b.network_id = &"slot_b"
	slot_b.allow_remote_commands = true
	scene.add_child(slot_b)
	await get_tree().process_frame

	network.begin_suppressed_routing()
	for index in 3:
		var card := Card.new()
		card.name = "DealCard%d" % index
		card._move_to_local(source, Card.MoveConfig.new(0.0))
	var slot_card_a := Card.new()
	slot_card_a.name = "SlotCardA"
	slot_card_a._move_to_local(slot_a, Card.MoveConfig.new(0.0))
	var slot_card_b := Card.new()
	slot_card_b.name = "SlotCardB"
	slot_card_b._move_to_local(slot_b, Card.MoveConfig.new(0.0))
	network.end_suppressed_routing()
	await get_tree().process_frame

	scene.get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	var dealt := await source.deal_to(target, 2, Card.MoveConfig.new(0.0))
	_expect(dealt == 2, "Routed deal_to() did not return the authoritative moved count.")
	_expect(target.get_card_count() == 2, "Routed deal_to() did not apply the move.")

	var swapped := await slot_a.swap_with(slot_b)
	_expect(swapped, "Routed swap_with() did not return the authoritative success value.")
	_expect(slot_a.get_card() == slot_card_b and slot_b.get_card() == slot_card_a, "Routed slot swap did not exchange cards.")

	scene.get_multiplayer().multiplayer_peer = null
	scene.queue_free()
	await get_tree().process_frame


func _test_network_registry_cleans_up_exiting_nodes() -> void:
	var scene := Node.new()
	scene.name = "RegistryCleanupScene"
	add_child(scene)

	var network := CardServerAuthoritativeNetwork.new()
	network.name = "CardNetwork"
	scene.add_child(network)

	var hand := CardHand.new()
	hand.name = "CleanupHand"
	hand.shape = LineShape.new()
	hand.network_id = &"cleanup_hand"
	scene.add_child(hand)

	var slot := CardSlot.new()
	slot.name = "CleanupSlot"
	slot.network_id = &"cleanup_slot"
	scene.add_child(slot)

	await get_tree().process_frame
	await get_tree().process_frame

	var card := Card.new()
	card.name = "CleanupCard"
	card.network_id = &"cleanup_card"
	card._move_to_local(hand, Card.MoveConfig.new(0.0))
	await get_tree().process_frame

	_expect(network.get_container(&"cleanup_hand") == hand, "Cleanup hand was not registered.")
	_expect(network.get_container(&"cleanup_slot") == slot, "Cleanup slot was not registered.")
	_expect(network.get_card(&"cleanup_card") == card, "Cleanup card was not registered.")

	scene.remove_child(hand)
	scene.remove_child(slot)
	await get_tree().process_frame

	_expect(network.get_container(&"cleanup_hand") == null, "CardHand exit left a valid stale container in the registry.")
	_expect(network.get_container(&"cleanup_slot") == null, "CardSlot exit left a valid stale container in the registry.")
	_expect(network.get_card(&"cleanup_card") == null, "Card exit left a valid stale card in the registry.")

	hand.free()
	slot.free()
	scene.queue_free()
	await get_tree().process_frame


func _test_network_card_order_restarts_idle_animation() -> void:
	var scene := Node.new()
	scene.name = "NetworkIdleRestartScene"
	add_child(scene)

	var network := CardPeerToPeerNetwork.new()
	network.name = "CardNetwork"
	scene.add_child(network)

	var source := CardPile.new()
	source.name = "IdleSource"
	source.network_id = &"idle_source"
	scene.add_child(source)

	var hand := CardHand.new()
	hand.name = "IdleHand"
	hand.shape = LineShape.new()
	hand.network_id = &"idle_hand"
	var idle_animation := TestIdleAnimation.new()
	hand.idle_animation = idle_animation
	scene.add_child(hand)
	await get_tree().process_frame

	var card := Card.new()
	card.name = "IdleCard"
	card.network_id = &"idle_card"
	card._move_to_local(source, Card.MoveConfig.new(0.0))
	await get_tree().process_frame

	hand.apply_network_card_order(PackedStringArray([String(card.network_id)]), 0.0)
	await get_tree().create_timer(0.03).timeout

	_expect(hand.cards.has(card), "Network card order did not move the card into the hand.")
	_expect(idle_animation.play_count > 0, "Network card order did not restart the hand idle animation.")
	var layout := card.get_layout()
	_expect(layout and is_equal_approx(layout.offset_top, 12.0), "Restarted idle animation did not run on the card layout.")

	scene.queue_free()
	await get_tree().process_frame


func _container_state(container: CardContainer, order: PackedStringArray) -> Dictionary:
	return {
		"container_id": container.network_id,
		"node_path": str(container.get_path()),
		"owner_peer_id": container.network_owner_peer_id,
		"visibility_policy": container.network_visibility_policy,
		"allow_remote_commands": container.allow_remote_commands,
		"card_order": order,
	}


func _first_card_id(snapshot: Dictionary) -> StringName:
	var cards: Array = snapshot.get("cards", [])
	if cards.is_empty():
		return &""
	return StringName((cards[0] as Dictionary).get("card_id", &""))


func _first_order_id(snapshot: Dictionary, container_id: StringName) -> StringName:
	for state in snapshot.get("containers", []):
		if state is Dictionary and StringName(state.get("container_id", &"")) == container_id:
			var order: PackedStringArray = state.get("card_order", PackedStringArray())
			return StringName(order[0]) if not order.is_empty() else &""
	return &""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_pending_command_cleanup() -> void:
	var network := CardServerAuthoritativeNetwork.new()
	add_child(network)
	var pending := CardServerAuthoritativeNetwork.PendingCommand.new()
	var results: Array[Dictionary] = []
	pending.completed.connect(func(result): results.append(result))
	network._pending_commands["test"] = pending
	network._timeout_pending_command(&"test", pending)
	_expect(results.size() == 1 and results[0].reason == "timeout", "Timeout did not resolve pending request.")
	network._resolve_pending_command(&"test", {"accepted": true})
	_expect(results.size() == 1, "Late reply resolved an expired request twice.")
	var exiting := CardServerAuthoritativeNetwork.PendingCommand.new()
	exiting.completed.connect(func(result): results.append(result))
	network._pending_commands["exit"] = exiting
	remove_child(network)
	_expect(network._pending_commands.is_empty(), "Manager exit retained pending commands.")
	_expect(results.size() == 2 and results[1].reason == "manager_exited", "Manager exit did not resolve pending request.")
	network.free()
	await get_tree().process_frame


func _test_duplicate_resource_state() -> void:
	var scene := Node.new()
	add_child(scene)
	var network := CardServerAuthoritativeNetwork.new()
	scene.add_child(network)
	var hand := CardHand.new()
	hand.shape = LineShape.new()
	scene.add_child(hand)
	var resource := StandardCardResource.new()
	resource.network_resource_id = &"shared_test_resource"
	resource.value = 3
	var a := Card.new(resource)
	var b := Card.new(resource)
	a._move_to_local(hand, Card.MoveConfig.new(0.0))
	b._move_to_local(hand, Card.MoveConfig.new(0.0))
	var state_a := a.get_network_state(1)
	var state_b := b.get_network_state(1)
	state_a.card_data.value = 7
	state_b.card_data.value = 9
	a.apply_network_state(state_a)
	b.apply_network_state(state_b)
	_expect(a.card_data.value == 7 and b.card_data.value == 9, "Per-card network data leaked between duplicate resources.")
	_expect(resource.value == 3, "Applying a snapshot mutated the shared resource template.")
	_expect(network._resources_by_id.size() == 1, "Resource cloning created transient registry IDs.")
	a.apply_network_state({"known": false})
	_expect(a.card_data == null and not a.is_front_face, "Concealing a visible card retained private data.")
	a.apply_network_state(state_a)
	_expect(a.card_data.value == 7 and b.card_data.value == 9, "Revealing a card lost isolated state.")
	_expect(a.get_network_state(1).resource_id == resource.network_resource_id, "Cloning changed the stable resource identity.")
	scene.queue_free()
	await get_tree().process_frame
