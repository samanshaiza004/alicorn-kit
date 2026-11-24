# Progress Bar

`alikit:progress` presents determinate or indeterminate work. A determinate bar
publishes role `Progress`, a visible percentage, and a numeric value/minimum/
maximum. An indeterminate bar publishes no numeric value.

Use a determinate bar when progress is measurable; use the indeterminate form
only for unknown work, and prefer a label that names the operation.

## Preview

The default appearance is a labelled linear bar with a value, plus an
indeterminate bar whose active segment the application advances. The parts
example renders the same numeric range as a linear bar and as a ring donut with
centered value text; a second ring shows an indeterminate segment. The
composition example hosts progress parts inside a modal export dialog.

Native captures in the catalog predate the parts examples; re-capture is
pending. The behavior, semantics, and source below are current.

## Installation

Copy these files into an application or import the package with the AliKit
collection:

- `progress/progress.odin`
- `progress/progress_test.odin` (conformance)
- `examples/progress/main.odin` (default appearance)
- `examples/progress_parts/main.odin` (linear and ring parts)
- `examples/progress_composition/main.odin` (dialog composition)

```odin
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import progress "alikit:progress"
```

No init or destroy is required. The component allocates nothing.

## Composition

There are three supported authoring paths:

1. Import the complete component and call `progress.progress`.
2. Import the parts and compose the label, value, track, and indicator.
3. Import the parts, copy the source, and draw an application-specific
   presentation from the public fraction and geometry helpers.

`progress` itself is a convenience wrapper built from the exact public parts, so
the default and custom paths share one semantic node and one numeric contract.

| Layer | Responsibility |
| --- | --- |
| Alicorn | Layout, semantic surfaces, `Progress` role, `semantic_numeric_range`, retained paint, reduced-motion preference, and paint-only motion. |
| `progress` | Root semantics, default label/value/track/fill parts, clamping, percentage formatting, indeterminate segment geometry, ring/linear geometry helpers, optional pulse declaration, namespaced surface recipe. |
| Application | Owns the value/range and the indeterminate phase. It advances the phase from its own animation loop if it wants continuous motion. |

The component has no timer, animation lifecycle, or application value. `State`
holds only diagnostic values from the most recent description, so an application
or test can inspect the resolved fraction, phase, reduced-motion decision, and
segment geometry without retained-runtime access.

The default wrapper draws this shape:

```text
begin      -> Progress semantic node, accessible value, numeric range
  label       (optional) -> heading text
  value_text  (optional) -> visible percentage or Loading
  track_begin -> surface track and computed inner geometry
    indicator (optional) -> default fill and indeterminate offset
  track_end
end
```

## Minimal example

```odin
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import progress "alikit:progress"

App :: struct {
	upload: progress.State,
	value:  f64,
}

// During the application description:
progress.progress(
	ctx,
	&app.upload,
	app.value, 0, 100,
	progress.Options{accessible_label="Upload progress", width=320},
	key=alicorn.key_string("upload"),
	instance_id=1,
)
```

No init or destroy is required. For multiple instances in one parent, give each
one a keyed parent scope so the component-internal keys stay distinct; the
default example does this for its four download bars and the loading bar.

## Controlled example

The application owns the value, range, and indeterminate phase. A value change
is ordinary application state; the component re-describes only its own
frontier:

```odin
progress.progress(ctx, &app.upload, app.bytes_done, 0, app.bytes_total,
	progress.Options{
		accessible_label="Upload progress",
		value_label=fmt.tprintf("%.1f MB", f64(app.bytes_done)/1e6),
		width=360,
	},
	key=alicorn.key_string("upload"), instance_id=41)
```

`value_label` overrides the formatted percentage in both the visible value and
the semantic value. Determinate progress additionally publishes
`semantic_numeric_range(clamped_value, minimum, maximum, 0)`. The numeric and
visible values use the same clamped fraction; a non-positive range reports zero
without dividing by zero.

Indeterminate work has no numeric value. Supply a caller-driven phase:

```odin
progress.progress(ctx, &app.loading, 0, 0, 1,
	progress.Options{
		accessible_label="Loading workspace",
		width=360,
		indeterminate=true,
		indeterminate_phase=app.phase, // 0..1, advanced by the application
		pulse=true,
	},
	key=alicorn.key_string("loading"), instance_id=42)
```

The component never owns a timer. When the host reports Reduce Motion, the
component declares `Motion_Intent.Snap` and the pulse does not animate.

## Custom rendering examples

The default parts:

