package scroll_area

// Scroll Area is a styled, focusable scroll container over Alicorn's retained
// Scroll_Region. Alicorn owns wheel input, scrollbar geometry, bar painting,
// offset retention, clipping, and the resolved viewport. AliKit owns the
// component contract the gallery previously rebuilt by hand:
//
//   - one bounded or intrinsic viewport (content height from a caller line
//     count or explicit extent, capped by max_height);
//   - keyboard scrolling on the focused region (Up/Down, Page Up/Down,
//     Home/End) because Alicorn does not bind keys to a Scroll_Region;
//   - a published Scroll_View role, an accessible name, and a single Tab stop;
//   - a theme-level scrollbar recipe (track, thumb, corner) and bar-part
//     geometry for tests and application overlays;
//   - a stable identity and retained offset across rebuilds.
//
// This component does not virtualize content. Use `alicorn.virtual_list_begin`
// or `alikit:data_grid` for large data. It owns no destroyable resources.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import tc "alikit:theme_contract"

SCROLL_AREA_NAMESPACE :: u64(0x5343524F4C4C4101) // "SCROLLA"
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)

// Alicorn owns these geometry constants. They are re-exported so a caller can
// reason about bar parts without reaching into runtime storage.
BAR_THICKNESS :: alicorn.SCROLLBAR_THICKNESS
MIN_THUMB :: alicorn.SCROLLBAR_MIN_THUMB

// Bar_Policy selects retained scrollbar visibility. Auto is the zero value so a
// partial Options value keeps the useful default.
Bar_Policy :: enum { Auto, Hidden, Always }

@(private)
bar_policy_resolve :: proc(policy: Bar_Policy) -> alicorn.Scrollbar_Policy {
	switch policy {
	case .Auto: return .Auto
	case .Hidden: return .Hidden
	case .Always: return .Always
	}
	return .Auto
}

Options :: struct {
	accessible_label: string,
	axes:             alicorn.Scroll_Axes,
	// viewport_height/width are explicit bounds. A zero height with
	// fit_content measures the viewport from content up to max_height.
	viewport_height: f32,
	viewport_width:  f32,
	fit_content:     bool,
	min_height:      f32,
	max_height:      f32,
	// content_height/width are logical extents. If content_height is zero and
	// line_count is positive, content_height = line_count*line_height.
	content_height: f32,
	content_width:  f32,
	line_count:     int,
	line_height:    f32,
	line_width:     f32,
	padding:        f32,
	// bar_policy selects retained bar visibility. Auto is the zero value.
	bar_policy: Bar_Policy,
	axis_behavior:  alicorn.Scroll_Axis_Behavior,
	// non_focusable opts the region out of the default single Tab stop.
	non_focusable:  bool,
}

DEFAULT_OPTIONS :: Options{
	accessible_label="Scroll area",
	axes=.Vertical,
	line_height=24,
	line_width=24,
	axis_behavior=.Auto_Lock,
}

Recipe :: struct {
	// frame_role tints the region background. Zero uses Surface.
	frame_surface_role: alicorn.Style_Extension_Color_Role_ID,
	// The pinned runtime resolves scrollbar colors from the registered theme,
	// not per node. theme_scrollbar_recipe maps these core roles into the
	// theme's Scrollbar_Recipe at setup time.
	track_role:  alicorn.Style_Color_Role,
	thumb_role:  alicorn.Style_Color_Role,
	corner_role: alicorn.Style_Color_Role,
}

DEFAULT_RECIPE :: Recipe{
	track_role=.Scrollbar_Track,
	thumb_role=.Scrollbar_Thumb,
	corner_role=.Surface,
}

Style :: struct {
	corner_radius: f32,
	stroke_width:  f32,
}

DEFAULT_STYLE :: Style{corner_radius=8, stroke_width=1}

Theme_Contract :: tc.Contract
Theme_Contract_Report :: tc.Report

State :: struct {
	region: alicorn.Node_ID,

	offset_y: f32,
	offset_x: f32,
	content_height: f32,
	content_width: f32,
	viewport_height: f32,
	viewport_width: f32,
	max_scroll_y: f32,
	max_scroll_x: f32,
	viewport_bounds: alicorn.Rect,
	vertical_bar_visible: bool,
	horizontal_bar_visible: bool,

	focus_pending:          bool,
	after_frame_registered: bool,
	key_scope_open:         bool,
	instance_id:            u64,
}

// Bar_Geometry is the component-level track/thumb part geometry for the
// vertical bar. It mirrors the runtime's retained bar geometry for tests and
// application overlays; it does not move interaction ownership.
Bar_Geometry :: struct {
	track:  alicorn.Rect,
	thumb:  alicorn.Rect,
	visible: bool,
}

