package progress

// Progress is a presentation-only determinate or indeterminate progress
// component built from public parts. It publishes one Progress semantic node
// with a numeric range while determinate, and never publishes a numeric value
// while indeterminate. Track, fill, label, and value are ordinary retained
// parts.
//
// Authors can use the complete progress() component or compose the parts:
//
//	p, visible := progress.begin(ctx, &state, value, minimum, maximum,
//		options=options, key=key, instance_id=1)
//	if visible {
//		progress.label(ctx, &p)
//		progress.value_text(ctx, &p)
//		track, track_visible := progress.track_begin(ctx, &p)
//		if track_visible {
//			progress.indicator(ctx, &track) // optional default fill
//			progress.track_end(ctx)
//		}
//		progress.end(ctx, &p)
//	}
//
// The author owns layout between the part calls. A linear bar, a ring donut,
// or an application-specific meter can share one numeric range, one semantic
// node, and the public fraction/geometry helpers. The component owns no timer.
// An indeterminate pulse is caller-driven: the application supplies a 0..1
// phase and may advance it from its own animation loop. When motion is enabled,
// the fill retargets through Alicorn's paint-only motion model; reduced motion
// snaps instead.

import "core:fmt"
import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import tc "alikit:theme_contract"

PROGRESS_NAMESPACE :: u64(0x50524F4752455353) // "PROGRESS"
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)
TRACK_KEY :: u64(0xA11C_3A01)
FILL_KEY :: u64(0xA11C_3A02)

Options :: struct {
	accessible_label: string,
	value_label:      string,
	// hide_label and hide_value are opt-out flags so a partial Options value
	// keeps both documented parts visible.
	hide_label:       bool,
	hide_value:       bool,
	// width is the definite track width in logical pixels. A percentage-width
	// fill needs a definite parent, so the component keeps the track explicit.
	width:            f32,
	track_height:     f32,
	track_padding:    f32,
	corner_radius:    f32,
	label_size:       f32,
	value_size:       f32,
	// indeterminate omits numeric semantics. indeterminate_phase positions the
	// active segment in 0..1; the application advances it if it wants motion.
	indeterminate:         bool,
	indeterminate_phase:   f32,
	indeterminate_width:   f32,
	// pulse opts into a paint-only opacity pulse for the indeterminate segment.
	pulse:                 bool,
}

DEFAULT_OPTIONS :: Options{
	width=260,
	track_height=10,
	track_padding=1,
	corner_radius=5,
	label_size=13,
	value_size=13,
	indeterminate_width=0.30,
}

Recipe :: struct {
	track_surface_role: alicorn.Style_Extension_Color_Role_ID,
	fill_surface_role:  alicorn.Style_Extension_Color_Role_ID,
}

Theme_Contract :: tc.Contract
Theme_Contract_Report :: tc.Report

recipe_default :: proc() -> Recipe { return {} }

