package selection

import "core:testing"

Fixture_Item :: struct {
	key:      u64,
	disabled: bool,
}

Fixture :: struct {
	items: [5]Fixture_Item,
}

fixture_key :: proc(data: rawptr, index: int) -> u64 {
	items := cast(^Fixture)data
	return items.items[index].key
}

fixture_enabled :: proc(data: rawptr, index: int) -> bool {
	items := cast(^Fixture)data
	return !items.items[index].disabled
}

fixture_view :: proc(fixture: ^Fixture) -> View {
	return View{
		count=len(fixture.items),
		data=rawptr(fixture),
		key_at=fixture_key,
		enabled_at=fixture_enabled,
	}
}

fixture :: proc() -> Fixture {
	return Fixture{items={
		{key=10},
		{key=20, disabled=true},
		{key=30},
		{key=0, disabled=true},
		{key=50},
	}}
}

@(test)
test_selection_lookup_and_skipping :: proc(t: ^testing.T) {
	fixture_value := fixture()
	view := fixture_view(&fixture_value)
	testing.expect_value(t, index_of_key(view, 30), 2)
	testing.expect_value(t, index_of_key(view, 20), 1)
	testing.expect_value(t, index_of_key(view, 0), -1)
	testing.expect_value(t, index_of_key(view, 99), -1)
	testing.expect(t, contains_key(view, 20), "a disabled key is still present")
	testing.expect(t, !selectable(view, 1), "a disabled item is not selectable")
	testing.expect(t, !selectable(view, 3), "a zero-key item is not selectable")
	testing.expect_value(t, first_enabled(view), 0)
	testing.expect_value(t, last_enabled(view), 4)
	testing.expect_value(t, nearest_enabled(view, 3, 1), 4)
	testing.expect_value(t, nearest_enabled(view, 3, -1), 2)
	testing.expect_value(t, nearest_enabled(view, 1, 1), 2)
}

@(test)
test_selection_move_and_wrap :: proc(t: ^testing.T) {
	fixture_value := fixture()
	view := fixture_view(&fixture_value)
	testing.expect_value(t, move(view, 0, 1), 2)
	testing.expect_value(t, move(view, 2, 1), 4)
	testing.expect_value(t, move(view, 4, 1), -1)
	testing.expect_value(t, move(view, 4, -1), 2)
	testing.expect_value(t, move(view, 4, 1, true), 0)
	testing.expect_value(t, move(view, 0, -1, true), 4)
	testing.expect_value(t, move_wrapped(view, 2, 1), 4)
}

@(test)
test_selection_reconcile_repairs_active_identity :: proc(t: ^testing.T) {
	fixture_value := fixture()
	view := fixture_view(&fixture_value)
	state := State{active_key=30, active_index=2}
	testing.expect(t, reconcile_active(&state, view, 10))
	testing.expect_value(t, state.active_key, u64(30))
	testing.expect_value(t, state.active_index, 2)

	// The active key becomes disabled: prefer the controlled selection.
	fixture_value.items[2].disabled = true
	testing.expect(t, reconcile_active(&state, view, 10))
	testing.expect_value(t, state.active_key, u64(10))
	testing.expect_value(t, state.active_index, 0)

	// Both active and selected disappear: repair from the old position.
	fixture_value.items[0].disabled = true
	testing.expect(t, reconcile_active(&state, view, 999))
	testing.expect_value(t, state.active_key, u64(50))

	fixture_value.items[4].disabled = true
	testing.expect(t, !reconcile_active(&state, view, 999))
	testing.expect_value(t, state.active_index, -1)
	testing.expect_value(t, state.active_key, u64(0))
}

@(test)
test_selection_modes_and_publication :: proc(t: ^testing.T) {
	fixture_value := fixture()
	view := fixture_view(&fixture_value)
	key, proposed := propose_focus(view, 0, .Follow_Focus)
	testing.expect(t, proposed && key == 10, "Follow_Focus should propose the focused key")
	_, proposed = propose_focus(view, 0, .Activate)
	testing.expect(t, !proposed, "Activate should not propose on focus")
	key, proposed = propose_activation(view, 2)
	testing.expect(t, proposed && key == 30, "activation should propose the activated key")
	_, proposed = propose_activation(view, 1)
	testing.expect(t, !proposed, "a disabled item must not be proposed")
	_, proposed = propose_activation(view, 99)
	testing.expect(t, !proposed, "an out-of-range item must not be proposed")

	testing.expect_value(t, published_key(view, 30), u64(30))
	testing.expect_value(t, published_key(view, 20), u64(20))
	testing.expect_value(t, published_key(view, 99), u64(0))
	testing.expect_value(t, selected_index(view, 30), 2)
	testing.expect_value(t, selected_index(view, 99), -1)
}

@(test)
test_selection_active_helpers :: proc(t: ^testing.T) {
	fixture_value := fixture()
	view := fixture_view(&fixture_value)
	state := State{}
	testing.expect(t, set_active(&state, view, 2))
	testing.expect_value(t, state.active_key, u64(30))
	testing.expect(t, active_is_valid(&state, view))
	testing.expect(t, !set_active(&state, view, 1), "disabled items cannot become active")
	clear_active(&state)
	testing.expect_value(t, state.active_index, -1)
	testing.expect(t, !active_is_valid(&state, view))
}
