package icon_picker

// Icon Picker is a complete, copyable custom composite built from public parts.
// It is deliberately a normal userland package: search, filtering, roving
// grid/list navigation, selection proposal, semantics, virtualization, and
// focus requests are ordinary state and procedures over Alicorn's public
// facilities. There is no runtime registration, second UI tree, lifecycle, or
// private memory access.
//
// Authors can use the complete picker() composite or compose the parts:
//
//	_ = picker.search(ctx, &state, options, key=search_key)
//	grid, visible := picker.grid_begin(ctx, &state, choices, options,
//		key=grid_key, instance_id=1, scope_owner=root)
//	if visible {
//		for index := grid.first; index < grid.last; index += 1 {
//			item, item_visible := picker.item_begin(ctx, &grid, index)
//			if item_visible {
//				if options.appearance == .Grid {
//					picker.cell(ctx, item)
//				} else {
//					picker.row(ctx, item)
//				}
//				picker.item_end(ctx, &grid, item)
//			}
//		}
//		event = picker.grid_end(ctx, &grid)
//	} else {
//		picker.empty(ctx, options)
//	}
//
// Everything between item_begin and item_end belongs to the author: keep the
// default cell/row, omit it, or draw any ordinary Alicorn layout inside the
// Button owner. The parts retain List_Box/List_Box_Option semantics, stable
// choice keys, roving grid/list navigation, disabled skipping, reveal, and one
// activation proposal. The application still owns the accepted selection.

import "core:math"
import "core:mem"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"

ICON_PICKER_NAMESPACE :: u64(0x49434F4E5049434B)
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)
CELL_KEY :: u64(0xA11C_1C01)

Appearance :: enum {
	// Grid: square icon cells with an accessible name but no visible label.
	Grid,
	// List: full-width rows with an icon, visible label, and detail text.
	List,
}

Choice :: struct {
	// key is the stable application identity. It must be nonzero and unique
	// within one picker instance. Reordering or removing choices keeps the
	// selected and active identities attached to the remaining keys.
	key:      u64,
	label:    string, // accessible name in both appearances
	icon:     alicorn.Icon_ID,
	keywords: string, // extra search terms; announced only through the name
	detail:   string, // optional description announced in both appearances
	disabled: bool,
}

Options :: struct {
	accessible_label:      string,
	search_accessible_name: string,
	empty_label:           string,
	appearance:            Appearance,
	columns:               int,
	cell_size:             f32,
	cell_gap:              f32,
	row_height:            f32,
	max_visible_rows:      int,
	icon_size:             f32,
	// hide_search omits the search field part entirely; an application with its
	// own query UI can set it and drive matches through set_query.
	hide_search:           bool,
}

DEFAULT_OPTIONS :: Options{
	accessible_label="Icons",
	search_accessible_name="Search icons",
	empty_label="No matching icons",
	appearance=.Grid,
	columns=6,
	cell_size=44,
	cell_gap=6,
	row_height=32,
	max_visible_rows=6,
	icon_size=20,
}

MIN_COLUMNS :: 1
MAX_COLUMNS :: 16

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.accessible_label == "" { result.accessible_label = DEFAULT_OPTIONS.accessible_label }
	if result.search_accessible_name == "" { result.search_accessible_name = DEFAULT_OPTIONS.search_accessible_name }
	if result.empty_label == "" { result.empty_label = DEFAULT_OPTIONS.empty_label }
	result.columns = clamp(result.columns, MIN_COLUMNS, MAX_COLUMNS)
	if result.cell_size <= 0 || math.is_nan(result.cell_size) || math.is_inf(result.cell_size) {
		result.cell_size = DEFAULT_OPTIONS.cell_size
	}
	if result.cell_gap < 0 || math.is_nan(result.cell_gap) || math.is_inf(result.cell_gap) {
		result.cell_gap = DEFAULT_OPTIONS.cell_gap
	}
	if result.row_height <= 0 || math.is_nan(result.row_height) || math.is_inf(result.row_height) {
		result.row_height = DEFAULT_OPTIONS.row_height
	}
	if result.max_visible_rows <= 0 { result.max_visible_rows = DEFAULT_OPTIONS.max_visible_rows }
	if result.icon_size <= 0 || math.is_nan(result.icon_size) || math.is_inf(result.icon_size) {
		result.icon_size = DEFAULT_OPTIONS.icon_size
	}
	return result
}

Event_Kind :: enum { None, Activated }

Event :: struct {
	kind: Event_Kind,
	// key is the proposed application change. The component never mutates the
	// controlled selection; the caller accepts the event by assigning
	// state.selected_key and applying its own command or value change.
	key:  u64,
}

