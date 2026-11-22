package sidebar

// Navigation Rail is the P0 Sidebar shape: a vertical, icon-led navigation
// list with expanded and collapsed presentations. Selection is application
// owned; the rail proposes a selection on activation and keeps roving focus
// separate. A tree-style sidebar is a later variant, not this component.
//
// The rail is one focusable List_Box with non-Tab-stop option rows. Arrow keys
// move the Current identity, Home/End move across enabled rows, disabled rows
// are skipped, and Return/Space/pointer/semantic Select propose the active
// route. Collapsing changes the presentation, not the identities or focus.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import tc "alikit:theme_contract"

SIDEBAR_NAMESPACE :: u64(0x5349444542415201) // "SIDEBAR"
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)
ITEM_KEY :: u64(0xA11C_5A01)

Item :: struct {
	// key is the stable application route identity. It must be nonzero and
	// unique within one rail.
	key:      u64,
	label:    string,
	icon:     alicorn.Icon_ID,
	detail:   string,
	badge:    string,
	disabled: bool,
}

Options :: struct {
	accessible_label: string,
	collapsed:        bool,
	wrap:             bool,
	rail_width:       f32,
	expanded_width:   f32,
	item_height:      f32,
	item_gap:         f32,
	padding:          f32,
	icon_size:        f32,
	label_size:       f32,
}

DEFAULT_OPTIONS :: Options{
	accessible_label="Navigation",
	rail_width=56,
	expanded_width=220,
	item_height=40,
	item_gap=2,
	padding=6,
	icon_size=18,
	label_size=0,
}

Recipe :: struct {
	rail_surface_role:     alicorn.Style_Extension_Color_Role_ID,
	item_surface_role:     alicorn.Style_Extension_Color_Role_ID,
	selected_surface_role: alicorn.Style_Extension_Color_Role_ID,
}

Style :: struct {
	corner_radius:  f32,
	indicator_width: f32,
	focus_width:    f32,
}

DEFAULT_STYLE :: Style{
	corner_radius=8,
	indicator_width=3,
	focus_width=2,
}

Theme_Contract :: tc.Contract
Theme_Contract_Report :: tc.Report

recipe_default :: proc() -> Recipe { return {} }
style_default :: proc() -> Style { return DEFAULT_STYLE }

theme_contract_default :: proc(recipe: Recipe) -> Theme_Contract {
	contract: Theme_Contract
	_ = role_requirement(&contract, recipe.rail_surface_role, "alikit.sidebar.rail_surface")
	_ = role_requirement(&contract, recipe.item_surface_role, "alikit.sidebar.item_surface")
	_ = role_requirement(&contract, recipe.selected_surface_role, "alikit.sidebar.selected_surface")
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

State :: struct {
	active_key:   u64,
	active_index: int,

	root_node:              alicorn.Node_ID,
	focus_pending:          bool,
	after_frame_registered: bool,

	proposed:       bool,
	proposed_key:   u64,
	last_collapsed: bool,
}

Event_Kind :: enum { None, Selection_Proposed }

Event :: struct {
	kind: Event_Kind,
	key:  u64,
}

@(private)
mix :: proc(seed, value: u64) -> u64 {
	state := seed+value+0x9E3779B97F4A7C15
	state = (state ~ (state>>30))*0xBF58476D1CE4E5B9
	state = (state ~ (state>>27))*0x94D049BB133111EB
	return state ~ (state>>31)
}

rail_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=SIDEBAR_NAMESPACE, value=mix(instance_id, 0x5241494C)}
}

item_semantic_id :: proc(instance_id, key: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=SIDEBAR_NAMESPACE, value=mix(instance_id, key)}
}

request_focus :: proc(state: ^State) -> bool {
	if state == nil { return false }
	state.focus_pending = true
	return true
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.rail_width <= 0 || math.is_nan(result.rail_width) || math.is_inf(result.rail_width) {
		result.rail_width = DEFAULT_OPTIONS.rail_width
	}
	if result.expanded_width <= 0 || math.is_nan(result.expanded_width) || math.is_inf(result.expanded_width) {
		result.expanded_width = DEFAULT_OPTIONS.expanded_width
	}
	if result.item_height <= 0 || math.is_nan(result.item_height) || math.is_inf(result.item_height) {
		result.item_height = DEFAULT_OPTIONS.item_height
	}
	if result.item_gap < 0 || math.is_nan(result.item_gap) || math.is_inf(result.item_gap) {
		result.item_gap = DEFAULT_OPTIONS.item_gap
	}
	if result.padding < 0 || math.is_nan(result.padding) || math.is_inf(result.padding) {
		result.padding = DEFAULT_OPTIONS.padding
	}
	if result.icon_size <= 0 || math.is_nan(result.icon_size) || math.is_inf(result.icon_size) {
		result.icon_size = DEFAULT_OPTIONS.icon_size
	}
	return result
}

