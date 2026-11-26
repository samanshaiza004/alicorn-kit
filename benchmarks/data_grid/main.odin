package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:time"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"
import grid "alikit:data_grid"

VIEWPORT_WIDTH :: 1280
VIEWPORT_HEIGHT :: 800
VISIBLE_ROWS :: 12
WARMUP_COUNT :: 3
SAMPLE_COUNT :: 101
P95_INDEX :: (SAMPLE_COUNT*95+99)/100-1
P99_INDEX :: (SAMPLE_COUNT*99+99)/100-1
INSTANCE_ID :: u64(4242)

Bench_App :: struct {
	state:   grid.State,
	columns: [3]grid.Column,
	rows:    []grid.Row,
	cells:   []grid.Cell,
}

build_data :: proc(app: ^Bench_App, row_count: int) {
	project_labels := [8]string{
		"Alder Project", "Beacon Lane", "Cedar Library", "Delta Tools",
		"Ember Archive", "Forest Notes", "Granite Studio", "Harbor Index",
	}
	app.columns = {
		{key=1, label="Project", width=240, align=.Start},
		{key=2, label="Owner", width=160, align=.Start},
		{key=3, label="Status", align=.Start},
	}
	app.rows = make([]grid.Row, row_count)
	app.cells = make([]grid.Cell, row_count*3)
	for index in 0..<row_count {
		cells := app.cells[index*3:index*3+3]
		cells[0] = grid.Cell{text=project_labels[index%len(project_labels)]}
		cells[1] = grid.Cell{text="Team"}
		cells[2] = grid.Cell{text="Active"}
		app.rows[index] = grid.Row{key=u64(index+1), cells=cells}
	}
}

