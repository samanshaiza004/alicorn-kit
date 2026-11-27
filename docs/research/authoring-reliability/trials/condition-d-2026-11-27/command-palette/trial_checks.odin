package main

import "core:fmt"
import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import palette "alikit:command_palette"

Viewport :: struct {
	width, height: int,
}

VIEWPORTS :: [3]Viewport{
	{1280, 800},
	{960, 720},
	{760, 640},
}

SCALES :: [4]f32{1, 1.25, 1.5, 2}

step_ok :: proc(
	t: ^testing.T,
	h: ^testui.Test_Handle(App),
	input: testui.Input,
	label: string,
) -> bool {
	status := testui.step(h, input)
	return testing.expect(t, status == .Ok,
		fmt.tprintf("%s: %s", label, testui.last_turn_diagnostic(h)))
}

find_unique :: proc(
	t: ^testing.T,
	h: ^testui.Test_Handle(App),
	query: testui.Query,
	label: string,
) -> testui.Find_Result {
	result := testui.find(h, query)
	testing.expect(t, result.status == .Ok && result.match == .Unique,
		fmt.tprintf("%s should be unique (match=%v status=%v): %s",
			label, result.match, result.status, testui.last_turn_diagnostic(h)))
	return result
}

query_for_role_name :: proc(role: alicorn.Semantic_Role, name: string) -> testui.Query {
	return testui.Query{role=role, name=name, match_role=true, match_name=true}
}

palette_panel_snapshot :: proc(
	t: ^testing.T,
	h: ^testui.Test_Handle(App),
	app: ^App,
	label: string,
) -> (element: testui.Element, ok: bool) {
	info, found := alicorn.node_info(h.runtime, app.palette_state.panel_node)
	if !testing.expect(t, found, fmt.tprintf("%s retained panel node should be live", label)) { return }
	element = testui.Element{
		handle_generation=h.generation,
		description_epoch=h.description_epoch,
		visual_node=app.palette_state.panel_node,
		bounds=info.bounds,
		has_bounds=info.bounds.w > 0 && info.bounds.h > 0,
		allocator=h.allocator,
	}
	ok = element.has_bounds
	if !testing.expect(t, ok, fmt.tprintf("%s retained panel node should have bounds", label)) { return }
	return
}

@(test)
test_palette_responsive_interaction_matrix :: proc(t: ^testing.T) {
	for viewport in VIEWPORTS {
		for scale in SCALES {
			test_palette_case(t, viewport, scale)
		}
	}
}

