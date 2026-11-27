package dialog

// Dialog is the demonstration component for AliKit's contract: composable
// parts over Alicorn's modal overlay that bake in dismissal, focus placement,
// focus restoration, backdrop policy, nested overlays, and accessibility
// instead of asking every application to rebuild them.
//
// Alicorn's runtime confines pointer, wheel, and focus traversal to the active
// modal overlay and blocks covered background activation. It does NOT bind
// Escape, decide whether a backdrop click dismisses, move focus into a newly
// opened overlay, or restore focus to the opener. Those policies belong to this
// component. Nested dialogs rely on Alicorn's stacked top-level overlays: the
// most recently described overlay owns input and focus.
//
// Parts: surface (the panel), title, description, content slot, action row
// (primary / cancel / custom actions), and an optional close affordance.
// Variants: Dialog (backdrop-dismissible by default) and Alert_Dialog (explicit
// acknowledgment: backdrop is ignored and Escape is prevented by default).

import "core:math"
import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import tc "alikit:theme_contract"

DIALOG_NAMESPACE :: u64(0x4449414C4F473031) // "DIALOG01"
MAX_INSTANCE_ID :: u64(0x3FFFFFFFFFFFFFFF)
DIALOG_KEY :: u64(0xA11C_6E01)

Variant :: enum { Dialog, Alert_Dialog }

Escape_Policy :: enum {
	// Default resolves from the variant: Cancel for Dialog, Prevent for Alert.
	Default,
	Cancel,
	Prevent,
}

Backdrop_Policy :: enum {
	// Default resolves from the variant: Dismiss for Dialog, Ignore for Alert.
	Default,
	Dismiss,
	Ignore,
}

Focus_Target :: enum {
	// Default resolves from the variant, then to Primary/First_Action/Panel.
	Default,
	Panel,
	Primary,
	First_Action,
	Configured,
}

Close_Reason :: enum { None, Escape, Backdrop, Action, Programmatic }

Options :: struct {
	description: string,
	variant:     Variant,
	escape:      Escape_Policy,
	backdrop:    Backdrop_Policy,
	focus:       Focus_Target,
	// focus_key/focus_kind address the configured focus target.
	focus_key:   ui.UI_Key,
	focus_kind:  alicorn.Node_Kind,
	// primary_key lets Primary focus resolve before the first action part is
	// known; otherwise the first emitted action is used.
	primary_key: ui.UI_Key,
	// show_close_affordance adds the optional close control.
	show_close_affordance: bool,
	width:      f32,
	height:     f32,
	max_height: f32,
	padding:    f32,
	gap:        f32,
	action_gap: f32,
}

DEFAULT_OPTIONS :: Options{
	variant=.Dialog,
	width=420,
	max_height=560,
	padding=22,
	gap=12,
	action_gap=8,
}

DEFAULT_ACTION_HEIGHT :: f32(32)

Recipe :: struct {
	panel_surface_role:   alicorn.Style_Extension_Color_Role_ID,
	backdrop_surface_role: alicorn.Style_Extension_Color_Role_ID,
}

Style :: struct {
	corner_radius: f32,
	focus_width:   f32,
	backdrop_alpha: f32,
}

DEFAULT_STYLE :: Style{corner_radius=10, focus_width=2, backdrop_alpha=0.68}

Theme_Contract :: tc.Contract
Theme_Contract_Report :: tc.Report

State :: struct {
	open:   bool,
	opener: alicorn.Node_ID,

	overlay_node: alicorn.Node_ID,
	panel_node:   alicorn.Node_ID,
	panel_bounds: alicorn.Rect,

	first_action_node: alicorn.Node_ID,
	configured_focus_node: alicorn.Node_ID,
	focus_options: Options,

	instance_id: u64,

	focus_pending:          bool,
	restore_pending:        bool,
	after_frame_registered: bool,
	key_scope_open:         bool,
}

