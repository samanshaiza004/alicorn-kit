package main

import "core:testing"
import alicorn "alicorn:runtime"
import palette "alikit:command_palette"
import testui "alicorn:testui"

test_key_adapter :: proc(data: rawptr, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	return on_key(cast(^App)data, rt, key)
}

test_text_change_adapter :: proc(data: rawptr, rt: ^alicorn.Runtime, change: alicorn.Text_Change) {
	on_text_change(cast(^App)data, rt, change)
}

open_reference :: proc(
	app: ^App,
	width, height: int,
	scale: f32,
) -> (testui.Test_Handle(App), testui.Status) {
	return testui.open(
		app,
		render,
		width=width,
		height=height,
		scale=scale,
		initialize=test_initialize_palette,
		render_overlays=render_overlays,
		on_key=test_key_adapter,
		on_text_change=test_text_change_adapter,
	)
}

find_unique :: proc(
	t: ^testing.T,
	handle: ^testui.Test_Handle(App),
	role: alicorn.Semantic_Role,
	name: string,
) -> testui.Find_Result {
	result := testui.find(handle, testui.Query{role=role, name=name, match_role=true, match_name=true})
	testing.expect(t, result.status == .Ok && result.match == .Unique,
		"expected a unique accessible element")
	return result
}

expect_visible :: proc(
	t: ^testing.T,
	handle: ^testui.Test_Handle(App),
	role: alicorn.Semantic_Role,
	name, expected: string,
) {
	result := find_unique(t, handle, role, name)
	visible := testui.expect_visible_text(handle, &result.element, expected)
	testing.expect(t, visible.ok, testui.visible_text_diagnostic(visible))
	testui.destroy_find_result(&result)
}

expect_inside_dialog :: proc(
	t: ^testing.T,
	handle: ^testui.Test_Handle(App),
	role: alicorn.Semantic_Role,
	name: string,
) {
	panel := find_unique(t, handle, .Dialog, "Quick actions")
	element := find_unique(t, handle, role, name)
	check := testui.expect_inside(handle, &element.element, &panel.element)
	testing.expect(t, check.ok, testui.layout_check_diagnostic(check))
	testui.destroy_find_result(&element)
	testui.destroy_find_result(&panel)
}

expect_palette_snapshot :: proc(t: ^testing.T, handle: ^testui.Test_Handle(App)) {
	panel := find_unique(t, handle, .Dialog, "Quick actions")
	query := find_unique(t, handle, .Text_Field, "Search actions")
	query_row := find_unique(t, handle, .Group, "Search input")
	editor := find_unique(t, handle, .Group, "Query editor")
	list := find_unique(t, handle, .List_Box, "Actions")
	first := find_unique(t, handle, .List_Box_Option, "Export workspace")
	second := find_unique(t, handle, .List_Box_Option, "Export selected project")
	third := find_unique(t, handle, .List_Box_Option, "Open export settings")

	testing.expect(t, query.element.value == "export", "initial query should be committed and accessible")
	testing.expect(t, query.element.focused, "query should receive focus when the palette opens")
	testing.expect(t, list.element.logical_count == 3, "the export query should show three actions")
	testing.expect(t, first.element.collection_selected, "first matching action should be selected initially")
	query_fill := testui.expect_fills_width(handle, &query.element, &editor.element)
	testing.expect(t, query_fill.ok, testui.layout_check_diagnostic(query_fill))
	query_row_inside := testui.expect_inside(handle, &editor.element, &query_row.element)
	testing.expect(t, query_row_inside.ok, testui.layout_check_diagnostic(query_row_inside))

	first_check := testui.expect_inside(handle, &first.element, &panel.element)
	testing.expect(t, first_check.ok, testui.layout_check_diagnostic(first_check))
	second_check := testui.expect_inside(handle, &second.element, &panel.element)
	testing.expect(t, second_check.ok, testui.layout_check_diagnostic(second_check))
	third_check := testui.expect_inside(handle, &third.element, &panel.element)
	testing.expect(t, third_check.ok, testui.layout_check_diagnostic(third_check))
	check_list := testui.expect_inside(handle, &list.element, &panel.element)
	testing.expect(t, check_list.ok, testui.layout_check_diagnostic(check_list))

	visible_query := testui.expect_visible_text(handle, &query.element, "export")
	testing.expect(t, visible_query.ok, testui.visible_text_diagnostic(visible_query))
	visible_title := testui.expect_visible_text(handle, &first.element, "Export workspace")
	testing.expect(t, visible_title.ok, testui.visible_text_diagnostic(visible_title))
	visible_desc := testui.expect_visible_text(handle, &first.element, "Create a local archive")
	testing.expect(t, visible_desc.ok, testui.visible_text_diagnostic(visible_desc))
	visible_shortcut := testui.expect_visible_text(handle, &first.element, "CMD  E")
	testing.expect(t, visible_shortcut.ok, testui.visible_text_diagnostic(visible_shortcut))
	visible_count := testui.expect_visible_text(handle, &panel.element, "3 actions")
	testing.expect(t, visible_count.ok, testui.visible_text_diagnostic(visible_count))

	testui.destroy_find_result(&third)
	testui.destroy_find_result(&second)
	testui.destroy_find_result(&first)
	testui.destroy_find_result(&list)
	testui.destroy_find_result(&editor)
	testui.destroy_find_result(&query_row)
	testui.destroy_find_result(&query)
	testui.destroy_find_result(&panel)
}

