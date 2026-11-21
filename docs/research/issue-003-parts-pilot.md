# Issue 3: composable parts and copyable custom components

Date: 2026-11-21
Branch: `codex/issue-3-parts-pilot`
Pinned Alicorn: `a19d2c89138bcf1f19b00ed6ece58b70ede0508a` (master, includes the
#218 composable select pilot and the #217 testui pattern checks)
AccessKit binding: `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`

## Verdict

- **GO: copyable source components.** A complete userland icon picker with two
  appearances, search, virtualized roving grid/list navigation, semantic
  collection, and one application-authored interaction builds and tests with
  only public Alicorn APIs. It copies outside AliKit's collection topology.
- **GO: parts-based palette results.** A `List_Box`-publishing virtual result
  list composed from public parts is viable and keeps caller-owned filtering,
  ranking, and commands. Measured, not assumed; see the comparison below.
- **NO-GO: a new generic behavior framework.** Component-specific coordination
  remains in AliKit. No second selection/focus/overlay system was added.
- **NO-GO for further migration now.** Do not rewrite `command_palette` or
  `tree_view`. Both stay public and unchanged; the parts packages demonstrate a
  migration path without behavioral risk.
- **Core pilot: two small gaps** (generic text owner key preemption and roving
  semantic focus) are proposed to Alicorn with two concrete consumers. Nothing
  was patched in Alicorn.

## Pin and build recipe

`tools/test.ps1` resolves the pinned checkout at `./alicorn`, verifies its
`HEAD` against `dependencies.lock.json`, verifies the AccessKit binding pin, and
builds every package with:

```powershell
-collection:alicorn=./alicorn
-collection:alikit=.
-collection:accesskit=./alicorn/.deps/odin-accesskit
```

plus the AccessKit C SDK collection and linker flags returned by
`alicorn/.deps/odin-accesskit/tools/bootstrap.ps1`. The local recipe uses a
directory junction or checkout at `./alicorn`; `dependencies.lock.json` now
pins `700f2c5...` (`codex/issue-226-key-preemption`) so the icon picker can
adopt Alicorn's scope-owned `text_preempt_keys` policy. Baseline before changes:
`palette_model` 4, `tree_model` 8, `command_palette` 6, `tree_view` 6 tests, both
native examples building. The same suite is green after the changes, and now
also runs `palette_parts` (8 tests), `icon_picker` (11 tests), the native icon
picker example, and a copied-source build.

The CI workflow pin matches the same revision.

## Inventory (verified in-repo)

| Package | File | LOC | Public procs | Private procs | Tests |
|---|---|---:|---:|---:|---:|
| `palette_model` | `palette_model/model.odin` | 176 | 8 | 4 | 4 |
| `command_palette` | `command_palette/command_palette.odin` | 517 | 11 | 5 | 6 |
| `tree_model` | `tree_model/model.odin` | 313 | 6 | 6 | 8 |
| `tree_view` | `tree_view/tree_view.odin` | 400 | 8 | 8 | 6 |
| `palette_parts` (new) | `palette_parts/parts.odin` | 402 | 7 | 7 | 8 |
| `icon_picker` (new) | `icon_picker/icon_picker.odin` | 840 | 12 | 22 | 10 |

### Machinery map

| Concern | `command_palette` | `tree_view` | Runtime/public precedent |
|---|---|---|---|
| Navigation | `palette_model.move` over a visible `Match` slice; wrapping, disabled skip | `tree_model.handle_key`; up/down/home/end/page, left/right expansion, pending ranges | Stock Select owns its own index policy |
| Selection | `palette_model.reconcile/activate`; stable `Item_ID` | `tree_model.State.focused_id/selected_id`, reconcile by revision | Tree/List selection is application-visible semantics |
| Typeahead/matching | ASCII token substring `filter`; caller-filtered mode bypasses it | none | Stock Select owns prefix typeahead |
| Popup open/close | `modal_overlay_begin` + overlay interaction scope; outside pointer check | none (inline) | Modal overlay is the public transient layer |
| Focus recovery | after-frame query focus, previous-focus restore, waits for retiring overlay | `semantic_focus_set` + virtual reveal + scroll owner focus | after-frame + public focus |
| Semantic parts | plain Buttons in `virtual_list`; no collection | `.Tree` description + `.Tree_Item` rows, no collection | `semantic_collection_*`, context-menu targeting |
| Virtualized identity | stable `Item_ID` keys; matched row index only for reveal | stable `Item_ID`; pending index for unloaded windows; row key from ID | fixed-row virtual list |
| Input adapter | overlay `ui.interaction_scope`, `handle_key` for native `on_key`, text-change scope callback | scroll `ui.interaction_scope`; `handle_key` fallback; context-menu pointer | Scoped input is delivered to the next description |

### Duplicated policy vs Alicorn runtime

The stock components deliberately duplicate policy that the runtime also owns
internally:

- **List navigation and reveal:** `palette_model.move` / `tree_model.handle_key`
  are AliKit policy over caller-owned slices; the runtime's stock Select has an
  equivalent internal policy.
- **Matching:** `palette_model.matches` is an ASCII-only substring policy; the
  runtime owns Unicode-aware stock Select typeahead.
- **Popup and input routing:** `command_palette` composes the public modal
  overlay and scopes rather than using `Context_Menu`; #218 recorded that the
  Context Menu routes only direct Button children, so nested virtualized rows
  cannot use it.
- **Focus restoration:** both components re-implement after-frame restoration
  around a retiring overlay. This is public API use, not private state.

No AliKit package reads private runtime fields. `command_palette` and
`tree_view` use only public runtime queries and callbacks.

## Stock vs parts comparison (issue step 2)

Path: the command palette result list. Baseline:
`alikit:command_palette.build` with caller-owned matching
(`Search_Mode.Caller_Filtered`). Candidate: `alikit:palette_parts.results`
composed with the fixture's query field and the same caller-owned matching,
ranking, and command dispatch.

Script (both implementations, same 12 items, one disabled item): open, commit
`"o"`, Down, Down, Up, Down, Return. Fixture:
`palette_parts/pilot_test.odin`. Run:

```powershell
odin test palette_parts -define:ODIN_TEST_THREADS=1 -collection:alicorn=./alicorn -collection:alikit=.
```

### Code and API surface

| Metric | Stock palette | Parts variant |
|---|---:|---:|
| Component implementation | 517 LOC | 402 LOC (`parts.odin`) |
| Public procedures | 11 | 7 |
| Shell added by the fixture | shared application | ~120 LOC query/root/callback shell in the pilot fixture |
| Modal/popup adapter | component-owned | **application-owned** in this variant |
| New runtime APIs | 0 | **0** |
| Result semantics | Buttons in a virtual list (no collection) | `List_Box` + `List_Box_Option`, logical count, selected/current |
| Visual parts | one runtime Button per row | custom Button + `.Icon`, `.Label`, `.Content`, `.Selected_Indicator` |

### Turn work (cumulative `testui.Turn_Work`, 6 measured turns)

| Counter | Stock | Parts | Parts / stock |
|---|---:|---:|---:|
| Descriptions emitted | 154 | 210 | 1.36x |
| Descriptions reused | 140 | 180 | 1.29x |
| Reconcile nodes visited | 154 | 210 | 1.36x |
| Measure nodes examined | 4 | 2 | 0.50x |
| Layout nodes visited | 25 | 199 | 7.96x |
| Paint nodes visited | 20 | 64 | 3.20x |
| Composition nodes visited | 120 | 160 | 1.33x |
| Text-shape requests | 8 | 35 | 4.38x |
| Semantic structure changes | 19 | 16 | 0.84x |
| Semantic property changes | 21 | 17 | 0.81x |

The parts list describes a custom row subtree and publishes a collection. Its
larger layout/text work is the cost of custom presentation; it publishes fewer
semantic property transitions. The stock modal shell does some work that the
parts fixture moves into application-owned code, so these numbers compare the
complete palettes as the pilot drives them, not only the row function.

### Allocations and idle

One run of the tracking allocator (sites include shared font/text setup; counts
vary by a few percent between runs because allocator-backed caches warm in
different orders):

| Metric | Stock | Parts |
|---|---:|---:|
| Allocations | 790 | 1,465 |
| Bytes | 941,273 | 1,436,019 |
| p50 turn | 93,100 ns | 228,100 ns |
| p95 turn | 364,100 ns | 512,100 ns |
| Idle wakes after settle (`advance_time`, 16 ms) | 0 | 0 |

Both settle with no scheduled descriptions or retained presentation. The parts
variant allocates more per frame because each row is an application subtree;
the shared font setup dominates neither total.

### Semantic parity

Both paths activate the same stable item for the scripted keyboard path
(asserted in `pilot_test.odin`). The parts list adds a real `List_Box`
collection with `logical_count`, `position_in_set`, `size_of_set`, and
selected/current identity. It does not claim to be semantically identical to
the stock palette because the stock palette publishes no collection; the added
structure is part of the parts recipe. Rows keep the accessible title, `Selected`
state, and `Select`/`Focus` actions.

## Novel composite (issue step 3)

`alikit:icon_picker` is the primary proof. It is 840 LOC of complete copyable
source with 12 public procedures. It uses only public facilities:

| Behavior | Public composition |
|---|---|
| Search field and IME ownership | `text_field_controlled`, `semantic_text_field_label` |
| Icon cells/rows | `button_begin(presentation=.Custom)`, `ui.panel`, `ui.icon`, `ui.text` |
| Visual parts | `visual_part_attach` (`.Icon`, `.Label`, `.Content`, `.Selected_Indicator`) |
| Collection and stable identity | `semantic_collection_begin(.List_Box)`, `semantic_collection_item(.List_Box_Option)`, instance+key `Semantic_ID` |
| Virtualized grid/list | `virtual_list_begin/end`, `virtual_list_ensure_visible` |
| Keyboard routing | `ui.interaction_scope` on the retained scroll owner |
| Grid/list navigation | ordinary procedures over the filtered match index; disabled skip and boundary clamp |
| Focus requests | `ui.after_frame` + `alicorn.focus`; public `request_search_focus`/`request_grid_focus` |
| Activation | one `Event{kind=.Activated, key}` proposal; caller assigns `selected_key` |
| Two appearances | `.Grid` vs `.List`, same contract, different layout and `cell_emit`/`row_emit` |
| Application interaction | example Ctrl+F → `request_search_focus`; no component API change |

Parts are named in [the component guide](../icon-picker.md). Usage is small
(`picker.init`, one `picker.picker` call, one event branch) and the complete
consumer is `examples/icon_picker/main.odin`.

### Contract coverage

| Contract | Coverage | Result |
|---|---|---|
| Keyboard/pointer/semantic activation parity | `test_icon_picker_keyboard_pointer_and_semantic_activation_agree` | same proposed key and accepted selection |
| Disabled items | same test + `..._skips_disabled_and_reconciles_removal` | skipped in navigation, no `Select` action |
| Focus vs selection | `test_icon_picker_focus_and_selection_are_separate` | `Current` and `Selected` are distinct |
| Removal/reorder | `..._skips_disabled_and_reconciles_removal` | active identity moves by key, selection stays caller-owned |
| IME yield | `test_icon_picker_search_filters_and_ime_yields_navigation` | preedit owns Up/Down; committed query filters |
| Search-focus key yield | `test_icon_picker_search_focus_yields_navigation_and_space` | arrows move the grid, Space activates, characters/Backspace edit, composition stays with text |
| Escape/outside click | `test_icon_picker_modal_escape_outside_click_and_nested_overlay` | dialog closes, focus returns to opener |
| Nested modal over picker | same test | nested dialog owns input; Escape closes only the top layer |
| Virtualized/recycled items | `test_icon_picker_virtualizes_large_grid_and_reveals_identity` | 200 choices, bounded realization, logical count 200, last identity revealed |
| Focus restoration | modal tests + pattern check | opener focus restored |
| Teardown/idle | virtualization/modal tests | no invalidated state or presentation after settle |
| Appearance identity | `test_icon_picker_appearance_switch_preserves_contract` | same semantic IDs and names, different geometry, behavior unchanged |
| Pattern check | `test_icon_picker_modal_pattern_conformance` | `.Modal_Dialog` passes at the pinned revision |

There is no `testui` pattern for a roving grid/list, so grid behavior uses
explicit drive assertions. That absence is recorded as a core candidate.

### Authoring complexity

| Artifact | LOC | Notes |
|---|---:|---|
| `icon_picker` complete package | 840 | 12 public procs, two appearances, label/detail variants |
| `icon_picker` tests | 724 | 11 tests, including pattern check, search-focus key yield, and 200-item virtualization |
| Example consumer | 260 | modal host, Escape/outside/nested, Ctrl+F, appearance toggle |
| `palette_parts` package | 402 | result list only |
| `palette_parts` tests + pilot | 753 | 8 tests plus measurement fixture |
| Stock `command_palette` (unchanged) | 517 | kept as the application entry point |

A copy-and-change edit is local: replace `cell_emit`/`row_emit`, change
`Options`, or omit search. No AliKit internals are reachable, and none are
required.

## GO/NO-GO per extraction candidate

Two-consumer rule: a shared helper is only justified when at least two
dissimilar consumers need the same generic contract.

| Candidate | Consumers | Verdict | Evidence |
|---|---|---|---|
| Shared result-list navigation/selection helper | `palette_parts`, `icon_picker` | **NO-GO now** | Both keep caller/app-owned filtering and identity. The picker adds 2D stride, row bounds, and appearance-dependent strides; a generic helper would need a navigation-shape parameter, recreating what each source file already expresses in ~40 LOC. Extract only with a third userland consumer. |
| Shared semantic collection helper | both | **NO-GO** | `semantic_collection_begin/item` already is the shared public helper; AliKit only wraps it with component identity. |
| Shared popup/dismissal | `command_palette`, parts shell | **NO-GO** | The stock palette's modal adapter is ~100 LOC. Extracting it would recreate a component framework and force focus restoration policy onto callers. |
| Copyable parts recipe | palette list, icon picker | **GO** | Demonstrated; no runtime changes; tests and measurements above. |
| Keep stock entry points | `command_palette`, `tree_view` | **GO** | Unchanged and green. |
| Generic behavior framework | — | **NO-GO** | The composite is ordinary state/procedures; a framework would add a second abstraction without a demonstrated consumer. |

## Core requirements proposed to Alicorn

1. **Key preemption for a generic text owner that is not an editor.** A focused
   `text_input_target` makes Alicorn suppress `Left`/`Right`/`Home`/`End`
   application keys (`application_key_can_preempt_text_field`). A grid that uses
   a text target for committed Space therefore cannot receive directional
   application keys. Concrete ask: let a retained interaction scope opt into
   preemption for its declared keys, or add a "text capture without editing"
   owner mode. Consumers: `icon_picker` (Space + arrows) and any palette list
   that wants Space activation while roving.
   **Resolved** by Alicorn #226 (`text_preempt_keys`); `icon_picker` now declares
   the policy on its single root scope and supports Space plus arrows while the
   search field keeps focus. The scope must own the text target (be an ancestor),
   so the picker's keyboard scope moved from the grid's scroll region to the
   composite root.
2. **Roving semantic focus for non-Tab-stop rows.** Rows are intentionally
   `focusable=false` so the collection is one Tab stop, so a semantic `Focus`
   action on a `List_Box_Option` is rejected by
   `semantic_realized_action_owner_is_eligible`. Concrete ask: an owner-routed
   semantic focus request that updates the collection's current item without
   adding every row to Tab traversal. Consumers: `icon_picker` and
   `palette_parts` both advertise `Focus` actions on non-focusable row owners.
3. **Roving grid/list pattern check in `testui`.** The `.Combobox_Listbox` check
   assumes a Combo_Box trigger and popup; there is no check for "one Tab stop,
   arrows skip disabled, Current/Selected separate, virtual reveal". Concrete
   ask: a `.Grid_Roving` (or `.Roving_List`) pattern with a collection part and
   target/disabled/semantic-action parts. Consumers: both new packages.
4. **Grid position semantics (optional).** There is no `.Grid` role or row/column
   position in `Semantic_Node`. The picker publishes a `List_Box` with linear
   positions today. A small grid extension would improve assistive-technology
   row/column announcements; not required for behavior.
5. **Collection parent identity (#218 finding, still open).** `List_Box` is
   parented to the nearest semantic ancestor rather than a named owner. The
   parts list does not need the popup parent contract, but a select-like parts
   popup still does. Keep the #218 proposal public parent parameter.

## Limits

- All behavioral tests are headless (`alicorn:testui`): no platform
  accessibility bridge, OS IME candidate window, or pixels.
- The native demo was smoke-run on SDL_GPU D3D12 (`icon_picker_smoke ... idle
  true`, one submission, no motion wakes). No hosted WebGPU run was performed
  for this branch; the composite uses no GPU-specific API.
- The comparison is one scripted palette path with one fixture. The work
  counters are deterministic; wall-clock latency and allocation bytes vary by a
  few percent per run.
- `icon_picker` Space activation depends on Alicorn #226 `text_preempt_keys`
  (pinned here at `700f2c5...`). A consumer still on an older Alicorn revision
  falls back to Return, pointer, or semantic activation.

## Reproduction

```powershell
./tools/test.ps1 -Odin odin
./out/icon_picker_example.exe --smoke
```

`tools/test.ps1` also copies `icon_picker/` beside a tiny consumer and builds it
with only `-collection:alicorn=...`, proving the source is not dependent on
AliKit's package topology.
