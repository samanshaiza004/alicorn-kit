package main

import "core:testing"
import alicorn "alicorn:runtime"
import "alicorn:testui"
import ui "alicorn:ui"

expect_ok :: proc(t: ^testing.T, status: testui.Status) {
	testing.expect(t, status == .Ok)
}

expect_query :: proc(t: ^testing.T, result: testui.Find_Result) {
	testing.expect(t, result.match == .Unique && result.status == .Ok)
}

find_role_name :: proc(
	t: ^testing.T,
	handle: ^testui.Test_Handle(App),
	role: alicorn.Semantic_Role,
	name: string,
) -> testui.Element {
	result := testui.find(handle, testui.Query{role=role, name=name, match_role=true, match_name=true})
	expect_query(t, result)
	element := result.element
	result.element = {}
	testui.destroy_find_result(&result)
	return element
}

find_button_key :: proc(
	t: ^testing.T,
	handle: ^testui.Test_Handle(App),
	key: string,
) -> testui.Element {
	result := testui.find(handle, testui.Query{
		role=.Button,
		key=ui.key_string(key),
		match_role=true,
		match_key=true,
	})
	expect_query(t, result)
	element := result.element
	result.element = {}
	testui.destroy_find_result(&result)
	return element
}

find_text_key :: proc(
	t: ^testing.T,
	handle: ^testui.Test_Handle(App),
	key: ui.UI_Key,
) -> testui.Element {
	result := testui.find(handle, testui.Query{role=.Static_Text, key=key, match_role=true, match_key=true})
	expect_query(t, result)
	element := result.element
	result.element = {}
	testui.destroy_find_result(&result)
	return element
}

click_button :: proc(t: ^testing.T, handle: ^testui.Test_Handle(App), key: string) {
	element := find_button_key(t, handle, key)
	if element.visual_node != 0 {
		expect_ok(t, testui.click(handle, &element))
	}
	testui.destroy_element(&element)
}

open_trial :: proc(
	t: ^testing.T,
	app: ^App,
	width, height: int,
	scale: f32,
) -> testui.Test_Handle(App) {
	app.confirm_description = DESCRIPTION
	handle, status := testui.open(app, render, width=width, height=height, scale=scale,
		render_overlays=render_overlays)
	expect_ok(t, status)
	return handle
}

@(test)
test_dialog_height_tracks_description_content :: proc(t: ^testing.T) {
	app: App
	handle := open_trial(t, &app, 1280, 800, 1)
	click_button(t, &handle, "open-delete")
	long_panel := find_role_name(t, &handle, .Dialog, "Delete project?")
	long_height := long_panel.bounds.h
	testui.destroy_element(&long_panel)

	app.confirm_description = "This cannot be undone."
	alicorn.invalidate_root(handle.runtime, "dialog description changed in TestUI")
	expect_ok(t, testui.step(&handle, testui.Input{kind=.Time_Advance}))
	short_panel := find_role_name(t, &handle, .Dialog, "Delete project?")
	short_description := find_text_key(t, &handle, ui.key_u64(0xA11C_6E01+2))
	testing.expect(t, short_panel.bounds.h < long_height)
	testing.expect(t, short_description.value == "This cannot be undone.")
	testui.destroy_element(&short_description)
	testui.destroy_element(&short_panel)
	testui.close(&handle)
}

within :: proc(inner, outer: alicorn.Rect) -> bool {
	return inner.x >= outer.x-0.5 && inner.y >= outer.y-0.5 &&
		inner.x+inner.w <= outer.x+outer.w+0.5 &&
		inner.y+inner.h <= outer.y+outer.h+0.5
}

expect_focus :: proc(t: ^testing.T, handle: ^testui.Test_Handle(App), element: testui.Element) {
	testing.expect(t, alicorn.focused_node(handle.runtime) == element.visual_node)
}

expect_focus_in_dialog :: proc(t: ^testing.T, handle: ^testui.Test_Handle(App)) {
	panel := find_role_name(t, handle, .Dialog, "Delete project?")
	cancel := find_button_key(t, handle, "cancel-delete")
	delete := find_button_key(t, handle, "confirm-delete")
	focused := alicorn.focused_node(handle.runtime)
	testing.expect(t, focused == panel.visual_node || focused == cancel.visual_node || focused == delete.visual_node)
	testui.destroy_element(&delete)
	testui.destroy_element(&cancel)
	testui.destroy_element(&panel)
}

expect_visible_inside :: proc(t: ^testing.T, element: testui.Element, bounds: alicorn.Rect) {
	testing.expect(t, element.has_bounds && element.bounds.w > 0 && element.bounds.h > 0)
	testing.expect(t, within(element.bounds, bounds))
}

