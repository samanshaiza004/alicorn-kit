package table

import "core:testing"
import "core:math"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

Test_App :: struct {
	columns: [3]Column,
	rows:    [4]Row,
	cells:   [4][3]Cell,
}

fixture_columns :: proc() -> [3]Column {
	return {
		{key=10, label="Name", width=200, align=.Start},
		{key=20, label="Size", width=90, align=.End},
		{key=30, label="Kind", width=110, align=.Start},
	}
}

fixture_render :: proc(app: ^Test_App, ctx: ^ui.UI) {
	table(ctx, app.columns[:], app.rows[:],
		Options{accessible_label="Files", row_header=true}, key=alicorn.key_string("table-fixture"),
		instance_id=9201)
}

fixture_open :: proc(
	app: ^Test_App,
	t: ^testing.T,
	scale: f32 = 1,
	first_column_width: f32 = 200,
) -> (testui.Test_Handle(Test_App), bool) {
	app.columns = fixture_columns()
	app.columns[0].width = first_column_width
	app.cells = [4][3]Cell{
		{{text="short", detail="one line"}, {text="12 KB"}, {text="file"}},
		{{text="a deliberately long cell value that must wrap across several visual lines", detail="and a detail line"}, {text="3 MB"}, {text="file"}},
		{{text="gamma"}, {text="0 B"}, {text="folder"}},
		{{text="delta"}, {text="8 KB"}, {text="file"}},
	}
	for index in 0..<4 {
		app.rows[index] = Row{key=u64(100+index), cells=app.cells[index][:]}
	}
	handle, status := testui.open(app, fixture_render, width=620, height=420, scale=scale)
	if !testing.expectf(t, status == .Ok, "the static table fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
find_table :: proc(handle: ^testui.Test_Handle(Test_App)) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.Table, name="Files", match_role=true, match_name=true})
}

@(private)
find_role :: proc(handle: ^testui.Test_Handle(Test_App), role: alicorn.Semantic_Role, name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=role, name=name, match_role=true, match_name=true})
}

@(test)
test_static_table_options_reject_non_finite_text_sizes :: proc(t: ^testing.T) {
	resolved := options_resolve(Options{
		header_text_size=math.nan_f32(),
		cell_text_size=math.inf_f32(1),
		detail_text_size=math.nan_f32(),
	})
	testing.expect_value(t, resolved.header_text_size, DEFAULT_OPTIONS.header_text_size)
	testing.expect_value(t, resolved.cell_text_size, DEFAULT_OPTIONS.cell_text_size)
	testing.expect_value(t, resolved.detail_text_size, DEFAULT_OPTIONS.detail_text_size)
}

@(test)
test_static_table_infinite_column_width_keeps_text_flexible :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t, first_column_width=math.inf_f32(1))
	if !ok { return }
	defer testui.close(&handle)

	table_node := find_table(&handle)
	cell := find_role(&handle, .Table_Row_Header, "short")
	if testing.expect(t, table_node.match == .Unique && cell.match == .Unique,
		"the infinite-width column should still realize its first cell") {
		visible := testui.expect_visible_text(&handle, &cell.element, "short")
		inside := testui.expect_inside(&handle, &cell.element, &table_node.element)
		no_overflow := testui.expect_no_overflow(&handle, &cell.element)
		testing.expectf(t, visible.ok && inside.ok && no_overflow.ok,
			"flexible column text should remain visible and contained: %s %s %s",
			testui.visible_text_diagnostic(visible),
			testui.layout_check_diagnostic(inside),
			testui.layout_check_diagnostic(no_overflow))
	}
	testui.destroy_find_result(&table_node)
	testui.destroy_find_result(&cell)
}

