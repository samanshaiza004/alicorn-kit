package main

// Static table example: application-owned columns and rows, intrinsic wrapped
// row heights, optional virtualization, and no managed cell focus. The
// application filters and orders its own projection; the table only presents
// it.
//
// Run:
//   odin run examples/table -collection:alicorn=/path/to/alicorn
//   ./out/table_example.exe --smoke

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import base_runtime "base:runtime"
import alicorn "alicorn:runtime"
import theme "alicorn:theme"
import ui "alicorn:ui"
import table "../../table"

THEME_PATH :: "examples/table/theme.json"
THEME_JSON :: #load("theme.json")

ROW_COUNT :: 60

App :: struct {
	query:      ui.Text_Buffer,
	initialized: bool,
	allocator:  mem.Allocator,

	source_cells: [ROW_COUNT][3]table.Cell,
	source_rows:  [ROW_COUNT]table.Row,
	projection:   [ROW_COUNT]table.Row,
	visible_count: int,
	sort_by_name: bool,

	recipe:      table.Recipe,
	theme_id:    alicorn.Style_Theme_ID,
	theme_error: bool,
	smoke:       bool,
}

COLUMNS: [3]table.Column = {
	{key=10, label="Document", width=280, align=.Start},
	{key=20, label="Notes", width=260, align=.Start},
	{key=30, label="Status", width=110, align=.End},
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	app.allocator = base_runtime.heap_allocator()
	app.query, app.initialized = ui.text_buffer("", app.allocator)
	for index in 0..<ROW_COUNT {
		notes := "Short note."
		if index%4 == 0 {
			notes = "A longer note that wraps across several lines and grows this row's intrinsic height."
		}
		status := "Ready"
		if index%5 == 0 { status = "Modified" }
		app.source_cells[index] = {
			{text=fmt.aprintf("Document %03d", index+1, allocator=app.allocator)},
			{text=notes, detail="Application-owned text"},
			{text=status},
		}
		app.source_rows[index] = table.Row{key=u64(index+1), cells=app.source_cells[index][:]}
	}
	rebuild_projection(app)
	registration := theme.theme_json_register(rt, string(THEME_JSON), THEME_PATH)
	defer theme.theme_json_register_result_destroy(&registration)
	app.theme_id = registration.theme_id
	if app.theme_id == 0 {
		fmt.println("Table example theme registration failed:", registration.failure)
		return
	}
	app.recipe = table.Recipe{
		header_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.table", "header"),
		row_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.table", "row"),
		alternate_row_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.table", "alternate"),
	}
	contract := table.theme_contract_default(app.recipe)
	report := table.theme_contract_check(rt, app.theme_id, contract)
	names, missing := table.theme_contract_missing_required(contract, report)
	for index in 0..<missing { fmt.println("Missing table theme role:", names[index]) }
	if missing > 0 { app.theme_error = true; app.recipe = {} }
}

contains_fold :: proc(haystack, needle: string) -> bool {
	if needle == "" { return true }
	if len(needle) > len(haystack) { return false }
	lower := strings.to_lower(haystack, context.temp_allocator)
	needle_lower := strings.to_lower(needle, context.temp_allocator)
	return strings.contains(lower, needle_lower)
}

adopt_accessibility_requests :: proc(app: ^App, rt: ^alicorn.Runtime) {
	if app == nil || rt == nil { return }
	filter_node, filter_found := alicorn.node_by_key(rt,
		ui.key_string("table-example-filter"), .Text_Field)
	filter_id: alicorn.Semantic_ID
	if filter_found { filter_id = alicorn.semantic_visual_id(filter_node) }
	for {
		request, found := alicorn.semantic_request_pop(rt)
		if !found { break }
		if request.kind == .Perform && request.id == filter_id && request.action == .Set_Value {
			if ui.text_buffer_set(&app.query, request.text_value) {
				rebuild_projection(app)
			}
		}
		alicorn.semantic_request_event_destroy(rt, &request)
	}
}

rebuild_projection :: proc(app: ^App) {
	query := app.query.text
	count := 0
	for row in app.source_rows {
		if !contains_fold(row.cells[0].text, query) { continue }
		app.projection[count] = row
		count += 1
	}
	if app.sort_by_name {
		for index in 1..<count {
			value := app.projection[index]
			position := index
			for position > 0 && app.projection[position-1].cells[0].text > value.cells[0].text {
				app.projection[position] = app.projection[position-1]
				position -= 1
			}
			app.projection[position] = value
		}
	}
	app.visible_count = count
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	adopt_accessibility_requests(app, ctx.runtime)
	if app.theme_error {
		_ = ui.text(ctx, "Table theme contract is not satisfied.", size=15,
			color=ui.style_color(ctx, .Danger))
		return
	}
	if ui.column(ctx, key=ui.key_string("table-example-root"), width=-1, height=-1,
		padding=24, gap=12) {
		_ = ui.text(ctx, "Table", size=26)
		_ = ui.text(ctx, "Static presentation: wrapped intrinsic rows, no managed focus or selection.",
			size=13, color=ui.style_color(ctx, .Muted_Text))
		if ui.row(ctx, key=ui.key_string("table-example-controls"), width=-1,
			height=34, gap=10, align=.Center) {
			old_query := app.query.text
			_ = ui.text_field(ctx, "Filter", &app.query,
				key=ui.key_string("table-example-filter"), width=240, height=30)
			if app.query.text != old_query { rebuild_projection(app) }
			if ui.checkbox(ctx, "Sort by name", &app.sort_by_name,
				key=ui.key_string("table-example-sort"), width=150) {
				rebuild_projection(app)
			}
			_ = ui.text(ctx, fmt.tprintf("%d rows", app.visible_count), size=12,
				color=ui.style_color(ctx, .Muted_Text))
		}
		if ui.panel(ctx, key=ui.key_string("table-example-panel"), width=-1, height=-1,
			grow=1, padding=8, fill=ui.style_color(ctx, .Surface), radius=10,
			stroke=ui.border(1, ui.style_color(ctx, .Border), .Inside)) {
			table.table(
				ctx,
				COLUMNS[:],
				app.projection[:app.visible_count],
				table.Options{accessible_label="Documents", row_header=true,
					alternate_rows=true, max_visible_rows=10, measure_width=680},
				key=ui.key_string("table-example-table"),
				instance_id=7101,
				recipe=app.recipe,
			)
		}
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("table_smoke", "rows", app.visible_count, "idle", true)
	}
	if app.initialized { ui.text_buffer_destroy(&app.query) }
	if app.allocator.procedure != nil {
		for index in 0..<ROW_COUNT {
			delete(app.source_cells[index][0].text, app.allocator)
		}
	}
}

on_key :: proc(app: ^App, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	_ = app
	_ = rt
	_ = key
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
