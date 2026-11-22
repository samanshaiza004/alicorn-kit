# Radio Group

`alikit:radio_group` is a controlled compound control for choosing one value
from a small fixed set. It publishes `Radio_Group` / `Radio_Button` semantics,
one Tab stop, roving arrow navigation, disabled skipping, and pointer, keyboard,
and assistive-technology activation parity. Use it for mutually exclusive
options. Use a Select for a long or dynamic list, and a Checkbox for an
independent boolean.

## Responsibility split

| Layer | Responsibility |
| --- | --- |
| Alicorn | Layout, retained nodes, focus, pointer hit testing, Button activation, semantic collection projection, and the `Radio_Group`/`Radio_Button` roles. |
| `radio_group` | The option layout, roving index proposal, checked/current presentation, namespaced surface recipe, `Press`/`Focus` actions, and one proposed selection event. |
| Application | Owns the selected value and mutual exclusion. Accepts a proposed value by assigning its own state. Owns labels, disabled policy, and any domain command. |

The component keeps no application selection. `selected_value` is an input.
`State` contains only ephemeral interaction state (the active roving identity,
focus request, and one pending proposal).

## Copyable implementation

Files: `radio_group/radio_group.odin`, `radio_group/radio_group_test.odin`,
`examples/radio_group/main.odin`, `examples/radio_group/theme.json`.

```odin
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import radio "alikit:radio_group"

App :: struct {
	group:    radio.State,
	options:  [3]radio.Option,
	selected: u64,
}

// options and selected are application-owned.
if event := radio.radio_group(
	ctx,
	&app.group,
	app.options[:],
	app.selected,
	radio.Options{accessible_label="Text size", orientation=.Vertical},
	key=alicorn.key_string("text-size"),
	instance_id=1,
); event.kind == .Selection_Proposed {
	app.selected = event.value
}
```

No init or destroy is required. The component allocates nothing. Call
`radio.request_focus(&state)` when an application interaction should move focus
to the group; the next description focuses the group's single Tab stop after
layout.

## Parts and identities

| Part | Identity | What can be omitted or replaced |
| --- | --- | --- |
| Group | `group_semantic_id(instance_id)` | Always present. It is the one Tab stop and the `Radio_Group` collection owner. |
| Option | `option_semantic_id(instance_id, value)` | The application supplies the option slice. Omitting an option removes its identity; remaining identities do not change. |
| Indicator and label | Stable child keys under the option owner | Visual only. Replace the drawing inside the Button owner; keep the semantic item call. |

Option value `0`, a zero instance ID, and duplicate values are invalid. Checked
identity follows the stable value, not the row index. Reordering options keeps
`Checked`, `Selected`, and the active identity attached to the same value.
Removing the active value repairs focus with Alicorn's pure roving model:
selected value first, else the nearest enabled option, else the first enabled
option.

## Styling, motion, and theme

`Recipe` declares four optional namespaced **surface** roles:

| Field | Core fallback |
| --- | --- |
| `item_surface_role` | `Subtle_Surface` |
| `selected_surface_role` | `Selection` |
| `indicator_surface_role` | `Subtle_Surface` |
| `selected_indicator_role` | `Accent` |

A zero role needs no theme registration. A configured role is validated by
`theme_contract_default`, `theme_contract_check`,
`theme_contract_satisfied`, and `theme_contract_missing_required`. Validate once
after theme registration or replacement, not per frame. The example registers
`vendor.alikit.radio_group.*` roles from `theme.json`; delete that registration
to use core roles.

`Style` carries corner radius, indicator radius, and focus-ring width.
`Options` carries orientation, selection mode, item geometry, and label size.
Selection is shown by the filled radio dot and the selected surface, not by
color alone. The focus ring is drawn on the active option while the group owns
keyboard focus. There is no motion: a radio value change must be immediately
readable, and the component does not add an ambient animation.

## Keyboard and accessibility contract

- **Tab** reaches the group once. Options are not separate Tab stops.
- **Up/Left** moves to the previous enabled option; **Down/Right** moves to the
  next enabled option. Navigation wraps by default; set `Options.no_wrap` to
  stop at the ends.
- **Home/End** move to the first/last enabled option.
- **Space or Return** propose the active option.
- With `Selection_Mode.Follow_Focus` (the default), an arrow move also proposes
  that option, matching the platform radio convention. With
  `Selection_Mode.Activate`, arrows change only the roving focus and Space,
  Return, pointer, or semantic `Press` proposes a value.
- Disabled options are skipped by navigation, do not activate, publish
  `Disabled`, and do not advertise `Press` or `Focus`.
- The group publishes role `Radio_Group`, its accessible name, the logical
  option count, `selected_id`, and `current_id`. Each option publishes role
  `Radio_Button`, its label, `Checked` + `Selected` when controlled-selected,
  `Current` when it owns roving focus, and `Press` + `Focus` when enabled.
- Semantic `Press` routes through the same retained Button activation as a
  pointer click. All three input paths return the same one-shot
  `Selection_Proposed` event.
- Focus stays on the group while the active item changes; focus does not follow
  the pointer into an option. Not claimed: multiple selection, a Checkbox
  contract, type-ahead, or a popup.

## Conformance tests

`radio_group/radio_group_test.odin` drives the package through
`alicorn:testui`:

- semantic roles, group/item parenting, positions, `Checked`/`Selected`/
  `Current`, and action presence;
- roving Down/Up/Home/End with disabled skipping and wrap;
- keyboard, pointer, and semantic `Press` propose the same value;
- `Activate` mode keeps focus and controlled selection separate;
- vertical and horizontal appearances keep semantic identity and materially
  change layout;
- reorder keeps selection attached to the stable value;
- the theme contract reports configured and missing roles;
- idle: the suite's final turn reports no remaining description or presentation
  work.

There is no `testui` pattern kind for a radio group at the pinned revision.
`.Roving_List` requires a `List_Box` container, and a radio group must publish
`Radio_Group`. A `.Radio_Group` pattern is therefore a candidate Alicorn
addition; this package uses explicit drive assertions instead of claiming a
pattern that does not exist. No negative-fixture pattern run is possible for the
same reason.

## Limits

- Headless tests do not prove a physical VoiceOver, Narrator, or NVDA session,
  OS high-contrast rendering, or pixel output. Native smoke covers SDL_GPU
  startup and one submitted frame.
- The component expects a small, caller-owned option slice. It does not
  virtualize; use a Select for long lists.
- Label text is single-line with ellipsis overflow. Provide a short label.
- `State.active_value` is presentation state. Do not persist it as the
  application's selection.

## Source map

- [Package](../radio_group/radio_group.odin)
- [Tests](../radio_group/radio_group_test.odin)
- [Example](../examples/radio_group/main.odin)
- [Theme JSON](../examples/radio_group/theme.json)
