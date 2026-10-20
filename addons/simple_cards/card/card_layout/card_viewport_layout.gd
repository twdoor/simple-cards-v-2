## Optional card face rendered into its own texture for whole-card shader effects.
## Put the visual Controls inside the child SubViewport and assign a material to
## this layout to shade the composed face. Card interaction stays on [Card].
@tool
@icon("res://addons/simple_cards/card/card_layout/icon_card_layout.png")
class_name CardViewportLayout extends CardLayout


func _get_initial_card_size() -> Vector2i:
	var viewport := get_node_or_null("SubViewport") as SubViewport
	return viewport.size if viewport else super._get_initial_card_size()


func _apply_card_size() -> void:
	var viewport := get_node_or_null("SubViewport") as SubViewport
	if viewport and card_size != Vector2i.ZERO:
		viewport.size = card_size
	super._apply_card_size()
	queue_redraw()


func _draw() -> void:
	var viewport := get_node_or_null("SubViewport") as SubViewport
	if viewport:
		draw_texture_rect(viewport.get_texture(), Rect2(Vector2.ZERO, size), false)


func get_layout_template() -> PackedScene:
	return load("res://addons/simple_cards/card/card_layout/viewport_card_layout.tscn")
