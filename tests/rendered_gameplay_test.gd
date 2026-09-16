## Rendered input regression. Launch with -- balatro|solitaire screenshot.png.
extends Node

var game: Node
var failed := false

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func pause(seconds: float = 0.4) -> void:
	await get_tree().create_timer(seconds).timeout

func point(control: Control, fraction := Vector2(0.5, 0.5)) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * fraction)

func motion(position: Vector2, _held: bool = false) -> void:
	get_viewport().warp_mouse(position)
	await pause(0.06)

func button(_position: Vector2, pressed: bool) -> void:
	# OS cursor position drives the addon’s drag threshold. Real button state is
	# needed so native motion events from warping do not cancel a synthetic press.
	var script := ProjectSettings.globalize_path("res://tests/native_mouse.py")
	check(OS.execute("python3", [script, "1" if pressed else "0"]) == 0, "Native mouse input failed.")
	await pause(0.06)

func click(control: Control) -> void:
	# Use the exposed outer half of a fanned card; its center can be covered
	# by the previously focused neighbor, which is deliberately drawn on top.
	var position := point(control, Vector2(0.9, 0.5) if control is Card else Vector2(0.5, 0.5))
	await motion(position)
	await pause(0.15)
	await button(position, true)
	await button(position, false)
	await pause()

func drag(card: Card, destination: Vector2, fraction := Vector2(0.5, 0.15)) -> void:
	var start := point(card, fraction)
	await motion(start)
	await button(start, true)
	for step in range(1, 13):
		await motion(start.lerp(destination, step / 12.0), true)
	check(CG.current_held_item == card, "Mouse drag expected %s, held %s at %s." % [card.name, CG.current_held_item, start])
	await button(destination, false)
	await pause(0.7)
	check(CG.current_held_item == null, "Mouse release retained the held card.")

