package menu

// Menu is a reusable, anchored, component-level dropdown menu. It is built from
// public parts: a trigger, an overlay popup, Menu_Item row owners, separators,
// optional ad-hoc Menu groups, and optional default row visuals.
//
// Authors can use the complete `item` helper or compose the parts:
//
//	visible, chosen := menu.popup_begin(ctx, &state, items, options, key, instance)
//	if visible {
//		for item, index in items {
//			row, row_visible := menu.item_begin(ctx, &state, item, index)
//			if row_visible {
//				menu.check(ctx, row)    // optional default check slot
//				menu.label(ctx, row)    // optional default label
//				menu.shortcut(ctx, row) // optional shortcut text
//				menu.item_end(ctx, row)
//			}
//		}
//		menu.popup_end(ctx, &state)
//	}
//
// Everything between item_begin and item_end belongs to the author: keep the
// default parts, omit them, or replace the inside of the Button owner with any
// ordinary Alicorn layout (label/detail/shortcut/checked or custom content).
// The parts retain Menu_Item semantics, checked/disabled/current publication,
// keyboard navigation, activation parity, Escape/outside dismissal, and focus
// restoration. The application still owns command identity and dispatch.
//
// It is intentionally distinct from Alicorn's runtime context menu:
// `alicorn.context_menu_*` remains the native-integration path (application
// target, runtime-owned popup state, native menu commands). This package is the
// in-app composition path with caller-owned state and parts.
//
// Submenus are not implemented in v1: the single popup, overlay, row scroll,
// and focus-restoration machinery is intentionally one level. Compose a second
// menu `State` anchored to a row when nested menus are required. The recorded
// `.Menu` collection gap is unchanged at the pinned revision; groups publish
// ad-hoc nested Menu semantics without a composite collection.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import sel "alikit:selection"
import tc "alikit:theme_contract"

MENU_NAMESPACE :: u64(0x4D454E554D454E01) // "MENUMEN"
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)
MAX_ITEMS :: 128
ITEM_KEY :: u64(0xA11C_6D01)
GROUP_KEY :: u64(0xA11C_6D30)

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

	// active is the shared single-selection/focus identity model. Menu rows
	// propose focus, not persistent selection; the checked state stays in the
	// application.
	using active: sel.State,

	instance_id:   u64,

	focus_pending:          bool,
	restore_pending:        bool,
	after_frame_registered: bool,

	// item_count is the number of logical rows in the most recent popup.
	item_count: int,

	chosen_key: u64,
}