State :: struct {
	query:       ui.Text_Buffer,
	initialized: bool,
	allocator:   mem.Allocator,

	// selected_key is controlled by the application.
	selected_key: u64,
	// active_key is the roving focus inside the current filtered matches.
	active_key:   u64,
	active_index: int,
	match_count:  int,
	matches:      []int,

	columns:   int,
	last_appearance: int,

	search_node:     alicorn.Node_ID,
	collection_node: alicorn.Node_ID,
	root_node:       alicorn.Node_ID,

	focus_search_pending: bool,
	focus_grid_pending:   bool,
	reveal_pending:       bool,
	after_frame_registered: bool,

	// proposed is an activation proposed during a description that cannot
	// return it directly (pointer activation on a row). It is reported by the
	// next grid_end or picker() call, so every input path shares one proposal.
	proposed:     bool,
	proposed_key: u64,
}

// Grid is the per-description grid/list context returned by grid_begin. It
// borrows the caller's choice slice and the state's filtered matches for the
// current description.
Grid :: struct {
	ctx:         ^ui.UI,
	state:       ^State,
	choices:     []Choice,
	options:     Options,
	instance_id: u64,
	node:        alicorn.Node_ID,
	virtual:     alicorn.Virtual_List_Handle,
	collection:  alicorn.Semantic_Collection_Handle,
	first:       int,
	last:        int,
	columns:     int,
	row_height:  f32,
	row_open:    bool,
	open_row:    int,
	visible:     bool,
}

// Grid_Item is the per-description cell/row context returned by item_begin.
Grid_Item :: struct {
	grid:      ^Grid,
	choice:    Choice,
	index:     int,
	count:     int,
	owner:     alicorn.Node_ID,
	selected:  bool,
	active:    bool,
	disabled:  bool,
	visible:   bool,
	activated: bool,
}

// init must receive a zero-initialized State. The caller owns its lifetime and
// must call destroy exactly once.
init :: proc(state: ^State, allocator: mem.Allocator = context.allocator) -> bool {
	if state == nil || state.initialized { return false }
	query, ok := ui.text_buffer("", allocator)
	if !ok { return false }
	state^ = State{query=query, allocator=allocator, initialized=true, active_index=-1}
	return true
}

destroy :: proc(state: ^State) {
	if state == nil || !state.initialized { return }
	ui.text_buffer_destroy(&state.query)
	if len(state.matches) > 0 { delete(state.matches, state.allocator) }
	state^ = {}
}

// set_query replaces the application-visible search text and requests one
// description. The picker owns the buffer storage; the caller owns its value.
set_query :: proc(state: ^State, rt: ^alicorn.Runtime, value: string) -> bool {
	if state == nil || !state.initialized { return false }
	if !ui.text_buffer_set(&state.query, value) { return false }
	if rt != nil { alicorn.invalidate_root(rt, "icon picker query changed") }
	return true
}

query_text :: proc(state: ^State) -> string {
	if state == nil || !state.initialized { return "" }
	return state.query.text
}

active_key :: proc(state: ^State) -> u64 {
	return state.active_key if state != nil else 0
}

match_count :: proc(state: ^State) -> int {
	return state.match_count if state != nil else 0
}

// request_search_focus and request_grid_focus are safe to call from ordinary
// application input handling. The next description schedules one after-frame
// focus request, after layout has finalized the target.
request_search_focus :: proc(state: ^State) -> bool {
	if state == nil { return false }
	state.focus_search_pending = true
	return true
}

request_grid_focus :: proc(state: ^State) -> bool {
	if state == nil { return false }
	state.focus_grid_pending = true
	return true
}

@(private)
mix :: proc(seed, value: u64) -> u64 {
	state := seed+value+0x9E3779B97F4A7C15
	state = (state ~ (state>>30))*0xBF58476D1CE4E5B9
	state = (state ~ (state>>27))*0x94D049BB133111EB
	return state ~ (state>>31)
}

// choice_semantic_id is public so tests, application interactions, and
// explicit semantic actions can target a cell. Identity depends on the picker
// instance and the stable choice key, not on appearance or row position.
choice_semantic_id :: proc(instance_id, key: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID || key == 0 { return {} }
	return alicorn.Semantic_ID{namespace=ICON_PICKER_NAMESPACE, value=mix(instance_id, key)}
}

collection_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=ICON_PICKER_NAMESPACE, value=mix(instance_id, 0x434F4C4C454354)}
}

@(private)
ascii_lower :: proc(value: u8) -> u8 {
	if value >= 'A' && value <= 'Z' { return value + ('a'-'A') }
	return value
}

