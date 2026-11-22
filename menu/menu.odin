package menu

// Menu is a reusable, anchored, component-level dropdown menu. It composes a
// trigger, an overlay popup, `Menu`/`Menu_Item` semantics, single-level items
// (label, shortcut, checked, disabled, separator), roving Up/Down/Home/End
// navigation, Escape and outside-click dismissal, and focus restoration to the
// trigger.
//
// It is intentionally distinct from Alicorn's runtime context menu:
// `alicorn.context_menu_*` remains the native-integration path (application
// target, runtime-owned popup state, native menu commands). This package is the
// in-app composition path with caller-owned state and parts. Submenus are not
// implemented; nest a second `State` when that behavior is needed, or wait for
// a recorded component extension.
//
// The popup is described through `popup_begin`/`item`/`popup_end` in the host's
// `render_overlays` hook after the ordinary root closes.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import tc "alikit:theme_contract"

MENU_NAMESPACE :: u64(0x4D454E554D454E01) // "MENUMEN"
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)
MAX_ITEMS :: 128
ITEM_KEY :: u64(0xA11C_6D01)

Item_Kind :: enum { Item, Separator }

Item :: struct {
	// key is the stable application command identity. It must be nonzero and
	// unique for actionable items.
	key:      u64,
	label:    string,
	detail:   string,
	shortcut: string,
	kind:     Item_Kind,
	disabled: bool,
	checked:  bool,
}

Options :: struct {
	accessible_label: string,
	popup_width:      f32,
	item_height:      f32,
	padding:          f32,
	// max_visible_items bounds the popup; extra rows scroll inside it.
	max_visible_items: int,
	placement_margin:  f32,
	// keep_open_on_select leaves the menu open after activation. The default
	// closes and restores trigger focus.
	keep_open_on_select: bool,
}

DEFAULT_OPTIONS :: Options{
	accessible_label="Menu",
	popup_width=240,
	item_height=32,
	padding=6,
	max_visible_items=10,
	placement_margin=8,
}

Recipe :: struct {
	panel_surface_role:   alicorn.Style_Extension_Color_Role_ID,
	item_surface_role:    alicorn.Style_Extension_Color_Role_ID,
	active_surface_role:  alicorn.Style_Extension_Color_Role_ID,
	check_color:          alicorn.Style_Color_Role,
}

Style :: struct {
	corner_radius: f32,
	focus_width:   f32,
	check_slot:    f32,
}

DEFAULT_STYLE :: Style{corner_radius=10, focus_width=2, check_slot=18}

Theme_Contract :: tc.Contract
Theme_Contract_Report :: tc.Report

State :: struct {
	open:          bool,
	trigger_node:  alicorn.Node_ID,
	anchor:        alicorn.Rect,
	viewport:      alicorn.Rect,

	overlay_node:  alicorn.Node_ID,
	panel_node:    alicorn.Node_ID,
	panel_bounds:  alicorn.Rect,
	row_scroll:    alicorn.Node_ID,
	key_scope_open: bool,
	row_viewport:  f32,
	row_content:   f32,

	active_key:    u64,
	active_index:  int,
	instance_id:   u64,

	focus_pending:          bool,
	restore_pending:        bool,
	after_frame_registered: bool,

	chosen_key: u64,
}

recipe_default :: proc() -> Recipe { return {} }
style_default :: proc() -> Style { return DEFAULT_STYLE }

theme_contract_default :: proc(recipe: Recipe) -> Theme_Contract {
	contract: Theme_Contract
	_ = role_requirement(&contract, recipe.panel_surface_role, "alikit.menu.panel_surface")
	_ = role_requirement(&contract, recipe.item_surface_role, "alikit.menu.item_surface")
	_ = role_requirement(&contract, recipe.active_surface_role, "alikit.menu.active_surface")
	return contract
}

@(private)
role_requirement :: proc(contract: ^Theme_Contract, role: alicorn.Style_Extension_Color_Role_ID, name: string) -> bool {
	if role == 0 { return tc.optional_role(contract, 0, name) }
	return tc.required_role(contract, role, name)
}

theme_contract_check :: proc(rt: ^alicorn.Runtime, theme: alicorn.Style_Theme_ID, contract: Theme_Contract) -> Theme_Contract_Report {
	return tc.check(rt, theme, contract)
}

theme_contract_satisfied :: proc(report: Theme_Contract_Report) -> bool {
	return tc.satisfied(report)
}

