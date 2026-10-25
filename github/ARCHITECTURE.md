# Architecture and ownership

The addon lives entirely in `addons/simple_cards`. Examples depend on the addon;
the addon must never depend on examples. `tests/validation_runner.gd` verifies a separate
addon-only installation to protect that boundary.

## Layout data

The root metadata in each layout scene owns its `layout_id` and `tags`.
Use the Card Layouts dock to edit it, or edit the root metadata in the scene.
Child-node metadata does not register a layout. Refresh rescans saved scenes;
unsaved editor changes must be saved first.

`LayoutCache` discovers scenes and builds `editor/layout_cache.json`. This file
also owns the user's enabled/disabled choices, which cannot be reconstructed
from scene metadata. Keep it in version control. Refresh preserves these choices
for existing paths; moving a scene is currently treated as a new path.

`layout_ids.gd` is generated autocomplete data for enabled layouts. Never edit it
by hand. The cache and generated constants are updated together only when layout
metadata passes validation. Fix errors shown in the dock, then Refresh.

`CardGlobal` reads the cache at runtime and builds lookup dictionaries. These
are derived state. It skips malformed entries and falls back to the built-in
faces. Runtime lookup does not scan the project or rewrite source files.
The export plugin includes the JSON; selected-resource exports still need all
referenced layout scenes and card resources explicitly included.

`LayoutValidation` owns identifier, generated-constant collision, cache-entry,
missing-scene, and template-root checks. The editor and runtime share these
rules. Templates are checked by instantiating them outside the tree; valid roots
extend `CardLayout`. Custom constructors must take no required arguments.

## Runtime boundaries

- `CardResource`: game-defined card data and face IDs.
- `CardLayout`: presentation and face animation. `CardViewportLayout` composes
  child visuals and owns an ordered shader stack, per-card material instances,
  capture resolution, and caching. It draws the final shader in the surrounding
  canvas. Effect-specific behavior and game rules belong outside these types.
- `Card`: interaction and the public move/flip API.
- `CardMotion`: transform tweens and cancellation. `Card` creates it on first use
  with `CardMotion.new()` and delegates movement to it. Tween state stays on the card.
- `CardContainer`: membership, acceptance, transfer notifications, arrangement.
  `CardHand`, `CardPile`, and `CardSlot` supply specialized behavior.
- `ContainerFocusNavigation`: directional and sequential focus links, including
  shape-specific neighbors. Containers create it on first use with
  `ContainerFocusNavigation.new()` and expose navigation override methods.
- `ContainerShape`: computes positions and rotations without moving nodes.
- `CardDeck`: deck definition; `CardDeckManager`: creates cards into a pile.
- `CardGlobal`: runtime autoload for shared layout lookup, held-card state, and active network
  manager lookup. Add new game/session rules in scene-local controllers.
- `editor/`: dock, discovery, and preview helpers. Runtime nodes allocate editor
  previews only when needed in the editor.
- `network/`: experimental synchronization and snapshot helpers.
- `RegisteredCardNetwork`: shared abstract base for the two built-in
  managers, owning their shared registries and cleanup. ID generation, RPCs,
  permissions, and command execution belong to each concrete manager. Custom
  managers extend `CardNetworkManager` directly.

## Editor initialization

Editor previews load layouts through `LayoutCache`. Tool-script editor branches
do not access the runtime autoload.

The plugin registers the autoload before loading its editor panel. On first
registration, `editor/card_global_bootstrap.tscn` establishes the global name
before Godot compiles the card scripts that reference it. The plugin then replaces
that empty Control with `card_global.gd`, which is the path saved in the project
configuration. Disabling the plugin removes its autoload.
