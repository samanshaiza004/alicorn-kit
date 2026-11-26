package main

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

initialize_reference_test :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	initialize(cast(^App)data, rt)
}

@(test)
test_reference_adopts_accessibility_filter_value :: proc(t: ^testing.T) {
	app := App{}
	handle, status := testui.open(
		&app,
		render,
		width=980,
		height=640,
		initialize=initialize_reference_test,
	)
	defer stop(&app)
	defer if handle.runtime != nil { testui.close(&handle) }
	if !testing.expectf(t, status == .Ok,
		"the Table reference should open for semantic filter testing: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		return
	}

	filter_node, found := alicorn.node_by_key(handle.runtime,
		ui.key_string("table-example-filter"), .Text_Field)
	if !testing.expect(t, found, "the reference filter should have a retained text-field node") {
		return
	}
	filter_id := alicorn.semantic_visual_id(filter_node)
	queued := alicorn.semantic_action_request(
		handle.runtime, filter_id, .Set_Value, text_value="Document 025")
	if !testing.expect(t, queued, "the semantic filter should accept a Set_Value request") {
		return
	}
	_ = testui.describe_once(&handle)
	testing.expect_value(t, app.query.text, "Document 025")
	testing.expect_value(t, app.visible_count, 1)
	row := testui.find(&handle, testui.Query{
		role=.Table_Row, name="Document 025", match_role=true, match_name=true,
	})
	defer testui.destroy_find_result(&row)
	testing.expect(t, row.match == .Unique, "the filtered row should be visibly published")
}
