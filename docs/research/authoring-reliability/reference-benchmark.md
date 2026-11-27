# Authoring reliability: reference component benchmark

This experiment asks whether Alicorn's cookbook and public APIs let a developer
recreate a common interface with correct geometry, behavior, and responsive
presentation without learning runtime internals.

Apply the shared [authoring-quality charter](../authoring-quality-charter.md)
when judging attempts, implementation tradeoffs, and performance evidence.

Keep the benchmark references separate from introductory examples. The
Command Palette now has a minimal Quick Start, its existing parts/composition
examples, and the full reference application. Dialog and Data Grid each have a
minimal Quick Start alongside their full reference application. These small
examples are not part of the reference-attempt counts below; they serve as the
first-use path, while the larger scenes exercise their broader contracts.
The catalog follow-up also adds an inline Icon Picker Quick Start while
preserving its modal reference, parts, and composition examples.
Each of the three reference apps and Quick Starts paints its root surface with
`Window_Background`, so the native host's default clear color cannot show
through the application content.

It starts with three components that exercise different layout contracts:

| Reference | Primary layout challenge | Visual target |
| --- | --- | --- |
| Command Palette | Nested modal layout, growing query/result region, icons and shortcut alignment | [Command Palette SVG](references/command-palette.svg) |
| Dialog | Intrinsic height, wrapped copy, action alignment, intentional initial focus | [Dialog SVG](references/dialog.svg) |
| Data Grid | Shared tracks, clipping, scrolling, selected cell, large virtual dataset | [Data Grid SVG](references/data-grid.svg) |

These are authored vector targets, not screenshots of the AliKit desktop app.
The catalog displays them as design-reference illustrations, not previews of running Alicorn
output. The reference viewport is
1280 × 800 logical pixels; each implementation must also be exercised at 960 × 720 and
760 × 640. Check native presentation at 1×, 1.25×, 1.5×, and 2× display scale where a native
capture environment is available.

The 14 source SVGs were rendered and reviewed together on 2026-11-26. Their
contexts range from project workspaces and inventory to audio production,
writing, build tooling, and archives. Their visual vocabulary is less varied:
12 use dark palettes and many use card surfaces; Radio Group and Table use light
palettes. This suite checks whether each component can reproduce its selected
layout and behavior. It does not establish creative freedom across unrelated
design languages, nor justify adding a styling abstraction. A separate study
would need alternative visual targets with the same behavior contract.

### Creative-freedom follow-up

Keep this separate from the current cookbook comparison. The current test asks
whether an author can reproduce a known layout; it does not ask whether Alicorn
can express unrelated visual systems without replacing component behavior.
For that follow-up, hold data, keyboard and pointer behavior, semantics, and
accessibility requirements constant, but use independently authored visual
targets from four families:

| Visual family | Distinguishing pressure |
| --- | --- |
| Minimal productivity UI | Sparse surfaces, compact hierarchy, restrained emphasis |
| Audio hardware-inspired UI | High information density, meter-like marks, strong state contrast |
| Editorial document UI | Typography-led hierarchy, long-form copy, low-chrome controls |
| Dense professional tooling | Compact controls, persistent selection, layered panels and tables |

Use the same public component behavior with at least two presentations per
selected component. Require each version to preserve stable identity, keyboard
and focus behavior, semantics, resize bounds, and scale-safe text and marks.
Record the Alicorn primitives and AliKit parts used, any `alicorn:runtime`
imports, layout workarounds, authoring attempts, and native output checks. Do
not judge the variants by resemblance to one preferred design system, or infer
that a shared styling language is needed from visual diversity alone. This is
a later expressive-capability study; no result is claimed yet.

## Method

Give each implementation agent only its component's vector target, this method,
[`../../layout-cookbook.md`](../../layout-cookbook.md), the corresponding component guide, and
the public API. Ask it to recreate the scene in the runnable example and add headless assertions
for the measured geometry and visible text. Do not provide hidden implementation notes from the
other components. Keep one agent per reference; this is a three-case experiment, not another
simultaneous sweep of the whole catalog.

