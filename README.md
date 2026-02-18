# <img src="https://github.com/twdoor/simple-cards-v-2/blob/main/github/assets/simple_card_v2.png" width="8%"> Simple Cards

A flexible, UI-based card system plugin for **Godot 4.5**. Build card games, deck builders, or any card-based interface using Control nodes that work seamlessly in both 2D and 3D projects.

![Example Animation](https://github.com/twdoor/simple-cards-v-2/blob/main/github/assets/example.gif)

------

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Card Layouts Panel](#card-layouts-panel)
- [API Reference](#api-reference)
  - [Card](#card)
  - [CardResource](#cardresource)
  - [CardLayout](#cardlayout)
  - [CardAnimationResource](#cardanimationresource)
  - [CardHand](#cardhand)
  - [CardHandShape](#cardhandshape)
  - [CardSlot](#cardslot)
  - [CardMat](#cardmat)
  - [CardPile](#cardpile)
  - [CardDeck](#carddeck)
  - [CardDeckManager](#carddeckmanager)
  - [CardGlobal (CG)](#cardglobal-cg)
  - [LayoutID](#layoutid)
- [Examples](#examples)
- [Changelog](#changelog)
- [Support](#support)

------

## Features

- **Drag & Drop Cards** - Built-in press and drag functionality with smooth animations
- **Customizable Visuals** - Create unique card faces using the layout system
- **Reusable Animations** - Plug-and-play animation resources for common card behaviors
- **Data-Driven Design** - Separate card data (resources) from visuals (layouts)
- **Hand Management** - Arrange cards in lines, arcs, grids, stacks, or custom shapes
- **Deck System** - Lightweight deck definitions with a minimal manager you can extend
- **Card Slots** - Drop zones for placing individual cards
- **Layout Management Panel** - Editor panel to view, create, and manage all card layouts
- **Fully Documented** - In-editor documentation for all classes

---

## Installation

### From Asset Library

1. Search for "SimpleCards" in the Godot Asset Library
2. Install the addon
3. Go to **Project → Project Settings → Plugins** and enable **SimpleCards**
4. **Reload the project** (important!)

### Manual Installation

1. Download or clone this repository
2. Copy the `addons/simple_cards` folder into your project's `addons` directory
3. Go to **Project → Project Settings → Plugins** and enable **SimpleCards**
4. **Reload the project** (important!)

---

## Quick Start

### 1. Create a Card Resource

Card resources store your card data. Create a new script that extends `CardResource`:

```gdscript
# my_card_resource.gd
class_name MyCardResource extends CardResource

@export var card_name: String = ""
@export var attack: int = 0
@export var defense: int = 0
@export var card_image: Texture2D
```

Then create `.tres` files using your new resource type to define individual cards.

### 2. Create a Card Layout

Layouts define how cards look. Open the **Card Layouts** panel at the bottom of the editor (next to Output, Debugger, etc.) and click **New**.

![Photo of layout creation window](https://github.com/twdoor/simple-cards-v-2/blob/main/github/assets/create_layout_part2.png)

![Photo of default layout](https://github.com/twdoor/simple-cards-v-2/blob/main/github/assets/default_layout.png)

Extend the layout script to update visuals:

```gdscript
# my_layout.gd
extends CardLayout

@onready var name_label: Label = %NameLabel
@onready var image: TextureRect = %CardImage

func _update_display() -> void:
    var data = card_resource as MyCardResource
    if data:
        name_label.text = data.card_name
        image.texture = data.card_image
```

### 3. Spawn Cards

```gdscript
# In your game scene
func _ready():
    var card_data = preload("res://cards/my_card.tres")
    var card = Card.new(card_data)
    add_child(card)
```

---

## Card Layouts Panel

The **Card Layouts** panel provides a centralized place to manage all your card layouts.

### Features

- **View All Layouts** - See every layout in your project at a glance
- **Search & Filter** - Find layouts by name or filter by tags
- **Create New Layouts** - Click **+ New Layout** to create a layout with a unique ID and optional tags
- **Edit Layout Properties** - Select a layout to edit its ID and tags in the details panel
- **Enable/Disable Layouts** - Toggle the checkbox to control which layouts are loaded at runtime
- **Delete Layouts** - Remove layouts you no longer need (deletes the scene file)
- **Open Scene** - Click the open icon to jump directly to the layout scene

### How It Works

The panel scans your project for scenes with layout metadata and caches the results. This is much faster than the old system which had to instantiate each scene to check for layouts.

Layouts are identified by metadata on the root node:

- `metadata/is_layout = true`
- `metadata/layout_id = "your_unique_id"`
- `metadata/tags = ["optional", "tags"]`

When you create or modify layouts through the panel, it automatically:

1. Updates the scene file metadata
2. Regenerates the `LayoutID` constants file for autocomplete

---

## API Reference

### Card

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
| `tween_started` | `tween_type: String` | Emitted when a tween starts |
| `tween_completed` | `tween_type: String` | Emitted when a tween completes |
| `card_data_changed` | `new_data: CardResource` | Emitted when card_data is set |

#### Methods

```gdscript
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

#### Example

```gdscript
var card = Card.new(my_resource)
add_child(card)

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

### CardResource

Abstract base class for storing card data. **Extend this class** to add your own properties.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `custom_layout_name` | `StringName` | Override the default front layout for this card |

#### Example

```gdscript
class_name PlayingCardResource extends CardResource

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES }

@export var suit: Suit
@export var value: int  # 1-13
@export var face_image: Texture2D
```

---

### CardLayout

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

**IMPORTANT!!** Overriding any of the flip/focus/update functions will also will override the signals emission.In this case you will need to implement the stared and completed signals yourself.

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

### CardAnimationResource

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

### CardHand

A container that arranges multiple cards in a configurable shape.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `shape` | `CardHandShape` | Defines the arrangement (line, arc, custom) |
| `enable_reordering` | `bool` | Allow drag-reordering within the hand |
| `max_hand_size` | `int` | Maximum cards allowed (-1 for unlimited) |
| `cards` | `Array[Card]` | Read-only copy of cards in hand |

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `card_added` | `card: Card, index: int` | Emitted when a card is added to the hand |
| `card_removed` | `card: Card, index: int` | Emitted when a card is removed from the hand |
| `hand_empty` | - | Emitted when the last card is removed |
| `hand_full` | - | Emitted when max_hand_size is reached |
| `hand_cleared` | - | Emitted when clear_hand() is called |
| `cards_reordered` | `new_order: Array[Card]` | Emitted when cards are reordered |
| `card_position_changed` | `card: Card, old_index: int, new_index: int` | Emitted when a specific card changes position in hand |
| `arrangement_started` | - | Emitted before arrange_cards() |
| `arrangement_completed` | - | Emitted after arrange_cards() completes |

#### Methods

```gdscript
# Add a single card (returns true if successful)
func add_card(card: Card) -> bool

# Add multiple cards (returns number successfully added)
func add_cards(card_array: Array[Card]) -> int

# Remove a card (does NOT free it, returns the card or null)
func remove_card(card: Card) -> Card

# Remove all cards (does NOT free them)
func clear_hand() -> void

# Remove all cards and free them
func clear_and_free() -> void

# Get card by index
func get_card(index: int) -> Card

# Get card count
func get_card_count() -> int

# Get index of a card
func get_card_index(card: Card) -> int

# Check if hand contains a card
func has_card(card: Card) -> bool

# Check if hand is full
func is_hand_full() -> bool

# Get remaining space
func get_remaining_space() -> int

# Sort cards using a custom comparison function
func sort_cards(compare_func: Callable) -> void

# Force arrangement of cards
func arrange_cards() -> void
```

#### Virtual Methods

```gdscript
# Override to handle card clicks
func _handle_clicked_card(card: Card) -> void

# Called when a card is added to the hand
func _on_card_added(card: Card, index: int) -> void

# Called when a card is removed from the hand
func _on_card_removed(card: Card, index: int) -> void
```

#### Example

```gdscript
@onready var hand: CardHand = $CardHand

func _ready():
    # Configure the hand
    hand.shape = ArcHandShape.new(500, 45, 270, 60)
    hand.max_hand_size = 7
    
    # Add cards
    for i in 5:
        var card = Card.new(card_resources[i])
        hand.add_card(card)

# Custom click handling
class_name MyHand extends CardHand

func _handle_clicked_card(card: Card) -> void:
    # Play the card
    remove_card(card)
    $PlayArea.add_child(card)
```

---

### CardHandShape

Abstract resource class that defines how cards are arranged in a hand. Subclasses only need to implement `_compute_raw_cards()` — the base class handles bounding box adjustment, layout sizing, and tween application automatically.

#### Architecture

The layout process is split into two phases:

1. **`compute_layout()`** — Computes final positions and rotations without moving cards. The hand uses this to update its minimum size before any tweens start, preventing layout jitter.
2. **`apply_layout()`** — Tweens cards to their computed positions. Called after the hand rect has settled.

#### Methods

```gdscript
# Computes final card positions and rotations (does NOT move cards)
# Returns Dictionary with "positions": Array[Vector2] and "rotations": Array[float]
func compute_layout(cards: Array[Card]) -> Dictionary

# Tweens cards to the positions from compute_layout(). Skipped cards are not moved.
func apply_layout(cards: Array[Card], layout: Dictionary, skipped_cards: Array[Card] = []) -> void
```

#### Creating Custom Shapes

Override `_compute_raw_cards()` to return raw center positions and rotations. The base class automatically adjusts the bounding box so cards fit inside the hand rect.

```gdscript
class_name MyCustomShape extends CardHandShape

func _compute_raw_cards(cards: Array[Card]) -> Dictionary:
    var positions: Array[Vector2] = []
    var rotations: Array[float] = []
    
    for i in cards.size():
        positions.append(Vector2(i * 100.0, 0.0))
        rotations.append(0.0)
    
    return { "positions": positions, "rotations": rotations }
```

#### Built-in Shapes

**LineHandShape**

```gdscript
var line = LineHandShape.new()
line.line_rotation = 0.0          # Rotation of the line in degrees
line.max_width = 600.0            # Maximum spread width
line.card_spacing = 50.0          # Space between cards
line.alignment = Alignment.CENTER # BEGIN, CENTER, or END alignment
line.card_rotation_angle = 0.0    # Rotation of individual cards in degrees
```

**ArcHandShape**

```gdscript
var arc = ArcHandShape.new()
arc.arc_radius = 400.0        # Circle radius
arc.arc_angle = 60.0          # Total arc angle (degrees)
arc.arc_orientation = 270.0   # Where the arc points (270 = up)
arc.card_spacing = 50.0       # Space between cards
```

**GridHandShape**

```gdscript
var grid = GridHandShape.new()
grid.num_of_cols = 3          # Number of columns
grid.num_of_rows = 3          # Number of rows
grid.col_offset = 120.0       # Horizontal spacing
grid.row_offset = 150.0       # Vertical spacing
grid.arrange_by_rows = true   # Fill rows first (true) or columns first (false)
```

**StackHandShape**

Places all cards at the same position (stacked on top of each other). Useful for draw/discard piles via `CardPile`.

```gdscript
var stack = StackHandShape.new()
```

Features:

- Auto-expansion to fit all cards
- Auto-centering for incomplete last row/column
- Configurable row-first or column-first arrangement
- All shapes automatically fit cards within the hand's bounding rect
- Shapes can be used by both `CardHand` and `CardPile`

---

### CardSlot

A panel that accepts a single dropped card.

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `card_entered` | `card: Card` | Card started hovering over slot |
| `card_exited` | `card: Card` | Card stopped hovering |
| `card_dropped` | `card: Card` | Card was dropped on slot |
| `card_abandoned` | `card: Card` | Card was removed via abandon (dropped on empty space) |
| `slot_lock_changed` | `is_locked: bool` | Slot lock state changed |
| `slot_hovered` | - | Emitted when mouse enters slot area |
| `slot_unhovered` | - | Emitted when mouse exits slot area |
| `slot_filled` | `card: Card` | Emitted when a card is successfully placed in the slot |
| `slot_emptied` | - | Emitted when a card is removed from the slot |
| `slot_swapped` | `old_card: Card, new_card: Card` | Emitted when cards are swapped |
| `card_rejected` | `card: Card, reason: String` | Emitted when a card is rejected |

#### Properties

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `held_card`| `Card` | `null` | The card currently in this slot |
| `slot_locked` | `bool` | `false` | Prevents cards from being dragged out or swapped in |
| `allow_swap` | `bool` | `true`  | When `false`, occupied slots reject incoming cards |
| `abandon_on_empty_space` | `bool` | `false` | Cards dropped on empty space are removed from slot |
| `abandon_reparent_target` | `Node` | `null`  | Where abandoned cards go (defaults to slot's parent) |

#### Methods

```gdscript
# Add a card to the slot (returns true if successful)
func add_card(card: Card) -> bool

# Remove a specific card from the slot (does NOT free it)
func remove_card(card: Card) -> Card

# Remove and return the held card (does NOT free it)
func pop_card() -> Card

# Clear the slot (force=true ignores lock)
func clear_slot(force: bool = false) -> Card

# Check if slot is empty
func is_empty() -> bool

# Get the held card without removing it
func get_card() -> Card

# Swap cards with another slot
func swap_with(other_slot: CardSlot) -> bool

# Transfer card to a hand
func transfer_to_hand(hand: CardHand) -> bool

# Lock/unlock helpers
func lock() -> void
func unlock() -> void
func is_locked() -> bool
```

#### Virtual Methods

```gdscript
# Override to handle clicks on the slotted card
func _on_card_clicked(card: Card) -> void:
    print("Slotted card clicked: ", card.name)
    
# Override to implement specific conditions on addig a card. (conditions are checked after slot lock)
func check_conditions(card: Card) -> bool:
	return true
```

**Swapping Cards Between Slots:** When dropping a card on an occupied slot, the cards automatically swap positions (unless `allow_swap` is `false`).

---

### CardMat

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
func handle_dropped_card(card: Card) -> void:
    pass
```

---

### CardPile

A container for cards that can function as an invisible holder or a visual pile. CardPile is the building block for deck systems — it holds `Card` nodes as children and provides draw, add, shuffle, and arrangement operations.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `shape` | `CardHandShape` | Optional shape for visual arrangement (reuses hand shapes) |
| `show_cards` | `bool` | If `true`, card nodes are visible in the pile |
| `face_up` | `bool` | Whether cards in this pile show their front face |

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `card_added` | `card: Card, index: int` | Emitted when a card is added to the pile |
| `card_removed` | `card: Card` | Emitted when a card is removed from the pile |
| `pile_emptied` | - | Emitted when the pile becomes empty |
| `pile_shuffled` | - | Emitted when the pile is shuffled |
| `pile_changed` | `new_size: int` | Emitted when the pile size changes |

#### Methods

```gdscript
# Core
func get_card_count() -> int
func is_empty() -> bool
func get_cards() -> Array[Card]
func get_card_at(index: int) -> Card

# Adding cards
func add_card(card: Card) -> void
func add_card_at(card: Card, index: int) -> void
func add_cards(card_array: Array[Card]) -> void

# Drawing / removing cards
func draw_card() -> Card               # Draw from top
func draw_cards(count: int) -> Array[Card]
func draw_card_at(index: int) -> Card
func remove_card(card: Card) -> Card    # Does NOT free
func clear_pile() -> void               # Does NOT free
func clear_and_free() -> void           # Frees all cards

# Pile operations
func shuffle() -> void
func peek_top() -> Card
func peek_top_cards(count: int) -> Array[Card]
func has_card(card: Card) -> bool
func get_card_index(card: Card) -> int
func move_all_to(target_pile: CardPile) -> void

# Arrangement
func arrange() -> void
```

#### Virtual Methods

```gdscript
# Called when a card is added — override for custom behavior
func _on_card_added(card: Card, index: int) -> void

# Called when a card is removed — override for custom behavior
func _on_card_removed(card: Card) -> void
```

#### Example

```gdscript
@onready var draw_pile: CardPile = $DrawPile
@onready var discard_pile: CardPile = $DiscardPile
@onready var hand: CardHand = $Hand

func deal():
    var cards = draw_pile.draw_cards(5)
    hand.add_cards(cards)

func discard(card: Card):
    discard_pile.add_card(card)

func reshuffle():
    discard_pile.move_all_to(draw_pile)
    draw_pile.shuffle()
```

---

### CardDeck

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

### CardDeckManager

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
    var cards = draw_pile.draw_cards(5)
    hand.add_cards(cards)

func discard_card(card: Card):
    discard_pile.add_card(card)

func reshuffle():
    discard_pile.move_all_to(draw_pile)
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

---

## Examples

### Standard Deck

Located in `examples/cards/standard_deck/` this shows:

- a basic front and back layout for standard/poker decks
- 52 resources cards for all standard playing cards (except jokers)
- premade deck with the cards: `standard_deck.tres`

This deck is used in both the balatro and solitaire examples.
Open standard_layout.tscn to see the front face layout.
Open standard_back_layout.tscn to see the back face layout.

### Balatro Style

Located in `examples/balatro/`, this demonstrates:

- Hand selection and sorting card
- Applying modifiers to cards
- Deck management with draw/discard
- Pile preview functionality

Run BalatroExample.tscn to play.

### Solitaire

Located in `examples/solitaire/`, this demonstrates:

- Combined implementation of hands and mats
- Custom condition rules for card stacking and ordering in the hand. 
- Custom function for moving cards around

Run SolitaireExample.tscn to play.

---

## Changelog

### Version 2.6

- **CardPile** — New `Control` node that acts as a container for cards. Supports draw, add, shuffle, peek, and arrangement operations. Can use any `CardHandShape` for visual layout or stack cards invisibly. This is now the building block for deck systems.
- **CardDeck Simplified** — `CardDeck` is now a pure data resource. It defines *what cards* a deck contains (`cards` array) and nothing else. All runtime pile state, signals, serialization, and the `Pile` enum have been removed. Use `CardPile` nodes for runtime state instead.
- **CardDeckManager Simplified** — The manager now only creates `Card` instances from a `CardDeck` and populates a `CardPile`. All draw/discard/shuffle/preview/save-load logic has been removed — interact with `CardPile` nodes directly. Override `_create_card()` to customize card instantiation.
- **Reparenting Overhaul** — `CardHand`, `CardSlot`, and `CardPile` now track cards via `child_exiting_tree`. When a card is reparented away (e.g., via `reparent()` or moving to another container), the source container automatically cleans up its internal state and emits the appropriate signals. Manual `_release_card()` is no longer needed.
- **CardHand** — Added `clear_and_free()`, `has_card()`, `_on_card_added()`, and `_on_card_removed()` virtual callbacks. `remove_card()` now returns the card instead of void and no longer takes a `new_parent` parameter. Removed `_release_card()`.
- **CardSlot** — `remove_card()` now takes a `card: Card` parameter instead of `new_parent: Node`. Added `pop_card()` for removing the held card without specifying which card. Swap logic simplified using the new `_take_card()` helper.
- **CardHandShape** — `compute_layout()` and `_compute_raw_cards()` no longer require a `hand: CardHand` parameter, allowing shapes to be reused by both `CardHand` and `CardPile`.
- **StackHandShape** — New built-in shape that stacks all cards at the same position. Useful for draw/discard pile visuals.
- **Card** — Added early-exit guard on `is_front_face` setter to avoid redundant flips.
- **Check Exports** - Exports like arrays or assigned nodes on the deck and manager might need to be remade/reassigned.

**Breaking Changes:**

- `CardDeck`: No longer contains runtime pile state. The `Pile` enum, all signals, `card_list` (now `cards`), `piles`, `reset_to_draw()`, `draw_from_pile()`, `add_to_pile()`, `move_card()`, `shuffle_pile()`, `save_state()`, `load_state()`, and all related methods have been removed. It is now a pure data resource.
- `CardDeckManager`: All draw/discard/add/remove/shuffle/preview/save-load methods have been removed. Use `CardPile` methods directly instead. `pile_nodes` and `front_face_in_pile` exports removed. `shuffle_on_ready` renamed to `shuffle_on_setup`. The manager now takes a `starting_pile: CardPile` export instead.
- `CardHand`: `remove_card()` signature changed from `(card, new_parent)` to `(card)` returning `Card`. `_release_card()` removed — use `_on_card_removed()` instead.
- `CardSlot`: `remove_card()` signature changed from `(new_parent)` to `(card)`. Use `pop_card()` for the old behavior of removing whatever card is held.
- `CardHandShape`: `compute_layout()` and `_compute_raw_cards()` no longer take a `hand: CardHand` parameter. Update custom shapes accordingly.

### Version 2.5.2

- **CardHandShape Refactor** - Split layout into `compute_layout()` and `apply_layout()` phases. Subclasses now only override `_compute_raw_cards()` — bounding box adjustment, tween application, and sizing are handled by the base class automatically.
- **Card Placement Fix** - All built-in shapes (Line, Arc, Grid) now correctly place cards inside the hand's bounding rect instead of centering around origin.
- **`_release_card()` Virtual Method** - New overridable method for cleanup when a card leaves the hand by any path (remove, transfer, drag out). Subclasses should override this instead of `remove_card()` for cleanup logic.
- **Drag Reordering** - `_find_insertion_index()` now uses 2D slot-based distance instead of x-axis only, fixing reordering for arc and grid shapes.
- **Minimum Size** - Hand respects `custom_minimum_size` set in the editor; `_get_minimum_size()` returns `Vector2.ZERO` when empty.

**Breaking Changes:**

- `CardHandShape`: `arrange_cards()` replaced by `compute_layout()` + `apply_layout()`. Custom shapes must now override `_compute_raw_cards()` instead of `arrange_cards()`.
- `CardHand`: `_release_card()` is now the recommended override point for card removal cleanup instead of `remove_card()`.

### Version 2.5.1

- **Solitaire**: new example scene, fully playable game of soliaire
- Added some comments to the examples to explain some functions
- Updated Balatro example a bit to reflect some changes made over time
- **ScaleCardAnimation**: now tweens the layout instead of the card to fix some animation order bug 
- **LineHandShape**: minor improvements; now has align option (begin/center/end) 

### Version 2.5

- **Signal System Expansion** - Added comprehensive signals across all classes for better event-driven programming
  - **Card**: Added 11 new signals including hover events, drag events, flip events, focus events, and tween events
  - **CardLayout**: Added 10 new signals for animation lifecycle events (flip in/out, focus in/out)
  - **CardGlobal**: Added 3 new signals for layout management events
  - **CardDeck**: Added 8 new signals for pile management and card operations
  - **CardDeckManager**: Added 10 new signals for deck operations and card instance lifecycle
  - **CardHand**: Added 9 new signals for hand management and card positioning
  - **CardMat**: Added 2 new signals for hover events
  - **CardSlot**: Added 7 new signals for slot state changes and validation
  - **CardSlot/CardMat**: process function is now disabled while not holding a card (for optimization purpuses)

### Version 2.4

- **Deck Refactoring** - the CardDeck and CardDeckManager got a major changes; moved the main logic into the CardDeck, generalized the pile system for expandability and started on a save/load system.
- Cleaned CardHand logic to remove the duplicated `_cards` array
- New premade hand shape: **GridHandShape**. 

**Breaking Changes:**

- `CardDeck`/`CardDeckManager`: All methods using `is_discard: bool` now use `pile: CardDeck.Pile` enum

- `CardDeckManager`: Removed `add_card_to_pile_from_top_at()` - use `add_card_to_pile_at()` with negative numbers 

- `CardHand`: `refresh_arrangement()` was removed, `arrange_cards()` is now a public method instead (does the same thing)

### Version 2.3.3

- **CardAnimationResource System** - New reusable animation system for card layouts
- Fixed cards not changing face when added to deck pile (Thanks to Davidy22)
- Fixed cards drag bug when trying to move already dropped card (Thanks to iant72)
- Optimized cards and hands processes to be disabled when not used.

### Version 2.3.2

- Fixed bugs and typos

### Version 2.3.1

- **CardMat** - New simple panel that checks for cards dropped inside of the area
- Added customizable condion fuction for card slots for better functionality

### Version 2.3

- **CardSlot Improved** - expended the slot to fit in better with the other containers
- Fixed card always snapping back to slot when dragged out
- Fixed error when dropping a card on its own slot while hovering
- Fixed signal connection leak in CardSlot
- Fixed Card Layouts panel being too small on first open

### Version 2.2

- **Card Layouts Panel** - New editor panel to view, create, edit, and delete layouts
- **LayoutID Constants** - Auto-generated constants for type-safe layout references with autocomplete
- **Improved Layout Discovery** - Layouts are now parsed from scene files without instantiation (faster startup)
- **Layout Enable/Disable** - Control which layouts are loaded at runtime via the panel

### Version 2.1.5

- Refactored the deck functions to be compatible with both draw and discard piles
- Added documentation

### Version 2.1

- **CardSlot** - Container for single cards with swap functionality
- **CardHandShape** - Moved shape logic to resources for easier customization
- Reworked layout discovery using metadata for better flexibility
- Deck manager functions for inserting cards at specific positions
- Pile preview using CardHand

### Version 2.0

- Complete rewrite with improved architecture
- Separated data (resources) from visuals (layouts)
- Improved drag and drop system
- Added CardHand and CardDeckManager

---

## Support

For feedback, suggestions, or issues:

- **Twitter/X:** [@twdoortoo](https://twitter.com/twdoortoo)
- **GitHub Issues:** [Create an issue](https://github.com/twdoor/simple-cards-v-2/issues)

---

**Good luck! -Tw**