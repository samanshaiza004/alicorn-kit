package sidebar

// Navigation Rail is the P0 Sidebar shape: a vertical, icon-led navigation
// list with expanded and collapsed presentations. It is built from public
// parts. Selection is application owned; the rail proposes a selection on
// activation and keeps roving focus separate. A tree-style sidebar is a later
// variant, not this component.
//
// Authors can use the complete rail() component or compose the parts:
//
//	rail, visible := sidebar.rail_begin(ctx, &state, items, selected_key,
//		label="Workspace navigation", key=key, instance_id=1)
//	if visible {
//		for item in items {
//			row, row_visible := sidebar.item_begin(ctx, &rail, item)
//			if row_visible {
//				sidebar.indicator(ctx, row) // optional selected bar
//				sidebar.icon(ctx, row)      // optional icon
//				sidebar.label(ctx, row)     // optional label
//				sidebar.badge(ctx, row)     // optional badge
//				sidebar.item_end(ctx, row)
//			}
//		}
//		event = sidebar.rail_end(ctx, &rail)
//	}
//
// Everything between item_begin and item_end belongs to the author: keep the
// default parts, omit some of them, or replace the inside of the Button owner
// with any ordinary Alicorn layout. The parts retain List_Box_Option semantics,
// roving focus participation, selected/current/disabled publication, keyboard
// navigation, and one activation proposal. The application still owns the
// accepted route.
//
// It is ordinary AliKit code: no runtime registration, second UI tree, focus
// policy, or private runtime access.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import sel "alikit:selection"
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
	// active is the shared single-selection/focus identity model. active_key is
	// the roving focus route, not selection; the selected route stays in the
	// application.
	using active: sel.State,

	root_node:              alicorn.Node_ID,
	focus_pending:          bool,
	after_frame_registered: bool,

	// proposed is a route proposed during a description that cannot return it
	// directly (pointer or semantic activation). rail_end reports it so every
	// input path shares one controlled result.
	proposed:     bool,
	proposed_key: u64,

	last_collapsed: bool,
}

Event_Kind :: enum { None, Selection_Proposed }

Event :: struct {
	kind: Event_Kind,
	key:  u64,
}

// Rail is the per-description rail context returned by rail_begin. It owns no
// application selection and allocates nothing; the caller-owned State remains
// the only retained interaction state.
Rail :: struct {
	ctx:          ^ui.UI,
	state:        ^State,
	items:        []Item,
	selected_key: u64,
	resolved:     Options,
	style:        Style,
	recipe:       Recipe,
	instance_id:  u64,
	root:         alicorn.Node_ID,
	surface:      alicorn.Node_ID,
	collection:   alicorn.Semantic_Collection_Handle,
	visible:      bool,
}

