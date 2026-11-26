package radio_group

// Public-surface tests: this package drives the component exactly as an
// application would through Alicorn's headless test harness. It never reads
// private runtime storage.

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

FIXTURE_VALUES :: [4]u64{10, 20, 30, 40}

fixture_options :: proc() -> [4]Option {
	return {
		{value=10, label="Small", description="Compact spacing"},
		{value=20, label="Medium", description="Unavailable in this build", disabled=true},
		{value=30, label="Large", description="Comfortable spacing"},
		{value=40, label="Huge", description="Presentation spacing"},
	}
}

Test_App :: struct {
	group:      State,
	options:    [4]Option,
	selected:   u64,
	mode:       Selection_Mode,
	orientation: Orientation,
	activations: int,
	last_value: u64,
	events:     int,
	render_orientation: Orientation,
}

fixture_render :: proc(app: ^Test_App, ctx: ^ui.UI) {
	_ = ui.text(ctx, "Radio group fixture", size=18)
	app.render_orientation = app.orientation
	event := radio_group(
		ctx,
		&app.group,
		app.options[:],
		app.selected,
		Options{accessible_label="Text size", orientation=app.orientation, selection_mode=app.mode},
		key=alicorn.key_string("radio-fixture"),
		instance_id=7001,
	)
	if event.kind == .Selection_Proposed {
		app.selected = event.value
		app.last_value = event.value
		app.events += 1
		app.activations += 1
	}
}

fixture_open :: proc(app: ^Test_App, t: ^testing.T, scale: f32 = 1) -> (testui.Test_Handle(Test_App), bool) {
	app.options = fixture_options()
	app.selected = 10
	app.mode = .Follow_Focus
	app.orientation = .Vertical
	_ = request_focus(&app.group)
	handle, status := testui.open(app, fixture_render, width=520, height=320, scale=scale)
	if !testing.expectf(t, status == .Ok, "the radio fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
find_group :: proc(handle: ^testui.Test_Handle(Test_App)) -> testui.Find_Result {
	return testui.find(handle, testui.Query{
		role=.Radio_Group, name="Text size", match_role=true, match_name=true,
	})
}

@(private)
find_radio :: proc(handle: ^testui.Test_Handle(Test_App), name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{
		role=.Radio_Button, name=name, match_role=true, match_name=true,
	})
}

@(test)
test_radio_group_labels_remain_visible_and_contained_at_fractional_scales :: proc(t: ^testing.T) {
	scales := [4]f32{1, 1.25, 1.5, 2}
	for scale in scales {
		app := Test_App{}
		handle, ok := fixture_open(&app, t, scale)
		if !ok { continue }

		group := find_group(&handle)
		small := find_radio(&handle, "Small")
		if testing.expectf(t, group.match == .Unique && small.match == .Unique,
			"radio group and first option should be available at %.2f", scale) {
			visible := testui.expect_visible_text(&handle, &small.element, "Small")
			inside := testui.expect_inside(&handle, &small.element, &group.element)
			testing.expectf(t, visible.ok && inside.ok,
				"radio label should remain visible and contained at %.2f: %s %s",
				scale, testui.visible_text_diagnostic(visible), testui.layout_check_diagnostic(inside))
		}
		testui.destroy_find_result(&group)
		testui.destroy_find_result(&small)
		testui.close(&handle)
	}
}

@(test)
test_radio_group_identity_and_theme_contract :: proc(t: ^testing.T) {
	testing.expect(t, option_semantic_id(0, 1).namespace == 0, "instance zero must not publish identity")
	testing.expect(t, option_semantic_id(1, 0).namespace == 0, "option value zero must not publish identity")
	testing.expect(t, option_semantic_id(1, 10) != option_semantic_id(2, 10),
		"the same value in two groups must have distinct identity")
	testing.expect(t, group_semantic_id(1) != option_semantic_id(1, 10),
		"the group and an option must not collide")

	recipe := Recipe{
		selected_surface_role=alicorn.style_extension_color_role_id("alikit.radio_group", "selected"),
	}
	contract := theme_contract_default(recipe)
	testing.expect_value(t, contract.required_count, 1)
	testing.expect_value(t, contract.optional_count, 3)
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 240, 160})
	defer alicorn.destroy_runtime(&rt)
	report := theme_contract_check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	testing.expect(t, !theme_contract_satisfied(report), "a configured role must be validated")
	names, count := theme_contract_missing_required(contract, report)
	testing.expect(t, count == 1 && names[0] == "alikit.radio_group.selected_surface")
}

