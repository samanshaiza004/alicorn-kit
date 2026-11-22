# Menu

`alikit:menu` is a reusable, anchored, component-level dropdown menu. It composes
a trigger, a transparent modal overlay popup, `Menu`/`Menu_Item` semantics,
single-level rows (label, shortcut, checked, disabled, separator), roving
Up/Down/Home/End navigation, Escape and outside-click dismissal, and focus
restoration to the trigger.

It is deliberately distinct from Alicorn's runtime context menu:

| | `alicorn.context_menu_*` | `alikit:menu` |
| --- | --- | --- |
| Owner | Runtime popup state | Caller-owned component state |
| Use | Native integration, application target, native menu commands | In-app composed controls |
| Contents | Runtime items and separators | Caller-owned item parts |
| Semantics | Runtime menu popup | `Menu` group + `Menu_Item` |

Submenus are not implemented. Nest a second `State` or wait for a recorded
component extension.

## Responsibility split

| Layer | Responsibility |
| --- | --- |
| Alicorn | Modal overlay containment, pointer/wheel/focus confinement, `context_menu_placement`, Menu/Menu_Item roles, scroll region, buttons, theme roles. |
| `menu` | Trigger, anchored popup, placement, active-row navigation, reveal, outside/Escape dismissal, checked/disabled/separator presentation, focus restoration. |
| Application | Items, command identity, dispatch, checked state, policy after activation. |

## Copyable implementation

Files: `menu/menu.odin`, `menu/menu_test.odin`, `examples/menu/main.odin`.

```odin
// In the root:
_ = menu.trigger(ctx, &app.menu, "Actions", menu.Options{accessible_label="Actions"},
	key=alicorn.key_string("actions-trigger"))

// In render_overlays:
visible, chosen := menu.popup_begin(ctx, &app.menu, app.items[:],
	menu.Options{accessible_label="Actions"}, key=alicorn.key_string("actions-popup"),
	instance_id=1)
if !visible {
	if chosen != 0 { app.run(chosen) }
	return
}
for item, index in app.items {
	if menu.item(ctx, &app.menu, item, index) { app.run(item.key) }
}
menu.popup_end(ctx, &app.menu)
```

A custom trigger calls `open_from_node(&state, runtime, trigger_node)` instead
of the stock `trigger`.

## Parts and identities

| Part | Identity | Notes |
| --- | --- | --- |
| Trigger | Application key | Stock `trigger` draws a Button with Expanded/Collapse semantics. |
| Popup | `menu_semantic_id(instance_id)` | Focusable Menu group inside the overlay. |
| Row | `item_semantic_id(instance_id, item_key)` | `Menu_Item`; checked/disabled/current states. |
| Separator | Visual row | Not actionable, no identity, not counted as an item. |

`Item.key` must be nonzero and unique for actionable rows. `Item.detail` becomes
the semantic description; `shortcut` is visual. `MAX_ITEMS` is 128.

### Menu collection gap

Alicorn's pinned `semantic_collection_begin` accepts List, Tree, Tab_List,
List_Box, Radio_Group, Table, and Table_Row, but **not** `.Menu`. The menu
therefore publishes a flat `Menu` group and `Menu_Item` children without a
composite collection count/selection. Composite menu collection support is
recorded as an Alicorn-side gap.

## Styling, motion, and theme

`Recipe` has optional panel, item, and active-item surface roles plus a core
check color. `Style` carries corner radius, focus width, and check slot width.
`Options` carries popup width, row height, padding, maximum visible rows,
placement margin, and whether selection keeps the menu open. The popup uses a
transparent backdrop (no dimming) and a themed surface panel with a border.

Keyboard-active rows are revealed through an inner hidden-scrollbar scroll
region; wheel scrolling works because the region is retained. There is no
animation.

## Keyboard and accessibility contract

- **Trigger** is a Button: pointer, Enter/Space, and semantic Press open or
  close it. It publishes Expanded while open.
- **Up/Down** move the active row, skipping separators and disabled rows;
  **Home/End** move to the first/last enabled row.
- **Return/Space** choose the active row. `popup_begin` returns the chosen key
  and closes the menu (unless the app reopens it). Pointer/semantic row
  activation returns `true` from `item`.
- **Escape** and a pointer down outside the panel close the menu and restore
  trigger focus.
- The popup publishes one `Menu` with the accessible label and each actionable
  row as `Menu_Item` with label, value, description, Checked/Disabled/Current
  states, and Focus/Select/Press actions when enabled.
- Not claimed: submenus, type-ahead, multi-select, composite collection
  count/position, or native menu integration.

## Conformance tests

`menu/menu_test.odin` covers:

- identities, theme contract, and role overrides;
- trigger semantics, Menu/Menu_Item grouping, checked/disabled states;
- Down skipping separators/disabled rows, Return choice, Escape dismissal, and
  trigger focus restoration;
- pointer item selection, outside-click dismissal, bottom-edge placement flip,
  and viewport containment.

There is no dropdown-menu pattern kind in `testui` at this revision; explicit
drive assertions are used.

## Limits

- Headless tests do not prove a physical screen-reader menu session or pixels.
- Long menus scroll inside the popup but do not use a composite collection.
- Submenus and type-ahead are future work.

## Source map

- [Package](../menu/menu.odin)
- [Tests](../menu/menu_test.odin)
- [Example](../examples/menu/main.odin)
