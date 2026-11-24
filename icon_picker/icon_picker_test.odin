package icon_picker

// External-package behavior tests: this package imports Alicorn's public
// runtime and `alicorn:testui`; it never reads private runtime fields. The
// fixture uses the package exactly as an application would, including a modal
// host, an application-owned Ctrl+F interaction, two appearances, and a nested
// dialog over the picker.

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

FIXTURE_CHOICE_COUNT :: 12
LARGE_CHOICE_COUNT :: 200

fixture_choices :: proc() -> [FIXTURE_CHOICE_COUNT]Choice {
	return {
		{key=1, label="Home", icon=.Folder_Closed, keywords="house start", detail="Go to the workspace home"},
		{key=2, label="Search", icon=.Search, keywords="find", detail="Search files and commands"},
		{key=3, label="Settings", icon=.Settings, keywords="preferences", detail="Open application settings"},
		{key=4, label="Save", icon=.Check, keywords="write store", detail="Save the current document"},
		{key=5, label="Warning", icon=.Warning, keywords="alert", detail="Show a warning marker"},
		{key=6, label="Info", icon=.Info, keywords="details", detail="Show an information marker"},
		{key=7, label="Terminal", icon=.Terminal, keywords="shell console", detail="Open a terminal"},
		{key=8, label="More", icon=.More_Horizontal, keywords="overflow menu", detail="More actions"},
		{key=9, label="Locked", icon=.Close, keywords="private", detail="Unavailable in this build", disabled=true},
		{key=10, label="Folder", icon=.Folder_Open, keywords="directory", detail="Open a folder"},
		{key=11, label="File", icon=.File, keywords="document", detail="Open a file"},
		{key=12, label="Chevron", icon=.Chevron_Right, keywords="next", detail="Expand the next level"},
	}
}

Focus_Target :: enum { None, Search, Grid }

Test_App :: struct {
	picker:       State,
	choices:      [FIXTURE_CHOICE_COUNT]Choice,
	large:        [LARGE_CHOICE_COUNT]Choice,
	large_used:   bool,
	selected_key: u64,
	activations:  int,
	last_key:     u64,

	appearance: Appearance,
	inline:     bool,
	focus_target: Focus_Target,

	open_modal:  bool,
	overlay_node, opener_node: alicorn.Node_ID,
	nested_open: bool,
	nested_overlay, nested_dialog, nested_opener: alicorn.Node_ID,
	restore_node: alicorn.Node_ID,
	page_clicks:  int,
}

test_build_large_choices :: proc(app: ^Test_App) {
	if app.large_used { return }
	icons := [5]alicorn.Icon_ID{.Search, .Settings, .Folder_Open, .File, .Terminal}
	for index in 0..<LARGE_CHOICE_COUNT {
		app.large[index] = Choice{
			key=u64(1000+index),
			label=fmt_name(index),
			icon=icons[index%len(icons)],
			keywords="generated",
			detail="Generated choice",
			disabled=index == 57,
		}
	}
	app.large_used = true
}