@(private)
style_resolve :: proc(style: Style) -> Style {
	result := style
	if result.corner_radius < 0 || math.is_nan(result.corner_radius) || math.is_inf(result.corner_radius) {
		result.corner_radius = DEFAULT_STYLE.corner_radius
	}
	if result.indicator_width <= 0 || math.is_nan(result.indicator_width) || math.is_inf(result.indicator_width) {
		result.indicator_width = DEFAULT_STYLE.indicator_width
	}
	if result.focus_width <= 0 || math.is_nan(result.focus_width) || math.is_inf(result.focus_width) {
		result.focus_width = DEFAULT_STYLE.focus_width
	}
	return result
}

@(private)
enabled_at :: proc(items: []Item, index: int) -> bool {
	if index < 0 || index >= len(items) { return false }
	return items[index].key != 0 && !items[index].disabled
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
Rail_Roving :: struct {
	items: []Item,
}

@(private)
rail_enabled :: proc(data: rawptr, index: int) -> bool {
	ctx := cast(^Rail_Roving)data
	return enabled_at(ctx.items, index)
}

@(private)
rail_view :: proc(ctx: ^Rail_Roving, items: []Item, wrap: bool) -> alicorn.Roving_View {
	ctx.items = items
	return alicorn.Roving_View{
		count=len(items),
		enabled=rail_enabled,
		data=rawptr(ctx),
		wrap=wrap,
	}
}

@(private)
set_active :: proc(state: ^State, items: []Item, index: int) {
	if state == nil || index < 0 || index >= len(items) { return }
	state.active_index = index
	state.active_key = items[index].key
}

@(private)
reconcile_active :: proc(state: ^State, items: []Item, selected_key: u64) {
	if state == nil { return }
	if len(items) == 0 {
		state.active_index = -1
		state.active_key = 0
		return
	}
	index := index_of_key(items, state.active_key)
	if index >= 0 && enabled_at(items, index) {
		state.active_index = index
		return
	}
	index = index_of_key(items, selected_key)
	if index >= 0 && enabled_at(items, index) {
		set_active(state, items, index)
		return
	}
	ctx: Rail_Roving
	view := rail_view(&ctx, items, false)
	start := clamp(state.active_index, 0, len(items)-1)
	index = alicorn.roving_nearest_enabled(view, start, 1)
	if index < 0 { index = alicorn.roving_first_enabled(view) }
	if index < 0 {
		state.active_index = -1
		state.active_key = 0
		return
	}
	set_active(state, items, index)
}

@(private)
propose :: proc(state: ^State, key: u64) {
	if state == nil || key == 0 { return }
	state.proposed = true
	state.proposed_key = key
}

@(private)
apply_key :: proc(state: ^State, items: []Item, options: Options, key: alicorn.Application_Key) -> bool {
	if state == nil || state.active_index < 0 || state.active_index >= len(items) { return false }
	previous := state.active_index
	if key == .Return || key == .Toggle {
		if enabled_at(items, state.active_index) { propose(state, items[state.active_index].key) }
		return true
	}
	move, mapped := alicorn.roving_move_for_key(key)
	if !mapped { return false }
	if move == .Left || move == .Right || move == .Page_Up || move == .Page_Down { return false }
	ctx: Rail_Roving
	view := rail_view(&ctx, items, options.wrap)
	if index := alicorn.roving_propose(view, state.active_index, move); index >= 0 {
		set_active(state, items, index)
	}
	return state.active_index != previous
}

@(private)
schedule_after_frame :: proc(state: ^State, rt: ^alicorn.Runtime) {
	if state == nil || rt == nil || state.after_frame_registered { return }
	if alicorn.interaction_after_frame_register(rt, rawptr(state), rail_after_frame) {
		state.after_frame_registered = true
	}
}

@(private)
rail_after_frame :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	state := cast(^State)data
	if state == nil || rt == nil { return }
	state.after_frame_registered = false
	if state.focus_pending && state.root_node != 0 {
		if alicorn.focus(rt, state.root_node) {
			state.focus_pending = false
			alicorn.focus_indicator_set(rt, true)
		}
	}
	if state.focus_pending { schedule_after_frame(state, rt) }
}

