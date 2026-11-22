package data_grid

// Data Grid is the interactive dataset grid: a composable, virtualized,
// non-spanned grid over Alicorn's compound table roles. The application owns
// columns, rows, sorting, filtering, and the accepted selection; this package
// owns shared column tracks, nested Table -> Table_Row -> cell collections,
// header roles, roving cell focus, row reveal, optional sort-header proposals,
// and one cell activation proposal.
//
// Navigation is row-level roving focus with a cell coordinate: Up/Down move a
// row, Left/Right move within the focused row, Home/End target the row, and
// Page Up/Down move by visible rows. One Tab stop owns the grid. Sorting and
// filtering are application callbacks over its own data; they are not built in.
//
// Alicorn's pinned Semantic_Role set has no Grid or Grid_Cell role. v1
// therefore publishes Table / Table_Row / Table_Cell and records the Grid role
// question as an Alicorn-side request rather than inventing private semantics.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import tc "alikit:theme_contract"

GRID_NAMESPACE :: u64(0x4752494447524401) // "GRIDGRID"
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)
MAX_COLUMNS :: 64
CELL_KEY :: u64(0xA11C_6B01)

Alignment :: enum { Start, Center, End }

// Sort_State is presentation input only. The application owns the comparator
// and the projected row order; the grid publishes the requested direction on
// the column header and proposes a change when a sortable header activates.
Sort_State :: enum { None, Ascending, Descending }

Column :: struct {
	// key is the stable application column identity. It must be nonzero and
	// unique within one grid.
	key:   u64,
	label: string,
	// width <= 0 requests an equal fraction of the remaining width. A positive
	// value is a fixed logical-pixel track.
	width: f32,
	// min_width is optional; zero leaves the grid track unconstrained.
	min_width: f32,
	align: Alignment,
	// sortable makes the header an activation target for application sorting.
	sortable: bool,
	// sort is the application's accepted direction for this column.
	sort: Sort_State,
}

Cell :: struct {
	text:   string,
	detail: string,
}

Row :: struct {
	// key is the stable application row identity. It must be nonzero and unique
	// within one grid.
	key:      u64,
	cells:    []Cell,
	disabled: bool,
}

Selection :: struct {
	row_key:    u64,
	column_key: u64,
}

Options :: struct {
	accessible_label: string,
	empty_label:      string,
	// hide_header opts out of the header row; the default keeps it visible for
	// a partial Options value.
	hide_header:      bool,
	// row_header makes the first column publish Table_Row_Header in body rows.
	// The header row's first cell remains a Table_Column_Header.
	row_header:       bool,
	row_height:       f32,
	header_height:    f32,
	max_visible_rows: int,
	column_gap:       f32,
	cell_padding:     f32,
	header_text_size: f32,
	cell_text_size:   f32,
}

DEFAULT_OPTIONS :: Options{
	accessible_label="Data grid",
	empty_label="No rows",
	row_height=34,
	header_height=32,
	max_visible_rows=8,
	column_gap=0,
	cell_padding=8,
	header_text_size=12,
	cell_text_size=13,
}

Recipe :: struct {
	header_surface_role:       alicorn.Style_Extension_Color_Role_ID,
	row_surface_role:          alicorn.Style_Extension_Color_Role_ID,
	selected_row_surface_role: alicorn.Style_Extension_Color_Role_ID,
	selected_cell_surface_role: alicorn.Style_Extension_Color_Role_ID,
}

Style :: struct {
	corner_radius:   f32,
	focus_width:     f32,
	selected_bar_width: f32,
}

DEFAULT_STYLE :: Style{
	corner_radius=6,
	focus_width=2,
	selected_bar_width=2,
}

Theme_Contract :: tc.Contract
Theme_Contract_Report :: tc.Report

recipe_default :: proc() -> Recipe { return {} }
style_default :: proc() -> Style { return DEFAULT_STYLE }

