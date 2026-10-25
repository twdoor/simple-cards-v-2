## Internal base shared by the built-in managers. Custom managers may continue
## extending CardNetworkManager directly. Authority and transport stay in subclasses.
@abstract
class_name RegisteredCardNetwork extends CardNetworkManager


var _cards_by_id: Dictionary = {}
var _containers_by_id: Dictionary = {}
var _resources_by_id: Dictionary = {}


func register_container(container: CardContainer) -> void:
	if not is_instance_valid(container):
		return
	ensure_container_id(container)
	_containers_by_id[String(container.network_id)] = container


func unregister_container(container: CardContainer) -> void:
	if not container:
		return
	var id := String(container.network_id)
	if _containers_by_id.get(id) == container:
		_containers_by_id.erase(id)


func register_card(card: Card) -> void:
	if not is_instance_valid(card):
		return
	ensure_card_id(card)
	_cards_by_id[String(card.network_id)] = card
	if card.card_data:
		register_resource(card.card_data)


func unregister_card(card: Card) -> void:
	if not card:
		return
	var id := String(card.network_id)
	if _cards_by_id.get(id) == card:
		_cards_by_id.erase(id)


func register_resource(resource: CardResource) -> void:
	if not resource:
		return
	var id := String(resource.get_network_resource_id())
	if id.is_empty():
		return
	_resources_by_id[id] = resource


func get_card(card_id: StringName) -> Card:
	var card = _cards_by_id.get(String(card_id))
	if card and is_instance_valid(card):
		return card as Card
	_cards_by_id.erase(String(card_id))
	return null


func get_container(container_id: StringName) -> CardContainer:
	var container = _containers_by_id.get(String(container_id))
	if container and is_instance_valid(container):
		return container as CardContainer
	_containers_by_id.erase(String(container_id))
	return null


func get_resource(resource_id: StringName) -> CardResource:
	var resource = _resources_by_id.get(String(resource_id))
	if resource and is_instance_valid(resource):
		return resource as CardResource
	_resources_by_id.erase(String(resource_id))
	return null


func ensure_container_id(container: CardContainer) -> StringName:
	if not container:
		return &""
	if not container.network_id.is_empty():
		return container.network_id
	if container.is_inside_tree():
		container.network_id = StringName(str(container.get_path()))
	else:
		container.network_id = StringName("sc_container_%d" % container.get_instance_id())
	return container.network_id


func _cleanup_registries() -> void:
	for id in _cards_by_id.keys():
		if not is_instance_valid(_cards_by_id[id]):
			_cards_by_id.erase(id)
	for id in _containers_by_id.keys():
		if not is_instance_valid(_containers_by_id[id]):
			_containers_by_id.erase(id)
	for id in _resources_by_id.keys():
		if not is_instance_valid(_resources_by_id[id]):
			_resources_by_id.erase(id)
