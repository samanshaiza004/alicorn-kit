package main

import "core:os"
import "core:fmt"
import "core:time"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import testui "alicorn:testui"
import radio "alikit:radio_group"
import segmented "alikit:segmented"

Treatment :: enum { Minimal, Hardware, Paper }
Marker :: enum { Bar, Dot, Underline }
Style_Context :: enum { Toolbar, Dialog }
Style_Origin_Kind :: enum { Default, Fragment, Context, Instance }
Style_Field :: enum {
	Height, Gap, Inset, Font, Font_Size, Font_Weight,
	Fill, Selected_Fill, Ink, Disabled_Ink, Mark_Ink, Focus_Ink,
	Stroke, Radius, Material, Optical_Height, Marker, Count,
}
Style_Fragment :: enum {
	Base_Ink, Compact_Metrics, Hardware_Metrics, Paper_Metrics,
	Flat_Surface, Relief_Surface, Paper_Surface,
	Standard_Type, Monospace_Type, Paper_Type,
	Bar_Indicator, Dot_Indicator, Underline_Indicator,
}
STYLE_METRIC_FIELDS := [3]Style_Field{.Height, .Gap, .Inset}

// A closed vocabulary for this pilot. Layout is measured in logical units.
// The marker's dimensions never set the Button owner's hit target.
Item_Style :: struct {
	height, gap, inset: f32,
	font:               alicorn.Font_Role,
	text:               alicorn.Text_Style,
	fill, selected_fill: alicorn.Color,
	ink, disabled_ink:  alicorn.Color,
	mark_ink, focus_ink: alicorn.Color,
	stroke:             alicorn.Paint_Stroke,
	radius:             f32,
	material:           alicorn.Material_ID,
	optical_height:     f32,
	marker:             Marker,
}

Style_Origin :: struct {
	kind:     Style_Origin_Kind,
	recipe:   Treatment,
	fragment: Style_Fragment,
	context_scope: Style_Context,
}

Style_Result :: struct {
	recipe:   Treatment,
	context_scope: Style_Context,
	value:    Item_Style,
	origins:  [Style_Field.Count]Style_Origin,
}

Style_Override :: struct {
	height:     f32,
	set_height: bool,
}

// The recipe is intentionally ordinary Odin. Named procedures compose a
// complete typed value; contexts are explicit inputs and styles are resolved
// when the application changes treatment, not while describing each frame.
style_mark_origin :: proc(result: ^Style_Result, field: Style_Field, origin: Style_Origin) {
	result.origins[int(field)] = origin
}

style_apply_base_ink :: proc(result: ^Style_Result, treatment: Treatment) {
	result.value.ink = ui.rgb(0xF2F6FA)
	result.value.disabled_ink = ui.rgb(0xA8B0B9)
	result.value.mark_ink = ui.rgb(0xA6DFFF)
	result.value.focus_ink = ui.rgb(0xFFF1AD)
	origin := Style_Origin{kind=.Fragment, fragment=.Base_Ink}
	style_mark_origin(result, .Ink, origin)
	style_mark_origin(result, .Disabled_Ink, origin)
	style_mark_origin(result, .Mark_Ink, origin)
	style_mark_origin(result, .Focus_Ink, origin)
	if treatment == .Paper {
		result.value.ink = ui.rgb(0x262520)
		result.value.disabled_ink = ui.rgb(0x665D51)
		result.value.mark_ink = ui.rgb(0x703C25)
		result.value.focus_ink = ui.rgb(0x4B3A87)
	}
}

style_apply_compact_metrics :: proc(result: ^Style_Result) {
	result.value.height, result.value.gap, result.value.inset = 44, 2, 0
	for field in STYLE_METRIC_FIELDS {
		style_mark_origin(result, field, {kind=.Fragment, fragment=.Compact_Metrics})
	}
	result.value.optical_height = 0
	style_mark_origin(result, .Optical_Height, {kind=.Fragment, fragment=.Compact_Metrics})
	result.value.radius = 3
	style_mark_origin(result, .Radius, {kind=.Fragment, fragment=.Compact_Metrics})
}

