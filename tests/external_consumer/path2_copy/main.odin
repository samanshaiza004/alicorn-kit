package main

// External consumer, authoring path 2: copy component sources into the
// application's own tree. tools/validate_external_consumer.ps1 copies every
// declared component source closure into path2_copy/vendor/ and rewrites all
// intra-AliKit imports to local packages. The build needs only the Alicorn
// collection; there is no `alikit` collection or AliKit topology.
//
// Build (exact collection args recorded by the harness):
//   odin build . -collection:alicorn=<alicorn>
// Run:
//   external_consumer_path2.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import command_palette "./vendor/command_palette"
import data_grid "./vendor/data_grid"
import dialog "./vendor/dialog"
import icon_picker "./vendor/icon_picker"
import menu "./vendor/menu"
import notices "./vendor/notices"
import palette_parts "./vendor/palette_parts"
import progress "./vendor/progress"
import radio "./vendor/radio_group"
import scroll_area "./vendor/scroll_area"
import segmented "./vendor/segmented"
import sidebar "./vendor/sidebar"
import table "./vendor/table"
import tree_view "./vendor/tree_view"

PLANS := [3]radio.Option{
	{value=201, label="Personal", description="One workspace and local history"},
	{value=202, label="Team", description="Shared review, comments, and exports"},
	{value=203, label="Enterprise", description="Audit policy and private mirrors", disabled=true},
}

COPY_ACTIONS := [3]menu.Item{
	{key=301, label="Copy plan link", shortcut="Ctrl+C"},
	{key=302, label="Change billing contact"},
	{key=303, label="Remove workspace", disabled=true},
}

// Referencing each component's public state/data type makes Odin compile the
// complete copied package set rather than only the controls used in this app.
Copy_Package_Proof :: struct {
	command_palette: command_palette.State,
	tree_view:       tree_view.State,
	icon_picker:     icon_picker.State,
	palette_parts:   palette_parts.State,
	radio_group:     radio.State,
	progress:        progress.State,
	segmented:       segmented.State,
	notices:         notices.State,
	sidebar:          sidebar.State,
	table_row:       table.Row,
	menu:            menu.State,
	data_grid:       data_grid.State,
	dialog:           dialog.State,
	scroll_area:      scroll_area.State,
}

App :: struct {
	copy_proof: Copy_Package_Proof,
	group:    radio.State,
	actions:  menu.State,
	selected: u64,
	status:   string,
	smoke:    bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("copied-root"), width=-1, height=-1,
		padding=28, gap=14, align=.Center) {
		_ = ui.text(ctx, "AliKit external consumer", size=26)
		_ = ui.text(ctx, "Copied Radio Group and Menu packages; no alikit collection is required.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		_ = menu.trigger(ctx, &app.actions, "Workspace actions",
			menu.Options{accessible_label="Workspace actions"},
			key=alicorn.key_string("copied-menu-trigger"))

		if ui.panel(ctx, key=alicorn.key_string("copied-panel"), width=480,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=18, gap=12,
			fill=alicorn.style_color(ctx, .Surface), radius=10,
			stroke=ui.border(1, alicorn.style_color(ctx, .Border), .Inside)) {
			group, group_visible := radio.group_begin(
				ctx,
				&app.group,
				PLANS[:],
				app.selected,
				label="Plan",
				key=alicorn.key_string("copied-plan"),
				instance_id=5001,
				group_options=radio.Options{
					orientation=.Vertical,
					item_height=50,
					item_min_width=420,
					item_padding=10,
					item_gap=8,
				},
			)
			if group_visible {
				for plan in PLANS {
					item, item_visible := radio.item_begin(ctx, &group, plan)
					if !item_visible { continue }
					// Author-owned row: keep the component's indicator part and
					// replace the default label with a two-line subtree.
					if ui.row(ctx, key=ui.key_u64(1), grow=1, gap=10, align=.Center) {
						radio.indicator(ctx, item)
						if ui.column(ctx, key=ui.key_u64(2), grow=1, gap=1) {
							_ = ui.text(ctx, plan.label, key=ui.key_u64(3), size=14)
							_ = ui.text(ctx, plan.description, key=ui.key_u64(4), size=12,
								color=alicorn.style_color(ctx, .Muted_Text))
						}
					}
					radio.item_end(ctx, item)
				}
				if event := radio.group_end(ctx, &group); event.kind == .Selection_Proposed {
					app.selected = event.value
				}
			}
		}
		_ = ui.text(ctx, fmt.tprintf("Selected plan value: %d", app.selected), size=13)
		_ = ui.text(ctx, app.status, size=13, color=alicorn.style_color(ctx, .Muted_Text))
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	visible, chosen := menu.popup_begin(ctx, &app.actions, COPY_ACTIONS[:],
		menu.Options{accessible_label="Workspace actions"},
		key=alicorn.key_string("copied-menu-popup"), instance_id=5002)
	if visible {
		for item, index in COPY_ACTIONS {
			if menu.item(ctx, &app.actions, item, index) {
				app.status = fmt.tprintf("Menu action %d selected.", item.key)
			}
		}
		menu.popup_end(ctx, &app.actions)
	} else if chosen != 0 {
		app.status = fmt.tprintf("Menu action %d selected.", chosen)
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("external_consumer_path2_smoke", "plan", app.selected, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{
		selected=201,
		status="The copied Radio Group and Menu keep their interaction contracts.",
		smoke=smoke,
	}
	ui.run(
		&app,
		render,
		title="Alicorn - AliKit external consumer (copied source)",
		width=680,
		height=520,
		render_overlays=render_overlays,
		on_stop=stop,
		smoke=smoke,
	)
}
