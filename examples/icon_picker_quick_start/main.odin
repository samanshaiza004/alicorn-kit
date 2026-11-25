package main

// A compact, inline Icon Picker consumer. The caller owns the choices and
// accepts the stable-key activation; the stock composite owns its behavior.

import ui "alicorn:ui"
import picker "alikit:icon_picker"

CHOICES := [8]picker.Choice{
	{key=1, label="Home", icon=.Folder_Closed, detail="Workspace home"},
	{key=2, label="Search", icon=.Search, detail="Find files"},
	{key=3, label="Settings", icon=.Settings, detail="Preferences"},
	{key=4, label="Save", icon=.Check, detail="Save document"},
	{key=5, label="Info", icon=.Info, detail="More information"},
	{key=6, label="Terminal", icon=.Terminal, detail="Open a shell"},
	{key=7, label="File", icon=.File, detail="Document"},
	{key=8, label="Next", icon=.Chevron_Right, detail="Continue"},
}

App :: struct {
	state: picker.State,
}

selected_label :: proc(app: ^App) -> string {
	for choice in CHOICES {
		if choice.key == app.state.selected_key { return choice.label }
	}
	return "None"
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=ui.key_string("quick-start-root"), width=-1,
		height=-1, padding=24, gap=12) {
		_ = ui.text(ctx, "Choose an icon", size=24)
		_ = ui.text(ctx, "Search or use the arrow keys, then press Enter.", size=14)
		event := picker.picker(ctx, &app.state, CHOICES[:],
			picker.Options{accessible_label="Available icons", columns=4,
				max_visible_rows=2},
			key=ui.key_string("quick-start-picker"), instance_id=1)
		if event.kind == .Activated {
			app.state.selected_key = event.key
		}
		_ = ui.text(ctx, "Selected icon", size=12)
		_ = ui.text(ctx, selected_label(app), size=13)
	}
}

main :: proc() {
	app := App{}
	if !picker.init(&app.state) { return }
	defer picker.destroy(&app.state)
	app.state.selected_key = 1
	ui.run(&app, render, title="Icon Picker Quick Start",
		width=560, height=520)
}
