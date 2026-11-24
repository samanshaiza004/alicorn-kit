# Segmented Control

`alikit:segmented` is a single-selection control over equal-width segments. It
publishes a `Tab_List` / `Tab` collection, one Tab stop, roving arrow
navigation, disabled skipping, keyboard/pointer/semantic activation parity, and
a moving selected indicator.

Use it for a small set of mutually exclusive views or modes. Use tabs when the
selection switches page-level content with a persistent tab strip; use a radio
group when the options are a form value rather than a view.

## Preview

The default appearance is a rounded track with equal-width labels and a
selected surface that translates to the active segment. The example toggles
between `Follow_Focus` and `Activate` modes, disables one segment, and shows the
application-owned view below.

The complete runnable consumer is `examples/segmented/main.odin`.

## Installation

Copy these files into an application or import the package with the AliKit
collection:

- `segmented/segmented.odin`
- `segmented/segmented_test.odin` (conformance)
- `examples/segmented/main.odin`
- `examples/segmented/theme.json`

```odin
import ui "alicorn:ui"
import segmented "alikit:segmented"
```

No init or destroy is required. The component allocates nothing.

## Composition

Segmented is a complete component built on the shared `alikit:selection`
behavior. It composes with any surrounding container, dialog, card, or form.
The experimental `Presentation` argument lets a caller replace the label
presentation inside each existing segment owner. Supply a `draw_item`
procedure and optional borrowed `data`. The procedure receives the item, its
owner, available logical size, and selected and active states. Describe
decorative descendants with no independent input or semantics, and keep them
inside the supplied bounds. The component still supplies the accessible
label and Tab roles and accepts pointer, keyboard, and semantic actions.

`omit_moving_indicator` lets the item presentation supply its own selection
cue. When omitting it, distinguish the selected value from the active item
while the group has focus, including in `Activate` mode. An omitted
`Presentation` uses the standard label and moving indicator. See the
[selection styles pilot](../examples/selection_styles/README.md).

| Layer | Responsibility |
| --- | --- |
| Alicorn | Layout, retained surfaces and positioned children, focus, pointer hit testing, Button activation, semantic collection projection, and paint-only motion. |
| `alikit:selection` | Pure single-selection policy: keyed lookup, disabled skipping, focus repair, at-most-one publication, and Follow_Focus vs Activate. |
| `segmented` | Equal-width segment layout, Tab_List/Tab semantics, roving focus routing, the moving indicator, namespaced surface recipe, and one proposed value. |
| Application | Owns the selected view/mode, accepts the proposal, and renders the selected content. |

`selected_value` is an input and is never mutated. `State` stores only ephemeral
interaction state and diagnostic indicator geometry.

## Minimal example

```odin
import ui "alicorn:ui"
import segmented "alikit:segmented"

App :: struct {
	state:   segmented.State,
	items:   [3]segmented.Item,
	selected: u64,
}

if event := segmented.control(
	ctx,
	&app.state,
	app.items[:],
	app.selected,
	segmented.Options{accessible_label="Workspace view", width=480},
	key=ui.key_string("view"),
	instance_id=1,
); event.kind == .Selection_Proposed {
	app.selected = event.value
}
```

Call `segmented.request_focus(&state)` when an application interaction should
move focus to the control's one Tab stop.

## Controlled example

With `Selection_Mode.Follow_Focus` (the default), arrow movement proposes the
new segment immediately. With `Selection_Mode.Activate`, arrows move only the
roving focus; Space, Return, pointer, or semantic `Select` proposes a value.

```odin
import ui "alicorn:ui"
event := segmented.control(ctx, &app.view, app.items[:], app.selected,
	segmented.Options{
		accessible_label="Workspace view",
		width=480,
		selection_mode=.Activate,
		no_wrap=true,
	},
	key=ui.key_string("view"), instance_id=41)
switch event.kind {
case .Selection_Proposed:
	app.selected = event.value
case .None:
}
```

Checked/selected identity follows `Item.value` across reorder and removal.
Disabled segments remain visible, publish `Disabled`, are skipped by navigation,
and do not advertise `Select` or `Focus`.

## Custom rendering examples

Segmented intentionally ships one appearance: the moving indicator needs equal
segment widths to translate predictably. Customize it with `Options` and
`Recipe`:

```odin
import ui "alicorn:ui"
import alicorn "alicorn:runtime"
control := segmented.control(ctx, &app.state, app.items[:], app.selected,
	segmented.Options{
		accessible_label="Density",
		width=360,
		height=44,
		padding=4,
		corner_radius=12,
		label_size=13,
	},
	key=ui.key_string("density"), instance_id=42,
	recipe=segmented.Recipe{
		track_surface_role=alicorn.style_extension_color_role_id("vendor.app.segmented", "track"),
		indicator_surface_role=alicorn.style_extension_color_role_id("vendor.app.segmented", "indicator"),
	},
	style=segmented.Style{focus_width=2},
)
```

