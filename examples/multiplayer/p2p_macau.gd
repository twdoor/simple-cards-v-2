## Trusted peer-to-peer Macau example.
##
## Run one instance as host and up to five more as clients. The host coordinates
## turn/rule state while CardPeerToPeerNetwork synchronizes the card containers.
extends CanvasLayer


const PORT := 24455
const DEFAULT_ADDRESS := "127.0.0.1"
const HOST_PEER_ID := 1
const MAX_PLAYERS := 6
const ONE_DECK_MAX_PLAYERS := 3
const STARTING_HAND_SIZE := 5
const DEAL_DURATION := 0.16
const PLAY_DURATION := 0.16
const DRAW_DURATION := 0.12
const DISCARD_REFILL_DURATION := 0.08

const VALUE_JACK := 11
const VALUE_QUEEN := 12
const VALUE_KING := 13
const VALUE_ACE := 14


enum Phase { WAITING, PLAYING, GAME_OVER }


@export var deck: CardDeck
@export var opponent_scene: PackedScene

@onready var card_network: CardPeerToPeerNetwork = %CardPeerToPeerNetwork
@onready var deck_manager: CardDeckManager = $CardDeckManager
@onready var player_hand: CardHand = %PlayerHand
@onready var opponents_box: HBoxContainer = %OpponentsBox
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var start_button: Button = %StartButton
@onready var draw_button: Button = %DrawButton
@onready var snapshot_button: Button = %SnapshotButton
@onready var status_label: Label = %StatusLabel
@onready var turn_label: Label = %TurnLabel
@onready var draw_state_label: Label = %DrawStateLabel
@onready var draw_pile: CardPile = %DrawPile
@onready var play_pile: CardPile = %PlayPile

var phase: Phase = Phase.WAITING
var player_peer_ids: Array[int] = [HOST_PEER_ID]
var current_turn_index: int = 0
var draw_active: bool = false
var draw_amount: int = 0
var last_message: String = "Host or join, then start a Macau match."
var hand_counts: Array[int] = []
var winner_peer_id: int = 0
var _pending_local_action: bool = false

var _seat_hands: Array[CardContainer] = []
var _network_hands: Dictionary = {}
var _all_hand_nodes: Array[CardContainer] = []
var _local_hand_layout: Dictionary = {}


func _ready() -> void:
	_capture_local_hand_layout()
	_initialize_hand_nodes()
	_configure_cards()
	_connect_ui()
	_connect_all_hands()
	_apply_game_state(_build_game_state(last_message))


func _capture_local_hand_layout() -> void:
	_local_hand_layout = {
		"anchor_left": player_hand.anchor_left,
		"anchor_top": player_hand.anchor_top,
		"anchor_right": player_hand.anchor_right,
		"anchor_bottom": player_hand.anchor_bottom,
		"offset_left": player_hand.offset_left,
		"offset_top": player_hand.offset_top,
		"offset_right": player_hand.offset_right,
		"offset_bottom": player_hand.offset_bottom,
		"grow_horizontal": player_hand.grow_horizontal,
		"grow_vertical": player_hand.grow_vertical,
		"size_flags_horizontal": player_hand.size_flags_horizontal,
		"size_flags_vertical": player_hand.size_flags_vertical,
	}


func _initialize_hand_nodes() -> void:
	_network_hands.clear()
	_all_hand_nodes = [player_hand]
	_seat_hands.clear()


func _configure_cards() -> void:
	deck_manager.deck = deck
	deck_manager.starting_pile = draw_pile
	deck_manager.shuffle_on_setup = true
	deck_manager.network_spawn_cards = true

	draw_pile.show_cards = true
	draw_pile.face_up = false
	play_pile.show_cards = true
	play_pile.face_up = true

	_set_default_network_id(draw_pile, &"macau_draw")
	_set_default_network_id(play_pile, &"macau_discard")
	# Trusted P2P keeps draw identities public so all peers can animate draws.
	# The local presentation still masks draw cards as backs.
	draw_pile.network_visibility_policy = CardNetworkManager.VisibilityPolicy.PUBLIC
	play_pile.network_visibility_policy = CardNetworkManager.VisibilityPolicy.PUBLIC
	draw_pile.allow_remote_commands = false
	play_pile.allow_remote_commands = false

	card_network.register_container(draw_pile)
	card_network.register_container(play_pile)
	_configure_player_hands()


