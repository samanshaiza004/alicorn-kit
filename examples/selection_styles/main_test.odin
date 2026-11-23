package main

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import radio "alikit:radio_group"

initialize_test :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	initialize((^App)(data), rt)
}

find_option :: proc(
	handle: ^testui.Test_Handle(App), role: alicorn.Semantic_Role, name: string,
) -> testui.Find_Result {
	return testui.find(handle, {role=role, name=name, match_role=true, match_name=true})
}

check_treatment_paint :: proc(t: ^testing.T, rt: ^alicorn.Runtime, style: Item_Style) {
	display, ok := alicorn.paint_display_list(rt)
	if !testing.expect(t, ok) { return }
	faces, marks, labels, disabled_labels := 0, 0, 0, 0
	for command in display.commands {
		if surface, found := command.payload.(alicorn.Surface_Paint); found {
			if surface.fill == style.fill || surface.fill == style.selected_fill {
				testing.expect_value(t, surface.material, style.material)
				faces += 1
			}
			if surface.fill == style.mark_ink { marks += 1 }
		}
		if text, found := command.payload.(alicorn.Text_Paint); found {
			if text.color == style.ink { labels += 1 }
			if text.color == style.disabled_ink { disabled_labels += 1 }
		}
	}
	testing.expect_value(t, faces, 6)
	testing.expect_value(t, marks, 2)
	testing.expect_value(t, labels, 4)
	testing.expect_value(t, disabled_labels, 2)
}

@(test)
test_style_switch_preserves_owners_and_selection :: proc(t: ^testing.T) {
	app := App{radio_value=1, view_value=1}
	_ = radio.request_focus(&app.radio_state)
	handle, status := testui.open(&app, render, width=500, height=430, initialize=initialize_test)
	defer testui.close(&handle)
	if !testing.expect(t, status == .Ok) { return }

	first_radio := find_option(&handle, .Radio_Button, "Draft")
	first_tab := find_option(&handle, .Tab, "Overview")
	defer testui.destroy_find_result(&first_radio)
	defer testui.destroy_find_result(&first_tab)
	if !testing.expect(t, first_radio.match == .Unique && first_tab.match == .Unique) { return }
	focused := alicorn.focused_node(handle.runtime)
	testing.expect(t, focused != 0)
	check_treatment_paint(t, handle.runtime, style_for(.Minimal, app.relief))

	treatments := [2]Treatment{.Hardware, .Paper}
	for treatment in treatments {
		app.treatment = treatment
		alicorn.invalidate_root(handle.runtime, "test switched treatment")
		testing.expect_value(t, testui.advance_time(&handle, 0), testui.Status.Ok)
		testing.expect_value(t, alicorn.focused_node(handle.runtime), focused)
		current_radio := find_option(&handle, .Radio_Button, "Draft")
		current_tab := find_option(&handle, .Tab, "Overview")
		defer testui.destroy_find_result(&current_radio)
		defer testui.destroy_find_result(&current_tab)
		testing.expect_value(t, current_radio.element.semantic_id, first_radio.element.semantic_id)
		testing.expect_value(t, current_tab.element.semantic_id, first_tab.element.semantic_id)
		testing.expect_value(t, current_radio.element.visual_node, first_radio.element.visual_node)
		testing.expect_value(t, current_tab.element.visual_node, first_tab.element.visual_node)
		testing.expect_value(t, current_radio.element.actions, first_radio.element.actions)
		testing.expect_value(t, current_tab.element.actions, first_tab.element.actions)
		testing.expect(t, current_radio.element.collection_selected && current_tab.element.collection_selected)
		testing.expect(t, current_radio.element.bounds.h > first_radio.element.bounds.h)
		testing.expect(t, current_tab.element.bounds.h > first_tab.element.bounds.h)
		check_treatment_paint(t, handle.runtime, style_for(treatment, app.relief))
	}

	_ = testui.step(&handle, {kind=.Key, key=.Right})
	testing.expect_value(t, app.radio_value, u64(2))
	_ = testui.step(&handle, {kind=.Key, key=.Right})
	testing.expect_value(t, app.radio_value, u64(1))

	activity := find_option(&handle, .Tab, "Activity")
	defer testui.destroy_find_result(&activity)
	testing.expect_value(t, testui.click(&handle, &activity.element), testui.Status.Ok)
	testing.expect_value(t, app.view_value, u64(2))
	_ = testui.step(&handle, {kind=.Semantic_Action, semantic_id=first_tab.element.semantic_id,
		semantic_action=.Select})
	testing.expect_value(t, app.view_value, u64(1))

	archive := find_option(&handle, .Tab, "Archive")
	defer testui.destroy_find_result(&archive)
	testing.expect(t, alicorn.semantic_states_has(archive.element.states, .Disabled))
	_ = testui.click(&handle, &archive.element)
	testing.expect_value(t, app.view_value, u64(1))
	_ = testui.advance_time(&handle, 100_000_000)
	testing.expect_value(t, handle.last_turn.descriptions, 0)
}
