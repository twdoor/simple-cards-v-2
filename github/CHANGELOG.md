# Changelog

## Version 2.10

- **Editor Layout Preview** — `Card` is now `@tool`. Cards placed in the editor show their actual layout template (panels, borders, textures) at the correct size instead of a blank rectangle. Card size is read from the layout's SubViewport.
- **Live Data Preview** — Layout scripts marked `@tool` get full data-driven preview in the editor. Changing card_data, value, suit, or modifier updates the card visually in real time. `standard_layout.gd` ships with `@tool` as a reference.
- **Layout Name Enum Dropdowns** — `Card` and `CardResource` now use `_validate_property` to show `front_layout_name` and `back_layout_name` as enum dropdowns populated from `LayoutID.get_all()` instead of plain text fields.
- **CardResource is `@tool`** — Required for the layout enum dropdown. Pure data container, no side effects. Subclasses need their own `@tool` annotation for the enum to appear (GDScript does not inherit `@tool`).
- **Consistent Callback Naming** — `CardContainer` virtual callbacks renamed: `_on_card_added` → `_handle_card_added`, `_on_card_removed` → `_handle_card_removed`, `_on_container_empty` → `_handle_container_empty`, `_on_container_full` → `_handle_container_full`. All user-facing extension points now use the `_handle_*` prefix; `_on_*` is reserved for internal signal handlers.
- **`_clamp_max_cards()` Virtual** — New virtual method on `CardContainer` called by the `max_cards` setter. `CardSlot` overrides it to always return `1`, preventing accidental misconfiguration from code or inspector.
- **CardSlot Swap Callbacks** — `_swap_cards()` now fires `_handle_card_removed` / `_handle_card_added` callbacks and signals for both the outgoing and incoming card, matching the behavior of normal card transfers.
- **Layout Panel Preview** — Selecting a layout in the Card Layouts panel now shows a scene preview thumbnail in the details panel.
- Fixed typos in `CardLayout` documentation (`Refrence` → `Reference`, `Emited` → `Emitted`, `Overwrite` → `Override`).

### Breaking Changes

- `CardContainer`: Virtual callbacks renamed — `_on_card_added` → `_handle_card_added`, `_on_card_removed` → `_handle_card_removed`, `_on_container_empty` → `_handle_container_empty`, `_on_container_full` → `_handle_container_full`. Subclasses overriding the old names must rename.

## Version 2.9

- **Animation Resource Safety** — `FadeCardAnimation` and `ScaleCardAnimation` no longer store tween references as instance variables. This fixes a bug where shared `.tres` animation resources would overwrite each other's tweens when used by multiple cards simultaneously.
- **Layout Switching Guard** — `Card._setup_layout()` now has a `_layout_switching` guard to prevent overlapping layout transitions when `flip()` is called rapidly.
- **Focus Await Safety** — `_on_focus_entered` and `_on_focus_exited` now check `is_inside_tree()` after awaiting animations, preventing state updates on freed cards.
- **`get_cards()` Returns Duplicate** — `CardContainer.get_cards()` now returns a copy of the internal array (matching `CardDeck.get_cards()` behavior) so callers can't accidentally mutate internal state.
- **Typed `LayoutResult`** — `ContainerShape.compute_layout()` and `_compute_raw_cards()` now return a typed `ContainerShape.LayoutResult` inner class instead of an untyped Dictionary. Custom shapes must update their return type accordingly.
- **Unified Validation** — `CardSlot.check_conditions()` renamed to `_check_conditions()` to match the parent `CardContainer` pattern. All container subclasses now override the same method.
- **Explicit Batch Mode** — `deal_to()`, `move_cards_to()`, and `move_all_to()` now accept a `batch: bool = false` parameter to explicitly defer layout computation. Still auto-enabled when `duration = 0` for backward compatibility.
- **Reorder Optimization** — `CardHand._update_card_reordering()` skips the insertion index search when the cursor has moved less than 2px, reducing unnecessary computation during drag.
- **Deprecated API Removed** — Replaced `get_editor_interface()` with the `EditorInterface` singleton (Godot 4.5+).
- **Scan Performance** — Layout cache scan now skips `.tscn` files whose modified time matches the cache, avoiding unnecessary file reads on large projects.
- **RegEx Caching** — `LayoutCache` now compiles regex patterns once at init instead of per-file during scans.
- **Debug Prints Cleaned** — Runtime `print()` calls in `CardGlobal` replaced with `push_warning` or removed. Editor prints in `LayoutCache` gated behind a `DEBUG_LOG` constant.
- **Return Type Annotations** — Added `-> void` to all async layout animation methods (`_flip_in`, `_flip_out`, `_focus_in`, `_focus_out`, `play_animation`).
- **Signal Cleanup** — `CardMat._exit_tree()` now properly disconnects mouse signals.
- **Internal Renames** — `CardGlobal._layouts` → `_layout_paths`, `_layouts_by_id` → `_layout_tags` for clarity.
- Removed `tween_started` and `tween_completed` signals from `Card`.
- Fixed typo in layout panel validation message.