fmt_name :: proc(index: int) -> string {
	// A static table avoids allocation and keeps the fixture copyable. The
	// picker only borrows names for the description.
	names := [LARGE_CHOICE_COUNT]string{
		"Icon 001", "Icon 002", "Icon 003", "Icon 004", "Icon 005", "Icon 006", "Icon 007", "Icon 008",
		"Icon 009", "Icon 010", "Icon 011", "Icon 012", "Icon 013", "Icon 014", "Icon 015", "Icon 016",
		"Icon 017", "Icon 018", "Icon 019", "Icon 020", "Icon 021", "Icon 022", "Icon 023", "Icon 024",
		"Icon 025", "Icon 026", "Icon 027", "Icon 028", "Icon 029", "Icon 030", "Icon 031", "Icon 032",
		"Icon 033", "Icon 034", "Icon 035", "Icon 036", "Icon 037", "Icon 038", "Icon 039", "Icon 040",
		"Icon 041", "Icon 042", "Icon 043", "Icon 044", "Icon 045", "Icon 046", "Icon 047", "Icon 048",
		"Icon 049", "Icon 050", "Icon 051", "Icon 052", "Icon 053", "Icon 054", "Icon 055", "Icon 056",
		"Icon 057", "Icon 058", "Icon 059", "Icon 060", "Icon 061", "Icon 062", "Icon 063", "Icon 064",
		"Icon 065", "Icon 066", "Icon 067", "Icon 068", "Icon 069", "Icon 070", "Icon 071", "Icon 072",
		"Icon 073", "Icon 074", "Icon 075", "Icon 076", "Icon 077", "Icon 078", "Icon 079", "Icon 080",
		"Icon 081", "Icon 082", "Icon 083", "Icon 084", "Icon 085", "Icon 086", "Icon 087", "Icon 088",
		"Icon 089", "Icon 090", "Icon 091", "Icon 092", "Icon 093", "Icon 094", "Icon 095", "Icon 096",
		"Icon 097", "Icon 098", "Icon 099", "Icon 100", "Icon 101", "Icon 102", "Icon 103", "Icon 104",
		"Icon 105", "Icon 106", "Icon 107", "Icon 108", "Icon 109", "Icon 110", "Icon 111", "Icon 112",
		"Icon 113", "Icon 114", "Icon 115", "Icon 116", "Icon 117", "Icon 118", "Icon 119", "Icon 120",
		"Icon 121", "Icon 122", "Icon 123", "Icon 124", "Icon 125", "Icon 126", "Icon 127", "Icon 128",
		"Icon 129", "Icon 130", "Icon 131", "Icon 132", "Icon 133", "Icon 134", "Icon 135", "Icon 136",
		"Icon 137", "Icon 138", "Icon 139", "Icon 140", "Icon 141", "Icon 142", "Icon 143", "Icon 144",
		"Icon 145", "Icon 146", "Icon 147", "Icon 148", "Icon 149", "Icon 150", "Icon 151", "Icon 152",
		"Icon 153", "Icon 154", "Icon 155", "Icon 156", "Icon 157", "Icon 158", "Icon 159", "Icon 160",
		"Icon 161", "Icon 162", "Icon 163", "Icon 164", "Icon 165", "Icon 166", "Icon 167", "Icon 168",
		"Icon 169", "Icon 170", "Icon 171", "Icon 172", "Icon 173", "Icon 174", "Icon 175", "Icon 176",
		"Icon 177", "Icon 178", "Icon 179", "Icon 180", "Icon 181", "Icon 182", "Icon 183", "Icon 184",
		"Icon 185", "Icon 186", "Icon 187", "Icon 188", "Icon 189", "Icon 190", "Icon 191", "Icon 192",
		"Icon 193", "Icon 194", "Icon 195", "Icon 196", "Icon 197", "Icon 198", "Icon 199", "Icon 200",
	}
	if index < 0 || index >= len(names) { return "Icon" }
	return names[index]
}

@(private)
restore_focus :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	app := cast(^Test_App)data
	if app == nil || rt == nil || app.restore_node == 0 { return }
	if _, found := alicorn.node_info(rt, app.restore_node); found {
		_ = alicorn.focus(rt, app.restore_node)
		alicorn.focus_indicator_set(rt, true)
	}
	app.restore_node = 0
}

@(private)
schedule_restore :: proc(app: ^Test_App, rt: ^alicorn.Runtime, node: alicorn.Node_ID) {
	if app == nil || rt == nil { return }
	app.restore_node = node
	_ = alicorn.interaction_after_frame_register(rt, rawptr(app), restore_focus)
}

test_open_modal :: proc(app: ^Test_App, opener: alicorn.Node_ID) {
	app.open_modal = true
	app.nested_open = false
	app.opener_node = opener
	_ = set_query(&app.picker, nil, "")
	_ = request_search_focus(&app.picker)
}

test_close_modal :: proc(app: ^Test_App, rt: ^alicorn.Runtime) {
	app.open_modal = false
	app.nested_open = false
	schedule_restore(app, rt, app.opener_node)
}

@(private)
picker_ui :: proc(app: ^Test_App, ctx: ^ui.UI) {
	if app.focus_target == .Search {
		_ = request_search_focus(&app.picker)
		app.focus_target = .None
	} else if app.focus_target == .Grid {
		_ = request_grid_focus(&app.picker)
		app.focus_target = .None
	}
	choices := app.choices[:]
	instance := u64(9001)
	if app.large_used {
		choices = app.large[:]
		instance = 9002
	}
	options := Options{
		accessible_label="Icon choices",
		search_accessible_name="Search icons",
		appearance=app.appearance,
		columns=6,
		cell_size=40,
		cell_gap=6,
		row_height=30,
		max_visible_rows=5,
	}
	event := picker(ctx, &app.picker, choices, options, key=alicorn.key_string("icon-picker-fixture"), instance_id=instance)
	if event.kind == .Activated {
		app.selected_key = event.key
		app.picker.selected_key = event.key
		app.last_key = event.key
		app.activations += 1
		if !app.inline { test_close_modal(app, ctx.runtime) }
	}
}

