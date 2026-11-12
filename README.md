# AliKit

AliKit is an optional set of reusable application components for Alicorn, the
native GUI runtime for Odin. It uses Alicorn's existing retained runtime,
controls, semantics, layout, and host input APIs. It does not introduce another
UI tree, state store, or application lifecycle.

The first component is an application-facing command palette. The application
owns command discovery, ranking, and dispatch; AliKit owns query filtering,
selection behavior, modal presentation, and keyboard navigation.

## Current status

AliKit is an early, source-level companion package. Its first component targets
Alicorn v0.2.1 APIs. The API may evolve with Alicorn; pin both projects when
consuming it. The palette currently supports ASCII case-insensitive substring
matching, caller-ordered results, stable numeric item IDs, disabled actions,
virtualized result rows, focus restoration, and native host key routing.

It does not promise Unicode case folding, fuzzy ranking, command registration,
application dispatch, or native OS command services. An application can
pre-rank its items before passing them to the component.

## Repository layout

- `palette_model/` — UI-independent filtering and selection behavior.
- `command_palette/` — Alicorn presentation and native input adapter.
- `examples/command_palette/` — small native consumer showing callback wiring.
- `docs/command-palette.md` — API, ownership, and integration guide.

See the guide before adopting the component in an application. A native Alicorn
consumer needs the same Odin, SDL, and AccessKit setup as other Alicorn desktop
applications.
