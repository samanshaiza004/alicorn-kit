package main

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

initialize_reference_test :: proc(data: rawptr, _rt: ^alicorn.Runtime) {
	initialize(cast(^App)data)
}

check_reference_layout :: proc(t: ^testing.T, width, height: int, scale: f32) {
	app := App{}
	handle, status := testui.open(
		&app,
		render,
		width=width,
		height=height,
		scale=scale,
		initialize=initialize_reference_test,
	)
	defer stop(&app)
	defer if handle.runtime != nil { testui.close(&handle) }
	if !testing.expectf(t, status == .Ok,
		"the Data Grid reference should open at %d×%d / %.2fx: %v %s",
		width, height, scale, status, testui.last_turn_diagnostic(&handle)) {
		return
	}

	viewport := alicorn.viewport_bounds(handle.runtime)
	window_id, window_found := alicorn.node_by_key(handle.runtime,
		ui.key_string("grid-example-window"), .Container)
	window, window_ok := alicorn.node_info(handle.runtime, window_id)
	main_id, main_found := alicorn.node_by_key(handle.runtime,
		ui.key_string("grid-example-main"), .Container)
	main, main_ok := alicorn.node_info(handle.runtime, main_id)
	panel_id, panel_found := alicorn.node_by_key(handle.runtime,
		ui.key_string("grid-example-panel"), .Container)
	panel, panel_ok := alicorn.node_info(handle.runtime, panel_id)
	content_id, content_found := alicorn.node_by_key(handle.runtime,
		ui.key_string("grid-example-content"), .Container)
	content, content_ok := alicorn.node_info(handle.runtime, content_id)
	list, list_ok := alicorn.node_info(handle.runtime, app.view.list_node)
	testing.expectf(t, window_found && window_ok && window.bounds == viewport,
		"the reference root should fill the viewport at %d×%d / %.2fx: viewport=%v root=%v",
		width, height, scale, viewport, window.bounds)
	if testing.expectf(t, main_found && main_ok && main.bounds.h > 0,
		"the workspace should receive height below its titlebar at %d×%d / %.2fx: %v",
		width, height, scale, main.bounds) {
		testing.expectf(t, panel_found && panel_ok && panel.bounds.w > 0 && panel.bounds.h > 0,
			"the grid panel should have visible bounds at %d×%d / %.2fx: %v",
			width, height, scale, panel.bounds)
	}
	grid := testui.find(&handle, testui.Query{
		role=.Table, name="Projects", match_role=true, match_name=true,
	})
	defer testui.destroy_find_result(&grid)
	if !testing.expect(t, grid.match == .Unique, "the reference app should publish its Projects table") {
		return
	}
	grid_info, grid_info_ok := alicorn.node_info(handle.runtime, grid.element.visual_node)
	testing.expectf(t, list_ok && list.scroll_viewport_bounds.w > 0 && list.scroll_viewport_bounds.h > 0,
		"the virtual grid viewport should have nonzero width and height at %d×%d / %.2fx: list=%v content-root=%v panel=%v grid=%v",
		width, height, scale, list.scroll_viewport_bounds,
		grid_info.bounds, panel.bounds, grid.element.bounds)
	testing.expectf(t, panel_found && panel_ok && panel.bounds.w >= 320,
		"the panel should retain its intended width at %d×%d / %.2fx: panel=%v content=%v/%v bounds=%v content-root=%v grid=%v",
		width, height, scale, panel.bounds, content_found, content_ok, content.bounds, grid_info.bounds, grid.element.bounds)
	testing.expect_value(t, grid.element.logical_count, u64(ROW_COUNT+1))
	inside_viewport := grid.element.bounds.x >= viewport.x-0.5 &&
		grid.element.bounds.y >= viewport.y-0.5 &&
		grid.element.bounds.x+grid.element.bounds.w <= viewport.x+viewport.w+0.5 &&
		grid.element.bounds.y+grid.element.bounds.h <= viewport.y+viewport.h+0.5
	testing.expectf(t, inside_viewport,
		"the table should remain inside the application viewport at %d×%d / %.2fx: %v viewport=%v",
		width, height, scale, grid.element.bounds, viewport)
	testing.expectf(t, grid_info_ok && grid_info.bounds.w > 0 && grid_info.bounds.h > 0 &&
		grid.element.bounds.w > 0 && grid.element.bounds.h > 0,
		"the semantic Table owner should have visible bounds at %d×%d / %.2fx: %v",
		width, height, scale, grid.element.bounds)

	first_project := testui.find(&handle, testui.Query{
		role=.Table_Row_Header, name="Quarterly planning", match_role=true, match_name=true,
	})
	defer testui.destroy_find_result(&first_project)
	if testing.expectf(t, first_project.match == .Unique && !first_project.element.is_virtual_item &&
		first_project.element.has_bounds,
		"the first project should be a realized row header at %d×%d / %.2fx",
		width, height, scale) {
		row_bounds := first_project.element.bounds
		list_bounds := list.scroll_viewport_bounds
		row_inside_list := row_bounds.x >= list_bounds.x-0.5 && row_bounds.y >= list_bounds.y-0.5 &&
			row_bounds.x+row_bounds.w <= list_bounds.x+list_bounds.w+0.5 &&
			row_bounds.y+row_bounds.h <= list_bounds.y+list_bounds.h+0.5
		testing.expectf(t, row_inside_list,
			"the first row should fit the visible list viewport at %d×%d / %.2fx: row=%v list=%v",
			width, height, scale, row_bounds, list_bounds)
		inside_table := testui.expect_inside(&handle, &first_project.element, &grid.element)
		testing.expectf(t, inside_table.ok,
			"the table bounds should contain its visible first row at %d×%d / %.2fx: %s",
			width, height, scale, testui.layout_check_diagnostic(inside_table))
		visible := testui.expect_visible_text(&handle, &first_project.element, "Qua")
		testing.expect(t, visible.ok, testui.visible_text_diagnostic(visible))
	}

	filter := testui.find(&handle, testui.Query{
		role=.Text_Field, name="Filter projects", match_role=true, match_name=true,
	})
	defer testui.destroy_find_result(&filter)
	row_count, row_count_ok := alicorn.node_info(handle.runtime, app.row_count_node)
	if testing.expectf(t, filter.match == .Unique && row_count_ok,
		"filter and row count should exist at %d×%d / %.2fx: filter=%v row-count=%v",
		width, height, scale, filter.match, row_count_ok) {
		filter_bounds := filter.element.bounds
		row_bounds := row_count.bounds
		separated := filter_bounds.x+filter_bounds.w <= row_bounds.x+0.5 ||
			row_bounds.x+row_bounds.w <= filter_bounds.x+0.5
		testing.expectf(t, separated,
			"filter and row count overlap at %d×%d / %.2fx: filter=%v row-count=%v",
			width, height, scale, filter_bounds, row_bounds)
	}
}

