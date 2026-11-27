# Navigation Rail / Sidebar

`alikit:sidebar` is a vertical, icon-led navigation rail with expanded and
collapsed presentations. It publishes one `List_Box` with `List_Box_Option`
routes, one Tab stop, roving Up/Down/Home/End focus, and one proposed route
change on activation. Selection is application-owned; the router is not part of
this package.

The package is built from public parts. `rail()` is a convenience wrapper over
the exact parts, so a default rail and a fully custom rail share one interaction
and semantic contract.

## Preview

The default appearance is a compact rail of icon/label rows with an accent
selected bar. The parts example replaces every row visual with a letter tile, a
two-line layout, badges, and a selected checkmark. The composition example
hosts the rail beside a Segmented control in a settings shell.

## Installation

For normal use, import the package through the AliKit collection:

```odin
import ui "alicorn:ui"
import sidebar "alikit:sidebar"
```

To copy and edit the source, use the complete source closure and import
rewrites in [`components.json`](../components.json). It includes the shared
`selection` and `theme_contract` packages. Tests and examples remain in AliKit.

No init or destroy is required. The component allocates nothing.

## Composition

There are three supported authoring paths:

1. Import the complete component and call `sidebar.rail`.
2. Import the parts and compose the rail and rows: `rail_begin`, `item_begin`,
   optional visual parts, `item_end`, `rail_end`.
3. Import the parts and write any visual subtree between `item_begin` and
   `item_end`. A source fork can use the recipe in `components.json`.

| Layer | Responsibility |
| --- | --- |
| Alicorn | Layout, focus, pointer hit testing, retained Button activation, `List_Box`/`List_Box_Option` semantics, and the roving model. |
| `sidebar` | Rail scope, roving focus proposal, selected/current publication, keyboard routing, default visual parts, namespaced surface recipe, and one proposed route. |
| Application | Owns the accepted route, route content, router/history, badges, and disabled policy. |

`State` contains only ephemeral interaction state: the active roving identity, a
focus request, and one pending proposal. Focus movement uses Alicorn's pure
roving model; reconcile, disabled skipping, and the activation proposal use the
shared `alikit:selection` model.

The default wrapper draws this shape:

```text
rail_begin          -> rail surface, List_Box collection, one Tab stop, key routing
  item_begin        -> one List_Box_Option Button owner; Selected/Current/Disabled
    row_surface     -> optional default row background and focus stroke
      indicator     -> optional selected bar
      icon          -> optional icon
      label         -> optional visible label (omitted when collapsed)
      badge         -> optional badge text (omitted when collapsed)
    item_end        -> one pending route proposal on activation
rail_end            -> one Selection_Proposed event
```

## Minimal example

```odin
ROUTES: [2]sidebar.Item = {
	{key=1, label="Overview", icon=.Info, detail="Workspace summary"},
	{key=2, label="Files", icon=.Folder_Closed, detail="Browse files"},
}

App :: struct {
	rail:         sidebar.State,
	selected_key: u64,
	collapsed:    bool,
}

if event := sidebar.rail(
	ctx,
	&app.rail,
	ROUTES[:],
	app.selected_key,
	sidebar.Options{accessible_label="Workspace navigation", collapsed=app.collapsed},
	key=ui.key_string("workspace-rail"),
	instance_id=1,
); event.kind == .Selection_Proposed {
	app.selected_key = event.key
	// Navigate the application route here. The rail does not own a router.
}
```

Call `sidebar.request_focus(&state)` when an application interaction should
move focus to the rail. The next description focuses the rail after layout.

## Custom rendering examples

The default appearance uses `row_surface`, `indicator`, `icon`, `label`, and
`badge`:

```odin
rail, visible := sidebar.rail_begin(ctx, &app.rail, ROUTES[:], app.selected_key,
	label="Workspace navigation", key=ui.key_string("rail"), instance_id=41)
if visible {
	for route in ROUTES {
		row, row_visible := sidebar.item_begin(ctx, &rail, route)
		if row_visible {
			if sidebar.row_surface(ctx, row) != 0 {
				sidebar.indicator(ctx, row)
				sidebar.icon(ctx, row)
				sidebar.label(ctx, row)
				sidebar.badge(ctx, row)
				ui.surface_end(ctx)
			}
			sidebar.item_end(ctx, row)
		}
	}
	if event := sidebar.rail_end(ctx, &rail); event.kind == .Selection_Proposed {
		app.selected_key = event.key
	}
}
```

A custom row keeps the semantic owner and owns everything inside it:

```odin
rail, visible := sidebar.rail_begin(ctx, &app.rail, ROUTES[:], app.selected_key,
	label="Workspace navigation", key=ui.key_string("rail"), instance_id=42,
	rail_options=sidebar.Options{expanded_width=260, item_height=58, item_gap=6})
if visible {
	for route, index in ROUTES {
		row, row_visible := sidebar.item_begin(ctx, &rail, route)
		if !row_visible { continue }

		// Any ordinary Alicorn layout is allowed here. This row omits every
		// default visual part and draws a letter tile, two text lines, a badge,
		// and a selected checkmark.
		if ui.row(ctx, key=ui.key_u64(1), width=-1, height=-1, padding=10, gap=10,
			align=.Center) {
			_ = ui.text(ctx, initials[index], key=ui.key_u64(2), size=12)
			if ui.column(ctx, key=ui.key_u64(3), grow=1) {
				_ = ui.text(ctx, route.label, key=ui.key_u64(4), size=14)
				_ = ui.text(ctx, route.detail, key=ui.key_u64(5), size=11)
			}
			if row.selected { _ = ui.icon(ctx, .Check, key=ui.key_u64(6), size=16) }
		}
		sidebar.item_end(ctx, row)
	}
	event := sidebar.rail_end(ctx, &rail)
}
```
import ui "alicorn:ui"

