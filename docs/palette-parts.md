# Palette Parts

`alikit:palette_parts` is a copyable, parts-based variant of the command
palette's result list. It exists to compare a stock component path against the
same path composed from public Alicorn facilities, not to replace
`alikit:command_palette`. The stock palette remains available; this package is
one reusable list part plus the application-owned shell that uses it.

The package owns only:

- the retained virtual list and published `List_Box` collection;
- selection reconciliation by stable `Item_ID`;
- enabled-row navigation, reveal, and one activation event;
- optional focus request for the list owner.

The application still owns the query, matching/ranking, commands, modal shell,
dismissal, and focus restoration. See
[the issue 3 research record](research/issue-003-parts-pilot.md) for the
measured comparison with `alikit:command_palette`.

## Usage

```odin
import palette "alikit:palette_model"
import parts "alikit:palette_parts"

app.matches_count, _ = palette.filter(app.items[:], app.query.text, app.matches[:])
event := parts.results(
	ctx,
	&app.results,
	app.items[:],
	app.matches[:app.matches_count],
	key=alicorn.key_string("app-palette-results"),
	parts.Options{accessible_label="Commands"},
)
if event.kind == .Activated {
	app.run_command(event.item_id)
}
```

Call `results` once per description, after the query field. Pass a fresh visible
slice each turn; the part never stores item strings. `handle_key` is the
application's keyboard path when its query field owns focus:

```odin
handled, event := parts.handle_key(&app.results, rt, items, visible, key)
```

When the list itself owns focus, its retained interaction scope delivers the
same keys through `interaction_event_next` during the next description. Both
paths use `palette_model.move` and `palette_model.activate`; there is no second
selection policy.

`parts.request_focus(&app.results)` asks for one after-frame focus of the list.
`parts.selection_visible_index(items, visible, &state)` reports the selected
row's current position without retained state.

## Semantics

Each realized row is a `button_begin(presentation=.Custom)` owner with a
`List_Box_Option` semantic record. The scroll region owns the `List_Box`
collection with a logical count, realized range, and selected/current identity.
Rows expose `Selected`, `Current`, `Disabled`, and `Select`/`Focus` actions.
Visual parts are attached for `.Icon`, `.Label`, `.Content`, and
`.Selected_Indicator` so an application can restyle without changing behavior.

`row_build` is deliberately the part to copy and edit. Replacing the leading
surface, text, or check icon does not change identity, navigation, focus, or
activation.

## Behavior

| Input | Result |
|---|---|
| `Up`/`Down` | `palette.move` with wrapping and disabled skipping |
| `Home`/`End` | first/last enabled visible row |
| `Return` | one activation event for the selected stable item |
| pointer | row activation through the ordinary Button owner |
| semantic `Select` | the same activation through `List_Box_Option` |
| caller reorder/removal | selection follows `Item_ID`; reconcile falls back to the first enabled row |

The part publishes only realized rows. `virtual_list_ensure_visible` is requested
after navigation; the list remains a single Tab stop with the rows
non-focusable.

## Limits

- It is a result-list part, not a modal palette. Add the application's own
  overlay/query shell, as the pilot fixture does.
- It does not implement type-ahead; the query field owns text input.
- `Page_Up`/`Page_Down` are not handled, matching the stock palette's current
  keyboard contract.
- Headless tests do not validate native IME or a platform accessibility bridge.
