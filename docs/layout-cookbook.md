# Alicorn layout cookbook

This guide collects the layout patterns used by AliKit's catalog components. It describes the
current `alicorn:ui` helpers and sizing rules, not a new layout abstraction.

## Start with the parent allocation

Use these values deliberately:

| Value | Meaning |
| --- | --- |
| `-1` | Fill the size offered by the parent on that axis. |
| Fit-content sentinel | Measure a container from its children on a supported axis. |
| `grow=1` | Share leftover space along the parent's main axis. |
| A nonnegative number | Use a fixed logical size on that axis. |

`ui.row` and `ui.column` stretch across their parent's width and measure their height from their
children by default. `grow` only distributes remaining space when the parent has a definite size.
Choose a fixed or fill height for a full-window root; keep the default fit-content height for
cards and compact groups.

```odin
import ui "alicorn:ui"
if ui.column(ctx, width=-1, height=-1, padding=16, gap=12) {
	_ = ui.text(ctx, "Workspace", size=24)
	if ui.row(ctx, height=36, align=.Center, gap=8) {
		_ = ui.text(ctx, "A row of controls")
	}
}
```

## Let `grow` own the remainder

In a horizontal split, give the fixed navigation rail a fixed width and let the content column
grow. In a vertical split, give the header its content height and let the results region grow.
Avoid assigning the same axis both a fixed size and a grow share.

```odin
import ui "alicorn:ui"
if ui.row(ctx, width=-1, height=-1, gap=12) {
	if ui.column(ctx, width=220, height=-1, padding=12, gap=8) {
		_ = ui.text(ctx, "Navigation")
	}
	if ui.column(ctx, width=-1, height=-1, grow=1, gap=8) {
		_ = ui.text(ctx, "Main content")
	}
}
```

## Align icon-and-label rows

Give the row an explicit height, center its children on the cross axis, and keep the icon and label
in the same row. A key belongs to each repeated data item, not to its current visual position.

```odin
import ui "alicorn:ui"

if ui.row(ctx, key=ui.key_u64(u64(item.id)), width=-1, height=36,
	align=.Center, gap=8) {
	_ = ui.icon(ctx, item.icon, size=16)
	_ = ui.text(ctx, item.label)
}
```

For an interactive row, prefer one full-width `ui.button` or component-owned row control. Putting
a narrow button beside a separate background surface can leave the hit target and painted row with
different bounds.

## Use panels for grouped content

`ui.panel` is a column surface. Its default width fills the parent and its default height measures
its children. Padding and gap belong to the panel's content layout; the fill, radius, and stroke
belong to its surface.

```odin
import ui "alicorn:ui"
if ui.panel(ctx, width=-1, padding=12, gap=8, radius=8) {
	_ = ui.text(ctx, "Recent files", size=18)
	_ = ui.text(ctx, "README.md")
}
```

Use `clip=true` only when overflow must be clipped. Clipping constrains painted descendants; it
does not shorten or ellipsize the underlying text.

## Bound large repeated content

Use a virtual list when only a viewport of a large collection needs to be described. Keep the row
height fixed and describe exactly the returned `[first, last)` range. Each row should use a stable
item key.

```odin
import ui "alicorn:ui"
if list, opened := ui.virtual_list(ctx, len(items), 32,
	key=ui.key_string("items"), height=280, focusable=true); opened {
	for index := list.first; index < list.last; index += 1 {
		item := items[index]
		if ui.row(ctx, key=ui.key_u64(item.id), width=-1, height=32, align=.Center) {
			_ = ui.text(ctx, item.label)
		}
	}
}
```

The virtual-list scope closes automatically when its `if` body ends. Do not add a second scroll
region around it unless the design intentionally needs nested scrolling.

## Use the high-level import for ordinary application code

`alicorn:ui` re-exports the public types and key constructors needed by ordinary applications:
`ui.Runtime`, `ui.Application_Key`, `ui.UI_Key`, and `ui.key_string`/`ui.key_u64`. A component
consumer should not import `alicorn:runtime` just to assign a stable key or write a normal
`ui.run` keyboard callback.

