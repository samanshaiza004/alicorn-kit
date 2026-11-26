# Command Palette reference result

The runnable scene is `examples/command_palette/main.odin`; pass `--reference`
to open the modal with the `export` query. The comparison target is the authored
vector file
[`../references/command-palette.svg`](../references/command-palette.svg), not a
desktop application screenshot.

## Result

| Measure | Result |
| --- | --- |
| Attempts to pass geometry/behavior checks | 4 implementation attempts; see log below. Final TestUI reference case passes. |
| Imports used; runtime import and reason | `alicorn:ui`, `alicorn:runtime`, `alikit:command_palette`, `alikit:palette_model`, `alikit:palette_parts`. Runtime is needed for the custom overlay (`modal_overlay_begin/end`), custom surface/role construction, and dialog semantics. A stock `palette.build` consumer only needs `alicorn:ui` and `alikit:command_palette`. |
| Hardcoded dimensions | Reference window 1280 × 800; top bar 54; sidebar 232; project cards 94 high; modal 660 × 576; modal outer inset 32; panel gap 12; query row 52; uniform result rows 72; leading icon tile 38; shortcut tile 72 × 26. Text sizes are 22/13 for the modal heading/subtitle and 13/11 for row title/description. |
| Layout workarounds | The item model has no icon or shortcut properties and `build` has no custom-row callback, so the app maps stable item IDs to visual icons/shortcut labels and composes the public input/list/item parts. `alicorn:ui` does not re-export `modal_overlay_begin/end` or `semantic_describe_as`, so the custom shell imports runtime. The current icon enum has no plus mark; the workspace logo uses a text `+`. The target has nonuniform row heights; the example keeps a uniform 72px virtual-list track. |
| 1280 × 800, 960 × 720, 760 × 640 | TestUI asserts a centered 660 × 576 modal at each viewport and checks query/result containment. All three passed. |
| TestUI scales 1×, 1.25×, 1.5×, 2× | Passed for centered modal geometry and visible query/result text. Native pixels and physical-DPI output remain unverified. |
| Visual match to SVG target | Unverified. The modal bounds and retained visible text are checked headlessly; no native pixel comparison was captured. |
| Existing behavior and accessibility | Passed in the reference test: query focus and visible typed text, three matching results, selected/current semantics, title/description/shortcut drawable text, one-result filtering, Return activation, close, and focus restoration. The existing component suite covers keyboard navigation, disabled items, Escape, IME composition, modal containment, semantic activation, and idle return. |

## Attempt log

1. **Initial custom shell.** The example compiled. The first TestUI run rejected
   the result-title visibility check (`matching-glyphs=16`, `visible-glyphs=0`);
   the second query and the follow-on activation/focus assertions also failed.
2. **Grow the result content and make the second query deterministic.** The
   query path was changed to use the public `set_query` API after resize. The
   row visibility assertion still failed. A retained-node trace showed the
   semantic Button was 624px wide, the row surface only 80px wide, and the
   title text owner 0px wide.
3. **Fix the shared row part.** `palette_parts.row_surface` now grows across its
   Button owner. A parts regression asserts that the default row title has
   visible shaped text. The parts suite passed 7/7, and the reference fixture
   passed after using the shared helper.
4. **Match the target's modal geometry and finish the workspace scene.** The
   first build found invalid inline typed-array loop syntax. Moving those
   arrays to package constants fixed compilation. Final command-palette tests
   passed 9/9, parts tests passed 7/7, and the example build succeeded.

## Validation record

All commands ran from the AliKit repository with Odin
`dev-2026-11:9a6991685`, Alicorn
`4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`, and AccessKit
`e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`.

```sh
odin test command_palette \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=. \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -define:ODIN_TEST_THREADS=1
# Initial reference run passed 9/9 tests; current suite passes 10/10 after
# adding the four-scale retained-output check.

odin test palette_parts \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=. \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -define:ODIN_TEST_THREADS=1
# Passed: 7/7 tests.

odin build examples/command_palette \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=. \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -out:/private/tmp/alikit-command-palette-reference
# Passed; linker reported a duplicate -lobjc warning.
```

The four TestUI scale cases do not render to a native GPU surface. No native
screenshot, pixel comparison, or physical-DPI capture was produced; those
checks remain necessary before claiming a visual match.
