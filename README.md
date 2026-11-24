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

- composable radio parts and a wrapper with `Radio_Group`/`Radio_Button`
  semantics;
- composable linear or ring progress with a published numeric range;
- a segmented control and the shared pure single-selection behavior;
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
- [Radio Group guide](docs/radio-group.md) - composable radio parts, roving
  arrows, activation parity, and custom item rendering.
- [Progress guide](docs/progress.md) - composable determinate and indeterminate
  linear or ring presentations.
- [Segmented guide](docs/segmented.md) - the shared single-selection behavior
  and its moving indicator.
- [Notices guide](docs/notices.md) - runtime toasts and copyable inline cards.
- [Sidebar guide](docs/sidebar.md) - the navigation rail and collapsed
  presentation.
- [Table guide](docs/table.md) - virtualized nested table semantics, navigation,
  and the non-spanned v1 decision.
- [Issue 3 research record](docs/research/issue-003-parts-pilot.md) - inventory,
  measured stock-vs-parts comparison, contract coverage, and GO/NO-GO.
- [Issue 4 research record](docs/research/issue-004-v03-components.md) - pin
  choice, P0 component evidence, and core gaps.
- [Issue 5 research record](docs/research/issue-005-selection-and-shared-behaviors.md)
  - shared selection behavior, two consumers, and deferred extraction candidates.
- [Issue 6 phase 6 record](docs/research/issue-006-phase-6-external-consumers.md) -
  external-consumer fixture, package imports, copy audit, and friction.
- [Agent guidance](AGENTS.md) - project boundaries and validation steps.

## Repository layout

- `palette_model/` - UI-independent filtering and selection behavior.
- `command_palette/` - Alicorn presentation and native input adapter.
- `palette_parts/` - copyable parts-based palette result list.
- `tree_model/` - UI-independent tree navigation and window reconciliation.
- `tree_view/` - Alicorn tree presentation, semantics, and input adapter.
- `icon_picker/` - complete copyable custom composite with two appearances.
- `theme_contract/` - bounded setup-time validation for component theme roles.
- `selection/` - pure single-selection behavior over a borrowed keyed item set.
- `radio_group/` - composable controlled radio group parts and wrapper.
- `progress/` - composable determinate/indeterminate progress parts.
- `segmented/` - single-selection segmented control with a moving indicator.
- `notices/` - runtime notice helpers and inline card parts.
- `sidebar/` - navigation rail.
- `table/` - virtualized table.
- `examples/` - runnable consumers for every component, including the parts-based palette.
- `tests/` - the external-consumer fixture templates used by `tools/validate_external_consumer.ps1`.
- `docs/` - component guides and research records.
- `website/` - the Astro + Starlight component catalog with runnable examples.
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

The phase-6 external-consumer check generates a standalone project outside the
repository, builds one application that imports packages through the `alikit`
collection and one that uses a copied radio group plus its declared source
dependencies, then runs both native smokes:

```powershell
./tools/validate_external_consumer.ps1 -Odin odin
```

The harness also audits `components.json` source dependencies, test/example
paths, and copy recipes before building.

## Component catalog

The static catalog lives in `website/`. It renders runnable example links,
copyable source, ownership and input contracts, theme roles, API references,
and test coverage for every component. Desktop application screenshots are
not included in the documentation. Build it locally with:

```powershell
cd website
npm ci
npm run build
```

`components.json` is the machine-readable registry seed. The catalog does not
recreate a component in JavaScript. See [the website README](website/README.md)
for the site choice and the GitHub Pages workflow note.
