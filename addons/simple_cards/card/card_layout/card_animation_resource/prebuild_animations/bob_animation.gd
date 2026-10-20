class_name BobCardAnimation extends CardAnimationResource

## Max vertical offset in pixels from the base position.
@export var amplitude: float = 5.0
## How many full bobs per second (Hz).
@export var frequency: float = 1.5
## Per-card phase spread.  TAU / N = full wave across N cards.
@export var phase_variance: float = TAU / 7.0

var _tweens: Dictionary = {}
var _base_positions: Dictionary = {}


func play_animation(layout: CardLayout) -> void:
	if not is_instance_valid(layout) or not layout.is_inside_tree(): return

	_clear_layout(layout)
	_base_positions[layout] = layout.position

	var tween = layout.create_tween()
	_tweens[layout] = tween
	if not layout.tree_exiting.is_connected(_clear_layout.bind(layout)):
		layout.tree_exiting.connect(_clear_layout.bind(layout), CONNECT_ONE_SHOT)

	if looping:
		tween.set_loops()

	var period = 1.0 / maxf(frequency, 0.001)
	tween.tween_method(_apply_bob.bind(layout, period), 0.0, period, period)

	if not looping:
		await _await_tween(layout, tween)
		if is_instance_valid(layout):
			_clear_layout(layout)


func stop_animation(layout: CardLayout) -> void:
	if not is_instance_valid(layout) or not layout.is_inside_tree():
		_clear_layout(layout)
		return
	if layout in _tweens:
		_tweens[layout].kill()
	if layout not in _base_positions:
		_clear_layout(layout)
		return
	var base_position: Vector2 = _base_positions[layout]
	if layout.position.is_equal_approx(base_position):
		_clear_layout(layout)
		return
	var tween = layout.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tweens[layout] = tween
	tween.tween_property(layout, "position", base_position, 0.15)
	tween.finished.connect(_clear_layout.bind(layout), CONNECT_ONE_SHOT)


func _clear_layout(layout: CardLayout) -> void:
	if layout in _tweens:
		_tweens[layout].kill()
		_tweens.erase(layout)
	# Reparenting exits the layout's tree too. Restore its resting transform before
	# it enters a different container, even when no stop tween can run there.
	if is_instance_valid(layout) and layout in _base_positions:
		layout.position = _base_positions[layout]
	_base_positions.erase(layout)


func _apply_bob(t: float, layout: CardLayout, period: float) -> void:
	if not is_instance_valid(layout): return
	var card := layout.card_instance
	var parent := card.get_parent() if is_instance_valid(card) else null
	var idx: int = maxi(parent.cards.find(card), 0) if parent is CardContainer else 0
	var offset := sin(t * TAU / period + idx * phase_variance) * amplitude
	if layout not in _base_positions:
		_base_positions[layout] = layout.position
	layout.position = _base_positions[layout] + Vector2(0, offset)