func _configure_player_hands() -> void:
	# Seat remapping is local presentation/setup, never a new card command.
	card_network.begin_suppressed_routing()
	var previous_hands := _seat_hands.duplicate()
	var local_seat_index := _local_seat_index()

	_seat_hands.clear()
	for index in player_peer_ids.size():
		var hand := player_hand if index == local_seat_index else _get_or_create_network_hand(index)
		_seat_hands.append(hand)

	_transfer_cards_to_new_seat_nodes(previous_hands)

	for hand in _all_hand_nodes:
		card_network.unregister_container(hand)

	_remove_unused_network_hands()
	_refresh_all_hand_nodes()

	for index in _seat_hands.size():
		var hand := _seat_hands[index]
		_prepare_hand_container(hand)
		hand.network_id = StringName("macau_hand_%d" % index)
		hand.network_owner_peer_id = player_peer_ids[index] if index < player_peer_ids.size() else 0
		card_network.register_container(hand)
	_connect_all_hands()
	card_network.end_suppressed_routing()


func _get_or_create_network_hand(index: int) -> CardContainer:
	if _network_hands.has(index):
		var existing := _network_hands[index] as CardContainer
		if is_instance_valid(existing):
			return existing

	var hand := CardPile.new()
	hand.name = "NetworkSeat%d" % index
	hand.visible = false
	hand.show_cards = false
	hand.face_up = false
	hand.max_cards = -1
	hand.cards_focusable = false
	hand.preview_enabled = false
	add_child(hand)
	_network_hands[index] = hand
	_connect_hand(hand)
	return hand


func _remove_unused_network_hands() -> void:
	var active_network_hands: Dictionary = {}
	for hand in _seat_hands:
		if hand != player_hand:
			active_network_hands[hand] = true

	for key in _network_hands.keys().duplicate():
		var hand := _network_hands[key] as CardContainer
		if not is_instance_valid(hand):
			_network_hands.erase(key)
			continue
		if active_network_hands.has(hand):
			continue

		card_network.unregister_container(hand)
		hand.clear_and_free()
		hand.queue_free()
		_network_hands.erase(key)


func _refresh_all_hand_nodes() -> void:
	_all_hand_nodes = [player_hand]
	for hand in _network_hands.values():
		var container := hand as CardContainer
		if is_instance_valid(container):
			_all_hand_nodes.append(container)


func _prepare_hand_container(hand: CardContainer) -> void:
	hand.network_visibility_policy = CardNetworkManager.VisibilityPolicy.OWNER_ONLY
	hand.allow_remote_commands = false
	hand.max_cards = -1
	hand.cards_focusable = false
	hand.visible = false
	if hand is CardHand:
		(hand as CardHand).enable_reordering = false
		hand.cards_focusable = true
	if hand is CardPile:
		(hand as CardPile).show_cards = false
		(hand as CardPile).face_up = false


func _transfer_cards_to_new_seat_nodes(previous_hands: Array) -> void:
	for index in mini(previous_hands.size(), _seat_hands.size()):
		var old_hand := previous_hands[index] as CardContainer
		var new_hand := _seat_hands[index]
		if not old_hand or not new_hand or old_hand == new_hand:
			continue

		card_network.begin_suppressed_routing()
		for card in old_hand.cards.duplicate():
			(card as Card)._move_to_local(new_hand, Card.MoveConfig.new(0.0))
		card_network.end_suppressed_routing()


func _set_default_network_id(container: CardContainer, id: StringName) -> void:
	if container and container.network_id.is_empty():
		container.network_id = id


func _connect_ui() -> void:
	host_button.pressed.connect(_host_game)
	join_button.pressed.connect(_join_game)
	start_button.pressed.connect(_start_match)
	draw_button.pressed.connect(_draw_or_take_penalty)
	snapshot_button.pressed.connect(_request_snapshot)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	card_network.command_rejected.connect(_on_command_rejected)
	card_network.state_revision_applied.connect(_on_state_revision_applied)
	card_network.snapshot_applied.connect(_on_snapshot_applied)


func _connect_all_hands() -> void:
	for hand in _all_hand_nodes:
		_connect_hand(hand)


func _connect_hand(hand: CardContainer) -> void:
	if not hand.card_added.is_connected(_on_hand_card_added):
		hand.card_added.connect(_on_hand_card_added)
	for card in hand.cards:
		_connect_card_click(card)


func _on_hand_card_added(card: Card, _index: int) -> void:
	_connect_card_click(card)
	_apply_local_view.call_deferred()