```odin
import ui "alicorn:ui"
on_key :: proc(app: ^App, rt: ^ui.Runtime, key: ui.Application_Key) -> bool {
	if !app.palette_state.open && key == .Open_Command_Palette {
		return palette.open_palette(&app.palette_state, rt)
	}
	return false
}
```

Import `alicorn:runtime` when the example genuinely uses runtime facilities that are outside the
high-level UI surface, such as custom retained primitives, diagnostics, theme registration, or
specialized semantic APIs. Explain that boundary in the example rather than making the import
look mandatory for ordinary component use.

## Compose parts without reaching into the runtime

When a component part opens a surface for custom descendants, close it with `ui.surface_end`. For a
custom keyboard scope attached to the current layout owner, `ui.interaction_scope_current` returns
the owner ID a component may need to consume its queued events. Existing `ui.interaction_scope`
remains available when the owner is already known.

```odin
import ui "alicorn:ui"
if ui.column(ctx, key=ui.key_string("picker-shell"), width=420, gap=8) {
	owner, registered := ui.interaction_scope_current(ctx, rawptr(app),
		ui.Interaction_Scope_Options{keys={.Up, .Down, .Return}})
	if registered {
		// Pass owner to the composed component's scoped-input API.
		grid, visible := picker.grid_begin(ctx, &app.picker, choices,
			picker.Options{}, key=ui.key_string("picker-grid"), instance_id=1,
			scope_owner=owner)
		_ = grid
		_ = visible
	}
}
```

## Verify layout changes

For each repeated or responsive component, check:

1. Fixed, fit-content, and grow-sized parents separately.
2. Short and long labels, including labels with no spaces.
3. Empty and maximum-size data sets.
4. Keyboard focus and pointer bounds against the visible row bounds.
5. Stable item identity after reorder and resize.
6. At least one native visual check at fractional scale when the platform is available.

Headless layout and component tests can verify bounds, identity, semantics, and invalidation. They
do not replace native pixel inspection, operating-system input testing, or a physical DPI matrix.

## Make layout intent measurable

Use `alicorn:testui` in component tests to turn the intended geometry and visible output into
assertions. These helpers inspect finalized logical bounds and the retained shaped-text/paint
stream; they do not claim GPU pixel verification.

```odin
import testui "alicorn:testui"

panel := testui.find(&h, testui.Query{
    role=.Dialog, name="Search", match_role=true, match_name=true,
})
query := testui.find(&h, testui.Query{
    role=.Text_Field, name="Search commands", match_role=true, match_name=true,
})
defer testui.destroy_find_result(&panel)
defer testui.destroy_find_result(&query)

inside := testui.expect_inside(&h, &query.element, &panel.element)
testing.expect(t, inside.ok, testui.layout_check_diagnostic(inside))
fills := testui.expect_fills_width(&h, &query.element, &panel.element)
testing.expect(t, fills.ok, testui.layout_check_diagnostic(fills))
visible := testui.expect_visible_text(&h, &query.element, "build")
testing.expect(t, visible.ok, testui.visible_text_diagnostic(visible))
```

`expect_aligned` checks a center or edge against another queried element.
`expect_no_overflow` checks against the immediate retained parent; use `expect_inside` for a
different ancestor. Re-query after each input or resize so assertions never use stale snapshots.
Pair these checks with native screenshots at the target logical size and fractional display scales:
headless geometry cannot detect antialiasing, glyph residency, clipping mistakes in the GPU path,
or platform-specific font fallback.

For the Command Palette, Dialog, and Data Grid reference examples, record failed geometry checks
and code/test iterations as attempts. Count an initial implementation as attempt 1; every later
implementation pass needed to make a failed check pass increments the count. Record imports,
fixed dimensions, and layout workarounds separately so a visually correct result does not hide an
unnecessarily difficult authoring path.
