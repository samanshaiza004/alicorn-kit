# AliKit components

AliKit is a small, optional set of source-level Odin packages built on Alicorn.
It does not add another runtime, component lifecycle, or application state
store. This catalog describes the packages that exist today.

## Available packages

| Package | Use it for | Ownership |
| --- | --- | --- |
| `alikit:palette_model` | Filtering and navigating a caller-owned list without UI dependencies | The application owns items, stable IDs, ranking, and activation. The model borrows item text and stores selection by ID. |
| `alikit:command_palette` | An accessible modal palette with a controlled query, selection, keyboard navigation, virtualized results, public result parts, and focus restoration | The application owns command discovery and dispatch. AliKit owns palette interaction and presentation. |
| `alikit:tree_model` | UI-independent tree-row validation, keyboard navigation, stable focus/selection, and paged-window reconciliation | The application owns the hierarchy, visible projection, loaded data, and commands. |
| `alikit:tree_view` | Accessible virtualized tree rows, indentation, focus reveal, keyboard navigation, and optional row-anchored context menus | The application owns expansion/loading policy, mutation, activation, selection policy, and context-menu actions. |
| `alikit:palette_parts` | A copyable, parts-based result list: retained virtual rows, `List_Box` semantics, enabled-row navigation, reveal, groups, optional row visuals, and one activation event | The application owns the query, matching/ranking, commands, modal shell, dismissal, and focus restoration. |
| `alikit:icon_picker` | A complete copyable composite built from search/grid/choice parts: virtualized grid or list, roving focus, selection proposal, two appearances, and one application-authored focus interaction | The application owns choices, accepted selection, commands, and any surrounding dialog. |
| `alikit:radio_group` | Composable radio parts and a wrapper: `Radio_Group`/`Radio_Button` semantics, one Tab stop, roving arrows, disabled skipping, keyboard/pointer/semantic activation parity, and replaceable item rendering | The application owns the selected value and mutual exclusion. The component owns ephemeral focus and one proposed selection event. |
| `alikit:progress` | Composable determinate and indeterminate progress with `Progress` semantics, numeric range, linear or ring parts, and optional caller-driven pulse | The application owns the value/range and indeterminate phase. The component owns presentation and semantic range projection. |
| `alikit:segmented` | Single selection over equal-width segments with `Tab_List`/`Tab` semantics, one Tab stop, roving arrows, a moving indicator, and reduced-motion snapping | The application owns the selected view/mode and content. The component owns ephemeral focus, indicator motion, and one proposed value. |
| `alikit:selection` | Pure, allocation-free single-selection policy over a borrowed keyed item set | The application owns the item set and accepted selection. The helper owns focus repair, disabled skipping, at-most-one publication, and mode proposals. |
| `alikit:notices` | Runtime toast helpers plus copyable card/stack parts for inline banners and application-hosted snackbars, with reveal/retire motion | Alicorn owns the notice queue, deadlines, actions, and built-in toast overlay. The application owns card items and resolution policy. |
| `alikit:sidebar` | A flat navigation rail built from rail/item parts: expanded/collapsed presentations, `List_Box`/`List_Box_Option` semantics, roving focus, optional visuals, and one proposed route | The application owns accepted routes, content, router/history, badges, row rendering, and disabled policy. |
| `alikit:table` | A static, non-spanned presentation table with intrinsic wrapped row heights, inline detail/icon formatting, shared header/cell scaffolding, and optional fixed-row virtualization | The application owns columns, rows, stable keys, sorting, filtering, formatting, and data lifetime. The table owns no focus, selection, or activation. |
| `alikit:data_grid` | An interactive dataset grid with one Tab stop, roving cell focus, row/cell selection, sort-header proposals, and essential virtualization | The application owns columns, rows, comparators, filters, accepted selection, and dispatch. AliKit owns ephemeral focus and one proposal. |
| `alikit:dialog` | Composable Dialog / Alert_Dialog parts with Escape and backdrop policy, initial focus, focus restoration, Alert live semantics, and nested overlays | The application owns when to open, action meaning, content, and dispatch. AliKit owns dismissal/focus policy. |
| `alikit:menu` | An anchored component-level dropdown with Menu/Menu_Item semantics, checked/disabled/separator rows, roving navigation, Escape/outside dismissal, and reveal | The application owns items, command identity, checked state, and dispatch. The runtime context menu remains the native-integration path. |
| `alikit:scroll_area` | A focusable, bounded or intrinsic scroll container with keyboard/wheel scrolling, Scroll_View semantics, and bar-part geometry | The application owns content extents/lines and theme registration. Alicorn owns the retained scroll region and bars. |
| `alikit:table_core` | Shared presentation for Table and Data Grid: column/cell/row shapes, tracks, header parts, and cell semantic scaffolding | Components own their interaction layers; applications own data and policy. The shared package owns no focus, selection, or activation. |
| `alikit:theme_contract` | Bounded setup-time validation for namespaced component theme roles | Components own their role names and core fallbacks; applications register and validate a theme once. |

## Installation and copying

AliKit is source-level Odin. Choose the authoring path that matches how much of
the component you want to own:

1. **Import the complete component.** Add the AliKit checkout as a collection
   and import the package, for example
   `odin build . -collection:alicorn=<alicorn> -collection:alikit=<alicorn-kit>`.
   The native host also needs the pinned AccessKit SDK arguments described by
   `alicorn/.deps/odin-accesskit/tools/bootstrap.ps1`.