test_palette_case :: proc(t: ^testing.T, viewport: Viewport, scale: f32) {
	app: App
	h, status := testui.open(
		&app,
		render=render,
		width=viewport.width,
		height=viewport.height,
		scale=scale,
		initialize=app_initialize,
		render_overlays=render_overlays,
		on_key=testui_on_key,
	)
	defer palette.destroy(&app.palette_state)
	defer if h.runtime != nil { testui.close(&h) }
	label := fmt.tprintf("%dx%d @ %.2gx", viewport.width, viewport.height, scale)
	if !testing.expect(t, status == .Ok, fmt.tprintf("%s initial description failed", label)) { return }

	opener := find_unique(t, &h, query_for_role_name(.Button, "Projects"), "Projects opener")
	if opener.match == .Unique {
		clicked := testui.click(&h, &opener.element)
		if !testing.expect(t, clicked == .Ok,
			fmt.tprintf("%s opener click failed: %s", label, testui.last_turn_diagnostic(&h))) {
			testui.destroy_find_result(&opener)
			return
		}
	}
	testui.destroy_find_result(&opener)

	if !step_ok(t, &h, testui.Input{kind=.Key, key=.Open_Command_Palette},
		fmt.tprintf("%s open palette", label)) { return }
	if !testing.expect(t, app.palette_state.open, fmt.tprintf("%s palette should open", label)) { return }

	panel, panel_ok := palette_panel_snapshot(t, &h, &app, label)
	query := find_unique(t, &h, query_for_role_name(.Text_Field,
		"Search actions, files, and commands"), "palette query")
	list := find_unique(t, &h, query_for_role_name(.List_Box, "Actions"), "palette result list")
	if panel_ok && query.match == .Unique && list.match == .Unique {
		overlay_info, overlay_found := alicorn.node_info(h.runtime, app.palette_state.overlay_node)
		testing.expect(t, overlay_found && overlay_info.bounds.x == 0 && overlay_info.bounds.y == 0 &&
			overlay_info.bounds.w == f32(viewport.width) && overlay_info.bounds.h == f32(viewport.height),
			fmt.tprintf("%s modal overlay should fill its logical viewport", label))
		p := panel.bounds
		center_x := p.x+p.w*0.5
		center_y := p.y+p.h*0.5
		testing.expect(t, absf(center_x-f32(viewport.width)*0.5) <= 0.75 &&
			absf(center_y-f32(viewport.height)*0.5) <= 0.75,
			fmt.tprintf("%s modal panel should be centered in the logical viewport: %v", label, p))
		testing.expect(t, p.x >= 0 && p.y >= 0 && p.x+p.w <= f32(viewport.width)+0.75 &&
			p.y+p.h <= f32(viewport.height)+0.75,
			fmt.tprintf("%s modal panel should remain inside the viewport: %v", label, p))
		inside_query := testui.expect_inside(&h, &query.element, &panel)
		inside_list := testui.expect_inside(&h, &list.element, &panel)
		testing.expect(t, inside_query.ok, testui.layout_check_diagnostic(inside_query))
		testing.expect(t, inside_list.ok, testui.layout_check_diagnostic(inside_list))
		query_fills_list := testui.expect_fills_width(&h, &query.element, &list.element, tolerance=0.75)
		testing.expect(t, query_fills_list.ok, testui.layout_check_diagnostic(query_fills_list))
		query_centered := testui.expect_aligned(&h, &query.element, &list.element, .Center_X, tolerance=0.75)
		testing.expect(t, query_centered.ok, testui.layout_check_diagnostic(query_centered))
		query_no_overflow := testui.expect_no_overflow(&h, &query.element)
		list_no_overflow := testui.expect_no_overflow(&h, &list.element)
		testing.expect(t, query_no_overflow.ok, testui.layout_check_diagnostic(query_no_overflow))
		testing.expect(t, list_no_overflow.ok, testui.layout_check_diagnostic(list_no_overflow))
	}
	testui.destroy_find_result(&query)
	testui.destroy_find_result(&list)

	if !step_ok(t, &h, testui.Input{kind=.Text_Commit, text="settings"},
		fmt.tprintf("%s type first query", label)) { return }
	query = find_unique(t, &h, query_for_role_name(.Text_Field,
		"Search actions, files, and commands"), "query after first edit")
	settings_text := testui.expect_visible_text(&h, &query.element, "settings")
	testing.expect(t, settings_text.ok, testui.visible_text_diagnostic(settings_text))
	list = find_unique(t, &h, query_for_role_name(.List_Box, "Actions"), "filtered result list")
	testing.expect(t, list.element.logical_count == 1,
		fmt.tprintf("%s 'settings' should filter to one result, got %d", label, list.element.logical_count))
	settings_result := find_unique(t, &h, query_for_role_name(.List_Box_Option,
		"Open export settings"), "settings result")
	settings_visible := testui.expect_visible_text(&h, &settings_result.element, "Open export settings")
	testing.expect(t, settings_visible.ok, testui.visible_text_diagnostic(settings_visible))
	panel, panel_ok = palette_panel_snapshot(t, &h, &app, label)
	if panel_ok {
		inside_result := testui.expect_inside(&h, &settings_result.element, &panel)
		no_overflow_result := testui.expect_no_overflow(&h, &settings_result.element)
		testing.expect(t, inside_result.ok, testui.layout_check_diagnostic(inside_result))
		testing.expect(t, no_overflow_result.ok, testui.layout_check_diagnostic(no_overflow_result))
	}
	missing_result := testui.find(&h, query_for_role_name(.List_Box_Option, "Export workspace"))
	testing.expect(t, missing_result.match == .None,
		fmt.tprintf("%s filtered results should omit Export workspace", label))
	testui.destroy_find_result(&missing_result)
	testui.destroy_find_result(&settings_result)
	testui.destroy_find_result(&list)
	testui.destroy_find_result(&query)

	for _ in 0..<len("settings") {
		if !step_ok(t, &h, testui.Input{kind=.Key, key=.Backspace},
			fmt.tprintf("%s clear query", label)) { return }
	}
	if !step_ok(t, &h, testui.Input{kind=.Text_Commit, text="export"},
		fmt.tprintf("%s replace query", label)) { return }
	query = find_unique(t, &h, query_for_role_name(.Text_Field,
		"Search actions, files, and commands"), "query after replacement")
	export_text := testui.expect_visible_text(&h, &query.element, "export")
	testing.expect(t, export_text.ok, testui.visible_text_diagnostic(export_text))
	list = find_unique(t, &h, query_for_role_name(.List_Box, "Actions"), "replacement result list")
	testing.expect(t, list.element.logical_count == 3,
		fmt.tprintf("%s replacing the query with 'export' should restore three results, got %d",
			label, list.element.logical_count))
	workspace_result := find_unique(t, &h, query_for_role_name(.List_Box_Option,
		"Export workspace"), "workspace result")
	workspace_visible := testui.expect_visible_text(&h, &workspace_result.element, "Export workspace")
	testing.expect(t, workspace_visible.ok, testui.visible_text_diagnostic(workspace_visible))
	panel, panel_ok = palette_panel_snapshot(t, &h, &app, label)
	if panel_ok {
		inside_result := testui.expect_inside(&h, &workspace_result.element, &panel)
		testing.expect(t, inside_result.ok, testui.layout_check_diagnostic(inside_result))
	}
	testui.destroy_find_result(&workspace_result)
	testui.destroy_find_result(&query)
	testui.destroy_find_result(&list)

	if !step_ok(t, &h, testui.Input{kind=.Key, key=.Down},
		fmt.tprintf("%s move selection", label)) { return }
	if app.down_key_count == 0 {
		handled := on_key(&app, h.runtime, .Down)
		if !testing.expect(t, handled, fmt.tprintf("%s palette host callback should consume Down", label)) { return }
		if !step_ok(t, &h, testui.Input{kind=.Time_Advance, delta_ns=0},
			fmt.tprintf("%s describe keyboard selection", label)) { return }
	}
	testing.expect(t, app.down_key_count == 1,
		fmt.tprintf("%s Down should be consumed once by the palette host callback", label))
	selected := find_unique(t, &h, query_for_role_name(.List_Box_Option,
		"Export selected project"), "keyboard-selected result")
	panel, panel_ok = palette_panel_snapshot(t, &h, &app, label)
	if panel_ok {
		inside_selected := testui.expect_inside(&h, &selected.element, &panel)
		selected_no_overflow := testui.expect_no_overflow(&h, &selected.element)
		testing.expect(t, inside_selected.ok, testui.layout_check_diagnostic(inside_selected))
		testing.expect(t, selected_no_overflow.ok, testui.layout_check_diagnostic(selected_no_overflow))
	}
	testing.expect(t, app.palette_state.selection.id == palette.Item_ID(102),
		fmt.tprintf("%s Down should select stable item ID 102, got %v", label, app.palette_state.selection.id))
	testing.expect(t, selected.element.collection_current || selected.element.collection_selected,
		fmt.tprintf("%s selected row should publish current or selected collection state", label))
	testui.destroy_find_result(&selected)
	if !step_ok(t, &h, testui.Input{kind=.Key, key=.Return},
		fmt.tprintf("%s activate selection", label)) { return }
	testing.expect(t, app.activation_count == 1 && app.activated_id == palette.Item_ID(102),
		fmt.tprintf("%s Return should activate stable item ID 102, count=%d id=%v",
			label, app.activation_count, app.activated_id))
	testing.expect(t, !app.palette_state.open, fmt.tprintf("%s activation should close the modal", label))
	opener = find_unique(t, &h, query_for_role_name(.Button, "Projects"), "opener after activation")
	testing.expect(t, opener.element.focused, fmt.tprintf("%s activation should restore focus to Projects", label))
	testui.destroy_find_result(&opener)

	if !step_ok(t, &h, testui.Input{kind=.Key, key=.Open_Command_Palette},
		fmt.tprintf("%s reopen palette", label)) { return }
	if !step_ok(t, &h, testui.Input{kind=.Key, key=.Escape},
		fmt.tprintf("%s dismiss palette", label)) { return }
	testing.expect(t, !app.palette_state.open, fmt.tprintf("%s Escape should close the modal", label))
	opener = find_unique(t, &h, query_for_role_name(.Button, "Projects"), "opener after Escape")
	testing.expect(t, opener.element.focused, fmt.tprintf("%s Escape should restore focus to Projects", label))
	testui.destroy_find_result(&opener)
}

testui_on_key :: proc(state: rawptr, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	app := cast(^App)state
	if app == nil { return false }
	return on_key(app, rt, key)
}

absf :: proc(value: f32) -> f32 {
	return -value if value < 0 else value
}
