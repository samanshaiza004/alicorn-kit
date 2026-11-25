# Authoring reliability: reference component benchmark

This experiment asks whether Alicorn's cookbook and public APIs let a developer
recreate a common interface with correct geometry, behavior, and responsive
presentation without learning runtime internals.

Keep the benchmark references separate from introductory examples. The
Command Palette now has a minimal Quick Start, its existing parts/composition
examples, and the full reference application. Dialog and Data Grid each have a
minimal Quick Start alongside their full reference application. These small
examples are not part of the reference-attempt counts below; they serve as the
first-use path, while the larger scenes exercise their broader contracts.

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
| Command Palette | 4 | Yes, for its custom modal shell; stock `build` does not require it | 1280 × 800, 960 × 720, 760 × 640 passed | Native pixels and DPI unverified | [Result](results/command-palette.md) |
| Dialog | 7 | No | 1280 × 800, 960 × 720, 760 × 640 passed | Native pixels and DPI unverified | [Result](results/dialog.md) |
| Data Grid | 6 | No | 1280 × 800, 960 × 720, 760 × 640 passed | TestUI scales 1×, 1.25×, 1.5×, 2×; native pixels unverified | [Result](results/data-grid.md) |

The iteration counts are not a speed ranking. They count implementation/verification
passes needed to satisfy each component's different contracts. All three examples
passed their reported headless behavior and geometry checks. Every implementation
recorded specific fixed dimensions or public-API constraints; none used hidden
runtime workarounds for layout. The reports preserve those details rather than
claiming that the cookbook removed all authoring friction.

Native screenshot comparison, physical fractional-DPI rendering, and platform
accessibility review remain outstanding. A native Command Palette launch was
attempted but SDL had no display in the runner. Do not treat the SVG targets or
headless retained-output checks as visual-match evidence.

### Cross-reference observations

- The visible-text assertion caught Command Palette row content with a zero-width
  text owner; growing the shared row surface fixed both geometry and drawable text.
- The Data Grid reference exposed a 12 px header/body track mismatch when the body
  scrollbar consumed width. The shared header now reserves Alicorn's scrollbar
  thickness inside its full-width background only when rows can scroll. A later
  transition test found that this conditional wrapper recreated the keyed header
  grid and sortable cells when the scrollbar appeared or disappeared; using
  Alicorn's identity-transparent container preserves those node IDs.
- Dialog's public action helper fixes its button height at 32 px; reaching the
  target's 40 px uses ordinary `ui.button` controls inside the public action row.
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

For each of the three reference implementations, keep one result file under `results/` with this table and its attempt notes:

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
