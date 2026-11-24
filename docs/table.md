# Table

`alikit:table` is a static, composable, non-spanned presentation table. It is
for read-oriented data: intrinsic row heights, wrapped cell text, inline
icon/detail formatting, alignment, headers, and optional fixed-row
virtualization. It owns **no** managed cell focus, selection, roving
navigation, or activation. Use [Data Grid](data-grid.md) when the table is an
interactive dataset.

Both components use Alicorn's compound `Table` / `Table_Row` / `Table_Cell`
roles. Alicorn's pinned `Semantic_Role` enum has no `Grid`/`Grid_Cell`; the
grid-role question is recorded for an Alicorn-side addition rather than
invented here.

## Responsibility split

| Layer | Responsibility |
| --- | --- |
| Alicorn | Layout, text shaping, semantic collections, table roles, virtual list, theme roles, pointer/focus primitives. |
| `table_core` | Shared `Column`/`Cell`/`Row`/`Alignment` shapes, column-track computation, header surface/row/cell scaffolding, cell semantic scaffolding, and core-role surface fallback. |
| `table` | Static body composition, nested table/row/cell collections, intrinsic row height measurement, wrapped cells, optional virtualization, theme contract. |
| Application | Columns, rows, stable keys, sorting/filtering, data lifetime, formatting, document navigation policy. |

The component keeps no state and allocates nothing. It borrows `columns` and
`rows` for the call. `alikit:table_core` is the shared presentation package also
used by [Data Grid](data-grid.md); it owns no focus, selection, or activation
policy.

## Copyable implementation

Files: `table/table.odin`, `table/table_test.odin`, `examples/table/main.odin`,
`examples/table/theme.json`.

```odin
import table "alikit:table"

table.table(
	ctx,
	app.columns[:],
	app.projection[:app.visible_count],
	table.Options{
		accessible_label="Documents",
		row_header=true,
		alternate_rows=true,
		max_visible_rows=10,
		measure_width=680,
	},
	key=alicorn.key_string("documents"),
	instance_id=1,
	recipe=app.table_recipe,
)
```

No init or destroy is required. Call `table.theme_contract_default`,
`theme_contract_check`, and `theme_contract_missing_required` once after theme
registration.

## Parts and identities

| Part | Identity | What can be omitted or replaced |
| --- | --- | --- |
| Table | `table_semantic_id(instance_id)` | Always present. It is the `Table` collection. |
| Header row | `header_row_semantic_id(instance_id)` | Omit with `Options.hide_header`. Logical row 0 when present. |
| Header cell | `header_cell_semantic_id(instance_id, column_key)` | Publishes `Table_Column_Header`. |
| Body row | `row_semantic_id(instance_id, row_key)` | Application row slice; nested `Table_Row` collection. |
| Body cell | `cell_semantic_id(instance_id, row_key, column_key)` | `Table_Cell`, or `Table_Row_Header` for the first column. |

Column keys and row keys must be nonzero and unique within one table. A body
row at application index `i` is logical position `i+1` when a header exists.
`MAX_COLUMNS` is 64; spans are not implemented. `Column`, `Cell`, `Row`, and
`Alignment` are aliases of `alikit:table_core` shapes. `Column` also carries the
shared optional `sortable`/`sort` fields; Table ignores them.

The component publishes no `Selected`, `Current`, or `Focus`-driven cell state.
Rows publish `Disabled` when the application marks them disabled.

## Styling, motion, and theme

`Recipe` declares three optional namespaced surface roles:

| Field | Core fallback |
| --- | --- |
| `header_surface_role` | `Subtle_Surface` |
| `row_surface_role` | `Surface` |
| `alternate_row_surface_role` | `Subtle_Surface` |

Zero roles need no registration. Configured roles are validated with the
`theme_contract_*` helpers; an unresolved configured role falls back to the core
role at render time.

`Style` carries the header corner radius and divider width. `Options` carries
header height, cell padding, column gap, text sizes, wrapping, alternating rows,
and optional virtualization. There is no animation; layout is immediate.

**Intrinsic rows.** When `Options.no_wrap` is false (the default), the component
measures primary and detail text at the column's resolved width and authors the
row height so wrapped text and secondary lines are not clipped. Fixed columns
use their declared width; flexible columns use the equal share of
`Options.measure_width`. This is deterministic but assumes the table's final
width is close to `measure_width`; set it to the intended container width.
`Options.no_wrap` keeps each cell to one ellipsized line.

Virtualization is opt-in (`Options.virtualize` with `max_visible_rows` and
`virtual_row_height`) because intrinsic measurement requires all rows to be
described. Virtualized rows use Alicorn's fixed-row virtual list and publish
unrealized rows as virtual `Table_Row` semantic items.

## Keyboard and accessibility contract

- The table is one ordinary focusable container. There is **no** cell
  navigation, no roving focus, and no Tab stop per cell.
- Arrow keys are not consumed by this component. Wrapping the table in
  `alikit:scroll_area` gives the region its keyboard scrolling contract.
- Header cells publish `Table_Column_Header`; the first body column publishes
  `Table_Row_Header` when `row_header` is set; other cells publish
  `Table_Cell` with text, detail description, and column position.
- The collection publishes its accessible name, logical count (header + rows),
  and realized window.
- Not claimed: sort controls, selection, activation, editing, spans, column
  resizing/reordering, or built-in filtering. Implement those with
  `alikit:data_grid` or application policy.
- Static text selection is not implemented. Alicorn exposes retained text
  selection for text owners; selecting arbitrary document table text would
  require an application-owned selection model, so it is recorded as a limit
  rather than silently claimed.

## Conformance tests

`table/table_test.odin` covers:

- stable table/row/cell identities and column track mapping;
- the theme contract and missing-role diagnostics;
- `Table` logical count, header positions, row/cell roles, and absence of
  selected/current state;
- intrinsic row growth for a wrapped cell with a detail line;
- optional fixed-row virtualization and wheel reveal of the last logical row;
- an idle smoke path through `examples/table` on real SDL_GPU D3D12.

There is no `testui` static-table pattern at the pinned revision. Explicit
drive assertions cover the contract.

## Limits

- Headless tests do not prove a physical screen-reader table session, pixels, or
  native table navigation commands.
- Wrapped flexible columns are measured against `Options.measure_width`; a very
  different final width can make the authored intrinsic height conservative.
- Non-spanned only. Virtualized rows do not publish their cells until realized.
- Sorting and filtering remain application callbacks over the caller's
  projection.

## Source map

- [Package](../table/table.odin)
- [Shared presentation](../table_core/table_core.odin)
- [Tests](../table/table_test.odin)
- [Example](../examples/table/main.odin)
- [Theme JSON](../examples/table/theme.json)
