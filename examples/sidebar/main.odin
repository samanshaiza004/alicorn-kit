package main

// Navigation Rail example. The rail owns roving focus and one proposed route;
// the application owns the accepted route and renders the content. Toggle
// "Collapse rail" to switch presentations without changing identity or focus.
//
// Run:
//   odin run examples/sidebar -collection:alicorn=/path/to/alicorn
//   ./out/sidebar_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import theme "alicorn:theme"
import ui "alicorn:ui"
import sidebar "../../sidebar"

THEME_PATH :: "examples/sidebar/theme.json"
THEME_JSON :: #load("theme.json")

ROUTES: [6]sidebar.Item = {
	{key=1, label="Overview", icon=.Info, detail="Workspace summary"},
	{key=2, label="Files", icon=.Folder_Closed, detail="Browse workspace files"},
	{key=3, label="Search", icon=.Search, detail="Find files and symbols"},
	{key=4, label="Terminal", icon=.Terminal, detail="Open a terminal", badge="2"},
	{key=5, label="Settings", icon=.Settings, detail="Workspace settings"},
	{key=6, label="Archived", icon=.Close, detail="Unavailable", disabled=true},
}

App :: struct {
	rail:         sidebar.State,
	selected_key: u64,
	collapsed:    bool,

	recipe:       sidebar.Recipe,
	theme_id:     alicorn.Style_Theme_ID,
	theme_error:  bool,
	missing:      [8]string,
	missing_count: int,
	smoke:        bool,
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	app.selected_key = 2
	registration := theme.theme_json_register(rt, string(THEME_JSON), THEME_PATH)
	defer theme.theme_json_register_result_destroy(&registration)
	app.theme_id = registration.theme_id
	if app.theme_id == 0 {
		fmt.println("Sidebar example theme registration failed:", registration.failure)
		return
	}
	app.recipe = sidebar.Recipe{
		rail_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.sidebar", "rail"),
		item_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.sidebar", "item"),
		selected_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.sidebar", "selected"),
	}
	contract := sidebar.theme_contract_default(app.recipe)
	report := sidebar.theme_contract_check(rt, app.theme_id, contract)
	app.missing, app.missing_count = sidebar.theme_contract_missing_required(contract, report)
	for index in 0..<app.missing_count {
		fmt.println("Missing sidebar theme role:", app.missing[index])
	}
	if app.missing_count > 0 { app.theme_error = true; app.recipe = {} }
}

selected_route :: proc(app: ^App) -> sidebar.Item {
	for item in ROUTES {
		if item.key == app.selected_key { return item }
	}
	return ROUTES[0]
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.row(ctx, key=alicorn.key_string("sidebar-example-root"), width=-1, height=-1,
		padding=18, gap=18) {
		if event := sidebar.rail(
			ctx,
			&app.rail,
			ROUTES[:],
			app.selected_key,
			sidebar.Options{accessible_label="Workspace navigation", collapsed=app.collapsed},
			key=alicorn.key_string("sidebar-example-rail"),
			instance_id=6101,
			recipe=app.recipe,
		); event.kind == .Selection_Proposed {
			app.selected_key = event.key
		}
		if ui.column(ctx, key=alicorn.key_string("sidebar-example-content"), width=-1, height=-1,
			grow=1, padding=24, gap=12, align=.Start) {
			_ = ui.text(ctx, selected_route(app).label, size=26)
			_ = ui.text(ctx, selected_route(app).detail, size=14,
				color=alicorn.style_color(ctx, .Muted_Text))
			_ = ui.text(ctx, "The application owns the accepted route; the rail only proposes it.",
				size=13, color=alicorn.style_color(ctx, .Muted_Text))
			_ = ui.checkbox(ctx, "Collapse rail", &app.collapsed,
				key=alicorn.key_string("sidebar-example-collapse"), width=180, height=28)
			if app.theme_error {
				_ = ui.text(ctx, "Optional sidebar theme roles are incomplete; core roles are in use.",
					size=12, color=alicorn.style_color(ctx, .Danger))
			}
		}
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("sidebar_smoke", "selected", app.selected_key, "collapsed", app.collapsed, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{smoke=smoke}
	ui.run(
		&app,
		render,
		title="Alicorn - Navigation Rail",
		width=820,
		height=560,
		on_initialize=initialize,
		on_stop=stop,
		smoke=smoke,
	)
}
