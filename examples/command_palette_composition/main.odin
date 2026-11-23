package main

// Command Palette and Segmented composition: the segmented control owns the
// current search scope (Commands / Files / Navigation), and the command palette
// searches the application-owned result set for that scope. The application
// owns the accepted scope, filtering, ranking, opening policy, and dispatch.
// The palette keeps its modal shell, controlled query, selection, and focus
// restoration; the segmented control keeps its own semantics and focus.
//
// Run:
//   odin run examples/command_palette_composition -collection:alicorn=/path/to/alicorn
//   ./out/command_palette_composition_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import palette "alikit:command_palette"
import segmented "../../segmented"
import model "alikit:palette_model"

SCOPES: [3]segmented.Item = {
	{value=1, label="Commands"},
	{value=2, label="Files"},
	{value=3, label="Navigation"},
}

COMMANDS: [4]model.Item = {
	{id=model.Item_ID(1), title="Build project", description="Run the configured build", keywords="compile"},
	{id=model.Item_ID(2), title="Run tests", description="Execute the full workspace suite", keywords="test"},
	{id=model.Item_ID(3), title="Open settings", description="Adjust editor preferences", keywords="preferences"},
	{id=model.Item_ID(4), title="Publish release", description="Unavailable while checks run", keywords="ship", disabled=true},
}

FILES: [3]model.Item = {
	{id=model.Item_ID(11), title="main.odin", description="src/main.odin", keywords="source"},
	{id=model.Item_ID(12), title="README.md", description="Project overview", keywords="docs"},
	{id=model.Item_ID(13), title="theme.json", description="examples/theme.json", keywords="theme"},
}

NAVIGATION: [3]model.Item = {
	{id=model.Item_ID(21), title="Go to definition", description="Jump to the symbol", keywords="symbol"},
	{id=model.Item_ID(22), title="Go to line", description="Enter a line number", keywords="line"},
	{id=model.Item_ID(23), title="Go to file", description="Search workspace files", keywords="file"},
}

App :: struct {
	palette:  palette.State,
	segments: segmented.State,
	scope:    u64,
	last:     model.Item_ID,
	status:   string,
	smoke:    bool,
}

scope_items :: proc(scope: u64) -> []model.Item {
	switch scope {
	case 2: return FILES[:]
	case 3: return NAVIGATION[:]
	}
	return COMMANDS[:]
}

scope_label :: proc(scope: u64) -> string {
	for item in SCOPES {
		if item.value == scope { return item.label }
	}
	return "Commands"
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if alicorn.container_begin(ctx, .Container, label="command-palette-composition-root",
		key=alicorn.key_string("command-palette-composition-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, grow=1, padding=24, gap=12),
		color=alicorn.style_color(ctx, .Window_Background)) != 0 {
		_ = ui.text(ctx, "Palette + Segmented", size=26)
		_ = ui.text(ctx, "The segmented control owns the search scope; the palette searches that application-owned set.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		if event := segmented.control(
			ctx,
			&app.segments,
			SCOPES[:],
			app.scope,
			segmented.Options{accessible_label="Search scope", width=360, height=34},
			key=alicorn.key_string("command-palette-composition-scope"),
			instance_id=7701,
		); event.kind == .Selection_Proposed {
			app.scope = event.value
			app.status = fmt.tprintf("Search scope: %s.", scope_label(event.value))
		}
		if !app.palette.open {
			if ui.button(ctx, "Search", key=alicorn.key_string("command-palette-composition-open"),
				width=140, height=32, variant=.Primary) {
				_ = palette.open_palette(&app.palette, ctx.runtime, .Caller_Filtered)
			}
		}
		_ = ui.text(ctx, app.status, size=13, color=alicorn.style_color(ctx, .Muted_Text))
		alicorn.container_end(ctx)
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.palette.open { return }
	event := palette.build(
		ctx,
		&app.palette,
		scope_items(app.scope),
		key=alicorn.key_string("command-palette-composition-palette"),
		options=palette.Options{
			title=fmt.tprintf("Search %s", scope_label(app.scope)),
			results_accessible_name=fmt.tprintf("%s results", scope_label(app.scope)),
		},
	)
	if event.kind == .Activated {
		app.last = event.item_id
		app.status = fmt.tprintf("Activated item ID %d in %s.", model.item_id_value(event.item_id),
			scope_label(app.scope))
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("command_palette_composition_smoke", "scope", app.scope,
			"last", model.item_id_value(app.last), "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{scope=1, status="Choose a scope, then open the palette.", smoke=smoke}
	if !palette.init(&app.palette) { return }
	defer palette.destroy(&app.palette)
	ui.run(&app, render, title="Alicorn - Command Palette Composition", width=760, height=520,
		render_overlays=render_overlays, on_stop=stop, smoke=smoke)
}
