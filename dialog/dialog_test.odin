package dialog

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

Test_App :: struct {
	state:    State,
	activations: int,
	last_action: string,
	background_activations: int,
	variant:  Variant,
	focus:    Focus_Target,
	configured_focus: bool,
}

fixture_open_dialog :: proc(app: ^Test_App, ctx: ^ui.UI) {
	visible, event := begin(ctx, &app.state, "Confirm record deletion",
		Options{
			description="A modal confirmation with destructive and cancel actions.",
			variant=app.variant,
			focus=app.focus,
			focus_key=alicorn.key_string("dialog-field"),
			focus_kind=.Button,
			primary_key=alicorn.key_string("dialog-confirm"),
		},
		key=alicorn.key_string("dialog-fixture"), instance_id=9501)
	if !visible { _ = event; return }
	title(ctx, "Confirm record deletion")
	description(ctx, "Record 003 will be removed.")
	if content_begin(ctx, alicorn.key_string("dialog-content")) {
		if app.configured_focus {
			_ = ui.button(ctx, "Content action", key=alicorn.key_string("dialog-field"), width=160, height=30)
		}
		content_end(ctx)
	}
	if action_row_begin(ctx, Options{}, alicorn.key_string("dialog-actions")) {
		if action(ctx, &app.state, "Confirm", .Primary, key=alicorn.key_string("dialog-confirm")) {
			app.activations += 1
			app.last_action = "confirm"
			dismiss(ctx, &app.state, .Action)
		}
		if action(ctx, &app.state, "Cancel", .Cancel, key=alicorn.key_string("dialog-cancel")) {
			app.activations += 1
			app.last_action = "cancel"
			dismiss(ctx, &app.state, .Action)
		}
		action_row_end(ctx)
	}
	end(ctx, &app.state)
}

fixture_render :: proc(app: ^Test_App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("dialog-fixture-root"), width=-1, height=-1, padding=20, gap=8) {
		if ui.button(ctx, "Open dialog", key=alicorn.key_string("dialog-open"), width=160, height=32) {
			_ = open(&app.state, ctx.runtime)
		}
		if ui.button(ctx, "Background action", key=alicorn.key_string("dialog-background"), width=180, height=32) {
			app.background_activations += 1
		}
	}
}

fixture_overlays :: proc(app: ^Test_App, ctx: ^ui.UI) {
	if app.state.open { fixture_open_dialog(app, ctx) }
}

fixture_open :: proc(app: ^Test_App, t: ^testing.T) -> (testui.Test_Handle(Test_App), bool) {
	handle, status := testui.open(app, fixture_render, width=640, height=480, render_overlays=fixture_overlays)
	if !testing.expectf(t, status == .Ok, "the dialog fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
find_button :: proc(handle: ^testui.Test_Handle(Test_App), name: string) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.Button, name=name, match_role=true, match_name=true})
}

@(test)
test_dialog_identity_theme_and_policy_resolution :: proc(t: ^testing.T) {
	testing.expect(t, dialog_semantic_id(0).namespace == 0, "instance zero must not publish identity")
	testing.expect(t, dialog_semantic_id(1) != dialog_semantic_id(2),
		"distinct dialogs must have distinct identity")

	recipe := Recipe{
		panel_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.dialog", "panel"),
	}
	contract := theme_contract_default(recipe)
	testing.expect_value(t, contract.required_count, 1)
	testing.expect_value(t, contract.optional_count, 1)
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 200, 120})
	defer alicorn.destroy_runtime(&rt)
	report := theme_contract_check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	names, missing := theme_contract_missing_required(contract, report)
	testing.expect(t, !theme_contract_satisfied(report) && missing == 1 &&
		names[0] == "alikit.dialog.panel_surface")

	dialog_options := options_resolve(Options{})
	testing.expect(t, dialog_options.escape == .Cancel && dialog_options.backdrop == .Dismiss,
		"a Dialog dismisses with Escape and backdrop by default")
	alert_options := options_resolve(Options{variant=.Alert_Dialog})
	testing.expect(t, alert_options.escape == .Prevent && alert_options.backdrop == .Ignore,
		"an Alert Dialog requires explicit acknowledgment by default")
	explicit := options_resolve(Options{variant=.Alert_Dialog, escape=.Cancel, backdrop=.Dismiss})
	testing.expect(t, explicit.escape == .Cancel && explicit.backdrop == .Dismiss,
		"explicit policies override variant defaults")
}

