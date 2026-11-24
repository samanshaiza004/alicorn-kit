package main

import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import radio "alikit:radio_group"
import segmented "alikit:segmented"

Treatment :: enum { Minimal, Hardware, Paper }
Marker :: enum { Bar, Dot, Underline }

// A closed vocabulary for this pilot. Layout is measured in logical units.
// The marker's dimensions never set the Button owner's hit target.
Item_Style :: struct {
	height, gap, inset: f32,
	font:               alicorn.Font_Role,
	text:               alicorn.Text_Style,
	fill, selected_fill: alicorn.Color,
	ink, disabled_ink:  alicorn.Color,
	mark_ink, focus_ink: alicorn.Color,
	stroke:             alicorn.Paint_Stroke,
	radius:             f32,
	material:           alicorn.Material_ID,
	optical_height:     f32,
	marker:             Marker,
}

style_for :: proc(treatment: Treatment, relief: alicorn.Material_ID) -> Item_Style {
	switch treatment {
	case .Minimal:
		return {
			height=44, gap=2, inset=0,
			text={font_size=14, font_weight=400, overflow=.Ellipsis},
			fill=ui.rgb(0x202933), selected_fill=ui.rgb(0x283646),
			ink=ui.rgb(0xF2F6FA), disabled_ink=ui.rgb(0xA8B0B9),
			mark_ink=ui.rgb(0xA6DFFF), focus_ink=ui.rgb(0xFFF1AD),
			radius=3, marker=.Bar,
		}
	case .Hardware:
		return {
			height=66, gap=4, inset=4, font=.Monospace,
			text={font_size=15, font_weight=700, overflow=.Ellipsis},
			fill=ui.rgb(0x263138), selected_fill=ui.rgb(0x394C55),
			ink=ui.rgb(0xF2F6FA), disabled_ink=ui.rgb(0xA8B0B9),
			mark_ink=ui.rgb(0xA6DFFF), focus_ink=ui.rgb(0xFFF1AD),
			stroke={color=ui.rgb(0x677882), width=1},
			radius=9, material=relief, optical_height=1, marker=.Dot,
		}
	case .Paper:
		return {
			height=56, gap=7, inset=2,
			text={font_size=18, font_weight=500, overflow=.Ellipsis},
			fill=ui.rgb(0xEEE5CE), selected_fill=ui.rgb(0xFFF7E7),
			ink=ui.rgb(0x262520), disabled_ink=ui.rgb(0x665D51),
			mark_ink=ui.rgb(0x703C25), focus_ink=ui.rgb(0x4B3A87),
			stroke={color=ui.rgb(0xB3A68C), width=1},
			radius=1, marker=.Underline,
		}
	}
	return {}
}

draw_item :: proc(
	ctx: ^ui.UI, owner: alicorn.Node_ID, label: string, selected, disabled, focused: bool,
	width, height: f32, style: Item_Style,
) {
	fill := style.selected_fill if selected else style.fill
	ink := style.disabled_ink if disabled else style.ink
	stroke := style.stroke
	if focused { stroke = {color=style.focus_ink, width=2} }
	face := alicorn.surface_begin(
		ctx, alicorn.surface_core_color_role(.Surface), key=ui.key_u64(1),
		style=ui.layout_style(.Column, width=max(width-2*style.inset, 0),
			height=max(height-2*style.inset, 0), padding=4, gap=style.gap,
			align=.Center, justify=.Center, clip=true),
		shape={kind=.Rounded_Rectangle, corner_radius=style.radius},
		fill=fill, stroke=stroke, material=style.material, physical_height=style.optical_height,
		label="selection-style-face",
	)
	if face == 0 { return }
	defer ui.surface_end(ctx)
	_ = alicorn.visual_part_attach(ctx, face, owner, alicorn.visual_part_core(.Surface))

	text := ui.text(ctx, label, key=ui.key_u64(2), color=ink, font=style.font,
		text_style=style.text, decorative=true)
	if text != 0 {
		// The core Label part inherits ink from the Button recipe. This part
		// keeps the treatment's explicit ink while the owner keeps the name.
		_ = alicorn.visual_part_attach(ctx, text, owner,
			alicorn.visual_part_extension_id("alikit.selection_styles", "label"))
	}

	// Keep the marker's space stable when selection moves.
	marker_width, marker_height, radius: f32
	switch style.marker {
	case .Bar:       marker_width, marker_height, radius = 14, 3, 1
	case .Dot:       marker_width, marker_height, radius = 8, 8, 4
	case .Underline: marker_width, marker_height, radius = 42, 2, 0
	}
	if ui.row(ctx, key=ui.key_u64(3), width=marker_width, height=marker_height, align=.Center) {
		if selected {
			marker := ui.box(ctx, key=ui.key_u64(4), width=marker_width, height=marker_height,
				radius=radius, fill=style.mark_ink)
			if marker != 0 {
				_ = alicorn.visual_part_attach(ctx, marker, owner,
					alicorn.visual_part_extension_id("alikit.selection_styles", "selection-marker"))
			}
		}
	}
}

