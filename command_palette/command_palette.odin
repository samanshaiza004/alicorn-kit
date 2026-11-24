package command_palette

import "core:fmt"
import "core:math"
import "core:mem"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import palette "alikit:palette_model"
import parts "alikit:palette_parts"

Item_ID :: palette.Item_ID
Item :: palette.Item
Match :: palette.Match
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

// Result_List, Result_Row, and Result_Group alias the public result-list parts
// used by build. Applications that own their own modal/query shell can compose
// those parts directly; the aliases keep one result contract.
Result_List :: parts.List
Result_Row :: parts.Row
Result_Group :: parts.Group

State :: struct {
	query:          ui.Text_Buffer,
	allocator:      mem.Allocator,
	matches:        []Match,
	matches_capacity: int,
	match_count:    int,
	selection:      palette.Selection,
	// results is the retained parts-based result list (virtual list owner,
	// reveal/focus requests, and selection mirrored with `selection`).
	results:        parts.State,
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
	after_frame_registered: bool,
	initialized:    bool,
}

Options :: struct {
	title:                 string,
	query_accessible_name: string,
	results_accessible_name: string,
	empty_message:         string,
	allocation_error_message: string,
	footer_label:          string,
	query_prefix:          string,
	hide_title:            bool,
	panel_max_width:       f32,
	list_max_height:       f32,
	row_height:            f32,
	query_height:          f32,
	query_text_style:      alicorn.Text_Style,
	appearance:            Appearance,
}

// Appearance is an optional set of surface-level overrides. Components that
// leave it disabled use Alicorn's ordinary theme defaults.
Appearance :: struct {
	enabled:          bool,
	overlay_padding:  f32,
	panel_padding:    f32,
	panel_gap:        f32,
	backdrop_color:   alicorn.Color,
	panel_shape:      alicorn.Surface_Shape,
	panel_material:   alicorn.Material_ID,
	physical_height:  f32,
	panel_fill:       alicorn.Color,
	backdrop_effect:  alicorn.Backdrop_Effect,
}

DEFAULT_OPTIONS :: Options{
	title="Commands",
	query_accessible_name="Search commands",
	results_accessible_name="Results",
	empty_message="No matching commands",
	allocation_error_message="Results temporarily unavailable",
	footer_label="actions  ·  ↑/↓ navigate  ·  Enter run  ·  Esc close",
	panel_max_width=720,
	list_max_height=360,
	row_height=38,
	query_height=42,
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.title == "" { result.title = DEFAULT_OPTIONS.title }
	if result.query_accessible_name == "" { result.query_accessible_name = DEFAULT_OPTIONS.query_accessible_name }
	if result.results_accessible_name == "" { result.results_accessible_name = DEFAULT_OPTIONS.results_accessible_name }
	if result.empty_message == "" { result.empty_message = DEFAULT_OPTIONS.empty_message }
	if result.allocation_error_message == "" { result.allocation_error_message = DEFAULT_OPTIONS.allocation_error_message }
	if result.footer_label == "" { result.footer_label = DEFAULT_OPTIONS.footer_label }
	if result.panel_max_width <= 0 || math.is_nan(result.panel_max_width) || math.is_inf(result.panel_max_width) {
		result.panel_max_width = DEFAULT_OPTIONS.panel_max_width
	}
	if result.list_max_height <= 0 || math.is_nan(result.list_max_height) || math.is_inf(result.list_max_height) {
		result.list_max_height = DEFAULT_OPTIONS.list_max_height
	}
	if result.row_height <= 0 || math.is_nan(result.row_height) || math.is_inf(result.row_height) {
		result.row_height = DEFAULT_OPTIONS.row_height
	}
	if result.query_height <= 0 || math.is_nan(result.query_height) || math.is_inf(result.query_height) {
		result.query_height = DEFAULT_OPTIONS.query_height
	}
	if result.appearance.enabled {
		if result.appearance.overlay_padding < 0 || math.is_nan(result.appearance.overlay_padding) || math.is_inf(result.appearance.overlay_padding) {
			result.appearance.overlay_padding = 32
		}
		if result.appearance.panel_padding < 0 || math.is_nan(result.appearance.panel_padding) || math.is_inf(result.appearance.panel_padding) {
			result.appearance.panel_padding = 14
		}
		if result.appearance.panel_gap < 0 || math.is_nan(result.appearance.panel_gap) || math.is_inf(result.appearance.panel_gap) {
			result.appearance.panel_gap = 8
		}
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
	state.results = {}
	state.search_mode = search_mode
	palette_schedule_after_frame(state, rt)
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
	state.results.list_node = 0
	if rt != nil {
		if restore_focus { palette_schedule_after_frame(state, rt) }
		alicorn.invalidate_root(rt, "AliKit command palette closed")
	}
}

@(private)
palette_schedule_after_frame :: proc(state: ^State, rt: ^alicorn.Runtime) {
	if state == nil || rt == nil || state.after_frame_registered { return }
	if alicorn.interaction_after_frame_register(rt, rawptr(state), palette_after_frame_callback) {
		state.after_frame_registered = true
	}
}

@(private)
palette_after_frame_callback :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	state := cast(^State)data
	if state != nil { state.after_frame_registered = false }
	after_frame(state, rt)
}