theme_contract_default :: proc(recipe: Recipe) -> Theme_Contract {
	contract: Theme_Contract
	_ = role_requirement(&contract, recipe.header_surface_role, "alikit.data_grid.header_surface")
	_ = role_requirement(&contract, recipe.row_surface_role, "alikit.data_grid.row_surface")
	_ = role_requirement(&contract, recipe.selected_row_surface_role, "alikit.data_grid.selected_row_surface")
	_ = role_requirement(&contract, recipe.selected_cell_surface_role, "alikit.data_grid.selected_cell_surface")
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

State :: struct {
	active_row_key:    u64,
	active_column_key: u64,
	active_row_index:  int,
	active_column_index: int,

	root_node:              alicorn.Node_ID,
	list_node:              alicorn.Node_ID,
	focus_pending:          bool,
	reveal_pending:         bool,
	after_frame_registered: bool,

	proposed:        bool,
	proposed_row:    u64,
	proposed_column: u64,

	last_first: int,
	last_last:  int,
}

Event_Kind :: enum { None, Activated, Sort_Proposed }

Event :: struct {
	kind:        Event_Kind,
	row_key:     u64,
	column_key:  u64,
}

@(private)
mix :: proc(seed, value: u64) -> u64 {
	state := seed+value+0x9E3779B97F4A7C15
	state = (state ~ (state>>30))*0xBF58476D1CE4E5B9
	state = (state ~ (state>>27))*0x94D049BB133111EB
	return state ~ (state>>31)
}

grid_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=GRID_NAMESPACE, value=mix(instance_id, 0x5441424C)}
}

header_row_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=GRID_NAMESPACE, value=mix(instance_id, 0x48454144)}
}

header_cell_semantic_id :: proc(instance_id, column_key: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || column_key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=GRID_NAMESPACE, value=mix(instance_id, column_key ~ 0x48454144)}
}

row_semantic_id :: proc(instance_id, row_key: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || row_key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=GRID_NAMESPACE, value=mix(instance_id, row_key)}
}

cell_semantic_id :: proc(instance_id, row_key, column_key: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || row_key == 0 || column_key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=GRID_NAMESPACE,
		value=mix(mix(instance_id, row_key), column_key ~ 0x43454C4C)}
}

request_focus :: proc(state: ^State) -> bool {
	if state == nil { return false }
	state.focus_pending = true
	return true
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.empty_label == "" { result.empty_label = DEFAULT_OPTIONS.empty_label }
	if result.row_height <= 0 || math.is_nan(result.row_height) || math.is_inf(result.row_height) {
		result.row_height = DEFAULT_OPTIONS.row_height
	}
	if result.header_height <= 0 || math.is_nan(result.header_height) || math.is_inf(result.header_height) {
		result.header_height = DEFAULT_OPTIONS.header_height
	}
	if result.max_visible_rows <= 0 { result.max_visible_rows = DEFAULT_OPTIONS.max_visible_rows }
	if result.column_gap < 0 || math.is_nan(result.column_gap) || math.is_inf(result.column_gap) {
		result.column_gap = DEFAULT_OPTIONS.column_gap
	}
	if result.cell_padding < 0 || math.is_nan(result.cell_padding) || math.is_inf(result.cell_padding) {
		result.cell_padding = DEFAULT_OPTIONS.cell_padding
	}
	if result.header_text_size <= 0 { result.header_text_size = DEFAULT_OPTIONS.header_text_size }
	if result.cell_text_size <= 0 { result.cell_text_size = DEFAULT_OPTIONS.cell_text_size }
	return result
}

@(private)
style_resolve :: proc(style: Style) -> Style {
	result := style
	if result.corner_radius < 0 || math.is_nan(result.corner_radius) || math.is_inf(result.corner_radius) {
		result.corner_radius = DEFAULT_STYLE.corner_radius
	}
	if result.focus_width <= 0 || math.is_nan(result.focus_width) || math.is_inf(result.focus_width) {
		result.focus_width = DEFAULT_STYLE.focus_width
	}
	if result.selected_bar_width <= 0 || math.is_nan(result.selected_bar_width) || math.is_inf(result.selected_bar_width) {
		result.selected_bar_width = DEFAULT_STYLE.selected_bar_width
	}
	return result
}

@(private)
column_index :: proc(columns: []Column, key: u64) -> int {
	if key == 0 { return -1 }
	for column, index in columns {
		if column.key == key { return index }
	}
	return -1
}

@(private)
row_index :: proc(rows: []Row, key: u64) -> int {
	if key == 0 { return -1 }
	for row, index in rows {
		if row.key == key { return index }
	}
	return -1
}