For a different visual contract (icons over labels, a pill outline, no moving
surface), copy `segmented/segmented.odin` as ordinary AliKit source and change
the item/label/indicator drawing. Keep the `Tab_List`/`Tab` collection, the
single Tab stop, the roving key routing, and the one proposed value.

## Styling and motion

`Recipe` declares two optional namespaced surface roles:

| Field | Core fallback |
| --- | --- |
| `track_surface_role` | `Subtle_Surface` |
| `indicator_surface_role` | `Selection` |

A zero role needs no theme registration. Configured roles are validated with
`theme_contract_default`, `theme_contract_check`, `theme_contract_satisfied`,
and `theme_contract_missing_required`. The example registers
`vendor.alikit.segmented.*` roles from `theme.json` and activates the theme with
`alicorn.style_environment_push`; delete the registration to use core roles.

`Options` carries the definite width, height, padding, corner radius, label
size, selection mode, and `no_wrap`. `Style` carries the focus-ring width. The
track outline uses `.Border`, or `.Focus` while the control owns keyboard focus.

The selected indicator is an ordinary positioned surface. Its target is
`active_index * segment_width`; the component declares a paint-only
`ui.motion` translation and lets Alicorn animate it. The first description
snaps to the initial segment, and the host's Reduce Motion preference selects
`Motion_Intent.Snap`. The translation never changes layout, hit bounds, or
semantics.

## API reference

| Declaration | Notes |
| --- | --- |
| `Item` | `value`, `label`, `disabled`. Values must be nonzero and unique. |
| `Options` | Accessible label, width, height, padding, corner radius, label size, selection mode, `no_wrap`. |
| `Recipe` / `Style` | Optional track/indicator surface roles and focus width. |
| `State` | Active roving key/index, focus request, pending proposal, indicator diagnostics. |
| `Event` / `Event_Kind` | One-shot `Selection_Proposed` carrying `value`. |
| `control` | Describe the control and return one proposal. |
| `request_focus` | Focus the control's Tab stop after layout. |
| `Selection_Mode` | Alias of `alikit:selection.Mode`. |
| `recipe_default`, `style_default` | Core-role defaults. |
| `theme_contract_default`, `theme_contract_check`, `theme_contract_satisfied`, `theme_contract_missing_required` | Setup-time validation. |
| `control_semantic_id`, `segment_semantic_id` | Stable semantic identities. |

## Accessibility and conformance

- **Tab** reaches the control once. Segments are not separate Tab stops.
- **Up/Left** and **Down/Right** move to the previous/next selectable segment.
  Navigation wraps by default; set `no_wrap` to stop at the ends.
- **Home/End** move to the first/last enabled segment.
- **Space or Return** propose the active segment.
- Disabled segments are skipped, do not activate, publish `Disabled`, and do not
  advertise `Select` or `Focus`.
- The control publishes role `Tab_List`, its accessible name, the logical
  segment count, `selected_id`, and `current_id`. Segments publish role `Tab`
  with `Selected` + `Checked` when controlled-selected, `Current` when active,
  and `Select` + `Focus` when enabled.
- Semantic `Select` routes through the same retained Button activation as a
  pointer click. Keyboard, pointer, and semantic input return the same one-shot
  `Selection_Proposed` event.
- The moving indicator is decorative and publishes no extra semantic entity.
- Not claimed: page content management, tab-panel relationships beyond the
  `Tab_List` collection, closable segments, or an animated width change.

`segmented/segmented_test.odin` covers:

- stable control/segment identity and the theme contract;
- `Tab_List`/`Tab` roles, parenting, positions, `Selected`/`Current`/`Disabled`,
  and action presence;
- roving Down/Up/Home/End with disabled skipping and wrap;
- keyboard, pointer, and semantic `Select` proposing the same value;
- `Activate` mode keeping focus and selection separate;
- the indicator target translating by segment width and reduced motion being
  observed;
- reorder keeping identity attached to the stable value;
- idle settlement after a snapped indicator.

There is no `testui` pattern kind for a segmented control. `.Roving_List`
requires a `List_Box`, while this component publishes `Tab_List`; explicit drive
assertions are used.

```powershell
odin test segmented -define:ODIN_TEST_THREADS=1 -collection:alicorn=<alicorn> -collection:alikit=.
./out/segmented_example.exe --smoke
```

## Source and limitations

- Headless tests do not prove pixels, native high-contrast rendering, or a
  physical screen-reader session. Native smoke covers SDL_GPU startup and one
  submitted frame.
- All segments have equal width. The moving indicator translates by whole
  segments, so variable-width segments are intentionally out of scope.
- The control expects a small, caller-owned item slice; it does not virtualize.
- The first description snaps the indicator; subsequent selection changes
  animate through Alicorn's motion policy.
- Label text is single-line with ellipsis overflow; use short segment labels.
- `State.active_key` is presentation state. Do not persist it as the
  application's selection.

Source map:

- [Package](../segmented/segmented.odin)
- [Tests](../segmented/segmented_test.odin)
- [Example](../examples/segmented/main.odin)
- [Theme JSON](../examples/segmented/theme.json)
