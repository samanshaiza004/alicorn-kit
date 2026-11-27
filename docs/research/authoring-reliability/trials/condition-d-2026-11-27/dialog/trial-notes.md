# Condition D authoring trial: Dialog

## Trial record

- Trial started: `2026-11-27 00:27:45 UTC`.
- First successful build: `2026-11-27 00:33:33 UTC`, 5m48s after start.
- Trial target: the supplied Northstar project-settings confirmation and Alert design in `docs/research/authoring-reliability/references/dialog.svg`.
- Current trial implementation: `main.odin`; checks: `main_test.odin`.
- No AliKit checkout files were edited. The app was built but not launched, so there was no native visual review.

## Materials and revisions

At trial start I read only the Dialog guide, `docs/layout-cookbook.md`, the Dialog SVG target, the public Dialog package API, the public `alicorn:ui` facade, and TestUI's public API. The guide in the supplied snapshot said `7/7`; the pinned test source had eight test declarations. The guide count was corrected separately.

- Assigned AliKit API revision: `5e8fe6224bd14c294fe002c5ef9bc302faa26645`.
- AliKit checkout revision at verification time: `2d477baa696f23982c1b8342280c4b7fe5db138a`. Per the parent agent's diff check, only `docs/dialog.md` and `docs/research/authoring-reliability/results/dialog.md` differ from the assigned revision; the public package/API sources used here are byte-identical to `5e8fe62`.
- Alicorn: `4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`.
- Odin: `/opt/homebrew/bin/odin`, `dev-2026-11:9a6991685`.
- AccessKit Odin bindings: `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`.

## Result

The dialog and alert can be expressed with the public component API and compile against the assigned source API. `main.odin` imports only `alicorn:ui` and `alikit:dialog`; it does not need `alicorn:runtime`. The TestUI file imports `alicorn:runtime` for keyed retained text-node geometry inspection, and `alicorn:testui` for layout and visible-text assertions.

The destructive confirmation uses the Dialog's `.Configured` initial-focus policy to focus Cancel; the Delete action is a public `ui.button` with `.Danger`, since `dialog.action` does not expose a danger variant. Alert uses the public `.Alert_Dialog` policy and publishes both Dialog and Alert semantics.

The final TestUI suite is 3/3 passing. One test exercises all 12 combinations of 1280×800, 960×720, and 760×640 at 1×, 1.25×, 1.5×, and 2×. It checks centered fit/content geometry, modal containment and overflow, action alignment and dimensions, text-node containment and wrapped body height, and `expect_visible_text` for the title, body, details, and detail caption. The latter verifies produced visible shaped text rather than accepting application model state alone.

At 1280×800 and 1×, the final panel is `Rect{x=382, y=209, w=516, h=382}`, matching the SVG panel bounds. At 1.25×, geometry is rounded in subpixel increments (`h=382.4`); assertions allow 0.5–0.75 logical units for expected scale rounding. The final suite passed for every configured case.

Interaction tests cover opening both dialogs, configured Cancel initial focus, Return activating Cancel rather than the destructive action, Cancel dismissal, Escape and backdrop dismissal for an ordinary Dialog, opener focus restoration after each path, Alert focus and assertive Alert semantics, Alert ignoring Escape and backdrop presses, acknowledgement, and focus restoration after acknowledgement.

This is one independent trial. Its notes do not consistently count every code correction as a separate implementation attempt, so its correction-pass count should not be compared with the Palette count. It does not establish that the cookbook caused the successful result or improved the success rate.

## Commands and outcomes

Successful build (rerun after the reference-fit adjustment; no native launch):

```sh
/opt/homebrew/bin/odin build . -collection:alicorn=/private/tmp/alicorn-textfield-render -collection:alikit=/private/tmp/alicorn-kit-authoring-quality -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static -out:dialog-trial-verified
```

Final successful TestUI command:

```sh
/opt/homebrew/bin/odin test . -collection:alicorn=/private/tmp/alicorn-textfield-render -collection:alikit=/private/tmp/alicorn-kit-authoring-quality -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static -define:ODIN_TEST_THREADS=1 -out:trial.test
```

The final run output ended with `Finished 3 tests in 108.148ms. All tests were successful.` It emitted existing large-stack warnings from Alicorn test fixtures. The build emitted a duplicate `-lobjc` linker warning. An initial bare `/opt/homebrew/bin/odin test .` failed before compilation because it omitted the required `alicorn` and `alikit` collection flags. This was a command/setup failure, not a source failure.

The original first-successful-build shell command was not retained in the trial log. The timestamp and elapsed time above came from the contemporaneous run record; the successful build command shown here is an exact later rerun.

## Failures and friction by category

### Compiler and public API

- Initial compilation failed because the first draft referenced `ui.FONT_WEIGHT_*`; those constants are not re-exported by `alicorn:ui`. Removed the custom weight references and rebuilt successfully, retaining public defaults.
- Odin rejected a direct array literal in the `for in` expression. Naming the array before iteration fixed the syntax.
- A later bare test command failed on missing collection configuration as described above.

### Geometry and layout

- The initial intrinsic composition measured 516×302, 80 units shorter than the 516×382 SVG panel. The reference-fit pass adds the exact 80-unit difference by setting the panel height to 382, with 40-unit padding, 22-unit vertical gap, and a 50-unit action area. This is reference-specific sizing, not evidence that a generic dialog needs a fixed height.
- `ui.box(width=-1, height=1)` resolved to a 24-unit width in this separator use. Replacing it with a filling `ui.panel(width=-1, height=1)` produced the full 436-unit content width.
- Exact 153-unit Delete width differed by up to about 0.34 units under fractional scale rounding. Assertions now use a 0.75-unit tolerance.
- The final body geometry assertion confirms the long confirmation wraps to at least 30 units high; it stays within the panel at all viewport/scale combinations.

### Test and interaction authoring

- The first opener implementation displayed the action but did not call `dialog.open`; TestUI caught that the state remained closed. The opener was corrected to call the public API and tests verify the open state.
- An early semantic query for `.Static_Text` did not find the ordinary `ui.text` title/body nodes. The final checks use `testui.expect_visible_text` under the Dialog semantic node, plus public keyed runtime-node geometry for the specific title/body text nodes.
- Initial focus on Cancel required explicit `.Configured` focus and `focus_key`; the destructive Return safety check then passed by activating Cancel.

### Visual and native review

- No native rendering, screenshot comparison, GPU readback, or manual visual review was performed. TestUI covers logical geometry, semantics, retained text visibility, and shaped text, but cannot validate native antialiasing, colors, focus appearance, or cross-backend raster output.

## Fixed dimensions, workarounds, and limits

- Target-specific constants: 516×382 dialog, 40-unit inset, 58-unit detail row, 25-unit icon, 112×40 Cancel, 153×40 Delete, 12-unit action gap, and 50-unit action area. They reproduce this single SVG design and should not be read as component defaults.
- At the pinned API revision, the example composes title/body with `ui.text` and content via `dialog.begin`/`dialog.end`; Cancel uses `dialog.action`, while destructive styling uses `ui.button` because the action helper does not expose `.Danger`. The follow-up in current main adds `Action_Kind.Danger` and uses it in the public helper.
- The filled separator uses `ui.panel`, not `ui.box`, due to the width behavior encountered above.
- Alert and dialog layouts are checked in TestUI only. No resizing event, physical DPI transition, focus rendering, or native host lifecycle was run; scales and viewport sizes are TestUI cases.
