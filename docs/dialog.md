# Dialog

`alikit:dialog` is the composable dialog over Alicorn's modal overlay. It bakes
in the policies the gallery previously rebuilt by hand: Escape dismissal,
backdrop dismissal, initial focus placement, focus restoration, Alert vs Dialog
defaults, nested overlays, and `Dialog` semantics. It is the demonstration
component for why AliKit exists: a complete copyable implementation, not a new
runtime.

Alicorn confines pointer, wheel, focus traversal, and semantic activation to the
active modal overlay and blocks covered background activation. It does **not**
bind Escape, decide backdrop policy, move focus into a new overlay, or restore
the opener. Those are this component's contracts. Nested dialogs rely on
Alicorn's stacked top-level overlays: the most recently described overlay owns
input and focus.

## Responsibility split

| Layer | Responsibility |
| --- | --- |
| Alicorn | Modal overlay containment, pointer/wheel/focus confinement, focus semantics, semantic node storage, overlay stacking, layout. |
| `dialog` | Escape/backdrop policy, initial focus target, focus restoration, Alert live companion, parts (surface, title, description, content, actions, close), nested usage guidance, theme contract. |
| Application | When to open/close, action meaning and dispatch, content slot, dialog copy, whether an action resolves the dialog. |

`State` is caller-owned and needs no init/destroy. Use `open` (or
`open_from_node`) when opening and `close`/`dismiss` when resolving.

## Copyable implementation

Files: `dialog/dialog.odin`, `dialog/dialog_test.odin`, `examples/dialog/main.odin`.

```odin
import ui "alicorn:ui"
// In the ordinary root:
if ui.button(ctx, "Delete", key=ui.key_string("delete")) {
	_ = dialog.open(&app.dialog, ctx.runtime)
}

// In render_overlays, after the root closes:
if app.dialog.open {
	visible, event := dialog.begin(ctx, &app.dialog, "Delete record",
		dialog.Options{description="This cannot be undone.",
			primary_key=ui.key_string("confirm")},
		key=ui.key_string("delete-dialog"), instance_id=1)
	if !visible {
		if event.kind == .Dismissed { /* Escape or backdrop */ }
		return
	}
	dialog.title(ctx, "Delete record")
	dialog.description(ctx, "This cannot be undone.")
	if dialog.content_begin(ctx, ui.key_string("dialog-content")) {
		/* application content */
		dialog.content_end(ctx)
	}
	if dialog.action_row_begin(ctx, key=ui.key_string("dialog-actions")) {
		if dialog.action(ctx, &app.dialog, "Delete", .Primary, key=ui.key_string("confirm")) {
			dialog.dismiss(ctx, &app.dialog, .Action)
		}
		if dialog.action(ctx, &app.dialog, "Cancel", .Cancel, key=ui.key_string("cancel")) {
			dialog.dismiss(ctx, &app.dialog, .Action)
		}
		dialog.action_row_end(ctx)
	}
	dialog.end(ctx, &app.dialog)
}
```

`dismiss` closes and invalidates so the overlay disappears in the same turn.
`close` only updates state.

## Parts and identities

| Part | Identity | Notes |
| --- | --- | --- |
| Surface/panel | `dialog_semantic_id(instance_id)` | One focusable panel per open dialog; publishes `Dialog` with the title. |
| Title | `title(ctx, ...)` | Static text heading part. |
| Description | `description(ctx, ...)` | Supporting copy part. |
| Content | `content_begin/content_end` | Caller-owned slot; may be omitted. |
| Action row | `action_row_begin/action_row_end` | Right-aligned row; may be omitted. |
| Actions | `action(ctx, state, label, kind, key)` | Primary/Cancel/Custom Button owners; returns activation. |
| Close affordance | `close_affordance(ctx, state, key)` | Optional corner control. |
| Alert companion | `alert_semantic_id(instance_id)` | Live assertive `Alert` entity for Alert_Dialog. |

Parts are ordinary calls between `begin` and `end`; omit or replace any of them.
The panel is a themed `.Container` rather than a rounded surface because the
pinned runtime's surface fit-content path does not measure arbitrary children.
Rounded dialog frames are a recorded core gap.

## Styling, motion, and theme

`Recipe` has optional `panel_surface_role` and `backdrop_surface_role`.
`Style` has `corner_radius` (used by action parts), `focus_width`, and
`backdrop_alpha`. `Options` carries width, height (0 = fit content), max height,
padding, gaps, and action gap. Zero padding/gap values resolve to the documented
defaults; pass a positive small value for a tighter layout.

There is no motion contract: opening and closing are immediate. The backdrop is
a color alpha, not an animated scrim.

## Keyboard and accessibility contract

- **Escape** dismisses a `Dialog` by default. `Alert_Dialog` prevents Escape by
  default. Both can be overridden with `Options.escape`.
- **Backdrop pointer down** dismisses a `Dialog` by default and is ignored by
  `Alert_Dialog`. Override with `Options.backdrop`.
- **Initial focus** defaults to Primary when `Options.primary_key` names an
  action, otherwise the first action; `Alert_Dialog` defaults to the panel.
  Explicit targets: `Panel`, `Primary`, `First_Action`, `Configured`
  (`focus_key` + `focus_kind`).
- **Focus restoration** returns to the recorded opener on Escape, backdrop, or
  `close`/`dismiss`.
- **Tab** traversal is contained and wraps within the modal subtree by Alicorn.
  Panel content controls are reachable in description order.
- The panel publishes `Dialog` with the title/description. An Alert additionally
  publishes a live assertive `Alert` companion (the pinned public annotation
  path exposes live regions through `Semantic_Node_Description`).
- Not claimed: automatic focus to the first content control without a
  configured key; a native window-modal session; pixel rendering of rounded
  panel frames.

## Conformance tests

`dialog/dialog_test.odin` covers:

- identities, theme contract, and variant policy resolution;
- `testui` `Modal_Dialog` pattern conformance: pointer opening, focus
  containment, Tab wrap, Escape dismissal, opener restoration, background
  rejection, and primary activation parity (pointer/keyboard/semantic);
- Alert backdrop and Escape prevention plus the live Alerts entity;
- Dialog backdrop dismissal and focus restoration;
- primary and configured focus placement;
- nested dialogs: topmost Escape only, parent survival, child focus restoration.

## Limits

- Headless tests do not prove a physical screen-reader dialog announcement,
  native modal window behavior, or pixels.
- Focus to a content-slot control requires `Configured`; the public query API
  cannot enumerate descendants generically.
- The panel uses a themed container rather than a rounded surface; see the
  research record's core gaps.

## Source map

- [Package](../dialog/dialog.odin)
- [Tests](../dialog/dialog_test.odin)
- [Example](../examples/dialog/main.odin)
