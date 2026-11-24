package main

// Data Grid example with a real, application-owned dataset. The application
// filters and sorts its own source rows, rebuilds a stable-key projection, and
// owns the accepted cell selection. AliKit owns the table semantics,
// virtualization, shared column tracks, and roving cell focus.
//
// Run:
//   odin run examples/data_grid -collection:alicorn=/path/to/alicorn
//   ./out/data_grid_example.exe --smoke

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import base_runtime "base:runtime"
import alicorn "alicorn:runtime"
import theme "alicorn:theme"
import ui "alicorn:ui"
import data_grid "../../data_grid"

THEME_PATH :: "examples/data_grid/theme.json"
THEME_JSON :: #load("theme.json")

ROW_COUNT :: 120

Status :: enum { Ready, Modified, Archived }

App :: struct {
	view:       data_grid.State,
	columns:    [4]data_grid.Column,
	query:      ui.Text_Buffer,
	initialized: bool,
	allocator:  mem.Allocator,

	source_cells: [ROW_COUNT][4]data_grid.Cell,
	source_rows:  [ROW_COUNT]data_grid.Row,
	projection:   [ROW_COUNT]data_grid.Row,
	visible_count: int,
	sort_by_size: bool,
	sort_by_name: bool,
	selection:    data_grid.Selection,

	recipe:      data_grid.Recipe,
	theme_id:    alicorn.Style_Theme_ID,
	theme_error: bool,
	missing:     [8]string,
	missing_count: int,
	status_row: u64,
	status_col: u64,
	smoke:      bool,
}

COLUMNS: [4]data_grid.Column = {
	{key=10, label="Name", align=.Start},
	{key=20, label="Size", width=90, align=.End},
	{key=30, label="Kind", width=92, align=.Start},
	{key=40, label="Status", width=92, align=.Start},
}

sizes := [ROW_COUNT]f32{
	1240, 820, 4100, 980, 15200, 77, 6400, 2300, 9000, 512,
	1100, 30500, 400, 2000, 760, 8800, 300, 6100, 1500, 220,
	4300, 9900, 130, 5600, 7400, 260, 1900, 12800, 450, 3200,
	600, 4700, 2200, 690, 15000, 340, 5400, 8300, 210, 1800,
	3700, 900, 24000, 620, 1200, 7700, 290, 4800, 3300, 540,
	16000, 710, 3800, 110, 2500, 9300, 840, 6700, 420, 1900,
	5200, 300, 14000, 810, 3600, 120, 7800, 440, 2200, 980,
	17000, 640, 4100, 270, 2900, 8600, 390, 5900, 1300, 230,
	4500, 10100, 180, 6300, 7600, 320, 2000, 13200, 470, 3400,
	680, 4900, 2400, 730, 15500, 360, 5600, 8500, 250, 1900,
	3900, 960, 25000, 660, 1400, 7900, 310, 5000, 3500, 580,
	16500, 750, 4000, 150, 2700, 9500, 880, 6900, 460, 2100,
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	app.allocator = base_runtime.heap_allocator()
	app.query, app.initialized = ui.text_buffer("", app.allocator)
	app.columns = COLUMNS
	app.columns[0].sortable = true
	app.columns[1].sortable = true
	app.selection = data_grid.Selection{row_key=1, column_key=10}
	for index in 0..<ROW_COUNT {
		kind := "File"
		if index%3 == 0 { kind = "Folder" }
		status := "Ready"
		if index%5 == 0 { status = "Modified" }
		app.source_cells[index] = {
			{text=fmt.aprintf("Document %03d", index+1, allocator=app.allocator)},
			{text=format_size(sizes[index], app.allocator)},
			{text=kind},
			{text=status},
		}
		app.source_rows[index] = data_grid.Row{key=u64(index+1), cells=app.source_cells[index][:]}
	}
	rebuild_projection(app)
	registration := theme.theme_json_register(rt, string(THEME_JSON), THEME_PATH)
	defer theme.theme_json_register_result_destroy(&registration)
	app.theme_id = registration.theme_id
	if app.theme_id == 0 {
		fmt.println("Data Grid example theme registration failed:", registration.failure)
		return
	}
	app.recipe = data_grid.Recipe{
		header_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.data_grid", "header"),
		row_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.data_grid", "row"),
		selected_row_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.data_grid", "selected_row"),
		selected_cell_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.data_grid", "selected_cell"),
	}
	contract := data_grid.theme_contract_default(app.recipe)
	report := data_grid.theme_contract_check(rt, app.theme_id, contract)
	app.missing, app.missing_count = data_grid.theme_contract_missing_required(contract, report)
	for index in 0..<app.missing_count {
		fmt.println("Missing table theme role:", app.missing[index])
	}
	if app.missing_count > 0 { app.theme_error = true; app.recipe = {} }
}

format_size :: proc(bytes: f32, allocator := context.allocator) -> string {
	if bytes >= 1024*1024 { return fmt.aprintf("%.1f MB", bytes/(1024*1024), allocator=allocator) }
	if bytes >= 1024 { return fmt.aprintf("%.0f KB", bytes/1024, allocator=allocator) }
	return fmt.aprintf("%.0f B", bytes, allocator=allocator)
}

