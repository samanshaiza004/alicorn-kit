package main

// Progress parts example: one numeric range rendered as a complete linear bar
// and as a ring donut. Both presentations use the public parts, the same
// Progress semantic node, and the public fraction/geometry helpers. The linear
// bar uses track_begin/indicator; the ring owns its Arc surfaces and centered
// value text. A third indeterminate ring demonstrates ring_segment_shape.
//
// Run:
//   odin run examples/progress_parts -collection:alicorn=/path/to/alicorn
//   ./out/progress_parts_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import progress "../../progress"

App :: struct {
	linear:  progress.State,
	ring:    progress.State,
	loading: progress.State,
	value:   f64,
	phase:   f32,
	animate: bool,
	smoke:   bool,
}

linear_render :: proc(app: ^App, ctx: ^ui.UI) {
	part, visible := progress.begin(
		ctx,
		&app.linear,
		app.value,
		0,
		100,
		progress.Options{accessible_label="Export progress", width=420},
		key=alicorn.key_string("parts-linear"),
		instance_id=4601,
	)
	if !visible { return }
	if ui.row(ctx, key=alicorn.key_string("parts-linear-heading"), width=-1,
		height=alicorn.LAYOUT_SIZE_FIT_CONTENT, align=.Center, gap=8) {
		progress.label(ctx, &part)
		progress.value_text(ctx, &part)
	}
	track, track_visible := progress.track_begin(ctx, &part)
	if track_visible {
		// This is the default indicator, but the author could draw any child
		// inside the track instead.
		progress.indicator(ctx, &track)
		progress.track_end(ctx)
	}
	progress.end(ctx, &part)
}

ring_render :: proc(app: ^App, ctx: ^ui.UI) {
	part, visible := progress.begin(
		ctx,
		&app.ring,
		app.value,
		0,
		100,
		progress.Options{accessible_label="Export ring", width=180},
		key=alicorn.key_string("parts-ring"),
		instance_id=4602,
	)
	if !visible { return }
	if ui.column(ctx, key=alicorn.key_string("parts-ring-heading"), width=-1,
		height=alicorn.LAYOUT_SIZE_FIT_CONTENT, align=.Center, gap=2) {
		_ = ui.text(ctx, "Export", key=alicorn.key_string("parts-ring-title"), size=14)
		_ = ui.text(ctx, "custom ring layout", key=alicorn.key_string("parts-ring-note"), size=11,
			color=alicorn.style_color(ctx, .Muted_Text))
	}
	if ui.row(ctx, key=ui.key_u64(10), width=168, height=168,
		align=.Center, justify=.Center) {
		ring_track(ctx, 160, .Border, 12, key=ui.key_u64(11))
		if part.normalized > 0 {
			arc := alicorn.surface_begin(
				ctx,
				alicorn.surface_core_color_role(.Accent),
				key=ui.key_u64(12),
				style=ui.layout_style(.Row, width=160, height=160),
				shape=progress.ring_shape(part.normalized),
				fill=alicorn.Color{0, 0, 0, 0},
				stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Accent), width=12},
				label="export-ring-arc",
			)
			if arc != 0 {
				alicorn.surface_end(ctx)
				_ = alicorn.position_child(ctx, arc, alicorn.positioned(0, 0))
			}
		}
		if ui.column(ctx, key=ui.key_u64(13), width=160, height=160,
			align=.Center, justify=.Center, gap=2) {
			_ = ui.text(ctx, progress.format_value(part.normalized), key=ui.key_u64(14), size=30)
			_ = ui.text(ctx, "complete", key=ui.key_u64(15), size=11,
				color=alicorn.style_color(ctx, .Muted_Text))
		}
	}
	progress.end(ctx, &part)
}

