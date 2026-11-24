# Palette Parts

`alikit:palette_parts` is a copyable, parts-based result list for command
palettes and other enabled-row list surfaces. It owns the retained virtual list,
the published `List_Box` collection, selection by stable `Item_ID`,
enabled-row navigation, reveal, optional single-level groups, optional default
row visuals, and one activation event.

The application owns the query, matching/ranking, commands, modal shell,
dismissal, and focus restoration. `alikit:command_palette` now builds its own
results from these parts, so the complete modal and an application-owned shell
share one result contract.

## Preview

The default row is a rounded surface with an accent leading tile, title,
optional description, and a selected check. The command-palette parts example
replaces that row with an application-owned icon tile, title/description
column, keyword chip, and check inside an application-owned inline shell.

## Installation

Copy `palette_parts/parts.odin` (and, for the regression suite,
`palette_parts/parts_test.odin`) into an application, or import
`alikit:palette_parts` with the AliKit collection. The pilot measurement lives
with `alikit:command_palette` because it compares both paths.

```odin
import parts "alikit:palette_parts"

ITEMS := [2]parts.Item{
	{id=parts.Item_ID(1), title="Open File", description="Browse the workspace"},
	{id=parts.Item_ID(2), title="Build Project", keywords="compile"},
}
```

No init or destroy is required; the part allocates nothing. `parts.Item`,
`parts.Item_ID`, and `parts.Match` expose the public input types, so ordinary
consumers do not need to import `palette_model` just to construct rows. Import
`palette_model` only when using its independent filtering or selection helpers.
The application owns its `ui.Text_Buffer` query and its match buffer.

## Composition

There are three supported authoring paths:

1. Import `palette_parts` and call `results` for the default list.
2. Compose `list_begin`, `item_begin`, optional visual parts, `item_end`, and
   `list_end`; add `group_begin`/`group_end` and `empty` where needed.
3. Copy `parts.odin` and replace the row visual parts or navigation helpers.

| Layer | Responsibility |
| --- | --- |
| Alicorn | Virtual list, semantics, focus, keys, layout, rendering. |
| `palette_parts` | Retained list owner, `List_Box`/`List_Box_Option` publication, stable-ID selection, enabled navigation, reveal, groups, and one activation event. |
| Application | Query, matching/ranking, commands, shell, dismissal, and focus restoration. |

## Usage

```odin
import ui "alicorn:ui"
import palette "alikit:palette_model" // optional helper for substring filtering
import parts "alikit:palette_parts"

app.matches_count, _ = palette.filter(app.items[:], app.query.text, app.matches[:])
event := parts.results(
	ctx,
	&app.results,
	app.items[:],
	app.matches[:app.matches_count],
	key=ui.key_string("app-palette-results"),
	parts.Options{accessible_label="Commands"},
)
if event.kind == .Activated {
	app.run_command(event.item_id)
}
```

The example uses `palette_model.filter` as an optional substring matcher; matching and ranking
remain application policy. `parts.Item`, `parts.Item_ID`, and `parts.Match` are the component's
public input types, so import `palette_model` only when its helper behavior fits the application.

Pass a fresh visible slice each turn; the part never stores item strings.
`handle_key` is the application's keyboard path when its query field owns
focus:

```odin
handled, event := parts.handle_key(&app.results, rt, items, visible, key)
```

When the list itself owns focus, its retained interaction scope delivers the
same keys through `interaction_event_next` during the next description. Both
paths use `palette_model.move` and `palette_model.activate`.

`parts.request_focus(&app.results)` asks for one after-frame focus of the list.
`parts.selection_visible_index(items, visible, &state)` reports the selected
row's current position without retained state.

## Custom rendering

```odin
import ui "alicorn:ui"
list, opened := parts.list_begin(ctx, &app.results, ITEMS[:], visible,
	key=ui.key_string("results"), options=parts.Options{accessible_label="Commands"})
if !opened {
	_ = parts.empty(ctx, parts.Options{empty_label="No matches"})
} else {
	for index in list.first..<list.last {
		row, row_visible := parts.item_begin(ctx, &list, index)
		if !row_visible { continue }
		if parts.row_surface(ctx, row) != 0 {
			parts.icon(ctx, row)
			parts.label(ctx, row)
			parts.description(ctx, row)
			parts.indicator(ctx, row)
			ui.surface_end(ctx)
		}
		if parts.item_end(ctx, &list, row) {
			app.run_command(row.item.id)
		}
	}
	if event := parts.list_end(ctx, &list); event.kind == .Activated {
		app.run_command(event.item_id)
	}
}
```

`Row` exposes `item`, `index`, `count`, `selected`, `disabled`, `activated`,
`owner`, and `visible`. Any ordinary Alicorn layout is allowed between
`item_begin` and `item_end`. The parts own identity, navigation, focus,
semantics, and activation; omitting a visual part changes only the visual tree.

### Groups

`group_begin(ctx, &list, "Suggested", key=...)` draws a header and publishes a
semantic `Group`; rows in the group parent to it. Groups require the complete
visible slice to be realized because the virtual list uses a uniform row track
and group headers do not consume a collection position. Use them for short,
result-complete lists. Groups are single-level.

## Semantics

Each realized row is a `button_begin(presentation=.Custom)` owner with a
`List_Box_Option` semantic record. The scroll region owns the `List_Box`
collection with a logical count, realized range, and selected/current identity.
Rows expose `Selected`, `Current`, `Disabled`, and `Select`/`Focus` actions.
Visual parts attach `.Icon`, `.Label`, `.Content`, and `.Selected_Indicator`.
Groups publish a semantic `.Group` with the group label.

## Behavior

| Input | Result |
|---|---|
| `Up`/`Down` | `palette.move` with wrapping and disabled skipping |
| `Home`/`End` | first/last enabled visible row |
| `Return` | one activation event for the selected stable item |
| pointer | row activation through the ordinary Button owner |
| semantic `Select` | the same activation through `List_Box_Option` |
| caller reorder/removal | selection follows `Item_ID`; reconcile falls back to the first enabled row |

The part publishes only realized rows. `virtual_list_ensure_visible` is
requested after navigation; the list remains a single Tab stop with the rows
non-focusable.

## API reference

| Declaration | Notes |
| --- | --- |
| `Item`, `Item_ID`, `Match`, `Selection` | Aliases of the palette model's borrowed item and match types. |
| `Options` | Accessible/empty labels, row height, max list height, semantic namespace. |
| `State` | Selection by stable ID, list owner, reveal/focus requests. |
| `List` | Per-description list context: realized range, collection, group parent. |
| `Row` | Per-description row context. |
| `Group` | Per-description group context. |
| `results` | Convenience default result list. |
| `list_begin` / `list_end` | Open/close the virtual list and collection. |
| `item_begin` / `item_end` | Open/close one semantic row. |
| `row_surface`, `icon`, `label`, `description`, `indicator` | Optional default visuals. |
| `empty` | No-results label part. |
| `group_begin` / `group_end` | Single-level semantic group and header. |
| `handle_key`, `request_focus`, `selection_visible_index` | Application-driven navigation, focus, and derived position. |
| `item_semantic_id`, `list_semantic_id`, `group_semantic_id`, `row_key` | Stable identities and retained keys. |

## Limits

- It is a result-list part, not a modal palette. Add the application's own
  overlay/query shell, as the examples do.
- It does not implement type-ahead; the query field owns text input.
- `Page_Up`/`Page_Down` are not handled, matching the stock palette's current
  keyboard contract.
- Groups require all visible rows to be realized.
- Headless tests do not validate native IME or a platform accessibility bridge.