style_apply_hardware_metrics :: proc(result: ^Style_Result) {
	result.value.height, result.value.gap, result.value.inset = 66, 4, 4
	for field in STYLE_METRIC_FIELDS {
		style_mark_origin(result, field, {kind=.Fragment, fragment=.Hardware_Metrics})
	}
	result.value.optical_height = 1
	style_mark_origin(result, .Optical_Height, {kind=.Fragment, fragment=.Hardware_Metrics})
	result.value.radius = 9
	style_mark_origin(result, .Radius, {kind=.Fragment, fragment=.Hardware_Metrics})
}

style_apply_paper_metrics :: proc(result: ^Style_Result) {
	result.value.height, result.value.gap, result.value.inset = 56, 7, 2
	for field in STYLE_METRIC_FIELDS {
		style_mark_origin(result, field, {kind=.Fragment, fragment=.Paper_Metrics})
	}
	result.value.optical_height = 0
	style_mark_origin(result, .Optical_Height, {kind=.Fragment, fragment=.Paper_Metrics})
	result.value.radius = 1
	style_mark_origin(result, .Radius, {kind=.Fragment, fragment=.Paper_Metrics})
}

style_apply_flat_surface :: proc(result: ^Style_Result) {
	result.value.fill, result.value.selected_fill = ui.rgb(0x202933), ui.rgb(0x283646)
	result.value.stroke = {}
	result.value.material = 0
	style_mark_origin(result, .Fill, {kind=.Fragment, fragment=.Flat_Surface})
	style_mark_origin(result, .Selected_Fill, {kind=.Fragment, fragment=.Flat_Surface})
	style_mark_origin(result, .Stroke, {kind=.Fragment, fragment=.Flat_Surface})
	style_mark_origin(result, .Material, {kind=.Fragment, fragment=.Flat_Surface})
}

style_apply_relief_surface :: proc(result: ^Style_Result, relief: alicorn.Material_ID) {
	result.value.fill, result.value.selected_fill = ui.rgb(0x263138), ui.rgb(0x394C55)
	result.value.stroke = {color=ui.rgb(0x677882), width=1}
	result.value.material = relief
	style_mark_origin(result, .Fill, {kind=.Fragment, fragment=.Relief_Surface})
	style_mark_origin(result, .Selected_Fill, {kind=.Fragment, fragment=.Relief_Surface})
	style_mark_origin(result, .Stroke, {kind=.Fragment, fragment=.Relief_Surface})
	style_mark_origin(result, .Material, {kind=.Fragment, fragment=.Relief_Surface})
}

style_apply_paper_surface :: proc(result: ^Style_Result) {
	result.value.fill, result.value.selected_fill = ui.rgb(0xEEE5CE), ui.rgb(0xFFF7E7)
	result.value.stroke = {color=ui.rgb(0xB3A68C), width=1}
	result.value.material = 0
	style_mark_origin(result, .Fill, {kind=.Fragment, fragment=.Paper_Surface})
	style_mark_origin(result, .Selected_Fill, {kind=.Fragment, fragment=.Paper_Surface})
	style_mark_origin(result, .Stroke, {kind=.Fragment, fragment=.Paper_Surface})
	style_mark_origin(result, .Material, {kind=.Fragment, fragment=.Paper_Surface})
}

style_apply_type :: proc(result: ^Style_Result, fragment: Style_Fragment, font: alicorn.Font_Role, size, weight: f32) {
	result.value.font = font
	result.value.text = {font_size=size, font_weight=weight, overflow=.Ellipsis}
	origin := Style_Origin{kind=.Fragment, fragment=fragment}
	style_mark_origin(result, .Font, origin)
	style_mark_origin(result, .Font_Size, origin)
	style_mark_origin(result, .Font_Weight, origin)
}

style_apply_indicator :: proc(result: ^Style_Result, fragment: Style_Fragment, marker: Marker, ink: alicorn.Color) {
	result.value.marker = marker
	result.value.mark_ink = ink
	origin := Style_Origin{kind=.Fragment, fragment=fragment}
	style_mark_origin(result, .Marker, origin)
	style_mark_origin(result, .Mark_Ink, origin)
}

