# Navigation Rail / Sidebar

`alikit:sidebar` is the P0 Sidebar shape: a vertical, icon-led navigation rail
with expanded and collapsed presentations. It publishes one `List_Box` with
`List_Box_Option` routes, one Tab stop, roving Up/Down/Home/End focus, and one
proposed route change on activation. Selection is application-owned; the router
is not part of this package (a P1 concern).

A tree-style sidebar with nested sections is a later variant. This package
deliberately implements the flat navigation rail first: stable route identity,
one focus representative, and no second navigation model.

## Responsibility split

| Layer | Responsibility |
| --- | --- |
| Alicorn | Layout, focus, pointer hit testing, retained Button activation, `List_Box`/`List_Box_Option` semantics, and the roving model. |
| `sidebar` | Rail and row drawing, expanded/collapsed presentations, roving index proposal, selected/current presentation, namespaced surface recipe, and one selection event. |
| Application | Owns the accepted route, route content, router/history, badges, and disabled policy. |

## Copyable implementation

Files: `sidebar/sidebar.odin`, `sidebar/sidebar_test.odin`,
`examples/sidebar/main.odin`, `examples/sidebar/theme.json`.

```odin
import sidebar "alikit:sidebar"

if event := sidebar.rail(
	ctx,
	&app.rail,
	app.routes[:],
	app.selected_key,
	sidebar.Options{accessible_label="Workspace navigation", collapsed=app.collapsed},
	key=alicorn.key_string("workspace-rail"),
	instance_id=1,
); event.kind == .Selection_Proposed {
	app.selected_key = event.key
	// Navigate the application route here. The rail does not own a router.
}
```

Call `sidebar.request_focus(&state)` when an application interaction should
move focus to the rail. The next description focuses the rail after layout.

## Parts and identities

| Part | Identity | What can be omitted or replaced |
| --- | --- | --- |
| Rail | `rail_semantic_id(instance_id)` | Always present. It is the one Tab stop and the `List_Box` collection. |
| Route row | `item_semantic_id(instance_id, key)` | The application supplies the item slice. Removing an item keeps the remaining identities. |
| Icon / label / badge | Stable child keys under the row owner | Collapsed presentation omits the visible label/badge; the accessible label remains. |
| Selected indicator | `.Selected_Indicator` | Replace the drawing; keep the selected state and `Selected` semantics. |

Route key `0`, zero instance ID, and duplicate keys are invalid. Selected and
Current identity follow the stable key across reorder. Removing the active key
repairs focus with the selected key first, then the nearest enabled route, then
the first enabled route. The accent indicator and label weight make selection
visible without relying on color alone.

## Styling, motion, and theme

`Recipe` declares three optional namespaced surface roles:

| Field | Core fallback |
| --- | --- |
| `rail_surface_role` | `Surface` |
| `item_surface_role` | `Surface` |
| `selected_surface_role` | `Selection` |

Zero roles need no theme registration. Configured roles are validated with
`theme_contract_default`, `theme_contract_check`,
`theme_contract_satisfied`, and `theme_contract_missing_required`. The example
registers `vendor.alikit.sidebar.*`. A missing configured role falls back to the
core role at render time after setup validation, so the rail remains usable.

`Style` carries corner radius, selected-indicator width, and focus-ring width.
`Options` carries collapsed state, rail/expanded width, item height, gap,
padding, icon size, label size, and `wrap`. Collapsing changes width and omits
the visible label; it does not change semantic IDs, selected state, or focus
ownership. There is no motion: navigation selection is immediately readable and
the component does not own an animation lifecycle.

## Keyboard and accessibility contract

- **Tab** reaches the rail once. Rows are not separate Tab stops.
- **Up/Down** move the roving focus to the previous/next enabled route.
  **Home/End** move to the first/last enabled route. Navigation stops at the
  ends by default; set `Options.wrap` to wrap.
- **Return/Space** propose the active route. Pointer and semantic `Select`
  propose the same route. Arrow navigation alone does not change selection.
- Disabled routes are skipped, publish `Disabled`, and do not advertise
  `Select` or `Focus`.
- The rail publishes `List_Box`, its accessible name, logical route count,
  `selected_id`, and `current_id`. Rows publish `List_Box_Option`, label,
  description (detail), `Selected` when controlled-selected, `Current` when they
  own roving focus, and `Select` + `Focus` when enabled.
- The rail is the focus representative. Rows are intentionally non-focusable;
  semantic `Focus` on a row may be rejected by the runtime's realized-action
  eligibility rule, which is a recorded core gap shared with the icon picker.
  The rail's own Focus action remains valid.
- Not claimed: nested sections, expand/collapse route groups, a router, history,
  or drag reorder.

## Conformance tests

`sidebar/sidebar_test.odin` covers:

- `List_Box`/`List_Box_Option` semantics, selected/current identity, disabled
  action rejection, and parent structure;
- Down skipping a disabled route, Return activation, pointer activation, and
  semantic `Select` parity;
- the `.Roving_List` pattern with a container focus representative, disabled
  skipping, no wrap, Home/End, and selection activation;
- collapsed/expanded width changes with identical semantic identity and selected
  state;
- reorder keeping the selected route attached to its stable key;
- the theme contract.

The `.Roving_List` check is a real positive conformance run. Its negative
controls are covered by Alicorn's own `testui` fixture; this package does not
duplicate the core fixture.

## Limits

- Headless tests do not prove a physical screen-reader session, pixel output, or
  native route focus. Native smoke runs SDL_GPU D3D12 startup.
- The rail is flat. A nested sidebar needs a tree projection and is a separate
  P1 component.
- Collapsed rows show icons only. Provide a meaningful icon and accessible
  label; there is no built-in tooltip.
- The application owns route content, routing, history, and any keyboard
  shortcut that jumps directly to a route.

## Source map

- [Package](../sidebar/sidebar.odin)
- [Tests](../sidebar/sidebar_test.odin)
- [Example](../examples/sidebar/main.odin)
- [Theme JSON](../examples/sidebar/theme.json)
