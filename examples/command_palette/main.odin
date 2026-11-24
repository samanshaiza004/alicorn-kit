package main

// The default command palette needs only Alicorn's high-level UI package and
// the AliKit component. Import lower-level packages when an application uses
// APIs that are not wrapped by those public surfaces.

import "core:fmt"
import "core:os"
import ui "alicorn:ui"
import palette "alikit:command_palette"

SAMPLE_ITEMS :: [4]palette.Item{
	{ id=palette.Item_ID(1), title="Open File", description="Browse the workspace", keywords="file browse" },
	{ id=palette.Item_ID(2), title="Search in Files", description="Find text across the workspace", keywords="find grep" },
	{ id=palette.Item_ID(3), title="Build Project", description="Run the configured build", keywords="compile" },
	{ id=palette.Item_ID(4), title="Publish Release", description="Unavailable in this example", keywords="ship", disabled=true },
}

App :: struct {
	palette_state: palette.State,
	items:       [4]palette.Item,
	last_action: palette.Item_ID,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, padding=16, gap=8) {
		_ = ui.text(ctx, "AliKit · Command Palette", size=24)
		_ = ui.text(ctx, "Press the host command-palette shortcut, or open it with the button.")
		if !app.palette_state.open {
			if ui.button(ctx, "Open palette", key=ui.key_string("command-palette-example-open"),
				width=140, height=30, variant=.Primary) {
				_ = palette.open_palette(&app.palette_state, ctx.runtime)
			}
		}
		if app.last_action != 0 {
			_ = ui.text(ctx, fmt.tprintf("Last activated item ID: %d", u64(app.last_action)))
		}
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.palette_state.open { return }
	event := palette.build(ctx, &app.palette_state, app.items[:],
		key=ui.key_string("alikit-example-palette"),
		options=palette.Options{
			title="Example Actions",
			query_accessible_name="Search example actions",
		})
	if event.kind == .Activated { app.last_action = event.item_id }
}

on_key :: proc(app: ^App, rt: ^ui.Runtime, key: ui.Application_Key) -> bool {
	if !app.palette_state.open && key == .Open_Command_Palette {
		_ = palette.open_palette(&app.palette_state, rt)
		return true
	}
	return false
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{items=SAMPLE_ITEMS}
	if !palette.init(&app.palette_state) {
		fmt.eprintln("Could not initialize the command palette state.")
		return
	}
	defer palette.destroy(&app.palette_state)
	ui.run(&app, render, title="AliKit Command Palette", width=760, height=520,
		on_key=on_key, render_overlays=render_overlays, smoke=smoke)
}
