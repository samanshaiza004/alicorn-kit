package segmented

// Public-surface tests for the shared selection model's second consumer.

import "core:testing"
import "core:math"
import alicorn "alicorn:runtime"
import sel "alikit:selection"
import testui "alicorn:testui"
import ui "alicorn:ui"

SEGMENT_ITEMS :: [4]Item{
	{value=10, label="Overview"},
	{value=20, label="Activity", disabled=true},
	{value=30, label="Files"},
	{value=40, label="Settings"},
}

Test_App :: struct {
	state:    State,
	items:    [4]Item,
	selected: u64,
	mode:     sel.Mode,
	events:   int,
	last:     u64,
}

fixture_render :: proc(app: ^Test_App, ctx: ^ui.UI) {
	_ = ui.text(ctx, "Segmented fixture", size=18)
	event := control(
		ctx,
		&app.state,
		app.items[:],
		app.selected,
		Options{accessible_label="Workspace view", width=320, selection_mode=app.mode},
		key=alicorn.key_string("segmented-fixture"),
		instance_id=9801,
	)
	if event.kind == .Selection_Proposed {
		app.selected = event.value
		app.last = event.value
		app.events += 1
	}
}

fixture_open :: proc(app: ^Test_App, t: ^testing.T) -> (testui.Test_Handle(Test_App), bool) {
	app.items = SEGMENT_ITEMS
	app.selected = 10
	app.mode = .Follow_Focus
	_ = request_focus(&app.state)
	handle, status := testui.open(app, fixture_render, width=520, height=260)
	if !testing.expectf(t, status == .Ok, "the segmented fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
find_control :: proc(handle: ^testui.Test_Handle(Test_App)) -> testui.Find_Result {
	return testui.find(handle, testui.Query{
		role=.Tab_List, name="Workspace view", match_role=true, match_name=true,
	})
}

@(private)
find_segment :: proc(handle: ^testui.Test_Handle(Test_App), name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{
		role=.Tab, name=name, match_role=true, match_name=true,
	})
}

@(test)
test_segmented_identity_and_theme_contract :: proc(t: ^testing.T) {
	testing.expect(t, control_semantic_id(0).namespace == 0, "instance zero must not publish identity")
	testing.expect(t, segment_semantic_id(1, 0).namespace == 0, "segment zero must not publish identity")
	testing.expect(t, control_semantic_id(1) != segment_semantic_id(1, 10),
		"the control and a segment must not collide")
	testing.expect(t, segment_semantic_id(1, 10) != segment_semantic_id(2, 10),
		"the same segment in two controls must have distinct identity")

	recipe := Recipe{
		indicator_surface_role=alicorn.style_extension_color_role_id("alikit.segmented", "indicator"),
	}
	contract := theme_contract_default(recipe)
	testing.expect_value(t, contract.required_count, 1)
	testing.expect_value(t, contract.optional_count, 1)
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 240, 160})
	defer alicorn.destroy_runtime(&rt)
	report := theme_contract_check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	testing.expect(t, !theme_contract_satisfied(report), "a configured role must be validated")
	names, count := theme_contract_missing_required(contract, report)
	testing.expect(t, count == 1 && names[0] == "alikit.segmented.indicator_surface")
}

