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
parent change. It also verifies that the grid's stable root remains the
keyboard focus owner as the scrollbar disappears and returns. The regression
also hovers the sortable Name header before the transition, checks that its
hover state remains on the same owner, and clicks it after the gutter disappears
and returns; both clicks still propose the stable Name column key. The first
follow-up run passed the Data Grid suite at 7/7 and shared Table suite at 3/3;
current main passes the expanded suites at 8/8 and 6/6. The original six
recreation passes remain unchanged; this is a post-benchmark correctness
follow-up.

## Scrollbar negative control

For a verification-only negative control, the gutter passed to the header was
temporarily forced to zero while the body still scrolled. The 200-row geometry
test failed with the expected `12.00 px` Name-track mismatch at 1280, 960, and
760 px. The source was restored to use Alicorn's `SCROLLBAR_THICKNESS` constant,
and the final tests pass. The temporary change is not present in the working
tree.

## Follow-up: retained-description scaling

The 200-row reference did not test the performance and working-set cost of
publishing virtual row semantics for large datasets. The
[`benchmarks/data_grid/main.odin`](../../../../benchmarks/data_grid/main.odin)
probe describes a fixed 1280 × 800 viewport with 12 visible rows, performs
three warmup descriptions, and measures 101 repeated descriptions per process.
It validates every logical row through the public semantic lookup API before
timing. Each result below is the median of three fresh process launches; the
p95/p99 values are the median of the three per-process percentiles.

| Logical rows | Virtual row semantics | Description p50 / p95 / p99 | Reconcile p50 | Semantic sync p50 | Peak process RSS |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 200 | 187 | 0.118 / 0.128 / 0.148 ms | 0.063 ms | 0.019 ms | 13.9 MB |
| 10,000 | 9,987 | 1.259 / 1.696 / 2.395 ms | 0.202 ms | 0.154 ms | 28.9 MB |
| 100,000 | 99,987 | 30.277 / 32.955 / 35.714 ms | 4.371 ms | 4.304 ms | 273.0 MB |

Every launch emitted 44 non-row semantic descriptions in addition to the row
descriptions. At 100,000 rows, the final timed turn examined zero measure and
layout nodes and reported zero semantic structure changes. Reconcile p50 was
4.371 ms, of which Semantic_Sync was 4.304 ms. The 30.277 ms Description
stage includes the application callback and other turn work; this probe does
not isolate callback time. The component's all-rows loop is the unbounded path
visible in source.

Peak RSS is the whole child process, including the application-owned row and
cell arrays, the runtime's retained semantic entities, and TestUI. It is not a
runtime-only memory measurement. Timings are CPU-only retained-pipeline
measurements: they exclude native renderer preparation, GPU submission,
presentation, and physical accessibility clients. The
[raw comparison capture](data-grid-performance-comparison-raw.json) contains
all 18 process summaries and the sorted 101-sample Description and Semantic
Sync distributions for each launch.

### Settled-idle follow-up

The release runner now probes settled idle before its repeated-description
samples. For each data size it advances TestUI 101 times by 16 ms and requires
zero emitted or reused descriptions, retained stage work, GPU submissions,
runtime invalidation, and scheduled frame demand. All three cases passed. The
same single release run measured the following full-description distribution;
these are one-process results and should not be compared directly with the
three-launch medians above.

| Logical rows | Description p50 / p95 / p99 |
| ---: | ---: |
| 200 | 0.194 / 0.207 / 0.234 ms |
| 10,000 | 2.641 / 3.212 / 3.400 ms |
| 100,000 | 38.390 / 46.319 / 65.344 ms |

The raw 101-sample Description and Semantic Sync distributions, runtime stage
percentiles, and idle assertions are in the [single-run capture](data-grid-idle-probe-raw.json).
The idle probe establishes zero retained work and frame demand under TestUI; it
does not measure native host wakeups, GPU or display submissions, energy, or
idle wall-clock CPU cost.

## Matched before/after comparison

This comparison checks whether the Data Grid layout corrections changed the
warm repeated-description cost. The baseline is AliKit `fded57a94e6a`, before
the authoring-quality reference work; the candidate source state is
`ec080d423e88`. The relevant implementation delta is the identity-transparent
scrollbar-gutter header slot and explicit semantic owner height in `data_grid`
and `table_core`. The exact same current benchmark source was copied into the
historical checkout and built against both revisions.

To isolate AliKit's contribution, both snapshots used the same current
Alicorn `4e0862f368cb` and AccessKit binding `e290e5f55da9`, Odin
`dev-2026-11:9a6991685`, and release optimization. This intentionally overrides
the historical snapshot's dependency lock; it does not compare each revision
with its original dependency stack. Three fresh processes were run per source
revision and row count, alternating order. Each process used the same 1280 ×
800 viewport, 12 visible rows, data, three warmups, and 101 timed descriptions.
The raw per-launch data is linked above.

