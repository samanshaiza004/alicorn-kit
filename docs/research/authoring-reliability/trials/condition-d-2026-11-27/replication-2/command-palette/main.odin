package main

import "core:mem"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import palette "alikit:command_palette"
import model "alikit:palette_model"
import parts "alikit:palette_parts"

App :: struct {
	palette_state: palette.State,
	items: [4]palette.Item,
	matches: [4]palette.Match,
	match_count: int,
	last_dispatched: palette.Item_ID,
}

PANEL_SEMANTIC_ID :: alicorn.Semantic_ID{namespace=0x434F4D4D, value=1}
QUERY_ROW_SEMANTIC_ID :: alicorn.Semantic_ID{namespace=0x434F4D4D, value=2}
QUERY_EDITOR_SEMANTIC_ID :: alicorn.Semantic_ID{namespace=0x434F4D4D, value=3}

init_app :: proc(app: ^App, allocator: mem.Allocator = context.allocator) -> bool {
	if app == nil { return false }
	app.items = [4]palette.Item{
		{id=palette.Item_ID(101), title="Export workspace", description="Create a local archive of every project", keywords="export archive all projects"},
		{id=palette.Item_ID(102), title="Export selected project", description="Download the current project only", keywords="export current project"},
		{id=palette.Item_ID(103), title="Open export settings", description="Choose file format and destination", keywords="export preferences format"},
		{id=palette.Item_ID(104), title="Invite teammate", description="Add someone to this workspace", keywords="people sharing"},
	}
	return palette.init(&app.palette_state, allocator)
}

destroy_app :: proc(app: ^App) {
	if app != nil { palette.destroy(&app.palette_state) }
}

initialize_palette :: proc(app: ^App, rt: ^alicorn.Runtime) {
	if app == nil || rt == nil { return }
	if palette.open_palette(&app.palette_state, rt) {
		_ = palette.set_query(&app.palette_state, rt, "export")
	}
}

test_initialize_palette :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	initialize_palette(cast(^App)data, rt)
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if app == nil || ctx == nil { return }
	if !ui.panel(ctx,
		key=ui.key_string("workspace-root"), width=-1, height=-1, grow=1,
		fill=ui.rgb(0x12151A), padding=0, gap=0,
	) { return }
	if ui.panel(ctx,
		key=ui.key_string("workspace-header"), width=-1, height=54,
		fill=ui.rgb(0x191D24), padding=0, gap=12,
	) {
		if ui.row(ctx, key=ui.key_string("header-content"), width=-1, height=54, padding=24, gap=12, align=.Center) {
			if ui.panel(ctx, key=ui.key_string("northstar-mark"), width=24, height=24,
				fill=ui.rgb(0x4D85CF), radius=7, align=.Center, justify=.Center) {
				_ = ui.text(ctx, "+", size=18, color=ui.rgb(0xF4F7FF), decorative=true)
			}
			_ = ui.text(ctx, "Northstar", size=15, color=ui.rgb(0xE7EAF0),
				text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD})
			if ui.row(ctx, key=ui.key_string("header-actions"), width=-1, height=54, grow=1, justify=.End, gap=28, align=.Center) {
				_ = ui.button(ctx, "Workspace", key=ui.key_string("workspace-opener"), height=28,
					variant=.Quiet, text_style=alicorn.Text_Style{font_size=13})
				_ = ui.text(ctx, "Profile", size=13, color=ui.rgb(0xA4ADBB))
			}
		}
	}
	if ui.row(ctx, key=ui.key_string("workspace-body"), width=-1, height=-1, grow=1, gap=0) {
		if ui.panel(ctx, key=ui.key_string("workspace-nav"), width=232, height=-1,
			fill=ui.rgb(0x171B21), padding=16, gap=0) {
			_ = ui.text(ctx, "WORKSPACE", size=11, color=ui.rgb(0x778292),
				text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_BOLD})
			if ui.panel(ctx, key=ui.key_string("nav-projects"), width=-1, height=38,
				fill=ui.rgb(0x242A33), radius=7, padding=12, align=.Center) {
				_ = ui.text(ctx, "Projects", size=14, color=ui.rgb(0xE7EAF0))
			}
		_ = ui.text(ctx, "Activity", size=14, color=ui.rgb(0xA4ADBB), style=ui.layout_style(.Row, height=40, padding=12, align=.Center))
		_ = ui.text(ctx, "Shared with me", size=14, color=ui.rgb(0xA4ADBB), style=ui.layout_style(.Row, height=40, padding=12, align=.Center))
		_ = ui.text(ctx, "Archive", size=14, color=ui.rgb(0xA4ADBB), style=ui.layout_style(.Row, height=40, padding=12, align=.Center))
		if ui.box(ctx, key=ui.key_string("nav-separator"), width=-1, height=1, fill=ui.rgb(0x353C48)) != 0 {
			// The leaf surface is already closed by ui.box.
		}
		_ = ui.text(ctx, "RECENT", size=11, color=ui.rgb(0x778292), style=ui.layout_style(.Row, height=30, padding=12, align=.Center),
			text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_BOLD})
		_ = ui.text(ctx, "Design system", size=13, color=ui.rgb(0xA4ADBB), style=ui.layout_style(.Row, height=30, padding=12, align=.Center))
		_ = ui.text(ctx, "Mobile launch", size=13, color=ui.rgb(0xA4ADBB), style=ui.layout_style(.Row, height=30, padding=12, align=.Center))
		_ = ui.text(ctx, "Spring campaign", size=13, color=ui.rgb(0xA4ADBB), style=ui.layout_style(.Row, height=30, padding=12, align=.Center))
		}
		if ui.column(ctx, key=ui.key_string("workspace-main"), width=-1, height=-1, grow=1, padding=38, gap=14) {
			_ = ui.text(ctx, "Projects", size=25, color=ui.rgb(0xE7EAF0),
				text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD})
			_ = ui.text(ctx, "Everything your team is working on.", size=14, color=ui.rgb(0xA4ADBB))
			workspace_card(ctx, "Design system", "Updated 18 minutes ago", "workspace-card-1")
			workspace_card(ctx, "Mobile launch", "Updated yesterday", "workspace-card-2")
			workspace_card(ctx, "Spring campaign", "Updated Monday", "workspace-card-3")
		}
	}
}

