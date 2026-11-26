package main

// A compact Data Grid consumer. The application owns the rows and accepted
// selection; AliKit owns grid navigation, semantics, and activation proposals.

import ui "alicorn:ui"
import data_grid "alikit:data_grid"

App :: struct {
	grid:      data_grid.State,
	columns:   [2]data_grid.Column,
	cells:     [3][2]data_grid.Cell,
	rows:      [3]data_grid.Row,
	selection: data_grid.Selection,
}

initialize :: proc(app: ^App) {
	app.columns = {
		{key=1, label="File", align=.Start},
		{key=2, label="Type", width=120, align=.Start},
	}
	app.cells = {
		{{text="README.md"}, {text="Markdown"}},
		{{text="main.odin"}, {text="Odin"}},
		{{text="theme.json"}, {text="JSON"}},
	}
	for index in 0..<len(app.rows) {
		app.rows[index] = data_grid.Row{key=u64(index+1), cells=app.cells[index][:]}
	}
	app.selection = data_grid.Selection{row_key=1, column_key=1}
	_ = data_grid.request_focus(&app.grid)
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.panel(ctx, key=ui.key_string("quick-start-root"), width=-1,
		height=-1, padding=24, gap=12,
		fill=ui.style_color(ctx, .Window_Background), label="quick-start-root") {
		_ = ui.text(ctx, "Recent files", size=24)
		_ = ui.text(ctx, "Use the arrow keys to move through the grid.", size=14)
		if event := data_grid.data_grid(ctx, &app.grid, app.columns[:], app.rows[:],
			app.selection,
			data_grid.Options{accessible_label="Recent files", row_header=true,
				max_visible_rows=3},
			key=ui.key_string("quick-start-grid"), instance_id=1);
			event.kind == .Activated {
			app.selection = data_grid.Selection{
				row_key=event.row_key,
				column_key=event.column_key,
			}
		}
	}
}

main :: proc() {
	app := App{}
	initialize(&app)
	ui.run(&app, render, title="Data Grid Quick Start",
		width=720, height=480)
}