// Rail_Item is the per-description route context returned by item_begin. Its
// public fields expose everything a custom row needs: the caller-owned route,
// its stable index and count, selected state, roving focus, focus visibility,
// disabled policy, and the Button owner.
Rail_Item :: struct {
	rail:          ^Rail,
	item:          Item,
	index:         int,
	count:         int,
	owner:         alicorn.Node_ID,
	selected:      bool,
	focused:       bool,
	focus_visible: bool,
	disabled:      bool,
	visible:       bool,
	activated:     bool,
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

// instance_from_key derives a stable instance identity when a parts author
// supplies only the UI key. An explicit nonzero instance_id is preferred when
// the key may change between descriptions.
instance_from_key :: proc(key: ui.UI_Key) -> u64 {
	switch value in key {
	case alicorn.UI_Unkeyed:
		return 0
	case u64:
		return mix(value, 0x524B4559)
	case alicorn.UI_Key_Pair:
		return mix(value.first, value.second)
	case string:
		hash := u64(0xCBF29CE484222325)
		for byte in value {
			hash = (hash ~ u64(byte))*0x100000001B3
		}
		return mix(hash, 0x52535452)
	}
	return 0
}

request_focus :: proc(state: ^State) -> bool {
	if state == nil { return false }
	state.focus_pending = true
	return true
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.accessible_label == "" { result.accessible_label = DEFAULT_OPTIONS.accessible_label }
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
Selection_View :: struct {
	items: []Item,
}

@(private)
selection_key_at :: proc(data: rawptr, index: int) -> u64 {
	ctx := cast(^Selection_View)data
	if index < 0 || index >= len(ctx.items) { return 0 }
	return ctx.items[index].key
}

@(private)
selection_enabled_at :: proc(data: rawptr, index: int) -> bool {
	ctx := cast(^Selection_View)data
	return enabled_at(ctx.items, index)
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
	if state == nil { return }
	ctx: Selection_View
	view := selection_view(&ctx, items)
	_ = sel.set_active(&state.active, view, index)
}

@(private)
reconcile_active :: proc(state: ^State, items: []Item, selected_key: u64) {
	if state == nil { return }
	ctx: Selection_View
	view := selection_view(&ctx, items)
	_ = sel.reconcile_active(&state.active, view, selected_key)
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
	selection_ctx: Selection_View
	selection := selection_view(&selection_ctx, items)
	if key == .Return || key == .Toggle {
		if value, ok := sel.propose_activation(selection, state.active_index); ok {
			propose(state, value)
		}
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

// rail_begin opens the rail surface, its single focus scope, and the List_Box
// collection. items is the caller-owned keyed route slice; selected_key is the
// application-owned selection. label overrides the accessible label when
// nonempty. When instance_id is zero, a stable identity is derived from key.
//
// The returned Rail is a per-description value. Pass its address to item_begin
// and rail_end. visible is false when the key scope, runtime, or collection is
// unavailable; call rail_end only when visible is true.
rail_begin :: proc(
	ctx: ^ui.UI,
	state: ^State,
	items: []Item,
	selected_key: u64,
	label: string = "",
	key: ui.UI_Key = {},
	instance_id: u64 = 0,
	rail_options: Options = {},
	recipe: Recipe = {},
	style: Style = {},
) -> (rail: Rail, visible: bool) {
	if ctx == nil || ctx.runtime == nil || state == nil { return }
	resolved_instance := instance_id
	if resolved_instance == 0 { resolved_instance = instance_from_key(key) }
	if resolved_instance == 0 || resolved_instance > MAX_INSTANCE_ID { return }

	resolved := options_resolve(rail_options)
	if label != "" { resolved.accessible_label = label }
	resolved_style := style_resolve(style)
	if !ui.key_scope(ctx, key) { return }

	reconcile_active(state, items, selected_key)
	// Collapsing changes the visible width but not the retained focus owner or
	// semantic identities. No explicit focus restart is needed.
	state.last_collapsed = resolved.collapsed
	rail = Rail{
		ctx=ctx,
		state=state,
		items=items,
		selected_key=selected_key,
		resolved=resolved,
		style=resolved_style,
		recipe=recipe,
		instance_id=resolved_instance,
	}

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
	rail.root = root
	rail.surface = rail_surface
	selected_id := item_semantic_id(resolved_instance, selected_key)
	if index_of_key(items, selected_key) < 0 { selected_id = {} }
	collection := alicorn.semantic_collection_begin(
		ctx,
		root,
		rail_semantic_id(resolved_instance),
		.List_Box,
		resolved.accessible_label,
		u64(len(items)),
		selected_id=selected_id,
		current_id=item_semantic_id(resolved_instance, state.active_key),
		realized_first=0,
		realized_last=u64(len(items)),
	)
	if collection.id.namespace == 0 {
		alicorn.container_end(ctx)
		alicorn.surface_end(ctx)
		state.root_node = 0
		rail.root = 0
		rail.surface = 0
		return
	}
	rail.collection = collection
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
	rail.visible = true
	return rail, true
}

// item_begin opens one route's Button owner and publishes its List_Box_Option
// semantic item. It returns visible=false for an invalid rail, an unknown or
// zero route key, or a failed Button owner; in that case the author skips both
// the visual subtree and its semantics, and must not call item_end.
//
// item_style defaults to the rail's presentation geometry. Pass an ordinary
// ui.Layout_Style value to own the row's outer width, height, direction,
// padding, gap, and alignment. The Button owner remains the semantic and hit
// owner regardless of the visual tree inside it.
item_begin :: proc(
	ctx: ^ui.UI,
	rail: ^Rail,
	item: Item,
	item_style: ui.Layout_Style = {},
) -> (row: Rail_Item, visible: bool) {
	if ctx == nil || ctx.runtime == nil || rail == nil || !rail.visible { return }
	index := index_of_key(rail.items, item.key)
	if index < 0 { return }

	resolved := rail.resolved
	state := rail.state
	selected := item.key != 0 && item.key == rail.selected_key
	active := index == state.active_index
	root_focused := state.root_node != 0 && alicorn.focused_node(ctx.runtime) == state.root_node
	style := item_style
	if style == (ui.Layout_Style{}) {
		style = ui.layout_style(.Row,
			width=resolved.item_height if resolved.collapsed else -1,
			height=resolved.item_height,
			align=.Center)
	}
	owner, activated := alicorn.button_begin(
		ctx,
		item.label,
		key=ui.key_pair(ITEM_KEY, item.key),
		style=style,
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
	_ = alicorn.semantic_collection_item(ctx, rail.collection, u64(index), alicorn.Semantic_Node_Description{
		id=item_semantic_id(rail.instance_id, item.key),
		role=.List_Box_Option,
		label=item.label,
		description=item.detail,
		value=item.label,
		states=states,
		actions=actions,
		visual_node=owner,
	})

	row = Rail_Item{
		rail=rail,
		item=item,
		index=index,
		count=len(rail.items),
		owner=owner,
		selected=selected,
		focused=active,
		focus_visible=active && root_focused,
		disabled=item.disabled,
		visible=true,
		activated=activated,
	}
	return row, true
}

// indicator draws the default selected-route bar. It is optional: omit it and
// draw any surface, shape, icon, or image inside the row. It draws nothing for
// a route that is not selected.
indicator :: proc(ctx: ^ui.UI, row: Rail_Item) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible || row.rail == nil || !row.selected { return 0 }
	rail := row.rail
	resolved := rail.resolved
	style := rail.style
	indicator := alicorn.surface_begin(
		ctx,
		alicorn.surface_core_color_role(.Accent),
		key=ui.key_pair(ITEM_KEY+2, row.item.key),
		style=ui.layout_style(.Row, width=style.indicator_width,
			height=max(resolved.item_height-16, 0)),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=style.indicator_width*0.5},
		label="sidebar-selected-indicator",
	)
	if indicator != 0 {
		_ = alicorn.visual_part_attach(ctx, indicator, row.owner, alicorn.visual_part_core(.Selected_Indicator))
		alicorn.surface_end(ctx)
	}
	return indicator
}

// icon draws the route icon and attaches the core Icon part. Omit it for a
// custom leading visual.
icon :: proc(ctx: ^ui.UI, row: Rail_Item) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible || row.rail == nil { return 0 }
	icon_color := alicorn.Style_Color_Role.Text
	if row.selected { icon_color = .Accent_Text }
	if row.disabled { icon_color = .Muted_Text }
	icon := ui.icon(ctx, row.item.icon, key=ui.key_pair(ITEM_KEY+3, row.item.key),
		size=row.rail.resolved.icon_size, color_role=icon_color)
	if icon != 0 { _ = alicorn.visual_part_attach(ctx, icon, row.owner, alicorn.visual_part_core(.Icon)) }
	return icon
}

// label draws the visible route label. It is optional, and it draws nothing in
// the collapsed presentation; the accessible name remains on the semantic item.
label :: proc(ctx: ^ui.UI, row: Rail_Item, text: string = "") -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible || row.rail == nil { return 0 }
	if row.rail.resolved.collapsed { return 0 }
	value := text
	if value == "" { value = row.item.label }
	label_color := alicorn.style_color(ctx, .Text)
	if row.disabled { label_color = alicorn.style_color(ctx, .Muted_Text) }
	weight := alicorn.FONT_WEIGHT_REGULAR
	if row.selected { weight = alicorn.FONT_WEIGHT_MEDIUM }
	label := ui.text(ctx, value,
		key=ui.key_pair(ITEM_KEY+4, row.item.key),
		style=ui.layout_style(.Row, grow=1),
		size=row.rail.resolved.label_size,
		color=label_color,
		decorative=true,
		text_style=alicorn.Text_Style{overflow=.Ellipsis, font_weight=weight},
	)
	if label != 0 { _ = alicorn.visual_part_attach(ctx, label, row.owner, alicorn.visual_part_core(.Label)) }
	return label
}

// badge draws the optional route badge text. It draws nothing for an empty
// badge or in the collapsed presentation. Provide a meaningful label on the
// route; the badge is not a separate semantic item.
badge :: proc(ctx: ^ui.UI, row: Rail_Item, text: string = "") -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible || row.rail == nil { return 0 }
	if row.rail.resolved.collapsed { return 0 }
	value := text
	if value == "" { value = row.item.badge }
	if value == "" { return 0 }
	badge := ui.text(ctx, value,
		key=ui.key_pair(ITEM_KEY+5, row.item.key),
		size=11,
		color=alicorn.style_color(ctx, .Muted_Text),
		decorative=true,
	)
	if badge != 0 { _ = alicorn.visual_part_attach(ctx, badge, row.owner, alicorn.visual_part_core(.Content)) }
	return badge
}

