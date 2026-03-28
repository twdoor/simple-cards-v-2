extends Label

enum HandRank {
	HIGH_CARD,
	ONE_PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
	ROYAL_FLUSH
}

var label_tween: Tween


func tween_text(value: String, duration: float = .5) -> void:
	if label_tween:
		label_tween.kill()
	
	label_tween = create_tween()
	label_tween.tween_property(self, "text", value, duration)
	await label_tween.finished


func handle_combos(cards: Array[Card]) -> String:
	var res: Array[StandardCardResource] = []
	for card in cards:
		res.append(card.card_data)
	
	var conclusion = evaluate_hand(res)
	var c_name: String = HandRank.keys()[conclusion["rank"]]
	c_name = c_name.replace("_", " ")
	return c_name


func evaluate_hand(cards: Array[StandardCardResource]) -> Dictionary:
	var hand_size = cards.size()
	if hand_size == 0:
		return {"rank": HandRank.HIGH_CARD, "score": []}

	cards.sort_custom(func(a, b): return a.value > b.value)
	
	var values = cards.map(func(c): return c.value)
	var suits = cards.map(func(c): return c.card_suit)
	
	var value_counts = {}
	for v in values:
		value_counts[v] = value_counts.get(v, 0) + 1
	
	var counts = value_counts.values()
	counts.sort_custom(func(a, b): return a > b)

	var tie_breaker = value_counts.keys()
	tie_breaker.sort_custom(func(a, b):
		if value_counts[a] != value_counts[b]:
			return value_counts[a] > value_counts[b]
		return a > b
	)

	var is_flush = _check_flush(suits) if hand_size == 5 else false
	var is_straight = _check_straight(values) if hand_size == 5 else false

	if is_flush and is_straight:
		if values[0] == 14 and values[4] == 10: 
			return {"rank": HandRank.ROYAL_FLUSH, "score": values}
		return {"rank": HandRank.STRAIGHT_FLUSH, "score": values}
	
	if 4 in counts:
		return {"rank": HandRank.FOUR_OF_A_KIND, "score": tie_breaker}
	
	if hand_size == 5 and 3 in counts and 2 in counts:
		return {"rank": HandRank.FULL_HOUSE, "score": tie_breaker}
	
	if is_flush:
		return {"rank": HandRank.FLUSH, "score": values}
	
	if is_straight:
		return {"rank": HandRank.STRAIGHT, "score": values}
	
	if 3 in counts:
		return {"rank": HandRank.THREE_OF_A_KIND, "score": tie_breaker}
	
	if counts.count(2) >= 2:
		return {"rank": HandRank.TWO_PAIR, "score": tie_breaker}
	
	if 2 in counts:
		return {"rank": HandRank.ONE_PAIR, "score": tie_breaker}
	
	return {"rank": HandRank.HIGH_CARD, "score": values}


func _check_straight(values: Array) -> bool:
	if values == [14, 5, 4, 3, 2]: return true
	for i in range(values.size() - 1):
		if values[i] != values[i+1] + 1:
			return false
	return true


func _check_flush(suits: Array) -> bool:
	for i in range(1, suits.size()):
		if suits[i] != suits[0]:
			return false
	return true
