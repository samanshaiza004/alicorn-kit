# AliKit catalog authoring-quality sweep

This first catalog sweep covered the 12 components registered at the time in
[`components.json`](../../components.json). The existing Dialog package was
subsequently added as a thirteenth catalog component; its reference experiment
is tracked in the [authoring-reliability benchmark](authoring-reliability/reference-benchmark.md).
The table and original 81-test count below are a record of that earlier sweep,
not the result of the new three-component benchmark.

For each package, it checks public inputs and outputs, imports, state ownership,
layout sizing, visual parts, keyboard and pointer behavior, semantics,
accessibility claims, its runnable example, and its component guide. The
command palette remains the reference example for a complete application
consumer.

## Catalog coverage

| Component | Checks emphasized | Headless component tests |
| --- | --- | ---: |
| Command Palette | Controlled query and lifecycle; stable action IDs; modal/result-list parts; focus restoration; public `Item`, `Item_ID`, and `Match` types. | 8 |
| Tree View | Stable tree identity; visible preorder projection; expansion and keyboard traversal; virtual row window. | 6 |
| Icon Picker | Query ownership; virtual grid/list; stable choices; focus and activation parity; custom part scope. | 14 |
| Palette Parts | Borrowed item/match slices; stable-ID selection; virtual rows; group constraints; public input type aliases. | 7 |
| Radio Group | One Tab stop; selected versus roving focus; disabled skipping; custom card rendering; input parity. | 8 |
| Progress | Range and value semantics; linear/ring parts; determinate and indeterminate presentation; caller-owned motion. | 9 |
| Segmented Control | Selected versus active state; equal-width indicator geometry; selection modes; reduced-motion behavior. | 5 |
| Notices | Runtime toast ownership versus inline cards; expiry/action paths; Status/Alert semantics; retire lifecycle. | 3 |
| Sidebar | Expanded/collapsed rail; stable route identity; focus/selection; replaceable row visuals. | 8 |
| Table | Column sizing; wrapped/intrinsic rows; table semantics; optional fixed-row virtualization. | 3 |
| Menu | Trigger and overlay lifecycle; keyboard dismissal/navigation; checked/disabled rows; focus restoration. | 6 |
| Data Grid | Stable row/column identity; virtualized semantics; roving cell focus; application-owned sorting and selection. | 4 |

The 81 tests above are the catalog-package suites. The broader AliKit run
covered 110 tests across the catalog, supporting behavior/model packages,
dialog and scroll-area packages, and the selection-style example.

## Improvements recorded

- Ordinary example layout, keys, and common style helpers use
  `alicorn:ui`. `ui.Runtime`, `ui.Application_Key`, and the key constructors
  are sufficient for normal `ui.run` callbacks. Runtime imports remain in
  examples that use custom retained geometry, theme registration, specialized
  semantics, or other runtime-only integration.
- Command Palette now re-exports `Match` alongside `Item` and `Item_ID` for
  callers composing its result parts. Palette Parts already re-exported
  `Item`, `Item_ID`, and `Match`; its docs and examples now use those types and
  import `palette_model` only for independent filtering/selection helpers.
- Alicorn's UI facade exposes `surface_end` and
  `interaction_scope_current`, so parts examples can close a surface and
  attach a scope to the current layout owner without reaching into runtime
  stack internals.
- [`../layout-cookbook.md`](../layout-cookbook.md) records fill, fit-content,
  fixed and grow sizing, icon/label alignment, panels, virtual lists, common
  import choices, and the public composition helpers.
- The catalog pages link to runnable Odin examples instead of embedding
  desktop application screenshots. Screenshot files and capture metadata were
  removed from the published catalog. The capture script remains available
  for local visual validation and writes outside the documentation by default.
- Radio Group and Segmented tests now release replaced semantic snapshots;
  Icon Picker parts tests release their state-owned match buffers on both
  success and failure paths. The focused suites finish without those
  allocation warnings.

## Validation

- Alicorn `ui` tests: **63/63 passed** at the pinned revision.
- AliKit matrix: **110/110 passed**. After the public type alias and snapshot
  cleanup changes, Command Palette **8/8**, Radio Group **8/8**, and Segmented
  Control **5/5** were rerun successfully.
- Native example builds: **27/27 passed** during the sweep. The final affected
  builds for Command Palette, Palette Parts, Command Palette Parts, Progress
  Parts, Progress Composition, and Selection Styles also passed.
- Registry JSON parsed; registry sources, tests, examples, and published pages
  were checked for presence. Documentation snippets using `ui.*` and
  `alicorn.*` were checked for the matching imports. `git diff --check` passed.
- `npm run build` could not complete because the website checkout has no
  installed Astro executable (`astro: command not found`). Dependencies were
  not installed as part of this sweep.

## Limits and known constraints

Headless tests establish layout bounds, shaped text/resources where tested,
paint commands, semantic state, identity, and interaction behavior. They do
not establish native pixel equivalence, screen-reader behavior, OS input,
fractional-DPI rendering, or GPU output. This environment had no usable native
display for visual captures, so no DPI matrix is claimed. Windows and macOS
native interaction checks remain outstanding.

The guides retain known constraints rather than hiding them: Palette Parts
groups require a complete realized result slice; Segmented uses equal-width
segments and translates its indicator without width animation; Menu groups
are ad-hoc nested semantics and submenus remain application-composed; Table
and Data Grid do not support spans; Scroll Area's fit-content limitations are
recorded in its separate guide. None of these were presented as validated
native visual behavior.
