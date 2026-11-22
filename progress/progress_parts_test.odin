package progress

// Parts-level public-surface tests for Progress. The ring fixture composes
// begin/label/value_text/end with custom Arc surfaces and centered text; the
// linear fixture uses track_begin/indicator. Both preserve the same Progress
// semantic identity and numeric range.

import "core:math"
import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

Ring_App :: struct {
	state:    State,
	value:    f64,
	bare:     bool,
}

ring_render :: proc(app: ^Ring_App, ctx: ^ui.UI) {
	part, visible := begin(
		ctx,
		&app.state,
		app.value,
		0,
		100,
		Options{accessible_label="Storage used", width=200, label_size=13, value_size=13},
		key=alicorn.key_string("ring-progress"),
		instance_id=9501,
	)
	if !visible { return }
	// Custom heading: these are the same public label/value parts in a
	// different layout.
	if !app.bare {
		if ui.row(ctx, key=alicorn.key_string("ring-heading"), width=-1,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, align=.Center, gap=8) {
			label(ctx, &part)
			value_text(ctx, &part)
		}
	}
	if ui.row(ctx, key=ui.key_u64(10), width=132, height=132,
		align=.Center, justify=.Center) {
		// Custom track ring: an outlined circle behind a public geometry-derived
		// progress arc. Neither surface is a semantic entity.
		if track := alicorn.surface_begin(
			ctx,
			alicorn.surface_core_color_role(.Subtle_Surface),
			key=ui.key_u64(11),
			style=ui.layout_style(.Row, width=128, height=128),
			shape=alicorn.Surface_Shape{kind=.Circle},
			fill=alicorn.Color{0, 0, 0, 0},
			stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Border), width=10},
			label="ring-track",
		); track != 0 {
			alicorn.surface_end(ctx)
			_ = alicorn.position_child(ctx, track, alicorn.positioned(0, 0))
		}
		if part.normalized > 0 {
			arc := alicorn.surface_begin(
				ctx,
				alicorn.surface_core_color_role(.Accent),
				key=ui.key_u64(12),
				style=ui.layout_style(.Row, width=128, height=128),
				shape=ring_shape(part.normalized),
				fill=alicorn.Color{0, 0, 0, 0},
				stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Accent), width=10},
				label="ring-arc",
			)
			if arc != 0 {
				alicorn.surface_end(ctx)
				_ = alicorn.position_child(ctx, arc, alicorn.positioned(0, 0))
			}
		}
		// Centered text is an ordinary author-owned flow subtree. The ring
		// surfaces are positioned and contribute no flow size.
		if ui.column(ctx, key=ui.key_u64(13), width=128, height=128,
			align=.Center, justify=.Center, gap=2) {
			_ = ui.text(ctx, format_value(part.normalized), key=ui.key_u64(14), size=24)
			if !app.bare {
				_ = ui.text(ctx, "of 100 GB", key=ui.key_u64(15), size=11,
					color=alicorn.style_color(ctx, .Muted_Text))
			}
		}
	}
	end(ctx, &part)
}

