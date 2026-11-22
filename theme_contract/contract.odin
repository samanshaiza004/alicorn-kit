package theme_contract

// AliKit components use Alicorn's built-in semantic color roles by default, so
// first use needs no theme compilation. A component that wants a namespaced
// look exposes optional extension-role fields in its Recipe. This package
// validates those roles once, after theme registration, and reports the
// missing names instead of letting every widget call fail quietly.
//
// The contract is a value. Callers build it from fixed arrays and may keep it
// for the lifetime of the registered theme. No strings are retained by the
// runtime; role names are borrowed for the duration of a check.

import alicorn "alicorn:runtime"

MAX_ROLES :: 8

Role :: struct {
	id:   alicorn.Style_Extension_Color_Role_ID,
	name: string,
}

Contract :: struct {
	required:       [MAX_ROLES]Role,
	required_count: int,
	optional:       [MAX_ROLES]Role,
	optional_count: int,
}

Report :: struct {
	required_available: [MAX_ROLES]bool,
	optional_available: [MAX_ROLES]bool,
	required_count:     int,
	optional_count:     int,
}

// make builds a bounded contract. Extra requirements are ignored rather than
// growing an allocation; a component recipe has a fixed documented role set.
make :: proc(required: []Role, optional: []Role = nil) -> (contract: Contract) {
	contract.required_count = min(len(required), MAX_ROLES)
	for role, index in required[:contract.required_count] {
		contract.required[index] = role
	}
	contract.optional_count = min(len(optional), MAX_ROLES)
	for role, index in optional[:contract.optional_count] {
		contract.optional[index] = role
	}
	return
}

// required_role appends one requirement to a contract under construction.
required_role :: proc(contract: ^Contract, id: alicorn.Style_Extension_Color_Role_ID, name: string) -> bool {
	if contract == nil || id == 0 || contract.required_count >= MAX_ROLES { return false }
	contract.required[contract.required_count] = Role{id=id, name=name}
	contract.required_count += 1
	return true
}

// optional_role appends one optional requirement. An optional role with a zero
// ID means "use the component's core fallback"; it always reports available.
optional_role :: proc(contract: ^Contract, id: alicorn.Style_Extension_Color_Role_ID, name: string) -> bool {
	if contract == nil || contract.optional_count >= MAX_ROLES { return false }
	contract.optional[contract.optional_count] = Role{id=id, name=name}
	contract.optional_count += 1
	return true
}

// check resolves every configured role against one registered theme. It is a
// setup-time operation: call it after registration or replacement, not from a
// per-frame description.
check :: proc(rt: ^alicorn.Runtime, theme: alicorn.Style_Theme_ID, contract: Contract) -> (report: Report) {
	report.required_count = contract.required_count
	report.optional_count = contract.optional_count
	for index in 0..<contract.required_count {
		requirement := contract.required[index]
		_, report.required_available[index] = alicorn.style_extension_color(rt, theme, requirement.id)
	}
	for index in 0..<contract.optional_count {
		requirement := contract.optional[index]
		if requirement.id == 0 {
			report.optional_available[index] = true
		} else {
			_, report.optional_available[index] = alicorn.style_extension_color(rt, theme, requirement.id)
		}
	}
	return
}

// satisfied reports whether every required role resolved. Missing optional
// roles fall back to the component's core roles by documented policy.
satisfied :: proc(report: Report) -> bool {
	for index in 0..<report.required_count {
		if !report.required_available[index] { return false }
	}
	return true
}

// missing_count counts unresolved required roles.
missing_count :: proc(report: Report) -> int {
	count := 0
	for index in 0..<report.required_count {
		if !report.required_available[index] { count += 1 }
	}
	return count
}

// missing_name returns the next unresolved required role name at or after
// start. It makes setup diagnostics possible without allocating a slice.
missing_name :: proc(contract: Contract, report: Report, start: int) -> (name: string, index: int, found: bool) {
	if start < 0 || start >= contract.required_count { return }
	for absolute in start..<contract.required_count {
		if !report.required_available[absolute] {
			return contract.required[absolute].name, absolute, true
		}
	}
	return
}
