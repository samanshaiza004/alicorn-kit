# Icon Picker

`alikit:icon_picker` is a complete custom composite built from public parts:
search, a virtualized grid or list of icon choices, roving keyboard focus,
stable selection, semantics, one activation event, and two appearances that
share one behavior contract. It is ordinary copyable Odin source built only on
Alicorn's public UI and runtime APIs; there is no runtime registration, second
UI tree, state store, or component lifecycle.

Use it when an application needs a small icon chooser. Copy
[`icon_picker/icon_picker.odin`](../icon_picker/icon_picker.odin) into the
application, keep the parts it needs, and change the drawing procedures. The
complete consumer is
[`examples/icon_picker/main.odin`](../examples/icon_picker/main.odin); it imports
the package by relative path and builds with only `-collection:alicorn=...`.

## Preview

The default grid paints square icon cells; the list paints full-width rows with
an icon, label, and detail. The parts example replaces both with application
visuals (letter tiles or custom rows). The composition example hosts the picker
inside a dialog and uses a Segmented control for the appearance.

The authoring-quality follow-up includes an [authored list-appearance visual
target](research/authoring-reliability/references/icon-picker.svg), not a
desktop capture. The example switches between Grid and List with Ctrl+2. The
new retained-output checks verify that the search query and List row name/detail
produce visible glyphs, including after resizing.

## Runnable examples

- [Quick Start](../examples/icon_picker_quick_start/main.odin): the default
  inline grid, eight caller-owned choices, and controlled stable-key selection.
  It imports only `alicorn:ui` and `alikit:icon_picker`.
- [Reference application](../examples/icon_picker/main.odin): the complete
  copyable composite in a modal, with Grid/List switching, focus restoration,
  and nested-dialog behavior.
- [Parts](../examples/icon_picker_parts/main.odin) and
  [Composition](../examples/icon_picker_composition/main.odin) show custom
  row/cell drawing and a dialog-hosted picker.

## Installation

For normal use, import the package through the AliKit collection. To copy and
edit the source, use its recipe in [`components.json`](../components.json); it
contains the single package source and needs no intra-AliKit import rewrites.
Tests and examples remain in the AliKit repository.

```odin
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import picker "alikit:icon_picker" // or the local package from the copy recipe
```

Initialize once and destroy once:

```odin
if !picker.init(&app.icon) { return }
defer picker.destroy(&app.icon)
app.icon.selected_key = app.selected_key
```

## Composition

There are three supported authoring paths:

1. Import the complete component and call `picker.picker`.
2. Import the parts and compose search, grid, and items:
   `search`, `grid_begin`, `item_begin`, optional `cell`/`row`, `item_end`,
   `grid_end`, and `empty`.
3. Import the parts and write any visual subtree between `item_begin` and
   `item_end`.

| Layer | Responsibility |
| --- | --- |
| Alicorn | Layout, focus, pointer hit testing, Button activation, text field, virtual list, semantics, and rendering. |
| `icon_picker` | Query buffer, filtering policy, stable match projection, roving grid/list navigation, selection proposal, reveal, semantics, and default visuals. |
| Application | Choices, accepted selection, commands, surrounding dialog, naming, and any ranking override. |

`State` owns the query buffer, filtered match indexes, active roving identity,
focus/reveal requests, the last appearance, and one activation proposal. The
application owns `selected_key`; the component never mutates it. An
`Event{kind=.Activated, key=...}` is a proposal.

The search buffer belongs to the picker. Route native accessibility
`.Set_Value` requests from `ui.run`'s `on_wake` callback so the query and
filtered choices update together:

```odin
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import picker "alikit:icon_picker"

on_wake :: proc(app: ^App, ctx: ui.Application_Context) {
	rt := cast(^alicorn.Runtime)ctx
	for {
		request, found := alicorn.semantic_request_pop(rt)
		if !found { break }
		_ = picker.handle_semantic_set_value_request(&app.icon, rt, request)
		alicorn.semantic_request_event_destroy(rt, &request)
	}
}
```

The application owns the shared queue. In a larger app, route each event to
its owner before destroying it. The modal reference app demonstrates this
integration; the inline Quick Start omits the optional host callback.

The default wrapper draws this shape:

```text
picker
  root container + one keyboard scope
    search              -> controlled text field part
    grid_begin          -> virtual grid/list + List_Box collection
      item_begin        -> one List_Box_Option Button owner
        cell / row      -> optional default visual
      item_end
    grid_end            -> one Activated event
  empty                 -> no-results label part
```

## Ready-made usage

