package segmented

// Segmented Control is a single-selection control over equal-width segments.
// It publishes a Tab_List/Tab collection, one Tab stop, roving arrow
// navigation, disabled skipping, and keyboard/pointer/semantic activation
// parity. A moving selected indicator is a paint-only translation animated
// through alicorn's motion model; reduced motion snaps it.
//
// The component uses the shared alikit:selection model for keyed selection
// proposals and alicorn's pure roving model for focus movement. It keeps no
// application selection: selected_value is an input and the component returns
// one proposed value.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import sel "alikit:selection"
import tc "alikit:theme_contract"

SEGMENTED_NAMESPACE :: u64(0x5345474D454E5431) // "SEGMENT1"
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)
SEGMENT_KEY :: u64(0xA11C_5E01)
INDICATOR_KEY :: u64(0xA11C_5E02)

Selection_Mode :: sel.Mode

Item :: struct {
	// value is the application-owned stable identity. It must be nonzero and
	// unique within one control.
	value:    u64,
	label:    string,
	disabled: bool,
}

Options :: struct {
	accessible_label: string,
	// width is the definite control width. Equal segment widths are derived
	// from it so the moving indicator can translate by whole segments.
	width:            f32,
	height:           f32,
	padding:          f32,
	corner_radius:    f32,
	label_size:       f32,
	selection_mode:   sel.Mode,
	// no_wrap stops arrow navigation at the first and last enabled segment.
	no_wrap:          bool,
}

DEFAULT_OPTIONS :: Options{
	accessible_label="View",
	width=360,
	height=36,
	padding=3,
	corner_radius=10,
	selection_mode=.Follow_Focus,
}

Recipe :: struct {
	track_surface_role:     alicorn.Style_Extension_Color_Role_ID,
	indicator_surface_role: alicorn.Style_Extension_Color_Role_ID,
}

Style :: struct {
	focus_width: f32,
}

DEFAULT_STYLE :: Style{focus_width=2}

Theme_Contract :: tc.Contract
Theme_Contract_Report :: tc.Report

recipe_default :: proc() -> Recipe { return {} }
style_default :: proc() -> Style { return DEFAULT_STYLE }

theme_contract_default :: proc(recipe: Recipe) -> Theme_Contract {
	contract: Theme_Contract
	if recipe.track_surface_role == 0 {
		_ = tc.optional_role(&contract, 0, "alikit.segmented.track_surface")
	} else {
		_ = tc.required_role(&contract, recipe.track_surface_role, "alikit.segmented.track_surface")
	}
	if recipe.indicator_surface_role == 0 {
		_ = tc.optional_role(&contract, 0, "alikit.segmented.indicator_surface")
	} else {
		_ = tc.required_role(&contract, recipe.indicator_surface_role, "alikit.segmented.indicator_surface")
	}
	return contract
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
	// active is the shared pure selection/focus identity model.
	using active: sel.State,

	root_node:              alicorn.Node_ID,
	focus_pending:          bool,
	after_frame_registered: bool,

	proposed:       bool,
	proposed_value: u64,

	// Diagnostic state from the most recent description.
	last_indicator_x:    f32,
	last_reduced_motion: bool,
	indicator_initialized: bool,
}

Event_Kind :: enum { None, Selection_Proposed }

Event :: struct {
	kind:  Event_Kind,
	value: u64,
}

@(private)
mix :: proc(seed, value: u64) -> u64 {
	state := seed+value+0x9E3779B97F4A7C15
	state = (state ~ (state>>30))*0xBF58476D1CE4E5B9
	state = (state ~ (state>>27))*0x94D049BB133111EB
	return state ~ (state>>31)
}

control_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=SEGMENTED_NAMESPACE, value=mix(instance_id, 0x53454743)}
}

segment_semantic_id :: proc(instance_id, value: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || value == 0 { return {} }
	return alicorn.Semantic_ID{namespace=SEGMENTED_NAMESPACE, value=mix(instance_id, value)}
}