@(private)
row_enabled :: proc(rows: []Row, index: int) -> bool {
	if index < 0 || index >= len(rows) { return false }
	return rows[index].key != 0 && !rows[index].disabled
}

@(private)
Row_Roving :: struct {
	rows: []Row,
}

@(private)
row_roving_enabled :: proc(data: rawptr, index: int) -> bool {
	ctx := cast(^Row_Roving)data
	return row_enabled(ctx.rows, index)
}

@(private)
row_view :: proc(ctx: ^Row_Roving, rows: []Row, visible_rows: int) -> alicorn.Roving_View {
	ctx.rows = rows
	return alicorn.Roving_View{
		count=len(rows),
		enabled=row_roving_enabled,
		data=rawptr(ctx),
		page=max(visible_rows, 1),
	}
}

@(private)
set_active :: proc(state: ^State, rows: []Row, columns: []Column, row: int, column: int) {
	if state == nil || len(columns) == 0 { return }
	if row < 0 || row >= len(rows) {
		state.active_row_index = -1
		state.active_column_index = -1
		state.active_row_key = 0
		state.active_column_key = 0
		return
	}
	resolved_column := clamp(column, 0, len(columns)-1)
	state.active_row_index = row
	state.active_column_index = resolved_column
	state.active_row_key = rows[row].key
	state.active_column_key = columns[resolved_column].key
}

@(private)
reconcile_active :: proc(state: ^State, rows: []Row, columns: []Column, options: Options, selection: Selection) {
	if state == nil { return }
	if len(rows) == 0 || len(columns) == 0 {
		state.active_row_index = -1
		state.active_column_index = -1
		state.active_row_key = 0
		state.active_column_key = 0
		return
	}
	row := row_index(rows, state.active_row_key)
	column := column_index(columns, state.active_column_key)
	if row < 0 {
		row = row_index(rows, selection.row_key)
		if column < 0 && row >= 0 { column = column_index(columns, selection.column_key) }
	}
	if column < 0 { column = 0 }
	if row >= 0 && row_enabled(rows, row) {
		set_active(state, rows, columns, row, column)
		return
	}
	// Repair focus to the nearest enabled row, preserving the column.
	ctx: Row_Roving
	view := row_view(&ctx, rows, options.max_visible_rows)
	start := clamp(state.active_row_index, 0, len(rows)-1)
	repaired := alicorn.roving_nearest_enabled(view, start, 1)
	if repaired < 0 { repaired = alicorn.roving_first_enabled(view) }
	set_active(state, rows, columns, repaired, column)
}

@(private)
propose :: proc(state: ^State, row_key, column_key: u64) {
	if state == nil || row_key == 0 || column_key == 0 { return }
	state.proposed = true
	state.proposed_row = row_key
	state.proposed_column = column_key
}

@(private)
apply_key :: proc(state: ^State, rows: []Row, columns: []Column, options: Options, key: alicorn.Application_Key) -> bool {
	if state == nil || state.active_row_index < 0 || len(columns) == 0 { return false }
	previous_row := state.active_row_index
	previous_column := state.active_column_index
	if key == .Return || key == .Toggle {
		if row_enabled(rows, state.active_row_index) {
			propose(state, state.active_row_key, state.active_column_key)
		}
		return true
	}
	#partial switch key {
	case .Left:
		set_active(state, rows, columns, previous_row, previous_column-1)
		return true
	case .Right:
		set_active(state, rows, columns, previous_row, previous_column+1)
		return true
	case .Home:
		set_active(state, rows, columns, previous_row, 0)
		return true
	case .End:
		set_active(state, rows, columns, previous_row, len(columns)-1)
		return true
	}
	move, mapped := alicorn.roving_move_for_key(key)
	if !mapped { return false }
	if move == .Left || move == .Right { return false }
	ctx: Row_Roving
	view := row_view(&ctx, rows, options.max_visible_rows)
	index := alicorn.roving_propose(view, previous_row, move)
	if index < 0 && move == .Page_Down { index = alicorn.roving_last_enabled(view) }
	if index < 0 && move == .Page_Up { index = alicorn.roving_first_enabled(view) }
	if index >= 0 {
		set_active(state, rows, columns, index, previous_column)
		state.reveal_pending = true
	}
	return previous_row != state.active_row_index || previous_column != state.active_column_index
}

