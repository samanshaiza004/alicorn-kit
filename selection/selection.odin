package selection

// Package selection is a pure, allocation-free single-selection model over a
// caller-owned keyed item set.
//
// It owns the selection-policy math: stable-key lookup, enabled/disabled
// skipping, focus repair, the at-most-one invariant, and the Follow_Focus vs
// Activate proposal rule. It retains no state and owns no application state:
// the caller supplies a borrowed View and owns the returned proposal.
//
// Responsibility split with Alicorn:
//
//   - Alicorn's alicorn.roving model computes FOCUS movement (which index the
//     navigation key proposes) over the same keyed set.
//   - This package computes SELECTION proposals: whether the focused key should
//     be proposed under the active Mode, and how focus is repaired when the
//     caller's set or selection changes.
//
// Components keep their own ephemeral State and call the pure helpers; no
// callbacks retain state and no second lifecycle is introduced.

// Mode controls whether a focus move proposes the focused key.
Mode :: enum { Follow_Focus, Activate }

// View is a borrowed, read-only projection of the caller's keyed item set. The
// callbacks are valid only for the duration of a helper call and must not
// mutate the set. A nil key_at reports key zero; a nil enabled_at reports every
// in-range item as enabled.
View :: struct {
	count:      int,
	data:       rawptr,
	key_at:     proc(data: rawptr, index: int) -> u64,
	enabled_at: proc(data: rawptr, index: int) -> bool,
}

// State is caller-owned ephemeral focus identity. It stores the active roving
// key and its last resolved index; it never stores the selected key, which
// remains an application input.
State :: struct {
	active_key:   u64,
	active_index: int,
}

// key_at returns the nonzero stable key at index, or zero for an invalid index.
key_at :: proc(view: View, index: int) -> u64 {
	if index < 0 || index >= view.count || view.key_at == nil { return 0 }
	return view.key_at(view.data, index)
}

// enabled_at reports whether an in-range item may be focused or selected.
enabled_at :: proc(view: View, index: int) -> bool {
	if index < 0 || index >= view.count { return false }
	if view.enabled_at == nil { return true }
	return view.enabled_at(view.data, index)
}

// selectable reports whether an index names a nonzero, enabled item.
selectable :: proc(view: View, index: int) -> bool {
	return key_at(view, index) != 0 && enabled_at(view, index)
}

// index_of_key returns the first index with the given nonzero key, or -1.
index_of_key :: proc(view: View, key: u64) -> int {
	if key == 0 { return -1 }
	for index in 0..<view.count {
		if key_at(view, index) == key { return index }
	}
	return -1
}

// contains_key reports whether the key is present, including a disabled item.
contains_key :: proc(view: View, key: u64) -> bool {
	return index_of_key(view, key) >= 0
}

// first_enabled and last_enabled return the first/last selectable index, or -1.
first_enabled :: proc(view: View) -> int {
	for index in 0..<view.count {
		if selectable(view, index) { return index }
	}
	return -1
}

last_enabled :: proc(view: View) -> int {
	for index := view.count-1; index >= 0; index -= 1 {
		if selectable(view, index) { return index }
	}
	return -1
}

// nearest_enabled repairs an index after membership or disabled state changed.
// It returns index when selectable, otherwise the nearest selectable index
// preferring the given direction; -1 when no item is selectable.
nearest_enabled :: proc(view: View, index: int, prefer: int = 1) -> int {
	if view.count <= 0 { return -1 }
	start := clamp(index, 0, view.count-1)
	if selectable(view, start) { return start }
	direction := 1 if prefer >= 0 else -1
	for distance in 1..=view.count {
		forward := start+distance*direction
		if forward >= 0 && forward < view.count && selectable(view, forward) { return forward }
		backward := start-distance*direction
		if backward >= 0 && backward < view.count && selectable(view, backward) { return backward }
	}
	return -1
}

// move returns the next selectable index in the requested direction, skipping
// disabled and zero-key items. direction > 0 moves forward; <= 0 moves
// backward. Without wrap it stops at the set edge. Returns -1 when no enabled
// item lies in that direction.
move :: proc(view: View, from: int, direction: int, wrap: bool = false) -> int {
	if view.count <= 0 { return -1 }
	step := 1 if direction > 0 else -1
	start := clamp(from, 0, view.count-1)
	limit := view.count if wrap else view.count-1
	index := start
	for _ in 0..<limit {
		index += step
		if wrap { index = (index+view.count)%view.count }
		else if index < 0 || index >= view.count { return -1 }
		if selectable(view, index) { return index }
	}
	return -1
}

// move_wrapped is move with wrap enabled.
move_wrapped :: proc(view: View, from: int, direction: int) -> int {
	return move(view, from, direction, true)
}

// set_active records a selectable index as the active focus identity.
set_active :: proc(state: ^State, view: View, index: int) -> bool {
	if state == nil || !selectable(view, index) { return false }
	state.active_index = index
	state.active_key = key_at(view, index)
	return true
}

// clear_active removes the active identity.
clear_active :: proc(state: ^State) {
	if state == nil { return }
	state.active_index = -1
	state.active_key = 0
}

// active_is_valid reports whether the state names a currently selectable item.
active_is_valid :: proc(state: ^State, view: View) -> bool {
	if state == nil { return false }
	index := index_of_key(view, state.active_key)
	return index >= 0 && selectable(view, index)
}

// reconcile_active repairs the active identity after the keyed set, disabled
// policy, or application selection changes. It prefers the current active key,
// then the selected key, then the nearest enabled item from the previous index,
// then the first enabled item. Returns false when no item is selectable.
reconcile_active :: proc(state: ^State, view: View, selected_key: u64) -> bool {
	if state == nil { return false }
	if view.count <= 0 {
		clear_active(state)
		return false
	}
	index := index_of_key(view, state.active_key)
	if selectable(view, index) {
		state.active_index = index
		return true
	}
	index = index_of_key(view, selected_key)
	if selectable(view, index) { return set_active(state, view, index) }
	index = nearest_enabled(view, state.active_index, 1)
	if index < 0 { index = first_enabled(view) }
	if index < 0 {
		clear_active(state)
		return false
	}
	return set_active(state, view, index)
}

// selected_index returns the index of the controlled selection, or -1 when the
// selected key is absent. A disabled selected key is still present: controllers
// may publish its identity while excluding it from focus.
selected_index :: proc(view: View, selected_key: u64) -> int {
	return index_of_key(view, selected_key)
}

// published_key returns the key that may be published as the single selected
// key. It is the caller's selected key when present, otherwise zero. The
// one-key return type is the at-most-one invariant: a caller cannot publish a
// second selection through this model.
published_key :: proc(view: View, selected_key: u64) -> u64 {
	if contains_key(view, selected_key) { return selected_key }
	return 0
}

// propose_focus returns the selection proposal after focus moved to index.
// Follow_Focus proposes the focused key; Activate proposes nothing. A disabled
// or absent key is never proposed.
propose_focus :: proc(view: View, index: int, mode: Mode) -> (key: u64, proposed: bool) {
	if mode != .Follow_Focus { return 0, false }
	return propose_activation(view, index)
}

// propose_activation returns the selection proposal for an explicit activation
// (Space/Return, pointer, or semantic Press) of the item at index.
propose_activation :: proc(view: View, index: int) -> (key: u64, proposed: bool) {
	if !selectable(view, index) { return 0, false }
	return key_at(view, index), true
}
