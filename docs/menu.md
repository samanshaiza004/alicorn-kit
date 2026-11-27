# Menu

`alikit:menu` is a reusable, anchored, component-level dropdown menu. It is
built from public parts: a trigger, an overlay popup, `Menu_Item` row owners,
separators, optional grouped sections, and optional default row visuals. It
publishes `Menu`/`Menu_Item` semantics, roving Up/Down/Home/End navigation,
Escape and outside-click dismissal, and focus restoration to the trigger.

It is deliberately distinct from Alicorn's runtime context menu:

| | `alicorn.context_menu_*` | `alikit:menu` |
| --- | --- | --- |
| Owner | Runtime popup state | Caller-owned component state |
| Use | Native integration, application target, native menu commands | In-app composed controls |
| Contents | Runtime items and separators | Caller-owned item parts and custom rows |
| Semantics | Runtime menu popup | `Menu` group + `Menu_Item` (and ad-hoc nested groups) |

## Preview

The default appearance is a compact panel of label/shortcut rows with a check
slot, separators, and an active fill. The parts example replaces each row with
an icon, two text lines, a custom checkmark, and a danger group. The composition
example hosts a permission menu inside a share dialog.

The [external-consumer fixture](../tests/external_consumer/README.md) imports
`alikit:menu` through a collection from outside this repository and also
builds a source copy with only the Alicorn collection.

## Installation

For normal use, import the package through the AliKit collection:

```odin
import ui "alicorn:ui"
import menu "alikit:menu"
```

No init or destroy is required. The component allocates nothing.

To copy and edit the component source, copy the declared dependency recipe from
[`components.json`](../components.json):

- `menu/menu.odin`
- `selection/selection.odin`
- `theme_contract/contract.odin`

Place these in sibling packages, such as `vendor/menu`, `vendor/selection`, and
`vendor/theme_contract`, then rewrite the two intra-AliKit imports in the
copied `menu.odin`:

```odin
import sel "../selection"
import tc "../theme_contract"
```

The copy builds with only the Alicorn collection. Copying `menu.odin` alone
does not compile. The external-consumer fixture builds both the package-import
and source-copy forms.

## Composition

There are three supported authoring paths:

1. Import the complete component and call `trigger`, `popup_begin`, `item`, and
   `popup_end`.
2. Import the parts and compose the popup, groups, and rows: `popup_begin`,
   `group_begin`, `item_begin`, optional visual parts, `item_end`, `group_end`,
   `popup_end`.
3. Import the parts and write any visual subtree between `item_begin` and
   `item_end`.

| Layer | Responsibility |
| --- | --- |
| Alicorn | Modal overlay containment, pointer/wheel/focus confinement, `context_menu_placement`, Menu/Menu_Item roles, scroll region, buttons, theme roles. |
| `menu` | Trigger, anchored popup, placement, active-row navigation, reveal, outside/Escape dismissal, checked/disabled/separator publication, group scaffolding, focus restoration, and one chosen-command result. |
| Application | Items, command identity, dispatch, checked state, custom row content, and policy after activation. |

`State` contains only ephemeral interaction state: open/anchor/panel nodes, the
active roving key, focus/restoration requests, and one chosen command key. Row
navigation uses Alicorn's pure roving model through the shared
`alikit:selection` view; no application selection is stored.

The default wrapper draws this shape:

```text
trigger            -> Button with Expanded/Collapse semantics
popup_begin        -> transparent modal overlay, panel, Menu group, row scroll
  group_begin      -> optional ad-hoc nested Menu group (not a collection)
    item_begin     -> one Menu_Item Button owner; Checked/Disabled/Current
      row_surface  -> optional default row background and active fill
        check      -> optional default check slot
        label      -> optional default label
        shortcut   -> optional default shortcut hint
    item_end       -> one chosen-command result on activation
  group_end
  separator        -> visual row with no identity and no navigation slot
popup_end
```

## Minimal example

```odin
ITEMS: [3]menu.Item = {
	{key=1, label="Rename", shortcut="F2"},
	{key=2, label="Show grid", checked=true},
	{key=3, kind=.Separator},
}

// In the ordinary root:
_ = menu.trigger(ctx, &app.menu, "Actions", menu.Options{accessible_label="Actions"},
	key=ui.key_string("actions-trigger"))

// In render_overlays, after the ordinary root closes:
visible, chosen := menu.popup_begin(ctx, &app.menu, ITEMS[:],
	menu.Options{accessible_label="Actions"}, key=ui.key_string("actions-popup"),
	instance_id=1)
if !visible {
	if chosen != 0 { app.run(chosen) }
	return
}
for item, index in ITEMS {
	if menu.item(ctx, &app.menu, item, index) { app.run(item.key) }
}
menu.popup_end(ctx, &app.menu)
```