loading_ring_render :: proc(app: ^App, ctx: ^ui.UI) {
	part, visible := progress.begin(
		ctx,
		&app.loading,
		0,
		1,
		1,
		progress.Options{
			accessible_label="Optimizing images",
			width=140,
			indeterminate=true,
			indeterminate_phase=app.phase,
		},
		key=alicorn.key_string("parts-loading-ring"),
		instance_id=4603,
	)
	if !visible { return }
	if ui.row(ctx, key=ui.key_u64(20), width=132, height=132,
		align=.Center, justify=.Center) {
		ring_track(ctx, 124, .Border, 10, key=ui.key_u64(21))
		arc := alicorn.surface_begin(
			ctx,
			alicorn.surface_core_color_role(.Selection),
			key=ui.key_u64(22),
			style=ui.layout_style(.Row, width=124, height=124),
			shape=progress.ring_segment_shape(app.phase),
			fill=alicorn.Color{0, 0, 0, 0},
			stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Selection), width=10},
			label="loading-ring-arc",
		)
		if arc != 0 {
			alicorn.surface_end(ctx)
			_ = alicorn.position_child(ctx, arc, alicorn.positioned(0, 0))
		}
		if ui.column(ctx, key=ui.key_u64(23), width=124, height=124,
			align=.Center, justify=.Center) {
			_ = ui.text(ctx, "Optimizing", key=ui.key_u64(24), size=11,
				color=alicorn.style_color(ctx, .Muted_Text))
		}
	}
	progress.end(ctx, &part)
}

ring_track :: proc(
	ctx: ^ui.UI,
	size: f32,
	role: alicorn.Style_Color_Role,
	stroke_width: f32,
	key: ui.UI_Key,
) {
	id := alicorn.surface_begin(
		ctx,
		alicorn.surface_core_color_role(role),
		key=key,
		style=ui.layout_style(.Row, width=size, height=size),
		shape=alicorn.Surface_Shape{kind=.Circle},
		fill=alicorn.Color{0, 0, 0, 0},
		stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, role), width=stroke_width},
		label="progress-ring-track",
	)
	if id == 0 { return }
	alicorn.surface_end(ctx)
	_ = alicorn.position_child(ctx, id, alicorn.positioned(0, 0))
}

tick :: proc(app: ^App, rt: ^alicorn.Runtime) {
	if !app.animate || app.smoke { return }
	app.phase += 0.008
	if app.phase > 1 { app.phase -= 1 }
	alicorn.invalidate_root(rt, "progress parts example advanced indeterminate ring")
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("progress-parts-root"),
		width=-1, height=-1, padding=26, gap=16, align=.Center) {
		_ = ui.text(ctx, "Progress parts", size=26)
		_ = ui.text(ctx, "Same range, two presentations. The ring owns its layout and geometry; semantics stay shared.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		if ui.row(ctx, key=alicorn.key_string("progress-parts-row"), gap=28, align=.Start) {
			if ui.column(ctx, key=alicorn.key_string("progress-parts-left"),
				width=440, gap=16) {
				_ = ui.text(ctx, "Linear parts", size=15)
				linear_render(app, ctx)
				loading_ring_render(app, ctx)
				_ = ui.checkbox(ctx, "Animate indeterminate ring", &app.animate,
					key=alicorn.key_string("progress-parts-animate"), width=250, height=28)
			}
			if ui.column(ctx, key=alicorn.key_string("progress-parts-right"),
				width=220, gap=12, align=.Center) {
				_ = ui.text(ctx, "Ring parts", size=15)
				ring_render(app, ctx)
			}
		}
		_ = ui.text(ctx, fmt.tprintf("Value %.0f%% · phase %.2f", app.value, app.phase),
			key=alicorn.key_string("progress-parts-status"), size=12,
			color=alicorn.style_color(ctx, .Muted_Text))
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("progress_parts_smoke", "value", app.value, "phase", app.phase, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{value=68, smoke=smoke}
	ui.run(
		&app,
		render,
		title="Alicorn - Progress Parts",
		width=780,
		height=520,
		on_tick=tick,
		on_stop=stop,
		smoke=smoke,
	)
}