workspace_card :: proc(ctx: ^ui.UI, title, subtitle, key: string) {
	if ui.panel(ctx, key=ui.key_string(key), width=-1, height=94, padding=24, gap=9,
		fill=ui.rgb(0x1A1F27), radius=10, stroke=ui.border(1, ui.rgb(0x2C333E))) {
		_ = ui.text(ctx, title, size=15, color=ui.rgb(0xE7EAF0),
			text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD})
		_ = ui.text(ctx, subtitle, size=13, color=ui.rgb(0xA4ADBB))
	}
}

on_key :: proc(app: ^App, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	if app == nil || rt == nil { return false }
	if !app.palette_state.open && key == .Open_Command_Palette {
		return palette.open_palette(&app.palette_state, rt)
	}
	if app.palette_state.open {
		handled, event := palette.handle_key(&app.palette_state, rt, app.items[:], key)
		if event.kind == .Activated { dispatch(app, event.item_id) }
		return handled
	}
	return false
}

on_text_change :: proc(app: ^App, rt: ^alicorn.Runtime, change: alicorn.Text_Change) {
	if app != nil { _ = palette.text_change(&app.palette_state, rt, change) }
}

on_scoped_text_change :: proc(data: rawptr, rt: ^alicorn.Runtime, change: alicorn.Text_Change) -> bool {
	app := cast(^App)data
	if app == nil { return false }
	return palette.text_change(&app.palette_state, rt, change)
}

dispatch :: proc(app: ^App, id: palette.Item_ID) {
	if app == nil { return }
	// The reference scene keeps dispatch in application state; a real workspace
	// would execute its command service here.
	app.last_dispatched = id
}

on_key_event :: proc(app: ^App, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	return on_key(app, rt, key)
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if app == nil || ctx == nil || !app.palette_state.open { return }
	state := &app.palette_state
	state.overlay_node = alicorn.modal_overlay_begin(
		ctx,
		ui.key_string("command-palette-overlay"),
		style=ui.layout_style(.Column, width=-1, height=-1, grow=1, padding=32,
			align=.Center, justify=.Center, clip=true),
		backdrop_color=alicorn.Color{0.031, 0.039, 0.051, 0.67},
	)
	if state.overlay_node == 0 { return }
	_ = ui.interaction_scope(ctx, state.overlay_node, rawptr(app), alicorn.Interaction_Scope_Options{
		keys={.Escape, .Open_Command_Palette, .Up, .Down, .Return},
		composition_yield_keys={.Up, .Down, .Return},
		pointers={.Primary_Down},
		modal=true,
		on_text_change=on_scoped_text_change,
	})
	if queued, found := ui.interaction_event_next(ctx, state.overlay_node); found {
		switch queued.kind {
		case .Key:
			if handled, event := palette.handle_key(state, ctx.runtime, app.items[:], queued.key); handled {
				if event.kind == .Activated { dispatch(app, event.item_id) }
			}
		case .Pointer:
			_ = palette.pointer(state, ctx.runtime, queued.pointer, queued.target)
		}
	}
	if state.open { draw_palette(app, ctx) }
	alicorn.modal_overlay_end(ctx)
}