@(private)
contains_folded :: proc(haystack, needle: string) -> bool {
	if len(needle) == 0 { return true }
	if len(needle) > len(haystack) { return false }
	for start in 0..=(len(haystack)-len(needle)) {
		equal := true
		for offset in 0..<len(needle) {
			if ascii_lower(haystack[start+offset]) != ascii_lower(needle[offset]) { equal = false; break }
		}
		if equal { return true }
	}
	return false
}

@(private)
is_space :: proc(value: u8) -> bool {
	return value == ' ' || value == '\t' || value == '\n' || value == '\r'
}

// matches applies every whitespace-separated query token to the accessible
// name, search keywords, or detail. ASCII letters compare without case; other
// UTF-8 bytes compare exactly. Copy or replace this policy with the
// application's own matcher and ranking.
matches :: proc(choice: Choice, query: string) -> bool {
	position := 0
	for position < len(query) {
		for position < len(query) && is_space(query[position]) { position += 1 }
		if position >= len(query) { break }
		start := position
		for position < len(query) && !is_space(query[position]) { position += 1 }
		token := query[start:position]
		if !contains_folded(choice.label, token) && !contains_folded(choice.keywords, token) &&
		   !contains_folded(choice.detail, token) {
			return false
		}
	}
	return true
}

@(private)
ensure_match_capacity :: proc(state: ^State, count: int) -> bool {
	if count <= len(state.matches) { return true }
	new_matches, err := make([]int, count, state.allocator)
	if err != nil { return false }
	if len(state.matches) > 0 { delete(state.matches, state.allocator) }
	state.matches = new_matches
	return true
}

@(private)
refresh_matches :: proc(state: ^State, choices: []Choice) -> bool {
	if state == nil || !state.initialized { return false }
	if !ensure_match_capacity(state, len(choices)) { state.match_count = 0; state.active_index = -1; return false }
	count := 0
	for choice, index in choices {
		if choice.key == 0 { continue }
		if matches(choice, state.query.text) {
			state.matches[count] = index
			count += 1
		}
	}
	state.match_count = count
	return true
}

@(private)
choice_at_match :: proc(choices: []Choice, state: ^State, match_index: int) -> (Choice, bool) {
	if state == nil || match_index < 0 || match_index >= state.match_count { return {}, false }
	choice_index := state.matches[match_index]
	if choice_index < 0 || choice_index >= len(choices) { return {}, false }
	return choices[choice_index], true
}

@(private)
enabled_at :: proc(choices: []Choice, state: ^State, match_index: int) -> bool {
	choice, found := choice_at_match(choices, state, match_index)
	return found && !choice.disabled
}

@(private)
Picker_Roving :: struct {
	choices: []Choice,
	state:   ^State,
}

@(private)
picker_roving_enabled :: proc(data: rawptr, index: int) -> bool {
	ctx := cast(^Picker_Roving)data
	return enabled_at(ctx.choices, ctx.state, index)
}

@(private)
picker_roving_view :: proc(
	ctx: ^Picker_Roving,
	choices: []Choice,
	state: ^State,
	options: Options,
) -> alicorn.Roving_View {
	ctx.choices = choices
	ctx.state = state
	grid := options.appearance == .Grid
	visible := max(options.max_visible_rows-1, 1)
	return alicorn.Roving_View{
		count=state.match_count,
		columns=options.columns if grid else 0,
		enabled=picker_roving_enabled,
		data=rawptr(ctx),
		page=max(options.columns*visible, 1) if grid else visible,
		// The shipped grid moves linearly at row edges, stops at the filtered
		// boundary, and scopes Home/End to the active row.
		home_end=.Row if grid else .All,
	}
}

@(private)
set_active :: proc(choices: []Choice, state: ^State, index: int) {
	if state == nil { return }
	state.active_index = index
	state.active_key = 0
	state.reveal_pending = index >= 0
	if index >= 0 {
		if choice, found := choice_at_match(choices, state, index); found { state.active_key = choice.key }
	}
}

@(private)
reconcile_active :: proc(choices: []Choice, state: ^State) {
	if state == nil { return }
	if state.match_count == 0 {
		state.active_index = -1
		state.active_key = 0
		return
	}
	if state.active_index >= 0 && state.active_index < state.match_count {
		if choice, found := choice_at_match(choices, state, state.active_index); found &&
		   !choice.disabled && (state.active_key == 0 || choice.key == state.active_key) {
			state.active_key = choice.key
			return
		}
	}
	// Keep the active key if it is still visible; otherwise start from the
	// previous position and take the first enabled row at or after it.
	if state.active_key != 0 {
		for match_index in 0..<state.match_count {
			choice, found := choice_at_match(choices, state, match_index)
			if found && choice.key == state.active_key && !choice.disabled {
				state.active_index = match_index
				return
			}
		}
	}
	ctx: Picker_Roving
	view := picker_roving_view(&ctx, choices, state, Options{})
	start := clamp(state.active_index, 0, state.match_count-1)
	index := alicorn.roving_first_enabled_from(view, start, 1)
	if index < 0 { index = alicorn.roving_first_enabled_from(view, start, -1) }
	if index < 0 { index = alicorn.roving_first_enabled(view) }
	if index < 0 {
		state.active_index = -1
		state.active_key = 0
		return
	}
	state.active_index = index
	if choice, found := choice_at_match(choices, state, index); found { state.active_key = choice.key }
}