theme_contract_default :: proc(recipe: Recipe) -> Theme_Contract {
	contract: Theme_Contract
	if recipe.track_surface_role == 0 {
		_ = tc.optional_role(&contract, 0, "alikit.progress.track_surface")
	} else {
		_ = tc.required_role(&contract, recipe.track_surface_role, "alikit.progress.track_surface")
	}
	if recipe.fill_surface_role == 0 {
		_ = tc.optional_role(&contract, 0, "alikit.progress.fill_surface")
	} else {
		_ = tc.required_role(&contract, recipe.fill_surface_role, "alikit.progress.fill_surface")
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
	// last_* are diagnostic values from the most recent description. They let
	// tests and applications verify phase/reduced-motion handling without
	// reading retained runtime storage.
	last_phase:          f32,
	last_reduced_motion: bool,
	last_fraction:       f64,
	has_last_fraction:   bool,
	last_fill_width:     f32,
	last_offset_width:   f32,
}

// Progress is the per-description context returned by begin. It borrows the
// caller-owned State and the application's numeric range; it allocates nothing.
Progress :: struct {
	ctx:           ^ui.UI,
	state:         ^State,
	resolved:      Options,
	recipe:        Recipe,
	value:         f64,
	minimum:       f64,
	maximum:       f64,
	normalized:    f64,
	clamped_value: f64,
	value_text:    string,
	determinate:   bool,
	root:          alicorn.Node_ID,
	visible:       bool,
}

// Track is the per-description context returned by track_begin. It carries the
// resolved inner size and the component-computed fill/offset geometry so an
// author can draw a custom indicator inside the same track.
Track :: struct {
	ctx:          ^ui.UI,
	progress:     ^Progress,
	node:         alicorn.Node_ID,
	width:        f32,
	height:       f32,
	padding:      f32,
	inner_width:  f32,
	inner_height: f32,
	fill_width:   f32,
	offset_width: f32,
	visible:      bool,
}

@(private)
mix :: proc(seed, value: u64) -> u64 {
	state := seed+value+0x9E3779B97F4A7C15
	state = (state ~ (state>>30))*0xBF58476D1CE4E5B9
	state = (state ~ (state>>27))*0x94D049BB133111EB
	return state ~ (state>>31)
}

progress_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=PROGRESS_NAMESPACE, value=mix(instance_id, 0x50524F47)}
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.accessible_label == "" { result.accessible_label = "Progress" }
	if result.width <= 0 || math.is_nan(result.width) || math.is_inf(result.width) {
		result.width = DEFAULT_OPTIONS.width
	}
	if result.track_height <= 0 || math.is_nan(result.track_height) || math.is_inf(result.track_height) {
		result.track_height = DEFAULT_OPTIONS.track_height
	}
	if result.track_padding < 0 || math.is_nan(result.track_padding) || math.is_inf(result.track_padding) {
		result.track_padding = DEFAULT_OPTIONS.track_padding
	}
	if result.corner_radius < 0 || math.is_nan(result.corner_radius) || math.is_inf(result.corner_radius) {
		result.corner_radius = DEFAULT_OPTIONS.corner_radius
	}
	if result.label_size <= 0 || math.is_nan(result.label_size) || math.is_inf(result.label_size) {
		result.label_size = DEFAULT_OPTIONS.label_size
	}
	if result.value_size <= 0 || math.is_nan(result.value_size) || math.is_inf(result.value_size) {
		result.value_size = DEFAULT_OPTIONS.value_size
	}
	if result.indeterminate_width <= 0 || result.indeterminate_width > 1 ||
	   math.is_nan(result.indeterminate_width) || math.is_inf(result.indeterminate_width) {
		result.indeterminate_width = DEFAULT_OPTIONS.indeterminate_width
	}
	if math.is_nan(result.indeterminate_phase) || math.is_inf(result.indeterminate_phase) {
		result.indeterminate_phase = 0
	}
	result.indeterminate_phase = clamp(result.indeterminate_phase, 0, 1)
	return result
}

// fraction returns the determinate value's normalized position. A non-positive
// range reports zero instead of dividing by zero.
fraction :: proc(value, minimum, maximum: f64) -> f64 {
	if !(maximum > minimum) { return 0 }
	return clamp((value-minimum)/(maximum-minimum), 0, 1)
}

// format_value returns the default human-readable percentage for a normalized
// fraction. The value is clamped to 0..1.
format_value :: proc(normalized: f64) -> string {
	return fmt.tprintf("%.0f%%", clamp(normalized, 0, 1)*100)
}

// linear_geometry computes the default fill and indeterminate-offset widths for
// a track whose content width is inner_width. It is the same public math the
// convenience progress() wrapper uses, so custom linear appearances and the
// default stay in agreement. The result is zero for a non-positive width.
linear_geometry :: proc(
	inner_width: f32,
	normalized: f64,
	indeterminate: bool = false,
	phase: f32 = 0,
	segment_width: f32 = DEFAULT_OPTIONS.indeterminate_width,
) -> (fill_width, offset_width: f32) {
	if inner_width <= 0 || math.is_nan(inner_width) || math.is_inf(inner_width) { return 0, 0 }
	segment := clamp(segment_width, 0, 1)
	if math.is_nan(segment) || math.is_inf(segment) { segment = DEFAULT_OPTIONS.indeterminate_width }
	fill_fraction: f64 = clamp(normalized, 0, 1)
	if indeterminate { fill_fraction = f64(segment) }
	fill_width = inner_width*f32(fill_fraction)
	if indeterminate {
		p := clamp(phase, 0, 1)
		if math.is_nan(p) || math.is_inf(p) { p = 0 }
		offset_width = inner_width*f32((1-segment)*p)
	}
	return
}

