package notices

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

Runtime_App :: struct {
	posted: bool,
}

runtime_render :: proc(app: ^Runtime_App, ctx: ^ui.UI) {
	_ = ui.text(ctx, "Notices fixture", size=18)
}

runtime_initialize :: proc(state: rawptr, rt: ^alicorn.Runtime) {
	app := cast(^Runtime_App)state
	actions := [1]Action{{id=alicorn.Action_ID(77), label="Undo"}}
	_ = post(rt, toast("saved", "Saved", "Document saved.", .Success, .Transient,
		nil, duration_ms=1_000), 10_000)
	_ = post(rt, toast("action-required", "Action required", "Choose whether to retry.", .Warning,
		.Persistent, actions[:]), 10_000)
	app.posted = true
}

@(test)
test_runtime_toast_renders_actions_and_uses_one_shot_deadline :: proc(t: ^testing.T) {
	app := Runtime_App{}
	handle, status := testui.open(
		&app,
		runtime_render,
		width=520,
		height=320,
		initialize=runtime_initialize,
	)
	if !testing.expectf(t, status == .Ok, "the runtime notice fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return
	}
	defer testui.close(&handle)
	testing.expect(t, app.posted, "the initialize callback should post one notice")

	card := testui.find(&handle, testui.Query{role=.Status, name="Saved", match_role=true, match_name=true})
	if !testing.expect(t, card.match == .Unique, "the runtime should render one toast card") {
		testui.destroy_find_result(&card)
		return
	}
	testing.expect_value(t, card.element.value, "Document saved.")
	testui.destroy_find_result(&card)

	action := testui.find(&handle, testui.Query{role=.Button, name="Undo", match_role=true, match_name=true})
	if !testing.expect(t, action.match == .Unique, "the runtime toast should expose its action button") {
		testui.destroy_find_result(&action)
		return
	}
	click := testui.click(&handle, &action.element)
	testui.destroy_find_result(&action)
	if !testing.expect(t, click == .Ok, "the toast action should accept pointer input") { return }
	event, found := take_action(handle.runtime)
	testing.expect(t, found && event.action == alicorn.Action_ID(77),
		"the runtime action queue should deliver the app-owned action ID")

	deadline := next_deadline(handle.runtime)
	testing.expect_value(t, deadline, u64(1_000_010_000))
	testing.expect(t, !advance(handle.runtime, deadline-1),
		"a transient notice must remain before its one-shot deadline")
	testing.expect(t, advance(handle.runtime, deadline),
		"the notice should expire at the exposed deadline")
	alicorn.invalidate_root(handle.runtime, "test expired runtime notice")
	_ = testui.describe_once(&handle)
	card = testui.find(&handle, testui.Query{role=.Status, name="Saved", match_role=true, match_name=true})
	testing.expect(t, card.match == .None, "the expired toast should no longer be described")
	testui.destroy_find_result(&card)
	testing.expect_value(t, next_deadline(handle.runtime), u64(0))
	persistent := testui.find(&handle, testui.Query{role=.Status, name="Action required", match_role=true, match_name=true})
	testing.expect(t, persistent.match == .Unique,
		"the persistent action-bearing notice should remain after the transient expiry")
	testui.destroy_find_result(&persistent)
}

Card_App :: struct {
	states: [2]State,
	items:  [2]Item,
	actions: [2]Action,
	events: int,
	last_action: alicorn.Action_ID,
	last_kind: Event_Kind,
}

card_render :: proc(app: ^Card_App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("notice-card-fixture-root"), width=-1, height=-1,
		grow=1, padding=20, gap=10, align=.End) {
		app.items[0] = Item{
			key=1,
			title="Couldn't refresh folder",
			message="The folder's contents may be out of date.",
			details="Network timeout after 30 seconds.",
			severity=.Warning,
			actions=app.actions[:],
		}
		retiring := app.items[1].retiring
		app.items[1] = Item{
			key=2,
			title="Theme saved",
			message="Your theme preference is now active.",
			severity=.Success,
			retiring=retiring,
		}
		if event := stack(ctx, app.states[:], app.items[:], Options{accessible_label="Notifications"},
			key=alicorn.key_string("notice-card-fixture-stack")); event.kind != .None {
			app.events += 1
			app.last_kind = event.kind
			app.last_action = event.action
			if event.kind == .Dismissed { app.items[0].retiring = true }
		}
	}
}

