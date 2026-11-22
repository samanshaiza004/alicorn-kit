package radio_group

// Radio Group is a controlled, copyable compound control built from public
// parts. The application owns the selected value and performs mutual exclusion;
// these parts publish the Radio_Group/Radio_Button semantics, one Tab stop,
// roving arrow navigation, pointer/semantic activation parity, and a namespaced
// appearance recipe.
//
// Authors can use the complete radio_group() component or compose the parts:
//
//	group, visible := radio.group_begin(ctx, &state, options, selected,
//		label="Text size", key=key, instance_id=1)
//	if visible {
//		for option in options {
//			item, item_visible := radio.item_begin(ctx, &group, option)
//			if item_visible {
//				radio.indicator(ctx, item) // optional default dot
//				radio.label(ctx, item)     // optional default label
//				radio.item_end(ctx, item)
//			}
//		}
//		event = radio.group_end(ctx, &group)
//	}
//
// Everything between item_begin and item_end belongs to the author: keep the
// default parts, omit the indicator, or replace the inside of the Button owner
// with any ordinary Alicorn layout. The parts retain keyboard navigation,
// roving focus, checked-state publication, and Radio_Button semantics; the
// application still owns the accepted selected value.
//
// It is ordinary AliKit code: no runtime registration, second UI tree, focus
// policy, or private runtime access. Copy the folder and change drawing or
// geometry locally; selection remains with the application.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import tc "alikit:theme_contract"

RADIO_GROUP_NAMESPACE :: u64(0x524144494F475250) // "RADIOGRP"
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)
ITEM_KEY :: u64(0xA11C_2A01)

Option :: struct {
	// value is the application-owned stable identity. It must be nonzero and
	// unique within one group. Checked identity follows this value across
	// reorder and removal.
	value:       u64,
	label:       string,
	description: string,
	disabled:    bool,
}

Orientation :: enum { Horizontal, Vertical }

// Selection_Mode controls whether arrow navigation proposes a selection
// change. Follow_Focus is the platform radio convention. Activate keeps focus
// movement separate and proposes only on Space/Return or pointer activation.
Selection_Mode :: enum { Follow_Focus, Activate }

Options :: struct {
	accessible_label: string,
	orientation:      Orientation,
	selection_mode:   Selection_Mode,
	// no_wrap stops arrow navigation at the first and last enabled option.
	// Radio groups wrap by default, so the zero value keeps the platform
	// convention.
	no_wrap:          bool,
	item_height:      f32,
	item_min_width:   f32,
	item_gap:         f32,
	item_padding:     f32,
	indicator_size:   f32,
	label_size:       f32,
}

DEFAULT_OPTIONS :: Options{
	accessible_label="Option",
	orientation=.Vertical,
	selection_mode=.Follow_Focus,
	item_height=32,
	item_min_width=120,
	item_gap=8,
	item_padding=8,
	indicator_size=18,
	label_size=0,
}

// Recipe declares optional namespaced surface roles. A zero role uses the
// documented core fallback, so first use needs no theme compilation.
Recipe :: struct {
	item_surface_role:     alicorn.Style_Extension_Color_Role_ID,
	selected_surface_role: alicorn.Style_Extension_Color_Role_ID,
	indicator_surface_role: alicorn.Style_Extension_Color_Role_ID,
	selected_indicator_role: alicorn.Style_Extension_Color_Role_ID,
}

DEFAULT_RECIPE :: Recipe{}

// Style carries geometry shared by every radio in one instance.
Style :: struct {
	corner_radius:   f32,
	indicator_radius: f32,
	focus_width:     f32,
}

DEFAULT_STYLE :: Style{
	corner_radius=6,
	focus_width=2,
}

Theme_Contract :: tc.Contract
Theme_Contract_Report :: tc.Report

recipe_default :: proc() -> Recipe { return DEFAULT_RECIPE }
style_default :: proc() -> Style { return DEFAULT_STYLE }