render :: proc(app: ^Test_App, ctx: ^ui.UI) {
	_ = ui.text(ctx, "Icon picker fixture", size=20)
	if ui.button(ctx, "Background action", key=alicorn.key_string("background-action"), width=160, height=30) {
		app.page_clicks += 1
	}
	if app.inline {
		picker_ui(app, ctx)
	} else {
		opener, clicked := alicorn.button_ex(ctx, "Insert icon…", key="open-icon-picker",
			style=ui.layout_style(width=160, height=32), variant=.Primary)
		if clicked {
			test_open_modal(app, opener)
		}
	}
	_ = ui.text(ctx, "Selected key is application-owned.", size=12, color=alicorn.style_color(ctx, .Muted_Text))
}

render_overlays :: proc(app: ^Test_App, ctx: ^ui.UI) {
	if !app.open_modal { return }
	overlay := alicorn.modal_overlay_begin(
		ctx,
		alicorn.key_string("icon-picker-modal"),
		style=ui.layout_style(.Column, width=-1, height=-1, padding=28, align=.Center, justify=.Center),
		backdrop_color=alicorn.Color{0.01, 0.02, 0.03, 0.42},
	)
	app.overlay_node = overlay
	if overlay == 0 { return }
	if ui.panel(ctx, key=alicorn.key_string("icon-picker-dialog"), width=420,
		height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=16, gap=10) {
		_ = alicorn.semantic_description(ctx, .Dialog, "Choose an icon", description="Select an icon for the document")
		if ui.row(ctx, key=alicorn.key_string("icon-picker-dialog-header"), height=26, align=.Center) {
			_ = ui.text(ctx, "Choose an icon", size=16, style=ui.layout_style(.Row, grow=1))
			if ui.button(ctx, "Close", key=alicorn.key_string("icon-picker-dialog-close"), width=64, height=26, variant=.Quiet) {
				test_close_modal(app, ctx.runtime)
			}
		}
		picker_ui(app, ctx)
		if app.open_modal {
			nested, opened := alicorn.button_ex(ctx, "Shortcut details",
				key="icon-picker-nested-opener",
				style=ui.layout_style(width=140, height=26), variant=.Quiet)
			if opened {
				app.nested_open = true
				app.nested_opener = nested
			}
		}
	}
	alicorn.modal_overlay_end(ctx)
	if app.nested_open {
		nested := alicorn.modal_overlay_begin(
			ctx,
			alicorn.key_string("icon-picker-nested-modal"),
			style=ui.layout_style(.Column, width=-1, height=-1, padding=28, align=.Center, justify=.Center),
			backdrop_color=alicorn.Color{0.01, 0.02, 0.03, 0.42},
		)
		app.nested_overlay = nested
		if nested != 0 {
			if ui.panel(ctx, key=alicorn.key_string("icon-picker-nested-dialog"), width=300,
				height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=14, gap=8) {
				_ = alicorn.semantic_description(ctx, .Dialog, "Shortcut details")
				_ = ui.text(ctx, "Ctrl+F focuses the icon search field.", size=12)
				if ui.button(ctx, "Done", key=alicorn.key_string("icon-picker-nested-done"), width=80, height=26) {
					app.nested_open = false
					schedule_restore(app, ctx.runtime, app.nested_opener)
				}
			}
			alicorn.modal_overlay_end(ctx)
		}
	}
}

on_key :: proc(state: rawptr, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	app := cast(^Test_App)state
	if app == nil { return false }
	#partial switch key {
	case .Escape:
		if app.nested_open {
			app.nested_open = false
			schedule_restore(app, rt, app.nested_opener)
			alicorn.invalidate_root(rt, "fixture closed nested dialog")
			return true
		}
		if app.open_modal {
			test_close_modal(app, rt)
			alicorn.invalidate_root(rt, "fixture closed icon picker dialog")
			return true
		}
	case .Find:
		// Application-authored interaction: Ctrl+F focuses the picker search
		// from anywhere in the dialog. It is ordinary state plus a public focus
		// request, not component API.
		if app.open_modal || app.inline {
			_ = request_search_focus(&app.picker)
			alicorn.invalidate_root(rt, "fixture Ctrl+F focused icon search")
			return true
		}
	}
	return false
}

