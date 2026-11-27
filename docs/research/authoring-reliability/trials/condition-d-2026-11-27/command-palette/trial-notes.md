# Condition D: Command Palette, trial 2

## Trial record

- Archived trial directory: this directory. The original working directory was `/private/tmp/alikit-authoring-trials/2026-11-27/condition-d/command-palette-2/`.
- Start: **2026-11-27 00:43:58 UTC**.
- First clean TestUI run: **2026-11-27 01:01:22–01:01:25 UTC**.
- First successful executable build: **2026-11-27 01:01:42–01:01:44 UTC**. Elapsed from trial start to successful build completion: **17m46s**.
- Initial implementation was attempt 1; three code/test iterations followed to address compile and assertion failures. Final attempt count: **4**.
- The single TestUI test runs 12 cases: 1280×800, 960×720, and 760×640 at 1×, 1.25×, 1.5×, and 2×.

## Revisions and inputs

- Alicorn: `4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`.
- AliKit API source pinned by the task: `5e8fe6224bd14c294fe002c5ef9bc302faa26645`.
- The AliKit checkout was at `2d477baa696f23982c1b8342280c4b7fe5db138a` when first inspected and advanced to `47553c9e710ad086914f3cdcc23a11e1e70f2862` during the trial. `git diff --name-status 5e8fe6224bd14c294fe002c5ef9bc302faa26645 HEAD -- command_palette/command_palette.odin palette_parts/parts.odin` returned no changes. Thus the command palette source compiled for the final build matches the pinned API source; the AliKit docs were read before the checkout advanced.
- Odin: `/opt/homebrew/bin/odin`, `dev-2026-11:9a6991685`.
- Odin AccessKit binding: `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`.
- AccessKit C library collection: `/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static`.
- Inputs read were the listed Command Palette and layout cookbook docs, reference SVG, `command_palette.odin`, TestUI README, `testui.odin`, `geometry_checks.odin`, and `frontier_checks.odin`. `palette_parts/parts.odin` was not needed. No AliKit examples, AliKit package tests, research results, screenshots, other trials, or hidden notes were opened.

## Implementation

- `main.odin` builds a Northstar workspace shell and uses `palette.build` for the modal, query field, and results. It opens on `.Open_Command_Palette`, owns three stable command IDs, and stores the activated ID in application state.
- The shell root fills the offered viewport (`width=-1`, `height=-1`, `grow=1`). Palette options use a 660 logical-pixel maximum panel width, 24-pixel overlay padding, 40-pixel panel padding, 12-pixel panel gap, 52-pixel query row, 70-pixel uniform result rows, and a 246-pixel result-list maximum. The component computes the panel's fit-content height; the SVG's exact 576-pixel panel height was not reproduced.
- The query prefix is empty so the query field fills and aligns with the list. The target SVG's search glyph is omitted. The panel fill, rounded shape, backdrop, title, result descriptions, and footer approximate the supplied vector target.
- The app imports `alicorn:runtime` for colors/surface appearance types and the runtime callback type, `alicorn:ui` for the shell, and `alikit:command_palette` for the modal. Tests import `core:testing`, `alicorn:testui`, and the same palette package.

## Verification and limits

The TestUI checks pass for all 12 viewport/scale cases:

- The modal overlay fills the logical viewport; the retained panel is centered and contained within it.
- The query and result list fit inside the retained panel; query width fills the list width, centers with it, and has no parent overflow. The list has no parent overflow.
- Result rows remain inside the modal panel and have no immediate-parent overflow.
- Query replacement from `settings` to `export` filters from one result to three. TestUI checks the retained shaped query text and shaped result title with `expect_visible_text`.
- Down selection reaches stable ID 102 and is reflected in the retained result semantics. Return activates stable ID 102. Escape and Return both close the palette and restore focus to the clicked Projects opener.

**TestUI key-routing boundary:** with the palette modal open, `testui.step(Input{kind=.Key, key=.Down})` did not call the application's `on_key` callback; an instrumented counter remained at zero. The test therefore invokes the documented `palette.handle_key` host callback manually for Down when needed, then runs a TestUI time-advance description and checks selection semantics. TestUI Return activation, Escape dismissal, focus restoration, query replacement, layout, and shaped text remain exercised through the harness. This does not prove the native host's Down-key routing.

The panel surface did not appear in TestUI's semantic index under its visual key. Geometry checks therefore create a current `testui.Element` snapshot from the retained `panel_node` and its current `node_info` bounds, then use TestUI's `expect_inside`, alignment, fill, and overflow helpers against that snapshot.

The checks inspect retained logical layout and shaped paint output. No GPU pixels, native IME behavior, screen-reader bridge, or physical display scale were verified. The executable was built but not launched.

## Build and test commands

All commands ran with the trial directory as the working directory and these four Odin collections:

```sh
-collection:alicorn=/private/tmp/alicorn-textfield-render
-collection:alikit=/private/tmp/alicorn-kit-authoring-quality
-collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit
-collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static
```

The first, failed command omitted `accesskit_c` and mistakenly supplied the trial directory as an `app` collection:

```sh
/opt/homebrew/bin/odin test . -define:ODIN_TEST_THREADS=1 \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=/private/tmp/alicorn-kit-authoring-quality \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:app=.
```

All later test runs, including the first failed compile, failed assertion runs, and final passing run, used:

```sh
/opt/homebrew/bin/odin test . -define:ODIN_TEST_THREADS=1 \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=/private/tmp/alicorn-kit-authoring-quality \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static
```

Successful executable build:

```sh
/opt/homebrew/bin/odin build . -out:command_palette \
  -collection:alicorn=/private/tmp/alicorn-textfield-render \
  -collection:alikit=/private/tmp/alicorn-kit-authoring-quality \
  -collection:accesskit=/private/tmp/acetate-alicorn-master-3d49b8b/.deps/odin-accesskit \
  -collection:accesskit_c=/private/tmp/alicorn-textfield-render/.deps/accesskit/accesskit-c-0.23.1/lib/macos/arm64/static
```

## Failed attempts and corrections

1. **00:54:55 UTC — first test command failed:** `accesskit:accesskit.odin` references the `accesskit_c` library collection, which was not mapped. Added the pinned AccessKit C static-library path as the fourth collection.
2. **00:55:09 UTC — compile failed:** TestUI requires the raw-pointer `Application_Key_Proc`, while the native `ui.run` callback takes `^App`. Added a small raw-pointer adapter for the TestUI host.
3. **00:55:36–00:55:38 UTC — first test run failed:** all 12 cases could not find the panel by semantic key, and Down/Return activated the default first item. Replaced the key lookup with a current retained-node snapshot for the panel. Added an `on_key` call-through, but the next run showed the TestUI modal router still did not call it for Down.
4. **00:58:01 UTC — test rerun still failed on Down selection.** Added a callback counter; at **00:59:43–00:59:46 UTC**, it confirmed zero `on_key` calls for the TestUI Down input. Added the documented manual `palette.handle_key` callback fallback for Down, followed by a TestUI description pass. The matrix then passed at **01:01:22–01:01:25 UTC**.
5. **01:01:42–01:01:44 UTC — executable build succeeded** with the command above. Odin emitted existing stack-size warnings referencing Alicorn dependency test source paths and a linker warning about duplicate `-lobjc`; neither prevented the build.

The Odin compiler output referenced Alicorn `*_test.odin` file paths while compiling. Their contents were not opened, read, or used as guidance; the warnings named large local declarations only. Compiler diagnostics are recorded as build output and were not used as implementation guidance.

One independent trial does not show that the layout cookbook improves authoring.
