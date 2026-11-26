# Data Grid reference result

This implementation recreates the 1280 × 800 Northstar project-grid target as
a runnable SDL_GPU example, with the benchmark's required 200 application-owned
rows. The vector reference is not a desktop capture.

| Measure | Result |
| --- | --- |
| Attempts to pass geometry/behavior checks | 11 total: the original six passes plus five full-reference follow-up passes. The follow-up added viewport/DPI assertions and corrected empty scope handling, panel sizing, and Table-owner bounds. |
| Imports used; runtime import and reason | `alicorn:ui`, `alikit:data_grid`, `core:fmt`, `core:mem`, `core:os`, `core:strings`, and `base:runtime`; no `alicorn:runtime` import. The render callback reads viewport dimensions from its public `ui.UI` context to adapt the row count, content width, and column widths. |
| Hardcoded dimensions | 200 rows; 54 px top bar; 72 px navigation rail; 38 px content inset; 110 px trailing margin; 24 px title inset; 56 px heading; 19 px vertical gap; 320 px filter; 116/132 px action buttons; 48 px rows; 42 px header; 10 px cell padding; 34/36 px rail icons. The card width is `clamp(viewport.w - 220, 320, 1060)` and its height is `max(viewport.h - 234, 320)`. At 1280 px, the three trailing tracks are 200/200/198 px; below 1100 px they are 150/150/112 px so the flexible Name track remains usable. |
| Layout workarounds | No clipped or overlapping tracks. `table_core` keeps the header surface full width and places the fixed gutter inside it, shrinking only the header track grid when the virtual list can scroll. Empty spacers are closed layout scopes; the panel width follows the responsive content width. The Data Grid sizes its Table owner from the header and virtual-list viewport so semantic bounds contain realized rows. |
| 1280 × 800, 960 × 720, 760 × 640 | Headless checks pass at all three viewports for a 200-row grid, including first-row visibility, Table-owner containment, toolbar separation, and viewport containment. |
| 1×, 1.25×, 1.5×, 2× DPI | The full-reference checks pass at all four scales for each viewport (12 size/scale combinations). These are logical presentation checks, not native display DPI captures. |
| Visual match to SVG target | Unverified: this environment did not provide a native display capture for side-by-side pixel review. |
| Existing behavior and accessibility | Data Grid package tests pass: stable row/column identities, table semantics, disabled-row navigation, selected/current publication, sorting proposals, keyboard activation, 200-row virtualization, Page Down reveal, and header identity across scrollbar transitions. The example keeps sorting, filtering, and accepted selection application-owned. |
| Large-dataset total work | Visual cells are viewport/overscan bounded, but `data_grid()` publishes one virtual `Table_Row` semantic item per offscreen row. The retained-description scaling probe below measures the resulting CPU and whole-process peak RSS at 200, 10,000, and 100,000 rows. |

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

## Follow-up: full reference layout and semantic bounds

The earlier component suite tested the grid body in a constrained panel but did
not exercise the full reference application's root composition. A new TestUI
check over 1280 × 800, 960 × 720, and 760 × 640 at 1×, 1.25×, 1.5×, and 2×
found three concrete defects:

7. The outer window column used fit-content height, so the workspace did not
   receive the remaining viewport height. Setting the root to grow fixed the
   vertical allocation; the test still found a zero-width grid.
8. Empty spacer columns were called as though they were leaf nodes, leaving
   their layout scopes open around later controls. Expressing them as empty
   scoped `if ui.column(...) {}` blocks corrected the sibling hierarchy; the
   panel still measured to 1 px wide.
9. The reference panel's `width=-1` resolved to its 1 px intrinsic width in this
   composition. Giving it the existing responsive content-width calculation
   made the grid and its rows visible; the new containment assertion then
   exposed that the semantic Table owner was only 24 px high.
10. A temporary growing wrapper did not correct the Table-owner height and was
    removed to avoid adding an unneeded layer.
11. The Data Grid now sizes its focus/semantic owner from the configured header
    and virtual-list viewport. The visible row is inside both the scroll
    viewport and the Table bounds, and the full 12-case viewport/scale matrix
    passes.

