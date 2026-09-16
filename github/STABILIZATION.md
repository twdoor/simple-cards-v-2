# Stabilization update plan

Status: implemented and locally validated. The automated suite passes on Godot 4.5.1 and 4.5.2, with the exact engine script-retention exception documented in [Validation](VALIDATION.md). Hosted CI and the full manual release playthrough remain pre-release checks. No release has been published.

Implemented focused preview and snapshot extractions after the lifecycle fixes: editor layout loading/sizing and transient container visuals now live in dedicated helpers; card payload state and container order reconciliation live in network helpers. Public methods, inspector properties, signals, and scene/resource paths remain intact. Helpers borrow nodes per call and are created only when needed; none retain an owning node. Interaction, movement, and subclass hooks remain in the core classes.

## Objective

Make the existing card framework dependable to extend and release: reproducible checks, clean lifecycle handling, covered core behavior, and verified installation/export behavior. Preserve the public API and serialized scene/resource properties. Multiplayer remains experimental.

## Baseline

Review performed on Godot 4.5.2, matching `.godotrc`:

- Multiplayer regression tests passed.
- Separate server/client ENet roundtrip passed.
- Balatro, Solitaire, and Macau started in headless smoke checks.
- Editor shutdown reported leaked objects and 11 resources still in use.
- Balatro shutdown reported leaked objects and 3 resources still in use; Solitaire reported leaked objects. Causes remain unconfirmed. Forced smoke-test shutdown must be distinguished from normal scene cleanup.
- Existing automated coverage concentrates on multiplayer; no CI workflow was found.
- Visual behavior, clean-project installation, exports, and performance were not validated.

## 1. Reproducible validation — first priority

Deliver one documented command for local and CI validation.

- Add a runner accepting `GODOT`, with an installed `godot` fallback, and resolve paths relative to the repository rather than the caller's working directory.
- Import a fresh checkout before running tests so missing `.godot` caches cannot hide setup failures.
- Run regression scenes, the actual server/client roundtrip, and bounded example smoke checks. Retain separate logs and return nonzero on failed assertions, script/runtime errors, or timeouts, including errors emitted with engine exit code zero.
- Replace the roundtrip runner's fixed startup sleep with bounded server readiness. Make its port configurable, clean up both processes on failure/interruption, and bound connection waits.
- Add GitHub Actions using pinned Godot 4.5.2. Confirm 4.5.1 compatibility before retaining the README's 4.5.1+ minimum; resolve any discrepancy in code or documentation.
- Capture known shutdown diagnostics explicitly while investigating them; do not broadly suppress warnings or bless new leak reports.

Acceptance: a fresh checkout runs without manual editor setup; an unavailable server, test failure, or parser error fails promptly with useful logs and leaves no child process behind.

## 2. Lifecycle and shutdown fixes — release blocker

Use verbose engine diagnostics to identify leaked instance types and ownership before changing cleanup code.

- Compare normal scene removal and several idle frames before quit against abrupt `--quit-after` shutdown. Use a minimal project/control case if needed to separate engine diagnostics from addon defects.
- Investigate pending animation callbacks, resource references, editor panel/cache lifetime, bound signals, and example state only where diagnostics point.
- Exercise freeing cards during moves, flips, focus animations, and idle loops; freeing containers with cards; repeated scene replacement; and plugin enable/disable cycles.
- Verify the global held-card reference, network registries, and signal connections do not retain stale state after teardown.
- Add a focused regression for each confirmed lifecycle bug. Keep fixes separate from structural refactoring.

Acceptance: repeated normal teardown produces no addon-attributable leaks, invalid-instance errors, or callbacks into removed scenes. Any remaining engine-only or abrupt-shutdown diagnostic has a minimal reproduction and an explicit documented exception.

## 3. Core behavior coverage — release blocker

Test observable behavior and state invariants, with deterministic setup and bounded asynchronous waits.

| Area | Required scenarios and assertions |
| --- | --- |
| Transfers | Single/bulk/deal operations, insertion order, partial capacity, rejected moves, same-container moves; each card belongs to exactly one container and returned counts match actual moves. |
| Signals and slots | Add/remove counts and ordering, full/empty transitions, locked/rejecting slots, successful and rejected swaps; rejection leaves state intact. |
| Interaction | Drag/reorder completion, rejected drop recovery, overlapping-card input order, keyboard/controller focus after transfers, interaction restored after animation. Automate state checks and retain manual checks for actual input/visual behavior. |
| Layouts and resources | Front/back fallback, runtime size changes, shared card/animation resources, missing/disabled layouts; one instance's state must not unintentionally affect another. |
| Solitaire | Move/stack undo, draw undo, recycle undo, face restoration, and reset; restore card order and counts without stale references. |