on_pointer :: proc(state: rawptr, rt: ^alicorn.Runtime, event: alicorn.Pointer_Event, target: alicorn.Node_ID) {
	app := cast(^Test_App)state
	if app == nil { return }
	if event.kind != .Down || event.button != alicorn.POINTER_BUTTON_PRIMARY { return }
	if app.nested_open && target == app.nested_overlay {
		app.nested_open = false
		schedule_restore(app, rt, app.nested_opener)
		alicorn.invalidate_root(rt, "fixture dismissed nested dialog by outside click")
		return
	}
	if app.open_modal && !app.nested_open && target == app.overlay_node {
		test_close_modal(app, rt)
		alicorn.invalidate_root(rt, "fixture dismissed icon dialog by outside click")
	}
}

test_open :: proc(app: ^Test_App, t: ^testing.T, width := 640, height := 520) -> (testui.Test_Handle(Test_App), bool) {
	if !init(&app.picker) { return {}, false }
	app.selected_key = 1
	app.picker.selected_key = 1
	handle, status := testui.open(
		app,
		render,
		width=width,
		height=height,
		render_overlays=render_overlays,		on_key=on_key,
		on_pointer=on_pointer,
	)
	if !testing.expectf(t, status == .Ok, "the icon picker fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		destroy(&app.picker)
		return {}, false
	}
	return handle, true
}

test_close :: proc(app: ^Test_App, handle: ^testui.Test_Handle(Test_App)) {
	if handle.runtime != nil { testui.close(handle) }
	destroy(&app.picker)
}

find_cell :: proc(handle: ^testui.Test_Handle(Test_App), name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.List_Box_Option, name=name, match_role=true, match_name=true})
}

open_modal_by_click :: proc(handle: ^testui.Test_Handle(Test_App), t: ^testing.T) -> bool {
	trigger := testui.find(handle, testui.Query{role=.Button, name="Insert icon…", match_role=true, match_name=true})
	defer testui.destroy_find_result(&trigger)
	if !testing.expect(t, trigger.match == .Unique, "the opener should be unique") { return false }
	if !testing.expect(t, testui.click(handle, &trigger.element) == .Ok, "the opener should accept a click: %s",
		testui.last_turn_diagnostic(handle)) { return false }
	return true
}

@(test)
test_icon_picker_matches_tokens_and_rejects_empty_identity :: proc(t: ^testing.T) {
	choices := fixture_choices()
	testing.expect(t, matches(choices[0], "HOME"), "ASCII case-insensitive matching should apply to names")
	testing.expect(t, matches(choices[0], "house"), "keywords should match")
	testing.expect(t, matches(choices[0], "go workspace"), "every token should have to match")
	testing.expect(t, !matches(choices[0], "go folder"), "a missing token should reject")
	testing.expect(t, choice_semantic_id(0, 1).namespace == 0, "instance zero should not publish identity")
	testing.expect(t, choice_semantic_id(1, 0).namespace == 0, "choice key zero should not publish identity")
	testing.expect(t, choice_semantic_id(1, 2) != choice_semantic_id(2, 2),
		"the same choice key in two instances should have distinct identity")
}