Count attempts consistently: the first implementation is attempt 1. Every subsequent code pass
needed after a failed compile, geometry assertion, behavior assertion, or visual review increments
the count. Record the checks that failed on each attempt; do not count unrelated formatting or
dependency setup as an attempt.

Use TestUI assertions for objective layout checks: `expect_inside`, `expect_no_overflow`,
`expect_fills_width`, `expect_aligned`, and `expect_visible_text`. Re-query elements after each
description or input. Geometry checks use logical pixels. Native screenshots remain necessary to
score visual match, GPU text and icon visibility, fractional-DPI edges, and clipping. If a native
capture cannot be made, report visual match as **unverified**, not as a pass.

For components that own editable buffers, also route a semantic `.Set_Value`
request through the application's shared request queue to the owning
component. Verify that the query is visibly drawn and that its dependent
results update; checking only the buffer or semantic tree can miss a retained
text-rendering failure.

## Controlled authoring comparison

The reference attempt counts below are correction-pass counts for the current
work. They do not show whether the cookbook reduces first-pass failures. To
measure that, run the same target independently under these conditions:

| Condition | Available materials |
| --- | --- |
| A | Comparable historical AliKit API and its component guide, from `fded57a` |
| B | Current API and the same component guide, without the layout cookbook |
| C | Current API, component guide, and layout cookbook |
| D | Current API, component guide, cookbook, and TestUI layout assertions |

The earlier `40692e3` snapshot predates the Data Grid and Dialog packages, so
it cannot serve as the common historical baseline for all three tasks. Use
`fded57a`, which contains all three packages, and record its exact dependency
pins.

Each trial starts from a fresh isolated directory and receives only its
condition's materials plus the target SVG and shared task contract. Keep the
model/version, prompt, decoding settings, time/token budget, dependency pins,
compiler, and validation order fixed. Do not expose existing examples,
benchmark results, or other trial outputs. Run at least three independent
trials per condition before making a comparative claim.

Record separate counts for compile/API errors, geometry/layout errors,
interaction/accessibility errors, test-authoring or harness errors, and visual
review failures. Count a new implementation attempt only when a code change
follows a failed check in one of those categories; report harness/test mistakes
separately from interface defects. Also record first-build time, runtime
imports, fixed dimensions/workarounds, resize and scale results, visual score,
and unresolved limitations.

Condition A and C each have one pilot implementation per reference. They are
not a controlled comparison: the A trials received shared host and text-field
API context after work had started, and the C pilot did not complete the same
live validation protocol. All three A examples compiled against the pinned
historical packages, but SDL reported that no video display was available, so
none could be checked for live geometry, interaction, resize, DPI, or
accessibility output. Keep these pilots out of any condition-level success-rate
claim. Run the full independently repeated protocol above before comparing
conditions.

## Per-reference acceptance criteria

### Command Palette

- The modal, title, query, three result rows, selected state, shortcut, and footer fit within the
  reference panel at the target viewport.
- The query fills its parent row; icon/title/description/shortcut remain contained and aligned.
- Filtering changes the visible match count and the typed query is drawable in the field.
- Keyboard navigation, activation, Escape dismissal, focus restoration, and accessible names remain
  correct.
- Record whether the stock component and the target presentation can be built without
  `alicorn:runtime`. If the custom parts require a lower-level public overlay API, report the
  exact boundary rather than bypassing it.

### Dialog

- The dialog height follows its content; the long description wraps without clipping or overlap.
- Detail text stays inside the panel, and action buttons share a baseline at the trailing edge.
- The visible focus ring is on Cancel for the destructive confirmation; Enter cannot accidentally
  confirm deletion on first open.
- Escape/backdrop policy, Tab containment, focus restoration, Alert behavior, and semantic labels
  remain correct.
- Record whether the example needs `alicorn:runtime` and identify any specific public operation
  that causes the dependency.
- Record every fixed dimension and any compensating spacer/offset used to match the target.

### Data Grid