This is five additional implementation/verification passes beyond the initial
six reference passes. The issue showed why package-level grid tests alone did
not validate the complete application composition.

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

## Follow-up: retained-description scaling

The earlier 200-row reference did not test the performance and working-set
cost of publishing virtual row semantics for large datasets. The new
[`benchmarks/data_grid/main.odin`](../../../../benchmarks/data_grid/main.odin) probe
isolates repeated root descriptions at a fixed 1280 × 800 viewport with 12
visible rows. It warms the retained tree three times, takes 101 samples, and
measures the full TestUI turn plus Alicorn's `Semantic_Sync` stage. It also
checks the public semantic-node lookup API to confirm that every logical row
was published and that offscreen rows were marked virtual. The lookup is done
outside the timed samples.

| Logical rows | Virtual row semantics | Description p50 / p95 / p99 | Reconcile p50 | Semantic sync p50 | Peak process RSS |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 200 | 187 | 0.137 / 0.220 / 0.229 ms | 0.073 ms | 0.023 ms | 13.7 MB |
| 10,000 | 9,987 | 1.705 / 2.854 / 3.602 ms | 0.282 ms | 0.219 ms | 28.9 MB |
| 100,000 | 99,987 | 32.653 / 38.583 / 40.490 ms | 5.000 ms | 4.920 ms | 260.8 MB |

All three cases emitted 44 non-row semantic descriptions in addition to the
row descriptions. At 100,000 rows, the runtime's Reconcile stage took 5.000 ms
p50, of which Semantic_Sync took 4.920 ms. The 32.653 ms Description stage
also includes the application callback and other turn work; this probe does
not isolate callback time. The component's all-rows loop is the unbounded path
visible in source. Warm samples examined zero layout nodes, zero measure
nodes, shaped no text, and made zero semantic structure changes, so layout and
shaping do not explain the growth. A tenfold row increase from 10,000 to
100,000 increased description p50 about 19.2-fold and peak process RSS about
9.0-fold in this run.

Peak RSS is the whole child process, including the application-owned row and
cell arrays, the runtime's retained semantic entities, and TestUI. It is not a
runtime-only memory measurement. Timings are CPU-only retained-pipeline
measurements: they exclude native renderer preparation, GPU submission,
presentation, and physical accessibility clients. The p95/p99 figures come
from 101 samples on one machine and are useful as a local scaling probe, not a
cross-machine performance claim.

### Reproduction

Environment: macOS 27.2.1 arm64; Odin `dev-2026-11:9a6991685`; AliKit
`d705cd6217517360a22750d82a89adec9c7feca2` (benchmark working tree); Alicorn
`4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`; release (`-o:speed`) build.

```sh
odin build benchmarks/data_grid -o:speed \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=. \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -out:/private/tmp/alikit-data-grid-scaling-speed

python3 -c '
import resource, subprocess, sys
p = subprocess.run(["/private/tmp/alikit-data-grid-scaling-speed", "100000"], text=True, capture_output=True)
sys.stdout.write(p.stdout)
sys.stderr.write(p.stderr)
print("child_maxrss_bytes", resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)
sys.exit(p.returncode)
'
```

Run the second command with `200` and `10000` as separate invocations to
measure each child process independently. On macOS, `ru_maxrss` is reported in
bytes; the table rounds it to decimal MB. The benchmark itself accepts any
row count at least as large as the visible-row count, or runs the three
reference sizes when invoked without an argument. Each invocation prints the
raw Description and Semantic_Sync samples and p50/p95/p99 for all runtime
stages.

This establishes a real scalability limit in the current semantic publication
contract. Do not remove the offscreen row semantics as an AliKit-only fix:
they let assistive technology address virtualized rows. A future optimization
needs a runtime-level way to retain or page collection semantics without
re-describing and retaining one row entity per logical item. Native screen
reader behavior and GPU presentation remain separate validation work.

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

odin test examples/data_grid \
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
finished with 3/3 passing; the full-reference layout suite finished with 1/1
passing. The example build exited successfully. Odin emitted unrelated
large-stack test warnings from Alicorn and the macOS linker warned about
duplicate `-lobjc` libraries. SDL cannot initialize a display in this shell
session, so native pixels and physical DPI remain unverified.