Event_Kind :: enum { None, Dismissed }
Event :: struct {
	kind:   Event_Kind,
	reason: Close_Reason,
}

Action_Kind :: enum { Primary, Cancel, Custom, Danger }

recipe_default :: proc() -> Recipe { return {} }
style_default :: proc() -> Style { return DEFAULT_STYLE }

theme_contract_default :: proc(recipe: Recipe) -> Theme_Contract {
	contract: Theme_Contract
	_ = role_requirement(&contract, recipe.panel_surface_role, "alikit.dialog.panel_surface")
	_ = role_requirement(&contract, recipe.backdrop_surface_role, "alikit.dialog.backdrop_surface")
	return contract
}

@(private)
role_requirement :: proc(contract: ^Theme_Contract, role: alicorn.Style_Extension_Color_Role_ID, name: string) -> bool {
	if role == 0 { return tc.optional_role(contract, 0, name) }
	return tc.required_role(contract, role, name)
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

@(private)
mix :: proc(seed, value: u64) -> u64 {
	state := seed+value+0x9E3779B97F4A7C15
	state = (state ~ (state>>30))*0xBF58476D1CE4E5B9
	state = (state ~ (state>>27))*0x94D049BB133111EB
	return state ~ (state>>31)
}

dialog_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=DIALOG_NAMESPACE, value=mix(instance_id, 0x4449414C)}
}

alert_semantic_id :: proc(instance_id: u64) -> alicorn.Semantic_ID {
	if instance_id == 0 || instance_id > MAX_INSTANCE_ID { return {} }
	return alicorn.Semantic_ID{namespace=DIALOG_NAMESPACE, value=mix(instance_id, 0x414C455254)}
}

@(private)
options_resolve :: proc(options: Options) -> Options {
	result := options
	if result.variant != .Alert_Dialog { result.variant = .Dialog }
	if result.escape == .Default {
		result.escape = (Escape_Policy.Prevent if result.variant == .Alert_Dialog else Escape_Policy.Cancel)
	}
	if result.backdrop == .Default {
		result.backdrop = (Backdrop_Policy.Ignore if result.variant == .Alert_Dialog else Backdrop_Policy.Dismiss)
	}
	if result.width <= 0 || math.is_nan(result.width) || math.is_inf(result.width) {
		result.width = DEFAULT_OPTIONS.width
	}
	if result.height < 0 || math.is_nan(result.height) || math.is_inf(result.height) {
		result.height = 0
	}
	if result.max_height <= 0 || math.is_nan(result.max_height) || math.is_inf(result.max_height) {
		result.max_height = DEFAULT_OPTIONS.max_height
	}
	if result.padding <= 0 || math.is_nan(result.padding) || math.is_inf(result.padding) {
		result.padding = DEFAULT_OPTIONS.padding
	}
	if result.gap <= 0 || math.is_nan(result.gap) || math.is_inf(result.gap) {
		result.gap = DEFAULT_OPTIONS.gap
	}
	if result.action_gap <= 0 || math.is_nan(result.action_gap) || math.is_inf(result.action_gap) {
		result.action_gap = DEFAULT_OPTIONS.action_gap
	}
	if result.focus == .Default {
		if result.variant == .Alert_Dialog {
			result.focus = .Panel
		} else if alicorn.ui_key_is_explicit(result.primary_key) {
			result.focus = .Primary
		} else {
			result.focus = .First_Action
		}
	}
	if result.focus == .Configured && result.focus_kind == .Root {
		result.focus_kind = .Button
	}
	return result
}

@(private)
style_resolve :: proc(style: Style) -> Style {
	result := style
	if result.corner_radius < 0 || math.is_nan(result.corner_radius) || math.is_inf(result.corner_radius) {
		result.corner_radius = DEFAULT_STYLE.corner_radius
	}
	if result.focus_width <= 0 || math.is_nan(result.focus_width) || math.is_inf(result.focus_width) {
		result.focus_width = DEFAULT_STYLE.focus_width
	}
	if result.backdrop_alpha < 0 || math.is_nan(result.backdrop_alpha) || math.is_inf(result.backdrop_alpha) {
		result.backdrop_alpha = DEFAULT_STYLE.backdrop_alpha
	}
	result.backdrop_alpha = clamp(result.backdrop_alpha, 0, 1)
	return result
}

