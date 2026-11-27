# Condition D Dialog trial notes

## Result and toolchain

- The reference app is in `main.odin`; its `main` uses `ui.run`, but no native window was launched during this trial.
- The final TestUI run passed all 4 tests at 2026-11-27 03:00:55 UTC. The test covers 1280×800, 960×720, and 760×640 at 1×, 1.25×, 1.5×, and 2×; content height changes; destructive confirmation behavior; focus and dismissal; and Alert semantics/default policy.
- The required app build passed after the final `ui.run` entry point was added. Linker emitted only `ignoring duplicate libraries: '-lobjc'`.
- Pinned inputs: Odin `dev-2026-11:9a6991685`; AliKit `5c1c0964cb6a531156b5b4a0c34e468cba4810e`; Alicorn `4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`; Odin AccessKit `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`; AccessKit C `0.23.1` static macOS arm64 library. No dependency or external checkout contents were inspected.
- First compiling `odin test` invocation: 02:49:47 UTC, about 2m47s after the batch start at 02:47 UTC (about 2m22s after first local implementation work at 02:47:25).

## Implementation passes and failures

Four code-changing passes addressed failed checks:

1. Fixed Odin compile/API errors: inferred `.{...}` text-style literals were invalid in this context, and `ui.rgb` requires a UI context, so color expressions moved from globals to call sites.
2. Changed TestUI static-text queries to stable node keys and asserted displayed strings via `Element.value`; checked focus with `alicorn.focused_node`.
3. Adjusted Tab assertions to account for the Dialog panel itself being focusable. The first Tab moves from Cancel to Delete; repeated subsequent Tabs remained on the panel or one of the actions.
4. Routed mutable application copy through both `Options.description` and `dialog.description`; a TestUI description update then verified the fit-content panel becomes shorter.

Category record:

- **Compile/API:** 3 failed compiler invocations before the first successful TestUI compile (invalid inferred text-style literal, one remaining instance, then context-dependent global `ui.rgb` calls). All resolved.
- **Layout:** The first content-height mutation check failed because only the semantic option changed while the visible description call still used a constant. After wiring both to app state, height shrank for shorter copy. Final checks passed wrapping (`description.bounds.h >= 36`), no overlap with the detail row, viewport/panel containment, and equal action y/height at all 12 size/scale combinations.
- **Interaction/accessibility:** Initial focus is Cancel; Return on first open never sets `deleted`; Escape and backdrop dismiss and restore focus to the opener. Alert publishes `Alert` and `Dialog` semantics, focuses its panel, and ignores Escape/backdrop by default. Tab remained in the Dialog panel/action subtree across repeated traversal. No unresolved TestUI focus containment failure remains.
- **Test/harness:** TestUI reports visible `Static_Text` content through `Element.value` while its `name` is empty. Also, `Element.focused` was false for the Cancel element even when `alicorn.focused_node` equaled its visual node; focus assertions therefore use the runtime’s focused node ID. This was handled in the assertions rather than interpreted as a Dialog focus failure.
- **Visual review:** No native rendering or screenshot review was performed. The code was authored against the supplied SVG only. The component currently uses a themed Container for the panel, so the rounded panel frame in the target is not provided by this Dialog implementation.

## Imports, dimensions, and limits

- `main.odin` imports only `alicorn:ui` and `alikit:dialog`; `ctx.runtime` is enough for `dialog.open`. `main_test.odin` imports `alicorn:runtime` for `Semantic_Role`, `Rect`, and `focused_node` assertions.
- The Dialog implementation itself imports `alicorn:runtime`: `dialog.open` calls `alicorn.focused_node` to capture the opener, and its after-frame callback calls `alicorn.focus` to apply/restore focus. It also uses runtime semantic and modal-overlay APIs for Dialog/Alert semantics and containment.
- Fixed authored dimensions: workspace header 54; navigation rail 224; selected rail row 38; content padding 46; project cards 94 high with 24 padding; opener button 116×36; confirmation width 516, padding 40, gap 12, max height 560, fit-content height 0; detail panel 58 high with 16 padding and 25×25 icon tile; separator 1 high; action gap 12; Cancel 112×40 and Delete 153×40. Alert width 420, padding 24, acknowledgement button 96×40.
- No compensating spacer or manual offset was used. Dialog height is content-sized and was tested by changing its description.
- Native rendering, physical DPI behavior, OS accessibility announcements, and real screen-reader behavior remain unverified; TestUI scale is a headless presentation-scale check.