```odin
part, visible := progress.begin(ctx, &app.upload, app.value, 0, 100,
	progress.Options{accessible_label="Upload progress", width=320},
	key=alicorn.key_string("upload"), instance_id=43)
if visible {
	progress.label(ctx, &part)
	progress.value_text(ctx, &part)

	track, track_visible := progress.track_begin(ctx, &part)
	if track_visible {
		progress.indicator(ctx, &track) // omit for a custom fill
		progress.track_end(ctx)
	}
	progress.end(ctx, &part)
}
```

A ring donut from the same range uses no track part at all:

```odin
part, visible := progress.begin(ctx, &app.export, app.value, 0, 100,
	progress.Options{accessible_label="Export", width=180},
	key=alicorn.key_string("export-ring"), instance_id=44)
if visible {
	if ui.row(ctx, key=ui.key_u64(1), width=160, height=160,
		align=.Center, justify=.Center) {
		// Track ring: an authored circle surface, not a Progress part.
		track := alicorn.surface_begin(ctx,
			alicorn.surface_core_color_role(.Subtle_Surface), key=ui.key_u64(2),
			style=ui.layout_style(.Row, width=160, height=160),
			shape=alicorn.Surface_Shape{kind=.Circle},
			fill=alicorn.Color{0,0,0,0},
			stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Border), width=12},
			label="ring-track")
		if track != 0 {
			alicorn.surface_end(ctx)
			_ = alicorn.position_child(ctx, track, alicorn.positioned(0, 0))
		}
		// The component supplies the fraction-to-arc conversion.
		if part.normalized > 0 {
			arc := alicorn.surface_begin(ctx,
				alicorn.surface_core_color_role(.Accent), key=ui.key_u64(3),
				style=ui.layout_style(.Row, width=160, height=160),
				shape=progress.ring_shape(part.normalized),
				fill=alicorn.Color{0,0,0,0},
				stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Accent), width=12},
				label="ring-arc")
			if arc != 0 {
				alicorn.surface_end(ctx)
				_ = alicorn.position_child(ctx, arc, alicorn.positioned(0, 0))
			}
		}
		if ui.column(ctx, key=ui.key_u64(4), width=160, height=160,
			align=.Center, justify=.Center) {
			ui.text(ctx, progress.format_value(part.normalized), key=ui.key_u64(5), size=30)
		}
	}
	progress.end(ctx, &part)
}
```

Public geometry helpers:

| Helper | Result |
| --- | --- |
| `fraction(value, minimum, maximum)` | Clamped normalized fraction; zero for a non-positive range. |
| `format_value(normalized)` | Default percentage text (`"42%"`). |
| `linear_geometry(inner_width, normalized, indeterminate, phase, segment_width)` | `(fill_width, offset_width)` for a linear track. |
| `ring_sweep(normalized)` | Clockwise arc sweep in radians. |
| `ring_shape(normalized, radius, start_angle)` | Arc `Surface_Shape` starting at twelve o'clock by default. |
| `ring_segment_shape(phase, segment_width, radius, start_angle)` | Moving indeterminate arc segment. |

An Arc requires a nonzero sweep, so skip drawing when the fraction is zero.
Semantics are published by `begin`; visual choices and omissions never remove
the accessible value or the numeric range.

`track_begin` returns a `Track` whose public fields describe the resolved
geometry: `width`, `height`, `padding`, `inner_width`, `inner_height`,
`fill_width`, and `offset_width`. A custom indicator can use those fields
directly. `indicator` is optional and draws the default fill.

## Styling and motion

`Recipe` declares two optional namespaced surface roles:

| Field | Core fallback |
| --- | --- |
| `track_surface_role` | `Subtle_Surface` |
| `fill_surface_role` | `Accent` |

Zero roles need no theme registration. Configured roles are validated with
`theme_contract_default`, `theme_contract_check`, `theme_contract_satisfied`,
and `theme_contract_missing_required`. The example registers
`vendor.alikit.progress.*`, activates the theme with
`alicorn.style_environment_push`, and falls back to core roles when the recipe is
zero.

Geometry lives in `Options`: `width`, `track_height`, `track_padding`,
`corner_radius`, label/value sizes, and `indeterminate_width`. The track width is
definite so fill geometry is exact and a value change touches only the bar's
layout frontier. `value_label` overrides the formatted percentage in both
visible and semantic values.

Indeterminate work has no numeric value. The application supplies
`indeterminate_phase` in `0..1`; the active segment moves by that phase. Setting
`pulse=true` adds a paint-only opacity response through `ui.motion`. The
application must advance the phase if it wants continuous motion; the component
never owns a timer. When the host reports Reduce Motion, the component declares
`Motion_Intent.Snap` and the pulse does not animate. Selection/appearance does
not rely on color alone: the value text and segment position carry the state.

