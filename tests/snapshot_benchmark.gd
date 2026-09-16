extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for count in [52, 104]:
		for peers in [2, 6]:
			var scene := Node.new()
			add_child(scene)
			var network := CardServerAuthoritativeNetwork.new()
			scene.add_child(network)
			var pile := CardPile.new()
			pile.network_id = &"benchmark_pile"
			pile.network_visibility_policy = CardNetworkManager.VisibilityPolicy.HIDDEN
			scene.add_child(pile)
			network.begin_suppressed_routing()
			pile._batch_mode = true
			for i in count:
				var card := Card.new()
				card._move_to_local(pile, Card.MoveConfig.new(0.0))
			pile._batch_mode = false
			network.end_suppressed_routing()
			var snapshots: Array[Dictionary] = []
			var bytes := 0
			var start := Time.get_ticks_usec()
			for repetition in 20:
				for peer in range(2, peers + 1):
					var snapshot := network.build_snapshot_for_peer(peer)
					bytes += var_to_bytes(snapshot).size()
					if peer == 2: snapshots.append(snapshot)
			var elapsed := Time.get_ticks_usec() - start
			scene.queue_free()
			await get_tree().process_frame
			var client_scene := Node.new()
			add_child(client_scene)
			var client := CardServerAuthoritativeNetwork.new()
			client_scene.add_child(client)
			var client_pile := CardPile.new()
			client_pile.network_id = &"benchmark_pile"
			client_scene.add_child(client_pile)
			var apply_us := 0
			for snapshot in snapshots:
				var apply_start := Time.get_ticks_usec()
				client._apply_snapshot_payload(snapshot)
				apply_us += Time.get_ticks_usec() - apply_start
				await get_tree().process_frame
			print("SNAPSHOT cards=%d players=%d bytes_per_broadcast=%d build_and_encode_us=%d apply_us_per_client=%d hidden_nodes_replaced_per_client=%d" % [count, peers, bytes / 20, elapsed / 20, apply_us / 20, count])
			client_scene.queue_free()
			await get_tree().process_frame
	get_tree().quit()
