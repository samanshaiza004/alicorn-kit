package palette_parts

// Palette Parts is a copyable, parts-based result list for command palettes and
// other enabled-row list surfaces. It owns only the reusable list interaction:
// a retained virtual list, a published List_Box collection, enabled-item
// navigation, reveal, group scaffolding, optional default row visuals, and one
// activation event. The application still owns the query, matching, ranking,
// commands, modal shell, and focus restoration.
//
// Authors can use the complete results() helper or compose the parts:
//
//	list, visible := parts.list_begin(ctx, &state, items, matches, key, options)
//	if visible {
//		for index := list.first; index < list.last; index += 1 {
//			row, row_visible := parts.item_begin(ctx, &list, index)
//			if row_visible {
//				if parts.row_surface(ctx, row) != 0 {
//					parts.icon(ctx, row)        // optional
//					parts.label(ctx, row)       // optional
//					parts.description(ctx, row) // optional
//					parts.indicator(ctx, row)   // optional selected check
//					alicorn.surface_end(ctx)
//				}
//				parts.item_end(ctx, &list, row)
//			}
//		}
//		event = parts.list_end(ctx, &list)
//	} else {
//		parts.empty(ctx, options)
//	}
//
// Everything between item_begin and item_end belongs to the author. The parts
// retain List_Box/List_Box_Option semantics, selection by stable Item_ID,
// enabled-row navigation, reveal, and one activation proposal. The application
// still owns filtering/ranking and dispatch.

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

// List is the per-description result-list context returned by list_begin. It
// borrows the caller's item and match slices for the description only.
List :: struct {
	ctx:        ^ui.UI,
	state:      ^State,
	items:      []Item,
	visible:    []Match,
	options:    Options,
	node:       alicorn.Node_ID,
	virtual:    alicorn.Virtual_List_Handle,
	collection: alicorn.Semantic_Collection_Handle,
	namespace:  u64,
	first:      int,
	last:       int,
	// current_group is the semantic Group parent for rows between
	// group_begin and group_end. Zero means rows parent to the List_Box.
	current_group: alicorn.Semantic_ID,
	event:        Event,
	opened:       bool,
}

// Row is the per-description row context returned by item_begin.
Row :: struct {
	list:      ^List,
	item:      Item,
	index:     int,
	count:     int,
	owner:     alicorn.Node_ID,
	selected:  bool,
	disabled:  bool,
	visible:   bool,
	activated: bool,
}

// Group is the per-description group context returned by group_begin.
Group :: struct {
	list:    ^List,
	label:   string,
	id:      alicorn.Semantic_ID,
	header:  alicorn.Node_ID,
	visible: bool,
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

// group_semantic_id derives a stable semantic Group identity for one group.
group_semantic_id :: proc(namespace: u64, key: u64) -> alicorn.Semantic_ID {
	if namespace == 0 || key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=namespace, value=mix(namespace, key ~ 0x475250)}
}

// row_key returns the retained Button key for one stable item. Applications
// that need to target or measure a realized row can use this instead of
// duplicating the component's key pair.
row_key :: proc(id: Item_ID) -> ui.UI_Key {
	return ui.key_pair(RESULTS_ROW_KEY, u64(id))
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

// empty draws the configured empty-result label. Use it when a list has no
// visible rows; it owns no retained node.
empty :: proc(ctx: ^ui.UI, options: Options = {}, key: ui.UI_Key = {}) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil { return 0 }
	resolved := options_resolve(options)
	text_key := key
	if text_key == (ui.UI_Key{}) { text_key = alicorn.key_string("alikit-palette-parts-empty") }
	return ui.text(ctx, resolved.empty_label, key=text_key)
}

