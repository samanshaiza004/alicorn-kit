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
		if ui.row(ctx, key=alicorn.key_string("menu-fixture-trigger-row"), width=-1, height=40, align=.Center) {
			_ = trigger(ctx, &app.state, "Actions", options=DEFAULT_OPTIONS,
				key=alicorn.key_string("menu-fixture-trigger"))
		}
		if app.chosen != chosen_before { app.activations += 1 }
		_ = ui.button(ctx, "Background", key=alicorn.key_string("menu-fixture-background"), width=120, height=30)
	}
}

fixture_overlays :: proc(app: ^Test_App, ctx: ^ui.UI) {
	options := DEFAULT_OPTIONS
	options.accessible_label = "Actions"
	visible, chosen := popup_begin(ctx, &app.state, app.items[:],
		options, key=alicorn.key_string("menu-fixture-popup"), instance_id=9401, style=DEFAULT_STYLE)
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

fixture_open :: proc(app: ^Test_App, t: ^testing.T, height := 420, scale: f32 = 1) -> (testui.Test_Handle(Test_App), bool) {
	app.items = fixture_items()
	handle, status := testui.open(app, fixture_render, width=560, height=height,
		scale=scale, render_overlays=fixture_overlays)
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
test_menu_popup_item_is_visible_and_contained_at_fractional_scales :: proc(t: ^testing.T) {
	scales := [4]f32{1, 1.25, 1.5, 2}
	for scale in scales {
		app := Test_App{}
		handle, ok := fixture_open(&app, t, scale=scale)
		if !ok { continue }

		trigger := testui.find(&handle, testui.Query{role=.Button, name="Actions", match_role=true, match_name=true})
		if testing.expect(t, trigger.match == .Unique && testui.click(&handle, &trigger.element) == .Ok,
			"the menu should open through its trigger at every scale") {
			testing.expectf(t, trigger.element.has_bounds && trigger.element.bounds.w > 0 &&
				trigger.element.bounds.w < handle.runtime.viewport.w*0.5,
				"the stock trigger should fit its label instead of stretching across the window at %.2f: %v",
				scale, trigger.element.bounds)
			_ = testui.describe_once(&handle)
			menu_part := testui.find(&handle, testui.Query{role=.Menu, name="Actions", match_role=true, match_name=true})
			item_part := find_item(&handle, "Duplicate")
			if testing.expectf(t, menu_part.match == .Unique && item_part.match == .Unique,
				"the popup and checked item should be present at %.2f", scale) {
				visible := testui.expect_visible_text(&handle, &item_part.element, "Duplicate")
				inside := testui.expect_inside(&handle, &item_part.element, &menu_part.element)
				testing.expectf(t, visible.ok && inside.ok,
					"the menu item should remain visible and inside its popup at %.2f: %s %s",
					scale, testui.visible_text_diagnostic(visible), testui.layout_check_diagnostic(inside))
				highlight, highlight_found := alicorn.node_by_key(handle.runtime,
					ui.key_pair(9401, POPUP_HIGHLIGHT_KEY), .Container)
				highlight_info, highlight_info_ok := alicorn.node_info(handle.runtime, highlight)
				panel_node, panel_found := alicorn.node_by_key(handle.runtime,
					ui.key_pair(9401, 0x50414E454C), .Container)
				panel_info, panel_info_ok := alicorn.node_info(handle.runtime, panel_node)
				panel_record, panel_record_found := handle.runtime.nodes[panel_node]
				panel_padding: f32
				expected_content_width: f32
				expected_accent := alicorn.style_theme_color(handle.runtime, alicorn.DEFAULT_STYLE_THEME_ID, .Accent)
				if panel_record_found && panel_record != nil {
					panel_padding = panel_record.style.padding
					expected_content_width = panel_info.bounds.w-2*panel_padding
				}
				testing.expectf(t, highlight_found && highlight_info_ok &&
					panel_found && panel_info_ok && panel_record_found &&
					highlight_info.bounds.x >= panel_info.bounds.x+panel_padding-0.51 &&
					highlight_info.bounds.w >= expected_content_width-0.02 &&
					highlight_info.bounds.x+highlight_info.bounds.w <= panel_info.bounds.x+panel_info.bounds.w-panel_padding+0.51 &&
					highlight_info.bounds.y >= panel_info.bounds.y+2.5 &&
					highlight_info.bounds.y+highlight_info.bounds.h <= panel_info.bounds.y+panel_padding+0.02 &&
					highlight_info.bounds.h > 0 && highlight_info.bounds.h <= 2.5,
					"the decorative accent should fill visible popup top padding at %.2f: panel=%v padding=%.2f accent=%v expected_width=%.2f",
					scale, panel_info.bounds, panel_padding, highlight_info.bounds, expected_content_width)
				highlight_paint_fills := false
				highlight_display_fills := false
				highlight_display_uses_accent := false
				highlight_display_bounds := alicorn.Rect{}
				highlight_display_clip := alicorn.Rect{}
				if highlight_record, record_found := handle.runtime.nodes[highlight]; record_found && highlight_record != nil {
					for command in highlight_record.paint {
						if _, surface_ok := command.payload.(alicorn.Surface_Paint); surface_ok {
							highlight_paint_fills = command.bounds.w >= expected_content_width-0.02
							break
						}
					}
				}
				for command in handle.runtime.display_target {
					if command.owner != highlight { continue }
					if surface, surface_ok := command.payload.(alicorn.Surface_Paint); surface_ok {
						highlight_display_bounds = command.bounds
						highlight_display_clip = command.clip
						highlight_display_uses_accent = surface.fill == expected_accent
						highlight_display_fills = command.bounds.w >= expected_content_width-0.51 &&
							command.bounds.x >= panel_info.bounds.x+panel_padding-0.51 &&
							command.bounds.x+command.bounds.w <= panel_info.bounds.x+panel_info.bounds.w-panel_padding+0.51 &&
							command.clip.x <= command.bounds.x+0.51 &&
							command.clip.x+command.clip.w >= command.bounds.x+command.bounds.w-0.51
						break
					}
				}
				testing.expectf(t, highlight_paint_fills && highlight_display_fills && highlight_display_uses_accent,
					"accent paint, theme fill, finalized bounds, and clip should cover visible popup content at %.2f: paint=%v fill_ok=%v bounds=%v clip=%v expected_width=%.2f",
					scale, highlight_paint_fills, highlight_display_uses_accent, highlight_display_bounds, highlight_display_clip, expected_content_width)
				for item, separator_index in app.items {
					if item.kind != .Separator { continue }
					separator, separator_found := alicorn.node_by_key(handle.runtime,
						ui.key_u64(0xA11C_6D21+u64(separator_index)), .Container)
					separator_info, separator_info_ok := alicorn.node_info(handle.runtime, separator)
					testing.expectf(t, separator_found && separator_info_ok &&
						separator_info.bounds.w >= expected_content_width-0.02,
						"separator %d should fill the popup's padded width at %.2f", separator_index, scale)
				}
				check_glyph_visible := false
				check_text_color := alicorn.style_theme_color(handle.runtime, alicorn.DEFAULT_STYLE_THEME_ID, .Text)
				check_background := alicorn.style_theme_color(handle.runtime, alicorn.DEFAULT_STYLE_THEME_ID, .Surface)
				for command in handle.runtime.display {
					text_paint, text_ok := command.payload.(alicorn.Text_Paint)
					if !text_ok { continue }
					run, run_ok := alicorn.paint_text_run_resolve(handle.runtime, text_paint.run)
					if run_ok && run.value == "✓" {
						check_glyph_visible = text_paint.color == check_text_color &&
							alicorn.style_color_contrast_ratio(text_paint.color, check_background) >= 4.5
						break
					}
				}
				testing.expect(t, check_glyph_visible,
					"the checked marker should use legible text contrast on the default menu surface")
				_ = testui.describe_once(&handle)
				highlight_after, highlight_after_found := alicorn.node_by_key(handle.runtime,
					ui.key_pair(9401, POPUP_HIGHLIGHT_KEY), .Container)
				testing.expect(t, highlight_after_found && highlight_after == highlight,
					"re-describing the menu must preserve decorative identity")
			}
			testui.destroy_find_result(&menu_part)
			testui.destroy_find_result(&item_part)
		}
		testui.destroy_find_result(&trigger)
		testui.close(&handle)
	}
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
		visible_label := testui.expect_visible_text(&handle, &checked.element, "Duplicate")
		testing.expect(t, visible_label.ok, testui.visible_text_diagnostic(visible_label))
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