## API reference

| Declaration | Notes |
| --- | --- |
| `Options` | Labels, width, track geometry, label/value sizes, indeterminate phase/width, `pulse`, `hide_label`, `hide_value`, `value_label`. |
| `Recipe` | Optional track/fill namespaced surface roles. |
| `State` | Diagnostic resolved fraction, phase, reduced-motion decision, and segment geometry. |
| `Progress` | Per-description root/value context returned by `begin`. |
| `Track` | Per-description track and geometry context returned by `track_begin`. |
| `begin` | Opens the root, publishes `Progress` semantics and numeric range; returns `(Progress, visible)`. |
| `label` | Optional default label text part; empty text uses the accessible label. |
| `value_text` | Optional default value part; empty text uses the computed value. |
| `track_begin` | Opens the default track and computes inner/fill geometry. |
| `indicator` | Optional default fill and indeterminate offset. |
| `track_end` | Closes the track surface. |
| `end` | Closes the progress root. |
| `progress` | Convenience wrapper built from the parts. |
| `progress_semantic_id` | Stable semantic identity from the instance ID. |
| `fraction`, `format_value` | Pure fraction and text helpers. |
| `linear_geometry`, `ring_sweep`, `ring_shape`, `ring_segment_shape` | Public geometry math for custom linear and ring appearances. |
| `recipe_default` | Core-role recipe. |
| `theme_contract_default`, `theme_contract_check`, `theme_contract_satisfied`, `theme_contract_missing_required` | Setup-time validation. |

## Accessibility and conformance

- Progress is non-interactive: it has no Tab stop, key map, or actions.
- The semantic node publishes role `Progress`, the accessible label, and a
  human-readable value (`"42%"`, or `"Loading"` when indeterminate).
- Determinate progress additionally publishes
  `semantic_numeric_range(clamped_value, minimum, maximum, 0)`. The numeric
  value is clamped to the declared range; the visible percentage uses the same
  clamped fraction. A non-positive range reports 0 without dividing by zero.
- Indeterminate progress does **not** publish numeric range properties, so
  assistive technology does not announce a fabricated percentage.
- Not claimed: task cancellation, estimated remaining time, or live-region
  announcements on every value change. A progress bar is not a status log.

`progress/progress_test.odin` covers the default wrapper:

- fraction clamping and the zero-range case;
- role, label, value text, numeric range, and stable identity;
- a value change driven by ordinary input, with updated semantics and a bounded
  layout frontier (`layout_nodes_visited < 80`);
- indeterminate mode has no numeric value and reports `"Loading"`;
- caller-driven phase moves the segment without changing its width;
- reduced-motion observation is reflected in state and a snapped pulse still
  settles through an advance-time turn;
- the theme contract reports configured and missing roles.

`progress/progress_parts_test.odin` covers the parts:

- linear/ring geometry helpers and the zero-width case;
- a custom ring preserves role, label, value, numeric range, identity, and
  geometry;
- omitting visual label/value parts keeps the accessible value and removes only
  the visual parts;
- the default track/indicator geometry matches the wrapper;
- an indeterminate custom appearance publishes no numeric value.

```powershell
odin test progress -define:ODIN_TEST_THREADS=1 -collection:alicorn=<alicorn> -collection:alikit=.
./out/progress_example.exe --smoke
./out/progress_parts_example.exe --smoke
./out/progress_composition_example.exe --smoke
```

There is no `testui` pattern kind for a progress bar. It is a non-interactive
presentation contract; explicit semantic assertions are the appropriate
conformance check.

## Source and limitations

- Headless tests do not prove pixels, native high-contrast rendering, or an
  assistive-technology announcement. Native smoke runs SDL_GPU D3D12 startup and
  one submitted frame.
- The default track has a definite width. A fill percentage needs a definite
  parent, and the component deliberately avoids a second percentage-width
  policy. Custom appearances such as the ring choose their own definite size.
- Continuous indeterminate motion is application-owned. The component provides
  the phase mapping and an optional motion declaration, not a scheduler.
- The value text uses `%.0f%%`; supply `value_label` or call `value_text` with
  custom text for units or localization.
- A ring Arc requires a nonzero sweep; callers skip a zero-fraction arc.

Source map:

- [Package](../progress/progress.odin)
- [Default tests](../progress/progress_test.odin)
- [Parts tests](../progress/progress_parts_test.odin)
- [Default example](../examples/progress/main.odin)
- [Parts example](../examples/progress_parts/main.odin)
- [Composition example](../examples/progress_composition/main.odin)
- [Theme JSON](../examples/progress/theme.json)
