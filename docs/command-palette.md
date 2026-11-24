# Command Palette

`alikit:command_palette` provides a themed modal palette over a caller-owned
action list. `alikit:palette_model` contains the filtering and selection rules
without a UI dependency. `command_palette` re-exports `Item`, `Item_ID`, and
`Match`, so a consumer can compose its public input/result APIs without importing
model types. Import `palette_model` only when using its independent model helpers.
The result list is built from the same public parts as
`alikit:palette_parts`, so a complete palette and an application-owned shell
share one result contract.

The application owns commands, stable IDs, ranking policy, dispatch, and the
open shortcut. AliKit owns the query field, result-list interaction, selection
by stable ID, modal containment, and focus restoration.

## Preview

The default appearance is a centered modal with a title, controlled query, a
virtual result list, and a footer. The parts example keeps the application's
query shell and draws custom result rows with groups, descriptions, chips, and
checks. The composition example pairs the palette with a Segmented search
scope.

The result rows use public parts for their leading icon, title, description,
and selected check. The runnable `examples/command_palette` is the
authoring-reliability reference scene; `--reference` opens its filtered modal.
Its vector target is
[`docs/research/authoring-reliability/references/command-palette.svg`](research/authoring-reliability/references/command-palette.svg).
The docs link to the authored target and runnable source instead of embedding
desktop application screenshots.

## Installation

Copy these files into an application or import the package with the AliKit
collection:

- `command_palette/command_palette.odin`
- `command_palette/command_palette_test.odin` (modal/default behavior)
- `command_palette/command_palette_parts_test.odin` (public part behavior)
- `command_palette/visual_output_test.odin` (reference geometry, visible text, filtering, and focus)
- `command_palette/pilot_test.odin` (stock-vs-parts measurement)
- `examples/command_palette/main.odin` (workspace scene and reference shell; use `--reference` to open it)
- `examples/command_palette_parts/main.odin` (application-owned shell)
- `examples/command_palette_composition/main.odin` (palette + segmented scope)
- `docs/research/authoring-reliability/results/command-palette.md` (attempt log and verification limits)

`init` allocates the query and match buffer; `destroy` releases them:

```odin
palette: command_palette.State
if !command_palette.init(&palette) { return }
defer command_palette.destroy(&palette)
```

No other lifecycle is required.

## Composition

There are three supported authoring paths:

1. Import the complete component and call `build` from `render_overlays`.
2. Import `input`, `list_begin`, `item_begin`, `item_end`, `empty`,
   `group_begin`, and `list_end` to own the modal/shell while using the same
   result contract.
3. Use `alikit:palette_parts` directly for an inline result list, or copy its
   row drawing and change it locally.

| Layer | Responsibility |
| --- | --- |
| Alicorn | Modal overlay, focus scope, input routing, text field, virtual list, semantics, layout, and rendering. |
| `command_palette` | Controlled query, match buffer, stable-ID selection, keyboard/pointer routing, result-list parts, panel appearance, and focus restoration. |
| Application | Items and stable `Item_ID` values, matching/ranking in caller-filtered mode, open shortcut, grouping policy, and activation dispatch. |

The component's `build` shell draws:

```text
modal overlay
  panel
    title (optional)
    query row        -> input part
    result list      -> list_begin / item_begin / item_end / list_end
    empty or error   -> empty part / allocation message
    footer
```

## Minimal example

