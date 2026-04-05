##A simple panel that detects when cards are dropped on it
@icon("uid://bukyt18o5dnp2")
class_name CardMat extends Panel

##Emitted when a card starts hovering over this mat
signal card_entered(card: Card)
##Emitted when a card stops hovering over this mat
signal card_exited(card: Card)
##Emitted when a card is dropped on this mat
signal card_dropped(card: Card)
##Emitted when mouse enters mat area
signal mat_hovered()
##Emitted when mouse exits mat area
signal mat_unhovered()

var _card_over: bool = false
var _card_currently_over: Card = null

func _ready() -> void:
	CG.holding_card.connect(_on_holding_card)
	CG.dropped_card.connect(_on_card_dropped)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	set_process(false)


func _process(_delta: float) -> void:
	var cursor_pos = CG.get_cursor_position()
	var is_over = get_global_rect().has_point(cursor_pos)
	
	if is_over and not _card_over:
		_card_over = true
		_card_currently_over = CG.current_held_item
		card_entered.emit(_card_currently_over)
		_handle_card_entered(_card_currently_over)
	
	elif not is_over and _card_over:
		_card_over = false
		if _card_currently_over:
			card_exited.emit(_card_currently_over)
			_handle_card_exited(_card_currently_over)
		_card_currently_over = null


func _on_holding_card(card: Card) -> void:
	set_process(true)


func _on_card_dropped() -> void:
	if _card_over and _card_currently_over:
		card_dropped.emit(_card_currently_over)
		_handle_dropped_card(_card_currently_over)
	
	_card_over = false
	_card_currently_over = null
	set_process(false)

func _on_mouse_entered() -> void:
	mat_hovered.emit()
	_handle_mat_hovered()

func _on_mouse_exited() -> void:
	mat_unhovered.emit()
	_handle_mat_unhovered()


func _exit_tree() -> void:
	if CG.holding_card.is_connected(_on_holding_card):
		CG.holding_card.disconnect(_on_holding_card)
	if CG.dropped_card.is_connected(_on_card_dropped):
		CG.dropped_card.disconnect(_on_card_dropped)

#region Overridable Callbacks

## Called after a card is dropped. Override for custom behavior.
func _handle_dropped_card(card: Card) -> void: pass

## Called after a card entered the mat. Override for custom behavior.
func _handle_card_entered(card: Card) -> void: pass

## Called after a card exited the mat. Override for custom behavior.
func _handle_card_exited(card: Card) -> void: pass

## Called after the mouse entered the mat. Override for custom behavior.
func _handle_mat_hovered() -> void: pass

## Called after the mouse exited the mat. Override for custom behavior.
func _handle_mat_unhovered() -> void: pass

#endregion
