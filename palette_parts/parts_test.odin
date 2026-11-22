package palette_parts

// Behavior tests for the parts-based palette result list. These are external
// consumers of Alicorn's public runtime and `alicorn:testui`; no AliKit-private
// runtime access is used. The comparison against the stock command palette is
// in pilot_test.odin.

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"
import palette "alikit:palette_model"

TEST_ITEM_COUNT :: 6

test_items :: proc() -> [TEST_ITEM_COUNT]Item {
	return {
		{id=1, title="Alpha", description="First"},
		{id=2, title="Bravo", description="Second"},
		{id=3, title="Charlie", description="Third", disabled=true},
		{id=4, title="Delta", description="Fourth"},
		{id=5, title="Echo", description="Fifth"},
		{id=6, title="Foxtrot", description="Sixth"},
	}
}

Test_App :: struct {
	items:          [TEST_ITEM_COUNT]Item,
	filtered:       [TEST_ITEM_COUNT]Item,
	matches:        [TEST_ITEM_COUNT]Match,
	filtered_count: int,
	query:          ui.Text_Buffer,
	state:          State,
	activations:    int,
	last_id:        Item_ID,
	close_on_activate: bool,
	manual_filter:  bool,
}

test_filter :: proc(app: ^Test_App) {
	app.filtered_count = 0
	for item in app.items {
		if palette.matches(item, app.query.text) {
			app.filtered[app.filtered_count] = item
			app.filtered_count += 1
		}
	}
	count, _ := palette.index_all(app.filtered[:app.filtered_count], app.matches[:])
	app.filtered_count = count
}

test_build :: proc(state: rawptr, rt: ^alicorn.Runtime, width, height: int, scale: f32) -> alicorn.Node_ID {
	app := cast(^Test_App)state
	ctx, should_build := alicorn.begin_frame(rt)
	if !should_build { return 0 }
	root := alicorn.container_begin(&ctx, .Root, label="palette-parts-test-root",
		key=alicorn.key_string("palette-parts-test-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, padding=12, gap=8))
	_ = alicorn.text_field_controlled(
		&ctx,
		&app.query,
		key=alicorn.key_string("palette-parts-test-query"),
		style=alicorn.layout_style(.Row, width=-1, height=32),
	)
	if !app.manual_filter { test_filter(app) }
	event := results(
		&ctx,
		&app.state,
		app.filtered[:app.filtered_count],
		app.matches[:app.filtered_count],
		key=alicorn.key_string("palette-parts-test-list"),
		options=Options{accessible_label="Test results", list_max_height=260},
	)
	if event.kind == .Activated {
		app.activations += 1
		app.last_id = event.item_id
	}
	alicorn.container_end(&ctx)
	alicorn.end_frame(&ctx)
	return root
}

test_initialize :: proc(state: rawptr, rt: ^alicorn.Runtime) {
	app := cast(^Test_App)state
	app.items = test_items()
	app.state.selection.id = 1
	_ = request_focus(&app.state)
}

test_on_key :: proc(state: rawptr, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	app := cast(^Test_App)state
	handled, event := handle_key(&app.state, rt, app.filtered[:app.filtered_count], app.matches[:app.filtered_count], key)
	if event.kind == .Activated {
		app.activations += 1
		app.last_id = event.item_id
	}
	return handled
}

test_open :: proc(app: ^Test_App, t: ^testing.T) -> (testui.Test_Handle(Test_App), bool) {
	buffer, ok := ui.text_buffer("")
	if !ok { return {}, false }
	app.query = buffer
	handle, status := testui.open(
		app,
		width=520,
		height=420,
		initialize=test_initialize,
		build_application=test_build,
		on_key=test_on_key,
	)
	if !testing.expectf(t, status == .Ok, "palette parts test application should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		ui.text_buffer_destroy(&app.query)
		return {}, false
	}
	return handle, true
}

test_close :: proc(app: ^Test_App, handle: ^testui.Test_Handle(Test_App)) {
	if handle.runtime != nil { testui.close(handle) }
	ui.text_buffer_destroy(&app.query)
}

find_option :: proc(handle: ^testui.Test_Handle(Test_App), name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.List_Box_Option, name=name, match_role=true, match_name=true})
}

