extends Node


var port: int = 24567


var _network: CardServerAuthoritativeNetwork
var _source: CardPile
var _target: CardHand


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
	get_tree().create_timer(20.0).timeout.connect(func():
		push_error("Roundtrip timed out.")
		get_tree().quit(1)
	)
	_setup_board()
	await get_tree().process_frame
	await get_tree().process_frame

	var role := _get_role()
	if role == "server":
		await _run_server()
	elif role == "client":
		await _run_client()
	else:
		push_error("Use --role=server or --role=client.")
		get_tree().quit(2)


func _setup_board() -> void:
	_network = CardServerAuthoritativeNetwork.new()
	_network.name = "CardNetwork"
	_network.command_timeout = 0.4
	add_child(_network)

	_source = CardPile.new()
	_source.name = "Source"
	_source.network_id = &"roundtrip_source"
	_source.allow_remote_commands = true
	add_child(_source)

	_target = CardHand.new()
	_target.name = "Target"
	_target.shape = LineShape.new()
	_target.network_id = &"roundtrip_target"
	_target.allow_remote_commands = true
	add_child(_target)

	var card := Card.new()
	card.name = "SharedSceneCard"
	card.network_id = &"roundtrip_card"
	card._move_to_local(_source, Card.MoveConfig.new(0.0))


func _run_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 8)
	if error != OK:
		push_error("Roundtrip server failed to start: %s" % error_string(error))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	print("ROUNDTRIP_READY")


func _run_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client("127.0.0.1", port)
	if error != OK:
		push_error("Roundtrip client failed to start: %s" % error_string(error))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	await multiplayer.connected_to_server
	await get_tree().create_timer(0.2).timeout
	var dealt := await _source.deal_to(_target, 1, Card.MoveConfig.new(0.0))
	if dealt != 1:
		push_error("Client deal_to() returned %d instead of the authoritative result." % dealt)
		get_tree().quit(1)
		return
	if _target.get_card_count() != 1:
		push_error("Client did not apply the authoritative snapshot before completion.")
		get_tree().quit(1)
		return
	var rejected_deal := await _source.deal_to(_target, 1, Card.MoveConfig.new(0.0))
	if rejected_deal != 0:
		push_error("Rejected deal_to() did not return 0.")
		get_tree().quit(1)
		return
	# Deliberately lose a reply, then recover via an authoritative snapshot.
	_set_reply_mode.rpc_id(1, false)
	await get_tree().create_timer(0.1).timeout
	var timed_out := await _target.deal_to(_source, 1, Card.MoveConfig.new(0.0))
	if timed_out != 0 or not _network._pending_commands.is_empty():
		push_error("Lost reply did not time out cleanly.")
		get_tree().quit(1)
		return
	_set_reply_mode.rpc_id(1, true)
	await get_tree().create_timer(0.1).timeout
	_network._request_full_snapshot.rpc_id(1)
	await get_tree().create_timer(0.1).timeout
	var recovered := await _target.deal_to(_source, 1, Card.MoveConfig.new(0.0))
	if recovered != 1:
		push_error("Client failed to recover after timeout.")
		get_tree().quit(1)
		return
	# Recreate the client board and reconnect to an already-running server.
	multiplayer.multiplayer_peer = null
	_network.queue_free()
	_source.queue_free()
	_target.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_setup_board()
	_source.clear_and_free()
	await get_tree().process_frame
	peer = ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1", port) != OK:
		push_error("Reconnect failed to start.")
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	await multiplayer.connected_to_server
	_network._request_full_snapshot.rpc_id(1)
	while _source.get_card_count() != 1:
		await get_tree().process_frame
	if not _target.is_empty():
		push_error("Reconnect snapshot retained obsolete client cards.")
		get_tree().quit(1)
		return
	# A dropped connection must release an awaiting public API caller.
	_disconnect_test.rpc_id(1)
	await get_tree().create_timer(0.05).timeout
	var disconnected := await _source.deal_to(_target, 1, Card.MoveConfig.new(0.0))
	if disconnected != 0 or not _network._pending_commands.is_empty():
		push_error("Disconnect did not resolve pending command.")
		get_tree().quit(1)
		return
	print("Client roundtrip passed (rejection, timeout recovery, reconnect, disconnect).")
	get_tree().quit(0)


func _get_role() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			return argument.trim_prefix("--role=")
	return ""


@rpc("any_peer", "reliable")
func _set_reply_mode(value: bool) -> void:
	if multiplayer.is_server():
		_network.enabled = value


@rpc("any_peer", "reliable")
func _disconnect_test() -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	_network.enabled = false
	await get_tree().create_timer(0.15).timeout
	if _source.get_card_count() != 1 or _target.get_card_count() != 0:
		push_error("Timeout recovery left server in the wrong state.")
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer.disconnect_peer(sender)
	await get_tree().create_timer(0.2).timeout
	print("Server roundtrip passed.")
	get_tree().quit(0)
