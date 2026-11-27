# Scroll Area

`alikit:scroll_area` is a styled, focusable scroll container over Alicorn's
retained `Scroll_Region`. It owns the contract the Control Gallery previously
rebuilt with hand-maintained section heights and claims it could not keep:
bounded or intrinsic viewport sizing, keyboard scrolling on a single Tab stop,
wheel scrolling, a published `Scroll_View` role, and bar-part geometry.

Alicorn owns wheel routing, scrollbar geometry/painting, offset retention,
clipping, and the resolved viewport. AliKit owns the component contract around
them. This component does not virtualize; use `virtual_list_begin` or
`alikit:data_grid` for large data.

## Responsibility split

| Layer | Responsibility |
| --- | --- |
| Alicorn | Scroll region, wheel input, scrollbar geometry/paint, offset retention, clipping, layout, theme scrollbar recipe. |
| `scroll_area` | Viewport bound or content-sized cap, line-to-content sizing helpers, single Tab stop, Up/Down/Page/Home/End key map, focus request, Scroll_View semantics, bar-part geometry, theme contract. |
| Application | Content, logical line count or measured extent, theme registration, commands that reveal content. |

`State` is caller-owned; no init/destroy is required.

## Package example and source-copy recipe

Production source closure: `scroll_area/scroll_area.odin`, `theme_contract/contract.odin`.
The complete recipe is in [`components.json`](../components.json); place copied files in
sibling packages and apply its `importRewrites`. Only the Alicorn collection is required;
tests and examples remain in AliKit. The import snippet below shows ordinary
collection-based package use.

```odin
import ui "alicorn:ui"
import scroll_area "alikit:scroll_area"

if scroll_area.begin(ctx, &app.log,
	scroll_area.Options{
		accessible_label="Build log",
		line_count=40,
		line_height=24,
		fit_content=true,
		max_height=320,
		axes=.Vertical,
	},
	key=ui.key_string("log"), instance_id=1, recipe=app.recipe) {
	if ui.column(ctx, key=ui.key_string("log-lines")) {
		for line in 0..<40 { /* ui.text(... height=24) */ }
	}
	scroll_area.end(ctx, &app.log)
}
```

## Parts and identities

| Part | Identity | Notes |
| --- | --- | --- |
| Region | `scroll_area_semantic_id(instance_id)` | One `Scroll_View`, one Tab stop. |
| Bar track/thumb | `bar_geometry(state)` | Owner-local/absolute track and thumb rects computed from the resolved viewport; useful for tests and app overlays. |
| Frame | `Recipe.frame_surface_role` | Optional themed region background. |
| Theme bars | `theme_scrollbar_recipe(recipe)` | Maps track/thumb/corner roles into the theme-level scrollbar recipe. |

## Styling, motion, and theme

`Recipe` has an optional `frame_surface_role` plus core `track_role`,
`thumb_role`, and `corner_role`. The pinned runtime resolves scrollbar colors
from the registered theme, not per node, so install them at setup:

```odin
import alicorn "alicorn:runtime"
theme := alicorn.DEFAULT_STYLE_THEME
theme.scrollbar_recipe = scroll_area.theme_scrollbar_recipe(app.recipe)
id := alicorn.style_theme_register(rt, theme)
```

`Options` carries axes, explicit or fit viewport sizes, min/max height, content
extent or line count, line metrics, padding, bar policy, axis behavior, and
focusability. The component does not expose per-instance corner or stroke
settings: Alicorn's scroll-region API does not currently apply those values,
so the unused `Style` surface was removed rather than implying that it changes
the rendered viewport.

The component computes the fit-content viewport itself from content + max
height. The pinned `Scroll_Region` fit-content path does not resolve a nonzero
bounds height inside a Column parent, so an explicit bounded viewport is the
reliable contract; this is recorded as a core gap.

There is no motion.

## Keyboard and accessibility contract

- The region is one Tab stop by default (`Options.non_focusable` opts out).
- **Up/Down** scroll by one line; **Page Up/Down** by a viewport; **Home/End**
  jump to the content start/end. Keys are delivered to the focused region
  through an interaction scope; the component retains the offset command.
- **Wheel** is runtime-owned and works while the pointer is over the region.
- `Scroll_View` publishes the accessible name and a short description. The
  component does not publish semantic scroll actions at this revision; physical
  assistive-technology scrolling is not claimed.
- Not claimed: horizontal keyboard scrolling (Left/Right), scroll-to-focus on
  Tab, or a custom bar interaction model. Horizontal wheel and bar drag remain
  runtime-owned.

## The gallery friction fixed

The Control Gallery used a hard-coded `content_height` per section, a second
hard-coded line count for its nested example, and claimed Page Up/Down/Home/End
support even though a retained `Scroll_Region` has no key bindings. That class
of mistake is now component-owned:

- `content_height_from_lines` / `line_count` replaces hand-maintained extents.
- `fit_content` + `max_height` bounds the viewport without guessing.
- The region is focusable by default and AliKit handles the claimed keys.
- `bar_geometry` gives tests and overlays the track/thumb parts.

## Conformance tests

`scroll_area/scroll_area_test.odin` covers:

- identity, recipe-to-theme mapping, role validation, and sizing helpers;
- `Scroll_View` semantics, explicit viewport height, focus, Down/Page/Home/End,
  wheel parity, and thumb/track part geometry;
- intrinsic fit sizing and max-height bounding;
- command helpers (`scroll_to`, `scroll_to_line`, `scroll_page`) and clamping.
- visible retained text, containment, and width adaptation after resizing from
  520 × 420 to 360 × 300 logical pixels.

## Limits

- Headless tests do not prove physical screen-reader scrolling or pixels.
- Per-node scrollbar color/style overrides are unavailable at the pinned
  runtime; use the theme recipe.
- AliKit does not draw custom thumb/track pixels: the runtime paints its
  retained bars with the supplied theme recipe. `bar_geometry` exposes the part
  rects for inspection and app overlays.
- The implementation and focused tests in this checkout use Alicorn
  `4e0862f368cb638b7aece0bad9dd82cae0c3d8c4`, recorded in
  [`dependencies.lock.json`](../dependencies.lock.json).

## Source map

The reference preview is an authored SVG layout target, not a desktop
application screenshot. It does not claim pixel equivalence with native output.
Open the [Scroll Area reference](research/authoring-reliability/references/scroll-area.svg)
beside the runnable example when reviewing its proportions and scroll treatment.

- [Package](../scroll_area/scroll_area.odin)
- [Tests](../scroll_area/scroll_area_test.odin)
- [Example](../examples/scroll_area/main.odin)
- [Theme JSON](../examples/scroll_area/theme.json)