```odin
App :: struct {
	icon: picker.State,
	choices: [2]picker.Choice,
	selected_key: u64,
	open: bool,
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.open { return }
	if alicorn.modal_overlay_begin(ctx, "icon-dialog") == 0 { return }
	if ui.panel(ctx, width=420, height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=16) {
		_ = alicorn.semantic_description(ctx, .Dialog, "Choose an icon")
		event := picker.picker(ctx, &app.icon, app.choices[:],
			picker.Options{accessible_label="Icons"},
			key=ui.key_string("app-icon-picker"),
			instance_id=1)
		if event.kind == .Activated {
			app.selected_key = event.key // accept the proposed change
			app.open = false
		}
	}
	alicorn.modal_overlay_end(ctx)
}
```

## Custom rendering examples

The parts own the semantics and navigation; the author owns the cell or row:

```odin
root := alicorn.container_begin(ctx, .Container, label="icons",
	key=ui.key_string("icons-root"),
	style=ui.layout_style(.Column, width=-1, height=alicorn.LAYOUT_SIZE_FIT_CONTENT, gap=8))
_ = ui.interaction_scope(ctx, root, rawptr(&app.icon), alicorn.Interaction_Scope_Options{
	keys={.Up, .Down, .Left, .Right, .Home, .End, .Page_Up, .Page_Down, .Return, .Toggle},
	composition_yield_keys={.Up, .Down, .Left, .Right, .Home, .End, .Page_Up, .Page_Down, .Return, .Toggle},
	text_preempt_keys={.Up, .Down, .Left, .Right, .Home, .End, .Page_Up, .Page_Down, .Toggle},
})
_, _ = picker.search(ctx, &app.icon, options, key=ui.key_string("icons-search"))

grid, visible := picker.grid_begin(ctx, &app.icon, choices, options,
	key=ui.key_string("icons-grid"), instance_id=1, scope_owner=root)
if !visible {
	_ = picker.empty(ctx, &app.icon, options)
} else {
	for index := grid.first; index < grid.last; index += 1 {
		item, item_visible := picker.item_begin(ctx, &grid, index)
		if !item_visible { continue }
		// Draw any ordinary Alicorn layout inside the semantic Button owner.
		if ui.panel(ctx, key=ui.key_u64(1), width=-1, height=-1, padding=4,
			align=.Center, justify=.Center,
			fill=ui.style_color(ctx, .Selection if item.selected else .Subtle_Surface),
			radius=12) {
			_ = ui.text(ctx, item.choice.label[:1], key=ui.key_u64(2), size=18)
		}
		picker.item_end(ctx, &grid, item)
	}
	if event := picker.grid_end(ctx, &grid); event.kind == .Activated {
		app.selected_key = event.key
	}
}
alicorn.container_end(ctx)
```

`Grid_Item` exposes the state a custom cell/row needs:

| Field | Meaning |
| --- | --- |
| `choice` | The caller-owned choice being rendered. |
| `index`, `count` | Position in the filtered match set. |
| `selected` | Controlled `selected_key` equality. |
| `active` | This choice owns the roving focus. |
| `disabled` | The choice's disabled policy. |
| `visible` | `false` means skip the subtree and do not call `item_end`. |
| `owner` | The semantic Button owner. |

`grid_begin` owns the virtual list and the `List_Box` collection. In Grid
appearance it opens one row container automatically as items are emitted in
ascending realized order, so a custom author only needs to emit cells. The
author can pass zero for `scope_owner` and drive navigation with the public
`handle_key` instead.

`cell` and `row` are the default visuals. Omit them, or use them with your own
choice data. `search` can be omitted with `Options.hide_search` when the
application supplies its own query UI.

## Two appearances, one contract

`Options.appearance` selects `.Grid` (square icon cells) or `.List` (full-width
rows with an icon, label, and detail). The appearances differ only in layout and
the drawing procedure:

- the same choices, filter, stable keys, semantic IDs, states, and actions;
- the same `Up`/`Down` step (one row in the grid, one item in the list);
- the same `Left`/`Right` grid step, `Home`/`End` row bounds,
  `Page_Up`/`Page_Down` page stride, disabled skipping, and boundary clamping;
- the same proposed activation and controlled selection;
- focus stays on the collection when the appearance changes.

## Behavior

| Input | Result |
|---|---|
| `Up`/`Down` | grid: one row; list: one item; disabled choices skipped |
| `Left`/`Right` | grid: one cell; list: ignored |
| `Home`/`End` | first/last enabled cell of the active row (list: first/last) |
| `Page_Up`/`Page_Down` | one page of rows/cells |
| `Return` | proposes the active enabled choice |
| `Space` | proposes the active enabled choice |
| pointer click | proposes the clicked enabled choice |
| semantic `Select`/`Press` | proposes the same choice through `button_begin` activation |
| query edit | refilters; the active key stays when it remains visible, otherwise the nearest enabled row is chosen |
| choice removal | the active key moves to a remaining enabled choice; `selected_key` stays application-controlled |
| reorder | active and selected identity stay attached to keys, not positions |
| virtualization | only realized rows publish; the retained virtual list reveals the active row |

