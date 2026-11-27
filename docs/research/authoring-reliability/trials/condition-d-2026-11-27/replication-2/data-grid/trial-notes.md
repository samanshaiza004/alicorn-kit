# Condition D Data Grid trial notes

## Result and revisions

- Odin: `dev-2026-11:9a6991685`.
- AliKit: `5c1c0964cb6a531156b5b4a0c34e468cba4810e`.
- Alicorn: `4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`.
- Odin AccessKit binding: `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`.
- First successful test compilation: **2026-11-27 02:54:26 UTC**, 7m26s after the shared 02:47 UTC batch start. The first compiler attempt at 02:53:52 failed before producing a test binary.
- First successful app build: **2026-11-27 02:57:45 UTC**, 10m45s after the shared batch start.
- Four implementation passes total: initial app/tests, compiler/API corrections, app invalidation and projection corrections after the first interaction run, and test-query/reveal-position corrections after the next run. Final verification completed by 02:57:45 UTC, within the 15-minute batch budget.

## Verification

Ran the pinned `odin test work ... -out:work/trial-tests` command and `odin build work ... -out:work/trial-app` command from `data-grid-2`. The final test run passed all 3 tests. The app build succeeded with only `ld: warning: ignoring duplicate libraries: '-lobjc'`.

The TestUI suite checks the 1280×800, 960×720, and 760×640 logical viewports at 1×, 1.25×, 1.5×, and 2×. It verifies the 200-row application projection, bounded realized rows, header/body first-track alignment, cell containment, visible text, table viewport width, selected/current row and cell semantics, stable row/header/cell IDs, Page Down reveal, disabled-row navigation, Return activation, sortable-header proposal and direction, text filtering, semantic `Set_Value`, and semantic reveal of a row in the sorted projection.

### Failed checks by category

- **Compile/API:** The first compile found four authoring issues: `fmt.aprintf` takes the format first, procedures are not implicit `App` methods, array loop values are immutable, and `ui.run` and TestUI use different initialize callback signatures. These were corrected in pass 2.
- **Layout:** No final geometry or visible-text assertion failed. The first complete 12-case matrix passed before the interaction fixes and passed again in the final run.
- **Interaction/accessibility:** The first interaction run found that sort state needed a follow-up invalidation, filtering needed to rebuild the projection after the controlled field adopted text, and queued semantic requests needed dispatch before the next projection was built. The app now invalidates after accepted selection/sort changes and drains requests at render entry. The semantic reveal test initially assumed the row's original data index; the app had sorted the projection, so the test now verifies that the requested row becomes realized through its current projected position.
- **Test/harness:** The initial row-count query assumed `Static_Text` was uniquely named by its display value. The test now locates it by a stable UI key and verifies its shaped text. No TestUI harness failure remained.
- **Visual review:** No native UI was launched. The retained TestUI paint/text and geometry stream passed; native pixels, physical fractional DPI, and OS accessibility remain unverified as required by the trial boundary.

## Imports and runtime boundary

The app imports `alicorn:ui`, `alikit:data_grid`, and `alicorn:runtime`, plus `core:fmt`, `core:mem`, and `core:strings`. Tests add `alicorn:testui` and `core:testing`.

This consumer needs `alicorn:runtime` for the application-owned semantic request queue: it resolves the filter field with `node_by_key` / `semantic_visual_id`, drains requests with `semantic_request_pop`, adopts filter `.Set_Value`, maps row `.Reveal` through `data_grid.handle_semantic_reveal_request`, and destroys events with `semantic_request_event_destroy`. It also reads the runtime viewport to choose responsive tracks and calls `invalidate_root` after accepting app state changes. The Data Grid component itself can be consumed with `alicorn:ui` and `alikit:data_grid`; this reference's semantic request ownership is the operation that needs the runtime package.

## Layout choices and limits

- Root fills the window; title bar is 54 logical px; sidebar is 72 px; main content uses 24 px padding; grid card uses 16 px padding.
- Data rows are 48 px high and the header is 42 px. The toolbar filter is 320 px wide. Visible rows are `clamp(int((viewport_height - 360) / 48), 4, 8)`: 8 rows at 800 px, 7 at 720 px, and 5 at 640 px. Data Grid reserves `SCROLLBAR_THICKNESS` for the shared header tracks when the 200-row projection is longer than that viewport.
- App-owned fixed tracks are calculated from viewport width minus the 72 px sidebar, 48 px main padding, 32 px card padding, and active scrollbar gutter. Track proportions are 41%, 19%, 20%, and the remainder. Minimum widths are 240, 108, 112, and 112 px. At the narrowest tested full-list viewport, tracks total 596 px and each remains above its minimum; the no-overflow checks pass.
- The component uses the pinned table semantic roles because this Alicorn revision has no Grid/Grid_Cell roles. The component publishes sort direction accessibly but has no public slot for the reference's small visible sort chevron. The toolbar field uses the public labeled text-field helper, so its visible label sits outside the blank input rather than appearing as an inline placeholder with a search icon. Sidebar symbols are text glyphs instead of custom icons.
- No claims are made about native rendering, physical DPI, screen-reader behavior, or OS-level accessibility. The reference is a non-spanned single-selection grid; sorting/filtering and accepted selection stay app-owned.
