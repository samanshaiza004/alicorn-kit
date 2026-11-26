package data_grid

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

Test_App :: struct {
	state:     State,
	columns:   [3]Column,
	rows:      [6]Row,
	cells:     [6][3]Cell,
	selection: Selection,
	events:    int,
	last_row:  u64,
	last_col:  u64,
	last_sort: u64,
}

fixture_columns :: proc() -> [3]Column {
	return {
		{key=10, label="Name", align=.Start, sortable=true, sort=.Ascending},
		{key=20, label="Size", width=90, align=.End},
		{key=30, label="Kind", width=70, align=.Start},
	}
}

fixture_render :: proc(app: ^Test_App, ctx: ^ui.UI) {
	event := data_grid(
		ctx,
		&app.state,
		app.columns[:],
		app.rows[:],
		app.selection,
		Options{accessible_label="Files", row_header=true, max_visible_rows=5},
		key=alicorn.key_string("grid-fixture"),
		instance_id=9101,
	)
	if event.kind == .Sort_Proposed {
		app.last_sort = event.column_key
		app.events += 1
	} else if event.kind == .Activated {
		app.selection.row_key = event.row_key
		app.selection.column_key = event.column_key
		app.last_row = event.row_key
		app.last_col = event.column_key
		app.events += 1
	}
}

fixture_open :: proc(app: ^Test_App, t: ^testing.T) -> (testui.Test_Handle(Test_App), bool) {
	app.columns = fixture_columns()
	app.cells = [6][3]Cell{
		{{text="alpha"}, {text="12 KB"}, {text="file"}},
		{{text="beta"}, {text="3 MB"}, {text="file"}},
		{{text="gamma"}, {text="0 B"}, {text="folder"}},
		{{text="delta"}, {text="8 KB"}, {text="file"}},
		{{text="epsilon"}, {text="1 MB"}, {text="folder"}},
		{{text="zeta"}, {text="5 KB"}, {text="file"}},
	}
	for index in 0..<6 {
		app.rows[index] = Row{key=u64(100+index), cells=app.cells[index][:]}
	}
	app.rows[2].disabled = true
	app.selection = Selection{row_key=103, column_key=20}
	_ = request_focus(&app.state)
	handle, status := testui.open(app, fixture_render, width=620, height=360)
	if !testing.expectf(t, status == .Ok, "the table fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
find_grid :: proc(handle: ^testui.Test_Handle(Test_App)) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.Table, name="Files", match_role=true, match_name=true})
}

@(private)
find_role :: proc(handle: ^testui.Test_Handle($T), role: alicorn.Semantic_Role, name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=role, name=name, match_role=true, match_name=true})
}

@(test)
test_table_identity_tracks_and_theme_contract :: proc(t: ^testing.T) {
	testing.expect(t, grid_semantic_id(0).namespace == 0, "instance zero must not publish identity")
	testing.expect(t, row_semantic_id(1, 0).namespace == 0, "row key zero must not publish identity")
	testing.expect(t, cell_semantic_id(1, 2, 3) != cell_semantic_id(1, 3, 2),
		"row and column coordinates must identify distinct cells")

	columns := fixture_columns()
	tracks: [MAX_COLUMNS]alicorn.Grid_Track
	count := tracks_for(columns[:], tracks[:])
	testing.expect_value(t, count, 3)
	testing.expect_value(t, tracks[0].kind, alicorn.Grid_Track_Kind.Fraction)
	testing.expect_value(t, tracks[1].kind, alicorn.Grid_Track_Kind.Fixed)
	testing.expect_value(t, tracks[1].value, f32(90))

	recipe := Recipe{
		header_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.data_grid", "header"),
	}
	contract := theme_contract_default(recipe)
	testing.expect_value(t, contract.required_count, 1)
	testing.expect_value(t, contract.optional_count, 3)
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 200, 120})
	defer alicorn.destroy_runtime(&rt)
	report := theme_contract_check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	testing.expect(t, !theme_contract_satisfied(report), "a configured role must be validated")
	names, missing := theme_contract_missing_required(contract, report)
	testing.expect(t, missing == 1 && names[0] == "alikit.data_grid.header_surface")
}