// sync refreshes the filtered match set from the caller's choices and repairs
// the active identity. Call it before grid_begin when you own the shell; grid_begin
// calls it as well so the complete picker stays one description.
sync :: proc(state: ^State, choices: []Choice) -> bool {
	if state == nil || !state.initialized { return false }
	if !refresh_matches(state, choices) { return false }
	reconcile_active(choices, state)
	return true
}

// handle_key applies grid/list navigation and activation to the current
// filtered matches. It is the public path for applications whose query field
// owns focus; grid_begin also uses it for retained scoped input.
handle_key :: proc(
	state: ^State,
	choices: []Choice,
	options: Options = {},
	key: alicorn.Application_Key,
) -> bool {
	if state == nil || state.match_count == 0 { return false }
	resolved := options_resolve(options)
	previous := state.active_index
	if key == .Return || key == .Toggle {
		if choice, found := choice_at_match(choices, state, state.active_index); found && !choice.disabled {
			state.proposed = true
			state.proposed_key = choice.key
		}
		return true
	}
	move, mapped := alicorn.roving_move_for_key(key)
	if !mapped { return false }
	if resolved.appearance != .Grid && (move == .Left || move == .Right) { return false }
	ctx: Picker_Roving
	view := picker_roving_view(&ctx, choices, state, resolved)
	if index := alicorn.roving_propose(view, state.active_index, move); index >= 0 {
		set_active(choices, state, index)
	}
	return state.active_index != previous
}

@(private)
apply_navigation :: proc(choices: []Choice, state: ^State, options: Options, key: alicorn.Application_Key) -> bool {
	return handle_key(state, choices, options, key)
}

@(private)
schedule_after_frame :: proc(state: ^State, rt: ^alicorn.Runtime) {
	if state == nil || rt == nil || state.after_frame_registered { return }
	if alicorn.interaction_after_frame_register(rt, rawptr(state), picker_after_frame) {
		state.after_frame_registered = true
	}
}

@(private)
picker_after_frame :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	state := cast(^State)data
	if state == nil || rt == nil { return }
	state.after_frame_registered = false
	if state.focus_search_pending && state.search_node != 0 {
		if alicorn.focus(rt, state.search_node) {
			state.focus_search_pending = false
			alicorn.focus_indicator_set(rt, true)
			_ = alicorn.set_text_selection(rt, state.search_node, 0, len(state.query.text))
		}
	} else if state.search_node == 0 {
		state.focus_search_pending = false
	}
	if state.focus_grid_pending && state.collection_node != 0 {
		if alicorn.focus(rt, state.collection_node) {
			state.focus_grid_pending = false
			alicorn.focus_indicator_set(rt, true)
		}
	} else if state.collection_node == 0 {
		state.focus_grid_pending = false
	}
	if state.reveal_pending && state.collection_node != 0 && state.active_index >= 0 {
		virtual_index := state.active_index
		if state.columns > 1 { virtual_index = state.active_index/state.columns }
		_ = alicorn.virtual_list_ensure_visible(rt, state.collection_node, virtual_index,
			"icon picker active choice revealed")
		state.reveal_pending = false
	}
	if state.focus_search_pending || state.focus_grid_pending || state.reveal_pending {
		schedule_after_frame(state, rt)
	}
}

// search draws the controlled search field part. It returns visible=false when
// `Options.hide_search` is set or the field cannot open; the caller can supply
// its own query UI. Call it inside the picker's key scope.
search :: proc(
	ctx: ^ui.UI,
	state: ^State,
	options: Options = {},
	key: ui.UI_Key,
) -> (node: alicorn.Node_ID, visible: bool) {
	if ctx == nil || ctx.runtime == nil || state == nil || !state.initialized { return }
	resolved := options_resolve(options)
	if resolved.hide_search {
		state.search_node = 0
		state.focus_search_pending = false
		return
	}
	field := alicorn.text_field_controlled(
		ctx,
		&state.query,
		key=key,
		style=ui.layout_style(.Row, width=-1, height=32),
	)
	state.search_node = field.node
	if field.node == 0 { return }
	_ = alicorn.semantic_text_field_label(ctx, resolved.search_accessible_name)
	return field.node, true
}

