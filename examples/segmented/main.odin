package main

// Segmented Control example: one single-selection model, a moving indicator,
// and an application-owned view. The application owns the selected view and
// accepts one proposed value; the component owns keyed selection, roving
// focus, disabled skipping, and activation parity. The indicator animates via
// Alicorn's paint-only motion and snaps when the host requests reduced motion.
//
// Run:
//   odin run examples/segmented -collection:alicorn=/path/to/alicorn
//   ./out/segmented_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import theme "alicorn:theme"
import ui "alicorn:ui"
import segmented "../../segmented"

THEME_PATH :: "examples/segmented/theme.json"
THEME_JSON :: #load("theme.json")

VIEWS :: [4]segmented.Item{
	{value=10, label="Overview"},
	{value=20, label="Activity", disabled=true},
	{value=30, label="Files"},
	{value=40, label="Settings"},
}

App :: struct {
	state:    segmented.State,
	items:    [4]segmented.Item,
	selected: u64,
	mode:     segmented.Selection_Mode,
	activate_mode: bool,
	recipe:   segmented.Recipe,
	theme_id: alicorn.Style_Theme_ID,
	theme_error: bool,
	missing:  [8]string,
	missing_count: int,
	smoke:    bool,
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	app.recipe = segmented.Recipe{
		track_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.segmented", "track"),
		indicator_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.segmented", "indicator"),
	}
	registration := theme.theme_json_register(rt, string(THEME_JSON), THEME_PATH)
	defer theme.theme_json_register_result_destroy(&registration)
	app.theme_id = registration.theme_id
	if app.theme_id == 0 {
		fmt.println("Segmented example theme registration failed:", registration.failure)
		app.recipe = {}
		return
	}
	contract := segmented.theme_contract_default(app.recipe)
	report := segmented.theme_contract_check(rt, app.theme_id, contract)
	app.missing, app.missing_count = segmented.theme_contract_missing_required(contract, report)
	for index in 0..<app.missing_count {
		fmt.println("Missing segmented theme role:", app.missing[index])
	}
	if app.missing_count > 0 { app.theme_error = true; app.recipe = {} }
}

view_copy :: proc(value: u64) -> (title, body: string) {
	switch value {
	case 10:
		return "Overview", "A summary of this workspace. Arrow keys move the indicator and propose the view."
	case 30:
		return "Files", "Files selected by the segmented control. Selection remains application-owned."
	case 40:
		return "Settings", "Settings selected by the same shared single-selection model."
	}
	return "Overview", "Select a view with the mouse, keyboard, or assistive technology."
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("segmented-example-root"),
		width=-1, height=-1, padding=28, gap=16, align=.Center) {
		_ = ui.text(ctx, "Segmented Control", size=26)
		_ = ui.text(ctx, "One keyed single-selection model. The selected indicator moves through paint-only motion.",
			size=13, color=ui.style_color(ctx, .Muted_Text))

		theme_scope := alicorn.Style_Environment_Scope{}
		if app.theme_id != 0 {
			theme_scope = alicorn.style_environment_push(ctx, alicorn.Style_Environment{theme=app.theme_id})
		}
		if ui.column(ctx, key=ui.key_string("segmented-example-card"), width=560,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=22, gap=16) {
			event := segmented.control(
				ctx,
				&app.state,
				app.items[:],
				app.selected,
				segmented.Options{
					accessible_label="Workspace view",
					width=516,
					height=40,
					padding=4,
					selection_mode=app.mode,
				},
				key=ui.key_string("segmented-example-control"),
				instance_id=4801,
				recipe=app.recipe,
			)
			if event.kind == .Selection_Proposed { app.selected = event.value }

			title, body := view_copy(app.selected)
			_ = ui.text(ctx, title, key=ui.key_string("segmented-example-title"), size=20)
			_ = ui.text(ctx, body, key=ui.key_string("segmented-example-body"), size=13,
				color=ui.style_color(ctx, .Muted_Text))

			_ = ui.checkbox(ctx, "Activate mode (arrows move focus; Space selects)",
				&app.activate_mode, key=ui.key_string("segmented-example-mode"),
				width=340, height=28)
			if app.activate_mode { app.mode = .Activate } else { app.mode = .Follow_Focus }
			if app.theme_error {
				_ = ui.text(ctx, "Optional segmented theme roles are incomplete; core roles are in use.",
					size=12, color=ui.style_color(ctx, .Danger))
			}
		}
		if theme_scope.active { alicorn.style_environment_pop(ctx, theme_scope) }
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("segmented_smoke", "selected", app.selected, "mode", app.mode, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{selected=10, mode=.Follow_Focus, smoke=smoke}
	app.items = VIEWS
	ui.run(
		&app,
		render,
		title="Alicorn - Segmented Control",
		width=760,
		height=480,
		on_initialize=initialize,
		on_stop=stop,
		smoke=smoke,
	)
}
