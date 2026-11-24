package main

// Sidebar and Segmented composition: a settings shell where the navigation
// rail proposes the application route and a segmented control owns the
// settings section. Both components keep their own semantics and focus model;
// the application owns the accepted route, the accepted section, and the
// content.
//
// Run:
//   odin run examples/sidebar_composition -collection:alicorn=/path/to/alicorn
//   ./out/sidebar_composition_example.exe --smoke

import "core:fmt"
import "core:os"
import ui "alicorn:ui"
import segmented "../../segmented"
import sidebar "../../sidebar"

ROUTES: [4]sidebar.Item = {
	{key=1, label="Workspace", icon=.Settings, detail="Settings and policy"},
	{key=2, label="Members", icon=.Info, detail="People and roles"},
	{key=3, label="Billing", icon=.File, detail="Plans and invoices"},
	{key=4, label="Danger", icon=.Warning, detail="Unavailable", disabled=true},
}

SECTIONS: [3]segmented.Item = {
	{value=1, label="General"},
	{value=2, label="Appearance"},
	{value=3, label="Advanced"},
}

App :: struct {
	rail:         sidebar.State,
	segments:     segmented.State,
	route:        u64,
	section:      u64,
	status:       string,
	smoke:        bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.row(ctx, key=ui.key_string("sidebar-composition-root"),
		width=-1, height=-1, grow=1, padding=18, gap=18,
		label="sidebar-composition-root") {
		if event := sidebar.rail(
			ctx,
			&app.rail,
			ROUTES[:],
			app.route,
			sidebar.Options{accessible_label="Settings navigation", expanded_width=230},
			key=ui.key_string("sidebar-composition-rail"),
			instance_id=6301,
		); event.kind == .Selection_Proposed {
			app.route = event.key
			app.status = fmt.tprintf("Route %d accepted; the application owns the content.", event.key)
		}
		if ui.column(ctx, key=ui.key_string("sidebar-composition-content"), grow=1,
			height=-1, padding=24, gap=14, align=.Start) {
			_ = ui.text(ctx, route_label(app.route), size=26)
			_ = ui.text(ctx, "The rail proposes routes; the segmented control owns the section.",
				size=13, color=ui.style_color(ctx, .Muted_Text))
			if event := segmented.control(
				ctx,
				&app.segments,
				SECTIONS[:],
				app.section,
				segmented.Options{accessible_label="Settings section", width=380, height=34},
				key=ui.key_string("sidebar-composition-sections"),
				instance_id=6302,
			); event.kind == .Selection_Proposed {
				app.section = event.value
			}
			if ui.panel(ctx, key=ui.key_string("sidebar-composition-card"),
				width=-1, height=180, padding=18, gap=8, align=.Start,
				fill=ui.style_color(ctx, .Surface), radius=12,
				stroke=ui.border(1, ui.style_color(ctx, .Border), .Inside)) {
				_ = ui.text(ctx, section_title(app.section), size=18)
				_ = ui.text(ctx, section_body(app.section), size=13,
					color=ui.style_color(ctx, .Muted_Text))
				_ = ui.text(ctx, app.status, size=12,
					color=ui.style_color(ctx, .Muted_Text))
			}
		}
	}
}

route_label :: proc(key: u64) -> string {
	for route in ROUTES {
		if route.key == key { return route.label }
	}
	return "Workspace"
}

section_title :: proc(value: u64) -> string {
	switch value {
	case 2: return "Appearance"
	case 3: return "Advanced"
	}
	return "General"
}

section_body :: proc(value: u64) -> string {
	switch value {
	case 2: return "Theme, density, and reduced-motion preferences live here."
	case 3: return "Experimental options are application policy, not component state."
	}
	return "Name, language, and workspace defaults. The application accepts both proposals."
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("sidebar_composition_smoke", "route", app.route,
			"section", app.section, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{route=1, section=1, status="Change either control; both proposals are application-owned.", smoke=smoke}
	ui.run(&app, render, title="Alicorn - Sidebar Composition", width=900, height=560,
		on_stop=stop, smoke=smoke)
}