style_apply_context :: proc(result: ^Style_Result, ctx_scope: Style_Context) {
	if ctx_scope == .Toolbar {
		result.value.height = max(result.value.height-4, 36)
		result.value.inset = max(result.value.inset-1, 0)
		origin := Style_Origin{kind=.Context, context_scope=.Toolbar}
		style_mark_origin(result, .Height, origin)
		style_mark_origin(result, .Inset, origin)
	} else {
		result.value.height += 4
		result.value.gap += 1
		result.value.inset += 1
		origin := Style_Origin{kind=.Context, context_scope=.Dialog}
		style_mark_origin(result, .Height, origin)
		style_mark_origin(result, .Gap, origin)
		style_mark_origin(result, .Inset, origin)
	}
}

style_resolve :: proc(treatment: Treatment, ctx_scope: Style_Context, relief: alicorn.Material_ID, override: Style_Override = {}) -> Style_Result {
	result := Style_Result{
		recipe=treatment,
		context_scope=ctx_scope,
		value=Item_Style{radius=0, text={overflow=.Ellipsis}},
	}
	style_apply_base_ink(&result, treatment)
	switch treatment {
	case .Minimal:
		style_apply_compact_metrics(&result)
		style_apply_flat_surface(&result)
		style_apply_type(&result, .Standard_Type, .UI, 14, 400)
		style_apply_indicator(&result, .Bar_Indicator, .Bar, result.value.mark_ink)
	case .Hardware:
		style_apply_hardware_metrics(&result)
		style_apply_relief_surface(&result, relief)
		style_apply_type(&result, .Monospace_Type, .Monospace, 15, 700)
		style_apply_indicator(&result, .Dot_Indicator, .Dot, result.value.mark_ink)
	case .Paper:
		style_apply_paper_metrics(&result)
		style_apply_paper_surface(&result)
		style_apply_type(&result, .Paper_Type, .UI, 18, 500)
		style_apply_indicator(&result, .Underline_Indicator, .Underline, result.value.mark_ink)
	}
	style_apply_context(&result, ctx_scope)
	if override.set_height {
		result.value.height = override.height
		style_mark_origin(&result, .Height, {kind=.Instance})
	}
	return result
}

style_explain :: proc(result: Style_Result, field: Style_Field) -> Style_Origin {
	if field == .Count { return {} }
	origin := result.origins[int(field)]
	origin.recipe = result.recipe
	if origin.kind == .Context { origin.context_scope = result.context_scope }
	return origin
}

draw_item :: proc(
	ctx: ^ui.UI, owner: alicorn.Node_ID, label: string, selected, disabled, focused: bool,
	width, height: f32, style: Item_Style,
) {
	fill := style.selected_fill if selected else style.fill
	ink := style.disabled_ink if disabled else style.ink
	stroke := style.stroke
	if focused { stroke = {color=style.focus_ink, width=2} }
	face := alicorn.surface_begin(
		ctx, alicorn.surface_core_color_role(.Surface), key=ui.key_u64(1),
		style=ui.layout_style(.Column, width=max(width-2*style.inset, 0),
			height=max(height-2*style.inset, 0), padding=4, gap=style.gap,
			align=.Center, justify=.Center, clip=true),
		shape={kind=.Rounded_Rectangle, corner_radius=style.radius},
		fill=fill, stroke=stroke, material=style.material, physical_height=style.optical_height,
		label="selection-style-face",
	)
	if face == 0 { return }
	defer ui.surface_end(ctx)
	_ = alicorn.visual_part_attach(ctx, face, owner, alicorn.visual_part_core(.Surface))

	text := ui.text(ctx, label, key=ui.key_u64(2), color=ink, font=style.font,
		text_style=style.text, decorative=true)
	if text != 0 {
		// The core Label part inherits ink from the Button recipe. This part
		// keeps the treatment's explicit ink while the owner keeps the name.
		_ = alicorn.visual_part_attach(ctx, text, owner,
			alicorn.visual_part_extension_id("alikit.selection_styles", "label"))
	}

	// Keep the marker's space stable when selection moves.
	marker_width, marker_height, radius: f32
	switch style.marker {
	case .Bar:       marker_width, marker_height, radius = 14, 3, 1
	case .Dot:       marker_width, marker_height, radius = 8, 8, 4
	case .Underline: marker_width, marker_height, radius = 42, 2, 0
	}
	if ui.row(ctx, key=ui.key_u64(3), width=marker_width, height=marker_height, align=.Center) {
		if selected {
			marker := ui.box(ctx, key=ui.key_u64(4), width=marker_width, height=marker_height,
				radius=radius, fill=style.mark_ink)
			if marker != 0 {
				_ = alicorn.visual_part_attach(ctx, marker, owner,
					alicorn.visual_part_extension_id("alikit.selection_styles", "selection-marker"))
			}
		}
	}
}

