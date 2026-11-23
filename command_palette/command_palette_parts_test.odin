package command_palette

// Public result-part tests for the command-palette package. The fixture owns
// the query shell and uses input/list_begin/item_begin/group_begin/list_end
// directly, proving the same result contract build() uses is available to an
// application that composes its own shell.

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"
import palette "alikit:palette_model"
import parts "alikit:palette_parts"

PARTS_ITEMS: [3]palette.Item = {
	{id=palette.Item_ID(1), title="Open file", description="Browse the workspace"},
	{id=palette.Item_ID(2), title="Open settings", description="Adjust the editor"},
	{id=palette.Item_ID(3), title="Unavailable", description="Disabled action", disabled=true},
}

Parts_App :: struct {
	state:       State,
	matches:     [3]palette.Match,
	count:       int,
	activations: int,
	last_id:     palette.Item_ID,
}

parts_build :: proc(app: ^Parts_App, ctx: ^ui.UI) {
	if alicorn.container_begin(ctx, .Root, label="command-palette-parts-root",
		key=alicorn.key_string("command-palette-parts-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, padding=12, gap=8)) == 0 {
		return
	}
	_, _ = input(ctx, &app.state, Options{hide_title=true},
		key=alicorn.key_string("command-palette-parts-input"))
	app.count, _ = palette.index_all(PARTS_ITEMS[:], app.matches[:])
	list, opened := list_begin(ctx, &app.state, PARTS_ITEMS[:], app.matches[:app.count],
		key=alicorn.key_string("command-palette-parts-list"),
		options=Options{hide_title=true, list_max_height=260})
	if opened {
		group, group_visible := group_begin(ctx, &list, "General",
			key=alicorn.key_string("command-palette-parts-group"))
		for index in list.first..<list.last {
			row, row_visible := item_begin(ctx, &list, index)
			if !row_visible { continue }
			if surface := parts.row_surface(ctx, row); surface != 0 {
				parts.label(ctx, row)
				parts.description(ctx, row)
				parts.indicator(ctx, row)
				alicorn.surface_end(ctx)
			}
			if item_end(ctx, &app.state, &list, row) {
				app.activations += 1
				app.last_id = row.item.id
			}
		}
		if group_visible { group_end(ctx, &group) }
		if event := list_end(ctx, &app.state, &list); event.kind == .Activated {
			app.activations += 1
			app.last_id = event.item_id
		}
	} else {
		_ = empty(ctx, Options{hide_title=true}, key=alicorn.key_string("command-palette-parts-empty"))
	}
	alicorn.container_end(ctx)
}

parts_initialize :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	app := cast(^Parts_App)data
	if !init(&app.state) { return }
	app.state.open = true
}

parts_key :: proc(data: rawptr, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	app := cast(^Parts_App)data
	handled, event := handle_key(&app.state, rt, PARTS_ITEMS[:], key)
	if event.kind == .Activated {
		app.activations += 1
		app.last_id = event.item_id
	}
	return handled
}

@(test)
test_command_palette_public_result_parts_and_group :: proc(t: ^testing.T) {
	app := Parts_App{}
	handle, status := testui.open(&app, parts_build, width=520, height=360,
		initialize=parts_initialize, on_key=parts_key)
	if !testing.expectf(t, status == .Ok, "the public parts fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return
	}
	defer {
		testui.close(&handle)
		destroy(&app.state)
	}

	list := testui.find(&handle, testui.Query{role=.List_Box, name="Results",
		match_role=true, match_name=true})
	if testing.expect(t, list.match == .Unique, "the public list part should publish one List_Box") {
		testing.expect(t, list.element.is_collection && list.element.logical_count == 3,
			"the result part should publish the visible logical count")
	}
	testui.destroy_find_result(&list)

	group := testui.find(&handle, testui.Query{role=.Group, name="General",
		match_role=true, match_name=true})
	testing.expect(t, group.match == .Unique, "group_begin should publish a semantic Group")
	testui.destroy_find_result(&group)

	settings := testui.find(&handle, testui.Query{role=.List_Box_Option, name="Open settings",
		match_role=true, match_name=true})
	if testing.expect(t, settings.match == .Unique, "a custom row should publish List_Box_Option") {
		_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
		_ = testui.step(&handle, testui.Input{kind=.Key, key=.Return})
		testing.expect_value(t, app.last_id, palette.Item_ID(2))
		testing.expect_value(t, app.activations, 1)
	}
	testui.destroy_find_result(&settings)
}
