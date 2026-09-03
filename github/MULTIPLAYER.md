# Multiplayer (Experimental)

Simple Cards includes experimental opt-in card synchronization through scene-local `CardNetworkManager` nodes.

> **Experimental:** The multiplayer API is available for testing, but class names, command payloads, visibility behavior, and helper methods may change before it is considered stable.

This guide covers the built-in multiplayer path. For custom transports, custom authority models, or non-Godot networking backends, see [Custom Multiplayer](CUSTOM_MULTIPLAYER.md).

## What The Addon Handles

The card network layer synchronizes card and container state:

- card movement, dealing, sorting, shuffling, flipping, hand reorder, and slot drop/swap,
- stable card/container IDs,
- peer-specific visibility for private hands and hidden piles,
- late-join snapshots,
- animation durations for remote card movement,
- command rejection signals.

Your game still owns:

- creating the `MultiplayerPeer`,
- lobbies, matchmaking, NAT traversal, authentication, and reconnect flow,
- turn order, score, timers, phases, and game-specific rules,
- game-specific RPCs for actions that need rule validation.

## Choose A Network Manager

Use `CardServerAuthoritativeNetwork` when one peer must validate card actions. This is the recommended starting point for online games, private hands, hidden draw piles, server shuffle/deal/play validation, and late join.

Use `CardPeerToPeerNetwork` only for trusted/local games. Each peer applies its own card actions and broadcasts snapshots to the other peers. It is useful for LAN prototypes and cooperative tools, but it is not cheat-resistant.

Offline scenes do not need a network node. If no manager registers on `CG`, all card APIs stay local-only.

## Quickstart

### 1. Build The Card Scene

Start with a normal card-table scene. Add the containers your game needs:

- `CardPile` for draw, discard, stock, or scoring piles,
- `CardHand` for player hands or ordered table areas,
- `CardSlot` for fixed board positions,
- `CardDeckManager` for spawning a deck into a pile.

Give important containers stable network IDs. You can set these directly in the Inspector under `Multiplayer (Experimental)`:

- `network_id`
- `network_owner_peer_id`
- `network_visibility_policy`
- `allow_remote_commands`

Or assign them from script:

```gdscript
@onready var draw_pile: CardPile = %DrawPile
@onready var shared_area: CardHand = %SharedArea
@onready var player_1_hand: CardHand = %Player1Hand
@onready var player_2_hand: CardHand = %Player2Hand

func _ready() -> void:
    draw_pile.network_id = &"draw"
    shared_area.network_id = &"shared_area"
    player_1_hand.network_id = &"player_1_hand"
    player_2_hand.network_id = &"player_2_hand"
```

You can leave IDs empty while prototyping, but explicit IDs make saved scenes, debugging, and late-join sync easier to reason about.

### 2. Configure Godot Networking

Simple Cards does not create peers. Your game still creates the `MultiplayerPeer`.

Minimal local host/client setup:

```gdscript
const PORT := 24455
const SERVER_PEER_ID := 1

func host_game() -> void:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(PORT, 8)
    if error != OK:
        push_error("Host failed: %s" % error_string(error))
        return
    multiplayer.multiplayer_peer = peer


func join_game(address: String = "127.0.0.1") -> void:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(address, PORT)
    if error != OK:
        push_error("Join failed: %s" % error_string(error))
        return
    multiplayer.multiplayer_peer = peer
```

### 3. Add A CardNetwork Node

Add a node named `CardNetwork` to the multiplayer game scene:

```text
GameScene
  CardNetwork
```

For server-authoritative multiplayer, set its script to:

```text
res://addons/simple_cards/network/card_server_authoritative_network.gd
```

For trusted peer-to-peer multiplayer, use:

```text
res://addons/simple_cards/network/card_peer_to_peer_network.gd
```

Make it a unique-name node so scripts can use `%CardNetwork`, then keep a typed reference:

```gdscript
@onready var card_network: CardServerAuthoritativeNetwork = %CardNetwork
```

Use `CardPeerToPeerNetwork` as the type when the scene node uses the peer-to-peer script.

