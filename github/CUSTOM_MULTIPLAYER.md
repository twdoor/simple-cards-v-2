# Custom Multiplayer (Experimental)

This guide is for authors who want Simple Cards to use their own multiplayer infrastructure instead of the built-in `CardServerAuthoritativeNetwork` or `CardPeerToPeerNetwork`.

> **Experimental:** The multiplayer API is available for testing, but class names, command payloads, visibility behavior, and helper methods may change before it is considered stable.

## When To Write A Custom Manager

Use the built-in managers first if Godot RPCs and the included authority models fit your game.

Write a custom `CardNetworkManager` when you need:

- a third-party transport or relay,
- rollback, lockstep, deterministic replay, or custom prediction,
- a dedicated backend that is not a Godot peer,
- custom authentication or authorization,
- custom snapshot compression or delta formats,
- a different authority model from server-authoritative or trusted peer-to-peer.

The addon does not require your transport to send `Card`, `CardContainer`, `CardResource`, `Callable`, `Tween`, or other object references. Network payloads should stay Variant-safe and resolve live objects through stable IDs.

## Core Idea

Cards and containers call into `CG.get_network_manager()` when a network manager is active. Your manager decides whether public card APIs should:

- run locally,
- become a network command,
- broadcast a state change after a local mutation,
- apply received state without recursively creating more commands.

A custom manager must extend `CardNetworkManager` and implement every abstract method.

```gdscript
class_name MyCardNetwork
extends CardNetworkManager

var _cards_by_id: Dictionary = {}
var _containers_by_id: Dictionary = {}
var _resources_by_id: Dictionary = {}
var _applying_remote_state := false
var _routing_suppression := 0

func is_applying_remote_state() -> bool:
    return _applying_remote_state or _routing_suppression > 0
```

When your node enters the tree, `CardNetworkManager._ready()` registers it on `CG` and scans the current scene for cards and containers. If you override `_ready()` or `_exit_tree()`, call `super`.

```gdscript
func _ready() -> void:
    super._ready()
    # Connect your transport here.


func _exit_tree() -> void:
    # Disconnect your transport here.
    super._exit_tree()
```

## Required Responsibilities

### Routing Guards

These methods prevent local API calls from recursively generating network traffic while you are applying remote state.

```gdscript
func is_applying_remote_state() -> bool
func begin_apply_remote_state() -> void
func end_apply_remote_state() -> void
func begin_suppressed_routing() -> void
func end_suppressed_routing() -> void
```

Implement them with counters, not simple booleans, so nested operations stay balanced:

```gdscript
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
```

Use `begin_apply_remote_state()` while applying snapshots or deltas from the network. Use `begin_suppressed_routing()` when authoritative local code needs to call card/container methods without producing another command.

### Routing Decisions

These methods are called by `Card`, `CardContainer`, `CardPile`, `CardHand`, and `CardSlot` before they mutate local state.

```gdscript
func should_route_move(card: Card, target: CardContainer) -> bool
func should_route_container_command(source: CardContainer, target: CardContainer = null) -> bool
func should_route_container_order(container: CardContainer) -> bool
func should_route_pile_command(pile: CardPile) -> bool
func should_route_slot_command(slot: CardSlot, card: Card = null) -> bool
func should_broadcast_local_action() -> bool
```

Return `true` from the `should_route_*` methods when the local public API call should become a network request instead of applying immediately.

For a server-authoritative model:

- clients return `true` for routed commands,
- the server returns `false` and applies locally,
- `should_broadcast_local_action()` returns `true` only on the server and only outside remote-apply/suppression blocks.

For a trusted peer-to-peer model:

- any peer with a connected transport can route or apply-and-broadcast its local action,
- `should_broadcast_local_action()` returns `true` for local authoritative mutations outside suppression blocks.

### Registries

The addon resolves live objects through stable IDs. Your manager must track cards, containers, and resources.