theme_contract_missing_required :: proc(contract: Theme_Contract, report: Theme_Contract_Report) -> (names: [tc.MAX_ROLES]string, count: int) {
	search := 0
	for count < len(names) {
		name, index, found := tc.missing_name(contract, report, search)
		if !found { break }
		names[count] = name
		count += 1
		search = index+1
	}
	return
}

@(private)
mix :: proc(seed, value: u64) -> u64 {
	state := seed+value+0x9E3779B97F4A7C15
	state = (state ~ (state>>30))*0xBF58476D1CE4E5B9
	state = (state ~ (state>>27))*0x94D049BB133111EB
	return state ~ (state>>31)
}

menu_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=MENU_NAMESPACE, value=mix(instance_id, 0x4D454E55)}
}

item_semantic_id :: proc(instance_id, key: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=MENU_NAMESPACE, value=mix(instance_id, key)}
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.accessible_label == "" { result.accessible_label = DEFAULT_OPTIONS.accessible_label }
	if result.popup_width <= 0 || math.is_nan(result.popup_width) || math.is_inf(result.popup_width) {
		result.popup_width = DEFAULT_OPTIONS.popup_width
	}
	if result.item_height <= 0 || math.is_nan(result.item_height) || math.is_inf(result.item_height) {
		result.item_height = DEFAULT_OPTIONS.item_height
	}
	if result.padding < 0 || math.is_nan(result.padding) || math.is_inf(result.padding) {
		result.padding = DEFAULT_OPTIONS.padding
	}
	if result.max_visible_items <= 0 { result.max_visible_items = DEFAULT_OPTIONS.max_visible_items }
	if result.placement_margin < 0 || math.is_nan(result.placement_margin) || math.is_inf(result.placement_margin) {
		result.placement_margin = DEFAULT_OPTIONS.placement_margin
	}
	return result
}

@(private)
style_resolve :: proc(style: Style) -> Style {
	result := style
	if result.corner_radius < 0 || math.is_nan(result.corner_radius) || math.is_inf(result.corner_radius) {
		result.corner_radius = DEFAULT_STYLE.corner_radius
	}
	if result.focus_width <= 0 || math.is_nan(result.focus_width) || math.is_inf(result.focus_width) {
		result.focus_width = DEFAULT_STYLE.focus_width
	}
	if result.check_slot <= 0 || math.is_nan(result.check_slot) || math.is_inf(result.check_slot) {
		result.check_slot = DEFAULT_STYLE.check_slot
	}
	return result
}

@(private)
item_enabled :: proc(items: []Item, index: int) -> bool {
	if index < 0 || index >= len(items) { return false }
	item := items[index]
	return item.kind == .Item && item.key != 0 && !item.disabled
}

@(private)
first_enabled :: proc(items: []Item) -> int {
	for item, index in items {
		if item_enabled(items, index) { return index }
	}
	return -1
}

@(private)
last_enabled :: proc(items: []Item) -> int {
	for index := len(items)-1; index >= 0; index -= 1 {
		if item_enabled(items, index) { return index }
	}
	return -1
}

@(private)
step_enabled :: proc(items: []Item, from, delta: int) -> int {
	index := from
	for _ in 0..<len(items) {
		index += delta
		if index < 0 { index = len(items)-1 }
		if index >= len(items) { index = 0 }
		if item_enabled(items, index) { return index }
	}
	return -1
}

@(private)
index_of_key :: proc(items: []Item, key: u64) -> int {
	if key == 0 { return -1 }
	for item, index in items {
		if item.key == key { return index }
	}
	return -1
}

@(private)
set_active :: proc(state: ^State, items: []Item, index: int) {
	if state == nil || index < 0 || index >= len(items) { return }
	state.active_index = index
	state.active_key = items[index].key
}

@(private)
reconcile_active :: proc(state: ^State, items: []Item) {
	index := index_of_key(items, state.active_key)
	if index >= 0 && item_enabled(items, index) {
		state.active_index = index
		return
	}
	index = first_enabled(items)
	if index >= 0 { set_active(state, items, index) }
}

