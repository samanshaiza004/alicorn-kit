package main

// Radio and Dialog composition: the public radio parts inside a modal dialog
// form. The Dialog owns Escape/backdrop policy, initial focus, and focus
// restoration; Radio owns single-selection semantics, roving focus, and the
// selection proposal. The application owns the accepted plan and dispatch.
//
// Run:
//   odin run examples/radio_group_composition -collection:alicorn=/path/to/alicorn
//   ./out/radio_group_composition_example.exe --smoke

import "core:fmt"
import "core:os"
import ui "alicorn:ui"
import dialog "../../dialog"
import radio "../../radio_group"

PLANS := [3]radio.Option{
	{value=201, label="Personal", description="One workspace and local history"},
	{value=202, label="Team", description="Shared review, comments, and exports"},
	{value=203, label="Enterprise", description="Audit policy and private mirrors", disabled=true},
}

App :: struct {
	group:    radio.State,
	view:     dialog.State,
	selected: u64,
	status:   string,
	smoke:    bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("radio-compose-root"),
		width=-1, height=-1, padding=28, gap=14, align=.Center) {
		_ = ui.text(ctx, "Radio + Dialog", size=26)
		_ = ui.text(ctx, "The radio parts live inside a modal form. Dialog owns dismissal and focus; Radio owns selection.",
			size=13, color=ui.style_color(ctx, .Muted_Text))
		if ui.button(ctx, "Change plan", key=ui.key_string("radio-compose-open"),
			width=150, height=34) {
			_ = dialog.open(&app.view, ctx.runtime)
		}
		_ = ui.text(ctx, app.status, size=13, color=ui.style_color(ctx, .Muted_Text))
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.view.open { return }
	visible, event := dialog.begin(
		ctx,
		&app.view,
		"Choose a plan",
		dialog.Options{
			description="The selected plan is applied when you save.",
			primary_key=ui.key_string("radio-compose-save"),
		},
		key=ui.key_string("radio-compose-dialog"),
		instance_id=4401,
	)
	if !visible {
		if event.kind == .Dismissed { app.status = "Plan change dismissed." }
		return
	}
	dialog.title(ctx, "Choose a plan")
	dialog.description(ctx, "One plan per workspace. Disabled plans stay visible but cannot be selected.")
	if dialog.content_begin(ctx, key=ui.key_string("radio-compose-content")) {
		group, group_visible := radio.group_begin(
			ctx,
			&app.group,
			PLANS[:],
			app.selected,
			label="Plan",
			key=ui.key_string("radio-compose-plan"),
			instance_id=4402,
			group_options=radio.Options{
				orientation=.Vertical,
				item_height=52,
				item_min_width=420,
				item_padding=10,
				item_gap=8,
			},
		)
		if group_visible {
			for option in PLANS {
				item, item_visible := radio.item_begin(ctx, &group, option)
				if !item_visible { continue }
				radio.indicator(ctx, item)
				if ui.column(ctx, key=ui.key_u64(1), grow=1, gap=1) {
					_ = ui.text(ctx, option.label, key=ui.key_u64(2), size=14)
					_ = ui.text(ctx, option.description, key=ui.key_u64(3), size=12,
						color=ui.style_color(ctx, .Muted_Text))
				}
				radio.item_end(ctx, item)
			}
			if radio_event := radio.group_end(ctx, &group); radio_event.kind == .Selection_Proposed {
				app.selected = radio_event.value
			}
		}
		dialog.content_end(ctx)
	}
	if dialog.action_row_begin(ctx, key=ui.key_string("radio-compose-actions")) {
		if dialog.action(ctx, &app.view, "Save", .Primary, key=ui.key_string("radio-compose-save")) {
			app.status = fmt.tprintf("Plan %d saved.", app.selected)
			dialog.dismiss(ctx, &app.view, .Action)
		}
		if dialog.action(ctx, &app.view, "Cancel", .Cancel, key=ui.key_string("radio-compose-cancel")) {
			app.status = "Plan change cancelled."
			dialog.dismiss(ctx, &app.view, .Action)
		}
		dialog.action_row_end(ctx)
	}
	dialog.end(ctx, &app.view)
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("radio_group_composition_smoke", "selected", app.selected, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{selected=201, status="Open the dialog to change plans.", smoke=smoke}
	ui.run(
		&app,
		render,
		title="Alicorn - Radio Composition",
		width=780,
		height=520,
		render_overlays=render_overlays,
		on_stop=stop,
		smoke=smoke,
	)
}