```gdscript
func register_container(container: CardContainer) -> void
func unregister_container(container: CardContainer) -> void
func register_card(card: Card) -> void
func unregister_card(card: Card) -> void
func register_resource(resource: CardResource) -> void

func get_card(card_id: StringName) -> Card
func get_container(container_id: StringName) -> CardContainer
func get_resource(resource_id: StringName) -> CardResource
```

Recommended behavior:

- call `ensure_container_id()` or `ensure_card_id()` inside register methods,
- store dictionary keys as `String(container.network_id)` and `String(card.network_id)`,
- remove stale entries when `is_instance_valid()` returns `false`,
- register a card's `card_data` resource when available,
- never send object references over the wire.

Example:

```gdscript
func register_card(card: Card) -> void:
    if not is_instance_valid(card):
        return
    ensure_card_id(card)
    _cards_by_id[String(card.network_id)] = card
    if card.card_data:
        register_resource(card.card_data)


func get_card(card_id: StringName) -> Card:
    var key := String(card_id)
    var card = _cards_by_id.get(key)
    if card and is_instance_valid(card):
        return card as Card
    _cards_by_id.erase(key)
    return null
```

### ID Assignment

```gdscript
func ensure_card_id(card: Card) -> StringName
func assign_card_id(card: Card) -> StringName
func ensure_container_id(container: CardContainer) -> StringName
```

Container IDs should be stable across peers. Scene-path IDs are a good fallback for saved scenes, but explicit IDs are easier to debug.

Card IDs must represent card instances, not card definitions. If a deck has four identical resource cards, those four runtime cards need four different `network_id` values.

Recommended rules:

- keep existing non-empty IDs,
- use deterministic scene-path IDs for scene-authored cards,
- use opaque session IDs for runtime cards,
- only the authoritative side should create hidden runtime card IDs in server-authoritative games.

### Command Requests

These methods are called by public card/container APIs after routing has decided that a network command is needed.

```gdscript
func request_move(card: Card, target: CardContainer, config: Card.MoveConfig = null) -> void
func request_move_cards(cards: Array[Card], source: CardContainer, target: CardContainer, config: Card.MoveConfig = null) -> int
func request_deal(source: CardContainer, target: CardContainer, count: int, config: Card.MoveConfig = null) -> int
func request_reorder(container: CardContainer, ordered_cards: Array[Card]) -> void
func request_set_container_order(container: CardContainer) -> void
func request_shuffle(pile: CardPile) -> void
func request_flip(card: Card) -> void
func request_slot_drop(slot: CardSlot, incoming: Card) -> void
func request_slot_swap(slot: CardSlot, other_slot: CardSlot) -> bool
func request_set_card_data(card: Card) -> void
```

Your implementation should build a Variant-safe command using IDs and primitive data, send it through your transport, then apply the accepted result on the authoritative side.

Bulk methods and slot swaps have return values because user code may await them:

- `request_move_cards()` returns the accepted moved-card count,
- `request_deal()` returns the accepted dealt-card count,
- `request_slot_swap()` returns whether the swap happened.

If a request is rejected or times out, return `0` or `false`.

Move configs should be serialized by value:

```gdscript
{
    "target_index": config.index,
    "duration": config.duration,
    "batch": config.batch,
}
```

Do not serialize `config.position_callable`; callables are local code and not safe network data.

### Local Application

When the authoritative side accepts a command, call the local implementation methods, not the public API wrappers:

- `card._move_to_local(target, config)`
- `card._flip_local()`
- `source._deal_to_local(target, count, config)`
- `source._move_cards_to_local(cards, target, config)`
- `container.apply_network_card_order(card_ids, duration)`
- `pile._shuffle_local()`
- `slot._handle_drop_local(card)`
- `slot._swap_with_local(other_slot)`

Wrap these calls in suppression guards:

```gdscript
begin_suppressed_routing()
var moved := await source._deal_to_local(target, count, config)
end_suppressed_routing()
bump_revision_and_broadcast(config.duration)
```

That prevents authoritative apply code from recursively creating more network requests.

### Broadcasting

```gdscript
func bump_revision_and_broadcast(animation_duration: float = 0.0) -> void
func queue_revision_broadcast() -> void
func broadcast_state(animation_duration: float = 0.0) -> void
```

