# API Reference

### <img src="assets/icon_card.png"> Card

A draggable button that represents a single card.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `card_data` | `CardResource` | The resource containing card data |
| `undraggable` | `bool` | If `true`, disables dragging (click still works) |
| `holding` | `bool` | `true` when card is being dragged |
| `focused` | `bool` | `true` when card has focus |
| `is_front_face` | `bool` | `true` shows front layout, `false` shows back |
| `front_layout_name` | `StringName` | ID of the front layout |
| `back_layout_name` | `StringName` | ID of the back layout |
| `position_offset` | `Vector2` | Custom offset used by CardHand |
| `rotation_offset` | `float` | Custom rotation offset used by CardHand |
| `drag_coef` | `float` | Coefficient used for the drag function |
| `max_card_rotation_deg` | `float` | Max angle the card will rotate while being dragged |
| `drag_threshold` | `float` | Custom distance in px for the drag action to trigger |

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `card_clicked` | `card: Card` | Emitted when card is clicked (not dragged) |
| `card_hovered` | - | Emitted when mouse enters card area |
| `card_unhovered` | - | Emitted when mouse exits card area |
| `drag_started` | `card: Card` | Emitted when drag threshold exceeded |
| `drag_ended` | `card: Card` | Emitted when drag completes |
| `card_flipped` | `is_front_face: bool` | Emitted when flip() is called |
| `card_focused` | - | Emitted when card gains focus |
| `card_unfocused` | - | Emitted when card loses focus |
| `layout_changed` | `layout_name: StringName` | Emitted when layout switches |
| `card_data_changed` | `new_data: CardResource` | Emitted when card_data is set |
| `move_completed` | `card: Card` | Emitted when `move_to()` finishes |

#### Methods

```gdscript
# Move this card to a CardContainer (hand, pile, or slot)
# Handles reparenting, registration, and animation in one call.
# duration: -1 uses target default, 0 snaps instantly
func move_to(target: CardContainer, duration: float = -1, index: int = -1) -> void

# Flip the card between front and back
func flip() -> void

# Change layouts
func set_layout(new_layout_name: String, is_front: bool = true) -> void

# Get current used layout
func get_layout() -> CardLayout

# Refresh the current layout display
func refresh_layout() -> void

# Animated transforms
func tween_scale(desired_scale: Vector2 = Vector2.ONE, duration: float = 0.2) -> void
func tween_rotation(desired_rotation: float = 0, duration: float = 0.2) -> void
func tween_position(desired_position: Vector2, duration: float = 0.3, global: bool = false) -> void

# Stop all animations
func kill_all_tweens() -> void
```

#### Virtual Methods

```gdscript
#Triggers at the end of the _ready() function of the card. Override if needed
func _card_ready() -> void
  
```


#### Example

```gdscript
var card = Card.new(my_resource)

# Move a card to a hand (animated)
card.move_to(hand)

# Move instantly (setup/dealing)
card.move_to(pile, 0)

# Listen for clicks
card.card_clicked.connect(func(c): print("Clicked: ", c.card_data))

# Flip the card
card.flip()

# Disable dragging but allow clicking
card.undraggable = true

# To disable clicking just use the buttons disable feature
card.disabled = true
```

---

### <img src="assets/icon_card_resource.png"> CardResource

Abstract base class for storing card data. **Extend this class** to add your own properties.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `front_layout_name` | `StringName` | Override the default front layout for this card |
| `back_layout_name` | `StringName` | Override the default back layout for this card |

#### Example

```gdscript
class_name PlayingCardResource extends CardResource

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES }

@export var suit: Suit
@export var value: int  # 1-13
@export var face_image: Texture2D
```

---

### <img src="assets/icon_card_layout.png"> CardLayout