@(test)
test_table_semantics_headers_coordinates_and_navigation :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	grid_node := find_grid(&handle)
	defer testui.destroy_find_result(&grid_node)
	if !testing.expect(t, grid_node.match == .Unique, "the grid should publish one Table") { return }
	testing.expect(t, grid_node.element.is_collection && grid_node.element.logical_count == 7,
		"the grid should publish a header plus six rows")
	testing.expect_value(t, grid_node.element.collection_selected_id, row_semantic_id(9101, 103))

	for label, index in ([3]string{"Name", "Size", "Kind"}) {
		header := find_role(&handle, .Table_Column_Header, label)
		if testing.expect(t, header.match == .Unique, "each column header should be unique") {
			testing.expect_value(t, header.element.position_in_set, u64(index))
			testing.expect_value(t, header.element.parent_semantic_id, header_row_semantic_id(9101))
		}
		testui.destroy_find_result(&header)
	}

	delta := find_role(&handle, .Table_Row, "delta")
	if !testing.expect(t, delta.match == .Unique, "the delta row should be realized") { return }
	testing.expectf(t, !delta.element.is_virtual_item, "the active row should be realized (window=%d..%d)",
		app.state.last_first, app.state.last_last)
	testing.expect(t, delta.element.collection_selected, "the selected row should publish Selected")
	testing.expect(t, delta.element.collection_current, "the active row should publish Current")
	testing.expect_value(t, delta.element.position_in_set, u64(4))
	testui.destroy_find_result(&delta)

	row_header := find_role(&handle, .Table_Row_Header, "delta")
	selected_cell := find_role(&handle, .Table_Cell, "8 KB")
	if testing.expect(t, row_header.match == .Unique, "the first body cell should be a row header") {
		testing.expect_value(t, row_header.element.position_in_set, u64(0))
		testing.expect(t, row_header.element.collection_selected == false,
			"the row header is not the selected Size cell")
	}
	if testing.expect(t, selected_cell.match == .Unique, "the selected Size cell should be realized") {
		testing.expect_value(t, selected_cell.element.position_in_set, u64(1))
		testing.expect(t, selected_cell.element.collection_selected && selected_cell.element.collection_current,
			"the selected cell should also be Current at its coordinate")
	}
	testui.destroy_find_result(&row_header)
	testui.destroy_find_result(&selected_cell)

	// Up from delta/Size skips the disabled gamma row and stays in Size.
	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Up}) == .Ok, "Up should be scoped") { return }
	testing.expect_value(t, app.state.active_row_key, u64(101))
	testing.expect_value(t, app.state.active_column_key, u64(20))
	// Down reaches delta again; End moves to Kind in the active row.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, app.state.active_row_key, u64(103))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.End})
	testing.expect_value(t, app.state.active_column_key, u64(30))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Home})
	testing.expect_value(t, app.state.active_column_key, u64(10))

	// Return proposes the active cell; the application accepts it as selection.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Return})
	testing.expect_value(t, app.last_row, u64(103))
	testing.expect_value(t, app.last_col, u64(10))
	testing.expect_value(t, app.selection.column_key, u64(10))

	// Pointer activation of the active row's Size cell proposes the same
	// coordinates as keyboard activation.
	delta_size := find_role(&handle, .Table_Cell, "8 KB")
	if testing.expect(t, delta_size.match == .Unique, "delta's Size cell should be realized") {
		click := testui.click(&handle, &delta_size.element)
		testing.expectf(t, click == .Ok, "the delta Size cell should accept a click: %v", click)
		testing.expectf(t, app.last_row == 103 && app.last_col == 20,
			"pointer activation should propose delta/Size, got %d/%d", app.last_row, app.last_col)
	}
	testui.destroy_find_result(&delta_size)

	// Disabled gamma cells do not activate.
	gamma := find_role(&handle, .Table_Row, "gamma")
	if testing.expect(t, gamma.match == .Unique, "the disabled row should be published") {
		testing.expect(t, alicorn.semantic_states_has(gamma.element.states, .Disabled),
			"the disabled row should publish Disabled")
	}
	testui.destroy_find_result(&gamma)
}