// empty draws the no-results label and schedules pending focus/reveal work.
empty :: proc(ctx: ^ui.UI, state: ^State, options: Options = {}, key: ui.UI_Key = {}) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil { return 0 }
	resolved := options_resolve(options)
	if state != nil {
		state.collection_node = 0
		if state.focus_search_pending || state.focus_grid_pending || state.reveal_pending {
			schedule_after_frame(state, ctx.runtime)
		}
	}
	text_key := key
	if text_key == (ui.UI_Key{}) { text_key = alicorn.key_string("icon-picker-empty") }
	return ui.text(ctx, resolved.empty_label, key=text_key)
}

// grid_begin opens the retained virtual grid/list and its published List_Box
// collection. options.appearance selects the row model: grid rows contain
// `columns` cells; list rows contain one full-width choice. scope_owner is the
// caller's interaction scope (usually the picker root); grid_begin drains its
// queued navigation keys. Pass zero when the application drives `handle_key`
// itself.
//
// grid_begin returns visible=false when the picker is not initialized, the
// instance is invalid, or there are no filtered matches. Call `empty` for the
// no-results presentation.
grid_begin :: proc(
	ctx: ^ui.UI,
	state: ^State,
	choices: []Choice,
	options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
	scope_owner: alicorn.Node_ID = 0,
) -> (grid: Grid, visible: bool) {
	if ctx == nil || ctx.runtime == nil || state == nil || !state.initialized ||
	   instance_id == 0 || instance_id > MAX_INSTANCE_ID {
		return
	}
	resolved := options_resolve(options)
	// Switching appearance replaces the retained list owner. Keep keyboard
	// focus on the equivalent collection instead of dropping it with the old
	// node; this is ordinary public focus state, not runtime policy.
	if state.last_appearance >= 0 && state.last_appearance != int(resolved.appearance) {
		if state.collection_node != 0 && alicorn.focused_node(ctx.runtime) == state.collection_node {
			state.focus_grid_pending = true
		}
	}
	state.last_appearance = int(resolved.appearance)
	if !sync(state, choices) {
		state.collection_node = 0
		return
	}
	state.columns = resolved.columns

	// Process retained scoped input from the previous description. This is
	// where ordinary arrow/Home/End/Return grid navigation runs, including keys
	// yielded by the focused search field.
	if scope_owner != 0 {
		for {
			queued, found := alicorn.interaction_event_next(ctx.runtime, scope_owner)
			if !found { break }
			if queued.kind == .Key {
				if apply_navigation(choices, state, resolved, queued.key) {
					alicorn.invalidate_root(ctx.runtime, "icon picker keyboard navigation")
				}
			}
		}
	}

	if state.match_count == 0 {
		state.collection_node = 0
		return
	}

	state.collection_node = 0
	collection_id := collection_semantic_id(instance_id)
	selected_id := choice_semantic_id(instance_id, state.selected_key)
	active_id := choice_semantic_id(instance_id, state.active_key)
	active_in_view := false
	for match_index in 0..<state.match_count {
		if choice, found := choice_at_match(choices, state, match_index); found && choice.key == state.active_key {
			active_in_view = true
			break
		}
	}
	if !active_in_view { active_id = {} }

	if resolved.appearance == .Grid {
		row_count := (state.match_count+resolved.columns-1)/resolved.columns
		row_height := resolved.cell_size+resolved.cell_gap
		max_height := f32(min(resolved.max_visible_rows, row_count))*row_height
		virtual := alicorn.virtual_list_begin(
			ctx,
			row_count,
			row_height,
			key=key,
			style=ui.layout_style(.Column, width=-1, height=max_height, clip=true),
			label=resolved.accessible_label,
			focusable=true,
		)
		state.collection_node = virtual.scroll.id
		if virtual.scroll.id == 0 { return }
		realized_first := min(virtual.first*resolved.columns, state.match_count)
		realized_last := min(virtual.last*resolved.columns, state.match_count)
		collection := alicorn.semantic_collection_begin(
			ctx,
			virtual.scroll.id,
			collection_id,
			.List_Box,
			resolved.accessible_label,
			u64(state.match_count),
			selected_id=selected_id,
			current_id=active_id,
			realized_first=u64(realized_first),
			realized_last=u64(realized_last),
		)
		grid = Grid{
			ctx=ctx,
			state=state,
			choices=choices,
			options=resolved,
			instance_id=instance_id,
			node=virtual.scroll.id,
			virtual=virtual,
			collection=collection,
			first=realized_first,
			last=realized_last,
			columns=resolved.columns,
			row_height=row_height,
			visible=true,
		}
		return grid, true
	}

	max_height := f32(min(resolved.max_visible_rows, state.match_count))*resolved.row_height
	virtual := alicorn.virtual_list_begin(
		ctx,
		state.match_count,
		resolved.row_height,
		key=key,
		style=ui.layout_style(.Column, width=-1, height=max_height, clip=true),
		label=resolved.accessible_label,
		focusable=true,
	)
	state.collection_node = virtual.scroll.id
	if virtual.scroll.id == 0 { return }
	collection := alicorn.semantic_collection_begin(
		ctx,
		virtual.scroll.id,
		collection_id,
		.List_Box,
		resolved.accessible_label,
		u64(state.match_count),
		selected_id=selected_id,
		current_id=active_id,
		realized_first=u64(virtual.first),
		realized_last=u64(virtual.last),
	)
	grid = Grid{
		ctx=ctx,
		state=state,
		choices=choices,
		options=resolved,
		instance_id=instance_id,
		node=virtual.scroll.id,
		virtual=virtual,
		collection=collection,
		first=virtual.first,
		last=virtual.last,
		columns=0,
		row_height=resolved.row_height,
		visible=true,
	}
	return grid, true
}