Base class for card visuals. A `SubViewportContainer` that renders the card face.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `card_resource` | `CardResource` | Reference to the card's data |
| `card_instance` | `Card` | Reference to the parent Card node |
| `focus_in_animation` | `CardAnimationResource` | Animation to play when card gains focus |
| `focus_out_animation` | `CardAnimationResource` | Animation to play when card loses focus |
| `flip_in_animation` | `CardAnimationResource` | Animation to play when layout is added |
| `flip_out_animation` | `CardAnimationResource` | Animation to play when layout is removed |

#### Signals

| Signal | Description |
| --- | --- |
| `layout_ready` | Emitted when setup is complete |
| `layout_initialized` | Emitted when layout is initialized |
| `display_updated` | Emitted after display is updated |
| `flip_in_started` | Emitted when flip in animation starts |
| `flip_in_completed` | Emitted when flip in animation completes |
| `flip_out_started` | Emitted when flip out animation starts |
| `flip_out_completed` | Emitted when flip out animation completes |
| `focus_in_started` | Emitted when focus in animation starts |
| `focus_in_completed` | Emitted when focus in animation completes |
| `focus_out_started` | Emitted when focus out animation starts |
| `focus_out_completed` | Emitted when focus out animation completes |

#### Virtual Methods (Override These)

```gdscript
# Called when resource changes - update your visuals here
func _update_display() -> void

# Called when layout is added to card
# Uses flip_in_animation if set, otherwise override for custom behavior
func _flip_in() -> void

# Called when layout is removed
# Uses flip_out_animation if set, otherwise override for custom behavior
func _flip_out() -> void

# Called when card gains focus
# Uses focus_in_animation if set, otherwise override for custom behavior
func _focus_in() -> void

# Called when card loses focus
# Uses focus_out_animation if set, otherwise override for custom behavior
func _focus_out() -> void
```

**IMPORTANT!!** Overriding any of the flip/focus/update functions will also will override the signals emission. In this case you will need to implement the stared and completed signals yourself.

```gdscript
# Overrite example
func _flip_in() -> void:
	flip_in_started.emit()
	# Add custom code here...
	flip_in_completed.emit()
	
```


#### Creating a Layout

1. Open the **Card Layouts** panel at the bottom of the editor
2. Click **New**
3. Enter a unique **Layout ID** (e.g., `my_card_front`)
4. Optionally add tags for organization
5. Choose a save location and click **Create**
6. Customize the visuals in the opened scene

#### Example Layout Script

```gdscript
extends CardLayout

@onready var title: Label = %TitleLabel
@onready var image: TextureRect = %CardImage
@onready var stats: Label = %StatsLabel

func _update_display() -> void:
    var data = card_resource as MyCardResource
    if not data:
        return
    
    title.text = data.card_name
    image.texture = data.card_image
    stats.text = "ATK: %d  DEF: %d" % [data.attack, data.defense]

# Option 1: Use CardAnimationResource (set in inspector)
# Just assign a ScaleCardAnimation or FadeCardAnimation resource to
# focus_in_animation, focus_out_animation, etc. in the inspector

# Option 2: Override methods for custom animations
func _flip_in() -> void:
    # Custom fade in animation
    modulate.a = 0
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _focus_in() -> void:
    # Custom hover effect (only if focus_in_animation is not set)
    if not focus_in_animation:
        card_instance.tween_scale(Vector2(1.1, 1.1))
    else:
        # Call the animation resource
        super._focus_in()
```

**Notes**:

- The card will use the size of the Subviewport as the final size. If the layout does not seem right reset the custom minumum size of the CardLayout (CardLayout -> Control -> Layout -> Custom Minimum Size or Transform)
- For using shaders, apply the shader material to the CardLayout for it be applied on the whole card

---

### <img src="assets/icon_card_animation.png"> CardAnimationResource

Abstract base class for creating reusable card animations. Assign these to CardLayout properties for plug-and-play animations.

#### Methods

```gdscript
# Override this method to define animation behavior
func play_animation(layout: CardLayout) -> void:
    pass
```

#### Built-In Animations