render :: proc(app: ^Bench_App, ctx: ^ui.UI) {
	_ = grid.data_grid(
		ctx,
		&app.state,
		app.columns[:],
		app.rows,
		grid.Selection{row_key=1, column_key=1},
		grid.Options{
			accessible_label="Projects",
			row_header=true,
			max_visible_rows=VISIBLE_ROWS,
			row_height=32,
		},
		key=ui.key_string("data-grid-scaling-benchmark"),
		instance_id=INSTANCE_ID,
	)
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

run_case :: proc(row_count: int) -> bool {
	app := Bench_App{}
	build_data(&app, row_count)
	handle, status := testui.open(&app, render, width=VIEWPORT_WIDTH, height=VIEWPORT_HEIGHT)
	if status != .Ok {
		fmt.eprintln("open failed", row_count, status, testui.last_turn_diagnostic(&handle))
		if handle.runtime != nil { testui.close(&handle) }
		delete(app.rows)
		delete(app.cells)
		return false
	}
	defer testui.close(&handle)
	defer delete(app.rows)
	defer delete(app.cells)

	// Warm several explicit root descriptions so the timed samples measure
	// updates to an established retained tree, not first creation or startup.
	for _ in 0..<WARMUP_COUNT {
		alicorn.invalidate_root(handle.runtime, "benchmark warmup")
		if testui.advance_time(&handle, 0) != .Ok {
			fmt.eprintln("warmup failed", row_count, testui.last_turn_diagnostic(&handle))
			return false
		}
	}

	logical_row_entities := 0
	virtual_row_entities := 0
	virtual_row_label_bytes := 0
	for index in 0..<row_count {
		row_id := grid.row_semantic_id(INSTANCE_ID, u64(index+1))
		row_node, found := alicorn.semantic_node_lookup(handle.runtime, row_id)
		if found && row_node.role == .Table_Row {
			logical_row_entities += 1
			if row_node.is_virtual_item {
				virtual_row_entities += 1
				virtual_row_label_bytes += len(row_node.label)
			}
		}
	}
	if logical_row_entities != row_count || virtual_row_entities > row_count ||
		(row_count > VISIBLE_ROWS*2 && virtual_row_entities == 0) {
		fmt.println(
			"benchmark fixture did not publish the expected virtual semantics",
			row_count, logical_row_entities, virtual_row_entities,
		)
		return false
	}

	description_samples: [SAMPLE_COUNT]u64
	stage_samples: [alicorn.RUNTIME_TIMING_STAGE_COUNT][SAMPLE_COUNT]u64
	semantic_description_samples: [SAMPLE_COUNT]u64
	for index in 0..<SAMPLE_COUNT {
		alicorn.invalidate_root(handle.runtime, "benchmark repeated description")
		stats_before := alicorn.frame_stats_snapshot(handle.runtime)
		started := time.now()
		status = testui.advance_time(&handle, 0)
		description_samples[index] = u64(time.duration_nanoseconds(time.since(started)))
		if status != .Ok {
			fmt.eprintln("sample failed", row_count, index, status, testui.last_turn_diagnostic(&handle))
			return false
		}
		stats_after := alicorn.frame_stats_snapshot(handle.runtime)
		work := handle.last_turn.work
		for stage_index in 0..<alicorn.RUNTIME_TIMING_STAGE_COUNT {
			stage_samples[stage_index][index] = work.stage_timings_ns[alicorn.Runtime_Timing_Stage(stage_index)]
		}
		semantic_description_samples[index] = stats_after.semantic_descriptions_emitted-
			stats_before.semantic_descriptions_emitted
	}
	sort_samples(description_samples[:])
	for stage_index in 0..<alicorn.RUNTIME_TIMING_STAGE_COUNT {
		sort_samples(stage_samples[stage_index][:])
	}
	sort_samples(semantic_description_samples[:])

	fmt.println("case", row_count, "viewport", VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	fmt.println("logical_row_semantic_entities", logical_row_entities)
	fmt.println("offscreen_row_semantic_entities", virtual_row_entities)
	fmt.println("offscreen_row_label_bytes", virtual_row_label_bytes)
	fmt.println("description_median_ns", description_samples[SAMPLE_COUNT/2])
	fmt.println("description_p95_ns", description_samples[P95_INDEX])
	fmt.println("description_p99_ns", description_samples[P99_INDEX])
	fmt.println("stage_timings_ns p50 p95 p99")
	for stage_index in 0..<alicorn.RUNTIME_TIMING_STAGE_COUNT {
		stage := alicorn.Runtime_Timing_Stage(stage_index)
		stage_values := stage_samples[stage_index]
		fmt.println(stage, stage_values[SAMPLE_COUNT/2], stage_values[P95_INDEX], stage_values[P99_INDEX])
	}
	fmt.println("semantic_descriptions_per_frame_median", semantic_description_samples[SAMPLE_COUNT/2])
	fmt.println("measure_nodes_examined", handle.last_turn.work.measure_nodes_examined)
	fmt.println("layout_nodes_visited", handle.last_turn.work.layout_nodes_visited)
	fmt.println("semantic_structure_changes", handle.last_turn.work.semantic_structure_changes)
	fmt.print("description_samples_ns")
	for sample in description_samples { fmt.print(" ", sample) }
	fmt.println()
	fmt.print("semantic_sync_samples_ns")
	for sample in stage_samples[int(alicorn.Runtime_Timing_Stage.Semantic_Sync)] { fmt.print(" ", sample) }
	fmt.println()
	return true
}

main :: proc() {
	fmt.println("AliKit Data Grid retained-description scaling probe")
	fmt.println("rows visible", VISIBLE_ROWS, "warmups", WARMUP_COUNT, "samples", SAMPLE_COUNT)
	if len(os.args) == 2 {
		row_count, ok := strconv.parse_int(os.args[1])
		if !ok || row_count < VISIBLE_ROWS { fmt.eprintln("row count must be an integer >=", VISIBLE_ROWS); os.exit(2) }
		if !run_case(row_count) { os.exit(1) }
		return
	}
	if len(os.args) > 2 { fmt.eprintln("usage: data_grid_benchmark [row-count]"); os.exit(2) }
	for row_count in ([3]int{200, 10_000, 100_000}) {
		if !run_case(row_count) { os.exit(1) }
	}
}