ring_open :: proc(app: ^Ring_App, t: ^testing.T) -> (testui.Test_Handle(Ring_App), bool) {
	app.value = 75
	handle, status := testui.open(app, ring_render, width=440, height=320)
	if !testing.expectf(t, status == .Ok, "the ring fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(test)
test_progress_parts_geometry_helpers :: proc(t: ^testing.T) {
	testing.expect(t, math.abs(f64(ring_sweep(0.25)-f32(0.25*2*math.PI))) < 1e-6,
		"ring_sweep should map a quarter fraction to a quarter turn")
	testing.expect_value(t, ring_sweep(-1), f32(0))
	testing.expect_value(t, ring_sweep(2), f32(2*math.PI))
	testing.expect_value(t, format_value(0.424), "42%")
	testing.expect_value(t, format_value(-1), "0%")
	testing.expect_value(t, format_value(2), "100%")

	fill, offset := linear_geometry(200, 0.25)
	testing.expect_value(t, fill, f32(50))
	testing.expect_value(t, offset, f32(0))
	fill, offset = linear_geometry(200, 0, indeterminate=true, phase=0.5, segment_width=0.30)
	testing.expect(t, math.abs(f64(fill-60)) < 0.001, "the indeterminate segment should be 30% of the track")
	testing.expect_value(t, offset, f32(70))
	fill, offset = linear_geometry(0, 0.5)
	testing.expect(t, fill == 0 && offset == 0, "a non-positive width should report no geometry")

	shape := ring_shape(0.5)
	testing.expect_value(t, shape.kind, alicorn.Surface_Shape_Kind.Arc)
	testing.expect(t, math.abs(f64(shape.arc.sweep_angle-f32(math.PI))) < 1e-6,
		"a half fraction should sweep a half turn")
	testing.expect(t, math.abs(f64(shape.arc.start_angle-f32(-math.PI/2))) < 1e-6,
		"the ring should start at twelve o'clock by default")
	segment := ring_segment_shape(0.5, 0.25)
	testing.expect(t, math.abs(f64(segment.arc.sweep_angle-f32(0.5*math.PI))) < 1e-6,
		"an indeterminate ring segment should use the normalized segment width")
}

@(test)
test_progress_parts_ring_preserves_semantics_identity_and_value :: proc(t: ^testing.T) {
	app := Ring_App{}
	handle, ok := ring_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	node, found := alicorn.semantic_node_lookup(handle.runtime, progress_semantic_id(9501))
	if !testing.expect(t, found, "the custom ring should publish the stable progress identity") { return }
	testing.expect_value(t, node.role, alicorn.Semantic_Role.Progress)
	testing.expect_value(t, node.label, "Storage used")
	testing.expect_value(t, node.value, "75%")
	testing.expect(t, node.has_numeric_value && node.numeric_value == 75 &&
		node.numeric_minimum == 0 && node.numeric_maximum == 100,
		"the custom ring should publish the same numeric range")
	testing.expect(t, node.has_bounds && node.bounds.h > 0,
		"the custom ring root should have realized geometry")

	// The default labels were omitted in the bare variant, but semantics are
	// unchanged.
	app.bare = true
	alicorn.invalidate_root(handle.runtime, "ring fixture switched to bare parts")
	_ = testui.describe_once(&handle)
	node, found = alicorn.semantic_node_lookup(handle.runtime, progress_semantic_id(9501))
	testing.expect(t, found && node.value == "75%" && node.has_numeric_value,
		"omitting visual label/value parts must not erase accessible value semantics")
	testing.expect(t, !alicorn.visual_part_owner_has_role(handle.runtime, node.visual_node, .Label),
		"the bare ring should not publish a Label visual part")
	testing.expect(t, !alicorn.visual_part_owner_has_role(handle.runtime, node.visual_node, .Content),
		"the bare ring should not publish a value Content visual part")

	if testing.expect(t, testui.step(&handle, testui.Input{kind=.Time_Advance, delta_ns=16_000_000}) == .Ok,
		"the custom ring should settle after an idle time advance") {
		turn := testui.last_turn(&handle)
		testing.expect(t, turn.stabilized && !turn.layout_pending,
			"the custom ring should report a stabilized, layout-clean idle turn")
	}
}

@(test)
test_progress_parts_track_indicator_and_custom_width :: proc(t: ^testing.T) {
	app := Test_App{options=Options{width=300}}
	handle, ok := fixture_open(&app, t, app.options)
	if !ok { return }
	defer testui.close(&handle)
	node, found := alicorn.semantic_node_lookup(handle.runtime, progress_semantic_id(8101))
	if !testing.expect(t, found, "the linear fixture should publish progress identity") { return }
	testing.expect(t, alicorn.visual_part_owner_has_role(handle.runtime, node.visual_node, .Indicator),
		"the convenience linear wrapper should publish the Indicator part")
	testing.expect_value(t, app.state.last_fill_width, f32(75))
	testing.expect_value(t, app.state.last_offset_width, f32(0))
}

Track_App :: struct {
	state: State,
	value: f64,
}

track_render :: proc(app: ^Track_App, ctx: ^ui.UI) {
	part, visible := begin(
		ctx,
		&app.state,
		app.value,
		0,
		100,
		Options{accessible_label="Custom track", width=320},
		key=alicorn.key_string("custom-track"),
		instance_id=9502,
	)
	if !visible { return }
	// The author owns the track size; the component supplies the fraction math
	// from the same value and range.
	track, track_visible := track_begin(ctx, &part, width=200, height=20, padding=0)
	if track_visible {
		indicator(ctx, &track)
		track_end(ctx)
	}
	end(ctx, &part)
}

@(test)
test_progress_parts_author_owned_track_geometry :: proc(t: ^testing.T) {
	app := Track_App{value=75}
	handle, status := testui.open(&app, track_render, width=420, height=180)
	if !testing.expectf(t, status == .Ok, "the custom track fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return
	}
	defer testui.close(&handle)
	testing.expect_value(t, app.state.last_fill_width, f32(150))
	testing.expect_value(t, app.state.last_offset_width, f32(0))
	node, found := alicorn.semantic_node_lookup(handle.runtime, progress_semantic_id(9502))
	testing.expect(t, found && node.has_numeric_value && node.numeric_value == 75,
		"the author-owned track should keep the public numeric semantics")
}

@(test)
test_progress_parts_indeterminate_ring_has_no_numeric_value :: proc(t: ^testing.T) {
	app := Test_App{options=Options{indeterminate=true, indeterminate_phase=0.4, width=240}}
	handle, ok := fixture_open(&app, t, app.options)
	if !ok { return }
	defer testui.close(&handle)
	node, found := alicorn.semantic_node_lookup(handle.runtime, progress_semantic_id(8101))
	if !testing.expect(t, found, "indeterminate progress should publish a node") { return }
	testing.expect(t, !node.has_numeric_value,
		"an indeterminate custom appearance must not publish a fabricated numeric value")
	_, offset := linear_geometry(300, 0, indeterminate=true, phase=0.5, segment_width=0.30)
	testing.expect(t, offset > 0, "the indeterminate helper should move the segment")
}