2. **Import and compose the parts.** Pass the same collections and call the
   package's `*_begin` / part / `*_end` procedures. The complete wrappers are
   built from those same parts.
3. **Import behaviors or copy source.** `alikit:selection` is a pure behavior
   package. A component whose source you copy becomes application code; copy its
   declared `source` files and, when it imports another AliKit package, the
   dependency files listed in `components.json` under `copy`. Rewrite those
   intra-AliKit imports to local relative packages so the copy needs only the
   Alicorn collection. A radio-group copy, for example, needs `selection/` and
   `theme_contract/` beside it; copying `radio_group.odin` alone does not
   compile.

`components.json` records the copy recipe for audited copyable components and
the exact package dependencies for every entry.
[`tools/validate_external_consumer.ps1`](../tools/validate_external_consumer.ps1)
generates a standalone project outside the repository, builds both the
collection-import path and the radio-group copy path, and runs native smokes.

The command-palette example is the canonical starting point for a small
Alicorn application using AliKit. It shows application-owned actions, optional
appearance settings, `ui.run` input routing, state initialization, and cleanup:
[`examples/command_palette`](../examples/command_palette/main.odin).
The tree example shows how an application builds a visible preorder projection
and handles expansion while AliKit owns reusable navigation and presentation:
[`examples/tree_view`](../examples/tree_view/main.odin).

## Choosing palette search behavior

Use the built-in substring mode when each whitespace-separated query term
should match contiguously in an item's title, description, or keywords. ASCII
letters compare without case; non-ASCII UTF-8 bytes compare exactly.

Use `Search_Mode.Caller_Filtered` when the application already has a matcher,
aliases, ranking, or recency policy. Build a fresh result slice for each
description and input turn, preserving stable, unique, nonzero `Item_ID` values.
The palette keeps selection by item ID rather than filtered row index.

See [the command-palette guide](command-palette.md) for the complete API,
ownership and lifetime rules, native callback wiring, presentation options,
and IME limitations.

See [the Tree View guide](tree-view.md) for stable row identity, full and paged
visible-row windows, keyboard behavior, context-menu targeting, and the
application-owned data contract.

See [the icon picker guide](icon-picker.md) for a complete copyable custom
composite with two appearances and named parts,
[the palette-parts guide](palette-parts.md) for the parts-based result-list
variant and its ownership boundary, [the radio group guide](radio-group.md)
for a small controlled compound control with explicit radio semantics and
composable item rendering, [the progress guide](progress.md) for determinate and
indeterminate progress with a published numeric range and linear/ring parts,
[the segmented guide](segmented.md) for the shared single-selection behavior's
second consumer and its moving indicator, [the notices guide](notices.md) for runtime
toast helpers and copyable inline card parts, [the sidebar guide](sidebar.md)
for the flat navigation rail and its collapsed presentation, and
[the table guide](table.md) for the static presentation table, [the data grid guide](data-grid.md) for the interactive dataset grid, [the dialog guide](dialog.md) for modal contracts, [the menu guide](menu.md) for anchored dropdowns, and [the scroll area guide](scroll-area.md) for bounded scrolling. The measured stock-vs-parts comparison,
contract coverage, and core-requirement list live in
[the issue 3 research record](research/issue-003-parts-pilot.md) and\n[the issue 5 shared-behavior record](research/issue-005-selection-and-shared-behaviors.md).

## Published catalog

The static catalog in [`website/`](../website/) renders every component page
with a native SDL_GPU capture, copyable source, ownership and input contracts,
theme roles, API reference, and test coverage. Rebuild it with
`cd website && npm ci && npm run build`. The machine-readable registry seed is
[`components.json`](../components.json), and
[`tools/capture_catalog.ps1`](../tools/capture_catalog.ps1) regenerates the
native captures from `out/`.

## Not in AliKit yet

Calendars, color pickers, split panes, terminals, and rich editors are not
available AliKit components. Tables and data grids are non-spanned; row/column spans, built-in sorting/filtering, submenus, and cell editing are P1 or application policy. A per-node scrollbar style override is not available at the pinned Alicorn revision. A tree-style sidebar with nested sections is a later Sidebar variant. Add a
component when a real application need demonstrates reusable behavior; keep
application-specific data and policy in the application, and keep independent
domain engines outside the UI runtime where practical.

Copyable source components are intentionally small enough to copy and change:
start from `icon_picker/icon_picker.odin` and its example, or from the
`palette_parts` result list. A copy is application code; it may edit drawing,
omit optional parts, and add bespoke interactions with ordinary state and
scoped input. Do not copy a second runtime, state store, or modal policy.

## Authoring conventions

AliKit components are ordinary Odin procedures. Keep persistent interaction
state in an explicit caller-owned `State` only when the component needs it;
add `init`/`destroy` only when it owns resources. Return `bool` for a simple
value change, a typed event when callers must distinguish several actions,
and an explicit status/result for fallible operations. Presentation-only
components return no value.

Components should use Alicorn's built-in semantic theme roles by default, so
first use needs no JSON compilation or theme registration. A component with
optional extension roles can expose its own recipe or appearance values.
Applications that install a custom theme validate component contracts once
during initialization; contract setup does not belong in each widget call.

For input, register the component's retained owner and handled keys/pointers
during `build`. Alicorn delivers those events to the next description, where
the component can read fresh application data. Prefer this scoped routing with
`ui.run`; use manual `Application` callbacks and `handle_key` helpers only
when an application needs a lower-level host loop. Preserve Alicorn's IME,
focus, modal, and event-ordering rules rather than keeping a second event loop
inside a component.
