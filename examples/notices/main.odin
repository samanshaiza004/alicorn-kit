package main

// Notices example. Runtime toasts use Alicorn's own bounded notice queue and
// overlay. The inline banner uses AliKit's copyable card/stack parts for an
// application-owned presentation surface. Actions stay application-owned.
//
// Run:
//   odin run examples/notices -collection:alicorn=/path/to/alicorn
//   ./out/notices_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import theme "alicorn:theme"
import ui "alicorn:ui"
import notices "../../notices"

THEME_PATH :: "examples/notices/theme.json"
THEME_JSON :: #load("theme.json")

RETRY_ACTION :: alicorn.Action_ID(101)
DETAILS_ACTION :: alicorn.Action_ID(102)

App :: struct {
	pending:        alicorn.Notice,
	pending_set:    bool,

	banner_states:   [1]notices.State,
	banner_items:    [1]notices.Item,
	banner_actions:  [2]notices.Action,
	warning_actions: [1]notices.Action,

	recipe:         notices.Recipe,
	theme_id:       alicorn.Style_Theme_ID,
	theme_error:    bool,
	missing:        [8]string,
	missing_count:  int,

	status:         string,
	smoke:          bool,
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	app.banner_actions = {
		{id=RETRY_ACTION, label="Retry"},
		{id=DETAILS_ACTION, label="Details"},
	}
	app.warning_actions = {{id=RETRY_ACTION, label="Retry"}}
	app.banner_items[0] = notices.Item{
		key=1,
		title="Workspace is offline",
		message="Reconnect to refresh files.",
		details="The last sync attempt timed out.",
		severity=.Warning,
		actions=app.banner_actions[:],
	}
	registration := theme.theme_json_register(rt, string(THEME_JSON), THEME_PATH)
	defer theme.theme_json_register_result_destroy(&registration)
	app.theme_id = registration.theme_id
	if app.theme_id == 0 {
		fmt.println("Notices example theme registration failed:", registration.failure)
		return
	}
	app.recipe = notices.Recipe{
		card_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.notices", "card"),
	}
	contract := notices.theme_contract_default(app.recipe)
	report := notices.theme_contract_check(rt, app.theme_id, contract)
	app.missing, app.missing_count = notices.theme_contract_missing_required(contract, report)
	for index in 0..<app.missing_count {
		fmt.println("Missing notice theme role:", app.missing[index])
	}
	if app.missing_count > 0 { app.theme_error = true; app.recipe = {} }
}

post_pending :: proc(app: ^App, rt: ^alicorn.Runtime) {
	if !app.pending_set { return }
	app.pending_set = false
	// These example notices are persistent, so the runtime needs no clock
	// sample to set a deadline. Actions are delivered through its queue.
	_ = notices.post(rt, app.pending, 0)
}

request_toast :: proc(app: ^App, notice: alicorn.Notice) {
	app.pending = notice
	app.pending_set = true
}

on_after_frame :: proc(app: ^App, rt: ^alicorn.Runtime) {
	post_pending(app, rt)
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	for {
		event, found := notices.take_action(ctx.runtime)
		if !found { break }
		if event.action == RETRY_ACTION {
			app.status = "Retry requested; reconnecting."
			_ = notices.dismiss_handle(ctx.runtime, event.notice)
		} else if event.action == DETAILS_ACTION {
			app.status = "Details opened for the warning."
		}
	}

	if alicorn.container_begin(ctx, .Container, label="notices-example-root",
		key=ui.key_string("notices-example-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, grow=1, padding=28, gap=16, align=.Center),
		color=ui.style_color(ctx, .Window_Background)) != 0 {
		_ = ui.text(ctx, "Notices", size=26)
		_ = ui.text(ctx, "Runtime toasts plus copyable inline card parts.",
			size=13, color=ui.style_color(ctx, .Muted_Text))

		theme_scope := alicorn.Style_Environment_Scope{}
		if app.theme_id != 0 {
			theme_scope = alicorn.style_environment_push(ctx, alicorn.Style_Environment{theme=app.theme_id})
		}
		if ui.panel(ctx, key=ui.key_string("notices-example-card"), width=600,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=20, gap=12,
			fill=ui.style_color(ctx, .Surface), radius=12,
			stroke=ui.border(1, ui.style_color(ctx, .Border), .Inside)) {
			if ui.row(ctx, key=ui.key_string("notices-example-actions"), width=-1,
				height=32, gap=8, justify=.Center) {
				if ui.button(ctx, "Post saved", key=ui.key_string("post-saved"), width=130, height=30, variant=.Primary) {
					request_toast(app, notices.toast("example-saved", "Saved", "Document saved.",
						.Success, .Persistent))
				}
				if ui.button(ctx, "Post warning", key=ui.key_string("post-warning"), width=150, height=30) {
					request_toast(app, notices.toast("example-warning", "Couldn't refresh folder",
						"The folder's contents may be out of date.", .Warning, .Persistent,
						app.warning_actions[:]))
				}
				if ui.button(ctx, "Post error", key=ui.key_string("post-error"), width=130, height=30, variant=.Danger) {
					request_toast(app, notices.toast("example-error", "Save failed",
						"Check the destination and try again.", .Error, .Persistent))
				}
			}
			_ = ui.text(ctx, "Inline card parts:", size=13, color=ui.style_color(ctx, .Muted_Text))
			if event := notices.stack(ctx, app.banner_states[:], app.banner_items[:],
				key=ui.key_string("notices-example-banner"), recipe=app.recipe); event.kind != .None {
				app.status = "Banner action received."
				if event.kind == .Actioned && event.action == RETRY_ACTION {
					app.status = "Banner retry requested."
				}
				if event.kind == .Dismissed { app.banner_items[0].retiring = true }
				if event.kind == .Retire_Settled {
					app.banner_items[0] = notices.Item{key=1, title="Workspace is back online",
						message="Files are up to date.", severity=.Success}
					app.banner_states[0] = {}
				}
			}
			_ = ui.text(ctx, app.status, key=ui.key_string("notices-example-status"), size=13,
				color=ui.style_color(ctx, .Muted_Text))
			if app.theme_error {
				_ = ui.text(ctx, "Optional notice theme role is missing; core roles are in use.",
					size=12, color=ui.style_color(ctx, .Danger))
			}
		}
		if theme_scope.active { alicorn.style_environment_pop(ctx, theme_scope) }
		alicorn.container_end(ctx)
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("notices_smoke", "status", app.status, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{smoke=smoke, status="No active notice."}
	ui.run(
		&app,
		render,
		title="Alicorn - Notices",
		width=760,
		height=560,
		on_initialize=initialize,
		on_after_frame=on_after_frame,
		on_stop=stop,
		smoke=smoke,
	)
}