| Logical rows | Baseline Description p50 / p95 / p99 | Candidate Description p50 / p95 / p99 | Reconcile p50, baseline / candidate | Semantic sync p50, baseline / candidate | Peak process RSS, baseline / candidate |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 200 | 0.111 / 0.115 / 0.122 ms | 0.118 / 0.128 / 0.148 ms | 0.064 / 0.063 ms | 0.020 / 0.019 ms | 13.8 / 13.9 MB |
| 10,000 | 1.250 / 1.591 / 2.124 ms | 1.259 / 1.696 / 2.395 ms | 0.191 / 0.202 ms | 0.146 / 0.154 ms | 28.8 / 28.9 MB |
| 100,000 | 30.352 / 33.885 / 38.704 ms | 30.277 / 32.955 / 35.714 ms | 4.108 / 4.371 ms | 4.038 / 4.304 ms | 270.4 / 273.0 MB |

The total Description p50 is effectively flat at 10,000 and 100,000 rows;
the 200-row difference is 7 μs. At 10,000 and 100,000 rows, candidate
Semantic_Sync p50 is about 5–7% higher (roughly 8 μs and 266 μs), while the
whole-turn p50 changes by about 9 μs and -75 μs, respectively. Peak process
RSS differs by about 0.1–2.6 MB across these conditions. These results do not
show a material full-turn regression, but they also do not demonstrate a
performance improvement. Three launches per condition on one machine limit
confidence in tail differences; treat this as a local non-regression check,
not a general performance claim.

All conditions published the same logical and virtual row counts and emitted
the same number of semantic descriptions. This is a repeated full-root
description workload, not an isolated style change, input-latency test, native
renderer/GPU benchmark, or comparison of all three reference applications.
The separate settled-idle probe above is a work-demand gate, not an idle CPU
timing comparison. The raw artifact records individual process percentiles and
distributions.

### Reproduction

Environment: macOS 27.2.1 arm64; Odin `dev-2026-11:9a6991685`; baseline AliKit
`fded57a94e6a2c5bf44d8b980befe5a260ff5ed5`; candidate AliKit
`ec080d423e885aee569da12305e40eefb70a631a`; Alicorn
`4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`; AccessKit binding
`e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`; release (`-o:speed`) builds.
The current benchmark source was copied into the baseline snapshot before
building it. Both builds used the same `-collection:alicorn`,
`-collection:accesskit`, and `-collection:accesskit_c` paths; only
`-collection:alikit` differed.

```sh
mkdir -p /private/tmp/alikit-fded57a
git archive fded57a94e6a2c5bf44d8b980befe5a260ff5ed5 | tar -x -C /private/tmp/alikit-fded57a
mkdir -p /private/tmp/alikit-fded57a/benchmarks/data_grid
cp benchmarks/data_grid/main.odin /private/tmp/alikit-fded57a/benchmarks/data_grid/main.odin

cd /private/tmp/alikit-fded57a
odin build benchmarks/data_grid -o:speed \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=/private/tmp/alikit-fded57a \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -out:/private/tmp/alikit-data-grid-scaling-fded57a

cd /private/tmp/alicorn-kit-authoring-quality
odin build benchmarks/data_grid -o:speed \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=. \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -out:/private/tmp/alikit-data-grid-scaling-current

python3 -c '
import resource, subprocess, sys
p = subprocess.run([sys.argv[1], sys.argv[2]], text=True, capture_output=True)
sys.stdout.write(p.stdout)
sys.stderr.write(p.stderr)
print("child_maxrss_bytes", resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)
sys.exit(p.returncode)
' /private/tmp/alikit-data-grid-scaling-current 100000
```

Run each binary three times for `200`, `10000`, and `100000` rows, alternating
baseline/candidate order as in the raw capture. Repeat the final command with
the baseline binary and each row count. Capture each binary invocation in its
own Python process when collecting RSS so `RUSAGE_CHILDREN.ru_maxrss`
measures only that benchmark process; macOS reports the value in bytes. The
benchmark accepts any row count at least as large as the visible-row count, or
runs the three reference sizes when invoked without an argument. Each
invocation prints sorted Description and Semantic_Sync sample distributions
plus p50/p95/p99 for runtime stages. The JSON capture retains these sorted
arrays and the per-process RSS values; sample order is not retained.

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

At the initial local capture, the Data Grid suite finished with 7/7 tests
passing; the shared Table suite finished with 3/3; and the full-reference
layout suite finished with 1/1. At current main `1ecd945`, the Windows CI run
passes Data Grid 8/8, Table 6/6, and full-reference layout 2/2 as part of
138/138 tests across 21 test targets. The same workflow's native example build
matrix completed successfully. Odin emitted unrelated
large-stack test warnings from Alicorn and the macOS linker warned about
duplicate `-lobjc` libraries. SDL cannot initialize a display in this shell
session, so native pixels and physical DPI remain unverified.
