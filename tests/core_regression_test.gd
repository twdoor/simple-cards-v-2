extends Node

class RejectSlot extends CardSlot:
	var reject: bool = false
	func _check_conditions(_card: Card) -> bool:
		return not reject

var failures: Array[String] = []
var events: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _pile(root: Node) -> CardPile:
	var pile := CardPile.new()
	root.add_child(pile)
	pile.card_move_duration = 0.0
	return pile

func _card(pile: CardContainer) -> Card:
	var card := Card.new()
	card.move_to(pile, Card.MoveConfig.new(0.0))
	return card

func _run() -> void:
	await _transfers()
	await _interaction()
	await _slots()
	await _lifecycle_and_layouts()
	await _undo()
	for failure in failures:
		push_error(failure)
	if failures.is_empty(): print("Core regression tests passed.")
	get_tree().quit(0 if failures.is_empty() else 1)

func _transfers() -> void:
	var root := Node.new()
	add_child(root)
	var source := _pile(root)
	var target := _pile(root)
	target.max_cards = 2
	var a := _card(source)
	var b := _card(source)
	var c := _card(source)
	source.card_removed.connect(func(_card, _index): events.append("removed"))
	target.card_added.connect(func(_card, _index): events.append("added"))
	target.container_full.connect(func(): events.append("full"))
	var dealt := await source.deal_to(target, 3, Card.MoveConfig.new(0.0))
	expect(dealt == 2, "Partial deal must report only accepted cards.")
	expect(source.cards == [a] and target.cards == [c, b], "Deal must preserve top-of-pile order and capacity.")
	expect(events == ["removed", "added", "removed", "added", "full"], "Transfer signals must describe each mutation exactly once.")
	a.move_to(target, Card.MoveConfig.new(0.0))
	expect(a.get_parent() == source and source.cards == [a], "Rejected transfer changed ownership.")
	var same := await target.move_all_to(target, Card.MoveConfig.new(0.0))
	expect(same == 0 and target.cards == [c, b], "Same-container bulk move must be a no-op.")
	var copied := target.get_cards()
	copied.clear()
	expect(target.get_card_count() == 2, "get_cards leaked mutable storage.")
	var moved := await target.move_all_to(source, Card.MoveConfig.new(0.0, 0))
	expect(moved == 2 and target.is_empty() and source.cards == [b, c, a], "Indexed bulk transfer order/count mismatch.")
	for card in source.cards:
		expect(card.get_parent() == source, "Parent and card registry disagree.")
	root.queue_free()
	await get_tree().process_frame

func _slots() -> void:
	var root := Node.new()
	add_child(root)
	var a := RejectSlot.new()
	var b := RejectSlot.new()
	root.add_child(a)
	root.add_child(b)
	var ca := _card(a)
	var cb := _card(b)
	a.lock()
	expect(not await a.swap_with(b), "Locked slot accepted swap.")
	a.unlock()
	b.reject = true
	expect(not await a.swap_with(b), "Slot swap bypassed target conditions.")
	expect(a.get_card() == ca and b.get_card() == cb, "Rejected swap mutated cards.")
	b.reject = false
	events.clear()
	a.card_removed.connect(func(_card, _index): events.append("removed"))
	a.card_added.connect(func(_card, _index): events.append("added"))
	expect(await a.swap_with(b), "Valid slot swap failed.")
	expect(a.get_card() == cb and b.get_card() == ca, "Slot swap did not exchange ownership.")
	expect(events == ["removed", "added"], "Public slot swap omitted transfer signals.")
	a.reject = true
	b._handle_drop(a.get_card())
	expect(a.get_card() == cb and b.get_card() == ca, "Drop swap bypassed source placement conditions.")
	root.queue_free()
	await get_tree().process_frame

