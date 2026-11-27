package main

import "core:fmt"
import "core:testing"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import testui "alicorn:testui"
import data_grid "alikit:data_grid"

@(private)
query_by_name :: proc(role: alicorn.Semantic_Role, name: string) -> testui.Query {
	return testui.Query{role=role, name=name, match_role=true, match_name=true}
}

@(private)
find_expect_unique :: proc(
	t: ^testing.T,
	handle: ^testui.Test_Handle(App),
	role: alicorn.Semantic_Role,
	name: string,
) -> testui.Find_Result {
	result := testui.find(handle, query_by_name(role, name))
	testing.expect(t, result.match == .Unique && result.status == .Ok,
		fmt.tprintf("expected unique %v named %q; match=%v status=%v", role, name, result.match, result.status))
	return result
}

@(test)
test_data_grid_visual_matrix :: proc(t: ^testing.T) {
	dimensions := [3][2]int{{1280, 800}, {960, 720}, {760, 640}}
	scales := [4]f32{1, 1.25, 1.5, 2}
	for size in dimensions {
		for scale in scales {
			app: App
			handle, status := testui.open(&app, render,
				width=size[0], height=size[1], scale=scale, initialize=initialize_test)
			testing.expect(t, status == .Ok,
				fmt.tprintf("TestUI open failed for %dx%d at %.2fx: %v", size[0], size[1], scale, status))
			if status != .Ok { continue }

			table := find_expect_unique(t, &handle, .Table, "Projects")
			header := find_expect_unique(t, &handle, .Table_Column_Header, "NAME")
			row := find_expect_unique(t, &handle, .Table_Row, "Quarterly planning")
			cell := find_expect_unique(t, &handle, .Table_Row_Header, "Quarterly planning")

			testing.expect(t, app.visible_count == 200, "the application owns 200 logical rows")
			testing.expect(t, table.element.logical_count == 201,
				fmt.tprintf("table collection includes 200 data rows plus one header row; got %d", table.element.logical_count))
			testing.expect(t, row.element.semantic_id == data_grid.row_semantic_id(GRID_INSTANCE_ID, 1),
				"row identity follows the stable application row key")
			testing.expect(t, header.element.semantic_id == data_grid.header_cell_semantic_id(GRID_INSTANCE_ID, 1) &&
				 cell.element.semantic_id == data_grid.cell_semantic_id(GRID_INSTANCE_ID, 1, 1),
				"header and body cell identities follow stable column and row keys")
			testing.expect(t, alicorn.semantic_states_has(cell.element.states, .Selected),
				"accepted selection is published on the selected cell")
			testing.expect(t, alicorn.semantic_states_has(cell.element.states, .Current),
				"roving current cell is published separately from selection")
			testing.expect(t, table.element.collection_selected_id == data_grid.row_semantic_id(GRID_INSTANCE_ID, 1) &&
				 table.element.collection_current_id == data_grid.row_semantic_id(GRID_INSTANCE_ID, 1),
				"table publishes selected and current row identities")
			testing.expect(t, app.view.last_first == 0 && app.view.last_last <= app.max_visible_rows+2,
				fmt.tprintf("only visible/overscan rows are realized: [%d,%d) for max %d",
					app.view.last_first, app.view.last_last, app.max_visible_rows))

			inside := testui.expect_inside(&handle, &cell.element, &table.element)
			testing.expect(t, inside.ok, testui.layout_check_diagnostic(inside))
			no_overflow := testui.expect_no_overflow(&handle, &cell.element)
			testing.expect(t, no_overflow.ok, testui.layout_check_diagnostic(no_overflow))
			aligned := testui.expect_fills_width(&handle, &cell.element, &header.element, 0.75)
			testing.expect(t, aligned.ok, testui.layout_check_diagnostic(aligned))
			text := testui.expect_visible_text(&handle, &cell.element, "Quarterly planning")
			testing.expect(t, text.ok, testui.visible_text_diagnostic(text))
			viewport := alicorn.Rect{0, 0, f32(size[0]), f32(size[1])}
			testing.expect(t, table.element.bounds.x >= viewport.x &&
				table.element.bounds.x+table.element.bounds.w <= viewport.x+viewport.w+0.75,
				fmt.tprintf("table stays within %dx%d logical viewport: %v", size[0], size[1], table.element.bounds))

			testui.destroy_find_result(&cell)
			testui.destroy_find_result(&row)
			testui.destroy_find_result(&header)
			testui.destroy_find_result(&table)
			testui.close(&handle)
			destroy(&app)
		}
	}
}

