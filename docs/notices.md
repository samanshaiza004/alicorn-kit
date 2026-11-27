# Notices and Cards

`alikit:notices` is a presentation layer over Alicorn's notice runtime. It adds
notice construction, action/deadline helpers, and copyable card/stack parts for
inline banners or an application-owned snackbar region. Real toasts stay on
Alicorn's built-in overlay, which owns stable-ID deduplication, bounded
capacity, live-region announcements, and one-shot expiry.

## Responsibility split

| Layer | Responsibility |
| --- | --- |
| Alicorn | The bounded notice queue, stable-ID updates, capacity/eviction, action queue, expiry deadline, built-in toast overlay, live-region announcements, and `ui.motion`. |
| `notices` | `toast` construction, thin post/dismiss/action/deadline helpers, card/stack parts, severity presentation, reveal/retire motion, and a namespaced card recipe. |
| Application | Owns notice text, severity, lifetime, actions, conditions, resolution, and any application-hosted card items. |

The package does not create a second notice queue. `post` and `emit` call the
runtime; `take_action`, `next_deadline`, and `advance` are pass-throughs. The
card/stack parts are ordinary presentation of application-owned `Item` values;
they do not schedule expiry or store runtime actions.

## Package example and source-copy recipe

Production source closure: `notices/notices.odin`, `theme_contract/contract.odin`. The
complete recipe is in [`components.json`](../components.json); place copied files in
sibling packages and apply its `importRewrites`. Only the Alicorn collection is required;
tests and examples remain in AliKit. The import snippet below shows ordinary
collection-based package use.

```odin
import ui "alicorn:ui"
import notices "alikit:notices"

// Between frames (for example from ui.run on_after_frame), with the host clock:
_ = notices.post(rt, notices.toast(
	"workspace-failure",
	"Couldn't refresh folder",
	"The folder's contents may be out of date.",
	.Warning, .Persistent,
), now_ns)

// During an application frame, drain one runtime action:
if event, found := notices.take_action(rt); found {
	if event.action == RETRY_ACTION { start_retry() }
}

// Inline presentation parts:
if event := notices.stack(ctx, app.card_states[:], app.cards[:],
	key=ui.key_string("notices"), recipe=app.recipe); event.kind != .None {
	if event.kind == .Actioned { handle_action(event.action) }
	if event.kind == .Dismissed { app.cards[0].retiring = true }
	if event.kind == .Retire_Settled { remove_card(app) }
}
```

No init or destroy is required. `State` is per-card presentation state and
allocates nothing.

## Parts and identities

| Part | Identity | What can be omitted or replaced |
| --- | --- | --- |
| Runtime toast | Runtime stable ID or emitted handle | Entire path optional. The runtime owns the visual card; use it for real toasts. |
| Inline card | `Item.key` (nonzero, stable) | Omit close or actions with `Options.hide_close` / `hide_actions`; replace text, severity, and actions per item. |
| Stack | Caller key + item keys | Use `card` directly in a custom shell, or use `stack` for a vertical group. |
| Action buttons | `Item.key` + `Action_ID` | The application supplies action IDs and labels and performs the work. |

Removing a card from the application slice removes it immediately; setting
`Item.retiring` requests the presentation retire path. A repeated key is a
widget-identity error, so keep keys stable and unique.

## Styling, motion, and theme

`Recipe` declares one optional namespaced surface role, `card_surface_role`
(core fallback `Subtle_Surface`; errors use `Surface`). Validate it with
`theme_contract_default`, `theme_contract_check`,
`theme_contract_satisfied`, and `theme_contract_missing_required`. The example
registers `vendor.alikit.notices.card`.

`Options` carries card width, padding, gap, corner radius, and opt-out
`hide_close`/`hide_actions` flags. The severity icon and color use core roles so
severity remains readable without a custom theme.

Entry motion reveals the noninteractive card content (icon, title, message,
details) through `ui.motion` with `.Reveal`; buttons are present immediately, as
required by Alicorn's noninteractive-subtree rule. Setting `item.retiring`
retargets the whole card to opacity 0; when the presentation settles the card
returns `Retire_Settled` and the application removes the item. Reduced motion
uses `.Snap`. The card never owns a timer.

## Keyboard and accessibility contract

- Runtime toasts are nonmodal, do not take focus, and use the runtime's live
  Status/Alert regions. Action buttons are ordinary Buttons reached by Tab.
- Inline cards publish role `Status`, or `Alert` for errors, with the title as
  label, the message as value, and details as description. Action and close
  buttons are ordinary Buttons.
- `Escape` is not claimed by a card. The surrounding dialog/overlay owns
  dismissal policy.
- A retiring card disables its action buttons and is not a new focus target.
- Not claimed: a custom card inside Alicorn's built-in toast overlay, live
  announcements from inline cards, or an application-defined queue policy. At
  the pinned Alicorn revision the toast card is runtime-owned and there is no
  public live-region annotation for a custom surface; these are recorded as core
  gaps, not worked around.

## Conformance tests

`notices/notices_test.odin` covers:

- runtime toast rendering as a Status card, action-button pointer activation,
  the runtime action queue, and the exact one-shot expiry deadline (no polling);
- persistent action-bearing notices surviving a transient expiry;
- inline card Status semantics, value/description, Action_ID delivery, and the
  retire path reaching `Retire_Settled`;
- `toast` defaults and the card theme contract;
- idle return after the retire motion settles.

No `testui` pattern kind fits a notice card. Runtime toasts use the runtime's
own semantics; inline cards use explicit assertions. There is no negative
pattern fixture to run.

## Limits

- Headless tests do not prove a native screen-reader announcement, OS toast
  placement, or pixels. Native smoke runs SDL_GPU D3D12 startup.
- Transient notices require a monotonic `now_ns` in the host's clock domain.
  Persistent/action-bearing notices need no deadline sample. The example posts
  persistent notices from `on_after_frame`, where `ui.run` does not expose a
  clock.
- Inline cards do not publish live-region announcements; use runtime toasts when
  announcement is required.
- Card text is clipped by the runtime layout; keep messages short.

## Source map

- [Package](../notices/notices.odin)
- [Tests](../notices/notices_test.odin)
- [Example](../examples/notices/main.odin)
- [Theme JSON](../examples/notices/theme.json)
- [Core gap record](research/issue-004-v03-components.md)