// open_from_node opens the menu anchored to an existing retained trigger.
// Applications with a custom trigger use this instead of the stock `trigger`.
open_from_node :: proc(state: ^State, rt: ^alicorn.Runtime, trigger_node: alicorn.Node_ID) -> bool {
	if state == nil || rt == nil || trigger_node == 0 { return false }
	info, ok := alicorn.node_info(rt, trigger_node)
	if !ok { return false }
	state.trigger_node = trigger_node
	state.anchor = info.bounds
	state.viewport = alicorn.viewport_bounds(rt)
	state.open = true
	state.focus_pending = true
	return true
}

close :: proc(state: ^State) {
	if state == nil { return }
	if state.open { state.restore_pending = true }
	state.open = false
}

@(private)
choose :: proc(state: ^State, items: []Item, index: int, options: Options) {
	if state == nil || index < 0 || index >= len(items) || !item_enabled(items, index) { return }
	state.chosen_key = items[index].key
	if !options.keep_open_on_select { close(state) }
}

@(private)
schedule_after_frame :: proc(ctx: ^ui.UI, state: ^State) {
	if ctx == nil || ctx.runtime == nil || state == nil || state.after_frame_registered { return }
	if ui.after_frame(ctx, state, menu_after_frame) { state.after_frame_registered = true }
}

@(private)
menu_after_frame :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	state := cast(^State)data
	if state == nil || rt == nil { return }
	state.after_frame_registered = false
	if state.focus_pending && state.panel_node != 0 {
		if alicorn.focus(rt, state.panel_node) {
			state.focus_pending = false
			alicorn.focus_indicator_set(rt, true)
		}
	}
	if state.restore_pending && !state.open && state.trigger_node != 0 {
		if alicorn.focus(rt, state.trigger_node) {
			state.restore_pending = false
			alicorn.focus_indicator_set(rt, true)
		}
	}
	if state.focus_pending || state.restore_pending { schedule_after_frame_node(state, rt) }
}

@(private)
schedule_after_frame_node :: proc(state: ^State, rt: ^alicorn.Runtime) {
	if state == nil || rt == nil || state.after_frame_registered { return }
	if alicorn.interaction_after_frame_register(rt, rawptr(state), menu_after_frame) {
		state.after_frame_registered = true
	}
}

// trigger describes the stock menu trigger. It returns true when the
// application should let the menu open (the component opens its own state).
// For a custom trigger, call open_from_node with the retained trigger node.
trigger :: proc(
	ctx: ^ui.UI,
	state: ^State,
	label: string,
	options: Options = {},
	key: ui.UI_Key,
	recipe: Recipe = {},
	style: Style = {},
) -> bool {
	if ctx == nil || ctx.runtime == nil || state == nil { return false }
	resolved := options_resolve(options)
	resolved_style := style_resolve(style)
	owner, activated := alicorn.button_begin(
		ctx,
		label,
		key=key,
		style=ui.layout_style(.Row, height=resolved.item_height+8),
		state=alicorn.Button_State{selected=state.open},
		variant=.Quiet,
	)
	if owner == 0 { return false }
	states := alicorn.Semantic_States{}
	actions := alicorn.Semantic_Actions{.Press}
	if state.open {
		states = alicorn.semantic_states_add(states, .Expanded)
		actions = alicorn.semantic_actions_add(actions, .Collapse)
	} else {
		actions = alicorn.semantic_actions_add(actions, .Expand)
	}
	_ = alicorn.semantic_augment(ctx, states_add=states, actions_add=actions)
	_ = resolved_style
	alicorn.button_end(ctx)
	if activated {
		if state.open {
			close(state)
		} else {
			_ = open_from_node(state, ctx.runtime, owner)
		}
	}
	return activated
}

@(private)
begin_surface :: proc(
	ctx: ^ui.UI,
	role: alicorn.Style_Extension_Color_Role_ID,
	fallback: alicorn.Style_Color_Role,
	key: ui.UI_Key,
	layout: alicorn.Layout_Style,
	shape: alicorn.Surface_Shape,
	stroke: alicorn.Paint_Stroke,
	label: string,
) -> alicorn.Node_ID {
	if role != 0 {
		if id := alicorn.surface_begin(ctx, alicorn.surface_extension_color_role(role),
			key=key, style=layout, shape=shape, stroke=stroke, label=label); id != 0 {
			return id
		}
	}
	return alicorn.surface_begin(ctx, alicorn.surface_core_color_role(fallback),
		key=key, style=layout, shape=shape, stroke=stroke, label=label)
}

@(private)
content_height :: proc(items: []Item, options: Options) -> f32 {
	return f32(len(items))*options.item_height+2*options.padding
}

