@tool
extends CardPile

signal clicked()

var click_enabled: bool = true:
	set(value):
		click_enabled = value
		_click_started = false

var _click_started: bool = false
var _card_mouse_filters: Dictionary = {}


func _container_ready() -> void:
	super._container_ready()
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Click to preview this pile. Click again or press Escape to close."
	custom_minimum_size = Card.EDITOR_DEFAULT_SIZE


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not click_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_click_started = true
			grab_focus()
		elif _click_started:
			_click_started = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				clicked.emit()
		accept_event()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		clicked.emit()
		accept_event()


func _apply_card_state(card: Card) -> void:
	super._apply_card_state(card)
	if not _card_mouse_filters.has(card):
		_card_mouse_filters[card] = card.mouse_filter
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _restore_card_state(card: Card) -> void:
	super._restore_card_state(card)
	if _card_mouse_filters.has(card):
		card.mouse_filter = _card_mouse_filters[card]
		_card_mouse_filters.erase(card)