func _lifecycle_and_layouts() -> void:
	var root := Node.new()
	add_child(root)
	var pile := _pile(root)
	var card := _card(pile)
	var other := _card(pile)
	var doomed := _card(pile)
	pile.idle_animation = BobCardAnimation.new()
	pile._start_card_idle(doomed, 0.02)
	doomed.queue_free()
	await get_tree().create_timer(0.04).timeout
	var layout := card.get_layout()
	layout.card_size = Vector2i(91, 133)
	expect(card.size == Vector2(91, 133), "Runtime layout size did not propagate to card.")
	expect(other.get_layout().card_size != layout.card_size, "Card size leaked to another layout.")
	expect(CG.resolve_layout_id(&"missing", LayoutID.DEFAULT_BACK) == LayoutID.DEFAULT_BACK, "Missing back layout did not use back fallback.")
	var animation := BobCardAnimation.new()
	animation.looping = true
	animation.play_animation(layout)
	animation.play_animation(other.get_layout())
	await get_tree().create_timer(0.03).timeout
	animation.stop_animation(layout)
	animation.play_animation(layout)
	CG.current_held_item = card
	root.queue_free()
	await get_tree().process_frame
	expect(CG.current_held_item == null, "Held-card reference survived card teardown.")
	expect(animation._tweens.is_empty(), "Shared idle animation retained tweens after teardown.")
	await get_tree().create_timer(0.2).timeout

func _undo() -> void:
	var root := Node.new()
	add_child(root)
	var source := _pile(root)
	var target := _pile(root)
	# Keep faces stable; this test exercises undo independently of pile presentation.
	source.face_up = true
	target.face_up = true
	var a := _card(source)
	var b := _card(source)
	var undo := SolitaireUndo.new()
	root.add_child(undo)
	undo.starting_pile = source
	undo.deal_hand = target
	b.move_to(target, Card.MoveConfig.new(0.0))
	undo.record_card_move([b], source, 1, target, a)
	await undo.undo()
	expect(source.cards == [a, b] and target.is_empty() and not a.is_front_face, "Move undo failed to restore order/face.")
	await source.deal_to(target, 2, Card.MoveConfig.new(0.0))
	undo.record_draw([b, a])
	await undo.undo()
	expect(source.cards == [a, b] and target.is_empty(), "Draw undo failed to restore deck order.")
	await source.deal_to(target, 2, Card.MoveConfig.new(0.0))
	var order := target.get_cards()
	await target.move_all_to(source, Card.MoveConfig.new(0.0))
	undo.record_recycle(order)
	await undo.undo()
	expect(target.cards == order and source.is_empty(), "Recycle undo failed to restore waste order.")
	undo.record_draw(order)
	undo.clear()
	expect(not undo.can_undo(), "Undo reset retained history.")
	root.queue_free()
	await get_tree().process_frame


func _interaction() -> void:
	var root := Node.new()
	add_child(root)
	var pile := _pile(root)
	var hand := CardHand.new()
	hand.shape = LineShape.new()
	root.add_child(hand)
	var a := _card(pile)
	var b := _card(pile)
	expect(a.disabled, "Pile card should start disabled.")
	a.move_to(hand, Card.MoveConfig.new(0.02))
	b.move_to(hand, Card.MoveConfig.new(0.02))
	await get_tree().create_timer(0.06).timeout
	expect(not a.disabled and not b.disabled, "Transfer did not restore hand interaction.")
	expect(a.get_node(a.focus_next) == b, "Hand focus chain does not follow card order.")
	a.name = "A"
	b.name = "B"
	hand.sort_cards(_descending_name)
	expect(hand.cards == [b, a] and b.get_index() < a.get_index(), "Sorted overlap input order differs from visible order.")
	expect(b.get_node(b.focus_next) == a, "Sorting did not update focus chain.")
	var slot := CardSlot.new()
	root.add_child(slot)
	slot.lock()
	slot._handle_drop(a)
	expect(a.get_parent() == hand and hand.cards == [b, a], "Rejected drop changed hand order.")
	await get_tree().create_timer(0.35).timeout
	expect(not a.disabled, "Rejected drop left card disabled.")
	root.queue_free()
	await get_tree().process_frame


func _descending_name(left: Card, right: Card) -> bool:
	return String(left.name) > String(right.name)