```odin
import ui "alicorn:ui"
import palette "alikit:command_palette"

SAMPLE_ITEMS :: [2]palette.Item{
	{id=palette.Item_ID(1), title="Open File", description="Browse the workspace"},
	{id=palette.Item_ID(2), title="Build Project", keywords="compile"},
}

App :: struct {
	palette_state: palette.State,
	items:   [2]palette.Item,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	_ = ui.text(ctx, "AliKit · Command Palette", size=24)
}

render_overlays :: proc(app: ^App, ctx: ^ui.UI) {
	if !app.palette_state.open { return }
	event := palette.build(ctx, &app.palette_state, app.items[:],
		ui.key_string("app-palette"),
		palette.Options{title="Example Actions"})
	if event.kind == .Activated {
		// Dispatch the stable ID in application code.
	}
}

on_key :: proc(app: ^App, rt: ^ui.Runtime, key: ui.Application_Key) -> bool {
	if !app.palette_state.open && key == .Open_Command_Palette {
		return palette.open_palette(&app.palette_state, rt)
	}
	return false
}

main :: proc() {
	app := App{items=SAMPLE_ITEMS}
	if !palette.init(&app.palette_state) { return }
	defer palette.destroy(&app.palette_state)
	ui.run(&app, render,
		title="AliKit Command Palette",
		width=760,
		height=520,
		on_key=on_key,
		render_overlays=render_overlays,
	)
}
```

`open_palette` clears the query, captures the current focus, and requests a
redraw. If the reset fails, the palette stays closed and `state.last_status`
reports the reason. If the match buffer cannot grow, the old buffer remains
valid and the modal shows `Options.allocation_error_message`.

## Custom rendering examples

An application can own the shell and still use the palette's public parts:

```odin
import ui "alicorn:ui"
import model "alikit:palette_model"
import palette "alikit:command_palette"
import parts "alikit:palette_parts"

_, _ = palette.input(ctx, &app.palette_state, palette.Options{hide_title=true},
	key=ui.key_string("app-query"))

count, _ := model.filter(ITEMS[:], palette.query_text(&app.palette_state), app.matches[:])
list, opened := palette.list_begin(ctx, &app.palette_state, ITEMS[:], app.matches[:count],
	key=ui.key_string("app-results"), options=palette.Options{hide_title=true})
if !opened {
	_ = palette.empty(ctx, palette.Options{hide_title=true})
} else {
	for index in list.first..<list.last {
		row, row_visible := palette.item_begin(ctx, &list, index)
		if !row_visible { continue }
		if surface := parts.row_surface(ctx, row); surface != 0 {
			// Ordinary Alicorn layout; use row.item, row.selected, row.disabled.
			_ = ui.text(ctx, row.item.title, key=ui.key_u64(1))
			ui.surface_end(ctx)
		}
		if palette.item_end(ctx, &app.palette_state, &list, row) {
			app.dispatch(row.item.id)
		}
	}
	if event := palette.list_end(ctx, &app.palette_state, &list); event.kind == .Activated {
		app.dispatch(event.item_id)
	}
}
```

The public result types are `Result_List`, `Result_Row`, and `Result_Group`;
their visual helpers come from `alikit:palette_parts` (`row_surface`, `icon`,
`label`, `description`, `indicator`) so there is one row contract. `row_key(id)`
returns the retained Button key when an application needs to target a row.
`row_surface` grows to the realized Button row's available width; a regression
test checks that the default option title remains visibly drawable.

The stock `build` path owns its modal and row drawing. For a custom modal and
per-result artwork, the reference example composes `input`, `list_begin`,
`item_begin`, `item_end`, and `list_end`, then draws the row surface and content
with public UI APIs. Its custom overlay calls
`alicorn.modal_overlay_begin/end` and `alicorn.semantic_describe_as`, so it
imports `alicorn:runtime`; `alicorn:ui` does not currently expose those modal
or semantic operations. A basic consumer of `build` still needs only
`alicorn:ui` and `alikit:command_palette`.

`Item` has no icon or shortcut fields, and `build` has no custom-row callback.
The reference application maps stable item IDs to icon IDs and shortcut labels
while owning result-row drawing. This remains application presentation data,
not part of the palette command model.

### Groups

`group_begin(ctx, &list, "Suggested", key=...)` draws a section header and
publishes a semantic `Group`; rows between `group_begin` and `group_end` parent
to that group. Groups require the complete visible slice to be realized because
the virtual list uses a uniform row track and group headers do not consume a
collection position. Use groups for short/result-complete lists; keep a flat
long list otherwise. This is single-level grouping, matching Alicorn's Select
group model.

## Application-owned items