@(private)
palette_text_change_callback :: proc(data: rawptr, rt: ^alicorn.Runtime, change: alicorn.Text_Change) -> bool {
	return text_change(cast(^State)data, rt, change)
}

@(private)
refresh_matches :: proc(state: ^State, items: []Item) -> bool {
	if state == nil || !state.initialized { return false }
	state.last_status = .Ready
	if state.matches_capacity < len(items) {
		new_matches, err := make([]Match, len(items), state.allocator)
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
handle_key :: proc(state: ^State, rt: ^alicorn.Runtime, items: []Item, key: alicorn.Application_Key) -> (handled: bool, event: Event) {
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
		if _, found := alicorn.node_info(rt, state.overlay_node); found {
			// A row can activate after its overlay has already been described in
			// this frame. Keep checking after the corrective description retires
			// that overlay, then restore focus behind the modal boundary.
			palette_schedule_after_frame(state, rt)
			alicorn.invalidate_root(rt, "AliKit command palette waiting for modal retirement")
			return
		}
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

@(private)
parts_options :: proc(options: Options) -> parts.Options {
	return parts.Options{
		accessible_label=options.results_accessible_name,
		empty_label=options.empty_message,
		row_height=options.row_height,
		list_max_height=options.list_max_height,
	}
}

// input describes the controlled query field used by the modal shell. It is a
// public part for applications that compose their own overlay but want the
// same controlled text and accessible label. Call it inside the shell's key
// scope; the modal scope already owns IME/text routing.
input :: proc(
	ctx: ^ui.UI,
	state: ^State,
	options: Options = {},
	key: ui.UI_Key,
) -> (node: alicorn.Node_ID, visible: bool) {
	if ctx == nil || ctx.runtime == nil || state == nil || !state.initialized { return }
	resolved := options_resolve(options)
	field := alicorn.text_field_controlled(
		ctx,
		&state.query,
		key=key,
		style=ui.layout_style(.Row, grow=1, height=resolved.query_height-4),
		text_style=resolved.query_text_style,
	)
	state.query_node = field.node
	if field.node == 0 { return }
	_ = alicorn.semantic_text_field_label(ctx, resolved.query_accessible_name)
	return field.node, true
}

// list_begin opens the public parts-based result list. The application owns
// filtering/ranking and passes a fresh visible slice. Selection is mirrored
// between the palette state and the result part.
list_begin :: proc(
	ctx: ^ui.UI,
	state: ^State,
	items: []Item,
	visible: []Match,
	key: ui.UI_Key,
	options: Options = {},
) -> (list: Result_List, opened: bool) {
	if ctx == nil || ctx.runtime == nil || state == nil || !state.initialized { return }
	resolved := options_resolve(options)
	state.results.selection = state.selection
	list, opened = parts.list_begin(ctx, &state.results, items, visible, key, parts_options(resolved))
	if opened { state.results_node = list.node }
	return
}

// result_row_key returns the retained Button key for one stable result ID.
result_row_key :: proc(id: Item_ID) -> ui.UI_Key {
	return parts.row_key(id)
}

item_begin :: proc(ctx: ^ui.UI, list: ^Result_List, index: int) -> (row: Result_Row, visible: bool) {
	return parts.item_begin(ctx, list, index)
}

item_end :: proc(ctx: ^ui.UI, state: ^State, list: ^Result_List, row: Result_Row) -> bool {
	activated := parts.item_end(ctx, list, row)
	if state != nil {
		state.selection = state.results.selection
		if activated { state.results_node = 0 }
	}
	return activated
}

list_end :: proc(ctx: ^ui.UI, state: ^State, list: ^Result_List) -> (event: Event) {
	result := parts.list_end(ctx, list)
	if state != nil {
		state.selection = state.results.selection
		state.results_node = 0
	}
	if result.kind == .Activated { return Event{kind=.Activated, item_id=result.item_id} }
	return
}

empty :: proc(ctx: ^ui.UI, options: Options = {}, key: ui.UI_Key = {}) -> alicorn.Node_ID {
	resolved := options_resolve(options)
	return parts.empty(ctx, parts_options(resolved), key=key)
}

group_begin :: proc(ctx: ^ui.UI, list: ^Result_List, label: string, key: ui.UI_Key = {}) -> (Result_Group, bool) {
	return parts.group_begin(ctx, list, label, key)
}

group_end :: proc(ctx: ^ui.UI, group: ^Result_Group) {
	parts.group_end(ctx, group)
}

@(private)
activate_result :: proc(state: ^State, rt: ^alicorn.Runtime, id: Item_ID) -> Event {
	if state == nil { return {} }
	state.selection.id = id
	close_palette(state, rt, true)
	return Event{kind=.Activated, item_id=id}
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
	if state.overlay_node != 0 {
		if queued, found := alicorn.interaction_event_next(ctx.runtime, state.overlay_node); found {
			switch queued.kind {
			case .Key:
				_, event = handle_key(state, ctx.runtime, items, queued.key)
			case .Pointer:
				_ = pointer(state, ctx.runtime, queued.pointer, queued.target)
			}
			if !state.open { return }
		}
	}
	if state.focus_pending || state.restore_focus {
		palette_schedule_after_frame(state, ctx.runtime)
	}
	_ = refresh_matches(state, items)
	resolved_options := options_resolve(options)
	appearance := resolved_options.appearance
	default_shape := alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=8}
	backdrop_color := alicorn.Color{0.02, 0.025, 0.04, 0.58}
	panel_shape := default_shape
	panel_material := alicorn.MATERIAL_FLAT
	panel_fill := alicorn.NO_BACKGROUND_COLOR
	backdrop_effect := alicorn.BACKDROP_NONE
	panel_height: f32 = 0
	overlay_padding: f32 = 32
	panel_padding: f32 = 14
	panel_gap: f32 = 8
	if appearance.enabled {
		backdrop_color = appearance.backdrop_color
		panel_shape = appearance.panel_shape
		panel_material = appearance.panel_material
		panel_fill = appearance.panel_fill
		backdrop_effect = appearance.backdrop_effect
		panel_height = appearance.physical_height
		overlay_padding = appearance.overlay_padding
		panel_padding = appearance.panel_padding
		panel_gap = appearance.panel_gap
	}

	state.overlay_node = alicorn.modal_overlay_begin(
		ctx,
		alicorn.key_string("alikit-command-palette-overlay"),
		style=ui.layout_style(.Column, grow=1, padding=overlay_padding, align=.Center, justify=.Center, clip=true),
		backdrop_color=backdrop_color,
	)
	if state.overlay_node == 0 { return }
	_ = ui.interaction_scope(ctx, state.overlay_node, rawptr(state), alicorn.Interaction_Scope_Options{
		keys={.Escape, .Open_Command_Palette, .Up, .Down, .Return},
		composition_yield_keys={.Up, .Down, .Return},
		pointers={.Primary_Down},
		modal=true,
		on_text_change=palette_text_change_callback,
	})
	state.panel_node = alicorn.surface_begin(
		ctx,
		alicorn.surface_core_color_role(.Surface),
		key=alicorn.key_string("alikit-command-palette-panel"),
		style=ui.layout_style(.Column, width=-1, height=alicorn.LAYOUT_SIZE_FIT_CONTENT,
			max_width=resolved_options.panel_max_width, max_height=resolved_options.list_max_height+150,
			padding=panel_padding, gap=panel_gap, clip=true),
		shape=panel_shape,
		material=panel_material,
		physical_height=panel_height,
		fill=panel_fill,
		backdrop_effect=backdrop_effect,
		label="alikit-command-palette-panel",
	)
	if state.panel_node != 0 {
		if !resolved_options.hide_title {
			_ = ui.text(ctx, resolved_options.title, key=alicorn.key_string("alikit-command-palette-title"), size=20)
		}
		if ui.row(ctx, key=alicorn.key_string("alikit-command-palette-query-row"), height=resolved_options.query_height, gap=4, align=.Center) {
			if resolved_options.query_prefix != "" {
				_ = ui.text(ctx, resolved_options.query_prefix,
					key=alicorn.key_string("alikit-command-palette-prefix"),
					style=ui.layout_style(.Row, width=16, height=resolved_options.query_height-4),
					text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD})
			}
			_, _ = input(ctx, state, resolved_options,
				key=alicorn.key_string("alikit-command-palette-query"))
		}

		if state.last_status == .Match_Buffer_Allocation_Failed {
			_ = ui.text(ctx, resolved_options.allocation_error_message, key=alicorn.key_string("alikit-command-palette-allocation-error"))
		} else if state.match_count == 0 {
			_ = empty(ctx, resolved_options,
				key=alicorn.key_string("alikit-command-palette-empty"))
		} else {
			list, opened := list_begin(ctx, state, items, state.matches[:state.match_count],
				key=alicorn.key_string("alikit-command-palette-results"),
				options=resolved_options)
			if opened {
				for index in list.first..<list.last {
					row, row_visible := item_begin(ctx, &list, index)
					if !row_visible { continue }
					if surface := parts.row_surface(ctx, row); surface != 0 {
						parts.icon(ctx, row)
						parts.label(ctx, row)
						parts.description(ctx, row)
						parts.indicator(ctx, row)
						alicorn.surface_end(ctx)
					}
					if item_end(ctx, state, &list, row) {
						event = activate_result(state, ctx.runtime, row.item.id)
					}
				}
				if list_event := list_end(ctx, state, &list); list_event.kind == .Activated {
					event = list_event
				}
			}
		}
		_ = ui.text(ctx, fmt.tprintf("%d %s", state.match_count, resolved_options.footer_label),
			key=alicorn.key_string("alikit-command-palette-help"), size=13)
		alicorn.surface_end(ctx)
	}
	alicorn.modal_overlay_end(ctx)
	return
}
