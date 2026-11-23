package table_core

// Table Core is the shared presentation layer for `alikit:table` (static) and
// `alikit:data_grid` (interactive). It owns the data shapes both components
// expose (Column, Cell, Row, Alignment, Sort_State), column-track computation,
// header surface/row/cell scaffolding, cell semantic scaffolding, and the
// common surface fallback helpers.
//
// It deliberately owns no focus, selection, roving, activation, sorting, or
// filtering policy. Table is static; data_grid keeps its managed focus and
// proposals. Sharing presentation keeps the two components' semantics aligned
// without merging their interaction layers.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"

MAX_COLUMNS :: 64

Alignment :: enum { Start, Center, End }

// Sort_State is presentation input only. The application owns the comparator
// and projected row order; data_grid publishes the requested direction on the
// header and proposes a change when a sortable header activates. Table leaves
// it at .None.
Sort_State :: enum { None, Ascending, Descending }

Column :: struct {
	// key is the stable application column identity. It must be nonzero and
	// unique within one table/grid.
	key:   u64,
	label: string,
	// width <= 0 requests an equal fraction of the remaining width. A positive
	// value is a fixed logical-pixel track.
	width:     f32,
	// min_width is optional; zero leaves the grid track unconstrained.
	min_width: f32,
	align:     Alignment,
	// sortable and sort are used by data_grid; table ignores them.
	sortable: bool,
	sort:     Sort_State,
}

Cell :: struct {
	text:   string,
	// detail is an optional secondary line. It participates in intrinsic row
	// height for the static table and is published as the cell description.
	detail: string,
	// icon is optional inline formatting before the text. Zero omits it.
	icon: Maybe(alicorn.Icon_ID),
	// color_role overrides the primary text color for this cell. Zero uses the
	// row default (Text, or Muted_Text for a disabled row).
	color_role: alicorn.Style_Color_Role,
}

Row :: struct {
	// key is the stable application row identity. It must be nonzero and
	// unique within one table/grid.
	key:      u64,
	cells:    []Cell,
	disabled: bool,
}

grid_alignment :: proc(align: Alignment) -> alicorn.Grid_Item_Alignment {
	switch align {
	case .Start: return .Start
	case .Center: return .Center
	case .End: return .End
	}
	return .Start
}

row_justify :: proc(align: Alignment) -> alicorn.Main_Axis_Distribution {
	switch align {
	case .Start: return .Start
	case .Center: return .Center
	case .End: return .End
	}
	return .Start
}

column_align :: proc(align: Alignment) -> alicorn.Align {
	switch align {
	case .Start: return .Start
	case .Center: return .Center
	case .End: return .End
	}
	return .Start
}

@(private)
flexible_width :: proc(width: f32) -> bool {
	return !(width > 0 && !math.is_nan(width) && !math.is_inf(width))
}

// tracks_for fills shared Grid tracks from the caller's columns. Flexible
// columns get an equal fraction; fixed columns keep their width and optional
// min/max constraint. It returns the number of tracks written.
tracks_for :: proc(columns: []Column, tracks: []alicorn.Grid_Track) -> int {
	count := min(len(columns), len(tracks))
	for column, index in columns[:count] {
		if !flexible_width(column.width) {
			tracks[index] = alicorn.grid_fixed(column.width)
			if column.min_width > 0 {
				tracks[index] = alicorn.grid_min_max(min(column.min_width, column.width), column.width)
			}
		} else {
			tracks[index] = alicorn.grid_fraction(1)
		}
	}
	return count
}

cell_at :: proc(row: Row, column: int) -> Cell {
	if column < 0 || column >= len(row.cells) { return {} }
	return row.cells[column]
}

row_label :: proc(row: Row) -> string {
	if len(row.cells) == 0 { return "Row" }
	return row.cells[0].text
}

// begin_surface opens an optional namespaced extension surface, falling back
// to the documented core role. Both components use the same fallback rule.
begin_surface :: proc(
	ctx: ^ui.UI,
	role: alicorn.Style_Extension_Color_Role_ID,
	fallback: alicorn.Style_Color_Role,
	key: ui.UI_Key,
	style: alicorn.Layout_Style,
	shape: alicorn.Surface_Shape,
	stroke: alicorn.Paint_Stroke,
	label: string,
) -> alicorn.Node_ID {
	if role != 0 {
		if id := alicorn.surface_begin(ctx, alicorn.surface_extension_color_role(role),
			key=key, style=style, shape=shape, stroke=stroke, label=label); id != 0 {
			return id
		}
	}
	return alicorn.surface_begin(ctx, alicorn.surface_core_color_role(fallback),
		key=key, style=style, shape=shape, stroke=stroke, label=label)
}

