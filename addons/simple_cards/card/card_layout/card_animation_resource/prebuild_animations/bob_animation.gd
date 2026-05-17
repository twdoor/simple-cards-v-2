class_name BobCardAnimation extends CardAnimationResource

## Max vertical offset in pixels from the base position.
@export var amplitude: float = 5.0
## How many full bobs per second (Hz).
@export var frequency: float = 1.5
## Per-card phase spread.  TAU / N = full wave across N cards.
@export var phase_variance: float = TAU / 7.0

var _tweens: Dictionary = {}


func play_animation(layout: CardLayout) -> void:
	if not layout: return

	if layout in _tweens:
		_tweens[layout].kill()

	var tween = layout.create_tween()
	_tweens[layout] = tween
	if not layout.tree_exiting.is_connected(_clear_layout.bind(layout)):
		layout.tree_exiting.connect(_clear_layout.bind(layout), CONNECT_ONE_SHOT)

	if looping:
		tween.set_loops()

	var period = 1.0 / frequency
	var card = layout.card_instance

	tween.tween_method(func(t):
		var parent = card.get_parent() if card else null
		var idx = parent.cards.find(card) if parent is CardContainer else 0
		if idx < 0: idx = 0
		var offset = sin(t * TAU / period + idx * phase_variance) * amplitude
		layout.offset_top = offset
		layout.offset_bottom = offset
	, 0.0, period, period)

	if not looping:
		await tween.finished
		_tweens.erase(layout)


func stop_animation(layout: CardLayout) -> void:
	if layout in _tweens:
		_tweens[layout].kill()
	if is_zero_approx(layout.offset_top) and is_zero_approx(layout.offset_bottom):
		_tweens.erase(layout)
		return
	var tween = layout.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tweens[layout] = tween
	tween.tween_property(layout, "offset_top", 0.0, 0.15)
	tween.parallel().tween_property(layout, "offset_bottom", 0.0, 0.15)
	tween.finished.connect(func(): _tweens.erase(layout))


func _clear_layout(layout: CardLayout) -> void:
	if layout in _tweens:
		_tweens[layout].kill()
		_tweens.erase(layout)