// ring_sweep returns the clockwise sweep in radians for a normalized fraction.
// Start at -PI/2 (12 o'clock) for the conventional progress ring.
ring_sweep :: proc(normalized: f64) -> f32 {
	return f32(clamp(normalized, 0, 1))*2*math.PI
}

// ring_shape returns a drawable Arc surface for a determinate ring. A caller
// must skip drawing when fraction <= 0 because an Arc requires a nonzero sweep.
ring_shape :: proc(
	normalized: f64,
	radius: f32 = 0.45,
	start_angle: f32 = -math.PI/2,
) -> alicorn.Surface_Shape {
	return alicorn.surface_shape_arc(start_angle, ring_sweep(normalized), radius)
}

// ring_segment_shape returns the moving indeterminate ring segment. phase and
// segment_width use the same normalized 0..1 inputs as the linear appearance.
ring_segment_shape :: proc(
	phase: f32,
	segment_width: f32 = DEFAULT_OPTIONS.indeterminate_width,
	radius: f32 = 0.45,
	start_angle: f32 = -math.PI/2,
) -> alicorn.Surface_Shape {
	segment := clamp(segment_width, 0, 1)
	p := clamp(phase, 0, 1)
	advance := (1-segment)*p
	return alicorn.surface_shape_arc(start_angle+advance*2*math.PI, segment*2*math.PI, radius)
}

@(private)
reduced_motion :: proc(rt: ^alicorn.Runtime) -> bool {
	observation := alicorn.style_root_accessibility_observation_get(rt)
	if .Reduce_Motion not_in observation.known { return false }
	return observation.preferences.reduce_motion
}

@(private)
surface_role :: proc(role: alicorn.Style_Extension_Color_Role_ID, fallback: alicorn.Style_Color_Role) -> alicorn.Semantic_Surface_Color_Role {
	if role != 0 { return alicorn.surface_extension_color_role(role) }
	return alicorn.surface_core_color_role(fallback)
}

// begin opens the progress root, binds the stable Progress semantic identity,
// and publishes the visible value plus the numeric range while determinate.
// value/minimum/maximum are ignored for numeric semantics while
// options.indeterminate is true. The value_label override replaces the
// formatted percentage in both visible and semantic values.
//
// visible is false when the runtime, state, instance identity, key scope, or
// root is unavailable; call end only when visible is true.
begin :: proc(
	ctx: ^ui.UI,
	state: ^State,
	value, minimum, maximum: f64,
	options: Options = {},
	key: ui.UI_Key = {},
	instance_id: u64,
	recipe: Recipe = {},
) -> (progress: Progress, visible: bool) {
	if ctx == nil || ctx.runtime == nil || state == nil || instance_id == 0 ||
	   instance_id > MAX_INSTANCE_ID {
		return
	}
	resolved := options_resolve(options)
	if !ui.key_scope(ctx, key) { return }
	normalized := fraction(value, minimum, maximum)
	percentage_text := format_value(normalized)
	value_text := percentage_text
	if resolved.value_label != "" { value_text = resolved.value_label }
	if resolved.indeterminate && resolved.value_label == "" { value_text = "Loading" }

	root := alicorn.container_begin(
		ctx,
		.Container,
		label=resolved.accessible_label,
		key=alicorn.key_string("alikit-progress"),
		style=ui.layout_style(.Column, width=resolved.width,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, gap=4),
	)
	if root == 0 { return }
	_ = alicorn.semantic_bind(ctx, progress_semantic_id(instance_id))
	_ = alicorn.semantic_description(ctx, .Progress, resolved.accessible_label, value=value_text)
	clamped := minimum+normalized*(maximum-minimum)
	if !resolved.indeterminate {
		_ = alicorn.semantic_numeric_range(ctx, clamped, minimum, maximum, 0)
	}

	progress = Progress{
		ctx=ctx,
		state=state,
		resolved=resolved,
		recipe=recipe,
		value=value,
		minimum=minimum,
		maximum=maximum,
		normalized=normalized,
		clamped_value=clamped,
		value_text=value_text,
		determinate=!resolved.indeterminate,
		root=root,
		visible=true,
	}

	inner_width := max(resolved.width-2*resolved.track_padding, 0)
	fill_width, offset_width := linear_geometry(inner_width, normalized,
		resolved.indeterminate, resolved.indeterminate_phase, resolved.indeterminate_width)
	state.last_phase = resolved.indeterminate_phase
	state.last_reduced_motion = reduced_motion(ctx.runtime)
	state.last_fraction = normalized
	state.has_last_fraction = !resolved.indeterminate
	state.last_fill_width = fill_width
	state.last_offset_width = offset_width
	return progress, true
}

