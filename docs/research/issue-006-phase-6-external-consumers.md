# Issue 6: composability phase 6, external consumers

Date: 2026-11-22
Branch: `codex/v03-phase6-consumers`
Base: `origin/main` at `78a6df7` (phases 1-5 merged)
Pinned Alicorn: `47c9d4a7cd1f637876190fec899daeeac00a30ae`
AccessKit binding: `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`

## Verdict

- **GO: package imports from outside the repository.** A consumer with
  `-collection:alicorn=<alicorn> -collection:alikit=<alicorn-kit>` compiles and
  runs `alikit:dialog`, `alikit:radio_group`, `alikit:progress`,
  `alikit:notices`, and `alikit:selection`, including a dialog-hosted
  parts-composed radio group and a toast.
- **GO: behavior-only authoring.** The same consumer builds an author-owned
  selection strip directly on `alikit:selection`'s borrowed `View`,
  `reconcile_active`, `move_wrapped`, `propose_focus`, and
  `propose_activation`; no AliKit presentation package is involved.
- **GO: source copying.** Copied `radio_group.odin`, `selection.odin`, and
  `contract.odin` compile with only the Alicorn collection after the two
  intra-AliKit imports are rewritten to sibling relative packages. Copying
  `radio_group.odin` alone does **not** compile.
- **GO: native smoke and idle.** Both generated consumers start SDL_GPU, submit
  a frame, reach the host's `SDL application PASS`, and report `idle true`.
  No stabilization-limit hits and no repeated-rebuild loop.

## Fixture design

The consumer is generated outside the AliKit build:

```text
%TEMP%\alikit-external-consumer\
  BUILD_NOTES.md
  bin\SDL3.dll
  path1_packages\main.odin
  path2_copy\
    main.odin
    vendor\radio_group\radio_group.odin
    vendor\selection\selection.odin
    vendor\theme_contract\contract.odin
```

Templates live in [`tests/external_consumer`](../../tests/external_consumer/README.md);
[`tools/validate_external_consumer.ps1`](../../tools/validate_external_consumer.ps1)
recreates the directory on every run, copies the radio files, rewrites imports,
builds both projects, and runs the smokes.

### Path 1: import packages

`path1_packages/main.odin` imports five packages by collection. It renders:

- a dialog (`alikit:dialog`) opened from the application root;
- a radio group composed from `group_begin`, `item_begin`, `indicator`,
  `item_end`, `group_end` (`alikit:radio_group`), with the application owning
  `selected`;
- a progress part (`alikit:progress`) whose value follows the accepted plan;
- a persistent runtime toast (`alikit:notices`) posted after the first frame,
  plus a second toast posted from the dialog's Save action;
- an author-owned strip that uses `alikit:selection` directly and publishes
  at-most-one selection through application state.

Exact build:

```text
odin build path1_packages ^
  -collection:alicorn=<alicorn> ^
  -collection:alikit=<alicorn-kit> ^
  -out:bin/external_consumer_path1.exe ^
  -collection:accesskit=<alicorn>/.deps/odin-accesskit ^
  -collection:accesskit_c=<accesskit sdk static lib dir> ^
  -extra-linker-flags:bcrypt.lib ntdll.lib propsys.lib runtimeobject.lib ^
    uiautomationcore.lib userenv.lib ws2_32.lib
```

Result: compile OK; `--smoke` exit 0; `external_consumer_path1_smoke plan 101
lane 1 toasts 1 idle true`; `SDL application PASS`; one first-frame
stabilization rebuild because the toast is posted after the first description;
zero stabilization-limit hits.

### Path 2: copy source

The harness copies the radio package and its declared dependencies into
`path2_copy/vendor/` and rewrites:

```odin
import sel "alikit:selection"     -> import sel "../selection"
import tc  "alikit:theme_contract" -> import tc  "../theme_contract"
```

`path2_copy/main.odin` imports `./vendor/radio_group` and composes the group and
items with an author-owned two-line row that keeps the copied indicator part.

Exact build:

```text
odin build path2_copy -collection:alicorn=<alicorn> -out:bin/external_consumer_path2.exe
```

The same AccessKit arguments are required by the native host but no `alikit`
collection is passed. Result: compile OK; `--smoke` exit 0;
`external_consumer_path2_smoke plan 201 idle true`; `SDL application PASS`;
`application_stabilization_rebuilds 0`.

### Copy audit

The radio group imports exactly two AliKit packages:

| Import | Copy source | Rewritten import |
| --- | --- | --- |
| `alikit:selection` | `selection/selection.odin` | `../selection` |
| `alikit:theme_contract` | `theme_contract/contract.odin` | `../theme_contract` |

`theme_contract` imports only `alicorn:runtime`; `selection` imports nothing.
There are no hidden package-internal dependencies. The copy is self-contained
once those files are siblings and the import lines are rewritten. Keeping the
`alikit:` imports and pointing an `alikit` collection at the copied root also
works, but then the consumer still needs a collection; the fixture uses the
stronger form that needs only `alicorn`.

