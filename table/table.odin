package table

// Table is the STATIC table: a read-oriented, non-spanned presentation table
// over Alicorn's compound table roles. It owns shared column tracks, header
// cells, nested Table -> Table_Row -> cell collections, intrinsic row heights,
// wrapped cell text, and optional fixed-row virtualization. It deliberately
// owns NO managed focus, NO selection, NO roving cell navigation, and NO
// activation event. Navigation is ordinary document navigation (Tab, the
// application's own shortcuts, and assistive-technology table navigation).
//
// Use `alikit:data_grid` instead when the table is an interactive dataset that
// needs one Tab stop, roving cell focus, row/cell selection, and activation.
//
// Column and row keys are stable application identities. The component never
// mutates application data and allocates nothing.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import tc "alikit:theme_contract"

TABLE_NAMESPACE :: u64(0x5441424C45303101) // "TABLE01"
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)
MAX_COLUMNS :: 64
CELL_KEY :: u64(0xA11C_6A01)

Alignment :: enum { Start, Center, End }

Column :: struct {
	// key is the stable application column identity. It must be nonzero and
	// unique within one table.
	key:   u64,
	label: string,
	// width <= 0 requests an equal fraction of the remaining width. A positive
	// value is a fixed logical-pixel track.
	width:     f32,
	// min_width is optional; zero leaves the grid track unconstrained.
	min_width: f32,
	align:     Alignment,
}

Cell :: struct {
	text:   string,
	// detail is an optional secondary line. It participates in intrinsic row
	// height and is published as the cell's semantic description.
	detail: string,
	// icon is optional inline formatting before the text. Zero omits it.
	icon: Maybe(alicorn.Icon_ID),
	// color_role overrides the primary text color for this cell. Zero uses the
	// row default (Text, or Muted_Text for a disabled row).
	color_role: alicorn.Style_Color_Role,
}

Row :: struct {
	// key is the stable application row identity. It must be nonzero and
	// unique within one table.
	key:      u64,
	cells:    []Cell,
	disabled: bool,
}

Options :: struct {
	accessible_label: string,
	empty_label:      string,
	// hide_header opts out of the header row; the default keeps it visible for
	// a partial Options value.
	hide_header: bool,
	// row_header publishes Table_Row_Header for the first column in body rows.
	row_header:  bool,
	header_height: f32,
	// row_padding and cell_padding are inner cell spacing. Intrinsic rows grow
	// with wrapped text and optional detail lines.
	row_padding:   f32,
	column_gap:    f32,
	cell_padding:  f32,
	header_text_size: f32,
	cell_text_size:   f32,
	detail_text_size: f32,
	// no_wrap keeps each cell to one ellipsized line. The default wraps primary
	// and detail text inside their column track and grows the row height.
	no_wrap: bool,
	// alternate_rows tints every second body row with Recipe.alternate_row_surface_role.
	alternate_rows: bool,
	// virtualize emits a fixed-row virtual window instead of every row. It is
	// opt-in because intrinsic row heights require all rows to be measured.
	virtualize:       bool,
	max_visible_rows: int,
	virtual_row_height: f32,
	// measure_width resolves flexible columns for intrinsic text measurement.
	// Fixed columns use their declared width.
	measure_width: f32,
	row_min_height: f32,
}

DEFAULT_OPTIONS :: Options{
	accessible_label="Table",
	empty_label="No rows",
	header_height=32,
	row_padding=8,
	column_gap=0,
	cell_padding=8,
	header_text_size=12,
	cell_text_size=13,
	detail_text_size=11,
	max_visible_rows=8,
	virtual_row_height=40,
	measure_width=480,
	row_min_height=24,
}

Recipe :: struct {
	header_surface_role:          alicorn.Style_Extension_Color_Role_ID,
	row_surface_role:             alicorn.Style_Extension_Color_Role_ID,
	alternate_row_surface_role:   alicorn.Style_Extension_Color_Role_ID,
	// divider_role is a core role because the runtime owns the row separator.
	divider_role: alicorn.Style_Color_Role,
}

Style :: struct {
	corner_radius:    f32,
	divider_width:    f32,
}

DEFAULT_STYLE :: Style{
	corner_radius=6,
	divider_width=1,
}

