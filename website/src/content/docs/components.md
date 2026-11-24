---
title: Component catalog
description: The AliKit packages available today, their ownership boundary, and when to use each one.
---

AliKit is a small, optional set of source-level Odin packages built on Alicorn. It does not add
another runtime, component lifecycle, or application state store. This catalog describes the
packages that exist today; every entry links to a page with the native preview, copyable source,
contract, tests, API, and limits.

## Available components

| Package | Use it for | Native preview |
| --- | --- | --- |
| [`alikit:command_palette`](command-palette/) | An accessible modal palette with a controlled query, selection, keyboard navigation, virtualized results, public result parts, and focus restoration. | [Command Palette](command-palette/) |
| [`alikit:tree_view`](tree-view/) | Accessible virtualized tree rows, indentation, focus reveal, keyboard navigation, and optional row-anchored context menus. | [Tree View](tree-view/) |
| [`alikit:icon_picker`](icon-picker/) | A complete copyable icon composite built from search/grid/choice parts: virtualized grid or list, roving focus, selection proposal, and two appearances. | [Icon Picker](icon-picker/) |
| [`alikit:palette_parts`](palette-parts/) | A copyable parts-based palette result list: virtual rows, `List_Box` semantics, enabled-row navigation, and one activation event. | [Palette Parts](palette-parts/) |
| [`alikit:radio_group`](radio-group/) | Controlled radio group parts: `Radio_Group`/`Radio_Button` semantics, one Tab stop, roving arrows, activation parity, and replaceable item rendering. | [Radio Group](radio-group/) |
| [`alikit:progress`](progress/) | Composable determinate/indeterminate progress with `Progress` semantics, numeric range, linear or ring presentations, and optional caller-driven pulse. | [Progress](progress/) |
| [`alikit:segmented`](segmented/) | Single selection over equal-width segments with `Tab_List`/`Tab` semantics, one Tab stop, roving arrows, and a moving indicator. | [Segmented Control](segmented/) |
| [`alikit:notices`](notices/) | Runtime toast helpers plus copyable card/stack parts for inline banners and application-hosted snackbars. | [Notices](notices/) |
| [`alikit:sidebar`](sidebar/) | A flat navigation rail built from rail/item parts with expanded/collapsed presentations, `List_Box` semantics, roving focus, custom rows, and one proposed route. | [Sidebar](sidebar/) |
| [`alikit:menu`](menu/) | An anchored dropdown built from trigger/popup/row/separator/group parts with custom row rendering and one chosen command. | [Menu](menu/) |
| [`alikit:table`](table/) | A static, non-spanned presentation table with shared column tracks, headers, cell scaffolding, intrinsic wrapped rows, and optional virtualization. | [Table](table/) |
| [`alikit:data_grid`](data-grid/) | An interactive dataset grid with one Tab stop, roving cell focus, selection publication, sort proposals, and essential virtualization. | [Data Grid](data-grid/) |
| [`alikit:table_core`](../manifest/) | Shared presentation for Table and Data Grid: column/cell/row shapes, tracks, headers, and cell semantics. | Support package |
| [`alikit:palette_model`](../manifest/) | Filtering and navigating a caller-owned list without UI dependencies. | Model package |
| [`alikit:tree_model`](../manifest/) | UI-independent tree-row validation, keyboard navigation, stable focus/selection, and paged-window reconciliation. | Model package |
| [`alikit:selection`](../manifest/) | Pure, allocation-free single-selection policy over a borrowed keyed item set. | Behavior package |
| [`alikit:theme_contract`](../manifest/) | Bounded setup-time validation for namespaced component theme roles. | Support package |

## Ownership at a glance

| Layer | Owns |
| --- | --- |
| **Application** | Domain state, commands, ranking, hierarchy, loading, mutation, routing, dispatch, and product policy. |
| **AliKit** | Reusable interaction behavior, semantics, copyable presentation parts, and setup-time theme contracts. |
| **Alicorn** | Layout, styling, motion, focus, input routing, semantics, virtual lists, rendering, and conformance primitives. |

The component pages state the exact split per component. When a behavior is application policy,
AliKit exposes the event or callback instead of owning a second policy engine.

## Installation and copying

AliKit is source-level Odin with three authoring paths:

1. **Complete component.** Import the package with the Alicorn and AliKit collections:
   `-collection:alicorn=<alicorn> -collection:alikit=<alicorn-kit>`. The native host also needs
   the pinned AccessKit SDK arguments from `alicorn/.deps/odin-accesskit/tools/bootstrap.ps1`.
2. **Parts.** Use the same collections and compose the package's `*_begin` / part / `*_end`
   procedures. The complete wrappers use the same parts.
3. **Behaviors or copied source.** `alikit:selection` is a pure behavior package. A copied
   component becomes application code: copy its declared `source` files plus any dependency files
   listed under `copy` in `components.json`, then rewrite the intra-AliKit imports to local
   relative packages. For example, a radio-group copy needs `selection/` and `theme_contract/`
   beside it and compiles with only `-collection:alicorn=<alicorn>`; copying
   `radio_group.odin` alone does not compile.

`tools/validate_external_consumer.ps1` generates a standalone consumer outside the repository,
builds the collection-import and copied-source paths, and runs native smokes. `components.json`
records the audited copy recipes and exact package dependencies.

## Choosing a result-list path

The command palette and Palette Parts intentionally overlap:

- Use `alikit:command_palette` when the application wants a complete modal palette with built-in
  substring filtering, query field, focus restoration, and a virtualized result list.
- Use `alikit:palette_parts` when the application already owns the query field, matching,
  ranking, modal shell, dismissal, and focus restoration, and only wants the reusable result
  list part. The modal palette now uses these same public result parts internally.
- Use `alikit:palette_model` alone when the application wants the filtering and selection rules
  without Alicorn presentation.

The parts pilot exists to keep the component boundaries honest, not to replace the stock
palette. See [Palette Parts](palette-parts/).

## Not in AliKit yet

Calendars, color pickers, split panes, terminals, and rich editors are not available. The P0
table is non-spanned; row/column spans, built-in sorting/filtering, and cell editing are P1 or
application policy. A tree-style sidebar with nested sections is a later Sidebar variant.

Copyable source components are intentionally small enough to copy and change. Start from
`icon_picker/icon_picker.odin` and its example, or from the `palette_parts` result list. A copy is
application code: it may edit drawing, omit optional parts, and add bespoke interactions with
ordinary state and scoped input. Do not copy a second runtime, state store, or modal policy.

## Authoring conventions

AliKit components are ordinary Odin procedures. Keep persistent interaction state in an explicit
caller-owned `State` only when the component needs it; add `init`/`destroy` only when it owns
resources. Return `bool` for a simple value change, a typed event when callers must distinguish
several actions, and an explicit status/result for fallible operations.

Components use Alicorn's built-in semantic theme roles by default. A component with optional
extension roles exposes a recipe; applications validate that contract once during initialization.
See [Alicorn's component-authoring standard](https://github.com/Carnival-Science/Alicorn/blob/master/docs/component-authoring.md)
for the five-point publication standard used by every page here.
