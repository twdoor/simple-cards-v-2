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
- **Hand Management** - Arrange cards in lines, arcs, grids, or custom shapes
- **Extensible Deck System** - Dictionary-based pile management for easy extension
- **Card Slots** - Drop zones for placing individual cards
- **Flip Animations** - Front/back card faces with transition support
- **Layout Management Panel** - Editor panel to view, create, and manage all card layouts
- **Fully Documented** - In-editor documentation for all classes

------

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
func tween_position(desired_position: Vector2, duration: float = 0.2, global: bool = false) -> void

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

#### Virtual Methods (Override These)

```gdscript
# Called when resource changes - update your visuals here
func _update_display() -> void:
    pass

# Called when layout is added to card
# Uses flip_in_animation if set, otherwise override for custom behavior
func _flip_in() -> void:
    if flip_in_animation: flip_in_animation.play_animation(self)

# Called when layout is removed
# Uses flip_out_animation if set, otherwise override for custom behavior
func _flip_out() -> void:
    if flip_out_animation: flip_out_animation.play_animation(self)

# Called when card gains focus
# Uses focus_in_animation if set, otherwise override for custom behavior
func _focus_in() -> void:
    if focus_in_animation: focus_in_animation.play_animation(self)

# Called when card loses focus
# Uses focus_out_animation if set, otherwise override for custom behavior
func _focus_out() -> void:
    if focus_out_animation: focus_out_animation.play_animation(self)
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

#### Methods

```gdscript
# Add a single card (returns true if successful)
func add_card(card: Card) -> bool

# Add multiple cards (returns number successfully added)
func add_cards(card_array: Array[Card]) -> int

# Remove a card (does NOT free it)
func remove_card(card: Card, new_parent: Node = null) -> void

# Remove all cards (does NOT free them)
func clear_hand() -> void

# Get card by index
func get_card(index: int) -> Card

# Get card count
func get_card_count() -> int

# Get index of a card
func get_card_index(card: Card) -> int

# Check if hand is full
func is_hand_full() -> bool

# Get remaining space
func get_remaining_space() -> int

# Force arrangement of cards
func arrange_cards() -> void
```

#### Virtual Methods

```gdscript
# Override to handle card clicks
func _handle_clicked_card(card: Card) -> void:
    print("Card clicked: ", card.name)
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

Abstract resource class that defines how cards are arranged in a hand.

#### Built-in Shapes

**LineHandShape**

```gdscript
var line = LineHandShape.new()
line.line_rotation = 0.0      # Rotation in degrees
line.max_width = 600.0        # Maximum spread width
line.card_spacing = 50.0      # Space between cards
```

**ArcHandShape**

```gdscript
var arc = ArcHandShape.new()
arc.arc_radius = 400.0        # Circle radius
arc.arc_angle = 60.0          # Total arc angle (degrees)
arc.arc_orientation = 270.0   # Where the arc points (270 = up)
arc.card_spacing = 50.0       # Space between cards
```

**GridHandShape** *(New in 2.4)*

```gdscript
var grid = GridHandShape.new()
grid.num_of_cols = 3          # Number of columns
grid.num_of_rows = 3          # Number of rows
grid.col_offset = 120.0       # Horizontal spacing
grid.row_offset = 150.0       # Vertical spacing
grid.arrange_by_rows = true   # Fill rows first (true) or columns first (false)
```

Features:

- Auto-expansion to fit all cards
- Auto-centering for incomplete last row/column
- Configurable row-first or column-first arrangement

---

### CardSlot

A panel that accepts a single dropped card.

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `card_entered` | `card: Card` | Card started hovering over slot 
| `card_exited`  `card: Card`  Card stopped hovering |
| `card_dropped` | `card: Card` | Card was dropped on slot |
| `card_abandoned` | `card: Card` | Card was removed via abandon (dropped on empty space) |
| `slot_lock_changed` | `is_locked: bool` | Slot lock state changed |

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

# Remove the card from the slot
func remove_card(new_parent: Node = null) -> Card

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

A panel that detects dropped card.

#### Signals

| Signal | Parameters | Description |
| --- | --- | --- |
| `card_entered` | `card: Card` | Card started hovering over mat |
| `card_exited` | `card: Card` | Card stopped hovering |
| `card_dropped` | `card: Card` | Card was dropped on mat |

#### Virtual Methods

```gdscript
# Override to handle action when card is dropped
func handle_dropped_card(card: Card) -> void:
    pass
```

---

### CardDeck

A resource that stores card composition and runtime pile state. Uses dictionary-based pile system for extensibility.

#### Enum

```gdscript
enum Pile {
    DRAW,
    DISCARD,
}
```

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `deck_name` | `StringName` | Optional name for the deck |
| `card_list` | `Array[CardResource]` | Complete deck composition |
| `piles` | `Dictionary[Pile, Array]` | Runtime pile state (automatically managed) |

