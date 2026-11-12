package command_palette

import "core:fmt"
import "core:math"
import "core:mem"
import alicorn "alicorn:runtime"
import host "alicorn:native/sdl_gpu"
import ui "alicorn:ui"
import palette "alikit:palette_model"

Item_ID :: palette.Item_ID
Item :: palette.Item
Event_Kind :: enum {None, Activated}

Search_Mode :: enum {
	Substring,
	Caller_Filtered,
}

Status :: enum {
	Ready,
	Query_Reset_Failed,
	Query_Update_Failed,
	Match_Buffer_Allocation_Failed,
}

Event :: struct {
	kind: Event_Kind,
	item_id: Item_ID,
}

State :: struct {
	query:          ui.Text_Buffer,
	allocator:      mem.Allocator,
	matches:        []palette.Match,
	matches_capacity: int,
	match_count:    int,
	selection:      palette.Selection,
	search_mode:    Search_Mode,
	last_status:    Status,
	query_node:     alicorn.Node_ID,
	overlay_node:   alicorn.Node_ID,
	panel_node:     alicorn.Node_ID,
	results_node:   alicorn.Node_ID,
	previous_focus: alicorn.Node_ID,
	open:           bool,
	focus_pending:  bool,
	restore_focus:  bool,
	initialized:    bool,
}

Options :: struct {
	title:                 string,
	query_accessible_name: string,
	empty_message:         string,
	allocation_error_message: string,
	panel_max_width:       f32,
	list_max_height:       f32,
	row_height:            f32,
}

DEFAULT_OPTIONS :: Options{
	title="Commands",
	query_accessible_name="Search commands",
	empty_message="No matching commands",
	allocation_error_message="Results temporarily unavailable",
	panel_max_width=720,
	list_max_height=360,
	row_height=38,
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.title == "" { result.title = DEFAULT_OPTIONS.title }
	if result.query_accessible_name == "" { result.query_accessible_name = DEFAULT_OPTIONS.query_accessible_name }
	if result.empty_message == "" { result.empty_message = DEFAULT_OPTIONS.empty_message }
	if result.allocation_error_message == "" { result.allocation_error_message = DEFAULT_OPTIONS.allocation_error_message }
	if result.panel_max_width <= 0 || math.is_nan(result.panel_max_width) || math.is_inf(result.panel_max_width) {
		result.panel_max_width = DEFAULT_OPTIONS.panel_max_width
	}
	if result.list_max_height <= 0 || math.is_nan(result.list_max_height) || math.is_inf(result.list_max_height) {
		result.list_max_height = DEFAULT_OPTIONS.list_max_height
	}
	if result.row_height <= 0 || math.is_nan(result.row_height) || math.is_inf(result.row_height) {
		result.row_height = DEFAULT_OPTIONS.row_height
	}
	return result
}

// init must receive a zero-initialized State. The caller owns its lifetime and
// must call destroy exactly once after the palette is no longer in use.
init :: proc(state: ^State, allocator: mem.Allocator = context.allocator) -> bool {
	if state == nil || state.initialized { return false }
	query, ok := ui.text_buffer("", allocator)
	if !ok { return false }
	state^ = State{query=query, allocator=allocator, initialized=true}
	return true
}

destroy :: proc(state: ^State) {
	if state == nil || !state.initialized { return }
	ui.text_buffer_destroy(&state.query)
	if len(state.matches) > 0 { delete(state.matches, state.allocator) }
	state^ = {}
}

set_query :: proc(state: ^State, rt: ^alicorn.Runtime, value: string) -> bool {
	if state == nil || !state.initialized { return false }
	if !ui.text_buffer_set(&state.query, value) {
		state.last_status = .Query_Update_Failed
		return false
	}
	state.last_status = .Ready
	if rt != nil { alicorn.invalidate_root(rt, "AliKit command palette query changed") }
	return true
}

open_palette :: proc(
	state: ^State,
	rt: ^alicorn.Runtime,
	search_mode := Search_Mode.Substring,
) -> bool {
	if state == nil || rt == nil || !state.initialized { return false }
	if state.open { return true }
	if !ui.text_buffer_set(&state.query, "") {
		state.last_status = .Query_Reset_Failed
		return false
	}
	state.last_status = .Ready
	state.previous_focus = alicorn.focused_node(rt)
	state.open = true
	state.focus_pending = true
	state.restore_focus = false
	state.query_node = 0
	state.overlay_node = 0
	state.panel_node = 0
	state.results_node = 0
	state.selection = {}
	state.search_mode = search_mode
	alicorn.invalidate_root(rt, "AliKit command palette opened")
	return true
}

close_palette :: proc(state: ^State, rt: ^alicorn.Runtime, restore_focus := true) {
	if state == nil || !state.initialized { return }
	state.open = false
	state.focus_pending = false
	state.restore_focus = restore_focus
	state.query_node = 0
	state.panel_node = 0
	state.results_node = 0
	if rt != nil { alicorn.invalidate_root(rt, "AliKit command palette closed") }
}