### Breaking Changes

- `ContainerShape`: `compute_layout()` and `_compute_raw_cards()` now return `ContainerShape.LayoutResult` instead of `Dictionary`. Custom shapes must update their return type and use `LayoutResult.new(positions, rotations)`.
- `CardSlot`: `check_conditions()` renamed to `_check_conditions()`. Subclasses overriding `check_conditions()` must rename to `_check_conditions()`.
- `Card`: `tween_started` and `tween_completed` signals removed. Remove any connections to these signals.
- `Card`: `_check_for_hold()` return type changed from `bool` to `void`.

### Version 2.8

- Integrated the multicard dragging from the solitaire example into the main hand script with extra functionality.
- Added a lot of virtual methods for all containers, the `_handle_...` functions trigger at the same time with their respective signal to give more flexibility when making subclasses of containers.
- CardGlobal now has a 'rng' variable to control random events (only pile shuffle for now)

## Version 2.7

- **CardContainer Base Class** — New `Panel`-based base class for `CardHand`, `CardPile`, and `CardSlot`. Shared logic (card array, layout computation, signals, queries, bulk operations, clear/free) lives here once instead of being duplicated across three files.
- **`Card.move_to()`** — New single-call API for moving cards between containers. Handles reparenting, registration, and animated tweening. Replaces the old `add_card()` / `draw_card()` / `remove_card()` pattern. Supports custom duration (`0` for instant) and insertion index.
- **Bulk Operations** — `deal_to()`, `move_cards_to()`, and `move_all_to()` on `CardContainer` for batch card transfers with optional stagger animation. Instant moves (`duration = 0`) use batch mode for efficient layout computation.
- **ContainerShape** — Renamed from `CardHandShape`. Shapes now only compute positions and rotations (pure data) — they no longer tween cards. All built-in shapes renamed: `LineShape`, `ArcShape`, `GridShape`, `StackShape`. The `shape` export now lives on `CardContainer`, so all container types can use shapes.
- **CardResource Layouts** — `custom_layout_name` replaced with `front_layout_name` and `back_layout_name`, allowing per-card override of both faces. !this have priority over default layouts!
- **CardSlot** — Now extends `CardContainer` with `max_cards = 1`. Simplified API — use `card.move_to(slot)` to place and `slot.get_card().move_to(target)` to transfer. Swap logic, abandon, and lock all preserved.
- **CardPile** — Now extends `CardContainer`. `draw_card()` / `draw_cards()` removed — use `pile.peek_top().move_to(target)` or `pile.deal_to(target, count)` instead. `peek_top()` remains for single-card access. `peek_top_cards()` replaced by `peek_cards(count, index)` which takes a 1-based directional index (positive = from top, negative = from bottom).
- **CardHand** — Now extends `CardContainer`. Reordering, focus chain, and z-index management preserved. All shared methods moved to base class.
- **Signal Consolidation** — `hand_empty`, `pile_emptied`, `slot_emptied` → `container_empty`. `hand_full` → `container_full`. `slot_filled` → `card_added`. `pile_changed` removed (use `card_added`/`card_removed` + `get_card_count()`).
- **`move_completed` Signal** — New signal on `Card`, emitted when `move_to()` finishes (after tween or instant snap).
- Fixed LayoutID/LayoutCache not properly saving on MacOS.

### Breaking Changes

