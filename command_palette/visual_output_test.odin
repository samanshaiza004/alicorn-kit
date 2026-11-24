package command_palette

import "core:fmt"
import "core:testing"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import model "alikit:palette_model"
import parts "alikit:palette_parts"
import testui "alicorn:testui"

@(private)
Reference_Test_App :: struct {
	state:       State,
	items:       [4]Item,
	matches:     [4]Match,
	match_count: int,
	last_action: Item_ID,
}

@(private)
REFERENCE_TEST_ITEMS :: [4]Item{
	{ id=Item_ID(1), title="Export workspace", description="Create a local archive", keywords="export archive" },
	{ id=Item_ID(2), title="Export project", description="Download the selected project", keywords="export download" },
	{ id=Item_ID(3), title="Export settings", description="Choose format and destination", keywords="export preferences" },
	{ id=Item_ID(4), title="Build project", description="Run the configured build", keywords="compile", disabled=true },
}

@(private)
reference_panel_matches :: proc(element: ^testui.Element, viewport_width, viewport_height: int) -> bool {
	if element == nil || !element.has_bounds { return false }
	bounds := element.bounds
	expected_x := f32(viewport_width-660)*0.5
	expected_y := f32(viewport_height-576)*0.5
	return reference_absf(bounds.x-expected_x) <= 0.5 && reference_absf(bounds.y-expected_y) <= 0.5 &&
		reference_absf(bounds.w-660) <= 0.5 && reference_absf(bounds.h-576) <= 0.5
}

@(private)
reference_absf :: proc(value: f32) -> f32 {
	return -value if value < 0 else value
}

@(private)
reference_test_render :: proc(app: ^Reference_Test_App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("palette-reference-test-root"),
		width=-1, height=-1, padding=16) {
		if ui.button(ctx, "Open command palette", key=ui.key_string("palette-reference-test-open"),
			width=190, height=34, variant=.Primary) {
			_ = open_palette(&app.state, ctx.runtime)
		}
	}
}

@(private)
reference_test_text_change :: proc(data: rawptr, rt: ^alicorn.Runtime, change: alicorn.Text_Change) -> bool {
	return text_change(cast(^State)data, rt, change)
}