@(test)
test_radio_group_semantics_and_roving_activation_parity :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	group := find_group(&handle)
	defer testui.destroy_find_result(&group)
	if !testing.expect(t, group.match == .Unique, "the radio group should be unique") { return }
	testing.expect(t, group.element.is_collection && group.element.logical_count == 4,
		"the group should publish one four-option collection")
	testing.expect_value(t, group.element.collection_selected_id, option_semantic_id(7001, 10))
	testing.expect_value(t, group.element.collection_current_id, option_semantic_id(7001, 10))

	small := find_radio(&handle, "Small")
	medium := find_radio(&handle, "Medium")
	large := find_radio(&handle, "Large")
	defer testui.destroy_find_result(&small)
	defer testui.destroy_find_result(&medium)
	defer testui.destroy_find_result(&large)
	if testing.expect(t, small.match == .Unique, "the selected option should be realized") {
		visible_label := testui.expect_visible_text(&handle, &small.element, "Small")
		testing.expect(t, visible_label.ok, testui.visible_text_diagnostic(visible_label))
	}
	testing.expect(t, small.element.collection_selected && small.element.collection_current,
		"the controlled selection should be Checked/Selected and Current")
	testing.expect(t, small.element.parent_semantic_id == group.element.semantic_id,
		"the radio should be parented to the group")
	testing.expect(t, medium.element.parent_semantic_id == group.element.semantic_id,
		"disabled radios should still publish their position")
	testing.expect(t, alicorn.semantic_states_has(medium.element.states, .Disabled),
		"a disabled option should publish Disabled")
	testing.expect(t, !alicorn.semantic_actions_has(medium.element.actions, .Press),
		"a disabled radio must not advertise Press")

	// Down skips the disabled Medium and proposes Large. Follow_Focus means the
	// controlled selection moves with the roving focus.
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok, "Down should be scoped")
	testing.expect_value(t, app.selected, u64(30))
	testing.expect_value(t, app.last_value, u64(30))
	testui.destroy_find_result(&large)
	large = find_radio(&handle, "Large")
	testing.expect(t, large.match == .Unique && large.element.collection_selected && large.element.collection_current,
		"the accepted proposal should be Checked/Selected and Current")

	// Down again reaches Huge, then wraps to Small while skipping Medium.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, app.selected, u64(40))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, app.selected, u64(10))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Up})
	testing.expect_value(t, app.selected, u64(40))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Home})
	testing.expect_value(t, app.selected, u64(10))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.End})
	testing.expect_value(t, app.selected, u64(40))

	// Return proposes the active identity. Pointer and semantic Press then
	// propose the same controlled value.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Return})
	testing.expect_value(t, app.last_value, u64(40))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Left})
	testing.expect_value(t, app.selected, u64(30))
	testui.destroy_find_result(&large)
	large = find_radio(&handle, "Large")
	if !testing.expect(t, large.match == .Unique, "Large should remain realized") { return }
	if !testing.expect(t, testui.click(&handle, &large.element) == .Ok, "the pointer should activate Large") { return }
	testing.expect_value(t, app.last_value, u64(30))

	testui.destroy_find_result(&small)
	small = find_radio(&handle, "Small")
	if !testing.expect(t, small.match == .Unique, "Small should remain realized") { return }
	status := testui.step(&handle, testui.Input{
		kind=.Semantic_Action,
		semantic_id=small.element.semantic_id,
		semantic_action=.Press,
	})
	testing.expect(t, status == .Ok, "a semantic Press on a radio should be accepted")
	testing.expect_value(t, app.last_value, u64(10))
	testing.expect(t, app.events >= 8, "keyboard, pointer, and semantic activation should share one proposal path")

	// Disabled Medium rejects both pointer and semantic activation.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Home})
	testui.destroy_find_result(&medium)
	medium = find_radio(&handle, "Medium")
	if testing.expect(t, medium.match == .Unique, "Medium should remain realized") {
		_ = testui.click(&handle, &medium.element)
		testing.expect_value(t, app.selected, u64(10))
		_ = testui.step(&handle, testui.Input{
			kind=.Semantic_Action,
			semantic_id=medium.element.semantic_id,
			semantic_action=.Press,
		})
		testing.expect_value(t, app.selected, u64(10))
	}
}