@(test)
test_icon_picker_keyboard_pointer_and_semantic_activation_agree :: proc(t: ^testing.T) {
	app := Test_App{choices=fixture_choices(), appearance=.Grid, inline=true, focus_target=.Grid}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	// Home (row start) keeps Home active; Down moves one row (six cells).
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Home})
	testing.expect_value(t, active_key(&app.picker), u64(1))
	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok, "Down should be scoped") { return }
	testing.expect_value(t, active_key(&app.picker), u64(7))
	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Right}) == .Ok, "Right should be scoped") { return }
	testing.expect_value(t, active_key(&app.picker), u64(8))
	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Return}) == .Ok, "Return should be scoped") { return }
	keyboard_key := app.last_key
	testing.expect_value(t, keyboard_key, u64(8))
	testing.expect_value(t, app.selected_key, u64(8))

	chevron := find_cell(&handle, "Chevron")
	if !testing.expect(t, chevron.match == .Unique, "Chevron should be realized") { testui.destroy_find_result(&chevron); return }
	testing.expect(t, !chevron.element.collection_selected, "a non-accepted cell should not be Selected")
	testui.destroy_find_result(&chevron)
	more_selected := find_cell(&handle, "More")
	if testing.expect(t, more_selected.match == .Unique, "More should be realized") {
		testing.expect(t, more_selected.element.collection_selected,
			"the accepted selection should be Selected")
	}
	testui.destroy_find_result(&more_selected)

	// Pointer activation of More proposes the same identity.
	more := find_cell(&handle, "More")
	if !testing.expect(t, more.match == .Unique, "More should be realized") { testui.destroy_find_result(&more); return }
	click := testui.click(&handle, &more.element)
	if !testing.expectf(t, click == .Ok, "the cell should accept a click: %v", click) {
		testui.destroy_find_result(&more)
		return
	}
	pointer_key := app.last_key
	testui.destroy_find_result(&more)
	testing.expect_value(t, pointer_key, u64(8))

	// Semantic Select uses the stable cell identity and produces the same
	// proposed change.
	more_again := find_cell(&handle, "More")
	if !testing.expect(t, more_again.match == .Unique, "More should remain realized") {
		testui.destroy_find_result(&more_again)
		return
	}
	status := testui.step(&handle, testui.Input{
		kind=.Semantic_Action,
		semantic_id=more_again.element.semantic_id,
		semantic_action=.Select,
	})
	testui.destroy_find_result(&more_again)
	testing.expect(t, status == .Ok, "List_Box_Option Select should be accepted")
	testing.expect_value(t, app.last_key, u64(8))
	testing.expect_value(t, app.activations, 3)
}

@(test)
test_icon_picker_focus_and_selection_are_separate :: proc(t: ^testing.T) {
	app := Test_App{choices=fixture_choices(), appearance=.Grid, inline=true, focus_target=.Grid}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	// Selection is key 1 from the fixture. Move the roving focus without
	// accepting a change.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Right})
	testing.expect_value(t, app.selected_key, u64(1))
	testing.expect_value(t, active_key(&app.picker), u64(2))
	home := find_cell(&handle, "Home")
	search := find_cell(&handle, "Search")
	defer testui.destroy_find_result(&home)
	defer testui.destroy_find_result(&search)
	testing.expect(t, home.element.collection_selected && !home.element.collection_current,
		"the accepted selection should stay Selected while focus moved")
	testing.expect(t, search.element.collection_current && !search.element.collection_selected,
		"the roving focus should publish Current without Selected")
}

@(test)
test_icon_picker_skips_disabled_and_reconciles_removal :: proc(t: ^testing.T) {
	app := Test_App{choices=fixture_choices(), appearance=.List, inline=true, focus_target=.Grid}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	// List appearance moves by one row.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.End})
	testing.expect_value(t, active_key(&app.picker), u64(12))
	// The application accepts the proposed value by assigning its own state.
	app.selected_key = 12
	app.picker.selected_key = 12
	// Remove the active and selected identities, then reorder the caller data.
	// The controlled selection clears when it disappears; the active key moves
	// to the first enabled row.
	app.choices = [FIXTURE_CHOICE_COUNT]Choice{
		{key=20, label="Replacement A", icon=.Search},
		{key=21, label="Replacement B", icon=.Settings},
		{key=22, label="Replacement C", icon=.File},
		{}, {}, {}, {}, {}, {}, {}, {}, {},
	}
	app.selected_key = 12
	alicorn.invalidate_root(handle.runtime, "fixture replaced choices")
	_ = testui.describe_once(&handle)
	testing.expect(t, app.picker.match_count > 0, "matches should reconcile to the new source")
	testing.expect(t, active_key(&app.picker) == 20 || active_key(&app.picker) == 21 || active_key(&app.picker) == 22,
		"active identity should move to a remaining enabled choice")
	// Selection is caller-controlled: the picker itself does not clear it.
	testing.expect_value(t, app.picker.selected_key, u64(12))

	// Reorder and keep the active identity.
	app.choices = [FIXTURE_CHOICE_COUNT]Choice{
		{key=22, label="Replacement C", icon=.File},
		{key=20, label="Replacement A", icon=.Search},
		{key=21, label="Replacement B", icon=.Settings},
		{}, {}, {}, {}, {}, {}, {}, {}, {},
	}
	alicorn.invalidate_root(handle.runtime, "fixture reordered choices")
	_ = testui.describe_once(&handle)
	key := active_key(&app.picker)
	testing.expect(t, key == 20 || key == 21 || key == 22, "active identity should survive a reorder")
}