// theme_contract_default requires exactly the extension roles the recipe
// actually configures. Each zero role is documented as a core-role fallback.
theme_contract_default :: proc(recipe: Recipe) -> Theme_Contract {
	contract: Theme_Contract
	optional_role(&contract, recipe.item_surface_role, "alikit.radio_group.item_surface")
	optional_role(&contract, recipe.selected_surface_role, "alikit.radio_group.selected_surface")
	optional_role(&contract, recipe.indicator_surface_role, "alikit.radio_group.indicator_surface")
	optional_role(&contract, recipe.selected_indicator_role, "alikit.radio_group.selected_indicator")
	return contract
}

@(private)
optional_role :: proc(contract: ^Theme_Contract, role: alicorn.Style_Extension_Color_Role_ID, name: string) {
	if role == 0 {
		_ = tc.optional_role(contract, 0, name)
	} else {
		_ = tc.required_role(contract, role, name)
	}
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
	// active_value is the roving focus identity. It is component state, not
	// selection; the selected value stays in the application.
	active_value: u64,
	active_index: int,

	root_node:             alicorn.Node_ID,
	focus_pending:         bool,
	after_frame_registered: bool,

	// proposed is a selection proposed during a description that cannot return
	// it directly (pointer or semantic activation). It is reported by the next
	// group_end call so every input path shares one controlled result.
	proposed:     bool,
	proposed_value: u64,

	// last_orientation is diagnostic state for tests and applications; it is
	// the resolved orientation used by the most recent description.
	last_orientation: Orientation,
}

Event_Kind :: enum { None, Selection_Proposed }

Event :: struct {
	kind:  Event_Kind,
	value: u64,
}

// Group is the per-description group context returned by group_begin. It owns
// no application selection and allocates nothing; the caller-owned State
// remains the only retained interaction state.
Group :: struct {
	ctx:            ^ui.UI,
	state:          ^State,
	options:        []Option,
	selected_value: u64,
	resolved:       Options,
	style:          Style,
	recipe:         Recipe,
	instance_id:    u64,
	root:           alicorn.Node_ID,
	collection:     alicorn.Semantic_Collection_Handle,
	visible:        bool,
}

// Item is the per-description option context returned by item_begin. The
// public fields expose everything a custom appearance needs: the caller-owned
// option, its stable index and position, checked state, roving focus, focus
// visibility, and disabled policy.
Item :: struct {
	group:         ^Group,
	option:        Option,
	index:         int,
	count:         int,
	owner:         alicorn.Node_ID,
	checked:       bool,
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

// group_semantic_id and option_semantic_id are stable across reorder and
// appearance changes. They are public so tests and application interactions
// can target the group or one radio explicitly.
group_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=RADIO_GROUP_NAMESPACE, value=mix(instance_id, 0x47524F5550)}
}

option_semantic_id :: proc(instance_id, value: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || value == 0 { return {} }
	return alicorn.Semantic_ID{namespace=RADIO_GROUP_NAMESPACE, value=mix(instance_id, value)}
}

// instance_from_key derives a stable instance identity when a parts author
// supplies only the UI key. An explicit nonzero instance_id is always
// preferred when the key may change between descriptions.
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

// request_focus asks the next description to focus the group's single Tab
// stop after layout. Safe to call from ordinary application input handling.
request_focus :: proc(state: ^State) -> bool {
	if state == nil { return false }
	state.focus_pending = true
	return true
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.accessible_label == "" { result.accessible_label = DEFAULT_OPTIONS.accessible_label }
	if result.item_height <= 0 || math.is_nan(result.item_height) || math.is_inf(result.item_height) {
		result.item_height = DEFAULT_OPTIONS.item_height
	}
	if result.item_min_width <= 0 || math.is_nan(result.item_min_width) || math.is_inf(result.item_min_width) {
		result.item_min_width = DEFAULT_OPTIONS.item_min_width
	}
	if result.item_gap < 0 || math.is_nan(result.item_gap) || math.is_inf(result.item_gap) {
		result.item_gap = DEFAULT_OPTIONS.item_gap
	}
	if result.item_padding < 0 || math.is_nan(result.item_padding) || math.is_inf(result.item_padding) {
		result.item_padding = DEFAULT_OPTIONS.item_padding
	}
	if result.indicator_size <= 0 || math.is_nan(result.indicator_size) || math.is_inf(result.indicator_size) {
		result.indicator_size = DEFAULT_OPTIONS.indicator_size
	}
	return result
}