@(test)
test_dialog_modal_pattern_conformance :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	parts := []testui.Pattern_Part{
		{id=.Trigger, query=testui.Query{role=.Button, name="Open dialog", match_role=true, match_name=true}},
		{id=.Dialog, query=testui.Query{role=.Dialog, name="Confirm record deletion", match_role=true, match_name=true}},
		{id=.Primary_Action, query=testui.Query{role=.Button, name="Confirm", match_role=true, match_name=true}},
		{id=.Secondary_Action, query=testui.Query{role=.Button, name="Cancel", match_role=true, match_name=true}},
		{id=.Background_Action, query=testui.Query{role=.Button, name="Background action", match_role=true, match_name=true}},
	}
	report := testui.pattern_check(&handle, testui.Pattern_Config{kind=.Modal_Dialog, parts=parts})
	testing.expect(t, report.ok, testui.pattern_failure_diagnostic(&report.failure))
	testing.expect(t, app.background_activations == 0,
		"a covered background control must not activate while the dialog is open")
	testing.expect(t, app.activations >= 3,
		"pointer, keyboard, and semantic primary activation should all reach the application")
}

@(test)
test_dialog_alert_backdrop_and_escape_policy :: proc(t: ^testing.T) {
	app := Test_App{variant=.Alert_Dialog}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	open_button := find_button(&handle, "Open dialog")
	if !testing.expect(t, open_button.match == .Unique, "the opener should be realized") {
		testui.destroy_find_result(&open_button)
		return
	}
	_ = testui.click(&handle, &open_button.element)
	testui.destroy_find_result(&open_button)
	testing.expect(t, app.state.open, "the alert should open")
	_ = testui.describe_once(&handle)

	// The live Alert companion is published for an assertive announcement.
	alert_node, alert_found := alicorn.semantic_node_lookup(handle.runtime, alert_semantic_id(9501))
	testing.expect(t, alert_found && alert_node.role == .Alert && alert_node.live == .Assertive,
		"an alert should publish a live assertive Alert entity")

	alicorn.invalidate_root(handle.runtime, "fixture forced settled dialog geometry")
	_ = testui.describe_once(&handle)
	panel_info, panel_found := alicorn.node_info(handle.runtime, app.state.panel_node)
	testing.expect(t, panel_found && panel_info.bounds.h > 0,
		"the panel geometry should be retained")

	// A backdrop click and Escape are both ignored by default for Alert_Dialog.
	_ = testui.step(&handle, testui.Input{kind=.Pointer, pointer=alicorn.Pointer_Event{
		kind=.Down, button=alicorn.POINTER_BUTTON_PRIMARY, x=2, y=2,
	}})
	testing.expect(t, app.state.open, "an alert must ignore backdrop dismissal")
	_ = testui.describe_once(&handle)
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Escape})
	testing.expect(t, app.state.open, "an alert should prevent Escape by default")

	// Explicit acknowledgment closes it and restores the opener.
	cancel := find_button(&handle, "Cancel")
	if testing.expect(t, cancel.match == .Unique, "the cancel action should be realized") {
		_ = testui.click(&handle, &cancel.element)
		testing.expect(t, !app.state.open, "an explicit action acknowledges the alert")
		testing.expect_value(t, app.last_action, "cancel")
	}
	testui.destroy_find_result(&cancel)
	_ = testui.describe_once(&handle)
	opener := find_button(&handle, "Open dialog")
	if testing.expect(t, opener.match == .Unique, "the opener should return") {
		testing.expect_value(t, alicorn.focused_node(handle.runtime), opener.element.visual_node)
	}
	testui.destroy_find_result(&opener)
}

@(test)
test_dialog_backdrop_dismissal_and_focus_placement :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	open_button := find_button(&handle, "Open dialog")
	if !testing.expect(t, open_button.match == .Unique, "the opener should be realized") {
		testui.destroy_find_result(&open_button)
		return
	}
	opener := open_button.element.visual_node
	_ = testui.click(&handle, &open_button.element)
	testui.destroy_find_result(&open_button)
	_ = testui.describe_once(&handle)
	testing.expect(t, app.state.open, "the dialog should open")
	alicorn.invalidate_root(handle.runtime, "fixture forced settled dialog geometry")
	_ = testui.describe_once(&handle)

	// Default Dialog focus is the primary action when primary_key is provided.
	confirm := find_button(&handle, "Confirm")
	if testing.expect(t, confirm.match == .Unique, "the primary action should be realized") {
		testing.expect_value(t, alicorn.focused_node(handle.runtime), confirm.element.visual_node)
	}
	testui.destroy_find_result(&confirm)

	_ = testui.step(&handle, testui.Input{kind=.Pointer, pointer=alicorn.Pointer_Event{
		kind=.Down, button=alicorn.POINTER_BUTTON_PRIMARY, x=1, y=1,
	}})
	testing.expect(t, !app.state.open, "a Dialog should dismiss on a backdrop click")
	_ = testui.describe_once(&handle)
	testing.expect_value(t, alicorn.focused_node(handle.runtime), opener)

	// Configured focus addresses a caller-owned content control.
	app.focus = .Configured
	app.configured_focus = true
	open_button = find_button(&handle, "Open dialog")
	if testing.expect(t, open_button.match == .Unique, "the opener should return after dismissal") {
		_ = testui.click(&handle, &open_button.element)
	}
	testui.destroy_find_result(&open_button)
	_ = testui.describe_once(&handle)
	field, field_found := alicorn.node_by_key(handle.runtime, alicorn.key_string("dialog-field"), .Button)
	testing.expect(t, field_found && alicorn.focused_node(handle.runtime) == field,
		"Configured focus should address the caller's control")
}