- Header and every realized row share the same column tracks; the selected cell remains inside the
  table clip and columns do not drift while scrolling.
- A 200-row dataset renders only the visible/overscan rows; keyboard reveal and scroll keep focus
  visible.
- Stable row/column IDs, selected/current semantics, disabled-row navigation, activation, and sort
  proposals remain correct.
- The grid and surrounding filter/status controls adapt at all three viewport sizes without
  horizontal overflow; report whether any fixed track or minimum width is necessary.
- Report whether `alicorn:runtime` is needed for the reference implementation and what public
  operation requires it.

## Results template

## First reference run

| Reference | Attempts | `alicorn:runtime` in example | Logical resize checks | DPI and native visual result | Report |
| --- | ---: | --- | --- | --- | --- |
| Command Palette | 4 | Yes, for its custom modal shell; stock `build` does not require it | 1280 × 800, 960 × 720, 760 × 640 passed | TestUI 1×, 1.25×, 1.5×, 2× passed; native scene reviewed, pixel/DPI match unverified | [Result](results/command-palette.md) |
| Dialog | 7 | No | 1280 × 800, 960 × 720, 760 × 640 passed | TestUI 1×, 1.25×, 1.5×, 2× passed; qualitative native review passed, pixel/DPI match unverified | [Result](results/dialog.md) |
| Data Grid | 11 | Yes, in the reference app for virtual-row reveal and filter-value requests; Quick Start does not | 1280 × 800, 960 × 720, 760 × 640 passed | TestUI scales 1×, 1.25×, 1.5×, 2×; native scene reviewed, pixel/DPI match unverified | [Result](results/data-grid.md) |

The iteration counts are not a speed ranking. They count implementation/verification
passes needed to satisfy each component's different contracts. All three examples
passed their reported headless behavior and geometry checks. Every implementation
recorded specific fixed dimensions or public-API constraints; none used hidden
runtime workarounds for layout. The reports preserve those details rather than
claiming that the cookbook removed all authoring friction.

