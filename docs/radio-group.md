# Radio Group

`alikit:radio_group` is a controlled compound control for choosing one value
from a small fixed set. It publishes `Radio_Group` / `Radio_Button` semantics,
one Tab stop, roving arrow navigation, disabled skipping, and pointer, keyboard,
and assistive-technology activation parity.

Use it for mutually exclusive options. Use a Select for a long or dynamic list,
and a Checkbox for an independent boolean.

## Preview

The default appearance is a vertical or horizontal list of labelled radio rows.
The parts example renders the same component as price cards with a picture,
title, description, and selected checkmark; the default dot is omitted.
The composition example hosts the radio parts inside a modal dialog form.

## Installation

Import the package through the AliKit collection:

```odin
import ui "alicorn:ui"
import radio "alikit:radio_group"
```

Pass `-collection:alikit=<alicorn-kit checkout>` when building. No init or
destroy is required; the component allocates nothing.

To copy the source instead, copy the package file plus its two intra-AliKit
dependencies (also declared under `copy` in [`components.json`](../components.json)):

- `radio_group/radio_group.odin`
- `selection/selection.odin`
- `theme_contract/contract.odin`

Put them in sibling packages, for example `vendor/radio_group`,
`vendor/selection`, and `vendor/theme_contract`, and rewrite the two imports in
the copied `radio_group.odin`:

```odin
import sel "../selection"
import tc "../theme_contract"
```

The copy then builds with only `-collection:alicorn=<alicorn>`; no `alikit`
collection is needed. Copying `radio_group.odin` alone does not compile. The
conformance tests and examples stay in the AliKit repository.
[`tools/validate_external_consumer.ps1`](../tools/validate_external_consumer.ps1)
builds both the collection path and this copy path from a generated project
outside the repository.

## Composition

There are three supported authoring paths:

1. Import the complete component and call `radio.radio_group`.
2. Import the parts and compose the group, items, indicator, and label.
3. Import the parts and write any visual subtree between `item_begin` and
   `item_end`.

`radio_group` itself is a convenience wrapper built from the exact public
parts, so the two paths share one interaction and semantic contract.

| Layer | Responsibility |
| --- | --- |
| Alicorn | Layout, retained nodes, focus, pointer hit testing, Button activation, semantic collection projection, and the `Radio_Group`/`Radio_Button` roles. |
| `radio_group` | Group scope, roving focus proposal, checked/current publication, keyboard routing, the default indicator/label parts, namespaced surface recipe, and one proposed selection event. |
| Application | Owns the selected value and mutual exclusion. Accepts a proposed value by assigning its own state. Owns labels, disabled policy, and any domain command. |

The parts keep no application selection. `selected_value` is an input. `State`
contains only ephemeral interaction state: the active roving identity, a focus
request, and one pending proposal. Selection proposals use the shared
`alikit:selection` model; Alicorn roving owns focus movement, and the selection
model owns the focused-key proposal rule, disabled/at-most-one publication, and
focus repair.

The default wrapper draws this shape:

```text
group_begin  -> Radio_Group collection, one Tab stop, key routing
  item_begin -> one Radio_Button owner, checked/current/disabled semantics
    indicator (optional) -> default dot
    label     (optional) -> default label
  item_end
group_end    -> one Selection_Proposed event
```

## Minimal example

```odin
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
	key=ui.key_string("text-size"),
	instance_id=1,
); event.kind == .Selection_Proposed {
	app.selected = event.value
}
```

No init or destroy is required. Call `radio.request_focus(&state)` when an
application interaction should move focus to the group; the next description
focuses the group's single Tab stop after layout.

## Controlled example

`selected_value` is never mutated by the component. Every input path returns the
same one-shot proposal:

```odin
event := radio.radio_group(ctx, &app.group, app.options[:], app.size,
	radio.Options{
		accessible_label="Text size",
		selection_mode=.Activate, // arrows move focus; activation selects
		no_wrap=true,
	},
	key=ui.key_string("size"), instance_id=41)
switch event.kind {
case .Selection_Proposed:
	app.size = event.value        // accept, reject, or map to a command
case .None:
}
```

With `Selection_Mode.Follow_Focus` (the default), arrow movement also proposes
that option, matching the platform radio convention. With
`Selection_Mode.Activate`, arrows change only the roving focus; Space, Return,
pointer, or semantic `Press` proposes a value.