// column_cell_layout is the static table's flow cell layout inside one column
// track. data_grid keeps its own fixed-row cell layout.
column_cell_layout :: proc(column: Column, padding, height: f32) -> alicorn.Layout_Style {
	flexible := flexible_width(column.width)
	return ui.layout_style(.Column,
		width=(f32(-1) if flexible else column.width),
		height=height,
		grow=(f32(1) if flexible else f32(0)),
		padding=padding,
		gap=2,
		justify=.Center,
		align=column_align(column.align),
	)
}

Header_Layout :: enum { Flow, Grid }

Header_Config :: struct {
	layout:       Header_Layout,
	columns:      []Column,
	// tracks is required for Header_Layout.Grid and ignored for Flow.
	tracks:       []alicorn.Grid_Track,
	height:       f32,
	column_gap:   f32,
	cell_padding: f32,
	text_size:    f32,
	corner_radius: f32,
	row_label:    string,
	surface_role: alicorn.Style_Extension_Color_Role_ID,
	// row_key and cells_key key the header surface and row container.
	row_key:      ui.UI_Key,
	cells_key:    ui.UI_Key,
}

Header :: struct {
	ctx:        ^ui.UI,
	config:     Header_Config,
	parent:     alicorn.Semantic_Collection_Handle,
	collection: alicorn.Semantic_Collection_Handle,
	surface:    alicorn.Node_ID,
	row:        alicorn.Node_ID,
	open:       bool,
}

// header_begin opens the shared header surface and a Table_Row collection with
// Table_Column_Header cells. row_id names the header row; the component keeps
// its own namespace identity. It publishes the header row to `parent` at
// logical position zero. Close it with header_end.
header_begin :: proc(
	ctx: ^ui.UI,
	config: Header_Config,
	parent: alicorn.Semantic_Collection_Handle,
	row_id: alicorn.Semantic_ID,
) -> (header: Header, visible: bool) {
	if ctx == nil || ctx.runtime == nil || len(config.columns) == 0 || len(config.columns) > MAX_COLUMNS { return }
	if row_id.namespace == 0 || parent.id.namespace == 0 { return }
	surface := begin_surface(
		ctx,
		config.surface_role,
		.Subtle_Surface,
		key=config.row_key,
		style=ui.layout_style(.Column, width=-1, height=config.height),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=config.corner_radius},
		stroke={},
		label="table-header-row",
	)
	if surface == 0 { return }
	collection := alicorn.semantic_collection_begin(
		ctx,
		surface,
		row_id,
		.Table_Row,
		config.row_label,
		u64(len(config.columns)),
		realized_first=0,
		realized_last=u64(len(config.columns)),
		parent=parent.id,
	)
	if collection.id.namespace == 0 {
		alicorn.surface_end(ctx)
		return
	}
	_ = alicorn.semantic_collection_item(ctx, parent, 0, alicorn.Semantic_Node_Description{
		id=row_id,
		role=.Table_Row,
		label=config.row_label,
		parent=parent.id,
		visual_node=surface,
	})
	row: alicorn.Node_ID
	switch config.layout {
	case .Flow:
		row = alicorn.container_begin(
			ctx,
			.Container,
			label="table-header-row-cells",
			key=config.cells_key,
			style=ui.layout_style(.Row, width=-1, height=-1, gap=config.column_gap, align=.Stretch),
		)
	case .Grid:
		auto_rows := [1]alicorn.Grid_Track{alicorn.grid_auto()}
		row = alicorn.grid_begin(ctx, config.cells_key, config.tracks, auto_rows[:],
			style=ui.layout_style(.Row, width=-1, height=config.height),
			gap_x=config.column_gap, gap_y=0, label="grid-header-grid")
	}
	if row == 0 {
		alicorn.surface_end(ctx)
		return
	}
	header = Header{
		ctx=ctx,
		config=config,
		parent=parent,
		collection=collection,
		surface=surface,
		row=row,
		open=true,
	}
	return header, true
}

Header_Cell :: struct {
	header:    ^Header,
	column:    Column,
	index:     int,
	owner:     alicorn.Node_ID,
	sortable:  bool,
	activated: bool,
}