@(private)
style_resolve :: proc(style: Style, options: Options) -> Style {
	result := style
	if result.corner_radius < 0 || math.is_nan(result.corner_radius) || math.is_inf(result.corner_radius) {
		result.corner_radius = DEFAULT_STYLE.corner_radius
	}
	if result.indicator_radius < 0 || math.is_nan(result.indicator_radius) || math.is_inf(result.indicator_radius) {
		result.indicator_radius = options.indicator_size*0.5
	}
	if result.focus_width <= 0 || math.is_nan(result.focus_width) || math.is_inf(result.focus_width) {
		result.focus_width = DEFAULT_STYLE.focus_width
	}
	return result
}

@(private)
enabled_at :: proc(options: []Option, index: int) -> bool {
	if index < 0 || index >= len(options) { return false }
	return options[index].value != 0 && !options[index].disabled
}

@(private)
index_of_value :: proc(options: []Option, value: u64) -> int {
	if value == 0 { return -1 }
	for option, index in options {
		if option.value == value { return index }
	}
	return -1
}

@(private)
first_enabled :: proc(options: []Option) -> int {
	for option, index in options {
		if option.value != 0 && !option.disabled { return index }
	}
	return -1
}

@(private)
Radio_Roving :: struct {
	options: []Option,
}

@(private)
radio_enabled :: proc(data: rawptr, index: int) -> bool {
	ctx := cast(^Radio_Roving)data
	return enabled_at(ctx.options, index)
}

@(private)
radio_view :: proc(ctx: ^Radio_Roving, options: []Option, wrap: bool) -> alicorn.Roving_View {
	ctx.options = options
	return alicorn.Roving_View{
		count=len(options),
		enabled=radio_enabled,
		data=rawptr(ctx),
		wrap=wrap,
	}
}

@(private)
set_active :: proc(state: ^State, options: []Option, index: int) {
	if state == nil || index < 0 || index >= len(options) { return }
	state.active_index = index
	state.active_value = options[index].value
}

@(private)
reconcile_active :: proc(state: ^State, options: []Option, selected_value: u64) {
	if state == nil { return }
	if len(options) == 0 {
		state.active_index = -1
		state.active_value = 0
		return
	}
	index := index_of_value(options, state.active_value)
	if index >= 0 && enabled_at(options, index) {
		state.active_index = index
		return
	}
	// Prefer the controlled selection the first time, then repair from the old
	// position. A disabled selection is not focusable.
	index = index_of_value(options, selected_value)
	if index >= 0 && enabled_at(options, index) {
		set_active(state, options, index)
		return
	}
	ctx: Radio_Roving
	view := radio_view(&ctx, options, true)
	start := clamp(state.active_index, 0, len(options)-1)
	index = alicorn.roving_nearest_enabled(view, start, 1)
	if index < 0 { index = first_enabled(options) }
	if index < 0 {
		state.active_index = -1
		state.active_value = 0
		return
	}
	set_active(state, options, index)
}

@(private)
propose :: proc(state: ^State, value: u64) {
	if state == nil || value == 0 { return }
	state.proposed = true
	state.proposed_value = value
}

@(private)
apply_key :: proc(
	state: ^State,
	options: []Option,
	resolved: Options,
	key: alicorn.Application_Key,
) -> bool {
	if state == nil || state.active_index < 0 || state.active_index >= len(options) { return false }
	previous := state.active_index
	if key == .Return || key == .Toggle {
		value := state.active_value
		if value != 0 && enabled_at(options, state.active_index) {
			propose(state, value)
		}
		return true
	}
	move, mapped := alicorn.roving_move_for_key(key)
	if !mapped { return false }
	if move == .Page_Up || move == .Page_Down { return true }
	ctx: Radio_Roving
	view := radio_view(&ctx, options, !resolved.no_wrap)
	if index := alicorn.roving_propose(view, state.active_index, move); index >= 0 {
		set_active(state, options, index)
		if resolved.selection_mode == .Follow_Focus {
			propose(state, options[index].value)
		}
	}
	return state.active_index != previous
}