// label emits the default label text part under the progress root. An empty
// text uses the accessible label. It is optional: omit it for a custom layout.
label :: proc(ctx: ^ui.UI, progress: ^Progress, text: string = "") -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || progress == nil || !progress.visible { return 0 }
	value := text
	if value == "" { value = progress.resolved.accessible_label }
	label_id := ui.text(ctx, value,
		key=ui.key_u64(1),
		style=ui.layout_style(.Row, grow=1),
		size=progress.resolved.label_size,
		decorative=true,
		color=alicorn.style_color(ctx, .Text),
		text_style=alicorn.Text_Style{overflow=.Ellipsis},
	)
	if label_id != 0 {
		_ = alicorn.visual_part_attach(ctx, label_id, progress.root, alicorn.visual_part_core(.Label))
	}
	return label_id
}

// value_text emits the default visible value part. An empty text uses the
// component-formatted percentage or the indeterminate "Loading" value.
// Semantic value publication is independent of this visual part.
value_text :: proc(ctx: ^ui.UI, progress: ^Progress, text: string = "") -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || progress == nil || !progress.visible { return 0 }
	value := text
	if value == "" { value = progress.value_text }
	value_id := ui.text(ctx, value,
		key=ui.key_u64(2),
		size=progress.resolved.value_size,
		decorative=true,
		color=alicorn.style_color(ctx, .Muted_Text),
	)
	if value_id != 0 {
		_ = alicorn.visual_part_attach(ctx, value_id, progress.root, alicorn.visual_part_core(.Content))
	}
	return value_id
}

// track_begin opens the default surface track and computes its inner geometry.
// width/height/padding <= 0 (padding < 0) use the resolved Options values.
// The author owns anything described after track_begin: call indicator for the
// default fill, draw a custom indicator, or open a different track entirely.
track_begin :: proc(
	ctx: ^ui.UI,
	progress: ^Progress,
	width: f32 = 0,
	height: f32 = 0,
	padding: f32 = -1,
) -> (track: Track, visible: bool) {
	if ctx == nil || ctx.runtime == nil || progress == nil || !progress.visible { return }
	resolved := progress.resolved
	track_width := width
	if track_width <= 0 { track_width = resolved.width }
	track_height := height
	if track_height <= 0 { track_height = resolved.track_height }
	track_padding := padding
	if track_padding < 0 { track_padding = resolved.track_padding }

	track_node := alicorn.surface_begin(
		ctx,
		surface_role(progress.recipe.track_surface_role, .Subtle_Surface),
		key=ui.key_u64(3),
		style=ui.layout_style(.Row, width=track_width, height=track_height,
			padding=track_padding, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=resolved.corner_radius},
		label="progress-track",
	)
	if track_node == 0 { return }
	_ = alicorn.visual_part_attach(ctx, track_node, progress.root, alicorn.visual_part_core(.Surface))
	inner_width := max(track_width-2*track_padding, 0)
	inner_height := max(track_height-2*track_padding, 0)
	fill_width, offset_width := linear_geometry(inner_width, progress.normalized,
		resolved.indeterminate, resolved.indeterminate_phase, resolved.indeterminate_width)
	track = Track{
		ctx=ctx,
		progress=progress,
		node=track_node,
		width=track_width,
		height=track_height,
		padding=track_padding,
		inner_width=inner_width,
		inner_height=inner_height,
		fill_width=fill_width,
		offset_width=offset_width,
		visible=true,
	}
	progress.state.last_phase = resolved.indeterminate_phase
	progress.state.last_fraction = progress.normalized
	progress.state.has_last_fraction = !resolved.indeterminate
	progress.state.last_fill_width = fill_width
	progress.state.last_offset_width = offset_width
	return track, true
}