func _connect_card_click(card: Card) -> void:
	if not card.card_clicked.is_connected(_on_card_clicked):
		card.card_clicked.connect(_on_card_clicked)
	if not card.layout_changed.is_connected(_on_card_layout_changed):
		card.layout_changed.connect(_on_card_layout_changed.unbind(1))


func _on_card_layout_changed() -> void:
	_apply_local_view.call_deferred()


func _host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS - 1)
	if error != OK:
		_apply_game_state(_build_game_state("Host failed: %s" % error_string(error)))
		return

	multiplayer.multiplayer_peer = peer
	player_peer_ids = [HOST_PEER_ID]
	phase = Phase.WAITING
	_configure_player_hands()
	_broadcast_game_state("Hosting on UDP %d. Waiting for players." % PORT)


func _join_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(DEFAULT_ADDRESS, PORT)
	if error != OK:
		_apply_game_state(_build_game_state("Join failed: %s" % error_string(error)))
		return

	multiplayer.multiplayer_peer = peer
	_apply_game_state(_build_game_state("Joining %s:%d..." % [DEFAULT_ADDRESS, PORT]))


func _start_match() -> void:
	if not _is_server_ready():
		return
	if not deck:
		_broadcast_game_state("No standard deck assigned.")
		return

	player_peer_ids = _current_connected_player_ids()
	if player_peer_ids.size() < 2:
		_broadcast_game_state("Need at least 2 players to start.")
		return
	if player_peer_ids.size() > MAX_PLAYERS:
		_broadcast_game_state("Macau supports up to %d players." % MAX_PLAYERS)
		return

	_configure_player_hands()
	card_network.begin_suppressed_routing()
	_clear_table()
	deck_manager.setup(_build_macau_deck(player_peer_ids.size()), draw_pile)
	await _deal_starting_hands()
	await draw_pile.deal_to(play_pile, 1, Card.MoveConfig.new(DEAL_DURATION))
	_show_discard_top()
	card_network.end_suppressed_routing()

	phase = Phase.PLAYING
	current_turn_index = 0
	draw_active = false
	draw_amount = 0
	winner_peer_id = 0

	_broadcast_game_state("New Macau match. Starting %s; %s begins." % [
		_card_label(play_pile.peek_top()),
		_player_name(_current_turn_peer_id()),
	])
	_broadcast_cards(DEAL_DURATION)


func _build_macau_deck(player_count: int) -> CardDeck:
	var macau_deck := CardDeck.new()
	var deck_count := 1 if player_count <= ONE_DECK_MAX_PLAYERS else 2
	macau_deck.deck_name = StringName("Macau %d deck%s" % [deck_count, "" if deck_count == 1 else "s"])

	for _copy_index in deck_count:
		for card_resource in deck.cards:
			macau_deck.cards.append(card_resource)

	return macau_deck


func _deal_starting_hands() -> void:
	for _round_index in STARTING_HAND_SIZE:
		for peer_id in player_peer_ids:
			var hand := _hand_for_peer(peer_id)
			if hand:
				await draw_pile.deal_to(hand, 1, Card.MoveConfig.new(DEAL_DURATION, -1, 0.02))
				_show_hand_top_card(hand)


func _clear_table() -> void:
	for container in [draw_pile, play_pile]:
		container.clear_and_free()
	for hand in _all_hand_nodes:
		hand.clear_and_free()


func _on_card_clicked(card: Card) -> void:
	if phase != Phase.PLAYING:
		_apply_game_state(_build_game_state("Start a match first."))
		return

	var local_peer_id := _local_view_peer_id()
	if local_peer_id != _current_turn_peer_id():
		_apply_game_state(_build_game_state("It is %s's turn." % _player_name(_current_turn_peer_id())))
		return
	if not _is_card_playable(card):
		_apply_game_state(_build_game_state("%s is not playable on %s." % [_card_label(card), _card_label(play_pile.peek_top())]))
		return

	if multiplayer.is_server():
		_play_card_on_host(card.network_id, local_peer_id, true)
	else:
		_pending_local_action = true
		_preview_local_play(card)
		_request_play_card.rpc_id(HOST_PEER_ID, card.network_id, local_peer_id)


func _preview_local_play(card: Card) -> void:
	card_network.begin_suppressed_routing()
	card._move_to_local(play_pile, Card.MoveConfig.new(PLAY_DURATION))
	card.is_front_face = true
	card_network.end_suppressed_routing()
	_apply_local_view()


