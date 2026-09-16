extends Node

var game: Node
var expected_players: int = 2
var role := "client"
var screenshot_path := ""
var verified_peers: Dictionary = {}
var gameplay := false
var action_done := false

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--gameplay": gameplay = true
		if argument.begins_with("--players="): expected_players = int(argument.trim_prefix("--players="))
		if argument.begins_with("--role="): role = argument.trim_prefix("--role=")
		if argument.begins_with("--screenshot="): screenshot_path = argument.trim_prefix("--screenshot=")
	_run.call_deferred()

func _run() -> void:
	game = preload("res://examples/multiplayer/p2p_macau.tscn").instantiate()
	game.name = "Game"
	add_child(game)
	if role == "server":
		game._host_game()
		print("MACAU_READY")
		while game.player_peer_ids.size() != expected_players:
			await get_tree().process_frame
		await game._start_match()
	else:
		game._join_game()
	while game.phase != game.Phase.PLAYING or game.player_hand.get_card_count() != 5:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var count: int = game.draw_pile.get_card_count() + game.play_pile.get_card_count()
	for hand in game._all_hand_nodes: count += hand.get_card_count()
	if count != (52 if expected_players <= 3 else 104):
		push_error("Macau lost cards during initial synchronization: %d" % count)
		get_tree().quit(1)
		return
	if game.play_pile.get_card_count() != 1:
		push_error("Macau starting discard was not synchronized.")
		get_tree().quit(1)
		return
	# Snapshot refresh must preserve the local five-card hand.
	game._request_snapshot()
	await get_tree().create_timer(0.3).timeout
	if game.player_hand.get_card_count() != 5:
		push_error("Macau snapshot refresh changed local hand count.")
		get_tree().quit(1)
		return
	if not screenshot_path.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("Macau %d-player %s passed." % [expected_players, role])
	# Wait for every peer's assertions before shutting down the session.
	if role != "server":
		_verified.rpc_id(1)
		return
	while verified_peers.size() != expected_players - 1:
		await get_tree().process_frame
	if gameplay:
		await _gameplay_checks()
	else:
		game.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	# Close one peer at a time so ENet never relays to another closing peer.
	for peer in multiplayer.get_peers():
		_finish.rpc_id(peer)
		while peer in multiplayer.get_peers():
			await get_tree().process_frame
		if gameplay:
			_assert(game.phase == game.Phase.GAME_OVER and "disconnected" in game.status_label.text and game.draw_button.disabled, "Disconnect presentation did not end the match.")
	if gameplay:
		game.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		print("Macau rendered gameplay passed.")
	multiplayer.multiplayer_peer = null
	get_tree().quit()

@rpc("any_peer", "reliable")
func _verified() -> void:
	if multiplayer.is_server():
		verified_peers[multiplayer.get_remote_sender_id()] = true

@rpc("authority", "reliable")
func _finish() -> void:
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	multiplayer.multiplayer_peer = null
	get_tree().quit()

func _assert(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		get_tree().quit(1)

func _click(control: Control) -> void:
	var position := control.get_global_transform_with_canvas() * (control.size * (Vector2(0.9, 0.5) if control is Card else Vector2(0.5, 0.5)))
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().create_timer(0.06).timeout

@rpc("authority", "reliable")
func _act(action: String, card_id: StringName = &"") -> void:
	if action == "play":
		await _click(game.card_network.get_card(card_id))
	elif action == "draw":
		await _click(game.draw_button)
	else:
		await _click(game.snapshot_button)
	await get_tree().create_timer(0.8).timeout
	if role == "server": action_done = true
	else: _acted.rpc_id(1)

@rpc("any_peer", "reliable")
func _acted() -> void:
	action_done = true

func _perform(peer: int, action: String, card_id: StringName = &"") -> void:
	action_done = false
	if peer == 1: await _act(action, card_id)
	else: _act.rpc_id(peer, action, card_id)
	while not action_done: await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

func _prepare_play(peer: int, value: int) -> StringName:
	var card: Card = game._hand_for_peer(peer).cards.back()
	# Apply isolated data through the snapshot API so the source resource path
	# remains available when a previously concealed card is revealed to peers.
	var state: Dictionary = card.get_network_state(peer)
	state["card_data"]["value"] = value
	state["card_data"]["card_suit"] = game.play_pile.cards.back().card_data.card_suit
	card.apply_network_state(state)
	game._broadcast_cards(0.0)
	return card.network_id

func _gameplay_checks() -> void:
	# Controlled ranks ensure both normal and penalty paths, without relying on shuffle luck.
	var jack := _prepare_play(1, 11)
	await get_tree().create_timer(0.6).timeout
	await _perform(1, "play", jack)
	_assert(game.draw_active and game.draw_amount == 2 and game.player_hand.get_card_count() == 4, "Jack play did not start the draw penalty.")
	var penalized: int = game._current_turn_peer_id()
	await _perform(penalized, "draw")
	_assert(not game.draw_active and game._hand_for_peer(penalized).get_card_count() == 7, "Remote penalty draw did not converge.")
	var actor: int = game._current_turn_peer_id()
	await _perform(actor, "draw")
	var next_actor: int = game._current_turn_peer_id()
	var before: int = game._hand_for_peer(next_actor).get_card_count()
	var normal := _prepare_play(next_actor, 5)
	await get_tree().create_timer(0.6).timeout
	await _perform(next_actor, "play", normal)
	_assert(game._hand_for_peer(next_actor).get_card_count() == before - 1 and game.play_pile.get_card_count() == 3, "Remote normal play did not converge.")
	await _perform(penalized, "snapshot")
	verified_peers.clear()
	_verify_gameplay.rpc(game._current_hand_counts())
	await _verify_gameplay(game._current_hand_counts())
	while verified_peers.size() != expected_players - 1: await get_tree().process_frame

@rpc("authority", "reliable")
func _verify_gameplay(counts: Array) -> void:
	await get_tree().create_timer(0.5).timeout
	_assert(game._current_hand_counts() == counts, "Peers disagree on hand counts after gameplay.")
	var total: int = game.draw_pile.get_card_count() + game.play_pile.get_card_count()
	for hand in game._all_hand_nodes:
		total += hand.get_card_count()
		if hand != game.player_hand:
			_assert(not hand.visible, "Opponent hand nodes became visible.")
	_assert(total == (52 if expected_players <= 3 else 104), "Gameplay lost cards.")
	for card in game.player_hand.cards:
		_assert(card._get_requested_layout_id() == card.front_layout_name, "Local hand is concealed.")
	if not screenshot_path.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(screenshot_path)
	if role != "server": _verified.rpc_id(1)