@(test)
test_static_table_visible_cells_remain_aligned_at_fractional_scales :: proc(t: ^testing.T) {
	scales := [4]f32{1, 1.25, 1.5, 2}
	for scale in scales {
		app := Test_App{}
		handle, ok := fixture_open(&app, t, scale)
		if !ok { continue }

		table_node := find_table(&handle)
		cell := find_role(&handle, .Table_Cell, "12 KB")
		if testing.expectf(t, table_node.match == .Unique && cell.match == .Unique,
			"the table and visible body cell should be available at %.2f", scale) {
			visible := testui.expect_visible_text(&handle, &cell.element, "12 KB")
			inside := testui.expect_inside(&handle, &cell.element, &table_node.element)
			testing.expectf(t, visible.ok && inside.ok,
				"the body cell should remain visible and inside the table at %.2f: %s %s",
				scale, testui.visible_text_diagnostic(visible), testui.layout_check_diagnostic(inside))
		}
		testui.destroy_find_result(&table_node)
		testui.destroy_find_result(&cell)
		testui.close(&handle)
	}
}

@(test)
test_static_table_identity_tracks_and_theme_contract :: proc(t: ^testing.T) {
	testing.expect(t, table_semantic_id(0).namespace == 0, "instance zero must not publish identity")
	testing.expect(t, row_semantic_id(1, 0).namespace == 0, "row key zero must not publish identity")
	testing.expect(t, cell_semantic_id(1, 2, 3) != cell_semantic_id(1, 3, 2),
		"row and column coordinates must identify distinct cells")

	columns := fixture_columns()
	tracks: [MAX_COLUMNS]alicorn.Grid_Track
	count := tracks_for(columns[:], tracks[:])
	testing.expect_value(t, count, 3)
	testing.expect_value(t, tracks[0].kind, alicorn.Grid_Track_Kind.Fixed)
	testing.expect_value(t, tracks[0].value, f32(200))
	testing.expect_value(t, tracks[1].value, f32(90))

	recipe := Recipe{
		header_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.table", "header"),
	}
	contract := theme_contract_default(recipe)
	testing.expect_value(t, contract.required_count, 1)
	testing.expect_value(t, contract.optional_count, 2)
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 200, 120})
	defer alicorn.destroy_runtime(&rt)
	report := theme_contract_check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	testing.expect(t, !theme_contract_satisfied(report), "a configured role must be validated")
	names, missing := theme_contract_missing_required(contract, report)
	testing.expect(t, missing == 1 && names[0] == "alikit.table.header_surface")
}

@(test)
test_static_table_semantics_wrapped_rows_and_no_managed_focus :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	table_node := find_table(&handle)
	defer testui.destroy_find_result(&table_node)
	if !testing.expect(t, table_node.match == .Unique, "the table should publish one Table") { return }
	testing.expect(t, table_node.element.is_collection && table_node.element.logical_count == 5,
		"the static table publishes a header plus four logical rows")
	testing.expect(t, table_node.element.collection_selected_id.namespace == 0 &&
		table_node.element.collection_current_id.namespace == 0,
		"the static table must not publish a selection or current cell")

	for label, index in ([3]string{"Name", "Size", "Kind"}) {
		header := find_role(&handle, .Table_Column_Header, label)
		if testing.expect(t, header.match == .Unique, "each column header should be unique") {
			testing.expect_value(t, header.element.position_in_set, u64(index))
			testing.expect(t, !alicorn.semantic_actions_has(header.element.actions, .Press),
				"a static header is not a sort control")
		}
		testui.destroy_find_result(&header)
	}

	short_row := find_role(&handle, .Table_Row, "short")
	long_row := find_role(&handle, .Table_Row, "a deliberately long cell value that must wrap across several visual lines")
	if testing.expect(t, short_row.match == .Unique && long_row.match == .Unique,
		"both intrinsic-height rows should be realized") {
		testing.expectf(t, long_row.element.bounds.h > short_row.element.bounds.h + 8,
			"wrapped text and a detail line should grow the row (short=%.1f long=%.1f)",
			short_row.element.bounds.h, long_row.element.bounds.h)
		testing.expect(t, !short_row.element.collection_selected && !short_row.element.collection_current,
			"a static row must not publish Selected or Current")
	}
	testui.destroy_find_result(&short_row)
	testui.destroy_find_result(&long_row)

	cell := find_role(&handle, .Table_Cell, "12 KB")
	if testing.expect(t, cell.match == .Unique, "body cells publish Table_Cell") {
		visible_cell_text := testui.expect_visible_text(&handle, &cell.element, "12 KB")
		testing.expect(t, visible_cell_text.ok, testui.visible_text_diagnostic(visible_cell_text))
		testing.expect(t, !cell.element.collection_selected && !cell.element.collection_current,
			"a static cell must not publish selected/current state")
	}
	testui.destroy_find_result(&cell)

	// No managed navigation: an arrow key changes nothing the component owns.
	before := find_table(&handle)
	before_current := before.element.collection_current_id
	testui.destroy_find_result(&before)
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	after := find_table(&handle)
	testing.expect_value(t, after.element.collection_current_id, before_current)
	testui.destroy_find_result(&after)
}