@(test)
test_radio_group_activate_mode_separates_focus_and_selection :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	app.mode = .Activate
	alicorn.invalidate_root(handle.runtime, "fixture switched radio selection mode")
	_ = testui.describe_once(&handle)

	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok, "Down should move focus")
	testing.expect_value(t, app.selected, u64(10))
	group := find_group(&handle)
	defer testui.destroy_find_result(&group)
	testing.expect_value(t, group.element.collection_selected_id, option_semantic_id(7001, 10))
	testing.expect_value(t, group.element.collection_current_id, option_semantic_id(7001, 30))
	large := find_radio(&handle, "Large")
	small := find_radio(&handle, "Small")
	defer testui.destroy_find_result(&large)
	defer testui.destroy_find_result(&small)
	testing.expect(t, large.element.collection_current && !large.element.collection_selected,
		"the roving focus should publish Current without Selected")
	testing.expect(t, small.element.collection_selected && !small.element.collection_current,
		"the controlled selection should stay Checked while focus moved")

	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Toggle})
	testing.expect_value(t, app.selected, u64(30))
}

@(test)
test_radio_group_orientation_switch_keeps_identity :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	small := find_radio(&handle, "Small")
	large := find_radio(&handle, "Large")
	if !testing.expect(t, small.match == .Unique && large.match == .Unique, "both radios should be realized") { return }
	vertical_id := small.element.semantic_id
	vertical_bounds := small.element.bounds
	vertical_large_y := large.element.bounds.y
	testing.expect(t, vertical_large_y > vertical_bounds.y, "the vertical appearance should stack options")
	testing.expect_value(t, app.render_orientation, Orientation.Vertical)
	testing.expect_value(t, app.group.last_orientation, Orientation.Vertical)
	vertical_group := find_group(&handle)
	vertical_group_bounds := vertical_group.element.bounds
	testui.destroy_find_result(&small)
	testui.destroy_find_result(&large)
	testui.destroy_find_result(&vertical_group)

	app.orientation = .Horizontal
	alicorn.invalidate_root(handle.runtime, "fixture switched radio orientation")
	_ = testui.describe_once(&handle)
	small = find_radio(&handle, "Small")
	large = find_radio(&handle, "Large")
	if !testing.expect(t, small.match == .Unique && large.match == .Unique, "both radios should remain realized") { return }
	testing.expect_value(t, small.element.semantic_id, vertical_id)
	testing.expect(t, large.element.bounds.x > small.element.bounds.x,
		"the horizontal appearance should place options side by side")
	horizontal_group := find_group(&handle)
	testing.expectf(t, horizontal_group.element.bounds.h < vertical_group_bounds.h,
		"the horizontal appearance should be shorter than the vertical group: vertical=%v horizontal=%v",
		vertical_group_bounds, horizontal_group.element.bounds)
	testui.destroy_find_result(&small)
	testui.destroy_find_result(&large)
	testui.destroy_find_result(&horizontal_group)

	// Reorder the caller data. Active and selected identities follow their
	// stable values rather than row positions.
	app.options = [4]Option{
		{value=40, label="Huge"},
		{value=20, label="Medium", disabled=true},
		{value=10, label="Small"},
		{value=30, label="Large"},
	}
	alicorn.invalidate_root(handle.runtime, "fixture reordered radios")
	_ = testui.describe_once(&handle)
	small = find_radio(&handle, "Small")
	testing.expect(t, small.match == .Unique && small.element.collection_selected,
		"the controlled selection should follow its stable value after reorder")
	testui.destroy_find_result(&small)
}
