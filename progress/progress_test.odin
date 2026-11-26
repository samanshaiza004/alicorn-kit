package progress

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

Test_App :: struct {
	state: State,
	value: f64,
	options: Options,
}

fixture_render :: proc(app: ^Test_App, ctx: ^ui.UI) {
	if ui.button(ctx, "Advance", key=alicorn.key_string("progress-advance"), width=110, height=30) {
		app.value = min(app.value+25, 100)
	}
	options := app.options
	options.accessible_label = "Upload progress"
	progress(ctx, &app.state, app.value, 0, 100, options, key=alicorn.key_string("progress-fixture"), instance_id=8101)
}

fixture_open :: proc(app: ^Test_App, t: ^testing.T, options: Options = {}, scale: f32 = 1) -> (testui.Test_Handle(Test_App), bool) {
	app.value = 25
	app.options = options
	handle, status := testui.open(app, fixture_render, width=420, height=220, scale=scale)
	if !testing.expectf(t, status == .Ok, "the progress fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
lookup_progress :: proc(handle: ^testui.Test_Handle(Test_App)) -> (alicorn.Semantic_Node, bool) {
	return alicorn.semantic_node_lookup(handle.runtime, progress_semantic_id(8101))
}

@(test)
test_progress_visible_label_and_value_at_fractional_scales :: proc(t: ^testing.T) {
	scales := [4]f32{1, 1.25, 1.5, 2}
	for scale in scales {
		app := Test_App{}
		handle, ok := fixture_open(&app, t, scale=scale)
		if !ok { continue }

		owner := testui.find(&handle, testui.Query{
			role=.Progress, name="Upload progress", match_role=true, match_name=true,
		})
		if testing.expectf(t, owner.match == .Unique,
			"the progress owner should remain exposed at %.2f", scale) {
			visible_label := testui.expect_visible_text(&handle, &owner.element, "Upload progress")
			visible_value := testui.expect_visible_text(&handle, &owner.element, "25%")
			testing.expectf(t, visible_label.ok && visible_value.ok,
				"progress label and value should remain drawable at %.2f: %s %s",
				scale, testui.visible_text_diagnostic(visible_label), testui.visible_text_diagnostic(visible_value))
		}
		testui.destroy_find_result(&owner)
		testui.close(&handle)
	}
}

@(test)
test_progress_fraction_and_theme_contract :: proc(t: ^testing.T) {
	testing.expect_value(t, fraction(50, 0, 100), 0.5)
	testing.expect_value(t, fraction(-10, 0, 100), 0.0)
	testing.expect_value(t, fraction(120, 0, 100), 1.0)
	testing.expect_value(t, fraction(10, 10, 10), 0.0)
	testing.expect_value(t, progress_semantic_id(0).namespace, u64(0))
	testing.expect(t, progress_semantic_id(1) != progress_semantic_id(2),
		"two progress instances should have distinct identity")

	recipe := Recipe{
		fill_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.progress", "fill"),
	}
	contract := theme_contract_default(recipe)
	testing.expect_value(t, contract.required_count, 1)
	testing.expect_value(t, contract.optional_count, 1)
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 200, 100})
	defer alicorn.destroy_runtime(&rt)
	report := theme_contract_check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	testing.expect(t, !theme_contract_satisfied(report), "a configured fill role must be validated")
	names, count := theme_contract_missing_required(contract, report)
	testing.expect(t, count == 1 && names[0] == "alikit.progress.fill_surface")
}

@(test)
test_progress_determinate_publishes_value_and_range :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	node, found := lookup_progress(&handle)
	if !testing.expect(t, found, "the progress node should publish stable identity") { return }
	testing.expect_value(t, node.role, alicorn.Semantic_Role.Progress)
	testing.expect_value(t, node.label, "Upload progress")
	testing.expect_value(t, node.value, "25%")
	testing.expect(t, node.has_numeric_value && node.numeric_value == 25 &&
		node.numeric_minimum == 0 && node.numeric_maximum == 100,
		"determinate progress should publish its numeric range")

	// A value change is local: the fill width and textual value change, while
	// the surrounding description remains bounded.
	advance := testui.find(&handle, testui.Query{role=.Button, name="Advance", match_role=true, match_name=true})
	if !testing.expect(t, advance.match == .Unique, "the Advance button should be unique") {
		testui.destroy_find_result(&advance)
		return
	}
	status := testui.click(&handle, &advance.element)
	testui.destroy_find_result(&advance)
	if !testing.expect(t, status == .Ok, "the value change should be driven by ordinary input") { return }
	testing.expect_value(t, app.value, 50)
	node, found = lookup_progress(&handle)
	testing.expect(t, found && node.value == "50%" && node.numeric_value == 50,
		"the re-described value should update value text and numeric semantics")
	turn := testui.last_turn(&handle)
	testing.expect(t, turn.work.layout_nodes_visited > 0 && turn.work.layout_nodes_visited < 80,
		"a progress value change should stay within a bounded layout frontier")
}

@(test)
test_progress_indeterminate_has_no_numeric_value_and_moves_segment :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t, Options{indeterminate=true, indeterminate_phase=0, width=300})
	if !ok { return }
	defer testui.close(&handle)

	node, found := lookup_progress(&handle)
	if !testing.expect(t, found, "indeterminate progress should still publish a node") { return }
	testing.expect_value(t, node.role, alicorn.Semantic_Role.Progress)
	testing.expect_value(t, node.value, "Loading")
	testing.expect(t, !node.has_numeric_value,
		"indeterminate progress must not publish a numeric value")
	first_offset := app.state.last_offset_width
	first_width := app.state.last_fill_width
	testing.expect(t, first_width > 0, "the indeterminate segment should have a width")

	app.options.indeterminate_phase = 0.5
	alicorn.invalidate_root(handle.runtime, "fixture advanced indeterminate progress phase")
	_ = testui.describe_once(&handle)
	testing.expect_value(t, app.state.last_phase, 0.5)
	testing.expect(t, app.state.last_offset_width > first_offset,
		"the caller-driven phase should move the indeterminate segment")
	testing.expect_value(t, app.state.last_fill_width, first_width)
}

@(test)
test_progress_reduced_motion_is_reported_and_pulse_still_describes :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t, Options{indeterminate=true, pulse=true, width=240})
	if !ok { return }
	defer testui.close(&handle)

	observation := alicorn.Accessibility_Appearance_Observation{
		preferences=alicorn.Accessibility_Appearance_Preferences{reduce_motion=true},
		known={.Reduce_Motion},
	}
	testing.expect(t, alicorn.style_root_accessibility_observation_set(handle.runtime, observation),
		"the fixture should enable reduced motion")
	alicorn.invalidate_root(handle.runtime, "fixture enabled reduced motion")
	_ = testui.describe_once(&handle)
	testing.expect(t, app.state.last_reduced_motion,
		"the component should observe reduced motion and snap the pulse")
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Time_Advance, delta_ns=16_000_000}) == .Ok,
		"a snap pulse should settle without invalidating the description")
}