// open starts a dialog and captures the current focus owner as its opener.
open :: proc(state: ^State, rt: ^alicorn.Runtime) -> bool {
	if state == nil || rt == nil { return false }
	state.opener = alicorn.focused_node(rt)
	state.open = true
	state.focus_pending = true
	state.restore_pending = false
	return true
}

// open_from_node records an explicit opener, useful when the host owns the
// focus transition.
open_from_node :: proc(state: ^State, rt: ^alicorn.Runtime, opener: alicorn.Node_ID) -> bool {
	if state == nil || rt == nil || opener == 0 { return false }
	state.opener = opener
	state.open = true
	state.focus_pending = true
	state.restore_pending = false
	return true
}

// close marks the dialog closed and schedules focus restoration to the opener.
close :: proc(state: ^State, reason := Close_Reason.Programmatic) {
	if state == nil { return }
	if state.open { state.restore_pending = true }
	state.open = false
	_ = reason
}

// dismiss closes the dialog and requests a corrective description so its
// overlay disappears in the same interaction turn.
dismiss :: proc(ctx: ^ui.UI, state: ^State, reason := Close_Reason.Programmatic) {
	if state == nil { return }
	close(state, reason)
	if ctx != nil && ctx.runtime != nil {
		alicorn.invalidate_root(ctx.runtime, "dialog dismissed")
		if ui.after_frame(ctx, state, dialog_after_frame) {
			state.after_frame_registered = true
		}
	}
}

@(private)
schedule_after_frame :: proc(ctx: ^ui.UI, state: ^State) {
	if ctx == nil || ctx.runtime == nil || state == nil || state.after_frame_registered { return }
	if ui.after_frame(ctx, state, dialog_after_frame) { state.after_frame_registered = true }
}

@(private)
dialog_after_frame :: proc(data: rawptr, rt: ^alicorn.Runtime) {
	state := cast(^State)data
	if state == nil || rt == nil { return }
	state.after_frame_registered = false
	if state.focus_pending {
		target := resolve_focus(state, rt, state.focus_options)
		if target != 0 {
			if alicorn.focus(rt, target) {
				state.focus_pending = false
				alicorn.focus_indicator_set(rt, true)
			}
		} else {
			state.focus_pending = false
		}
	}
	if state.restore_pending && !state.open {
		if state.opener != 0 && alicorn.focus(rt, state.opener) {
			state.restore_pending = false
			alicorn.focus_indicator_set(rt, true)
		} else if state.opener != 0 && !alinode_active(rt, state.opener) {
			state.restore_pending = false
		}
	}
	if state.focus_pending || state.restore_pending {
		if alicorn.interaction_after_frame_register(rt, rawptr(state), dialog_after_frame) {
			state.after_frame_registered = true
		}
	}
}

@(private)
alinode_active :: proc(rt: ^alicorn.Runtime, id: alicorn.Node_ID) -> bool {
	info, ok := alicorn.node_info(rt, id)
	return ok && info.active
}

@(private)
resolve_focus :: proc(state: ^State, rt: ^alicorn.Runtime, options: Options) -> alicorn.Node_ID {
	target := state.panel_node
	switch options.focus {
	case .Primary:
		if alicorn.ui_key_is_explicit(options.primary_key) {
			if id, ok := alicorn.node_by_key(rt, options.primary_key, .Button); ok { target = id }
		} else if state.first_action_node != 0 {
			target = state.first_action_node
		}
	case .First_Action:
		if state.first_action_node != 0 { target = state.first_action_node }
	case .Configured:
		if alicorn.ui_key_is_explicit(options.focus_key) {
			if id, ok := alicorn.node_by_key(rt, options.focus_key, options.focus_kind); ok { target = id }
		}
	case .Panel, .Default:
	}
	return target
}

