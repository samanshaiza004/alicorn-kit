# AliKit agent guidance

AliKit is an optional Odin companion library for Alicorn. Keep application
commands, domain state, ranking, and dispatch in the consuming application;
keep reusable interaction behavior in AliKit; use Alicorn's public UI and
runtime APIs. Do not add a second component lifecycle or access private runtime
storage.

## Before changing a component

- Check [the component catalog](docs/components.md) to confirm what exists and
  which layer owns each responsibility.
- Read the component's API guide. For the Command Palette, start with the
  minimal [`command_palette_quick_start`](examples/command_palette_quick_start/main.odin)
  `ui.run` consumer; use the full
  [`command_palette` reference app](examples/command_palette/main.odin) for its
  custom shell and workspace composition. Dialog and Data Grid also have
  dedicated Quick Starts beside their reference apps. Use lower-level host
  callbacks only when the application needs custom dispatch.
- For tree integrations, follow [`docs/tree-view.md`](docs/tree-view.md) and
  [`examples/tree_view`](examples/tree_view/main.odin); keep the visible-row
  projection, expansion/loading policy, and item actions in the application.
- For copyable composites, follow [`docs/icon-picker.md`](docs/icon-picker.md)
  and [`examples/icon_picker`](examples/icon_picker/main.odin). Copy the source,
  keep named parts, change drawing locally, and express bespoke behavior as
  ordinary application state plus scoped input. Do not add a component
  framework or a second focus/overlay policy.
- Preserve caller-owned state and stable item identities. Check the API guide
  for borrowed-value lifetimes before retaining data.
- Keep Alicorn and AccessKit at the exact revisions in
  [`dependencies.lock.json`](dependencies.lock.json); update pins deliberately.

## Validation

Run `./tools/test.ps1 -Odin odin` on Windows. It checks the models, retained
component behavior, canonical native examples, the parts-based palette, the
icon picker (including the `alicorn:testui` modal pattern check), the v0.3
radio/progress/notices/sidebar/table/data_grid/scroll_area/menu/dialog
suites, the sidebar's `.Roving_List` and the dialog's `.Modal_Dialog` patterns,
and a copied-source build against the pinned dependencies. Headless
tests do not validate operating-system IME candidate windows, physical
screen-reader sessions, or pixels; describe that limitation when relevant.
Run the matching `./out/<component>_example.exe --smoke` for native SDL_GPU
smoke coverage.

Run `./tools/validate_external_consumer.ps1 -Odin odin` to build that suite's
fixture from outside the repository: one consumer imports packages through the
`alikit` collection, and one consumes the declared source closures for all 14
catalog components with only the Alicorn collection. The harness audits
`components.json` dependencies, test/example paths, and copy recipes as part of
the run.

Update the catalog and component guide when public packages or ownership
contracts change. Record measured decisions and core requirements in
[`docs/research/issue-003-parts-pilot.md`](docs/research/issue-003-parts-pilot.md)
or a successor record.