@(private)
refresh_matches :: proc(state: ^State, items: []Item) -> bool {
	if state == nil || !state.initialized { return false }
	state.last_status = .Ready
	if state.matches_capacity < len(items) {
		new_matches, err := make([]palette.Match, len(items), state.allocator)
		if err != nil {
			state.match_count = 0
			state.selection = {}
			state.last_status = .Match_Buffer_Allocation_Failed
			return false
		}
		old_matches := state.matches
		state.matches = new_matches
		state.matches_capacity = len(new_matches)
		if len(old_matches) > 0 { delete(old_matches, state.allocator) }
	}
	count: int
	status: palette.Filter_Status
	if state.search_mode == .Caller_Filtered {
		count, status = palette.index_all(items, state.matches)
	} else {
		count, status = palette.filter(items, state.query.text, state.matches)
	}
	if status != .Ok {
		state.match_count = 0
		state.selection = {}
		return false
	}
	state.match_count = count
	_ = palette.reconcile(&state.selection, items, state.matches[:count])
	return true
}

// query_text returns the current borrowed query. The view remains valid until
// the next query edit, set_query call, or destroy; clone it if it must outlive
// that interval.
query_text :: proc(state: ^State) -> string {
	if state == nil || !state.initialized { return "" }
	return state.query.text
}

// text_change adopts committed query edits from Alicorn's native host. The
// host owns and releases change.text after this callback returns.
text_change :: proc(state: ^State, rt: ^alicorn.Runtime, change: alicorn.Text_Change) -> bool {
	if state == nil || rt == nil || !state.open || !change.changed || change.node != state.query_node { return false }
	if !ui.text_buffer_set(&state.query, change.text) {
		state.last_status = .Query_Update_Failed
		return false
	}
	state.last_status = .Ready
	alicorn.invalidate_root(rt, "AliKit command palette query changed")
	return true
}

// handle_key is intended to be called from Application.on_key. It receives a
// fresh item slice because applications may rebuild or reorder actions between
// input turns. It consumes only palette navigation, activation, and dismissal.
handle_key :: proc(state: ^State, rt: ^alicorn.Runtime, items: []Item, key: host.Application_Key) -> (handled: bool, event: Event) {
	if state == nil || rt == nil || !state.open { return }
	if key == .Up || key == .Down || key == .Return {
		if interaction, found := alicorn.text_field_interaction(rt, state.query_node); found && interaction.composition_active {
			return false, {}
		}
	}
	#partial switch key {
	case .Escape, .Open_Command_Palette:
		close_palette(state, rt, true)
		return true, {}
	case .Up, .Down, .Return:
		if !refresh_matches(state, items) { return true, {} }
	case:
		return false, {}
	}
	visible := state.matches[:state.match_count]
	#partial switch key {
	case .Up, .Down:
		delta := -1 if key == .Up else 1
		_ = palette.move(&state.selection, items, visible, delta)
		if state.results_node != 0 {
			for match, index in visible {
				if match.item_index >= 0 && match.item_index < len(items) && items[match.item_index].id == state.selection.id {
					_ = alicorn.virtual_list_ensure_visible(rt, state.results_node, index, "AliKit command palette selection visibility")
					break
				}
			}
		}
		alicorn.invalidate_root(rt, "AliKit command palette selection moved")
		return true, {}
	case .Return:
		if id, ok := palette.activate(state.selection, items, visible); ok {
			close_palette(state, rt, true)
			return true, Event{kind=.Activated, item_id=id}
		}
		return true, {}
	case:
		return false, {}
	}
}

// after_frame applies focus changes once described nodes have been reconciled.
// Call after alicorn.end_frame in the host build callback.
after_frame :: proc(state: ^State, rt: ^alicorn.Runtime) {
	if state == nil || rt == nil || !state.initialized { return }
	if state.open && state.focus_pending && state.query_node != 0 {
		if alicorn.focus(rt, state.query_node) {
			state.focus_pending = false
			_ = alicorn.set_text_selection(rt, state.query_node, 0, len(state.query.text))
		}
	}
	if state.open || !state.restore_focus { return }
	// A pointer activation occurs while the current frame is being described,
	// so its overlay can remain in that submitted tree for one more frame. Wait
	// until it is retired before restoring focus behind the modal boundary.
	if state.overlay_node != 0 {
		if _, found := alicorn.node_info(rt, state.overlay_node); found { return }
	}
	state.restore_focus = false
	focus := state.previous_focus
	state.previous_focus = 0
	state.overlay_node = 0
	if focus != 0 {
		if _, found := alicorn.node_info(rt, focus); found { _ = alicorn.focus(rt, focus) }
	}
}

