package main

// Command palette parts example: an application-owned shell that composes the
// public input and result-list parts. The application owns the query buffer,
// filtering, ranking, grouping, and dispatch. The parts own the controlled text
// field, List_Box/List_Box_Option semantics, stable-ID selection, enabled-row
// navigation, reveal, and one activation event. The row content is authored
// here: leading icon tile, title, description, scope chip, and selected check.
//
// Run:
//   odin run examples/command_palette_parts -collection:alicorn=/path/to/alicorn
//   ./out/command_palette_parts_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import palette "alikit:command_palette"
import model "alikit:palette_model"
import parts "alikit:palette_parts"

ITEMS: [6]model.Item = {
	{id=model.Item_ID(1), title="Open file", description="Browse the workspace", keywords="file browse"},
	{id=model.Item_ID(2), title="Search in files", description="Find text across the workspace", keywords="find grep"},
	{id=model.Item_ID(3), title="Toggle sidebar", description="Show or hide navigation", keywords="panel nav"},
	{id=model.Item_ID(4), title="Build project", description="Run the configured build", keywords="compile"},
	{id=model.Item_ID(5), title="Publish release", description="Unavailable in this example", keywords="ship", disabled=true},
	{id=model.Item_ID(6), title="Open settings", description="Adjust editor preferences", keywords="preferences"},
}

App :: struct {
	state:   palette.State,
	matches: [len(ITEMS)]model.Match,
	count:   int,
	last:    model.Item_ID,
	smoke:   bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if alicorn.container_begin(ctx, .Container, label="command-palette-parts-example-root",
		key=alicorn.key_string("command-palette-parts-example-root"),
		style=alicorn.layout_style(.Column, width=-1, height=-1, grow=1, padding=24, gap=10),
		color=alicorn.style_color(ctx, .Window_Background)) != 0 {
		_ = ui.text(ctx, "Command palette parts", size=26)
		_ = ui.text(ctx, "The application owns the shell, filtering, grouping, and dispatch.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		_, _ = palette.input(ctx, &app.state,
			palette.Options{hide_title=true, query_height=40},
			key=alicorn.key_string("command-palette-parts-example-input"))
		app.count, _ = model.filter(ITEMS[:], palette.query_text(&app.state), app.matches[:])
		if app.count == 0 {
			_ = palette.empty(ctx, palette.Options{hide_title=true},
				key=alicorn.key_string("command-palette-parts-example-empty"))
		} else {
			list, opened := palette.list_begin(ctx, &app.state, ITEMS[:], app.matches[:app.count],
				key=alicorn.key_string("command-palette-parts-example-list"),
				options=palette.Options{hide_title=true, list_max_height=300})
			if opened {
				// A caller-owned visual group over the short result set. Groups
				// need every row realized; this list fits its viewport.
				group, group_visible := palette.group_begin(ctx, &list, "Suggested",
					key=alicorn.key_string("command-palette-parts-example-group"))
				for index in list.first..<list.last {
					row, row_visible := palette.item_begin(ctx, &list, index)
					if !row_visible { continue }
					if parts.row_surface(ctx, row) != 0 {
						_ = ui.box(ctx, key=ui.key_u64(1), size=22,
							fill=alicorn.style_color(ctx, .Selection if row.selected else .Subtle_Surface),
							radius=6)
						if ui.column(ctx, key=ui.key_u64(2), grow=1, gap=1) {
							_ = ui.text(ctx, row.item.title, key=ui.key_u64(3), size=13,
								color=alicorn.style_color(ctx, .Muted_Text if row.disabled else .Text))
							_ = ui.text(ctx, row.item.description, key=ui.key_u64(4), size=10,
								color=alicorn.style_color(ctx, .Muted_Text))
						}
						if row.item.keywords != "" {
							_ = ui.text(ctx, row.item.keywords, key=ui.key_u64(5), size=10,
								color=alicorn.style_color(ctx, .Muted_Text))
						}
						if row.selected {
							_ = ui.icon(ctx, .Check, key=ui.key_u64(6), size=14, color_role=.Accent)
						}
						alicorn.surface_end(ctx)
					}
					if palette.item_end(ctx, &app.state, &list, row) {
						app.last = row.item.id
					}
				}
				if group_visible { palette.group_end(ctx, &group) }
				if event := palette.list_end(ctx, &app.state, &list); event.kind == .Activated {
					app.last = event.item_id
				}
			}
		}
		status := "Type to filter, then use Up/Down and Return."
		if app.last != 0 {
			status = fmt.tprintf("Activated item ID: %d", model.item_id_value(app.last))
		}
		_ = ui.text(ctx, status, size=13, color=alicorn.style_color(ctx, .Muted_Text))
		alicorn.container_end(ctx)
	}
}

on_key :: proc(app: ^App, rt: ^alicorn.Runtime, key: alicorn.Application_Key) -> bool {
	handled, event := palette.handle_key(&app.state, rt, ITEMS[:], key)
	if event.kind == .Activated { app.last = event.item_id }
	return handled
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("command_palette_parts_smoke", "last", model.item_id_value(app.last), "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{smoke=smoke}
	if !palette.init(&app.state) { return }
	defer palette.destroy(&app.state)
	ui.run(&app, render, title="Alicorn - Command Palette Parts", width=720, height=540,
		on_key=on_key, on_stop=stop, smoke=smoke)
}
