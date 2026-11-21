package palette_parts

// Palette Parts is a copyable, parts-based variant of the command palette
// result list. It owns only the reusable list interaction: a retained virtual
// list, a published List_Box collection, enabled-item navigation, reveal, and
// one activation event. The application still owns the query, matching,
// ranking, commands, modal shell, and focus restoration.
//
// It deliberately does not wrap `alikit:command_palette`. The package exists to
// show which pieces of that component are ordinary public Alicorn facilities
// and which policy remains application-owned. See
// docs/research/issue-003-parts-pilot.md for the stock-vs-parts measurement.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import palette "alikit:palette_model"

Item :: palette.Item
Item_ID :: palette.Item_ID
Match :: palette.Match
Selection :: palette.Selection

PALETTE_PARTS_NAMESPACE :: u64(0x50414C5041525453)
RESULTS_ROW_KEY :: u64(0xA11C_9A01)

Event_Kind :: enum { None, Activated }

Event :: struct {
	kind:    Event_Kind,
	item_id: Item_ID,
}

Options :: struct {
	accessible_label:   string,
	empty_label:        string,
	row_height:         f32,
	list_max_height:    f32,
	semantic_namespace: u64,
	focus_on_pointer:   bool,
}

DEFAULT_OPTIONS :: Options{
	accessible_label="Results",
	empty_label="No matching items",
	row_height=38,
	list_max_height=320,
	focus_on_pointer=true,
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.accessible_label == "" { result.accessible_label = DEFAULT_OPTIONS.accessible_label }
	if result.empty_label == "" { result.empty_label = DEFAULT_OPTIONS.empty_label }
	if result.row_height <= 0 || math.is_nan(result.row_height) || math.is_inf(result.row_height) {
		result.row_height = DEFAULT_OPTIONS.row_height
	}
	if result.list_max_height <= 0 || math.is_nan(result.list_max_height) || math.is_inf(result.list_max_height) {
		result.list_max_height = DEFAULT_OPTIONS.list_max_height
	}
	return result
}

State :: struct {
	// selection is the component-visible row. The application reads it for
	// commands and may set it before calling results.
	selection: Selection,
	// selection_index is the selected position in the caller's current visible
	// slice. It is derived, never identity: the stable ID remains selection.id.
	selection_index: int,
	// list_node is the retained focus owner for keyboard navigation.
	list_node:  alicorn.Node_ID,
	namespace:  u64,
	// reveal_pending asks the next after-frame hook to scroll the selected row
	// into view. This is a retained scroll request, not a second layout pass.
	reveal_pending: bool,
	// focus_pending is set by request_focus and consumed after the node exists.
	focus_pending:       bool,
	after_frame_registered: bool,
}

@(private)
mix :: proc(seed, value: u64) -> u64 {
	state := seed+value+0x9E3779B97F4A7C15
	state = (state ~ (state>>30))*0xBF58476D1CE4E5B9
	state = (state ~ (state>>27))*0x94D049BB133111EB
	return state ~ (state>>31)
}

// item_semantic_id derives a stable row identity from the instance namespace
// and the application-owned stable item ID. It is public so applications can
// target a row with an explicit semantic action or reveal request.
item_semantic_id :: proc(namespace: u64, id: Item_ID) -> alicorn.Semantic_ID {
	if namespace == 0 || id == palette.Item_ID(0) { return {} }
	return alicorn.Semantic_ID{namespace=namespace, value=mix(namespace, u64(id))}
}

// list_semantic_id derives the List_Box identity for one instance.
list_semantic_id :: proc(namespace: u64) -> alicorn.Semantic_ID {
	if namespace == 0 { return {} }
	return alicorn.Semantic_ID{namespace=namespace, value=mix(namespace, 0x4C495354424F58)}
}

selection_id :: proc(state: ^State) -> Item_ID {
	return state.selection.id if state != nil else palette.Item_ID(0)
}

@(private)
first_enabled :: proc(items: []Item, visible: []Match, reverse := false) -> (Item_ID, int, bool) {
	if reverse {
		for index := len(visible)-1; index >= 0; index -= 1 {
			match := visible[index]
			if match.item_index < 0 || match.item_index >= len(items) { continue }
			item := items[match.item_index]
			if item.id != palette.Item_ID(0) && !item.disabled { return item.id, index, true }
		}
		return palette.Item_ID(0), -1, false
	}
	for match, index in visible {
		if match.item_index < 0 || match.item_index >= len(items) { continue }
		item := items[match.item_index]
		if item.id != palette.Item_ID(0) && !item.disabled { return item.id, index, true }
	}
	return palette.Item_ID(0), -1, false
}

@(private)
schedule_after_frame :: proc(state: ^State, rt: ^alicorn.Runtime) {
	if state == nil || rt == nil || state.after_frame_registered { return }
	if alicorn.interaction_after_frame_register(rt, rawptr(state), parts_after_frame) {
		state.after_frame_registered = true
	}
}

