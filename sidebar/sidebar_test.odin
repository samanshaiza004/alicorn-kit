package sidebar

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

FIXTURE_ITEMS :: [5]Item{
	{key=1, label="Home", icon=.Folder_Closed},
	{key=2, label="Search", icon=.Search, disabled=true},
	{key=3, label="Files", icon=.File},
	{key=4, label="Terminal", icon=.Terminal, badge="2"},
	{key=5, label="Help", icon=.Info},
}

Test_App :: struct {
	rail:         State,
	items:        [5]Item,
	selected_key: u64,
	collapsed:    bool,
	events:       int,
	last_key:     u64,
}

fixture_render :: proc(app: ^Test_App, ctx: ^ui.UI) {
	if ui.row(ctx, key=alicorn.key_string("sidebar-fixture-root"), width=-1, height=-1, grow=1) {
		event := rail(
			ctx,
			&app.rail,
			app.items[:],
			app.selected_key,
			Options{accessible_label="Main navigation", collapsed=app.collapsed},
			key=alicorn.key_string("sidebar-fixture-rail"),
			instance_id=5101,
		)
		if event.kind == .Selection_Proposed {
			app.selected_key = event.key
			app.last_key = event.key
			app.events += 1
		}
		if ui.column(ctx, key=alicorn.key_string("sidebar-fixture-content"), width=-1, height=-1,
			padding=20, gap=8) {
			_ = ui.text(ctx, "Content", size=20)
		}
	}
}

fixture_open :: proc(app: ^Test_App, t: ^testing.T, scale: f32 = 1) -> (testui.Test_Handle(Test_App), bool) {
	app.items = FIXTURE_ITEMS
	app.selected_key = 1
	_ = request_focus(&app.rail)
	handle, status := testui.open(app, fixture_render, width=640, height=420, scale=scale)
	if !testing.expectf(t, status == .Ok, "the sidebar fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
find_rail :: proc(handle: ^testui.Test_Handle(Test_App)) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.List_Box, name="Main navigation", match_role=true, match_name=true})
}

@(private)
find_item :: proc(handle: ^testui.Test_Handle(Test_App), name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.List_Box_Option, name=name, match_role=true, match_name=true})
}

@(test)
test_sidebar_routes_remain_visible_and_contained_at_fractional_scales :: proc(t: ^testing.T) {
	scales := [4]f32{1, 1.25, 1.5, 2}
	for scale in scales {
		app := Test_App{}
		handle, ok := fixture_open(&app, t, scale)
		if !ok { continue }

		rail_node := find_rail(&handle)
		files := find_item(&handle, "Files")
		if testing.expectf(t, rail_node.match == .Unique && files.match == .Unique,
			"sidebar and visible route should be available at %.2f", scale) {
			visible := testui.expect_visible_text(&handle, &files.element, "Files")
			inside := testui.expect_inside(&handle, &files.element, &rail_node.element)
			testing.expectf(t, visible.ok && inside.ok,
				"sidebar route should remain visible and contained at %.2f: %s %s",
				scale, testui.visible_text_diagnostic(visible), testui.layout_check_diagnostic(inside))
		}
		testui.destroy_find_result(&rail_node)
		testui.destroy_find_result(&files)
		testui.close(&handle)
	}
}

@(test)
test_sidebar_identity_and_theme_contract :: proc(t: ^testing.T) {
	testing.expect(t, item_semantic_id(0, 1).namespace == 0, "instance zero must not publish identity")
	testing.expect(t, item_semantic_id(1, 0).namespace == 0, "item key zero must not publish identity")
	testing.expect(t, item_semantic_id(1, 2) != item_semantic_id(2, 2),
		"the same route in two rails must have distinct identity")

	recipe := Recipe{
		selected_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.sidebar", "selected"),
	}
	contract := theme_contract_default(recipe)
	testing.expect_value(t, contract.required_count, 1)
	testing.expect_value(t, contract.optional_count, 2)
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 200, 120})
	defer alicorn.destroy_runtime(&rt)
	report := theme_contract_check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	testing.expect(t, !theme_contract_satisfied(report), "a configured role must be validated")
	names, count := theme_contract_missing_required(contract, report)
	testing.expect(t, count == 1 && names[0] == "alikit.sidebar.selected_surface")
}