// list_begin opens the retained virtual list, its single interaction scope,
// and the List_Box collection. It processes queued scoped input from the
// previous description, reconciles selection by stable ID, and returns
// visible=false when there is no visible row or the list cannot open. Call
// empty for the no-results presentation.
list_begin :: proc(
	ctx: ^ui.UI,
	state: ^State,
	items: []Item,
	visible: []Match,
	key: ui.UI_Key,
	options: Options = {},
) -> (list: List, ok: bool) {
	if ctx == nil || ctx.runtime == nil || state == nil { return }
	resolved := options_resolve(options)
	if !ui.key_scope(ctx, key) { return }
	pending_event: Event
	previous_list := state.list_node
	if previous_list != 0 {
		if queued, found := alicorn.interaction_event_next(ctx.runtime, previous_list); found {
			if queued.kind == .Key {
				_, pending_event = handle_key(state, ctx.runtime, items, visible, queued.key)
			}
		}
	}
	_ = palette.reconcile(&state.selection, items, visible)
	state.selection_index = visible_index_of(items, visible, state.selection.id)
	state.list_node = 0
	if len(visible) == 0 { return list, false }

	virtual := alicorn.virtual_list_begin(
		ctx,
		len(visible),
		resolved.row_height,
		key=alicorn.key_string("alikit-palette-parts-list"),
		style=ui.layout_style(.Column, height=alicorn.LAYOUT_SIZE_FIT_CONTENT,
			max_height=resolved.list_max_height, grow=1, clip=true),
		label=resolved.accessible_label,
		focusable=true,
	)
	state.list_node = virtual.scroll.id
	if virtual.scroll.id == 0 { return list, false }
	if state.namespace == 0 {
		state.namespace = resolved.semantic_namespace
		if state.namespace == 0 {
			state.namespace = u64(virtual.scroll.id) ~ PALETTE_PARTS_NAMESPACE
			if state.namespace == 0 { state.namespace = PALETTE_PARTS_NAMESPACE }
		}
	}
	_ = ui.interaction_scope(ctx, virtual.scroll.id, rawptr(state), alicorn.Interaction_Scope_Options{
		keys={.Up, .Down, .Home, .End, .Return},
		composition_yield_keys={.Up, .Down, .Home, .End, .Return},
	})
	selected_id := item_semantic_id(state.namespace, state.selection.id)
	collection := alicorn.semantic_collection_begin(
		ctx,
		virtual.scroll.id,
		list_semantic_id(state.namespace),
		.List_Box,
		resolved.accessible_label,
		u64(len(visible)),
		selected_id=selected_id,
		current_id=selected_id,
		realized_first=u64(virtual.first),
		realized_last=u64(virtual.last),
	)
	list = List{
		ctx=ctx,
		state=state,
		items=items,
		visible=visible,
		options=resolved,
		node=virtual.scroll.id,
		virtual=virtual,
		collection=collection,
		namespace=state.namespace,
		first=virtual.first,
		last=virtual.last,
		event=pending_event,
		opened=true,
	}
	return list, true
}

// group_begin opens an optional single-level semantic Group and draws its
// header. Groups require the complete visible slice to be realized: the
// virtual list uses a uniform row track and group headers do not consume a
// collection position, so a windowed list with groups would misplace the
// scroll metric. For short lists this gives real Group semantics; long lists
// should keep a flat result set. group_end closes the group scope.
group_begin :: proc(
	ctx: ^ui.UI,
	list: ^List,
	label: string,
	key: ui.UI_Key = {},
) -> (group: Group, visible: bool) {
	if ctx == nil || ctx.runtime == nil || list == nil || !list.opened || label == "" { return }
	if list.last-list.first != len(list.visible) { return }
	group_key := mix(list.namespace, u64(len(label)+1))
	switch value in key {
	case u64: group_key = mix(group_key, value)
	case alicorn.UI_Key_Pair: group_key = mix(group_key, value.first ~ value.second)
	case string:
		hash := u64(0xCBF29CE484222325)
		for byte in value { hash = (hash ~ u64(byte))*0x100000001B3 }
		group_key = mix(group_key, hash)
	case alicorn.UI_Unkeyed:
	}
	id := group_semantic_id(list.namespace, group_key)
	if id.namespace == 0 { return }
	header := ui.text(ctx, label, key=ui.key_pair(0xA11C_9A10, group_key),
		style=ui.layout_style(.Row, height=list.options.row_height, padding=8, align=.Center),
		size=11, color=alicorn.style_color(ctx, .Muted_Text), decorative=true)
	if header == 0 { return }
	_ = alicorn.semantic_collection_item(ctx, list.collection, 0, alicorn.Semantic_Node_Description{
		id=id,
		role=.Group,
		label=label,
		value=label,
		parent=list.collection.id,
		visual_node=header,
	})
	list.current_group = id
	group = Group{list=list, label=label, id=id, header=header, visible=true}
	return group, true
}

