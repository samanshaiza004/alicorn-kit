# Progress Bar

`alikit:progress` presents determinate or indeterminate work. A determinate bar
publishes role `Progress`, a visible percentage, and a numeric value/minimum/
maximum. An indeterminate bar publishes no numeric value. Use a determinate bar
when progress is measurable; use the indeterminate form only for unknown work,
and prefer a label that names the operation.

## Responsibility split

| Layer | Responsibility |
| --- | --- |
| Alicorn | Layout, semantic surfaces, `Progress` role, `semantic_numeric_range`, retained paint, reduced-motion preference, and paint-only motion. |
| `progress` | Track, fill, label, and value parts; clamping; percentage formatting; indeterminate segment geometry; optional pulse declaration; namespaced surface recipe. |
| Application | Owns the value/range and the indeterminate phase. It advances the phase from its own animation loop if it wants a pulse. |

The component has no timer, animation lifecycle, or application value. `State`
holds only diagnostic values from the most recent description, so an
application or test can inspect the resolved fraction, phase, reduced-motion
decision, and segment geometry without retained-runtime access.

## Copyable implementation

Files: `progress/progress.odin`, `progress/progress_test.odin`,
`examples/progress/main.odin`, `examples/progress/theme.json`.

```odin
import ui "alicorn:ui"
import progress "alikit:progress"

app := struct {
	upload: progress.State,
	value:  f64,
}{value=42}

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

No init or destroy is required; the component allocates nothing.

## Parts and identities

| Part | Visual part | What can be omitted or replaced |
| --- | --- | --- |
| Root | — | Always present. It carries `Progress` semantics and the stable semantic ID. |
| Label | `.Label` | Set `show_label=false` to omit it; the accessible name remains. |
| Value | `.Content` | Set `show_value=false` to omit the visible value; semantic value remains. |
| Track | `.Surface` | Always present, but its surface role/geometry is recipe/style driven. |
| Fill | `.Indicator` | Omitted at 0% (and when the unresolved range is empty). Replace the drawing inside the track; keep the semantic root. |

`progress_semantic_id(instance_id)` is stable across value, phase, and theme
changes. A zero instance ID is rejected. The fill and track are decorative
visual parts and do not add duplicate semantic entities.

## Styling, motion, and theme

`Recipe` declares two optional namespaced surface roles:

| Field | Core fallback |
| --- | --- |
| `track_surface_role` | `Subtle_Surface` |
| `fill_surface_role` | `Accent` |

Zero roles need no theme registration. Configured roles are validated with
`theme_contract_default`, `theme_contract_check`,
`theme_contract_satisfied`, and `theme_contract_missing_required`. The example
registers `vendor.alikit.progress.*`; delete the registration to use core roles.

`Style` is not a separate type: the documented geometry lives in `Options`
(`width`, `track_height`, `track_padding`, `corner_radius`, label/value sizes,
`indeterminate_width`). The track width is definite so fill geometry is exact
and a value change touches only the bar's layout frontier. `value_label`
overrides the formatted percentage in both visible and semantic values.

Indeterminate work has no numeric value. The application supplies
`indeterminate_phase` in `0..1`; the active segment moves by that phase. Setting
`pulse=true` adds a paint-only opacity response through `ui.motion`. The
application must advance the phase if it wants continuous motion; the component
never owns a timer. When the host reports Reduce Motion, the component declares
`Motion_Intent.Snap` and the pulse does not animate. Selection/appearance does
not rely on color alone: the value text and segment position carry the state.

## Keyboard and accessibility contract

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

## Conformance tests

`progress/progress_test.odin` covers:

- fraction clamping and the zero-range case;
- role, label, value text, numeric range, and stable identity;
- a value change driven by ordinary input, with updated semantics and a bounded
  layout frontier (`layout_nodes_visited < 80`);
- indeterminate mode has no numeric value and reports `"Loading"`;
- caller-driven phase moves the segment without changing its width;
- reduced-motion observation is reflected in state and a snapped pulse still
  settles through an advance-time turn;
- the theme contract reports configured and missing roles.

There is no `testui` pattern kind for a progress bar. It is a non-interactive
presentation contract; explicit semantic assertions are the appropriate
conformance check.

## Limits

- Headless tests do not prove pixels, native high-contrast rendering, or an
  assistive-technology announcement. Native smoke runs SDL_GPU D3D12 startup and
  one submitted frame.
- The track has a definite width. A fill percentage needs a definite parent, and
  the component deliberately avoids a second percentage-width policy.
- Continuous indeterminate motion is application-owned. The component provides
  the phase mapping and an optional motion declaration, not a scheduler.
- The value text uses `%.0f%%`; supply `value_label` for units or localization.

## Source map

- [Package](../progress/progress.odin)
- [Tests](../progress/progress_test.odin)
- [Example](../examples/progress/main.odin)
- [Theme JSON](../examples/progress/theme.json)