// request_focus asks the next description to focus the control's one Tab stop
// after layout.
request_focus :: proc(state: ^State) -> bool {
	if state == nil { return false }
	state.focus_pending = true
	return true
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.accessible_label == "" { result.accessible_label = DEFAULT_OPTIONS.accessible_label }
	if result.width <= 0 || math.is_nan(result.width) || math.is_inf(result.width) {
		result.width = DEFAULT_OPTIONS.width
	}
	if result.height <= 0 || math.is_nan(result.height) || math.is_inf(result.height) {
		result.height = DEFAULT_OPTIONS.height
	}
	if result.padding < 0 || math.is_nan(result.padding) || math.is_inf(result.padding) {
		result.padding = DEFAULT_OPTIONS.padding
	}
	if result.corner_radius < 0 || math.is_nan(result.corner_radius) || math.is_inf(result.corner_radius) {
		result.corner_radius = DEFAULT_OPTIONS.corner_radius
	}
	if result.label_size <= 0 || math.is_nan(result.label_size) || math.is_inf(result.label_size) {
		result.label_size = 0
	}
	return result
}

@(private)
style_resolve :: proc(style: Style) -> Style {
	result := style
	if result.focus_width <= 0 || math.is_nan(result.focus_width) || math.is_inf(result.focus_width) {
		result.focus_width = DEFAULT_STYLE.focus_width
	}
	return result
}

@(private)
Selection_View :: struct {
	items: []Item,
}

@(private)
segment_key_at :: proc(data: rawptr, index: int) -> u64 {
	ctx := cast(^Selection_View)data
	if index < 0 || index >= len(ctx.items) { return 0 }
	return ctx.items[index].value
}

@(private)
segment_enabled_at :: proc(data: rawptr, index: int) -> bool {
	ctx := cast(^Selection_View)data
	if index < 0 || index >= len(ctx.items) { return false }
	return ctx.items[index].value != 0 && !ctx.items[index].disabled
}

@(private)
selection_view :: proc(ctx: ^Selection_View, items: []Item) -> sel.View {
	ctx.items = items
	return sel.View{
		count=len(items),
		data=rawptr(ctx),
		key_at=segment_key_at,
		enabled_at=segment_enabled_at,
	}
}

@(private)
Roving_Data :: struct {
	items: []Item,
}

@(private)
roving_enabled :: proc(data: rawptr, index: int) -> bool {
	ctx := cast(^Roving_Data)data
	if index < 0 || index >= len(ctx.items) { return false }
	return ctx.items[index].value != 0 && !ctx.items[index].disabled
}

@(private)
roving_view :: proc(ctx: ^Roving_Data, items: []Item, wrap: bool) -> alicorn.Roving_View {
	ctx.items = items
	return alicorn.Roving_View{
		count=len(items),
		enabled=roving_enabled,
		data=rawptr(ctx),
		wrap=wrap,
	}
}

@(private)
propose :: proc(state: ^State, value: u64) {
	if state == nil || value == 0 { return }
	state.proposed = true
	state.proposed_value = value
}

@(private)
reconcile_active :: proc(state: ^State, items: []Item, selected_value: u64) {
	if state == nil { return }
	ctx: Selection_View
	view := selection_view(&ctx, items)
	_ = sel.reconcile_active(&state.active, view, selected_value)
}

@(private)
set_active :: proc(state: ^State, items: []Item, index: int) {
	if state == nil { return }
	ctx: Selection_View
	view := selection_view(&ctx, items)
	_ = sel.set_active(&state.active, view, index)
}

