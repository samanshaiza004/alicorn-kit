# AliKit agent guidance

AliKit is an optional Odin companion library for Alicorn. Keep application
commands, domain state, ranking, and dispatch in the consuming application;
keep reusable interaction behavior in AliKit; use Alicorn's public UI and
runtime APIs. Do not add a second component lifecycle or access private runtime
storage.

## Before changing a component

- Check [the component catalog](docs/components.md) to confirm what exists and
  which layer owns each responsibility.
- Read the component's API guide and follow the complete native integration in
  [`examples/command_palette`](examples/command_palette/main.odin).
- Preserve caller-owned state and stable item identities. Check the API guide
  for borrowed-value lifetimes before retaining data.
- Keep Alicorn and AccessKit at the exact revisions in
  [`dependencies.lock.json`](dependencies.lock.json); update pins deliberately.

## Validation

Run `./tools/test.ps1 -Odin odin` on Windows. It checks the model, retained
component behavior, and canonical native example against the pinned
dependencies. Headless tests do not validate operating-system IME candidate
windows; describe that limitation when relevant.

Update the catalog and component guide when public packages or ownership
contracts change. Keep examples compiling and focused on real consumer code.