These results do not establish that authors or AI agents make fewer initial
mistakes than they did with earlier Alicorn/AliKit APIs. We did not run the same
tasks against an earlier revision with matched instructions and task budgets.
The attempt counts measure correction passes needed to satisfy the current
checks; they are not a before/after success-rate comparison. Matched headless
component-pipeline CPU and process peak-RSS probes cover all three references
at current main: Command Palette and Dialog at 47223c7, and Data Grid at
47223c7 with a direct timer around `data_grid()`. In this capture, Palette
description p50 was 27 µs in both revisions, Dialog was 10 µs in both, and the
Data Grid call was 0.082/2.257/37.082 ms at baseline versus
0.090/2.092/37.157 ms for 200/10,000/100,000 rows. These are local same-runtime
comparisons, not native rendering, long-session memory, or cross-framework
workloads. Settled-idle gates now cover the three reference scenes: Command
Palette and Dialog run 32 virtual 16 ms probes after a 2 s
settling advance at each TestUI scale; Data Grid runs 101 probes at each row
count. All assert zero retained work, invalidation, and frame demand. These are
headless work-demand checks, not native wakeup, GPU/presentation, energy, or
idle CPU-timing measurements. Persistent-heap measurements and a matched
before/after authoring comparison remain outstanding. See the [Command Palette
and Dialog probe](results/reference-components-performance.md) and the [Data
Grid current-head comparison](results/data-grid.md#current-head-component-call-comparison)
for their dependency controls, results, and limits.

The Data Grid's visual virtualization does not bound all work by the viewport.
For assistive-technology navigation, `data_grid()` publishes a virtual
`Table_Row` semantic item for every offscreen logical row; Alicorn retains those
row-level semantic entities while realizing cells only for visible rows. The
current five-launch probe measured direct `data_grid()` call p50 at
0.090/2.092/37.157 ms and whole-process peak RSS at 13.91/28.90/260.41 MB for
200/10,000/100,000 rows. The matched baseline values were 0.082/2.257/37.082 ms
and 13.76/28.77/261.03 MB. These are single-machine TestUI CPU and process-
memory measurements, not native renderer or screen-reader results.
See the [Data Grid result](results/data-grid.md) and its linked raw capture for
the method, per-launch distributions, and limitations.

Native pixel comparison, physical fractional-DPI rendering, and platform
accessibility review remain outstanding. Current Palette and Data Grid builds
were inspected through live macOS captures at a 2560 × 1440 capture resolution;
the physical display scale factor was not recorded. The Palette query and three
filtered results were visible, and the Data Grid showed its selected cell and
200-row dataset. The post-fix Dialog build was also reviewed live: its root
background filled the window, its Alert Dialog was centered over the backdrop,
and activating OK dismissed the dialog and restored the page. These captures
were not archived as repository images. Do not treat the SVG targets or
headless retained-output checks as pixel-match evidence.

### Cross-reference observations

- The visible-text assertion caught Command Palette row content with a zero-width
  text owner; growing the shared row surface fixed both geometry and drawable text.
- The Data Grid reference exposed a 12 px header/body track mismatch when the body
  scrollbar consumed width. The shared header now reserves Alicorn's scrollbar
  thickness inside its full-width background only when rows can scroll. A later
  transition test found that this conditional wrapper recreated the keyed header
  grid and sortable cells when the scrollbar appeared or disappeared; using
  Alicorn's identity-transparent container preserves those node IDs, hover, and
  sort interaction across both transitions. The full reference-app check later
  caught unclosed empty layout scopes, a collapsed panel width, and a semantic
  Table owner that did not cover its virtualized rows; all three now have
  permanent regression assertions.
- A post-benchmark accessibility audit found that the Data Grid published virtual
  `Table_Row` items but its reference app discarded the runtime's app-owned
  `.Reveal` and filter `.Set_Value` requests. The app now routes reveal requests
  through the component's stable-row resolver and adopts filter values into its
  owned text buffer. A TestUI regression verifies that revealing an offscreen
  semantic row makes it a realized row. This follow-up adds a new contract after
  the original attempt-count exercise, so the reported 11 passes remain scoped to
  that earlier task definition.
- The same request-queue audit found that the static Table also published
  offscreen virtual rows without a public reveal resolver, and its reference
  filter did not adopt semantic `.Set_Value` requests. The Table now resolves
  `.Reveal` by its stable row key and instance identity, and its example routes
  filter updates into application-owned state. Package and reference-app tests
  cover both behaviors. The Table reference remains a nonvirtualized intrinsic
  row-height example, so its app-level reveal path is not exercised there.
- The Dialog benchmark exposed a fixed 32 px action height and a missing Danger
  action kind. Follow-ups added an optional height while retaining that default
  and mapped `.Danger` through the component helper; the reference now uses
  `dialog.action` for its 40 px Cancel and destructive actions.
- The custom Command Palette shell needs runtime exports for modal overlay and
  semantic construction. A stock palette consumer still has the simpler
  `alicorn:ui` + `alikit:command_palette` import surface.

### Follow-up outside the three reference cases

A catalog audit found that Scroll Area had a guide, example, and test suite but
was missing from both the machine-readable registry and website component list.
The same audit found a public `Style` type whose radius and stroke fields were
never applied. The registry/page omission and no-op API were corrected, and a
visible-text/resize assertion plus an authored Scroll Area target were added.
See the separate [Scroll Area follow-up](results/scroll-area.md); it is not part
of the three reference attempt counts.

The Icon Picker follow-up added an actual visible-glyph regression after an
initially empty search and after IME commit, checked that a narrow resize keeps
the field inside the viewport, and found that List rows placed their icon,
label, and detail as vertical siblings inside a 30 px row. The default row now
uses a centered icon tile and a horizontal text layout. See the separate
[Icon Picker follow-up](results/icon-picker.md); it is not part of the three
reference attempt counts.

The experiment is complete only after the three reports include native captures or explicitly list
the platform work that remains. A passing compiler, semantic value, or TestUI geometry check alone
does not establish visual equivalence.