@(private)
reference_test_overlays :: proc(app: ^Reference_Test_App, ctx: ^ui.UI) {
	state := &app.state
	if !state.open { return }
	state.overlay_node = alicorn.modal_overlay_begin(ctx,
		ui.key_string("palette-reference-test-overlay"),
		style=ui.layout_style(.Column, grow=1, padding=32, align=.Center, justify=.Center, clip=true))
	if state.overlay_node == 0 { return }
	_ = ui.interaction_scope(ctx, state.overlay_node, rawptr(state), ui.Interaction_Scope_Options{
		keys={.Escape, .Open_Command_Palette, .Up, .Down, .Return},
		composition_yield_keys={.Up, .Down, .Return}, pointers={.Primary_Down}, modal=true,
		on_text_change=reference_test_text_change,
	})
	if queued, found := ui.interaction_event_next(ctx, state.overlay_node); found {
		switch queued.kind {
		case .Key:
			handled, event := handle_key(state, ctx.runtime, app.items[:], queued.key)
			_ = handled
			if event.kind == .Activated { app.last_action = event.item_id }
		case .Pointer:
			_ = pointer(state, ctx.runtime, queued.pointer, queued.target)
		}
		if !state.open { alicorn.modal_overlay_end(ctx); return }
	}

	style := ui.layout_style(.Column, width=-1, height=576,
		max_width=660, max_height=576, padding=32, gap=12, clip=true)
	state.panel_node = alicorn.surface_begin(ctx, alicorn.surface_core_color_role(.Surface),
		key=ui.key_string("palette-reference-test-panel"), style=style,
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=14},
		fill=ui.style_color(ctx, .Surface), label="palette-reference-test-panel")
	if state.panel_node != 0 {
		_ = alicorn.semantic_describe_as(ctx,
			alicorn.Semantic_ID{namespace=0x5445535450414C, value=1}, .Dialog, "Quick actions")
		_ = ui.text(ctx, "Quick actions", size=22)
		if ui.row(ctx, height=52, width=-1, gap=10, align=.Center) {
			_ = ui.icon(ctx, .Search, size=18, color_role=.Muted_Text)
			_, _ = input(ctx, state,
				Options{hide_title=true, query_accessible_name="Search actions"},
				key=ui.key_string("palette-reference-test-query"))
		}
		app.match_count, _ = model.filter(app.items[:], query_text(state), app.matches[:])
		list, opened := list_begin(ctx, state, app.items[:], app.matches[:app.match_count],
			key=ui.key_string("palette-reference-test-results"),
			options=Options{hide_title=true, results_accessible_name="Action results",
				row_height=72, list_max_height=280})
		if opened {
			activated: Item_ID
			for index in list.first..<list.last {
				row, visible := item_begin(ctx, &list, index)
				if !visible { continue }
				row_surface := parts.row_surface(ctx, row)
				if row_surface != 0 {
					icon := ui.Icon_ID.File
					if row.item.id == Item_ID(3) { icon = .Settings }
					if ui.panel(ctx, key=ui.key_u64(1), width=38, height=38,
						align=.Center, justify=.Center,
						fill=ui.style_color(ctx, .Subtle_Surface if row.selected else .Surface), radius=8) {
						_ = ui.icon(ctx, icon, key=ui.key_u64(2), size=17, color_role=.Accent)
					}
					if ui.column(ctx, key=ui.key_u64(3), width=-1, grow=1, gap=2) {
						_ = ui.text(ctx, row.item.title, key=ui.key_u64(4), size=13,
							decorative=true, text_style=ui.Text_Style{overflow=.Ellipsis})
						_ = ui.text(ctx, row.item.description, key=ui.key_u64(5), size=11,
							color=ui.style_color(ctx, .Muted_Text), decorative=true,
							text_style=ui.Text_Style{overflow=.Ellipsis})
					}
					shortcut := "CMD E"
					if row.item.id == Item_ID(2) { shortcut = "CMD SHIFT E" }
					if row.item.id == Item_ID(3) { shortcut = "CMD ," }
					if ui.panel(ctx, key=ui.key_u64(6), width=72, height=26,
						align=.Center, justify=.Center, fill=ui.style_color(ctx, .Subtle_Surface),
						radius=5, stroke=ui.border(1, ui.style_color(ctx, .Border), .Inside)) {
						_ = ui.text(ctx, shortcut, size=10, color=ui.style_color(ctx, .Muted_Text), decorative=true)
					}
					if row.selected { _ = ui.icon(ctx, .Check, key=ui.key_u64(7), size=14, color_role=.Text) }
					ui.surface_end(ctx)
				}
				if item_end(ctx, state, &list, row) { activated = row.item.id }
			}
			if event := list_end(ctx, state, &list); event.kind == .Activated { activated = event.item_id }
			if activated != 0 {
				app.last_action = activated
				close_palette(state, ctx.runtime, true)
			}
		} else if app.match_count == 0 {
			_ = empty(ctx, Options{hide_title=true, empty_message="No matching actions"})
		}
		_ = ui.text(ctx, fmt.tprintf("%d actions  ·  Up/Down navigate  ·  Enter run  ·  Esc close", app.match_count),
			size=12, color=ui.style_color(ctx, .Muted_Text))
		ui.surface_end(ctx)
	}
	alicorn.modal_overlay_end(ctx)
}

