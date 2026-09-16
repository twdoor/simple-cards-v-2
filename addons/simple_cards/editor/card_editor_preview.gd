## Editor layout loading and static card previews. No retained node references.
@tool
extends RefCounted


static func setup(card: Card) -> void:
	if card._layout:
		if card._layout.card_size_changed.is_connected(card._on_layout_size_changed):
			card._layout.card_size_changed.disconnect(card._on_layout_size_changed)
		card._layout.queue_free()
		card._layout = null

	var layout_id: StringName = card.front_layout_name
	if card.card_data and !card.card_data.front_layout_name.is_empty():
		layout_id = card.card_data.front_layout_name

	card._layout = card._editor_create_layout(layout_id)
	if not card._layout:
		card.size = Card.EDITOR_DEFAULT_SIZE
		card.custom_minimum_size = Card.EDITOR_DEFAULT_SIZE
		card.pivot_offset = Card.EDITOR_DEFAULT_SIZE / 2.0
		return

	var card_size := get_layout_size(card._layout)

	card.size = card_size
	card.custom_minimum_size = card_size
	card.pivot_offset = card.size / 2.0
	card.self_modulate.a = 0

	card.add_child(card._layout)
	card._layout.card_size_changed.connect(card._on_layout_size_changed)
	card._layout.anchors_preset = Control.PRESET_FULL_RECT
	card._layout.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Only call setup() if the layout script is @tool — non-@tool scripts become
	# placeholder instances in the editor and cannot receive method calls.
	# Placeholder layouts still render their baked-in scene visuals (panels, borders, etc.).
	var script = card._layout.get_script()
	if script and script.is_tool():
		card._layout.setup(card, card.card_data)


static func create_layout(layout_id: StringName) -> CardLayout:
	var cache := LayoutCache.new()
	var path := cache.get_layout_path(layout_id, LayoutID.DEFAULT)

	if not ResourceLoader.exists(path):
		push_warning("Card: Editor layout not found at " + path)
		return null

	var scene = load(path)
	if not scene:
		return null

	var instance = scene.instantiate()
	if not instance is CardLayout:
		instance.free()
		return null

	return instance


static func get_layout_size(layout: CardLayout) -> Vector2:
	if layout.card_size != Vector2i.ZERO:
		return Vector2(layout.card_size)
	var viewport := layout.get_node_or_null("SubViewport") as SubViewport
	if viewport and viewport.size != Vector2i.ZERO:
		return Vector2(viewport.size)
	return Card.EDITOR_DEFAULT_SIZE