check_confirm_layout :: proc(
	t: ^testing.T,
	handle: ^testui.Test_Handle(App),
	width, height: int,
) {
	panel := find_role_name(t, handle, .Dialog, "Delete project?")
	description := find_text_key(t, handle, ui.key_u64(0xA11C_6E01+2))
	detail_title := find_text_key(t, handle, ui.key_string("detail-count"))
	detail_body := find_text_key(t, handle, ui.key_string("detail-note"))
	title := find_text_key(t, handle, ui.key_u64(0xA11C_6E01+1))
	cancel := find_button_key(t, handle, "cancel-delete")
	delete := find_button_key(t, handle, "confirm-delete")

	viewport := alicorn.Rect{0, 0, f32(width), f32(height)}
	expect_visible_inside(t, panel, viewport)
	expect_visible_inside(t, title, panel.bounds)
	expect_visible_inside(t, description, panel.bounds)
	expect_visible_inside(t, detail_title, panel.bounds)
	expect_visible_inside(t, detail_body, panel.bounds)
	expect_visible_inside(t, cancel, panel.bounds)
	expect_visible_inside(t, delete, panel.bounds)
	// The reference description is three lines and stays above the detail row.
	testing.expect(t, description.bounds.h >= 36)
	testing.expect(t, description.bounds.y+description.bounds.h <= detail_title.bounds.y+1)
	testing.expect(t, title.value == "Delete project?")
	testing.expect(t, description.value == DESCRIPTION)
	testing.expect(t, detail_title.value == "14 files · 2 members")
	testing.expect(t, detail_body.value == "Shared access ends immediately.")
	// Both action controls share one trailing row baseline.
	testing.expect(t, abs(cancel.bounds.y-delete.bounds.y) <= 0.5)
	testing.expect(t, abs(cancel.bounds.h-delete.bounds.h) <= 0.5)
	testing.expect(t, panel.description == DESCRIPTION)

	testui.destroy_element(&delete)
	testui.destroy_element(&cancel)
	testui.destroy_element(&title)
	testui.destroy_element(&detail_body)
	testui.destroy_element(&detail_title)
	testui.destroy_element(&description)
	testui.destroy_element(&panel)
}

@(test)
test_dialog_viewports_scales_and_requery :: proc(t: ^testing.T) {
	View :: struct { width, height: int }
	viewports := [3]View{{1280, 800}, {960, 720}, {760, 640}}
	scales := [4]f32{1, 1.25, 1.5, 2}
	for view in viewports {
		for scale in scales {
			app: App
			handle := open_trial(t, &app, view.width, view.height, scale)
			click_button(t, &handle, "open-delete")
			testing.expect(t, app.confirm.open && !app.deleted)
			check_confirm_layout(t, &handle, view.width, view.height)

			cancel := find_button_key(t, &handle, "cancel-delete")
			expect_focus(t, &handle, cancel)
			testui.destroy_element(&cancel)

			// Every TestUI input invalidates previous Element snapshots. Re-query
			// after each key to ensure Tab remains inside the modal subtree.
			expect_ok(t, testui.step(&handle, testui.Input{kind=.Key, key=.Tab}))
			delete := find_button_key(t, &handle, "confirm-delete")
			expect_focus(t, &handle, delete)
			testui.destroy_element(&delete)
			for _ in 0..<6 {
				expect_ok(t, testui.step(&handle, testui.Input{kind=.Key, key=.Tab}))
				expect_focus_in_dialog(t, &handle)
			}
			testui.close(&handle)
		}
	}
}

@(test)
test_dialog_safe_return_escape_backdrop_and_restore :: proc(t: ^testing.T) {
	app: App
	handle := open_trial(t, &app, 1280, 800, 1)
	click_button(t, &handle, "open-delete")
	cancel := find_button_key(t, &handle, "cancel-delete")
	expect_focus(t, &handle, cancel)
	testui.destroy_element(&cancel)

	// Enter starts on Cancel, so it cannot activate the destructive action.
	expect_ok(t, testui.step(&handle, testui.Input{kind=.Key, key=.Return}))
	testing.expect(t, !app.deleted)
	if !app.confirm.open {
		click_button(t, &handle, "open-delete")
	}
	expect_ok(t, testui.step(&handle, testui.Input{kind=.Key, key=.Escape}))
	testing.expect(t, !app.confirm.open && !app.deleted)
	opener := find_button_key(t, &handle, "open-delete")
	expect_focus(t, &handle, opener)
	testui.destroy_element(&opener)

	click_button(t, &handle, "open-delete")
	expect_ok(t, testui.click_at(&handle, 2, 2))
	testing.expect(t, !app.confirm.open && !app.deleted)
	opener = find_button_key(t, &handle, "open-delete")
	expect_focus(t, &handle, opener)
	testui.destroy_element(&opener)
	testui.close(&handle)
}

@(test)
test_alert_semantics_and_non_dismissal_defaults :: proc(t: ^testing.T) {
	app: App
	handle := open_trial(t, &app, 960, 720, 1.25)
	click_button(t, &handle, "open-alert")
	testing.expect(t, app.alert.open)
	alert := find_role_name(t, &handle, .Alert, "Project is safe")
	testing.expect(t, alert.description == "This project has no pending changes.")
	testing.expect(t, alert.bounds.w > 0 && alert.bounds.h > 0)
	testui.destroy_element(&alert)
	panel := find_role_name(t, &handle, .Dialog, "Project is safe")
	expect_focus(t, &handle, panel)
	testing.expect(t, panel.description == "This project has no pending changes.")
	testui.destroy_element(&panel)

	expect_ok(t, testui.step(&handle, testui.Input{kind=.Key, key=.Escape}))
	testing.expect(t, app.alert.open)
	expect_ok(t, testui.click_at(&handle, 2, 2))
	testing.expect(t, app.alert.open)
	ok := find_button_key(t, &handle, "alert-acknowledge")
	testing.expect(t, ok.name == "Got it")
	testui.destroy_element(&ok)
	click_button(t, &handle, "alert-acknowledge")
	testing.expect(t, !app.alert.open && app.alert_acknowledged)
	open_alert := find_button_key(t, &handle, "open-alert")
	expect_focus(t, &handle, open_alert)
	testui.destroy_element(&open_alert)
	testui.close(&handle)
}