recipe_default :: proc() -> Recipe { return DEFAULT_RECIPE }
style_default :: proc() -> Style { return DEFAULT_STYLE }

theme_contract_default :: proc(recipe: Recipe) -> Theme_Contract {
	contract: Theme_Contract
	_ = role_requirement(&contract, recipe.frame_surface_role, "alikit.scroll_area.frame_surface")
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

// theme_scrollbar_recipe maps the component's part roles onto the theme-level
// Scrollbar_Recipe. Install it during theme setup:
//
//	theme := alicorn.DEFAULT_STYLE_THEME
//	theme.scrollbar_recipe = scroll_area.theme_scrollbar_recipe(recipe)
//	id := alicorn.style_theme_register(rt, theme)
//
// The runtime does not support a per-node scrollbar color override, so this is
// the only styling seam for track/thumb/corner at the pinned revision.
theme_scrollbar_recipe :: proc(recipe: Recipe) -> alicorn.Scrollbar_Recipe {
	result := alicorn.DEFAULT_SCROLLBAR_RECIPE
	result.defined = true
	if recipe.track_role != .Count { result.track_role = recipe.track_role }
	if recipe.thumb_role != .Count { result.thumb_role = recipe.thumb_role }
	if recipe.corner_role != .Count { result.corner_role = recipe.corner_role }
	return result
}

recipe_is_valid :: proc(recipe: Recipe) -> bool {
	return recipe.track_role != .Count && recipe.thumb_role != .Count && recipe.corner_role != .Count
}

// recipe_resolve fills zero part roles with the documented core defaults, so a
// partial Recipe value (including the zero value) needs no setup.
recipe_resolve :: proc(recipe: Recipe) -> Recipe {
	result := recipe
	if result.track_role == .Count { result.track_role = DEFAULT_RECIPE.track_role }
	if result.thumb_role == .Count { result.thumb_role = DEFAULT_RECIPE.thumb_role }
	if result.corner_role == .Count { result.corner_role = DEFAULT_RECIPE.corner_role }
	return result
}

scroll_area_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=SCROLL_AREA_NAMESPACE, value=instance_id*0x9E3779B97F4A7C15+1}
}

@(private)
mix :: proc(seed, value: u64) -> u64 {
	state := seed+value+0x9E3779B97F4A7C15
	state = (state ~ (state>>30))*0xBF58476D1CE4E5B9
	state = (state ~ (state>>27))*0x94D049BB133111EB
	return state ~ (state>>31)
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.accessible_label == "" { result.accessible_label = DEFAULT_OPTIONS.accessible_label }
	if result.line_height <= 0 || math.is_nan(result.line_height) || math.is_inf(result.line_height) {
		result.line_height = DEFAULT_OPTIONS.line_height
	}
	if result.line_width <= 0 || math.is_nan(result.line_width) || math.is_inf(result.line_width) {
		result.line_width = DEFAULT_OPTIONS.line_width
	}
	if result.padding < 0 || math.is_nan(result.padding) || math.is_inf(result.padding) {
		result.padding = 0
	}
	if result.min_height < 0 || math.is_nan(result.min_height) || math.is_inf(result.min_height) {
		result.min_height = 0
	}
	if result.max_height < 0 || math.is_nan(result.max_height) || math.is_inf(result.max_height) {
		result.max_height = 0
	}
	if result.content_height <= 0 && result.line_count > 0 {
		result.content_height = f32(result.line_count)*result.line_height
	}
	return result
}

// content_height_from_lines is the small sizing helper that replaces the
// gallery's hand-maintained section-height table. It includes optional padding
// on both edges.
content_height_from_lines :: proc(line_count: int, line_height: f32, padding: f32 = 0) -> f32 {
	if line_count <= 0 || line_height <= 0 { return 0 }
	return f32(line_count)*line_height+2*max(padding, 0)
}

// content_height_from_measure adds one measured content extent (for example a
// text node's height) to the region padding.
content_height_from_measure :: proc(measured_height: f32, padding: f32 = 0) -> f32 {
	if measured_height <= 0 || math.is_nan(measured_height) || math.is_inf(measured_height) { return 0 }
	return measured_height+2*max(padding, 0)
}

request_focus :: proc(state: ^State) -> bool {
	if state == nil { return false }
	state.focus_pending = true
	return true
}

offset_y :: proc(state: ^State) -> f32 { return state != nil ? state.offset_y : 0 }
offset_x :: proc(state: ^State) -> f32 { return state != nil ? state.offset_x : 0 }

max_scroll_y :: proc(state: ^State) -> f32 {
	if state == nil { return 0 }
	return max(state.content_height-state.viewport_height, 0)
}