@(test)
test_icon_picker_appearance_switch_preserves_contract :: proc(t: ^testing.T) {
	app := Test_App{choices=fixture_choices(), appearance=.Grid, inline=true, focus_target=.Grid}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	home := find_cell(&handle, "Home")
	if !testing.expect(t, home.match == .Unique, "Home should be realized") { testui.destroy_find_result(&home); return }
	grid_id := home.element.semantic_id
	grid_bounds := home.element.bounds
	testui.destroy_find_result(&home)

	app.appearance = .List
	alicorn.invalidate_root(handle.runtime, "fixture changed icon picker appearance")
	_ = testui.describe_once(&handle)
	list := find_cell(&handle, "Home")
	if !testing.expect(t, list.match == .Unique, "Home should remain realized in the list appearance") {
		testui.destroy_find_result(&list)
		return
	}
	testing.expect_value(t, list.element.semantic_id, grid_id)
	testing.expect(t, list.element.has_bounds, "the list appearance should realize the same identity")
	testing.expect(t, list.element.bounds.w != grid_bounds.w || list.element.bounds.h != grid_bounds.h,
		"the two appearances should have materially different geometry")
	testing.expect(t, list.element.collection_selected, "selection should survive the appearance change")
	testui.destroy_find_result(&list)

	// Behavior is unchanged: End then Return still proposes the last choice.
	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.End}) == .Ok, "End should work in list") { return }
	testing.expect_value(t, active_key(&app.picker), u64(12))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Return})
	testing.expect_value(t, app.last_key, u64(12))
}

@(test)
test_icon_picker_search_filters_and_ime_yields_navigation :: proc(t: ^testing.T) {
	app := Test_App{choices=fixture_choices(), appearance=.Grid, inline=true, focus_target=.Search}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	_ = testui.step(&handle, testui.Input{kind=.Text_Commit, text="term"})
	testing.expect_value(t, app.picker.match_count, 1)
	terminal := find_cell(&handle, "Terminal")
	testing.expect(t, terminal.match == .Unique, "the filtered cell should remain named")
	testui.destroy_find_result(&terminal)
	search := find_cell(&handle, "Search")
	testing.expect_value(t, search.match, testui.Find_Match.None)
	testui.destroy_find_result(&search)

	// IME composition on the search field owns Up/Down and navigation stays put.
	active_before := active_key(&app.picker)
	_ = testui.step(&handle, testui.Input{kind=.Text_Preedit, text="te", composition_start_char=0, composition_length_char=2})
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Down})
	testing.expect_value(t, active_key(&app.picker), active_before)
	_ = testui.step(&handle, testui.Input{kind=.Text_Cancel})
	testing.expect_value(t, query_text(&app.picker), "term")

	// Leaving composition returns ordinary text input to the search field.
	_ = testui.step(&handle, testui.Input{kind=.Text_Commit, text="inal"})
	testing.expect_value(t, query_text(&app.picker), "terminal")
	testing.expect_value(t, app.picker.match_count, 1)
}

@(test)
test_icon_picker_search_focus_yields_navigation_and_space :: proc(t: ^testing.T) {
	app := Test_App{choices=fixture_choices(), appearance=.Grid, inline=true, focus_target=.Search}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	focused := alicorn.focused_node(handle.runtime)
	info, found := alicorn.node_info(handle.runtime, focused)
	testing.expect(t, found && info.kind == .Text_Field,
		"the search field should own focus before the grid keys are exercised")

	// text_preempt_keys returns arrows and Space to the picker while the search
	// field keeps focus; this is configuration, not a component key fork.
	active_before := active_key(&app.picker)
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Right}) == .Ok &&
		active_key(&app.picker) != active_before && query_text(&app.picker) == "",
		"Right should navigate the grid while the search field keeps focus")
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Space}) == .Ok &&
		app.activations == 1 && app.selected_key == active_key(&app.picker),
		"Space should activate the active choice while the search field keeps focus")

	testing.expect(t, testui.step(&handle, testui.Input{kind=.Text_Commit, text="term"}) == .Ok &&
		query_text(&app.picker) == "term" && match_count(&app.picker) == 1,
		"characters should still edit the focused search field")
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Left}) == .Ok &&
		active_key(&app.picker) == 7 && query_text(&app.picker) == "term",
		"yielded navigation should keep the single-match active identity")
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Backspace}) == .Ok &&
		query_text(&app.picker) == "ter",
		"Backspace should still reach the focused search field")

	// Active composition owns the whole navigation set.
	active_after := active_key(&app.picker)
	_ = testui.step(&handle, testui.Input{kind=.Text_Preedit, text="mi", composition_start_char=0, composition_length_char=2})
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Left}) == .Ok &&
		active_key(&app.picker) == active_after && query_text(&app.picker) == "ter",
		"IME composition should keep Left with the search field")
	_ = testui.step(&handle, testui.Input{kind=.Text_Cancel})
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Right}) == .Ok &&
		query_text(&app.picker) == "ter" && match_count(&app.picker) == 1,
		"after composition the search field should yield navigation again")
}

