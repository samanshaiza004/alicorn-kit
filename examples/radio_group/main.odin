package main

// Radio Group example. The application owns both selected values and accepts a
// proposed change from the controlled component. The embedded theme overrides
// the component's optional namespaced surface roles; delete the registration to
// fall back to Alicorn's core roles with no theme compilation.
//
// Run:
//   odin run examples/radio_group -collection:alicorn=/path/to/alicorn
//   ./out/radio_group_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import theme "alicorn:theme"
import ui "alicorn:ui"
import radio "../../radio_group"

THEME_PATH :: "examples/radio_group/theme.json"
THEME_JSON :: #load("theme.json")

TEXT_SIZES := [4]radio.Option{
	{value=1, label="Small", description="Compact interface text"},
	{value=2, label="Medium", description="Default interface text"},
	{value=3, label="Large", description="Comfortable interface text"},
	{value=4, label="Presentation", description="Large-format interface text", disabled=true},
}

DENSITIES := [3]radio.Option{
	{value=10, label="Compact"},
	{value=20, label="Comfortable"},
	{value=30, label="Spacious"},
}

App :: struct {
	size_group:    radio.State,
	density_group: radio.State,
	text_size:     u64,
	density:       u64,

	recipe:      radio.Recipe,
	theme_id:    alicorn.Style_Theme_ID,
	theme_error: bool,
	missing:     [8]string,
	missing_count: int,

	smoke: bool,
}

example_recipe :: proc() -> radio.Recipe {
	return radio.Recipe{
		item_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.radio_group", "item_surface"),
		selected_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.radio_group", "selected_surface"),
		indicator_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.radio_group", "indicator_surface"),
		selected_indicator_role=alicorn.style_extension_color_role_id("vendor.alikit.radio_group", "selected_indicator"),
	}
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	app.text_size = 2
	app.density = 20
	app.recipe = example_recipe()
	registration := theme.theme_json_register(rt, string(THEME_JSON), THEME_PATH)
	defer theme.theme_json_register_result_destroy(&registration)
	app.theme_id = registration.theme_id
	if app.theme_id == 0 {
		fmt.println("Radio example theme registration failed:", registration.failure)
		app.recipe = {}
		return
	}
	contract := radio.theme_contract_default(app.recipe)
	report := radio.theme_contract_check(rt, app.theme_id, contract)
	app.missing, app.missing_count = radio.theme_contract_missing_required(contract, report)
	for index in 0..<app.missing_count {
		fmt.println("Missing radio theme role:", app.missing[index])
	}
	if app.missing_count > 0 {
		app.theme_error = true
		app.recipe = {}
	}
}

settings_panel :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.panel(ctx, key=alicorn.key_string("radio-example-card"), width=520,
		height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=20, gap=16,
		fill=alicorn.style_color(ctx, .Surface), radius=12,
		stroke=ui.border(1, alicorn.style_color(ctx, .Border), .Inside)) {
		_ = ui.text(ctx, "Reading preferences", size=20)
		if event := radio.radio_group(
			ctx,
			&app.size_group,
			TEXT_SIZES[:],
			app.text_size,
			radio.Options{accessible_label="Interface text size", orientation=.Vertical},
			key=alicorn.key_string("radio-example-size"),
			instance_id=4101,
			recipe=app.recipe,
		); event.kind == .Selection_Proposed {
			app.text_size = event.value
		}
		_ = ui.text(ctx, "Density", size=13, color=alicorn.style_color(ctx, .Muted_Text))
		if event := radio.radio_group(
			ctx,
			&app.density_group,
			DENSITIES[:],
			app.density,
			radio.Options{accessible_label="Interface density", orientation=.Horizontal},
			key=alicorn.key_string("radio-example-density"),
			instance_id=4102,
			recipe=app.recipe,
		); event.kind == .Selection_Proposed {
			app.density = event.value
		}
		label := fmt.tprintf("Text size %d · density %d", app.text_size, app.density)
		_ = ui.text(ctx, label, key=alicorn.key_string("radio-example-value"), size=13,
			color=alicorn.style_color(ctx, .Muted_Text))
		if app.theme_error {
			_ = ui.text(ctx, "The optional radio theme roles are incomplete; core roles are in use.",
				size=12, color=alicorn.style_color(ctx, .Danger))
		}
	}
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("radio-example-root"), width=-1, height=-1,
		padding=28, gap=14, align=.Center) {
		_ = ui.text(ctx, "Radio Group", size=26)
		_ = ui.text(ctx, "One controlled value per group. Arrows move and select; disabled options are skipped.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		settings_panel(app, ctx)
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("radio_group_smoke", "text_size", app.text_size, "density", app.density, "idle", true)
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
		title="Alicorn - Radio Group",
		width=680,
		height=520,
		on_initialize=initialize,
		on_stop=stop,
		smoke=smoke,
	)
}