@(test)
test_palette_parts_publishes_a_list_collection :: proc(t: ^testing.T) {
	app := Test_App{close_on_activate=true}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	list := testui.find(&handle, testui.Query{role=.List_Box, name="Test results", match_role=true, match_name=true})
	defer testui.destroy_find_result(&list)
	if !testing.expect(t, list.match == .Unique, "the parts list should publish exactly one List_Box") { return }
	testing.expect(t, list.element.is_collection, "the List_Box should be a semantic collection")
	testing.expect_value(t, list.element.logical_count, u64(6))

	alpha := find_option(&handle, "Alpha")
	defer testui.destroy_find_result(&alpha)
	if !testing.expect(t, alpha.match == .Unique, "Alpha should publish one option") { return }
	testing.expect_value(t, alpha.element.collection_id, list.element.semantic_id)
	testing.expect_value(t, alpha.element.position_in_set, u64(0))
	testing.expect_value(t, alpha.element.size_of_set, u64(6))
	testing.expect(t, alpha.element.collection_current, "the reconciled selection should be current")
	testing.expectf(t, alpha.element.visual_node != 0 && alpha.element.has_bounds,
		"the realized row should have a visual node: visual=%v bounds=%v", alpha.element.visual_node, alpha.element.has_bounds)
	testing.expect(t, alpha.element.collection_selected, "the reconciled selection should be selected")
	testing.expect(t, alicorn.semantic_states_has(alpha.element.states, .Selected),
		"the selected option should publish Selected")
	testing.expect(t, alicorn.semantic_actions_has(alpha.element.actions, .Select),
		"the option should advertise Select")
}

@(test)
test_palette_parts_keyboard_navigation_and_activation :: proc(t: ^testing.T) {
	app := Test_App{close_on_activate=true}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok, "Down should be delivered") { return }
	testing.expect_value(t, app.state.selection.id, Item_ID(2))
	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok, "Down should be delivered") { return }
	testing.expect_value(t, app.state.selection.id, Item_ID(4))
	bravo := find_option(&handle, "Bravo")
	defer testui.destroy_find_result(&bravo)
	testing.expect(t, !bravo.element.collection_selected, "a previously selected row should no longer be selected")

	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Return}) == .Ok, "Return should be delivered") { return }
	testing.expect_value(t, app.activations, 1)
	testing.expect_value(t, app.last_id, Item_ID(4))
}

@(test)
test_palette_parts_skips_disabled_rows :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	_ = testui.step(&handle, testui.Input{kind=.Key, key=.End})
	testing.expect_value(t, app.state.selection.id, Item_ID(6))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Home})
	testing.expect_value(t, app.state.selection.id, Item_ID(1))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, app.state.selection.id, Item_ID(4))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Up})
	testing.expect_value(t, app.state.selection.id, Item_ID(2))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, app.state.selection.id, Item_ID(4))

	charlie := find_option(&handle, "Charlie")
	defer testui.destroy_find_result(&charlie)
	testing.expect(t, alicorn.semantic_states_has(charlie.element.states, .Disabled),
		"the disabled option should publish Disabled")
	testing.expect(t, !alicorn.semantic_actions_has(charlie.element.actions, .Select),
		"the disabled option should not advertise Select")
}

@(test)
test_palette_parts_keyboard_pointer_and_semantic_activation_agree :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	// Keyboard: Home then Down reaches Bravo.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Home})
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Return}) == .Ok, "Return should activate") { return }
	keyboard_id := app.last_id

	// Pointer: click the same row.
	bravo := find_option(&handle, "Bravo")
	if !testing.expectf(t, bravo.match == .Unique, "Bravo should be present: match=%v status=%v visual=%v bounds=%v",
		bravo.match, bravo.status, bravo.element.visual_node, bravo.element.has_bounds) {
		testui.destroy_find_result(&bravo)
		return
	}
	click_status := testui.click(&handle, &bravo.element)
	if !testing.expectf(t, click_status == .Ok, "the row should accept a coordinate click: %v visual=%v bounds=%v id=%v",
		click_status, bravo.element.visual_node, bravo.element.has_bounds, bravo.element.semantic_id) {
		testui.destroy_find_result(&bravo)
		return
	}
	pointer_id := app.last_id
	testui.destroy_find_result(&bravo)

	// Semantic: request Select on the same stable row identity.
	bravo_again := find_option(&handle, "Bravo")
	if !testing.expect(t, bravo_again.match == .Unique, "Bravo should still be present") {
		testui.destroy_find_result(&bravo_again)
		return
	}
	status := testui.step(&handle, testui.Input{
		kind=.Semantic_Action,
		semantic_id=bravo_again.element.semantic_id,
		semantic_action=.Select,
	})
	testui.destroy_find_result(&bravo_again)
	testing.expect(t, status == .Ok, "the List_Box_Option Select action should be accepted")

	testing.expect_value(t, keyboard_id, Item_ID(2))
	testing.expect_value(t, pointer_id, Item_ID(2))
	testing.expect_value(t, app.last_id, Item_ID(2))
	testing.expect_value(t, app.activations, 3)
}

