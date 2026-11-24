package main

// Icon Picker parts example: the search field and virtualized grid/list are
// composed directly, with an application-owned cell visual. The parts still
// publish List_Box/List_Box_Option semantics, stable choice keys, roving grid
// navigation, disabled skipping, reveal, and one activation proposal. This file
// owns the letter-tile cell, the selected outline, and the detail row.
//
// Run:
//   odin run examples/icon_picker_parts -collection:alicorn=/path/to/alicorn
//   ./out/icon_picker_parts_example.exe --smoke

import "core:fmt"
import "core:os"
import ui "alicorn:ui"
import picker "../../icon_picker"

CHOICES: [9]picker.Choice = {
	{key=1, label="Home", icon=.Folder_Closed, keywords="house", detail="Workspace home"},
	{key=2, label="Search", icon=.Search, keywords="find", detail="Find anything"},
	{key=3, label="Settings", icon=.Settings, keywords="preferences", detail="Preferences"},
	{key=4, label="File", icon=.File, keywords="document", detail="A document"},
	{key=5, label="Folder", icon=.Folder_Open, keywords="directory", detail="A folder"},
	{key=6, label="Terminal", icon=.Terminal, keywords="shell", detail="A terminal"},
	{key=7, label="Warning", icon=.Warning, keywords="alert", detail="A warning"},
	{key=8, label="Locked", icon=.Close, keywords="private", detail="Unavailable", disabled=true},
	{key=9, label="Info", icon=.Info, keywords="about", detail="Information"},
}

App :: struct {
	state:    picker.State,
	selected: u64,
	appearance: picker.Appearance,
	list_mode: bool,
	status:   string,
	smoke:    bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.panel(ctx, key=ui.key_string("icon-picker-parts-example-root"),
		width=-1, height=-1, grow=1, padding=24, gap=10,
		fill=ui.style_color(ctx, .Window_Background), label="icon-picker-parts-example-root") {
		_ = ui.text(ctx, "Icon picker parts", size=26)
		_ = ui.text(ctx, "The application owns the tile and row visuals; the parts own search, grid navigation, and semantics.",
			size=13, color=ui.style_color(ctx, .Muted_Text))
		_ = ui.checkbox(ctx, "List appearance", &app.list_mode,
			key=ui.key_string("icon-picker-parts-example-list"), width=170, height=28)
		app.appearance = .List if app.list_mode else .Grid

		if !ui.key_scope(ctx, ui.key_string("icon-picker-parts-example-scope")) { return }
		if ui.column(ctx, key=ui.key_string("icon-picker-parts-example-body"), width=460, gap=8) {
			root, scope_registered := ui.interaction_scope_current(ctx, rawptr(app), ui.Interaction_Scope_Options{
				keys={.Up, .Down, .Left, .Right, .Home, .End, .Page_Up, .Page_Down, .Return, .Toggle},
				composition_yield_keys={.Up, .Down, .Left, .Right, .Home, .End, .Page_Up, .Page_Down, .Return, .Toggle},
				text_preempt_keys={.Up, .Down, .Left, .Right, .Home, .End, .Page_Up, .Page_Down, .Toggle},
			})
			if !scope_registered { return }
			options := picker.Options{accessible_label="Icon choices",
				search_accessible_name="Search icons", appearance=app.appearance,
				columns=5, cell_size=56, cell_gap=8, row_height=40, max_visible_rows=4}
			_, _ = picker.search(ctx, &app.state, options,
				key=ui.key_string("icon-picker-parts-example-search"))
			grid, visible := picker.grid_begin(ctx, &app.state, CHOICES[:], options,
				key=ui.key_string("icon-picker-parts-example-grid"),
				instance_id=8101, scope_owner=root)
			if !visible {
				_ = picker.empty(ctx, &app.state, options)
			} else {
				for index := grid.first; index < grid.last; index += 1 {
					item, item_visible := picker.item_begin(ctx, &grid, index)
					if !item_visible { continue }
					if app.appearance == .Grid {
						picker_cell(ctx, item)
					} else {
						picker_row(ctx, item)
					}
					picker.item_end(ctx, &grid, item)
				}
				if event := picker.grid_end(ctx, &grid); event.kind == .Activated {
					app.selected = event.key
					app.status = fmt.tprintf("Choice %d proposed.", event.key)
				}
			}
		}
		_ = ui.text(ctx, app.status, size=13, color=ui.style_color(ctx, .Muted_Text))
	}
}

picker_cell :: proc(ctx: ^ui.UI, item: picker.Grid_Item) {
	fill := ui.style_color(ctx, .Selection if item.selected else .Subtle_Surface)
	stroke := ui.style_color(ctx, .Focus if item.active else .Border)
	if ui.panel(ctx, key=ui.key_u64(1), width=-1, height=-1, padding=4,
		align=.Center, justify=.Center, fill=fill, radius=12,
		stroke=ui.border(2 if item.active else 1, stroke, .Inside),
		label="custom-icon-cell") {
		_ = ui.text(ctx, item.choice.label[:1], key=ui.key_u64(2), size=18,
			color=ui.style_color(ctx, .Accent_Text if item.selected else .Text))
		_ = ui.text(ctx, item.choice.label, key=ui.key_u64(3), size=9,
			color=ui.style_color(ctx, .Muted_Text))
	}
}

picker_row :: proc(ctx: ^ui.UI, item: picker.Grid_Item) {
	fill := ui.style_color(ctx, .Selection if item.selected else .Surface)
	if ui.panel(ctx, key=ui.key_u64(1), width=-1, height=38, padding=8, gap=8,
		align=.Center, fill=fill, radius=8,
		stroke=ui.border(1, ui.style_color(ctx, .Border), .Inside),
		label="custom-icon-row") {
		_ = ui.box(ctx, key=ui.key_u64(2), size=22, radius=6,
			fill=ui.style_color(ctx, .Subtle_Surface))
		if ui.column(ctx, key=ui.key_u64(3), grow=1, gap=1) {
			_ = ui.text(ctx, item.choice.label, key=ui.key_u64(4), size=13)
			_ = ui.text(ctx, item.choice.detail, key=ui.key_u64(5), size=10,
				color=ui.style_color(ctx, .Muted_Text))
		}
		if item.selected {
			_ = ui.icon(ctx, .Check, key=ui.key_u64(6), size=14, color_role=.Accent)
		}
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("icon_picker_parts_smoke", "selected", app.selected, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{selected=2, status="Choose an icon; the application accepts the proposal.", smoke=smoke}
	if !picker.init(&app.state) { return }
	defer picker.destroy(&app.state)
	app.state.selected_key = app.selected
	ui.run(&app, render, title="Alicorn - Icon Picker Parts", width=760, height=560,
		on_stop=stop, smoke=smoke)
}