@rpc("any_peer", "reliable")
func _request_play_card(card_id: StringName, actor_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = actor_peer_id
	if sender_id != actor_peer_id:
		_broadcast_game_state("Rejected play from unexpected peer.")
		return

	_play_card_on_host(card_id, actor_peer_id, true)


func _play_card_on_host(card_id: StringName, peer_id: int, broadcast_result: bool) -> void:
	if phase != Phase.PLAYING:
		_reject_play_on_host("The game is not active.", broadcast_result)
		return
	if peer_id != _current_turn_peer_id():
		_reject_play_on_host("It is %s's turn." % _player_name(_current_turn_peer_id()), broadcast_result)
		return

	var hand := _hand_for_peer(peer_id)
	var card := card_network.get_card(card_id)
	if not card or not hand or not hand.cards.has(card):
		_reject_play_on_host("That card is not in your hand.", broadcast_result)
		return
	if not _is_card_playable(card):
		_reject_play_on_host("%s is not playable on %s." % [_card_label(card), _card_label(play_pile.peek_top())], broadcast_result)
		return

	card_network.begin_suppressed_routing()
	card._move_to_local(play_pile, Card.MoveConfig.new(PLAY_DURATION))
	card.is_front_face = true
	card_network.end_suppressed_routing()

	var message := _apply_play_effect(card, peer_id)
	if hand.is_empty():
		phase = Phase.GAME_OVER
		winner_peer_id = peer_id
		draw_active = false
		draw_amount = 0
		message = "%s played %s and wins." % [_player_name(peer_id), _card_label(card)]

	_sync_cards_if_needed(PLAY_DURATION, broadcast_result)
	_apply_or_broadcast_game_state(message, broadcast_result)


func _reject_play_on_host(message: String, broadcast_result: bool) -> void:
	_sync_cards_if_needed(0.0, broadcast_result)
	_apply_or_broadcast_game_state(message, broadcast_result)


func _apply_play_effect(card: Card, peer_id: int) -> String:
	var value := _card_value(card)
	var card_label := _card_label(card)

	if draw_active:
		match value:
			VALUE_JACK:
				draw_amount += 2
				_advance_turn()
				return "%s stacked %s. Draw is now %d." % [_player_name(peer_id), card_label, draw_amount]
			VALUE_QUEEN:
				draw_amount += 3
				_advance_turn()
				return "%s stacked %s. Draw is now %d." % [_player_name(peer_id), card_label, draw_amount]
			VALUE_KING:
				draw_active = false
				draw_amount = 0
				_advance_turn()
				return "%s denied the draw with %s." % [_player_name(peer_id), card_label]

	if value == VALUE_JACK:
		draw_active = true
		draw_amount = 2
		_advance_turn()
		return "%s played %s. Draw 2 is active." % [_player_name(peer_id), card_label]
	if value == VALUE_QUEEN:
		draw_active = true
		draw_amount = 3
		_advance_turn()
		return "%s played %s. Draw 3 is active." % [_player_name(peer_id), card_label]
	if value == VALUE_ACE:
		var skipped_peer_id := _next_peer_id(1)
		_advance_turn(2)
		return "%s played %s and skipped %s." % [
			_player_name(peer_id),
			card_label,
			_player_name(skipped_peer_id),
		]

	_advance_turn()
	return "%s played %s." % [_player_name(peer_id), card_label]


func _draw_or_take_penalty() -> void:
	if phase != Phase.PLAYING:
		_apply_game_state(_build_game_state("Start a match first."))
		return

	var local_peer_id := _local_view_peer_id()
	if local_peer_id != _current_turn_peer_id():
		_apply_game_state(_build_game_state("It is %s's turn." % _player_name(_current_turn_peer_id())))
		return

	if multiplayer.is_server():
		await _draw_for_player_on_host(local_peer_id, true)
	else:
		_pending_local_action = true
		_apply_local_view()
		draw_button.disabled = true
		_request_draw.rpc_id(HOST_PEER_ID, local_peer_id)


@rpc("any_peer", "reliable")
func _request_draw(actor_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = actor_peer_id
	if sender_id != actor_peer_id:
		_broadcast_game_state("Rejected draw from unexpected peer.")
		return

	await _draw_for_player_on_host(actor_peer_id, true)


func _draw_for_player_on_host(peer_id: int, broadcast_result: bool) -> void:
	if phase != Phase.PLAYING:
		_apply_or_broadcast_game_state("The game is not active.", broadcast_result)
		return
	if peer_id != _current_turn_peer_id():
		_apply_or_broadcast_game_state("It is %s's turn." % _player_name(_current_turn_peer_id()), broadcast_result)
		return

	var requested := draw_amount if draw_active else 1
	var was_penalty := draw_active
	card_network.begin_suppressed_routing()
	var drawn := await _draw_cards_for_peer(peer_id, requested)
	card_network.end_suppressed_routing()

	if was_penalty:
		draw_active = false
		draw_amount = 0

	_advance_turn()
	_sync_cards_if_needed(DRAW_DURATION, broadcast_result)

	var message := "%s drew %d card%s." % [
		_player_name(peer_id),
		drawn,
		"" if drawn == 1 else "s",
	]
	if was_penalty:
		message = "%s took the draw penalty and drew %d card%s." % [
			_player_name(peer_id),
			drawn,
			"" if drawn == 1 else "s",
		]
	if drawn < requested:
		message += " The deck ran out."

	_apply_or_broadcast_game_state(message, broadcast_result)


func _draw_cards_for_peer(peer_id: int, count: int) -> int:
	var hand := _hand_for_peer(peer_id)
	if not hand:
		return 0

	var drawn := 0
	for _i in count:
		if draw_pile.is_empty():
			await _refill_draw_pile_from_discard()
		if draw_pile.is_empty():
			break
		await draw_pile.deal_to(hand, 1, Card.MoveConfig.new(DRAW_DURATION))
		_show_hand_top_card(hand)
		drawn += 1

	return drawn


func _refill_draw_pile_from_discard() -> void:
	if play_pile.get_card_count() <= 1:
		return

	var top_card := play_pile.peek_top()
	var refill_cards: Array[Card] = []
	for card in play_pile.cards:
		if card != top_card:
			refill_cards.append(card)

	await play_pile.move_cards_to(refill_cards, draw_pile, Card.MoveConfig.new(DISCARD_REFILL_DURATION, -1, 0.0, true))
	for card in draw_pile.cards:
		card.is_front_face = false
	draw_pile.shuffle()
	_show_discard_top()


func _show_hand_top_card(hand: CardContainer) -> void:
	var card := hand.get_card_at(-1)
	if card:
		card.is_front_face = true


func _show_discard_top() -> void:
	var card := play_pile.peek_top()
	if card:
		card.is_front_face = true


func _is_card_playable(card: Card) -> bool:
	if not card:
		return false

	var value := _card_value(card)
	if draw_active:
		return value == VALUE_JACK or value == VALUE_QUEEN or value == VALUE_KING

	var top_card := play_pile.peek_top()
	if not top_card:
		return true

	return _card_suit(card) == _card_suit(top_card) or value == _card_value(top_card)


func _request_snapshot() -> void:
	if multiplayer.is_server():
		_broadcast_game_state(last_message)
		card_network.bump_revision_and_broadcast()
	else:
		_request_game_state.rpc_id(HOST_PEER_ID)
		card_network._request_full_snapshot.rpc_id(HOST_PEER_ID)
	_apply_game_state(_build_game_state("Snapshot requested."))


@rpc("any_peer", "reliable")
func _request_game_state() -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	_apply_game_state_remote.rpc_id(sender_id, _build_game_state(last_message))


func _broadcast_cards(animation_duration: float = 0.0) -> void:
	card_network.bump_revision_and_broadcast(animation_duration)


func _sync_cards_if_needed(animation_duration: float, broadcast_result: bool) -> void:
	if broadcast_result:
		_broadcast_cards(animation_duration)


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if phase != Phase.WAITING:
		_disconnect_peer(peer_id)
		_broadcast_game_state("Rejected late join from peer %d." % peer_id)
		return

	player_peer_ids = _current_connected_player_ids()
	if player_peer_ids.size() > MAX_PLAYERS:
		_disconnect_peer(peer_id)
		player_peer_ids = _current_connected_player_ids()
		_broadcast_game_state("Lobby is full. Macau supports up to %d players." % MAX_PLAYERS)
		return

	_configure_player_hands()
	_broadcast_game_state("Peer %d connected. %d/%d players in lobby." % [peer_id, player_peer_ids.size(), MAX_PLAYERS])
	card_network.bump_revision_and_broadcast()


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if phase == Phase.PLAYING:
		phase = Phase.GAME_OVER
		winner_peer_id = 0
		_broadcast_game_state("Peer %d disconnected. Match ended." % peer_id)
		return

	player_peer_ids.erase(peer_id)
	if player_peer_ids.is_empty():
		player_peer_ids = [HOST_PEER_ID]
	_configure_player_hands()
	_broadcast_game_state("Peer %d disconnected. %d/%d players in lobby." % [peer_id, player_peer_ids.size(), MAX_PLAYERS])


func _disconnect_peer(peer_id: int) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer and peer.has_method("disconnect_peer"):
		peer.disconnect_peer(peer_id)


func _on_connected_to_server() -> void:
	_apply_game_state(_build_game_state("Connected as peer %d. Requesting snapshot." % multiplayer.get_unique_id()))
	_request_game_state.rpc_id(HOST_PEER_ID)
	card_network._request_full_snapshot.rpc_id(HOST_PEER_ID)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	phase = Phase.WAITING
	player_peer_ids = [HOST_PEER_ID]
	_configure_player_hands()
	_apply_game_state(_build_game_state("Connection failed. Host or join again."))


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	phase = Phase.WAITING
	player_peer_ids = [HOST_PEER_ID]
	_configure_player_hands()
	_apply_game_state(_build_game_state("Server disconnected."))


func _on_snapshot_applied() -> void:
	_connect_all_hands()
	_apply_local_view()


func _on_state_revision_applied(_revision: int) -> void:
	_apply_local_view.call_deferred()


func _on_command_rejected(_command: Dictionary, reason: String) -> void:
	_apply_game_state(_build_game_state("Command rejected: %s" % reason))


func _is_server_ready() -> bool:
	if not _has_active_network_peer():
		_apply_game_state(_build_game_state("Host a game first."))
		return false
	if not multiplayer.is_server():
		_apply_game_state(_build_game_state("Only the host can do that."))
		return false
	return true


func _current_connected_player_ids() -> Array[int]:
	var ids: Array[int] = [HOST_PEER_ID]
	for peer_id in multiplayer.get_peers():
		ids.append(int(peer_id))
	ids.sort()
	if ids.size() > MAX_PLAYERS:
		ids.resize(MAX_PLAYERS)
	return ids


func _build_game_state(message: String) -> Dictionary:
	return {
		"phase": int(phase),
		"players": player_peer_ids.duplicate(),
		"turn_index": current_turn_index,
		"draw_active": draw_active,
		"draw_amount": draw_amount,
		"hand_counts": _current_hand_counts(),
		"draw_count": draw_pile.get_card_count(),
		"discard_count": play_pile.get_card_count(),
		"winner_peer": winner_peer_id,
		"message": message,
	}


func _broadcast_game_state(message: String) -> void:
	last_message = message
	var state := _build_game_state(message)
	_apply_game_state(state)
	if _has_connected_peer():
		_apply_game_state_remote.rpc(state)


@rpc("any_peer", "reliable")
func _apply_game_state_remote(state: Dictionary) -> void:
	_apply_game_state(state)


func _apply_or_broadcast_game_state(message: String, broadcast_result: bool) -> void:
	if broadcast_result:
		_broadcast_game_state(message)
	else:
		_apply_game_state(_build_game_state(message))


func _apply_game_state(state: Dictionary) -> void:
	_pending_local_action = false
	phase = int(state.get("phase", int(phase))) as Phase
	player_peer_ids = _to_int_array(state.get("players", player_peer_ids))
	if player_peer_ids.is_empty():
		player_peer_ids = [HOST_PEER_ID]
	current_turn_index = clampi(int(state.get("turn_index", current_turn_index)), 0, max(0, player_peer_ids.size() - 1))
	draw_active = bool(state.get("draw_active", draw_active))
	draw_amount = int(state.get("draw_amount", draw_amount))
	hand_counts = _to_int_array(state.get("hand_counts", hand_counts))
	winner_peer_id = int(state.get("winner_peer", winner_peer_id))
	last_message = String(state.get("message", last_message))

	_configure_player_hands()
	status_label.text = last_message
	turn_label.text = _turn_text()
	draw_state_label.text = _draw_state_text(
		int(state.get("draw_count", draw_pile.get_card_count())),
		int(state.get("discard_count", play_pile.get_card_count()))
	)

	var has_network_peer := _has_active_network_peer()
	host_button.disabled = has_network_peer
	join_button.disabled = has_network_peer
	start_button.disabled = not has_network_peer or not multiplayer.is_server() or phase == Phase.PLAYING
	draw_button.disabled = _pending_local_action or phase != Phase.PLAYING or _local_view_peer_id() != _current_turn_peer_id()
	snapshot_button.disabled = not has_network_peer

	_update_opponent_views()
	_apply_local_view()


func _turn_text() -> String:
	if phase == Phase.WAITING:
		return "Lobby: %d/%d players" % [player_peer_ids.size(), MAX_PLAYERS]
	if phase == Phase.GAME_OVER:
		if winner_peer_id != 0:
			return "Winner: %s" % _relative_player_name(winner_peer_id, _local_view_peer_id())
		return "Match ended."

	var turn_peer_id := _current_turn_peer_id()
	var turn_owner := _relative_player_name(turn_peer_id, _local_view_peer_id())
	if draw_active:
		return "%s to respond to draw %d" % [turn_owner, draw_amount]
	return "%s to play" % turn_owner


func _draw_state_text(draw_count: int, discard_count: int) -> String:
	var active_text := "active draw %d" % draw_amount if draw_active else "no active draw"
	var deck_text := "1 deck" if player_peer_ids.size() <= ONE_DECK_MAX_PLAYERS else "2 decks"
	return "%s | draw %d | discard %d | %s" % [deck_text, draw_count, discard_count, active_text]


func _update_opponent_views() -> void:
	for child in opponents_box.get_children():
		opponents_box.remove_child(child)
		child.queue_free()

	var viewer_peer_id := _local_view_peer_id()
	for peer_id in player_peer_ids:
		if peer_id == viewer_peer_id:
			continue

		var view := _create_opponent_view(peer_id)
		opponents_box.add_child(view)


func _create_opponent_view(peer_id: int) -> Control:
	var view: Control = null
	if opponent_scene:
		view = opponent_scene.instantiate() as Control
	if not view:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		view = label

	var count := _hand_count_for_peer(peer_id)
	var is_turn := phase == Phase.PLAYING and peer_id == _current_turn_peer_id()
	var player_label := _relative_player_name(peer_id, _local_view_peer_id())
	if view.has_method("set_player_info"):
		view.call("set_player_info", player_label, count, is_turn)
	elif view is Label:
		(view as Label).text = "%s\n%d cards" % [player_label, count]

	return view


func _apply_local_view() -> void:
	var local_seat_index := _local_seat_index()
	for hand in _all_hand_nodes:
		hand.visible = false

	for index in _seat_hands.size():
		var hand := _seat_hands[index]
		var is_local := index == local_seat_index and hand == player_hand

		hand.visible = is_local
		if is_local:
			_apply_saved_hand_layout(hand)
			_apply_hand_visibility(hand, true)
		else:
			_apply_hand_visibility(hand, false)

	if local_seat_index == -1:
		player_hand.visible = true
		_apply_saved_hand_layout(player_hand)
		_apply_hand_visibility(player_hand, true)

	for card in play_pile.cards:
		_show_actual_face(card)
		card.disabled = true

	for card in draw_pile.cards:
		_show_card_back(card)
		card.disabled = true


func _apply_saved_hand_layout(hand: CardHand) -> void:
	hand.anchor_left = float(_local_hand_layout["anchor_left"])
	hand.anchor_top = float(_local_hand_layout["anchor_top"])
	hand.anchor_right = float(_local_hand_layout["anchor_right"])
	hand.anchor_bottom = float(_local_hand_layout["anchor_bottom"])
	hand.offset_left = float(_local_hand_layout["offset_left"])
	hand.offset_top = float(_local_hand_layout["offset_top"])
	hand.offset_right = float(_local_hand_layout["offset_right"])
	hand.offset_bottom = float(_local_hand_layout["offset_bottom"])
	hand.grow_horizontal = int(_local_hand_layout["grow_horizontal"]) as Control.GrowDirection
	hand.grow_vertical = int(_local_hand_layout["grow_vertical"]) as Control.GrowDirection
	hand.size_flags_horizontal = int(_local_hand_layout["size_flags_horizontal"])
	hand.size_flags_vertical = int(_local_hand_layout["size_flags_vertical"])


func _apply_hand_visibility(hand: CardContainer, is_owner: bool) -> void:
	var can_play := not _pending_local_action and phase == Phase.PLAYING and _local_view_peer_id() == _current_turn_peer_id()
	for card in hand.cards:
		if is_owner:
			_show_actual_face(card)
			card.disabled = not can_play
		else:
			card.disabled = true
			_show_card_back(card)


func _show_actual_face(card: Card) -> void:
	if card:
		card.set_local_face_override(-1)


func _show_card_back(card: Card) -> void:
	if card:
		card.set_local_face_override(0)


func _advance_turn(steps: int = 1) -> void:
	if player_peer_ids.is_empty():
		current_turn_index = 0
		return
	current_turn_index = (current_turn_index + steps) % player_peer_ids.size()


func _current_turn_peer_id() -> int:
	if player_peer_ids.is_empty():
		return HOST_PEER_ID
	current_turn_index = clampi(current_turn_index, 0, player_peer_ids.size() - 1)
	return player_peer_ids[current_turn_index]


func _next_peer_id(steps: int = 1) -> int:
	if player_peer_ids.is_empty():
		return HOST_PEER_ID
	var index := (current_turn_index + steps) % player_peer_ids.size()
	return player_peer_ids[index]


func _hand_for_peer(peer_id: int) -> CardContainer:
	var index := player_peer_ids.find(peer_id)
	if index < 0 or index >= _seat_hands.size():
		return null
	return _seat_hands[index]


func _current_hand_counts() -> Array[int]:
	var counts: Array[int] = []
	for peer_id in player_peer_ids:
		var hand := _hand_for_peer(peer_id)
		counts.append(hand.get_card_count() if hand else 0)
	return counts


func _hand_count_for_peer(peer_id: int) -> int:
	var index := player_peer_ids.find(peer_id)
	if index >= 0 and index < hand_counts.size():
		return hand_counts[index]

	var hand := _hand_for_peer(peer_id)
	return hand.get_card_count() if hand else 0


func _local_seat_index() -> int:
	if not _has_active_network_peer():
		return 0
	if multiplayer.is_server():
		var host_index := player_peer_ids.find(HOST_PEER_ID)
		return host_index if host_index >= 0 else 0

	var peer := multiplayer.multiplayer_peer
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return -1

	var id := multiplayer.get_unique_id()
	if id == 0:
		return -1
	return player_peer_ids.find(id)


func _local_view_peer_id() -> int:
	var peer := multiplayer.multiplayer_peer
	if not _has_active_network_peer():
		return HOST_PEER_ID
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return HOST_PEER_ID
	if multiplayer.is_server():
		return HOST_PEER_ID
	var id := multiplayer.get_unique_id()
	return id if id != 0 else HOST_PEER_ID


func _has_connected_peer() -> bool:
	var peer := multiplayer.multiplayer_peer
	if not _has_active_network_peer():
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and not multiplayer.get_peers().is_empty()


func _has_active_network_peer() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	if peer.get_class() == "OfflineMultiplayerPeer":
		return false
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func _player_name(peer_id: int) -> String:
	if peer_id == HOST_PEER_ID:
		return "Host"
	return "Peer %d" % peer_id


func _relative_player_name(peer_id: int, viewer_peer_id: int) -> String:
	if peer_id == viewer_peer_id:
		return "You"
	return _player_name(peer_id)


func _card_value(card: Card) -> int:
	if not card or not card.card_data:
		return -1
	var standard := card.card_data as StandardCardResource
	return standard.value if standard else -1


func _card_suit(card: Card) -> int:
	if not card or not card.card_data:
		return -1
	var standard := card.card_data as StandardCardResource
	return int(standard.card_suit) if standard else -1


func _card_label(card: Card) -> String:
	if not card:
		return "no card"
	return "%s of %s" % [_value_label(_card_value(card)), _suit_label(_card_suit(card))]


func _value_label(value: int) -> String:
	match value:
		VALUE_JACK:
			return "J"
		VALUE_QUEEN:
			return "Q"
		VALUE_KING:
			return "K"
		VALUE_ACE:
			return "A"
		_:
			return str(value)


func _suit_label(suit: int) -> String:
	match suit:
		StandardCardResource.Suit.CLUBS:
			return "Clubs"
		StandardCardResource.Suit.DIAMOND:
			return "Diamonds"
		StandardCardResource.Suit.HEART:
			return "Hearts"
		StandardCardResource.Suit.SPADE:
			return "Spades"
		_:
			return "Unknown"


func _to_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is PackedInt32Array:
		for item in value:
			result.append(int(item))
	elif value is Array:
		for item in value:
			result.append(int(item))
	return result