// bar_geometry computes the vertical track and thumb parts from the last
// resolved viewport. The thumb obeys Alicorn's minimum length.
bar_geometry :: proc(state: ^State) -> Bar_Geometry {
	if state == nil || !state.vertical_bar_visible || state.viewport_height <= 0 || state.content_height <= 0 {
		return {}
	}
	bounds := state.viewport_bounds
	if bounds.w <= 0 || bounds.h <= 0 {
		bounds = alicorn.Rect{0, 0, state.viewport_width, state.viewport_height}
	}
	track := alicorn.Rect{
		x=bounds.x+bounds.w-BAR_THICKNESS,
		y=bounds.y,
		w=BAR_THICKNESS,
		h=bounds.h,
	}
	travel := max(bounds.h-MIN_THUMB, 0)
	thumb_height := max(bounds.h*(state.viewport_height/state.content_height), MIN_THUMB)
	thumb_height = min(thumb_height, bounds.h)
	max_offset := max(state.content_height-state.viewport_height, 0)
	position := f32(0)
	if max_offset > 0 {
		position = clamp(state.offset_y/max_offset, 0, 1)
	}
	thumb_y := bounds.y+(bounds.h-thumb_height)*position
	return Bar_Geometry{track=track, thumb=alicorn.Rect{x=track.x, y=thumb_y, w=track.w, h=thumb_height}, visible=true}
}

@(private)
refresh_offsets :: proc(rt: ^alicorn.Runtime, state: ^State) {
	if rt == nil || state == nil || state.region == 0 { return }
	state.offset_y = alicorn.scroll_region_offset(rt, state.region)
	state.offset_x = alicorn.scroll_region_offset_x(rt, state.region)
}

@(private)
snapshot :: proc(state: ^State, handle: alicorn.Scroll_Region_Handle) {
	state.region = handle.id
	state.offset_y = handle.offset_y
	state.offset_x = handle.offset_x
	state.content_height = handle.content_height
	state.content_width = handle.content_width
	state.viewport_height = handle.viewport_height
	state.viewport_width = handle.viewport_width
	state.max_scroll_y = handle.max_scroll_y
	state.max_scroll_x = handle.max_scroll_x
	state.viewport_bounds = handle.viewport_bounds
	state.vertical_bar_visible = handle.vertical_bar_visible
	state.horizontal_bar_visible = handle.horizontal_bar_visible
}

@(private)
apply_key :: proc(rt: ^alicorn.Runtime, state: ^State, options: Options, key: alicorn.Application_Key) -> bool {
	if rt == nil || state == nil || state.region == 0 { return false }
	page := max(state.viewport_height-options.line_height, options.line_height)
	target := state.offset_y
	changed := true
	#partial switch key {
	case .Up:
		target -= options.line_height
	case .Down:
		target += options.line_height
	case .Page_Up:
		target -= page
	case .Page_Down:
		target += page
	case .Home:
		target = 0
	case .End:
		target = state.content_height
	case:
		changed = false
	}
	if !changed { return false }
	return alicorn.scroll_region_set_offset(rt, state.region, target, "scroll area keyboard")
}

// scroll_to sets the vertical offset (clamped by the runtime) and requests a
// redescription. It is an application command, not retained input.
scroll_to :: proc(rt: ^alicorn.Runtime, state: ^State, offset: f32, reason := "scroll area command") -> bool {
	if rt == nil || state == nil || state.region == 0 { return false }
	if !alicorn.number_is_finite(offset) { return false }
	changed := alicorn.scroll_region_set_offset(rt, state.region, offset, reason)
	if changed {
		state.offset_y = clamp(offset, 0, max(state.content_height-state.viewport_height, 0))
	}
	return changed
}

scroll_to_line :: proc(rt: ^alicorn.Runtime, state: ^State, line: int, options: Options) -> bool {
	resolved := options_resolve(options)
	return scroll_to(rt, state, f32(max(line, 0))*resolved.line_height)
}

scroll_page :: proc(rt: ^alicorn.Runtime, state: ^State, pages: int, options: Options) -> bool {
	resolved := options_resolve(options)
	page := max(state.viewport_height-resolved.line_height, resolved.line_height)
	return scroll_to(rt, state, state.offset_y+f32(pages)*page)
}

@(private)
schedule_after_frame :: proc(state: ^State, rt: ^alicorn.Runtime) {
	if state == nil || rt == nil || state.after_frame_registered { return }
	if alicorn.interaction_after_frame_register(rt, rawptr(state), scroll_after_frame) {
		state.after_frame_registered = true
	}
}

@(private)
scroll_after_frame :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	state := cast(^State)data
	if state == nil || rt == nil { return }
	state.after_frame_registered = false
	if state.focus_pending && state.region != 0 {
		if alicorn.focus(rt, state.region) {
			state.focus_pending = false
			alicorn.focus_indicator_set(rt, true)
		}
	}
	if state.focus_pending { schedule_after_frame(state, rt) }
}

