package icon_picker

// Parts-level public-surface tests. The fixture composes search, grid_begin,
// item_begin, a custom cell/row visual, item_end, and grid_end exactly as an
// application would.

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

PARTS_CHOICES :: [4]Choice{
	{key=1, label="Home", icon=.Folder_Closed, detail="Workspace home"},
	{key=2, label="Search", icon=.Search, detail="Find anything"},
	{key=3, label="Locked", icon=.Close, detail="Unavailable", disabled=true},
	{key=4, label="Settings", icon=.Settings, detail="Preferences"},
}

Parts_App :: struct {
	state:   State,
	choices: [4]Choice,
	options: Options,
	last:    u64,
	events:  int,
}

parts_render :: proc(app: ^Parts_App, ctx: ^ui.UI) {
	if !ui.key_scope(ctx, alicorn.key_string("icon-picker-parts-scope")) { return }
	root := alicorn.container_begin(
		ctx,
		.Container,
		label="icon-picker-parts-root",
		key=alicorn.key_string("icon-picker-parts-root"),
		style=ui.layout_style(.Column, width=-1, height=alicorn.LAYOUT_SIZE_FIT_CONTENT, gap=8),
	)
	if root == 0 { return }
	_ = ui.interaction_scope(ctx, root, rawptr(app), alicorn.Interaction_Scope_Options{
		keys=NAVIGATION_KEYS,
		composition_yield_keys=NAVIGATION_KEYS,
		text_preempt_keys=SEARCH_YIELD_KEYS,
	})
	_, _ = search(ctx, &app.state, app.options, key=alicorn.key_string("icon-picker-parts-search"))
	grid, visible := grid_begin(ctx, &app.state, app.choices[:], app.options,
		key=alicorn.key_string("icon-picker-parts-grid"), instance_id=9801, scope_owner=root)
	if !visible {
		_ = empty(ctx, &app.state, app.options)
		alicorn.container_end(ctx)
		return
	}
	for index := grid.first; index < grid.last; index += 1 {
		item, item_visible := item_begin(ctx, &grid, index)
		if !item_visible { continue }
		if app.options.appearance == .Grid {
			// Author-owned cell: a rounded swatch with a monogram instead of the
			// default icon cell.
			if ui.panel(ctx, key=ui.key_u64(1), width=-1, height=-1, padding=4,
				align=.Center, justify=.Center,
				fill=alicorn.style_color(ctx, .Selection if item.selected else .Subtle_Surface),
				radius=10,
				stroke=ui.border(2 if item.active else 1,
					alicorn.style_color(ctx, .Focus if item.active else .Border), .Inside),
				label="parts-icon-cell") {
				_ = ui.text(ctx, item.choice.label[:1], key=ui.key_u64(2), size=14)
			}
		} else {
			// Author-owned list row: label and detail without the default icon.
			if ui.panel(ctx, key=ui.key_u64(1), width=-1, height=app.options.row_height-2,
				padding=8, gap=8, align=.Center,
				fill=alicorn.style_color(ctx, .Selection if item.selected else .Surface),
				radius=6, label="parts-icon-row") {
				if ui.column(ctx, key=ui.key_u64(2), grow=1, gap=1) {
					_ = ui.text(ctx, item.choice.label, key=ui.key_u64(3), size=13)
					_ = ui.text(ctx, item.choice.detail, key=ui.key_u64(4), size=10,
						color=alicorn.style_color(ctx, .Muted_Text))
				}
				if item.selected {
					_ = ui.icon(ctx, .Check, key=ui.key_u64(5), size=14, color_role=.Accent)
				}
			}
		}
		item_end(ctx, &grid, item)
	}
	if event := grid_end(ctx, &grid); event.kind == .Activated {
		app.last = event.key
		app.state.selected_key = event.key
		app.events += 1
	}
	alicorn.container_end(ctx)
}

parts_initialize :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	app := cast(^Parts_App)data
	if !init(&app.state) { return }
	app.state.selected_key = 1
	_ = request_grid_focus(&app.state)
}

parts_open :: proc(app: ^Parts_App, t: ^testing.T) -> (testui.Test_Handle(Parts_App), bool) {
	app.choices = PARTS_CHOICES
	if app.options.columns == 0 {
		app.options = Options{accessible_label="Icon choices", search_accessible_name="Search icons",
			appearance=.Grid, columns=2, cell_size=44, cell_gap=6, row_height=34, max_visible_rows=4}
	}
	handle, status := testui.open(app, parts_render, width=420, height=360,
		initialize=parts_initialize)
	if !testing.expectf(t, status == .Ok, "the icon picker parts fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(test)
test_icon_picker_parts_custom_grid_preserves_semantics_and_activation :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, ok := parts_open(&app, t)
	if !ok {
		destroy(&app.state)
		return
	}
	defer destroy(&app.state)
	defer testui.close(&handle)

	list := testui.find(&handle, testui.Query{role=.List_Box, name="Icon choices",
		match_role=true, match_name=true})
	if testing.expect(t, list.match == .Unique, "the grid part should publish one List_Box") {
		testing.expect(t, list.element.is_collection && list.element.logical_count == 4,
			"the grid part should publish four logical choices")
	}
	testui.destroy_find_result(&list)

	home := testui.find(&handle, testui.Query{role=.List_Box_Option, name="Home",
		match_role=true, match_name=true})
	if testing.expect(t, home.match == .Unique, "the custom cell should publish List_Box_Option") {
		testing.expect(t, home.element.collection_selected, "the controlled selection should be Selected")
	}
	testui.destroy_find_result(&home)

	// Down moves one row; Right moves one cell; Return proposes the same key
	// through the custom visual parts.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Right})
	testing.expect_value(t, active_key(&app.state), u64(4))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Return})
	testing.expect_value(t, app.last, u64(4))
	testing.expect_value(t, app.events, 1)
	testing.expect_value(t, app.state.selected_key, u64(4))

	locked := testui.find(&handle, testui.Query{role=.List_Box_Option, name="Locked",
		match_role=true, match_name=true})
	if testing.expect(t, locked.match == .Unique, "the disabled cell should be realized") {
		testing.expect(t, alicorn.semantic_states_has(locked.element.states, .Disabled),
			"the disabled cell should publish Disabled")
	}
	testui.destroy_find_result(&locked)
}

@(test)
test_icon_picker_parts_custom_list_row_and_search_part :: proc(t: ^testing.T) {
	app := Parts_App{}
	app.options = Options{accessible_label="Icon choices", search_accessible_name="Search icons",
		appearance=.List, columns=2, cell_size=44, cell_gap=6, row_height=40, max_visible_rows=3}
	handle, ok := parts_open(&app, t)
	if !ok {
		destroy(&app.state)
		return
	}
	defer destroy(&app.state)
	defer testui.close(&handle)

	search_field := testui.find(&handle, testui.Query{role=.Text_Field, name="Search icons",
		match_role=true, match_name=true})
	testing.expect(t, search_field.match == .Unique, "the search part should publish a labeled Text_Field")
	testui.destroy_find_result(&search_field)

	settings := testui.find(&handle, testui.Query{role=.List_Box_Option, name="Settings",
		match_role=true, match_name=true})
	if testing.expect(t, settings.match == .Unique, "the custom list row should publish List_Box_Option") {
		_ = testui.step(&handle, testui.Input{kind=.Key, key=.End})
		_ = testui.step(&handle, testui.Input{kind=.Key, key=.Return})
		testing.expect_value(t, app.last, u64(4))
	}
	testui.destroy_find_result(&settings)
}