### 4. Set Ownership And Visibility

The server must know all cards. Clients should only receive the card identities they are allowed to know.

Common setup for a two-player private-hand game:

```gdscript
func configure_network_containers(player_1_peer_id: int, player_2_peer_id: int) -> void:
    player_1_hand.network_owner_peer_id = player_1_peer_id
    player_1_hand.network_visibility_policy = CardNetworkManager.VisibilityPolicy.OWNER_ONLY
    player_1_hand.allow_remote_commands = true

    player_2_hand.network_owner_peer_id = player_2_peer_id
    player_2_hand.network_visibility_policy = CardNetworkManager.VisibilityPolicy.OWNER_ONLY
    player_2_hand.allow_remote_commands = true

    draw_pile.network_visibility_policy = CardNetworkManager.VisibilityPolicy.HIDDEN
    draw_pile.allow_remote_commands = false

    shared_area.network_visibility_policy = CardNetworkManager.VisibilityPolicy.PUBLIC
    shared_area.allow_remote_commands = false

    card_network.register_container(draw_pile)
    card_network.register_container(shared_area)
    card_network.register_container(player_1_hand)
    card_network.register_container(player_2_hand)
```

Visibility policies:

- `PUBLIC`: all peers receive card resource identity and serialized data.
- `OWNER_ONLY`: only the container/card owner and server receive identity/data.
- `FACE_UP_PUBLIC`: everyone sees identity/data only while the card is face up.
- `HIDDEN`: clients receive only opaque card IDs and back layouts.

Ownership is controlled by:

```gdscript
container.network_owner_peer_id = peer_id
card.network_owner_peer_id = peer_id
```

When a peer cannot see a card, its wire ID is regenerated for every snapshot. The canonical server ID is never sent to that peer, so a previously revealed card cannot be followed through a hidden shuffle by ID.

### 5. Spawn, Shuffle, And Deal On The Server

Only the server should create the starting card state in server-authoritative games.

```gdscript
@export var deck: CardDeck
@onready var deck_manager: CardDeckManager = $CardDeckManager

func start_match() -> void:
    if not multiplayer.is_server():
        return

    deck_manager.network_spawn_cards = true
    deck_manager.setup(deck, draw_pile)

    draw_pile.shuffle()
    await draw_pile.deal_to(player_1_hand, 5, Card.MoveConfig.new(0.2, -1, 0.03))
    await draw_pile.deal_to(player_2_hand, 5, Card.MoveConfig.new(0.2, -1, 0.03))
```

Runtime card IDs are opaque session IDs. Do not use deck index, suit, value, or resource path as hidden-card identity.

### 6. Use Normal Card APIs

The active `CardNetworkManager` keeps the existing card API intact:

```gdscript
card.move_to(shared_area, Card.MoveConfig.new(0.18))
var dealt := await draw_pile.deal_to(player_hand, 1)
pile.shuffle()
card.flip()
```

With `CardServerAuthoritativeNetwork`:

- server calls apply locally and broadcast authoritative snapshots,
- client calls become RPC requests to peer `1`,
- the server validates commands and sends peer-specific state back,
- clients apply snapshots by stable card/container IDs, not object references,
- rejected commands emit `card_network.command_rejected`.

Bulk methods and `CardSlot.swap_with()` keep their return semantics in network mode. Await them on clients to receive the server-approved result:

```gdscript
var dealt := await draw_pile.deal_to(player_hand, 5)
var swapped := await left_slot.swap_with(right_slot)
```

The same calls can originate on a client only when all involved containers explicitly allow remote commands.

### 7. Validate Game-Specific Actions

Containers deny remote commands by default. Set `allow_remote_commands = true` only when every structurally valid generic action to or from that container is legal in your game.

The built-in validator checks ownership, capacity, slot locks, conditions, permissions, command size, and stale revisions. It does not know your turn order, scoring rules, or card-specific game rules. For those, use a game-specific server RPC and apply card moves from server code:

