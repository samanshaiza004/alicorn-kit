package main

// Dialog example: one Dialog and one Alert_Dialog over Alicorn modal overlays.
// The component owns Escape/backdrop policy, initial focus, and restoration.
//
// Run:
//   odin run examples/dialog -collection:alicorn=/path/to/alicorn
//   ./out/dialog_example.exe --smoke

import "core:fmt"
import "core:os"
import ui "alicorn:ui"
import dialog "../../dialog"

App :: struct {
	view:   dialog.State,
	alert:  dialog.State,
	status: string,
	smoke:  bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("dialog-example-root"), width=-1, height=-1,
		padding=24, gap=12) {
		_ = ui.text(ctx, "Dialog", size=26)
		_ = ui.text(ctx, "Composable modal parts with baked-in dismissal, focus placement, and focus restoration.",
			size=13, color=ui.style_color(ctx, .Muted_Text))
		if ui.row(ctx, gap=10) {
			if ui.button(ctx, "Delete record", key=ui.key_string("dialog-example-open"),
				width=150, height=34) {
				_ = dialog.open(&app.view, ctx.runtime)
			}
			if ui.button(ctx, "Alert", key=ui.key_string("dialog-example-alert"),
				width=110, height=34, variant=.Quiet) {
				_ = dialog.open(&app.alert, ctx.runtime)
			}
		}
		_ = ui.text(ctx, app.status, size=13, color=ui.style_color(ctx, .Muted_Text))
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if app.view.open {
		visible, event := dialog.begin(ctx, &app.view, "Delete record",
			dialog.Options{description="This cannot be undone.",
				primary_key=ui.key_string("dialog-confirm")},
			key=ui.key_string("dialog-example-dialog"), instance_id=7401)
		if !visible {
			if event.kind == .Dismissed { app.status = "Dismissed without deleting." }
			return
		}
		dialog.title(ctx, "Delete record")
		dialog.description(ctx, "Record 003 will be removed. This cannot be undone.")
		if dialog.action_row_begin(ctx, key=ui.key_string("dialog-example-actions")) {
			if dialog.action(ctx, &app.view, "Delete", .Primary, key=ui.key_string("dialog-confirm")) {
				app.status = "Record deleted."
				dialog.dismiss(ctx, &app.view, .Action)
			}
			if dialog.action(ctx, &app.view, "Cancel", .Cancel, key=ui.key_string("dialog-cancel")) {
				app.status = "Cancelled."
				dialog.dismiss(ctx, &app.view, .Action)
			}
			dialog.action_row_end(ctx)
		}
		dialog.end(ctx, &app.view)
	}
	if app.alert.open {
		visible, event := dialog.begin(ctx, &app.alert, "Storage is full",
			dialog.Options{variant=.Alert_Dialog, description="Free space before continuing.",
				primary_key=ui.key_string("alert-confirm")},
			key=ui.key_string("dialog-example-alert-dialog"), instance_id=7402)
		if !visible {
			if event.kind == .Dismissed { app.status = "Alert dismissed." }
			return
		}
		dialog.title(ctx, "Storage is full")
		dialog.description(ctx, "Free space before continuing. Escape and backdrop dismissal are prevented.")
		if dialog.action_row_begin(ctx, key=ui.key_string("dialog-example-alert-actions")) {
			if dialog.action(ctx, &app.alert, "OK", .Primary, key=ui.key_string("alert-confirm")) {
				app.status = "Alert acknowledged."
				dialog.dismiss(ctx, &app.alert, .Action)
			}
			dialog.action_row_end(ctx)
		}
		dialog.end(ctx, &app.alert)
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("dialog_smoke", "status", app.status, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{status="Open a dialog.", smoke=smoke}
	ui.run(&app, render, title="Alicorn - Dialog", width=760, height=460,
		render_overlays=render_overlays, on_stop=stop, smoke=smoke)
}