LARGE_ROW_COUNT :: 200

Large_Fixture :: struct {
	state:          State,
	columns:        []Column,
	rows:           []Row,
	sort_proposals: int,
	last_sort:      u64,
}

large_render :: proc(fixture: ^Large_Fixture, ctx: ^ui.UI) {
	visible_rows := clamp(int((ctx.runtime.viewport.h-350)/48), 4, 8)
	if ui.column(ctx, key=ui.key_string("grid-large-root"), width=-1, height=-1,
		padding=16, gap=12) {
		_ = ui.text(ctx, "Projects", size=24)
		if ui.panel(ctx, key=ui.key_string("grid-large-panel"), width=-1, height=-1,
			grow=1, padding=8, gap=8, fill=ui.style_color(ctx, .Surface), radius=8,
			stroke=ui.border(1, ui.style_color(ctx, .Border), .Inside)) {
			event := data_grid(ctx, &fixture.state, fixture.columns, fixture.rows,
				Selection{row_key=1000, column_key=10},
				Options{accessible_label="Files", row_header=true,
					max_visible_rows=visible_rows, row_height=48, header_height=42},
				key=alicorn.key_string("grid-large-fixture"), instance_id=9102)
			if event.kind == .Sort_Proposed {
				fixture.sort_proposals += 1
				fixture.last_sort = event.column_key
			}
		}
	}
}

check_large_grid_geometry :: proc(
	t: ^testing.T,
	handle: ^testui.Test_Handle(Large_Fixture),
	fixture: ^Large_Fixture,
) {
	grid_node := testui.find(handle, testui.Query{role=.Table, name="Files", match_role=true, match_name=true})
	defer testui.destroy_find_result(&grid_node)
	if !testing.expect(t, grid_node.match == .Unique, "the reference scene should publish one Data Grid") { return }
	first_row := find_role(handle, .Table_Row, "Row 1")
	defer testui.destroy_find_result(&first_row)
	if !testing.expect(t, first_row.match == .Unique, "the first row should be realized in the viewport") { return }
	list_info, list_found := alicorn.node_info(handle.runtime, fixture.state.list_node)
	if !testing.expect(t, list_found && list_info.scroll_geometry_resolved,
		"the virtualized body should expose resolved scroll geometry") { return }
	viewport := list_info.scroll_viewport_bounds
	row_bounds := first_row.element.bounds
	row_visible := row_bounds.x >= viewport.x-0.5 && row_bounds.y >= viewport.y-0.5 &&
		row_bounds.x+row_bounds.w <= viewport.x+viewport.w+0.5 &&
		row_bounds.y+row_bounds.h <= viewport.y+viewport.h+0.5
	testing.expect(t, row_visible,
		"the realized row should remain inside the clipped virtual-list viewport")
	table_contains_row := testui.expect_inside(handle, &first_row.element, &grid_node.element)
	testing.expect(t, table_contains_row.ok,
		"the semantic Table bounds should contain its visible virtualized rows")

	name_header := find_role(handle, .Table_Column_Header, "Name")
	defer testui.destroy_find_result(&name_header)
	name_cell := find_role(handle, .Table_Row_Header, "Row 1")
	defer testui.destroy_find_result(&name_cell)
	header_row := find_role(handle, .Table_Row, "Columns")
	defer testui.destroy_find_result(&header_row)
	if !testing.expect(t, name_header.match == .Unique && name_cell.match == .Unique,
		"the first shared column should expose its header and first row cell") { return }
	if testing.expect(t, header_row.match == .Unique, "the full header track should be exposed") {
		left_viewport := testui.expect_aligned(handle, &header_row.element, &first_row.element, .Left)
		testing.expect(t, left_viewport.ok, testui.layout_check_diagnostic(left_viewport))
		// The header paint stays full width, while its tracks reserve the body's
		// actual scrollbar viewport. Short datasets should have no empty gutter.
		expected_gutter := f32(0)
		if list_info.scroll_content_height > list_info.scroll_viewport_height {
			expected_gutter = alicorn.SCROLLBAR_THICKNESS
		}
		width_difference := header_row.element.bounds.w-first_row.element.bounds.w
		width_error := width_difference-expected_gutter
		if width_error < 0 { width_error = -width_error }
		testing.expectf(t, width_error <= 0.5,
			"header background should extend the body track by the active gutter %.2f; difference=%.2f",
			expected_gutter, width_difference)
	}
	left_track := testui.expect_aligned(handle, &name_cell.element, &name_header.element, .Left)
	testing.expect(t, left_track.ok, testui.layout_check_diagnostic(left_track))
	right_track := testui.expect_aligned(handle, &name_cell.element, &name_header.element, .Right)
	testing.expect(t, right_track.ok, testui.layout_check_diagnostic(right_track))
	cell_inside_row := testui.expect_inside(handle, &name_cell.element, &first_row.element)
	testing.expect(t, cell_inside_row.ok, testui.layout_check_diagnostic(cell_inside_row))
	visible := testui.expect_visible_text(handle, &name_cell.element, "Row 1")
	testing.expect(t, visible.ok, testui.visible_text_diagnostic(visible))
}

