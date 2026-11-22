# P0-2 dialog, menu, scroll area, and table split

Branch: `codex/v03-p0-dialog-scroll` from `main` at `40692e3`.
Pinned Alicorn: `47c9d4a` (v0.3 core semantics baseline).

This record captures the measured decisions and core requirements for the P0-2
batch. The components are ordinary AliKit packages over public Alicorn APIs;
no runtime code was changed in this repository, and no private runtime storage
is read.

## What was built

| Component | Owner of ephemeral state | Contract |
| --- | --- | --- |
| `dialog` | `State` | Escape/backdrop policy, initial focus, focus restoration, Alert live semantics, nested overlays, parts. |
| `menu` | `State` | Anchored popup, active row, placement, outside/Escape dismissal, trigger restoration. |
| `scroll_area` | `State` | Bounded/intrinsic viewport, keyboard scrolling, focus, bar geometry. |
| `table` | none | Static presentation: intrinsic wrapped rows, inline cell formatting, optional virtualization, no managed focus. |
| `data_grid` | `State` | Roving cell focus, selection publication, sort-header proposal, virtualization. |

## Runtime responsibilities verified

- `modal_overlay_begin` confines pointer, wheel, and focus traversal to the
  active overlay and blocks covered semantic activation. It does not bind
  Escape, dismiss on backdrop, focus a new overlay, or restore the opener.
- `modal_overlay_root` returns the most recent active top-level overlay, so
  stacked dialogs are supported; each overlay must be described after the
  ordinary root and closed before the next `modal_overlay_begin`.
- Focus traversal wraps within the active modal subtree.
- Interaction scopes deliver keys/pointer downs to the next description. A
  scope must be registered after its owner is described in the current frame.
- `context_menu_placement` provides flip-and-clamp placement for anchored
  popups.
- Live announcements are available through `Semantic_Node_Description.live`
  and `live_atomic`; `semantic_description` does not expose them. The dialog
  publishes an `Alert` companion for Alert_Dialog.
- `semantic_collection_begin` does not accept `.Menu` or `.Grid`.

## Gallery friction findings and fixes

The Control Gallery's overlay section claimed "Escape also dismisses" and
manually restored focus through an ad-hoc after-frame callback; it did not
actually handle Escape. Its scroll section used hand-maintained
`GALLERY_SECTION_HEIGHTS` (720/700/...) and a hard-coded nested content height,
then claimed Page Up/Down/Home/End support even though a retained
`Scroll_Region` has no key bindings.

The components now own those contracts:

- dialog Escape/backdrop/restoration are component policy with tests;
- `scroll_area` derives extents from `line_count`/`content_height` and handles
  the claimed keys on a focusable region.

## Core gaps discovered (report only)

1. **Surface fit-content.** `LAYOUT_SIZE_FIT_CONTENT` is supported for Row and
   Column `Container` nodes and `Scroll_Region`, not arbitrary
   `Custom_Surface` nodes. A rounded dialog panel therefore cannot be a
   fit-content surface; the dialog uses a themed `.Container` panel. A
   fit-content surface (or a surface style on Container) would close this.
2. **Fit-content Scroll_Region inside a Column.** A `Scroll_Region` with
   `height=LAYOUT_SIZE_FIT_CONTENT` resolves `viewport_height` during
   description but its retained `bounds.h` remained 0 inside a Column parent in
   the fixture. AliKit computes the bounded viewport itself. A retained
   fit-content geometry regression/fix would let the component delegate it.
3. **Nested Row child in a fit-content Column.** A fit-content Container with a
   `Row` child at `height=-1` measured only padding/one default line in the
   fixture; giving the Row `height=LAYOUT_SIZE_FIT_CONTENT` fixed it. The table
   now measures intrinsic text heights itself and authors an explicit row
   height, because Grid auto rows did not propagate wrapped text height.
4. **Menu collection role.** `Semantic_Role.Menu` exists, and `Menu_Item`
   exists, but `semantic_collection_begin` rejects `.Menu`. v1 publishes a flat
   Menu group with Menu_Item children (no logical count/position/selection).
5. **Grid roles.** `Semantic_Role` has no `Grid`/`Grid_Cell`; AccessKit does.
   `data_grid` uses `Table` roles for v1. Adding Grid roles plus collection
   support is an Alicorn-side change.
6. **Per-node scrollbar colors.** The runtime resolves scrollbar track/thumb/
   corner from the theme's `Scrollbar_Recipe`, not from a node role. AliKit
   exposes a recipe-to-theme mapping. A per-node scrollbar role/style seam
   would allow per-instance bar styling without registering a derived theme.
7. **Scroll Region keyboard scrolling.** The runtime has no keyboard bindings
   for a focused Scroll_Region. AliKit owns Up/Down/Page/Home/End through a
   scope. A runtime-owned convention (or a public scroll key helper) would be
   a candidate if several components need the same map.
8. **Content focus discovery.** The public query API cannot enumerate
   descendants of a panel. Dialog initial focus supports panel, primary,
   first action, and a configured key; "first focusable content control" is not
   generically addressable.

## Verification

- Package tests: `table`, `data_grid`, `scroll_area`, `menu`, `dialog`.
- Repo suite in `tools/test.ps1` includes all five packages and their examples.
- Native smoke runs on SDL_GPU D3D12 for each new example.
- Headless tests do not prove physical screen readers, native IME, or pixels.
