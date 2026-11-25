# AliKit authoring-quality charter

AliKit should make common interfaces dependable to build while preserving the
freedom to create uncommon interfaces. Apply these guarantees when changing
component APIs, examples, documentation, and validation.

## Guarantees

- **Expressivity:** Convenience components and recipes do not hide or remove
  public Alicorn primitives. A caller can still replace a presentation or
  compose the lower-level parts when the default anatomy does not fit.
- **Optionality:** The shortest complete example stays available beside
  composition examples and full reference applications. Simple consumers do
  not need the setup code required by advanced consumers.
- **Ownership:** Applications own domain data, commands, sorting, filtering,
  and accepted state changes. Components own reusable interaction behavior and
  propose events through stable identities.
- **Correctness:** Verify behavior, geometry, semantics, and visible output as
  separate contracts. A successful build or a correct application value does
  not prove that the intended content is drawable.
- **Layout and scale:** Exercise documented viewport sizes and scale factors.
  TestUI geometry checks are logical-pixel evidence; native captures are
  required before claiming actual GPU pixels or physical-DPI quality.
- **Identity and locality:** Resizing or restyling a logically unchanged node
  preserves its retained identity. A local visual change should invalidate
  only the stages its inputs require, and settled unchanged UI should return to
  idle.
- **Compatibility:** High-level APIs expose the types needed to use them.
  Supported collection imports, source-copy recipes, and platform claims must
  have corresponding build or runtime evidence and migration notes when they
  change.
- **Performance evidence:** Compare identical scripted behavior, data,
  viewport, compiler, dependency revisions, and host conditions. Publish raw
  samples and limitations. Treat framework-specific work counters as
  diagnostic explanations, not interchangeable performance units.
- **Simplicity:** Add an abstraction only when it removes demonstrated
  consumer work without introducing a second lifecycle, state owner, or
  interaction policy. Keep the author's visual intent visible in ordinary
  Odin code.

## Change review checklist

For a component change, record the applicable checks:

1. Public imports and state ownership remain understandable from a minimal
   consumer example.
2. Keyboard, pointer, focus, disabled, semantic, and dismissal behavior remain
   correct for the component's contract.
3. Geometry, text visibility, clipping, and overflow are asserted in TestUI
   where those properties are observable.
4. Responsive viewport and scale-factor checks pass; native pixel claims are
   marked unverified until a real capture is reviewed.
5. Stable IDs, stage-work counters, and idle behavior are checked when the
   change affects retained identity, layout, shaping, paint, or motion.
6. External-consumer builds and source-copy validation are updated when the
   public package or copy recipe changes.
7. Performance comparisons use equivalent workloads and keep authoring
   attempts, correctness failures, and runtime cost as separate measurements.

An unchecked item is a disclosed validation gap, not an assumed pass. Keep
reference applications separate from quick starts so a polished demonstration
does not become the only path shown to new users.