contains_fold :: proc(haystack, needle: string) -> bool {
	if needle == "" { return true }
	return strings.contains(strings.to_lower(haystack, context.temp_allocator),
		strings.to_lower(needle, context.temp_allocator))
}

rebuild_projection :: proc(app: ^App) {
	app.visible_count = 0
	for index in 0..<ROW_COUNT {
		if !contains_fold(app.source_cells[index][0].text, app.query.text) { continue }
		app.projection[app.visible_count] = app.source_rows[index]
		app.visible_count += 1
	}
	// Application-owned sorting: insert stable keys into the projection. The
	// table never sorts or filters the caller's rows.
	for index in 1..<app.visible_count {
		current := app.projection[index]
		move := index
		for move > 0 && less(app, current, app.projection[move-1]) {
			app.projection[move] = app.projection[move-1]
			move -= 1
		}
		app.projection[move] = current
	}
}

less :: proc(app: ^App, left, right: data_grid.Row) -> bool {
	if app.sort_by_size {
		left_size := sizes[left.key-1]
		right_size := sizes[right.key-1]
		if left_size == right_size { return left.key < right.key }
		return left_size < right_size
	}
	if app.sort_by_name { return left.cells[0].text < right.cells[0].text }
	return left.key < right.key
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("table-example-root"), width=-1, height=-1,
		padding=24, gap=12) {
		_ = ui.text(ctx, "Data Grid", size=26)
		_ = ui.text(ctx, "Application-owned filtering and sorting; virtualized rows; nested table semantics.",
			size=13, color=ui.style_color(ctx, .Muted_Text))
		if ui.row(ctx, key=ui.key_string("table-example-controls"), width=-1,
			height=34, gap=10, align=.Center) {
			_ = ui.text_field(ctx, "Filter", &app.query,
				key=ui.key_string("table-example-filter"), width=240, height=30)
			_ = ui.checkbox(ctx, "Sort by size", &app.sort_by_size,
				key=ui.key_string("table-example-sort"), width=160, height=28)
			_ = ui.text(ctx, fmt.tprintf("%d rows", app.visible_count), size=12,
				color=ui.style_color(ctx, .Muted_Text))
		}
		rebuild_projection(app)
		if ui.panel(ctx, key=ui.key_string("table-example-panel"), width=-1, height=-1,
			grow=1, padding=8, fill=ui.style_color(ctx, .Surface), radius=10,
			stroke=ui.border(1, ui.style_color(ctx, .Border), .Inside)) {
			if event := data_grid.data_grid(
				ctx,
				&app.view,
				app.columns[:],
				app.projection[:app.visible_count],
				app.selection,
				data_grid.Options{accessible_label="Documents", row_header=true,
					max_visible_rows=10, row_height=30},
				key=ui.key_string("grid-example-grid"),
				instance_id=7101,
				recipe=app.recipe,
				); event.kind == .Activated {
				app.selection.row_key = event.row_key
				app.selection.column_key = event.column_key
				app.status_row = event.row_key
				app.status_col = event.column_key
			} else if event.kind == .Sort_Proposed {
				if event.column_key == 10 {
					app.sort_by_name = !app.sort_by_name
					app.sort_by_size = false
				} else if event.column_key == 20 {
					app.sort_by_size = !app.sort_by_size
					app.sort_by_name = false
				}
				app.columns[0].sort = (data_grid.Sort_State.Ascending if app.sort_by_name else data_grid.Sort_State.None)
				app.columns[1].sort = (data_grid.Sort_State.Ascending if app.sort_by_size else data_grid.Sort_State.None)
				rebuild_projection(app)
			}
			if app.theme_error {
				_ = ui.text(ctx, "Optional table theme roles are incomplete; core roles are in use.",
					size=12, color=ui.style_color(ctx, .Danger))
			}
		}
		status := "Activate a cell with Return, Space, or the pointer."
		if app.status_row != 0 {
			status = fmt.tprintf("Activated row %d, column %d", app.status_row, app.status_col)
		}
		_ = ui.text(ctx, status, size=13, color=ui.style_color(ctx, .Muted_Text))
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("data_grid_smoke", "rows", app.visible_count, "selected", app.selection.row_key,
			"column", app.selection.column_key, "idle", true)
	}
	if app.initialized { ui.text_buffer_destroy(&app.query) }
	if app.allocator.procedure != nil {
		for index in 0..<ROW_COUNT {
			delete(app.source_cells[index][0].text, app.allocator)
			delete(app.source_cells[index][1].text, app.allocator)
		}
	}
}

on_key :: proc(app: ^App, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	#partial switch key {
	case .Escape:
		_ = ui.text_buffer_set(&app.query, "")
		alicorn.invalidate_root(rt, "Data Grid example cleared filter")
		return true
	}
	return false
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{smoke=smoke}
	ui.run(
		&app,
		render,
		title="Alicorn - Table",
		width=980,
		height=640,
		on_initialize=initialize,
		on_key=on_key,
		on_stop=stop,
		smoke=smoke,
	)
}
