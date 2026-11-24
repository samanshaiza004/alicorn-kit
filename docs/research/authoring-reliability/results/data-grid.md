# Data Grid reference result

This implementation recreates the 1280 × 800 Northstar project-grid target as
a runnable SDL_GPU example, with the benchmark's required 200 application-owned
rows. The vector reference is not a desktop capture.

| Measure | Result |
| --- | --- |
| Attempts to pass geometry/behavior checks | 6 implementation/verification passes; final headless geometry and behavior checks pass. The shared-track assertions were added after the first run exposed a 12 px mismatch. |
| Imports used; runtime import and reason | `alicorn:ui`, `alikit:data_grid`, `core:fmt`, `core:mem`, `core:os`, `core:strings`, and `base:runtime`; no `alicorn:runtime` import. The render callback reads viewport dimensions from its public `ui.UI` context to adapt the row count, content width, and column widths. |
| Hardcoded dimensions | 200 rows; 54 px top bar; 72 px navigation rail; 38 px content inset; 110 px trailing margin; 24 px title inset; 56 px heading; 19 px vertical gap; 320 px filter; 116/132 px action buttons; 48 px rows; 42 px header; 10 px cell padding; 34/36 px rail icons. The card width is `clamp(viewport.w - 220, 320, 1060)` and its height is `max(viewport.h - 234, 320)`. At 1280 px, the three trailing tracks are 200/200/198 px; below 1100 px they are 150/150/112 px so the flexible Name track remains usable. |
| Layout workarounds | No clipped or overlapping tracks. `table_core` keeps the header surface full width and places the fixed gutter inside it, shrinking only the header track grid when the virtual list can scroll. The gutter comes from Alicorn's `SCROLLBAR_THICKNESS`; this is not an application spacer workaround. |
| 1280 × 800, 960 × 720, 760 × 640 | Headless checks pass at all three viewports for a 200-row grid. The test checks header/body edges, first-row containment in the scroll viewport, and visible cell text. |
| 1×, 1.25×, 1.5×, 2× DPI | TestUI scale checks pass at all four scales. These are logical presentation checks, not native display DPI captures. |
| Visual match to SVG target | Unverified: this environment did not provide a native display capture for side-by-side pixel review. |
| Existing behavior and accessibility | Data Grid package tests pass: stable row/column identities, table semantics, disabled-row navigation, selected/current publication, sorting proposals, keyboard activation, 200-row virtualization, Page Down reveal, and header identity across scrollbar transitions. The example keeps sorting, filtering, and accepted selection application-owned. |

## Attempt log

1. The initial reference scene built, but its geometry test found a 12 px
   difference: the header Name track was 1,072 px while the body track was
   1,060 px. The first containment assertion also treated the Table semantic
   bounds as if they described the whole grid.
2. The shared `table_core` header slot and conditional scrollbar gutter were
   added. The first revised check still failed because the semantic Table owner
   does not identify the virtual-list viewport.
3. The geometry test was changed to use the public scroll-node snapshot for
   clipped viewport bounds. A review caught that the header decoration should
   remain full width, so the gutter slot moved inside the surface and only the
   track grid shrinks. The final targeted suite passed at all required widths
   and scales. A short three-row fixture verifies that a non-scrolling list
   reserves no gutter.
4. The example layout was adjusted to follow the SVG's top bar, rail, heading,
   search toolbar, and centered-width data panel. Compilation found that the
   UI icon API accepts `color_role`, not `color`.
5. The icon call was corrected and the example compiled. A final contract
   review then clarified that the gutter belongs inside the header surface so
   the surface background remains continuous.
6. The gutter slot moved inside the surface; the geometry check now verifies
   both its full-width background extent and the shared column track. The final
   Data Grid and shared Table package suites pass, as does the example build.

## Follow-up: scrollbar transition identity

A transition regression extended the reference check from separate short and
long fixtures to one retained grid moving from nine rows (scrollbar present) to
eight rows (no scrollbar) and back. Before the fix, the transition away from
the scrollbar changed the retained IDs of the header track grid, sortable Name
cell, and Name label, even though their semantic IDs stayed stable.

The conditional header slot now uses Alicorn's identity-transparent container.
It remains a layout parent for the track grid, while its appearance no longer
changes descendant identity. The regression checks the header surface, track
grid, sortable cell, and label IDs in both directions, as well as the slot's
parent change. It passes with the Data Grid suite at 7/7; the shared Table suite
passes at 3/3. The original six recreation passes remain unchanged; this is a
post-benchmark correctness follow-up.

## Scrollbar negative control

For a verification-only negative control, the gutter passed to the header was
temporarily forced to zero while the body still scrolled. The 200-row geometry
test failed with the expected `12.00 px` Name-track mismatch at 1280, 960, and
760 px. The source was restored to use Alicorn's `SCROLLBAR_THICKNESS` constant,
and the final tests pass. The temporary change is not present in the working
tree.

## Commands

All commands ran from the AliKit repository root, using the local Alicorn
checkout at the pinned revision and the pinned AccessKit collection:

```sh
odin test data_grid \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=. \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -define:ODIN_TEST_THREADS=1

odin test table \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=. \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -define:ODIN_TEST_THREADS=1

odin build examples/data_grid \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=. \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -out:/private/tmp/alikit-data-grid-reference
```

The Data Grid suite finished with 7/7 tests passing; the shared Table suite
finished with 3/3 passing. The example build exited
successfully; Odin emitted unrelated large-stack test warnings from Alicorn
and the macOS linker warned about duplicate `-lobjc` libraries. No native
window capture or physical DPI validation was available.