// indicator draws the default fill (and the indeterminate offset segment)
// inside an open track. It is optional; the author can instead draw any custom
// indicator inside the track or replace the track entirely. The semantic
// Progress owner is unchanged.
indicator :: proc(ctx: ^ui.UI, track: ^Track) -> alicorn.Node_ID {
	if ctx == nil || ctx.runtime == nil || track == nil || !track.visible || track.progress == nil {
		return 0
	}
	progress := track.progress
	resolved := progress.resolved
	if track.offset_width > 0 {
		_ = alicorn.container_begin(ctx, .Container,
			label="progress-indeterminate-offset",
			key=ui.key_u64(4),
			style=ui.layout_style(.Row, width=track.offset_width,
				height=track.inner_height),
		)
		alicorn.container_end(ctx)
	}
	if track.fill_width <= 0 { return 0 }
	fill := alicorn.surface_begin(
		ctx,
		surface_role(progress.recipe.fill_surface_role, .Accent),
		key=ui.key_u64(FILL_KEY),
		style=ui.layout_style(.Row, width=track.fill_width,
			height=track.inner_height),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle,
			corner_radius=max(resolved.corner_radius-track.padding, 0)},
		label="progress-fill",
	)
	if fill == 0 { return 0 }
	_ = alicorn.visual_part_attach(ctx, fill, progress.root, alicorn.visual_part_core(.Indicator))
	if resolved.pulse && resolved.indeterminate {
		alpha := 0.62+0.38*f32((math.sin(f64(resolved.indeterminate_phase)*2*math.PI)+1)*0.5)
		intent := alicorn.Motion_Intent.Settle
		if reduced_motion(ctx.runtime) { intent = .Snap }
		_ = ui.motion(ctx, fill, alicorn.Motion_Target{opacity=f64(alpha), has_opacity=true}, intent)
	}
	alicorn.surface_end(ctx)
	return fill
}

// track_end closes the surface scope opened by track_begin.
track_end :: proc(ctx: ^ui.UI) {
	if ctx == nil { return }
	alicorn.surface_end(ctx)
}

// end closes the progress root. Call it only when begin returned visible=true.
end :: proc(ctx: ^ui.UI, progress: ^Progress) {
	if ctx == nil || progress == nil || !progress.visible { return }
	alicorn.container_end(ctx)
	progress.visible = false
	progress.root = 0
}

// progress is the convenience component built from the exact public parts.
// It preserves the original linear appearance, label/value heading, and
// determinate/indeterminate behavior. The returned value is not used.
progress :: proc(
	ctx: ^ui.UI,
	state: ^State,
	value, minimum, maximum: f64,
	options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
	recipe: Recipe = {},
) {
	part, visible := begin(ctx, state, value, minimum, maximum, options, key, instance_id, recipe)
	if !visible { return }
	if !part.resolved.hide_label || !part.resolved.hide_value {
		if ui.row(ctx, key=alicorn.key_string("alikit-progress-heading"), width=-1,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, align=.Center, gap=8) {
			if !part.resolved.hide_label { label(ctx, &part) }
			if !part.resolved.hide_value { value_text(ctx, &part) }
		}
	}
	track, track_visible := track_begin(ctx, &part)
	if track_visible {
		indicator(ctx, &track)
		track_end(ctx)
	}
	end(ctx, &part)
}
