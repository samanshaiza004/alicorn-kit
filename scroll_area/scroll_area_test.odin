package scroll_area

import "core:testing"
import alicorn "alicorn:runtime"
import testui "alicorn:testui"
import ui "alicorn:ui"

Test_App :: struct {
	view:    State,
	options: Options,
	recipe:  Recipe,
}

fixture_options :: proc() -> Options {
	return Options{
		accessible_label="Log",
		viewport_height=120,
		content_height=f32(22*24),
		line_height=24,
		axes=.Vertical,
	}
}

fixture_render :: proc(app: ^Test_App, ctx: ^ui.UI) {
	if ui.column(ctx, key=alicorn.key_string("scroll-fixture-root"), width=-1, height=-1, padding=8, gap=8) {
		_ = ui.button(ctx, "Before", key=alicorn.key_string("scroll-fixture-before"), width=120, height=30)
		if begin(ctx, &app.view, app.options, key=alicorn.key_string("scroll-fixture-area"),
			instance_id=9301, recipe=app.recipe) {
			for line in 0..<22 {
				label := "Scrollable line"
				if line == 0 { label = "Visible top line" }
				_ = ui.text(ctx, label, key=ui.key_u64(u64(700+line)), style=ui.layout_style(.Column, height=24),
					decorative=true, color=alicorn.style_color(ctx, .Muted_Text))
			}
			end(ctx, &app.view)
		}
	}
}

fixture_open :: proc(app: ^Test_App, t: ^testing.T) -> (testui.Test_Handle(Test_App), bool) {
	app.options = fixture_options()
	handle, status := testui.open(app, fixture_render, width=520, height=420)
	if !testing.expectf(t, status == .Ok, "the scroll area fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return {}, false
	}
	return handle, true
}

@(private)
find_area :: proc(handle: ^testui.Test_Handle(Test_App)) -> testui.Find_Result {
	return testui.find(handle, testui.Query{role=.Scroll_View, name="Log", match_role=true, match_name=true})
}

@(test)
test_scroll_area_identity_recipe_and_sizing_helpers :: proc(t: ^testing.T) {
	testing.expect(t, scroll_area_semantic_id(0).namespace == 0, "instance zero must not publish identity")
	testing.expect(t, scroll_area_semantic_id(1) != scroll_area_semantic_id(2),
		"distinct instances must have distinct identity")

	recipe := recipe_default()
	bar := theme_scrollbar_recipe(recipe)
	testing.expect(t, bar.defined && bar.track_role == .Scrollbar_Track &&
		bar.thumb_role == .Scrollbar_Thumb && bar.corner_role == .Surface,
		"the default recipe maps track, thumb, and corner parts")
	override := Recipe{track_role=.Subtle_Surface, thumb_role=.Accent, corner_role=.Surface}
	bar_override := theme_scrollbar_recipe(override)
	testing.expect(t, bar_override.track_role == .Subtle_Surface && bar_override.thumb_role == .Accent,
		"per-instance role overrides reach the theme scrollbar recipe")
	testing.expect(t, recipe_is_valid(override), "a resolved recipe is valid")
	testing.expect(t, !recipe_is_valid(Recipe{thumb_role=.Count}), "Count is not a color role")

	testing.expect_value(t, content_height_from_lines(5, 20), f32(100))
	testing.expect_value(t, content_height_from_lines(5, 20, 4), f32(108))
	testing.expect_value(t, content_height_from_measure(90, 4), f32(98))

	contract := theme_contract_default(Recipe{
		frame_surface_role=alicorn.style_extension_color_role_id("vendor.alikit.scroll_area", "frame"),
	})
	testing.expect_value(t, contract.required_count, 1)
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 120, 80})
	defer alicorn.destroy_runtime(&rt)
	report := theme_contract_check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	names, missing := theme_contract_missing_required(contract, report)
	testing.expect(t, !theme_contract_satisfied(report) && missing == 1 &&
		names[0] == "alikit.scroll_area.frame_surface")
}

@(test)
test_scroll_area_semantics_keyboard_and_wheel :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	area := find_area(&handle)
	if !testing.expect(t, area.match == .Unique, "the scroll area should publish one Scroll_View") {
		testui.destroy_find_result(&area)
		return
	}
	testing.expect_value(t, area.element.description, "Scrollable content")
	testing.expect(t, area.element.has_bounds && area.element.bounds.h == 120,
		"the explicit viewport height should be retained")
	area_bounds := area.element.bounds
	testui.destroy_find_result(&area)

	// Focus is a single region owner. Keyboard scrolling is AliKit-owned.
	testing.expect(t, alicorn.focus(handle.runtime, app.view.region), "the region should accept focus")
	testing.expect(t, testui.step(&handle, testui.Input{kind=.Key, key=.Down}) == .Ok, "Down should be scoped")
	testing.expect_value(t, alicorn.scroll_region_offset(handle.runtime, app.view.region), f32(24))
	testing.expect_value(t, app.view.offset_y, f32(24))

	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Page_Down})
	testing.expect(t, app.view.offset_y > 24, "Page Down should advance by a viewport")
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.End})
	testing.expect_value(t, app.view.offset_y, f32(22*24-120))
	_ = testui.step(&handle, testui.Input{kind=.Key, key=.Home})
	testing.expect_value(t, app.view.offset_y, f32(0))

	// Wheel input over the region remains runtime-owned and still moves it.
	_ = testui.step(&handle, testui.Input{kind=.Scroll, scroll=alicorn.Scroll_Event{
		x=area_bounds.x+30, y=area_bounds.y+30, delta_y=-3,
	}})
	testing.expect(t, app.view.offset_y > 0, "wheel scrolling should update the retained offset")

	// The thumb/track parts track the resolved viewport and content extent.
	bar := thumb_parts(&app.view)
	testing.expect(t, bar.visible && bar.track.w == BAR_THICKNESS,
		"a visible vertical bar should publish a track part")
	testing.expect(t, bar.thumb.h >= MIN_THUMB && bar.thumb.h < bar.track.h,
		"the thumb should be bounded by the minimum and shorter than its track")
	testing.expect(t, bar.track.x+bar.track.w <= area_bounds.x+area_bounds.w+0.01,
		"bar parts should sit on the region's trailing edge")
}