@(test)
test_reference_layout_visible_at_supported_viewports_and_dpi_scales :: proc(t: ^testing.T) {
	widths := [3]int{1280, 960, 760}
	heights := [3]int{800, 720, 640}
	scales := [4]f32{1, 1.25, 1.5, 2}
	for width, index in widths {
		for scale in scales {
			check_reference_layout(t, width, heights[index], scale)
		}
	}
}

@(test)
test_reference_adopts_accessibility_filter_value :: proc(t: ^testing.T) {
	app := App{}
	handle, status := testui.open(
		&app,
		render,
		width=1280,
		height=800,
		initialize=initialize_reference_test,
	)
	defer stop(&app)
	defer if handle.runtime != nil { testui.close(&handle) }
	if !testing.expectf(t, status == .Ok,
		"the reference app should open for semantic filter testing: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		return
	}

	filter_node, found := alicorn.node_by_key(handle.runtime,
		ui.key_string("grid-example-filter"), .Text_Field)
	if !testing.expect(t, found, "the reference filter should have a retained text-field node") {
		return
	}
	filter_id := alicorn.semantic_visual_id(filter_node)
	queued := alicorn.semantic_action_request(
		handle.runtime, filter_id, .Set_Value, text_value="Blocked")
	if !testing.expect(t, queued, "the semantic filter should accept an app-owned Set_Value request") {
		return
	}
	_ = testui.describe_once(&handle)
	testing.expect_value(t, app.query.text, "Blocked")
	testing.expect_value(t, app.visible_count, 66)
}