group_end :: proc(ctx: ^ui.UI, group: ^Group) {
	if ctx == nil || group == nil || !group.visible || group.list == nil { return }
	group.list.current_group = {}
	group.visible = false
}

// item_begin opens one realized row's Button owner and publishes its
// List_Box_Option semantic item. index is a position in the caller's visible
// match slice. It returns visible=false for an invalid list, a match or item
// that is out of range, a zero item ID, or a failed Button owner; in that case
// the author must skip the visual subtree and not call item_end.
item_begin :: proc(ctx: ^ui.UI, list: ^List, index: int) -> (row: Row, visible: bool) {
	if ctx == nil || ctx.runtime == nil || list == nil || !list.opened { return }
	if index < 0 || index >= len(list.visible) { return }
	match := list.visible[index]
	if match.item_index < 0 || match.item_index >= len(list.items) { return }
	item := list.items[match.item_index]
	if item.id == palette.Item_ID(0) { return }
	selected := list.state.selection.id == item.id
	owner, activated := alicorn.button_begin(
		ctx,
		item.title,
		key=row_key(item.id),
		style=ui.layout_style(.Row, height=list.options.row_height),
		state=alicorn.Button_State{selected=selected, disabled=item.disabled},
		presentation=.Custom,
		focusable=false,
	)
	if owner == 0 { return }
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
	_ = alicorn.semantic_collection_item(ctx, list.collection, u64(index), alicorn.Semantic_Node_Description{
		id=item_semantic_id(list.namespace, item.id),
		role=.List_Box_Option,
		label=item.title,
		description=item.description,
		value=item.title,
		states=states,
		actions=actions,
		parent=list.current_group,
	})
	row = Row{
		list=list,
		item=item,
		index=index,
		count=len(list.visible),
		owner=owner,
		selected=selected,
		disabled=item.disabled,
		visible=true,
		activated=activated,
	}
	return row, true
}

// row_surface draws the default rounded row background and selected fill.
// Close it with alicorn.surface_end after the row parts or custom content.
row_surface :: proc(ctx: ^ui.UI, row: Row) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible || row.list == nil { return 0 }
	row_fill := alicorn.style_color(ctx, .Surface)
	if row.selected { row_fill = alicorn.style_color(ctx, .Selection) }
	surface := alicorn.surface_begin(
		ctx,
		alicorn.surface_core_color_role(.Surface),
		key=ui.key_u64(1),
		style=ui.layout_style(.Row, width=-1, height=row.list.options.row_height-2, grow=1,
			padding=8, gap=8, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=5},
		fill=row_fill,
		label="palette-parts-row",
	)
	return surface
}

// icon draws the default leading accent box. It is optional.
icon :: proc(ctx: ^ui.UI, row: Row) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible { return 0 }
	leading := ui.box(ctx, key=ui.key_u64(2), size=16,
		fill=alicorn.style_color(ctx, .Accent), radius=4)
	if leading != 0 { _ = alicorn.visual_part_attach(ctx, leading, row.owner, alicorn.visual_part_core(.Icon)) }
	return leading
}

