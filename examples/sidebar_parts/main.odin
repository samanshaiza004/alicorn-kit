package main

// Sidebar parts example: custom navigation rows built with the public rail
// parts. The component still owns List_Box/List_Box_Option semantics, the one
// Tab stop, roving focus, selected/current state, and one route proposal. This
// file owns every visual inside the row: the letter tile, the two-line layout,
// the badge chip, and the selected checkmark. It omits the default row surface,
// icon, label, indicator, and badge parts.
//
// Run:
//   odin run examples/sidebar_parts -collection:alicorn=/path/to/alicorn
//   ./out/sidebar_parts_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import sidebar "../../sidebar"

ROUTES: [5]sidebar.Item = {
	{key=1, label="Inbox", icon=.Info, detail="Review mentions and requests", badge="4"},
	{key=2, label="Projects", icon=.Folder_Closed, detail="Active workspaces"},
	{key=3, label="Automations", icon=.Settings, detail="Scheduled actions", badge="beta"},
	{key=4, label="Archive", icon=.File, detail="Read-only history", disabled=true},
	{key=5, label="Help", icon=.Info, detail="Guides and shortcuts"},
}

App :: struct {
	rail:         sidebar.State,
	selected_key: u64,
	collapsed:    bool,
	status:       string,
	smoke:        bool,
}

INITIALS: [5]string = {"IN", "PR", "AU", "AR", "HE"}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if alicorn.container_begin(ctx, .Container, label="sidebar-parts-example-root",
		key=alicorn.key_string("sidebar-parts-example-root"),
		style=alicorn.layout_style(.Row, width=-1, height=-1, grow=1, padding=20, gap=20),
		color=alicorn.style_color(ctx, .Window_Background)) != 0 {
		rail_ctx, visible := sidebar.rail_begin(
			ctx,
			&app.rail,
			ROUTES[:],
			app.selected_key,
			label="Workspace navigation",
			key=alicorn.key_string("sidebar-parts-example-rail"),
			instance_id=6201,
			rail_options=sidebar.Options{collapsed=app.collapsed, expanded_width=260,
				item_height=58, item_gap=6, padding=8},
			style=sidebar.Style{corner_radius=14, focus_width=2},
		)
		if visible {
			for route, index in ROUTES {
				row, row_visible := sidebar.item_begin(ctx, &rail_ctx, route)
				if !row_visible { continue }
				custom_row(ctx, app, row, INITIALS[index])
				sidebar.item_end(ctx, row)
			}
			if event := sidebar.rail_end(ctx, &rail_ctx); event.kind == .Selection_Proposed {
				app.selected_key = event.key
				app.status = fmt.tprintf("Route %d proposed by the application-owned rail.", event.key)
			}
		}
		if ui.column(ctx, key=alicorn.key_string("sidebar-parts-example-main"), grow=1,
			height=-1, padding=24, gap=12, align=.Start) {
			_ = ui.text(ctx, "Sidebar parts", size=26)
			_ = ui.text(ctx, "Every row visual is authored here. The rail still owns semantics, focus, and the proposal.",
				size=13, color=alicorn.style_color(ctx, .Muted_Text))
			_ = ui.checkbox(ctx, "Collapse rail", &app.collapsed,
				key=alicorn.key_string("sidebar-parts-example-collapse"), width=180, height=28)
			_ = ui.text(ctx, app.status, size=13,
				color=alicorn.style_color(ctx, .Muted_Text))
		}
		alicorn.container_end(ctx)
	}
}

custom_row :: proc(ctx: ^ui.UI, app: ^App, row: sidebar.Rail_Item, initials: string) {
	fill := alicorn.surface_core_color_role(.Surface)
	if row.selected { fill = alicorn.surface_core_color_role(.Selection) }
	stroke := alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Border), width=1}
	if row.focus_visible {
		stroke = alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Focus), width=2}
	}
	if alicorn.surface_begin(ctx, fill, key=ui.key_u64(1),
		style=ui.layout_style(.Row, width=-1, height=-1, padding=10, gap=10, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=12},
		stroke=stroke, label="custom-route-row") == 0 {
		return
	}
	// Letter tile instead of the default icon part.
	if alicorn.surface_begin(ctx,
		alicorn.surface_core_color_role(.Accent if row.selected else .Subtle_Surface),
		key=ui.key_u64(2),
		style=ui.layout_style(.Row, width=32, height=32, align=.Center, justify=.Center),
		shape=alicorn.Surface_Shape{kind=.Circle}, label="route-initials") != 0 {
		_ = ui.text(ctx, initials, key=ui.key_u64(3), size=11,
			color=alicorn.style_color(ctx, .Accent_Text if row.selected else .Text))
		alicorn.surface_end(ctx)
	}
	if !app.collapsed {
		if ui.column(ctx, key=ui.key_u64(4), grow=1, gap=1) {
			_ = ui.text(ctx, row.item.label, key=ui.key_u64(5), size=14)
			_ = ui.text(ctx, row.item.detail, key=ui.key_u64(6), size=11,
				color=alicorn.style_color(ctx, .Muted_Text))
		}
		if row.item.badge != "" {
			if alicorn.surface_begin(ctx, alicorn.surface_core_color_role(.Subtle_Surface),
				key=ui.key_u64(7),
				style=ui.layout_style(.Row, padding=5, align=.Center),
				shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=8},
				label="route-badge") != 0 {
				_ = ui.text(ctx, row.item.badge, key=ui.key_u64(8), size=10,
					color=alicorn.style_color(ctx, .Muted_Text))
				alicorn.surface_end(ctx)
			}
		}
		if row.selected {
			_ = ui.icon(ctx, .Check, key=ui.key_u64(9), size=16, color_role=.Accent)
		}
	} else if row.selected {
		// A collapsed custom row keeps a non-color selected cue.
		_ = ui.text(ctx, "\u2022", key=ui.key_u64(10), size=12,
			color=alicorn.style_color(ctx, .Accent))
	}
	alicorn.surface_end(ctx)
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("sidebar_parts_smoke", "selected", app.selected_key,
			"collapsed", app.collapsed, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{selected_key=1, status="Navigate with the rail; the application accepts the route.", smoke=smoke}
	ui.run(&app, render, title="Alicorn - Sidebar Parts", width=860, height=560,
		on_stop=stop, smoke=smoke)
}