`Rail_Item` exposes the state a custom row needs:

| Field | Meaning |
| --- | --- |
| `item` | The caller-owned route being rendered. |
| `index`, `count` | Stable position in the keyed route set. |
| `selected` | Controlled `selected_key` equality. |
| `focused` | This route owns the roving focus identity. |
| `focus_visible` | Roving focus is active and the rail owns keyboard focus. |
| `disabled` | The route's disabled policy. |
| `visible` | `false` means the caller must skip the subtree and not call `item_end`. |

`item_begin` also accepts an ordinary `ui.Layout_Style` when the author wants to
own the row's outer geometry. The parts retain keyboard navigation, roving
focus, selected/current publication, the Button owner, and activation parity.
Omitting visual parts changes only the visual tree.

`row_surface` returns an opened surface. Close it with `ui.surface_end` after
the row content; custom authors that draw their own background simply do not
call it.

## Styling, motion, and theme

`Recipe` declares three optional namespaced **surface** roles:

| Field | Core fallback |
| --- | --- |
| `rail_surface_role` | `Surface` |
| `item_surface_role` | `Surface` |
| `selected_surface_role` | `Selection` |

Zero roles need no theme registration. Configured roles are validated with
`theme_contract_default`, `theme_contract_check`, `theme_contract_satisfied`,
and `theme_contract_missing_required`. The default example registers
`vendor.alikit.sidebar.*`; delete that registration to use core roles. A missing
configured role falls back to the core role at render time after setup
validation, so the rail remains usable.

`Style` carries corner radius, selected-indicator width, and focus-ring width.
`Options` carries collapsed state, rail/expanded width, item height, gap,
padding, icon size, label size, and `wrap`. Collapsing changes width and omits
the visible label/badge; it does not change semantic IDs, selected state, or
focus ownership. There is no motion: navigation selection is immediately
readable and the component does not own an animation lifecycle.

## API reference

| Declaration | Notes |
| --- | --- |
| `Item` | Route `key`, `label`, `icon`, `detail`, optional `badge`, `disabled`. |
| `Options` | Collapsed state, widths, item geometry, icon/label size, `wrap`. |
| `Recipe` / `Style` | Optional namespaced surface roles and visual geometry. |
| `State` | Active roving key/index, focus request, and pending route proposal. |
| `Rail` | Per-description rail context returned by `rail_begin`. |
| `Rail_Item` | Per-description row context with selected/focused/disabled/position state. |
| `rail_begin` | Opens the rail surface, `List_Box` collection, and one focus scope; returns `(Rail, visible)`. |
| `item_begin` | Opens one `List_Box_Option` Button owner; returns `(Rail_Item, visible)`. |
| `row_surface`, `indicator`, `icon`, `label`, `badge` | Optional default visual parts. |
| `item_end` | Closes the row and records its activation proposal. |
| `rail_end` | Closes the rail and returns the one proposal. |
| `rail` | Convenience wrapper built from the parts. |
| `request_focus` | Focus the rail's Tab stop after layout. |
| `recipe_default`, `style_default` | Core-role defaults. |
| `theme_contract_default`, `theme_contract_check`, `theme_contract_satisfied`, `theme_contract_missing_required` | Setup-time validation. |
| `rail_semantic_id`, `item_semantic_id` | Stable semantic identities. |
| `instance_from_key` | Stable instance identity fallback when a parts author supplies only the key. |

`rail_begin` accepts `label`, `key`, and an optional `instance_id`. When the
instance ID is zero, a stable identity is derived from the key; explicit IDs are
preferred when keys may change between descriptions.

Route key `0`, zero instance ID, and duplicate keys are invalid. Selected and
Current identity follow the stable key across reorder. Removing the active key
repairs focus with the selected key first, then the nearest enabled route, then
the first enabled route. The accent indicator and label weight make selection
visible without relying on color alone.

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

`sidebar/sidebar_test.odin` covers the wrapper: semantics, selected/current
identity, disabled action rejection, parent structure, Down skipping disabled
routes, Return/pointer/semantic activation parity, the `.Roving_List` pattern,
collapsed/expanded identity, reorder, and the theme contract.
`sidebar/sidebar_parts_test.odin` drives custom rows directly:

- custom rows preserve `List_Box`/`List_Box_Option` semantics and activation;
- disabled routes are skipped by roving navigation;
- an unknown route returns `visible=false` and publishes no semantics;
- collapse keeps stable identity and the selected state for custom rows;
- the `.Roving_List` pattern passes with author-owned row visuals.

```powershell
odin test sidebar -define:ODIN_TEST_THREADS=1 -collection:alicorn=<alicorn> -collection:alikit=.
./out/sidebar_example.exe --smoke
./out/sidebar_parts_example.exe --smoke
./out/sidebar_composition_example.exe --smoke
```

## Limits

- Headless tests do not prove a physical screen-reader session, pixel output, or
  native route focus. Native smoke runs SDL_GPU D3D12 startup and one submitted
  frame.
- The rail is flat. A nested sidebar needs a tree projection and is a separate
  P1 component.
- Collapsed rows show icons (or whatever a custom row chooses). Provide a
  meaningful icon and accessible label; there is no built-in tooltip.
- The application owns route content, routing, history, and any keyboard
  shortcut that jumps directly to a route.

## Source map

- [Package](../sidebar/sidebar.odin)
- [Default tests](../sidebar/sidebar_test.odin)
- [Parts tests](../sidebar/sidebar_parts_test.odin)
- [Default example](../examples/sidebar/main.odin)
- [Parts example](../examples/sidebar_parts/main.odin)
- [Composition example](../examples/sidebar_composition/main.odin)
- [Theme JSON](../examples/sidebar/theme.json)
