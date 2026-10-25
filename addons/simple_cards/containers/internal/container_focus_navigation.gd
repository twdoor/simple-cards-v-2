## Internal focus navigation. Membership and public callbacks stay on CardContainer.
@tool
class_name ContainerFocusNavigation extends RefCounted

func update(container: CardContainer) -> void:
	var card_count = container.cards.size()
	if card_count == 0: return

	if not container.cards_focusable:
		for card in container.cards:
			card.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
			card.focus_neighbor_left = ^""
			card.focus_neighbor_right = ^""
			card.focus_neighbor_top = ^""
			card.focus_neighbor_bottom = ^""
			card.focus_previous = ^""
			card.focus_next = ^""
		return

	for i in card_count:
		var card = container.cards[i]
		card.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED

		card.focus_neighbor_left = container._neighbor_path(card, i, "left", card_count)
		card.focus_neighbor_right = container._neighbor_path(card, i, "right", card_count)
		card.focus_neighbor_top = container._neighbor_path(card, i, "up", card_count)
		card.focus_neighbor_bottom = container._neighbor_path(card, i, "down", card_count)

		card.focus_previous = card.get_path_to(container.cards[i - 1]) if i > 0 else ^""
		card.focus_next = card.get_path_to(container.cards[i + 1]) if i < card_count - 1 else ^""

func neighbor_path(container: CardContainer, card: Card, index: int, direction: String, card_count: int) -> NodePath:
	if not container.shape:
		match direction:
			"left":
				var left_index = index - 1
				return card.get_path_to(container.cards[left_index]) if left_index >= 0 else ^""
			"right":
				var right_index = index + 1
				return card.get_path_to(container.cards[right_index]) if right_index < card_count else ^""
			_:
				return ^""

	var target = container.shape.get_focus_neighbor(index, direction, card_count)
	if target == -1: return ^""
	return card.get_path_to(container.cards[target])