@(test)
test_palette_parts_selection_survives_reorder_and_reports_removal :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down}) // Bravo
	testing.expect_value(t, app.state.selection.id, Item_ID(2))

	// Reorder the caller's data. The visible slice order is the application's
	// ranking policy; stable IDs keep selection attached to Bravo.
	original := app.items
	app.items = [TEST_ITEM_COUNT]Item{
		original[5], original[3], original[1], original[0], original[4], original[2],
	}
	reordered := [TEST_ITEM_COUNT]Item{}
	count := 0
	for item in app.items {
		if palette.matches(item, app.query.text) {
			reordered[count] = item
			count += 1
		}
	}
	app.filtered = reordered
	app.filtered_count = count
	_, _ = palette.index_all(app.filtered[:app.filtered_count], app.matches[:])
	alicorn.invalidate_root(handle.runtime, "test reordered caller data")
	_ = testui.describe_once(&handle)

	testing.expect_value(t, app.state.selection.id, Item_ID(2))
	bravo := find_option(&handle, "Bravo")
	defer testui.destroy_find_result(&bravo)
	testing.expect(t, bravo.element.collection_selected, "selection should follow the stable ID after reordering")

	// Remove the selected item. Reconcile falls back to the first enabled row.
	app.manual_filter = true
	app.filtered = [TEST_ITEM_COUNT]Item{
		original[0], original[3], original[4], original[5], {}, {},
	}
	app.filtered_count = 4
	_, _ = palette.index_all(app.filtered[:app.filtered_count], app.matches[:])
	alicorn.invalidate_root(handle.runtime, "test removed the selected caller item")
	_ = testui.describe_once(&handle)
	testing.expect_value(t, app.state.selection.id, Item_ID(1))
}

@(test)
test_palette_parts_filters_preserve_identity :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	// Move keyboard focus to the query field, then commit text there. The list
	// itself owns scoped input only while it has focus.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Tab, modifiers=alicorn.Input_Modifiers{shift=true}})
	focus_info, focus_found := alicorn.node_info(handle.runtime, alicorn.focused_node(handle.runtime))
	testing.expectf(t, focus_found && focus_info.kind == .Text_Field,
		"shift+Tab should focus the query field, got %v", focus_info.kind)
	commit := testui.step(&handle, testui.Input{kind=.Text_Commit, text="a"})
	testing.expectf(t, commit == .Ok, "the query commit should be accepted: %v", commit)
	testing.expectf(t, app.query.text == "a", "query text should be %q, got %q", "a", app.query.text)
	// Alpha, Bravo (Bravo contains 'a'), Charlie (disabled), Delta, Foxtrot.
	testing.expect(t, app.filtered_count >= 3, "caller filtering should publish matching rows")
	alpha := find_option(&handle, "Alpha")
	defer testui.destroy_find_result(&alpha)
	testing.expect(t, alpha.match == .Unique, "filtered rows should keep their accessible names")
	testing.expect(t, alpha.element.collection_selected, "selection should remain on a visible stable ID")

	_ = testui.step(&handle, testui.Input{kind=.Text_Commit, text="zzz"})
	testing.expect_value(t, app.filtered_count, 0)
	list := testui.find(&handle, testui.Query{role=.List_Box, name="Test results", match_role=true, match_name=true})
	if list.match == .Unique {
		testing.expect(t, list.element.visual_node == 0 && !list.element.has_bounds,
			"an empty result set must not leave a realized List_Box")
	}
	testui.destroy_find_result(&list)
	snapshot := alicorn.semantic_snapshot(handle.runtime, context.temp_allocator)
	defer alicorn.semantic_snapshot_destroy(&snapshot)
	empty_message := false
	for node in snapshot.nodes {
		if node.role == .Static_Text && node.value == "No matching items" { empty_message = true; break }
	}
	testing.expect(t, empty_message, "the empty label should publish as static text")
}

@(test)
test_palette_parts_teardown_returns_to_idle :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect(t, testui.advance_time(&handle, 16_000_000) == .Ok, "explicit virtual time should advance")
	testing.expect(t, !handle.runtime.invalidated && !alicorn.presentation_needs_frame(handle.runtime),
		"the parts list should settle to no scheduled work")
}