draw_palette :: proc(app: ^App, ctx: ^ui.UI) {
	state := &app.palette_state
	state.panel_node = alicorn.surface_begin(
		ctx,
		alicorn.surface_core_color_role(.Surface),
		key=ui.key_string("command-palette-panel"),
		style=ui.layout_style(.Column, width=660, height=576, padding=40, gap=0, clip=true),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=14},
		fill=ui.rgb(0x20252E),
		stroke=alicorn.Paint_Stroke{color=ui.rgb(0x39414E), width=1},
		label="command-palette-panel",
	)
	if state.panel_node == 0 { return }
	_ = alicorn.semantic_describe_as(ctx, PANEL_SEMANTIC_ID, .Dialog, "Quick actions")
	_ = ui.text(ctx, "Quick actions", key=ui.key_string("palette-title"), size=22,
		color=ui.rgb(0xE7EAF0), text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD})
	_ = ui.text(ctx, "Search actions, files, and commands", key=ui.key_string("palette-subtitle"), size=13,
		color=ui.rgb(0xA4ADBB))
	spacer(ctx, 16, "palette-query-gap")
	query_surface := alicorn.surface_begin(
		ctx,
		alicorn.surface_core_color_role(.Surface),
		key=ui.key_string("palette-query-surface"),
		style=ui.layout_style(.Row, width=-1, height=52, padding=10, gap=10, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=8},
		fill=ui.rgb(0x151920),
		stroke=alicorn.Paint_Stroke{color=ui.rgb(0x78AAF3), width=2},
		label="command-palette-query-row",
	)
	if query_surface != 0 {
		_ = alicorn.semantic_describe_as(ctx, QUERY_ROW_SEMANTIC_ID, .Group, "Search input")
		_ = ui.icon(ctx, .Search, key=ui.key_string("palette-search-icon"), size=16, color_role=.Muted_Text)
		if ui.row(ctx, key=ui.key_string("palette-query-editor"), width=-1, height=32, grow=1, align=.Center) {
			if editor := alicorn.container_begin(ctx, .Container, label="query-editor", key=ui.key_string("palette-query-editor-owner"),
				style=ui.layout_style(.Row, width=-1, height=32, grow=1)); editor != 0 {
				_ = alicorn.semantic_describe_as(ctx, QUERY_EDITOR_SEMANTIC_ID, .Group, "Query editor")
				_, _ = palette.input(ctx, &app.palette_state,
					palette.Options{query_accessible_name="Search actions", query_height=32,
						query_text_style=alicorn.Text_Style{font_size=14}},
					key=ui.key_string("palette-query-field"))
				alicorn.container_end(ctx)
			}
		}
		ui.surface_end(ctx)
	}
	spacer(ctx, 14, "palette-results-gap")
	count, _ := model.filter(app.items[:], palette.query_text(&app.palette_state), app.matches[:])
	app.match_count = count
	if count == 0 {
		_ = palette.empty(ctx, palette.Options{empty_message="No matching actions"}, key=ui.key_string("palette-empty"))
	} else {
		list, opened := palette.list_begin(ctx, &app.palette_state, app.items[:], app.matches[:count],
			key=ui.key_string("palette-results"),
			options=palette.Options{results_accessible_name="Actions", row_height=74, list_max_height=240})
		if opened {
			for index := list.first; index < list.last; index += 1 {
				row, visible := palette.item_begin(ctx, &list, index)
				if !visible { continue }
				if parts.row_surface(ctx, row) != 0 {
					draw_result_icon(ctx, row.item.id)
					if ui.column(ctx, key=ui.key_string("palette-row-copy"), width=-1, height=50, grow=1, gap=2, justify=.Center) {
						_ = ui.text(ctx, row.item.title, key=ui.key_string("row-title"), size=14, color=ui.rgb(0xE7EAF0),
							text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD, overflow=.Ellipsis})
						_ = ui.text(ctx, row.item.description, key=ui.key_string("row-description"), size=12, color=ui.rgb(0xA4ADBB),
							text_style=alicorn.Text_Style{overflow=.Ellipsis})
					}
					draw_shortcut(ctx, shortcut_for(row.item.id))
					ui.surface_end(ctx)
				}
				if palette.item_end(ctx, &app.palette_state, &list, row) {
					activated := palette.Event{kind=.Activated, item_id=row.item.id}
					dispatch(app, activated.item_id)
					palette.close_palette(&app.palette_state, ctx.runtime, true)
				}
			}
			if event := palette.list_end(ctx, &app.palette_state, &list); event.kind == .Activated {
				dispatch(app, event.item_id)
				palette.close_palette(&app.palette_state, ctx.runtime, true)
			}
		}
	}
	spacer(ctx, 34, "palette-footer-gap")
	_ = ui.box(ctx, key=ui.key_string("palette-divider"), width=-1, height=1, fill=ui.rgb(0x353C48))
	spacer(ctx, 14, "palette-footer-top-gap")
	if ui.row(ctx, key=ui.key_string("palette-footer"), width=-1, height=24, gap=8, align=.Center) {
		_ = ui.text(ctx, fmt_count(app.match_count), key=ui.key_string("palette-count"), size=12, color=ui.rgb(0xA4ADBB))
		spacer_width(ctx, 12, "footer-count-space")
		if ui.row(ctx, key=ui.key_string("footer-navigate"), width=122, height=24, gap=7, align=.Center) {
			_ = ui.text(ctx, "↑↓", size=13, color=ui.rgb(0xBBC4D0), decorative=true)
			_ = ui.text(ctx, "Navigate", size=12, color=ui.rgb(0xA4ADBB))
		}
		if ui.row(ctx, key=ui.key_string("footer-run"), width=78, height=24, gap=6, align=.Center) {
			key_cap(ctx, "↵", 24, "footer-return-key")
			_ = ui.text(ctx, "Run", size=12, color=ui.rgb(0xA4ADBB))
		}
		if ui.row(ctx, key=ui.key_string("footer-close"), width=92, height=24, gap=7, align=.Center) {
			key_cap(ctx, "ESC", 38, "footer-escape-key")
			_ = ui.text(ctx, "Close", size=12, color=ui.rgb(0xA4ADBB))
		}
	}
	alicorn.surface_end(ctx)
}

