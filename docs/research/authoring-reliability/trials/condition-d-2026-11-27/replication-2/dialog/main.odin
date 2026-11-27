package main

import ui "alicorn:ui"
import "alikit:dialog"

App :: struct {
	confirm: dialog.State,
	alert: dialog.State,
	confirm_description: string,
	deleted: bool,
	alert_acknowledged: bool,
}

DESCRIPTION :: "“Summer Archive” and its files will be removed from Northstar for everyone with access. This action cannot be undone, and any active downloads will stop."

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.panel(ctx, key=ui.key_string("workspace-root"), width=-1, height=-1, grow=1,
		fill=ui.rgb(0x12151A), label="workspace") {
			if ui.panel(ctx, key=ui.key_string("workspace-header"), width=-1, height=54,
				padding=16, fill=ui.rgb(0x191D24), label="header") {
				if ui.row(ctx, key=ui.key_string("brand-row"), width=-1, height=-1,
					align=.Center, gap=12) {
					_ = ui.box(ctx, key=ui.key_string("traffic-red"), width=12, height=12,
						fill=ui.rgb(0xF07972), radius=6)
					_ = ui.box(ctx, key=ui.key_string("traffic-yellow"), width=12, height=12,
						fill=ui.rgb(0xE9BE5B), radius=6)
					_ = ui.box(ctx, key=ui.key_string("traffic-green"), width=12, height=12,
						fill=ui.rgb(0x64BD77), radius=6)
					_ = ui.text(ctx, "Northstar", key=ui.key_string("brand"), size=15, color=ui.rgb(0xE7EAF0))
				}
			}

			if ui.row(ctx, key=ui.key_string("workspace-main"), width=-1, height=-1,
				grow=1, gap=0) {
				if ui.panel(ctx, key=ui.key_string("settings-rail"), width=224, height=-1,
					padding=14, gap=14, fill=ui.rgb(0x171B21), label="settings") {
					_ = ui.text(ctx, "SETTINGS", size=11, color=ui.rgb(0x778292))
					_ = ui.text(ctx, "Profile", size=14, color=ui.rgb(0xA4ADBB))
					_ = ui.text(ctx, "Members", size=14, color=ui.rgb(0xA4ADBB))
					if ui.panel(ctx, key=ui.key_string("projects-selection"), width=-1,
						height=38, padding=10, fill=ui.rgb(0x252B35), radius=7) {
						_ = ui.text(ctx, "Projects", size=14, color=ui.rgb(0xE7EAF0))
					}
					_ = ui.text(ctx, "Billing", size=14, color=ui.rgb(0xA4ADBB))
					_ = ui.text(ctx, "Security", size=14, color=ui.rgb(0xA4ADBB))
				}

				if ui.column(ctx, key=ui.key_string("project-settings"), width=-1,
					height=-1, grow=1, padding=46, gap=16) {
					_ = ui.text(ctx, "Project settings", size=25, color=ui.rgb(0xE7EAF0))
					_ = ui.text(ctx, "Manage access, details, and retention.", size=14, color=ui.rgb(0xA4ADBB))

					if ui.panel(ctx, key=ui.key_string("archive-card"), width=-1, height=94,
						padding=24, fill=ui.rgb(0x1A1F27), radius=9, stroke=ui.border(1, ui.rgb(0x2C333E))) {
						if ui.row(ctx, key=ui.key_string("archive-row"), width=-1, height=-1,
							align=.Center, gap=20) {
							if ui.column(ctx, key=ui.key_string("archive-copy"), width=-1,
								grow=1, gap=8) {
								_ = ui.text(ctx, "Summer Archive", size=15, color=ui.rgb(0xE7EAF0))
								_ = ui.text(ctx, "Owner: Nora Kim · 14 files · 2 members", size=13, color=ui.rgb(0xA4ADBB))
							}
							if ui.button(ctx, "Delete project", key=ui.key_string("open-delete"),
								variant=.Danger, width=116, height=36) {
								_ = dialog.open(&app.confirm, ctx.runtime)
							}
						}
					}

					if ui.panel(ctx, key=ui.key_string("access-card"), width=-1, height=94,
						padding=24, fill=ui.rgb(0x1A1F27), radius=9, stroke=ui.border(1, ui.rgb(0x2C333E))) {
						if ui.column(ctx, width=-1, height=-1, justify=.Center, gap=8) {
								_ = ui.text(ctx, "Workspace access", size=15, color=ui.rgb(0xE7EAF0))
							_ = ui.text(ctx, "Only invited members can view this project.", size=13, color=ui.rgb(0xA4ADBB))
						}
					}

					if ui.panel(ctx, key=ui.key_string("retention-card"), width=-1, height=94,
						padding=24, fill=ui.rgb(0x1A1F27), radius=9, stroke=ui.border(1, ui.rgb(0x2C333E))) {
						if ui.column(ctx, width=-1, height=-1, justify=.Center, gap=8) {
								_ = ui.text(ctx, "File retention", size=15, color=ui.rgb(0xE7EAF0))
							_ = ui.text(ctx, "Files are retained until the project is deleted.", size=13, color=ui.rgb(0xA4ADBB))
						}
					}

					if ui.button(ctx, "Show alert", key=ui.key_string("open-alert"),
						width=104, height=32) {
						_ = dialog.open(&app.alert, ctx.runtime)
					}
				}
			}
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	confirm_options := dialog.Options{
		description=app.confirm_description,
		width=516,
		height=0,
		max_height=560,
		padding=40,
		gap=12,
		action_gap=12,
		focus=.Configured,
		focus_key=ui.key_string("cancel-delete"),
		focus_kind=.Button,
		primary_key=ui.key_string("confirm-delete"),
	}
	if app.confirm.open {
		visible, _ := dialog.begin(ctx, &app.confirm, "Delete project?", confirm_options,
			key=ui.key_string("delete-dialog"), instance_id=1)
		if visible {
			dialog.title(ctx, "Delete project?")
			dialog.description(ctx, app.confirm_description)
			if dialog.content_begin(ctx, ui.key_string("delete-details")) {
				if ui.panel(ctx, key=ui.key_string("delete-details-panel"), width=-1, height=58,
						padding=16, fill=ui.rgb(0x292F39), radius=8,
						stroke=ui.border(1, ui.rgb(0x3B424E))) {
					if ui.row(ctx, key=ui.key_string("delete-details-row"), width=-1, height=-1,
						align=.Center, gap=15) {
						_ = ui.box(ctx, key=ui.key_string("delete-detail-icon"), width=25, height=25,
							fill=ui.rgb(0x4A3438), radius=6)
						if ui.column(ctx, key=ui.key_string("delete-detail-copy"), width=-1,
							grow=1, gap=3) {
							_ = ui.text(ctx, "14 files · 2 members", key=ui.key_string("detail-count"), size=13, color=ui.rgb(0xE7EAF0))
							_ = ui.text(ctx, "Shared access ends immediately.", key=ui.key_string("detail-note"), size=12, color=ui.rgb(0xA4ADBB))
						}
					}
				}
				dialog.content_end(ctx)
			}
			_ = ui.box(ctx, key=ui.key_string("delete-separator"), width=-1, height=1,
				fill=ui.rgb(0x3B424E))
			if dialog.action_row_begin(ctx, options=confirm_options,
				key=ui.key_string("delete-actions")) {
				if dialog.action(ctx, &app.confirm, "Cancel", .Cancel,
					key=ui.key_string("cancel-delete"), width=112, height=40) {
					dialog.dismiss(ctx, &app.confirm, .Action)
				}
				if dialog.action(ctx, &app.confirm, "Delete project", .Danger,
					key=ui.key_string("confirm-delete"), width=153, height=40) {
					app.deleted = true
					dialog.dismiss(ctx, &app.confirm, .Action)
				}
				dialog.action_row_end(ctx)
			}
			dialog.end(ctx, &app.confirm)
		}
	}

	if app.alert.open {
		alert_options := dialog.Options{
			description="This project has no pending changes.",
			variant=.Alert_Dialog,
			width=420,
			height=0,
			padding=24,
			gap=12,
		}
		visible, _ := dialog.begin(ctx, &app.alert, "Project is safe", alert_options,
			key=ui.key_string("safe-alert"), instance_id=2)
		if visible {
			dialog.title(ctx, "Project is safe")
			dialog.description(ctx, "This project has no pending changes.")
			if dialog.action_row_begin(ctx, options=alert_options,
				key=ui.key_string("safe-alert-actions")) {
				if dialog.action(ctx, &app.alert, "Got it", .Primary,
					key=ui.key_string("alert-acknowledge"), width=96, height=40) {
					app.alert_acknowledged = true
					dialog.dismiss(ctx, &app.alert, .Action)
				}
				dialog.action_row_end(ctx)
			}
			dialog.end(ctx, &app.alert)
		}
	}
}

main :: proc() {
	app := App{confirm_description=DESCRIPTION}
	ui.run(&app, render, title="Northstar", width=1280, height=800,
		render_overlays=render_overlays)
}
