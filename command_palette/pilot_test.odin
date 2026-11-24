package command_palette

// GO/NO-GO measurement for AliKit issue 3. Run with:
//   odin test palette_parts -define:ODIN_TEST_THREADS=1
// and filter for PILOT lines.
//
// Both fixtures present the same 12 caller-owned items with the same
// application-owned query, matching, ranking, and command dispatch. The stock
// fixture uses alikit:command_palette (modal shell, runtime list interaction).
// The parts fixture composes a text field with palette_parts.results. The
// scripted turns are identical.

import "core:fmt"
import "core:mem"
import "core:testing"
import "core:time"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"
import palette "alikit:palette_model"
import parts "alikit:palette_parts"

PILOT_ITEM_COUNT :: 12

Pilot_Item :: struct {
	id:       parts.Item_ID,
	title:    string,
	disabled: bool,
}

pilot_items :: proc() -> [PILOT_ITEM_COUNT]Pilot_Item {
	labels := [PILOT_ITEM_COUNT]string{
		"Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot",
		"Golf", "Hotel", "India", "Juliet", "Kilo", "Target",
	}
	items: [PILOT_ITEM_COUNT]Pilot_Item
	for label, index in labels {
		items[index] = Pilot_Item{id=parts.Item_ID(index+1), title=label, disabled=index == 7}
	}
	return items
}

pilot_palette_item :: proc(source: Pilot_Item) -> parts.Item {
	return parts.Item{id=source.id, title=source.title, disabled=source.disabled}
}

// A caller-owned filter and ranking policy shared by both fixtures. It keeps
// source order and applies substrings to the visible label.
pilot_filter :: proc(items: []Pilot_Item, query: string, output: []parts.Item) -> int {
	count := 0
	for item in items {
		candidate := pilot_palette_item(item)
		if !palette.matches(candidate, query) { continue }
		output[count] = candidate
		count += 1
	}
	return count
}

Pilot_Allocation_Site :: struct {
	procedure:   string,
	line:        i32,
	allocations: u64,
	bytes:       u64,
}

Pilot_Allocation_State :: struct {
	backing:     mem.Allocator,
	sites:       [dynamic]Pilot_Allocation_Site,
	allocations: u64,
	bytes:       u64,
}

pilot_allocator_proc :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	loc := #caller_location,
) -> ([]byte, mem.Allocator_Error) {
	state := cast(^Pilot_Allocation_State)data
	result, err := state.backing.procedure(state.backing.data, mode, size, alignment, old_memory, old_size, loc)
	if mode == .Alloc || mode == .Alloc_Non_Zeroed || mode == .Resize || mode == .Resize_Non_Zeroed {
		state.allocations += 1
		state.bytes += u64(size)
		for &site in state.sites {
			if site.procedure == loc.procedure && site.line == loc.line {
				site.allocations += 1
				site.bytes += u64(size)
				return result, err
			}
		}
		if len(state.sites) < 512 {
			append(&state.sites, Pilot_Allocation_Site{procedure=loc.procedure, line=i32(loc.line), allocations=1, bytes=u64(size)})
		}
	}
	return result, err
}

Pilot_Metrics :: struct {
	turns:                 int,
	descriptions:          u64,
	descriptions_reused:   u64,
	reconcile:             u64,
	measure:               u64,
	layout:                u64,
	paint:                 u64,
	composition:           u64,
	text_shape_requests:   u64,
	semantic_structure:    u64,
	semantic_properties:   u64,
	allocations:           u64,
	allocated_bytes:       u64,
	latencies:             [64]u64,
	idle_wakes:            int,
}

pilot_record_work :: proc(metrics: ^Pilot_Metrics, work: testui.Turn_Work, elapsed: u64) {
	metrics.turns += 1
	metrics.descriptions += work.descriptions_emitted
	metrics.descriptions_reused += work.descriptions_reused
	metrics.reconcile += work.reconcile_nodes_visited
	metrics.measure += work.measure_nodes_examined
	metrics.layout += work.layout_nodes_visited
	metrics.paint += work.paint_nodes_visited
	metrics.composition += work.composition_nodes_visited
	metrics.text_shape_requests += work.text_shape_requests
	metrics.semantic_structure += work.semantic_structure_changes
	metrics.semantic_properties += work.semantic_property_changes
	if metrics.turns-1 < len(metrics.latencies) { metrics.latencies[metrics.turns-1] = elapsed }
}