Acceptance: each area has executable coverage or a clearly specified manual visual/input check. Existing examples retain their current behavior.

## 4. Multiplayer failure paths and measurements

- Extend the real multi-process harness beyond the current happy-path deal: rejection, late join, peer disconnect during a pending request, timeout recovery, and scene reload/reconnection.
- Assert unauthorized commands leave server state unchanged and permitted peers converge on container order and card state.
- Exercise duplicate card resources, hidden-to-visible transitions, stale revisions, and repeated snapshots. Verify concealed payloads omit private resource/data fields and rotate hidden IDs as intended.
- Run trusted P2P checks separately from server-authoritative checks; keep their distinct trust assumptions explicit.
- Measure serialized snapshot size, snapshot build/apply time, and client node churn for representative 52-card and 104-card boards with 2 and 6 players. Record environment and results; use GUI runs for rendering/animation costs.
- Keep full snapshots unless measurements show a practical problem. Do not introduce delta replication as part of routine cleanup.

Acceptance: failures resolve within configured bounds, rejected operations do not mutate authoritative state, resynchronization converges, and multiplayer costs/limitations are recorded with reproducible measurements.

## 5. Focused internal cleanup — after coverage

- Extract editor-preview responsibilities from `Card`/`CardContainer` where doing so reduces runtime/editor coupling.
- Compare the two network managers for identical registry, serialization, and snapshot plumbing. Share only behavior with equivalent semantics; retain transport/trust-specific validation separately.
- Keep existing class names, resource paths, exported properties, signals, public method signatures, and return/await behavior.
- Avoid changing scripts attached to existing scenes/resources merely to shorten files. Defer any extraction whose compatibility cost outweighs the benefit.

Acceptance: all checks remain green, existing scenes/resources load unchanged, and each extraction has a concrete responsibility boundary. No file-length target or broad rewrite.

## 6. Packaging, documentation, and release verification

- Install only `addons/simple_cards` into a fresh project. Enable the plugin, create a custom resource/layout, spawn cards, and move them between containers.
- Verify autoload setup/removal, layout discovery, generated layout IDs, and layout-cache refresh after rename/deletion without depending on repository examples.
- Export and launch a small standalone sample using custom front/back layouts. Confirm dynamically loaded scenes/resources and the JSON layout cache are included; implement export handling or precise required configuration if the check exposes missing assets.
- Manually check Balatro, Solitaire, and 2-player/6-player Macau for dragging, stacking, flips, focus, resizing, and opponent-hand presentation.
- Document the validation command and manual checklist; update the changelog with confirmed fixes and retained limitations. Choose the release version according to the project's existing convention once scope is final.

Acceptance: fresh install and exported sample work, automated gates pass, the manual checklist is recorded, and documented behavior matches the shipped addon.

## Delivery order and scope control

Land reviewable changes in this order: runner/CI, diagnosed lifecycle fixes with regressions, core behavior tests and fixes, multiplayer resilience tests and fixes, justified internal extractions, packaging/docs.

Steps 1–3 are the foundation. Step 4 can expose additional release blockers; step 5 is optional if it puts stability at risk. Step 6 closes the release. A failed behavior test or compatibility check takes priority over additional cleanup.

Out of scope: new gameplay features, visual redesign, a new networking protocol, expanded prediction modes, and public API redesign. Publishing a release is a separate action from completing this stabilization work.

## Implementation results and release gates

- [x] Fresh-copy validation passes locally on Godot 4.5.1 and 4.5.2; a CI matrix and retained logs are configured.
- [x] Diagnosed animation teardown and freed-card callback failures are fixed and covered. Script-only engine retention has an independent reproduction and an exact documented exception.
- [x] Core behavior, shared card data, network timeout/disconnect/reconnect, and two-/six-player Macau have regression coverage.
- [x] Existing public names, signatures, scene/resource paths, and exported properties are preserved.
- [x] Fresh installation, editor plugin/cache lifecycle, exported resource packs, and native Linux debug export were exercised.
- [x] Rendered captures were inspected for Balatro, Solitaire, and two-/six-player Macau; automated focus/order/drop checks cover core interaction state.
- [x] Snapshot measurements and their limitations are documented.
- [x] README and unreleased changelog describe the implementation.
- [ ] Hosted CI passes after the changes are pushed.
- [ ] Complete the manual mouse/controller playthrough in [Validation](VALIDATION.md) before publishing.

The snapshot protocol remains unchanged. The measured cost of rebuilding concealed cards is a documented performance limitation; broader protocol optimization is a separate follow-up.