```gdscript
func request_play_card(card_id: StringName) -> void:
    if multiplayer.is_server():
        play_card_on_server(card_id, multiplayer.get_unique_id())
    else:
        _request_play_card.rpc_id(SERVER_PEER_ID, card_id)


@rpc("any_peer", "reliable")
func _request_play_card(card_id: StringName) -> void:
    if not multiplayer.is_server():
        return
    play_card_on_server(card_id, multiplayer.get_remote_sender_id())


func play_card_on_server(card_id: StringName, peer_id: int) -> void:
    var hand := hand_for_peer(peer_id)
    var card := card_network.get_card(card_id)
    if not card or not hand.cards.has(card):
        return
    if peer_id != current_turn_peer_id:
        return

    card.move_to(shared_area, Card.MoveConfig.new(0.18))
```

### 8. Sync Game State Separately

The active card network manager synchronizes cards and containers. Your game still owns turn, score, phase, timers, and rule-specific state.

Send that state from the server with your own RPC:

```gdscript
var current_turn_peer_id := 0
var player_1_score := 0
var player_2_score := 0

func broadcast_game_state() -> void:
    if not multiplayer.is_server():
        return
    var state := {
        "turn": current_turn_peer_id,
        "player_1_score": player_1_score,
        "player_2_score": player_2_score,
    }
    apply_game_state(state)
    _apply_game_state_remote.rpc(state)


@rpc("authority", "reliable")
func _apply_game_state_remote(state: Dictionary) -> void:
    apply_game_state(state)


func apply_game_state(state: Dictionary) -> void:
    current_turn_peer_id = int(state.get("turn", current_turn_peer_id))
    player_1_score = int(state.get("player_1_score", player_1_score))
    player_2_score = int(state.get("player_2_score", player_2_score))
```

Do not calculate private scores on clients from hidden card resources. If a client cannot know hidden card identity, it also cannot safely derive score from those cards. Send authoritative score/count values from the server.

### 9. Handle Late Join

When a client finishes loading the game scene, request a card snapshot from the server:

```gdscript
func _on_connected_to_server() -> void:
    card_network._request_full_snapshot.rpc_id(SERVER_PEER_ID)
```

Also send your game-state RPC after peer connect or after snapshot request, so late joiners receive turn, score, and phase text.

### 10. Present Private Hands Locally

Private data filtering happens in card network snapshots. A server process still has all authoritative card data in memory. If the server also renders a player UI, mask opponent cards in that local presentation.

Use the local display override for presentation-only card backs:

```gdscript
func show_owned_hand(hand: CardHand) -> void:
    for card in hand.cards:
        card.set_local_face_override(-1)
        card.disabled = false


func show_opponent_hand(hand: CardHand) -> void:
    for card in hand.cards:
        card.set_local_face_override(0)
        card.disabled = true
```

This changes only the local visual face. It does not change authoritative `card.is_front_face`.

For stronger secrecy from the server machine's user, use a dedicated non-player server.

## Data Model Details

### IDs

Cards and containers have network IDs:

```gdscript
card.network_id
container.network_id
```

Empty container IDs are assigned from the scene path. Scene-authored cards receive deterministic scene-path IDs, while runtime cards receive opaque session IDs.

For predictable scenes, setting explicit container IDs is recommended:

```gdscript
draw_pile.network_id = &"draw"
player_hand.network_id = &"player_1_hand"
opponent_hand.network_id = &"player_2_hand"
card_network.register_container(draw_pile)
card_network.register_container(player_hand)
card_network.register_container(opponent_hand)
```

### Hidden And Visible Cards

Hidden cards are sent like this:

```gdscript
{
    "card_id": StringName,
    "container_id": StringName,
    "index": int,
    "known": false,
    "is_front_face": false,
    "back_layout_name": StringName,
}
```

Visible cards include `resource_id`, optional `resource_path`, and `card_data`.

### Card Data

`CardResource.to_network_data()` serializes stored/exported Variant-safe values only. It skips `Object`, `Resource`, `RID`, `Callable`, `Signal`, and nested arrays/dictionaries containing them.

Override these methods for custom behavior:

```gdscript
func get_network_resource_id() -> StringName
func to_network_data(for_peer_id: int = 0) -> Dictionary
func apply_network_data(data: Dictionary) -> void
```