draw_result_icon :: proc(ctx: ^ui.UI, id: palette.Item_ID) {
	icon_id := alicorn.Icon_ID.Folder_Open
	fill := ui.rgb(0x344A68)
	switch id {
	case palette.Item_ID(102): icon_id = .File; fill = ui.rgb(0x292F39)
	case palette.Item_ID(103): icon_id = .Settings; fill = ui.rgb(0x292F39)
	case palette.Item_ID(104): icon_id = .More_Horizontal; fill = ui.rgb(0x292F39)
	case:
	}
	if ui.panel(ctx, key=ui.key_string("row-icon-tile"), width=38, height=38, fill=fill,
		radius=9, align=.Center, justify=.Center) {
		color_role := alicorn.Style_Color_Role.Muted_Text
		if id == palette.Item_ID(101) { color_role = .Text }
		_ = ui.icon(ctx, icon_id, key=ui.key_string("row-action-icon"), size=18, color_role=color_role)
	}
}

shortcut_for :: proc(id: palette.Item_ID) -> string {
	switch id {
	case palette.Item_ID(101): return "CMD  E"
	case palette.Item_ID(102): return "CMD  ⇧ E"
	case palette.Item_ID(103): return "CMD  ,"
	case: return ""
	}
}

draw_shortcut :: proc(ctx: ^ui.UI, value: string) {
	if len(value) == 0 { return }
	key_cap(ctx, value, 72, "row-shortcut")
}

key_cap :: proc(ctx: ^ui.UI, value: string, width: f32, key: string) {
	if ui.panel(ctx, key=ui.key_string(key), width=width, height=27, padding=5, gap=0,
		fill=ui.rgb(0x202936), radius=5, align=.Center, justify=.Center,
		stroke=ui.border(1, ui.rgb(0x536176))) {
		_ = ui.text(ctx, value, size=11, color=ui.rgb(0xA4ADBB), decorative=true)
	}
}

spacer :: proc(ctx: ^ui.UI, height: f32, key: string) {
	if ui.row(ctx, key=ui.key_string(key), width=-1, height=height) {}
}

spacer_width :: proc(ctx: ^ui.UI, width: f32, key: string) {
	if ui.column(ctx, key=ui.key_string(key), width=width, height=1) {}
}

fmt_count :: proc(count: int) -> string {
	if count == 1 { return "1 action" }
	if count == 3 { return "3 actions" }
	return "0 actions"
}

main :: proc() {
	app: App
	if !init_app(&app) { return }
	defer destroy_app(&app)
	ui.run(&app, render,
		title="Northstar · Quick actions",
		width=1280,
		height=800,
		render_overlays=render_overlays,
		on_initialize=initialize_palette,
		on_key=on_key_event,
		on_text_change=on_text_change,
	)
}