#### Methods

```gdscript
# Initialization
func reset_to_draw() -> void
func shuffle_pile(pile: Pile = Pile.DRAW) -> void

# Deck building
func add_card(card: CardResource) -> void
func remove_card(card: CardResource) -> bool
func get_card_count(card: CardResource) -> int
func duplicate_deck() -> CardDeck

# State queries
func get_pile(pile: Pile) -> Array
func get_pile_size(pile: Pile = Pile.DRAW) -> int
func is_pile_empty(pile: Pile = Pile.DRAW) -> bool
func get_total_card_count() -> int

# State manipulation
func draw_from_pile(pile: Pile = Pile.DRAW) -> CardResource
func add_to_pile(card: CardResource, pile: Pile = Pile.DRAW) -> void
func move_card(card: CardResource, from_pile: Pile, to_pile: Pile) -> bool
func move_pile_to_pile(from_pile: Pile, to_pile: Pile) -> void
func move_discard_to_draw() -> void

# Serialization
func save_state() -> Dictionary
func load_state(state: Dictionary) -> void
```

---

### CardDeckManager

Manages visual Card nodes from a CardDeck resource. Uses dictionary-based pile system for extensibility.

#### Properties

| Property | Type | Description |
| --- | --- | --- |
| `deck` | `CardDeck` | The deck being managed |
| `auto_setup` | `bool` | Auto-setup on ready |
| `shuffle_on_ready` | `bool` | Shuffle on setup |
| `show_cards` | `bool` | Show cards in piles |
| `pile_nodes` | `Dictionary[CardDeck.Pile, Node]` | Container nodes for each pile |
| `front_face_in_pile` | `Dictionary[CardDeck.Pile, bool]` | Face-up state per pile |

#### Methods

```gdscript
# Setup
func setup(starting_deck: CardDeck = deck) -> void

# Drawing cards
func draw_card(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> Card
func draw_cards(count: int, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> Array[Card]

# Peeking
func peek_top_card(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> Card
func peek_top_cards(count: int, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> Array[Card]

# Adding cards
func add_card_to_pile(card: Card, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> void
func add_card_to_pile_at(card: Card, index: int, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> void

# Removing cards
func remove_card_from_pile(card: Card, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> bool
func remove_card_from_pile_at(index: int, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> Card

# Pile operations
func shuffle(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> void
func reshuffle_discard_into_draw() -> void
func reshuffle_discard_and_shuffle() -> void

# Pile info
func get_pile_size(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> int
func is_pile_empty(pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> bool
func get_total_card_count() -> int

# Preview
func show_pile_preview_hand(preview_hand: CardHand, pile: CardDeck.Pile = CardDeck.Pile.DRAW) -> void
func hide_pile_preview_hand() -> void

# Save/Load
func save_deck_state() -> Dictionary
func load_deck_state(state: Dictionary) -> void

# Cleanup
func clear_deck() -> void
```

#### Example

```gdscript
@onready var deck_manager: CardDeckManager = $CardDeckManager
@onready var hand: CardHand = $Hand

func _ready():
    deck_manager.setup()
    draw_starting_hand()

func draw_starting_hand():
    var cards = deck_manager.draw_cards(5)
    hand.add_cards(cards)

func discard_card(card: Card):
    hand.remove_card(card)
    deck_manager.add_card_to_pile(card, CardDeck.Pile.DISCARD)

func reshuffle():
    deck_manager.reshuffle_discard_and_shuffle()
```

---

### CardGlobal (CG)

The global singleton providing shared state and utilities. Access via `CG`.

#### Properties

| Property            | Type         | Description                    |
| ------------------- | ------------ | ------------------------------ |
| `def_front_layout`  | `StringName` | Default front layout ID        |
| `def_back_layout`   | `StringName` | Default back layout ID         |
| `current_held_item` | `Card`       | Currently dragged card         |
| `card_index`        | `int`        | Auto-incrementing card counter |

#### Signals

| Signal           | Parameters   | Description                         |
| ---------------- | ------------ | ----------------------------------- |
| `holding_card`   | `card: Card` | Card started being dragged          |
| `dropped_card`   | -            | Card was released                   |
| `layouts_loaded` | -            | Layouts have been loaded from cache |

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

### Balatro Style

Located in `examples/balatro_style/`, this demonstrates:

- Custom card resource with suits, values, and modifiers
- Hand selection and sorting
- Deck management with draw/discard
- Pile preview functionality

Run the scene to see a Balatro-inspired card game interface.

---

## Changelog

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

------

## Support

For feedback, suggestions, or issues:

- **Twitter/X:** [@twdoortoo](https://twitter.com/twdoortoo)
- **GitHub Issues:** [Create an issue](https://github.com/twdoor/simple-cards-v-2/issues)

------

**Good luck! -Tw**
