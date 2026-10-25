# Building a release

Use the Godot 4.7.2 editor. Save all files first; validation and packaging read
saved files from disk. The root `LICENSE` is the canonical license text.

## Verify the version

Set the version in `addons/simple_cards/plugin.cfg` and `project.godot`, and add
the version/date to `CHANGELOG.md`. The packager takes its version from
`plugin.cfg`. Check the examples and API docs describe the final implementation.

## Run checks

Open `tests/run_tests.gd` in the Script Editor and use **File > Run**
(Ctrl+Shift+X). Desktop runs include real rendered shader checks. For CLI use,
see [Validation](VALIDATION.md).

`tests/ReleaseSmokeTest.tscn` exercises the actual example scenes. Run it with
one of these user arguments after `--`:

- `--case=balatro`: mouse selection, shiny/Glass, hover reset, sorting,
  discard/refill, pile preview/Escape, keyboard/controller accept, and play/refill.
- `--case=solitaire`: draw/undo, a legal three-card mouse drag/drop/undo, stock
  recycle, and recycle undo.
- `--case=macau-host` and `--case=macau-client` in two processes: start/deal,
  private hands, disconnect, reconnect, and a new match with a fresh snapshot.

For example:

```sh
godot --path . tests/ReleaseSmokeTest.tscn -- --case=solitaire
```

Add `--artifacts=/absolute/output/directory` to save screenshots. These tests
simulate input; they do not verify a physical controller or platform-specific
window behavior. Inspect the captured examples and the layout dock at narrow
and wide sizes. Check both direct and viewport faces can be created.

Export a test game with the plugin enabled and **Export all resources**. The
export plugin adds the layout-cache JSON. For an automated exported check, use
`ReleaseSmokeTest.tscn` as the main scene in a temporary project copy and run its
executable with `-- --case=balatro --export-smoke` (and then `solitaire`). Do not
change the distributed project's main scene for this check.

## Build archives

Open `tools/build_release.gd` in Godot's Script Editor and use **File > Run**.
Alternatively, after importing the project:

```sh
godot --headless --path . --script tools/build_release_headless.gd
```

The builder writes `.releases/<version>/`:

- `addon.zip`: `addons/simple_cards/`, ready to copy into another project.
- `project.zip`: the examples project, addon, docs, tests, and release tools.
- `<version-with-v>.zip`, for example `2v14.zip`: the addon inside a matching
  top-level folder, following the previous Asset Library package structure.

Every archive includes `addons/simple_cards/LICENSE`, copied from the root
license. The project archive also includes the root license. The builder reopens
all archives and compares every member with its source, including the license.
It includes source/import metadata and UID sidecars, and excludes `.godot`,
`.git`, prior releases, and unrelated files outside its source allowlist.

Extract and test the actual archives: enable the addon in a fresh project,
import the full example project without an existing `.godot` cache, and rerun
validation from that extracted project. Packaging does not publish, tag, or
upload anything. Keep exported binaries and diagnostic logs separate from the
three source archives.

`SHA256SUMS` records the SHA-256 hashes of the three completed ZIPs.