A custom trigger calls `open_from_node(&state, runtime, trigger_node)` instead
of the stock `trigger`.

## Custom rendering examples

The default appearance uses `row_surface`, `check`, `label`, and `shortcut`:

```odin
visible, chosen := menu.popup_begin(ctx, &app.menu, ITEMS[:],
	menu.Options{accessible_label="Actions"}, key=ui.key_string("popup"), instance_id=41)
if visible {
	for item, index in ITEMS {
		if item.kind == .Separator {
			menu.separator(ctx, index)
			continue
		}
		row, row_visible := menu.item_begin(ctx, &app.menu, item, index)
		if row_visible {
			if menu.row_surface(ctx, row) != 0 {
				menu.check(ctx, row)
				menu.label(ctx, row)
				menu.shortcut(ctx, row)
				ui.surface_end(ctx)
			}
			if menu.item_end(ctx, row) { app.run(item.key) }
		}
	}
	menu.popup_end(ctx, &app.menu)
}
```

A custom row keeps the `Menu_Item` owner and owns everything inside it:

```odin
for item, index in ITEMS {
	row, row_visible := menu.item_begin(ctx, &app.menu, item, index)
	if !row_visible { continue }
	if menu.row_surface(ctx, row) != 0 {
		_ = ui.icon(ctx, .File, key=ui.key_u64(1), size=16)
		if ui.column(ctx, key=ui.key_u64(2), grow=1) {
			_ = ui.text(ctx, item.label, key=ui.key_u64(3), size=13)
			_ = ui.text(ctx, item.detail, key=ui.key_u64(4), size=10)
		}
		if row.checked { _ = ui.icon(ctx, .Check, key=ui.key_u64(5), size=14) }
		if item.shortcut != "" {
			_ = ui.text(ctx, item.shortcut, key=ui.key_u64(6), size=10)
		}
		ui.surface_end(ctx)
	}
	if menu.item_end(ctx, row) { app.run(item.key) }
}
```

`MenuItem` exposes the state a custom row needs:

| Field | Meaning |
| --- | --- |
| `item` | The caller-owned item being rendered. |
| `index`, `count` | Stable position in the popup's logical rows. |
| `selected` | This row owns the keyboard-active identity. |
| `checked` | The application-owned checked state. |
| `disabled` | The item's disabled policy. |
| `keep_open` | The popup's `keep_open_on_select` policy for this description. |
| `check_color`, `check_slot` | Resolved defaults for the check part. |
| `visible` | `false` means skip the subtree and do not call `item_end`. |

`item_begin` also accepts ordinary `Options`, `Recipe`, and `Style` values, so a
parts author can share the same resolved geometry as `popup_begin`.

### Groups

`group_begin(ctx, &state, "Danger", key=...)` opens an optional ad-hoc semantic
`Menu` group around a section of rows; `group_end` closes it. Groups do not
change row indexes, do not add a focus stop, and are not composite collections.
Alicorn's pinned `semantic_collection_begin` still rejects `.Menu`, so the
popup publishes a flat `Menu` group with `Menu_Item` children and groups add
nested `Menu` semantics without a logical count or selected identity. This is
the recorded #241 gap, not a second semantic model.

### Submenus

v1 is intentionally single-level. The single anchored popup, one panel scroll
region, one active-row index, and trigger focus restoration do not contain a
nested-open/open-parent coordination model. Implementing nested popups would
duplicate that policy and need new dismissal/focus tests; it is not a cheap
extension of the current machinery. Compose a second menu `State` anchored to a
row when an application needs a submenu, and keep the parent/child open policy
in the application. The package does not claim native submenu semantics.

## Styling, motion, and theme

`Recipe` has optional panel, item, and active-item surface roles plus a core
check color. `Style` carries corner radius, focus width, and check slot width.
`Options` carries popup width, row height, padding, maximum visible rows,
placement margin, and whether selection keeps the menu open. The popup uses a
transparent backdrop (no dimming) and a themed surface panel with a border.

Keyboard-active rows are revealed through an inner hidden-scrollbar scroll
region; wheel scrolling works because the region is retained. There is no
component motion: a menu opens and closes immediately, and the runtime owns
overlay focus presentation.