@(private)
begin_surface :: proc(
	ctx: ^ui.UI,
	role: alicorn.Style_Extension_Color_Role_ID,
	fallback: alicorn.Style_Color_Role,
	key: ui.UI_Key,
	layout: alicorn.Layout_Style,
	shape: alicorn.Surface_Shape,
	stroke: alicorn.Paint_Stroke,
	label: string,
) -> alicorn.Node_ID {
	if role != 0 {
		if id := alicorn.surface_begin(ctx, alicorn.surface_extension_color_role(role),
			key=key, style=layout, shape=shape, stroke=stroke, label=label); id != 0 {
			return id
		}
	}
	return alicorn.surface_begin(ctx, alicorn.surface_core_color_role(fallback),
		key=key, style=layout, shape=shape, stroke=stroke, label=label)
}

// begin describes the dialog overlay. Call it from render_overlays after the
// ordinary root closes. When it returns visible=false the dialog has already
// dismissed this frame (Escape, backdrop, or closed state); inspect the Event.
// The parts must be emitted between begin and end.
begin :: proc(
	ctx: ^ui.UI,
	state: ^State,
	title_text: string,
	options: Options = {},
	key: ui.UI_Key,
	instance_id: u64,
	recipe: Recipe = {},
	style: Style = {},
) -> (visible: bool, event: Event) {
	if ctx == nil || ctx.runtime == nil || state == nil || !state.open ||
	   instance_id == 0 || instance_id > MAX_INSTANCE_ID {
		return
	}
	resolved := options_resolve(options)
	resolved_style := style_resolve(style)
	rt := ctx.runtime
	state.instance_id = instance_id

	// Refresh authored panel geometry before deciding whether a pointer event
	// landed on the backdrop. A first-open frame has no retained panel bounds
	// yet, so backdrop dismissal is inert until the next description.
	if state.panel_node != 0 {
		if info, ok := alicorn.node_info(rt, state.panel_node); ok {
			state.panel_bounds = info.bounds
		}
	}

	if state.overlay_node != 0 {
		for {
			queued, found := alicorn.interaction_event_next(rt, state.overlay_node)
			if !found { break }
			if queued.kind == .Pointer {
				pointer := queued.pointer
				if pointer.kind == .Down {
					b := state.panel_bounds
					known := b.w > 0 && b.h > 0
					inside := pointer.x >= b.x && pointer.y >= b.y &&
						pointer.x <= b.x+b.w && pointer.y <= b.y+b.h
					if known && !inside && resolved.backdrop == .Dismiss {
						close(state, .Backdrop)
						event = Event{kind=.Dismissed, reason=.Backdrop}
						break
					}
				}
				continue
			}
			if queued.kind == .Key && queued.key == .Escape && resolved.escape == .Cancel {
				close(state, .Escape)
				event = Event{kind=.Dismissed, reason=.Escape}
				break
			}
		}
	}
	if !state.open {
		schedule_after_frame(ctx, state)
		return false, event
	}

	if !ui.key_scope(ctx, key) { return }
	state.key_scope_open = true
	backdrop := alicorn.Color{0.01, 0.02, 0.04, resolved_style.backdrop_alpha}
	if recipe.backdrop_surface_role != 0 {
		theme := rt.style_environment.theme
		if theme == 0 { theme = alicorn.DEFAULT_STYLE_THEME_ID }
		if color, found := alicorn.style_extension_color(rt, theme, recipe.backdrop_surface_role); found {
			color.a *= resolved_style.backdrop_alpha
			backdrop = color
		}
	}
	state.overlay_node = alicorn.modal_overlay_begin(
		ctx,
		key=ui.key_pair(instance_id, 0x4449414C),
		style=ui.layout_style(.Column, width=-1, height=-1, align=.Center, justify=.Center),
		backdrop_color=backdrop,
	)
	if state.overlay_node == 0 {
		state.key_scope_open = false
		alicorn.key_scope_end(ctx)
		close(state)
		return
	}
	keys := alicorn.Interaction_Key_Set{.Escape}
	_ = ui.interaction_scope(ctx, state.overlay_node, state, alicorn.Interaction_Scope_Options{
		keys=keys,
		composition_yield_keys=keys,
		pointers={.Primary_Down},
		modal=true,
	})

	panel_color := alicorn.style_color(ctx, .Surface)
	if recipe.panel_surface_role != 0 {
		theme := rt.style_environment.theme
		if theme == 0 { theme = alicorn.DEFAULT_STYLE_THEME_ID }
		if color, found := alicorn.style_extension_color(rt, theme, recipe.panel_surface_role); found {
			panel_color = color
		}
	}
	height := resolved.height
	if height <= 0 { height = alicorn.LAYOUT_SIZE_FIT_CONTENT }
	state.panel_node = alicorn.container_begin(
		ctx,
		.Container,
		label=title_text if title_text != "" else "Dialog",
		key=ui.key_pair(instance_id, 0x50414E454C),
		style=ui.layout_style(.Column, width=resolved.width, height=height,
			min_height=0, max_height=resolved.max_height,
			padding=resolved.padding, gap=resolved.gap),
		color=panel_color,
		focusable=true,
	)
	if state.panel_node == 0 {
		alicorn.modal_overlay_end(ctx)
		if state.key_scope_open { alicorn.key_scope_end(ctx); state.key_scope_open = false }
		close(state)
		return
	}
	_ = alicorn.semantic_description(ctx, .Dialog, title_text if title_text != "" else "Dialog",
		description=resolved.description)
	_ = alicorn.semantic_bind(ctx, dialog_semantic_id(instance_id))
	if resolved.variant == .Alert_Dialog {
		// The pinned public annotation path exposes live regions through
		// Semantic_Node_Description, not semantic_description. Publish a live
		// Alert companion entity so opening an alert is announced.
		_ = alicorn.semantic_node_set(rt, alicorn.Semantic_Node_Description{
			id=alert_semantic_id(instance_id),
			role=.Alert,
			label=title_text if title_text != "" else "Alert",
			description=resolved.description,
			live=.Assertive,
			live_atomic=true,
			visual_node=state.panel_node,
		})
	}
	state.first_action_node = 0
	state.configured_focus_node = 0
	state.focus_options = resolved
	// Focus is requested once by `open`; re-requesting it every description
	// would fight Tab traversal and pointer focus.
	// The panel bounds are authored geometry from the prior description; a
	// first open has none until layout runs, so backdrop dismissal becomes
	// active on the next description.
	if info, ok := alicorn.node_info(rt, state.panel_node); ok {
		state.panel_bounds = info.bounds
	}
	schedule_after_frame(ctx, state)
	return true, event
}