Theme_Contract :: tc.Contract
Theme_Contract_Report :: tc.Report

recipe_default :: proc() -> Recipe { return {} }
style_default :: proc() -> Style { return DEFAULT_STYLE }

theme_contract_default :: proc(recipe: Recipe) -> Theme_Contract {
	contract: Theme_Contract
	_ = role_requirement(&contract, recipe.header_surface_role, "alikit.table.header_surface")
	_ = role_requirement(&contract, recipe.row_surface_role, "alikit.table.row_surface")
	_ = role_requirement(&contract, recipe.alternate_row_surface_role, "alikit.table.alternate")
	return contract
}

@(private)
role_requirement :: proc(contract: ^Theme_Contract, role: alicorn.Style_Extension_Color_Role_ID, name: string) -> bool {
	if role == 0 { return tc.optional_role(contract, 0, name) }
	return tc.required_role(contract, role, name)
}

theme_contract_check :: proc(rt: ^alicorn.Runtime, theme: alicorn.Style_Theme_ID, contract: Theme_Contract) -> Theme_Contract_Report {
	return tc.check(rt, theme, contract)
}

theme_contract_satisfied :: proc(report: Theme_Contract_Report) -> bool {
	return tc.satisfied(report)
}

theme_contract_missing_required :: proc(contract: Theme_Contract, report: Theme_Contract_Report) -> (names: [tc.MAX_ROLES]string, count: int) {
	search := 0
	for count < len(names) {
		name, index, found := tc.missing_name(contract, report, search)
		if !found { break }
		names[count] = name
		count += 1
		search = index+1
	}
	return
}

@(private)
mix :: proc(seed, value: u64) -> u64 {
	state := seed+value+0x9E3779B97F4A7C15
	state = (state ~ (state>>30))*0xBF58476D1CE4E5B9
	state = (state ~ (state>>27))*0x94D049BB133111EB
	return state ~ (state>>31)
}

table_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=TABLE_NAMESPACE, value=mix(instance_id, 0x5441424C)}
}

header_row_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=TABLE_NAMESPACE, value=mix(instance_id, 0x48454144)}
}

header_cell_semantic_id :: proc(instance_id, column_key: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || column_key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=TABLE_NAMESPACE, value=mix(instance_id, column_key ~ 0x48454144)}
}

row_semantic_id :: proc(instance_id, row_key: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || row_key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=TABLE_NAMESPACE, value=mix(instance_id, row_key)}
}

cell_semantic_id :: proc(instance_id, row_key, column_key: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || row_key == 0 || column_key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=TABLE_NAMESPACE,
		value=mix(mix(instance_id, row_key), column_key ~ 0x43454C4C)}
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.empty_label == "" { result.empty_label = DEFAULT_OPTIONS.empty_label }
	if result.header_height <= 0 || math.is_nan(result.header_height) || math.is_inf(result.header_height) {
		result.header_height = DEFAULT_OPTIONS.header_height
	}
	if result.row_padding < 0 || math.is_nan(result.row_padding) || math.is_inf(result.row_padding) {
		result.row_padding = DEFAULT_OPTIONS.row_padding
	}
	if result.column_gap < 0 || math.is_nan(result.column_gap) || math.is_inf(result.column_gap) {
		result.column_gap = DEFAULT_OPTIONS.column_gap
	}
	if result.cell_padding < 0 || math.is_nan(result.cell_padding) || math.is_inf(result.cell_padding) {
		result.cell_padding = DEFAULT_OPTIONS.cell_padding
	}
	if result.header_text_size <= 0 { result.header_text_size = DEFAULT_OPTIONS.header_text_size }
	if result.cell_text_size <= 0 { result.cell_text_size = DEFAULT_OPTIONS.cell_text_size }
	if result.detail_text_size <= 0 { result.detail_text_size = DEFAULT_OPTIONS.detail_text_size }
	if result.max_visible_rows <= 0 { result.max_visible_rows = DEFAULT_OPTIONS.max_visible_rows }
	if result.virtual_row_height <= 0 || math.is_nan(result.virtual_row_height) || math.is_inf(result.virtual_row_height) {
		result.virtual_row_height = DEFAULT_OPTIONS.virtual_row_height
	}
	if result.measure_width <= 0 || math.is_nan(result.measure_width) || math.is_inf(result.measure_width) {
		result.measure_width = DEFAULT_OPTIONS.measure_width
	}
	if result.row_min_height <= 0 || math.is_nan(result.row_min_height) || math.is_inf(result.row_min_height) {
		result.row_min_height = DEFAULT_OPTIONS.row_min_height
	}
	return result
}