// popup_begin describes the anchored popup. Call it from render_overlays after
// the ordinary root closes, then emit `item` parts and call `popup_end`. The
// returned chosen key is nonzero when keyboard activation (Return/Space)
// selected an item during this description.
popup_begin :: proc(
	ctx: ^ui.UI,
	state: ^State,
	items: []Item,
	options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
	recipe: Recipe = {},
	style: Style = {},
) -> (visible: bool, chosen_key: u64) {
	if ctx == nil || ctx.runtime == nil || state == nil || !state.open ||
	   instance_id == 0 || instance_id > MAX_INSTANCE_ID || len(items) == 0 || len(items) > MAX_ITEMS {
		return
	}
	resolved := options_resolve(options)
	resolved_style := style_resolve(style)
	rt := ctx.runtime
	if state.instance_id != instance_id {
		state.active_key = 0
		state.active_index = 0
		state.overlay_node = 0
		state.panel_node = 0
		state.row_scroll = 0
	}
	state.instance_id = instance_id

	if state.overlay_node != 0 {
		for {
			event, found := alicorn.interaction_event_next(rt, state.overlay_node)
			if !found { break }
			if event.kind == .Pointer {
				pointer := event.pointer
				if pointer.kind == .Down {
					b := state.panel_bounds
					inside := pointer.x >= b.x && pointer.y >= b.y &&
						pointer.x <= b.x+b.w && pointer.y <= b.y+b.h
					if !inside { close(state); break }
				}
				continue
			}
			if event.kind != .Key { continue }
			#partial switch event.key {
			case .Escape:
				close(state)
			case .Return, .Toggle:
				choose(state, items, state.active_index, resolved)
			case .Up:
				if index := step_enabled(items, state.active_index, -1); index >= 0 { set_active(state, items, index) }
			case .Down:
				if index := step_enabled(items, state.active_index, 1); index >= 0 { set_active(state, items, index) }
			case .Home:
				index := first_enabled(items); if index >= 0 { set_active(state, items, index) }
			case .End:
				index := last_enabled(items); if index >= 0 { set_active(state, items, index) }
			}
			if !state.open { break }
		}
	}

	if !state.open {
		if state.chosen_key != 0 { chosen_key = state.chosen_key; state.chosen_key = 0 }
		schedule_after_frame(ctx, state)
		return
	}
	reconcile_active(state, items)

	viewport := rt.viewport
	if viewport.w <= 0 || viewport.h <= 0 { viewport = state.viewport }
	state.viewport = viewport
	panel_height := content_height(items, resolved)
	max_height := f32(resolved.max_visible_items)*resolved.item_height+2*resolved.padding
	panel_height = min(panel_height, max_height)
	panel_height = min(panel_height, max(viewport.h-2*resolved.placement_margin, resolved.item_height))
	placement := alicorn.context_menu_placement(viewport, state.anchor, resolved.popup_width,
		panel_height, resolved.placement_margin)
	if placement.w <= 0 || placement.h <= 0 { close(state); return }

	// Keep the keyboard-active row visible. The offset is applied to the
	// previous region before the replacement is described; the new region
	// reuses it during reconciliation.
	inner_height := max(placement.h-2*resolved.padding, 0)
	if state.row_scroll != 0 && state.active_index >= 0 {
		row_top := f32(state.active_index)*resolved.item_height
		offset := alicorn.scroll_region_offset(rt, state.row_scroll)
		if row_top < offset {
			_ = alicorn.scroll_region_set_offset(rt, state.row_scroll, row_top, "menu active item reveal")
		} else if row_top+resolved.item_height > offset+inner_height {
			_ = alicorn.scroll_region_set_offset(rt, state.row_scroll,
				row_top+resolved.item_height-inner_height, "menu active item reveal")
		}
	}

	if !ui.key_scope(ctx, key) { close(state); return }
	state.key_scope_open = true

	state.overlay_node = alicorn.modal_overlay_begin(
		ctx,
		key=ui.key_pair(instance_id, 0x4D454E55),
		style=ui.layout_style(.Column, width=-1, height=-1),
		backdrop_color=alicorn.Color{0, 0, 0, 0},
	)
	if state.overlay_node == 0 {
		close(state)
		alicorn.key_scope_end(ctx)
		state.key_scope_open = false
		return
	}
	keys := alicorn.Interaction_Key_Set{.Up, .Down, .Home, .End, .Escape, .Return, .Toggle}
	_ = ui.interaction_scope(ctx, state.overlay_node, state, alicorn.Interaction_Scope_Options{
		keys=keys,
		composition_yield_keys=keys,
		pointers={.Primary_Down},
		modal=true,
	})
	top := placement.y
	if top > 0 {
		spacer := alicorn.container_begin(ctx, .Container, label="menu-y-spacer",
			key=ui.key_u64(0xA11C_6D10), style=ui.layout_style(.Row, width=-1, height=top))
		if spacer != 0 { alicorn.container_end(ctx) }
	}
	state.panel_node = 0
	state.panel_bounds = placement
	placement_row := alicorn.container_begin(
		ctx,
		.Container,
		label="menu-placement-row",
		key=ui.key_u64(0xA11C_6D11),
		style=ui.layout_style(.Row, width=-1, height=placement.h, align=.Start),
	)
	if placement_row != 0 {
		if placement.x > 0 {
			x_spacer := alicorn.container_begin(ctx, .Container, label="menu-x-spacer",
				key=ui.key_u64(0xA11C_6D12),
				style=ui.layout_style(.Column, width=placement.x, height=placement.h))
			if x_spacer != 0 { alicorn.container_end(ctx) }
		}
		panel := begin_surface(
			ctx,
			recipe.panel_surface_role,
			.Surface,
			key=ui.key_pair(instance_id, 0x50414E454C),
			layout=ui.layout_style(.Column, width=placement.w, height=placement.h, padding=resolved.padding),
			shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=resolved_style.corner_radius},
			stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Border), width=resolved_style.focus_width},
			label="menu-popup",
		)
		if panel != 0 {
			rows := alicorn.container_begin(
				ctx,
				.Container,
				label="menu-rows-owner",
				key=ui.key_pair(instance_id, 0x524F5750),
				style=ui.layout_style(.Column, width=-1, height=-1),
				focusable=true,
			)
			if rows != 0 {
				state.panel_node = rows
				// Alicorn's semantic_collection_begin does not accept .Menu at
				// the pinned revision, so the menu publishes a flat Menu group
				// with Menu_Item children instead of a composite collection.
				_ = alicorn.semantic_description(ctx, .Menu, resolved.accessible_label,
					description="Menu")
				_ = alicorn.semantic_bind(ctx, menu_semantic_id(instance_id))
				region := alicorn.scroll_region_begin(
					ctx,
					key=ui.key_pair(instance_id, 0x524F5753),
					viewport_height=inner_height,
					content_height=f32(len(items))*resolved.item_height,
					line_height=resolved.item_height,
					style=ui.layout_style(.Column, width=-1, height=inner_height, clip=true),
					label="menu-rows",
					axes=.Vertical,
					scrollbars=.Hidden,
					focusable=false,
				)
				state.row_scroll = region.id
				state.row_viewport = region.viewport_height
				state.row_content = region.content_height
				state.chosen_key = 0
				schedule_after_frame(ctx, state)
				return true, 0
			}
			alicorn.surface_end(ctx)
		}
	}
	if placement_row != 0 { alicorn.container_end(ctx) }
	alicorn.modal_overlay_end(ctx)
	state.overlay_node = 0
	state.panel_node = 0
	if state.key_scope_open {
		alicorn.key_scope_end(ctx)
		state.key_scope_open = false
	}
	return true, 0
}

