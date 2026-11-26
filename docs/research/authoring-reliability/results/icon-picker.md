# Icon Picker authoring-quality follow-up

This is a catalog-component audit after the three reference-component runs. It
does not change their attempt counts or claim that the Icon Picker is a fourth
benchmark reference.

## Verified issue and correction

The default List row built its icon tile, label, detail, and selected mark as
vertical siblings inside a fixed 30 px row. The component still published the
right semantic names, so semantic queries alone did not reveal that the text
glyphs were clipped from the visible row.

The default row now creates a full-width horizontal layout. It centers the
22 px icon tile, lets the label use the remaining width, and places optional
detail and selected-mark content in the same row. This preserves the existing
Button owner, stable choice key, semantic parts, and activation path.

The regression checks actual retained text output for the committed search
query, repeats the assertion after IME commit, resizes the fixture from its
initial viewport to 420 × 400 logical pixels, and verifies that the search
field remains contained, follows the narrower width, and continues to show the
query. The semantic `.Set_Value` regression verifies that an assistive query
value is visible in the search field and updates the sole matching choice. It
also switches to List appearance and checks visible glyphs for the Home row's
label and detail.

Before the row correction, the new visibility assertions failed for both
strings: the Home label reported 4 matching glyphs and 0 visible glyphs; its
detail reported 24 matching glyphs and 0 visible glyphs. After the correction,
both assertions pass. This gives the test a concrete negative control for
clipped text.

## Authoring and verification record

| Measure | Result |
| --- | --- |
| Part of the three reference-component attempt count | No; separate catalog follow-up |
| Blind recreation attempts | Not measured; this was an audit of the existing implementation |
| `alicorn:runtime` in the runnable example | Yes; the application owns modal overlay, semantic dialog, focus restoration, native key/pointer callbacks, and nested overlay behavior |
| Hardcoded dimensions | Yes; dialog, row, cell, and search sizing are explicit demo choices; no geometry-key workaround was added |
| Layout workaround | The default List row now uses ordinary `ui.row`/`ui.panel` composition; no duplicate text node or forced rebuild |
| Headless behavior/output tests | 16/16 passed against Alicorn `4e0862f` and the pinned AccessKit binding; includes semantic search-value adoption |
| Example build | Passed against the same locked dependencies |
| Resize | 420 × 400 logical viewport; search remains within bounds and retains visible query text |
| Native pixels, screen reader, physical DPI | Unverified; this environment has no native display |

Commands run:

```sh
odin test icon_picker -define:ODIN_TEST_THREADS=1 \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -collection:alikit=.

odin build examples/icon_picker \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -collection:alikit=.
```

The [authored List appearance target](../references/icon-picker.svg) is a
design reference, not runtime output. Native pixel matching, 1×/1.25×/1.5×/2×
DPI captures, and a platform screen-reader session remain unverified.
