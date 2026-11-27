package main

import "core:fmt"
import "core:mem"
import "core:strings"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import data_grid "alikit:data_grid"

ROW_COUNT :: 200
COLUMN_COUNT :: 4
GRID_INSTANCE_ID :: u64(1)

App :: struct {
	allocator: mem.Allocator,
	query: ui.Text_Buffer,
	query_ready: bool,
	rows: [ROW_COUNT]data_grid.Row,
	cells: [ROW_COUNT][COLUMN_COUNT]data_grid.Cell,
	generated_names: [ROW_COUNT]string,
	projection: [ROW_COUNT]data_grid.Row,
	visible_count: int,
	columns: [COLUMN_COUNT]data_grid.Column,
	view: data_grid.State,
	selection: data_grid.Selection,
	max_visible_rows: int,
	sort_column: int,
	sort_direction: data_grid.Sort_State,
	accepted_activations: int,
	sort_proposals: int,
	filter_request_count: int,
	reveal_request_count: int,
}

initialize :: proc(state: rawptr, _rt: ^alicorn.Runtime) {
	app := cast(^App)state
	if app == nil { return }
	app.allocator = context.allocator
	app.query, app.query_ready = ui.text_buffer("", app.allocator)
	app.columns = [COLUMN_COUNT]data_grid.Column{
		{key=1, label="NAME", sortable=true},
		{key=2, label="OWNER", sortable=true},
		{key=3, label="UPDATED", sortable=true},
		{key=4, label="STATUS", sortable=true},
	}
	app.selection = data_grid.Selection{row_key=1, column_key=1}
	app.sort_column = -1
	app.sort_direction = .None

	names := [8]string{
		"Quarterly planning", "Mobile launch", "Spring campaign", "Research & insights",
		"Brand refresh 2027", "Website migration", "Workspace cleanup", "Customer interviews",
	}
	owners := [5]string{"Nora Kim", "Eli Turner", "Mina Patel", "Sam Rivera", "Jordan Lee"}
	updated := [8]string{"Today, 10:42", "Yesterday", "Mon, 16:08", "Jun 11", "Jun 10", "Jun 9", "Jun 7", "Jun 5"}
	statuses := [3]string{"Ready", "Review", "Blocked"}
	for i := 0; i < ROW_COUNT; i += 1 {
		name := ""
		if i < len(names) {
			name = names[i]
		} else {
			name = fmt.aprintf("Project %03d", i+1)
			app.generated_names[i] = name
		}
		app.cells[i] = [COLUMN_COUNT]data_grid.Cell{
			{text=name},
			{text=owners[i%len(owners)]},
			{text=updated[i%len(updated)]},
			{text=statuses[i%len(statuses)]},
		}
		app.rows[i] = data_grid.Row{
			key=u64(i+1),
			cells=app.cells[i][:],
			disabled=i == 10,
		}
	}
	app.max_visible_rows = 8
	rebuild_projection(app)
	_ = data_grid.request_focus(&app.view)
}

destroy :: proc(app: ^App) {
	if app == nil { return }
	if app.query_ready { ui.text_buffer_destroy(&app.query) }
	for name in app.generated_names {
		if len(name) > 0 { delete(name, app.allocator) }
	}
}

@(private)
rebuild_projection :: proc(app: ^App) {
	if app == nil { return }
	query := app.query.text
	app.visible_count = 0
	for row in app.rows {
		if len(query) > 0 && strings.index(row.cells[0].text, query) < 0 { continue }
		app.projection[app.visible_count] = row
		app.visible_count += 1
	}
	if app.sort_column >= 0 && app.sort_direction != .None {
		for i := 1; i < app.visible_count; i += 1 {
			j := i
			for j > 0 {
				left := app.projection[j-1].cells[app.sort_column].text
				right := app.projection[j].cells[app.sort_column].text
				order := strings.compare(left, right)
				before := order > 0 if app.sort_direction == .Descending else order < 0
				if !before { break }
				tmp := app.projection[j-1]
				app.projection[j-1] = app.projection[j]
				app.projection[j] = tmp
				j -= 1
			}
		}
	}
	for index := 0; index < COLUMN_COUNT; index += 1 {
		app.columns[index].sort = .None
		if index == app.sort_column { app.columns[index].sort = app.sort_direction }
	}
}

