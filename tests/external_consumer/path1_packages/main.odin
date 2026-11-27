package main

// External consumer, authoring path 1: import complete AliKit packages through
// the `alikit` collection and compose them. This file is copied outside the
// AliKit repository by tools/validate_external_consumer.ps1.
//
// It exercises three authoring paths at once:
//   1. complete packages: alikit:dialog, alikit:menu, alikit:progress, alikit:notices;
//   2. parts: a radio group composed from group_begin/item_begin/indicator/
//      label/item_end/group_end inside the dialog content slot;
//   3. behavior-only: a small author-owned selection strip built directly on
//      alikit:selection's borrowed View and proposal helpers.
//
// Build (exact collection args recorded by the harness):
//   odin build . -collection:alicorn=<alicorn> -collection:alikit=<alicorn-kit>
// Run:
//   external_consumer_path1.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import dialog "alikit:dialog"
import menu "alikit:menu"
import notices "alikit:notices"
import progress "alikit:progress"
import radio "alikit:radio_group"
import selection "alikit:selection"

PLANS := [3]radio.Option{
	{value=101, label="Personal", description="One workspace and local history"},
	{value=102, label="Team", description="Shared review, comments, and exports"},
	{value=103, label="Enterprise", description="Audit policy and private mirrors", disabled=true},
}

PLAN_ACTIONS := [3]menu.Item{
	{key=201, label="Copy invitation link", shortcut="Ctrl+C"},
	{key=202, label="Resend invitation"},
	{key=203, label="Remove invite", disabled=true},
}

// Lane is application-owned data for the behavior-only strip. The keys are
// stable, nonzero, and unique, as alikit:selection expects.
Lane :: struct {
	key:   u64,
	label: string,
}

LANES := [4]Lane{
	{key=1, label="Draft"},
	{key=2, label="Review"},
	{key=3, label="Ship"},
	{key=4, label="Archive"},
}

App :: struct {
	// Complete package + parts composition.
	view:     dialog.State,
	group:    radio.State,
	actions:  menu.State,
	selected: u64,

	// Progress part.
	progress: progress.State,

	// Behavior-only strip: application state plus the shared selection model.
	lanes:      [4]Lane,
	lane_state: selection.State,
	lane:       u64,

	// Toast part.
	pending_toast:  bool,
	ready_posted:   bool,
	toasts_posted:  int,

	status: string,
	smoke:  bool,
}

lane_key_at :: proc(data: rawptr, index: int) -> u64 {
	lanes := cast([^]Lane)data
	return lanes[index].key
}

lane_view :: proc(lanes: []Lane) -> selection.View {
	return selection.View{
		count=len(lanes),
		data=rawptr(raw_data(lanes)),
		key_at=lane_key_at,
	}
}

selected_plan_text :: proc(app: ^App) -> string {
	for plan in PLANS {
		if plan.value == app.selected { return plan.label }
	}
	return "none"
}

render_lane_strip :: proc(app: ^App, ctx: ^ui.UI) {
	view := lane_view(app.lanes[:])
	_ = selection.reconcile_active(&app.lane_state, view, app.lane)

	if ui.row(ctx, key=alicorn.key_string("consumer-lanes"), width=-1,
		height=alicorn.LAYOUT_SIZE_FIT_CONTENT, gap=8, align=.Center) {
		if ui.button(ctx, "<", key=alicorn.key_string("consumer-lanes-prev"),
			width=32, height=32, variant=.Quiet) {
			index := selection.index_of_key(view, app.lane)
			if previous := selection.move_wrapped(view, index, -1); previous >= 0 {
				// Follow_Focus is the platform radio convention; an explicit
				// activation would use propose_activation instead.
				if key, proposed := selection.propose_focus(view, previous, .Follow_Focus); proposed {
					app.lane = key
				}
			}
		}
		for lane in app.lanes {
			variant := alicorn.Button_Variant.Default
			if lane.key == app.lane { variant = .Primary }
			if ui.button(ctx, lane.label, key=ui.key_u64(lane.key),
				width=96, height=32, variant=variant) {
				index := selection.index_of_key(view, lane.key)
				if key, proposed := selection.propose_activation(view, index); proposed {
					app.lane = key
				}
			}
		}
		if ui.button(ctx, ">", key=alicorn.key_string("consumer-lanes-next"),
			width=32, height=32, variant=.Quiet) {
			index := selection.index_of_key(view, app.lane)
			if next := selection.move_wrapped(view, index, 1); next >= 0 {
				if key, proposed := selection.propose_focus(view, next, .Follow_Focus); proposed {
					app.lane = key
				}
			}
		}
	}
}

