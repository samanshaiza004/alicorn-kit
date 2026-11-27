package data_grid_trial_tests

import "core:fmt"
import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import data_grid "alikit:data_grid"
import trial_app "trial:app"

Viewport :: struct {
	width, height: int,
}

trial_assertions: int

expect :: proc(t: ^testing.T, condition: bool, message: string) -> bool {
	trial_assertions += 1
	return testing.expect(t, condition, message)
}

find_named :: proc(
	handle: ^testui.Test_Handle(trial_app.Grid_App),
	role: alicorn.Semantic_Role,
	name: string,
) -> testui.Find_Result {
	return testui.find(handle, testui.Query{
		role=role,
		name=name,
		match_role=true,
		match_name=true,
	})
}

find_row :: proc(
	handle: ^testui.Test_Handle(trial_app.Grid_App),
	app: ^trial_app.Grid_App,
	index: int,
) -> testui.Find_Result {
	return find_named(handle, .Table_Row, app.cells[index][0].text)
}

expect_turn_ok :: proc(
	t: ^testing.T,
	status: testui.Status,
	handle: ^testui.Test_Handle(trial_app.Grid_App),
	message: string,
) -> bool {
	if status == .Ok { return expect(t, true, message) }
	return expect(t, false, fmt.tprintf("%s: %s", message, testui.last_turn_diagnostic(handle)))
}

expect_text_visible :: proc(
	t: ^testing.T,
	report: testui.Text_Visibility_Report,
	message: string,
) -> bool {
	if report.ok { return expect(t, true, message) }
	return expect(t, false, fmt.tprintf("%s: %s", message, testui.visible_text_diagnostic(report)))
}

expect_layout_inside :: proc(
	t: ^testing.T,
	report: testui.Layout_Check_Report,
	message: string,
) -> bool {
	if report.ok { return expect(t, true, message) }
	return expect(t, false, fmt.tprintf("%s: %s", message, testui.layout_check_diagnostic(report)))
}

abs32 :: proc(value: f32) -> f32 {
	return -value if value < 0 else value
}