@(test)
test_icon_picker_virtualizes_large_grid_and_reveals_identity :: proc(t: ^testing.T) {
	app := Test_App{appearance=.Grid, inline=true, focus_target=.Grid}
	test_build_large_choices(&app)
	handle, ok := test_open(&app, t, width=520, height=420)
	if !ok { return }
	defer test_close(&app, &handle)

	if !testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.End}) == .Ok, "End should move to the row end") { return }
	testing.expect_value(t, active_key(&app.picker), u64(1005))
	// Walk to the logical end in ordinary grid steps; each Down moves one row
	// and the retained list reveals the destination.
	for _ in 0..<40 { _ = testui.step(&handle, testui.Input{kind=.Key, key=.Down}) }
	// The next two Rights reach the final column of the last row.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Right})
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Right})
	testing.expect_value(t, active_key(&app.picker), u64(1199))
	// A retained virtual list realizes a bounded window; the last identity is
	// revealed and published, not every one of the 200 cells.
	last := find_cell(&handle, "Icon 200")
	if !testing.expect(t, last.match == .Unique, "the last item should be realized after reveal: %s",
		testui.last_turn_diagnostic(&handle)) {
		testui.destroy_find_result(&last)
		return
	}
	testing.expect(t, last.element.has_bounds, "the revealed option should have finalized bounds")
	testing.expect(t, last.element.collection_current, "the active identity should be current")
	testing.expect_value(t, last.element.size_of_set, u64(LARGE_CHOICE_COUNT))
	testui.destroy_find_result(&last)
	first := find_cell(&handle, "Icon 001")
	testing.expect(t, first.match == .None, "scrolled-away cells should leave the realized semantic working set")
	testui.destroy_find_result(&first)
	list := testui.find(&handle, testui.Query{role=.List_Box, name="Icon choices", match_role=true, match_name=true})
	defer testui.destroy_find_result(&list)
	if list.match == .Unique {
		testing.expect_value(t, list.element.logical_count, u64(LARGE_CHOICE_COUNT))
		testing.expect(t, list.element.collection_current_id != alicorn.Semantic_ID{},
			"the collection should publish the active logical identity")
	}
	testing.expect(t, testui.advance_time(&handle, 16_000_000) == .Ok, "virtual time should advance")
	testing.expect(t, !handle.runtime.invalidated && !alicorn.presentation_needs_frame(handle.runtime),
		"the virtualized picker should settle")
}

@(test)
test_icon_picker_modal_pattern_conformance :: proc(t: ^testing.T) {
	app := Test_App{choices=fixture_choices(), appearance=.Grid, inline=false}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	parts := []testui.Pattern_Part{
		{id=.Trigger, query=testui.Query{role=.Button, name="Insert icon…", match_role=true, match_name=true}},
		{id=.Dialog, query=testui.Query{role=.Dialog, name="Choose an icon", match_role=true, match_name=true}},
		{id=.Background_Action, query=testui.Query{role=.Button, name="Background action", match_role=true, match_name=true}},
	}
	report := testui.pattern_check(&handle, testui.Pattern_Config{
		kind=.Modal_Dialog,
		parts=parts,
		max_focus_cycle=8,
	})
	testing.expectf(t, report.ok, "modal dialog pattern should conform: %s",
		testui.pattern_failure_diagnostic(&report.failure))
}

