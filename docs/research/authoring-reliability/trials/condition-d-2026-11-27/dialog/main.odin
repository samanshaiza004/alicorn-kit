package main

import ui "alicorn:ui"
import dialog "alikit:dialog"

DELETE_DIALOG_KEY :: "reference-delete-dialog"
ALERT_DIALOG_KEY :: "reference-alert-dialog"
DELETE_OPEN_KEY :: "reference-delete-open"
ALERT_OPEN_KEY :: "reference-alert-open"
CANCEL_KEY :: "reference-delete-cancel"
DELETE_KEY :: "reference-delete-confirm"
ALERT_OK_KEY :: "reference-alert-ok"

DELETE_COPY :: "‘Summer Archive’ and its files will be removed from Northstar for everyone with access. This action cannot be undone, and any active downloads will stop."
ALERT_COPY :: "The project has been removed and access is no longer available."

App :: struct {
	delete_dialog: dialog.State,
	alert_dialog: dialog.State,
	delete_open_count: int,
	delete_count: int,
	cancel_count: int,
	alert_acknowledged: bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if !ui.panel(ctx, key=ui.key_string("workspace-root"), width=-1, height=-1, grow=1,
		fill=ui.rgb(0x12151a), label="Northstar workspace") {
		return
	}

	if ui.panel(ctx, key=ui.key_string("workspace-topbar"), width=-1, height=54,
		padding=0, fill=ui.rgb(0x191d24), label="workspace-topbar") {
		if ui.row(ctx, key=ui.key_string("workspace-topbar-content"), width=-1, height=-1,
			padding=16, gap=12, align=.Center) {
			_ = ui.box(ctx, key=ui.key_string("workspace-mark"), size=12, fill=ui.rgb(0x64bd77), radius=6)
			_ = ui.text(ctx, "Northstar", key=ui.key_string("workspace-brand"), size=15,
				color=ui.rgb(0xe7eaf0))
		}
	}

	if ui.row(ctx, key=ui.key_string("workspace-body"), width=-1, height=-1, grow=1, align=.Stretch) {
		if ui.panel(ctx, key=ui.key_string("workspace-sidebar"), width=224, height=-1,
			padding=14, gap=8, fill=ui.rgb(0x171b21), label="settings-sidebar") {
			_ = ui.text(ctx, "SETTINGS", key=ui.key_string("sidebar-caption"), size=11,
				color=ui.rgb(0x778292))
			_ = ui.text(ctx, "Profile", key=ui.key_string("sidebar-profile"), size=14, color=ui.rgb(0xa4adbb),
				style=ui.layout_style(.Row, width=-1, height=34, padding=10, align=.Center))
			_ = ui.text(ctx, "Members", key=ui.key_string("sidebar-members"), size=14, color=ui.rgb(0xa4adbb),
				style=ui.layout_style(.Row, width=-1, height=34, padding=10, align=.Center))
			if ui.panel(ctx, key=ui.key_string("sidebar-current"), width=-1, height=38,
				padding=10, fill=ui.rgb(0x252b35), radius=7, label="current-setting") {
				_ = ui.text(ctx, "Projects", key=ui.key_string("sidebar-projects"), size=14, color=ui.rgb(0xe7eaf0))
			}
			_ = ui.text(ctx, "Billing", key=ui.key_string("sidebar-billing"), size=14, color=ui.rgb(0xa4adbb),
				style=ui.layout_style(.Row, width=-1, height=34, padding=10, align=.Center))
			_ = ui.text(ctx, "Security", key=ui.key_string("sidebar-security"), size=14, color=ui.rgb(0xa4adbb),
				style=ui.layout_style(.Row, width=-1, height=34, padding=10, align=.Center))
		}

		if ui.column(ctx, key=ui.key_string("settings-content"), width=-1, height=-1, grow=1,
			padding=46, gap=16, align=.Stretch) {
			if ui.row(ctx, key=ui.key_string("settings-heading-row"), width=-1, height=56, align=.Center) {
				if ui.column(ctx, key=ui.key_string("settings-heading"), width=-1, grow=1, gap=2) {
					_ = ui.text(ctx, "Project settings", key=ui.key_string("settings-title"), size=25,
						color=ui.rgb(0xe7eaf0))
					_ = ui.text(ctx, "Manage access, details, and retention.", key=ui.key_string("settings-subtitle"),
						size=14, color=ui.rgb(0xa4adbb))
				}
				if ui.button(ctx, "Show alert", key=ui.key_string(ALERT_OPEN_KEY),
					variant=.Quiet, width=104, height=34) {
					_ = dialog.open(&app.alert_dialog, ctx.runtime)
				}
			}

			if ui.panel(ctx, key=ui.key_string("project-card"), width=-1, height=94, padding=24,
				fill=ui.rgb(0x1a1f27), radius=9, stroke=ui.border(1, ui.rgb(0x2c333e)), label="project-card") {
				if ui.row(ctx, key=ui.key_string("project-card-content"), width=-1, height=-1,
					align=.Center, gap=16) {
					if ui.column(ctx, key=ui.key_string("project-card-copy"), width=-1, grow=1, gap=4) {
						_ = ui.text(ctx, "Summer Archive", key=ui.key_string("project-card-title"), size=15,
							color=ui.rgb(0xe7eaf0))
						_ = ui.text(ctx, "Owner: Nora Kim · 14 files · 2 members",
							key=ui.key_string("project-card-details"), size=13, color=ui.rgb(0xa4adbb))
					}
					if ui.button(ctx, "Delete project", key=ui.key_string(DELETE_OPEN_KEY),
						variant=.Danger, width=116, height=36) {
						app.delete_open_count += 1
						_ = dialog.open(&app.delete_dialog, ctx.runtime)
					}
				}
			}

			if ui.panel(ctx, key=ui.key_string("access-card"), width=-1, height=94, padding=24,
				fill=ui.rgb(0x1a1f27), radius=9, stroke=ui.border(1, ui.rgb(0x2c333e)), label="access-card") {
				_ = ui.text(ctx, "Workspace access", key=ui.key_string("access-title"), size=15,
					color=ui.rgb(0xe7eaf0))
				_ = ui.text(ctx, "Only invited members can view this project.",
					key=ui.key_string("access-copy"), size=13, color=ui.rgb(0xa4adbb))
			}
			if ui.panel(ctx, key=ui.key_string("retention-card"), width=-1, height=94, padding=24,
				fill=ui.rgb(0x1a1f27), radius=9, stroke=ui.border(1, ui.rgb(0x2c333e)), label="retention-card") {
				_ = ui.text(ctx, "File retention", key=ui.key_string("retention-title"), size=15,
					color=ui.rgb(0xe7eaf0))
				_ = ui.text(ctx, "Files are retained until the project is deleted.",
					key=ui.key_string("retention-copy"), size=13, color=ui.rgb(0xa4adbb))
			}
		}
	}
	_ = app
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if app.delete_dialog.open {
		options := dialog.Options{
			description=DELETE_COPY,
			width=516,
			height=382,
			max_height=560,
			padding=40,
			gap=22,
			action_gap=12,
			focus=.Configured,
			focus_key=ui.key_string(CANCEL_KEY),
			focus_kind=.Button,
			primary_key=ui.key_string(DELETE_KEY),
		}
		visible, event := dialog.begin(ctx, &app.delete_dialog, "Delete project?", options,
			key=ui.key_string(DELETE_DIALOG_KEY), instance_id=1)
		if !visible {
			_ = event
			return
		}
		_ = ui.text(ctx, "Delete project?", key=ui.key_string("delete-dialog-title"), size=22,
			color=ui.style_color(ctx, .Text))
		_ = ui.text(ctx, DELETE_COPY, key=ui.key_string("delete-dialog-description"), size=14,
			color=ui.style_color(ctx, .Muted_Text), text_style=ui.Text_Style{overflow=.Wrap})
		if ui.panel(ctx, key=ui.key_string("delete-detail-row"), width=-1, height=58,
			padding=16, fill=ui.rgb(0x292f39), radius=8, stroke=ui.border(1, ui.rgb(0x3b424e)),
			label="deletion-details") {
			if ui.row(ctx, key=ui.key_string("delete-detail-content"), width=-1, height=-1,
				align=.Center, gap=12) {
				if ui.panel(ctx, key=ui.key_string("delete-detail-icon"), width=25, height=25,
					padding=0, fill=ui.rgb(0x4a3438), radius=6, justify=.Center, align=.Center,
					label="delete-icon") {
					_ = ui.text(ctx, "×", key=ui.key_string("delete-icon-mark"), size=16, color=ui.rgb(0xe8b5b5))
				}
				if ui.column(ctx, key=ui.key_string("delete-detail-copy"), width=-1, grow=1,
					gap=2, justify=.Center) {
					_ = ui.text(ctx, "14 files · 2 members", key=ui.key_string("delete-detail-title"),
						size=13, color=ui.rgb(0xe7eaf0))
					_ = ui.text(ctx, "Shared access ends immediately.",
						key=ui.key_string("delete-detail-description"), size=12, color=ui.rgb(0xa4adbb))
				}
			}
		}
		if ui.panel(ctx, key=ui.key_string("delete-separator"), width=-1, height=1,
			padding=0, fill=ui.rgb(0x3b424e), label="delete-separator") {}
		if ui.column(ctx, key=ui.key_string("delete-action-area"), width=-1, height=50,
			justify=.End, label="delete-action-area") {
			if ui.row(ctx, key=ui.key_string("delete-actions"), width=-1, height=40,
				gap=12, align=.Center, justify=.End) {
				if dialog.action(ctx, &app.delete_dialog, "Cancel", .Cancel,
					key=ui.key_string(CANCEL_KEY), width=112, height=40) {
					app.cancel_count += 1
					dialog.dismiss(ctx, &app.delete_dialog, .Action)
				}
				if ui.button(ctx, "Delete project", key=ui.key_string(DELETE_KEY),
					variant=.Danger, width=153, height=40) {
					app.delete_count += 1
					dialog.dismiss(ctx, &app.delete_dialog, .Action)
				}
			}
		}
		dialog.end(ctx, &app.delete_dialog)
	}

	if app.alert_dialog.open {
		options := dialog.Options{
			variant=.Alert_Dialog,
			description=ALERT_COPY,
			width=420,
			max_height=560,
			primary_key=ui.key_string(ALERT_OK_KEY),
		}
		visible, _ := dialog.begin(ctx, &app.alert_dialog, "Project removed", options,
			key=ui.key_string(ALERT_DIALOG_KEY), instance_id=2)
		if !visible { return }
		dialog.title(ctx, "Project removed")
		dialog.description(ctx, ALERT_COPY)
		if dialog.action_row_begin(ctx, key=ui.key_string("alert-actions")) {
			if dialog.action(ctx, &app.alert_dialog, "OK", .Primary, key=ui.key_string(ALERT_OK_KEY)) {
				app.alert_acknowledged = true
				dialog.dismiss(ctx, &app.alert_dialog, .Action)
			}
			dialog.action_row_end(ctx)
		}
		dialog.end(ctx, &app.alert_dialog)
	}
}

main :: proc() {
	app := App{}
	ui.run(&app, render, title="Northstar · Project settings", width=1280, height=800,
		render_overlays=render_overlays)
}
