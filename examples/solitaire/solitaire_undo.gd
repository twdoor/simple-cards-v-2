## Manages an undo stack for the Solitaire example.
##
## Records each player action (card move, draw, recycle) as a [MoveRecord]
## and can reverse them one at a time with animated playback.
## Attach as a child node of the Solitaire scene and call the [code]record_*[/code]
## methods after each action. Trigger [method undo] via button or Ctrl+Z.
class_name SolitaireUndo extends Node


#region Inner Types

class MoveRecord:
	enum Type { CARD_MOVE, DRAW, RECYCLE }

	var type: Type

	var cards: Array[Card] = []
	var source: CardContainer = null
	var source_index: int = -1
	var target: CardContainer = null
	var flipped_card: Card = null

	var drawn_cards: Array[Card] = []

	var recycled_cards: Array[Card] = []

#endregion


#region Signals

signal undo_stack_changed(can_undo: bool)

#endregion


#region Configuration

const MAX_UNDO: int = 100
const UNDO_MOVE_DURATION: float = 0.25

#endregion


#region State

var _undo_stack: Array[MoveRecord] = []
var _is_undoing: bool = false

## References set by the main solitaire script after ready.
var deal_hand: CardContainer
var starting_pile: CardContainer

#endregion


#region Public API

func can_undo() -> bool:
	return not _undo_stack.is_empty() and not _is_undoing


func clear() -> void:
	_undo_stack.clear()
	undo_stack_changed.emit(false)


func record_card_move(
	moved_cards: Array[Card],
	source: CardContainer,
	source_index: int,
	target: CardContainer,
	flipped_card: Card = null
) -> void:
	if _is_undoing:
		return
	var record := MoveRecord.new()
	record.type = MoveRecord.Type.CARD_MOVE
	record.cards = moved_cards.duplicate()
	record.source = source
	record.source_index = source_index
	record.target = target
	record.flipped_card = flipped_card
	_push(record)


func record_draw(drawn_cards: Array[Card]) -> void:
	if _is_undoing:
		return
	var record := MoveRecord.new()
	record.type = MoveRecord.Type.DRAW
	record.drawn_cards = drawn_cards.duplicate()
	_push(record)


func record_recycle(original_waste_order: Array[Card]) -> void:
	if _is_undoing:
		return
	var record := MoveRecord.new()
	record.type = MoveRecord.Type.RECYCLE
	record.recycled_cards = original_waste_order.duplicate()
	_push(record)


func undo() -> void:
	if not can_undo():
		return

	_is_undoing = true
	var record := _undo_stack.pop_back() as MoveRecord

	match record.type:
		MoveRecord.Type.CARD_MOVE:
			await _undo_card_move(record)
		MoveRecord.Type.DRAW:
			await _undo_draw(record)
		MoveRecord.Type.RECYCLE:
			await _undo_recycle(record)

	_is_undoing = false
	undo_stack_changed.emit(can_undo())

#endregion


#region Undo Implementations

func _undo_card_move(record: MoveRecord) -> void:
	var source := record.source
	var target := record.target

	var source_had_auto := _set_auto_update(source, false)
	var target_had_auto := _set_auto_update(target, false)

	for i in record.cards.size():
		var card: Card = record.cards[i]
		card.move_to(source, UNDO_MOVE_DURATION, record.source_index + i)

	if not record.cards.is_empty():
		await record.cards.back().move_completed

	if record.flipped_card:
		record.flipped_card.is_front_face = false

	_set_auto_update(source, source_had_auto)
	_set_auto_update(target, target_had_auto)
	_apply_rules(source)
	_apply_rules(target)


func _undo_draw(record: MoveRecord) -> void:
	for i in range(record.drawn_cards.size() - 1, -1, -1):
		var card: Card = record.drawn_cards[i]
		card.move_to(starting_pile, UNDO_MOVE_DURATION * 0.8)

	if not record.drawn_cards.is_empty():
		await record.drawn_cards[0].move_completed

	_apply_rules(deal_hand)


func _undo_recycle(record: MoveRecord) -> void:
	var had_auto := _set_auto_update(deal_hand, false)

	for card in record.recycled_cards:
		card.move_to(deal_hand, UNDO_MOVE_DURATION * 0.6)

	if not record.recycled_cards.is_empty():
		await record.recycled_cards.back().move_completed

	_set_auto_update(deal_hand, had_auto)
	_apply_rules(deal_hand)

#endregion


#region Helpers

func _push(record: MoveRecord) -> void:
	_undo_stack.push_back(record)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	undo_stack_changed.emit(true)


## Sets auto_update on a SolitaireHand and returns the previous value.
## Returns [code]false[/code] for non-SolitaireHand containers (no-op).
func _set_auto_update(container: CardContainer, value: bool) -> bool:
	if container is SolitaireHand:
		var prev: bool = container.auto_update
		container.auto_update = value
		return prev
	return false


func _apply_rules(container: CardContainer) -> void:
	if container is SolitaireHand:
		container.apply_rules()

#endregion
