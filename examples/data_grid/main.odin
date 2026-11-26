package main

// The application owns the 200-row dataset, filtering, sorting, and accepted
// selection. AliKit owns the shared grid tracks, table semantics,
// virtualization, and roving cell focus.
//
// Run:
//   odin run examples/data_grid -collection:alicorn=/path/to/alicorn
//   ./out/data_grid_example.exe --smoke

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import base_runtime "base:runtime"
import ui "alicorn:ui"
import data_grid "../../data_grid"

ROW_COUNT :: 200
SAMPLE_NAME_COUNT :: 8

App :: struct {
	view:            data_grid.State,
	row_count_node:  ui.Node_ID,
	columns:         [4]data_grid.Column,
	query:           ui.Text_Buffer,
	initialized:     bool,
	allocator:       mem.Allocator,
	source_cells:    [ROW_COUNT][4]data_grid.Cell,
	source_rows:     [ROW_COUNT]data_grid.Row,
	projection:      [ROW_COUNT]data_grid.Row,
	visible_count:   int,
	sort_column:     u64,
	sort_descending: bool,
	selection:       data_grid.Selection,
	status:          string,
	smoke:           bool,
}

COLUMNS: [4]data_grid.Column = {
	{key=10, label="Name", align=.Start, sortable=true},
	{key=20, label="Owner", width=150, align=.Start},
	{key=30, label="Updated", width=150, align=.Start, sortable=true},
	{key=40, label="Status", width=112, align=.Start},
}

SAMPLE_NAMES: [SAMPLE_NAME_COUNT]string = {
	"Quarterly planning",
	"Mobile launch",
	"Spring campaign",
	"Research & insights",
	"Brand refresh 2027",
	"Website migration",
	"Workspace cleanup",
	"Customer interviews",
}

OWNERS: [5]string = {"Nora Kim", "Eli Turner", "Mina Patel", "Jon Bell", "Ava Chen"}
UPDATED: [8]string = {
	"Today, 10:42", "Yesterday", "Mon, 16:08", "Jun 11",
	"Jun 10", "Jun 9", "Jun 7", "Jun 5",
}
STATUSES: [3]string = {"Ready", "Review", "Blocked"}

initialize :: proc(app: ^App) {
	app.allocator = base_runtime.heap_allocator()
	app.query, app.initialized = ui.text_buffer("", app.allocator)
	app.columns = COLUMNS
	app.selection = data_grid.Selection{row_key=1, column_key=10}
	app.status = ""
	for index in 0..<ROW_COUNT {
		name := ""
		if index < len(SAMPLE_NAMES) {
			name = SAMPLE_NAMES[index]
		} else {
			name = fmt.aprintf("Project %03d", index+1, allocator=app.allocator)
		}
		owner := OWNERS[index%len(OWNERS)]
		updated := UPDATED[index%len(UPDATED)]
		status := STATUSES[(index*7)%len(STATUSES)]
		app.source_cells[index] = {
			{text=name},
			{text=owner},
			{text=updated},
			{text=status},
		}
		app.source_rows[index] = data_grid.Row{key=u64(index+1), cells=app.source_cells[index][:]}
	}
	rebuild_projection(app)
	_ = data_grid.request_focus(&app.view)
}

contains_fold :: proc(haystack, needle: string) -> bool {
	if needle == "" { return true }
	return strings.contains(strings.to_lower(haystack, context.temp_allocator),
		strings.to_lower(needle, context.temp_allocator))
}

rebuild_projection :: proc(app: ^App) {
	app.visible_count = 0
	for index in 0..<ROW_COUNT {
		cells := app.source_cells[index]
		matches := false
		for cell in cells {
			if contains_fold(cell.text, app.query.text) {
				matches = true
				break
			}
		}
		if !matches { continue }
		app.projection[app.visible_count] = app.source_rows[index]
		app.visible_count += 1
	}
	// Sort only the application-owned projection; stable row keys keep focus
	// and selection attached to the same project as rows move.
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
	less_than := left.key < right.key
	if app.sort_column == 10 {
		less_than = left.cells[0].text < right.cells[0].text
	} else if app.sort_column == 30 {
		// The fixture's earlier keys are newer, matching the displayed dates.
		less_than = left.key < right.key
	}
	return !less_than if app.sort_descending else less_than
}