pilot_measure_step :: proc(metrics: ^Pilot_Metrics, handle: ^testui.Test_Handle($T), input: testui.Input) -> testui.Status {
	start := time.now()
	status := testui.step(handle, input)
	elapsed := u64(time.duration_nanoseconds(time.since(start)))
	pilot_record_work(metrics, handle.last_turn.work, elapsed)
	return status
}

pilot_percentile :: proc(values: []u64, fraction: f64) -> u64 {
	if len(values) == 0 { return 0 }
	for index in 1..<len(values) {
		value := values[index]
		cursor := index
		for cursor > 0 && value < values[cursor-1] {
			values[cursor] = values[cursor-1]
			cursor -= 1
		}
		values[cursor] = value
	}
	index := int(fraction*f64(len(values)-1)+0.5)
	return values[clamp(index, 0, len(values)-1)]
}

// Stock fixture: the existing AliKit command palette.

Pilot_Stock_App :: struct {
	state:    State,
	items:    [PILOT_ITEM_COUNT]Pilot_Item,
	filtered: [PILOT_ITEM_COUNT]parts.Item,
	count:    int,
	activations: int,
	last_id:  parts.Item_ID,
}

pilot_stock_build :: proc(state: rawptr, rt: ^alicorn.Runtime, width, height: int, scale: f32) -> alicorn.Node_ID {
	app := cast(^Pilot_Stock_App)state
	ctx, should_build := alicorn.begin_frame(rt)
	if !should_build { return 0 }
	root := alicorn.container_begin(&ctx, .Root, label="pilot-stock-root",
		key=alicorn.key_string("pilot-stock-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, padding=18))
	app.count = pilot_filter(app.items[:], query_text(&app.state), app.filtered[:])
	_ = ui.text(&ctx, "Commands", size=18)
	alicorn.container_end(&ctx)
	event := build(
		&ctx,
		&app.state,
		app.filtered[:app.count],
		key=alicorn.key_string("pilot-stock-palette"),
		options=Options{hide_title=true},
	)
	if event.kind == .Activated {
		app.activations += 1
		app.last_id = event.item_id
	}
	alicorn.end_frame(&ctx)
	return root
}

pilot_stock_initialize :: proc(state: rawptr, rt: ^alicorn.Runtime) {
	app := cast(^Pilot_Stock_App)state
	app.items = pilot_items()
	_ = open_palette(&app.state, rt, .Caller_Filtered)
}

pilot_stock_key :: proc(state: rawptr, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	app := cast(^Pilot_Stock_App)state
	handled, event := handle_key(&app.state, rt, app.filtered[:app.count], key)
	if event.kind == .Activated {
		app.activations += 1
		app.last_id = event.item_id
	}
	return handled
}

pilot_run_stock :: proc(metrics: ^Pilot_Metrics, allocation: ^Pilot_Allocation_State) -> bool {
	app := Pilot_Stock_App{items=pilot_items()}
	allocator := mem.Allocator{procedure=pilot_allocator_proc, data=allocation}
	if !init(&app.state, allocator) { return false }
	defer destroy(&app.state)
	handle, status := testui.open(
		&app,
		width=640,
		height=480,
		allocator=allocator,
		initialize=pilot_stock_initialize,
		build_application=pilot_stock_build,
		on_key=pilot_stock_key,
	)
	defer if handle.runtime != nil { testui.close(&handle) }
	if status != .Ok { fmt.println("PILOT stock open failed", status, testui.last_turn_diagnostic(&handle)); return false }
	if app.count == 0 { fmt.println("PILOT stock initial filter produced no rows"); return false }
	inputs := [6]testui.Input{
		{kind=.Text_Commit, text="o"},
		{kind=.Key, key=.Down},
		{kind=.Key, key=.Down},
		{kind=.Key, key=.Up},
		{kind=.Key, key=.Down},
		{kind=.Key, key=.Return},
	}
	for input in inputs {
		if pilot_measure_step(metrics, &handle, input) != .Ok {
			fmt.println("PILOT stock step failed", input.kind, input.key, testui.last_turn_diagnostic(&handle))
			return false
		}
	}
	if testui.advance_time(&handle, 16_000_000) != .Ok { fmt.println("PILOT stock advance failed"); return false }
	if handle.runtime.invalidated || alicorn.presentation_needs_frame(handle.runtime) { metrics.idle_wakes += 1 }
	metrics.allocations = allocation.allocations
	metrics.allocated_bytes = allocation.bytes
	if app.last_id != parts.Item_ID(6) { fmt.println("PILOT stock activation was", app.last_id, "count", app.count); return false }
	return true
}

// Parts fixture: caller-owned query, matching, ranking, and commands composed
// with palette_parts.results.

Pilot_Parts_App :: struct {
	items:     [PILOT_ITEM_COUNT]Pilot_Item,
	filtered:  [PILOT_ITEM_COUNT]parts.Item,
	matches:   [PILOT_ITEM_COUNT]parts.Match,
	count:     int,
	query:     ui.Text_Buffer,
	state:     parts.State,
	query_node: alicorn.Node_ID,
	focus_query_pending: bool,
	activations: int,
	last_id:   parts.Item_ID,
}

pilot_parts_focus_query :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	app := cast(^Pilot_Parts_App)data
	if app == nil || rt == nil || app.query_node == 0 { return }
	if alicorn.focus(rt, app.query_node) {
		app.focus_query_pending = false
		_ = alicorn.set_text_selection(rt, app.query_node, 0, len(app.query.text))
	}
}

pilot_parts_build :: proc(state: rawptr, rt: ^alicorn.Runtime, width, height: int, scale: f32) -> alicorn.Node_ID {
	app := cast(^Pilot_Parts_App)state
	ctx, should_build := alicorn.begin_frame(rt)
	if !should_build { return 0 }
	root := alicorn.container_begin(&ctx, .Root, label="pilot-parts-root",
		key=alicorn.key_string("pilot-parts-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, padding=18, gap=10))
	_ = ui.text(&ctx, "Commands", size=18)
	field := alicorn.text_field_controlled(
		&ctx,
		&app.query,
		key=alicorn.key_string("pilot-parts-query"),
		style=alicorn.layout_style(.Row, width=-1, height=38),
	)
	app.query_node = field.node
	if field.node != 0 { _ = alicorn.semantic_text_field_label(&ctx, "Search commands") }
	app.count = pilot_filter(app.items[:], app.query.text, app.filtered[:])
	_, _ = palette.index_all(app.filtered[:app.count], app.matches[:])
	event := parts.results(
		&ctx,
		&app.state,
		app.filtered[:app.count],
		app.matches[:app.count],
		key=alicorn.key_string("pilot-parts-results"),
		options=parts.Options{accessible_label="Commands", list_max_height=360},
	)
	if event.kind == .Activated {
		app.activations += 1
		app.last_id = event.item_id
	}
	if app.focus_query_pending { _ = ui.after_frame(&ctx, app, pilot_parts_focus_query) }
	alicorn.container_end(&ctx)
	alicorn.end_frame(&ctx)
	return root
}

pilot_parts_initialize :: proc(state: rawptr, rt: ^alicorn.Runtime) {
	app := cast(^Pilot_Parts_App)state
	app.items = pilot_items()
	app.focus_query_pending = true
	app.state.selection.id = 1
}

pilot_parts_key :: proc(state: rawptr, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	app := cast(^Pilot_Parts_App)state
	handled, event := parts.handle_key(&app.state, rt, app.filtered[:app.count], app.matches[:app.count], key)
	if event.kind == .Activated {
		app.activations += 1
		app.last_id = event.item_id
	}
	return handled
}

pilot_run_parts :: proc(metrics: ^Pilot_Metrics, allocation: ^Pilot_Allocation_State) -> bool {
	app := Pilot_Parts_App{items=pilot_items()}
	allocator := mem.Allocator{procedure=pilot_allocator_proc, data=allocation}
	buffer, ok := ui.text_buffer("", allocator)
	if !ok { return false }
	app.query = buffer
	defer ui.text_buffer_destroy(&app.query)
	app.state.selection.id = 1
	handle, status := testui.open(
		&app,
		width=640,
		height=480,
		allocator=allocator,
		initialize=pilot_parts_initialize,
		build_application=pilot_parts_build,
		on_key=pilot_parts_key,
	)
	defer if handle.runtime != nil { testui.close(&handle) }
	if status != .Ok { return false }
	if app.count == 0 { return false }
	inputs := [6]testui.Input{
		{kind=.Text_Commit, text="o"},
		{kind=.Key, key=.Down},
		{kind=.Key, key=.Down},
		{kind=.Key, key=.Up},
		{kind=.Key, key=.Down},
		{kind=.Key, key=.Return},
	}
	for input in inputs {
		if pilot_measure_step(metrics, &handle, input) != .Ok { return false }
	}
	if testui.advance_time(&handle, 16_000_000) != .Ok { return false }
	if handle.runtime.invalidated || alicorn.presentation_needs_frame(handle.runtime) { metrics.idle_wakes += 1 }
	metrics.allocations = allocation.allocations
	metrics.allocated_bytes = allocation.bytes
	if app.last_id != parts.Item_ID(6) {
		fmt.println("PILOT parts activation was", app.last_id, "count", app.count)
		return false
	}
	return true
}

pilot_print :: proc(label: string, metrics: Pilot_Metrics, allocation: Pilot_Allocation_State) {
	fmt.println("PILOT", label, "turns", metrics.turns,
		"descriptions", metrics.descriptions, "descriptions_reused", metrics.descriptions_reused,
		"reconcile", metrics.reconcile, "measure", metrics.measure, "layout", metrics.layout,
		"paint", metrics.paint, "composition", metrics.composition,
		"text_shape_requests", metrics.text_shape_requests,
		"semantic_structure", metrics.semantic_structure, "semantic_properties", metrics.semantic_properties)
	latency_values := metrics.latencies
	count := min(metrics.turns, len(latency_values))
	fmt.println("PILOT", label, "allocations", allocation.allocations, "allocated_bytes", allocation.bytes,
		"p50_turn_ns", pilot_percentile(latency_values[:count], 0.50),
		"p95_turn_ns", pilot_percentile(latency_values[:count], 0.95),
		"idle_wakes", metrics.idle_wakes)
}

@(test)
test_parts_pilot_measures_stock_palette_against_parts :: proc(t: ^testing.T) {
	stock_allocation := Pilot_Allocation_State{backing=context.allocator}
	stock_allocation.sites = make([dynamic]Pilot_Allocation_Site, 0, 256, allocator=context.allocator)
	defer delete(stock_allocation.sites)
	stock_metrics := Pilot_Metrics{}
	if !testing.expect(t, pilot_run_stock(&stock_metrics, &stock_allocation), "the stock palette pilot script should complete") { return }

	parts_allocation := Pilot_Allocation_State{backing=context.allocator}
	parts_allocation.sites = make([dynamic]Pilot_Allocation_Site, 0, 256, allocator=context.allocator)
	defer delete(parts_allocation.sites)
	parts_metrics := Pilot_Metrics{}
	if !testing.expect(t, pilot_run_parts(&parts_metrics, &parts_allocation), "the parts palette pilot script should complete") { return }

	pilot_print("stock", stock_metrics, stock_allocation)
	pilot_print("parts", parts_metrics, parts_allocation)
	testing.expect_value(t, parts_metrics.turns, stock_metrics.turns)
}
