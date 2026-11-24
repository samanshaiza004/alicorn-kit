# Dialog reference result

## Status

Headless layout, visible-text, focus, and behavior checks pass. Native visual
match and DPI capture remain **unverified** because SDL could not initialize a
display in this environment.

## Measures

| Measure | Result |
| --- | --- |
| Attempts to pass compile, geometry, text, and behavior checks | 7 implementation/test passes |
| Imports in ordinary example | `alicorn:ui` and the Dialog package; no `alicorn:runtime` import |
| Runtime-only import | Tests use `alicorn:runtime` to inspect focused nodes and retained semantic/output state |
| Hardcoded dimensions | Reference width 516 px; max height 500 px; padding 24 px; gaps 12 px; detail row 58 px; actions 112/153 × 40 px; app viewport 1280 × 800 |
| Layout workarounds | Uses ordinary `ui.button` inside the public Dialog action row to reach the target's 40 px button height; no spacers, overlaps, or positioned layout |
| Viewport checks | 1280 × 800 initial scene, then 960 × 720 and 760 × 640 TestUI resizes; panel remains in bounds and its full copy stays drawable |
| DPI: 1×, 1.25×, 1.5×, 2× | Unverified; native host has no display |
| Visual match to vector reference | Logical containment/alignment and text checks pass; pixel match unverified |
| Behavior and accessibility | Dialog suite 6/6 passed, including Cancel-first focus, Return safety, modal focus behavior, dismissal, restoration, and nested/Alert contracts |

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

## Validation

- `/opt/homebrew/bin/odin test dialog -collection:alicorn=/private/tmp/alicorn-textfield-render -collection:alikit=. -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static -define:ODIN_TEST_THREADS=1`:
  **6/6 passed**, with no allocation warning in the final run.
- `/opt/homebrew/bin/odin build examples/dialog -collection:alicorn=/private/tmp/alicorn-textfield-render -collection:alikit=. -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static -out:/private/tmp/alikit-dialog-reference`:
  **passed**. The linker reports a duplicate `-lobjc` warning.
- `/private/tmp/alikit-dialog-reference --smoke`:
  **could not run**. SDL reported `The video driver did not add any displays`.
- No desktop screenshots were added to documentation.

## Evidence boundary

The headless assertions establish retained bounds, button alignment, dialog
focus, safe Return behavior, and that the expected body text has shaped glyphs
with visible paint. They do not prove actual pixels, screen-reader announcements,
GPU clipping, font fallback, or fractional-DPI appearance. Those require the
native capture at each target scale.

The full-descendant text assertion depends on Alicorn's TestUI descendant-text
helper. At this run, the Alicorn checkout used by the tests and AliKit's lock
both resolve to `4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`; the helper is part
of the tested pin.

The 32 px fixed height in `dialog.action` is a concrete customization limit.
The public high-level `ui.button` makes the target achievable without runtime
access, but the component action helper does not expose an action-height option.