@(test)
test_scroll_area_keeps_content_visible_and_contained_after_resize :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)

	area := find_area(&handle)
	if !testing.expect(t, area.match == .Unique, "the scroll area should be realized before resize") {
		testui.destroy_find_result(&area)
		return
	}
	original_width := area.element.bounds.w
	visible := testui.expect_visible_text(&handle, &area.element, "Visible top line")
	testing.expect(t, visible.ok, testui.visible_text_diagnostic(visible))
	testui.destroy_find_result(&area)

	if !testing.expect(t, testui.resize(&handle, 360, 300) == .Ok,
		"the scroll area fixture should accept a narrower viewport") {
		return
	}
	area = find_area(&handle)
	defer testui.destroy_find_result(&area)
	if !testing.expect(t, area.match == .Unique, "the scroll area should be realized after resize") {
		return
	}
	testing.expect(t, area.element.bounds.w < original_width-100,
		"the scroll area should follow the available width after resize")
	viewport := alicorn.Rect{0, 0, 360, 300}
	inside_viewport := area.element.bounds.x >= viewport.x && area.element.bounds.y >= viewport.y &&
		area.element.bounds.x+area.element.bounds.w <= viewport.x+viewport.w &&
		area.element.bounds.y+area.element.bounds.h <= viewport.y+viewport.h
	testing.expect(t, inside_viewport,
		"the resized scroll area should remain inside the 360 × 300 logical viewport")
	visible = testui.expect_visible_text(&handle, &area.element, "Visible top line")
	testing.expect(t, visible.ok, testui.visible_text_diagnostic(visible))
}

@(test)
test_scroll_area_intrinsic_and_bounded_views :: proc(t: ^testing.T) {
	app := Test_App{}
	app.options = Options{
		accessible_label="Log",
		fit_content=true,
		max_height=100,
		line_count=3,
		line_height=24,
		axes=.Vertical,
	}
	handle, status := testui.open(&app, fixture_render, width=520, height=420)
	if !testing.expectf(t, status == .Ok, "the intrinsic scroll fixture should open: %v %s",
		status, testui.last_turn_diagnostic(&handle)) {
		if handle.runtime != nil { testui.close(&handle) }
		return
	}
	defer testui.close(&handle)

	area := find_area(&handle)
	if testing.expect(t, area.match == .Unique, "the intrinsic area should be realized") {
		if info, ok := alicorn.node_info(handle.runtime, app.view.region); ok {
			testing.expect_value(t, info.bounds.h, f32(3*24))
		}
	}
	testui.destroy_find_result(&area)
	testing.expect_value(t, app.view.content_height, f32(3*24))
	testing.expect(t, app.view.viewport_height == f32(3*24),
		"fit-content viewport should follow the declared content until max_height")

	app.options = Options{
		accessible_label="Log",
		fit_content=true,
		max_height=100,
		line_count=20,
		line_height=24,
		axes=.Vertical,
	}
	alicorn.invalidate_root(handle.runtime, "fixture grew intrinsic content")
	_ = testui.describe_once(&handle)
	area = find_area(&handle)
	if testing.expect(t, area.match == .Unique, "the bounded area should be realized") {
		if info, ok := alicorn.node_info(handle.runtime, app.view.region); ok {
			testing.expect_value(t, info.bounds.h, f32(100))
		}
	}
	testui.destroy_find_result(&area)
	testing.expect_value(t, app.view.content_height, f32(20*24))
	testing.expect_value(t, app.view.viewport_height, f32(100))
	testing.expect(t, max_scroll_y(&app.view) > 0, "bounded content should remain scrollable")
}

@(test)
test_scroll_area_command_helpers_clamp_to_content :: proc(t: ^testing.T) {
	app := Test_App{}
	handle, ok := fixture_open(&app, t)
	if !ok { return }
	defer testui.close(&handle)
	testing.expect(t, scroll_to_line(handle.runtime, &app.view, 4, app.options),
		"scroll_to_line should move the retained offset")
	testing.expect_value(t, app.view.offset_y, f32(96))
	testing.expect(t, scroll_page(handle.runtime, &app.view, -1, app.options),
		"scroll_page should accept a negative page")
	testing.expect(t, app.view.offset_y < 96, "scrolling back should reduce the offset")
	_ = scroll_to(handle.runtime, &app.view, 99999)
	testing.expect_value(t, app.view.offset_y, f32(22*24-120))
}
