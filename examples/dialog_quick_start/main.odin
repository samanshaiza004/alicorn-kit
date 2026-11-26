package main

// The smallest complete AliKit Dialog consumer. The application owns when
// the dialog opens and what its action means.

import ui "alicorn:ui"
import dialog "alikit:dialog"

App :: struct {
	state: dialog.State,
	accepted: bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.panel(ctx, key=ui.key_string("quick-start-root"), width=-1,
		height=-1, padding=24, gap=12,
		fill=ui.style_color(ctx, .Window_Background), label="quick-start-root") {
		_ = ui.text(ctx, "Dialog", size=24)
		if ui.button(ctx, "Show message", key=ui.key_string("quick-start-open")) {
			_ = dialog.open(&app.state, ctx.runtime)
		}
		if app.accepted {
			_ = ui.text(ctx, "Acknowledged.", size=13)
		}
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.state.open { return }
	visible, _ := dialog.begin(ctx, &app.state, "Changes saved",
		dialog.Options{description="Your project is up to date."},
		key=ui.key_string("quick-start-dialog"), instance_id=1)
	if !visible { return }

	dialog.title(ctx, "Changes saved")
	dialog.description(ctx, "Your project is up to date.")
	if dialog.action_row_begin(ctx, key=ui.key_string("quick-start-actions")) {
		if dialog.action(ctx, &app.state, "OK", .Primary,
			key=ui.key_string("quick-start-ok")) {
			app.accepted = true
			dialog.dismiss(ctx, &app.state, .Action)
		}
		dialog.action_row_end(ctx)
	}
	dialog.end(ctx, &app.state)
}

main :: proc() {
	app := App{}
	ui.run(&app, render, title="Dialog Quick Start",
		width=720, height=480, render_overlays=render_overlays)
}
