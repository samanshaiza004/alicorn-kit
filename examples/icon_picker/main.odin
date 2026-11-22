package main

// Icon Picker is a complete copyable custom composite. This example is the
// companion application: it imports the package by relative path, so the pair
// builds outside AliKit's collection layout with only the Alicorn collection.
//
// Run:
//   odin build examples/icon_picker -collection:alicorn=/path/to/alicorn
// or from AliKit:
//   ./tools/test.ps1 -Odin odin

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import picker "../../icon_picker"

Choice_Count :: 12

App :: struct {
	icon: picker.State,
	choices: [Choice_Count]picker.Choice,
	appearance: picker.Appearance,

	selected_key: u64,

	open_modal: bool,
	overlay_node, opener_node: alicorn.Node_ID,
	nested_open: bool,
	nested_opener: alicorn.Node_ID,
	restore_node: alicorn.Node_ID,

	smoke: bool,
}

example_choices :: proc() -> [Choice_Count]picker.Choice {
	return {
		{key=1, label="Home", icon=.Folder_Closed, keywords="house start", detail="Go to the workspace home"},
		{key=2, label="Search", icon=.Search, keywords="find", detail="Search files and commands"},
		{key=3, label="Settings", icon=.Settings, keywords="preferences", detail="Open application settings"},
		{key=4, label="Save", icon=.Check, keywords="write store", detail="Save the current document"},
		{key=5, label="Warning", icon=.Warning, keywords="alert", detail="Show a warning marker"},
		{key=6, label="Info", icon=.Info, keywords="details", detail="Show an information marker"},
		{key=7, label="Terminal", icon=.Terminal, keywords="shell console", detail="Open a terminal"},
		{key=8, label="More", icon=.More_Horizontal, keywords="overflow menu", detail="More actions"},
		{key=9, label="Locked", icon=.Close, keywords="private", detail="Unavailable in this build", disabled=true},
		{key=10, label="Folder", icon=.Folder_Open, keywords="directory", detail="Open a folder"},
		{key=11, label="File", icon=.File, keywords="document", detail="Open a file"},
		{key=12, label="Chevron", icon=.Chevron_Right, keywords="next", detail="Expand the next level"},
	}
}

restore_focus :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	app := cast(^App)data
	if app == nil || rt == nil || app.restore_node == 0 { return }
	if _, found := alicorn.node_info(rt, app.restore_node); found {
		_ = alicorn.focus(rt, app.restore_node)
		alicorn.focus_indicator_set(rt, true)
	}
	app.restore_node = 0
}

schedule_restore :: proc(app: ^App, rt: ^alicorn.Runtime, node: alicorn.Node_ID) {
	if app == nil || rt == nil { return }
	app.restore_node = node
	_ = alicorn.interaction_after_frame_register(rt, rawptr(app), restore_focus)
}

open_modal :: proc(app: ^App, opener: alicorn.Node_ID) {
	app.open_modal = true
	app.nested_open = false
	app.opener_node = opener
	_ = picker.set_query(&app.icon, nil, "")
	_ = picker.request_search_focus(&app.icon)
}

close_modal :: proc(app: ^App, rt: ^alicorn.Runtime) {
	app.open_modal = false
	app.nested_open = false
	schedule_restore(app, rt, app.opener_node)
}

picker_options :: proc(app: ^App) -> picker.Options {
	return picker.Options{
		accessible_label="Icon choices",
		search_accessible_name="Search icons",
		appearance=app.appearance,
		columns=6,
		cell_size=42,
		cell_gap=6,
		row_height=30,
		max_visible_rows=5,
	}
}