@(test)
test_segmented_semantics_keyboard_and_activation_parity :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	control_find := find_control(&handle)
	defer testui.destroy_find_result(&control_find)
	if !testing.expect(t, control_find.match == .Unique && control_find.element.logical_count == 4,
		"the control should publish one four-segment Tab_List") { return }
	testing.expect_value(t, control_find.element.collection_selected_id, segment_semantic_id(9801, 10))
	testing.expect_value(t, control_find.element.collection_current_id, segment_semantic_id(9801, 10))

	overview := find_segment(&handle, "Overview")
	activity := find_segment(&handle, "Activity")
	files := find_segment(&handle, "Files")
	defer testui.destroy_find_result(&overview)
	defer testui.destroy_find_result(&activity)
	defer testui.destroy_find_result(&files)
	if !testing.expect(t, overview.match == .Unique && activity.match == .Unique && files.match == .Unique,
		"all segments should be realized") { return }
	visible_label := testui.expect_visible_text(&handle, &overview.element, "Overview")
	testing.expect(t, visible_label.ok, testui.visible_text_diagnostic(visible_label))
	testing.expect(t, overview.element.collection_selected && overview.element.collection_current,
		"the initial selection should be Selected and Current")
	testing.expect(t, alicorn.semantic_states_has(activity.element.states, .Disabled),
		"a disabled segment should publish Disabled")
	testing.expect(t, !alicorn.semantic_actions_has(activity.element.actions, .Select),
		"a disabled segment must not advertise Press")

	// Down skips the disabled Activity segment and selects Files.
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok,
		"Down should be scoped to the control")
	testing.expect_value(t, app.selected, u64(30))
	testing.expect_value(t, app.last, u64(30))
	testui.destroy_find_result(&files)
	files = find_segment(&handle, "Files")
	testing.expect(t, files.element.collection_selected && files.element.collection_current,
		"the accepted proposal should update Selected and Current")
	testing.expectf(t, math.abs(app.state.last_indicator_x-160) < 0.01,
		"the indicator target should translate by two segment widths: %v", app.state.last_indicator_x)

	// Wrap and Home/End.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, app.selected, u64(40))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, app.selected, u64(10))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.End})
	testing.expect_value(t, app.selected, u64(40))

	// Pointer and semantic activation agree with the keyboard path.
	testui.destroy_find_result(&overview)
	overview = find_segment(&handle, "Overview")
	_ = testui.click(&handle, &overview.element)
	testing.expect_value(t, app.selected, u64(10))
	testui.destroy_find_result(&files)
	files = find_segment(&handle, "Files")
	status := testui.step(&handle, testui.Input{
		kind=.Semantic_Action,
		semantic_id=files.element.semantic_id,
		semantic_action=.Select,
	})
	testing.expect(t, status == .Ok, "a semantic Press on a segment should be accepted")
	testing.expect_value(t, app.selected, u64(30))
	testing.expect(t, app.events >= 6, "keyboard, pointer, and semantic activation should agree")

	// The disabled Activity segment rejects both paths.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Home})
	testui.destroy_find_result(&activity)
	activity = find_segment(&handle, "Activity")
	_ = testui.click(&handle, &activity.element)
	testing.expect_value(t, app.selected, u64(10))
	_ = testui.step(&handle, testui.Input{
		kind=.Semantic_Action,
		semantic_id=activity.element.semantic_id,
		semantic_action=.Select,
	})
	testing.expect_value(t, app.selected, u64(10))
}

@(test)
test_segmented_activate_mode_separates_focus_and_selection :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	app.mode = .Activate
	alicorn.invalidate_root(handle.runtime, "segmented fixture switched mode")
	_ = testui.describe_once(&handle)
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, app.selected, u64(10))
	control_find := find_control(&handle)
	defer testui.destroy_find_result(&control_find)
	testing.expect_value(t, control_find.element.collection_selected_id, segment_semantic_id(9801, 10))
	testing.expect_value(t, control_find.element.collection_current_id, segment_semantic_id(9801, 30))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Toggle})
	testing.expect_value(t, app.selected, u64(30))
}

@(test)
test_segmented_reduced_motion_snaps_indicator :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	observation := alicorn.Accessibility_Appearance_Observation{
		preferences=alicorn.Accessibility_Appearance_Preferences{reduce_motion=true},
		known={.Reduce_Motion},
	}
	testing.expect(t, alicorn.style_root_accessibility_observation_set(handle.runtime, observation),
		"the fixture should enable reduced motion")
	alicorn.invalidate_root(handle.runtime, "segmented fixture enabled reduced motion")
	_ = testui.describe_once(&handle)
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect(t, app.state.last_reduced_motion,
		"the control should observe reduced motion")
	testing.expectf(t, math.abs(app.state.last_indicator_x-160) < 0.01,
		"the snapped indicator should still target the new segment: %v", app.state.last_indicator_x)
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Time_Advance, delta_ns=16_000_000}) == .Ok,
		"a snapped indicator should settle without leaving the description pending")
	turn := testui.last_turn(&handle)
	testing.expect(t, turn.stabilized && !turn.layout_pending,
		"the segmented idle turn should be stabilized and layout-clean")
}

@(test)
test_segmented_reorder_keeps_stable_identity :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	before := find_segment(&handle, "Files")
	id_before := before.element.semantic_id
	testui.destroy_find_result(&before)

	app.items = [4]Item{
		{value=40, label="Settings"},
		{value=20, label="Activity", disabled=true},
		{value=10, label="Overview"},
		{value=30, label="Files"},
	}
	alicorn.invalidate_root(handle.runtime, "segmented fixture reordered items")
	_ = testui.describe_once(&handle)
	files := find_segment(&handle, "Files")
	defer testui.destroy_find_result(&files)
	testing.expect(t, files.match == .Unique && files.element.semantic_id == id_before,
		"segment identity should follow the stable value after reorder")
}
