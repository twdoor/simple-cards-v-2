# <img src="https://github.com/twdoor/simple-cards-v-2/blob/main/github/assets/simple_card_v2.png" width="8%"> Simple Cards

A flexible, UI-based card system plugin for **Godot 4.5.1+**. Build card games, deck builders, or any card-based interface using Control nodes that work seamlessly in both 2D and 3D projects.

![Example Animation](https://github.com/twdoor/simple-cards-v-2/blob/main/github/assets/gui_minijam_example.gif)

------

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Card Layouts Panel](#card-layouts-panel)
- [API Reference](github/API.md)
- [Examples](#examples)
- [Changelog](github/CHANGELOG.md)
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

![Balatro Example Animation](https://github.com/twdoor/simple-cards-v-2/blob/main/github/assets/balatro_example_new.gif)


### Solitaire

Located in `examples/solitaire/`, this demonstrates:

- Combined implementation of hands and mats
- Custom condition rules for card stacking and ordering in the hand. 
- Custom function for moving cards around

Run SolitaireExample.tscn to play.

![Solitaire Example Animation](https://github.com/twdoor/simple-cards-v-2/blob/main/github/assets/solitaire_example.gif)

### G.U.I
Game made for the minijam 201. 

You can give it a try here: https://twdoor.itch.io/gui

---

**Good luck! -Tw**
