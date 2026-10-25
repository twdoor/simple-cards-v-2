# Validation

Open `tests/run_tests.gd` in Godot's Script Editor and use **File > Run**
(Ctrl+Shift+X). This is an `@tool EditorScript` in the main project. Progress and
results appear in Output, and the editor remains open and responsive. Running it
again while validation is active prints a notice instead of starting another run.
Save changes first: validation reads files from disk.

For headless use or CI, run these commands from the repository root, replacing
`godot` with your editor executable path if needed:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/run_tests_headless.gd
```

Godot 4.7.2 is the only prerequisite. Both entry points use the same runner.
Every check runs in a temporary copy, including a separate
addon-only installation without the examples or a preconfigured autoload.
The headless import step registers project script classes before validation.
The runner uses the running editor executable to launch its child processes,
and Godot's file and process APIs for copying, timeouts, logs, and cleanup.
Failed runs retain their project copies and logs at the printed path; successful
runs remove them. No shell scripts or additional language runtimes are required.

The checks cover fresh imports, transfers and capacity, slot swaps, interaction
state, animation teardown, Solitaire undo, direct and viewport layout creation,
face switching, and example startup. Runtime tests must print their completion
marker and exit successfully. Script errors and engine errors fail validation.
Each process has a 90-second timeout.

Shader-stack checks cover named/indexed access, per-card material isolation,
parameter updates, bypassing effects, resizing, and capture counts. Running the
EditorScript in a desktop editor also launches pixel checks for effect ordering,
translucent colors, padding, and cached refreshes. To include these from the
headless runner in a desktop session, append `-- --rendered` to its command.
The rendered child process uses the real graphics driver; CI runs structural
shader checks with the headless dummy renderer.

Standard-deck checks also cover perspective reset when hover ends while drag
focus is retained, disabling tilt, and standalone faces without an owning Card.
Rendered checks repeat pressed pointer transitions between overlapping cards.

An editor plugin probe opens the Balatro example, adds a temporary slot, and verifies that slot
runtime processing stays off in the editor, including after reactivation as can
happen during a tool-script reload. Script errors in that editor session fail
validation as well.
It also checks plugin disable/re-enable registration and UID-based autoload
ownership. Installation fixtures verify the `CardGlobal` name and runtime behavior.

Multiplayer regressions cover hidden-card snapshots, permission rejection,
resource isolation, pending-request cleanup, registry replacement and cleanup in
both managers, and peer-to-peer transfer results without external servers.
Two local ENet processes also check authoritative results, rejection, timeout
recovery, reconnect snapshots, and disconnect cleanup. Local UDP sockets must be
available; this check does not require an internet service.

Known limitation: the headless editor currently reports retained ObjectDB
instances/resources during shutdown. These messages remain visible but do not
fail validation; no other engine errors are exempted. Diagnose this separately
before treating shutdown as leak-free.

Startup checks do not validate rendered appearance or mouse input.
Before releasing, check narrow/wide layout docks, create
both face types, drag/flip cards in each example, and connect two Macau clients.
The native example smoke checks and archive/export procedure are documented in
[Building a release](RELEASING.md).
