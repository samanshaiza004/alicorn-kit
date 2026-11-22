# AliKit

AliKit is an optional set of reusable application components for Alicorn, the
native GUI runtime for Odin. It uses Alicorn's existing retained runtime,
controls, semantics, layout, and host input APIs. It does not introduce another
UI tree, state store, or application lifecycle.

AliKit provides a command palette, a generic Tree View, a copyable icon picker,
and the v0.3 P0 components: radio group, progress, notices, navigation rail, and
virtualized table. The application owns domain state, ranking, route selection,
and dispatch. AliKit owns reusable interaction behavior, semantics, and
copyable presentation parts.

## Current status

AliKit is an early, source-level companion package pinned to the Alicorn
revision in `dependencies.lock.json`. The API may evolve with Alicorn; pin both
projects when consuming it.

The v0.3 P0 sprint adds:

- a controlled radio group with `Radio_Group`/`Radio_Button` semantics;
- determinate and indeterminate progress with a published numeric range;
- notice helpers plus copyable card/stack parts for inline banners;
- a collapsed/expanded navigation rail with a proposed app-owned route;
- a virtualized, non-spanned table with nested table/row/cell semantics.

Every component follows Alicorn's five-point component-authoring standard:
copyable implementation, composable parts, recipe/style/theme contract,
keyboard and accessibility contract, and `testui` conformance tests. Each has a
native example and a docs page.

Built-in palette matching is ASCII case-insensitive substring search.
Caller-filtered mode preserves an application's own matching and ranking. Tree
View supports nested visible projections and bounded loaded windows. AliKit
does not promise Unicode case folding or fuzzy ranking itself, and it does not
provide command registration, application dispatch, router policy, or native OS
command services.

## Start here

- [Component catalog](docs/components.md) - current packages and when to use
  them.
- [Command Palette guide](docs/command-palette.md) - API, ownership, input,
  appearance, and native integration.
- [Tree View guide](docs/tree-view.md) - stable identities, visible-row
  projections, loaded windows, keyboard navigation, and context menus.
- [Icon Picker guide](docs/icon-picker.md) - a complete copyable custom
  composite with search, grid/list appearances, named parts, and tests.
- [Palette Parts guide](docs/palette-parts.md) - the parts-based result-list
  variant and its ownership boundary.
- [Radio Group guide](docs/radio-group.md) - controlled radios, roving arrows,
  and activation parity.
- [Progress guide](docs/progress.md) - determinate and indeterminate bars.
- [Notices guide](docs/notices.md) - runtime toasts and copyable inline cards.
- [Sidebar guide](docs/sidebar.md) - the navigation rail and collapsed
  presentation.
- [Table guide](docs/table.md) - virtualized nested table semantics, navigation,
  and the non-spanned v1 decision.
- [Issue 3 research record](docs/research/issue-003-parts-pilot.md) - inventory,
  measured stock-vs-parts comparison, contract coverage, and GO/NO-GO.
- [Issue 4 research record](docs/research/issue-004-v03-components.md) - pin
  choice, P0 component evidence, and core gaps.
- [Agent guidance](AGENTS.md) - project boundaries and validation steps.

## Repository layout

- `palette_model/` - UI-independent filtering and selection behavior.
- `command_palette/` - Alicorn presentation and native input adapter.
- `palette_parts/` - copyable parts-based palette result list.
- `tree_model/` - UI-independent tree navigation and window reconciliation.
- `tree_view/` - Alicorn tree presentation, semantics, and input adapter.
- `icon_picker/` - complete copyable custom composite with two appearances.
- `theme_contract/` - bounded setup-time validation for component theme roles.
- `radio_group/` - controlled radio group.
- `progress/` - determinate/indeterminate progress bar.
- `notices/` - runtime notice helpers and inline card parts.
- `sidebar/` - navigation rail.
- `table/` - virtualized table.
- `examples/` - native consumers for every component, including the parts-based palette.
- `docs/` - component guides and research records.
- `website/` - the Astro + Starlight component catalog with native captures.
- `components.json` - machine-readable component registry seed.

## Validation

The Windows CI workflow checks the UI-independent models, retained-runtime
interaction tests, the v0.3 component suites, every native example, the
parts-based palette, the copyable icon picker, and a copied-source build against
the exact Alicorn and AccessKit binding commits in `dependencies.lock.json`.
To run the same checks locally, place the pinned Alicorn checkout at `./alicorn`
and run:

```powershell
./tools/test.ps1 -Odin odin
```

The script also copies `icon_picker/` beside a small consumer and compiles it
with only the Alicorn collection, so copyable-source consumption does not depend
on AliKit's package topology.

## Component catalog

The static catalog lives in `website/`. It renders native example captures,
copyable source, ownership and input contracts, theme roles, API references,
and test coverage for every component. Build it locally with:

```powershell
cd website
npm ci
npm run build
```

Re-capture the native PNGs after a component or pin change:

```powershell
./tools/capture_catalog.ps1 -BinDir out -OutDir website/public/captures
```

`components.json` is the machine-readable registry seed. The catalog does not
recreate a component in JavaScript; interactive WebGPU previews are a later
step. See [the website README](website/README.md) for the site choice and the
GitHub Pages workflow note.
