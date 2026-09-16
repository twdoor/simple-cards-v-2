## Network order reconciliation, independent of editor preview and input handling.
extends RefCounted


func get_network_card_order(container: CardContainer) -> PackedStringArray:
	var net = container._get_network_manager()
	var result := PackedStringArray()
	for card in container.cards:
		if net:
			net.ensure_card_id(card)
		result.append(String(card.network_id))
	return result


func apply_network_card_order(container: CardContainer, card_ids: PackedStringArray, duration: float = 0.0) -> void:
	var net = container._get_network_manager()
	if net:
		net.begin_apply_remote_state()

	var desired: Array[Card] = []
	if net:
		for id in card_ids:
			var card = net.get_card(StringName(id))
			if card:
				desired.append(card)

	for card in desired:
		var source := card.get_parent() as CardContainer
		if source and source != container and source.cards.has(card):
			source._stop_card_idle(card)
			source._raw_unregister(card)
			source._compute_layout()
			for source_card in source.cards:
				if source_card.holding: continue
				source._settle_card(source_card, duration)

	for card in container.cards.duplicate():
		if desired.has(card):
			continue
		container._stop_card_idle(card)
		container._raw_unregister(card)

	for card in desired:
		if card.get_parent() != container:
			card._reparent_to(container)
		if not container.cards.has(card):
			container._raw_register(card)

	container.cards = desired.duplicate()
	container._compute_layout()
	for card in container.cards:
		if card.holding: continue
		container._settle_card(card, duration)
	container._update_card_layer_order()
	container._schedule_idle_restart(duration)

	if net:
		net.end_apply_remote_state()
