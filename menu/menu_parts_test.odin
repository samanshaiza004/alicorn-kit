package menu

// Parts-level public-surface tests. These fixtures call popup_begin, group
// parts, item_begin/item_end, and popup_end directly, build custom rows, and
// drive the result through alicorn:testui exactly as an application would.

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

PARTS_ITEMS :: [6]Item{
	{key=11, label="Rename", detail="Change the item name", shortcut="F2"},
	{key=12, label="Pin to top", detail="Keep this item first", checked=true},
	{key=13, kind=.Separator},
	{key=14, label="Archive", detail="Unavailable for this item", disabled=true},
	{key=15, label="Delete", detail="Remove permanently", shortcut="Del"},
	{key=16, kind=.Separator},
}

Parts_App :: struct {
	state:       State,
	items:       [6]Item,
	chosen:      u64,
	activations: int,
}

parts_render :: proc(app: ^Parts_App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("menu-parts-root"), width=-1, height=-1,
		padding=20, gap=8) {
		_ = trigger(ctx, &app.state, "Actions",
			options=Options{accessible_label="Actions"},
			key=alicorn.key_string("menu-parts-trigger"))
		_ = ui.button(ctx, "Background", key=alicorn.key_string("menu-parts-background"),
			width=120, height=30)
	}
}

parts_overlays :: proc(app: ^Parts_App, ctx: ^ui.UI) {
	visible, chosen := popup_begin(ctx, &app.state, app.items[:],
		Options{accessible_label="Actions"}, key=alicorn.key_string("menu-parts-popup"),
		instance_id=9501)
	if !visible {
		if chosen != 0 { app.chosen = chosen; app.activations += 1 }
		return
	}
	for value, index in app.items {
		if value.kind == .Separator {
			separator(ctx, index)
			continue
		}
		// An ad-hoc semantic group around the dangerous rows. The pinned
		// runtime still rejects .Menu collections, so this is nested Menu
		// semantics without a count.
		in_danger_group := index >= 3
		if index == 3 {
			_ = group_begin(ctx, &app.state, "Danger", key=alicorn.key_string("menu-parts-danger"))
		}
		row, row_visible := item_begin(ctx, &app.state, value, index)
		if row_visible {
			// A custom row: icon chip, label, detail, checked mark, shortcut.
			if row_surface(ctx, row) != 0 {
				_ = ui.box(ctx, key=ui.key_pair(0xA11C_6D40, value.key), size=20,
					fill=alicorn.style_color(ctx, .Selection if row.selected else .Subtle_Surface),
					radius=6)
				if ui.column(ctx, key=ui.key_pair(0xA11C_6D41, value.key), grow=1, gap=1) {
					_ = ui.text(ctx, value.label, key=ui.key_pair(0xA11C_6D42, value.key), size=13,
						color=alicorn.style_color(ctx, .Muted_Text if row.disabled else .Text))
					if value.detail != "" {
						_ = ui.text(ctx, value.detail, key=ui.key_pair(0xA11C_6D43, value.key), size=10,
							color=alicorn.style_color(ctx, .Muted_Text))
					}
				}
				if row.checked {
					_ = ui.text(ctx, "\u2713", key=ui.key_pair(0xA11C_6D44, value.key), size=12,
						color=alicorn.style_color(ctx, .Accent))
				}
				if value.shortcut != "" {
					_ = ui.text(ctx, value.shortcut, key=ui.key_pair(0xA11C_6D45, value.key), size=10,
						color=alicorn.style_color(ctx, .Muted_Text))
				}
				alicorn.surface_end(ctx)
			}
			if item_end(ctx, row) {
				app.chosen = value.key
				app.activations += 1
			}
		}
		if in_danger_group && index == 4 { group_end(ctx) }
	}
	popup_end(ctx, &app.state)
}

parts_open :: proc(app: ^Parts_App, t: ^testing.T) -> (testui.Test_Handle(Parts_App), bool) {
	app.items = PARTS_ITEMS
	handle, status := testui.open(app, parts_render, width=560, height=420,
		render_overlays=parts_overlays)
	if !testing.expectf(t, status == .Ok, "the menu parts fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
parts_find_item :: proc(handle: ^testui.Test_Handle(Parts_App), name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.Menu_Item, name=name, match_role=true, match_name=true})
}

@(private)
parts_open_menu :: proc(app: ^Parts_App, handle: ^testui.Test_Handle(Parts_App), t: ^testing.T) {
	trigger_part := testui.find(handle, testui.Query{role=.Button, name="Actions",
		match_role=true, match_name=true})
	if !testing.expect(t, trigger_part.match == .Unique, "the parts trigger should be available") {
		testui.destroy_find_result(&trigger_part)
		return
	}
	_ = testui.click(handle, &trigger_part.element)
	testui.destroy_find_result(&trigger_part)
	_ = testui.describe_once(handle)
}

