package radio_group

// Parts-level public-surface tests. These fixtures call group_begin,
// item_begin, item_end, and group_end directly, build a non-default visual
// subtree, and drive the result through alicorn:testui exactly as an
// application would.

import "core:fmt"
import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

PARTS_OPTIONS :: [3]Option{
	{value=101, label="Starter", description="For trying ideas"},
	{value=102, label="Studio", description="For small teams"},
	{value=103, label="Scale", description="For organizations", disabled=true},
}

PARTS_PRICES :: [3]string{"$0", "$12", "$48"}

Seen_Item :: struct {
	checked:  bool,
	focused:  bool,
	disabled: bool,
	index:    int,
	count:    int,
}

Parts_App :: struct {
	state:      State,
	options:    [3]Option,
	selected:   u64,
	seen:       [3]Seen_Item,
	unknown_visible: bool,
	events:     int,
	last_value: u64,
}

parts_render :: proc(app: ^Parts_App, ctx: ^ui.UI) {
	_ = ui.text(ctx, "Choose a plan", size=18)
	group, visible := group_begin(
		ctx,
		&app.state,
		app.options[:],
		app.selected,
		label="Plan",
		key=alicorn.key_string("parts-plan"),
		instance_id=9301,
		group_options=Options{
			orientation=.Vertical,
			item_height=92,
			item_min_width=440,
			item_padding=12,
			item_gap=10,
		},
	)
	if !visible { return }

	// A deliberately radical appearance: no default indicator or label part.
	// The author owns the whole card layout inside the semantic Button owner.
	prices := PARTS_PRICES
	for option, index in app.options {
		item, item_visible := item_begin(ctx, &group, option)
		if !item_visible { continue }
		app.seen[index] = Seen_Item{
			checked=item.checked,
			focused=item.focused,
			disabled=item.disabled,
			index=item.index,
			count=item.count,
		}
		if ui.row(ctx, key=ui.key_u64(1), width=-1, height=-1, gap=12, align=.Center) {
			// A custom picture part stands in for the default radio dot.
			if alicorn.surface_begin(ctx, alicorn.surface_core_color_role(.Accent), key=ui.key_u64(2),
				style=ui.layout_style(.Row, width=44, height=44, align=.Center, justify=.Center),
				shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=10},
				label="plan-picture") != 0 {
				_ = ui.icon(ctx, .Settings, key=ui.key_u64(3), size=22)
				alicorn.surface_end(ctx)
			}
			if ui.column(ctx, key=ui.key_u64(4), grow=1, gap=2) {
				_ = ui.text(ctx, option.label, key=ui.key_u64(5), size=16)
				_ = ui.text(ctx, option.description, key=ui.key_u64(6), size=12,
					color=alicorn.style_color(ctx, .Muted_Text))
			}
			_ = ui.text(ctx, prices[index], key=ui.key_u64(7), size=15)
			if item.checked {
				_ = ui.icon(ctx, .Check, key=ui.key_u64(8), size=18, color_role=.Accent)
			}
		}
		item_end(ctx, item)
	}

	// An option outside the group must be invisible and publish no semantics.
	_, app.unknown_visible = item_begin(ctx, &group, Option{value=999, label="Ghost"})

	event := group_end(ctx, &group)
	if event.kind == .Selection_Proposed {
		app.selected = event.value
		app.last_value = event.value
		app.events += 1
	}
}

