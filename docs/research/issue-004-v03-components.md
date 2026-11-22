# Issue 4: AliKit v0.3 P0 component sprint

Date: 2026-11-22
Branch: `codex/v03-components`
Base: `codex/issue-3-parts-pilot` at `6ee3b92`
Pinned Alicorn: `47c9d4a7cd1f637876190fec899daeeac00a30ae` (master, "Merge
v0.3 core semantics: radio, progress, and table roles; pointer navigation
buttons")
AccessKit binding: `e290e5f55da9cfb5e5622e4a9e5be3b691a7b82b`

## Base and pin decision

`origin/main` contains the v0.2-era retained-component work and a pin to an
older fork commit (`54ba6d2`), but it does not contain the issue-3 pilot
package lineage: `palette_parts`, `icon_picker`, their examples, the parts
research record, or the v0.2.3 standard pin. The pilot branch is a direct
descendant of `origin/main` (`cff5c02`), so basing on
`codex/issue-3-parts-pilot` keeps every main commit and adds the pilot work.

The P0 components need semantics that landed after v0.2.3: explicit
`Radio_Button`/`Radio_Group`, `Progress`, and `Table`/`Table_Row`/`Table_Cell`/
`Table_Column_Header`/`Table_Row_Header` roles, nested row collections, numeric
range properties, and pointer Back/Forward buttons. Those are in Alicorn master
commit `47c9d4a`, which is not in a v0.2.x tag. The lock follows the repository's
existing master-ref convention and records the exact SHA. At the next Alicorn
release the `ref` should become the new version tag with the same or newer SHA;
the SHA is authoritative for reproducible checkouts.

`tools/test.ps1` verifies the checkout and AccessKit pin. The CI checkout ref
was updated to the same SHA.

## Core semantics verified at the pin

| Capability | Proof |
| --- | --- |
| Radio roles, `Checked`, `Press` routing | `runtime/semantic_compound_roles_test.odin`, `ui/ui_semantic_compound_test.odin` |
| Progress role + `semantic_numeric_range` | `runtime/semantic_range_value_test.odin`, reference compound section |
| Nested table rows/cells/headers | `runtime/semantic_compound_roles_test.odin` |
| Roving pure model and `.Roving_List`/`.Roving_Grid` checks | `runtime/roving.odin`, `testui/roving_pattern_test.odin` |
| Pointer Back/Forward | `POINTER_BUTTON_BACK`/`FORWARD`, host mapping tests |
| Collection `parent` | `semantic_collection_begin(..., parent=)` and #223 tests |
| Invalidation frontier checks | `testui/frontier_checks.odin` |

## Theme contract helper

All P0 components use `theme_contract`, a small bounded helper for optional
namespaced surface roles. A component's `theme_contract_default` marks each
configured role required and each zero role as a documented core fallback, so
first use needs no theme compilation. The helper reports missing role names and
does not resolve role names per frame. This is a shared helper by the
two-consumer rule: five components need the same validation shape, and the
helper is pure and UI-independent.

## Radio Group

Package: `radio_group`. It is controlled: `selected_value` is an argument and
only `Checked` identity is derived. The group is the single Tab stop and a
`Radio_Group` collection; options are non-focusable `Radio_Button` owners with
`Checked`/`Selected` and `Current`, and enabled options advertise `Press` and
`Focus`. Arrow movement uses `alicorn.roving_move_for_key` and
`alicorn.roving_propose` with wrap, disabled skipping, and Home/End. The
appearance is two orientations over the same identities.

Tests cover semantics/parenting, keyboard wrap and disabled skipping,
pointer/keyboard/semantic parity, focus-vs-selection in `Activate` mode,
orientation identity, reorder identity, and the theme contract. There is no
radio-group pattern in `testui`; `.Roving_List` requires `List_Box`. A
`.Radio_Group` pattern is a candidate core addition and is not claimed here.

## Progress Bar

Package: `progress`. Determinate mode publishes `.Progress` with a formatted
value and `semantic_numeric_range`; indeterminate mode deliberately omits
numeric properties. Parts are the label, value, track, and fill, with named
visual parts on the stable progress owner. The track uses a definite width so
the fill geometry is exact and value changes stay inside a bounded layout
frontier.

There is no component timer. The application supplies `indeterminate_phase`;
`pulse=true` adds a paint-only opacity response through `ui.motion` and reduced
motion selects `.Snap`. The test checks fraction clamping, semantic range,
indeterminate non-claims, phase movement, reduced-motion observation, and a
bounded `layout_nodes_visited` count after an input-driven value change. No
`testui` progress pattern exists or is needed for a non-interactive node.

## Notices

Package: `notices`. Real toasts call `notice_post`/`notice_emit` and keep the
runtime as the only queue, including stable-ID deduplication, capacity,
action-bearing persistence, live Status/Alert announcements, and one-shot
expiry. Thin helpers expose post/dismiss/take-action/next-deadline/advance.

The composable parts are an inline `card` and `stack` over application-owned
`Item` values. They publish Status/Alert semantics, ordinary action/close
buttons, reveal-only content motion, and an opacity retire path that reports
`Retire_Settled` after the presentation settles. Reduced motion snaps.

Why not a custom toast overlay over the runtime queue? At this pin
`notice_overlay_describe` owns the complete card tree. A custom overlay would
have to duplicate the visual card and, because there is no public live-region
annotation (`pending.semantic.live` is private), it would regress the
announcement guarantee. The card parts therefore target inline banners and
application-hosted surfaces; real toasts stay runtime-rendered. This is recorded
below as a core gap.

Tests cover runtime toast Status semantics, pointer action delivery through
`notice_take_action`, the exact one-shot expiry deadline without polling,
action-bearing persistence, inline card value/description/action delivery, and
the retire-settle path.

## Sidebar / Navigation Rail

(To be filled by the sidebar slice.)

## Table

(To be filled by the table slice.)

## Core gaps proposed to Alicorn

1. A radio-group pattern kind in `testui` (container `Radio_Group`, options
   `Radio_Button`, disabled skipping, wrap policy, Checked/Current identity).
2. A notice presentation hook. At this pin `notice_overlay_describe` owns the
   complete card tree; an application cannot supply card parts, motion, or a
   custom card recipe without duplicating the overlay.
3. A table pattern kind (nested `Table`/`Table_Row` collections, header roles,
   row/column coordinates, virtual row reveal).
4. A public monotonic clock query for components that need a deadline without
   owning a timer. The notice queue exposes its next deadline but not "now".
