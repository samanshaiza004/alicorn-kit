package main

// The smallest complete AliKit command-palette consumer. It uses the stock
// palette and keeps items and command dispatch in the application.

import ui "alicorn:ui"
import palette "alikit:command_palette"

ITEMS := [2]palette.Item{
	{id=palette.Item_ID(1), title="Open File", description="Browse the workspace"},
	{id=palette.Item_ID(2), title="Build Project", keywords="compile"},
}

App :: struct {
	state: palette.State,
	last_action: palette.Item_ID,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("quick-start-root"), width=-1,
		height=-1, padding=24, gap=12) {
		_ = ui.text(ctx, "Command Palette", size=24)
		_ = ui.text(ctx, "Open the palette and choose an action.", size=14)
		if ui.button(ctx, "Open commands", key=ui.key_string("quick-start-open")) {
			_ = palette.open_palette(&app.state, ctx.runtime)
		}
		if app.last_action != 0 {
			_ = ui.text(ctx, "Action selected.", size=13)
		}
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.state.open { return }
	event := palette.build(ctx, &app.state, ITEMS[:],
		ui.key_string("quick-start-palette"),
		palette.Options{title="Quick actions"})
	if event.kind == .Activated {
		app.last_action = event.item_id
		// Dispatch the stable ID in application code.
	}
}

main :: proc() {
	app := App{}
	if !palette.init(&app.state) { return }
	defer palette.destroy(&app.state)
	ui.run(&app, render, title="Command Palette Quick Start",
		width=720, height=480, render_overlays=render_overlays)
}
