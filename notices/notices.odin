package notices

// AliKit notices are a presentation layer over Alicorn's notice runtime. The
// runtime remains the single queue: it owns stable-ID deduplication, bounded
// capacity, action queues, live-region announcements, and one-shot expiry
// deadlines. This package adds notice construction, action/deadline helpers,
// and copyable card/stack parts for application-hosted banners or snackbars.
//
// The built-in toast overlay is intentionally not re-implemented. At the pinned
// Alicorn revision the runtime owns the complete toast card and application
// code cannot supply card parts or motion to it; see
// docs/research/issue-004-v03-components.md for that core gap. Use `post`/
// `emit` for real toasts and use `card`/`stack` for inline banners or an
// application-owned presentation surface.

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import tc "alikit:theme_contract"

Severity :: alicorn.Notice_Severity
Lifetime :: alicorn.Notice_Lifetime
Placement :: alicorn.Notice_Placement
Action :: alicorn.Notice_Action
Action_Event :: alicorn.Notice_Action_Event
Notice :: alicorn.Notice
Handle :: alicorn.Notice_Handle

CARD_KEY :: u64(0xA11C_4A10)

// toast builds a bounded runtime notice. An empty lifetime uses the runtime's
// transient default; an empty placement presents a toast.
toast :: proc(
	id, title, message: string,
	severity: Severity = .Info,
	lifetime: Lifetime = .Transient,
	actions: []Action = nil,
	details: string = "",
	duration_ms: u32 = 0,
	placement: Placement = .Toast,
	style_environment: alicorn.Style_Environment = {},
) -> Notice {
	return Notice{
		id=id,
		title=title,
		message=message,
		details=details,
		severity=severity,
		lifetime=lifetime,
		placement=placement,
		actions=actions,
		duration_ms=duration_ms,
		style_environment=style_environment,
	}
}

// post updates or inserts one stable-ID notice in the runtime queue.
post :: proc(rt: ^alicorn.Runtime, notice: Notice, now_ns: u64) -> bool {
	return alicorn.notice_post(rt, notice, now_ns)
}

// emit appends one independent occurrence and returns its dismiss handle.
emit :: proc(rt: ^alicorn.Runtime, notice: Notice, now_ns: u64) -> (handle: Handle, accepted: bool) {
	return alicorn.notice_emit(rt, notice, now_ns)
}

dismiss :: proc(rt: ^alicorn.Runtime, id: string) -> bool {
	return alicorn.notice_dismiss(rt, id)
}

dismiss_handle :: proc(rt: ^alicorn.Runtime, handle: Handle) -> bool {
	return alicorn.notice_dismiss_handle(rt, handle)
}

// take_action drains one runtime action. The application performs the work and
// then updates or dismisses the notice.
take_action :: proc(rt: ^alicorn.Runtime) -> (event: Action_Event, found: bool) {
	return alicorn.notice_take_action(rt)
}

// next_deadline exposes the single earliest transient expiry. A host waits
// once for this deadline; it does not poll.
next_deadline :: proc(rt: ^alicorn.Runtime) -> u64 {
	return alicorn.notice_next_deadline(rt)
}

// advance removes due transient notices. Hosts normally call this from their
// one-shot deadline path; tests may call it directly with an injected clock.
advance :: proc(rt: ^alicorn.Runtime, now_ns: u64) -> bool {
	return alicorn.notice_advance(rt, now_ns)
}

// Item is borrowed application presentation data for `card`/`stack`. It is not
// a notice queue: the application owns the items, their lifetime, and their
// resolution. Use the runtime queue for real toasts.
Item :: struct {
	key:      u64,
	title:    string,
	message:  string,
	details:  string,
	severity: Severity,
	actions:  []Action,
	// retiring asks the card to fade out. The card reports Retire_Settled when
	// motion has finished; the application then removes the item.
	retiring: bool,
	disabled: bool,
}

Options :: struct {
	accessible_label: string,
	width:            f32,
	padding:          f32,
	gap:              f32,
	corner_radius:    f32,
	// hide_close and hide_actions are opt-out flags so a partial Options value
	// keeps the documented default parts visible.
	hide_close:       bool,
	hide_actions:     bool,
}

DEFAULT_OPTIONS :: Options{
	accessible_label="Notice",
	width=360,
	padding=12,
	gap=7,
	corner_radius=10,
}

Recipe :: struct {
	card_surface_role: alicorn.Style_Extension_Color_Role_ID,
}

Theme_Contract :: tc.Contract
Theme_Contract_Report :: tc.Report

recipe_default :: proc() -> Recipe { return {} }

theme_contract_default :: proc(recipe: Recipe) -> Theme_Contract {
	contract: Theme_Contract
	if recipe.card_surface_role == 0 {
		_ = tc.optional_role(&contract, 0, "alikit.notices.card_surface")
	} else {
		_ = tc.required_role(&contract, recipe.card_surface_role, "alikit.notices.card_surface")
	}
	return contract
}