@(private)
style_resolve :: proc(style: Style) -> Style {
	result := style
	if result.corner_radius < 0 || math.is_nan(result.corner_radius) || math.is_inf(result.corner_radius) {
		result.corner_radius = DEFAULT_STYLE.corner_radius
	}
	if result.divider_width < 0 || math.is_nan(result.divider_width) || math.is_inf(result.divider_width) {
		result.divider_width = DEFAULT_STYLE.divider_width
	}
	return result
}

@(private)
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

@(private)
grid_alignment :: proc(align: Alignment) -> alicorn.Grid_Item_Alignment {
	switch align {
	case .Start: return .Start
	case .Center: return .Center
	case .End: return .End
	}
	return .Start
}

@(private)
row_justify :: proc(align: Alignment) -> alicorn.Main_Axis_Distribution {
	switch align {
	case .Start: return .Start
	case .Center: return .Center
	case .End: return .End
	}
	return .Start
}

@(private)
cell_at :: proc(row: Row, column: int) -> Cell {
	if column < 0 || column >= len(row.cells) { return {} }
	return row.cells[column]
}

@(private)
row_label :: proc(row: Row) -> string {
	if len(row.cells) == 0 { return "Row" }
	return row.cells[0].text
}

@(private)
tracks_for :: proc(columns: []Column, tracks: []alicorn.Grid_Track) -> int {
	count := min(len(columns), len(tracks))
	for column, index in columns[:count] {
		if column.width > 0 && !math.is_nan(column.width) && !math.is_inf(column.width) {
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

@(private)
column_align :: proc(align: Alignment) -> alicorn.Align {
	switch align {
	case .Start: return .Start
	case .Center: return .Center
	case .End: return .End
	}
	return .Start
}

@(private)
cell_layout :: proc(column: Column, padding: f32, height: f32) -> alicorn.Layout_Style {
	flexible := !(column.width > 0 && !math.is_nan(column.width) && !math.is_inf(column.width))
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

@(private)
measure_text_height :: proc(rt: ^alicorn.Runtime, value: string, size: f32, width: f32) -> f32 {
	if value == "" || size <= 0 { return 0 }
	run, ok := alicorn.runtime_text_run_build(rt, value, size, width, overflow=.Wrap)
	if !ok { return size*1.4 }
	height := run.height
	alicorn.text_run_destroy(&run)
	return height
}

@(private)
flex_measure_width :: proc(columns: []Column, options: Options) -> f32 {
	fixed_total: f32 = 0
	flex_count := 0
	for column in columns {
		if column.width > 0 && !math.is_nan(column.width) && !math.is_inf(column.width) {
			fixed_total += column.width
		} else {
			flex_count += 1
		}
	}
	if flex_count == 0 { return 0 }
	return max((options.measure_width-fixed_total)/f32(flex_count), 48)
}

@(private)
column_measure_width :: proc(column: Column, flex_width: f32) -> f32 {
	if column.width > 0 && !math.is_nan(column.width) && !math.is_inf(column.width) {
		return column.width
	}
	return flex_width
}

@(private)
row_intrinsic_height :: proc(
	ctx: ^ui.UI,
	row: Row,
	columns: []Column,
	options: Options,
) -> f32 {
	if options.no_wrap {
		return max(options.row_min_height,
			f32(2)*options.cell_padding+options.cell_text_size*1.35)
	}
	flex_width := flex_measure_width(columns, options)
	height := options.row_min_height
	for column, index in columns {
		cell := cell_at(row, index)
		cell_width := column_measure_width(column, flex_width)-2*options.cell_padding
		content: f32 = 0
		if _, has_icon := cell.icon.?; has_icon { content = max(content, options.cell_text_size+3) }
		content += measure_text_height(ctx.runtime, cell.text, options.cell_text_size, max(cell_width, 16))
		if cell.detail != "" {
			content += 2+measure_text_height(ctx.runtime, cell.detail, options.detail_text_size, max(cell_width, 16))
		}
		height = max(height, content+2*options.cell_padding)
	}
	return height
}

@(private)
emit_header_cell :: proc(
	ctx: ^ui.UI,
	column: Column,
	column_index: int,
	collection: alicorn.Semantic_Collection_Handle,
	instance_id: u64,
	options: Options,
) {
	key := ui.key_pair(CELL_KEY+3, column.key)
	cell := alicorn.container_begin(
		ctx,
		.Container,
		label="table-header-cell",
		key=key,
		style=cell_layout(column, options.cell_padding, -1),
	)
	if cell == 0 { return }
	_ = alicorn.semantic_collection_item(ctx, collection, u64(column_index), alicorn.Semantic_Node_Description{
		id=header_cell_semantic_id(instance_id, column.key),
		role=.Table_Column_Header,
		label=column.label,
		value=column.label,
	})
	_ = ui.text(ctx, column.label,
		key=ui.key_pair(CELL_KEY+4, column.key),
		style=ui.layout_style(.Column),
		size=options.header_text_size,
		color=alicorn.style_color(ctx, .Muted_Text),
		decorative=true,
		text_style=alicorn.Text_Style{overflow=.Ellipsis, font_weight=alicorn.FONT_WEIGHT_SEMIBOLD},
	)
	alicorn.container_end(ctx)
}

@(private)
emit_header_row :: proc(
	ctx: ^ui.UI,
	columns: []Column,
	table: alicorn.Semantic_Collection_Handle,
	instance_id: u64,
	options: Options,
	style: Style,
	recipe: Recipe,
) {
	row_id := header_row_semantic_id(instance_id)
	if row_id.namespace == 0 { return }
	row_surface := begin_surface(
		ctx,
		recipe.header_surface_role,
		.Subtle_Surface,
		key=ui.key_u64(0xA11C_6A10),
		style=ui.layout_style(.Column, width=-1, height=options.header_height),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=style.corner_radius},
		stroke={},
		label="table-header-row",
	)
	if row_surface == 0 { return }
	collection := alicorn.semantic_collection_begin(
		ctx,
		row_surface,
		row_id,
		.Table_Row,
		"Columns",
		u64(len(columns)),
		realized_first=0,
		realized_last=u64(len(columns)),
		parent=table.id,
	)
	_ = alicorn.semantic_collection_item(ctx, table, 0, alicorn.Semantic_Node_Description{
		id=row_id,
		role=.Table_Row,
		label="Columns",
		parent=table.id,
	})
	if ui.row(ctx, key=ui.key_u64(0xA11C_6A11), width=-1, height=-1, gap=options.column_gap,
		align=.Stretch, label="table-header-row-cells") {
		for column, index in columns {
			emit_header_cell(ctx, column, index, collection, instance_id, options)
		}
	}
	alicorn.surface_end(ctx)
}

@(private)
emit_cell :: proc(
	ctx: ^ui.UI,
	cell: Cell,
	column: Column,
	column_index: int,
	row: Row,
	options: Options,
	collection: alicorn.Semantic_Collection_Handle,
	instance_id: u64,
) {
	cell_key := ui.key_pair(CELL_KEY+2, mix(row.key, column.key))
	container := alicorn.container_begin(
		ctx,
		.Container,
		label="table-cell",
		key=cell_key,
		style=cell_layout(column, options.cell_padding, -1),
	)
	if container == 0 { return }
	role := alicorn.Semantic_Role.Table_Cell
	if column_index == 0 && options.row_header { role = .Table_Row_Header }
	states := alicorn.Semantic_States{}
	if row.disabled { states = alicorn.semantic_states_add(states, .Disabled) }
	_ = alicorn.semantic_collection_item(ctx, collection, u64(column_index), alicorn.Semantic_Node_Description{
		id=cell_semantic_id(instance_id, row.key, column.key),
		role=role,
		label=cell.text,
		description=cell.detail,
		value=cell.text,
		states=states,
		visual_node=container,
	})
	text_style := alicorn.Text_Style{overflow=.Ellipsis}
	text_width := f32(-1)
	if column.width > 0 { text_width = max(column.width-2*options.cell_padding, 1) }
	if !options.no_wrap { text_style.overflow = .Wrap }
	if id, has_icon := cell.icon.?; has_icon {
		if ui.row(ctx, key=ui.key_pair(CELL_KEY+6, mix(row.key, column.key)), width=-1, gap=6, align=.Center) {
			_ = ui.icon(ctx, id, key=ui.key_pair(CELL_KEY+7, mix(row.key, column.key)),
				size=options.cell_text_size+3, color_role=.Muted_Text if row.disabled else .Text)
			_ = ui.text(ctx, cell.text, key=ui.key_pair(CELL_KEY+8, mix(row.key, column.key)),
				style=ui.layout_style(.Column, width=text_width),
				size=options.cell_text_size, decorative=true, text_style=text_style,
				color=alicorn.style_color(ctx, .Muted_Text if row.disabled else .Text))
		}
	} else {
		text_color := cell.color_role
		if text_color == .Text { text_color = .Muted_Text if row.disabled else .Text }
		_ = ui.text(ctx, cell.text, key=ui.key_pair(CELL_KEY+8, mix(row.key, column.key)),
			style=ui.layout_style(.Column, width=text_width),
			size=options.cell_text_size, decorative=true, text_style=text_style,
			color=alicorn.style_color(ctx, text_color))
	}
	if cell.detail != "" {
		detail_style := alicorn.Text_Style{overflow=.Ellipsis}
		if !options.no_wrap { detail_style.overflow = .Wrap }
		_ = ui.text(ctx, cell.detail, key=ui.key_pair(CELL_KEY+9, mix(row.key, column.key)),
			style=ui.layout_style(.Column, width=text_width),
			size=options.detail_text_size, decorative=true, text_style=detail_style,
			color=alicorn.style_color(ctx, .Muted_Text))
	}
	alicorn.container_end(ctx)
}

@(private)
emit_row :: proc(
	ctx: ^ui.UI,
	columns: []Column,
	table: alicorn.Semantic_Collection_Handle,
	instance_id: u64,
	options: Options,
	style: Style,
	recipe: Recipe,
	row: Row,
	row_position: int,
	body_index: int,
	row_height: f32,
) {
	row_id := row_semantic_id(instance_id, row.key)
	if row_id.namespace == 0 { return }
	resolved_height := row_height
	if resolved_height < 0 { resolved_height = row_intrinsic_height(ctx, row, columns, options) }
	fill_role := recipe.row_surface_role
	fallback := alicorn.Style_Color_Role.Surface
	if options.alternate_rows && body_index%2 == 1 {
		fill_role = recipe.alternate_row_surface_role
		fallback = .Subtle_Surface
	}
	fill_color := alicorn.style_color(ctx, fallback)
	if fill_role != 0 {
		theme := ctx.runtime.style_environment.theme
		if theme == 0 { theme = alicorn.DEFAULT_STYLE_THEME_ID }
		if resolved_color, found := alicorn.style_extension_color(ctx.runtime, theme, fill_role); found {
			fill_color = resolved_color
		}
	}
	row_surface := alicorn.container_begin(
		ctx,
		.Container,
		label="table-row",
		key=ui.key_pair(CELL_KEY, row.key),
		style=ui.layout_style(.Column, width=-1, height=resolved_height),
		color=fill_color,
	)
	if row_surface == 0 { return }
	collection := alicorn.semantic_collection_begin(
		ctx,
		row_surface,
		row_id,
		.Table_Row,
		"",
		u64(len(columns)),
		realized_first=0,
		realized_last=u64(len(columns)),
		parent=table.id,
	)
	row_states := alicorn.Semantic_States{}
	if row.disabled { row_states = alicorn.semantic_states_add(row_states, .Disabled) }
	_ = alicorn.semantic_collection_item(ctx, table, u64(row_position), alicorn.Semantic_Node_Description{
		id=row_id,
		role=.Table_Row,
		label=row_label(row),
		states=row_states,
		parent=table.id,
		visual_node=row_surface,
	})
	if ui.row(ctx, key=ui.key_pair(CELL_KEY+1, row.key), width=-1, height=resolved_height,
		gap=options.column_gap, align=.Stretch, label="table-row-cells") {
		for column, column_index in columns {
			cell := cell_at(row, column_index)
			emit_cell(ctx, cell, column, column_index, row, options, collection, instance_id)
		}
	}
	alicorn.surface_end(ctx)
}

// table describes one static, non-spanned table. columns and rows are borrowed
// for the call. instance_id must be stable and unique among mounted tables.
// The component keeps no state and returns nothing: selection, focus, and
// activation belong to the application or to `alikit:data_grid`.
table :: proc(
	ctx: ^ui.UI,
	columns: []Column,
	rows: []Row,
	options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
	recipe: Recipe = {},
	style: Style = {},
) {
	if ctx == nil || ctx.runtime == nil || instance_id == 0 ||
	   instance_id > MAX_INSTANCE_ID || len(columns) == 0 || len(columns) > MAX_COLUMNS {
		return
	}
	resolved := options_resolve(options)
	resolved_style := style_resolve(style)
	if !ui.key_scope(ctx, key) { return }

	tracks: [MAX_COLUMNS]alicorn.Grid_Track
	track_count := tracks_for(columns, tracks[:])
	if track_count == 0 { return }
	tracks_slice := tracks[:track_count]
	_ = tracks_slice
	header_count := 0
	if !resolved.hide_header { header_count = 1 }
	row_count := len(rows)
	logical_count := row_count+header_count

	root := alicorn.container_begin(
		ctx,
		.Container,
		label=resolved.accessible_label,
		key=alicorn.key_string("alikit-table-root"),
		style=ui.layout_style(.Column, width=-1, height=-1, gap=0),
	)
	if root == 0 { return }
	table_id := table_semantic_id(instance_id)
	table_collection := alicorn.semantic_collection_begin(
		ctx,
		root,
		table_id,
		.Table,
		resolved.accessible_label,
		u64(logical_count),
		realized_first=0,
		realized_last=u64(logical_count),
	)
	if table_collection.id.namespace == 0 {
		alicorn.container_end(ctx)
		return
	}

	if !resolved.hide_header {
		emit_header_row(ctx, columns, table_collection, instance_id,
			resolved, resolved_style, recipe)
	}

	if row_count == 0 {
		_ = ui.text(ctx, resolved.empty_label, key=alicorn.key_string("alikit-table-empty"),
			size=resolved.cell_text_size, color=alicorn.style_color(ctx, .Muted_Text))
	} else if resolved.virtualize {
		list_height := f32(min(resolved.max_visible_rows, row_count))*resolved.virtual_row_height
		list := alicorn.virtual_list_begin(
			ctx,
			row_count,
			resolved.virtual_row_height,
			key=alicorn.key_string("alikit-table-list"),
			style=ui.layout_style(.Column, width=-1, height=list_height, clip=true),
			label=resolved.accessible_label,
			focusable=false,
		)
		if list.scroll.id != 0 {
			for row, index in rows {
				if index >= list.first && index < list.last { continue }
				virtual_states := alicorn.Semantic_States{}
				if row.disabled { virtual_states = alicorn.semantic_states_add(virtual_states, .Disabled) }
				_ = alicorn.semantic_collection_virtual_item(ctx, table_collection,
					u64(index+header_count), alicorn.Semantic_Node_Description{
						id=row_semantic_id(instance_id, row.key),
						role=.Table_Row,
						label=row_label(row),
						states=virtual_states,
						parent=table_id,
					})
			}
			for index := list.first; index < list.last; index += 1 {
				emit_row(ctx, columns, table_collection, instance_id,
					resolved, resolved_style, recipe, rows[index], index+header_count, index,
					resolved.virtual_row_height)
			}
			alicorn.virtual_list_end(ctx, list)
		}
	} else {
		for row, index in rows {
			emit_row(ctx, columns, table_collection, instance_id,
				resolved, resolved_style, recipe, row, index+header_count, index,
				alicorn.LAYOUT_SIZE_FIT_CONTENT)
		}
	}
	alicorn.container_end(ctx)
}