@(private)
parts_after_frame :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	state := cast(^State)data
	if state == nil || rt == nil { return }
	state.after_frame_registered = false
	if state.focus_pending && state.list_node != 0 {
		if alicorn.focus(rt, state.list_node) {
			state.focus_pending = false
			alicorn.focus_indicator_set(rt, true)
		}
	}
	if state.reveal_pending && state.list_node != 0 {
		if state.selection_index >= 0 {
			_ = alicorn.virtual_list_ensure_visible(rt, state.list_node, state.selection_index,
				"AliKit palette parts selection visibility")
		}
		state.reveal_pending = false
	}
}

// selection_visible_index reports the selected row's position in a caller's
// current visible slice, or -1 when the stable ID is not visible. It owns no
// state and is useful when an application pages or re-ranks its own results.
selection_visible_index :: proc(items: []Item, visible: []Match, state: ^State) -> int {
	if state == nil { return -1 }
	return visible_index_of(items, visible, state.selection.id)
}

// request_focus asks the component to focus its retained list after the next
// reconciled description. Call it from application input handling, not while
// describing a child of this list.
request_focus :: proc(state: ^State) -> bool {
	if state == nil { return false }
	state.focus_pending = true
	return true
}

@(private)
visible_index_of :: proc(items: []Item, visible: []Match, id: Item_ID) -> int {
	for match, index in visible {
		if match.item_index < 0 || match.item_index >= len(items) { continue }
		if items[match.item_index].id == id { return index }
	}
	return -1
}

// handle_key applies palette navigation to caller-owned matches. It is the
// path an application uses when its query field owns keyboard focus; the same
// function processes retained scoped input when the list itself is focused.
handle_key :: proc(
	state: ^State,
	rt: ^alicorn.Runtime,
	items: []Item,
	visible: []Match,
	key: alicorn.Application_Key,
) -> (handled: bool, event: Event) {
	if state == nil || rt == nil { return }
	_ = palette.reconcile(&state.selection, items, visible)
	state.selection_index = visible_index_of(items, visible, state.selection.id)
	#partial switch key {
	case .Up, .Down:
		delta := -1 if key == .Up else 1
		if palette.move(&state.selection, items, visible, delta) {
			state.reveal_pending = true
			alicorn.invalidate_root(rt, "AliKit palette parts selection moved")
		}
		state.selection_index = visible_index_of(items, visible, state.selection.id)
		if state.reveal_pending || state.focus_pending { schedule_after_frame(state, rt) }
		return true, {}
	case .Home, .End:
		id, index, found := first_enabled(items, visible, key == .End)
		if found && state.selection.id != id {
			state.selection.id = id
			state.reveal_pending = true
			alicorn.invalidate_root(rt, "AliKit palette parts selection moved")
		}
		state.selection_index = index
		if state.reveal_pending || state.focus_pending { schedule_after_frame(state, rt) }
		return true, {}
	case .Return:
		if id, ok := palette.activate(state.selection, items, visible); ok {
			return true, Event{kind=.Activated, item_id=id}
		}
		return true, {}
	}
	return false, {}
}

// results describes the parts-based result list. It borrows items and visible
// for this call; both may be rebuilt between input turns. The application owns
// filtering and ranking, and receives one activation event to dispatch.
results :: proc(
	ctx: ^ui.UI,
	state: ^State,
	items: []Item,
	visible: []Match,
	key: ui.UI_Key,
	options: Options = {},
) -> (event: Event) {
	if ctx == nil || ctx.runtime == nil || state == nil { return }
	resolved := options_resolve(options)
	if !ui.key_scope(ctx, key) { return }
	previous_list := state.list_node
	if previous_list != 0 {
		if queued, found := alicorn.interaction_event_next(ctx.runtime, previous_list); found {
			if queued.kind == .Key {
				_, event = handle_key(state, ctx.runtime, items, visible, queued.key)
			}
		}
	}
	_ = palette.reconcile(&state.selection, items, visible)
	state.selection_index = visible_index_of(items, visible, state.selection.id)
	state.list_node = 0
	if len(visible) == 0 {
		_ = ui.text(ctx, resolved.empty_label, key=alicorn.key_string("alikit-palette-parts-empty"))
		if state.focus_pending { schedule_after_frame(state, ctx.runtime) }
		return
	}
	list := alicorn.virtual_list_begin(
		ctx,
		len(visible),
		resolved.row_height,
		key=alicorn.key_string("alikit-palette-parts-list"),
		style=ui.layout_style(.Column, height=alicorn.LAYOUT_SIZE_FIT_CONTENT,
			max_height=resolved.list_max_height, grow=1, clip=true),
		label=resolved.accessible_label,
		focusable=true,
	)
	state.list_node = list.scroll.id
	if list.scroll.id == 0 { return }
	if state.namespace == 0 {
		state.namespace = resolved.semantic_namespace
		if state.namespace == 0 {
			state.namespace = u64(list.scroll.id) ~ PALETTE_PARTS_NAMESPACE
			if state.namespace == 0 { state.namespace = PALETTE_PARTS_NAMESPACE }
		}
	}
	_ = ui.interaction_scope(ctx, list.scroll.id, rawptr(state), alicorn.Interaction_Scope_Options{
		keys={.Up, .Down, .Home, .End, .Return},
		composition_yield_keys={.Up, .Down, .Home, .End, .Return},
	})
	selected_id := item_semantic_id(state.namespace, state.selection.id)
	collection := alicorn.semantic_collection_begin(
		ctx,
		list.scroll.id,
		list_semantic_id(state.namespace),
		.List_Box,
		resolved.accessible_label,
		u64(len(visible)),
		selected_id=selected_id,
		current_id=selected_id,
		realized_first=u64(list.first),
		realized_last=u64(list.last),
	)
	if list.scroll.id != 0 {
		for index := list.first; index < list.last; index += 1 {
			match := visible[index]
			if match.item_index < 0 || match.item_index >= len(items) { continue }
			item := items[match.item_index]
			if row_event := row_build(ctx, state, item, index, collection, resolved); row_event.kind != .None {
				event = row_event
			}
		}
		alicorn.virtual_list_end(ctx, list)
	}
	if event.kind == .Activated {
		alicorn.invalidate_root(ctx.runtime, "AliKit palette parts item activated")
	}
	if state.reveal_pending || state.focus_pending {
		schedule_after_frame(state, ctx.runtime)
	}
	return
}