@(test)
test_reference_grid_layout_is_stable_across_fractional_scales :: proc(t: ^testing.T) {
	columns := fixture_columns()
	cells: [LARGE_ROW_COUNT][3]Cell
	rows: [LARGE_ROW_COUNT]Row
	for index in 0..<LARGE_ROW_COUNT {
		cells[index] = {{text=fixture_row_name(index)}, {text="1 KB"}, {text="file"}}
		rows[index] = Row{key=u64(1000+index), cells=cells[index][:]}
	}
	scales := [4]f32{1, 1.25, 1.5, 2}
	for scale in scales {
		fixture := Large_Fixture{columns=columns[:], rows=rows[:]}
		_ = request_focus(&fixture.state)
		handle, status := testui.open(&fixture, large_render, width=1280, height=800, scale=scale)
		if !testing.expectf(t, status == .Ok, "the grid should open at scale %.2f: %v %s",
			scale, status, testui.last_turn_diagnostic(&handle)) {
			if handle.runtime != nil { testui.close(&handle) }
			continue
		}
		check_large_grid_geometry(t, &handle, &fixture)
		testui.close(&handle)
	}
}

@(test)
test_short_dataset_does_not_reserve_scrollbar_gutter :: proc(t: ^testing.T) {
	columns := fixture_columns()
	cells: [3][3]Cell
	rows: [3]Row
	for index in 0..<3 {
		cells[index] = {{text=fixture_row_name(index)}, {text="1 KB"}, {text="file"}}
		rows[index] = Row{key=u64(1000+index), cells=cells[index][:]}
	}
	fixture := Large_Fixture{columns=columns[:], rows=rows[:], state={}}
	_ = request_focus(&fixture.state)
	handle, status := testui.open(&fixture, large_render, width=1280, height=800)
	if !testing.expectf(t, status == .Ok, "the short grid fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return
	}
	defer testui.close(&handle)
	check_large_grid_geometry(t, &handle, &fixture)
}

Header_Identity_Probe :: struct {
	focus_owner: alicorn.Node_ID,
	surface:    alicorn.Node_ID,
	grid:       alicorn.Node_ID,
	name_cell:  alicorn.Node_ID,
	name_text:  alicorn.Node_ID,
	header_semantic: alicorn.Semantic_ID,
	cell_semantic:   alicorn.Semantic_ID,
}