@(test)
test_icon_picker_modal_escape_outside_click_and_nested_overlay :: proc(t: ^testing.T) {
	app := Test_App{choices=fixture_choices(), appearance=.Grid, inline=false}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	if !open_modal_by_click(&handle, t) { return }
	if !testing.expect(t, app.open_modal, "the modal should open") { return }
	search_focused := false
	for _ in 0..<4 {
		focused := alicorn.focused_node(handle.runtime)
		if info, found := alicorn.node_info(handle.runtime, focused); found && info.kind == .Text_Field {
			search_focused = true
			break
		}
		_ = testui.describe_once(&handle)
	}
	testing.expect(t, search_focused, "opening should focus the picker search field")

	// Escape dismisses the picker dialog and restores the opener.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Escape})
	testing.expect(t, !app.open_modal, "Escape should close the modal")
	opener := testui.find(&handle, testui.Query{role=.Button, name="Insert icon…", match_role=true, match_name=true})
	testing.expect(t, opener.match == .Unique && opener.element.focused, "focus should return to the opener")
	testui.destroy_find_result(&opener)

	// Pointer outside the panel dismisses the picker dialog too.
	if !open_modal_by_click(&handle, t) { return }
	_ = testui.click_at(&handle, 6, 6)
	testing.expect(t, !app.open_modal, "an outside primary click should dismiss the modal")

	// Nested modal over the picker owns input; Escape closes only the top layer.
	if !open_modal_by_click(&handle, t) { return }
	nested := testui.find(&handle, testui.Query{role=.Button, name="Shortcut details", match_role=true, match_name=true})
	if !testing.expect(t, nested.match == .Unique, "the nested opener should be present") {
		testui.destroy_find_result(&nested)
		return
	}
	_ = testui.click(&handle, &nested.element)
	testui.destroy_find_result(&nested)
	testing.expect(t, app.nested_open, "the nested dialog should open")
	active_before := active_key(&app.picker)
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Right})
	testing.expect_value(t, active_key(&app.picker), active_before)
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Escape})
	testing.expect(t, !app.nested_open && app.open_modal, "Escape should close only the nested dialog")
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Escape})
	testing.expect(t, !app.open_modal, "a second Escape should close the picker dialog")

	_ = testui.advance_time(&handle, 16_000_000)
	testing.expect(t, !handle.runtime.invalidated && !alicorn.presentation_needs_frame(handle.runtime),
		"the modal host should settle after teardown")
}

@(test)
test_icon_picker_ctrl_f_focus_is_application_authored :: proc(t: ^testing.T) {
	app := Test_App{choices=fixture_choices(), appearance=.Grid, inline=true, focus_target=.Grid}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	grid_focused := false
	if info, found := alicorn.node_info(handle.runtime, alicorn.focused_node(handle.runtime)); found &&
	   info.kind == .Scroll_Region && info.focused {
		grid_focused = true
	}
	testing.expect(t, grid_focused, "the initial focus should be the grid")
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Find})
	focused := alicorn.focused_node(handle.runtime)
	if !testing.expectf(t, focused != 0, "Ctrl+F should move focus") { return }
	info, found := alicorn.node_info(handle.runtime, focused)
	testing.expect(t, found && info.kind == .Text_Field,
		"the application-authored Ctrl+F interaction should focus the picker search field")
}

@(test)
test_icon_picker_roving_grid_pattern_conformance :: proc(t: ^testing.T) {
	app := Test_App{choices=fixture_choices(), appearance=.Grid, inline=true, focus_target=.Grid}
	handle, ok := test_open(&app, t)
	if !ok { return }
	defer test_close(&app, &handle)

	parts := []testui.Pattern_Part{
		{id=.Container, query=testui.Query{role=.List_Box, name="Icon choices", match_role=true, match_name=true}},
		{id=.Target_Option, query=testui.Query{role=.List_Box_Option, name="Chevron", match_role=true, match_name=true}},
		{id=.Disabled_Option, query=testui.Query{role=.List_Box_Option, name="Locked", match_role=true, match_name=true}},
	}
	report := testui.pattern_check(&handle, testui.Pattern_Config{
		kind=.Roving_Grid,
		parts=parts,
		roving=testui.Pattern_Roving_Config{
			focus=.Container,
			columns=6,
			home_end_row=true,
			expect_reveal=true,
			expect_selection=true,
		},
	})
	testing.expectf(t, report.ok, "roving grid pattern should conform: %s",
		testui.pattern_failure_diagnostic(&report.failure))
	testing.expect_value(t, app.selected_key, u64(12))
}
