# Table

`alikit:table` is a composable, virtualized, **non-spanned** table over
Alicorn's compound table roles. The application owns columns, rows, sorting,
filtering, and selection. The package owns shared column tracks, nested
`Table` → `Table_Row` → `Table_Cell` semantics, header roles, roving cell
coordinates, virtual row publication, and one activation proposal.

Use it for a read-oriented dataset with an application-owned data pipeline. Use
a virtual list for a single-column list, and a list of cards when each row needs
a fully custom layout. Data-table features such as built-in sort controls,
filters, grouping, editing, and spans are P1 or application policy.

## Responsibility split

| Layer | Responsibility |
| --- | --- |
| Alicorn | Grid tracks, virtual list, semantic collections, grid/table roles, focus, pointer hit testing, and `semantic_collection_virtual_item`. |
| `table` | Column track mapping, header/body composition, nested row/cell collections, cell coordinates, roving row focus with a column coordinate, reveal, and one activation event. |
| Application | Columns, rows, stable keys, sorting, filtering, selection, cell formatting, and data lifetime. |

The component stores only ephemeral focus and proposal state. It publishes
`Selected` from the application's `Selection`, but never mutates it.

## Copyable implementation

Files: `table/table.odin`, `table/table_test.odin`,
`examples/table/main.odin`, `examples/table/theme.json`.

```odin
import table "alikit:table"

if event := table.table(
	ctx,
	&app.table_state,
	app.columns[:],
	app.visible_rows[:], // application-filtered and sorted
	app.selection,
	table.Options{accessible_label="Documents", row_header=true, max_visible_rows=10},
	key=alicorn.key_string("documents"),
	instance_id=1,
); event.kind == .Activated {
	app.selection = table.Selection{row_key=event.row_key, column_key=event.column_key}
}
```

No init or destroy is required; the component allocates nothing. Call
`table.request_focus(&state)` to focus the single Tab stop.

## Parts and identities

| Part | Identity | What can be omitted or replaced |
| --- | --- | --- |
| Table | `table_semantic_id(instance_id)` | Always present. It is the `Table` collection and one Tab stop. |
| Header row | `header_row_semantic_id(instance_id)` | Omit with `Options.hide_header`. It is logical position 0 when present. |
| Header cell | `header_cell_semantic_id(instance_id, column_key)` | Each column publishes `Table_Column_Header` at its column position. |
| Body row | `row_semantic_id(instance_id, row_key)` | Application row slice. A realized row is a nested `Table_Row` collection. |
| Body cell | `cell_semantic_id(instance_id, row_key, column_key)` | `Table_Cell`, or `Table_Row_Header` for the first column when `row_header` is set. |

Column keys and row keys must be nonzero and unique within one table. Cells use
`position_in_set` as the column coordinate; header cells are position 0..N-1 in
the header row and body cells are 0..N-1 in their row. A header row is logical
row 0, so a body row at application index `i` is at table position `i+1`.

Virtualized rows outside the realized window are published with
`semantic_collection_virtual_item` as `Table_Row` items, so assistive technology
sees a bounded realized node set plus the logical row count. The total table
`logical_count` is `row_count + (header ? 1 : 0)`.

Column widths use the existing Grid tracks: a positive `Column.width` becomes a
fixed track (optionally `min_max`), and `width <= 0` becomes an equal fraction.
`MAX_COLUMNS` is 64. Spans are intentionally deferred: v1 emits one cell per
column with no `column_span`.

## Styling, motion, and theme

`Recipe` declares four optional namespaced surface roles:

| Field | Core fallback |
| --- | --- |
| `header_surface_role` | `Subtle_Surface` |
| `row_surface_role` | `Surface` |
| `selected_row_surface_role` | `Selection` |
| `selected_cell_surface_role` | `Selection` |

Zero roles need no theme registration. Configured roles are validated with
`theme_contract_default`, `theme_contract_check`,
`theme_contract_satisfied`, and `theme_contract_missing_required`. The example
registers `vendor.alikit.table.*`. A configured but unresolved role falls back
to the core role at render time after setup validation.

`Style` carries corner radius, focus outline width, and the selected-cell
outline. `Options` carries header/row height, visible rows, column gap, cell
padding, and text sizes. Selection is shown by the row fill + selected-cell
surface + focus outline, not color alone. There is no table animation; roving
focus and reveal are immediate.

## Keyboard and accessibility contract

- **Tab** reaches the table once. Body cells are not separate Tab stops.
- **Up/Down** move the focused row, skipping disabled rows and preserving the
  column. **Page Up/Page Down** move by `max_visible_rows` and clamp to the
  first/last enabled row.
- **Left/Right** move the cell coordinate within the focused row.
  **Home/End** move to the first/last column of that row.
- **Return/Space** activate the focused cell. Pointer activation of a cell and
  semantic activation of the table's roving cell use the same proposal path.
  (Semantic activation targets the table's stable collection item; cell roles do
  not advertise `Press`/`Select` because Alicorn has no realized cell-action
  mapping.)
- Disabled rows publish `Disabled`, their cells do not activate, and row
  navigation skips the whole row.
- The table publishes `Table`, its accessible name, logical row count,
  `selected_id` (selected row), and `current_id` (active row). Rows publish
  `Table_Row` with the row-header/first-cell label, `Selected`, `Current`, and
  `Disabled` as applicable. Header cells publish `Table_Column_Header`; body
  cells publish `Table_Cell`/`Table_Row_Header`, text value, description, and
  column coordinate.
- Focus stays on the table owner; the cell coordinate changes through the
  roving model. A cell's visual node is an ordinary Button owner for hit
  testing, but its published semantic role is the table role.
- Not claimed: cell spans, cell editing, multi-select, column resizing,
  column/row reorder, built-in sorting/filtering, or a tree table.

## Conformance tests

`table/table_test.odin` covers:

- stable table/row/cell identities, column track mapping, and the theme
  contract;
- `Table` logical count, header cells and positions, nested row collections,
  `Table_Row_Header`, selected cell coordinates, and selected/current states;
- Up skipping a disabled row while preserving the column, Down, Home/End
  columns, Return activation, and pointer activation parity;
- disabled row semantics and rejection;
- 200-row virtualization: the last row starts as a virtual semantic item, then
  Page Down + reveal realizes it, with logical count 201;
- the example smoke path with a real 120-row dataset.

There is no `testui` table pattern at the pinned revision. `.Roving_List` and
`.Roving_Grid` require a `List_Box` container, while a table must publish
`Table` and nested `Table_Row` collections. A table pattern is a recorded core
candidate; v1 uses explicit drive assertions.

## Limits

- Headless tests do not prove a native screen-reader table session, pixels, or
  physical cell navigation. Native smoke runs SDL_GPU D3D12 startup.
- Non-spanned cells only. Row/cell spans need a coordinated core semantic and
  layout contract and are deferred.
- Columns are capped at 64. Callers with wider data should project the visible
  subset or wait for a supported span/column policy.
- Sorting and filtering are application callbacks; the table only sees the
  projection. Stable row keys must survive that projection.
- A virtual row's cells are not published until it is realized. Assistive
  technology can request the row, but per-cell values for unrealized rows are
  not exported.

## Source map

- [Package](../table/table.odin)
- [Tests](../table/table_test.odin)
- [Example](../examples/table/main.odin)
- [Theme JSON](../examples/table/theme.json)
