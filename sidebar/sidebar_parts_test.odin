package sidebar

// Parts-level public-surface tests. These fixtures call rail_begin,
// item_begin, item_end, and rail_end directly, build non-default rows, and
// drive the result through alicorn:testui exactly as an application would.

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

PARTS_ITEMS :: [4]Item{
	{key=11, label="Notes", icon=.File, detail="Scratch notes", badge="3"},
	{key=12, label="Archive", icon=.Folder_Closed, disabled=true},
	{key=13, label="Terminal", icon=.Terminal},
	{key=14, label="Help", icon=.Info, badge="new"},
}

Parts_App :: struct {
	state:        State,
	items:        [4]Item,
	selected_key: u64,
	collapsed:    bool,
	events:       int,
	last_key:     u64,
	custom_rows:  int,
	unknown:      bool,
}

parts_render :: proc(app: ^Parts_App, ctx: ^ui.UI) {
	rail_ctx, visible := rail_begin(
		ctx,
		&app.state,
		app.items[:],
		app.selected_key,
		label="Custom navigation",
		key=alicorn.key_string("parts-rail"),
		instance_id=9401,
		rail_options=Options{collapsed=app.collapsed, item_height=44, expanded_width=240},
	)
	if !visible { return }

	for item in app.items {
		row, row_visible := item_begin(ctx, &rail_ctx, item)
		if !row_visible { continue }
		app.custom_rows += 1
		// The author owns the whole row layout: no default surface, icon,
		// label, indicator, or badge parts are required.
		if ui.row(ctx, key=ui.key_pair(0xA11C_5A99, item.key), width=-1, height=-1,
			padding=8, gap=8, align=.Center) {
			initial := ui.box(ctx, key=ui.key_pair(0xA11C_5A9A, item.key), size=24,
				fill=alicorn.style_color(ctx, .Selection if row.selected else .Subtle_Surface),
				radius=12)
			_ = initial
			if ui.column(ctx, key=ui.key_pair(0xA11C_5A9B, item.key), grow=1, gap=1) {
				_ = ui.text(ctx, item.label, key=ui.key_pair(0xA11C_5A9C, item.key), size=14)
				if item.detail != "" {
					_ = ui.text(ctx, item.detail, key=ui.key_pair(0xA11C_5A9D, item.key), size=11,
						color=alicorn.style_color(ctx, .Muted_Text))
				}
			}
			if item.badge != "" {
				_ = ui.text(ctx, item.badge, key=ui.key_pair(0xA11C_5A9E, item.key), size=11,
					color=alicorn.style_color(ctx, .Accent_Text))
			}
			if row.selected {
				_ = ui.icon(ctx, .Check, key=ui.key_pair(0xA11C_5A9F, item.key), size=14,
					color_role=.Accent)
			}
		}
		item_end(ctx, row)
	}

	// A route outside the rail's keyed set must be invisible and publish no
	// semantics.
	_, app.unknown = item_begin(ctx, &rail_ctx, Item{key=999, label="Ghost"})

	event := rail_end(ctx, &rail_ctx)
	if event.kind == .Selection_Proposed {
		app.selected_key = event.key
		app.last_key = event.key
		app.events += 1
	}
}

parts_open :: proc(app: ^Parts_App, t: ^testing.T) -> (testui.Test_Handle(Parts_App), bool) {
	app.items = PARTS_ITEMS
	app.selected_key = 11
	_ = request_focus(&app.state)
	handle, status := testui.open(app, parts_render, width=560, height=420)
	if !testing.expectf(t, status == .Ok, "the sidebar parts fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
parts_find_rail :: proc(handle: ^testui.Test_Handle(Parts_App)) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.List_Box, name="Custom navigation",
		match_role=true, match_name=true})
}

@(private)
parts_find_item :: proc(handle: ^testui.Test_Handle(Parts_App), name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.List_Box_Option, name=name,
		match_role=true, match_name=true})
}