While the search field is focused, `Up`/`Down`/`Left`/`Right`, `Home`/`End`,
`Page_Up`/`Page_Down`, and `Space` drive the grid. Characters, Backspace,
Delete, and IME composition stay with the field. This is Alicorn's
scope-owned `text_preempt_keys` policy on the picker's single root scope; the
complete wrapper registers it. A custom shell that passes a `scope_owner` owns
the same scope configuration.

The navigation index math comes from `alicorn:runtime`'s pure `Roving_View`
model. The picker projects its filtered match order, columns, page size, and
row-scoped Home/End into a value view, then applies the proposed index to its
own active key. The picker owns filtering, active identity, reveal, activation,
and selection; the model carries no state and publishes no semantics.

The collection publishes `List_Box` + `List_Box_Option` semantics with logical
count, realized range, `Selected`, `Current`, `Disabled`, and `Select`/`Focus`
actions. Registry keys follow `Choice.key`, never row position.

## Application-authored interaction

The example adds Ctrl+F from anywhere in the picker dialog. It is ordinary
application state and a public focus request, not component API:

```odin
case .Find:
	if app.open {
		_ = picker.request_search_focus(&app.icon)
		alicorn.invalidate_root(rt, "focus icon search")
		return true
	}
```

A copied package can be changed the same way: replace `cell`/`row`, add a
`Choice` field (for example a colour swatch), omit the search part with
`hide_search`, or add a bespoke key through the application's own
`ui.interaction_scope` / `on_key`. Keep focus, IME, modal, and semantic rules in
Alicorn's existing facilities.

## Hosting a dialog

The picker is an inline composite. A modal host owns Escape, outside-click
dismissal, nested overlays, and focus restoration; see
[`examples/icon_picker/main.odin`](../examples/icon_picker/main.odin) and
[`examples/icon_picker_composition/main.odin`](../examples/icon_picker_composition/main.odin).
The modal pattern check in `icon_picker_test.odin` verifies pointer opening,
focus inside, traversal wrap, containment, Escape, and focus restoration against
pinned `alicorn:testui`.

## API reference

| Declaration | Notes |
| --- | --- |
| `Choice` | `key`, `label`, `icon`, `keywords`, `detail`, `disabled`. |
| `Options` | Labels, appearance, columns, cell/row/icon geometry, max visible rows, `hide_search`. |
| `State` | Query buffer, matches, active identity, focus/reveal requests, last appearance, proposal. |
| `Grid` | Per-description grid/list context: realized match range, collection, row model. |
| `Grid_Item` | Per-description cell/row context. |
| `init` / `destroy` | Allocate and release the query and match buffer. |
| `search` | Controlled search field part. |
| `grid_begin` / `grid_end` | Open/close the virtual grid/list and collection; `grid_end` returns the proposal. |
| `item_begin` / `item_end` | Open/close one semantic choice Button. |
| `cell` / `row` | Optional default visuals. |
| `empty` | No-results label part. |
| `sync` | Refresh matches and repair the active identity. |
| `handle_key` | Public navigation/activation path for an application-owned scope. |
| `picker` | Complete composite wrapper. |
| `set_query`, `query_text`, `active_key`, `match_count` | Value and diagnostic helpers. |
| `request_search_focus`, `request_grid_focus` | After-frame focus requests. |
| `choice_semantic_id`, `collection_semantic_id` | Stable semantic identities. |

## Tests and limits

`odin test icon_picker -collection:alicorn=/path/to/alicorn -collection:alikit=.`
runs 14 external-package tests: token matching, identity,
keyboard/pointer/semantic activation parity, focus versus selection, disabled
skipping, removal and reorder reconciliation, appearance identity, filtering and
IME yield, search-focus key yield (arrows and Space), 200-choice virtualization
and reveal, visible query and List-row glyph checks, narrow-resize containment,
the `.Modal_Dialog` pattern check, Escape/outside-click/nested overlay
dismissal, teardown idle, an application Ctrl+F focus interaction, and the
public parts with custom grid cells and list rows.

Known limits:

- The grid has no dedicated ARIA/`.Grid` semantic role; it publishes a
  `List_Box` with positions. The logical order is the filtered order.
- `Home`/`End` are row bounds in the grid. There is no `Ctrl+Home`/`Ctrl+End`
  first/last intent in the public key vocabulary used here.
- Filtering is local ASCII case-insensitive substring matching. Replace
  `matches` with application ranking when ranking is domain-specific.
- Headless tests do not exercise OS IME candidate windows, native accessibility
  bridges, or pixels. The native demos are validated separately with `--smoke`.

## Source map

- [Package](../icon_picker/icon_picker.odin)
- [Default tests](../icon_picker/icon_picker_test.odin)
- [Parts tests](../icon_picker/icon_picker_parts_test.odin)
- [Default example](../examples/icon_picker/main.odin)
- [Parts example](../examples/icon_picker_parts/main.odin)
- [Composition example](../examples/icon_picker_composition/main.odin)
