# AliKit catalog authoring-quality sweep

The ongoing component work follows the [authoring-quality charter](authoring-quality-charter.md),
which keeps simplicity, composability, visible-output correctness, and evidence
standards explicit.

This first catalog sweep covered the 12 components registered at the time in
[`components.json`](../../components.json). The existing Dialog package was
subsequently added as a thirteenth catalog component; its reference experiment
is tracked in the [authoring-reliability benchmark](authoring-reliability/reference-benchmark.md).
Scroll Area was already implemented and documented but was missing from the
machine-readable registry and website component list; it has now been added as
the fourteenth catalog component. The table and original 81-test count below
are a record of that earlier sweep, not the result of the new reference work.

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
- At the original sweep, the AliKit matrix was **110/110 passed**. After the public type alias and snapshot
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

### Current component-suite retest (2026-11-25)

All 14 catalog component packages, four supporting packages, and the Selection
Styles example passed a fresh headless retest: **117/117 tests across 19 test
targets**. The per-package counts were Command Palette
9, Tree View 7, Icon Picker 14, Palette Parts 7, Radio Group 8, Progress 9,
Segmented Control 5, Notices 3, Sidebar 8, Table 3, Menu 6, Data Grid 7,
Dialog 6, Scroll Area 5, Palette Model 4, Tree Model 8, Theme Contract 2,
Selection 5, and Selection Styles 1.

Each of the 14 UI component suites now includes a TestUI assertion that checks
representative text is shaped and visible within its retained element bounds.
This verifies headless text output and layout bounds; it does not replace native
pixel captures or DPI validation.

### External-consumer compile check on macOS (2026-11-25)

The PowerShell external-consumer harness could not run on this host because
`pwsh` is unavailable. I reproduced its two build paths manually against the
same pinned dependencies: the collection-import fixture built with the
`alicorn` and `alikit` collections, and the copied Radio Group fixture built
from the `components.json` copy recipe with no `alikit` collection. Both builds
passed on macOS arm64 with Odin `dev-2026-11:9a6991685`, Alicorn
`4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`, and AccessKit binding
`e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`.

A read-only manifest audit checked all 19 component/supporting-package entries:
declared sources, tests, examples, copy sources, package directories, package
imports, and copy rewrites. It found zero errors and zero warnings. These are
compile and registry-contract results only. SDL native smoke runs and pixel
captures were not performed because the shell has no usable display; the
PowerShell orchestration and website build remain unverified on this host.

The run used Odin `dev-2026-11:9a6991685`, Alicorn
`4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`, AccessKit binding
`e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`, one test thread, and seed `1729`.
Each package was invoked with `odin test <package>`, the pinned `alicorn`,
`alikit`, `accesskit`, and `accesskit_c` collections, and those two test
defines. This retest establishes headless suite status only; it does not rerun
the native example build matrix, external-consumer build, website build, or
native pixel/DPI captures.

### Current component-suite retest (2026-11-26)

After the reference-window and Dialog root-sizing corrections, all 20 current
test targets were rerun at seed `1729`: **130/130 tests passed**. This includes
14 catalog component packages (109 tests), four supporting packages (19), and
the Data Grid reference and Selection Styles example suites (one each). The
matrix used Odin `dev-2026-11:9a6991685`, Alicorn
`4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`, and AccessKit binding
`e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`, with one test thread. It includes
the Command Palette and Dialog 1×, 1.25×, 1.5×, and 2× TestUI presentation-scale
matrices, the Data Grid scrollbar-transition identity regression and
full-reference layout check, and all Dialog interaction tests.

The PowerShell validation wrapper was unavailable on this macOS host, so the
20 Odin test targets were invoked directly with the same pinned collections,
`ODIN_TEST_THREADS=1`, and `ODIN_TEST_RANDOM_SEED=1729`. This is headless
evidence; it does not replace native pixel comparison, physical-DPI testing, or
OS-level accessibility checks.

The remaining 11 catalog components now also have TestUI presentation-scale
matrices at 1×, 1.25×, 1.5×, and 2×, with assertions for visible text and
component/viewport containment. Those 11 package suites pass **85/85 tests** at
the locked Alicorn and AccessKit revisions. The new checks exposed three
undersized semantic owners: Sidebar's rail collection, the static Table root,
and Menu's popup row owner. Their layout declarations now fill or measure their
intended content, and the corresponding scale checks pass. These are logical
layout checks under TestUI; they do not establish physical DPI behavior or
native pixel fidelity.

### Catalog reference previews (2026-11-26)

The catalog now has one authored SVG target on each of its 14 component pages.
Nine missing targets were added for Menu, Notices, Palette Parts, Progress,
Radio Group, Segmented Control, Sidebar, Table, and Tree View. The existing
five targets remain for Command Palette, Data Grid, Dialog, Icon Picker, and
Scroll Area. `website/scripts/sync-manifest.mjs` stages all 14 source SVGs
from this research directory into the site's ignored `public` output before
development or build. The illustrations use distinct real application
contexts, and the site labels each as an authored target rather than a capture.
They help authors reason about intended composition; they are not evidence of
native output fidelity or physical-DPI rendering.

## Limits and known constraints

Headless tests establish layout bounds, shaped text/resources where tested,
paint commands, semantic state, identity, and interaction behavior. Live
macOS reviews have also inspected the Command Palette, Data Grid, and corrected
Dialog reference app; the Dialog alert was opened and dismissed, and its
accessible title, description, and action were exposed. These are qualitative
single-environment checks, not archived screenshot comparisons or a physical
scale matrix. Native pixel equivalence, fractional-DPI rendering, GPU clipping,
screen-reader behavior, and Windows interaction checks remain outstanding.

The guides retain known constraints rather than hiding them: Palette Parts
groups require a complete realized result slice; Segmented uses equal-width
segments and translates its indicator without width animation; Menu groups
are ad-hoc nested semantics and submenus remain application-composed; Table
and Data Grid do not support spans; Scroll Area's fit-content limitations are
recorded in its separate guide. None of these were presented as validated
native visual behavior.