@(test)
test_command_palette_viewport_scale_matrix :: proc(t: ^testing.T) {
	widths := [3]int{1280, 960, 760}
	heights := [3]int{800, 720, 640}
	scales := [4]f32{1, 1.25, 1.5, 2}
	for width, index in widths {
		for scale in scales {
			app: App
			if !init_app(&app) {
				testing.expect(t, false, "palette state initialization failed")
				continue
			}
		handle, status := open_reference(&app, width, heights[index], scale)
			testing.expect(t, status == .Ok, "TestUI did not stabilize for a viewport/scale case")
			if status == .Ok {
				expect_palette_snapshot(t, &handle)
				status = testui.step(&handle, testui.Input{kind=.Text_Commit, text="settings"})
				testing.expect(t, status == .Ok, "committed query input did not stabilize")
				query := find_unique(t, &handle, .Text_Field, "Search actions")
				list := find_unique(t, &handle, .List_Box, "Actions")
				row := find_unique(t, &handle, .List_Box_Option, "Open export settings")
				testing.expect(t, query.element.value == "settings", "committed query should be re-readable")
				testing.expect(t, list.element.logical_count == 1, "filtering should reduce the result count")
				visible_query := testui.expect_visible_text(&handle, &query.element, "settings")
				testing.expect(t, visible_query.ok, testui.visible_text_diagnostic(visible_query))
				visible_title := testui.expect_visible_text(&handle, &row.element, "Open export settings")
				testing.expect(t, visible_title.ok, testui.visible_text_diagnostic(visible_title))
				panel := find_unique(t, &handle, .Dialog, "Quick actions")
				check_row := testui.expect_inside(&handle, &row.element, &panel.element)
				testing.expect(t, check_row.ok, testui.layout_check_diagnostic(check_row))
				testui.destroy_find_result(&panel)
				testui.destroy_find_result(&row)
				testui.destroy_find_result(&list)
				testui.destroy_find_result(&query)
			}
			testui.close(&handle)
			destroy_app(&app)
		}
	}
}

@(test)
test_command_palette_keyboard_dispatch_and_focus_restore :: proc(t: ^testing.T) {
	app: App
	testing.expect(t, init_app(&app), "palette state initialization failed")
	defer destroy_app(&app)
	handle, status := open_reference(&app, 1280, 800, 1)
	testing.expect(t, status == .Ok, "TestUI initial description did not stabilize")
	if status != .Ok { return }
	defer testui.close(&handle)

	status = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle))
	second := find_unique(t, &handle, .List_Box_Option, "Export selected project")
	testing.expect(t, second.element.collection_selected, "Down should select the next stable item")
	testui.destroy_find_result(&second)
	status = testui.step(&handle, testui.Input{kind=.Key, key=.Up})
	testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle))
	first := find_unique(t, &handle, .List_Box_Option, "Export workspace")
	testing.expect(t, first.element.collection_selected, "Up should return selection to the prior item")
	testui.destroy_find_result(&first)
	status = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle))

	status = testui.step(&handle, testui.Input{kind=.Key, key=.Return})
	testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle))
	testing.expect(t, app.last_dispatched == palette.Item_ID(102), "Return should dispatch the selected application command")
	testing.expect(t, !app.palette_state.open, "activation should dismiss the modal")

	opener := find_unique(t, &handle, .Button, "Workspace")
	_ = alicorn.focus(handle.runtime, opener.element.visual_node)
	testui.destroy_find_result(&opener)

	status = testui.step(&handle, testui.Input{kind=.Key, key=.Open_Command_Palette})
	testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle))
	testing.expect(t, app.palette_state.open, "the host shortcut should open the palette")
	status = testui.step(&handle, testui.Input{kind=.Key, key=.Escape})
	testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle))
	testing.expect(t, !app.palette_state.open, "Escape should dismiss the modal")
	opener_after := find_unique(t, &handle, .Button, "Workspace")
	testing.expect(t, opener_after.element.focused, "focus should return to the opener after dismissal")
	testui.destroy_find_result(&opener_after)
}