## API reference

| Declaration | Notes |
| --- | --- |
| `Item` | `key`, `label`, `detail`, `shortcut`, `kind`, `disabled`, `checked`. |
| `Item_Kind` | `.Item` or `.Separator`. |
| `Options` | Accessible label, popup width, row geometry, max visible rows, placement margin, `keep_open_on_select`. |
| `Recipe` / `Style` | Optional namespaced surface roles and visual geometry. |
| `State` | Open/anchor/panel/scroll nodes, active roving identity, focus requests, and the pending chosen key. |
| `MenuItem` | Per-description row context. |
| `trigger` | Stock anchored Button trigger. |
| `popup_begin` | Open the overlay, panel, `Menu` group, and row scroll; returns `(visible, chosen_key)`. |
| `item_begin` / `item_end` | Open/close one `Menu_Item` Button owner; `item_end` returns activation. |
| `row_surface`, `check`, `label`, `shortcut`, `detail` | Optional default row visuals. |
| `separator` | Visual separator part. |
| `group_begin` / `group_end` | Optional ad-hoc nested Menu group. |
| `item` | Convenience default row built from the parts. |
| `popup_end` | Close the panel, overlay, and key scope. |
| `open_from_node`, `close`, `take_chosen` | Custom trigger, programmatic close, and pending-key consumption. |
| `menu_semantic_id`, `item_semantic_id`, `group_semantic_id` | Stable semantic identities. |
| `recipe_default`, `style_default` | Core defaults. |
| `theme_contract_default`, `theme_contract_check`, `theme_contract_satisfied`, `theme_contract_missing_required` | Setup-time validation. |

`Item.key` must be nonzero and unique for actionable rows. `Item.detail` becomes
the semantic description; `shortcut` is visual. `MAX_ITEMS` is 128.

## Keyboard and accessibility contract

- **Trigger** is a Button: pointer, Enter/Space, and semantic Press open or
  close it. It publishes Expanded while open.
- **Up/Down** move the active row, skipping separators and disabled rows;
  **Home/End** move to the first/last enabled row.
- **Return/Space** choose the active row. `popup_begin` returns the chosen key
  and closes the menu (unless `keep_open_on_select`). Pointer/semantic row
  activation returns `true` from `item`/`item_end`.
- **Escape** and a pointer down outside the panel close the menu and restore
  trigger focus.
- The popup publishes one `Menu` with the accessible label and each actionable
  row as `Menu_Item` with label, value, description, Checked/Disabled/Current
  states, and Focus/Select/Press actions when enabled.
- Not claimed: submenus, type-ahead, multi-select, composite menu collection
  count/position, or native menu integration.

`menu/menu_test.odin` covers the wrapper: identities, theme contract, trigger
semantics, checked/disabled states, Down skipping separators/disabled rows,
Return choice, Escape dismissal, trigger focus restoration, pointer selection,
outside-click dismissal, placement flip, and viewport containment.
`menu/menu_parts_test.odin` drives custom rows and groups:

- custom rows preserve `Menu_Item` semantics, detail descriptions, checked and
  disabled states, and action presence;
- group parts publish ad-hoc nested `Menu` semantics without a collection;
- keyboard navigation skips separators and disabled custom rows and chooses the
  same stable key as the wrapper;
- pointer, Escape, and outside dismissal use the same focus restoration;
- placement remains inside the viewport.

```powershell
odin test menu -define:ODIN_TEST_THREADS=1 -collection:alicorn=<alicorn> -collection:alikit=.
./out/menu_example.exe --smoke
./out/menu_parts_example.exe --smoke
./out/menu_composition_example.exe --smoke
```

There is no dropdown-menu pattern kind in `testui` at this revision; explicit
drive assertions are used.

## Limits

- Headless tests do not prove a physical screen-reader menu session or pixels.
- Long menus scroll inside the popup but do not use a composite collection.
- Submenus are application-composed from a second menu `State`; they are not a
  package feature.
- Menu groups are ad-hoc nested Menu semantics, not a counted collection.
- The application owns command identity, dispatch, checked state, and any
  application-specific row content.

## Source map

- [Package](../menu/menu.odin)
- [Default tests](../menu/menu_test.odin)
- [Parts tests](../menu/menu_parts_test.odin)
- [Default example](../examples/menu/main.odin)
- [Parts example](../examples/menu_parts/main.odin)
- [Composition example](../examples/menu_composition/main.odin)