@(test)
test_sidebar_semantics_navigation_and_activation :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	rail_node := find_rail(&handle)
	defer testui.destroy_find_result(&rail_node)
	if !testing.expect(t, rail_node.match == .Unique, "the rail should publish one List_Box") { return }
	testing.expect(t, rail_node.element.is_collection && rail_node.element.logical_count == 5,
		"the rail should publish five logical routes")
	testing.expect_value(t, rail_node.element.collection_selected_id, item_semantic_id(5101, 1))
	testing.expect_value(t, rail_node.element.collection_current_id, item_semantic_id(5101, 1))

	search := find_item(&handle, "Search")
	defer testui.destroy_find_result(&search)
	testing.expect(t, alicorn.semantic_states_has(search.element.states, .Disabled),
		"a disabled route should publish Disabled")
	testing.expect(t, !alicorn.semantic_actions_has(search.element.actions, .Select),
		"a disabled route must not advertise Select")

	// Down skips the disabled Search route and moves Current without selecting.
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok, "Down should be scoped")
	testing.expect_value(t, app.selected_key, u64(1))
	testing.expect_value(t, app.rail.active_key, u64(3))
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Return}) == .Ok, "Return should be scoped")
	testing.expect_value(t, app.selected_key, u64(3))
	testing.expect_value(t, app.events, 1)

	files := find_item(&handle, "Files")
	if testing.expect(t, files.match == .Unique, "Files should be realized") {
		visible_label := testui.expect_visible_text(&handle, &files.element, "Files")
		testing.expect(t, visible_label.ok, testui.visible_text_diagnostic(visible_label))
		testing.expect(t, files.element.collection_selected && files.element.collection_current,
			"the accepted route should be Selected and Current")
	}
	testui.destroy_find_result(&files)

	// End reaches the last enabled route; pointer activation proposes the same
	// identity as keyboard and semantic Select.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.End})
	testing.expect_value(t, app.rail.active_key, u64(5))
	help := find_item(&handle, "Help")
	if testing.expect(t, help.match == .Unique, "Help should be realized") {
		_ = testui.click(&handle, &help.element)
		testing.expect_value(t, app.selected_key, u64(5))
	}
	testui.destroy_find_result(&help)

	terminal := find_item(&handle, "Terminal")
	if testing.expect(t, terminal.match == .Unique, "Terminal should be realized") {
		status := testui.step(&handle, testui.Input{
			kind=.Semantic_Action,
			semantic_id=terminal.element.semantic_id,
			semantic_action=.Select,
		})
		testing.expect(t, status == .Ok, "semantic Select should be accepted")
		testing.expect_value(t, app.selected_key, u64(4))
	}
	testui.destroy_find_result(&terminal)
}

@(test)
test_sidebar_roving_list_pattern_conformance :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	parts := []testui.Pattern_Part{
		{id=.Container, query=testui.Query{role=.List_Box, name="Main navigation", match_role=true, match_name=true}},
		{id=.Target_Option, query=testui.Query{role=.List_Box_Option, name="Files", match_role=true, match_name=true}},
		{id=.Disabled_Option, query=testui.Query{role=.List_Box_Option, name="Search", match_role=true, match_name=true}},
	}
	report := testui.pattern_check(&handle, testui.Pattern_Config{
		kind=.Roving_List,
		parts=parts,
		roving=testui.Pattern_Roving_Config{
			focus=.Container,
			wrap=false,
			expect_selection=true,
		},
	})
	testing.expect(t, report.ok, testui.pattern_failure_diagnostic(&report.failure))
	testing.expect_value(t, app.selected_key, u64(3))
}

@(test)
test_sidebar_collapse_preserves_identity_and_focus_owner :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	expanded_rail := find_rail(&handle)
	expanded_item := find_item(&handle, "Home")
	if !testing.expect(t, expanded_rail.match == .Unique && expanded_item.match == .Unique,
		"the expanded rail and Home should be realized") { return }
	expanded_width := expanded_rail.element.bounds.w
	expanded_item_width := expanded_item.element.bounds.w
	expanded_id := expanded_item.element.semantic_id
	testui.destroy_find_result(&expanded_rail)
	testui.destroy_find_result(&expanded_item)

	app.collapsed = true
	alicorn.invalidate_root(handle.runtime, "fixture collapsed navigation rail")
	_ = testui.describe_once(&handle)

	collapsed_rail := find_rail(&handle)
	collapsed_item := find_item(&handle, "Home")
	if !testing.expect(t, collapsed_rail.match == .Unique && collapsed_item.match == .Unique,
		"the collapsed rail and Home should remain realized") { return }
	testing.expect(t, collapsed_rail.element.bounds.w < expanded_width,
		"collapsing should reduce the rail width")
	testing.expect(t, collapsed_item.element.bounds.w < expanded_item_width,
		"collapsing should reduce the item width")
	testing.expect_value(t, collapsed_item.element.semantic_id, expanded_id)
	testing.expect(t, collapsed_item.element.collection_selected,
		"the selected route should survive the collapse")
	testui.destroy_find_result(&collapsed_rail)
	testui.destroy_find_result(&collapsed_item)

	// Reorder the caller data; the selected identity follows its stable key.
	app.items = [5]Item{
		{key=5, label="Help", icon=.Info},
		{key=3, label="Files", icon=.File},
		{key=1, label="Home", icon=.Folder_Closed},
		{key=2, label="Search", icon=.Search, disabled=true},
		{key=4, label="Terminal", icon=.Terminal, badge="2"},
	}
	alicorn.invalidate_root(handle.runtime, "fixture reordered rail")
	_ = testui.describe_once(&handle)
	home := find_item(&handle, "Home")
	testing.expect(t, home.match == .Unique && home.element.collection_selected,
		"the selected route should follow its stable key after reorder")
	testui.destroy_find_result(&home)
}