@(private)
schedule_after_frame :: proc(state: ^State, rt: ^alicorn.Runtime) {
	if state == nil || rt == nil || state.after_frame_registered { return }
	if alicorn.interaction_after_frame_register(rt, rawptr(state), table_after_frame) {
		state.after_frame_registered = true
	}
}

@(private)
table_after_frame :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	state := cast(^State)data
	if state == nil || rt == nil { return }
	state.after_frame_registered = false
	if state.focus_pending && state.root_node != 0 {
		if alicorn.focus(rt, state.root_node) {
			state.focus_pending = false
			alicorn.focus_indicator_set(rt, true)
		}
	}
	if state.reveal_pending && state.list_node != 0 && state.active_row_index >= 0 {
		_ = alicorn.virtual_list_ensure_visible(rt, state.list_node, state.active_row_index,
			"data grid active row revealed")
		state.reveal_pending = false
	}
	if state.focus_pending || state.reveal_pending { schedule_after_frame(state, rt) }
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
	return .Stretch
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
row_label :: proc(row: Row, row_header: bool) -> string {
	if len(row.cells) == 0 { return "Row" }
	if row_header { return row.cells[0].text }
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
emit_header_cell :: proc(
	ctx: ^ui.UI,
	column: Column,
	column_index: int,
	collection: alicorn.Semantic_Collection_Handle,
	instance_id: u64,
	options: Options,
) -> Event {
	key := ui.key_pair(CELL_KEY+3, column.key)
	owner: alicorn.Node_ID
	activated := false
	if column.sortable {
		owner, activated = alicorn.button_begin(
			ctx,
			column.label,
			key=key,
			style=ui.layout_style(.Row, width=-1, height=options.header_height, padding=options.cell_padding,
				justify=row_justify(column.align), align=.Center),
			presentation=.Custom,
			focusable=false,
		)
	} else {
		owner = alicorn.container_begin(
			ctx,
			.Container,
			label="grid-header-cell",
			key=key,
			style=ui.layout_style(.Row, width=-1, height=options.header_height, padding=options.cell_padding,
				justify=row_justify(column.align), align=.Center),
		)
	}
	if owner == 0 { return {} }
	actions := alicorn.Semantic_Actions{}
	description := ""
	if column.sortable { actions = alicorn.semantic_actions_add(actions, .Press) }
	#partial switch column.sort {
	case .Ascending: description = "Sorted ascending"
	case .Descending: description = "Sorted descending"
	}
	_ = alicorn.semantic_collection_item(ctx, collection, u64(column_index), alicorn.Semantic_Node_Description{
		id=header_cell_semantic_id(instance_id, column.key),
		role=.Table_Column_Header,
		label=column.label,
		description=description,
		value=column.label,
		actions=actions,
		visual_node=owner,
	})
	label := ui.text(ctx, column.label,
		key=ui.key_pair(CELL_KEY+4, column.key),
		style=ui.layout_style(.Row),
		size=options.header_text_size,
		color=alicorn.style_color(ctx, .Muted_Text),
		decorative=true,
		text_style=alicorn.Text_Style{overflow=.Ellipsis, font_weight=alicorn.FONT_WEIGHT_SEMIBOLD},
	)
	_ = label
	if column.sortable {
		alicorn.button_end(ctx)
	} else {
		alicorn.container_end(ctx)
	}
	_ = alicorn.grid_cell(ctx, owner, 0, column_index, align_x=grid_alignment(column.align))
	if activated {
		return Event{kind=.Sort_Proposed, column_key=column.key}
	}
	return {}
}

