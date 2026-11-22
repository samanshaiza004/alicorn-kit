package main

// Palette Parts example. The result list is the copyable AliKit part; this
// host application owns the query, filtering, modal shell, and dispatch. AliKit
// owns selection by stable ID, enabled-row navigation, reveal, semantics, and
// one activation event.
//
// Run:
//   odin run examples/palette_parts -collection:alicorn=/path/to/alicorn
//   ./out/palette_parts_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import model "alikit:palette_model"
import parts "alikit:palette_parts"

ITEMS := [6]model.Item{
	{id=model.Item_ID(1), title="Open File", description="Browse the workspace", keywords="file browse"},
	{id=model.Item_ID(2), title="Search in Files", description="Find text across the workspace", keywords="find grep"},
	{id=model.Item_ID(3), title="Build Project", description="Run the configured build", keywords="compile"},
	{id=model.Item_ID(4), title="Publish Release", description="Unavailable in this example", keywords="ship", disabled=true},
	{id=model.Item_ID(5), title="Open Settings", description="Adjust editor preferences", keywords="preferences options"},
	{id=model.Item_ID(6), title="Show Notifications", description="Review recent activity", keywords="alerts inbox"},
}

App :: struct {
	query:   ui.Text_Buffer,
	ready:   bool,
	matches: [len(ITEMS)]model.Match,
	visible: int,
	results: parts.State,
	last:    model.Item_ID,
	smoke:   bool,
}

rebuild :: proc(app: ^App) {
	app.visible, _ = model.filter(ITEMS[:], app.query.text, app.matches[:])
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.ready { return }
	rebuild(app)
	if alicorn.container_begin(ctx, .Container, label="palette-parts-example-root",
		key=alicorn.key_string("palette-parts-example-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, grow=1, padding=24, gap=12),
		color=alicorn.style_color(ctx, .Window_Background)) != 0 {
		_ = ui.text(ctx, "Palette Parts", size=26)
		_ = ui.text(ctx, "The application owns the query and matching; AliKit owns the result list interaction.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		_ = ui.text_field(ctx, "Filter", &app.query,
			key=alicorn.key_string("palette-parts-example-query"), width=360, height=32)
		if ui.panel(ctx, key=alicorn.key_string("palette-parts-example-panel"), width=460,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=6,
			fill=alicorn.style_color(ctx, .Surface), radius=10,
			stroke=ui.border(1, alicorn.style_color(ctx, .Border), .Inside)) {
			event := parts.results(
				ctx,
				&app.results,
				ITEMS[:],
				app.matches[:app.visible],
				key=alicorn.key_string("palette-parts-example-results"),
				options=parts.Options{accessible_label="Commands", list_max_height=260},
			)
			if event.kind == .Activated {
				app.last = event.item_id
			}
		}
		status := "Click the list, then use Up/Down and Return."
		if app.last != 0 {
			status = fmt.tprintf("Activated item ID: %d", model.item_id_value(app.last))
		}
		_ = ui.text(ctx, status, size=13, color=alicorn.style_color(ctx, .Muted_Text))
		_ = ui.text(ctx, fmt.tprintf("%d of %d items match", app.visible, len(ITEMS)),
			size=12, color=alicorn.style_color(ctx, .Muted_Text))
		alicorn.container_end(ctx)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{smoke=smoke}
	app.query, app.ready = ui.text_buffer("", context.allocator)
	if !app.ready {
		fmt.eprintln("Could not initialize the palette parts query buffer.")
		return
	}
	defer ui.text_buffer_destroy(&app.query)
	ui.run(&app, render, title="AliKit Palette Parts", width=640, height=460, smoke=smoke)
}
