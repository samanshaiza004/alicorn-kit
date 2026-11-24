package command_palette

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"

Command_Palette_Visual_App :: struct {
	state: State,
	items: [3]Item,
}

command_palette_visual_render :: proc(app: ^Command_Palette_Visual_App, ctx: ^alicorn.UI) {
	alicorn.container_begin(ctx, .Root, key=alicorn.key_string("visual-palette-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, padding=16, gap=8))
	_ = alicorn.text(ctx, "AliKit · Command Palette")
	alicorn.container_end(ctx)
}

command_palette_visual_overlay :: proc(app: ^Command_Palette_Visual_App, ctx: ^alicorn.UI) {
	if !app.state.open { return }
	_ = build(ctx, &app.state, app.items[:],
		key=alicorn.key_string("visual-palette-overlay"),
		options=Options{
			title="Example Actions",
			query_accessible_name="Search example actions",
		})
}

@(test)
test_default_palette_shows_committed_query_while_filtering :: proc(t: ^testing.T) {
	app := Command_Palette_Visual_App{
		items={
			{ id=Item_ID(1), title="Open File", description="Browse the workspace", keywords="file browse" },
			{ id=Item_ID(2), title="Search Files", description="Find text across the workspace", keywords="find grep" },
			{ id=Item_ID(3), title="Build Project", description="Run the configured build", keywords="compile" },
		},
	}
	if !init(&app.state) {
		testing.expect(t, false, "palette state should initialize")
		return
	}
	defer destroy(&app.state)
	handle, status := testui.open(&app, command_palette_visual_render,
		width=760, height=520, render_overlays=command_palette_visual_overlay)
	if !testing.expect(t, status == .Ok, testui.last_turn_diagnostic(&handle)) { return }
	defer if handle.runtime != nil { testui.close(&handle) }

	if !open_palette(&app.state, handle.runtime) {
		testing.expect(t, false, "the stock palette should open")
		return
	}
	if testui.step(&handle, testui.Input{kind=.Key, key=.Escape}) != .Ok {
		testing.expect(t, false, "the pending overlay description should complete")
		return
	}
	if !testing.expect(t, app.state.query_node != 0 && alicorn.focused_node(handle.runtime) == app.state.query_node,
		"the default palette should focus its query field after opening") { return }
	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Text_Commit, text="Open"}) == .Ok,
		"the focused default query should accept committed text") { return }

	query := testui.find(&handle, testui.Query{
		role=.Text_Field,
		name="Search example actions",
		match_role=true,
		match_name=true,
	})
	defer testui.destroy_find_result(&query)
	if !testing.expect(t, query.match == .Unique && query.element.has_bounds &&
		app.state.query.text == "Open" && app.state.match_count == 1,
		"the filter and accessible query should both retain the committed text") { return }

	visible := testui.expect_visible_text(&handle, &query.element, "Open")
	testing.expect(t, visible.ok, testui.visible_text_diagnostic(visible))
}
