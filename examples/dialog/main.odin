package main

// Dialog reference example. The ordinary application imports the high-level
// UI facade and the Dialog component; it does not need alicorn:runtime.

import "core:fmt"
import "core:os"
import ui "alicorn:ui"
import dialog "../../dialog"

DELETE_DESCRIPTION :: "“Summer Archive” and its files will be removed from Northstar for everyone with access. This action cannot be undone, and any active downloads will stop."

App :: struct {
	delete_dialog: dialog.State,
	alert_dialog:  dialog.State,
	status:        string,
	smoke:         bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("dialog-example-root"), width=-1, height=-1,
		padding=24, gap=12) {
		if ui.row(ctx, key=ui.key_string("dialog-example-heading"), width=-1,
			height=42, align=.Center, justify=.Space_Between) {
			_ = ui.text(ctx, "Project settings", size=25)
			if ui.button(ctx, "Show alert", key=ui.key_string("dialog-example-alert-open"),
				width=110, height=34, variant=.Quiet) {
				_ = dialog.open(&app.alert_dialog, ctx.runtime)
			}
		}
		_ = ui.text(ctx, "Manage access, details, and retention.",
			size=14, color=ui.style_color(ctx, .Muted_Text))

		if ui.panel(ctx, key=ui.key_string("dialog-example-project"), width=-1,
			height=94, padding=16, justify=.Center,
			fill=ui.style_color(ctx, .Surface), radius=9) {
			if ui.row(ctx, key=ui.key_string("dialog-example-project-row"),
				width=-1, align=.Center, gap=16) {
				if ui.column(ctx, key=ui.key_string("dialog-example-project-copy"),
					width=-1, grow=1, gap=6) {
					_ = ui.text(ctx, "Summer Archive", size=15)
					_ = ui.text(ctx, "Owner: Nora Kim · 14 files · 2 members",
						size=13, color=ui.style_color(ctx, .Muted_Text))
				}
				if ui.button(ctx, "Delete project",
					key=ui.key_string("dialog-example-delete-open"),
					width=116, height=36, variant=.Quiet) {
					_ = dialog.open(&app.delete_dialog, ctx.runtime)
				}
			}
		}
		if ui.panel(ctx, key=ui.key_string("dialog-example-access"), width=-1,
			height=94, padding=16, justify=.Center,
			fill=ui.style_color(ctx, .Surface), radius=9) {
			_ = ui.text(ctx, "Workspace access", size=15)
			_ = ui.text(ctx, "Only invited members can view this project.",
				size=13, color=ui.style_color(ctx, .Muted_Text))
		}
		if ui.panel(ctx, key=ui.key_string("dialog-example-retention"), width=-1,
			height=94, padding=16, justify=.Center,
			fill=ui.style_color(ctx, .Surface), radius=9) {
			_ = ui.text(ctx, "File retention", size=15)
			_ = ui.text(ctx, "Files are retained until this project is deleted.",
				size=13, color=ui.style_color(ctx, .Muted_Text))
		}
		if app.status != "" {
			_ = ui.text(ctx, app.status, size=13,
				color=ui.style_color(ctx, .Muted_Text))
		}
	}
}

render_delete_dialog :: proc(app: ^App, ctx: ^ui.UI) {
	visible, event := dialog.begin(ctx, &app.delete_dialog, "Delete project?",
		dialog.Options{
			description=DELETE_DESCRIPTION,
			primary_key=ui.key_string("dialog-delete-confirm"),
			focus=.Configured,
			focus_key=ui.key_string("dialog-delete-cancel"),
			focus_kind=.Button,
			width=516,
			max_height=500,
			padding=24,
			gap=12,
			action_gap=12,
		},
		key=ui.key_string("dialog-example-delete"), instance_id=7401)
	if !visible {
		if event.kind == .Dismissed { app.status = "Deletion cancelled." }
		return
	}

	dialog.title(ctx, "Delete project?")
	dialog.description(ctx, DELETE_DESCRIPTION)
	if dialog.content_begin(ctx, ui.key_string("dialog-delete-details")) {
		if ui.panel(ctx, key=ui.key_string("dialog-delete-summary"), width=-1,
			height=58, padding=12, gap=3,
			fill=ui.style_color(ctx, .Surface), radius=8) {
			_ = ui.text(ctx, "14 files · 2 members", size=13)
			_ = ui.text(ctx, "Shared access ends immediately.",
				size=12, color=ui.style_color(ctx, .Muted_Text))
		}
		dialog.content_end(ctx)
	}
	if dialog.action_row_begin(ctx,
		dialog.Options{action_gap=12}, ui.key_string("dialog-delete-actions")) {
		// Compose regular public buttons here because the reference needs 40 px
		// actions; dialog.action currently fixes its own button height at 32 px.
		if ui.button(ctx, "Cancel", key=ui.key_string("dialog-delete-cancel"),
			width=112, height=40, variant=.Quiet) {
			app.status = "Deletion cancelled."
			dialog.dismiss(ctx, &app.delete_dialog, .Action)
		}
		if ui.button(ctx, "Delete project", key=ui.key_string("dialog-delete-confirm"),
			width=153, height=40, variant=.Primary) {
			app.status = "Project deleted."
			dialog.dismiss(ctx, &app.delete_dialog, .Action)
		}
		dialog.action_row_end(ctx)
	}
	dialog.end(ctx, &app.delete_dialog)
}

render_alert_dialog :: proc(app: ^App, ctx: ^ui.UI) {
	visible, event := dialog.begin(ctx, &app.alert_dialog, "Storage is full",
		dialog.Options{
			variant=.Alert_Dialog,
			description="Free space before continuing.",
			primary_key=ui.key_string("dialog-alert-ok"),
		},
		key=ui.key_string("dialog-example-alert"), instance_id=7402)
	if !visible {
		if event.kind == .Dismissed { app.status = "Alert dismissed." }
		return
	}

	dialog.title(ctx, "Storage is full")
	dialog.description(ctx, "Free space before continuing. Escape and backdrop dismissal are prevented.")
	if dialog.action_row_begin(ctx, key=ui.key_string("dialog-example-alert-actions")) {
		if dialog.action(ctx, &app.alert_dialog, "OK", .Primary,
			key=ui.key_string("dialog-alert-ok")) {
			app.status = "Alert acknowledged."
			dialog.dismiss(ctx, &app.alert_dialog, .Action)
		}
		dialog.action_row_end(ctx)
	}
	dialog.end(ctx, &app.alert_dialog)
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if app.delete_dialog.open {
		render_delete_dialog(app, ctx)
	} else if app.alert_dialog.open {
		render_alert_dialog(app, ctx)
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
	app := App{status="Open a dialog to review the focus and dismissal behavior.", smoke=smoke}
	ui.run(&app, render, title="Northstar · Project Settings", width=1280, height=800,
		render_overlays=render_overlays, on_stop=stop, smoke=smoke)
}