// MenuItem is the per-description row context returned by item_begin. Its
// public fields expose the caller-owned item, stable position, checked /
// disabled / current state, and the Button owner.
MenuItem :: struct {
	state:     ^State,
	item:      Item,
	index:     int,
	count:     int,
	owner:     alicorn.Node_ID,
	selected:   bool,
	checked:    bool,
	disabled:   bool,
	keep_open:  bool,
	check_color: alicorn.Style_Color_Role,
	check_slot: f32,
	visible:    bool,
	activated:  bool,
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

group_semantic_id :: proc(instance_id, key: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=MENU_NAMESPACE, value=mix(instance_id, key ~ 0x475250)}
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
index_of_key :: proc(items: []Item, key: u64) -> int {
	if key == 0 { return -1 }
	for item, index in items {
		if item.key == key { return index }
	}
	return -1
}

@(private)
Selection_View :: struct {
	items: []Item,
}

@(private)
selection_key_at :: proc(data: rawptr, index: int) -> u64 {
	ctx := cast(^Selection_View)data
	if index < 0 || index >= len(ctx.items) { return 0 }
	if ctx.items[index].kind != .Item { return 0 }
	return ctx.items[index].key
}

@(private)
selection_enabled_at :: proc(data: rawptr, index: int) -> bool {
	ctx := cast(^Selection_View)data
	return item_enabled(ctx.items, index)
}

@(private)
selection_view :: proc(ctx: ^Selection_View, items: []Item) -> sel.View {
	ctx.items = items
	return sel.View{
		count=len(items),
		data=rawptr(ctx),
		key_at=selection_key_at,
		enabled_at=selection_enabled_at,
	}
}

@(private)
set_active :: proc(state: ^State, items: []Item, index: int) {
	if state == nil { return }
	ctx: Selection_View
	_ = sel.set_active(&state.active, selection_view(&ctx, items), index)
}

@(private)
reconcile_active :: proc(state: ^State, items: []Item) {
	if state == nil { return }
	ctx: Selection_View
	_ = sel.reconcile_active(&state.active, selection_view(&ctx, items), 0)
}

@(private)
first_enabled :: proc(items: []Item) -> int {
	ctx: Selection_View
	return sel.first_enabled(selection_view(&ctx, items))
}

@(private)
last_enabled :: proc(items: []Item) -> int {
	ctx: Selection_View
	return sel.last_enabled(selection_view(&ctx, items))
}

@(private)
step_enabled :: proc(items: []Item, from, delta: int) -> int {
	ctx: Selection_View
	return sel.move(selection_view(&ctx, items), from, delta, true)
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
// the ordinary root closes, then emit row parts and call popup_end. The
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
	state.item_count = len(items)

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
				style=ui.layout_style(.Column, width=-1, height=-1, grow=1),
				focusable=true,
			)
			if rows != 0 {
				state.panel_node = rows
				// Alicorn's semantic_collection_begin does not accept .Menu at
				// the pinned revision, so the menu publishes a flat Menu group
				// with Menu_Item children instead of a composite collection.
				// Groups add ad-hoc nested Menu semantics through group_begin.
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

// separator draws one visual separator row. It publishes no actionable item
// and does not participate in roving navigation.
separator :: proc(ctx: ^ui.UI, index: int, options: Options = {}) {
	if ctx == nil || ctx.runtime == nil || index < 0 { return }
	resolved := options_resolve(options)
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
}

// item_begin opens one row's Button owner and publishes its Menu_Item semantic
// item. It returns visible=false for an invalid state, a separator, an unknown
// or zero key, or a failed Button owner; in that case the author skips the
// visual subtree and must not call item_end. Use `separator` for separators.
//
// The default row visuals are `check`, `label`, `shortcut`, and `detail`.
// Call any subset of them, or draw a completely custom subtree inside the
// Button owner. The Button owner remains the semantic and hit owner.
item_begin :: proc(
	ctx: ^ui.UI,
	state: ^State,
	value: Item,
	index: int,
	options: Options = {},
	recipe: Recipe = {},
	style: Style = {},
) -> (row: MenuItem, visible: bool) {
	if ctx == nil || ctx.runtime == nil || state == nil || index < 0 { return }
	if value.kind == .Separator || value.key == 0 { return }
	resolved := options_resolve(options)
	resolved_style := style_resolve(style)
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
	if owner == 0 { return }

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

	check_color := recipe.check_color
	if check_color == .Text { check_color = .Accent }
	row = MenuItem{
		state=state,
		item=value,
		index=index,
		count=state.item_count,
		owner=owner,
		selected=selected,
		checked=value.checked,
		disabled=value.disabled,
		keep_open=resolved.keep_open_on_select,
		check_color=check_color,
		check_slot=resolved_style.check_slot,
		visible=true,
		activated=activated,
	}
	return row, true
}

// check draws the default check slot and checkmark. It is optional; omit it
// for a custom leading area and reuse `row.checked` in your own drawing.
check :: proc(ctx: ^ui.UI, row: MenuItem, style: Style = {}) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible { return 0 }
	resolved_style := style_resolve(style)
	check_color := row.check_color
	if check_color == .Text { check_color = .Accent }
	slot := row.check_slot
	if slot <= 0 { slot = resolved_style.check_slot }
	check := ui.text(ctx, "\u2713" if row.checked else "",
		key=ui.key_pair(ITEM_KEY+2, row.item.key),
		style=ui.layout_style(.Row, width=slot),
		size=0, color=alicorn.style_color(ctx, check_color), decorative=true)
	if check != 0 { _ = alicorn.visual_part_attach(ctx, check, row.owner, alicorn.visual_part_core(.Indicator)) }
	return check
}

// label draws the default label. Omit it for a custom title/detail layout.
label :: proc(ctx: ^ui.UI, row: MenuItem, text: string = "") -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible { return 0 }
	value := text
	if value == "" { value = row.item.label }
	label := ui.text(ctx, value, key=ui.key_pair(ITEM_KEY+3, row.item.key),
		style=ui.layout_style(.Row, grow=1),
		size=0, decorative=true,
		color=alicorn.style_color(ctx, .Muted_Text if row.disabled else .Text))
	if label != 0 { _ = alicorn.visual_part_attach(ctx, label, row.owner, alicorn.visual_part_core(.Label)) }
	return label
}

// shortcut draws the default shortcut hint. It is visual only; the semantic
// description continues to come from the application-owned item detail.
shortcut :: proc(ctx: ^ui.UI, row: MenuItem, text: string = "") -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible { return 0 }
	value := text
	if value == "" { value = row.item.shortcut }
	if value == "" { return 0 }
	shortcut := ui.text(ctx, value, key=ui.key_pair(ITEM_KEY+4, row.item.key),
		size=11, color=alicorn.style_color(ctx, .Muted_Text), decorative=true)
	if shortcut != 0 { _ = alicorn.visual_part_attach(ctx, shortcut, row.owner, alicorn.visual_part_core(.Content)) }
	return shortcut
}