@(private)
begin_surface :: proc(
	ctx: ^ui.UI,
	role: alicorn.Style_Extension_Color_Role_ID,
	fallback: alicorn.Style_Color_Role,
	key: ui.UI_Key,
	style: alicorn.Layout_Style,
	shape: alicorn.Surface_Shape,
	stroke: alicorn.Paint_Stroke,
	label: string,
) -> alicorn.Node_ID {
	if role != 0 {
		if id := alicorn.surface_begin(ctx, alicorn.surface_extension_color_role(role),
			key=key, style=style, shape=shape, stroke=stroke, label=label); id != 0 {
			return id
		}
	}
	return alicorn.surface_begin(ctx, alicorn.surface_core_color_role(fallback),
		key=key, style=style, shape=shape, stroke=stroke, label=label)
}

@(private)
emit_item :: proc(
	ctx: ^ui.UI,
	state: ^State,
	items: []Item,
	resolved: Options,
	style: Style,
	recipe: Recipe,
	item: Item,
	index: int,
	collection: alicorn.Semantic_Collection_Handle,
	instance_id: u64,
	selected_key: u64,
) {
	selected := item.key != 0 && item.key == selected_key
	active := index == state.active_index
	root_focused := state.root_node != 0 && alicorn.focused_node(ctx.runtime) == state.root_node
	owner, activated := alicorn.button_begin(
		ctx,
		item.label,
		key=ui.key_pair(ITEM_KEY, item.key),
		style=ui.layout_style(.Row,
			width=resolved.item_height if resolved.collapsed else -1,
			height=resolved.item_height,
			align=.Center),
		state=alicorn.Button_State{selected=selected, disabled=item.disabled},
		presentation=.Custom,
		focusable=false,
	)
	if owner == 0 { return }

	states := alicorn.Semantic_States{}
	actions := alicorn.Semantic_Actions{}
	if item.disabled { states = alicorn.semantic_states_add(states, .Disabled) }
	if selected { states = alicorn.semantic_states_add(states, .Selected) }
	if active { states = alicorn.semantic_states_add(states, .Current) }
	if !item.disabled {
		actions = alicorn.semantic_actions_add(actions, .Select)
		actions = alicorn.semantic_actions_add(actions, .Focus)
	}
	_ = alicorn.semantic_collection_item(ctx, collection, u64(index), alicorn.Semantic_Node_Description{
		id=item_semantic_id(instance_id, item.key),
		role=.List_Box_Option,
		label=item.label,
		description=item.detail,
		value=item.label,
		states=states,
		actions=actions,
		visual_node=owner,
	})

	fill_role := recipe.item_surface_role
	fallback := alicorn.Style_Color_Role.Surface
	if selected { fill_role = recipe.selected_surface_role; fallback = .Selection }
	stroke_role := alicorn.Style_Color_Role.Border
	if active && root_focused { stroke_role = .Focus }
	stroke_width: f32 = style.focus_width if active && root_focused else 1
	surface := begin_surface(
		ctx,
		fill_role,
		fallback,
		key=ui.key_pair(ITEM_KEY+1, item.key),
		style=ui.layout_style(.Row, width=-1, height=-1, padding=8, gap=8, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=style.corner_radius},
		stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, stroke_role), width=stroke_width},
		label="sidebar-item-surface",
	)
	if surface != 0 {
		if selected {
			indicator := alicorn.surface_begin(
				ctx,
				alicorn.surface_core_color_role(.Accent),
				key=ui.key_pair(ITEM_KEY+2, item.key),
				style=ui.layout_style(.Row, width=style.indicator_width,
					height=max(resolved.item_height-16, 0)),
				shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=style.indicator_width*0.5},
				label="sidebar-selected-indicator",
			)
			if indicator != 0 {
				_ = alicorn.visual_part_attach(ctx, indicator, owner, alicorn.visual_part_core(.Selected_Indicator))
				alicorn.surface_end(ctx)
			}
		}
		icon_color := alicorn.Style_Color_Role.Text
		if selected { icon_color = .Accent_Text }
		if item.disabled { icon_color = .Muted_Text }
		icon := ui.icon(ctx, item.icon, key=ui.key_pair(ITEM_KEY+3, item.key), size=resolved.icon_size, color_role=icon_color)
		if icon != 0 { _ = alicorn.visual_part_attach(ctx, icon, owner, alicorn.visual_part_core(.Icon)) }
		if !resolved.collapsed {
			label_color := alicorn.style_color(ctx, .Text)
			if item.disabled { label_color = alicorn.style_color(ctx, .Muted_Text) }
			weight := alicorn.FONT_WEIGHT_REGULAR
			if selected { weight = alicorn.FONT_WEIGHT_MEDIUM }
			label := ui.text(ctx, item.label,
				key=ui.key_pair(ITEM_KEY+4, item.key),
				style=ui.layout_style(.Row, grow=1),
				size=resolved.label_size,
				color=label_color,
				decorative=true,
				text_style=alicorn.Text_Style{overflow=.Ellipsis, font_weight=weight},
			)
			if label != 0 { _ = alicorn.visual_part_attach(ctx, label, owner, alicorn.visual_part_core(.Label)) }
			if item.badge != "" {
				badge := ui.text(ctx, item.badge,
					key=ui.key_pair(ITEM_KEY+5, item.key),
					size=11,
					color=alicorn.style_color(ctx, .Muted_Text),
					decorative=true,
				)
				if badge != 0 { _ = alicorn.visual_part_attach(ctx, badge, owner, alicorn.visual_part_core(.Content)) }
			}
		}
		alicorn.surface_end(ctx)
	}
	alicorn.button_end(ctx)
	if activated && !item.disabled { propose(state, item.key) }
}