@(test)
test_data_grid_authoring_trial :: proc(t: ^testing.T) {
	trial_assertions = 0
	viewports := [3]Viewport{
		{width=1280, height=800},
		{width=960, height=720},
		{width=760, height=640},
	}
	scales := [4]f32{1.0, 1.25, 1.5, 2.0}
	header_names := [4]string{"Project", "Owner", "Status", "Build"}
	row_zero_cells := [4]string{"Project 000", "Owner 000", "Open 000", "Build 4000"}
	body_roles := [4]alicorn.Semantic_Role{.Table_Row_Header, .Table_Cell, .Table_Cell, .Table_Cell}
	interaction_case_ran := false

	for viewport in viewports {
		for scale in scales {
			app: trial_app.Grid_App
			trial_app.initialize_app(&app)
			handle, status := testui.open(
				&app,
				width=viewport.width,
				height=viewport.height,
				scale=scale,
				initialize=trial_app.initialize_testui,
				build_application=trial_app.grid_build_application,
			)
			opened := status == .Ok && handle.runtime != nil
			if opened {
				_ = expect(t, true, "full application opens at each requested viewport and scale")
			} else {
				_ = expect(t, false, fmt.tprintf("application open failed: %s", testui.last_turn_diagnostic(&handle)))
			}
			if !opened {
				if handle.runtime != nil { testui.close(&handle) }
				continue
			}

			if !expect(t, handle.scale == scale && handle.viewport_width == viewport.width &&
				handle.viewport_height == viewport.height,
				"TestUI retained requested viewport and display scale") {
				testui.close(&handle)
				continue
			}

			grid := find_named(&handle, .Table, "Project directory")
			grid_ok := expect(t, grid.match == .Unique && grid.element.has_bounds,
				"one bounded Project directory table is published")
			if !grid_ok {
				testui.destroy_find_result(&grid)
				testui.close(&handle)
				continue
			}
			grid_inside_viewport := grid.element.bounds.x >= -0.5 && grid.element.bounds.y >= -0.5 &&
				grid.element.bounds.x+grid.element.bounds.w <= f32(viewport.width)+0.5 &&
				grid.element.bounds.y+grid.element.bounds.h <= f32(viewport.height)+0.5
			_ = expect(t, grid_inside_viewport,
				"grid bounds stay within the requested viewport")
			_ = expect(t, grid.element.bounds.w > 0 && grid.element.bounds.h > 0,
				"grid has positive finalized layout bounds")

			for column in 0..<4 {
				header := find_named(&handle, .Table_Column_Header, header_names[column])
				body := find_named(&handle, body_roles[column], row_zero_cells[column])
				parts_unique := header.match == .Unique && body.match == .Unique &&
					header.element.has_bounds && body.element.has_bounds
				if !expect(t, parts_unique,
					"header and first-row cell are both published with bounds") {
					testui.destroy_find_result(&header)
					testui.destroy_find_result(&body)
					continue
				}

				same_track := abs32(header.element.bounds.x-body.element.bounds.x) <= 0.5 &&
					abs32(header.element.bounds.w-body.element.bounds.w) <= 0.5
				_ = expect(t, same_track,
					"header and body use the same column track")

				body_inside := testui.expect_inside(&handle, &body.element, &grid.element, tolerance=0.5)
				_ = expect_layout_inside(t, body_inside, "first-row cell is contained by the grid")

				header_text := testui.expect_visible_text(&handle, &header.element, header_names[column])
				_ = expect_text_visible(t, header_text, "header text has visible retained shaped glyphs")
				body_text := testui.expect_visible_text(&handle, &body.element, row_zero_cells[column])
				_ = expect_text_visible(t, body_text, "cell text has visible retained shaped glyphs")
				testui.destroy_find_result(&header)
				testui.destroy_find_result(&body)
			}

			if !interaction_case_ran && viewport.width == 1280 && viewport.height == 800 && scale == 1.0 {
				interaction_case_ran = true
				_ = expect(t, grid.element.focused,
					"requested focus is on the single grid Tab stop")
				_ = expect(t, grid.element.logical_count == 201,
					"200 body rows plus one header are published")
				_ = expect(t, grid.element.collection_selected_id ==
					data_grid.row_semantic_id(trial_app.TRIAL_GRID_INSTANCE_ID, 1),
					"table collection publishes the caller-accepted selected row")
				_ = expect(t, grid.element.collection_current_id ==
					data_grid.row_semantic_id(trial_app.TRIAL_GRID_INSTANCE_ID, 1),
					"table collection publishes the focused current row")

				selected_cell := find_named(&handle, .Table_Row_Header, "Project 000")
				if expect(t, selected_cell.match == .Unique,
					"selected row-header cell is uniquely published") {
					_ = expect(t, .Selected in selected_cell.element.states && .Current in selected_cell.element.states,
						"accepted cell publishes both Selected and Current")
					visible := testui.expect_visible_text(&handle, &selected_cell.element, "Project 000")
					_ = expect_text_visible(t, visible, "selected text has visible retained shaped glyphs")
				}
				testui.destroy_find_result(&selected_cell)

				disabled_row := find_row(&handle, &app, 1)
				if expect(t, disabled_row.match == .Unique,
					"disabled logical row is semantically published") {
					_ = expect(t, .Disabled in disabled_row.element.states,
						"disabled row publishes Disabled state")
				}
				testui.destroy_find_result(&disabled_row)

				row_199 := find_row(&handle, &app, 199)
				if expect(t, row_199.match == .Unique && row_199.element.is_virtual_item && !row_199.element.has_bounds,
					"offscreen row 199 is published as a virtual semantic row without visual bounds") {
					_ = expect(t, row_199.element.position_in_set == 200 || row_199.element.position_in_set == 201,
						"offscreen semantic row carries its logical collection position")
				}
				testui.destroy_find_result(&row_199)

				semantic_rows := 0
				visual_rows := 0
				virtual_rows := 0
				for index in 0..<trial_app.GRID_ROW_COUNT {
					row := find_row(&handle, &app, index)
					if expect(t, row.match == .Unique,
						"each of the 200 logical rows is semantically published") {
						semantic_rows += 1
						if row.element.has_bounds { visual_rows += 1 }
						if row.element.is_virtual_item { virtual_rows += 1 }
					}
					testui.destroy_find_result(&row)
				}
			_ = expect(t, semantic_rows == 200,
					"all 200 semantic rows are present")
			_ = expect(t, visual_rows > 0 && visual_rows < 100 && virtual_rows > 100,
					"only a bounded visual row window is realized while most rows remain semantic-only")

				status_down := testui.step(&handle, testui.Input{kind=.Key, key=.Down})
				_ = expect_turn_ok(t, status_down, &handle, "Down key turn is accepted")
				testui.destroy_find_result(&grid)
				grid = find_named(&handle, .Table, "Project directory")
				_ = expect(t, grid.match == .Unique && grid.element.collection_current_id ==
					data_grid.row_semantic_id(trial_app.TRIAL_GRID_INSTANCE_ID, 3),
					"Down skips disabled row 1 and moves Current to stable row key 3")
				_ = expect(t, grid.match == .Unique && grid.element.collection_selected_id ==
					data_grid.row_semantic_id(trial_app.TRIAL_GRID_INSTANCE_ID, 1),
					"roving focus does not mutate the accepted selection")
				moved_row := find_row(&handle, &app, 2)
				if expect(t, moved_row.match == .Unique,
					"next enabled row remains published after navigation") {
					_ = expect(t, .Current in moved_row.element.states,
						"current row state follows disabled-row skipping")
				}
				testui.destroy_find_result(&moved_row)

				status_return := testui.step(&handle, testui.Input{kind=.Key, key=.Return})
				_ = expect_turn_ok(t, status_return, &handle, "Return key turn is accepted")
				_ = expect(t, app.activation_count == 1 &&
					app.last_activated_row == 3 && app.last_activated_column == trial_app.GRID_KEY_PROJECT,
					"Return proposes the active row 3 project cell once")
				_ = expect(t, app.selection.row_key == 3 && app.selection.column_key == trial_app.GRID_KEY_PROJECT,
					"application accepts activation into its owned selection")
				testui.destroy_find_result(&grid)
				grid = find_named(&handle, .Table, "Project directory")
				_ = expect(t, grid.match == .Unique && grid.element.collection_selected_id ==
					data_grid.row_semantic_id(trial_app.TRIAL_GRID_INSTANCE_ID, 3),
					"accepted cell selection is published on the collection")
				testui.destroy_find_result(&grid)

				header := find_named(&handle, .Table_Column_Header, "Project")
				if expect(t, header.match == .Unique && header.element.has_bounds,
					"sortable Project header is uniquely published and hit-testable") {
					sort_status := testui.click(&handle, &header.element)
					_ = expect_turn_ok(t, sort_status, &handle, "sort header click is accepted")
					_ = expect(t, app.sort_event_count == 1 &&
						app.last_sorted_column == trial_app.GRID_KEY_PROJECT && app.sort_descending,
						"header activation reaches the app sort callback")
					_ = expect(t, app.columns[0].sort == .Descending,
						"app-owned sort direction is updated from the proposal")
				}
				testui.destroy_find_result(&header)

				filter_button := find_named(&handle, .Button, "Filter: all rows")
				if expect(t, filter_button.match == .Unique && filter_button.element.has_bounds,
					"application-owned filter control is accessible and hit-testable") {
					filter_status := testui.click(&handle, &filter_button.element)
					_ = expect_turn_ok(t, filter_status, &handle, "filter control click is accepted")
					_ = expect(t, app.filter_event_count == 1 && app.only_open,
						"filter activation reaches app callback and enables open-only projection")
				}
				testui.destroy_find_result(&filter_button)
				grid = find_named(&handle, .Table, "Project directory")
				_ = expect(t, grid.match == .Unique && grid.element.logical_count == 101,
					"filter projection publishes 100 rows plus one header")
				testui.destroy_find_result(&grid)

				stable_offscreen := find_row(&handle, &app, 100)
				if expect(t, stable_offscreen.match == .Unique && stable_offscreen.element.is_virtual_item &&
					!stable_offscreen.element.has_bounds,
					"filtered offscreen row is identified by stable key 101") {
					request := alicorn.Semantic_Request_Event{
						kind=.Reveal,
						id=data_grid.row_semantic_id(trial_app.TRIAL_GRID_INSTANCE_ID, 101),
					}
					handled := data_grid.handle_semantic_reveal_request(
						&app.view,
						handle.runtime,
						app.projection[:app.visible_count],
						trial_app.TRIAL_GRID_INSTANCE_ID,
						request,
					)
					_ = expect(t, handled,
						"semantic reveal maps offscreen row by stable key in current projection")
					reveal_status := testui.step(&handle, testui.Input{kind=.Time_Advance, delta_ns=1})
					_ = expect_turn_ok(t, reveal_status, &handle, "reveal settles through normal TestUI description")
					testui.destroy_find_result(&stable_offscreen)
					stable_revealed := find_row(&handle, &app, 100)
					_ = expect(t, stable_revealed.match == .Unique && stable_revealed.element.has_bounds &&
						!stable_revealed.element.is_virtual_item,
						"stable key 101 becomes a realized row with visible bounds")
					testui.destroy_find_result(&stable_revealed)
				} else {
					testui.destroy_find_result(&stable_offscreen)
				}
			}

			testui.destroy_find_result(&grid)
			testui.close(&handle)
		}
	}

	_ = expect(t, interaction_case_ran, "the dedicated interaction and virtualization case ran")
	fmt.printf("DATA_GRID_TRIAL_ASSERTIONS=%d\n", trial_assertions)
}