// row_surface draws the default rounded row background, selected fill, and
// focus stroke. It is optional: custom rows may draw any surface composition
// inside the Button owner. Call it first in the row so the other parts layer
// above it.
row_surface :: proc(ctx: ^ui.UI, row: Rail_Item) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible || row.rail == nil { return 0 }
	rail := row.rail
	style := rail.style
	fill_role := rail.recipe.item_surface_role
	fallback := alicorn.Style_Color_Role.Surface
	if row.selected { fill_role = rail.recipe.selected_surface_role; fallback = .Selection }
	stroke_role := alicorn.Style_Color_Role.Border
	if row.focus_visible { stroke_role = .Focus }
	stroke_width: f32 = style.focus_width if row.focus_visible else 1
	surface := begin_surface(
		ctx,
		fill_role,
		fallback,
		key=ui.key_pair(ITEM_KEY+1, row.item.key),
		style=ui.layout_style(.Row, width=-1, height=-1, padding=8, gap=8, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=style.corner_radius},
		stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, stroke_role), width=stroke_width},
		label="sidebar-item-surface",
	)
	if surface == 0 { return 0 }
	return surface
}

// item_end closes the route's Button owner and records a pointer or semantic
// activation as the rail's one pending selection proposal. Call it only when
// item_begin returned visible=true.
item_end :: proc(ctx: ^ui.UI, row: Rail_Item) {
	if ctx == nil || !row.visible { return }
	alicorn.button_end(ctx)
	if row.activated && !row.disabled {
		propose(row.rail.state, row.item.key)
	}
}

