## Native release checks. Run this scene with -- --case=balatro|solitaire|macau-host|macau-client.
extends Node

var failures: Array[String] = []
var artifacts := ""
var test_case := "balatro"
var game: Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	# Use viewport coordinates directly for injected input, independently of a
	# desktop window manager resizing the native test window.
	get_tree().root.content_scale_size = Vector2i.ZERO
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): test_case = arg.trim_prefix("--case=")
		if arg.begins_with("--artifacts="): artifacts = arg.trim_prefix("--artifacts=")
	get_tree().create_timer(90.0).timeout.connect(func():
		push_error("Release smoke timed out: " + test_case)
		get_tree().quit(1))
	if "--export-smoke" in OS.get_cmdline_user_args():
		check(OS.has_feature("template"), "Export check ran in the editor executable")
	seed(214)
	match test_case:
		"balatro": await _balatro()
		"solitaire": await _solitaire()
		"macau-host", "macau-client": await _macau()
		_: check(false, "Unknown release case: " + test_case)
	if is_instance_valid(game):
		game.queue_free()
	await get_tree().create_timer(0.3).timeout
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("RELEASE_SMOKE_PASSED ", test_case)
	get_tree().quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func wait_for(condition: Callable, label: String, seconds := 12.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call():
		if Time.get_ticks_msec() > until:
			check(false, "Timed out: " + label)
			return false
		await get_tree().process_frame
	return true

func pointer(position: Vector2) -> void:
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(get_tree().root.get_final_transform() * position)
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	get_tree().root.push_input(event, true)

func click(node: Control, fraction := Vector2(0.5, 0.5)) -> void:
	var position := node.get_global_transform_with_canvas() * (node.size * fraction)
	pointer(position)
	await get_tree().create_timer(0.04).timeout
	var hovered := get_tree().root.gui_get_hovered_control()
	print("INPUT click ", node.name, " over ", hovered.get_path() if hovered else "none")
	await button(position, true)
	await button(position, false)

func button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	get_tree().root.push_input(event, true)
	await get_tree().create_timer(0.04).timeout

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_tree().root.push_input(event, true)
		await get_tree().process_frame

func joy(index: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = index
		event.pressed = pressed
		get_tree().root.push_input(event, true)
		await get_tree().process_frame

func screenshot(label: String) -> void:
	if artifacts.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(artifacts)
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(artifacts.path_join(label + ".png"))

func _balatro() -> void:
	game = load("res://examples/balatro/BalatroExample.tscn").instantiate()
	add_child(game)
	if not await wait_for(func(): return game.balatro_hand.cards.size() == 8, "initial hand"): return
	await get_tree().create_timer(0.6).timeout
	var card: Card = game.balatro_hand.cards[3]
	await click(card)
	check(game.balatro_hand.selected.has(card), "Mouse did not select Balatro card")
	await click(game.shiny_button)
	check(card.card_data.is_shiny, "Shiny button did not toggle the selected card")
	await click(card)
	await click(game.silv_button)
	check(card.card_data.current_modifier == StandardCardResource.Modifier.STEEL, "Glass button did not update card data")
	var layout := card.get_layout() as CardViewportLayout
	check(layout != null and not layout.live_source and layout.live_effects, "Shiny face has wrong capture settings")
	await screenshot("balatro-shiny-glass")
	pointer(card.get_global_transform_with_canvas() * (card.size * Vector2(0.2, 0.2)))
	await get_tree().create_timer(0.2).timeout
	check(absf(layout.get_shader_parameter(&"persp", &"x_rot")) > 0.1, "Hover did not tilt the card")
	pointer(Vector2(4, 4))
	await get_tree().create_timer(0.15).timeout
	check(layout.get_shader_parameter(&"persp", &"x_rot") == 0.0, "Hover exit did not flatten the card")
	await click(game.sort_suit_button)
	await get_tree().create_timer(0.3).timeout
	await click(card)
	await click(game.discard_button)
	if not await wait_for(func(): return game.discard.cards.has(card) and game.balatro_hand.cards.size() == 8, "discard and refill"): return
	await get_tree().create_timer(0.4).timeout
	await click(game.discard)
	check(game.preview_visible and game.shiny_button.disabled, "Pile preview did not disable modifier controls")
	await screenshot("balatro-preview")
	await key(KEY_ESCAPE)
	check(not game.preview_visible and not game.shiny_button.disabled, "Escape did not close pile preview")
	var pressed := [0]
	game.sort_value_button.pressed.connect(func(): pressed[0] += 1)
	game.sort_value_button.grab_focus()
	await key(KEY_ENTER)
	check(pressed[0] == 1, "Keyboard accept did not activate the focused button")
	await joy(JOY_BUTTON_A)
	check(pressed[0] == 2, "Controller accept did not activate the focused button")
	game.sort_suit_button.grab_focus()
	await key(KEY_TAB)
	check(not game.sort_suit_button.has_focus(), "Keyboard focus navigation did not move")
	game.sort_suit_button.grab_focus()
	await joy(JOY_BUTTON_DPAD_LEFT)
	check(not game.sort_suit_button.has_focus(), "Controller directional navigation did not move focus")
	await get_tree().create_timer(0.4).timeout
	await click(game.balatro_hand.cards.back())
	if game.balatro_hand.selected.is_empty():
		check(false, "Mouse did not select a card for play")
		return
	var selected: Card = game.balatro_hand.selected.front()
	await click(game.play_button)
	if not await wait_for(func(): return game.discard.cards.has(selected) and not game.play_button.disabled and game.balatro_hand.cards.size() == 8 and game.played_hand.cards.is_empty(), "play and refill"): return
	check(game.discard.cards.has(selected), "Played card did not reach discard")
	await screenshot("balatro-after-play")
	print("CHECKED Balatro mouse, shine/Glass, hover, sort, discard, preview, keyboard/controller accept, play")

func _solitaire() -> void:
	game = load("res://examples/solitaire/SolitaireExample.tscn").instantiate()
	add_child(game)
	if not await wait_for(func():
		var n := 0
		for hand in game.tableau_piles: n += hand.cards.size()
		return n == 28 and game.deck_manager.starting_pile.cards.size() == 24, "Solitaire deal"): return
	await get_tree().create_timer(0.7).timeout
	await screenshot("solitaire-dealt")
	await click(game.draw_card)
	if not await wait_for(func(): return game.deal_hand.cards.size() == game.deal_hand_num, "stock draw"): return
	await click(game.undo_button)
	if not await wait_for(func(): return game.deal_hand.cards.is_empty() and game.deck_manager.starting_pile.cards.size() == 24, "undo draw"): return
	await get_tree().create_timer(0.4).timeout
	# Create a legal exposed run within the actual dealt board, then drag all
	# three cards through the real CardHand/CardMat input path.
	var source: SolitaireHand = game.tableau_piles[6]
	var target: SolitaireHand = game.tableau_piles[5]
	var run: Array[Card] = source.cards.slice(source.cards.size() - 3)
	for i in run.size():
		run[i].card_data = run[i].card_data.duplicate()
		run[i].card_data.value = 8 - i
		run[i].card_data.card_suit = (StandardCardResource.Suit.SPADE if i % 2 == 0 else StandardCardResource.Suit.HEART)
		run[i].is_front_face = true
		run[i].refresh_layout()
	var top: Card = target.cards.back()
	top.card_data = top.card_data.duplicate()
	top.card_data.value = 9
	top.card_data.card_suit = StandardCardResource.Suit.HEART
	top.refresh_layout()
	source.apply_rules()
	target.apply_rules()
	await get_tree().create_timer(0.4).timeout
	var lead := run[0]
	var origin := lead.get_global_transform_with_canvas() * Vector2(lead.size.x * 0.5, 8)
	pointer(origin)
	await button(origin, true)
	pointer(origin + Vector2(25, 0))
	await get_tree().create_timer(0.15).timeout
	check(lead.holding and source.get_drag_stack().size() == 3, "Solitaire did not start a three-card drag")
	var drop := top.get_global_transform_with_canvas() * (top.size * 0.5)
	pointer(drop)
	await get_tree().create_timer(0.15).timeout
	await button(drop, false)
	if not await wait_for(func(): return lead.get_parent() == target and run[2].get_parent() == target, "three-card drop"): return
	await get_tree().create_timer(0.5).timeout
	await screenshot("solitaire-three-card-drop")
	await click(game.undo_button)
	if not await wait_for(func(): return run[0].get_parent() == source and run[2].get_parent() == source and not game.undo_manager._is_undoing, "undo stack move"): return
	for i in 53:
		if game.deck_manager.starting_pile.is_empty(): break
		await click(game.draw_card)
		await get_tree().create_timer(0.35).timeout
	check(game.deck_manager.starting_pile.is_empty(), "Stock did not drain")
	var waste_count: int = game.deal_hand.cards.size()
	await click(game.draw_card)
	if not await wait_for(func(): return game.deal_hand.cards.is_empty() and game.deck_manager.starting_pile.cards.size() == waste_count, "recycle stock"): return
	await click(game.undo_button)
	if not await wait_for(func(): return game.deal_hand.cards.size() == waste_count and not game.undo_manager._is_undoing, "undo recycle"): return
	for card in game.deal_hand.cards: check(card.is_front_face, "Undo recycle left a card face down")
	await screenshot("solitaire-undo-recycle")
	print("CHECKED Solitaire deal, draw/undo, three-card mouse drag/drop/undo, recycle/undo")

func _macau() -> void:
	game = load("res://examples/multiplayer/p2p_macau.tscn").instantiate()
	add_child(game)
	if test_case == "macau-host":
		game.host_button.pressed.emit()
		if not await wait_for(func(): return game.player_peer_ids.size() == 2, "Macau client join", 25): return
		game.start_button.pressed.emit()
		if not await wait_for(func(): return game.phase == game.Phase.PLAYING, "Macau start"): return
		check(game._current_hand_counts() == [5, 5], "Macau did not deal both private hands")
		game.draw_button.pressed.emit()
		await get_tree().create_timer(0.6).timeout
		check(game._current_hand_counts() == [6, 5], "Macau draw did not update the host hand")
		print("MACAU_MATCH_READY")
		if not await wait_for(func(): return game.phase == game.Phase.WAITING, "Macau return to lobby on disconnect"): return
		if not await wait_for(func(): return multiplayer.get_peers().size() == 1, "Macau reconnect", 25): return
		await get_tree().create_timer(0.5).timeout
		game.start_button.pressed.emit()
		if not await wait_for(func(): return game.phase == game.Phase.PLAYING, "Macau restart after reconnect"): return
		await get_tree().create_timer(1).timeout
		print("MACAU_RECONNECT_READY")
		await get_tree().create_timer(1).timeout
	else:
		game.join_button.pressed.emit()
		if not await wait_for(func(): return game.phase == game.Phase.PLAYING and game.player_hand.cards.size() == 5, "Macau snapshot", 25): return
		await get_tree().create_timer(0.7).timeout
		check(game._current_hand_counts() == [6, 5], "Macau draw did not synchronize to the client")
		check(game.player_hand.cards.all(func(card): return card.is_front_face), "Local Macau hand was not visible")
		for hand in game._seat_hands:
			if hand != game.player_hand:
				check(hand.cards.all(func(card): return card.current_layout_name == card.back_layout_name), "Remote Macau hand exposed front faces")
		await screenshot("macau-client-private-hand")
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		game.queue_free()
		await get_tree().create_timer(0.6).timeout
		game = load("res://examples/multiplayer/p2p_macau.tscn").instantiate()
		add_child(game)
		game.join_button.pressed.emit()
		if not await wait_for(func(): return game.phase == game.Phase.PLAYING and game.player_hand.cards.size() == 5, "Macau reconnect snapshot", 25): return
		game.snapshot_button.pressed.emit()
		await get_tree().create_timer(0.7).timeout
		await screenshot("macau-client-reconnected")
	print("CHECKED Macau ", test_case)
