# Authoring reliability: reference component benchmark

This experiment asks whether Alicorn's cookbook and public APIs let a developer
recreate a common interface with correct geometry, behavior, and responsive
presentation without learning runtime internals.

It starts with three components that exercise different layout contracts:

| Reference | Primary layout challenge | Visual target |
| --- | --- | --- |
| Command Palette | Nested modal layout, growing query/result region, icons and shortcut alignment | [Command Palette SVG](references/command-palette.svg) |
| Dialog | Intrinsic height, wrapped copy, action alignment, intentional initial focus | [Dialog SVG](references/dialog.svg) |
| Data Grid | Shared tracks, clipping, scrolling, selected cell, large virtual dataset | [Data Grid SVG](references/data-grid.svg) |

These are authored vector targets, not screenshots of the AliKit desktop app.
They are not documentation previews of running Alicorn output. The reference viewport is
1280 × 800 logical pixels; each implementation must also be exercised at 960 × 720 and
760 × 640. Check native presentation at 1×, 1.25×, 1.5×, and 2× display scale where a native
capture environment is available.

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

## Per-reference acceptance criteria

### Command Palette

- The modal, title, query, three result rows, selected state, shortcut, and footer fit within the
  reference panel at the target viewport.
- The query fills its parent row; icon/title/description/shortcut remain contained and aligned.
- Filtering changes the visible match count and the typed query is drawable in the field.
- Keyboard navigation, activation, Escape dismissal, focus restoration, and accessible names remain
  correct.
- No ordinary example code needs `alicorn:runtime`; report the imports actually used.

### Dialog

- The dialog height follows its content; the long description wraps without clipping or overlap.
- Detail text stays inside the panel, and action buttons share a baseline at the trailing edge.
- The visible focus ring is on Cancel for the destructive confirmation; Enter cannot accidentally
  confirm deletion on first open.
- Escape/backdrop policy, Tab containment, focus restoration, Alert behavior, and semantic labels
  remain correct.
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

Keep one result file per agent under `results/` with this table and its attempt notes:

| Measure | Result |
| --- | --- |
| Attempts to pass geometry/behavior checks | Unmeasured |
| Imports used; runtime import and reason | Unmeasured |
| Hardcoded dimensions | Unmeasured |
| Layout workarounds | Unmeasured |
| 1280 × 800, 960 × 720, 760 × 640 | Unmeasured |
| 1×, 1.25×, 1.5×, 2× DPI | Unverified until native captures |
| Visual match to SVG target | Unverified until native captures |
| Existing behavior and accessibility | Unmeasured |

The experiment is complete only after the three reports include native captures or explicitly list
the platform work that remains. A passing compiler, semantic value, or TestUI geometry check alone
does not establish visual equivalence.