@(private)
probe_header_identity :: proc(
	t: ^testing.T,
	handle: ^testui.Test_Handle(Large_Fixture),
) -> (probe: Header_Identity_Probe, ok: bool) {
	header_row := find_role(handle, .Table_Row, "Columns")
	if !testing.expect(t, header_row.match == .Unique, "the header row should stay published") {
		testui.destroy_find_result(&header_row)
		return
	}
	probe.surface = header_row.element.visual_node
	probe.header_semantic = header_row.element.semantic_id
	testui.destroy_find_result(&header_row)
	probe.focus_owner, _ = alicorn.node_by_key(handle.runtime,
		ui.key_string("alikit-data-grid-root"), .Container)

	name_header := find_role(handle, .Table_Column_Header, "Name")
	if !testing.expect(t, name_header.match == .Unique, "the Name header should stay published") {
		testui.destroy_find_result(&name_header)
		return
	}
	probe.name_cell = name_header.element.visual_node
	probe.cell_semantic = name_header.element.semantic_id
	testui.destroy_find_result(&name_header)

	probe.grid, _ = alicorn.node_by_key(handle.runtime, ui.key_u64(0xA11C_6A11), .Grid)
	probe.name_text, _ = alicorn.node_by_key(handle.runtime,
		ui.key_pair(0xA11C_6A04, 10), .Text)
	ok = probe.focus_owner != 0 && probe.surface != 0 && probe.grid != 0 &&
		probe.name_cell != 0 && probe.name_text != 0
	testing.expect(t, ok, "the grid focus owner and header parts should have retained nodes")
	return
}

