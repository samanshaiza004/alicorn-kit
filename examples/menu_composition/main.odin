package main

// Menu and Dialog composition: a modal share dialog with an anchored menu for
// link permissions. Dialog owns Escape/backdrop policy, initial focus, and
// focus restoration for the dialog; Menu owns its anchored popup, roving
// navigation, dismissal, and trigger focus restoration. The application owns
// the chosen permission, dialog actions, and dispatch.
//
// Run:
//   odin run examples/menu_composition -collection:alicorn=/path/to/alicorn
//   ./out/menu_composition_example.exe --smoke

import "core:fmt"
import "core:os"
import ui "alicorn:ui"
import dialog "../../dialog"
import menu "../../menu"

PERMISSIONS: [4]menu.Item = {
	{key=1, label="Anyone with the link", detail="View and comment", checked=true},
	{key=2, label="Workspace", detail="Only members of this workspace"},
	{key=3, kind=.Separator},
	{key=4, label="Private", detail="Only invited people"},
}

App :: struct {
	view:       dialog.State,
	permissions: menu.State,
	permission: u64,
	status:     string,
	smoke:      bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("menu-composition-root"), width=-1, height=-1,
		padding=24, gap=12) {
		_ = ui.text(ctx, "Menu + Dialog", size=26)
		_ = ui.text(ctx, "The dialog owns its modal policy; the menu inside it owns an anchored popup.",
			size=13, color=ui.style_color(ctx, .Muted_Text))
		if ui.button(ctx, "Share file", key=ui.key_string("menu-composition-open"),
			width=140, height=34) {
			_ = dialog.open(&app.view, ctx.runtime)
		}
		_ = ui.text(ctx, app.status, size=13, color=ui.style_color(ctx, .Muted_Text))
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if app.view.open {
		visible, event := dialog.begin(ctx, &app.view, "Share file",
			dialog.Options{description="Choose who can open this file.",
				primary_key=ui.key_string("menu-composition-done")},
			key=ui.key_string("menu-composition-dialog"), instance_id=7601)
		if !visible {
			if event.kind == .Dismissed { app.status = "Share dialog dismissed." }
			return
		}
		dialog.title(ctx, "Share file")
		dialog.description(ctx, "The permission menu is an anchored component popup over the dialog.")
		if dialog.content_begin(ctx, key=ui.key_string("menu-composition-content")) {
			_ = ui.text(ctx, "Permission", size=12, color=ui.style_color(ctx, .Muted_Text))
			_ = menu.trigger(ctx, &app.permissions, permission_label(app.permission),
				menu.Options{accessible_label="Link permission"},
				key=ui.key_string("menu-composition-trigger"))
			dialog.content_end(ctx)
		}
		if dialog.action_row_begin(ctx, key=ui.key_string("menu-composition-actions")) {
			if dialog.action(ctx, &app.view, "Done", .Primary,
				key=ui.key_string("menu-composition-done")) {
				app.status = fmt.tprintf("Shared with permission %d.", app.permission)
				dialog.dismiss(ctx, &app.view, .Action)
			}
			dialog.action_row_end(ctx)
		}
		dialog.end(ctx, &app.view)
	}

	// The menu overlay describes after the dialog so it stacks above it. The
	// menu's own modal scope owns input while it is open.
	visible, chosen := menu.popup_begin(ctx, &app.permissions, PERMISSIONS[:],
		menu.Options{accessible_label="Link permission"},
		key=ui.key_string("menu-composition-popup"), instance_id=7602)
	if !visible {
		if chosen != 0 {
			app.permission = chosen
			app.permissions.active_key = chosen
			app.status = fmt.tprintf("Permission %d accepted.", chosen)
		}
		return
	}
	for item, index in PERMISSIONS {
		if item.kind == .Separator {
			menu.separator(ctx, index)
			continue
		}
		value := item
		value.checked = item.key == app.permission
		if menu.item(ctx, &app.permissions, value, index) {
			app.permission = value.key
			app.status = fmt.tprintf("Permission %d accepted.", value.key)
		}
	}
	menu.popup_end(ctx, &app.permissions)
}

permission_label :: proc(key: u64) -> string {
	for item in PERMISSIONS {
		if item.key == key { return item.label }
	}
	return "Choose permission"
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("menu_composition_smoke", "permission", app.permission, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{permission=1, status="Open the share dialog.", smoke=smoke}
	ui.run(&app, render, title="Alicorn - Menu Composition", width=820, height=520,
		render_overlays=render_overlays, on_stop=stop, smoke=smoke)
}
