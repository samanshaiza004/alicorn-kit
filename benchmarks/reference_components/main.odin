package main

import "core:fmt"
import "core:os"
import "core:time"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"
import palette "alikit:command_palette"
import dialog "alikit:dialog"

VIEWPORT_WIDTH :: 1280
VIEWPORT_HEIGHT :: 800
WARMUP_COUNT :: 3
IDLE_PROBE_COUNT :: 101
SAMPLE_COUNT :: 1_001
P95_INDEX :: (SAMPLE_COUNT*95+99)/100-1
P99_INDEX :: (SAMPLE_COUNT*99+99)/100-1

PALETTE_ITEMS := [3]palette.Item{
	{id=1, title="Open Project", description="Browse workspace files", keywords="workspace files"},
	{id=2, title="Search Activity", description="Find recent changes", keywords="history"},
	{id=3, title="Project Settings", description="Manage access and retention", keywords="preferences"},
}

Palette_App :: struct {
	state: palette.State,
}

Dialog_App :: struct {
	state: dialog.State,
}

sort_samples :: proc(values: []u64) {
	for index in 1..<len(values) {
		value := values[index]
		cursor := index
		for cursor > 0 && value < values[cursor-1] {
			values[cursor] = values[cursor-1]
			cursor -= 1
		}
		values[cursor] = value
	}
}

work_is_zero :: proc(work: testui.Turn_Work) -> bool {
	if work.descriptions_emitted != 0 || work.descriptions_reused != 0 ||
	   work.reconcile_nodes_visited != 0 || work.measure_nodes_examined != 0 ||
	   work.measure_nodes_executed != 0 || work.layout_nodes_visited != 0 ||
	   work.paint_nodes_visited != 0 || work.composition_nodes_visited != 0 ||
	   work.text_shape_requests != 0 || work.semantic_entities_resolved != 0 ||
	   work.semantic_structure_changes != 0 || work.semantic_property_changes != 0 ||
	   work.semantic_projection_nodes_added != 0 || work.semantic_projection_nodes_updated != 0 ||
	   work.semantic_projection_nodes_removed != 0 || work.gpu_submits != 0 {
		return false
	}
	for stage_index in 0..<alicorn.RUNTIME_TIMING_STAGE_COUNT {
		if work.stage_timings_ns[alicorn.Runtime_Timing_Stage(stage_index)] != 0 { return false }
	}
	return true
}

palette_render :: proc(app: ^Palette_App, ctx: ^ui.UI) {
	if ui.panel(ctx, key=ui.key_string("bench-palette-root"), width=-1, height=-1,
		padding=24, gap=12, fill=ui.style_color(ctx, .Window_Background), label="Workspace") {
		_ = ui.text(ctx, "Northstar", size=24)
		_ = ui.text(ctx, "Workspace actions", size=14)
	}
}

palette_overlay :: proc(app: ^Palette_App, ctx: ^ui.UI) {
	if !app.state.open { return }
	_ = palette.build(ctx, &app.state, PALETTE_ITEMS[:],
		ui.key_string("bench-palette-modal"),
		palette.Options{title="Quick actions", query_accessible_name="Search actions"})
}

dialog_render :: proc(app: ^Dialog_App, ctx: ^ui.UI) {
	if ui.panel(ctx, key=ui.key_string("bench-dialog-root"), width=-1, height=-1,
		padding=24, gap=12, fill=ui.style_color(ctx, .Window_Background), label="Workspace") {
		_ = ui.text(ctx, "Northstar", size=24)
		_ = ui.text(ctx, "Project settings", size=14)
	}
}

dialog_overlay :: proc(app: ^Dialog_App, ctx: ^ui.UI) {
	if !app.state.open { return }
	visible, _ := dialog.begin(ctx, &app.state, "Rename project",
		dialog.Options{description="Choose a new name for this workspace."},
		key=ui.key_string("bench-dialog-modal"), instance_id=8042)
	if !visible { return }
	dialog.title(ctx, "Rename project")
	dialog.description(ctx, "Choose a new name for this workspace.")
	if dialog.action_row_begin(ctx, key=ui.key_string("bench-dialog-actions")) {
		if dialog.action(ctx, &app.state, "Cancel", .Cancel, key=ui.key_string("bench-dialog-cancel")) {
			dialog.dismiss(ctx, &app.state, .Action)
		}
		if dialog.action(ctx, &app.state, "Save", .Primary, key=ui.key_string("bench-dialog-save")) {
			dialog.dismiss(ctx, &app.state, .Action)
		}
		dialog.action_row_end(ctx)
	}
	dialog.end(ctx, &app.state)
}