@(test)
test_header_identity_survives_scrollbar_gutter_transitions :: proc(t: ^testing.T) {
	columns := fixture_columns()
	cells: [9][3]Cell
	rows: [9]Row
	for index in 0..<len(rows) {
		cells[index] = {{text=fixture_row_name(index)}, {text="1 KB"}, {text="file"}}
		rows[index] = Row{key=u64(1000+index), cells=cells[index][:]}
	}
	fixture := Large_Fixture{columns=columns[:], rows=rows[:]}
	_ = request_focus(&fixture.state)
	handle, status := testui.open(&fixture, large_render, width=1280, height=800)
	if !testing.expectf(t, status == .Ok, "the scrollbar transition fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return
	}
	defer testui.close(&handle)

	before, before_ok := probe_header_identity(t, &handle)
	if !before_ok { return }
	if !testing.expect(t, alicorn.focused_node(handle.runtime) == before.focus_owner,
		"the Data Grid should begin with focus on its stable root owner") { return }
	before_grid_info, before_grid_found := alicorn.node_info(handle.runtime, before.grid)
	_, gutter_present := alicorn.node_by_key(handle.runtime,
		ui.key_string("alikit-table-header-scrollbar-gutter"), .Container)
	if !testing.expect(t, before_grid_found && before_grid_info.parent != before.surface && gutter_present,
		"nine rows should place header tracks inside the slot before its gutter") { return }
	name_header := find_role(&handle, .Table_Column_Header, "Name")
	if !testing.expect(t, name_header.match == .Unique,
		"the sortable header should be available before changing the gutter") {
		testui.destroy_find_result(&name_header)
		return
	}
	header_owner := name_header.element.visual_node
	header_bounds := name_header.element.bounds
	move_status := testui.step(&handle, testui.Input{kind=.Pointer, pointer=alicorn.Pointer_Event{
		kind=.Move,
		x=header_bounds.x+header_bounds.w*0.5,
		y=header_bounds.y+header_bounds.h*0.5,
	}})
	if !testing.expectf(t, move_status == .Ok,
		"the pointer should hover the sortable header before transition: %v", move_status) {
		testui.destroy_find_result(&name_header)
		return
	}
	if !testing.expect(t, alicorn.visual_part_owner_hovered(handle.runtime, header_owner),
		"the sortable header should enter its hovered state before transition") {
		testui.destroy_find_result(&name_header)
		return
	}
	testui.destroy_find_result(&name_header)

	// Eight rows exactly fill the configured viewport, so the scrollbar and
	// conditional header wrappers should disappear without replacing the header.
	fixture.rows = rows[:8]
	alicorn.invalidate_root(handle.runtime, "data-grid scrollbar removed at viewport capacity")
	if !testing.expect(t, testui.describe_once(&handle), "the no-scroll frame should describe") { return }
	after, after_ok := probe_header_identity(t, &handle)
	if !after_ok { return }
	after_grid_info, after_grid_found := alicorn.node_info(handle.runtime, after.grid)
	_, gutter_present = alicorn.node_by_key(handle.runtime,
		ui.key_string("alikit-table-header-scrollbar-gutter"), .Container)
	testing.expect(t, after_grid_found && after_grid_info.parent == after.surface && !gutter_present,
		"eight rows should remove the slot and gutter and attach tracks directly to the header surface")
	testing.expect(t, before.surface == after.surface,
		"the retained header surface should keep its identity")
	testing.expect(t, before.header_semantic == after.header_semantic &&
		before.cell_semantic == after.cell_semantic,
		"semantic header identities should remain stable across the parent change")
	testing.expect(t, before.grid == after.grid,
		"the header track grid should keep its identity across the parent change")
	testing.expect(t, before.name_cell == after.name_cell,
		"the sortable header cell should keep its identity across the parent change")
	testing.expect(t, before.name_text == after.name_text,
		"the header label should keep its identity across the parent change")
	testing.expect(t, before.focus_owner == after.focus_owner &&
		alicorn.focused_node(handle.runtime) == before.focus_owner,
		"removing the scrollbar gutter should preserve keyboard focus on the grid")
	testing.expect(t, alicorn.visual_part_owner_hovered(handle.runtime, after.name_cell),
		"removing the scrollbar gutter should preserve hover on the sortable header owner")

	name_header = find_role(&handle, .Table_Column_Header, "Name")
	if testing.expect(t, name_header.match == .Unique,
		"the sortable header should remain available after the gutter disappears") {
		click := testui.click(&handle, &name_header.element)
		testing.expectf(t, click == .Ok, "the transitioned header should still accept clicks: %v", click)
		testing.expect(t, fixture.sort_proposals == 1 && fixture.last_sort == 10,
			"the transitioned header should still propose sorting its stable Name column")
	}
	testui.destroy_find_result(&name_header)

	fixture.rows = rows[:9]
	alicorn.invalidate_root(handle.runtime, "data-grid scrollbar restored beyond viewport capacity")
	if !testing.expect(t, testui.describe_once(&handle), "the scrolling frame should describe again") { return }
	restored, restored_ok := probe_header_identity(t, &handle)
	if !restored_ok { return }
	restored_grid_info, restored_grid_found := alicorn.node_info(handle.runtime, restored.grid)
	testing.expect(t, restored_grid_found && restored_grid_info.parent == before_grid_info.parent,
		"the restored header should reuse the original slot node")
	testing.expect(t, before.surface == restored.surface,
		"the header surface should keep its identity when scrolling returns")
	testing.expect(t, before.grid == restored.grid,
		"the header track grid should keep its identity when scrolling returns")
	testing.expect(t, before.name_cell == restored.name_cell,
		"the sortable header should keep its identity when scrolling returns")
	testing.expect(t, before.name_text == restored.name_text,
		"the header label should keep its identity when scrolling returns")
	testing.expect(t, before.focus_owner == restored.focus_owner &&
		alicorn.focused_node(handle.runtime) == before.focus_owner,
		"restoring the scrollbar gutter should preserve keyboard focus on the grid")
	testing.expect(t, alicorn.visual_part_owner_hovered(handle.runtime, restored.name_cell),
		"restoring the scrollbar gutter should preserve hover on the sortable header owner")
	name_header = find_role(&handle, .Table_Column_Header, "Name")
	if testing.expect(t, name_header.match == .Unique,
		"the sortable header should remain available after the gutter returns") {
		click := testui.click(&handle, &name_header.element)
		testing.expectf(t, click == .Ok, "the restored header should still accept clicks: %v", click)
		testing.expect(t, fixture.sort_proposals == 2 && fixture.last_sort == 10,
			"the restored header should still propose sorting its stable Name column")
	}
	testui.destroy_find_result(&name_header)
}