@(private)
apply_key :: proc(
	state: ^State,
	items: []Item,
	resolved: Options,
	key: alicorn.Application_Key,
) -> bool {
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
	if move == .Page_Up || move == .Page_Down { return true }
	roving_ctx: Roving_Data
	view := roving_view(&roving_ctx, items, !resolved.no_wrap)
	if index := alicorn.roving_propose(view, state.active_index, move); index >= 0 {
		set_active(state, items, index)
		if value, ok := sel.propose_focus(selection, index, resolved.selection_mode); ok {
			propose(state, value)
		}
	}
	return state.active_index != previous
}

@(private)
reduced_motion :: proc(rt: ^alicorn.Runtime) -> bool {
	observation := alicorn.style_root_accessibility_observation_get(rt)
	if .Reduce_Motion not_in observation.known { return false }
	return observation.preferences.reduce_motion
}

@(private)
schedule_after_frame :: proc(state: ^State, rt: ^alicorn.Runtime) {
	if state == nil || rt == nil || state.after_frame_registered { return }
	if alicorn.interaction_after_frame_register(rt, rawptr(state), segmented_after_frame) {
		state.after_frame_registered = true
	}
}

@(private)
segmented_after_frame :: proc(data: rawptr, rt: ^alicorn.Runtime) {
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
surface_role :: proc(role: alicorn.Style_Extension_Color_Role_ID, fallback: alicorn.Style_Color_Role) -> alicorn.Semantic_Surface_Color_Role {
	if role != 0 { return alicorn.surface_extension_color_role(role) }
	return alicorn.surface_core_color_role(fallback)
}

// control describes one segmented control. selected_value is the
// application-owned selection and is never mutated. The returned event is the
// one proposed selection change for this description, if any. instance_id must
// be stable and unique among simultaneously mounted controls.
control :: proc(
	ctx: ^ui.UI,
	state: ^State,
	items: []Item,
	selected_value: u64,
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
	reconcile_active(state, items, selected_value)

	state.root_node = 0
	root := alicorn.container_begin(
		ctx,
		.Container,
		label=resolved.accessible_label,
		key=alicorn.key_string("alikit-segmented"),
		style=ui.layout_style(.Row, width=resolved.width, height=resolved.height),
		focusable=true,
	)
	if root == 0 { return }
	state.root_node = root

	selected_id := segment_semantic_id(instance_id, selected_value)
	selected_ctx: Selection_View
	if sel.index_of_key(selection_view(&selected_ctx, items), selected_value) < 0 {
		selected_id = {}
	}
	current_id := segment_semantic_id(instance_id, state.active_key)
	collection := alicorn.semantic_collection_begin(
		ctx,
		root,
		control_semantic_id(instance_id),
		.Tab_List,
		resolved.accessible_label,
		u64(len(items)),
		selected_id=selected_id,
		current_id=current_id,
		realized_first=0,
		realized_last=u64(len(items)),
	)
	if collection.id.namespace == 0 {
		alicorn.container_end(ctx)
		state.root_node = 0
		return
	}
	_ = ui.interaction_scope(ctx, root, rawptr(state), alicorn.Interaction_Scope_Options{
		keys={.Left, .Right, .Up, .Down, .Home, .End, .Return, .Toggle},
		composition_yield_keys={.Left, .Right, .Up, .Down, .Home, .End, .Return, .Toggle},
	})
	for {
		queued, found := alicorn.interaction_event_next(ctx.runtime, root)
		if !found { break }
		if queued.kind == .Key && apply_key(state, items, resolved, queued.key) {
			alicorn.invalidate_root(ctx.runtime, "segmented control keyboard navigation")
		}
	}

	root_focused := alicorn.focused_node(ctx.runtime) == root
	corner_radius := resolved.corner_radius
	inner_width := max(resolved.width-2*resolved.padding, 0)
	inner_height := max(resolved.height-2*resolved.padding, 0)
	count := max(len(items), 1)
	segment_width := inner_width/f32(count)
	stroke_role := alicorn.Style_Color_Role.Border
	if root_focused { stroke_role = .Focus }
	track := alicorn.surface_begin(
		ctx,
		surface_role(recipe.track_surface_role, .Subtle_Surface),
		key=ui.key_u64(10),
		style=ui.layout_style(.Row, width=-1, height=-1, padding=resolved.padding,
			align=.Center, gap=0),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=corner_radius},
		stroke=alicorn.Paint_Stroke{
			color=alicorn.style_color(ctx, stroke_role),
			width=resolved_style.focus_width if root_focused else 1,
		},
		label="segmented-track",
	)
	if track != 0 {
		// A moving indicator surface behind the segment labels. Equal segment
		// widths let the paint-only translation express selection changes.
		indicator := alicorn.surface_begin(
			ctx,
			surface_role(recipe.indicator_surface_role, .Selection),
			key=ui.key_u64(INDICATOR_KEY),
			style=ui.layout_style(.Row, width=segment_width, height=inner_height),
			shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle,
				corner_radius=max(corner_radius-resolved.padding, 0)},
			stroke={},
			label="segmented-indicator",
		)
		if indicator != 0 {
			alicorn.surface_end(ctx)
			if alicorn.position_child(ctx, indicator, alicorn.positioned(0, 0)) {
				target_x := f32(max(state.active_index, 0))*segment_width
				state.last_indicator_x = target_x
				state.last_reduced_motion = reduced_motion(ctx.runtime)
				intent := alicorn.Motion_Intent.Settle
				if state.last_reduced_motion || !state.indicator_initialized {
					intent = .Snap
				}
				_ = ui.motion(ctx, indicator, alicorn.Motion_Target{
					translation=alicorn.Motion_Vector2{x=f64(target_x), y=0},
					has_translation=true,
				}, intent)
				if !state.indicator_initialized { state.indicator_initialized = true }
			}
		}

		shown := min(len(items), int(collection.logical_count))
		for item, index in items[:shown] {
			checked := item.value != 0 && item.value == selected_value
			active := index == state.active_index
			owner, activated := alicorn.button_begin(
				ctx,
				item.label,
				key=ui.key_pair(SEGMENT_KEY, item.value),
				style=ui.layout_style(.Row, width=segment_width, height=inner_height,
					align=.Center, justify=.Center),
				state=alicorn.Button_State{selected=checked, disabled=item.disabled},
				presentation=.Custom,
				focusable=false,
			)
			if owner == 0 { continue }
			states := alicorn.Semantic_States{}
			actions := alicorn.Semantic_Actions{}
			if item.disabled { states = alicorn.semantic_states_add(states, .Disabled) }
			if checked {
				states = alicorn.semantic_states_add(states, .Selected)
				states = alicorn.semantic_states_add(states, .Checked)
			}
			if active { states = alicorn.semantic_states_add(states, .Current) }
			if !item.disabled {
				actions = alicorn.semantic_actions_add(actions, .Select)
				actions = alicorn.semantic_actions_add(actions, .Focus)
			}
			_ = alicorn.semantic_collection_item(ctx, collection, u64(index),
				alicorn.Semantic_Node_Description{
					id=segment_semantic_id(instance_id, item.value),
					role=.Tab,
					label=item.label,
					states=states,
					actions=actions,
					visual_node=owner,
				})
			color := alicorn.style_color(ctx, .Text)
			if item.disabled { color = alicorn.style_color(ctx, .Muted_Text) }
			_ = ui.text(ctx, item.label,
				key=ui.key_u64(2),
				size=resolved.label_size,
				color=color,
				decorative=true,
				text_style=alicorn.Text_Style{overflow=.Ellipsis},
			)
			alicorn.button_end(ctx)
			if activated && !item.disabled { propose(state, item.value) }
		}
		alicorn.surface_end(ctx)
	}
	alicorn.container_end(ctx)

	if state.proposed {
		state.proposed = false
		event = Event{kind=.Selection_Proposed, value=state.proposed_value}
	}
	if state.focus_pending { schedule_after_frame(state, ctx.runtime) }
	return
}