// begin opens one scroll area. Call end after the content. The region is the
// single Tab stop; its offset is retained by the runtime across rebuilds.
// instance_id must be stable and unique among mounted scroll areas.
begin :: proc(
	ctx: ^ui.UI,
	state: ^State,
	options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
	recipe: Recipe = {},
	style: Style = {},
) -> bool {
	if ctx == nil || ctx.runtime == nil || state == nil || instance_id == 0 ||
	   instance_id > MAX_INSTANCE_ID {
		return false
	}
	resolved_recipe := recipe_resolve(recipe)
	if !recipe_is_valid(resolved_recipe) { return false }
	resolved := options_resolve(options)
	if state.instance_id != 0 && state.instance_id != instance_id { state^ = State{} }
	state.instance_id = instance_id
	if !ui.key_scope(ctx, key) { return false }
	state.key_scope_open = true

	// Consume input routed to the previous description before the replacement
	// region is emitted. Mutating the still-retained node lets the new
	// description carry the updated offset into reconciliation.
	if state.region != 0 {
		for {
			queued, found := alicorn.interaction_event_next(ctx.runtime, state.region)
			if !found { break }
			if queued.kind == .Key && apply_key(ctx.runtime, state, resolved, queued.key) {
				alicorn.invalidate_root(ctx.runtime, "scroll area keyboard")
			}
		}
		state.offset_y = alicorn.scroll_region_offset(ctx.runtime, state.region)
		state.offset_x = alicorn.scroll_region_offset_x(ctx.runtime, state.region)
	}

	height := resolved.viewport_height
	if resolved.fit_content {
		// The component computes the cap itself: the pinned Scroll_Region
		// fit-content path does not resolve a nonzero bounds height inside a
		// Column parent, so an explicit viewport is the reliable contract.
		fit_height := resolved.content_height+2*resolved.padding
		if resolved.max_height > 0 { fit_height = min(fit_height, resolved.max_height) }
		fit_height = max(fit_height, resolved.min_height)
		if fit_height <= 0 { fit_height = resolved.line_height }
		height = fit_height
	}
	style_height := height
	region_style := ui.layout_style(.Column,
		width=(resolved.viewport_width if resolved.viewport_width > 0 else f32(-1)),
		height=style_height,
		min_height=resolved.min_height,
		max_height=(resolved.max_height if resolved.max_height > 0 else f32(-1)),
		padding=resolved.padding,
		clip=true,
	)
	fill_color := alicorn.style_color(ctx, .Surface)
	if resolved_recipe.frame_surface_role != 0 {
		theme := ctx.runtime.style_environment.theme
		if theme == 0 { theme = alicorn.DEFAULT_STYLE_THEME_ID }
		if color, found := alicorn.style_extension_color(ctx.runtime, theme, resolved_recipe.frame_surface_role); found {
			fill_color = color
		}
	}
	handle := alicorn.scroll_region_begin(
		ctx,
		key=ui.key_pair(0xA11C_5C01, instance_id),
		viewport_height=height,
		content_height=resolved.content_height,
		line_height=resolved.line_height,
		viewport_width=resolved.viewport_width,
		content_width=resolved.content_width,
		line_width=resolved.line_width,
		style=region_style,
		color=fill_color,
		label=resolved.accessible_label,
		axes=resolved.axes,
		axis_behavior=resolved.axis_behavior,
		scrollbars=bar_policy_resolve(resolved.bar_policy),
		focusable=!resolved.non_focusable,
	)
	if handle.id == 0 { return false }
	snapshot(state, handle)
	_ = alicorn.semantic_description(ctx, .Scroll_View, resolved.accessible_label,
		description="Scrollable content")
	_ = alicorn.semantic_bind(ctx, scroll_area_semantic_id(instance_id))

	keys := alicorn.Interaction_Key_Set{.Up, .Down, .Page_Up, .Page_Down, .Home, .End}
	_ = ui.interaction_scope(ctx, handle.id, rawptr(state), alicorn.Interaction_Scope_Options{
		keys=keys,
		composition_yield_keys=keys,
		modal=false,
	})
	if state.focus_pending { schedule_after_frame(state, ctx.runtime) }
	return true
}

end :: proc(ctx: ^ui.UI, state: ^State) {
	if ctx == nil || ctx.runtime == nil { return }
	alicorn.scroll_region_end(ctx)
	if state != nil && state.key_scope_open {
		alicorn.key_scope_end(ctx)
		state.key_scope_open = false
	}
}

// thumb_parts is a convenience alias for bar_geometry used by tests and
// application overlays that style their own thumb.
thumb_parts :: proc(state: ^State) -> Bar_Geometry {
	return bar_geometry(state)
}