@(test)
test_table_virtualizes_and_reveals_large_rows :: proc(t: ^testing.T) {
	columns := fixture_columns()
	cells: [LARGE_ROW_COUNT][3]Cell
	rows: [LARGE_ROW_COUNT]Row
	for index in 0..<LARGE_ROW_COUNT {
		cells[index] = {{text=fixture_row_name(index)}, {text="1 KB"}, {text="file"}}
		rows[index] = Row{key=u64(1000+index), cells=cells[index][:]}
	}
	fixture := Large_Fixture{columns=columns[:], rows=rows[:]}
	_ = request_focus(&fixture.state)
	handle, status := testui.open(&fixture, large_render, width=1280, height=800)
	if !testing.expectf(t, status == .Ok, "the large grid fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return
	}
	defer testui.close(&handle)
	check_large_grid_geometry(t, &handle, &fixture)

	grid_node := testui.find(&handle, testui.Query{role=.Table, name="Files", match_role=true, match_name=true})
	if !testing.expect(t, grid_node.match == .Unique, "the large grid should publish one Table") {
		testui.destroy_find_result(&grid_node)
		return
	}
	testing.expect_value(t, grid_node.element.logical_count, u64(LARGE_ROW_COUNT+1))
	testui.destroy_find_result(&grid_node)
	last := testui.find(&handle, testui.Query{role=.Table_Row, name="Row 200", match_role=true, match_name=true})
	if testing.expect(t, last.match == .Unique, "the last logical row should have a virtual semantic item") {
		testing.expect(t, last.element.is_virtual_item,
			"the last row should start outside the realized window")
	}
	testui.destroy_find_result(&last)

	viewports := [3][2]int{{1280, 800}, {960, 720}, {760, 640}}
	for viewport in viewports {
		width, height := viewport[0], viewport[1]
		if handle.viewport_width != width || handle.viewport_height != height {
			resize_status := testui.resize(&handle, width, height)
			testing.expectf(t, resize_status == .Ok,
				"the grid should complete resize to %dx%d: %v", width, height, resize_status)
		}
		check_large_grid_geometry(t, &handle, &fixture)
	}

	for _ in 0..<40 {
		_ = testui.step(&handle, testui.Input{kind=.Key, key=.Page_Down})
	}
	testing.expect_value(t, fixture.state.active_row_index, LARGE_ROW_COUNT-1)
	_ = testui.describe_once(&handle)
	last = testui.find(&handle, testui.Query{role=.Table_Row, name="Row 200", match_role=true, match_name=true})
	if testing.expect(t, last.match == .Unique, "the last row should remain published") {
		testing.expect(t, !last.element.is_virtual_item,
			"paging to the end should realize the last logical row")
	}
	testui.destroy_find_result(&last)
}

fixture_row_name :: proc(index: int) -> string {
	return static_name(index)
}

