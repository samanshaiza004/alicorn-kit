# Data Grid

`alikit:data_grid` is the interactive dataset grid split out of the P0 table.
It owns one Tab stop, roving cell focus, row reveal, accepted-selection
publication, and cell activation proposals. The application owns columns, rows,
stable keys, sorting, filtering, and the accepted selection.

Use it for an application-owned dataset with cell navigation. Use
[Table](table.md) for static document-style presentation with intrinsic wrapped
rows and ordinary document navigation.

## Responsibility split

| Layer | Responsibility |
| --- | --- |
| Alicorn | Grid tracks, virtual list, semantic collections, table roles, focus traversal, pointer hit testing, `semantic_collection_virtual_item`. |
| `table_core` | Shared `Column`/`Cell`/`Row`/`Alignment`/`Sort_State` shapes, column tracks, header surface/row/cell scaffolding, cell semantics, and surface fallback. |
| `data_grid` | Interactive body composition, nested row/cell collections, roving cell coordinates, row reveal, sort-header proposals, one activation proposal, theme contract. |
| Application | Columns, rows, stable keys, comparators, filters, accepted selection, dispatch, editing policy. |

The component retains only ephemeral focus/proposal state. It publishes
`Selected`/`Current` from caller values and never mutates selection.

`alikit:table_core` is the shared presentation layer used by both this grid and
[Table](table.md). It owns the common data shapes, column tracks, header parts,
and cell semantic scaffolding; `data_grid` keeps its distinct managed-focus,
roving, reveal, and proposal layer.

## Copyable implementation

Files: `data_grid/data_grid.odin`, `data_grid/data_grid_test.odin`,
`examples/data_grid/main.odin`, `examples/data_grid/theme.json`.

```odin
import data_grid "alikit:data_grid"

event := data_grid.data_grid(
	ctx,
	&app.view,
	app.columns[:],
	app.projection[:app.visible_count],
	app.selection,
	data_grid.Options{accessible_label="Documents", row_header=true,
		max_visible_rows=10, row_height=30},
	key=alicorn.key_string("documents"),
	instance_id=1,
	recipe=app.recipe,
)
switch event.kind {
case .Activated:
	app.selection = data_grid.Selection{row_key=event.row_key, column_key=event.column_key}
case .Sort_Proposed:
	app.toggle_sort(event.column_key)
}
```

Call `data_grid.request_focus(&state)` to focus the single Tab stop.

## Parts and identities

| Part | Identity | What can be omitted or replaced |
| --- | --- | --- |
| Grid | `grid_semantic_id(instance_id)` | Always present. Publishes `Table` (grid roles are pending in Alicorn). |
| Header row | `header_row_semantic_id(instance_id)` | Omit with `Options.hide_header`. |
| Header cell | `header_cell_semantic_id(instance_id, column_key)` | Publishes `Table_Column_Header`; `Column.sortable` adds a Press action and `Sort_Proposed`. |
| Body row | `row_semantic_id(instance_id, row_key)` | Nested `Table_Row`. |
| Body cell | `cell_semantic_id(instance_id, row_key, column_key)` | `Table_Cell` / `Table_Row_Header`; selected/current states. |

`Column`, `Cell`, `Row`, `Alignment`, and `Sort_State` are aliases of
`alikit:table_core` shapes. `Column.sort` is presentation input only: the application changes its
projection and the accepted direction. Separator rows do not exist here; the
grid is a dataset.

## Styling, motion, and theme

`Recipe` declares four optional namespaced roles: header surface, row surface,
selected row surface, and selected cell surface. `Style` carries corner radius,
focus outline width, and selected-cell outline width. `Options` carries row and
header heights, visible rows, gaps, padding, and text sizes.

Selection is shown by row fill plus a selected-cell surface and accent outline,
not color alone. Roving focus and reveal are immediate; there is no animation.

## Keyboard and accessibility contract

- **Tab** reaches the grid once. Body cells are not separate Tab stops.
- **Up/Down** move the focused row, skipping disabled rows and preserving the
  column. **Page Up/Down** move by `max_visible_rows` and clamp to the first/last
  enabled row. **Left/Right** move the cell coordinate within the row;
  **Home/End** target the first/last column.
- **Return/Space** propose the active cell; pointer activation and semantic
  activation use the same proposal path.
- Disabled rows publish `Disabled`, skip navigation, and do not activate.
- The collection publishes `Table` with accessible name, logical row count,
  selected row, and current row. Rows publish `Table_Row`, `Selected`,
  `Current`, and `Disabled`. Header cells publish `Table_Column_Header` with
  sort direction and a Press action when sortable.
- Focus stays on the grid owner; the cell coordinate moves through the roving
  model.
- Not claimed: cell spans, editing, multi-select, column resizing/reordering,
  built-in sorting/filtering, or a composite grid role.

### Grid-role decision

Alicorn's pinned `Semantic_Role` enum contains `Table`, `Table_Row`,
`Table_Cell`, `Table_Column_Header`, and `Table_Row_Header`, but **no** `Grid`
or `Grid_Cell`, even though AccessKit has `ROLE_GRID`/`ROLE_GRID_CELL`. v1 uses
the table roles and records the grid-role question as an Alicorn-side proposal:
adding `.Grid`/`.Grid_Cell` plus collection support is an Alicorn change, not an
AliKit private semantic layer.

The founder's #238 revision proposes separate `.Table` vs `.Data_Grid` pattern
kinds in `testui`. Until that lands, tests use explicit drive assertions and the
existing `.Roving_Grid`-style navigation expectations are documented rather than
claimed as a pattern.

## Conformance tests

`data_grid/data_grid_test.odin` covers:

- identities, column tracks, and theme diagnostics;
- `Table` logical count, nested row/cell collections, row-header cells,
  selected/current coordinates;
- Up skipping a disabled row, Down, Home/End columns, Return activation, and
  pointer activation parity;
- sortable header semantics, direction description, Press action, and
  `Sort_Proposed`;
- 200-row virtualization with virtual semantic rows and Page Down reveal;
- the native example smoke path.

There is no `testui` data-grid pattern at the pinned revision; `.Roving_List`
and `.Roving_Grid` require a `List_Box` container. Explicit drive assertions are
used until the `.Data_Grid` pattern addition lands.

## Limits

- Headless tests do not prove a physical screen-reader grid session or pixels.
- Non-spanned only; columns cap at 64. Virtual rows publish cells only when
  realized.
- Sorting and filtering are application callbacks over the projection.

## Source map

- [Package](../data_grid/data_grid.odin)
- [Shared presentation](../table_core/table_core.odin)
- [Tests](../data_grid/data_grid_test.odin)
- [Example](../examples/data_grid/main.odin)
- [Theme JSON](../examples/data_grid/theme.json)