##### ScaleCardAnimation

- `scale_value: Vector2` - Target scale (default: Vector2.ONE)
- `custom_z_index: int` - Z-index to set during animation (default: 0)
- `duration: float` - Animation duration in seconds (default: 0.2)

##### FadeCardAnimation

- `fade_type: Fade` - Either `Fade.IN` or `Fade.OUT`
- `fade_duration: float` - Animation duration in seconds (default: 0.5)

---

### <img src="assets/icon_card_container.png"> CardContainer

Base class for all card containers (`CardHand`, `CardPile`, `CardSlot`). Extends `Panel`. Manages the internal card array, layout computation via `ContainerShape`, and the registration interface used by `Card.move_to()`.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `shape` | `ContainerShape` | Layout shape. If `null`, cards stack at the origin |
| `max_cards` | `int` | Maximum cards allowed (`-1` for unlimited) |
| `card_move_duration` | `float` | Default tween duration for cards settling into position |
| `cards` | `Array[Card]` | Internal card array |

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `card_added` | `card: Card, index: int` | Emitted when a card is added |
| `card_removed` | `card: Card, index: int` | Emitted when a card is removed |
| `container_empty` | - | Emitted when the last card is removed |
| `container_full` | - | Emitted when `max_cards` is reached |

#### Methods

```gdscript
# Queries
func get_card_count() -> int
func is_empty() -> bool
func is_full() -> bool
func has_card(card: Card) -> bool
func get_card_at(index: int) -> Card       # Negative indices count from end
func get_cards() -> Array[Card]
func get_card_index(card: Card) -> int
func get_remaining_space() -> int           # -1 if unlimited

# Acceptance (called by Card.move_to)
func can_accept_card(card: Card) -> bool

# Layout
func get_card_target_position(card: Card) -> Vector2
func get_card_target_rotation(card: Card) -> float
func arrange(duration: float = -1) -> void

# Bulk operations (batch defers layout to one arrange() call at the end — auto-enabled when duration = 0)
func deal_to(target: CardContainer, count: int, duration: float = -1, stagger: float = 0.0, batch: bool = false) -> int
func move_cards_to(card_array: Array[Card], target: CardContainer, duration: float = -1, stagger: float = 0.0, batch: bool = false) -> int
func move_all_to(target: CardContainer, duration: float = -1, stagger: float = 0.0, batch: bool = false) -> int
func sort_cards(compare_func: Callable) -> void

# Clear
func clear_and_free() -> void       # Frees all cards
```

#### Virtual Methods

```gdscript
# Override for subclass-specific setup (called at end of _ready)
func _container_ready() -> void

# Called when a card is added/removed
func _on_card_added(card: Card, index: int) -> void
func _on_card_removed(card: Card, index: int) -> void

## Called if container becomes empty/full
func _on_container_empty() -> void
func _on_container_full() -> void

# Override to apply/restore container-specific state
func _apply_card_state(card: Card) -> void
func _restore_card_state(card: Card) -> void

# Override to add custom acceptance rules
func _check_conditions(card: Card) -> bool

# Override for custom signal connections
func _connect_card_signals(card: Card) -> void
func _disconnect_card_signals(card: Card) -> void
```

#### Example

```gdscript
@onready var hand: CardHand = $CardHand
@onready var pile: CardPile = $DrawPile

func deal():
    # Deal 5 cards from pile to hand with stagger animation
    await pile.deal_to(hand, 5, 0.3, 0.1)

func discard(card: Card):
    # Move a single card
    card.move_to(pile)

func discard_selected(selected: Array[Card]):
    # Move multiple cards
    hand.move_cards_to(selected, pile)

func reshuffle():
    # Instant bulk move + shuffle
    await discard.move_all_to(pile, 0)
    pile.shuffle()
```

---

### <img src="assets/icon_card_hand_shape.png"> ContainerShape