parts_open :: proc(app: ^Parts_App, t: ^testing.T) -> (testui.Test_Handle(Parts_App), bool) {
	app.options = PARTS_OPTIONS
	app.selected = 101
	_ = request_focus(&app.state)
	handle, status := testui.open(app, parts_render, width=560, height=380)
	if !testing.expectf(t, status == .Ok, "the parts fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
find_parts_radio :: proc(handle: ^testui.Test_Handle(Parts_App), name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{
		role=.Radio_Button, name=name, match_role=true, match_name=true,
	})
}

@(test)
test_radio_parts_custom_cards_keep_semantics_keyboard_and_parity :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	group := testui.find(&handle, testui.Query{
		role=.Radio_Group, name="Plan", match_role=true, match_name=true,
	})
	defer testui.destroy_find_result(&group)
	if !testing.expect(t, group.match == .Unique && group.element.logical_count == 3,
		"the custom group should publish one three-option collection") { return }
	testing.expect_value(t, group.element.collection_selected_id, option_semantic_id(9301, 101))
	testing.expect_value(t, group.element.collection_current_id, option_semantic_id(9301, 101))

	starter := find_parts_radio(&handle, "Starter")
	studio := find_parts_radio(&handle, "Studio")
	scale := find_parts_radio(&handle, "Scale")
	defer testui.destroy_find_result(&starter)
	defer testui.destroy_find_result(&studio)
	defer testui.destroy_find_result(&scale)
	if !testing.expect(t, starter.match == .Unique && studio.match == .Unique && scale.match == .Unique,
		"all custom cards should publish their Radio_Button semantics") { return }
	testing.expect(t, starter.element.collection_selected && starter.element.collection_current,
		"the custom card should still publish Checked/Selected and Current")
	testing.expect(t, alicorn.semantic_states_has(scale.element.states, .Disabled),
		"the custom disabled card should publish Disabled")
	testing.expect(t, !alicorn.semantic_actions_has(scale.element.actions, .Press),
		"the custom disabled card must not advertise Press")

	// The custom appearance omitted the default indicator part; semantics and
	// the interaction owner are independent of that visual choice.
	testing.expect(t, !alicorn.visual_part_owner_has_role(handle.runtime, starter.element.visual_node, .Indicator),
		"the custom cards should not publish the default radio indicator part")

	// The item context exposed the state the author needed for custom drawing.
	testing.expect(t, app.seen[0].checked && app.seen[0].focused && !app.seen[0].disabled,
		"the first item should expose checked and focused state")
	testing.expect(t, app.seen[2].disabled && !app.seen[2].checked,
		"the third item should expose disabled state")
	testing.expect(t, app.seen[0].index == 0 && app.seen[1].index == 1 && app.seen[0].count == 3,
		"the item context should expose position in the keyed set")

	// Down skips the disabled third card and proposes the second card.
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok,
		"the custom group should keep its scoped Down key")
	testing.expect_value(t, app.selected, u64(102))
	testing.expect_value(t, app.last_value, u64(102))
	testing.expect(t, app.seen[1].focused && app.seen[1].checked,
		"the re-described custom card should expose the new checked/focused state")

	// Pointer and semantic activation share the same proposal path.
	studio = find_parts_radio(&handle, "Studio")
	starters := find_parts_radio(&handle, "Starter")
	_ = testui.click(&handle, &starters.element)
	testing.expect_value(t, app.selected, u64(101))
	status := testui.step(&handle, testui.Input{
		kind=.Semantic_Action,
		semantic_id=studio.element.semantic_id,
		semantic_action=.Press,
	})
	testing.expect(t, status == .Ok, "semantic Press should work on a custom-rendered radio")
	testing.expect_value(t, app.selected, u64(102))
	testing.expect(t, app.events >= 3, "keyboard, pointer, and semantic activation should agree")
	testing.expect(t, !app.unknown_visible,
		"item_begin must return visible=false for an option outside the keyed set")

	// Idle settlement: no retained description or presentation remains.
	if testing.expect(t, testui.step(&handle, testui.Input{kind=.Time_Advance, delta_ns=16_000_000}) == .Ok,
		"the custom radio group should settle after an idle time advance") {
		turn := testui.last_turn(&handle)
		testing.expect(t, turn.stabilized && !turn.layout_pending,
			"the custom radio group should report a stabilized, layout-clean idle turn")
	}
}

@(test)
test_radio_parts_default_indicator_is_present_and_omissible :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	small := find_radio(&handle, "Small")
	if !testing.expect(t, small.match == .Unique, "the default fixture should realize Small") { return }
	testing.expect(t, alicorn.visual_part_owner_has_role(handle.runtime, small.element.visual_node, .Indicator),
		"the default indicator part should be present for the convenience wrapper")
	testui.destroy_find_result(&small)
}

@(test)
test_radio_parts_reorder_keeps_custom_identity_and_selection :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	before := find_parts_radio(&handle, "Studio")
	id_before := before.element.semantic_id
	testui.destroy_find_result(&before)

	app.options = [3]Option{
		{value=103, label="Scale", disabled=true},
		{value=101, label="Starter"},
		{value=102, label="Studio"},
	}
	app.selected = 102
	alicorn.invalidate_root(handle.runtime, "parts fixture reordered options")
	_ = testui.describe_once(&handle)
	studio := find_parts_radio(&handle, "Studio")
	defer testui.destroy_find_result(&studio)
	testing.expect(t, studio.match == .Unique && studio.element.semantic_id == id_before,
		"the custom card identity should follow the stable value after reorder")
	testing.expect(t, studio.element.collection_selected,
		"the custom rendering should keep Checked/Selected on the stable value")
}

@(test)
test_radio_parts_custom_card_bounds_are_author_owned :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	starter := find_parts_radio(&handle, "Starter")
	studio := find_parts_radio(&handle, "Studio")
	defer testui.destroy_find_result(&starter)
	defer testui.destroy_find_result(&studio)
	if !testing.expect(t, starter.match == .Unique && studio.match == .Unique, "both cards should exist") { return }
	testing.expectf(t, starter.element.bounds.h >= 90 && studio.element.bounds.y > starter.element.bounds.y,
		"the author-owned 92px card geometry should be realized: starter=%v studio=%v",
		starter.element.bounds, studio.element.bounds)
	fmt.println("radio_parts_idle", "events", app.events, "idle", true)
}
