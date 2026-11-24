# Issue 6: composability phases 3-4

Phase 6 (installation, source copying, and external-consumer composition) is
recorded in
[issue-006-phase-6-external-consumers.md](issue-006-phase-6-external-consumers.md).

Date: 2026-11-23
Branch: `codex/v03-parts-migration`
Base: `origin/main` at `9d22fb2` (phases 1-2 merged)
Pinned Alicorn: `47c9d4a7cd1f637876190fec899daeeac00a30ae`
AccessKit binding: `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`

## Verdict

- **GO: Sidebar parts.** `rail_begin`/`item_begin`/optional visuals/`item_end`/
  `rail_end` over the shared selection model; the convenience `rail()` is built
  from the exact public parts.
- **GO: Menu parts.** `trigger`/`popup_begin`/`item_begin`/`separator`/group/
  `popup_end`, with custom row rendering and the `item()` convenience preserved.
- **GO: Command-palette result unification.** `command_palette.build` now uses
  the same public result parts as `palette_parts`: `input`, `list_begin`,
  `item_begin`, `item_end`, `empty`, `group_begin`, `list_end`.
- **GO: Icon Picker parts.** Search, grid/list, and choice contexts are public;
  the complete `picker()` is the convenience wrapper.
- **GO: shared table presentation.** `alikit:table_core` is the shared
  presentation package for Table and Data Grid.
- **NO-GO: menu submenus in v1.** The single overlay, row scroll, active index,
  and trigger focus restoration do not contain a nested open/parent-focus
  coordination model. Applications compose a second menu `State`; the package
  documents the boundary rather than duplicating overlay policy.
