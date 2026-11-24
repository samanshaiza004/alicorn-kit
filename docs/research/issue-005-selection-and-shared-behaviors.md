# Issue 5: shared single-selection behavior and the next extraction candidates

Date: 2026-11-22
Branch: `codex/v03-parts-composability`
Pinned Alicorn: `47c9d4a7cd1f637876190fec899daeeac00a30ae` (v0.3 core-semantics
master; roving model, semantic roles, interaction scopes, numeric ranges)
AccessKit binding: `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`

## Verdict

- **GO: one shared single-selection model.** `alikit:selection` is a pure,
  allocation-free behavior package with two proven consumers: the refactored
  Radio Group and the new Segmented Control.
- **NO-GO: a behavior framework.** The model is a small set of ordinary Odin
  procedures over a borrowed `View`. There is no registration, interface,
  inheritance, retained tree, or second lifecycle.
- **NO-GO for the other founder-table behaviors in this sprint.** Grid
  navigation, type-ahead, search matching, range normalization, and
  labels/validation do not yet have the two-consumer evidence needed to
  generalize. Consumers and gaps are recorded below.
- **NO-GO: range normalization riding along.** Progress owns numeric range
  clamping; radio and segmented own keyed selection. They do not share a range
  contract, so a shared normalization helper would be a false abstraction.

## Why selection is shared

Radio and Segmented need the same policy:

1. stable-key lookup over a caller-owned keyed item set;
2. disabled and zero-key skipping;
3. focus repair after membership/disabled/selection changes;
4. a single selected-key publication (at-most-one);
5. `Follow_Focus` versus `Activate` proposals;
6. no application selection stored in the helper.

Both components still own their own ephemeral `State`. The package stores
nothing globally and never reads runtime internals.

## Responsibility split with Alicorn roving

| Concern | Owner | Contract |
| --- | --- | --- |
| Which index a navigation key proposes for **focus** | Alicorn `roving_propose` | Caller-owned index; wrap/disabled policy; no retained state. |
| Whether the focused key is **selected** | `alikit:selection` | Focused key proposal under `Follow_Focus`; explicit activation proposal under `Activate`. |
| Focus repair after set changes | `alikit:selection` | Active key, then selected key, then nearest enabled, then first enabled. |
| At-most-one selected-key publication | `alikit:selection` | `published_key` returns one key or zero. |
| Widget state and proposal delivery | Component | Component `State`, one `Selection_Proposed` event. |

Alicorn has no selection model at the pinned revision: the roving model is
strictly focus navigation. That is why the split is explicit rather than a
duplicate implementation.

## Public model surface

`selection.View` borrows `count`, `data`, `key_at`, and `enabled_at`.
`selection.State` stores `active_key` and `active_index`.

| Procedure | Use |
| --- | --- |
| `key_at`, `enabled_at`, `selectable` | Read the borrowed set. |
| `index_of_key`, `contains_key`, `first_enabled`, `last_enabled` | Key/index lookup. |
| `nearest_enabled`, `move`, `move_wrapped` | Disabled-skipping and wrap math. |
| `set_active`, `clear_active`, `active_is_valid` | Caller-owned active identity. |
| `reconcile_active` | Focus repair after set/selection changes. |
| `selected_index`, `published_key` | Selection validation and at-most-one publication. |
| `propose_focus`, `propose_activation` | Mode-aware selection proposals. |

## Consumer evidence

### Radio Group (refactor)

Radio's selection proposal moved from private option loops to
`alikit:selection`. The component still uses Alicorn roving for focus movement.
Existing default tests and the parts tests pass unchanged in behavior; the
wrapper remains the same call shape. The docs record the split.

### Segmented Control (new)

`alikit:segmented` is a complete equal-width single-selection control. It uses
the same model for reconcile and proposal rules, publishes `Tab_List`/`Tab`
semantics, and adds the moving indicator on top. It is the second, dissimilar
consumer: radio publishes `Radio_Group`, segmented publishes `Tab_List`, and
segmented adds paint-only indicator motion.

Tests: `selection/selection_test.odin` (5), radio suite (8 including parts),
segmented suite (5). Both native examples pass `--smoke`.

## Candidate table after this sprint

| Candidate | Current consumers | Evidence | Decision |
| --- | --- | --- | --- |
| Single selection | Radio Group, Segmented | Two dissimilar consumers, same keyed policy; both green. | **GO: shipped** as `alikit:selection`. |
| Grid navigation | Data Grid, Table, Icon Picker, Tree View | Consumers differ in 1D/2D stride, row bounds, tree expansion, virtual windows, and page/clamp policy. Alicorn roving already owns the pure focus proposal. | **NO-GO now.** A generic helper would need a navigation-shape parameter that each source already expresses locally. Revisit with a third userland grid consumer or a documented row-bounds/page-clamp gap in the roving model. |
| Type-ahead | Menu, Sidebar (future), Select-like popups, Command Palette | No current component implements prefix type-ahead over its own items. The stock Alicorn Select owns its internal type-ahead; AliKit has no public consumer. | **NO-GO now.** Needs two AliKit consumers and a defined text-ownership/preemption contract. |
| Search matching | Command Palette, Icon Picker, Palette Parts | Three consumers, but policies differ: ASCII substring, caller-filtered ranking, and application aliases/recency. | **NO-GO.** A shared matcher would either force one ranking policy or become a callback shell. Keep matching caller-owned; the existing `palette_model` is the narrow shared model where it already fits. |
| Range normalization | Progress; Data Grid numeric columns (display only); no radio/segmented overlap | One real consumer of clamped numeric-range semantics. Progress already exposes `fraction`; the other components do not share the input shape. | **NO-GO.** `progress.fraction` is the documented helper. Revisit when a Slider/Range component and a numeric formatter need the same contract. |
| Labels and validation | Form-like compositions (dialog forms, settings cards), no dedicated field component | Labels live in ordinary `ui.text`; validation policy and messages are application/domain state. No shared API is demonstrated by two components. | **NO-GO now.** A form/field component would need its own concrete pilot before extracting label/validation behavior. |
| Popup/dismissal | Dialog, Menu, Command Palette, Icon Picker | Different overlay ownership and focus restoration policies; Dialog/Menu already own their contracts, and the palette deliberately composes the public modal layer. | **NO-GO.** Revisit only if a second component needs the same non-component popup lifecycle. |
| Focus restoration | Dialog, Menu, Command Palette, Icon Picker | Repeated public pattern, but each consumer restores a different opener/target and must wait for its own overlay retirement. | **NO-GO now.** The mechanism is Alicorn's after-frame focus; AliKit would add policy, not behavior. |

The governing rule remains the two-consumer test: extract only a contract that
two dissimilar consumers need in the same shape. Single selection met it. The
remaining candidates did not in this sprint.

## Validation

```powershell
./tools/test.ps1 -Odin C:\odin\odin.exe
./out/radio_group_example.exe --smoke
./out/radio_group_parts_example.exe --smoke
./out/radio_group_composition_example.exe --smoke
./out/progress_example.exe --smoke
./out/progress_parts_example.exe --smoke
./out/progress_composition_example.exe --smoke
./out/segmented_example.exe --smoke
```

Headless tests do not prove physical screen-reader speech, OS high-contrast
rendering, IME candidate windows, or pixels. Native smoke covers SDL_GPU D3D12
startup and one submitted frame. Motion assertions are diagnostic targets plus
reduced-motion snap observation, not sampled animation curves.
