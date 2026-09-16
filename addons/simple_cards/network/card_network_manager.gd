## Base class for scene-local Simple Cards network managers.
##
## Add a subclass node, such as [CardServerAuthoritativeNetwork], to a multiplayer
## scene. The node registers itself on [CardGlobal] so cards and containers can
## route optional networking through the active scene manager.
## @experimental: Multiplayer support may change before it is considered stable.
@abstract
class_name CardNetworkManager extends Node


enum PredictionMode { NONE, LOCAL_VISUAL_ONLY, OPTIMISTIC }
enum VisibilityPolicy { PUBLIC, OWNER_ONLY, FACE_UP_PUBLIC, HIDDEN }


signal command_rejected(command: Dictionary, reason: String)
signal state_revision_applied(revision: int)
signal snapshot_applied()


@export_group("Multiplayer (Experimental)")
## Enables card networking for this scene node.
## @experimental: Multiplayer support may change before it is considered stable.
@export var enabled: bool = true:
	set(value):
		enabled = value
		if enabled and is_inside_tree():
			_register_existing_nodes.call_deferred()
## Client prediction behavior for requested moves.
## @experimental: Multiplayer support may change before it is considered stable.
@export var prediction_mode: PredictionMode = PredictionMode.LOCAL_VISUAL_ONLY
## Default duration used when network commands do not include one.
## @experimental: Multiplayer support may change before it is considered stable.
@export var default_move_duration: float = -1.0
## Seconds to wait for an authoritative command result.
## @experimental: Multiplayer support may change before it is considered stable.
@export_range(0.1, 60.0, 0.1) var command_timeout: float = 10.0
@export_group("")


var state_revision: int = 0
var _next_hidden_wire_sequence: int = 1


func _ready() -> void:
	CardGlobal.get_instance().set_network_manager(self)
	_register_existing_nodes()
	_register_existing_nodes.call_deferred()


func _exit_tree() -> void:
	CardGlobal.get_instance().clear_network_manager(self)


func is_server_peer() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()


func ensure_card_id(card: Card) -> StringName:
	return card.network_id if card else &""


func assign_card_id(card: Card) -> StringName:
	return ensure_card_id(card)


## Return a per-snapshot ID for a concealed card so clients cannot track its
## identity through hidden zones or shuffles.
func make_hidden_wire_card_id(peer_id: int) -> StringName:
	var id := StringName("sc_hidden_%d_%d_%d" % [
		state_revision,
		peer_id,
		_next_hidden_wire_sequence,
	])
	_next_hidden_wire_sequence += 1
	return id


func _register_existing_nodes() -> void:
	if not enabled or not is_inside_tree():
		return
	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	_register_nodes_recursive(root)


func _register_nodes_recursive(node: Node) -> void:
	if node is CardContainer:
		register_container(node as CardContainer)
	if node is Card:
		register_card(node as Card)
	for child in node.get_children():
		_register_nodes_recursive(child)


func ensure_container_id(container: CardContainer) -> StringName:
	return container.network_id if container else &""


## Return true while applying received state or otherwise suppressing routed commands.
@abstract func is_applying_remote_state() -> bool

## Enter a guarded state-apply section; routed card APIs must not emit new commands inside it.
@abstract func begin_apply_remote_state() -> void

## Leave a guarded state-apply section started by [method begin_apply_remote_state].
@abstract func end_apply_remote_state() -> void

## Temporarily disable public API routing while local authoritative code mutates cards.
@abstract func begin_suppressed_routing() -> void

## Re-enable public API routing after [method begin_suppressed_routing].
@abstract func end_suppressed_routing() -> void

## Decide whether [method Card.move_to] should become a network command.
@abstract func should_route_move(_card: Card, _target: CardContainer) -> bool

## Decide whether bulk container operations should become network commands.
@abstract func should_route_container_command(_source: CardContainer, _target: CardContainer = null) -> bool

## Decide whether local card order changes should be synchronized.
@abstract func should_route_container_order(_container: CardContainer) -> bool

## Decide whether pile commands such as shuffle should be synchronized.
@abstract func should_route_pile_command(_pile: CardPile) -> bool