card_open :: proc(app: ^Card_App, t: ^testing.T) -> (testui.Test_Handle(Card_App), bool) {
	app.actions = [2]Action{{id=alicorn.Action_ID(11), label="Retry"}, {id=alicorn.Action_ID(12), label="Details"}}
	handle, status := testui.open(app, card_render, width=520, height=420)
	if !testing.expectf(t, status == .Ok, "the card fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(test)
test_card_parts_publish_status_actions_and_retire :: proc(t: ^testing.T) {
	app := Card_App{}
	handle, ok := card_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	if !testing.expect(t, testui.advance_time(&handle, 500_000_000) == .Ok,
		"notice reveal motion should advance before checking visible card text") { return }
	warning := testui.find(&handle, testui.Query{role=.Status, name="Couldn't refresh folder", match_role=true, match_name=true})
	if !testing.expect(t, warning.match == .Unique, "the warning card should publish Status") {
		testui.destroy_find_result(&warning)
		return
	}
	testing.expect(t, warning.element.has_bounds && warning.element.bounds.h > 0,
		"the Status owner should cover the visible notice card")
	testing.expect_value(t, warning.element.value, "The folder's contents may be out of date.")
	testing.expect_value(t, warning.element.description, "Network timeout after 30 seconds.")
	visible_title := testui.expect_visible_text(&handle, &warning.element, "Couldn't refresh folder")
	testing.expect(t, visible_title.ok, testui.visible_text_diagnostic(visible_title))
	visible_message := testui.expect_visible_text(&handle, &warning.element,
		"The folder's contents may be out of date.")
	testing.expect(t, visible_message.ok, testui.visible_text_diagnostic(visible_message))
	testui.destroy_find_result(&warning)

	retry := testui.find(&handle, testui.Query{role=.Button, name="Retry", match_role=true, match_name=true})
	if !testing.expect(t, retry.match == .Unique, "the card should expose its action") {
		testui.destroy_find_result(&retry)
		return
	}
	status := testui.click(&handle, &retry.element)
	testui.destroy_find_result(&retry)
	if !testing.expect(t, status == .Ok, "the card action should accept pointer input") { return }
	testing.expect(t, app.events == 1 && app.last_kind == .Actioned &&
		app.last_action == alicorn.Action_ID(11),
		"the card should return the app-owned Action_ID")

	// Mark the second card retiring. Its opacity motion must settle before the
	// application removes the item.
	app.items[1].retiring = true
	alicorn.invalidate_root(handle.runtime, "fixture retired notice card")
	_ = testui.describe_once(&handle)
	settled := false
	for _ in 0..<90 {
		_ = testui.advance_time(&handle, 16_000_000)
		alicorn.invalidate_root(handle.runtime, "fixture sampled retiring card motion")
		_ = testui.describe_once(&handle)
		if app.last_kind == .Retire_Settled { settled = true; break }
	}
	presentation := alicorn.motion_presentation(handle.runtime, app.states[1].motion_handle)
	testing.expectf(t, settled, "retiring card motion should report Retire_Settled (valid=%v last=%v status=%v active=%v opacity=%f declared=%v)",
		app.states[1].motion_valid, app.states[1].last_motion_status, presentation.status, presentation.active,
		presentation.presented_opacity, app.states[1].retire_declared)
	testing.expect(t, app.states[1].retire_settled, "the card state should record settlement")
}

@(test)
test_notice_theme_contract_and_toast_builder :: proc(t: ^testing.T) {
	notice := toast("id", "Title", "Message")
	testing.expect(t, notice.severity == .Info && notice.placement == .Toast &&
		notice.lifetime == .Transient, "toast should carry conservative defaults")
	testing.expect_value(t, notice.id, "id")
	testing.expect_value(t, notice.title, "Title")
	testing.expect_value(t, notice.message, "Message")

	recipe := Recipe{
		card_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.notices", "card"),
	}
	contract := theme_contract_default(recipe)
	testing.expect_value(t, contract.required_count, 1)
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 200, 100})
	defer alicorn.destroy_runtime(&rt)
	report := theme_contract_check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	testing.expect(t, !theme_contract_satisfied(report), "a configured card role must be validated")
	names, count := theme_contract_missing_required(contract, report)
	testing.expect(t, count == 1 && names[0] == "alikit.notices.card_surface")
}