@(private)
layout_dimensions :: proc(app: ^App, ctx: ^ui.UI) {
	if app == nil || ctx == nil || ctx.runtime == nil { return }
	width := ctx.runtime.viewport.w
	height := ctx.runtime.viewport.h
	visible := int((height-360)/48)
	app.max_visible_rows = clamp(visible, 4, 8)
	if app.visible_count == 0 { rebuild_projection(app) }
	needs_scrollbar := app.visible_count > app.max_visible_rows
	gutter := f32(0)
	if needs_scrollbar { gutter = alicorn.SCROLLBAR_THICKNESS }
	track_width := max(width-72-48-32-gutter, f32(572))
	track_width = max(track_width, 0)
	widths := [COLUMN_COUNT]f32{
		track_width*0.41,
		track_width*0.19,
		track_width*0.20,
		track_width-track_width*0.80,
	}
	minimums := [COLUMN_COUNT]f32{240, 108, 112, 112}
	for i := 0; i < COLUMN_COUNT; i += 1 {
		app.columns[i].width = widths[i]
		app.columns[i].min_width = minimums[i]
	}
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if app == nil || ctx == nil { return }
	drain_semantic_requests(app, ctx)
	rebuild_projection(app)

	if ui.panel(ctx, key=ui.key_string("projects-root"), width=-1, height=-1, grow=1,
		fill=ui.rgb(0x12151A), padding=0) {
		if ui.panel(ctx, key=ui.key_string("window-titlebar"), width=-1, height=54,
			fill=ui.rgb(0x191D24), padding=20) {
			if ui.row(ctx, key=ui.key_string("titlebar-content"), width=-1, height=-1,
				align=.Center, gap=8) {
				_ = ui.box(ctx, size=12, fill=ui.rgb(0xF07972), radius=6)
				_ = ui.box(ctx, size=12, fill=ui.rgb(0xE9BE5B), radius=6)
				_ = ui.box(ctx, size=12, fill=ui.rgb(0x64BD77), radius=6)
				_ = ui.text(ctx, "Northstar", size=15, color=ui.rgb(0xE7EAF0),
					style=ui.layout_style(.Row, width=100, height=-1, padding=8, align=.Center))
			}
		}
		if ui.row(ctx, key=ui.key_string("workspace-body"), width=-1, height=-1, grow=1) {
			if ui.panel(ctx, key=ui.key_string("sidebar"), width=72, height=-1,
				fill=ui.rgb(0x171B21), padding=18, gap=14) {
				_ = ui.button(ctx, "+", key=ui.key_string("sidebar-new"), width=36, height=36)
				_ = ui.button(ctx, "▦", key=ui.key_string("sidebar-projects"), width=36, height=36,
					state=alicorn.Button_State{selected=true})
				_ = ui.button(ctx, "⌕", key=ui.key_string("sidebar-search"), width=36, height=36)
			}
			if ui.column(ctx, key=ui.key_string("main-content"), width=-1, height=-1,
				grow=1, padding=24, gap=18) {
				if ui.row(ctx, key=ui.key_string("projects-heading"), width=-1, height=60,
					align=.Center, gap=12) {
					if ui.column(ctx, key=ui.key_string("heading-copy"), width=-1, height=-1,
						grow=1, gap=4) {
						_ = ui.text(ctx, "Projects", size=25, color=ui.rgb(0xE7EAF0),
							text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD})
						_ = ui.text(ctx, "200 projects in this workspace", size=14, color=ui.rgb(0xA4ADBB))
					}
					_ = ui.button(ctx, "Export", key=ui.key_string("export"), width=92, height=36)
					_ = ui.button(ctx, "New project", key=ui.key_string("new-project"), width=120,
						height=36, variant=.Primary)
				}
				if ui.panel(ctx, key=ui.key_string("grid-card"), width=-1,
					height=alicorn.LAYOUT_SIZE_FIT_CONTENT, grow=1, padding=16, gap=12,
					fill=ui.rgb(0x1B2028), radius=10,
					stroke=ui.border(1, ui.rgb(0x343B47))) {
					if ui.row(ctx, key=ui.key_string("grid-toolbar"), width=-1, height=38,
						align=.Center, gap=12) {
						_ = ui.text_field(ctx, "Filter projects", &app.query,
							key=ui.key_string("grid-filter"), width=320, height=38)
						// The controlled field adopts edits into the caller buffer during
						// description, so project the changed value before drawing status/grid.
						rebuild_projection(app)
						layout_dimensions(app, ctx)
						_ = ui.text(ctx, fmt.tprintf("%d rows", app.visible_count),
							key=ui.key_string("grid-row-count"), size=12,
							color=ui.rgb(0xA4ADBB), style=ui.layout_style(.Row, width=-1,
							height=-1, justify=.End))
					}
					options := data_grid.Options{
						accessible_label="Projects",
						empty_label="No matching projects",
						row_header=true,
						row_height=48,
						header_height=42,
						max_visible_rows=app.max_visible_rows,
						cell_padding=12,
						header_text_size=12,
						cell_text_size=13,
					}
					event := data_grid.data_grid(ctx, &app.view, app.columns[:],
						app.projection[:app.visible_count], app.selection, options,
						key=ui.key_string("projects-grid"), instance_id=GRID_INSTANCE_ID)
					switch event.kind {
					case .Activated:
						app.selection = data_grid.Selection{row_key=event.row_key,
							column_key=event.column_key}
						app.accepted_activations += 1
						alicorn.invalidate_root(ctx.runtime, "data grid activation accepted by application")
					case .Sort_Proposed:
						proposal_index := -1
						for column, i in app.columns {
							if column.key == event.column_key { proposal_index = i; break }
						}
						if proposal_index >= 0 {
							if proposal_index == app.sort_column && app.sort_direction == .Ascending {
								app.sort_direction = .Descending
							} else {
								app.sort_column = proposal_index
								app.sort_direction = .Ascending
							}
							app.sort_proposals += 1
							rebuild_projection(app)
							alicorn.invalidate_root(ctx.runtime, "data grid sort proposal accepted by application")
						}
					case .None:
					}
				}
			}
		}
	}
}