@(private)
schedule_after_frame :: proc(state: ^State, rt: ^alicorn.Runtime) {
	if state == nil || rt == nil || state.after_frame_registered { return }
	if alicorn.interaction_after_frame_register(rt, rawptr(state), radio_after_frame) {
		state.after_frame_registered = true
	}
}

@(private)
radio_after_frame :: proc(data: rawptr, rt: ^alicorn.Runtime) {
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
surface_or_fallback :: proc(
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
		if id := alicorn.surface_begin(ctx, alicorn.surface_extension_color_role(role), key=key,
			style=style, shape=shape, stroke=stroke, label=label); id != 0 {
			return id
		}
	}
	return alicorn.surface_begin(ctx, alicorn.surface_core_color_role(fallback), key=key,
		style=style, shape=shape, stroke=stroke, label=label)
}

// group_begin opens the group's single focus scope and Radio_Group collection.
// options is the caller-owned keyed option slice; selected_value is the
// application-owned selection. label overrides the accessible label when
// nonempty. When instance_id is zero, a stable identity is derived from key.
//
// The returned Group is a per-description value. Pass its address to
// item_begin and group_end. visible is false when the key scope, runtime, or
// collection is unavailable; call group_end only when visible is true.
group_begin :: proc(
	ctx: ^ui.UI,
	state: ^State,
	options: []Option,
	selected_value: u64,
	label: string = "",
	key: ui.UI_Key = {},
	instance_id: u64 = 0,
	group_options: Options = {},
	recipe: Recipe = {},
	style: Style = {},
) -> (group: Group, visible: bool) {
	if ctx == nil || ctx.runtime == nil || state == nil { return }
	resolved_instance := instance_id
	if resolved_instance == 0 { resolved_instance = instance_from_key(key) }
	if resolved_instance == 0 || resolved_instance > MAX_INSTANCE_ID { return }

	resolved := options_resolve(group_options)
	if label != "" { resolved.accessible_label = label }
	state.last_orientation = resolved.orientation
	resolved_style := style_resolve(style, resolved)
	if !ui.key_scope(ctx, key) { return }

	reconcile_active(state, options, selected_value)
	group = Group{
		ctx=ctx,
		state=state,
		options=options,
		selected_value=selected_value,
		resolved=resolved,
		style=resolved_style,
		recipe=recipe,
		instance_id=resolved_instance,
	}

	state.root_node = 0
	direction := alicorn.Layout_Direction.Column
	align: ui.Align = .Stretch
	if resolved.orientation == .Horizontal {
		direction = .Row
		align = .Center
	}
	root := alicorn.container_begin(
		ctx,
		.Container,
		label=resolved.accessible_label,
		key=alicorn.key_string("alikit-radio-group"),
		style=ui.layout_style(direction, width=-1, height=alicorn.LAYOUT_SIZE_FIT_CONTENT,
			gap=resolved.item_gap, align=align),
		focusable=true,
	)
	if root == 0 { return }
	state.root_node = root
	group.root = root

	selected_id := option_semantic_id(resolved_instance, selected_value)
	if index_of_value(options, selected_value) < 0 { selected_id = {} }
	current_id := option_semantic_id(resolved_instance, state.active_value)
	collection := alicorn.semantic_collection_begin(
		ctx,
		root,
		group_semantic_id(resolved_instance),
		.Radio_Group,
		resolved.accessible_label,
		u64(len(options)),
		selected_id=selected_id,
		current_id=current_id,
		realized_first=0,
		realized_last=u64(len(options)),
	)
	if collection.id.namespace == 0 {
		alicorn.container_end(ctx)
		state.root_node = 0
		group.root = 0
		return
	}
	group.collection = collection
	_ = ui.interaction_scope(ctx, root, rawptr(state), alicorn.Interaction_Scope_Options{
		keys={.Left, .Right, .Up, .Down, .Home, .End, .Return, .Toggle},
		composition_yield_keys={.Left, .Right, .Up, .Down, .Home, .End, .Return, .Toggle},
	})
	for {
		queued, found := alicorn.interaction_event_next(ctx.runtime, root)
		if !found { break }
		if queued.kind == .Key && apply_key(state, options, resolved, queued.key) {
			alicorn.invalidate_root(ctx.runtime, "radio group keyboard navigation")
		}
	}
	group.visible = true
	return group, true
}

