package main

// Scroll Area example: one bounded, focusable scroll container with keyboard
// and wheel scrolling. The application owns the log lines; the component owns
// the viewport bound, single Tab stop, key map, and bar-part geometry.
//
// Run:
//   odin run examples/scroll_area -collection:alicorn=/path/to/alicorn
//   ./out/scroll_area_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import theme "alicorn:theme"
import ui "alicorn:ui"
import scroll "../../scroll_area"

THEME_PATH :: "examples/scroll_area/theme.json"
THEME_JSON :: #load("theme.json")

LINE_COUNT :: 40

App :: struct {
	view:    scroll.State,
	recipe:  scroll.Recipe,
	theme_id: alicorn.Style_Theme_ID,
	smoke:   bool,
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	registration := theme.theme_json_register(rt, string(THEME_JSON), THEME_PATH)
	defer theme.theme_json_register_result_destroy(&registration)
	app.theme_id = registration.theme_id
	if app.theme_id == 0 {
		fmt.println("Scroll Area theme registration failed:", registration.failure)
		return
	}
	app.recipe = scroll.Recipe{
		frame_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.scroll_area", "frame"),
	}
	contract := scroll.theme_contract_default(app.recipe)
	report := scroll.theme_contract_check(rt, app.theme_id, contract)
	names, missing := scroll.theme_contract_missing_required(contract, report)
	for index in 0..<missing { fmt.println("Missing scroll area theme role:", names[index]) }
	if missing > 0 { app.recipe = {} }
	_ = scroll.request_focus(&app.view)
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("scroll-example-root"), width=-1, height=-1,
		padding=24, gap=12) {
		_ = ui.text(ctx, "Scroll Area", size=26)
		_ = ui.text(ctx, "Focus the region, then use Up/Down, Page Up/Down, Home, or End. Wheel input is runtime-owned.",
			size=13, color=ui.style_color(ctx, .Muted_Text))
		options := scroll.Options{
			accessible_label="Build log",
			line_count=LINE_COUNT,
			line_height=24,
			fit_content=true,
			max_height=320,
			axes=.Vertical,
		}
		if scroll.begin(ctx, &app.view, options, key=ui.key_string("scroll-example-area"),
			instance_id=7201, recipe=app.recipe) {
			if ui.column(ctx, key=ui.key_string("scroll-example-lines"), width=-1, gap=0) {
				for line in 0..<LINE_COUNT {
					_ = ui.text(ctx, fmt.tprintf("Build log line %02d: retained offset survives rebuilds.", line+1),
						key=ui.key_u64(u64(920+line)), style=ui.layout_style(.Column, height=24),
						size=12, decorative=true, color=ui.style_color(ctx, .Muted_Text))
				}
			}
			scroll.end(ctx, &app.view)
		}
		bar := scroll.bar_geometry(&app.view)
		_ = ui.text(ctx, fmt.tprintf("viewport %.0f / content %.0f / thumb %.0f",
			app.view.viewport_height, app.view.content_height, bar.thumb.h),
			size=12, color=ui.style_color(ctx, .Muted_Text))
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("scroll_area_smoke", "offset", app.view.offset_y, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{smoke=smoke}
	ui.run(&app, render, title="Alicorn - Scroll Area", width=820, height=560,
		on_initialize=initialize, on_stop=stop, smoke=smoke)
}