@(private)
drain_semantic_requests :: proc(app: ^App, ctx: ^ui.UI) {
	if app == nil || ctx == nil || ctx.runtime == nil { return }
	filter_node, filter_found := alicorn.node_by_key(ctx.runtime,
		ui.key_string("grid-filter"), .Text_Field)
	filter_id: alicorn.Semantic_ID
	if filter_found { filter_id = alicorn.semantic_visual_id(filter_node) }
	for {
		request, found := alicorn.semantic_request_pop(ctx.runtime)
		if !found { break }
		if request.kind == .Perform && request.id == filter_id && request.action == .Set_Value {
			if ui.text_buffer_set(&app.query, request.text_value) { app.filter_request_count += 1 }
		} else if request.kind == .Reveal {
			if data_grid.handle_semantic_reveal_request(&app.view, ctx.runtime,
				app.projection[:app.visible_count], GRID_INSTANCE_ID, request) {
				app.reveal_request_count += 1
			}
		}
		alicorn.semantic_request_event_destroy(ctx.runtime, &request)
	}
}

main :: proc() {
	app: App
	ui.run(&app, render, title="Northstar — Projects", width=1280, height=800,
		on_initialize=initialize_native, on_stop=destroy)
}

initialize_test :: proc(state: rawptr, rt: ^alicorn.Runtime) {
	initialize(state, rt)
}

initialize_native :: proc(app: ^App, rt: ^alicorn.Runtime) {
	initialize(rawptr(app), rt)
}