@(test)
test_reference_palette_keeps_query_rows_and_focus_correct_across_resize :: proc(t: ^testing.T) {
	app := Reference_Test_App{items=REFERENCE_TEST_ITEMS}
	if !init(&app.state) {
		testing.expect(t, false, "palette state should initialize")
		return
	}
	defer destroy(&app.state)
	handle, status := testui.open(&app, reference_test_render,
		width=1280, height=800, render_overlays=reference_test_overlays)
	if !testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle)) { return }
	defer if handle.runtime != nil { testui.close(&handle) }

	opener := testui.find(&handle, testui.Query{
		role=.Button, name="Open command palette", match_role=true, match_name=true,
	})
	if !testing.expect(t, opener.match == .Unique && testui.click(&handle, &opener.element) == .Ok,
		"the application button should open the public-parts palette shell") {
		testui.destroy_find_result(&opener)
		return
	}
	opener_node := opener.element.visual_node
	testui.destroy_find_result(&opener)
	if !testing.expect(t, app.state.open, "the modal should remain open after its opener is activated") { return }
	panel := testui.find(&handle, testui.Query{
		role=.Dialog, name="Quick actions", match_role=true, match_name=true,
	})
	if !testing.expect(t, panel.match == .Unique && reference_panel_matches(&panel.element, 1280, 800),
		fmt.tprintf("the modal should match the 660x576 reference bounds: %v", panel.element.bounds)) {
		testui.destroy_find_result(&panel)
		return
	}

	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Text_Commit, text="export"}) == .Ok,
		"the focused controlled field should accept a query") { return }
	query := testui.find(&handle, testui.Query{
		role=.Text_Field, name="Search actions", match_role=true, match_name=true,
	})
	if !testing.expect(t, query.match == .Unique && query.element.focused &&
		app.match_count == 3 && app.state.query.text == "export",
		"the query field should retain focus and filter the three export actions") {
		testui.destroy_find_result(&query)
		return
	}
	visible_query := testui.expect_visible_text(&handle, &query.element, "export")
	testing.expect(t, visible_query.ok, testui.visible_text_diagnostic(visible_query))
	query_bounds := testui.expect_no_overflow(&handle, &query.element)
	testing.expect(t, query_bounds.ok, testui.layout_check_diagnostic(query_bounds))
	testui.destroy_find_result(&panel)
	panel = testui.find(&handle, testui.Query{
		role=.Dialog, name="Quick actions", match_role=true, match_name=true,
	})
	query_inside := testui.expect_inside(&handle, &query.element, &panel.element)
	testing.expect(t, query_inside.ok, testui.layout_check_diagnostic(query_inside))
	testui.destroy_find_result(&query)

	list := testui.find(&handle, testui.Query{
		role=.List_Box, name="Action results", match_role=true, match_name=true,
	})
	if !testing.expect(t, list.match == .Unique && list.element.logical_count == 3,
		"the list should publish all three filtered actions") {
		testui.destroy_find_result(&list)
		return
	}
	row := testui.find(&handle, testui.Query{
		role=.List_Box_Option, name="Export workspace", match_role=true, match_name=true,
	})
	if !testing.expect(t, row.match == .Unique, "the first result should remain a semantic list option") {
		testui.destroy_find_result(&row)
		testui.destroy_find_result(&list)
		return
	}
	testing.expect(t, alicorn.semantic_states_has(row.element.states, .Selected) &&
		alicorn.semantic_states_has(row.element.states, .Current),
		"the default selected result should expose selected/current semantics")
	row_bounds := testui.expect_inside(&handle, &row.element, &list.element)
	testing.expect(t, row_bounds.ok, testui.layout_check_diagnostic(row_bounds))
	visible_row := testui.expect_visible_text(&handle, &row.element, "Export workspace")
	testing.expect(t, visible_row.ok, testui.visible_text_diagnostic(visible_row))
	visible_description := testui.expect_visible_text(&handle, &row.element, "Create a local archive")
	testing.expect(t, visible_description.ok, testui.visible_text_diagnostic(visible_description))
	visible_shortcut := testui.expect_visible_text(&handle, &row.element, "CMD E")
	testing.expect(t, visible_shortcut.ok, testui.visible_text_diagnostic(visible_shortcut))
	testui.destroy_find_result(&row)
	testui.destroy_find_result(&list)
	testui.destroy_find_result(&panel)

	for viewport in ([2][2]int{{960, 720}, {760, 640}}) {
		resize_status := testui.resize(&handle, viewport[0], viewport[1])
		if !testing.expect(t, resize_status == .Ok,
			"the palette should re-describe at each smaller viewport") { return }
		query = testui.find(&handle, testui.Query{
			role=.Text_Field, name="Search actions", match_role=true, match_name=true,
		})
		query_visible := testui.expect_visible_text(&handle, &query.element, "export")
		query_fits := testui.expect_no_overflow(&handle, &query.element)
		if !testing.expect(t, query.match == .Unique && query_visible.ok && query_fits.ok,
			fmt.tprintf("query should remain visible and contained at %dx%d: %s %s",
				viewport[0], viewport[1], testui.visible_text_diagnostic(query_visible),
				testui.layout_check_diagnostic(query_fits))) {
			testui.destroy_find_result(&query)
			return
		}
		panel := testui.find(&handle, testui.Query{
			role=.Dialog, name="Quick actions", match_role=true, match_name=true,
		})
		panel_fits := testui.expect_no_overflow(&handle, &panel.element)
		if !testing.expect(t, panel.match == .Unique && panel_fits.ok &&
			reference_panel_matches(&panel.element, viewport[0], viewport[1]),
			fmt.tprintf("modal should fit the %dx%d viewport: %s", viewport[0], viewport[1],
				testui.layout_check_diagnostic(panel_fits))) {
			testui.destroy_find_result(&panel)
			testui.destroy_find_result(&query)
			return
		}
		testui.destroy_find_result(&panel)
		testui.destroy_find_result(&query)
		list = testui.find(&handle, testui.Query{
			role=.List_Box, name="Action results", match_role=true, match_name=true,
		})
		row = testui.find(&handle, testui.Query{
			role=.List_Box_Option, name="Export workspace", match_role=true, match_name=true,
		})
		contained := testui.expect_inside(&handle, &row.element, &list.element)
		visible_row = testui.expect_visible_text(&handle, &row.element, "Export workspace")
		visible_description = testui.expect_visible_text(&handle, &row.element, "Create a local archive")
		visible_shortcut = testui.expect_visible_text(&handle, &row.element, "CMD E")
		if !testing.expect(t, list.match == .Unique && row.match == .Unique && contained.ok &&
			visible_row.ok && visible_description.ok && visible_shortcut.ok,
			fmt.tprintf("result row should remain inside the list at %dx%d: %s",
				viewport[0], viewport[1], testui.layout_check_diagnostic(contained))) {
			testui.destroy_find_result(&row)
			testui.destroy_find_result(&list)
			return
		}
		testui.destroy_find_result(&row)
		testui.destroy_find_result(&list)
	}

	if !testing.expect(t, set_query(&app.state, handle.runtime, "settings"),
		"the public controlled-query setter should replace the current query") { return }
	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok,
		"the palette should refresh its filtered selection after a programmatic query update") { return }
	query = testui.find(&handle, testui.Query{
		role=.Text_Field, name="Search actions", match_role=true, match_name=true,
	})
	visible_query = testui.expect_visible_text(&handle, &query.element, "settings")
	testing.expect(t, query.match == .Unique && visible_query.ok && app.match_count == 1 &&
		query.element.focused,
		"the second query should be visible while filtering to one result")
	testui.destroy_find_result(&query)

	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Return}) == .Ok,
		"Return should activate the selected result through the scoped input path") { return }
	testing.expect(t, !app.state.open && app.last_action == Item_ID(3),
		"activation should dispatch the stable ID and close the palette")
	testing.expect(t, alicorn.focused_node(handle.runtime) == opener_node,
		"closing should restore focus to the opener behind the modal")
}
