# Scroll Area catalog follow-up

This is a focused follow-up audit after the three-reference benchmark. It is
not included in their recreation attempt counts.

## Findings and changes

- `scroll_area` was a supported package with a guide, example, and test-runner
  entry, but the machine-readable registry and website component catalog did
  not include it. Added its component registry entry, website page, landing-page
  card, and an authored SVG reference target.
- `scroll_area.Style` advertised `corner_radius` and `stroke_width`, but neither
  value was read by `begin` or applied to Alicorn's retained `Scroll_Region`.
  Removed the no-op type, default value/helper, and unused `begin` argument.
  The component continues to expose the actual frame and scrollbar theme recipe.
- Added retained-output coverage for a unique visible line and a narrow-window
  resize. The check asserts that the region narrows, remains inside the logical
  viewport, and still has visible shaped text.

## Verification

| Check | Result |
| --- | --- |
| `odin test scroll_area` against Alicorn `4e0862f` and pinned AccessKit | 5/5 passed |
| `odin build examples/scroll_area` against the same collections | Passed; linker emitted the existing duplicate `-lobjc` warning |
| Registry JSON and source/test/example/page paths | Passed after adding Scroll Area as catalog component 14 |
| Website `components.json` sync | Passed; generated copy matches the repository registry |
| Native pixel/DPI and screen-reader validation | Unverified; no native display was available |

The SVG is a design target, not a capture of runtime output. The resized test
verifies a 360 × 300 logical viewport and retained text, not GPU pixels or
physical fractional-DPI rendering.