## Decide whether slot drop/swap actions should become network commands.
@abstract func should_route_slot_command(_slot: CardSlot, _card: Card = null) -> bool

## Return true when a local mutation should broadcast state after it finishes.
@abstract func should_broadcast_local_action() -> bool

## Track a container by its network ID so snapshots and commands can resolve it.
@abstract func register_container(_container: CardContainer) -> void

## Stop tracking a container that is leaving the active scene.
@abstract func unregister_container(_container: CardContainer) -> void

## Track a card by its network ID and register its resource when available.
@abstract func register_card(_card: Card) -> void

## Stop tracking a card that is leaving the active scene.
@abstract func unregister_card(_card: Card) -> void

## Track a resource by its network resource ID for visible card payloads.
@abstract func register_resource(_resource: CardResource) -> void

## Resolve a card ID to a live [Card], or return null when missing.
@abstract func get_card(_card_id: StringName) -> Card

## Resolve a container ID to a live [CardContainer], or return null when missing.
@abstract func get_container(_container_id: StringName) -> CardContainer

## Resolve a network resource ID to a [CardResource], or return null when missing.
@abstract func get_resource(_resource_id: StringName) -> CardResource

## Submit or apply a single-card move command.
@abstract func request_move(_card: Card, _target: CardContainer, _config: Card.MoveConfig = null) -> void

## Submit or apply a multi-card move command.
@abstract func request_move_cards(_cards: Array[Card], _source: CardContainer, _target: CardContainer, _config: Card.MoveConfig = null) -> int

## Submit or apply a deal command from one container to another.
@abstract func request_deal(_source: CardContainer, _target: CardContainer, _count: int, _config: Card.MoveConfig = null) -> int

## Submit or apply a final hand/container reorder command.
@abstract func request_reorder(_container: CardContainer, _ordered_cards: Array[Card]) -> void

## Submit or apply the container's current card order as authoritative.
@abstract func request_set_container_order(_container: CardContainer) -> void

## Submit or apply a shuffle command; implementations should synchronize final order.
@abstract func request_shuffle(_pile: CardPile) -> void

## Submit or apply a card face flip command.
@abstract func request_flip(_card: Card) -> void

## Submit or apply a card drop into a slot.
@abstract func request_slot_drop(_slot: CardSlot, _incoming: Card) -> void

## Submit or apply a swap between two slots.
@abstract func request_slot_swap(_slot: CardSlot, _other_slot: CardSlot) -> bool

## Submit or apply synchronized primitive card-resource data changes.
@abstract func request_set_card_data(_card: Card) -> void

## Advance the local state revision and broadcast the resulting snapshot/delta.
@abstract func bump_revision_and_broadcast(_animation_duration: float = 0.0) -> void

## Defer a revision broadcast so multiple same-frame mutations can coalesce.
@abstract func queue_revision_broadcast() -> void

## Broadcast current card/container state to connected peers.
@abstract func broadcast_state(_animation_duration: float = 0.0) -> void

## Build a Variant-safe, peer-specific card/container snapshot.
@abstract func build_snapshot_for_peer(_peer_id: int = 0, _animation_duration: float = 0.0) -> Dictionary

## Return whether a peer should receive visible card identity and data.
@abstract func can_peer_see_card(_card: Card, _peer_id: int) -> bool

## Resolve or load the card resource described by a visible card payload.
@abstract func resolve_resource_from_payload(_payload: Dictionary) -> CardResource

@rpc("any_peer", "reliable")
## RPC entry point for command requests.
@abstract func _request_card_command(_command: Dictionary) -> void

@rpc("authority", "reliable")
## RPC entry point for applying an incremental or snapshot-shaped state delta.
@abstract func _apply_card_delta(_delta: Dictionary) -> void

@rpc("authority", "reliable")
## RPC entry point for replacing local state from a full snapshot.
@abstract func _apply_full_snapshot(_snapshot: Dictionary) -> void

@rpc("any_peer", "reliable")
## RPC entry point for requesting a peer-specific full snapshot.
@abstract func _request_full_snapshot() -> void