@(private)
emit_header_row :: proc(
	ctx: ^ui.UI,
	columns: []Column,
	tracks: []alicorn.Grid_Track,
	grid: alicorn.Semantic_Collection_Handle,
	instance_id: u64,
	options: Options,
	style: Style,
	recipe: Recipe,
) -> Event {
	row_id := header_row_semantic_id(instance_id)
	if row_id.namespace == 0 { return {} }
	row_surface := begin_surface(
		ctx,
		recipe.header_surface_role,
		.Subtle_Surface,
		key=ui.key_u64(0xA11C_6A10),
		style=ui.layout_style(.Column, width=-1, height=options.header_height),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=style.corner_radius},
		stroke={},
		label="grid-header-row",
	)
	if row_surface == 0 { return {} }
	collection := alicorn.semantic_collection_begin(
		ctx,
		row_surface,
		row_id,
		.Table_Row,
		"Columns",
		u64(len(columns)),
		realized_first=0,
		realized_last=u64(len(columns)),
		parent=grid.id,
	)
	_ = alicorn.semantic_collection_item(ctx, grid, 0, alicorn.Semantic_Node_Description{
		id=row_id,
		role=.Table_Row,
		label="Columns",
		parent=grid.id,
	})
	auto_rows := [1]alicorn.Grid_Track{alicorn.grid_auto()}
	grid_node := alicorn.grid_begin(ctx, ui.key_u64(0xA11C_6A11), tracks, auto_rows[:],
		style=ui.layout_style(.Row, width=-1, height=options.header_height),
		gap_x=options.column_gap, gap_y=0, label="grid-header-grid")
	event := Event{}
	if grid_node != 0 {
		for column, index in columns {
			header_event := emit_header_cell(ctx, column, index, collection, instance_id, options)
			if header_event.kind != .None { event = header_event }
		}
		alicorn.grid_end(ctx)
	}
	alicorn.surface_end(ctx)
	return event
}

@(private)
emit_row :: proc(
	ctx: ^ui.UI,
	state: ^State,
	rows: []Row,
	columns: []Column,
	tracks: []alicorn.Grid_Track,
	grid: alicorn.Semantic_Collection_Handle,
	instance_id: u64,
	options: Options,
	style: Style,
	recipe: Recipe,
	selection: Selection,
	row: Row,
	row_position: int,
) -> Event {
	row_id := row_semantic_id(instance_id, row.key)
	if row_id.namespace == 0 { return {} }
	row_selected := row.key == selection.row_key
	fill_role := recipe.row_surface_role
	fallback := alicorn.Style_Color_Role.Surface
	if row_selected { fill_role = recipe.selected_row_surface_role; fallback = .Selection }
	row_surface := begin_surface(
		ctx,
		fill_role,
		fallback,
		key=ui.key_pair(CELL_KEY, row.key),
		style=ui.layout_style(.Column, width=-1, height=options.row_height),
		shape=alicorn.Surface_Shape{kind=.Rectangle},
		stroke={},
		label="grid-row",
	)
	if row_surface == 0 { return {} }
	cell_selected_id := cell_semantic_id(instance_id, row.key, selection.column_key)
	if selection.row_key != row.key { cell_selected_id = {} }
	cell_current_id := cell_semantic_id(instance_id, row.key, state.active_column_key)
	if !row_selected { cell_current_id = {} }
	collection := alicorn.semantic_collection_begin(
		ctx,
		row_surface,
		row_id,
		.Table_Row,
		"",
		u64(len(columns)),
		selected_id=cell_selected_id,
		current_id=cell_current_id,
		realized_first=0,
		realized_last=u64(len(columns)),
		parent=grid.id,
	)
	row_states := alicorn.Semantic_States{}
	if row.disabled { row_states = alicorn.semantic_states_add(row_states, .Disabled) }
	if row_selected { row_states = alicorn.semantic_states_add(row_states, .Selected) }
	if row.key == state.active_row_key { row_states = alicorn.semantic_states_add(row_states, .Current) }
	_ = alicorn.semantic_collection_item(ctx, grid, u64(row_position), alicorn.Semantic_Node_Description{
		id=row_id,
		role=.Table_Row,
		label=row_label(row, options.row_header),
		states=row_states,
		parent=grid.id,
		visual_node=row_surface,
	})
	auto_rows := [1]alicorn.Grid_Track{alicorn.grid_auto()}
	grid_node := alicorn.grid_begin(ctx, ui.key_pair(CELL_KEY+1, row.key), tracks, auto_rows[:],
		style=ui.layout_style(.Row, width=-1, height=options.row_height),
		gap_x=options.column_gap, gap_y=0, label="grid-row-grid")
	if grid_node == 0 { alicorn.surface_end(ctx); return {} }
	event := Event{}
	for column, column_index in columns {
		cell := cell_at(row, column_index)
		selected := row_selected && column.key == selection.column_key
		active := row.key == state.active_row_key && column.key == state.active_column_key
		owner, activated := alicorn.button_begin(
			ctx,
			cell.text,
			key=ui.key_pair(CELL_KEY+2, mix(row.key, column.key)),
			style=ui.layout_style(.Row, width=-1, height=options.row_height),
			state=alicorn.Button_State{selected=selected, disabled=row.disabled},
			presentation=.Custom,
			focusable=false,
		)
		if owner == 0 { continue }
		states := alicorn.Semantic_States{}
		if row.disabled { states = alicorn.semantic_states_add(states, .Disabled) }
		if selected { states = alicorn.semantic_states_add(states, .Selected) }
		if active { states = alicorn.semantic_states_add(states, .Current) }
		role := alicorn.Semantic_Role.Table_Cell
		if column_index == 0 && options.row_header { role = .Table_Row_Header }
		_ = alicorn.semantic_collection_item(ctx, collection, u64(column_index), alicorn.Semantic_Node_Description{
			id=cell_semantic_id(instance_id, row.key, column.key),
			role=role,
			label=cell.text,
			description=cell.detail,
			value=cell.text,
			states=states,
			visual_node=owner,
		})
		cell_style := ui.layout_style(.Row, width=-1, height=-1, padding=options.cell_padding,
			justify=row_justify(column.align), align=.Center)
		if selected {
			selected_surface := begin_surface(
				ctx,
				recipe.selected_cell_surface_role,
				.Selection,
				key=ui.key_pair(CELL_KEY+5, mix(row.key, column.key)),
				style=cell_style,
				shape=alicorn.Surface_Shape{kind=.Rectangle},
				stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Accent), width=style.focus_width},
				label="grid-cell-selected",
			)
			if selected_surface != 0 {
				_ = alicorn.visual_part_attach(ctx, selected_surface, owner, alicorn.visual_part_core(.Selected_Indicator))
				_ = ui.text(ctx, cell.text, key=ui.key_u64(1), size=options.cell_text_size,
					decorative=true, text_style=alicorn.Text_Style{overflow=.Ellipsis})
				alicorn.surface_end(ctx)
			}
		} else if ui.row(ctx, key=ui.key_u64(1), width=-1, height=-1,
			padding=options.cell_padding, justify=row_justify(column.align), align=.Center) {
			_ = ui.text(ctx, cell.text, key=ui.key_u64(2), size=options.cell_text_size,
				decorative=true, text_style=alicorn.Text_Style{overflow=.Ellipsis},
				color=alicorn.style_color(ctx, .Muted_Text if row.disabled else .Text))
		}
		alicorn.button_end(ctx)
		_ = alicorn.grid_cell(ctx, owner, 0, column_index, align_x=grid_alignment(column.align))
		if activated && !row.disabled {
			propose(state, row.key, column.key)
			event = Event{kind=.Activated, row_key=row.key, column_key=column.key}
		}
	}
	alicorn.grid_end(ctx)
	alicorn.surface_end(ctx)
	return event
}