- **NO-GO: Menu collection at the pinned revision.** `semantic_collection_role_is_valid`
  still accepts only List, Tree, Tab_List, List_Box, Radio_Group, Table, and
  Table_Row. Menu groups therefore publish ad-hoc nested `Menu` semantics, not a
  counted collection (#241 remains open).

## Patterns reused

The phase 1-2 patterns are unchanged:

- convenience wrapper over public `begin`/part/`end` procedures;
- parts own interaction, semantics, per-item state, and activation parity;
- authors own the subtree between item begin/end and may omit default visuals;
- shared `alikit:selection` for focus repair/at-most-one/proposals and Alicorn
  roving for focus movement;
- three compiling examples per migrated component;
- authoring-first guide, registry entry, and catalog page.

## Per-component API and LOC

| Component | Public parts | LOC before | LOC after | Notes |
| --- | --- | ---: | ---: | --- |
| `sidebar` | `rail_begin`, `item_begin`, `row_surface`, `indicator`, `icon`, `label`, `badge`, `item_end`, `rail_end` | 552 | 809 | +257: author-owned rows, optional visual parts, shared selection, `Rail`/`Rail_Item`. `rail()` preserved. |
| `menu` | `trigger`, `popup_begin`, `item_begin`, `row_surface`, `check`, `label`, `shortcut`, `detail`, `item_end`, `separator`, `group_begin`, `group_end`, `popup_end` | 711 | 934 | +223: custom rows, separators, ad-hoc groups, shared selection. `item()` preserved. |
| `command_palette` | `input`, `list_begin`, `item_begin`, `item_end`, `empty`, `group_begin`, `group_end`, `list_end`, result aliases | 517 | 611 | +94: shell now composes result parts; `build` preserved. |
| `palette_parts` | `list_begin`, `list_end`, `item_begin`, `item_end`, `row_surface`, `icon`, `label`, `description`, `indicator`, `empty`, `group_begin`, `group_end` | 402 | 645 | +243: public row/group parts; `results()` preserved. |
| `icon_picker` | `search`, `grid_begin`, `grid_end`, `item_begin`, `item_end`, `cell`, `row`, `empty`, `sync`, `handle_key` | 826 | 1039 | +213: public parts and `Grid`/`Grid_Item`; `picker()` preserved. |
| `table` | shared core helpers | 725 | 561 | -164. |
| `data_grid` | shared core helpers | 904 | 732 | -172. |
| `table_core` (new) | `Column`/`Cell`/`Row`/`Alignment`/`Sort_State`, `tracks_for`, `header_*`, `cell_description`, `begin_surface` | 0 | 403 | Shared presentation; owns no interaction. |

The direct duplicate deletions in Table and Data Grid are 336 lines. The new
shared package is 403 lines (including its public contract comments), so total
presentation lines are +67 net while two consumers share tracks, headers, and
cell semantics. No interaction layer moved into the shared package.

## Wrapper compatibility

- Existing `rail`, `menu.trigger/item/popup_begin/popup_end`, `command_palette.*`,
  `icon_picker.picker`, `table.table`, and `data_grid.data_grid` call shapes are
  unchanged.
- Additive fields: `command_palette.State.results`,
  `command_palette.Options.results_accessible_name`, `MenuItem`, `Rail`,
  `Rail_Item`, `Grid`, `Grid_Item`, `List`, `Row`, `Group`.
- Type aliases preserve public names: `sidebar.Item`; `menu.Item`; table/data
  grid `Alignment`/`Column`/`Cell`/`Row`; `data_grid.Sort_State`.
- Result rows in the default command palette now use the public parts (leading
  tile, title/description, selection check). This is an appearance change; the
  catalog capture must be refreshed.
- `palette_parts/pilot_test.odin` moved to `command_palette/pilot_test.odin`.
  The test-only import of `command_palette` from the `palette_parts` package
  became a production import cycle once the palette adopted the parts. The
  measurement still compares both paths and now lives with the consumer.

## Menu decision detail

Groups are single-level and ad-hoc: `group_begin` opens a container, publishes a
nested `.Menu` description, and rows nested inside parent to it. Group headers
do not consume an item index and do not add navigation slots.

Submenus are not implemented because v1 has one overlay, one panel scroll
region, one active row index, and one trigger focus-restoration target. A nested
popup would need parent/child open coordination, child dismissal without closing
the parent, child focus restoration, and hover/arrow-right policy. That is a new
overlay policy, not a cheap extension of the current machinery. The composition
example and guide show a second menu `State` as the application-owned path.

## Palette unification detail

`command_palette` imports `alikit:palette_parts` and delegates its result list to
the public parts. `build` still owns the modal shell, title/query/footer,
match-buffer status, IME yield, outside-click dismissal, and focus restoration.
`palette_parts.results` remains the convenience list for application-owned
shells.

Group support in the parts requires the complete visible slice to be realized:
the virtual list uses a uniform row track and group headers do not consume a
collection position. This is documented for both packages; long lists stay
flat.

## Icon Picker detail

The complete composite is now `root + scope + search + grid parts`. The parts
emit grid rows manually with `alicorn.container_begin`, not `ui.row`. `ui.row`
is a deferred-scope helper and would close at the end of the opening block if
called inside `item_begin`; the manual scope keeps the row open across emitted
cells. This is the same layout-scope rule documented in the repository agent
guidance, applied inside a component.

Custom shells can pass their root node as `scope_owner` so grid navigation uses
the same text-preempt scope as the complete picker, or pass zero and drive
`handle_key` themselves.

## Validation

The full suite and native smokes are run after the registry/catalog sync. The
suite now covers:

- sidebar default 4 + parts 4 tests;
- menu default 3 + parts 3 tests;
- command palette modal 6 + pilot 1 + public parts 1 tests;
- palette parts 7 tests;
- icon picker default 12 + parts 2 tests;
- table 3 and data grid 4 tests.

## Follow-ups

- Historical follow-up superseded by the authoring-quality sweep: desktop
  captures were removed from the published catalog, and the pages now link to
  runnable source examples instead.
- Add a dedicated `table_core` unit test if a third consumer appears; current
  coverage comes through Table and Data Grid.
- Menu submenus remain application-composed; revisit only with a nested-overlay
  design and tests for parent focus restoration.
- Menu groups remain ad-hoc until Alicorn accepts `.Menu` collections.
