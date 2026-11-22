package menu

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

Test_App :: struct {
	state:     State,
	items:     [7]Item,
	chosen:    u64,
	activations: int,
	top_space: f32,
}

fixture_items :: proc() -> [7]Item {
	return {
		{key=1, label="Rename", shortcut="F2"},
		{key=2, label="Duplicate", shortcut="Ctrl+D", checked=true},
		{key=3, kind=.Separator},
		{key=4, label="Archive", disabled=true},
		{key=5, label="Delete", shortcut="Del"},
		{key=6, kind=.Separator},
		{key=7, label="Properties", shortcut="Alt+Enter"},
	}
}

fixture_render :: proc(app: ^Test_App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("menu-fixture-root"), width=-1, height=-1, padding=20, gap=8) {
		if app.top_space > 0 {
			if ui.row(ctx, key=alicorn.key_string("menu-fixture-space"), width=-1, height=app.top_space,
				label="menu-fixture-space") {}
		}
		chosen_before := app.chosen
		_ = trigger(ctx, &app.state, "Actions", options=Options{accessible_label="Actions"},
			key=alicorn.key_string("menu-fixture-trigger"))
		if app.chosen != chosen_before { app.activations += 1 }
		_ = ui.button(ctx, "Background", key=alicorn.key_string("menu-fixture-background"), width=120, height=30)
	}
}

fixture_overlays :: proc(app: ^Test_App, ctx: ^ui.UI) {
	visible, chosen := popup_begin(ctx, &app.state, app.items[:],
		Options{accessible_label="Actions"}, key=alicorn.key_string("menu-fixture-popup"), instance_id=9401)
	if !visible {
			if chosen != 0 { app.chosen = chosen; app.activations += 1 }
		return
	}
	for value, index in app.items {
		if item(ctx, &app.state, value, index) {
			app.chosen = value.key
			app.activations += 1
		}
	}
	popup_end(ctx, &app.state)
}

fixture_open :: proc(app: ^Test_App, t: ^testing.T, height := 420) -> (testui.Test_Handle(Test_App), bool) {
	app.items = fixture_items()
	handle, status := testui.open(app, fixture_render, width=560, height=height, render_overlays=fixture_overlays)
	if !testing.expectf(t, status == .Ok, "the menu fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
find_item :: proc(handle: ^testui.Test_Handle(Test_App), name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.Menu_Item, name=name, match_role=true, match_name=true})
}

@(test)
test_menu_identity_theme_contract_and_recipe_shape :: proc(t: ^testing.T) {
	testing.expect(t, menu_semantic_id(0).namespace == 0, "instance zero must not publish identity")
	testing.expect(t, item_semantic_id(1, 0).namespace == 0, "item key zero must not publish identity")
	testing.expect(t, item_semantic_id(1, 2) != item_semantic_id(2, 2),
		"the same command in two menus must have distinct identity")

	recipe := Recipe{
		active_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.menu", "active"),
	}
	contract := theme_contract_default(recipe)
	testing.expect_value(t, contract.required_count, 1)
	testing.expect_value(t, contract.optional_count, 2)
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 200, 120})
	defer alicorn.destroy_runtime(&rt)
	report := theme_contract_check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	names, missing := theme_contract_missing_required(contract, report)
	testing.expect(t, !theme_contract_satisfied(report) && missing == 1 &&
		names[0] == "alikit.menu.active_surface")
}