// item_begin opens one Radio_Button owner and publishes its Radio_Button
// semantic item. It returns visible=false for an invalid group, an unknown or
// zero option value, or a failed Button owner; in that case the author skips
// both the visual subtree and its semantics, and must not call item_end.
//
// item_style defaults to the group's orientation geometry. Pass an ordinary
// ui.layout_style value to own the item's outer width, height, direction,
// padding, gap, and alignment. The Button owner remains the semantic and hit
// owner regardless of the visual tree inside it.
item_begin :: proc(
	ctx: ^ui.UI,
	group: ^Group,
	option: Option,
	item_style: ui.Layout_Style = {},
) -> (item: Item, visible: bool) {
	if ctx == nil || ctx.runtime == nil || group == nil || !group.visible { return }
	index := index_of_value(group.options, option.value)
	// A disabled option is a valid semantic item; only an unknown or zero value
	// is skipped.
	if index < 0 { return }

	resolved := group.resolved
	state := group.state
	checked := option.value != 0 && option.value == group.selected_value
	active := index == state.active_index
	root_focused := state.root_node != 0 && alicorn.focused_node(ctx.runtime) == state.root_node
	style := item_style
	if style == (ui.Layout_Style{}) {
		style = ui.layout_style(.Row,
			width=resolved.item_min_width if resolved.orientation == .Horizontal else -1,
			height=resolved.item_height,
			grow=1 if resolved.orientation == .Vertical else 0)
	}
	owner, activated := alicorn.button_begin(
		ctx,
		option.label,
		key=ui.key_pair(ITEM_KEY, option.value),
		style=style,
		state=alicorn.Button_State{selected=checked, disabled=option.disabled},
		presentation=.Custom,
		focusable=false,
	)
	if owner == 0 { return }

	states := alicorn.Semantic_States{}
	actions := alicorn.Semantic_Actions{}
	if option.disabled { states = alicorn.semantic_states_add(states, .Disabled) }
	if checked {
		states = alicorn.semantic_states_add(states, .Checked)
		states = alicorn.semantic_states_add(states, .Selected)
	}
	if active { states = alicorn.semantic_states_add(states, .Current) }
	if !option.disabled {
		actions = alicorn.semantic_actions_add(actions, .Press)
		actions = alicorn.semantic_actions_add(actions, .Focus)
	}
	_ = alicorn.semantic_collection_item(ctx, group.collection, u64(index), alicorn.Semantic_Node_Description{
		id=option_semantic_id(group.instance_id, option.value),
		role=.Radio_Button,
		label=option.label,
		description=option.description,
		value=option.label,
		states=states,
		actions=actions,
		visual_node=owner,
	})

	item = Item{
		group=group,
		option=option,
		index=index,
		count=len(group.options),
		owner=owner,
		checked=checked,
		focused=active,
		focus_visible=active && root_focused,
		disabled=option.disabled,
		visible=true,
		activated=activated,
	}
	return item, true
}