// item describes one menu row. Separators are visual rows and publish no
// actionable item. Returns true when pointer or semantic activation selected
// the row; keyboard activation is reported by popup_begin's chosen_key.
item :: proc(
	ctx: ^ui.UI,
	state: ^State,
	value: Item,
	index: int,
	options: Options = {},
	recipe: Recipe = {},
	style: Style = {},
) -> bool {
	if ctx == nil || ctx.runtime == nil || state == nil || index < 0 { return false }
	resolved := options_resolve(options)
	resolved_style := style_resolve(style)
	if value.kind == .Separator {
		if ui.row(ctx, key=ui.key_u64(0xA11C_6D20+u64(index)), width=-1,
			height=resolved.item_height, align=.Center, label="menu-separator-row") {
			_ = alicorn.surface_begin(
				ctx,
				alicorn.surface_core_color_role(.Border),
				key=ui.key_u64(0xA11C_6D21+u64(index)),
				style=ui.layout_style(.Row, width=-1, height=1),
				label="menu-separator",
			)
			alicorn.surface_end(ctx)
		}
		return false
	}
	selected := state.active_index == index
	owner, activated := alicorn.button_begin(
		ctx,
		value.label,
		key=ui.key_pair(ITEM_KEY, value.key),
		style=ui.layout_style(.Row, width=-1, height=resolved.item_height),
		state=alicorn.Button_State{selected=selected, disabled=value.disabled},
		presentation=.Custom,
		focusable=false,
	)
	if owner == 0 { return false }
	states := alicorn.Semantic_States{}
	actions := alicorn.Semantic_Actions{}
	if value.disabled {
		states = alicorn.semantic_states_add(states, .Disabled)
	} else {
		actions = alicorn.semantic_actions_add(actions, .Focus)
		actions = alicorn.semantic_actions_add(actions, .Select)
		actions = alicorn.semantic_actions_add(actions, .Press)
	}
	if value.checked { states = alicorn.semantic_states_add(states, .Checked) }
	if selected { states = alicorn.semantic_states_add(states, .Current) }
	_ = alicorn.semantic_description(ctx, .Menu_Item, value.label,
		description=value.detail, value=value.label, states=states, actions=actions)
	_ = alicorn.semantic_bind(ctx, item_semantic_id(state.instance_id, value.key))

	fill_role := recipe.item_surface_role
	fallback := alicorn.Style_Color_Role.Surface
	if selected { fill_role = recipe.active_surface_role; fallback = .Selection }
	row := begin_surface(
		ctx,
		fill_role,
		fallback,
		key=ui.key_pair(ITEM_KEY+1, value.key),
		layout=ui.layout_style(.Row, width=-1, height=-1, padding=6, gap=8, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=max(resolved_style.corner_radius-3, 2)},
		stroke={},
		label="menu-item-surface",
	)
	if row == 0 { alicorn.button_end(ctx); return false }
	_ = alicorn.visual_part_attach(ctx, row, owner, alicorn.visual_part_core(.Surface))
	check_color := recipe.check_color
	if check_color == .Text { check_color = .Accent }
	check := ui.text(ctx, "\u2713" if value.checked else "", key=ui.key_pair(ITEM_KEY+2, value.key),
		style=ui.layout_style(.Row, width=resolved_style.check_slot),
		size=0, color=alicorn.style_color(ctx, check_color), decorative=true)
	if check != 0 { _ = alicorn.visual_part_attach(ctx, check, owner, alicorn.visual_part_core(.Indicator)) }
	label := ui.text(ctx, value.label, key=ui.key_pair(ITEM_KEY+3, value.key),
		style=ui.layout_style(.Row, grow=1),
		size=0, decorative=true,
		color=alicorn.style_color(ctx, .Muted_Text if value.disabled else .Text))
	if label != 0 { _ = alicorn.visual_part_attach(ctx, label, owner, alicorn.visual_part_core(.Label)) }
	if value.shortcut != "" {
		shortcut := ui.text(ctx, value.shortcut, key=ui.key_pair(ITEM_KEY+4, value.key),
			size=11, color=alicorn.style_color(ctx, .Muted_Text), decorative=true)
		if shortcut != 0 { _ = alicorn.visual_part_attach(ctx, shortcut, owner, alicorn.visual_part_core(.Content)) }
	}
	alicorn.surface_end(ctx)
	alicorn.button_end(ctx)

	if activated && !value.disabled {
		state.chosen_key = value.key
		if !resolved.keep_open_on_select { close(state) }
		return true
	}
	return false
}

// take_chosen consumes the pending chosen key. Applications that dispatch from
// popup_begin's return value can ignore this helper.
take_chosen :: proc(state: ^State) -> (key: u64, found: bool) {
	if state == nil || state.chosen_key == 0 { return }
	key = state.chosen_key
	state.chosen_key = 0
	return key, true
}

popup_end :: proc(ctx: ^ui.UI, state: ^State) {
	if ctx == nil || ctx.runtime == nil { return }
	alicorn.scroll_region_end(ctx)
	alicorn.container_end(ctx)
	alicorn.surface_end(ctx)
	alicorn.container_end(ctx)
	alicorn.modal_overlay_end(ctx)
	if state != nil {
		if state.key_scope_open {
			alicorn.key_scope_end(ctx)
			state.key_scope_open = false
		}
	}
}