Checked identity follows the stable `Option.value`, not the row index. Reordering
keeps `Checked`, `Selected`, and the active identity attached to the same value.
Removing the active value repairs focus with Alicorn's pure roving model:
selected value first, else the nearest enabled option, else the first enabled
option. `State.active_key` is presentation state; do not persist it as the
application's selection.

## Custom rendering examples

The default appearance uses the indicator and label parts:

```odin
group, visible := radio.group_begin(ctx, &app.group, app.options[:], app.selected,
	label="Text size", key=ui.key_string("size"), instance_id=41)
if visible {
	for option in app.options {
		item, item_visible := radio.item_begin(ctx, &group, option)
		if item_visible {
			radio.indicator(ctx, item) // omit to replace the dot
			radio.label(ctx, item)     // omit for a custom title layout
			radio.item_end(ctx, item)
		}
	}
	if event := radio.group_end(ctx, &group); event.kind == .Selection_Proposed {
		app.selected = event.value
	}
}
```

`Item` exposes the state a custom appearance needs:

| Field | Meaning |
| --- | --- |
| `option` | The caller-owned option being rendered. |
| `index`, `count` | Stable position in the keyed option set. |
| `checked` | Controlled `selected_value` equality. |
| `focused` | This option owns the roving focus identity. |
| `focus_visible` | Roving focus is active and the group owns keyboard focus. |
| `disabled` | The option's disabled policy. |
| `visible` | `false` means the caller must skip the subtree and not call `item_end`. |

A radical choice-card appearance keeps the semantic owner and owns everything
inside it:

```odin
group, visible := radio.group_begin(ctx, &app.group, options, app.selected,
	label="Plan", key=ui.key_string("plan"), instance_id=42,
	group_options=radio.Options{item_height=104, item_padding=0, item_gap=10})
if visible {
	for plan in app.plans {
		item, item_visible := radio.item_begin(ctx, &group, plan.option)
		if !item_visible { continue }

		// Any ordinary Alicorn layout is allowed here.
		if ui.row(ctx, key=ui.key_u64(1), width=-1, height=-1, gap=12) {
			_ = ui.icon(ctx, plan.icon, key=ui.key_u64(2), size=28)
			if ui.column(ctx, key=ui.key_u64(3), grow=1) {
				_ = ui.text(ctx, plan.option.label, key=ui.key_u64(4), size=16)
				_ = ui.text(ctx, plan.option.description, key=ui.key_u64(5), size=12)
			}
			_ = ui.text(ctx, plan.price, key=ui.key_u64(6))
			if item.checked { _ = ui.icon(ctx, .Check, key=ui.key_u64(7), size=18) }
		}
		radio.item_end(ctx, item)
	}
	event := radio.group_end(ctx, &group)
}
```
import ui "alicorn:ui"

The parts own keyboard navigation, roving focus, checked-state publication, the
Button owner, and activation parity. Omitting `indicator` or `label` changes only
the visual tree. An option that is not in the group's keyed set returns
`visible=false` from `item_begin`; no visual node or semantics are published for
it.

## Styling and motion

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
after theme registration or replacement, not per frame. The default example
registers `vendor.alikit.radio_group.*` roles from `theme.json`; delete that
registration to use core roles.

`Style` carries corner radius, indicator radius, and focus-ring width.
`Options` carries orientation, selection mode, item geometry, and label size.
Selection is shown by the filled radio dot and the selected surface, not by
color alone. The focus ring is drawn on the active option while the group owns
keyboard focus. There is no component motion: a radio value change must be
immediately readable, and the parts do not add an ambient animation. A custom
appearance may use `ui.motion` on its own visuals without changing the
interaction contract.

## API reference