// indicator draws the default radio indicator and, when checked, its dot. It is
// optional: omit it and draw any surface, icon, image, or animated visual
// inside the item. The semantic item and interaction owner are already
// published by item_begin.
indicator :: proc(ctx: ^ui.UI, item: Item) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !item.visible || item.group == nil { return 0 }
	group := item.group
	resolved := group.resolved
	recipe := group.recipe
	indicator := surface_or_fallback(
		ctx,
		recipe.indicator_surface_role,
		.Subtle_Surface,
		key=ui.key_u64(2),
		style=ui.layout_style(.Row, width=resolved.indicator_size, height=resolved.indicator_size,
			align=.Center, justify=.Center),
		shape=alicorn.Surface_Shape{kind=.Circle},
		stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Border), width=1},
		label="radio-indicator",
	)
	if indicator == 0 { return 0 }
	_ = alicorn.visual_part_attach(ctx, indicator, item.owner, alicorn.visual_part_core(.Indicator))
	if item.checked {
		inner_size := max(resolved.indicator_size*0.46, 4)
		dot := surface_or_fallback(
			ctx,
			recipe.selected_indicator_role,
			.Accent,
			key=ui.key_u64(3),
			style=ui.layout_style(.Row, width=inner_size, height=inner_size),
			shape=alicorn.Surface_Shape{kind=.Circle},
			stroke={},
			label="radio-selected-dot",
		)
		if dot != 0 {
			_ = alicorn.visual_part_attach(ctx, dot, item.owner, alicorn.visual_part_core(.Selected_Indicator))
			alicorn.surface_end(ctx)
		}
	}
	alicorn.surface_end(ctx)
	return indicator
}

// label draws the option label as the default text part. Omit it for a custom
// title/price/description layout inside the same item owner.
label :: proc(ctx: ^ui.UI, item: Item, text: string = "") -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !item.visible || item.group == nil { return 0 }
	value := text
	if value == "" { value = item.option.label }
	text_color := alicorn.style_color(ctx, .Text)
	if item.disabled { text_color = alicorn.style_color(ctx, .Muted_Text) }
	label_id := ui.text(ctx, value,
		key=ui.key_u64(4),
		style=ui.layout_style(.Row, grow=1),
		color=text_color,
		size=item.group.resolved.label_size,
		decorative=true,
		text_style=alicorn.Text_Style{overflow=.Ellipsis},
	)
	if label_id != 0 {
		_ = alicorn.visual_part_attach(ctx, label_id, item.owner, alicorn.visual_part_core(.Label))
	}
	return label_id
}

// item_end closes the item's Button owner and records a pointer or semantic
// activation as the group's one pending selection proposal. Call it only when
// item_begin returned visible=true.
item_end :: proc(ctx: ^ui.UI, item: Item) {
	if ctx == nil || !item.visible { return }
	alicorn.button_end(ctx)
	if item.activated && !item.disabled {
		propose(item.group.state, item.option.value)
	}
}

// group_end closes the group's collection scope and returns the one selection
// proposal produced by this description, if any. It also schedules a pending
// focus request.
group_end :: proc(ctx: ^ui.UI, group: ^Group) -> (event: Event) {
	if ctx == nil || group == nil || group.root == 0 { return }
	if group.state != nil && group.state.proposed {
		group.state.proposed = false
		event = Event{kind=.Selection_Proposed, value=group.state.proposed_value}
	}
	alicorn.container_end(ctx)
	if group.state != nil && group.state.focus_pending {
		schedule_after_frame(group.state, ctx.runtime)
	}
	group.visible = false
	group.root = 0
	return
}

// radio_group is the convenience component built from the exact public parts.
// selected_value is the application-owned selection and is never mutated. The
// returned event is the one proposed selection change for this description, if
// any. instance_id must be stable and unique among simultaneously mounted
// groups.
radio_group :: proc(
	ctx: ^ui.UI,
	state: ^State,
	options: []Option,
	selected_value: u64,
	group_options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
	recipe: Recipe = {},
	style: Style = {},
) -> (event: Event) {
	group, visible := group_begin(
		ctx,
		state,
		options,
		selected_value,
		label=group_options.accessible_label,
		key=key,
		instance_id=instance_id,
		group_options=group_options,
		recipe=recipe,
		style=style,
	)
	if !visible { return }
	for option in options {
		item, item_visible := item_begin(ctx, &group, option)
		if !item_visible { continue }
		indicator(ctx, item)
		label(ctx, item)
		item_end(ctx, item)
	}
	return group_end(ctx, &group)
}