draw_segment :: proc(data: rawptr, ctx: ^ui.UI, visual: segmented.Item_Visual) {
	draw_item(ctx, visual.owner, visual.item.label, visual.selected, visual.item.disabled,
		visual.group_focused && visual.active, visual.width, visual.height, (^Item_Style)(data)^)
}

RADIO_OPTIONS := [3]radio.Option{
	{value=1, label="Draft"}, {value=2, label="Review"}, {value=3, label="Published", disabled=true},
}
SEGMENTS := [3]segmented.Item{
	{value=1, label="Overview"}, {value=2, label="Activity"}, {value=3, label="Archive", disabled=true},
}

App :: struct {
	treatment:              Treatment,
	relief:                 alicorn.Material_ID,
	radio_style, segment_style: Style_Result,
	style_resolutions:      u64,
	benchmark_nodes:        int,
	radio_state:            radio.State,
	segment_state:          segmented.State,
	radio_value, view_value: u64,
}

refresh_styles :: proc(app: ^App) {
	app.radio_style = style_resolve(app.treatment, .Dialog, app.relief)
	app.segment_style = style_resolve(app.treatment, .Toolbar, app.relief)
	app.style_resolutions += 2
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	app.relief = alicorn.style_material_register(rt, {
		kind=.Analytic_Relief, bevel_width=2, bevel_strength=0.18,
	})
	refresh_styles(app)
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if app.benchmark_nodes > 0 {
		style := app.segment_style.value
		if ui.column(ctx, width=-1, height=-1, gap=2, clip=true) {
			for index in 0..<app.benchmark_nodes {
				_ = ui.button(ctx, "Apply", key=ui.key_u64(u64(index)+0x10000),
					width=180, height=style.height, text_style=style.text)
			}
		}
		return
	}
	if ui.column(ctx, padding=24, gap=12) {
		ui.text(ctx, "Selection styles", size=24)
		if ui.row(ctx, gap=8) {
			names := [Treatment]string{.Minimal="Minimal", .Hardware="Hardware", .Paper="Paper"}
			for name, index in names {
				treatment := Treatment(index)
				if ui.button(ctx, name, key=ui.key_u64(u64(index)+1),
					state={selected=treatment == app.treatment}) {
					app.treatment = treatment
					refresh_styles(app)
					alicorn.invalidate_root(ctx.runtime, "selection appearance changed")
				}
			}
		}
		radio_style := app.radio_style.value
		ui.text(ctx, "Radio Group", size=18)
		group, visible := radio.group_begin(ctx, &app.radio_state, RADIO_OPTIONS[:], app.radio_value,
			label="Publication status", key=ui.key_u64(11), instance_id=11,
			group_options={orientation=.Horizontal, item_gap=radio_style.gap})
		if visible {
			for option in RADIO_OPTIONS {
				item, shown := radio.item_begin(ctx, &group, option,
					item_style=ui.layout_style(.Row, width=132, height=radio_style.height,
						align=.Center, justify=.Center))
				if !shown { continue }
				draw_item(ctx, item.owner, option.label, item.checked, item.disabled,
					item.focus_visible, 132, radio_style.height, radio_style)
				radio.item_end(ctx, item)
			}
			if event := radio.group_end(ctx, &group); event.kind == .Selection_Proposed {
				app.radio_value = event.value
			}
		}
		ui.text(ctx, "Segmented Control", size=18)
		segment_style := app.segment_style.value
		if event := segmented.control(ctx, &app.segment_state, SEGMENTS[:], app.view_value,
			options={accessible_label="Workspace view", width=412, height=segment_style.height+8,
				padding=4, corner_radius=segment_style.radius+2},
			key=ui.key_u64(22), instance_id=22,
			presentation={data=&app.segment_style.value, draw_item=draw_segment, omit_moving_indicator=true});
			event.kind == .Selection_Proposed {
			app.view_value = event.value
		}
	}
}

style_composition_benchmark_sort :: proc(samples: ^[25]i64) {
	for index in 0..<len(samples) {
		for other in index+1..<len(samples) {
			if samples[other] < samples[index] {
				samples[index], samples[other] = samples[other], samples[index]
			}
		}
	}
}