// header_cell_begin opens one header cell, publishes Table_Column_Header
// semantics, and returns the cell context. sortable opens a Button owner and
// advertises Press; non-sortable headers use a plain container. description is
// the optional sort-state description. Call header_cell_label, then
// header_cell_end.
header_cell_begin :: proc(
	ctx: ^ui.UI,
	header: ^Header,
	column_index: int,
	id: alicorn.Semantic_ID,
	sortable: bool = false,
	description: string = "",
) -> (cell: Header_Cell, visible: bool) {
	if ctx == nil || ctx.runtime == nil || header == nil || !header.open { return }
	if column_index < 0 || column_index >= len(header.config.columns) { return }
	if id.namespace == 0 { return }
	column := header.config.columns[column_index]
	flow_style := column_cell_layout(column, header.config.cell_padding, -1)
	grid_style := ui.layout_style(.Row, width=-1, height=header.config.height,
		padding=header.config.cell_padding, justify=row_justify(column.align), align=.Center)
	style := flow_style
	if header.config.layout == .Grid { style = grid_style }
	owner: alicorn.Node_ID
	activated := false
	if sortable {
		owner, activated = alicorn.button_begin(
			ctx,
			column.label,
			key=ui.key_pair(0xA11C_6A03, column.key),
			style=style,
			presentation=.Custom,
			focusable=false,
		)
	} else {
		owner = alicorn.container_begin(ctx, .Container, label="table-header-cell",
			key=ui.key_pair(0xA11C_6A03, column.key), style=style)
	}
	if owner == 0 { return }
	actions := alicorn.Semantic_Actions{}
	if sortable { actions = alicorn.semantic_actions_add(actions, .Press) }
	_ = alicorn.semantic_collection_item(ctx, header.collection, u64(column_index),
		alicorn.Semantic_Node_Description{
			id=id,
			role=.Table_Column_Header,
			label=column.label,
			description=description,
			value=column.label,
			actions=actions,
			visual_node=owner,
		})
	cell = Header_Cell{
		header=header,
		column=column,
		index=column_index,
		owner=owner,
		sortable=sortable,
		activated=activated,
	}
	return cell, true
}

// header_cell_label draws the shared semibold, ellipsized header label.
header_cell_label :: proc(ctx: ^ui.UI, cell: Header_Cell) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || cell.header == nil { return 0 }
	style: alicorn.Layout_Style = ui.layout_style(.Column)
	if cell.header.config.layout == .Grid { style = ui.layout_style(.Row) }
	return ui.text(ctx, cell.column.label,
		key=ui.key_pair(0xA11C_6A04, cell.column.key),
		style=style,
		size=cell.header.config.text_size,
		color=alicorn.style_color(ctx, .Muted_Text),
		decorative=true,
		text_style=alicorn.Text_Style{overflow=.Ellipsis, font_weight=alicorn.FONT_WEIGHT_SEMIBOLD},
	)
}

// header_cell_end closes the cell owner. In Grid layout it also places the cell
// at its column coordinate.
header_cell_end :: proc(ctx: ^ui.UI, cell: Header_Cell) {
	if ctx == nil || cell.owner == 0 || cell.header == nil { return }
	if cell.sortable {
		alicorn.button_end(ctx)
	} else {
		alicorn.container_end(ctx)
	}
	if cell.header.config.layout == .Grid {
		_ = alicorn.grid_cell(ctx, cell.owner, 0, cell.index, align_x=grid_alignment(cell.column.align))
	}
}

header_end :: proc(ctx: ^ui.UI, header: ^Header) {
	if ctx == nil || header == nil || !header.open { return }
	switch header.config.layout {
	case .Flow:
		alicorn.container_end(ctx)
	case .Grid:
		alicorn.grid_end(ctx)
	}
	alicorn.surface_end(ctx)
	header.open = false
}

// body_cell_role selects Table_Row_Header for an opt-in row header column.
body_cell_role :: proc(column_index: int, row_header: bool) -> alicorn.Semantic_Role {
	if column_index == 0 && row_header { return .Table_Row_Header }
	return .Table_Cell
}

// cell_description builds the shared body-cell semantic record. Components
// keep their own stable IDs and states; this helper only removes duplicated
// shape wiring.
cell_description :: proc(
	id: alicorn.Semantic_ID,
	role: alicorn.Semantic_Role,
	text, detail: string,
	states: alicorn.Semantic_States,
	visual_node: alicorn.Node_ID = 0,
) -> alicorn.Semantic_Node_Description {
	return alicorn.Semantic_Node_Description{
		id=id,
		role=role,
		label=text,
		description=detail,
		value=text,
		states=states,
		visual_node=visual_node,
	}
}