Each item has a nonzero, unique `Item_ID` that remains stable for the palette
session. The ID is a scalar, so activation does not return a borrowed string or
an index into a temporary filtered list. `title`, `description`, and `keywords`
are borrowed only during `build` or `handle_key`; the application can rebuild
its item slice between turns.

The default `Search_Mode.Substring` filters in caller order and does not impose
rank policy. Every whitespace-separated query token must occur as a contiguous
substring in a title, description, or keyword. ASCII letters compare without
case; non-ASCII UTF-8 bytes compare exactly.

To preserve an application's existing fuzzy search or ranking, open the palette
with `Search_Mode.Caller_Filtered`. In that mode AliKit treats the supplied item
slice as the already-filtered result set and preserves its order. Use
`query_text` to build that set and pass a fresh slice to both `build` and
`handle_key`.

Disabled items remain visible but cannot be selected or activated. Selection is
retained by item ID while that item remains visible and enabled. If it vanishes,
becomes disabled, or stops matching, selection moves to the first enabled
result.

## Lifecycle and input

When used with `ui.run`, pass `render_overlays` and call `build` from that hook,
after the ordinary root has closed. `modal_overlay_begin` requires an empty
container stack, so a palette built inside the application's root does not
render. The palette registers its modal input scope during `build`; Alicorn
routes navigation, dismissal, outside clicks, and query text changes
automatically.

The current item slice is supplied to `build` on each description, so queued
input is applied against fresh application data. Applications using a lower
level host loop can use `handle_key`, `text_change`, `pointer`, and `after_frame`
directly. The text-change callback borrows `change.text` only for the callback;
AliKit copies it into its owned controlled-text buffer.

While Alicorn's public query-field snapshot reports active composition, the
palette declines Up, Down, and Return so the native text host handles them.
Alicorn routes Escape through native composition handling before dismissal.
When composition is inactive, the palette consumes Up/Down/Return/Escape and
its toggle key while open; unrelated keys continue through application policy.

## Styling, motion, and theme

The default appearance uses Alicorn's `Surface` role and a neutral modal
backdrop. Applications may enable `Options.appearance`:

| `Appearance` field | Effect |
| --- | --- |
| `overlay_padding`, `panel_padding`, `panel_gap` | Space around and inside the modal. |
| `backdrop_color`, `backdrop_effect` | Modal backdrop treatment. |
| `panel_shape`, `panel_material`, `physical_height`, `panel_fill` | Panel surface. |

`Options.hide_title`, `query_prefix`, `query_height`, and `query_text_style`
match an existing palette header. `results_accessible_name` names the result
`List_Box`. The component registers no theme resources and owns no component
motion; Alicorn's modal overlay and control recipes own focus/hover
presentation.

## API reference

| Declaration | Notes |
| --- | --- |
| `State` | Controlled query buffer, match buffer, selection, result-part state, focus/restoration flags, and `last_status`. |
| `Options` | Title, query/result accessible names, messages, prefix, footer, hide-title, panel/list/row/query geometry, query text style, and `Appearance`. |
| `Appearance` | Optional surface overrides; `enabled=false` keeps Alicorn defaults. |
| `Event` / `Event_Kind` | One-shot `Activated` event carrying `item_id`. |
| `Search_Mode` | `Substring` (built-in) or `Caller_Filtered` (application supplies the ranked slice). |
| `Status` | `Ready`, `Query_Reset_Failed`, `Query_Update_Failed`, `Match_Buffer_Allocation_Failed`. |
| `init` / `destroy` | Allocate and release the query and match buffer. |
| `open_palette` / `close_palette` | Controlled open/close with focus capture and restoration. |
| `build` | Describe the complete modal; call from `render_overlays`. |
| `input` | Public controlled query field part. |
| `list_begin`, `item_begin`, `item_end`, `list_end` | Public result-list parts over stable IDs. |
| `empty`, `group_begin`, `group_end` | Public no-results and group parts. |
| `Result_List`, `Result_Row`, `Result_Group` | Aliases of the result-part contexts. |
| `result_row_key`, `row_key` | Retained row Button keys. |
| `handle_key`, `text_change`, `pointer`, `after_frame` | Lower-level host path when not using `ui.run` scoping. |
| `set_query`, `query_text` | Controlled query value for caller-filtered ranking. |