LARGE_ROW_COUNT :: 200

Large_Fixture :: struct {
	columns: [3]Column,
	rows:    [LARGE_ROW_COUNT]Row,
	cells:   [LARGE_ROW_COUNT][3]Cell,
}

large_render :: proc(fixture: ^Large_Fixture, ctx: ^ui.UI) {
	table(ctx, fixture.columns[:], fixture.rows[:],
		Options{accessible_label="Large files", row_header=true, virtualize=true,
			max_visible_rows=6, virtual_row_height=30},
		key=alicorn.key_string("table-large-fixture"), instance_id=9202)
}

@(test)
test_static_table_optional_virtualization :: proc(t: ^testing.T) {
	fixture := Large_Fixture{columns=fixture_columns()}
	for index in 0..<LARGE_ROW_COUNT {
		fixture.cells[index] = {{text=static_name(index)}, {text="1 KB"}, {text="file"}}
		fixture.rows[index] = Row{key=u64(1000+index), cells=fixture.cells[index][:]}
	}
	handle, status := testui.open(&fixture, large_render, width=620, height=320)
	if !testing.expectf(t, status == .Ok, "the large table fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return
	}
	defer testui.close(&handle)

	table_node := testui.find(&handle, testui.Query{role=.Table, name="Large files", match_role=true, match_name=true})
	if !testing.expect(t, table_node.match == .Unique, "the large table should publish one Table") {
		testui.destroy_find_result(&table_node)
		return
	}
	testing.expect_value(t, table_node.element.logical_count, u64(LARGE_ROW_COUNT+1))
	table_bounds := table_node.element.bounds
	testui.destroy_find_result(&table_node)

	last := testui.find(&handle, testui.Query{role=.Table_Row, name="Row 200", match_role=true, match_name=true})
	if testing.expect(t, last.match == .Unique, "the last logical row should have a virtual semantic item") {
		testing.expect(t, last.element.is_virtual_item,
			"the last row should start outside the realized window")
	}
	testui.destroy_find_result(&last)

	// Wheel scrolling is runtime-owned; the static table opts into a fixed-row
	// virtual window and does not need managed focus to move it.
	for _ in 0..<40 {
		_ = testui.step(&handle, testui.Input{kind=.Scroll, scroll=alicorn.Scroll_Event{
			x=table_bounds.x+40, y=table_bounds.y+40, delta_y=-120,
		}})
	}
	last = testui.find(&handle, testui.Query{role=.Table_Row, name="Row 200", match_role=true, match_name=true})
	if testing.expect(t, last.match == .Unique, "the last row should remain published") {
		testing.expect(t, !last.element.is_virtual_item,
			"scrolling to the end should realize the last logical row")
	}
	testui.destroy_find_result(&last)
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
