package main

// This reference scene keeps command data and dispatch in the application,
// while the palette package owns query editing, filtering, selection, focus,
// and stable result IDs. `--reference` opens the modal with a filtered query so
// the example can be compared with docs/research/authoring-reliability.

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import palette "alikit:command_palette"
import model "alikit:palette_model"
import parts "alikit:palette_parts"

SAMPLE_ITEMS :: [4]palette.Item{
	{ id=palette.Item_ID(1), title="Export workspace", description="Create a local archive of every project", keywords="export archive" },
	{ id=palette.Item_ID(2), title="Export selected project", description="Download the current project only", keywords="export download" },
	{ id=palette.Item_ID(3), title="Open export settings", description="Choose file format and destination", keywords="export preferences" },
	{ id=palette.Item_ID(4), title="Build project", description="Run the configured build", keywords="compile", disabled=true },
}

SIDEBAR_LINKS :: [3]string{"Activity", "Shared with me", "Archive"}
RECENT_LINKS :: [3]string{"Design system", "Mobile launch", "Spring campaign"}

App :: struct {
	palette_state: palette.State,
	items:         [4]palette.Item,
	matches:       [4]palette.Match,
	match_count:   int,
	last_action:   palette.Item_ID,
	reference_mode: bool,
	smoke:         bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	root := alicorn.surface_begin(ctx, alicorn.surface_core_color_role(.Window_Background),
		key=ui.key_string("palette-reference-root"),
		style=ui.layout_style(.Column, width=-1, height=-1, grow=1),
		fill=ui.style_color(ctx, .Window_Background), label="palette-reference-root")
	if root == 0 { return }
	header := alicorn.surface_begin(ctx, alicorn.surface_core_color_role(.Surface),
		key=ui.key_string("palette-reference-topbar"),
		style=ui.layout_style(.Row, width=-1, height=54, padding=24, gap=12, align=.Center),
		fill=ui.style_color(ctx, .Surface), label="palette-reference-topbar")
	if header != 0 {
		if ui.panel(ctx, key=ui.key_string("palette-reference-mark"), width=24, height=24,
			align=.Center, justify=.Center, fill=ui.style_color(ctx, .Accent), radius=7) {
			_ = ui.text(ctx, "+", size=17, color=ui.style_color(ctx, .Text), decorative=true)
		}
		_ = ui.text(ctx, "Northstar", size=15,
			text_style=ui.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD})
		if ui.column(ctx, key=ui.key_string("palette-reference-topbar-spacer"), grow=1) {}
		_ = ui.text(ctx, "Workspace", size=13, color=ui.style_color(ctx, .Muted_Text))
		_ = ui.text(ctx, "Profile", size=13, color=ui.style_color(ctx, .Muted_Text))
		ui.surface_end(ctx)
	}
	if ui.row(ctx, key=ui.key_string("palette-reference-shell"), width=-1, height=-1, grow=1) {
		sidebar := alicorn.surface_begin(ctx, alicorn.surface_core_color_role(.Surface),
			key=ui.key_string("palette-reference-sidebar"),
			style=ui.layout_style(.Column, width=232, height=-1, padding=16, gap=12),
			fill=ui.style_color(ctx, .Surface), label="palette-reference-sidebar")
		if sidebar != 0 {
			_ = ui.text(ctx, "WORKSPACE", size=11, color=ui.style_color(ctx, .Muted_Text))
			if ui.panel(ctx, key=ui.key_string("palette-reference-nav-projects"),
				width=-1, height=38, padding=12, fill=ui.style_color(ctx, .Subtle_Surface), radius=7) {
				if ui.row(ctx, width=-1, height=-1, gap=12, align=.Center) {
					_ = ui.icon(ctx, .Folder_Closed, size=14, color_role=.Accent)
					_ = ui.text(ctx, "Projects", size=14)
				}
			}
			for label in SIDEBAR_LINKS {
				if ui.row(ctx, width=-1, height=29, padding=12, align=.Center) {
					// Preserve the same leading icon track without inventing glyphs
					// that the core icon set does not currently provide.
					if ui.column(ctx, width=14) {}
					_ = ui.text(ctx, label, size=14, color=ui.style_color(ctx, .Muted_Text))
				}
			}
			if ui.panel(ctx, key=ui.key_string("palette-reference-sidebar-divider"),
				width=-1, height=1, fill=ui.style_color(ctx, .Border)) {}
			_ = ui.text(ctx, "RECENT", size=11, color=ui.style_color(ctx, .Muted_Text))
			for label in RECENT_LINKS {
				if ui.row(ctx, width=-1, height=25, padding=26, align=.Center) {
					_ = ui.text(ctx, label, size=13, color=ui.style_color(ctx, .Muted_Text))
				}
			}
			ui.surface_end(ctx)
		}

		if ui.column(ctx, key=ui.key_string("palette-reference-content"),
			width=-1, height=-1, grow=1, padding=28, gap=12) {
			if ui.row(ctx, width=-1, height=40, align=.Center, gap=12) {
				_ = ui.text(ctx, "Projects", size=25,
					text_style=ui.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD})
			}
			_ = ui.text(ctx, "Everything your team is working on.",
				color=ui.style_color(ctx, .Muted_Text))
			palette_reference_project(ctx, "Design system", "Updated 18 minutes ago", 1)
			palette_reference_project(ctx, "Mobile launch", "Updated yesterday", 2)
			palette_reference_project(ctx, "Spring campaign", "Updated Monday", 3)
			if app.last_action != 0 {
				_ = ui.text(ctx, fmt.tprintf("Last activated action ID: %d", u64(app.last_action)),
					color=ui.style_color(ctx, .Muted_Text))
			}
		}
	}
	ui.surface_end(ctx)
}