// rail describes one navigation rail. selected_key is application-owned and is
// never mutated. The returned event is the one proposed route change for this
// description. instance_id must be stable and unique among mounted rails.
rail :: proc(
	ctx: ^ui.UI,
	state: ^State,
	items: []Item,
	selected_key: u64,
	options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
	recipe: Recipe = {},
	style: Style = {},
) -> (event: Event) {
	if ctx == nil || ctx.runtime == nil || state == nil || instance_id == 0 ||
	   instance_id > MAX_INSTANCE_ID {
		return
	}
	resolved := options_resolve(options)
	resolved_style := style_resolve(style)
	if !ui.key_scope(ctx, key) { return }
	reconcile_active(state, items, selected_key)
	// Collapsing changes the visible width but not the retained focus owner or
	// semantic identities. No explicit focus restart is needed.
	state.last_collapsed = resolved.collapsed

	width := resolved.expanded_width
	if resolved.collapsed { width = resolved.rail_width }
	state.root_node = 0
	rail_surface := begin_surface(
		ctx,
		recipe.rail_surface_role,
		.Surface,
		key=alicorn.key_string("alikit-sidebar-rail-surface"),
		style=ui.layout_style(.Column, width=width, height=-1),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=resolved_style.corner_radius},
		stroke={},
		label="sidebar-rail-surface",
	)
	if rail_surface == 0 { return }
	root := alicorn.container_begin(
		ctx,
		.Container,
		label=resolved.accessible_label,
		key=alicorn.key_string("alikit-sidebar-rail"),
		style=ui.layout_style(.Column, width=-1, height=-1, padding=resolved.padding,
			gap=resolved.item_gap, align=.Stretch),
		focusable=true,
	)
	if root == 0 { alicorn.surface_end(ctx); return }
	state.root_node = root
	selected_id := item_semantic_id(instance_id, selected_key)
	if index_of_key(items, selected_key) < 0 { selected_id = {} }
	collection := alicorn.semantic_collection_begin(
		ctx,
		root,
		rail_semantic_id(instance_id),
		.List_Box,
		resolved.accessible_label,
		u64(len(items)),
		selected_id=selected_id,
		current_id=item_semantic_id(instance_id, state.active_key),
		realized_first=0,
		realized_last=u64(len(items)),
	)
	// semantic_collection_begin applies the collection role to the owner; make
	// the owner focusable after the fact through the public focus request.
	if collection.id.namespace != 0 {
		_ = ui.interaction_scope(ctx, root, rawptr(state), alicorn.Interaction_Scope_Options{
			keys={.Up, .Down, .Home, .End, .Return, .Toggle},
			composition_yield_keys={.Up, .Down, .Home, .End, .Return, .Toggle},
		})
		for {
			queued, found := alicorn.interaction_event_next(ctx.runtime, root)
			if !found { break }
			if queued.kind == .Key && apply_key(state, items, resolved, queued.key) {
				alicorn.invalidate_root(ctx.runtime, "sidebar keyboard navigation")
			}
		}
		for item, index in items {
			emit_item(ctx, state, items, resolved, resolved_style, recipe, item, index,
				collection, instance_id, selected_key)
		}
		if state.proposed {
			state.proposed = false
			event = Event{kind=.Selection_Proposed, key=state.proposed_key}
		}
	}
	alicorn.container_end(ctx)
	alicorn.surface_end(ctx)
	if state.focus_pending { schedule_after_frame(state, ctx.runtime) }
	return
}