// detail draws an optional secondary line. It is not part of the default row;
// it exists for custom menus that want to make the semantic detail visible.
detail :: proc(ctx: ^ui.UI, row: MenuItem, text: string = "") -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible { return 0 }
	value := text
	if value == "" { value = row.item.detail }
	if value == "" { return 0 }
	detail := ui.text(ctx, value, key=ui.key_pair(ITEM_KEY+5, row.item.key),
		size=11, color=alicorn.style_color(ctx, .Muted_Text), decorative=true,
		text_style=alicorn.Text_Style{overflow=.Ellipsis})
	if detail != 0 { _ = alicorn.visual_part_attach(ctx, detail, row.owner, alicorn.visual_part_core(.Content)) }
	return detail
}

// row_surface draws the default rounded row background and active fill. It is
// optional; custom rows may draw any surface composition. Close it with
// alicorn.surface_end after the row content.
row_surface :: proc(ctx: ^ui.UI, row: MenuItem, options: Options = {}, recipe: Recipe = {}, style: Style = {}) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible { return 0 }
	resolved := options_resolve(options)
	resolved_style := style_resolve(style)
	fill_role := recipe.item_surface_role
	fallback := alicorn.Style_Color_Role.Surface
	if row.selected { fill_role = recipe.active_surface_role; fallback = .Selection }
	surface := begin_surface(
		ctx,
		fill_role,
		fallback,
		key=ui.key_pair(ITEM_KEY+1, row.item.key),
		layout=ui.layout_style(.Row, width=-1, height=-1, grow=1, padding=6, gap=8, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle,
			corner_radius=max(resolved_style.corner_radius-3, 2)},
		stroke={},
		label="menu-item-surface",
	)
	_ = resolved
	if surface != 0 { _ = alicorn.visual_part_attach(ctx, surface, row.owner, alicorn.visual_part_core(.Surface)) }
	return surface
}

// item_end closes the row's Button owner and applies the menu's one-shot
// activation policy. It returns true when pointer or semantic activation chose
// the row. Call it only when item_begin returned visible=true.
item_end :: proc(ctx: ^ui.UI, row: MenuItem) -> bool {
	if ctx == nil || !row.visible { return false }
	alicorn.button_end(ctx)
	if row.activated && !row.disabled && row.state != nil {
		row.state.chosen_key = row.item.key
		if !row.keep_open { close(row.state) }
		return true
	}
	return false
}

// item describes one menu row with the default visuals. It is the convenience
// wrapper over item_begin, row_surface, check, label, shortcut, and item_end.
// Separators are visual rows and publish no actionable item. Returns true when
// pointer or semantic activation selected the row; keyboard activation is
// reported by popup_begin's chosen_key.
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
	if value.kind == .Separator {
		separator(ctx, index, options)
		return false
	}
	row, visible := item_begin(ctx, state, value, index, options, recipe, style)
	if !visible { return false }
	if surface := row_surface(ctx, row, options, recipe, style); surface != 0 {
		check(ctx, row, style)
		label(ctx, row)
		shortcut(ctx, row)
		alicorn.surface_end(ctx)
	}
	return item_end(ctx, row)
}

// group_begin opens an optional ad-hoc semantic Menu group for a labeled
// section of rows. Alicorn's collection validation still rejects .Menu at the
// pinned revision, so this is a nested Menu description, not a composite
// collection: it has no logical count or selected identity. Close it with
// group_end. Group headers are not focusable and do not change row indexes.
group_begin :: proc(ctx: ^ui.UI, state: ^State, label: string, key: ui.UI_Key = {}) -> bool {
	if ctx == nil || ctx.runtime == nil || state == nil || state.instance_id == 0 { return false }
	group_key := mix(state.instance_id, 0x47524F5550)
	switch value in key {
	case u64: group_key = mix(group_key, value)
	case alicorn.UI_Key_Pair: group_key = mix(group_key, value.first ~ value.second)
	case string:
		hash := u64(0xCBF29CE484222325)
		for byte in value { hash = (hash ~ u64(byte))*0x100000001B3 }
		group_key = mix(group_key, hash)
	case alicorn.UI_Unkeyed:
	}
	container := alicorn.container_begin(
		ctx,
		.Container,
		label=label,
		key=ui.key_pair(GROUP_KEY, group_key),
		style=ui.layout_style(.Column, width=-1, height=alicorn.LAYOUT_SIZE_FIT_CONTENT, gap=0),
	)
	if container == 0 { return false }
	_ = alicorn.semantic_description(ctx, .Menu, label, description="Menu group")
	_ = alicorn.semantic_bind(ctx, group_semantic_id(state.instance_id, group_key))
	return true
}

group_end :: proc(ctx: ^ui.UI) {
	if ctx == nil { return }
	alicorn.container_end(ctx)
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
