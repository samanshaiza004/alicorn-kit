package main

import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import palette "alikit:command_palette"

App :: struct {
	palette_state: palette.State,
	items: [3]palette.Item,
	activated_id: palette.Item_ID,
	activation_count: int,
	open_key_count, down_key_count, return_key_count: int,
}

WINDOW_BACKGROUND :: alicorn.Color{0.071, 0.082, 0.102, 1}
TOP_BAR_BACKGROUND :: alicorn.Color{0.098, 0.114, 0.141, 1}
SIDEBAR_BACKGROUND :: alicorn.Color{0.090, 0.102, 0.122, 1}
CARD_BACKGROUND :: alicorn.Color{0.102, 0.122, 0.153, 1}

COMMANDS :: [3]palette.Item{
	{
		id=palette.Item_ID(101),
		title="Export workspace",
		description="Create a local archive of every project",
		keywords="archive backup all projects",
	},
	{
		id=palette.Item_ID(102),
		title="Export selected project",
		description="Download the current project only",
		keywords="archive download current",
	},
	{
		id=palette.Item_ID(103),
		title="Open export settings",
		description="Choose file format and destination",
		keywords="preferences format destination",
	},
}

app_initialize :: proc(state: rawptr, rt: ^alicorn.Runtime) {
	app := cast(^App)state
	if app == nil { return }
	app.items = COMMANDS
	_ = palette.init(&app.palette_state)
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	_ = app
	if ui.panel(ctx, key=ui.key_string("northstar-root"), width=-1, height=-1, grow=1,
		padding=0, gap=0, fill=WINDOW_BACKGROUND) {
		if ui.panel(ctx, key=ui.key_string("northstar-top-bar"), width=-1, height=54,
			padding=24, gap=12, fill=TOP_BAR_BACKGROUND) {
			if ui.row(ctx, key=ui.key_string("northstar-top-bar-content"), width=-1,
				height=-1, align=.Center, gap=12) {
				_ = ui.text(ctx, "✚", key=ui.key_string("northstar-logo"))
				_ = ui.text(ctx, "Northstar", key=ui.key_string("northstar-name"), size=15)
				if ui.row(ctx, width=-1, height=-1, grow=1) {
					_ = ui.text(ctx, "Workspace", key=ui.key_string("northstar-workspace"), size=13)
					_ = ui.text(ctx, "Profile", key=ui.key_string("northstar-profile"), size=13)
				}
			}
		}

		if ui.row(ctx, key=ui.key_string("northstar-body"), width=-1, height=-1, grow=1, gap=0) {
			if ui.panel(ctx, key=ui.key_string("northstar-sidebar"), width=232, height=-1,
				padding=24, gap=12, fill=SIDEBAR_BACKGROUND) {
				_ = ui.text(ctx, "WORKSPACE", key=ui.key_string("northstar-sidebar-heading"), size=11)
				_ = ui.button(ctx, "Projects", key=ui.key_string("northstar-projects-button"))
				_ = ui.button(ctx, "Activity", key=ui.key_string("northstar-activity-button"))
				_ = ui.button(ctx, "Shared with me", key=ui.key_string("northstar-shared-button"))
				_ = ui.button(ctx, "Archive", key=ui.key_string("northstar-archive-button"))
				_ = ui.text(ctx, "RECENT", key=ui.key_string("northstar-recent-heading"), size=11)
				_ = ui.text(ctx, "Design system", key=ui.key_string("northstar-recent-one"), size=13)
				_ = ui.text(ctx, "Mobile launch", key=ui.key_string("northstar-recent-two"), size=13)
				_ = ui.text(ctx, "Spring campaign", key=ui.key_string("northstar-recent-three"), size=13)
			}

			if ui.column(ctx, key=ui.key_string("northstar-projects"), width=-1, height=-1,
				grow=1, padding=38, gap=16) {
				_ = ui.text(ctx, "Projects", key=ui.key_string("northstar-projects-title"), size=25)
				_ = ui.text(ctx, "Everything your team is working on.",
					key=ui.key_string("northstar-projects-description"), size=14)
				if ui.panel(ctx, key=ui.key_string("northstar-card-one"), width=-1, height=94,
					padding=20, gap=8, radius=10, fill=CARD_BACKGROUND) {
					_ = ui.text(ctx, "Design system", key=ui.key_string("northstar-card-one-title"), size=15)
					_ = ui.text(ctx, "Updated 18 minutes ago", key=ui.key_string("northstar-card-one-meta"), size=13)
				}
				if ui.panel(ctx, key=ui.key_string("northstar-card-two"), width=-1, height=94,
					padding=20, gap=8, radius=10, fill=CARD_BACKGROUND) {
					_ = ui.text(ctx, "Mobile launch", key=ui.key_string("northstar-card-two-title"), size=15)
					_ = ui.text(ctx, "Updated yesterday", key=ui.key_string("northstar-card-two-meta"), size=13)
				}
				if ui.panel(ctx, key=ui.key_string("northstar-card-three"), width=-1, height=94,
					padding=20, gap=8, radius=10, fill=CARD_BACKGROUND) {
					_ = ui.text(ctx, "Spring campaign", key=ui.key_string("northstar-card-three-title"), size=15)
					_ = ui.text(ctx, "Updated Monday", key=ui.key_string("northstar-card-three-meta"), size=13)
				}
			}
		}
	}
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.palette_state.open { return }
	event := palette.build(ctx, &app.palette_state, app.items[:],
		ui.key_string("northstar-command-palette"),
		palette.Options{
			title="Quick actions\nSearch actions, files, and commands",
			query_accessible_name="Search actions, files, and commands",
			results_accessible_name="Actions",
			footer_label="Navigate  ·  Enter run  ·  Esc close",
			query_prefix="",
			panel_max_width=660,
			list_max_height=246,
			row_height=70,
			query_height=52,
			appearance=palette.Appearance{
				enabled=true,
				overlay_padding=24,
				panel_padding=40,
				panel_gap=12,
				backdrop_color=alicorn.Color{0.031, 0.039, 0.051, 0.67},
				panel_shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=14},
				panel_material=alicorn.MATERIAL_FLAT,
				panel_fill=alicorn.Color{0.125, 0.145, 0.180, 1},
				backdrop_effect=alicorn.BACKDROP_NONE,
			},
		},
	)
	if event.kind == .Activated {
		app.activated_id = event.item_id
		app.activation_count += 1
	}
}

on_key :: proc(app: ^App, rt: ^ui.Runtime, key: ui.Application_Key) -> bool {
	if !app.palette_state.open && key == .Open_Command_Palette {
		app.open_key_count += 1
		return palette.open_palette(&app.palette_state, rt)
	}
	if app.palette_state.open {
		if key == .Down { app.down_key_count += 1 }
		if key == .Return { app.return_key_count += 1 }
		handled, event := palette.handle_key(&app.palette_state, rt, app.items[:], key)
		if event.kind == .Activated {
			app.activated_id = event.item_id
			app.activation_count += 1
		}
		return handled
	}
	return false
}

main :: proc() {
	app: App
	app.items = COMMANDS
	if !palette.init(&app.palette_state) { return }
	defer palette.destroy(&app.palette_state)
	ui.run(&app, render,
		title="Northstar",
		width=1280,
		height=800,
		on_key=on_key,
		render_overlays=render_overlays,
	)
}