describe_picker :: proc(app: ^App, ctx: ^ui.UI) -> bool {
	event := picker.picker(ctx, &app.icon, app.choices[:], picker_options(app),
		key=alicorn.key_string("example-icon-picker"), instance_id=7001)
	if event.kind != .Activated { return false }
	app.selected_key = event.key
	app.icon.selected_key = event.key
	return true
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if alicorn.container_begin(ctx, .Container, label="icon-picker-example-root",
		key=alicorn.key_string("icon-picker-example-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, grow=1, padding=16, gap=8),
		color=alicorn.style_color(ctx, .Window_Background)) != 0 {
		_ = ui.text(ctx, "AliKit · Icon Picker", size=24)
		_ = ui.text(ctx,
			"Search, rove with arrows, Enter selects. Ctrl+F focuses search from anywhere in the picker; Ctrl+2 switches appearances.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		if ui.row(ctx, key=alicorn.key_string("example-actions"), height=36, gap=8, align=.Center) {
			opener, clicked := alicorn.button_ex(ctx, "Insert icon…", key="example-open-picker",
				style=ui.layout_style(width=150, height=32), variant=.Primary)
			if clicked { open_modal(app, opener) }
			if ui.button(ctx,
				"Appearance: Grid" if app.appearance == .Grid else "Appearance: List",
				key=alicorn.key_string("example-toggle-appearance"), width=170, height=32, variant=.Quiet,
			) {
				app.appearance = .List if app.appearance == .Grid else .Grid
			}
			if app.selected_key != 0 {
				_ = ui.text(ctx, "Selected choice is application-owned.", size=12,
					color=alicorn.style_color(ctx, .Muted_Text))
			}
		}
		_ = ui.text(ctx, "The dialog above uses the complete copyable package.", size=13)
		_ = ui.text(ctx, "Changes are proposed as one event and accepted by the application.", size=12,
			color=alicorn.style_color(ctx, .Muted_Text))
		alicorn.container_end(ctx)
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.open_modal { return }
	overlay := alicorn.modal_overlay_begin(
		ctx,
		alicorn.key_string("example-icon-picker-modal"),
		style=ui.layout_style(.Column, width=-1, height=-1, padding=28, align=.Center, justify=.Center),
		backdrop_color=alicorn.Color{0.01, 0.02, 0.03, 0.42},
	)
	app.overlay_node = overlay
	if overlay == 0 { return }
	if ui.panel(ctx, key=alicorn.key_string("example-icon-picker-dialog"), width=430,
		height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=16, gap=10) {
		_ = alicorn.semantic_description(ctx, .Dialog, "Choose an icon",
			description="Select an icon for the document")
		if ui.row(ctx, key=alicorn.key_string("example-icon-picker-header"), height=26, align=.Center) {
			_ = ui.text(ctx, "Choose an icon", size=16, style=ui.layout_style(.Row, grow=1))
			if ui.button(ctx, "Close", key=alicorn.key_string("example-icon-picker-close"),
				width=64, height=26, variant=.Quiet) {
				close_modal(app, ctx.runtime)
			}
		}
		if describe_picker(app, ctx) { close_modal(app, ctx.runtime) }
		if app.open_modal {
			nested, opened := alicorn.button_ex(ctx, "Shortcut details",
				key="example-icon-picker-nested",
				style=ui.layout_style(width=140, height=26), variant=.Quiet)
			if opened {
				app.nested_open = true
				app.nested_opener = nested
			}
		}
	}
	alicorn.modal_overlay_end(ctx)
	if app.nested_open {
		if alicorn.modal_overlay_begin(
			ctx,
			alicorn.key_string("example-icon-picker-nested-modal"),
			style=ui.layout_style(.Column, width=-1, height=-1, padding=28, align=.Center, justify=.Center),
			backdrop_color=alicorn.Color{0.01, 0.02, 0.03, 0.42},
		) != 0 {
			if ui.panel(ctx, key=alicorn.key_string("example-icon-picker-nested-dialog"), width=300,
				height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=14, gap=8) {
				_ = alicorn.semantic_description(ctx, .Dialog, "Shortcut details")
				_ = ui.text(ctx, "Ctrl+F focuses the icon search field.", size=12)
				if ui.button(ctx, "Done", key=alicorn.key_string("example-icon-picker-nested-done"),
					width=80, height=26) {
					app.nested_open = false
					schedule_restore(app, ctx.runtime, app.nested_opener)
				}
			}
			alicorn.modal_overlay_end(ctx)
		}
	}
}

on_key :: proc(app: ^App, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	#partial switch key {
	case .Escape:
		if app.nested_open {
			app.nested_open = false
			schedule_restore(app, rt, app.nested_opener)
			alicorn.invalidate_root(rt, "icon picker example closed nested dialog")
			return true
		}
		if app.open_modal {
			close_modal(app, rt)
			alicorn.invalidate_root(rt, "icon picker example closed dialog")
			return true
		}
	case .Find:
		// Application-authored interaction: focus the picker search from
		// anywhere in the dialog with ordinary state and a public focus request.
		if app.open_modal {
			_ = picker.request_search_focus(&app.icon)
			alicorn.invalidate_root(rt, "icon picker example focused search")
			return true
		}
	case .Command_2:
		app.appearance = .List if app.appearance == .Grid else .Grid
		alicorn.invalidate_root(rt, "icon picker example switched appearance")
		return true
	}
	return false
}

on_pointer :: proc(app: ^App, rt: ^alicorn.Runtime, event: alicorn.Pointer_Event, target: alicorn.Node_ID) {
	if event.kind != .Down || event.button != alicorn.POINTER_BUTTON_PRIMARY { return }
	if app.open_modal && !app.nested_open && target == app.overlay_node {
		close_modal(app, rt)
		alicorn.invalidate_root(rt, "icon picker example dismissed by outside click")
	}
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	if !picker.init(&app.icon) {
		return
	}
	app.choices = example_choices()
	app.selected_key = 1
	app.icon.selected_key = 1
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("icon_picker_smoke", "choices", Choice_Count, "selected", app.selected_key, "idle", true)
	}
	picker.destroy(&app.icon)
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{smoke=smoke, appearance=.Grid}
	ui.run(
		&app,
		render,
		title="Alicorn - Icon Picker",
		width=860,
		height=560,
		render_overlays=render_overlays,
		on_initialize=initialize,
		on_key=on_key,
		on_pointer=on_pointer,
		on_stop=stop,
		smoke=smoke,
	)
}