// title is the dialog heading part. It publishes Static_Text semantics.
title :: proc(ctx: ^ui.UI, value: string) {
	if ctx == nil || ctx.runtime == nil || value == "" { return }
	_ = ui.text(ctx, value, key=ui.key_u64(DIALOG_KEY+1), size=18,
		text_style=alicorn.Text_Style{font_weight=alicorn.FONT_WEIGHT_SEMIBOLD},
		color=alicorn.style_color(ctx, .Text))
}

// description is the supporting-copy part.
description :: proc(ctx: ^ui.UI, value: string) {
	if ctx == nil || ctx.runtime == nil || value == "" { return }
	_ = ui.text(ctx, value, key=ui.key_u64(DIALOG_KEY+2), size=13,
		text_style=alicorn.Text_Style{overflow=.Wrap},
		color=alicorn.style_color(ctx, .Muted_Text))
}

// content_begin opens the caller-owned content slot. Close it with content_end.
content_begin :: proc(ctx: ^ui.UI, key: ui.UI_Key) -> bool {
	if ctx == nil || ctx.runtime == nil { return false }
	return alicorn.container_begin(ctx, .Container, label="dialog-content", key=key,
		style=ui.layout_style(.Column, width=-1, height=alicorn.LAYOUT_SIZE_FIT_CONTENT)) != 0
}

