# Icon Picker

`alikit:icon_picker` is a complete custom composite: search, a virtualized grid
or list of icon choices, roving keyboard focus, semantic selection, one
activation event, and two appearances that share one behavior contract. It is
ordinary copyable Odin source built only on Alicorn's public UI and runtime
APIs; there is no runtime registration, second UI tree, state store, or
component lifecycle.

Use it when an application needs a small icon chooser. Copy
[`icon_picker/icon_picker.odin`](../icon_picker/icon_picker.odin) into the
application, keep the parts it needs, and change the drawing procedures. The
complete consumer is
[`examples/icon_picker/main.odin`](../examples/icon_picker/main.odin); it imports
the package by relative path and builds with only `-collection:alicorn=...`.

## Ready-made usage

```odin
import alicorn "alicorn:runtime"
import picker "alikit:icon_picker" // or a relative copy

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
			key=alicorn.key_string("app-icon-picker"),
			instance_id=1)
		if event.kind == .Activated {
			app.selected_key = event.key // accept the proposed change
			app.open = false
		}
	}
	alicorn.modal_overlay_end(ctx)
}
```

Initialize once and destroy once:

```odin
if !picker.init(&app.icon) { return }
defer picker.destroy(&app.icon)
app.icon.selected_key = app.selected_key
```

`state.selected_key` is controlled by the application. `picker` never mutates
it; an `Event{kind=.Activated, key=...}` is a proposal. Keyboard, pointer, and
semantic activation all produce that same event.

## Named parts

| Part | Public surface | Owned by |
|---|---|---|
| Search | `Options.hide_search`, `Options.search_accessible_name`, `state.query` | picker; `set_query`/`query_text` are the public value controls |
| Grid/list collection | `Options.accessible_label`, `Options.appearance`, `Options.columns`, `cell_size`, `row_height`, `max_visible_rows` | picker layout; one retained virtual list |
| Cell/row | `Choice{key,label,icon,keywords,detail,disabled}`, `cell_emit`, `row_emit` | application data; drawing is copyable source |
| Stable identity | `choice_semantic_id(instance_id,key)`, `collection_semantic_id(instance_id)` | application-provided `instance_id` plus stable choice keys |
| Activation | `Event`, `state.proposed` | picker proposes; application accepts |
| Focus requests | `request_search_focus`, `request_grid_focus` | application input/state calls them; picker schedules an after-frame focus |
| Theme | Alicorn core color roles only | no component theme contract is required |

`Choice.keywords` contributes to search but is not announced. `Choice.detail`
is announced in both appearances; the grid does not paint it. `Choice.label` is
always the accessible name, even when the grid paints only an icon.

## Two appearances, one contract

`Options.appearance` selects `.Grid` (square icon cells) or `.List` (full-width
rows with an icon, label, and detail). The appearances differ only in layout and
the drawing procedure:

- the same choices, filter, stable keys, semantic IDs, states, and actions;
- the same `Up`/`Down` step (one row in the grid, one item in the list);
- the same `Left`/`Right` grid step, `Home`/`End` row bounds, `Page_Up`/`Page_Down`
  page stride, disabled skipping, and boundary clamping;
- the same proposed activation and controlled selection;
- focus stays on the collection when the appearance changes.

The tests switch one mounted instance from grid to list and assert that the cell
semantic identity, accessible name, bounds change, selection, and behavior
survive.

## Behavior

| Input | Result |
|---|---|
| `Up`/`Down` | grid: one row; list: one item; disabled choices skipped |
| `Left`/`Right` | grid: one cell; list: ignored |
| `Home`/`End` | first/last enabled cell of the active row (list: first/last) |
| `Page_Up`/`Page_Down` | one page of rows/cells |
| `Return` | proposes the active enabled choice |
| pointer click | proposes the clicked enabled choice |
| semantic `Select`/`Press` | proposes the same choice through `button_begin` activation |
| query edit | refilters; the active key stays when it remains visible, otherwise the nearest enabled row is chosen |
| choice removal | the active key moves to a remaining enabled choice; `selected_key` stays application-controlled |
| reorder | active and selected identity stay attached to keys, not positions |
| virtualization | only realized rows publish; the retained virtual list reveals the active row |

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

A copied package can be changed the same way: replace `cell_emit`/`row_emit`,
add a `Choice` field (for example a colour swatch), omit the search part with
`hide_search`, or add a bespoke key through the application's own
`ui.interaction_scope` / `on_key`. Keep focus, IME, modal, and semantic rules in
Alicorn's existing facilities.

## Hosting a dialog

The picker is an inline composite. A modal host owns Escape, outside-click
dismissal, nested overlays, and focus restoration; see
[`examples/icon_picker/main.odin`](../examples/icon_picker/main.odin). The modal
pattern check in `icon_picker_test.odin` verifies pointer opening, focus inside,
traversal wrap, containment, Escape, and focus restoration against pinned
`alicorn:testui`.

## Tests and limits

`odin test icon_picker -collection:alicorn=/path/to/alicorn -collection:alikit=.`
runs 10 external-package tests: token matching, identity, keyboard/pointer/
semantic activation parity, focus versus selection, disabled skipping, removal
and reorder reconciliation, appearance identity, filtering and IME yield,
200-choice virtualization and reveal, the `.Modal_Dialog` pattern check, Escape/
outside-click/nested overlay dismissal, teardown idle, and an application
Ctrl+F focus interaction.

Known limits:

- **No Space activation on the collection.** The collection is a scroll region
  with a retained interaction scope, not a text owner. Marking it as a generic
  `text_input_target` would receive committed Space, but Alicorn's text-field
  preemption then suppresses `Left`/`Right`/`Home`/`End` application keys, which
  breaks grid navigation. The pilot records this as a concrete core candidate;
  use `Return`, pointer, or semantic activation.
- The grid has no dedicated ARIA/`.Grid` semantic role; it publishes a
  `List_Box` with positions. The logical order is the filtered order.
- `Home`/`End` are row bounds in the grid. There is no `Ctrl+Home`/`Ctrl+End`
  first/last intent in the public key vocabulary used here.
- Filtering is local ASCII case-insensitive substring matching. Replace
  `matches` with application ranking when ranking is domain-specific.
- Headless tests do not exercise OS IME candidate windows, native accessibility
  bridges, or pixels. The native demo is validated separately with `--smoke`.