@(test)
test_data_grid_interactions_and_requests :: proc(t: ^testing.T) {
	app: App
	handle, status := testui.open(&app, render, width=1280, height=800, scale=1, initialize=initialize_test)
	testing.expect(t, status == .Ok, fmt.tprintf("TestUI open: %v", status))
	if status != .Ok { return }

	status = testui.step(&handle, testui.Input{kind=.Key, key=.Page_Down})
	testing.expect(t, status == .Ok, fmt.tprintf("Page Down: %v", status))
	testing.expect(t, app.view.active_row_index == app.max_visible_rows,
		fmt.tprintf("Page Down moves by the visible row count: %d vs %d", app.view.active_row_index, app.max_visible_rows))
	testing.expect(t, app.view.last_first > 0, "keyboard reveal scrolls the focused row into the realized window")
	active_name := app.projection[app.view.active_row_index].cells[0].text
	active_row := find_expect_unique(t, &handle, .Table_Row, active_name)
	active_cell := find_expect_unique(t, &handle, .Table_Row_Header, active_name)
	testing.expect(t, active_row.element.has_bounds && active_cell.element.has_bounds,
		"focused row and cell have realized bounds after Page Down")
	testing.expect(t, alicorn.semantic_states_has(active_row.element.states, .Current) &&
		 alicorn.semantic_states_has(active_cell.element.states, .Current),
		"keyboard navigation updates Current while accepted selection remains app-owned")
	visible := testui.expect_visible_text(&handle, &active_cell.element, active_name)
	testing.expect(t, visible.ok, testui.visible_text_diagnostic(visible))
	grid := find_expect_unique(t, &handle, .Table, "Projects")
	inside := testui.expect_inside(&handle, &active_cell.element, &grid.element)
	testing.expect(t, inside.ok, testui.layout_check_diagnostic(inside))
	testui.destroy_find_result(&grid)
	testui.destroy_find_result(&active_cell)
	testui.destroy_find_result(&active_row)

	// The disabled project at logical row 11 is skipped by directional navigation.
	for _ in 0..<3 {
		status = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
		testing.expect(t, status == .Ok, fmt.tprintf("Down: %v", status))
	}
	testing.expect(t, app.view.active_row_index == 12,
		fmt.tprintf("disabled row is skipped; current index=%d", app.view.active_row_index))
	status = testui.step(&handle, testui.Input{kind=.Key, key=.Return})
	testing.expect(t, status == .Ok && app.accepted_activations == 1,
		fmt.tprintf("Return activation is accepted once: status=%v activations=%d", status, app.accepted_activations))
	testing.expect(t, app.selection.row_key == u64(app.view.active_row_index+1),
		"application adopts the activated row as accepted selection")

	name_header := find_expect_unique(t, &handle, .Table_Column_Header, "NAME")
	testing.expect(t, alicorn.semantic_actions_has(name_header.element.actions, .Press),
		"sortable header advertises Press")
	status = testui.click(&handle, &name_header.element)
	testing.expect(t, status == .Ok && app.sort_proposals == 1 && app.sort_direction == .Ascending,
		fmt.tprintf("header press proposes sorting and application adopts it: status=%v proposals=%d", status, app.sort_proposals))
	testui.destroy_find_result(&name_header)
	name_header = find_expect_unique(t, &handle, .Table_Column_Header, "NAME")
	testing.expect(t, name_header.element.description == "Sorted ascending",
		fmt.tprintf("sort direction is published: %q", name_header.element.description))
	row_after_sort := find_expect_unique(t, &handle, .Table_Row, "Quarterly planning")
	testing.expect(t, row_after_sort.element.semantic_id == data_grid.row_semantic_id(GRID_INSTANCE_ID, 1),
		"stable row identity survives application sorting")
	testui.destroy_find_result(&row_after_sort)
	testui.destroy_find_result(&name_header)

	filter := find_expect_unique(t, &handle, .Text_Field, "Filter projects")
	status = testui.click(&handle, &filter.element)
	testing.expect(t, status == .Ok, fmt.tprintf("focus filter: %v", status))
	testui.destroy_find_result(&filter)
	status = testui.step(&handle, testui.Input{kind=.Text_Commit, text="Mobile"})
	testing.expect(t, status == .Ok && app.query.text == "Mobile" && app.visible_count == 1,
		fmt.tprintf("text input updates application filter: status=%v query=%q rows=%d", status, app.query.text, app.visible_count))
	status_label := testui.find(&handle, testui.Query{
		role=.Static_Text,
		key=ui.key_string("grid-row-count"),
		match_role=true,
		match_key=true,
	})
	testing.expect(t, status_label.match == .Unique,
		fmt.tprintf("row count status is queryable by stable key; match=%v", status_label.match))
	visible_count_text := testui.expect_visible_text(&handle, &status_label.element, "1 rows")
	testing.expect(t, visible_count_text.ok, testui.visible_text_diagnostic(visible_count_text))
	testui.destroy_find_result(&status_label)

	// Host Set_Value requests use the same app-owned text buffer and filtering path.
	filter = find_expect_unique(t, &handle, .Text_Field, "Filter projects")
	filter_id := filter.element.semantic_id
	testing.expect(t, alicorn.semantic_action_request(handle.runtime, filter_id, .Set_Value,
		text_value="Project 150"), "queue a semantic filter Set_Value request")
	status = testui.step(&handle, testui.Input{kind=.Time_Advance})
	testing.expect(t, status == .Ok && app.query.text == "Project 150" &&
		app.visible_count == 1 && app.filter_request_count == 1,
		fmt.tprintf("semantic Set_Value is adopted by the app: status=%v query=%q rows=%d",
			status, app.query.text, app.visible_count))
	testui.destroy_find_result(&filter)

	// Restore the complete projection and ask the app to reveal a virtual row.
	filter = find_expect_unique(t, &handle, .Text_Field, "Filter projects")
	filter_id = filter.element.semantic_id
	testing.expect(t, alicorn.semantic_action_request(handle.runtime, filter_id, .Set_Value,
		text_value=""), "queue a semantic filter clear request")
	status = testui.step(&handle, testui.Input{kind=.Time_Advance})
	testing.expect(t, status == .Ok && app.visible_count == 200,
		fmt.tprintf("clear filter request: status=%v rows=%d", status, app.visible_count))
	testui.destroy_find_result(&filter)
	virtual_row_id := data_grid.row_semantic_id(GRID_INSTANCE_ID, 150)
	virtual_row := testui.find(&handle, query_by_name(.Table_Row, "Project 150"))
	testing.expect(t, virtual_row.match == .Unique && virtual_row.element.is_virtual_item &&
		!virtual_row.element.has_bounds, "offscreen logical row is published without a realized visual row")
	testing.expect(t, alicorn.semantic_reveal_request(handle.runtime, virtual_row_id),
		"queue the host request to reveal a virtual row")
	status = testui.step(&handle, testui.Input{kind=.Time_Advance})
	testing.expect(t, status == .Ok && app.reveal_request_count == 1,
		fmt.tprintf("application maps semantic reveal through the current projection: status=%v requests=%d range=[%d,%d)",
			status, app.reveal_request_count, app.view.last_first, app.view.last_last))
	testui.destroy_find_result(&virtual_row)
	virtual_row = testui.find(&handle, query_by_name(.Table_Row, "Project 150"))
	testing.expect(t, virtual_row.match == .Unique && virtual_row.element.has_bounds,
		"revealed row is realized with bounds")
	testui.destroy_find_result(&virtual_row)
	testui.close(&handle)
	destroy(&app)
}

@(test)
test_data_grid_app_build_is_shared :: proc(t: ^testing.T) {
	// Verify that the same UI callback used by ui.run is accepted by TestUI.
	app: App
	handle, status := testui.open(&app, render, width=960, height=720, scale=1.25, initialize=initialize_test)
	testing.expect(t, status == .Ok, "production render callback opens in TestUI")
	if status == .Ok {
		result := testui.find(&handle, query_by_name(.Table, "Projects"))
		testing.expect(t, result.match == .Unique, "production callback publishes the grid")
		testui.destroy_find_result(&result)
		testui.close(&handle)
	}
	destroy(&app)
}