// rail_end closes the rail's collection scope and returns the one selection
// proposal produced by this description, if any. It also schedules a pending
// focus request.
rail_end :: proc(ctx: ^ui.UI, rail: ^Rail) -> (event: Event) {
	if ctx == nil || rail == nil || rail.root == 0 { return }
	if rail.state != nil && rail.state.proposed {
		rail.state.proposed = false
		event = Event{kind=.Selection_Proposed, key=rail.state.proposed_key}
	}
	alicorn.container_end(ctx)
	alicorn.surface_end(ctx)
	if rail.state != nil && rail.state.focus_pending {
		schedule_after_frame(rail.state, ctx.runtime)
	}
	rail.visible = false
	rail.root = 0
	rail.surface = 0
	return
}

// rail is the convenience component built from the exact public parts.
// selected_key is the application-owned selection and is never mutated. The
// returned event is the one proposed route change for this description.
// instance_id must be stable and unique among simultaneously mounted rails.
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
	rail_ctx, visible := rail_begin(
		ctx,
		state,
		items,
		selected_key,
		label=options.accessible_label,
		key=key,
		instance_id=instance_id,
		rail_options=options,
		recipe=recipe,
		style=style,
	)
	if !visible { return }
	for item in items {
		row, row_visible := item_begin(ctx, &rail_ctx, item)
		if !row_visible { continue }
		if surface := row_surface(ctx, row); surface != 0 {
			indicator(ctx, row)
			icon(ctx, row)
			label(ctx, row)
			badge(ctx, row)
			alicorn.surface_end(ctx)
		}
		item_end(ctx, row)
	}
	return rail_end(ctx, &rail_ctx)
}