draw_segment :: proc(data: rawptr, ctx: ^ui.UI, visual: segmented.Item_Visual) {
	draw_item(ctx, visual.owner, visual.item.label, visual.selected, visual.item.disabled,
		visual.group_focused && visual.active, visual.width, visual.height, (^Item_Style)(data)^)
}

RADIO_OPTIONS := [3]radio.Option{
	{value=1, label="Draft"}, {value=2, label="Review"}, {value=3, label="Published", disabled=true},
}
SEGMENTS := [3]segmented.Item{
	{value=1, label="Overview"}, {value=2, label="Activity"}, {value=3, label="Archive", disabled=true},
}

App :: struct {
	treatment:              Treatment,
	relief:                 alicorn.Material_ID,
	radio_state:            radio.State,
	segment_state:          segmented.State,
	radio_value, view_value: u64,
}

initialize :: proc(app: ^App, rt: ^alicorn.Runtime) {
	app.relief = alicorn.style_material_register(rt, {
		kind=.Analytic_Relief, bevel_width=2, bevel_strength=0.18,
	})
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, padding=24, gap=12) {
		ui.text(ctx, "Selection styles", size=24)
		if ui.row(ctx, gap=8) {
			names := [Treatment]string{.Minimal="Minimal", .Hardware="Hardware", .Paper="Paper"}
			for name, index in names {
				treatment := Treatment(index)
				if ui.button(ctx, name, key=ui.key_u64(u64(index)+1),
					state={selected=treatment == app.treatment}) {
					app.treatment = treatment
					alicorn.invalidate_root(ctx.runtime, "selection appearance changed")
				}
			}
		}
		style := style_for(app.treatment, app.relief)
		ui.text(ctx, "Radio Group", size=18)
		group, visible := radio.group_begin(ctx, &app.radio_state, RADIO_OPTIONS[:], app.radio_value,
			label="Publication status", key=ui.key_u64(11), instance_id=11,
			group_options={orientation=.Horizontal, item_gap=style.gap})
		if visible {
			for option in RADIO_OPTIONS {
				item, shown := radio.item_begin(ctx, &group, option,
					item_style=ui.layout_style(.Row, width=132, height=style.height,
						align=.Center, justify=.Center))
				if !shown { continue }
				draw_item(ctx, item.owner, option.label, item.checked, item.disabled,
					item.focus_visible, 132, style.height, style)
				radio.item_end(ctx, item)
			}
			if event := radio.group_end(ctx, &group); event.kind == .Selection_Proposed {
				app.radio_value = event.value
			}
		}
		ui.text(ctx, "Segmented Control", size=18)
		if event := segmented.control(ctx, &app.segment_state, SEGMENTS[:], app.view_value,
			options={accessible_label="Workspace view", width=412, height=style.height+8,
				padding=4, corner_radius=style.radius+2},
			key=ui.key_u64(22), instance_id=22,
			presentation={data=&style, draw_item=draw_segment, omit_moving_indicator=true});
			event.kind == .Selection_Proposed {
			app.view_value = event.value
		}
	}
}

main :: proc() {
	app := App{radio_value=1, view_value=1}
	smoke := false
	for arg in os.args {
		switch arg {
		case "--smoke":    smoke = true
		case "--hardware": app.treatment = .Hardware
		case "--paper":    app.treatment = .Paper
		}
	}
	ui.run(&app, render, title="AliKit Selection Styles", width=500, height=430,
		on_initialize=initialize, smoke=smoke)
}