Abstract resource class that defines how cards are arranged in a `CardContainer`. Subclasses only need to implement `_compute_raw_cards()` — the base class handles bounding box adjustment automatically.

Shapes only compute positions — they do not move or tween cards. The container's `arrange()` method handles animation.

#### Inner Classes

```gdscript
# Holds the computed positions and rotations for a set of cards.
class LayoutResult:
    var positions: Array[Vector2]
    var rotations: Array[float]
```

#### Methods

```gdscript
# Computes final card positions and rotations (does NOT move cards)
func compute_layout(cards: Array[Card]) -> LayoutResult
```

#### Creating Custom Shapes

Override `_compute_raw_cards()` to return a `LayoutResult` with raw center positions and rotations. The base class automatically adjusts the bounding box so cards fit inside the container rect.

```gdscript
class_name MyCustomShape extends ContainerShape

func _compute_raw_cards(cards: Array[Card]) -> LayoutResult:
    var positions: Array[Vector2] = []
    var rotations: Array[float] = []
    
    for i in cards.size():
        positions.append(Vector2(i * 100.0, 0.0))
        rotations.append(0.0)
    
    return LayoutResult.new(positions, rotations)
```

#### Built-in Shapes

**LineShape**

```gdscript
var line = LineShape.new()
line.line_rotation = 0.0          # Rotation of the line in degrees
line.max_width = 600.0            # Maximum spread width
line.card_spacing = 50.0          # Space between cards
line.alignment = Alignment.CENTER # BEGIN, CENTER, or END alignment
line.card_rotation_angle = 0.0    # Rotation of individual cards in degrees
```

**ArcShape**

```gdscript
var arc = ArcShape.new()
arc.arc_radius = 400.0        # Circle radius
arc.arc_angle = 60.0          # Total arc angle (degrees)
arc.arc_orientation = 270.0   # Where the arc points (270 = up)
arc.card_spacing = 50.0       # Space between cards
```

**GridShape**

```gdscript
var grid = GridShape.new()
grid.num_of_cols = 3          # Number of columns
grid.num_of_rows = 3          # Number of rows
grid.col_offset = 120.0       # Horizontal spacing
grid.row_offset = 150.0       # Vertical spacing
grid.arrange_by_rows = true   # Fill rows first (true) or columns first (false)
```

**StackShape**

Places all cards at the same position (stacked on top of each other). Useful for draw/discard piles via `CardPile`.

```gdscript
var stack = StackShape.new()
```

Features:

- Auto-expansion to fit all cards
- Auto-centering for incomplete last row/column
- Configurable row-first or column-first arrangement
- All shapes automatically fit cards within the container's bounding rect

---

### <img src="assets/icon_card_hand.png"> CardHand

A card container that arranges cards in a visual hand layout. Adds drag-based reordering, focus chain management, and z-index stacking on top of `CardContainer`.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `enable_reordering` | `bool` | Allow drag-reordering within the hand |
|`enable_pile_drag`| `bool` | Allow dragging of multiple cards |

*Inherits `shape`, `max_cards`, `card_move_duration`, `cards` from `CardContainer`.*

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `cards_reordered` | `new_order: Array[Card]` | Emitted after cards are reordered |
| `card_position_changed` | `card: Card, old_index: int, new_index: int` | Emitted when a card changes position in hand |

*Inherits `card_added`, `card_removed`, `container_empty`, `container_full` from `CardContainer`.*

#### Virtual Methods

```gdscript
# Override to handle card clicks (selection, play, etc.)
func _handle_clicked_card(card: Card) -> void

## Called after cards are reordered. Override to custom behavior.
func _handle_reordered_cards(cards: Array[Card]) -> void

## If [enable_pile_drag] is true will drag multiple cards

## Override this to customize the way cards are picked
func _get_drag_companions(card: Card) -> Array[Card]

## Override this to customize the arangement of dragged cards
func _get_companion_offsets(dragged_card: Card, companions: Array[Card]) -> Array[Vector2]

## Returns the held card plus all active followers.
func get_drag_stack() -> Array[Card]
```