## Manifest audit and fixes

The harness reads `components.json`, checks every declared source/test/example/
capture file, compares each entry's actual `alikit:`/`alicorn:` imports with its
declared `dependencies`, validates copy recipes, and checks the referenced
validation scripts. Findings fixed in this phase:

- `sidebar` imported `alikit:selection` but did not declare it. Added.
- `palette-parts` listed `palette_parts/pilot_test.odin`; the pilot test moved
  to `command_palette/pilot_test.odin` in phase 3-4. Fixed.
- The four supporting packages had no `dependencies` field. Added `[]` for the
  pure models and `selection`, `alicorn:runtime` for `theme_contract`, and
  `alicorn:runtime` + `alicorn:ui` for `table_core`.
- `radio-group`, `palette-parts`, and `icon-picker` now record a `copy` recipe
  (`sources`, `importRewrites`, `collectionRequired`, note).
- `progress`, `notices`, `segmented`, `table`, `menu`, `data-grid`, and
  `radio-group` now list `theme_contract_satisfied` and
  `theme_contract_missing_required`, which they export.
- Added `validation.externalConsumer` and documented the copy rule in
  `docs/components.md` and the catalog's component page.

Historical manifest gap: `dialog` and `scroll_area` initially shipped without
registry entries. Both now have `components.json` entries and catalog pages;
the current registry covers all 14 supported catalog components. Published
catalog pages link runnable examples rather than embedding desktop captures.

## Friction list

1. **Copy instructions omitted source dependencies.** Several guides listed only
   the main component file as copyable. The radio-group guide and catalog page
   are corrected; the manifest copy recipes are the machine-readable source of
   truth. Components that promise source copying should keep this recipe audit
   current; collection-import packages do not need copy recipes.
2. **Copying requires import rewriting or an extra collection.** A raw directory
   copy keeps `alikit:` imports. The supported options are (a) rewrite the two
   imports to relative packages and use only `alicorn`, or (b) add
   `-collection:alikit=<copied root>`. The fixture proves (a); the manifest
   records the rewrites for (a).
3. **Native external consumers need the AccessKit SDK arguments.** A plain
   `-collection:alicorn` build does not link without the pinned static SDK
   collection and linker flags. The harness bootstraps them from the pinned
   Alicorn and records the exact arguments in the generated `BUILD_NOTES.md`.
   This is Alicorn host setup; a short consumer guide would remove the surprise.
4. **First-frame runtime notices cause one stabilization rebuild.** Posting the
   toast after the first description makes Alicorn build once more before it
   settles. The harness asserts no stabilization-limit hit and allows one
   rebuild; the path-2 copy (no toast) reports zero. This is expected behavior,
   not an AliKit defect.
5. **Pin combination is manual.** The consumer must check out Alicorn at the
   locked revision and the AccessKit binding at its locked revision. The
   `dependencies.lock.json` audit in the harness fails fast on mismatch; there is
   still no package-manager command.
6. **No per-component test command in the manifest.** Tests are listed as files
   and the global `validation.native` command covers them. The audit verifies
   file existence and actual imports, not a per-entry command string.

## Validation run

```text
./tools/validate_external_consumer.ps1 -Odin <odin>
  manifest audit: pass (warnings: dialog/scroll_area entries missing)
  path 1 build: pass
  path 1 smoke: pass, idle true
  path 2 build: pass (alicorn collection only)
  path 2 smoke: pass, idle true
./tools/test.ps1 -Odin <odin>
  all model, component, example, and copied-icon-picker checks: pass
```

The catalog site was not rebuilt in this branch run; the changed pages are
Markdown/MDX text only and the catalog build is a separate check.

### Menu package-import and source-copy follow-up (2026-11-26)

The external package fixture imports `alikit:menu` and composes its anchored
popup inside the external Dialog consumer. The source-copy fixture now also
copies Menu beside Radio Group with their shared `selection` and `theme_contract`
dependencies. `components.json` declares Menu's source and import-rewrite
recipe, and the harness checks that the copied package builds without the
AliKit collection. The package-import and copy builds pass against the locked
Alicorn and AccessKit revisions. Native `--smoke` and physical screen-reader
output were not verified in this follow-up.

## Follow-ups

- The registry entries and catalog pages for `dialog` and `scroll_area` were
  added after this initial phase. Desktop captures are no longer a catalog
  requirement.
- Continue the `copy` recipe audit for components that document source copying;
  Menu's recipe is now declared and exercised with Radio Group in the external
  fixture. Update each guide to make its supported package/copy path explicit.
- Consider a short "Consuming AliKit in your application" guide that includes
  the collection arguments, AccessKit bootstrap, and the copy-rewrite rule.
- Wire `tools/validate_external_consumer.ps1` into CI after a few green local
  runs; the generated consumer is disposable and the run is bounded by two
  native smokes.
