package main

import "core:fmt"
import alicorn "alicorn:runtime"
import host "alicorn:native/sdl_gpu"
import ui "alicorn:ui"
import palette "alikit:command_palette"
import model "alikit:palette_model"

SAMPLE_ITEMS :: [4]model.Item{
	{ id=model.Item_ID(1), title="Open File", description="Browse the workspace", keywords="file browse" },
	{ id=model.Item_ID(2), title="Search in Files", description="Find text across the workspace", keywords="find grep" },
	{ id=model.Item_ID(3), title="Build Project", description="Run the configured build", keywords="compile" },
	{ id=model.Item_ID(4), title="Publish Release", description="Unavailable in this example", keywords="ship", disabled=true },
}

// Example application-owned appearance values. A real application can build
// this from its own theme or leave Appearance disabled to use Alicorn defaults.
EXAMPLE_PALETTE_APPEARANCE :: palette.Appearance{
	enabled=true,
	overlay_padding=40,
	panel_padding=16,
	panel_gap=10,
	backdrop_color=alicorn.Color{0.025, 0.035, 0.055, 0.68},
	panel_shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=10},
	panel_material=alicorn.MATERIAL_FLAT,
	physical_height=0,
	panel_fill=alicorn.Color{0.12, 0.14, 0.18, 1},
	backdrop_effect=alicorn.BACKDROP_NONE,
}

App :: struct {
	palette:    palette.State,
	items:      [4]model.Item,
	last_action: model.Item_ID,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	_ = ui.text(ctx, "AliKit · Command Palette", size=24)
	_ = ui.text(ctx, "Press the host command-palette shortcut to open it.")
	if app.last_action != 0 {
		_ = ui.text(ctx, fmt.tprintf("Last activated item ID: %d", model.item_id_value(app.last_action)))
	}

	if app.palette.open {
		event := palette.build(ctx, &app.palette, app.items[:],
			alicorn.key_string("alikit-example-palette"),
			palette.Options{
				title="Example Actions",
				query_accessible_name="Search example actions",
				appearance=EXAMPLE_PALETTE_APPEARANCE,
			})
		if event.kind == .Activated { app.last_action = event.item_id }
	}
}

on_key :: proc(app: ^App, rt: ^alicorn.Runtime, key: host.Application_Key) -> bool {
	if !app.palette.open && key == .Open_Command_Palette {
		_ = palette.open_palette(&app.palette, rt)
		return true
	}
	return false
}

main :: proc() {
	app := App{items=SAMPLE_ITEMS}
	if !palette.init(&app.palette) {
		fmt.eprintln("Could not initialize the command palette state.")
		return
	}
	defer palette.destroy(&app.palette)
	ui.run(&app, render, title="AliKit Command Palette", width=760, height=520, on_key=on_key)
}
