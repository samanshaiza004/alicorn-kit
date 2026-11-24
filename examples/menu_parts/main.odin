package main

// Menu parts example: author-owned row content and an ad-hoc semantic group.
// The component still owns the anchored popup, Menu_Item semantics, roving
// navigation, checked/disabled states, Escape/outside dismissal, and focus
// restoration. This file owns the icons, two-line text, checkmark, group label,
// and shortcut chips inside each row.
//
// Run:
//   odin run examples/menu_parts -collection:alicorn=/path/to/alicorn
//   ./out/menu_parts_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import menu "../../menu"

ITEMS: [7]menu.Item = {
	{key=1, label="Rename", detail="Change the display name", shortcut="F2"},
	{key=2, label="Pin to top", detail="Keep this file above recent files", checked=true},
	{key=3, kind=.Separator},
	{key=4, label="Archive", detail="Unavailable while syncing", disabled=true},
	{key=5, label="Move to trash", detail="Reversible for 30 days", shortcut="Del"},
	{key=6, kind=.Separator},
	{key=7, label="Properties", detail="Size, owner, and sharing", shortcut="Alt+Enter"},
}

App :: struct {
	view:   menu.State,
	pinned: bool,
	status: string,
	smoke:  bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("menu-parts-example-root"), width=-1, height=-1,
		padding=24, gap=12) {
		_ = ui.text(ctx, "Menu parts", size=26)
		_ = ui.text(ctx, "Custom icon, detail, checkmark, and group label inside the semantic Menu_Item owner.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		_ = menu.trigger(ctx, &app.view, "File actions",
			menu.Options{accessible_label="File actions"},
			key=alicorn.key_string("menu-parts-example-trigger"))
		_ = ui.text(ctx, app.status, size=13, color=alicorn.style_color(ctx, .Muted_Text))
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	visible, chosen := menu.popup_begin(ctx, &app.view, ITEMS[:],
		menu.Options{accessible_label="File actions", popup_width=300},
		key=alicorn.key_string("menu-parts-example-popup"), instance_id=7501)
	if !visible {
		if chosen != 0 { apply(app, chosen) }
		return
	}
	for item, index in ITEMS {
		if item.kind == .Separator {
			menu.separator(ctx, index)
			continue
		}
		if index == 4 {
			_ = menu.group_begin(ctx, &app.view, "Danger zone",
				key=alicorn.key_string("menu-parts-example-danger"))
		}
		row, row_visible := menu.item_begin(ctx, &app.view, item, index,
			menu.Options{accessible_label="File actions", popup_width=300})
		if row_visible {
			if menu.row_surface(ctx, row) != 0 {
				_ = ui.icon(ctx, .File, key=ui.key_pair(0xA11C_6D50, item.key), size=16,
					color_role=.Muted_Text if row.disabled else .Text)
				if ui.column(ctx, key=ui.key_pair(0xA11C_6D51, item.key), grow=1, gap=1) {
					_ = ui.text(ctx, item.label, key=ui.key_pair(0xA11C_6D52, item.key), size=13,
						color=alicorn.style_color(ctx, .Muted_Text if row.disabled else .Text))
					_ = ui.text(ctx, item.detail, key=ui.key_pair(0xA11C_6D53, item.key), size=10,
						color=alicorn.style_color(ctx, .Muted_Text))
				}
				if row.checked {
					_ = ui.icon(ctx, .Check, key=ui.key_pair(0xA11C_6D54, item.key), size=14,
						color_role=.Accent)
				}
				if item.shortcut != "" {
					_ = ui.text(ctx, item.shortcut, key=ui.key_pair(0xA11C_6D55, item.key), size=10,
						color=alicorn.style_color(ctx, .Muted_Text))
				}
				alicorn.surface_end(ctx)
			}
			if menu.item_end(ctx, row) { apply(app, item.key) }
		}
		if index == 5 { menu.group_end(ctx) }
	}
	menu.popup_end(ctx, &app.view)
}

apply :: proc(app: ^App, key: u64) {
	switch key {
	case 1: app.status = "Rename proposed."
	case 2:
		app.pinned = !app.pinned
		app.status = "Pin toggled by the application."
	case 5: app.status = "Move to trash proposed."
	case 7: app.status = "Properties proposed."
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("menu_parts_smoke", "pinned", app.pinned, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{status="Open the menu to choose a command.", smoke=smoke}
	ui.run(&app, render, title="Alicorn - Menu Parts", width=820, height=520,
		render_overlays=render_overlays, on_stop=stop, smoke=smoke)
}