@(test)
test_menu_parts_custom_rows_groups_and_semantics :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	parts_open_menu(&app, &handle, t)
	testing.expect(t, app.state.open, "the trigger should open the parts menu")

	popup := testui.find(&handle, testui.Query{role=.Menu, name="Actions",
		match_role=true, match_name=true})
	if testing.expect(t, popup.match == .Unique, "the popup should publish one Menu") {
		testing.expect(t, !popup.element.is_collection,
			"the pinned runtime still rejects Menu collections")
	}
	testui.destroy_find_result(&popup)

	group := testui.find(&handle, testui.Query{role=.Menu, name="Danger",
		match_role=true, match_name=true})
	if testing.expect(t, group.match == .Unique, "group_begin should publish ad-hoc Menu semantics") {
		testing.expect(t, !group.element.is_collection,
			"an ad-hoc group is not a composite collection")
	}
	testui.destroy_find_result(&group)

	pinned := parts_find_item(&handle, "Pin to top")
	if testing.expect(t, pinned.match == .Unique, "the checked custom row should be realized") {
		testing.expect(t, alicorn.semantic_states_has(pinned.element.states, .Checked),
			"a checked custom row should publish Checked")
		testing.expect(t, pinned.element.description == "Keep this item first",
			"custom rows keep the item detail as the semantic description")
	}
	testui.destroy_find_result(&pinned)

	archive := parts_find_item(&handle, "Archive")
	if testing.expect(t, archive.match == .Unique, "the disabled custom row should be realized") {
		testing.expect(t, alicorn.semantic_states_has(archive.element.states, .Disabled),
			"a disabled custom row should publish Disabled")
		testing.expect(t, !alicorn.semantic_actions_has(archive.element.actions, .Press),
			"a disabled custom row must not advertise Press")
	}
	testui.destroy_find_result(&archive)
}

@(test)
test_menu_parts_keyboard_pointer_escape_and_outside_dismissal :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	parts_open_menu(&app, &handle, t)
	// Down skips the separator and the disabled Archive row: Rename -> Pin ->
	// Delete. Return chooses Delete through the same one-shot path as the
	// convenience item helper.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, app.state.active_key, u64(15))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Return})
	testing.expect(t, !app.state.open, "keyboard activation should close the parts menu")
	testing.expect_value(t, app.chosen, u64(15))
	_ = testui.describe_once(&handle)
	testing.expect_value(t, alicorn.focused_node(handle.runtime), app.state.trigger_node)

	// Pointer activation on a custom row chooses its stable key.
	app.chosen = 0
	parts_open_menu(&app, &handle, t)
	rename := parts_find_item(&handle, "Rename")
	if testing.expect(t, rename.match == .Unique, "Rename should be realized") {
		status := testui.click(&handle, &rename.element)
		testing.expectf(t, status == .Ok, "a custom row should accept a pointer click: %v", status)
		testing.expect_value(t, app.chosen, u64(11))
		testing.expect(t, !app.state.open, "pointer activation should close the parts menu")
	}
	testui.destroy_find_result(&rename)
	_ = testui.describe_once(&handle)

	// Escape closes without a choice; focus returns to the trigger.
	app.chosen = 0
	parts_open_menu(&app, &handle, t)
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Escape})
	testing.expect(t, !app.state.open, "Escape should close the parts menu")
	testing.expect_value(t, app.chosen, u64(0))
	_ = testui.describe_once(&handle)
	testing.expect_value(t, alicorn.focused_node(handle.runtime), app.state.trigger_node)

	// Outside pointer down dismisses without a choice.
	parts_open_menu(&app, &handle, t)
	_ = testui.step(&handle, testui.Input{kind=.Pointer, pointer=alicorn.Pointer_Event{
		kind=.Down, button=alicorn.POINTER_BUTTON_PRIMARY, x=2, y=2,
	}})
	testing.expect(t, !app.state.open, "an outside pointer down should dismiss the parts menu")
	testing.expect_value(t, app.chosen, u64(0))
}

@(test)
test_menu_parts_placement_stays_inside_the_viewport :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	parts_open_menu(&app, &handle, t)
	viewport_height := alicorn.viewport_bounds(handle.runtime).h
	panel := app.state.panel_bounds
	testing.expect(t, panel.h > 0 && panel.y >= 0 && panel.y+panel.h <= viewport_height+0.01,
		"parts popup placement should remain inside the viewport")
}