@(private)
close_open_row :: proc(grid: ^Grid) {
	if grid == nil || !grid.row_open { return }
	alicorn.container_end(grid.ctx)
	grid.row_open = false
}

@(private)
fill_and_close_row :: proc(grid: ^Grid, index: int) {
	if grid == nil || !grid.row_open { return }
	remaining := grid.columns-(index%grid.columns)-1
	for column in 0..<remaining {
		if ui.row(grid.ctx, key=ui.key_u64(0xFF00+u64(column)), width=grid.options.cell_size,
			height=grid.options.cell_size, label="icon-picker-cell-gap") {}
	}
	close_open_row(grid)
}

// item_begin opens one realized choice's Button owner and publishes its
// List_Box_Option semantic item. index is a position in the filtered match
// slice. In Grid appearance, the part also opens the containing row when the
// index starts a new row; call items in ascending realized order. It returns
// visible=false for an invalid grid, an out-of-range match, a zero key, or a
// failed Button owner; skip the subtree and do not call item_end.
item_begin :: proc(ctx: ^ui.UI, grid: ^Grid, index: int) -> (item: Grid_Item, visible: bool) {
	if ctx == nil || ctx.runtime == nil || grid == nil || !grid.visible { return }
	choice, found := choice_at_match(grid.choices, grid.state, index)
	if !found || choice.key == 0 { return }
	if grid.options.appearance == .Grid {
		row_index := index/grid.columns
		if grid.row_open && grid.open_row != row_index {
			fill_and_close_row(grid, index-1)
		}
		if !grid.row_open {
			// Open the row with the manual container scope, not ui.row: ui.row is
			// a deferred-scope helper and would close at the end of this block.
			row := alicorn.container_begin(
				ctx,
				.Container,
				label="icon-picker-grid-row",
				key=ui.key_pair(0xA11C_1C03, u64(row_index+1)),
				style=ui.layout_style(.Row, width=-1, height=grid.row_height,
					gap=grid.options.cell_gap, align=.Center),
			)
			if row == 0 { return }
			grid.row_open = true
			grid.open_row = row_index
		}
	}

	state := grid.state
	selected := state.selected_key == choice.key
	active := state.active_index == index
	owner, activated := alicorn.button_begin(
		ctx,
		choice.label,
		key=ui.key_pair(CELL_KEY, choice.key),
		style=ui.layout_style(.Column,
			width=grid.options.cell_size if grid.options.appearance == .Grid else -1,
			height=grid.options.cell_size if grid.options.appearance == .Grid else grid.options.row_height),
		state=alicorn.Button_State{selected=selected, disabled=choice.disabled},
		presentation=.Custom,
		focusable=false,
	)
	if owner == 0 { return }
	states := alicorn.Semantic_States{}
	actions := alicorn.Semantic_Actions{}
	if choice.disabled { states = alicorn.semantic_states_add(states, .Disabled) }
	if selected { states = alicorn.semantic_states_add(states, .Selected) }
	if active { states = alicorn.semantic_states_add(states, .Current) }
	if !choice.disabled {
		actions = alicorn.semantic_actions_add(actions, .Select)
		actions = alicorn.semantic_actions_add(actions, .Focus)
	}
	_ = alicorn.semantic_collection_item(ctx, grid.collection, u64(index), alicorn.Semantic_Node_Description{
		id=choice_semantic_id(grid.instance_id, choice.key),
		role=.List_Box_Option,
		label=choice.label,
		description=choice.detail,
		value=choice.label,
		states=states,
		actions=actions,
	})
	item = Grid_Item{
		grid=grid,
		choice=choice,
		index=index,
		count=state.match_count,
		owner=owner,
		selected=selected,
		active=active,
		disabled=choice.disabled,
		visible=true,
		activated=activated,
	}
	return item, true
}

