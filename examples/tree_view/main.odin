package main

import "core:fmt"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import tree_view "alikit:tree_view"
import model "alikit:tree_model"

SOURCE_ROWS :: [5]model.Item{
	{id=model.Item_ID(1), label="src", depth=0, expandable=true},
	{id=model.Item_ID(2), parent_id=model.Item_ID(1), label="main.odin", depth=1},
	{id=model.Item_ID(3), parent_id=model.Item_ID(1), label="ui", depth=1, expandable=true},
	{id=model.Item_ID(4), parent_id=model.Item_ID(3), label="theme.odin", depth=2},
	{id=model.Item_ID(5), label="README.md", depth=0},
}

App :: struct {
	view:       tree_view.State,
	expanded:   [5]bool,
	rows:       [5]tree_view.Item,
	row_count:  int,
	revision:   u64,
	last_item:  model.Item_ID,
}

rebuild_rows :: proc(app: ^App) {
	app.row_count = 0
	source_rows := SOURCE_ROWS
	for source, source_index in source_rows {
		visible := true
		parent_id := source.parent_id
		for parent_id != 0 {
			parent_index := -1
			for candidate, candidate_index in source_rows {
				if candidate.id == parent_id { parent_index = candidate_index; break }
			}
			if parent_index < 0 || !app.expanded[parent_index] {
				visible = false
				break
			}
			parent_id = source_rows[parent_index].parent_id
		}
		if !visible { continue }
		row := source
		row.expanded = app.expanded[source_index]
		app.rows[app.row_count] = row
		app.row_count += 1
	}
}

row_icon :: proc(_data: rawptr, item: tree_view.Item) -> alicorn.Icon_ID {
	if !item.expandable { return .File }
	if item.expanded { return .Folder_Open }
	return .Folder_Closed
}

apply_event :: proc(app: ^App, event: tree_view.Event) {
	if app == nil { return }
	#partial switch event.kind {
	case .Pressed:
		app.last_item = event.id
	case .Activated:
		app.last_item = event.id
	case .Expand_Requested, .Collapse_Requested:
		source_rows := SOURCE_ROWS
		for source, index in source_rows {
			if source.id == event.id {
				app.expanded[index] = event.kind == .Expand_Requested
				app.revision += 1
				break
			}
		}
		rebuild_rows(app)
	}
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	_ = ui.text(ctx, "AliKit · Tree View", size=24)
	_ = ui.text(ctx, "Use Up/Down to move, Left/Right to collapse or expand, and Enter to activate.")
	if app.last_item != 0 {
		_ = ui.text(ctx, fmt.tprintf("Focused item ID: %d", u64(app.last_item)))
	}
	window := tree_view.Window{total_count=app.row_count, revision=app.revision, items=app.rows[:app.row_count]}
	event := tree_view.build(ctx, &app.view, window, alicorn.key_string("example-tree"),
		tree_view.Options{
			accessible_label="Project files",
			selection_enabled=true,
			select_on_focus=true,
			icon_proc=row_icon,
		})
	apply_event(app, event)
}

main :: proc() {
	app := App{expanded={true, true, false, false, false}, revision=1}
	rebuild_rows(&app)
	ui.run(&app, render, title="AliKit Tree View", width=760, height=520)
}
