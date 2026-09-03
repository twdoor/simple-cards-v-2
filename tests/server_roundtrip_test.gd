extends Node


const PORT := 24567


var _network: CardServerAuthoritativeNetwork
var _source: CardPile
var _target: CardHand


func _ready() -> void:
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
	_network.command_timeout = 3.0
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
	var error := peer.create_server(PORT, 8)
	if error != OK:
		push_error("Roundtrip server failed to start: %s" % error_string(error))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	await get_tree().create_timer(5.0).timeout
	if _source.get_card_count() != 0 or _target.get_card_count() != 1:
		push_error("Server did not apply the client deal command.")
		get_tree().quit(1)
		return
	print("Server roundtrip passed.")
	get_tree().quit(0)


func _run_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client("127.0.0.1", PORT)
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
	print("Client roundtrip passed.")
	get_tree().quit(0)


func _get_role() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			return argument.trim_prefix("--role=")
	return ""
