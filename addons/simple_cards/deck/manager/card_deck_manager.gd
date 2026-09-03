## Manages a [CardDeck] by populating [CardPile] nodes with [Card] instances.
##
## CardDeckManager is intentionally minimal. It initializes piles from a deck definition
## and provides convenience methods for common operations. For game-specific logic
## (solitaire dealing, hand limits, turn structure), extend this class.
## [br][br]
## The manager does [b]not[/b] own or create piles — you add [CardPile] nodes
## in the scene tree and assign them via exports or code.
@icon("uid://u56pws80lkxh")
class_name CardDeckManager extends Node


#region Signals

## Emitted after [method setup] completes.
signal deck_initialized()
## Emitted when a card instance is created during setup.
signal card_created(card: Card, resource: CardResource)

#endregion


#region Exports

## The deck definition to use.
@export var deck: CardDeck

## The pile to populate on setup. If [code]null[/code], a child CardPile is created automatically.
@export var starting_pile: CardPile

## If [code]true[/code], calls [method setup] automatically on ready.
@export var auto_setup: bool = false

## If [code]true[/code], shuffles the starting pile after populating it.
@export var shuffle_on_setup: bool = true
@export_group("Multiplayer (Experimental)")
## If [code]true[/code], the active card network manager assigns opaque IDs to created cards while enabled.
## @experimental: Multiplayer support may change before it is considered stable.
@export var network_spawn_cards: bool = true
@export_group("")

#endregion


func _ready() -> void:
	if auto_setup:
		setup.call_deferred()


## Populates the starting pile with [Card] instances created from the deck definition.
## [br][br]
## If [param source_deck] is provided, it overrides the exported [member deck].
## If [param target_pile] is provided, it overrides the exported [member starting_pile].
## [br][br]
## Override [method _create_card] to customize card instantiation.
func setup(source_deck: CardDeck = deck, target_pile: CardPile = starting_pile) -> void:
	if source_deck:
		deck = source_deck
	if target_pile:
		starting_pile = target_pile

	if not starting_pile:
		starting_pile = CardPile.new()
		starting_pile.name = "GenPile"
		add_child(starting_pile)

	if not deck:
		push_warning("CardDeckManager: No deck assigned.")
		return

	var net = _get_network_manager()
	var broadcast_after: bool = net and net.enabled and net.is_server_peer() and net.should_broadcast_local_action()
	if broadcast_after:
		net.begin_suppressed_routing()

	starting_pile.clear_and_free()

	for card_resource in deck.cards:
		var card = _create_card(card_resource)
		if network_spawn_cards and net and net.enabled and net.is_server_peer():
			net.assign_card_id(card)
		card.move_to(starting_pile, Card.MoveConfig.new(0))
		card_created.emit(card, card_resource)

	if shuffle_on_setup:
		starting_pile.shuffle()

	if broadcast_after:
		net.end_suppressed_routing()
		net.bump_revision_and_broadcast()

	deck_initialized.emit()


## Creates a [Card] node from a [CardResource]. Override to customize card creation
## (e.g., connecting signals, setting properties, using a custom Card subclass).
func _create_card(card_resource: CardResource) -> Card:
	return Card.new(card_resource)


func _get_network_manager() -> CardNetworkManager:
	if not is_inside_tree():
		return null
	return CG.get_network_manager()