// label draws the default item title. It is optional.
label :: proc(ctx: ^ui.UI, row: Row, text: string = "") -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible { return 0 }
	value := text
	if value == "" { value = row.item.title }
	text_color := alicorn.style_color(ctx, .Text)
	if row.disabled { text_color = alicorn.style_color(ctx, .Muted_Text) }
	label := ui.text(ctx, value,
		key=ui.key_u64(3),
		style=ui.layout_style(.Row, grow=1),
		color=text_color,
		decorative=true,
		text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_MEDIUM, overflow=.Ellipsis},
	)
	if label != 0 { _ = alicorn.visual_part_attach(ctx, label, row.owner, alicorn.visual_part_core(.Label)) }
	return label
}

// description draws the default secondary description. It is optional.
description :: proc(ctx: ^ui.UI, row: Row, text: string = "") -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible { return 0 }
	value := text
	if value == "" { value = row.item.description }
	if value == "" { return 0 }
	description := ui.text(ctx, value,
		key=ui.key_u64(4),
		style=ui.layout_style(.Row),
		color=alicorn.style_color(ctx, .Muted_Text),
		decorative=true,
		text_style=alicorn.Text_Style{overflow=.Ellipsis},
	)
	if description != 0 {
		_ = alicorn.visual_part_attach(ctx, description, row.owner, alicorn.visual_part_core(.Content))
	}
	return description
}

// indicator draws the default selected checkmark. It is optional and draws
// nothing for an unselected row.
indicator :: proc(ctx: ^ui.UI, row: Row) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || !row.visible || !row.selected { return 0 }
	check := ui.icon(ctx, .Check, key=ui.key_u64(5), size=14, color_role=.Text)
	if check != 0 { _ = alicorn.visual_part_attach(ctx, check, row.owner, alicorn.visual_part_core(.Selected_Indicator)) }
	return check
}

// item_end closes the row's Button owner. Pointer or semantic activation
// becomes the list's one pending activation event. It returns true when the
// row activated.
item_end :: proc(ctx: ^ui.UI, list: ^List, row: Row) -> bool {
	if ctx == nil || !row.visible || list == nil { return false }
	alicorn.button_end(ctx)
	if row.activated && !row.disabled {
		list.state.selection.id = row.item.id
		list.event = Event{kind=.Activated, item_id=row.item.id}
		return true
	}
	return false
}

// list_end closes the virtual list and returns the one activation event for
// this description, if any.
list_end :: proc(ctx: ^ui.UI, list: ^List) -> (event: Event) {
	if ctx == nil || list == nil || !list.opened { return }
	alicorn.virtual_list_end(ctx, list.virtual)
	list.opened = false
	if list.event.kind == .Activated {
		event = list.event
		alicorn.invalidate_root(ctx.runtime, "AliKit palette parts item activated")
	}
	return
}

// results describes the parts-based result list with the default row visuals.
// It borrows items and visible for this call; both may be rebuilt between
// input turns. The application owns filtering and ranking, and receives one
// activation event to dispatch.
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
	list, opened := list_begin(ctx, state, items, visible, key, resolved)
	if !opened {
		_ = empty(ctx, resolved)
		if state.focus_pending || state.reveal_pending { schedule_after_frame(state, ctx.runtime) }
		return
	}
	for index in list.first..<list.last {
		row, row_visible := item_begin(ctx, &list, index)
		if !row_visible { continue }
		if surface := row_surface(ctx, row); surface != 0 {
			icon(ctx, row)
			label(ctx, row)
			description(ctx, row)
			indicator(ctx, row)
			alicorn.surface_end(ctx)
		}
		if item_end(ctx, &list, row) {
			event = Event{kind=.Activated, item_id=row.item.id}
		}
	}
	end_event := list_end(ctx, &list)
	if end_event.kind == .Activated { event = end_event }
	if state.reveal_pending || state.focus_pending {
		schedule_after_frame(state, ctx.runtime)
	}
	return
}
