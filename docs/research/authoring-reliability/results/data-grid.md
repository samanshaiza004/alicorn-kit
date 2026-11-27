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

### Semantic virtualization boundary

The current API cannot safely skip unchanged offscreen rows from the AliKit
loop. In the locked Alicorn revision, `semantic_collection_begin` advances the
collection generation; each `semantic_collection_virtual_item` publishes one
row record into the retained semantic tree; and collection pruning removes
members omitted from a rebuilt generation unless they are pinned as focused,
selected, or current. [The implementation](https://github.com/Carnival-Science/Alicorn/blob/dbd862a62643553aa0fba818bd16d85f15eb85b4/runtime/semantics.odin#L1026-L1152)
therefore makes a skipped row disappear from the current semantic working set.

The SDL host then builds a projection by copying every node in the semantic
snapshot into `Accessibility_Projection.nodes`. [Its projection builder](https://github.com/Carnival-Science/Alicorn/blob/dbd862a62643553aa0fba818bd16d85f15eb85b4/host/sdl3/accessibility/projection.odin#L201-L264)
therefore also scales with the current semantic working set. This describes the
SDL bridge's implementation; it does not establish identical behavior for every
host or native accessibility adapter.

The measured bottleneck therefore needs a runtime/host contract that can keep
offscreen rows addressable by stable ID and answer item-description, coordinate,
selection, focus, and reveal requests without re-emitting all row records on
each grid description. It cannot be fixed by dropping offscreen semantics or
by adding an AliKit-only skip flag. Alicorn #192 is adjacent but distinct: it
investigates keyed application-state update frontiers, not lazy accessibility
collection queries, so this finding does not duplicate that issue.

The current benchmark measures TestUI semantic synchronization and the AliKit
callback; it does not exercise the native AccessKit projection with 100,000
rows or a physical assistive-technology client. A runtime prototype should
measure initial build, one-row metadata change, scrolling/reveal, stable-ID
lookup, retained memory, and physical screen-reader navigation separately.

### Current-head component-call comparison

The earlier matched comparison did not isolate the public `data_grid()` call,
and used only three fresh processes per revision. This follow-up adds a timer
around that call and runs five fresh processes per revision and row count. The
same instrumented benchmark source is compiled against baseline AliKit
`fded57a94e6a` and current component source at `47223c7013ee`. Both use the
same pinned Alicorn, AccessKit binding, Odin compiler, release mode, viewport,
dataset, and alternating launch order. See the
[raw 30-process capture](data-grid-performance-follow-up-raw.json) and the
[paired runner](../../../../benchmarks/data_grid/run_paired.py).

Each value below is the median of the five process-level percentiles. The
component-call boundary includes the `data_grid()` API and timer overhead; the
full-turn Description boundary additionally includes TestUI and runtime work.
Reconcile and Semantic_Sync are Alicorn stage timings. Peak RSS is the whole
process, including the benchmark's application-owned row/cell arrays and
TestUI; it is not retained-runtime memory.

| Rows | `data_grid()` p50, baseline → current | Description p50 | Reconcile p50 | Semantic_Sync p50 | Peak RSS, baseline → current |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 200 | 0.082 → 0.090 ms (+9.8%) | 0.188 → 0.202 ms | 0.103 → 0.111 ms | 0.031 → 0.034 ms | 13.76 → 13.91 MB (+1.1%) |
| 10,000 | 2.257 → 2.092 ms (-7.3%) | 2.673 → 2.499 ms | 0.415 → 0.396 ms | 0.323 → 0.302 ms | 28.77 → 28.90 MB (+0.5%) |
| 100,000 | 37.082 → 37.157 ms (+0.2%) | 43.003 → 43.742 ms | 6.055 → 6.195 ms | 5.946 → 6.068 ms | 261.03 → 260.41 MB (-0.2%) |

At 100,000 rows, the direct component-call median is effectively flat. At
10,000 rows, it is lower in this capture. The 200-row p50 rises by 8 μs and
its p99 is noisy (0.152 → 0.214 ms); the 10,000- and 100,000-row component
p99 values move down (3.473 → 3.088 ms and 77.026 → 70.252 ms). With five
launches on one machine, these tail differences are not strong evidence of a
performance change. The results do not show a material large-grid CPU or RSS
regression, but they also do not establish a general performance improvement.
All 30 processes passed the 101-probe settled-idle gate and published every
logical row semantic entity.

This comparison also clarifies the scrollbar-transition review concern. The
existing regression changes one retained grid from nine rows to eight and
back, then checks retained header, track, cell and label IDs, focus, hover and
sorting behavior. That is the more direct identity check; the scaling probe
does not replace it. Neither check validates native screen-reader behavior,
GPU presentation, or physical DPI.

### Instrumented comparison reproduction

Copy the same benchmark source into the historical checkout, build both
executables against the exact shared dependencies above, and run the paired
capture:

```sh
mkdir -p /private/tmp/alikit-fded57a-benchmark
git archive fded57a94e6a2c5bf44d8b980befe5a260ff5ed5 \
  | tar -x -C /private/tmp/alikit-fded57a-benchmark
mkdir -p /private/tmp/alikit-fded57a-benchmark/benchmarks/data_grid
cp benchmarks/data_grid/main.odin \
  /private/tmp/alikit-fded57a-benchmark/benchmarks/data_grid/main.odin

cd /private/tmp/alikit-fded57a-benchmark
odin build benchmarks/data_grid -o:speed \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=/private/tmp/alikit-fded57a-benchmark \
  -collection:accesskit=/path/to/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -out:/private/tmp/alikit-data-grid-baseline

cd /private/tmp/alicorn-kit-authoring-quality
odin build benchmarks/data_grid -o:speed \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=. \
  -collection:accesskit=/path/to/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -out:/private/tmp/alikit-data-grid-current

python3 benchmarks/data_grid/run_paired.py \
  --baseline /private/tmp/alikit-data-grid-baseline \
  --candidate /private/tmp/alikit-data-grid-current \
  --baseline-revision fded57a94e6a2c5bf44d8b980befe5a260ff5ed5 \
  --candidate-revision 47223c7013ee8f92a3593b6ac99702ef505f2b6e \
  --runs 5 \
  --output docs/research/authoring-reliability/results/data-grid-performance-follow-up-raw.json
```

The runner records the benchmark source SHA-256, launch order, dependencies,
process resource use, the sorted 101-sample component-call and full-turn
distributions, runtime stage percentiles, and settled-idle assertions. Replace
the AccessKit collection path with the checkout at the recorded binding
revision.

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

## Revalidation with the current locked Alicorn

The earlier scaling captures used Alicorn `4e0862f`. This follow-up rebuilt
the same benchmark source at baseline AliKit `fded57a94e6a` and candidate
`f9b9d6d36160`, both against the current lock's Alicorn
`dbd862a62643553aa0fba818bd16d85f15eb85b4` and AccessKit binding
`e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`. It used Odin
`dev-2026-11:9a6991685`, release optimization, 1280 × 800, 12 visible rows,
and three fresh processes per revision and data size. The [raw capture](data-grid-dbd862a-raw.json)
contains all process samples, stage distributions, semantic counts, and idle
assertions.

Each cell is the median of the three process-level percentiles. The callback
timer wraps `data_grid()`; Description includes the whole TestUI/runtime turn.
Reconcile and Semantic Sync are runtime stage timings. RSS is process peak
memory, including the input model and TestUI.

| Logical rows | Description p50 / p95 / p99, baseline → candidate (ms) | `data_grid()` p50 (ms) | Reconcile / Semantic Sync p50 (ms) | Peak RSS (MB) |
| ---: | ---: | ---: | ---: | ---: |
| 200 | 0.184 / 0.192 / 0.201 → 0.194 / 0.205 / 0.218 | 0.080 → 0.090 | 0.102 / 0.031 → 0.103 / 0.031 | 13.70 → 13.88 |
| 10,000 | 2.026 / 2.353 / 2.691 → 2.025 / 2.532 / 2.657 | 1.718 → 1.718 | 0.321 / 0.249 → 0.309 / 0.236 | 28.70 → 28.88 |
| 100,000 | 36.931 / 41.679 / 42.510 → 38.159 / 44.167 / 45.426 | 31.950 → 32.344 | 4.927 / 4.826 → 5.262 / 5.160 | 267.47 → 272.88 |

The current runtime produces the same logical and offscreen semantic counts in
both AliKit revisions: at 100,000 rows, 99,987 rows are offscreen and the
median frame publishes 100,044 semantic descriptions. All 18 processes passed
the 101-probe settled-idle gate. Three launches are not enough to interpret
small tail or RSS differences as a regression; this run shows no meaningful
change in the large-grid call's median, while confirming that its work still
scales with total logical rows.

At 100,000 rows, the measured `data_grid()` call is about 32 ms p50 and
Semantic Sync is about 5.2 ms p50. That is evidence of a real large-data
scaling limit, but it does not establish that semantic publication alone
accounts for all callback time: formatting, app-owned data access, allocations,
and other runtime stages are inside the measured workload. Preserve offscreen
accessibility semantics; a scalable remedy requires an Alicorn collection
provider or equivalent lazy semantic query contract. This headless run does
not validate native GPU presentation, physical DPI, or assistive-technology
behavior.

To reproduce this capture, build the baseline AliKit snapshot and current
candidate against the same Alicorn and AccessKit checkouts recorded above,
copy the current `benchmarks/data_grid/main.odin` into the baseline snapshot,
then run the paired runner from the candidate repository root:

```sh
python3 benchmarks/data_grid/run_paired.py \
  --baseline /path/to/alikit-data-grid-baseline \
  --candidate /path/to/alikit-data-grid-candidate \
  --baseline-revision fded57a94e6a2c5bf44d8b980befe5a260ff5ed5 \
  --candidate-revision f9b9d6d36160c1969353a829950685d68ff42969 \
  --runs 3 \
  --output docs/research/authoring-reliability/results/data-grid-dbd862a-raw.json
```