@(test)
test_menu_trigger_semantics_keyboard_choice_and_focus_restore :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	trigger_part := testui.find(&handle, testui.Query{role=.Button, name="Actions", match_role=true, match_name=true})
	if !testing.expect(t, trigger_part.match == .Unique, "the stock trigger should publish a Button") {
		testui.destroy_find_result(&trigger_part)
		return
	}
	testing.expect(t, !alicorn.semantic_states_has(trigger_part.element.states, .Expanded),
		"a closed trigger is not Expanded")
	testui.destroy_find_result(&trigger_part)

	// Open through the trigger's activation path.
	trigger_part = testui.find(&handle, testui.Query{role=.Button, name="Actions", match_role=true, match_name=true})
	if testing.expect(t, trigger_part.match == .Unique, "the trigger should still be unique") {
		_ = testui.click(&handle, &trigger_part.element)
	}
	testui.destroy_find_result(&trigger_part)
	testing.expect(t, app.state.open, "trigger activation should open the menu")
	_ = testui.describe_once(&handle)

	menu_part := testui.find(&handle, testui.Query{role=.Menu, name="Actions", match_role=true, match_name=true})
	if !testing.expect(t, menu_part.match == .Unique, "the popup should publish one Menu") {
		testui.destroy_find_result(&menu_part)
		return
	}
	testing.expect(t, !menu_part.element.is_collection,
		"the pinned runtime has no Menu collection role; the menu publishes a flat group")
	testui.destroy_find_result(&menu_part)

	checked := find_item(&handle, "Duplicate")
	if testing.expect(t, checked.match == .Unique, "the checked item should be realized") {
		testing.expect(t, alicorn.semantic_states_has(checked.element.states, .Checked),
			"a checked menu item should publish Checked")
		testing.expect(t, alicorn.semantic_actions_has(checked.element.actions, .Press),
			"an enabled item should advertise Press")
	}
	testui.destroy_find_result(&checked)

	disabled := find_item(&handle, "Archive")
	if testing.expect(t, disabled.match == .Unique, "the disabled item should be realized") {
		testing.expect(t, alicorn.semantic_states_has(disabled.element.states, .Disabled),
			"a disabled item should publish Disabled")
		testing.expect(t, !alicorn.semantic_actions_has(disabled.element.actions, .Press),
			"a disabled item must not advertise Press")
	}
	testui.destroy_find_result(&disabled)

	// Keyboard Down skips separators and disabled rows; Return chooses Delete.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, app.state.active_key, u64(5))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Return})
	testing.expect(t, !app.state.open, "keyboard activation should close the menu")
	testing.expect_value(t, app.chosen, u64(5))
	_ = testui.describe_once(&handle)
	testing.expect_value(t, alicorn.focused_node(handle.runtime), app.state.trigger_node)

	// Escape closes without a chosen command, and focus returns to the trigger.
	app.chosen = 0
	trigger_part = testui.find(&handle, testui.Query{role=.Button, name="Actions", match_role=true, match_name=true})
	if testing.expect(t, trigger_part.match == .Unique, "the trigger should be available again") {
		_ = testui.click(&handle, &trigger_part.element)
	}
	testui.destroy_find_result(&trigger_part)
	_ = testui.describe_once(&handle)
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Escape})
	testing.expect(t, !app.state.open, "Escape should close the menu")
	testing.expect_value(t, app.chosen, u64(0))
	_ = testui.describe_once(&handle)
	testing.expect_value(t, alicorn.focused_node(handle.runtime), app.state.trigger_node)
}

@(test)
test_menu_pointer_selection_outside_dismissal_and_placement :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	trigger_part := testui.find(&handle, testui.Query{role=.Button, name="Actions", match_role=true, match_name=true})
	if !testing.expect(t, trigger_part.match == .Unique, "the trigger should be available") {
		testui.destroy_find_result(&trigger_part)
		return
	}
	_ = testui.click(&handle, &trigger_part.element)
	testui.destroy_find_result(&trigger_part)
	_ = testui.describe_once(&handle)

	item := find_item(&handle, "Delete")
	if testing.expect(t, item.match == .Unique, "Delete should be realized") {
		status := testui.click(&handle, &item.element)
		testing.expectf(t, status == .Ok, "Delete should accept a pointer click: %v", status)
		testing.expect_value(t, app.chosen, u64(5))
		testing.expect(t, !app.state.open, "pointer selection should close the menu")
	}
	testui.destroy_find_result(&item)
	_ = testui.describe_once(&handle)

	// Reopen with very little vertical space below the trigger: placement must
	// flip above the anchor and remain inside the viewport.
	app.chosen = 0
	app.top_space = 300
	alicorn.invalidate_root(handle.runtime, "fixture moved trigger down")
	_ = testui.describe_once(&handle)
	trigger_part = testui.find(&handle, testui.Query{role=.Button, name="Actions", match_role=true, match_name=true})
	if testing.expect(t, trigger_part.match == .Unique, "the moved trigger should be realized") {
		_ = testui.click(&handle, &trigger_part.element)
	}
	testui.destroy_find_result(&trigger_part)
	_ = testui.describe_once(&handle)
	testing.expect(t, app.state.open, "the menu should reopen near the viewport bottom")
	viewport_height := alicorn.viewport_bounds(handle.runtime).h
	panel := app.state.panel_bounds
	testing.expect(t, panel.h > 0 && panel.y >= 0 && panel.y+panel.h <= viewport_height+0.01,
		"placement should keep the popup inside the viewport")
	testing.expect(t, panel.y < app.state.anchor.y,
		"a bottom-anchored popup should flip above its trigger")

	// A pointer down outside the panel dismisses without choosing.
	_ = testui.step(&handle, testui.Input{kind=.Pointer, pointer=alicorn.Pointer_Event{
		kind=.Down, button=alicorn.POINTER_BUTTON_PRIMARY, x=2, y=2,
	}})
	testing.expect(t, !app.state.open, "a pointer down outside the panel should dismiss the menu")
	testing.expect_value(t, app.chosen, u64(0))
}
