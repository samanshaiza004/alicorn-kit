package main

// Progress example. Determinate bars publish a numeric range; the
// indeterminate bar has no numeric value and the application owns its pulse
// phase. Enable "Animate" to let the application's tick advance that phase.
//
// Run:
//   odin run examples/progress -collection:alicorn=/path/to/alicorn
//   ./out/progress_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import theme "alicorn:theme"
import ui "alicorn:ui"
import progress "../../progress"

THEME_PATH :: "examples/progress/theme.json"
THEME_JSON :: #load("theme.json")

App :: struct {
	bars: [4]progress.State,
	loading: progress.State,
	phase: f32,
	animate: bool,
	recipe: progress.Recipe,
	theme_id: alicorn.Style_Theme_ID,
	theme_error: bool,
	missing: [8]string,
	missing_count: int,
	smoke: bool,
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	registration := theme.theme_json_register(rt, string(THEME_JSON), THEME_PATH)
	defer theme.theme_json_register_result_destroy(&registration)
	app.theme_id = registration.theme_id
	if app.theme_id == 0 {
		fmt.println("Progress example theme registration failed:", registration.failure)
		return
	}
	app.recipe = progress.Recipe{
		track_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.progress", "track"),
		fill_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.progress", "fill"),
	}
	contract := progress.theme_contract_default(app.recipe)
	report := progress.theme_contract_check(rt, app.theme_id, contract)
	app.missing, app.missing_count = progress.theme_contract_missing_required(contract, report)
	for index in 0..<app.missing_count {
		fmt.println("Missing progress theme role:", app.missing[index])
	}
	if app.missing_count > 0 { app.theme_error = true; app.recipe = {} }
}

tick :: proc(app: ^App, rt: ^alicorn.Runtime) {
	if !app.animate || app.smoke { return }
	app.phase += 0.012
	if app.phase > 1 { app.phase -= 1 }
	alicorn.invalidate_root(rt, "progress example advanced indeterminate phase")
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("progress-example-root"), width=-1, height=-1,
		padding=28, gap=16, align=.Center) {
		_ = ui.text(ctx, "Progress", size=26)
		_ = ui.text(ctx, "Determinate values publish a numeric range; indeterminate work has no value.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		if ui.panel(ctx, key=alicorn.key_string("progress-example-card"), width=540,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=20, gap=16,
			fill=alicorn.style_color(ctx, .Surface), radius=12,
			stroke=ui.border(1, alicorn.style_color(ctx, .Border), .Inside)) {
			values := [4]f64{0, 25, 60, 100}
			for value, index in values {
				progress.progress(
					ctx,
					&app.bars[index],
					value,
					0,
					100,
					progress.Options{
						accessible_label=fmt.tprintf("Download %d", index+1),
						width=480,
					},
					key=ui.key_pair(0x50524F47, u64(index+1)),
					instance_id=u64(4200+index),
					recipe=app.recipe,
				)
			}
			progress.progress(
				ctx,
				&app.loading,
				0,
				0,
				1,
				progress.Options{
					accessible_label="Loading workspace",
					width=480,
					indeterminate=true,
					indeterminate_phase=app.phase,
					pulse=true,
				},
				key=alicorn.key_string("progress-example-loading"),
				instance_id=4205,
				recipe=app.recipe,
			)
			_ = ui.checkbox(ctx, "Animate indeterminate phase", &app.animate,
				key=alicorn.key_string("progress-example-animate"), width=240, height=28)
			if app.theme_error {
				_ = ui.text(ctx, "Optional progress theme roles are incomplete; core roles are in use.",
					size=12, color=alicorn.style_color(ctx, .Danger))
			}
		}
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("progress_smoke", "bars", len(app.bars), "phase", app.phase, "idle", true)
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
		title="Alicorn - Progress",
		width=720,
		height=560,
		on_initialize=initialize,
		on_tick=tick,
		on_stop=stop,
		smoke=smoke,
	)
}