style_composition_benchmark_sort_u64 :: proc(samples: []u64) {
	for index in 0..<len(samples) {
		for other in index+1..<len(samples) {
			if samples[other] < samples[index] {
				samples[index], samples[other] = samples[other], samples[index]
			}
		}
	}
}

initialize_benchmark_state :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	initialize((^App)(data), rt)
}

benchmark_idle_turn_is_empty :: proc(work: testui.Turn_Work) -> bool {
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
	for timing in work.stage_timings_ns {
		if timing != 0 { return false }
	}
	return true
}

style_retained_node_benchmark :: proc() {
	node_counts := [3]int{100, 1000, 3000}
	fmt.println("AliKit retained Button composition; fresh TestUI runtime; stage counters and timings; 7 runs per size")
	for node_count in node_counts {
		description_ns: [7]u64
		layout_visits: [7]u64
		shape_requests: [7]u64
		paint_visits: [7]u64
		idle_work_ok := true
		for sample in 0..<len(description_ns) {
			app := App{radio_value=1, view_value=1, benchmark_nodes=node_count}
			handle, status := testui.open(&app, render, width=1200, height=900,
				initialize=initialize_benchmark_state)
			if status != .Ok {
				fmt.println("STYLE_RETAINED_BENCH_FAILURE nodes", node_count, "status", status)
				idle_work_ok = false
				testui.close(&handle)
				break
			}
			description_ns[sample] = handle.last_turn.work.stage_timings_ns[.Description]
			layout_visits[sample] = handle.last_turn.work.layout_nodes_visited
			shape_requests[sample] = handle.last_turn.work.text_shape_requests
			paint_visits[sample] = handle.last_turn.work.paint_nodes_visited
			if testui.advance_time(&handle, 16_000_000) != .Ok ||
				!benchmark_idle_turn_is_empty(handle.last_turn.work) {
				idle_work_ok = false
			}
			testui.close(&handle)
		}
		style_composition_benchmark_sort_u64(description_ns[:])
		style_composition_benchmark_sort_u64(layout_visits[:])
		style_composition_benchmark_sort_u64(shape_requests[:])
		style_composition_benchmark_sort_u64(paint_visits[:])
		fmt.println("STYLE_RETAINED_BENCH nodes", node_count,
			"p50_description_ns", description_ns[3], "max_description_ns", description_ns[6],
			"p50_layout_visits", layout_visits[3], "p50_shape_requests", shape_requests[3],
			"p50_paint_visits", paint_visits[3], "idle_zero_work", idle_work_ok)
	}
}

style_composition_benchmark :: proc() {
	repeats := 200
	fmt.println("AliKit typed Odin recipe composition; style resolution only, not frame time; 25 samples x 200 batches")
	node_counts := [3]int{100, 1000, 3000}
	for node_count in node_counts {
		samples: [25]i64
		checksum: f64 = 0
		for sample in 0..<len(samples) {
			value: f64 = 0
			started := time.now()
			for _ in 0..<repeats {
				for node in 0..<node_count {
					result := style_resolve(Treatment(node%3), Style_Context(node%2), 0)
					value += f64(result.value.height + result.value.text.font_size)
				}
			}
			samples[sample] = time.duration_nanoseconds(time.since(started))
			checksum += value
		}
		style_composition_benchmark_sort(&samples)
		fmt.println("STYLE_COMPOSITION_BENCH nodes", node_count, "batches", repeats,
			"p50_ns", samples[12], "p95_ns", samples[23],
			"p50_ns_per_style", f64(samples[12])/f64(node_count*repeats),
			"p95_ns_per_style", f64(samples[23])/f64(node_count*repeats), "checksum", checksum)
	}
	style_retained_node_benchmark()
}

main :: proc() {
	app := App{radio_value=1, view_value=1}
	smoke := false
	benchmark := false
	for arg in os.args {
		switch arg {
		case "--smoke":    smoke = true
		case "--hardware": app.treatment = .Hardware
		case "--paper":    app.treatment = .Paper
		case "--bench":    benchmark = true
		}
	}
	if benchmark { style_composition_benchmark(); return }
	ui.run(&app, render, title="AliKit Selection Styles", width=500, height=430,
		on_initialize=initialize, smoke=smoke)
}