@(private)
static_name :: proc(index: int) -> string {
	names := [200]string{
		"Row 1", "Row 2", "Row 3", "Row 4", "Row 5", "Row 6", "Row 7", "Row 8",
		"Row 9", "Row 10", "Row 11", "Row 12", "Row 13", "Row 14", "Row 15", "Row 16",
		"Row 17", "Row 18", "Row 19", "Row 20", "Row 21", "Row 22", "Row 23", "Row 24",
		"Row 25", "Row 26", "Row 27", "Row 28", "Row 29", "Row 30", "Row 31", "Row 32",
		"Row 33", "Row 34", "Row 35", "Row 36", "Row 37", "Row 38", "Row 39", "Row 40",
		"Row 41", "Row 42", "Row 43", "Row 44", "Row 45", "Row 46", "Row 47", "Row 48",
		"Row 49", "Row 50", "Row 51", "Row 52", "Row 53", "Row 54", "Row 55", "Row 56",
		"Row 57", "Row 58", "Row 59", "Row 60", "Row 61", "Row 62", "Row 63", "Row 64",
		"Row 65", "Row 66", "Row 67", "Row 68", "Row 69", "Row 70", "Row 71", "Row 72",
		"Row 73", "Row 74", "Row 75", "Row 76", "Row 77", "Row 78", "Row 79", "Row 80",
		"Row 81", "Row 82", "Row 83", "Row 84", "Row 85", "Row 86", "Row 87", "Row 88",
		"Row 89", "Row 90", "Row 91", "Row 92", "Row 93", "Row 94", "Row 95", "Row 96",
		"Row 97", "Row 98", "Row 99", "Row 100", "Row 101", "Row 102", "Row 103", "Row 104",
		"Row 105", "Row 106", "Row 107", "Row 108", "Row 109", "Row 110", "Row 111", "Row 112",
		"Row 113", "Row 114", "Row 115", "Row 116", "Row 117", "Row 118", "Row 119", "Row 120",
		"Row 121", "Row 122", "Row 123", "Row 124", "Row 125", "Row 126", "Row 127", "Row 128",
		"Row 129", "Row 130", "Row 131", "Row 132", "Row 133", "Row 134", "Row 135", "Row 136",
		"Row 137", "Row 138", "Row 139", "Row 140", "Row 141", "Row 142", "Row 143", "Row 144",
		"Row 145", "Row 146", "Row 147", "Row 148", "Row 149", "Row 150", "Row 151", "Row 152",
		"Row 153", "Row 154", "Row 155", "Row 156", "Row 157", "Row 158", "Row 159", "Row 160",
		"Row 161", "Row 162", "Row 163", "Row 164", "Row 165", "Row 166", "Row 167", "Row 168",
		"Row 169", "Row 170", "Row 171", "Row 172", "Row 173", "Row 174", "Row 175", "Row 176",
		"Row 177", "Row 178", "Row 179", "Row 180", "Row 181", "Row 182", "Row 183", "Row 184",
		"Row 185", "Row 186", "Row 187", "Row 188", "Row 189", "Row 190", "Row 191", "Row 192",
		"Row 193", "Row 194", "Row 195", "Row 196", "Row 197", "Row 198", "Row 199", "Row 200",
	}
	if index < 0 || index >= len(names) { return "Row" }
	return names[index]
}

@(test)
test_data_grid_sort_column_proposal_and_header_state :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	name_header := find_role(&handle, .Table_Column_Header, "Name")
	if !testing.expect(t, name_header.match == .Unique, "the sortable Name header should be realized") { return }
	testing.expect_value(t, name_header.element.description, "Sorted ascending")
	testing.expect(t, alicorn.semantic_actions_has(name_header.element.actions, .Press),
		"a sortable header should advertise Press")
	events_before := app.events
	status := testui.click(&handle, &name_header.element)
	testing.expectf(t, status == .Ok, "the sortable header should accept a click: %v", status)
	testing.expect_value(t, app.last_sort, u64(10))
	testing.expect_value(t, app.events, events_before+1)
	testui.destroy_find_result(&name_header)

	size_header := find_role(&handle, .Table_Column_Header, "Size")
	if testing.expect(t, size_header.match == .Unique, "the non-sortable Size header should be realized") {
		testing.expect(t, !alicorn.semantic_actions_has(size_header.element.actions, .Press),
			"a non-sortable header must not advertise Press")
	}
	testui.destroy_find_result(&size_header)
}