run_palette :: proc() -> bool {
	app := Palette_App{}
	if !palette.init(&app.state) { return false }
	defer palette.destroy(&app.state)
	handle, status := testui.open(&app, palette_render, width=VIEWPORT_WIDTH,
		height=VIEWPORT_HEIGHT, render_overlays=palette_overlay)
	if status != .Ok {
		fmt.eprintln("palette open failed", status, testui.last_turn_diagnostic(&handle))
		if handle.runtime != nil { testui.close(&handle) }
		return false
	}
	defer testui.close(&handle)
	if !palette.open_palette(&app.state, handle.runtime) || testui.advance_time(&handle, 0) != .Ok {
		fmt.eprintln("palette modal open failed", testui.last_turn_diagnostic(&handle))
		return false
	}
	return measure("command_palette", &handle)
}

run_dialog :: proc() -> bool {
	app := Dialog_App{}
	handle, status := testui.open(&app, dialog_render, width=VIEWPORT_WIDTH,
		height=VIEWPORT_HEIGHT, render_overlays=dialog_overlay)
	if status != .Ok {
		fmt.eprintln("dialog open failed", status, testui.last_turn_diagnostic(&handle))
		if handle.runtime != nil { testui.close(&handle) }
		return false
	}
	defer testui.close(&handle)
	if !dialog.open(&app.state, handle.runtime) || testui.advance_time(&handle, 0) != .Ok {
		fmt.eprintln("dialog modal open failed", testui.last_turn_diagnostic(&handle))
		return false
	}
	return measure("dialog", &handle)
}

measure :: proc(label: string, handle: ^testui.Test_Handle($T)) -> bool {
	for _ in 0..<WARMUP_COUNT {
		alicorn.invalidate_root(handle.runtime, "reference benchmark warmup")
		if testui.advance_time(handle, 0) != .Ok {
			fmt.eprintln("warmup failed", label, testui.last_turn_diagnostic(handle))
			return false
		}
	}

	if testui.advance_time(handle, 2_000_000_000) != .Ok {
		fmt.eprintln("settle failed", label, testui.last_turn_diagnostic(handle))
		return false
	}
	for sample in 0..<IDLE_PROBE_COUNT {
		if testui.advance_time(handle, 16_000_000) != .Ok ||
		   !work_is_zero(handle.last_turn.work) || handle.runtime.invalidated ||
		   alicorn.presentation_needs_frame(handle.runtime) {
			fmt.eprintln("settled idle failed", label, sample, handle.last_turn.work)
			return false
		}
	}

	description_samples: [SAMPLE_COUNT]u64
	stage_samples: [alicorn.RUNTIME_TIMING_STAGE_COUNT][SAMPLE_COUNT]u64
	for index in 0..<SAMPLE_COUNT {
		alicorn.invalidate_root(handle.runtime, "reference benchmark description")
		started := time.now()
		status := testui.advance_time(handle, 0)
		description_samples[index] = u64(time.duration_nanoseconds(time.since(started)))
		if status != .Ok {
			fmt.eprintln("description sample failed", label, index, status,
				testui.last_turn_diagnostic(handle))
			return false
		}
		for stage_index in 0..<alicorn.RUNTIME_TIMING_STAGE_COUNT {
			stage_samples[stage_index][index] = handle.last_turn.work.stage_timings_ns[
				alicorn.Runtime_Timing_Stage(stage_index)]
		}
	}
	sort_samples(description_samples[:])
	for stage_index in 0..<alicorn.RUNTIME_TIMING_STAGE_COUNT {
		sort_samples(stage_samples[stage_index][:])
	}
	fmt.println("case", label, "viewport", VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	fmt.println("warmups", WARMUP_COUNT, "samples", SAMPLE_COUNT,
		"settled_idle_probes", IDLE_PROBE_COUNT, "retained_work", 0, "frame_demand", false)
	fmt.println("description_elapsed_ns_p50", description_samples[SAMPLE_COUNT/2])
	fmt.println("description_elapsed_ns_p95", description_samples[P95_INDEX])
	fmt.println("description_elapsed_ns_p99", description_samples[P99_INDEX])
	fmt.print("description_elapsed_samples_ns")
	for sample in description_samples { fmt.print(" ", sample) }
	fmt.println()
	fmt.println("runtime_stage_ns_p50_p95_p99")
	for stage_index in 0..<alicorn.RUNTIME_TIMING_STAGE_COUNT {
		stage := alicorn.Runtime_Timing_Stage(stage_index)
		stage_values := stage_samples[stage_index]
		fmt.println(stage, stage_values[SAMPLE_COUNT/2], stage_values[P95_INDEX], stage_values[P99_INDEX])
	}
	return true
}

main :: proc() {
	if len(os.args) != 2 {
		fmt.eprintln("usage: reference_components <command_palette|dialog>")
		os.exit(2)
	}
	ok := false
	switch os.args[1] {
	case "command_palette": ok = run_palette()
	case "dialog": ok = run_dialog()
	case: fmt.eprintln("unknown reference component:", os.args[1]); os.exit(2)
	}
	if !ok { os.exit(1) }
}