- `CardHand`, `CardPile`, `CardSlot` now extend `CardContainer` (which extends `Panel`) instead of `Control`/`Panel` directly. !!This will break every scene that has Hands or Piles unless replaced or changed to Panel instead of Control in the .tscn code (open .tscn file with code editor)!!
- `add_card()`, `add_cards()`, `remove_card()`, `draw_card()`, `draw_cards()`, `draw_card_at()`, `add_card_at()` removed from all containers. Use `card.move_to(target)` and bulk methods instead.
- `clear_hand()`, `clear_pile()`, `clear_slot()` removed. Use `clear_and_free()` to free all cards, or `move_all_to()` to transfer them to another container.
- `arrange_cards()` → `arrange()`.
- `max_hand_size` → `max_cards`.
- `is_hand_full()` → `is_full()`.
- `held_card` on `CardSlot` → `get_card()`.
- `pop_card()`, `transfer_to_hand()` removed from `CardSlot` — use `move_to()` directly. `swap_with()` retained.
- `hand_empty`, `hand_full`, `hand_cleared`, `pile_emptied`, `pile_changed`, `slot_filled`, `slot_emptied` signals removed — use `container_empty`, `container_full`, `card_added`, `card_removed`.
- `CardHandShape` → `ContainerShape`. `LineHandShape` → `LineShape`, `ArcHandShape` → `ArcShape`, `GridHandShape` → `GridShape`, `StackHandShape` → `StackShape`.
- `apply_layout()` removed from `ContainerShape` — shapes only compute, containers handle animation.
- `CardResource`: `custom_layout_name` → `front_layout_name` + `back_layout_name`.

## Version 2.6

- **CardPile** — New `Control` node that acts as a container for cards. Supports draw, add, shuffle, peek, and arrangement operations. Can use any `CardHandShape` for visual layout or stack cards invisibly. This is now the building block for deck systems.
- **CardDeck Simplified** — `CardDeck` is now a pure data resource. It defines _what cards_ a deck contains (`cards` array) and nothing else. All runtime pile state, signals, serialization, and the `Pile` enum have been removed. Use `CardPile` nodes for runtime state instead.
- **CardDeckManager Simplified** — The manager now only creates `Card` instances from a `CardDeck` and populates a `CardPile`. All draw/discard/shuffle/preview/save-load logic has been removed — interact with `CardPile` nodes directly. Override `_create_card()` to customize card instantiation.
- **Reparenting Overhaul** — `CardHand`, `CardSlot`, and `CardPile` now track cards via `child_exiting_tree`. When a card is reparented away (e.g., via `reparent()` or moving to another container), the source container automatically cleans up its internal state and emits the appropriate signals. Manual `_release_card()` is no longer needed.
- **CardHand** — Added `clear_and_free()`, `has_card()`, `_on_card_added()`, and `_on_card_removed()` virtual callbacks. `remove_card()` now returns the card instead of void and no longer takes a `new_parent` parameter. Removed `_release_card()`.
- **CardSlot** — `remove_card()` now takes a `card: Card` parameter instead of `new_parent: Node`. Added `pop_card()` for removing the held card without specifying which card. Swap logic simplified using the new `_take_card()` helper.
- **CardHandShape** — `compute_layout()` and `_compute_raw_cards()` no longer require a `hand: CardHand` parameter, allowing shapes to be reused by both `CardHand` and `CardPile`.
- **StackHandShape** — New built-in shape that stacks all cards at the same position. Useful for draw/discard pile visuals.
- **Card** — Added early-exit guard on `is_front_face` setter to avoid redundant flips.
- **Check Exports** - Exports like arrays or assigned nodes on the deck and manager might need to be remade/reassigned.

### Breaking Changes

- `CardDeck`: No longer contains runtime pile state. The `Pile` enum, all signals, `card_list` (now `cards`), `piles`, `reset_to_draw()`, `draw_from_pile()`, `add_to_pile()`, `move_card()`, `shuffle_pile()`, `save_state()`, `load_state()`, and all related methods have been removed. It is now a pure data resource.
- `CardDeckManager`: All draw/discard/add/remove/shuffle/preview/save-load methods have been removed. Use `CardPile` methods directly instead. `pile_nodes` and `front_face_in_pile` exports removed. `shuffle_on_ready` renamed to `shuffle_on_setup`. The manager now takes a `starting_pile: CardPile` export instead.
- `CardHand`: `remove_card()` signature changed from `(card, new_parent)` to `(card)` returning `Card`. `_release_card()` removed — use `_on_card_removed()` instead.
- `CardSlot`: `remove_card()` signature changed from `(new_parent)` to `(card)`. Use `pop_card()` for the old behavior of removing whatever card is held.
- `CardHandShape`: `compute_layout()` and `_compute_raw_cards()` no longer take a `hand: CardHand` parameter. Update custom shapes accordingly.