*Inherits `_on_card_added`, `_on_card_removed`, `_apply_card_state`, `_restore_card_state`, `_check_conditions` from `CardContainer`.*

#### Example

```gdscript
@onready var hand: CardHand = $CardHand

func _ready():
    hand.shape = ArcShape.new(500, 45, 270, 60)
    hand.max_cards = 7

# Custom click handling
class_name MyHand extends CardHand

func _handle_clicked_card(card: Card) -> void:
    card.move_to(play_area)
```

---

### <img src="assets/icon_card_pile.png"> CardPile

A card container for invisible holders or visual piles. Extends `CardContainer`. Cards in a pile are disabled and optionally hidden.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `show_cards` | `bool` | If `true`, card nodes are visible in the pile |
| `face_up` | `bool` | Whether cards in this pile show their front face |

*Inherits `shape`, `max_cards`, `card_move_duration`, `cards` from `CardContainer`.*

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `pile_shuffled` | - | Emitted when the pile is shuffled |

*Inherits `card_added`, `card_removed`, `container_empty`, `container_full` from `CardContainer`.*

#### Methods

```gdscript
# Pile operations
func shuffle() -> void
func peek_top() -> Card
func peek_cards(count: int, index: int = 1) -> Array[Card]  # Positive index = from top, negative = from bottom
```

*Inherits all query, bulk, and clear methods from `CardContainer`.*

#### Virtual Methods

```gdscript
## Called after the pile is shuffled. Override for custom behavior.
func _handle_shuffled_pile() -> void
```



*Inherits `_on_card_added`, `_on_card_removed`, `_apply_card_state`, `_restore_card_state`, `_check_conditions` from `CardContainer`.*

#### Example

```gdscript
@onready var draw_pile: CardPile = $DrawPile
@onready var discard_pile: CardPile = $DiscardPile
@onready var hand: CardHand = $Hand

func deal():
    await draw_pile.deal_to(hand, 5, 0.3, 0.1)

func discard(card: Card):
    card.move_to(discard_pile)

func reshuffle():
    await discard_pile.move_all_to(draw_pile, 0)
    draw_pile.shuffle()
```

---

### <img src="assets/icon_card_slot.png"> CardSlot

A single-card container that detects when a held card is dropped on it. Extends `CardContainer` with `max_cards = 1`.

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `card_entered` | `card: Card` | Card started hovering over slot |
| `card_exited` | `card: Card` | Card stopped hovering |
| `card_dropped_on` | `card: Card` | Card was dropped on slot |
| `card_abandoned` | `card: Card` | Card was removed via abandon (dropped on empty space) |
| `slot_lock_changed` | `is_locked: bool` | Slot lock state changed |
| `slot_hovered` | - | Emitted when mouse enters slot area |
| `slot_unhovered` | - | Emitted when mouse exits slot area |
| `slot_swapped` | `old_card: Card, new_card: Card` | Emitted when cards are swapped |
| `card_rejected` | `card: Card, reason: String` | Emitted when a card is rejected |

*Inherits `card_added`, `card_removed`, `container_empty`, `container_full` from `CardContainer`.*