@(private)
row_build :: proc(
	ctx: ^ui.UI,
	state: ^State,
	item: Item,
	index: int,
	collection: alicorn.Semantic_Collection_Handle,
	options: Options,
) -> Event {
	selected := state.selection.id == item.id
	owner, activated := alicorn.button_begin(
		ctx,
		item.title,
		key=ui.key_pair(RESULTS_ROW_KEY, u64(item.id)),
		style=ui.layout_style(.Row, height=options.row_height),
		state=alicorn.Button_State{selected=selected, disabled=item.disabled},
		presentation=.Custom,
		focusable=false,
	)
	if owner == 0 { return {} }
	states := alicorn.Semantic_States{}
	actions := alicorn.Semantic_Actions{}
	if item.disabled { states = alicorn.semantic_states_add(states, .Disabled) }
	if selected {
		states = alicorn.semantic_states_add(states, .Selected)
		states = alicorn.semantic_states_add(states, .Current)
	}
	if !item.disabled {
		actions = alicorn.semantic_actions_add(actions, .Select)
		actions = alicorn.semantic_actions_add(actions, .Focus)
	}
	_ = alicorn.semantic_collection_item(ctx, collection, u64(index), alicorn.Semantic_Node_Description{
		id=item_semantic_id(state.namespace, item.id),
		role=.List_Box_Option,
		label=item.title,
		description=item.description,
		value=item.title,
		states=states,
		actions=actions,
	})
	text_color := alicorn.style_color(ctx, .Text)
	if item.disabled { text_color = alicorn.style_color(ctx, .Muted_Text) }
	row_fill := alicorn.style_color(ctx, .Surface)
	if selected { row_fill = alicorn.style_color(ctx, .Selection) }
	row := alicorn.surface_begin(
		ctx,
		alicorn.surface_core_color_role(.Surface),
		key=ui.key_u64(1),
		style=ui.layout_style(.Row, width=-1, height=options.row_height-2, padding=8, gap=8, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=5},
		fill=row_fill,
		label="palette-parts-row",
	)
	if row != 0 {
		leading := ui.box(ctx, key=ui.key_u64(2), size=16, fill=alicorn.style_color(ctx, .Accent), radius=4)
		if leading != 0 {
			_ = alicorn.visual_part_attach(ctx, leading, owner, alicorn.visual_part_core(.Icon))
		}
		label := ui.text(ctx, item.title,
			key=ui.key_u64(3),
			style=ui.layout_style(.Row, grow=1),
			color=text_color,
			decorative=true,
			text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_MEDIUM, overflow=.Ellipsis},
		)
		if label != 0 { _ = alicorn.visual_part_attach(ctx, label, owner, alicorn.visual_part_core(.Label)) }
		if item.description != "" {
			description := ui.text(ctx, item.description,
				key=ui.key_u64(4),
				style=ui.layout_style(.Row),
				color=alicorn.style_color(ctx, .Muted_Text),
				decorative=true,
				text_style=alicorn.Text_Style{overflow=.Ellipsis},
			)
			if description != 0 {
				_ = alicorn.visual_part_attach(ctx, description, owner, alicorn.visual_part_core(.Content))
			}
		}
		if selected {
			check := ui.icon(ctx, .Check, key=ui.key_u64(5), size=14, color_role=.Text)
			if check != 0 {
				_ = alicorn.visual_part_attach(ctx, check, owner, alicorn.visual_part_core(.Selected_Indicator))
			}
		}
		alicorn.surface_end(ctx)
	}
	alicorn.button_end(ctx)
	if activated && !item.disabled {
		state.selection.id = item.id
		return Event{kind=.Activated, item_id=item.id}
	}
	return {}
}