// pointer dismisses when the primary pointer goes down on the overlay outside
// the panel. Alicorn's modal layer continues to own hit testing and focus scope.
pointer :: proc(state: ^State, rt: ^alicorn.Runtime, event: alicorn.Pointer_Event, target: alicorn.Node_ID) -> bool {
	if state == nil || rt == nil || !state.open { return false }
	if event.kind != .Down || event.button != alicorn.POINTER_BUTTON_PRIMARY || target != state.overlay_node { return false }
	panel, found := alicorn.node_info(rt, state.panel_node)
	inside := found && event.x >= panel.bounds.x && event.x < panel.bounds.x+panel.bounds.w &&
		event.y >= panel.bounds.y && event.y < panel.bounds.y+panel.bounds.h
	if !inside { close_palette(state, rt, true) }
	return true
}

// build draws an accessible, themed command palette as a modal overlay. The
// caller describes its ordinary root first, then invokes build. Item strings
// and the slice are borrowed through this call; IDs must be nonzero and unique.
build :: proc(
	ctx: ^ui.UI,
	state: ^State,
	items: []Item,
	key: ui.UI_Key,
	options: Options = {},
) -> (event: Event) {
	if ctx == nil || ctx.runtime == nil || state == nil || !state.initialized || !state.open { return }
	if !ui.key_scope(ctx, key) { return }
	_ = refresh_matches(state, items)
	resolved_options := options_resolve(options)

	state.overlay_node = alicorn.modal_overlay_begin(
		ctx,
		alicorn.key_string("alikit-command-palette-overlay"),
		style=ui.layout_style(.Column, grow=1, padding=32, align=.Center, justify=.Center, clip=true),
		backdrop_color=alicorn.Color{0.02, 0.025, 0.04, 0.58},
	)
	if state.overlay_node == 0 { return }
	state.panel_node = alicorn.surface_begin(
		ctx,
		alicorn.surface_core_color_role(.Surface),
		key=alicorn.key_string("alikit-command-palette-panel"),
		style=ui.layout_style(.Column, width=-1, height=alicorn.LAYOUT_SIZE_FIT_CONTENT,
			max_width=resolved_options.panel_max_width, max_height=resolved_options.list_max_height+150,
			padding=14, gap=8, clip=true),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=8},
		label="alikit-command-palette-panel",
	)
	if state.panel_node != 0 {
		_ = ui.text(ctx, resolved_options.title, key=alicorn.key_string("alikit-command-palette-title"), size=20)
		query := alicorn.text_field_controlled(
			ctx,
			&state.query,
			key=alicorn.key_string("alikit-command-palette-query"),
			style=ui.layout_style(.Row, height=42),
		)
		state.query_node = query.node
		if query.node != 0 { _ = alicorn.semantic_text_field_label(ctx, resolved_options.query_accessible_name) }

		if state.last_status == .Match_Buffer_Allocation_Failed {
			_ = ui.text(ctx, resolved_options.allocation_error_message, key=alicorn.key_string("alikit-command-palette-allocation-error"))
		} else if state.match_count == 0 {
			_ = ui.text(ctx, resolved_options.empty_message, key=alicorn.key_string("alikit-command-palette-empty"))
		} else {
			list := alicorn.virtual_list_begin(
				ctx,
				state.match_count,
				resolved_options.row_height,
				key=alicorn.key_string("alikit-command-palette-results"),
				style=ui.layout_style(.Column, height=alicorn.LAYOUT_SIZE_FIT_CONTENT,
					max_height=resolved_options.list_max_height, grow=1, clip=true),
				label="alikit-command-palette-results",
			)
			state.results_node = list.scroll.id
			if list.scroll.id != 0 {
				for index := list.first; index < list.last; index += 1 {
					match := state.matches[index]
					if match.item_index < 0 || match.item_index >= len(items) { continue }
					item := items[match.item_index]
					label := item.title
					if item.description != "" { label = fmt.tprintf("%s  ·  %s", item.title, item.description) }
					if ui.button(
						ctx,
						label,
						key=ui.key_pair(0xA11C_0001, palette.item_id_value(item.id)),
						style=ui.layout_style(.Row, height=resolved_options.row_height),
						state=ui.Button_State{selected=item.id == state.selection.id, disabled=item.disabled},
						text_style=alicorn.Text_Style{overflow=.Ellipsis},
						content_style=alicorn.button_content_style(horizontal=.Start, vertical=.Center, padding_x=10, padding_y=4),
						variant=.Quiet,
					) {
						state.selection.id = item.id
						state.open = false
						state.focus_pending = false
						state.restore_focus = true
						state.query_node = 0
						state.panel_node = 0
						state.results_node = 0
						event = Event{kind=.Activated, item_id=item.id}
						alicorn.invalidate_root(ctx.runtime, "AliKit command palette item activated")
					}
				}
				alicorn.virtual_list_end(ctx, list)
			}
		}
		_ = ui.text(ctx, fmt.tprintf("%d actions  ·  ↑/↓ navigate  ·  Enter run  ·  Esc close", state.match_count),
			key=alicorn.key_string("alikit-command-palette-help"), size=13)
		alicorn.surface_end(ctx)
	}
	alicorn.modal_overlay_end(ctx)
	return
}
