# Validation

Run from any directory with Python 3 and a Godot editor binary:

```bash
GODOT=/path/to/godot python3 /path/to/simple-cards-v-2/tests/run_tests.py
```

`GODOT` falls back to `godot` or `godot4` on PATH. Validation imports a temporary copy without `.godot`, `.git`, or release output, so local editor state and generated caches cannot hide setup failures or be overwritten by the checks. The runner prints its retained log directory; set `TEST_LOG_DIR` to choose one.

The suite covers core ownership/order/signals, slot conditions and swaps, focus after transfers/sorting, rejected drops, layout sizing/fallback, shared animation teardown, Solitaire undo, multiplayer visibility/resource isolation, pending-request cleanup, and repeated example teardown. Separate ENet processes exercise rejection, a lost reply and timeout recovery, client board recreation/reconnection, and disconnect during a pending request. Separate Macau sessions exercise two and six players, initial card conservation, and snapshot refresh.

The runner was also checked against zero-exit script errors, incomplete test output, subprocess timeout, and a server port already in use; each failed as intended and cleaned up its child process.

The roundtrip-only entry point is `tests/run_server_roundtrip.sh`; `TEST_PORT` overrides its automatically selected UDP port. Macau uses its example's UDP port 24455, so close other local Macau sessions before running validation. Network processes have readiness checks, deadlines, and cleanup on failure.

`tests/check_install.py` also runs independently. It installs only the addon into a temporary project, discovers custom layouts, transfers a custom card, exports a pack, and runs that pack outside the source tree. Use **Export all resources** for this supported export path; when exporting selected resources, include every dynamically selected layout and card resource explicitly. The enabled plugin includes the layout-cache JSON automatically. The fixture also verifies editor disable/re-enable, layout enable/disable, path/ID rename, deletion, and default preservation. Actual editor Card/CardPile instances exercise layout replacement, preview counts and bounds, disabling previews, and tree re-entry without registering preview cards as runtime members.

Native Linux debug export was additionally built and launched in isolation with the official Godot 4.5.2 template. To repeat it, set `GODOT_LINUX_TEMPLATE=/path/to/linux_debug.x86_64` when running `tests/check_install.py`; the standard suite uses pack export so CI does not need the full template download.

GitHub Actions runs the same suite on Godot 4.5.1 and 4.5.2 and uploads logs. A workflow file is provided; hosted CI results require pushing the change.

## Shutdown diagnostics

Runtime errors and engine errors fail validation even when Godot returns exit code zero. Leaked nodes, tweens, timers, animation resources, and unexpected script resources also fail.

Godot 4.5.2 exhibits script-resource retention after certain combinations of scripts are loaded. This can occur in the editor and when switching between different examples. Loading their scenes without instantiating any gameplay nodes reproduces the script-only signature. A separate no-addon reproduction of the underlying compiler behavior is available:

```bash
GODOT=/path/to/godot python3 tests/reproduce_engine_retention.py
```

It reproduces the behavior described in [Godot issue #122022](https://github.com/godotengine/godot/issues/122022). The reproduction intentionally prints a leak diagnostic; it is not a passing gameplay test. This is evidence for attributing the matching script-only shutdown signature to engine retention, rather than a claim that all shutdown leaks are engine defects.

The runner permits only an exact, recorded signature on 4.5.1/4.5.2 for import, core regression, combined example teardown, and rendered example gameplay: 11 named addon GDScript resources, 13 GDScript instances including two inner classes, and 10 GDScriptNativeClass instances. The preview extraction removes LayoutCache and its native base from the previously recorded signature; no new helper, node, or helper instance is retained. Helpers load lazily to avoid adding preload cycles to this script graph. No other instance type or resource path is accepted. Logs retain the full diagnostics and the console labels the exception. Set `STRICT_ENGINE_LEAKS=1` to fail on this signature too. Revisit the exception when updating Godot; do not expand it to cover a new leak without diagnosis.

## Snapshot benchmark

`tests/SnapshotBenchmark.tscn` measures 20 full broadcasts and 20 client snapshot applications. This is a stress case with every card in one hidden pile, so each new snapshot replaces all concealed card nodes. Player counts include the host. Encoded byte counts exclude transport overhead; apply timings exclude rendering and the subsequent deletion frame.

Reference run: Godot 4.5.2, Linux, AMD Ryzen 5 4600H, headless, September 16, 2026. Timings vary with system load.

| Cards | Players | Encoded bytes per broadcast | Build + encode | Apply per client | Hidden nodes replaced per client |
| --- | --- | --- | --- | --- | --- |
| 52 | 2 | 16,586 | 0.76 ms | 34.04 ms | 52 |
| 52 | 6 | 83,038 | 4.69 ms | 28.37 ms | 52 |
| 104 | 2 | 32,814 | 1.67 ms | 61.18 ms | 104 |
| 104 | 6 | 164,158 | 7.91 ms | 60.43 ms | 104 |

Hidden-node replacement can exceed a frame budget even for a turn-based board. Avoid sending redundant full snapshots continuously. This update preserves the protocol and identity-rotation privacy behavior; node reuse or delta replication needs separate design and profiling. The Macau sample uses public draw-pile identities with local face masking and is a different, trusted-P2P workload.

## Rendered checks and release checklist

A rendered capture helper sends Tab, resizes the window to 1024 × 640, captures the viewport, and tears down the example:

```bash
/path/to/godot --path . --scene res://tests/VisualCheck.tscn -- \
  res://examples/balatro/BalatroExample.tscn /tmp/balatro.png
```

Balatro and Solitaire rendered captures were inspected during implementation: cards, controls, layout, and stacking remained visible after resize. Two- and six-player Macau captures were also inspected: local hands were readable, opponent identities stayed concealed in the UI, and counts matched the one-/two-deck setup. The six-player rendered process test passed after orderly session teardown. These checks do not replace a full mouse/controller playthrough.

Run the rendered gameplay suite in an isolated X11 display (requires Xvfb and libXtst on Linux):

```bash
GODOT=/path/to/godot xvfb-run -a python3 tests/run_tests.py --rendered-only
```

This separate, bounded suite imports a fresh copy, uses native X11 mouse events for drags and injects keyboard/gamepad events, checks state after actions, saves screenshots, and runs real two-/six-process Macau games. It covers:

- Balatro: selection, reorder, keyboard/gamepad focus and accept, modifiers, sorting, play/discard/refill, and both pile previews.
- Solitaire: one-/three-card draw, recycle, rejected drops, legal single/stack drops, face restoration and undo (including every recycled waste card), reset, and resize. The stack setup uses existing deck cards in a deterministic legal arrangement.
- Macau: local hand visibility, concealed opponent nodes, host penalty play, remote penalty draw, ordinary draw/play, snapshot refresh, card conservation, and host disconnect presentation. Controlled card ranks exercise the same paths regardless of the deal.
- Editor plugin/cache lifecycle and native Linux export remain covered by `check_install.py`.

The CI matrix runs both headless and rendered suites and retains screenshots with logs. Injected controller events verify application input handling; physical controller discovery, mapping, and feel still require hardware testing. These are automated gameplay checks, not a claim of a human playthrough.

Public class names, exported properties, signals, and method signatures remain compatible. Network snapshots now isolate each card's mutable resource data; code should compare resource IDs rather than rely on two client cards sharing the same resource object.