palette_reference_project :: proc(ctx: ^ui.UI, title, updated: string, id: u64) {
	if ui.panel(ctx, key=ui.key_u64(id), width=-1, height=94, padding=20, gap=4,
		fill=ui.style_color(ctx, .Surface), radius=9,
		stroke=ui.border(1, ui.style_color(ctx, .Border), .Inside)) {
		_ = ui.text(ctx, title, size=15,
			text_style=ui.Text_Style{font_weight=alicorn.FONT_WEIGHT_MEDIUM})
		_ = ui.text(ctx, updated, size=12, color=ui.style_color(ctx, .Muted_Text))
	}
}

palette_text_change :: proc(data: rawptr, rt: ^alicorn.Runtime, change: alicorn.Text_Change) -> bool {
	return palette.text_change(cast(^palette.State)data, rt, change)
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	state := &app.palette_state
	if state == nil || !state.open { return }

	state.overlay_node = alicorn.modal_overlay_begin(ctx,
		ui.key_string("palette-reference-overlay"),
		style=ui.layout_style(.Column, grow=1, padding=32, align=.Center, justify=.Center, clip=true),
		backdrop_color=alicorn.Color{0.025, 0.03, 0.045, 0.68})
	if state.overlay_node == 0 { return }
	_ = ui.interaction_scope(ctx, state.overlay_node, rawptr(state), ui.Interaction_Scope_Options{
		keys={.Escape, .Open_Command_Palette, .Up, .Down, .Return},
		composition_yield_keys={.Up, .Down, .Return},
		pointers={.Primary_Down},
		modal=true,
		on_text_change=palette_text_change,
	})

	if queued, found := ui.interaction_event_next(ctx, state.overlay_node); found {
		switch queued.kind {
		case .Key:
			handled, event := palette.handle_key(state, ctx.runtime, app.items[:], queued.key)
			_ = handled
			if event.kind == .Activated { app.last_action = event.item_id }
		case .Pointer:
			_ = palette.pointer(state, ctx.runtime, queued.pointer, queued.target)
		}
		if !state.open {
			alicorn.modal_overlay_end(ctx)
			return
		}
	}

	style := ui.layout_style(.Column, width=-1, height=576,
		max_width=660, max_height=576, padding=32, gap=12, clip=true)
	state.panel_node = alicorn.surface_begin(ctx, alicorn.surface_core_color_role(.Surface),
		key=ui.key_string("palette-reference-panel"), style=style,
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=14},
		fill=ui.style_color(ctx, .Surface), label="palette-reference-panel")
	if state.panel_node != 0 {
		_ = alicorn.semantic_describe_as(ctx,
			alicorn.Semantic_ID{namespace=0x414C494B, value=0x50414C45},
			.Dialog, "Quick actions", "Search actions, files, and commands.")
		_ = ui.text(ctx, "Quick actions", size=22,
			text_style=ui.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD})
		_ = ui.text(ctx, "Search actions, files, and commands", size=13,
			color=ui.style_color(ctx, .Muted_Text))

		if ui.row(ctx, key=ui.key_string("palette-reference-query-row"),
			width=-1, height=52, gap=10, align=.Center) {
			_ = ui.icon(ctx, .Search, key=ui.key_string("palette-reference-search-icon"), size=18,
				color_role=.Muted_Text)
			_, _ = palette.input(ctx, state,
				palette.Options{hide_title=true, query_accessible_name="Search actions"},
				key=ui.key_string("palette-reference-query"))
		}

		app.match_count, _ = model.filter(app.items[:], palette.query_text(state), app.matches[:])
		if app.match_count == 0 {
			_ = palette.empty(ctx,
				palette.Options{hide_title=true, empty_message="No matching actions"},
				key=ui.key_string("palette-reference-empty"))
		} else {
			list, opened := palette.list_begin(ctx, state, app.items[:], app.matches[:app.match_count],
				key=ui.key_string("palette-reference-results"),
				options=palette.Options{hide_title=true, results_accessible_name="Action results",
					row_height=72, list_max_height=280})
			if opened {
				activated: palette.Item_ID
				for index in list.first..<list.last {
					row, visible := palette.item_begin(ctx, &list, index)
					if !visible { continue }
					row_surface := parts.row_surface(ctx, row)
					if row_surface != 0 {
						icon := ui.Icon_ID.File
						if row.item.id == palette.Item_ID(3) { icon = .Settings }
					if ui.panel(ctx, key=ui.key_u64(1), width=38, height=38,
						align=.Center, justify=.Center,
						fill=ui.style_color(ctx, .Subtle_Surface if row.selected else .Surface), radius=8) {
						_ = ui.icon(ctx, icon, key=ui.key_u64(2), size=17, color_role=.Accent)
					}
					if ui.column(ctx, key=ui.key_u64(3), width=-1, grow=1, gap=2) {
						_ = ui.text(ctx, row.item.title, key=ui.key_u64(4), size=13,
							color=ui.style_color(ctx, .Muted_Text if row.disabled else .Text),
							decorative=true,
							text_style=ui.Text_Style{font_weight=alicorn.FONT_WEIGHT_MEDIUM, overflow=.Ellipsis})
						_ = ui.text(ctx, row.item.description, key=ui.key_u64(5), size=11,
							color=ui.style_color(ctx, .Muted_Text), decorative=true,
							text_style=ui.Text_Style{overflow=.Ellipsis})
					}
					shortcut := "CMD E"
					if row.item.id == palette.Item_ID(2) { shortcut = "CMD ⇧ E" }
					if row.item.id == palette.Item_ID(3) { shortcut = "CMD ," }
					if ui.panel(ctx, key=ui.key_u64(6), width=72, height=26,
						align=.Center, justify=.Center, fill=ui.style_color(ctx, .Subtle_Surface),
						radius=5, stroke=ui.border(1, ui.style_color(ctx, .Border), .Inside)) {
						_ = ui.text(ctx, shortcut, size=10, color=ui.style_color(ctx, .Muted_Text), decorative=true)
					}
					if row.selected {
						_ = ui.icon(ctx, .Check, key=ui.key_u64(7), size=14, color_role=.Text)
					}
					ui.surface_end(ctx)
				}
				if palette.item_end(ctx, state, &list, row) { activated = row.item.id }
				}
				if event := palette.list_end(ctx, state, &list); event.kind == .Activated {
					activated = event.item_id
				}
				if activated != 0 {
					app.last_action = activated
					palette.close_palette(state, ctx.runtime, true)
				}
			}
		}

		_ = ui.text(ctx, fmt.tprintf("%d actions  ·  ↑/↓ navigate  ·  Enter run  ·  Esc close", app.match_count),
			key=ui.key_string("palette-reference-footer"), size=12,
			color=ui.style_color(ctx, .Muted_Text))
		ui.surface_end(ctx)
	}
	alicorn.modal_overlay_end(ctx)
}

on_key :: proc(app: ^App, rt: ^ui.Runtime, key: ui.Application_Key) -> bool {
	if !app.palette_state.open && key == .Open_Command_Palette {
		return palette.open_palette(&app.palette_state, rt)
	}
	return false
}

initialize :: proc(app: ^App, rt: ^ui.Runtime) {
	if app.reference_mode {
		if palette.open_palette(&app.palette_state, rt) {
			_ = palette.set_query(&app.palette_state, rt, "export")
		}
	}
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("command_palette_smoke", "matches", app.match_count,
			"last", u64(app.last_action), "idle", true)
	}
}

main :: proc() {
	smoke, reference_mode := false, false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
		if argument == "--reference" { reference_mode = true }
	}
	app := App{items=SAMPLE_ITEMS, smoke=smoke, reference_mode=reference_mode}
	if !palette.init(&app.palette_state) {
		fmt.eprintln("Could not initialize the command palette state.")
		return
	}
	defer palette.destroy(&app.palette_state)
	ui.run(&app, render, title="AliKit Command Palette", width=1280, height=800,
		on_initialize=initialize, on_key=on_key, render_overlays=render_overlays,
		on_stop=stop, smoke=smoke)
}