// cell draws the default square icon cell. It is optional; custom authors may
// draw any tile, swatch, image, or label inside the cell Button owner.
cell :: proc(ctx: ^ui.UI, item: Grid_Item) {
	if ctx == nil || ctx.runtime == nil || !item.visible || item.grid == nil { return }
	fill := alicorn.style_color(ctx, .Subtle_Surface)
	if item.selected { fill = alicorn.style_color(ctx, .Selection) }
	stroke_role := alicorn.Style_Color_Role.Border
	if item.active { stroke_role = .Focus }
	stroke_color := alicorn.style_color(ctx, stroke_role)
	stroke_width: f32 = 2 if item.active else 1
	if ui.panel(
		ctx,
		key=ui.key_u64(1),
		width=-1,
		height=-1,
		padding=6,
		align=.Center,
		justify=.Center,
		fill=fill,
		radius=8,
		stroke=ui.border(stroke_width, stroke_color, .Inside),
		label="icon-picker-cell",
	) {
		icon_color := alicorn.Style_Color_Role.Text
		if item.choice.disabled {
			icon_color = .Muted_Text
		} else if item.selected {
			icon_color = .Accent_Text
		}
		icon := ui.icon(ctx, item.choice.icon, key=ui.key_u64(2), size=item.grid.options.icon_size,
			color_role=icon_color)
		if icon != 0 { _ = alicorn.visual_part_attach(ctx, icon, item.owner, alicorn.visual_part_core(.Icon)) }
		if item.selected {
			dot := ui.box(ctx, key=ui.key_u64(3), size=5,
				fill=alicorn.style_color(ctx, .Accent), radius=3)
			if dot != 0 {
				_ = alicorn.visual_part_attach(ctx, dot, item.owner, alicorn.visual_part_core(.Selected_Indicator))
			}
		}
	}
}

// row draws the default full-width list row. It is optional.
row :: proc(ctx: ^ui.UI, item: Grid_Item) {
	if ctx == nil || ctx.runtime == nil || !item.visible || item.grid == nil { return }
	fill := alicorn.style_color(ctx, .Surface)
	if item.selected { fill = alicorn.style_color(ctx, .Selection) }
	stroke_role := alicorn.Style_Color_Role.Border
	if item.active { stroke_role = .Focus }
	stroke_color := alicorn.style_color(ctx, stroke_role)
	stroke_width: f32 = 2 if item.active else 1
	if ui.panel(
		ctx,
		key=ui.key_u64(1),
		width=-1,
		height=item.grid.options.row_height-2,
		padding=4,
		align=.Center,
		fill=fill,
		radius=6,
		stroke=ui.border(stroke_width, stroke_color, .Inside),
		label="icon-picker-row",
	) {
		if ui.row(ctx, key=ui.key_u64(7), width=-1, height=-1, gap=8, align=.Center) {
			if ui.panel(ctx, key=ui.key_u64(2), width=22, height=22,
				align=.Center, justify=.Center,
				fill=alicorn.style_color(ctx, .Subtle_Surface), radius=5,
				label="icon-picker-row-icon") {
				icon_color := alicorn.Style_Color_Role.Text
				if item.choice.disabled {
					icon_color = .Muted_Text
				} else if item.selected {
					icon_color = .Accent_Text
				}
				icon := ui.icon(ctx, item.choice.icon, key=ui.key_u64(3), size=16,
					color_role=icon_color)
				if icon != 0 {
					_ = alicorn.visual_part_attach(ctx, icon, item.owner, alicorn.visual_part_core(.Icon))
				}
			}
			text_color := alicorn.style_color(ctx, .Text)
			if item.choice.disabled { text_color = alicorn.style_color(ctx, .Muted_Text) }
			label := ui.text(ctx, item.choice.label,
				key=ui.key_u64(4),
				style=ui.layout_style(.Row, grow=1),
				size=14,
				color=text_color,
				decorative=true,
				text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_MEDIUM, overflow=.Ellipsis},
			)
			if label != 0 { _ = alicorn.visual_part_attach(ctx, label, item.owner, alicorn.visual_part_core(.Label)) }
			if item.choice.detail != "" {
				detail := ui.text(ctx, item.choice.detail,
					key=ui.key_u64(5),
					size=12,
					color=alicorn.style_color(ctx, .Muted_Text),
					decorative=true,
					text_style=alicorn.Text_Style{overflow=.Ellipsis},
				)
				if detail != 0 {
					_ = alicorn.visual_part_attach(ctx, detail, item.owner, alicorn.visual_part_core(.Content))
				}
			}
			if item.selected {
				check := ui.icon(ctx, .Check, key=ui.key_u64(6), size=14, color_role=.Accent_Text)
				if check != 0 {
					_ = alicorn.visual_part_attach(ctx, check, item.owner, alicorn.visual_part_core(.Selected_Indicator))
				}
			}
		}
	}
}