By default, `get_network_resource_id()` uses `network_resource_id` if set, otherwise `resource_path`.

`CardServerAuthoritativeNetwork.allow_remote_card_data_updates` defaults to `false`. Enable it only when your server validates every mutable field; otherwise clients could alter rule-relevant card values.

## Commands And Snapshots

The built-in command set is:

- `MOVE_CARD`
- `MOVE_CARDS`
- `DEAL_TO`
- `REORDER_HAND`
- `SHUFFLE_PILE`
- `FLIP_CARD`
- `SLOT_DROP`
- `SLOT_SWAP`
- `SET_CARD_DATA`
- `REQUEST_SNAPSHOT`

Commands are Variant-only dictionaries. They never serialize `Card`, `CardContainer`, `CardResource`, `Callable`, or `Tween` references.

The current delta RPC carries the full authoritative card/container state for simplicity and correctness. The RPC name is `_apply_card_delta`, but the payload is snapshot-shaped.

The server validates:

- source/target containers exist,
- cards exist and belong to the claimed source,
- target containers accept the card,
- slot locks and conditions,
- remote ownership/permission,
- remote card-data mutation policy,
- command revision bounds,
- command size limits.

Rejected commands emit:

```gdscript
card_network.command_rejected(command, reason)
```

Clients request a fresh snapshot after rejection.

## Common Game Loop

A typical server-authoritative flow:

1. Server or host creates a `MultiplayerPeer`.
2. Client joins and loads the same game scene.
3. Server assigns container owners and visibility policies.
4. Server creates, shuffles, and deals cards.
5. Server broadcasts game state.
6. Client clicks or drags cards using normal addon APIs or game-specific RPCs.
7. Server validates the action.
8. Server applies card moves with `move_to`, `deal_to`, `shuffle`, or `flip`.
9. `CardNetwork` broadcasts authoritative card state.
10. Your game RPC broadcasts turn, score, and phase state.

## Debug Checklist

- A `CardNetwork` node exists at the same scene path on every multiplayer peer.
- `CG.get_network_manager()` returns the scene's `CardNetwork` node.
- The server is peer `1`.
- Containers have stable `network_id` values.
- Private hands have `OWNER_ONLY` visibility and the correct `network_owner_peer_id`.
- The server creates cards with `CardDeckManager.network_spawn_cards = true`.
- Clients request `card_network._request_full_snapshot.rpc_id(1)` after connecting.
- Scores and turn text come from server game-state RPCs, not hidden client card data.
- Server-rendered player UI masks opponent hands with `set_local_face_override(0)`.
- Rejected commands are surfaced through `card_network.command_rejected`.

## Example Scenes

Open `examples/multiplayer/p2p_macau.tscn` for a complete trusted peer-to-peer Macau sample. It uses `CardPeerToPeerNetwork` for card/container sync and small game-specific RPCs for host-coordinated turn validation.

The sample supports 2 to 6 players. It uses one standard deck for 2 to 3 players and two standard decks for 4 to 6 players. Each instance keeps one visible local `PlayerHand`; other active seats get background `CardPile` containers on demand so the network has stable zones without hand layout, reordering, or idle animation work. Because this is a trusted P2P example, the draw pile uses public network identity while the UI still shows backs; this keeps draw animations smooth. Use hidden draw piles in server-authoritative or custom infrastructure when deck secrecy matters.

Rules implemented by the sample:

- Aces skip the next player.
- Jacks start or add draw 2.
- Queens start or add draw 3.
- Kings cancel the active draw. Outside an active draw, Kings are normal cards.
- When draw is active, the next player must play a Jack, Queen, or King, or take the full draw penalty.
- A Jack or Queen used as the starting discard is non-active. A Jack or Queen left on top after a player takes the draw penalty is also non-active.
- When draw is not active, cards follow normal Macau matching: same suit or same value.

Run one instance as host, up to five instances as clients, then press **Start** on the host. Click a card in your hand to play it, or press **Draw / Take Penalty** to draw one card when draw is inactive or take the current draw penalty when it is active.
