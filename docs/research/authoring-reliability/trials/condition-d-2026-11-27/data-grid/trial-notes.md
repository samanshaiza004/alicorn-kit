# Condition D: Data Grid trial 2

## Scope and start

- Archived trial directory: this directory. The original working directory was `/private/tmp/alikit-authoring-trials/2026-11-27/condition-d/data-grid-2/`.
- Exact start recorded before source review: **2026-11-27 00:51:31 UTC**.
- First successful app build was observed at **2026-11-27 01:02:25 UTC**.
- No AliKit source was edited. All authored files and build logs are in this trial directory.
- No native window was created or inspected.
- Manually reviewed only the task-listed AliKit Data Grid/layout sources and the listed TestUI README/source/check helpers. No `_test.odin` file, example, research report, other trial directory, or `third_party` checkout was manually opened. The Odin compiler did emit dependency diagnostics that name test-named source files; see the build notes below.

## Dependency revisions and package identity

- AliKit API/source pin: `5e8fe6224bd14c294fe002c5ef9bc302faa26645`.
- The pinned AliKit checkout had a docs-only delta at `2d477ba`. The coordinator later reported `47553c9` as a Dialog-only change; Data Grid and Table Core sources remain unchanged since `5e8fe62`.
- SHA-256 of the exact component sources used by the trial:
  - `data_grid/data_grid.odin`: `87cbca7787f8f5b3d379e735f0f65acb14ba35a8033e84c2145c78cb0bf72b61`
  - `table_core/table_core.odin`: `5d3f14ab75d7ab280df9f94556c55b034569ce20adbe75862166acb2508e562f`
- Alicorn/TestUI: `/private/tmp/alicorn-textfield-render`, commit `4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`.
- Odin: `/opt/homebrew/bin/odin`, `dev-2026-11:9a6991685`.
- Odin AccessKit binding: `/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit`, commit `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`.
- AccessKit C static library collection: `/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static`.

The app directly imports `alicorn:runtime`, `alicorn:ui`, and `alikit:data_grid`. The Data Grid package imports `alikit:table_core` for the shared public data shapes and tracks. The headless test imports `alicorn:testui`, `core:testing`, and the same Data Grid package. `alicorn:runtime` is used for the full application frame callback, focus setup, invalidation, and shared semantic request dispatch.

## Trial app and fixed layout

The fixture has 200 stable-key rows, four flexible columns, a selected first cell, one disabled row immediately after it, an app-owned sort callback, and an app-owned open-only filter projection. The app uses a full-window root/panel with `grow=1`, 14 px panel padding, an 8 px gap, a 32 px header, 30 px body rows, and an eight-row visual viewport. The selected cell and focus indicator are retained through the Data Grid component's caller-owned selection and focus state.

The TestUI matrix opened the full application at all 12 combinations of logical viewport and presentation scale:

| Logical viewport | Scales |
| --- | --- |
| 1280 × 800 | 1×, 1.25×, 1.5×, 2× |
| 960 × 720 | 1×, 1.25×, 1.5×, 2× |
| 760 × 640 | 1×, 1.25×, 1.5×, 2× |

Each combination checks viewport containment and positive grid bounds; unique header/body cells for all four columns; shared header/body track x/width within 0.5 logical px; body-cell containment; and retained shaped, visibly painted text for all headers and the first row. `testui.expect_visible_text` verifies shaped glyph runs, nontransparent glyphs, owner bounds, and paint clipping; it is not an app-state-only assertion.

The first 1280 × 800, 1× handle also checks the single focused grid Tab stop; accepted selected/current publication; disabled row state and Down navigation skipping that row; Return activation and app-owned selection; sort-header and filter-control callbacks; all 200 semantic row records; the bounded realized visual window versus virtual semantic rows; filter logical count; and reveal of stable key `101` (row label `Project 100`) while that row is offscreen.

## Build and test commands

The commands below were run from the original trial directory. `-file` is required for the root `main.odin` file. For a rerun from this archived directory, use its path as `TRIAL_DIR`; the dependency mappings match the pinned Alicorn/AccessKit graph.

```sh
TRIAL_DIR="$(pwd)"
TRIAL_OUTPUT_DIR="${TMPDIR:-/tmp}/alikit-condition-d-data-grid"
mkdir -p "$TRIAL_OUTPUT_DIR"
/opt/homebrew/bin/odin build main.odin -file \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=/private/tmp/alicorn-kit-authoring-quality \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -collection:trial="$TRIAL_DIR" \
  -out:"$TRIAL_OUTPUT_DIR/data-grid-app"
```

The final build command exited 0. Running the resulting app also exited 0; it constructs one retained Alicorn frame and exits without opening a window.

```sh
/opt/homebrew/bin/odin test tests \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=/private/tmp/alicorn-kit-authoring-quality \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -collection:trial="$TRIAL_DIR" \
  -out:"$TRIAL_OUTPUT_DIR/data-grid-tests"
```

Final result: **1 TestUI test passed, 535 assertions**, 362.245 ms reported test time. The count is 300 layout/text assertions (25 for each of the 12 size/scale combinations) plus 235 semantic, virtualization, interaction, and reveal assertions. The final run had no allocator leak report. Build and test logs were kept in the temporary trial workspace and are not part of the archive.

## Failures, fixes, and warnings

1. The first build attempt passed `main.odin` without `-file`. Odin rejected it because `odin build` expects a package/directory by default. Adding `-file` fixed the command form.
2. The next build could not resolve the `accesskit` foreign collection. Adding the pinned `-collection:accesskit=.../.deps/odin-accesskit` mapping exposed the next missing collection, `accesskit_c`.
3. Adding the pinned `-collection:accesskit_c=.../lib/macos/arm64/static` mapping produced the first successful app build at 01:02:25 UTC.
4. The first TestUI run passed with 532 assertions but reported 206.25 KiB of allocator-tracked leaks. The trial generated 800 row-label strings per app through formatted allocation and eagerly formatted several assertion messages. The fix stores row labels in fixed buffers owned by the app fixture and formats diagnostic strings only on failed assertions. The final run passed with 535 assertions and no allocator leak report.

The compiler emitted existing large-stack-local warnings from Alicorn dependency source named `secondary_window_host_test.odin` and `diagnostics_test.odin` (including a 303,216-byte native window local and a 524,288-byte quad array). Those files were not opened or used as trial tests. The final app build and TestUI command both exit 0.

## Workarounds and limits

- The test uses TestUI's full `build_application` callback so focus, frame lifecycle, app callbacks, Data Grid composition, and layout run through the same application builder.
- TestUI does not provide a direct input field for a host `.Reveal` request. The test constructs the public `Semantic_Request_Event{kind=.Reveal}` for stable row ID `101`, calls `data_grid.handle_semantic_reveal_request`, then advances a normal TestUI turn to verify realization. The trial app also drains the shared semantic request queue and routes Reveal requests by its current projection.
- The filter control is a button that switches the app-owned projection to open rows. Sort and filter are fixture callbacks over caller-owned state, consistent with the component's boundary; they are not built-in Data Grid behavior.
- TestUI provides finalized logical geometry and retained shaped-text/paint checks, but no GPU pixels, rasterization, native DPI, OS focus behavior, platform accessibility bridge, physical screen-reader session, or native input verification. The scale matrix changes TestUI's presentation scale only.
- The 200-row virtualization check establishes a bounded visual window and complete logical row publication for this fixture. It makes no CPU or memory claim for much larger data sets.
- This is one fresh trial, with no baseline comparison; it does not establish that the layout cookbook improved authoring quality.