Nested_App :: struct {
	parent: State,
	child:  State,
	parent_open: bool,
	child_open: bool,
	parent_trigger: alicorn.Node_ID,
	child_trigger: alicorn.Node_ID,
}

nested_render :: proc(app: ^Nested_App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("nested-root"), width=-1, height=-1, padding=20, gap=8) {
		if ui.button(ctx, "Open parent", key=alicorn.key_string("nested-parent-open"), width=160, height=32) {
			app.parent_open = true
			_ = open(&app.parent, ctx.runtime)
		}
	}
}

nested_dialog :: proc(ctx: ^ui.UI, app: ^Nested_App, state: ^State, title_text: string, parent: bool, key: ui.UI_Key, instance_id: u64) {
	visible, event := begin(ctx, state, title_text, Options{focus=.Panel}, key=key, instance_id=instance_id)
	if !visible {
		if event.kind == .Dismissed {
			if parent { app.parent_open = false } else { app.child_open = false }
		}
		return
	}
	title(ctx, title_text)
	if content_begin(ctx, ui.key_u64(0xA11C_6F01 if parent else 0xA11C_6F02)) {
		if parent {
			_ = ui.text(ctx, "Parent dialog content", size=12)
			details, activated := alicorn.button_begin(ctx, "Open details",
				key=alicorn.key_string("nested-details"), style=ui.layout_style(.Row, width=150, height=30))
			if details != 0 { alicorn.button_end(ctx) }
			if activated {
				app.child_open = true
				_ = open_from_node(&app.child, ctx.runtime, details)
			}
		} else {
			_ = ui.text(ctx, "Child dialog content", size=12)
		}
		content_end(ctx)
	}
	if action_row_begin(ctx, Options{}, ui.key_u64(0xA11C_6F03 if parent else 0xA11C_6F04)) {
		if action(ctx, state, "OK", .Primary, key=ui.key_u64(0xA11C_6F05 if parent else 0xA11C_6F06)) {
			if parent { app.parent_open = false } else { app.child_open = false }
			dismiss(ctx, state, .Action)
		}
		action_row_end(ctx)
	}
	end(ctx, state)
}

@(test)
test_dialog_nested_overlays_escape_only_topmost :: proc(t: ^testing.T) {
	app := Nested_App{}
	handle, status := testui.open(&app, nested_render, width=640, height=480,
		render_overlays=nested_overlays)
	if !testing.expectf(t, status == .Ok, "the nested fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return
	}
	defer testui.close(&handle)

	parent_button := testui.find(&handle, testui.Query{role=.Button, name="Open parent", match_role=true, match_name=true})
	if !testing.expect(t, parent_button.match == .Unique, "the parent opener should be realized") {
		testui.destroy_find_result(&parent_button)
		return
	}
	_ = testui.click(&handle, &parent_button.element)
	app.parent_trigger = parent_button.element.visual_node
	testui.destroy_find_result(&parent_button)
	_ = testui.describe_once(&handle)
	testing.expect(t, app.parent_open, "the parent dialog should open")

	details := testui.find(&handle, testui.Query{role=.Button, name="Open details", match_role=true, match_name=true})
	if !testing.expect(t, details.match == .Unique, "the nested opener should be realized inside the parent") {
		testui.destroy_find_result(&details)
		return
	}
	_ = testui.click(&handle, &details.element)
	app.child_trigger = details.element.visual_node
	testui.destroy_find_result(&details)
	_ = testui.describe_once(&handle)
	testing.expect(t, app.child_open, "the nested dialog should open")

	child := testui.find(&handle, testui.Query{role=.Dialog, name="Details dialog", match_role=true, match_name=true})
	if testing.expect(t, child.match == .Unique, "the nested Dialog should be published") {
		testing.expect(t, child.element.bounds.w > 0, "the nested dialog should have geometry")
	}
	testui.destroy_find_result(&child)

	// Escape closes only the topmost (nested) dialog.
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Escape})
	testing.expect(t, app.parent_open, "Escape must not close the covered parent")
	testing.expect(t, !app.child_open, "Escape closes the nested dialog")
	_ = testui.describe_once(&handle)
	testing.expect_value(t, alicorn.focused_node(handle.runtime), app.child_trigger)
}

nested_overlays :: proc(app: ^Nested_App, ctx: ^ui.UI) {
	if app.parent_open {
		nested_dialog(ctx, app, &app.parent, "Parent dialog", true,
			alicorn.key_string("nested-parent-dialog"), 9601)
	}
	if app.child_open {
		nested_dialog(ctx, app, &app.child, "Details dialog", false,
			alicorn.key_string("nested-child-dialog"), 9602)
	}
}
