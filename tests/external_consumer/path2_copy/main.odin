package main

// External consumer, authoring path 2: copy component source into the
// application's own tree. tools/validate_external_consumer.ps1 copies
// radio_group/radio_group.odin plus its declared source dependencies
// (selection/selection.odin and theme_contract/contract.odin) into
// path2_copy/vendor/ and rewrites the two intra-AliKit imports to those local
// packages. The build then needs only the Alicorn collection; there is no
// `alikit` collection and no AliKit repository topology.
//
// Build (exact collection args recorded by the harness):
//   odin build . -collection:alicorn=<alicorn>
// Run:
//   external_consumer_path2.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import radio "./vendor/radio_group"

PLANS := [3]radio.Option{
	{value=201, label="Personal", description="One workspace and local history"},
	{value=202, label="Team", description="Shared review, comments, and exports"},
	{value=203, label="Enterprise", description="Audit policy and private mirrors", disabled=true},
}

App :: struct {
	group:    radio.State,
	selected: u64,
	status:   string,
	smoke:    bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("copied-root"), width=-1, height=-1,
		padding=28, gap=14, align=.Center) {
		_ = ui.text(ctx, "AliKit external consumer", size=26)
		_ = ui.text(ctx, "Radio group copied into this application's source tree; only Alicorn is imported.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))

		if ui.panel(ctx, key=alicorn.key_string("copied-panel"), width=480,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=18, gap=12,
			fill=alicorn.style_color(ctx, .Surface), radius=10,
			stroke=ui.border(1, alicorn.style_color(ctx, .Border), .Inside)) {
			group, group_visible := radio.group_begin(
				ctx,
				&app.group,
				PLANS[:],
				app.selected,
				label="Plan",
				key=alicorn.key_string("copied-plan"),
				instance_id=5001,
				group_options=radio.Options{
					orientation=.Vertical,
					item_height=50,
					item_min_width=420,
					item_padding=10,
					item_gap=8,
				},
			)
			if group_visible {
				for plan in PLANS {
					item, item_visible := radio.item_begin(ctx, &group, plan)
					if !item_visible { continue }
					// Author-owned row: keep the component's indicator part and
					// replace the default label with a two-line subtree.
					if ui.row(ctx, key=ui.key_u64(1), grow=1, gap=10, align=.Center) {
						radio.indicator(ctx, item)
						if ui.column(ctx, key=ui.key_u64(2), grow=1, gap=1) {
							_ = ui.text(ctx, plan.label, key=ui.key_u64(3), size=14)
							_ = ui.text(ctx, plan.description, key=ui.key_u64(4), size=12,
								color=alicorn.style_color(ctx, .Muted_Text))
						}
					}
					radio.item_end(ctx, item)
				}
				if event := radio.group_end(ctx, &group); event.kind == .Selection_Proposed {
					app.selected = event.value
				}
			}
		}
		_ = ui.text(ctx, fmt.tprintf("Selected plan value: %d", app.selected), size=13)
		_ = ui.text(ctx, app.status, size=13, color=alicorn.style_color(ctx, .Muted_Text))
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("external_consumer_path2_smoke", "plan", app.selected, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{
		selected=201,
		status="The copied radio parts keep the component's interaction contract.",
		smoke=smoke,
	}
	ui.run(
		&app,
		render,
		title="Alicorn - AliKit external consumer (copied source)",
		width=680,
		height=520,
		on_stop=stop,
		smoke=smoke,
	)
}