## Keyboard and accessibility contract

| Input | Result |
| --- | --- |
| `Ctrl+Shift+P` | The canonical host shortcut maps to `.Open_Command_Palette`; the application decides whether to open. |
| `Up` / `Down` | Move selection through enabled, matching results. |
| `Home` / `End` | Move to the first/last enabled result. |
| `Return` | Emit one activation event with the selected stable `Item_ID`. |
| `Escape` | Close the palette; native composition handling runs first. |
| pointer | Row activation through the ordinary Button owner; outside click dismisses through the modal scope. |

- The result list publishes `List_Box` with its accessible name, logical count,
  realized range, and selected/current identity. Rows publish
  `List_Box_Option`, label, description, `Selected`/`Current`/`Disabled`, and
  `Select`/`Focus` when enabled.
- The modal retains Alicorn's focus scope, hit testing, and accessibility
  behavior. On close, focus returns to the captured opener.
- Not claimed: Unicode case folding, fuzzy ranking, command registration,
  application dispatch, or a native OS command service.

## Conformance tests

`command_palette/command_palette_test.odin` covers the modal path: substring and
caller-filtered behavior, disabled skipping, selection reconciliation,
open/close, query reset failures, match-buffer allocation failures, pointer and
keyboard activation, focus restoration, modal containment, Escape dismissal,
the `.Modal_Dialog` pattern check, IME composition yield, and idle return.

`command_palette/command_palette_parts_test.odin` composes `input`, the result
parts, and `group_begin` directly and verifies the `List_Box` logical count,
semantic `Group`, custom row activation, selected state, and visible default
row text.

`command_palette/visual_output_test.odin` exercises the reference shell at
1280 × 800, 960 × 720, and 760 × 640. It checks modal bounds, query and row
containment, shaped query/title/description/shortcut text, filtering, selected
semantics, activation, and focus restoration. This verifies retained geometry
and drawable text products, not GPU pixels or fractional-DPI rendering.

`command_palette/pilot_test.odin` runs the same scripted path through the stock
modal and `palette_parts.results` and asserts the same activated stable ID.

```powershell
odin test command_palette -define:ODIN_TEST_THREADS=1 -collection:alicorn=<alicorn> -collection:alikit=.
./out/command_palette_example.exe --smoke
./out/command_palette_parts_example.exe --smoke
./out/command_palette_composition_example.exe --smoke
```

Headless coverage does not validate the OS IME candidate window, a physical
screen-reader session, or pixels. Native smoke runs SDL_GPU D3D12 startup and
one submitted frame.

## Limits

- Built-in matching is ASCII case-insensitive substring search. Non-ASCII UTF-8
  bytes compare exactly; Unicode case folding and fuzzy ranking remain
  application policy.
- The palette does not register commands, choose ranking, or perform dispatch.
- Result groups require the complete visible slice to be realized.
- The lower-level path requires the application to describe the root first,
  then `build`, then `after_frame` after `alicorn.end_frame`.
- Headless tests do not prove native IME navigation or a platform accessibility
  bridge.

## Source map

- [Package](../command_palette/command_palette.odin)
- [Modal tests](../command_palette/command_palette_test.odin)
- [Part tests](../command_palette/command_palette_parts_test.odin)
- [Reference output test](../command_palette/visual_output_test.odin)
- [Pilot measurement](../command_palette/pilot_test.odin)
- [Default example](../examples/command_palette/main.odin)
- [Parts example](../examples/command_palette_parts/main.odin)
- [Composition example](../examples/command_palette_composition/main.odin)
- [Palette model](../palette_model/model.odin)
- [Palette parts](../palette_parts/parts.odin)
- [Authoring-reliability result](research/authoring-reliability/results/command-palette.md)