// data_grid describes one virtualized interactive grid. columns and rows are
// borrowed for the call; the application owns sorting, filtering, selection,
// and data lifetime. selection is the accepted cell; the component publishes
// Selected/Current but never mutates it. instance_id must be stable and unique
// among mounted grids. A sortable header proposes Sort_Proposed with its column
// key; the application changes the projection and updates Column.sort.
data_grid :: proc(
	ctx: ^ui.UI,
	state: ^State,
	columns: []Column,
	rows: []Row,
	selection: Selection,
	options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
	recipe: Recipe = {},
	style: Style = {},
) -> (event: Event) {
	if ctx == nil || ctx.runtime == nil || state == nil || instance_id == 0 ||
	   instance_id > MAX_INSTANCE_ID || len(columns) == 0 || len(columns) > MAX_COLUMNS {
		return
	}
	resolved := options_resolve(options)
	resolved_style := style_resolve(style)
	if !ui.key_scope(ctx, key) { return }
	state.list_node = 0
	reconcile_active(state, rows, columns, resolved, selection)

	tracks: [MAX_COLUMNS]alicorn.Grid_Track
	track_count := tracks_for(columns, tracks[:])
	if track_count == 0 { return }
	tracks_slice := tracks[:track_count]
	header_count := 0
	if !resolved.hide_header { header_count = 1 }
	row_count := len(rows)
	logical_count := row_count+header_count
	realized_last := u64(logical_count)

	state.root_node = alicorn.container_begin(
		ctx,
		.Container,
		label=resolved.accessible_label,
		key=alicorn.key_string("alikit-data-grid-root"),
		style=ui.layout_style(.Column, width=-1, height=-1, gap=0),
		focusable=true,
	)
	if state.root_node == 0 { return }
	table_id := grid_semantic_id(instance_id)
	selected_row_id := row_semantic_id(instance_id, selection.row_key)
	if row_index(rows, selection.row_key) < 0 { selected_row_id = {} }
	current_row_id := row_semantic_id(instance_id, state.active_row_key)
	table_collection := alicorn.semantic_collection_begin(
		ctx,
		state.root_node,
		table_id,
		.Table,
		resolved.accessible_label,
		u64(logical_count),
		selected_id=selected_row_id,
		current_id=current_row_id,
		realized_first=0,
		realized_last=realized_last,
	)
	if table_collection.id.namespace == 0 {
		alicorn.container_end(ctx)
		return
	}

	if !resolved.hide_header {
		header_event := emit_header_row(ctx, columns, tracks_slice, table_collection, instance_id,
			resolved, resolved_style, recipe)
		if header_event.kind != .None { event = header_event }
	}

	if row_count == 0 {
		_ = ui.text(ctx, resolved.empty_label, key=alicorn.key_string("alikit-data-grid-empty"),
			size=resolved.cell_text_size, color=alicorn.style_color(ctx, .Muted_Text))
	} else {
		list_height := f32(min(resolved.max_visible_rows, row_count))*resolved.row_height
		list := alicorn.virtual_list_begin(
			ctx,
			row_count,
			resolved.row_height,
			key=alicorn.key_string("alikit-data-grid-list"),
			style=ui.layout_style(.Column, width=-1, height=list_height, clip=true),
			label=resolved.accessible_label,
			focusable=false,
		)
		state.list_node = list.scroll.id
		state.last_first = list.first
		state.last_last = list.last
		if list.scroll.id != 0 {
			_ = ui.interaction_scope(ctx, state.root_node, rawptr(state), alicorn.Interaction_Scope_Options{
				keys={.Up, .Down, .Left, .Right, .Home, .End, .Page_Up, .Page_Down, .Return, .Toggle},
				composition_yield_keys={.Up, .Down, .Left, .Right, .Home, .End, .Page_Up, .Page_Down, .Return, .Toggle},
			})
			for {
				queued, found := alicorn.interaction_event_next(ctx.runtime, state.root_node)
				if !found { break }
				if queued.kind == .Key && apply_key(state, rows, columns, resolved, queued.key) {
					alicorn.invalidate_root(ctx.runtime, "data grid keyboard navigation")
				}
			}
			if state.proposed {
				state.proposed = false
				event = Event{kind=.Activated, row_key=state.proposed_row, column_key=state.proposed_column}
			}
			// Publish rows outside the realized window as virtual Table_Row
			// items so assistive technology can request them by row coordinate.
			for row, index in rows {
				if index >= list.first && index < list.last { continue }
				virtual_states := alicorn.Semantic_States{}
				if row.disabled { virtual_states = alicorn.semantic_states_add(virtual_states, .Disabled) }
				_ = alicorn.semantic_collection_virtual_item(ctx, table_collection,
					u64(index+header_count), alicorn.Semantic_Node_Description{
						id=row_semantic_id(instance_id, row.key),
						role=.Table_Row,
						label=row_label(row, resolved.row_header),
						states=virtual_states,
						parent=table_id,
					})
			}
			for index := list.first; index < list.last; index += 1 {
				row := rows[index]
				row_event := emit_row(ctx, state, rows, columns, tracks_slice, table_collection,
					instance_id, resolved, resolved_style, recipe, selection, row,
					index+header_count)
				if row_event.kind != .None { event = row_event }
			}
			alicorn.virtual_list_end(ctx, list)
		}
	}
	if state.proposed {
		state.proposed = false
		event = Event{kind=.Activated, row_key=state.proposed_row, column_key=state.proposed_column}
	}
	alicorn.container_end(ctx)
	if state.focus_pending || state.reveal_pending { schedule_after_frame(state, ctx.runtime) }
	return
}