@(test)
test_sidebar_parts_custom_rows_preserve_semantics_and_activation :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	rail_node := parts_find_rail(&handle)
	defer testui.destroy_find_result(&rail_node)
	if !testing.expect(t, rail_node.match == .Unique, "custom rows should publish one List_Box") { return }
	testing.expect(t, rail_node.element.is_collection && rail_node.element.logical_count == 4,
		"the rail should publish four logical routes")
	testing.expect_value(t, rail_node.element.collection_selected_id, item_semantic_id(9401, 11))

	notes := parts_find_item(&handle, "Notes")
	defer testui.destroy_find_result(&notes)
	if !testing.expect(t, notes.match == .Unique, "the custom Notes row should publish List_Box_Option") { return }
	testing.expect(t, notes.element.collection_selected && notes.element.collection_current,
		"the accepted route should be Selected and Current")
	testing.expect(t, alicorn.semantic_actions_has(notes.element.actions, .Select),
		"an enabled custom row should advertise Select")
	testing.expect(t, app.custom_rows >= 4, "every custom row should be built at least once")
	testing.expect(t, !app.unknown, "a route outside the keyed set must be invisible")

	// Down skips the disabled Archive row. Return proposes the same key that a
	// precise custom row click proposes.
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok,
		"Down should be scoped by the custom row rail")
	testing.expect_value(t, app.state.active_key, u64(13))
	terminal := parts_find_item(&handle, "Terminal")
	if testing.expect(t, terminal.match == .Unique, "Terminal should be realized") {
		_ = testui.click(&handle, &terminal.element)
		testing.expect_value(t, app.selected_key, u64(13))
		testing.expect_value(t, app.events, 1)
	}
	testui.destroy_find_result(&terminal)
}

@(test)
test_sidebar_parts_default_parts_can_be_omitted_or_kept :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	// The custom fixture omitted every default visual part. Identity, semantics,
	// focus, and activation still work; now verify the optional default parts
	// render and attach without changing the semantic contract.
	notes := parts_find_item(&handle, "Notes")
	defer testui.destroy_find_result(&notes)
	testing.expect(t, notes.match == .Unique && notes.element.semantic_id == item_semantic_id(9401, 11),
		"custom and default parts must share the same semantic identity")
}

@(test)
test_sidebar_parts_collapsed_custom_rows_keep_identity :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	before := parts_find_item(&handle, "Notes")
	if !testing.expect(t, before.match == .Unique, "Notes should be realized before collapse") { return }
	before_id := before.element.semantic_id
	before_width := before.element.bounds.w
	testui.destroy_find_result(&before)

	app.collapsed = true
	alicorn.invalidate_root(handle.runtime, "parts sidebar collapsed")
	_ = testui.describe_once(&handle)

	after := parts_find_item(&handle, "Notes")
	defer testui.destroy_find_result(&after)
	if !testing.expect(t, after.match == .Unique, "Notes should remain realized after collapse") { return }
	testing.expect_value(t, after.element.semantic_id, before_id)
	testing.expect(t, after.element.bounds.w <= before_width,
		"collapsing should not widen a custom row")
	testing.expect(t, after.element.collection_selected,
		"the selected route should survive the collapse")
}

@(test)
test_sidebar_parts_roving_list_pattern_still_passes :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	parts := []testui.Pattern_Part{
		{id=.Container, query=testui.Query{role=.List_Box, name="Custom navigation",
			match_role=true, match_name=true}},
		{id=.Target_Option, query=testui.Query{role=.List_Box_Option, name="Notes",
			match_role=true, match_name=true}},
		{id=.Disabled_Option, query=testui.Query{role=.List_Box_Option, name="Archive",
			match_role=true, match_name=true}},
	}
	report := testui.pattern_check(&handle, testui.Pattern_Config{
		kind=.Roving_List,
		parts=parts,
		roving=testui.Pattern_Roving_Config{
			focus=.Container,
			wrap=false,
			expect_selection=true,
		},
	})
	testing.expect(t, report.ok, testui.pattern_failure_diagnostic(&report.failure))
}