content_end :: proc(ctx: ^ui.UI) {
	if ctx == nil || ctx.runtime == nil { return }
	alicorn.container_end(ctx)
}

// action_row_begin opens the trailing action row, right-aligned. Close it with
// action_row_end. The row is a part: callers can omit it or compose their own.
action_row_begin :: proc(ctx: ^ui.UI, options: Options = {}, key: ui.UI_Key) -> bool {
	if ctx == nil || ctx.runtime == nil { return false }
	resolved := options_resolve(options)
	return alicorn.container_begin(ctx, .Container, label="dialog-actions", key=key,
		style=ui.layout_style(.Row, width=-1, height=alicorn.LAYOUT_SIZE_FIT_CONTENT,
			gap=resolved.action_gap, justify=.End, align=.Center)) != 0
}

action_row_end :: proc(ctx: ^ui.UI) {
	if ctx == nil || ctx.runtime == nil { return }
	alicorn.container_end(ctx)
}

// action describes one action button. The application owns whether activation
// resolves the dialog; call `close` when it does. Pointer, keyboard, and
// semantic activation all return true through the same Button owner.
action :: proc(
	ctx: ^ui.UI,
	state: ^State,
	label: string,
	kind: Action_Kind = .Custom,
	key: ui.UI_Key,
	width: f32 = 0,
	height: f32 = DEFAULT_ACTION_HEIGHT,
) -> bool {
	if ctx == nil || ctx.runtime == nil || state == nil { return false }
	variant := alicorn.Button_Variant.Default
	#partial switch kind {
	case .Primary: variant = .Primary
	case .Cancel: variant = .Quiet
	case .Danger: variant = .Danger
	}
	resolved_height := height
	if resolved_height <= 0 || math.is_nan(resolved_height) || math.is_inf(resolved_height) {
		resolved_height = DEFAULT_ACTION_HEIGHT
	}
	owner, activated := alicorn.button_begin(
		ctx,
		label,
		key=key,
		style=ui.layout_style(.Row, width=(width if width > 0 else f32(-1)), height=resolved_height),
		variant=variant,
	)
	if owner == 0 { return false }
	if state.first_action_node == 0 { state.first_action_node = owner }
	alicorn.button_end(ctx)
	return activated
}

// close_affordance is the optional corner close control. It closes the dialog
// immediately through the same focus restoration path as Escape.
close_affordance :: proc(ctx: ^ui.UI, state: ^State, key: ui.UI_Key) -> bool {
	if ctx == nil || ctx.runtime == nil || state == nil { return false }
	owner, activated := alicorn.button_begin(
		ctx,
		"\u00D7",
		key=key,
		style=ui.layout_style(.Row, width=28, height=28),
		variant=.Quiet,
	)
	if owner == 0 { return false }
	_ = alicorn.semantic_description(ctx, .Button, "Close")
	alicorn.button_end(ctx)
	if activated { dismiss(ctx, state, .Action) }
	return activated
}

// end closes the overlay and releases the identity scope. Call it after the
// last part; it does not dismiss the dialog.
end :: proc(ctx: ^ui.UI, state: ^State) {
	if ctx == nil || ctx.runtime == nil { return }
	alicorn.container_end(ctx)
	alicorn.modal_overlay_end(ctx)
	if state != nil && state.key_scope_open {
		alicorn.key_scope_end(ctx)
		state.key_scope_open = false
	}
}

// dismissed reports whether the last begin dismissed through a component-owned
// policy. Applications normally use the Event returned by begin.
dismissed :: proc(event: Event) -> bool {
	return event.kind == .Dismissed
}
