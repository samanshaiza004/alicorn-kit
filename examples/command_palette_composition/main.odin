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
import ui "alicorn:ui"
import palette "alikit:command_palette"
import segmented "../../segmented"

SCOPES: [3]segmented.Item = {
	{value=1, label="Commands"},
	{value=2, label="Files"},
	{value=3, label="Navigation"},
}

COMMANDS: [4]palette.Item = {
	{id=palette.Item_ID(1), title="Build project", description="Run the configured build", keywords="compile"},
	{id=palette.Item_ID(2), title="Run tests", description="Execute the full workspace suite", keywords="test"},
	{id=palette.Item_ID(3), title="Open settings", description="Adjust editor preferences", keywords="preferences"},
	{id=palette.Item_ID(4), title="Publish release", description="Unavailable while checks run", keywords="ship", disabled=true},
}

FILES: [3]palette.Item = {
	{id=palette.Item_ID(11), title="main.odin", description="src/main.odin", keywords="source"},
	{id=palette.Item_ID(12), title="README.md", description="Project overview", keywords="docs"},
	{id=palette.Item_ID(13), title="theme.json", description="examples/theme.json", keywords="theme"},
}

NAVIGATION: [3]palette.Item = {
	{id=palette.Item_ID(21), title="Go to definition", description="Jump to the symbol", keywords="symbol"},
	{id=palette.Item_ID(22), title="Go to line", description="Enter a line number", keywords="line"},
	{id=palette.Item_ID(23), title="Go to file", description="Search workspace files", keywords="file"},
}

App :: struct {
	palette_state: palette.State,
	segments: segmented.State,
	scope:    u64,
	last:     palette.Item_ID,
	status:   string,
	smoke:    bool,
}

scope_items :: proc(scope: u64) -> []palette.Item {
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
	if ui.column(ctx, key=ui.key_string("command-palette-composition-root"),
		width=-1, height=-1, grow=1, padding=24, gap=12,
		label="command-palette-composition-root") {
		_ = ui.text(ctx, "Palette + Segmented", size=26)
		_ = ui.text(ctx, "The segmented control owns the search scope; the palette searches that application-owned set.",
			size=13, color=ui.style_color(ctx, .Muted_Text))
		if event := segmented.control(
			ctx,
			&app.segments,
			SCOPES[:],
			app.scope,
			segmented.Options{accessible_label="Search scope", width=360, height=34},
			key=ui.key_string("command-palette-composition-scope"),
			instance_id=7701,
		); event.kind == .Selection_Proposed {
			app.scope = event.value
			app.status = fmt.tprintf("Search scope: %s.", scope_label(event.value))
		}
		if !app.palette_state.open {
			if ui.button(ctx, "Search", key=ui.key_string("command-palette-composition-open"),
				width=140, height=32, variant=.Primary) {
				_ = palette.open_palette(&app.palette_state, ctx.runtime, .Caller_Filtered)
			}
		}
		_ = ui.text(ctx, app.status, size=13, color=ui.style_color(ctx, .Muted_Text))
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.palette_state.open { return }
	event := palette.build(
		ctx,
		&app.palette_state,
		scope_items(app.scope),
		key=ui.key_string("command-palette-composition-palette"),
		options=palette.Options{
			title=fmt.tprintf("Search %s", scope_label(app.scope)),
			results_accessible_name=fmt.tprintf("%s results", scope_label(app.scope)),
		},
	)
	if event.kind == .Activated {
		app.last = event.item_id
		app.status = fmt.tprintf("Activated item ID %d in %s.", u64(event.item_id),
			scope_label(app.scope))
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("command_palette_composition_smoke", "scope", app.scope,
			"last", u64(app.last), "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{scope=1, status="Choose a scope, then open the palette.", smoke=smoke}
	if !palette.init(&app.palette_state) { return }
	defer palette.destroy(&app.palette_state)
	ui.run(&app, render, title="Alicorn - Command Palette Composition", width=760, height=520,
		render_overlays=render_overlays, on_stop=stop, smoke=smoke)
}
