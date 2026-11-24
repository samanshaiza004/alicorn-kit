package main

// Icon Picker and Dialog/Segmented composition: a modal icon chooser where the
// dialog owns dismissal, initial focus, and focus restoration, the segmented
// control owns the grid/list appearance, and the picker owns search, roving
// grid/list navigation, stable selection, and one activation proposal. The
// application owns the accepted icon and the surrounding command.
//
// Run:
//   odin run examples/icon_picker_composition -collection:alicorn=/path/to/alicorn
//   ./out/icon_picker_composition_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import dialog "../../dialog"
import picker "../../icon_picker"
import segmented "../../segmented"

CHOICES: [8]picker.Choice = {
	{key=1, label="Home", icon=.Folder_Closed, detail="Workspace home"},
	{key=2, label="Search", icon=.Search, detail="Find anything"},
	{key=3, label="Settings", icon=.Settings, detail="Preferences"},
	{key=4, label="File", icon=.File, detail="A document"},
	{key=5, label="Folder", icon=.Folder_Open, detail="A folder"},
	{key=6, label="Terminal", icon=.Terminal, detail="A terminal"},
	{key=7, label="Warning", icon=.Warning, detail="A warning"},
	{key=8, label="Locked", icon=.Close, detail="Unavailable", disabled=true},
}

VIEWS: [2]segmented.Item = {
	{value=1, label="Grid"},
	{value=2, label="List"},
}

App :: struct {
	view:     dialog.State,
	picker:   picker.State,
	segments: segmented.State,
	appearance: u64,
	selected: u64,
	status:   string,
	smoke:    bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if alicorn.container_begin(ctx, .Container, label="icon-picker-composition-root",
		key=alicorn.key_string("icon-picker-composition-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, grow=1, padding=24, gap=12),
		color=alicorn.style_color(ctx, .Window_Background)) != 0 {
		_ = ui.text(ctx, "Icon Picker + Dialog", size=26)
		_ = ui.text(ctx, "Dialog owns modal policy; Segmented owns the appearance; Picker owns search and grid navigation.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		if ui.button(ctx, "Choose icon", key=alicorn.key_string("icon-picker-composition-open"),
			width=150, height=34) {
			_ = dialog.open(&app.view, ctx.runtime)
		}
		_ = ui.text(ctx, app.status, size=13, color=alicorn.style_color(ctx, .Muted_Text))
		alicorn.container_end(ctx)
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.view.open { return }
	visible, event := dialog.begin(ctx, &app.view, "Choose an icon",
		dialog.Options{description="Pick the icon to insert into the document.",
			primary_key=alicorn.key_string("icon-picker-composition-close")},
		key=alicorn.key_string("icon-picker-composition-dialog"), instance_id=8201)
	if !visible {
		if event.kind == .Dismissed { app.status = "Icon chooser dismissed." }
		return
	}
	dialog.title(ctx, "Choose an icon")
	dialog.description(ctx, "Search by name or keyword. The segmented control switches the appearance.")
	if dialog.content_begin(ctx, key=alicorn.key_string("icon-picker-composition-content")) {
		if segmented_event := segmented.control(
			ctx,
			&app.segments,
			VIEWS[:],
			app.appearance,
			segmented.Options{accessible_label="Icon appearance", width=220, height=32},
			key=alicorn.key_string("icon-picker-composition-appearance"),
			instance_id=8202,
		); segmented_event.kind == .Selection_Proposed {
			app.appearance = segmented_event.value
		}
		picker_event := picker.picker(
			ctx,
			&app.picker,
			CHOICES[:],
			picker.Options{accessible_label="Icon choices",
				appearance=.List if app.appearance == 2 else .Grid,
				columns=5, cell_size=44, cell_gap=6, row_height=34, max_visible_rows=4},
			key=alicorn.key_string("icon-picker-composition-picker"),
			instance_id=8203,
		)
		if picker_event.kind == .Activated {
			app.selected = picker_event.key
			app.status = fmt.tprintf("Icon %d chosen.", picker_event.key)
			dialog.dismiss(ctx, &app.view, .Action)
		}
		dialog.content_end(ctx)
	}
	if dialog.action_row_begin(ctx, key=alicorn.key_string("icon-picker-composition-actions")) {
		if dialog.action(ctx, &app.view, "Cancel", .Cancel,
			key=alicorn.key_string("icon-picker-composition-cancel")) {
			app.status = "Icon chooser cancelled."
			dialog.dismiss(ctx, &app.view, .Action)
		}
		dialog.action_row_end(ctx)
	}
	dialog.end(ctx, &app.view)
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("icon_picker_composition_smoke", "selected", app.selected,
			"appearance", app.appearance, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{appearance=1, selected=1, status="Open the chooser.", smoke=smoke}
	if !picker.init(&app.picker) { return }
	defer picker.destroy(&app.picker)
	app.picker.selected_key = app.selected
	ui.run(&app, render, title="Alicorn - Icon Picker Composition", width=820, height=620,
		render_overlays=render_overlays, on_stop=stop, smoke=smoke)
}