// item_end closes the choice's Button owner and records pointer or semantic
// activation as the grid's one pending proposal. Call it only when item_begin
// returned visible=true.
item_end :: proc(ctx: ^ui.UI, grid: ^Grid, item: Grid_Item) {
	if ctx == nil || !item.visible { return }
	alicorn.button_end(ctx)
	if item.activated && !item.choice.disabled && grid != nil {
		grid.state.proposed = true
		grid.state.proposed_key = item.choice.key
	}
	if grid != nil && grid.options.appearance == .Grid {
		if item.index%grid.columns == grid.columns-1 || item.index == grid.state.match_count-1 {
			fill_and_close_row(grid, item.index)
		}
	}
}

// grid_end closes the virtual list and returns the one activation proposal for
// this description. It schedules pending focus/reveal work.
grid_end :: proc(ctx: ^ui.UI, grid: ^Grid) -> (event: Event) {
	if ctx == nil || grid == nil || !grid.visible { return }
	close_open_row(grid)
	alicorn.virtual_list_end(ctx, grid.virtual)
	grid.visible = false
	state := grid.state
	if state.proposed {
		state.proposed = false
		event = Event{kind=.Activated, key=state.proposed_key}
	}
	if state.focus_search_pending || state.focus_grid_pending || state.reveal_pending {
		schedule_after_frame(state, ctx.runtime)
	}
	return
}

// picker describes the complete composite with the default search field, grid
// or list part, and cell/row visuals. instance_id must be stable and unique
// among simultaneously mounted pickers; it scopes semantic identity but does
// not affect behavior. The returned event is the one proposed application
// change for this description.
picker :: proc(
	ctx: ^ui.UI,
	state: ^State,
	choices: []Choice,
	options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
) -> (event: Event) {
	if ctx == nil || ctx.runtime == nil || state == nil || !state.initialized ||
	   instance_id == 0 || instance_id > MAX_INSTANCE_ID {
		return
	}
	resolved := options_resolve(options)
	if !ui.key_scope(ctx, key) { return }
	state.root_node = alicorn.container_begin(
		ctx,
		.Container,
		label=resolved.accessible_label,
		key=alicorn.key_string("icon-picker-root"),
		style=ui.layout_style(.Column, width=-1, height=alicorn.LAYOUT_SIZE_FIT_CONTENT, gap=8),
	)
	if state.root_node == 0 { return }
	// One keyboard scope owns the whole composite, so the search field and the
	// grid share grid navigation. text_preempt_keys is the only configuration
	// needed for the focused search target to yield arrows and Space; characters,
	// deletion, and IME composition still belong to the field.
	_ = ui.interaction_scope(ctx, state.root_node, rawptr(state), alicorn.Interaction_Scope_Options{
		keys=NAVIGATION_KEYS,
		composition_yield_keys=NAVIGATION_KEYS,
		text_preempt_keys=SEARCH_YIELD_KEYS,
	})
	_, _ = search(ctx, state, resolved, key=alicorn.key_string("icon-picker-search"))

	grid, grid_visible := grid_begin(ctx, state, choices, resolved,
		key=alicorn.key_string("icon-picker-grid"), instance_id=instance_id,
		scope_owner=state.root_node)
	if !grid_visible {
		_ = empty(ctx, state, resolved)
		alicorn.container_end(ctx)
		return
	}
	for index := grid.first; index < grid.last; index += 1 {
		item, item_visible := item_begin(ctx, &grid, index)
		if !item_visible { continue }
		if resolved.appearance == .Grid {
			cell(ctx, item)
		} else {
			row(ctx, item)
		}
		item_end(ctx, &grid, item)
	}
	event = grid_end(ctx, &grid)
	alicorn.container_end(ctx)
	return
}

@(private)
NAVIGATION_KEYS :: alicorn.Interaction_Key_Set{
	.Up, .Down, .Left, .Right, .Home, .End, .Page_Up, .Page_Down, .Return, .Toggle,
}

// SEARCH_YIELD_KEYS are the keys a focused search field gives back to the
// picker. Characters, Backspace/Delete, and IME composition stay with the text
// field: composition_yield_keys already keeps the whole navigation set with
// the field while a preedit is active.
SEARCH_YIELD_KEYS :: alicorn.Interaction_Key_Set{
	.Up, .Down, .Left, .Right, .Home, .End, .Page_Up, .Page_Down, .Toggle,
}
