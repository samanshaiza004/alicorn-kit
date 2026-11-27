# Selection styles pilot

Minimal, Hardware, and Paper apply one typed style value to Radio Group and
Segmented Control. Switch treatments in the running example. Select values
with the pointer or use Tab and the arrow keys. Each group includes a disabled
option and keeps its own selection.

Hardware adds an inset relief surface, heavier monospaced labels, and a dot.
Paper uses warmer sheet surfaces, larger type, and an underline. Minimal uses
shorter rows, flat surfaces, and a compact bar. The selected mark occupies
a reserved slot, so changing selection does not move the label.

The example translates style values into ordinary Alicorn layout, text and
surface parameters. The caller-owned `style_resolve` function composes named
typed procedures for metrics, surface, typography and indicator, then applies
an explicit `Toolbar` or `Dialog` context and an optional per-instance value.
`style_explain` reports the typed source for each resolved field. The example
uses no registry, selector, runtime style API, or per-frame string lookup.
It resolves the two styles at initialization and again only when the treatment
changes.

Radio uses its public group and item parts. Segmented uses the optional item
drawing procedure on its complete wrapper. Both keep their existing focus,
hit owners, semantic roles, controlled values, and shared selection policy.
Target bounds follow the treatment's logical dimensions.

From the AliKit root, use the AccessKit compiler arguments from the pinned
Alicorn setup described in [the build instructions](../../README.md):

```sh
odin build examples/selection_styles -collection:alikit=. -collection:alicorn=/path/to/pinned/alicorn <AccessKit compiler arguments>
```

Pass `--hardware` or `--paper` to start with that treatment. The example
also accepts `--smoke`. The headless test checks owner identity, focus,
semantic actions, selection, disabled behavior, paint, context/fragment
provenance, instance precedence, cached style resolution, and idle descriptions.
Run `--bench` for two measurements at 100, 1,000, and 3,000 styles/nodes: a
pure Odin style-resolution microbenchmark, and a retained TestUI workload using
fresh runtimes with initial-description timings, layout/shaping/paint visit
counts, and a settled zero-work check. The latter has no GPU and is not a native
frame-latency measurement; neither benchmark has a matched direct-style
baseline.

Part of [Alicorn #244](https://github.com/Carnival-Science/Alicorn/issues/244)
and [#246](https://github.com/Carnival-Science/Alicorn/issues/246).
