package main

// Progress and Dialog composition: progress parts inside a modal export
// dialog. The Dialog owns Escape/backdrop policy, initial focus, and focus
// restoration; Progress owns its semantic range, fill geometry, and the
// caller-driven indeterminate phase. The application owns the export values
// and dispatch.
//
// Run:
//   odin run examples/progress_composition -collection:alicorn=/path/to/alicorn
//   ./out/progress_composition_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import dialog "../../dialog"
import progress "../../progress"

App :: struct {
	linear: progress.State,
	ring:   progress.State,
	view:   dialog.State,
	value:  f64,
	phase:  f32,
	smoke:  bool,
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	_ = dialog.open(&app.view, rt)
}

tick :: proc(app: ^App, rt: ^alicorn.Runtime) {
	if app.smoke || !app.view.open { return }
	app.phase += 0.01
	if app.phase > 1 { app.phase -= 1 }
	alicorn.invalidate_root(rt, "progress composition advanced phase")
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("progress-compose-root"),
		width=-1, height=-1, padding=28, gap=14, align=.Center) {
		_ = ui.text(ctx, "Progress + Dialog", size=26)
		_ = ui.text(ctx, "The dialog owns dismissal and focus; progress parts own their presentation and range.",
			size=13, color=ui.style_color(ctx, .Muted_Text))
		if ui.button(ctx, "Show export dialog", key=ui.key_string("progress-compose-open"),
			width=190, height=34) {
			_ = dialog.open(&app.view, ctx.runtime)
		}
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.view.open { return }
	visible, event := dialog.begin(
		ctx,
		&app.view,
		"Export project",
		dialog.Options{
			description="Your project is being prepared. Cancel stops the export.",
			primary_key=ui.key_string("progress-compose-cancel"),
		},
		key=ui.key_string("progress-compose-dialog"),
		instance_id=4701,
	)
	if !visible {
		if event.kind == .Dismissed { }
		return
	}
	dialog.title(ctx, "Export project")
	dialog.description(ctx, "Preparing assets and writing the package.")
	if dialog.content_begin(ctx, key=ui.key_string("progress-compose-content")) {
		linear_progress(app, ctx)
		ring_progress(app, ctx)
		dialog.content_end(ctx)
	}
	if dialog.action_row_begin(ctx, key=ui.key_string("progress-compose-actions")) {
		if dialog.action(ctx, &app.view, "Cancel export", .Cancel,
			key=ui.key_string("progress-compose-cancel")) {
			dialog.dismiss(ctx, &app.view, .Action)
		}
		dialog.action_row_end(ctx)
	}
	dialog.end(ctx, &app.view)
}

linear_progress :: proc(app: ^App, ctx: ^ui.UI) {
	part, visible := progress.begin(
		ctx,
		&app.linear,
		app.value,
		0,
		100,
		progress.Options{accessible_label="Package progress", width=360},
		key=ui.key_string("progress-compose-linear"),
		instance_id=4702,
	)
	if !visible { return }
	if ui.row(ctx, key=ui.key_u64(1), width=-1,
		height=alicorn.LAYOUT_SIZE_FIT_CONTENT, align=.Center, gap=8) {
		progress.label(ctx, &part)
		progress.value_text(ctx, &part)
	}
	track, track_visible := progress.track_begin(ctx, &part)
	if track_visible {
		progress.indicator(ctx, &track)
		progress.track_end(ctx)
	}
	progress.end(ctx, &part)
}

ring_progress :: proc(app: ^App, ctx: ^ui.UI) {
	part, visible := progress.begin(
		ctx,
		&app.ring,
		0,
		0,
		1,
		progress.Options{
			accessible_label="Optimizing images",
			width=120,
			indeterminate=true,
			indeterminate_phase=app.phase,
		},
		key=ui.key_string("progress-compose-ring"),
		instance_id=4703,
	)
	if !visible { return }
	if ui.row(ctx, key=ui.key_u64(10), width=116, height=116,
		align=.Start, gap=14) {
		if ui.row(ctx, key=ui.key_u64(11), width=92, height=92,
			align=.Center, justify=.Center) {
			track := alicorn.surface_begin(
				ctx,
				alicorn.surface_core_color_role(.Subtle_Surface),
				key=ui.key_u64(12),
				style=ui.layout_style(.Row, width=88, height=88),
				shape=alicorn.Surface_Shape{kind=.Circle},
				fill=alicorn.Color{0, 0, 0, 0},
				stroke=alicorn.Paint_Stroke{color=ui.style_color(ctx, .Border), width=8},
				label="compose-ring-track",
			)
			if track != 0 {
				ui.surface_end(ctx)
				_ = alicorn.position_child(ctx, track, alicorn.positioned(0, 0))
			}
			arc := alicorn.surface_begin(
				ctx,
				alicorn.surface_core_color_role(.Accent),
				key=ui.key_u64(13),
				style=ui.layout_style(.Row, width=88, height=88),
				shape=progress.ring_segment_shape(app.phase),
				fill=alicorn.Color{0, 0, 0, 0},
				stroke=alicorn.Paint_Stroke{color=ui.style_color(ctx, .Accent), width=8},
				label="compose-ring-arc",
			)
			if arc != 0 {
				ui.surface_end(ctx)
				_ = alicorn.position_child(ctx, arc, alicorn.positioned(0, 0))
			}
			_ = ui.icon(ctx, .Settings, key=ui.key_u64(14), size=18, color_role=.Muted_Text)
		}
		if ui.column(ctx, key=ui.key_u64(15), grow=1, gap=2, align=.Center) {
			_ = ui.text(ctx, "Optimizing images", key=ui.key_u64(16), size=13)
			_ = ui.text(ctx, "This step has no percentage.", key=ui.key_u64(17), size=11,
				color=ui.style_color(ctx, .Muted_Text))
		}
	}
	progress.end(ctx, &part)
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("progress_composition_smoke", "value", app.value, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{value=64, smoke=smoke}
	ui.run(
		&app,
		render,
		title="Alicorn - Progress Composition",
		width=780,
		height=560,
		on_initialize=initialize,
		on_tick=tick,
		render_overlays=render_overlays,
		on_stop=stop,
		smoke=smoke,
	)
}