## Version 2.5.2

- **CardHandShape Refactor** - Split layout into `compute_layout()` and `apply_layout()` phases. Subclasses now only override `_compute_raw_cards()` — bounding box adjustment, tween application, and sizing are handled by the base class automatically.
- **Card Placement Fix** - All built-in shapes (Line, Arc, Grid) now correctly place cards inside the hand's bounding rect instead of centering around origin.
- **`_release_card()` Virtual Method** - New overridable method for cleanup when a card leaves the hand by any path (remove, transfer, drag out). Subclasses should override this instead of `remove_card()` for cleanup logic.
- **Drag Reordering** - `_find_insertion_index()` now uses 2D slot-based distance instead of x-axis only, fixing reordering for arc and grid shapes.
- **Minimum Size** - Hand respects `custom_minimum_size` set in the editor; `_get_minimum_size()` returns `Vector2.ZERO` when empty.

### Breaking Changes

- `CardHandShape`: `arrange_cards()` replaced by `compute_layout()` + `apply_layout()`. Custom shapes must now override `_compute_raw_cards()` instead of `arrange_cards()`.
- `CardHand`: `_release_card()` is now the recommended override point for card removal cleanup instead of `remove_card()`.

## Version 2.5.1

- **Solitaire**: new example scene, fully playable game of soliaire
- Added some comments to the examples to explain some functions
- Updated Balatro example a bit to reflect some changes made over time
- **ScaleCardAnimation**: now tweens the layout instead of the card to fix some animation order bug
- **LineHandShape**: minor improvements; now has align option (begin/center/end)

## Version 2.5

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

## Version 2.4

- **Deck Refactoring** - the CardDeck and CardDeckManager got a major changes; moved the main logic into the CardDeck, generalized the pile system for expandability and started on a save/load system.
- Cleaned CardHand logic to remove the duplicated `_cards` array
- New premade hand shape: **GridHandShape**.

### Breaking Changes

- `CardDeck`/`CardDeckManager`: All methods using `is_discard: bool` now use `pile: CardDeck.Pile` enum

- `CardDeckManager`: Removed `add_card_to_pile_from_top_at()` - use `add_card_to_pile_at()` with negative numbers

- `CardHand`: `refresh_arrangement()` was removed, `arrange_cards()` is now a public method instead (does the same thing)

## Version 2.3.3

- **CardAnimationResource System** - New reusable animation system for card layouts
- Fixed cards not changing face when added to deck pile (Thanks to Davidy22)
- Fixed cards drag bug when trying to move already dropped card (Thanks to iant72)
- Optimized cards and hands processes to be disabled when not used.

## Version 2.3.2

- Fixed bugs and typos

## Version 2.3.1

- **CardMat** - New simple panel that checks for cards dropped inside of the area
- Added customizable condion fuction for card slots for better functionality

## Version 2.3

- **CardSlot Improved** - expended the slot to fit in better with the other containers
- Fixed card always snapping back to slot when dragged out
- Fixed error when dropping a card on its own slot while hovering
- Fixed signal connection leak in CardSlot
- Fixed Card Layouts panel being too small on first open

## Version 2.2

- **Card Layouts Panel** - New editor panel to view, create, edit, and delete layouts
- **LayoutID Constants** - Auto-generated constants for type-safe layout references with autocomplete
- **Improved Layout Discovery** - Layouts are now parsed from scene files without instantiation (faster startup)
- **Layout Enable/Disable** - Control which layouts are loaded at runtime via the panel

## Version 2.1.5

- Refactored the deck functions to be compatible with both draw and discard piles
- Added documentation

## Version 2.1

- **CardSlot** - Container for single cards with swap functionality
- **CardHandShape** - Moved shape logic to resources for easier customization
- Reworked layout discovery using metadata for better flexibility
- Deck manager functions for inserting cards at specific positions
- Pile preview using CardHand

## Version 2.0

- Complete rewrite with improved architecture
- Separated data (resources) from visuals (layouts)
- Improved drag and drop system
- Added CardHand and CardDeckManager