func key(code: Key, ctrl: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		Input.parse_input_event(event)
		await pause(0.06)
	await pause()

func joy(code: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = pressed
		event.pressure = 1.0 if pressed else 0.0
		Input.parse_input_event(event)
		await pause(0.06)
	await pause()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["balatro", "solitaire"]:
		push_error("Expected balatro|solitaire and screenshot path.")
		get_tree().quit(1)
		return
	CG.rng.seed = 20260916
	var path := "res://examples/balatro/BalatroExample.tscn" if args[0] == "balatro" else "res://examples/solitaire/SolitaireExample.tscn"
	game = (load(path) as PackedScene).instantiate()
	add_child(game)
	await pause(3.0)
	get_window().grab_focus()
	await pause()
	# Complete the X11 window activation before exercising game controls.
	await motion(Vector2(10, 10))
	await button(Vector2(10, 10), true)
	await button(Vector2(10, 10), false)
	await pause()
	if args[0] == "balatro":
		await balatro()
	else:
		await solitaire()
	get_window().size = Vector2i(1024, 640)
	await pause()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(args[1]) == OK, "Screenshot failed.")
	game.queue_free()
	await pause(0.6)
	print("Rendered %s gameplay passed." % args[0] if not failed else "Rendered gameplay failed.")
	get_tree().quit(1 if failed else 0)

func balatro() -> void:
	var hand: CardHand = game.balatro_hand
	check(hand.get_card_count() == 8, "Balatro did not deal eight cards.")
	var card: Card = hand.cards.back()
	await click(card)
	check(game.balatro_hand.selected.has(card), "Mouse selection failed.")
	await click(game.gold_button)
	check(card.card_data.current_modifier == StandardCardResource.Modifier.GOLD, "Gold modifier button failed.")
	await click(card)
	await click(game.silv_button)
	check(card.card_data.current_modifier == StandardCardResource.Modifier.STEEL, "Steel modifier button failed.")
	await click(card)
	await click(game.none_button)
	check(card.card_data.current_modifier == StandardCardResource.Modifier.NONE, "Clear modifier button failed.")
	card.grab_focus()
	await key(KEY_ENTER)
	check(game.balatro_hand.selected.has(card), "Keyboard selection failed.")
	card.grab_focus()
	await joy(JOY_BUTTON_A)
	check(not game.balatro_hand.selected.has(card), "Controller accept failed to deselect.")
	await joy(JOY_BUTTON_DPAD_LEFT)
	check(get_viewport().gui_get_focus_owner() is Card and get_viewport().gui_get_focus_owner() != card, "Controller focus navigation failed.")
	await key(KEY_TAB)
	check(get_viewport().gui_get_focus_owner() != null, "Tab lost focus.")
	var order := hand.get_cards()
	await drag(card, point(hand.cards[0]) - Vector2(40, 0), Vector2(0.9, 0.5))
	check(hand.cards != order and hand.has_card(card), "Mouse reorder failed.")
	await click(game.sort_suit_button)
	check(game.sort_by_suit, "Suit sort button failed.")
	await click(game.sort_value_button)
	check(not game.sort_by_suit, "Value sort button failed.")
	await click(game.preview_draw)
	check(game.preview_visible and game.preview_hand.get_card_count() == game.draw.get_card_count(), "Draw preview failed.")
	await click(game.preview_draw)
	check(not game.preview_visible and game.preview_hand.is_empty(), "Draw preview did not close.")
	await click(hand.cards.back())
	await click(game.discard_button)
	await pause(1.0)
	check(game.discard.get_card_count() == 1 and hand.get_card_count() == 8, "Discard did not refill hand.")
	await click(hand.cards.back())
	await click(game.play_button)
	await pause(4.0)
	check(game.played_hand.is_empty() and game.discard.get_card_count() == 2 and hand.get_card_count() == 8, "Play did not complete and refill.")
	await click(game.preview_discard)
	check(game.preview_visible and game.preview_hand.get_card_count() == 2, "Discard preview failed.")
	await click(game.preview_discard)

func solitaire() -> void:
	var stock: CardPile = game.deck_manager.starting_pile
	check(stock.get_card_count() == 24, "Solitaire initial stock count is wrong.")
	var stock_order := stock.get_cards()
	await click(game.draw_card)
	check(stock.get_card_count() == 24 - game.deal_hand_num and game.deal_hand.get_card_count() == game.deal_hand_num, "Draw input failed.")
	await key(KEY_Z, true)
	check(stock.cards == stock_order and game.deal_hand.is_empty(), "Ctrl-Z failed to undo draw order.")
	game.deal_hand_num = 3
	for i in 8:
		await click(game.draw_card)
	check(stock.is_empty() and game.deal_hand.get_card_count() == 24, "Repeated stock draw lost cards.")
	var waste_order: Array[Card] = game.deal_hand.get_cards()
	await click(game.draw_card)
	await pause(1.0)
	check(stock.get_card_count() == 24 and game.deal_hand.is_empty(), "Stock recycle failed.")
	await click(game.undo_button)
	await pause(0.5)
	check(stock.is_empty() and game.deal_hand.cards == waste_order, "Recycle undo failed.")
	for card in waste_order:
		check(card.is_front_face and card.current_layout_name == card.front_layout_name, "Recycle undo concealed a previously face-up waste card.")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[1].get_basename() + "-recycle-undo.png")
	# Deterministic legal stack, using existing deck cards and real drop areas.
	for pile in [game.deal_hand] + game.all_piles:
		pile.auto_update = false
		await pile.move_all_to(stock, Card.MoveConfig.new(0.0))
	var king: Card
	var queen: Card
	var hidden: Card
	for candidate in stock.cards:
		if candidate.card_data.value == 13 and candidate.card_data.card_suit == StandardCardResource.Suit.CLUBS: king = candidate
		if candidate.card_data.value == 12 and candidate.card_data.card_suit == StandardCardResource.Suit.HEART: queen = candidate
		if candidate.card_data.value == 2 and candidate.card_data.card_suit == StandardCardResource.Suit.CLUBS: hidden = candidate
	var source: SolitaireHand = game.tableau_piles[0]
	var target: SolitaireHand = game.tableau_piles[1]
	for card in [hidden, king, queen]: card.move_to(source, Card.MoveConfig.new(0.0))
	hidden.is_front_face = false
	king.is_front_face = true
	queen.is_front_face = true
	for pile in [game.deal_hand] + game.all_piles:
		pile.auto_update = true
		pile.apply_rules()
	game.undo_manager.clear()
	await pause()
	await drag(king, point(game.foundations[0].drop_area))
	check(source.cards == [hidden, king, queen] and not game.undo_manager.can_undo(), "Illegal stack drop changed cards or undo history.")
	await drag(king, point(target.drop_area))
	check(target.cards == [king, queen] and source.cards == [hidden] and hidden.is_front_face, "Legal stack drag/flip failed.")
	await click(game.undo_button)
	check(source.cards == [hidden, king, queen] and target.is_empty() and not hidden.is_front_face, "Stack undo did not restore faces/order.")
	# A single king can move to an empty tableau after moving the queen away.
	queen.move_to(stock, Card.MoveConfig.new(0.0))
	await pause()
	await drag(king, point(target.drop_area), Vector2(0.5, 0.5))
	check(target.cards == [king], "Single-card drag failed.")
	await click(game.undo_button)
	check(source.cards == [hidden, king] and target.is_empty(), "Single-card undo failed.")
	await click(game.reset_button)
	await pause(3.0)
	check(stock.get_card_count() == 24 and game.deal_hand.is_empty() and not game.undo_manager.can_undo(), "Reset failed to restore initial state.")
	for i in 7: check(game.tableau_piles[i].get_card_count() == i + 1, "Reset tableau count is wrong.")
