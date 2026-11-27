package main

import "core:fmt"
import "core:testing"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import testui "alicorn:testui"
import dialog "alikit:dialog"

absf :: proc(value: f32) -> f32 { return -value if value < 0 else value }

find_named :: proc(handle: ^testui.Test_Handle(App), role: alicorn.Semantic_Role, name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=role, name=name, match_role=true, match_name=true})
}

find_key :: proc(handle: ^testui.Test_Handle(App), key: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.Button, key=ui.key_string(key), match_role=true, match_key=true})
}

open_delete :: proc(t: ^testing.T, handle: ^testui.Test_Handle(App)) -> bool {
	opener := find_key(handle, DELETE_OPEN_KEY)
	defer testui.destroy_find_result(&opener)
	if !testing.expect(t, opener.match == .Unique, "the destructive action should be available before opening") {
		return false
	}
	if !testing.expect(t, testui.click(handle, &opener.element) == .Ok, "the project action should open the confirmation") {
		return false
	}
	if !testing.expect(t, handle.state^.delete_dialog.open,
		fmt.tprintf("the opener should leave the dialog state open after its click: click_count=%v open=%v overlay=%v",
			handle.state^.delete_open_count, handle.state^.delete_dialog.open, handle.state^.delete_dialog.overlay_node)) {
		return false
	}
	return true
}

open_alert :: proc(t: ^testing.T, handle: ^testui.Test_Handle(App)) -> bool {
	opener := find_key(handle, ALERT_OPEN_KEY)
	defer testui.destroy_find_result(&opener)
	if !testing.expect(t, opener.match == .Unique, "the alert action should be available") {
		return false
	}
	if !testing.expect(t, testui.click(handle, &opener.element) == .Ok, "the alert action should open the alert") {
		return false
	}
	return true
}

check_reference_case :: proc(t: ^testing.T, width, height: int, scale: f32) {
	app := App{}
	handle, status := testui.open(&app, render, width=width, height=height, scale=scale,
		render_overlays=render_overlays)
	defer testui.close(&handle)
	if !testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle)) { return }
	if !open_delete(t, &handle) { return }

	panel := find_named(&handle, .Dialog, "Delete project?")
	defer testui.destroy_find_result(&panel)
	cancel := find_key(&handle, CANCEL_KEY)
	defer testui.destroy_find_result(&cancel)
	delete := find_key(&handle, DELETE_KEY)
	defer testui.destroy_find_result(&delete)
	title := find_named(&handle, .Static_Text, "Delete project?")
	defer testui.destroy_find_result(&title)
	body := find_named(&handle, .Static_Text, DELETE_COPY)
	defer testui.destroy_find_result(&body)

	if !testing.expect(t, panel.match == .Unique && panel.element.has_bounds,
		fmt.tprintf("the open confirmation should have one measured Dialog panel: match=%v status=%v open=%v focus=%v",
			panel.match, panel.status, app.delete_dialog.open, handle.last_turn.focus)) { return }
	if !testing.expect(t, cancel.match == .Unique && delete.match == .Unique,
		"both action controls should have stable, unique Button identities") { return }

	bounds := panel.element.bounds
	center_dx := absf((bounds.x+bounds.w*0.5)-f32(width)*0.5)
	center_dy := absf((bounds.y+bounds.h*0.5)-f32(height)*0.5)
	testing.expect(t, absf(bounds.w-516) <= 0.5, "the dialog should keep its 516 px reference width")
	testing.expect(t, center_dx <= 0.5 && center_dy <= 0.5,
		"the modal should stay centered at each viewport and scale")
	testing.expect(t, bounds.x >= 0 && bounds.y >= 0 && bounds.x+bounds.w <= f32(width)+0.5 &&
		bounds.y+bounds.h <= f32(height)+0.5,
		"the fit-content modal should remain inside the viewport")
	testing.expect(t, bounds.h >= 300 && bounds.h <= 560,
		"the wrapped confirmation, detail row, and actions should fit within the modal's maximum height")
	panel_no_overflow := testui.expect_no_overflow(&handle, &panel.element)
	testing.expect(t, panel_no_overflow.ok, testui.layout_check_diagnostic(panel_no_overflow))

	title_node, title_found := alicorn.node_by_key(handle.runtime,
		ui.key_string("delete-dialog-title"), .Text)
	body_node, body_found := alicorn.node_by_key(handle.runtime,
		ui.key_string("delete-dialog-description"), .Text)
	title_info, title_info_found := alicorn.node_info(handle.runtime, title_node)
	body_info, body_info_found := alicorn.node_info(handle.runtime, body_node)
	title_bounds := title_info.bounds
	body_bounds := body_info.bounds
	text_inside := title_found && body_found && title_info_found && body_info_found &&
		title_bounds.x >= bounds.x && title_bounds.y >= bounds.y &&
		title_bounds.x+title_bounds.w <= bounds.x+bounds.w &&
		title_bounds.y+title_bounds.h <= bounds.y+bounds.h &&
		body_bounds.x >= bounds.x && body_bounds.y >= bounds.y &&
		body_bounds.x+body_bounds.w <= bounds.x+bounds.w &&
		body_bounds.y+body_bounds.h <= bounds.y+bounds.h
	testing.expect(t, text_inside, "the actual title and body text nodes should stay inside the modal bounds")
	testing.expect(t, body_bounds.h >= 30,
		fmt.tprintf("the long body should wrap into multiple shaped lines: body bounds=%v", body_bounds))

	elements := [2]^testui.Element{&cancel.element, &delete.element}
	for element in elements {
		inside := testui.expect_inside(&handle, element, &panel.element)
		testing.expect(t, inside.ok, testui.layout_check_diagnostic(inside))
		no_overflow := testui.expect_no_overflow(&handle, element)
		testing.expect(t, no_overflow.ok, testui.layout_check_diagnostic(no_overflow))
	}
	aligned := testui.expect_aligned(&handle, &cancel.element, &delete.element, .Center_Y)
	testing.expect(t, aligned.ok, testui.layout_check_diagnostic(aligned))
	testing.expect(t, absf(cancel.element.bounds.w-112) <= 0.75 && absf(delete.element.bounds.w-153) <= 0.75,
		fmt.tprintf("the two action widths should match the authored target: cancel=%v delete=%v",
			cancel.element.bounds.w, delete.element.bounds.w))

	expected_texts := [4]string{"Delete project?", DELETE_COPY, "14 files · 2 members", "Shared access ends immediately."}
	for expected in expected_texts {
		visible := testui.expect_visible_text(&handle, &panel.element, expected)
		testing.expect(t, visible.ok, testui.visible_text_diagnostic(visible))
	}
}