Use `state_revision` as a monotonic state version. Increment it whenever an accepted authoritative mutation should be visible to other peers.

Recommended behavior:

- `bump_revision_and_broadcast()` increments `state_revision`, then calls `broadcast_state()`,
- `queue_revision_broadcast()` coalesces multiple same-frame mutations,
- `broadcast_state()` sends peer-specific snapshots or deltas through your transport,
- emit `state_revision_applied` after local apply or broadcast.

### Snapshot Building

```gdscript
func build_snapshot_for_peer(peer_id: int = 0, animation_duration: float = 0.0) -> Dictionary
func can_peer_see_card(card: Card, peer_id: int) -> bool
func resolve_resource_from_payload(payload: Dictionary) -> CardResource
```

Snapshots should include:

- `revision`,
- `animation_duration`,
- a `containers` array with container IDs and card orders,
- a `cards` array with card state dictionaries from `Card.get_network_state(peer_id)`.

For hidden cards, use peer-specific wire IDs. `CardNetworkManager.make_hidden_wire_card_id(peer_id)` returns a per-snapshot concealed ID. Use that ID consistently in both the hidden card state and that snapshot's container order.

Visibility should respect:

- server/authority always sees all cards,
- `card.network_owner_peer_id`,
- `container.network_owner_peer_id`,
- `container.network_visibility_policy`.

Resource resolution should:

- return `null` for unknown/hidden payloads,
- look up registered resources by `resource_id`,
- optionally load `resource_path` if it exists and points to a `CardResource`,
- register loaded resources for future snapshots.

### Snapshot Application

The abstract base exposes RPC-shaped methods, but a custom transport can call them from any receive callback:

```gdscript
func _apply_card_delta(delta: Dictionary) -> void
func _apply_full_snapshot(snapshot: Dictionary) -> void
func _request_full_snapshot() -> void
func _request_card_command(command: Dictionary) -> void
```

When applying snapshot data:

1. Ignore stale revisions if your authority model requires ordered state.
2. Call `begin_apply_remote_state()`.
3. Resolve all containers first.
4. Resolve or create card nodes from card states.
5. Call `card.apply_network_state(card_state, Card.MoveConfig.new(animation_duration))`.
6. Apply container order with `container.apply_network_card_order(order, animation_duration)`.
7. Remove local cards missing from a full authoritative snapshot.
8. Call `end_apply_remote_state()`.
9. Emit `state_revision_applied` and `snapshot_applied`.

Only create missing containers if your game intentionally supports dynamic container nodes. The built-in managers expect containers to already exist in the scene and resolve them by `network_id` or `node_path`.

## Minimal Implementation Checklist

A custom manager should have:

- dictionaries for cards, containers, and resources,
- balanced remote-apply and routing-suppression guards,
- stable ID assignment,
- routing decisions for your authority model,
- Variant-safe command builders,
- command validation on the authoritative side,
- local apply code using `_move_to_local()` and other local methods,
- peer-specific snapshot building,
- peer-specific snapshot application,
- rejection and timeout behavior for awaited methods,
- late-join full snapshot handling.

## Common Mistakes

- Sending `Card` or `CardResource` objects over the wire instead of IDs and data.
- Using card resource path, suit, rank, or deck index as hidden card identity.
- Applying remote state through public methods like `card.move_to()` instead of local methods.
- Forgetting suppression guards and creating command loops.
- Creating runtime card IDs on multiple peers in a server-authoritative hidden-information game.
- Letting clients mutate `CardResource` data that affects game rules.
- Treating card synchronization as full game-state synchronization. Scores, turns, and phases still need your own RPCs.

## Reference Implementations

Use these built-in managers as working examples:

- `addons/simple_cards/network/card_server_authoritative_network.gd`
- `addons/simple_cards/network/card_peer_to_peer_network.gd`

The server-authoritative manager is the better template for validated online games. The peer-to-peer manager is shorter conceptually, but it assumes trust between peers.