sort_proposed :: proc(app: ^App, column_key: u64) {
	if app.sort_column == column_key {
		app.sort_descending = !app.sort_descending
	} else {
		app.sort_column = column_key
		app.sort_descending = false
	}
	for index in 0..<len(app.columns) { app.columns[index].sort = .None }
	state := data_grid.Sort_State.Ascending if !app.sort_descending else data_grid.Sort_State.Descending
	if app.sort_column == 10 { app.columns[0].sort = state }
	if app.sort_column == 30 { app.columns[2].sort = state }
	rebuild_projection(app)
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	rebuild_projection(app)
	viewport := ctx.runtime.viewport
	visible_rows := clamp(int((viewport.h-360)/48), 4, 8)
	panel_width := clamp(viewport.w-220, 320, 1060)
	panel_height := max(viewport.h-234, 320)
	if viewport.w >= 1100 {
		app.columns[1].width = 200
		app.columns[2].width = 200
		app.columns[3].width = 198
	} else {
		app.columns[1].width = 150
		app.columns[2].width = 150
		app.columns[3].width = 112
	}
	status := fmt.tprintf("%d projects in this workspace", app.visible_count)
	if app.status != "" { status = app.status }

	if ui.column(ctx, key=ui.key_string("grid-example-window"), width=-1, height=-1, grow=1) {
		if ui.panel(ctx, key=ui.key_string("grid-example-titlebar"), width=-1, height=54,
			fill=ui.style_color(ctx, .Subtle_Surface)) {
			if ui.row(ctx, key=ui.key_string("grid-example-brand"), width=-1,
				height=-1, align=.Center) {
				if ui.column(ctx, key=ui.key_string("grid-example-brand-inset"), width=96, height=1) {}
				_ = ui.text(ctx, "Northstar", size=15)
			}
		}
		if ui.row(ctx, key=ui.key_string("grid-example-main"), width=-1, height=-1, grow=1) {
			if ui.panel(ctx, key=ui.key_string("grid-example-rail"), width=72, height=-1,
				fill=ui.style_color(ctx, .Subtle_Surface), align=.Center) {
				if ui.column(ctx, key=ui.key_string("grid-example-rail-top-space"), width=1, height=34) {}
				if ui.icon_button(ctx, "Northstar", .Info,
					key=ui.key_string("grid-example-brand-mark"),
					style=ui.layout_style(width=34, height=34), variant=.Primary) {
					app.status = "Northstar workspace."
				}
				if ui.column(ctx, key=ui.key_string("grid-example-rail-brand-gap"), width=1, height=26) {}
				if ui.icon_button(ctx, "Projects", .File,
					key=ui.key_string("grid-example-projects"),
					style=ui.layout_style(width=36, height=36), selected=true) {
					app.status = "Projects is the current view."
				}
				if ui.column(ctx, key=ui.key_string("grid-example-rail-projects-gap"), width=1, height=15) {}
				if ui.icon_button(ctx, "Search", .Search,
					key=ui.key_string("grid-example-search"),
					style=ui.layout_style(width=36, height=36)) {
					app.status = "Use the project filter to search this dataset."
				}
			}
			if ui.column(ctx, key=ui.key_string("grid-example-content-inset"), width=38, height=-1) {}
			if ui.column(ctx, key=ui.key_string("grid-example-content"), width=panel_width,
				height=-1, gap=19) {
				_ = ui.column(ctx, key=ui.key_string("grid-example-content-top-space"),
					width=1, height=24)
				if ui.row(ctx, key=ui.key_string("grid-example-heading"), width=-1,
					height=56, gap=12, align=.Center) {
					if ui.column(ctx, width=-1, grow=1, gap=4) {
						_ = ui.text(ctx, "Projects", size=25)
						_ = ui.text(ctx, status, size=13, color=ui.style_color(ctx, .Muted_Text))
					}
					if ui.button(ctx, "Export", key=ui.key_string("grid-example-export"),
						width=116, height=36, variant=.Quiet) {
						app.status = "Export is an application-owned action."
					}
					if ui.button(ctx, "New project", key=ui.key_string("grid-example-new"),
						width=132, height=36, variant=.Primary) {
						app.status = "Project creation is an application-owned action."
					}
				}
				if ui.panel(ctx, key=ui.key_string("grid-example-panel"), width=panel_width,
					height=panel_height, padding=16, gap=12,
					fill=ui.style_color(ctx, .Surface), radius=10,
					stroke=ui.border(1, ui.style_color(ctx, .Border), .Inside)) {
					if ui.row(ctx, key=ui.key_string("grid-example-toolbar"), width=-1,
						height=40, justify=.Space_Between, align=.Center) {
						if ui.row(ctx, key=ui.key_string("grid-example-search-controls"),
							width=-1, height=-1, gap=10, align=.Center) {
							_ = ui.icon(ctx, .Search, size=16)
							_ = ui.text_field(ctx, "Filter projects", &app.query,
								key=ui.key_string("grid-example-filter"), width=320, height=36)
						}
						app.row_count_node = ui.text(ctx, fmt.tprintf("%d rows", app.visible_count),
							key=ui.key_string("grid-example-row-count"), size=12,
							color=ui.style_color(ctx, .Muted_Text))
					}
					if event := data_grid.data_grid(
						ctx,
						&app.view,
						app.columns[:],
						app.projection[:app.visible_count],
						app.selection,
						data_grid.Options{accessible_label="Projects", row_header=true,
							max_visible_rows=visible_rows, row_height=48, header_height=42,
							cell_padding=10, header_text_size=12, cell_text_size=13},
						key=ui.key_string("grid-example-grid"),
						instance_id=7101,
					); event.kind == .Activated {
						app.selection = data_grid.Selection{row_key=event.row_key, column_key=event.column_key}
						app.status = fmt.tprintf("Selected row %d, column %d", event.row_key, event.column_key)
					} else if event.kind == .Sort_Proposed {
						sort_proposed(app, event.column_key)
					}
				}
			}
		}
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("data_grid_smoke", "rows", ROW_COUNT, "visible", app.visible_count,
			"selected", app.selection.row_key, "column", app.selection.column_key, "idle", true)
	}
	if app.initialized { ui.text_buffer_destroy(&app.query) }
	if app.allocator.procedure != nil {
		for index in SAMPLE_NAME_COUNT..<ROW_COUNT {
			delete(app.source_cells[index][0].text, app.allocator)
		}
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{smoke=smoke}
	initialize(&app)
	ui.run(&app, render, title="Northstar · Projects", width=1280, height=800,
		on_stop=stop, smoke=smoke)
}
