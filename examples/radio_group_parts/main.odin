package main

// Radio Group parts example: a radically different choice-card appearance built
// with the public radio parts. The component still owns Radio_Group /
// Radio_Button semantics, the one Tab stop, roving arrows, focus, checked
// state, and activation parity. This file owns the card layout, the picture,
// the price, the description, and the selected checkmark; it omits the default
// radio indicator entirely.
//
// Run:
//   odin run examples/radio_group_parts -collection:alicorn=/path/to/alicorn
//   ./out/radio_group_parts_example.exe --smoke

import "core:fmt"
import "core:os"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import radio "../../radio_group"

Plan :: struct {
	option:      radio.Option,
	price:       string,
	icon:        alicorn.Icon_ID,
	accent:      alicorn.Style_Color_Role,
}

PLANS := [3]Plan{
	{option=radio.Option{value=101, label="Field Notes", description="One notebook, every device"},
		price="$0", icon=.File, accent=.Accent},
	{option=radio.Option{value=102, label="Workshop", description="Shared spaces and review"},
		price="$12", icon=.Settings, accent=.Selection},
	{option=radio.Option{value=103, label="Atelier", description="Advanced controls and exports", disabled=true},
		price="$48", icon=.Terminal, accent=.Border},
}

App :: struct {
	state:    radio.State,
	plans:    [3]Plan,
	selected: u64,
	events:   int,
	smoke:    bool,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("parts-example-root"),
		width=-1, height=-1, padding=28, gap=14, align=.Center) {
		_ = ui.text(ctx, "Radio parts", size=26)
		_ = ui.text(ctx, "Custom choice cards. The default dot is gone; semantics, roving focus, and activation stay.",
			size=13, color=alicorn.style_color(ctx, .Muted_Text))
		if ui.column(ctx, key=alicorn.key_string("parts-example-card"),
			width=540, height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=20, gap=12) {
			group, visible := radio.group_begin(
				ctx,
				&app.state,
				plans_options(app),
				app.selected,
				label="Plan",
				key=alicorn.key_string("parts-example-plan"),
				instance_id=4301,
				group_options=radio.Options{
					orientation=.Vertical,
					item_height=104,
					item_min_width=500,
					item_padding=0,
					item_gap=10,
				},
				style=radio.Style{corner_radius=12, focus_width=2},
			)
			if visible {
				for plan in app.plans {
					item, item_visible := radio.item_begin(ctx, &group, plan.option)
					if !item_visible { continue }
					plan_card(ctx, plan, item)
					radio.item_end(ctx, item)
				}
				if event := radio.group_end(ctx, &group); event.kind == .Selection_Proposed {
					app.selected = event.value
					app.events += 1
				}
			}
			if ui.button(ctx, "Apply plan", key=alicorn.key_string("parts-example-apply"),
				width=140, height=34) {
				app.events += 1
			}
			_ = ui.text(ctx, fmt.tprintf("Selected plan %d", app.selected), size=13,
				color=alicorn.style_color(ctx, .Muted_Text))
		}
	}
}

plans_options :: proc(app: ^App) -> []radio.Option {
	options := make([]radio.Option, len(app.plans), context.temp_allocator)
	for plan, index in app.plans { options[index] = plan.option }
	return options
}

plan_card :: proc(ctx: ^ui.UI, plan: Plan, item: radio.Item) {
	fill := alicorn.surface_core_color_role(.Surface)
	if item.checked { fill = alicorn.surface_core_color_role(.Selection) }
	stroke := alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Border), width=1}
	if item.focus_visible {
		stroke = alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Focus), width=2}
	}
	if alicorn.surface_begin(
		ctx,
		fill,
		key=ui.key_u64(1),
		style=ui.layout_style(.Row, width=-1, height=-1, padding=14, gap=14, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=12},
		stroke=stroke,
		label="plan-card",
	) == 0 {
		return
	}
	// Picture part: a large rounded tile with an icon.
	if alicorn.surface_begin(
		ctx,
		alicorn.surface_core_color_role(plan.accent),
		key=ui.key_u64(2),
		style=ui.layout_style(.Row, width=56, height=56, align=.Center, justify=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=14},
		label="plan-picture",
	) != 0 {
		_ = ui.icon(ctx, plan.icon, key=ui.key_u64(3), size=26, color_role=.Text)
		alicorn.surface_end(ctx)
	}
	if ui.column(ctx, key=ui.key_u64(4), grow=1, gap=2) {
		_ = ui.text(ctx, plan.option.label, key=ui.key_u64(5), size=16)
		_ = ui.text(ctx, plan.option.description, key=ui.key_u64(6), size=12,
			color=alicorn.style_color(ctx, .Muted_Text))
	}
	if ui.column(ctx, key=ui.key_u64(7), width=80, gap=2, align=.End) {
		_ = ui.text(ctx, plan.price, key=ui.key_u64(8), size=16)
		if item.checked {
			_ = ui.icon(ctx, .Check, key=ui.key_u64(9), size=18, color_role=.Accent)
		} else if item.disabled {
			_ = ui.text(ctx, "Unavailable", key=ui.key_u64(10), size=11,
				color=alicorn.style_color(ctx, .Muted_Text))
		}
	}
	alicorn.surface_end(ctx)
}

stop :: proc(app: ^App) {
	if app.smoke {
		fmt.println("radio_group_parts_smoke", "selected", app.selected, "events", app.events, "idle", true)
	}
}

main :: proc() {
	smoke := false
	for argument in os.args {
		if argument == "--smoke" { smoke = true }
	}
	app := App{selected=101, smoke=smoke}
	app.plans = PLANS
	ui.run(
		&app,
		render,
		title="Alicorn - Radio Parts",
		width=720,
		height=620,
		on_stop=stop,
		smoke=smoke,
	)
}