theme_contract_check :: proc(rt: ^alicorn.Runtime, theme: alicorn.Style_Theme_ID, contract: Theme_Contract) -> Theme_Contract_Report {
	return tc.check(rt, theme, contract)
}

theme_contract_satisfied :: proc(report: Theme_Contract_Report) -> bool {
	return tc.satisfied(report)
}

theme_contract_missing_required :: proc(contract: Theme_Contract, report: Theme_Contract_Report) -> (names: [tc.MAX_ROLES]string, count: int) {
	search := 0
	for count < len(names) {
		name, index, found := tc.missing_name(contract, report, search)
		if !found { break }
		names[count] = name
		count += 1
		search = index+1
	}
	return
}

Event_Kind :: enum { None, Actioned, Dismissed, Retire_Settled }

Event :: struct {
	kind:   Event_Kind,
	action: alicorn.Action_ID,
}

// State is per-card presentation state. It owns no item strings and allocates
// nothing. Keep one State beside each application-owned Item.
State :: struct {
	revealed:        bool,
	retire_declared: bool,
	retire_reduced:  bool,
	motion_handle:   alicorn.Motion_Owner_Handle,
	motion_valid:    bool,
	last_motion_status: alicorn.Motion_Runtime_Status,
	retire_settled:  bool,
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.width <= 0 || math.is_nan(result.width) || math.is_inf(result.width) {
		result.width = DEFAULT_OPTIONS.width
	}
	if result.padding < 0 || math.is_nan(result.padding) || math.is_inf(result.padding) {
		result.padding = DEFAULT_OPTIONS.padding
	}
	if result.gap < 0 || math.is_nan(result.gap) || math.is_inf(result.gap) {
		result.gap = DEFAULT_OPTIONS.gap
	}
	if result.corner_radius < 0 || math.is_nan(result.corner_radius) || math.is_inf(result.corner_radius) {
		result.corner_radius = DEFAULT_OPTIONS.corner_radius
	}
	return result
}

@(private)
reduced_motion :: proc(rt: ^alicorn.Runtime) -> bool {
	observation := alicorn.style_root_accessibility_observation_get(rt)
	if .Reduce_Motion not_in observation.known { return false }
	return observation.preferences.reduce_motion
}

@(private)
severity_icon :: proc(severity: Severity) -> (alicorn.Icon_ID, alicorn.Style_Color_Role) {
	switch severity {
	case .Info: return .Info, .Accent
	case .Success: return .Check, .Success
	case .Warning: return .Warning, .Accent_Hover
	case .Error: return .Warning, .Danger
	}
	return .Info, .Muted_Text
}

@(private)
semantic_role :: proc(severity: Severity) -> alicorn.Semantic_Role {
	return .Alert if severity == .Error else .Status
}

@(private)
reveal :: proc(ctx: ^ui.UI, state: ^State, node: alicorn.Node_ID, reduced: bool) {
	if ctx == nil || state == nil || node == 0 || state.revealed { return }
	intent := alicorn.Motion_Intent.Reveal
	if reduced { intent = .Snap }
	_ = ui.motion(
		ctx,
		node,
		alicorn.Motion_Target{
			translation={0, 0},
			has_translation=true,
			opacity=1,
			has_opacity=true,
		},
		intent,
		reveal_offset={0, 8},
	)
}