@(test)
test_reference_geometry_and_visible_text_at_all_scales :: proc(t: ^testing.T) {
	viewports := [3][2]int{{1280, 800}, {960, 720}, {760, 640}}
	scales := [4]f32{1, 1.25, 1.5, 2}
	for viewport in viewports {
		for scale in scales {
			check_reference_case(t, viewport[0], viewport[1], scale)
		}
	}
}

@(test)
test_destructive_confirmation_focus_and_dismissal :: proc(t: ^testing.T) {
	app := App{}
	handle, status := testui.open(&app, render, width=1280, height=800, render_overlays=render_overlays)
	defer testui.close(&handle)
	if !testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle)) { return }

	if !open_delete(t, &handle) { return }
	cancel := find_key(&handle, CANCEL_KEY)
	if !testing.expect(t, cancel.match == .Unique && cancel.element.focused,
		fmt.tprintf("Cancel should receive the configured initial focus: match=%v focused=%v state=%v pending=%v focus=%v",
			cancel.match, cancel.element.focused, app.delete_dialog.open, app.delete_dialog.focus_pending, handle.last_turn.focus)) {
		testui.destroy_find_result(&cancel)
		return
	}
	testui.destroy_find_result(&cancel)

	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Return}) == .Ok,
		"Return should activate the safely focused Cancel action") { return }
	testing.expect(t, !app.delete_dialog.open && app.cancel_count == 1 && app.delete_count == 0,
		"pressing Return on first open must cancel instead of deleting")
	opener := find_key(&handle, DELETE_OPEN_KEY)
	testing.expect(t, opener.match == .Unique && opener.element.focused,
		"action dismissal should restore focus to the Delete project opener")
	testui.destroy_find_result(&opener)

	if !open_delete(t, &handle) { return }
	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Escape}) == .Ok,
		"Escape should be handled by the normal modal route") { return }
	testing.expect(t, !app.delete_dialog.open, "Escape should dismiss an ordinary Dialog")
	opener = find_key(&handle, DELETE_OPEN_KEY)
	testing.expect(t, opener.match == .Unique && opener.element.focused,
		"Escape should restore focus to the opener")
	testui.destroy_find_result(&opener)

	if !open_delete(t, &handle) { return }
	if !testing.expect(t, testui.click_at(&handle, 8, 700) == .Ok,
		"a pointer down outside the panel should take the backdrop path") { return }
	testing.expect(t, !app.delete_dialog.open, "a Dialog should dismiss when its backdrop is pressed")
	opener = find_key(&handle, DELETE_OPEN_KEY)
	testing.expect(t, opener.match == .Unique && opener.element.focused,
		"backdrop dismissal should restore focus to the opener")
	testui.destroy_find_result(&opener)
}

@(test)
test_alert_ignores_escape_and_backdrop_then_acknowledges :: proc(t: ^testing.T) {
	app := App{}
	handle, status := testui.open(&app, render, width=960, height=720, render_overlays=render_overlays)
	defer testui.close(&handle)
	if !testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle)) { return }
	if !open_alert(t, &handle) { return }

	panel := find_named(&handle, .Dialog, "Project removed")
	alert := find_named(&handle, .Alert, "Project removed")
	testing.expect(t, panel.match == .Unique && panel.element.focused,
		"an Alert_Dialog should publish its live Alert and focus the panel")
	testing.expect(t, alert.match == .Unique, "the Alert_Dialog should publish one assertive Alert companion")
	testui.destroy_find_result(&panel)
	testui.destroy_find_result(&alert)

	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Escape})
	testing.expect(t, app.alert_dialog.open, "the default Alert_Dialog policy should ignore Escape")
	_ = testui.click_at(&handle, 8, 700)
	testing.expect(t, app.alert_dialog.open, "the default Alert_Dialog policy should ignore backdrop presses")

	ok := find_key(&handle, ALERT_OK_KEY)
	if !testing.expect(t, ok.match == .Unique && testui.click(&handle, &ok.element) == .Ok,
		"the Alert acknowledgement should be an ordinary focusable Button") {
		testui.destroy_find_result(&ok)
		return
	}
	testui.destroy_find_result(&ok)
	testing.expect(t, !app.alert_dialog.open && app.alert_acknowledged,
		"acknowledging the Alert should close it and record the application event")
	opener := find_key(&handle, ALERT_OPEN_KEY)
	testing.expect(t, opener.match == .Unique && opener.element.focused,
		"Alert acknowledgement should restore opener focus")
	testui.destroy_find_result(&opener)
}
