# Condition D: Command Palette trial

## Outcome

- Recreated the 1280 × 800 Northstar workspace and a centered 660 × 576 Quick actions modal with a focused query, three matching results, selected first row, shortcut keycaps, and footer.
- Application code owns the four command records, the visible `export` query, shortcut/icon mapping, result filtering for the custom list, and dispatch state. AliKit owns the controlled query field and stable-ID selection/list semantics.
- TestUI passed 2 tests, including all 12 combinations of 1280 × 800, 960 × 720, and 760 × 640 logical viewports at 1×, 1.25×, 1.5×, and 2× scale. It checked visible query/title/description/shortcut/footer text, containment, query width, accessible names, filtering to one result after committed text input, Down/Up navigation, Return activation, Escape dismissal, and focus restoration.
- No native UI was launched. Native renderer output, physical DPI behavior, and OS accessibility remain unverified.

## Pinned revisions

- Odin: `dev-2026-11:9a6991685`
- AliKit: `5c1c0964cb6a531156b5b4a0c34e468cba4810e`
- Alicorn: `4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`
- Odin AccessKit binding: `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`
- External dependency paths were used only in the compiler commands; no external source was searched or inspected.

## Timing and attempts

- Shared trial budget started at 02:47 UTC on 2026-11-27 and ends at 03:02 UTC.
- First successful app build completed at 02:51:55 UTC, 4m55s into the budget; that compiler invocation took 11.4s.
- Final app build completed at 02:59:11 UTC in 11.2s. Final TestUI run completed at 02:57:17 UTC and reported 2/2 successful tests.
- Implementation passes: 2. Pass 1 produced the initial app and built successfully. Pass 2 removed an unsupported `Text_Style.color` field discovered during the first combined test compile. A focusable opener was added before the behavior checks to make focus restoration testable; no layout or runtime behavior check required another implementation pass.
- Test/harness repair: two compiler iterations fixed a test array-loop expression, adapted TestUI's raw-pointer callbacks, removed dynamic string concatenation, imported the palette package in the test, and avoided taking a pointer to a copied loop value. These harness fixes did not require a UI behavior change.

## Failure categories

- Compile/API: one application API mismatch (`Text_Style` has no `color` field) was caught in the combined compile and fixed in pass 2. No remaining API errors.
- Layout: no TestUI geometry failures. Query fills its editor parent, and query, list, and result rows remain inside the dialog at all matrix sizes and scales.
- Interaction/accessibility: no TestUI failures. The field is named “Search actions,” the modal is “Quick actions,” the result collection has three named options, and the selected identity tracks keyboard navigation.
- Test/harness: two compile-only repair iterations as listed above. The final test run passed.
- Visual review: no native or pixel review was performed by instruction. TestUI's shaped-text/paint-stream checks are a headless visibility oracle only.

## Imports, layout, and limits

- Imports: `alicorn:ui`, `alicorn:runtime`, `alikit:command_palette`, `alikit:palette_model`, and `alikit:palette_parts`. Tests also import `alicorn:testui` and `core:testing`.
- The stock `command_palette.build` path can be consumed with only `alicorn:ui` and `alikit:command_palette`. This reference owns a custom modal and custom result rows, so it imports `alicorn:runtime` for `modal_overlay_begin/end` and explicit Dialog semantics. It imports `alikit:palette_model` for the custom filter and `alikit:palette_parts` for stable-ID rows and List_Box semantics.
- Fixed dimensions: modal 660 × 576 logical pixels; query row 52 px; result tracks 74 px each; modal overlay padding 32 px. At 760 × 640, the panel exactly fits between the 32 px vertical insets.
- The custom shell was needed because `Item` has no icon/shortcut fields and `build` has no custom-row callback. The shell composes the public query/list parts and supplies presentation data locally.
- Remaining gaps: no native rasterization, OS IME candidate-window, screen-reader, or physical-DPI checks; icon silhouettes and theme colors are a semantic approximation of the SVG artwork.

## Commands

```sh
odin test work -define:ODIN_TEST_THREADS=1 \
  -collection:alicorn=inputs/alicorn \
  -collection:alikit=inputs/alikit \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -out:work/trial-tests

odin build work \
  -collection:alicorn=inputs/alicorn \
  -collection:alikit=inputs/alikit \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static \
  -out:work/trial-app
```
