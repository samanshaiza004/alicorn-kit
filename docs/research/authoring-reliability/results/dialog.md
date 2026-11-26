# Dialog reference result

## Status

Headless layout, visible-text, focus, and behavior checks pass. A qualitative
post-fix native review confirmed the full-window background and centered Alert
Dialog, and verified dismissal through the visible OK action. SVG pixel matching
and physical-DPI validation remain **unverified**.

The reference app and Quick Start now paint their root surface with
`Window_Background`. This prevents the host's default clear color from showing
around the dark dialog and making the surrounding application text low-contrast.
Both roots also grow to fill the host viewport; this was missing from the first
reference implementation and its Quick Start.

## Measures

| Measure | Result |
| --- | --- |
| Attempts to pass compile, geometry, text, and behavior checks | 7 implementation/test passes |
| Imports in ordinary example | `alicorn:ui` and the Dialog package; no `alicorn:runtime` import |
| Runtime-only import | Tests use `alicorn:runtime` to inspect focused nodes and retained semantic/output state |
| Hardcoded dimensions | Reference width 516 px; max height 500 px; padding 24 px; gaps 12 px; detail row 58 px; actions 112/153 × 40 px; app viewport 1280 × 800 |
| Layout workarounds | Uses ordinary `ui.button` inside the public Dialog action row to reach the target's 40 px button height; no spacers, overlaps, or positioned layout |
| Viewport checks | 1280 × 800 initial scene, then 960 × 720 and 760 × 640 TestUI resizes; panel remains in bounds and its full copy stays drawable |
| TestUI scales 1×, 1.25×, 1.5×, 2× | Passed for panel/action containment, action alignment, Cancel focus, and visible description. One native output was reviewed; SVG pixel match and physical-DPI output remain unverified. |
| Settled idle | At each TestUI scale, after a 2 s settling advance, 32 × 16 ms probes produced zero descriptions, reconcile/measure/layout/paint/shaping/semantic work, GPU submits, invalidation, or frame demand. Headless scheduler check only. |
| Visual match to vector reference | Logical containment/alignment and text checks pass; pixel match unverified |
| Behavior and accessibility | Dialog suite 7/7 passed, including four-scale reference output, Cancel-first focus, Return safety, modal focus behavior, dismissal, restoration, and nested/Alert contracts |

The matched baseline/candidate component-pipeline probe is documented in
[Command Palette and Dialog performance results](reference-components-performance.md).
It uses a smaller stock dialog fixture and is not a native or full-reference-app
performance comparison.

## Attempt log

1. The initial implementation did not compile because the existing button-query
   helper accepted only the original fixture type.
2. After making the helper generic, compilation succeeded but the test failed:
   the destructive action label was ambiguous with its opener, and arbitrary
   text had no `Static_Text` semantic entry.
3. Switched the action lookup to its stable key and checked descendant text
   through the dialog panel. Tests passed, but memory tracking reported a 172 B
   leak from replacing a live panel find result during resize.
4. Released the first find result before reassigning it. The suite passed
   without a leak warning.
5. Added the required 960 × 720 intermediate viewport check; all three logical
   sizes passed.
6. The reference uses 40 px actions, but `dialog.action` has a fixed 32 px
   height. Composed ordinary `ui.button` controls in `dialog.action_row_begin`
   and retained `dialog.dismiss` for closing. Tests still pass and the scene can
   match the target dimensions through public APIs.
7. Strengthened `expect_visible_text` to check the complete body copy rather
   than only its final phrase; all tests remained green.

The standalone quote-mark polish was excluded from the count because it did not
resolve a failed acceptance check or change geometry.

## Follow-up: root fills the host viewport

A native Mac screenshot of the Dialog reference showed the host clear color
through most of the window. The root panel had a logical height of 24 px in a
1280 × 800 viewport because it used fit-content sizing without `grow=1`. The
same omission was present in the Quick Start. Both roots now grow, and the
TestUI reference fixture uses the same panel and asserts exact root/viewport
bounds at 1280 × 800, 960 × 720, and 760 × 640, plus 1×, 1.25×, 1.5×, and 2×
scales. The regression failed before the fix with `root=Rect{x=0, y=0,
w=1280, h=24}` and passes after it. No desktop screenshot was added to the
documentation.

## Validation

- `/opt/homebrew/bin/odin test dialog -collection:alicorn=/private/tmp/alicorn-textfield-render -collection:alikit=. -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static -define:ODIN_TEST_THREADS=1`:
  **6/6 passed**, with no allocation warning in the final run.
- `/opt/homebrew/bin/odin build examples/dialog -collection:alicorn=/private/tmp/alicorn-textfield-render -collection:alikit=. -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static -out:/private/tmp/alikit-dialog-reference`:
  **passed**. The linker reports a duplicate `-lobjc` warning.
- `/private/tmp/alikit-dialog-reference --smoke`:
  **could not run from the shell runner**. SDL reported
  `The video driver did not add any displays`.
- A live macOS capture of the pre-fix reference was inspected and showed the
  host clear color around its 24 px root. The screenshot was not archived in
  the repository.
- The current Dialog suite passes **7/7**, including the four-scale reference
  layout, root-to-viewport bounds, focus, and visible-description check.
- The updated SDL_GPU reference binary builds successfully with
  `-minimum-os-version:27.0`; linking reports the existing duplicate `-lobjc`
  warning and that the installed SDL3 dylib targets macOS 27.2. A live
  post-fix macOS review showed the application background filling the window
  and the Alert Dialog centered over its backdrop. The accessibility tree
  exposed the dialog, title, description, and OK action; activating OK closed
  the modal and restored the page with its acknowledgement text.
- This was a qualitative native review at one captured output size. It does
  not establish SVG pixel equivalence, the display's physical scaling factor,
  fractional-DPI rendering, or platform screen-reader announcements. No
  desktop screenshots were added to documentation.

## Evidence boundary

The headless assertions establish retained bounds, button alignment, dialog
focus, safe Return behavior, and that the expected body text has shaped glyphs
with visible paint. The live native review additionally establishes that the
post-fix scene and Alert Dialog were visibly presented and dismissible in that
run. Neither check proves SVG pixel equivalence, screen-reader announcements,
GPU clipping at every scale, font fallback, or fractional-DPI appearance.

The full-descendant text assertion depends on Alicorn's TestUI descendant-text
helper. At this run, the Alicorn checkout used by the tests and AliKit's lock
both resolve to `4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`; the helper is part
of the tested pin.

The 32 px fixed height in `dialog.action` is a concrete customization limit.
The public high-level `ui.button` makes the target achievable without runtime
access, but the component action helper does not expose an action-height option.