#### Properties

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `slot_locked` | `bool` | `false` | Prevents cards from being placed or removed |
| `allow_swap` | `bool` | `true`  | When `false`, occupied slots reject incoming cards |
| `abandon_on_empty_space` | `bool` | `false` | Cards dropped on empty space are removed from slot |
| `abandon_reparent_target` | `Node` | `null`  | Where abandoned cards go (defaults to slot's parent) |

#### Methods

```gdscript
# Get the held card without removing it
func get_card() -> Card

# Swap cards with another slot (fails if either is locked or empty)
func swap_with(other_slot: CardSlot) -> bool

# Lock/unlock helpers
func lock() -> void
func unlock() -> void
func is_locked() -> bool
```

*Inherits all query, bulk, and clear methods from `CardContainer`. Use `card.move_to(slot)` to place cards and `slot.get_card().move_to(target)` to transfer them.*

#### Virtual Methods

```gdscript
# Override to handle clicks on the slotted card
func _on_card_clicked(card: Card) -> void
    
# Override to implement specific conditions on placing a card (checked after slot lock)
func _check_conditions(card: Card) -> bool

## Called after a card occupies the slot
func _handle_card_entered(card: Card) -> void

## Called after a card leaves the slot
func _handle_card_exited(card: Card) -> void

## Called after a card is dropped
func _handle_card_dropped_on(card: Card) -> void

## Called after the lock state changes
func _handle_slot_lock_changed(is_locked: bool) -> void

## Called after the mouse entered the slot
func _handle_slot_hovered() -> void

## Called after the mouse exited the mat
func _handle_slot_unhovered() -> void

## Called after the card is swapped
func _handle_slot_swapped(old_card: Card, new_card: Card) -> void

## Called if the card is rejected
func _handle_card_rejected(card: Card, reason: String) -> void

## Called if the card is abandoned
func _handle_card_abandoned(card: Card) -> void
```

**Swapping Cards Between Slots:** When dropping a card on an occupied slot, the cards automatically swap positions (unless `allow_swap` is `false`).

---

### <img src="assets/icon_card_mat.png"> CardMat

A panel that detects dropped cards.

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `card_entered` | `card: Card` | Card started hovering over mat |
| `card_exited` | `card: Card` | Card stopped hovering |
| `card_dropped` | `card: Card` | Card was dropped on mat |
| `mat_hovered` | - | Emitted when mouse enters mat area |
| `mat_unhovered` | - | Emitted when mouse exits mat area |

#### Virtual Methods

```gdscript
# Override to handle action when card is dropped
func handle_dropped_card(card: Card) -> void

## Called after a card entered the mat
func _handle_card_entered(card: Card) -> void

## Called after a card exited the mat
func _handle_card_exited(card: Card) -> void

## Called after the mouse entered the mat
func _handle_mat_hovered() -> void

## Called after the mouse exited the mat 
func _handle_mat_unhovered() -> void
```

---


### <img src="assets/icon_card_deck.png"> CardDeck

A pure data resource that defines what cards make up a deck. CardDeck does **not** manage runtime state — use `CardPile` or `CardDeckManager` for that.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `deck_name` | `StringName` | Optional name for the deck |
| `cards` | `Array[CardResource]` | The cards that make up this deck |

#### Methods

```gdscript
# Returns a duplicate of the card list (safe to mutate)
func get_cards() -> Array[CardResource]

# Returns the number of cards in the deck definition
func get_size() -> int

# Returns true if the deck definition has no cards
func is_empty() -> bool
```

---

### <img src="assets/icon_card_deck.png"> CardDeckManager

Manages a `CardDeck` by populating `CardPile` nodes with `Card` instances. The manager is intentionally minimal — it initializes piles from a deck definition and provides a hook for card creation. For game-specific logic (solitaire dealing, hand limits, turn structure), extend this class.

The manager does **not** own or create piles — you add `CardPile` nodes in the scene tree and assign them via exports or code.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `deck` | `CardDeck` | The deck definition to use |
| `starting_pile` | `CardPile` | The pile to populate on setup (auto-created if null) |
| `auto_setup` | `bool` | If `true`, calls `setup()` on ready |
| `shuffle_on_setup` | `bool` | If `true`, shuffles the starting pile after populating it |

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `deck_initialized` | - | Emitted after `setup()` completes |
| `card_created` | `card: Card, resource: CardResource` | Emitted when a card instance is created during setup |

#### Methods

```gdscript
# Populates the starting pile with Card instances from the deck definition.
# Override _create_card() to customize card instantiation.
func setup(source_deck: CardDeck = deck, target_pile: CardPile = starting_pile) -> void
```

#### Virtual Methods

```gdscript
# Override to customize card creation (e.g., connect signals, set properties, use a subclass)
func _create_card(card_resource: CardResource) -> Card
```

#### Example

```gdscript
@onready var deck_manager: CardDeckManager = $CardDeckManager
@onready var draw_pile: CardPile = $DrawPile
@onready var discard_pile: CardPile = $DiscardPile
@onready var hand: CardHand = $Hand

func _ready():
    deck_manager.starting_pile = draw_pile
    deck_manager.setup()
    draw_starting_hand()

func draw_starting_hand():
    await draw_pile.deal_to(hand, 5, 0.3, 0.1)

func discard_card(card: Card):
    card.move_to(discard_pile)

func reshuffle():
    await discard_pile.move_all_to(draw_pile, 0)
    draw_pile.shuffle()
```

---

### CardGlobal (CG)

The global singleton providing shared state and utilities. Access via `CG`.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `def_front_layout` | `StringName` | Default front layout ID |
| `def_back_layout` | `StringName` | Default back layout ID |
| `current_held_item` | `Card` | Currently dragged card |
| `card_index` | `int` | Auto-incrementing card counter |
|`rng`|`RandomNumberGenerator`|Responsible for random events of in the addon|

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `holding_card`   | `card: Card` | Card started being dragged |
| `dropped_card`   | - | Card was released |
| `layouts_loaded` | - | Layouts have been loaded from cache |
| `layout_registered` | `layout_id: StringName` | Emitted when a layout is registered |
| `layout_unregistered` | `layout_id: StringName` | Emitted when a layout is unregistered |
| `layouts_refreshed` | - | Emitted when layouts are refreshed |

#### Methods

```gdscript
# Get cursor position
func get_cursor_position() -> Vector2
func get_local_cursor_position(node: Node) -> Vector2
# Return mouse global/local position. TOBE used on controller support

# Layout management
func get_available_layouts() -> Array[StringName]
func get_layouts_by_tag(tag: String) -> Array[StringName]
func get_all_layout_tags() -> Array[String]
func get_layout_tags(layout_id: StringName) -> Array
func create_layout(layout_id: StringName = &"") -> CardLayout
func refresh_layouts() -> void
```

#### Example

```gdscript
func _ready():
    # Set default layouts using LayoutID constants
    CG.def_front_layout = LayoutID.MY_CARD_FRONT
    CG.def_back_layout = LayoutID.CARD_BACK
    
    # Listen for drag events
    CG.holding_card.connect(_on_card_pickup)
    CG.dropped_card.connect(_on_card_drop)

func _on_card_pickup(card: Card):
    # Highlight valid drop zones
    for slot in get_tree().get_nodes_in_group("drop_zones"):
        slot.highlight()

func _on_card_drop():
    # Remove highlights
    for slot in get_tree().get_nodes_in_group("drop_zones"):
        slot.unhighlight()
```

---

### LayoutID

Auto-generated class containing constants for all enabled layout IDs. This file is regenerated whenever you modify layouts in the Card Layouts panel.

#### Usage

```gdscript
# Instead of error-prone strings:
card.front_layout_name = "my_card_front"  # Could have typos!

# Use type-safe constants with autocomplete:
card.front_layout_name = LayoutID.MY_CARD_FRONT  # Autocomplete and compile-time checking!

# Set default layouts
CG.def_front_layout = LayoutID.STANDARD_LAYOUT
CG.def_back_layout = LayoutID.STANDARD_BACK_LAYOUT

# Check if a layout exists
if LayoutID.is_valid(some_layout_id):
    card.set_layout(some_layout_id)

# Get all available layouts
var all_layouts = LayoutID.get_all()
```

#### Generated File Location

```
res://addons/simple_cards/layout_ids.gd
```

**Note:** This file is auto-generated. Do not edit it manually as your changes will be overwritten when layouts are modified.
