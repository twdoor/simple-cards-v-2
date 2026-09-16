## Owns transient editor preview cards; the container is borrowed per operation.
@tool
extends RefCounted

var _preview_card_size: Vector2 = Card.EDITOR_DEFAULT_SIZE
var _preview_visual_cards: Array[Card] = []


func _draw(container: CardContainer) -> void:
	if !Engine.is_editor_hint(): return
	if !container.preview_enabled: return

	if container.preview_draw_container_bounds:
		container.draw_rect(Rect2(Vector2.ZERO, container.size), CardContainer.PREVIEW_CONTAINER_BOUNDS_COLOR, false, 2.0)

	var preview_cards := _build_preview_cards(container)
	var layout := container._compute_preview_layout(preview_cards)
	if layout == null:
		layout = container._compute_stacked_preview_layout(preview_cards)
	var bounds := container._get_layout_bounds(preview_cards, layout.positions, layout.rotations)
	var should_draw_ghosts := _preview_visual_cards.is_empty()

	if should_draw_ghosts:
		for i in preview_cards.size():
			if i >= layout.positions.size(): break
			var card := preview_cards[i]
			var rot := layout.rotations[i] if i < layout.rotations.size() else 0.0
			container.draw_set_transform(layout.positions[i], rot, Vector2.ONE)
			var rect := Rect2(-card.pivot_offset, card.size)
			container.draw_rect(rect, CardContainer.PREVIEW_CARD_FILL_COLOR, true)
			container.draw_rect(rect, CardContainer.PREVIEW_CARD_OUTLINE_COLOR, false, 1.0)

		container.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if container.preview_draw_shape_bounds:
		if bounds.size != Vector2.ZERO:
			container.draw_rect(bounds, CardContainer.PREVIEW_SHAPE_BOUNDS_COLOR, false, 2.0)

	for card in preview_cards:
		card.free()


func _get_preview_card_count(container: CardContainer) -> int:
	if container.preview_card_count > 0:
		return clampi(container.preview_card_count, 1, 100)
	if container.max_cards > 0:
		return clampi(container.max_cards, 1, 100)
	return CardContainer.PREVIEW_DEFAULT_CARD_COUNT


func _build_preview_cards(container: CardContainer) -> Array[Card]:
	var result: Array[Card] = []
	var count := _get_preview_card_count(container)
	for i in count:
		var card := Card.new()
		card.size = _preview_card_size
		card.custom_minimum_size = _preview_card_size
		card.pivot_offset = _preview_card_size / 2.0
		result.append(card)
	return result


func _update_preview_visual_cards(container: CardContainer) -> void:
	if !Engine.is_editor_hint(): return
	if !container.preview_enabled:
		_clear_preview_visual_cards()
		return

	var preview_cards := _build_preview_cards(container)
	var layout := container._compute_preview_layout(preview_cards)
	if layout == null:
		layout = container._compute_stacked_preview_layout(preview_cards)

	_resize_preview_visual_cards(container, preview_cards.size())
	for i in _preview_visual_cards.size():
		var visual_card := _preview_visual_cards[i]
		if i >= layout.positions.size():
			visual_card.visible = false
			continue

		var reference_card := preview_cards[i]
		var rot := layout.rotations[i] if i < layout.rotations.size() else 0.0
		visual_card.visible = true
		visual_card.position = layout.positions[i] - reference_card.pivot_offset
		visual_card.rotation = rot
		visual_card.size = reference_card.size
		visual_card.custom_minimum_size = reference_card.size
		visual_card.pivot_offset = reference_card.pivot_offset
		visual_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_card.focus_mode = Control.FOCUS_NONE

	for card in preview_cards:
		card.free()


func _resize_preview_visual_cards(container: CardContainer, count: int) -> void:
	while _preview_visual_cards.size() > count:
		var card := _preview_visual_cards.pop_back()
		card.queue_free()

	while _preview_visual_cards.size() < count:
		var card := Card.new()
		card.name = "_preview_card_%d" % _preview_visual_cards.size()
		card.front_layout_name = container.preview_layout_name
		card.back_layout_name = container.preview_layout_name
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		card.self_modulate.a = 0.65
		container.add_child(card, false, Node.INTERNAL_MODE_FRONT)
		_preview_visual_cards.append(card)

	for card in _preview_visual_cards:
		if card.front_layout_name != container.preview_layout_name:
			card.front_layout_name = container.preview_layout_name
		if card.back_layout_name != container.preview_layout_name:
			card.back_layout_name = container.preview_layout_name


func _clear_preview_visual_cards() -> void:
	for card in _preview_visual_cards:
		if is_instance_valid(card):
			card.queue_free()
	_preview_visual_cards.clear()


func _get_preview_bounds(container: CardContainer) -> Rect2:
	var preview_cards := _build_preview_cards(container)
	var layout := container._compute_preview_layout(preview_cards)
	if layout == null:
		layout = container._compute_stacked_preview_layout(preview_cards)
	var bounds := container._get_layout_bounds(preview_cards, layout.positions, layout.rotations)
	for card in preview_cards:
		card.free()
	return bounds


func _editor_get_layout_card_size(layout_id: StringName) -> Vector2:
	if !Engine.is_editor_hint():
		return Card.EDITOR_DEFAULT_SIZE

	var preview = load("res://addons/simple_cards/editor/card_editor_preview.gd")
	var layout: CardLayout = preview.create_layout(layout_id)
	if not layout:
		return Card.EDITOR_DEFAULT_SIZE
	var result: Vector2 = preview.get_layout_size(layout)
	layout.free()
	return result
