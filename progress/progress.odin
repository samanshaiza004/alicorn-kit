package progress

// Progress is a presentation-only determinate or indeterminate progress bar.
// It publishes one Progress semantic node with a numeric range while
// determinate, and never publishes a numeric value while indeterminate. Track,
// fill, label, and value are ordinary retained parts.
//
// The component owns no timer. An indeterminate pulse is caller-driven: the
// application supplies a 0..1 phase and may advance it from its own animation
// loop. When motion is enabled, the fill retargets through Alicorn's paint-only
// motion model; reduced motion snaps instead.

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

@(private)
formatted_value :: proc(fraction: f64) -> string {
	return fmt.tprintf("%.0f%%", fraction*100)
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

// progress describes one progress bar. value/minimum/maximum are ignored for
// numeric semantics while options.indeterminate is true. The value_label
// override replaces the formatted percentage in both visible and semantic
// values.
progress :: proc(
	ctx: ^ui.UI,
	state: ^State,
	value, minimum, maximum: f64,
	options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
	recipe: Recipe = {},
) {
	if ctx == nil || ctx.runtime == nil || instance_id == 0 || instance_id > MAX_INSTANCE_ID { return }
	resolved := options_resolve(options)
	if !ui.key_scope(ctx, key) { return }
	normalized := fraction(value, minimum, maximum)
	percentage_text := formatted_value(normalized)
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
	if !resolved.indeterminate {
		clamped := minimum+normalized*(maximum-minimum)
		_ = alicorn.semantic_numeric_range(ctx, clamped, minimum, maximum, 0)
	}

	if !resolved.hide_label || !resolved.hide_value {
		if ui.row(ctx, key=alicorn.key_string("alikit-progress-heading"), width=-1,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, align=.Center, gap=8) {
			if !resolved.hide_label {
				label := resolved.accessible_label
				if resolved.value_label != "" && resolved.accessible_label == "" { label = resolved.value_label }
				label_id := ui.text(ctx, label,
					key=ui.key_u64(1),
					style=ui.layout_style(.Row, grow=1),
					size=resolved.label_size,
					decorative=true,
					color=alicorn.style_color(ctx, .Text),
					text_style=alicorn.Text_Style{overflow=.Ellipsis},
				)
				if label_id != 0 {
					_ = alicorn.visual_part_attach(ctx, label_id, root, alicorn.visual_part_core(.Label))
				}
			}
			if !resolved.hide_value {
				value_id := ui.text(ctx, value_text,
					key=ui.key_u64(2),
					size=resolved.value_size,
					decorative=true,
					color=alicorn.style_color(ctx, .Muted_Text),
				)
				if value_id != 0 {
					_ = alicorn.visual_part_attach(ctx, value_id, root, alicorn.visual_part_core(.Content))
				}
			}
		}
	}

	inner_width := max(resolved.width-2*resolved.track_padding, 0)
	fill_fraction := normalized
	if resolved.indeterminate { fill_fraction = f64(resolved.indeterminate_width) }
	fill_width := inner_width*f32(fill_fraction)
	offset_width: f32 = 0
	if resolved.indeterminate {
		offset_width = inner_width*f32((1-resolved.indeterminate_width)*resolved.indeterminate_phase)
	}

	track := alicorn.surface_begin(
		ctx,
		surface_role(recipe.track_surface_role, .Subtle_Surface),
		key=ui.key_u64(3),
		style=ui.layout_style(.Row, width=resolved.width, height=resolved.track_height,
			padding=resolved.track_padding, align=.Center),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=resolved.corner_radius},
		label="progress-track",
	)
	if track != 0 {
		_ = alicorn.visual_part_attach(ctx, track, root, alicorn.visual_part_core(.Surface))
		if offset_width > 0 {
			_ = alicorn.container_begin(ctx, .Container,
				label="progress-indeterminate-offset",
				key=ui.key_u64(4),
				style=ui.layout_style(.Row, width=offset_width,
					height=max(resolved.track_height-2*resolved.track_padding, 0)),
			)
			alicorn.container_end(ctx)
		}
		if fill_width > 0 {
			fill := alicorn.surface_begin(
				ctx,
				surface_role(recipe.fill_surface_role, .Accent),
				key=ui.key_u64(FILL_KEY),
				style=ui.layout_style(.Row, width=fill_width,
					height=max(resolved.track_height-2*resolved.track_padding, 0)),
				shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle,
					corner_radius=max(resolved.corner_radius-resolved.track_padding, 0)},
				label="progress-fill",
			)
			if fill != 0 {
				_ = alicorn.visual_part_attach(ctx, fill, root, alicorn.visual_part_core(.Indicator))
				if resolved.pulse && resolved.indeterminate {
					alpha := 0.62+0.38*f32((math.sin(f64(resolved.indeterminate_phase)*2*math.PI)+1)*0.5)
					intent := alicorn.Motion_Intent.Settle
					if reduced_motion(ctx.runtime) { intent = .Snap }
					_ = ui.motion(ctx, fill, alicorn.Motion_Target{opacity=f64(alpha), has_opacity=true}, intent)
				}
				alicorn.surface_end(ctx)
			}
		}
		alicorn.surface_end(ctx)
	}

	if state != nil {
		state.last_phase = resolved.indeterminate_phase
		state.last_reduced_motion = reduced_motion(ctx.runtime)
		state.last_fraction = normalized
		state.has_last_fraction = !resolved.indeterminate
		state.last_fill_width = fill_width
		state.last_offset_width = offset_width
	}
	alicorn.container_end(ctx)
}
