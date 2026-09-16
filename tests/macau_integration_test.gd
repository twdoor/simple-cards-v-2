extends Node

var game: Node
var expected_players: int = 2
var role := "client"
var screenshot_path := ""
var verified_peers: Dictionary = {}

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
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
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# Close one peer at a time so ENet never relays to another closing peer.
	for peer in multiplayer.get_peers():
		_finish.rpc_id(peer)
		while peer in multiplayer.get_peers():
			await get_tree().process_frame
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