// card describes one notice-style card. It is a presentation part: the
// application owns the Item's lifetime and removes it after Retire_Settled.
// The card publishes Status (Alert for errors) and ordinary action buttons.
// Mouse and semantic activation return the same Event; the app performs the
// action and may then set item.retiring.
card :: proc(
	ctx: ^ui.UI,
	state: ^State,
	item: Item,
	options: Options = {},
	recipe: Recipe = {},
	style: alicorn.Text_Style = {},
) -> (event: Event) {
	if ctx == nil || ctx.runtime == nil || state == nil || item.key == 0 { return }
	resolved := options_resolve(options)
	reduced := reduced_motion(ctx.runtime)
	retiring := item.retiring

	if retiring && !state.retire_declared {
		state.retire_declared = true
		state.retire_reduced = reduced
	}

	fallback := alicorn.Style_Color_Role.Subtle_Surface
	if item.severity == .Error { fallback = .Surface }
	card_role := alicorn.surface_core_color_role(fallback)
	if recipe.card_surface_role != 0 {
		card_role = alicorn.surface_extension_color_role(recipe.card_surface_role)
	}
	card := alicorn.surface_begin(
		ctx,
		card_role,
		key=ui.key_pair(CARD_KEY+1, item.key),
		style=ui.layout_style(.Column, width=resolved.width,
			height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=resolved.padding, gap=resolved.gap),
		shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=resolved.corner_radius},
		stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Border), width=1},
		label="notice-card",
	)
	if card == 0 && recipe.card_surface_role != 0 {
		card = alicorn.surface_begin(
			ctx,
			alicorn.surface_core_color_role(fallback),
			key=ui.key_pair(CARD_KEY+1, item.key),
			style=ui.layout_style(.Column, width=resolved.width,
				height=alicorn.LAYOUT_SIZE_FIT_CONTENT, padding=resolved.padding, gap=resolved.gap),
			shape=alicorn.Surface_Shape{kind=.Rounded_Rectangle, corner_radius=resolved.corner_radius},
			stroke=alicorn.Paint_Stroke{color=alicorn.style_color(ctx, .Border), width=1},
			label="notice-card",
		)
	}
	if card == 0 { return }
	_ = alicorn.semantic_description(ctx, semantic_role(item.severity), item.title,
		description=item.details, value=item.message)
	handle, motion_status := alicorn.motion_owner_begin(ctx.runtime, card)
	state.last_motion_status = motion_status
	state.motion_handle = handle
	state.motion_valid = motion_status == .Ok
	if retiring {
		intent := alicorn.Motion_Intent.Settle
		if reduced { intent = .Snap }
		_ = ui.motion(ctx, card, alicorn.Motion_Target{opacity=0, has_opacity=true}, intent)
		if motion_status == .Ok {
			presentation := alicorn.motion_presentation(ctx.runtime, handle)
			if presentation.status == .Stale_Owner ||
			   (!presentation.active && presentation.presented_opacity <= 0.02) {
				state.retire_settled = true
				event = Event{kind=.Retire_Settled}
			}
		}
	}

	if ui.row(ctx, key=ui.key_pair(CARD_KEY+2, item.key), width=-1, height=alicorn.LAYOUT_SIZE_FIT_CONTENT,
		align=.Center, gap=7) {
		icon_id, icon_role := severity_icon(item.severity)
		icon := ui.icon(ctx, icon_id, key=ui.key_pair(CARD_KEY+3, item.key), size=16, color_role=icon_role)
		reveal(ctx, state, icon, reduced)
		if item.title != "" {
			title := ui.text(ctx, item.title,
				key=ui.key_pair(CARD_KEY+4, item.key),
				style=ui.layout_style(.Row, grow=1),
				size=style.font_size,
				decorative=true,
				text_style=style,
			)
			reveal(ctx, state, title, reduced)
		}
		if !resolved.hide_close {
			if ui.icon_button(ctx, "Dismiss notice", .Close,
				key=ui.key_pair(CARD_KEY+5, item.key),
				style=ui.layout_style(.Row, width=26, height=26),
				disabled=item.disabled,
			) {
				event = Event{kind=.Dismissed}
			}
		}
	}
	if item.message != "" {
		message := ui.text(ctx, item.message,
			key=ui.key_pair(CARD_KEY+6, item.key),
			style=ui.layout_style(.Column, height=alicorn.LAYOUT_SIZE_FIT_CONTENT),
			size=style.font_size,
			decorative=true,
			text_style=style,
		)
		reveal(ctx, state, message, reduced)
	}
	if item.details != "" {
		details := ui.text(ctx, item.details,
			key=ui.key_pair(CARD_KEY+7, item.key),
			style=ui.layout_style(.Column, height=alicorn.LAYOUT_SIZE_FIT_CONTENT),
			size=style.font_size,
			color=alicorn.style_color(ctx, .Muted_Text),
			decorative=true,
			text_style=style,
		)
		reveal(ctx, state, details, reduced)
	}
	if !resolved.hide_actions && len(item.actions) > 0 {
		if ui.row(ctx, key=ui.key_pair(CARD_KEY+8, item.key), width=-1, height=32, align=.End, gap=6) {
			for action in item.actions {
				if ui.button(ctx, action.label,
					key=ui.key_pair(item.key, u64(action.id)),
					width=96, height=30, variant=.Quiet,
					state=alicorn.Button_State{disabled=item.disabled || retiring},
				) {
					event = Event{kind=.Actioned, action=action.id}
				}
			}
		}
	}
	state.revealed = true
	alicorn.surface_end(ctx)
	return
}

// stack describes an application-owned vertical list of cards. It is a visual
// part, not a notice queue; remove items yourself after Retire_Settled or when
// their application condition resolves. A full-window overlay wrapper belongs
// to the application; this helper can also be placed inline as a banner group.
stack :: proc(
	ctx: ^ui.UI,
	states: []State,
	items: []Item,
	options: Options = {},
	key: ui.UI_Key,
	recipe: Recipe = {},
	style: alicorn.Text_Style = {},
) -> (event: Event) {
	if ctx == nil || ctx.runtime == nil || len(items) == 0 || len(states) < len(items) { return }
	resolved := options_resolve(options)
	if ui.column(ctx, key=key, width=resolved.width,
		height=alicorn.LAYOUT_SIZE_FIT_CONTENT, gap=resolved.gap, align=.End) {
		for item, index in items {
			card_event := card(ctx, &states[index], item, resolved, recipe, style)
			if card_event.kind != .None { event = card_event }
		}
	}
	return
}