| Declaration | Notes |
| --- | --- |
| `Option` | `value`, `label`, `description`, `disabled`. |
| `Orientation` | `.Horizontal` or `.Vertical`. |
| `Selection_Mode` | Alias of `alikit:selection.Mode`: `.Follow_Focus` or `.Activate`. |
| `Options` | Accessible label, orientation, selection mode, item geometry, label size, `no_wrap`. |
| `Recipe` / `Style` | Optional namespaced surface roles and visual geometry. |
| `State` | Active roving key/index, focus request, and pending proposal. |
| `Event` / `Event_Kind` | One-shot `Selection_Proposed` carrying `value`. |
| `Group` | Per-description group context returned by `group_begin`. |
| `Item` | Per-description item context with checked/focused/disabled/position state. |
| `group_begin` | Opens the group and `Radio_Group` collection; returns `(Group, visible)`. |
| `item_begin` | Opens one `Radio_Button` owner and semantic item; returns `(Item, visible)`. |
| `indicator` | Optional default indicator/dot part. |
| `label` | Optional default text part; `text` overrides the option label. |
| `item_end` | Closes the item and records its activation proposal. |
| `group_end` | Closes the group and returns the one proposal. |
| `radio_group` | Convenience wrapper built from the parts. |
| `request_focus` | Focus the group's Tab stop after layout. |
| `recipe_default`, `style_default` | Core-role defaults. |
| `theme_contract_default`, `theme_contract_check`, `theme_contract_satisfied`, `theme_contract_missing_required` | Setup-time validation. |
| `group_semantic_id`, `option_semantic_id` | Stable semantic identities. |
| `instance_from_key` | Stable instance identity fallback when a parts author supplies only the key. |

`group_begin` accepts `label`, `key`, and an optional `instance_id`. When the
instance ID is zero, a stable identity is derived from the key; explicit IDs are
preferred when keys may change between descriptions.

`item_begin` accepts an optional `item_style` (an ordinary `ui.Layout_Style`).
The zero value uses the group's orientation geometry; a supplied style owns the
item's outer width, height, direction, padding, gap, and alignment.

## Accessibility and conformance

- **Tab** reaches the group once. Options are not separate Tab stops.
- **Up/Left** moves to the previous enabled option; **Down/Right** moves to the
  next enabled option. Navigation wraps by default; set `Options.no_wrap` to
  stop at the ends.
- **Home/End** move to the first/last enabled option.
- **Space or Return** propose the active option.
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
  the pointer into an option.
- Not claimed: multiple selection, a Checkbox contract, type-ahead, or a popup.

`radio_group/radio_group_test.odin` drives the default component through
`alicorn:testui`. `radio_group/radio_group_parts_test.odin` drives custom card
parts directly:

- semantic roles, group/item parenting, positions, `Checked`/`Selected`/
  `Current`, and action presence;
- roving Down/Up/Home/End with disabled skipping and wrap;
- keyboard, pointer, and semantic `Press` propose the same value;
- `Activate` mode keeps focus and controlled selection separate;
- vertical and horizontal appearances keep semantic identity and materially
  change layout;
- reorder keeps selection attached to the stable value;
- custom cards preserve semantics, identity, keyboard navigation, and
  activation parity without the default indicator part;
- an option outside the keyed set returns `visible=false` and publishes no
  semantics;
- the theme contract reports configured and missing roles;
- the parts example's author-owned card geometry is realized.

```powershell
odin test radio_group -define:ODIN_TEST_THREADS=1 -collection:alicorn=<alicorn> -collection:alikit=.
./out/radio_group_example.exe --smoke
./out/radio_group_parts_example.exe --smoke
./out/radio_group_composition_example.exe --smoke
```

There is no `testui` pattern kind for a radio group at the pinned revision.
`.Roving_List` requires a `List_Box` container, and a radio group must publish
`Radio_Group`. A `.Radio_Group` pattern is therefore a candidate Alicorn
addition; this package uses explicit drive assertions instead of claiming a
pattern that does not exist.

## Source and limitations

- Headless tests do not prove a physical VoiceOver, Narrator, or NVDA session,
  OS high-contrast rendering, or pixel output. Native smoke covers SDL_GPU
  startup and one submitted frame.
- The component expects a small, caller-owned option slice. It does not
  virtualize; use a Select for long lists.
- Option values must be nonzero and unique within one group.
- The default label part is single-line with ellipsis overflow. Custom parts can
  use any text layout inside the item owner.
- The pinned revision elides more aggressively in some narrow fit-content rows;
  give the item a definite width when exact label truncation matters.
- `State.active_key` is presentation state. Do not persist it as the
  application's selection.

Source map:

- [Package](../radio_group/radio_group.odin)
- [Default tests](../radio_group/radio_group_test.odin)
- [Parts tests](../radio_group/radio_group_parts_test.odin)
- [Default example](../examples/radio_group/main.odin)
- [Parts example](../examples/radio_group_parts/main.odin)
- [Composition example](../examples/radio_group_composition/main.odin)
- [Theme JSON](../examples/radio_group/theme.json)