render_progress_part :: proc(app: ^App, ctx: ^ui.UI) {
	value: f64
	switch app.selected {
	case 102: value = 66
	case 103: value = 100
	case:     value = 33
	}
	part, visible := progress.begin(
		ctx,
		&app.progress,
		value,
		0,
		100,
		progress.Options{accessible_label="Plan setup", width=360},
		key=alicorn.key_string("consumer-progress"),
		instance_id=9001,
	)
	if !visible { return }
	if ui.row(ctx, key=alicorn.key_string("consumer-progress-heading"), width=-1,
		height=alicorn.LAYOUT_SIZE_FIT_CONTENT, gap=8, align=.Center) {
		progress.label(ctx, &part)
		progress.value_text(ctx, &part)
	}
	if track, track_visible := progress.track_begin(ctx, &part); track_visible {
		progress.indicator(ctx, &track)
		progress.track_end(ctx)
	}
	progress.end(ctx, &part)
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("consumer-root"), width=-1, height=-1,
		padding=28, gap=14, align=.Center) {
		_ = ui.text(ctx, "AliKit external consumer", size=26)
		_ = ui.text(ctx, "Packages and parts imported through the alikit collection.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))

		if ui.button(ctx, "Change plan", key=alicorn.key_string("consumer-open"),
			width=150, height=34) {
			_ = dialog.open(&app.view, ctx.runtime)
		}
		_ = ui.text(ctx, fmt.tprintf("Selected plan: %s", selected_plan_text(app)),
			size=13, color=alicorn.style_color(ctx, .Muted_Text))

		_ = ui.text(ctx, "Author-owned strip over alikit:selection", size=13)
		render_lane_strip(app, ctx)
		_ = ui.text(ctx, fmt.tprintf("Lane: %d", app.lane), size=12,
			color=alicorn.style_color(ctx, .Muted_Text))

		render_progress_part(app, ctx)
		_ = ui.text(ctx, app.status, size=13, color=alicorn.style_color(ctx, .Muted_Text))
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
			primary_key=alicorn.key_string("consumer-save"),
		},
		key=alicorn.key_string("consumer-dialog"),
		instance_id=9002,
	)
	if !visible {
		if event.kind == .Dismissed { app.status = "Plan change dismissed." }
		return
	}
	dialog.title(ctx, "Choose a plan")
	dialog.description(ctx, "One plan per workspace. Disabled plans stay visible but cannot be selected.")
	if dialog.content_begin(ctx, key=alicorn.key_string("consumer-content")) {
		group, group_visible := radio.group_begin(
			ctx,
			&app.group,
			PLANS[:],
			app.selected,
			label="Plan",
			key=alicorn.key_string("consumer-plan"),
			instance_id=9003,
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
						color=alicorn.style_color(ctx, .Muted_Text))
				}
				radio.item_end(ctx, item)
			}
			if radio_event := radio.group_end(ctx, &group); radio_event.kind == .Selection_Proposed {
				app.selected = radio_event.value
			}
		}
		_ = menu.trigger(ctx, &app.actions, "Invitation actions",
			menu.Options{accessible_label="Invitation actions"},
			key=alicorn.key_string("consumer-invitation-actions"))
		dialog.content_end(ctx)
	}
	if dialog.action_row_begin(ctx, key=alicorn.key_string("consumer-actions")) {
		if dialog.action(ctx, &app.view, "Save", .Primary,
			key=alicorn.key_string("consumer-save")) {
			app.pending_toast = true
			app.status = fmt.tprintf("Plan %s saved.", selected_plan_text(app))
			dialog.dismiss(ctx, &app.view, .Action)
		}
		if dialog.action(ctx, &app.view, "Cancel", .Cancel,
			key=alicorn.key_string("consumer-cancel")) {
			app.status = "Plan change cancelled."
			dialog.dismiss(ctx, &app.view, .Action)
		}
		dialog.action_row_end(ctx)
	}
	dialog.end(ctx, &app.view)

	// The external package consumer composes Menu as an anchored popup inside
	// Dialog content. Describe it after the Dialog so it owns the top overlay.
	menu_visible, chosen := menu.popup_begin(ctx, &app.actions, PLAN_ACTIONS[:],
		menu.Options{accessible_label="Invitation actions"},
		key=alicorn.key_string("consumer-invitation-actions-popup"), instance_id=9004)
	if menu_visible {
		for item, index in PLAN_ACTIONS {
			if menu.item(ctx, &app.actions, item, index) {
				app.status = fmt.tprintf("Invitation action %d selected.", item.key)
			}
		}
		menu.popup_end(ctx, &app.actions)
	} else if chosen != 0 {
		app.status = fmt.tprintf("Invitation action %d selected.", chosen)
	}
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	if rt == nil { return }
	if app.smoke {
		// Render the modal composition during the bounded smoke run.
		_ = dialog.open(&app.view, rt)
	}
}

after_frame :: proc(app: ^App, rt: ^alicorn.Runtime) {
	if rt == nil { return }
	if !app.ready_posted {
		app.ready_posted = true
		// A toast is a runtime notice from the application's own queue. Post it
		// after the first frame, like the AliKit notices example, so the first
		// description is already complete.
		if notices.post(rt, notices.toast(
			"external-consumer-ready",
			"External consumer ready",
			"One package import and one copied source tree.",
			.Success,
			.Persistent,
		), 0) {
			app.toasts_posted += 1
		}
		return
	}
	if !app.pending_toast { return }
	app.pending_toast = false
	if notices.post(rt, notices.toast(
		fmt.tprintf("external-consumer-saved-%d", app.toasts_posted+1),
		"Plan saved",
		"The application-owned action posted this toast.",
		.Info,
		.Persistent,
	), 0) {
		app.toasts_posted += 1
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("external_consumer_path1_smoke",
			"plan", app.selected,
			"lane", app.lane,
			"toasts", app.toasts_posted,
			"idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{
		selected=101,
		lane=1,
		status="Open the dialog to change plans.",
		smoke=smoke,
	}
	ui.run(
		&app,
		render,
		title="Alicorn - AliKit external consumer (packages)",
		width=780,
		height=620,
		render_overlays=render_overlays,
		on_initialize=initialize,
		on_after_frame=after_frame,
		on_stop=stop,
		smoke=smoke,
	)
}
