package theme_contract

import "core:testing"
import alicorn "alicorn:runtime"

@(test)
test_contract_make_bounds_and_reports_missing_names :: proc(t: ^testing.T) {
	role := alicorn.style_extension_color_role_id("alikit.test", "accent")
	optional := alicorn.style_extension_color_role_id("alikit.test", "optional")
	contract := make(
		[]Role{{id=role, name="alikit.test.accent"}},
		[]Role{{id=optional, name="alikit.test.optional"}},
	)
	testing.expect_value(t, contract.required_count, 1)
	testing.expect_value(t, contract.optional_count, 1)

	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 200, 120})
	defer alicorn.destroy_runtime(&rt)

	report := check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	testing.expect(t, !satisfied(report), "an unbound extension role must fail the contract")
	testing.expect_value(t, missing_count(report), 1)
	name, index, found := missing_name(contract, report, 0)
	testing.expect(t, found && index == 0 && name == "alikit.test.accent")

	theme := alicorn.DEFAULT_STYLE_THEME
	theme.color_tokens = {alicorn.Color{0.2, 0.7, 0.9, 1}}
	theme.extension_color_roles = {alicorn.Style_Extension_Color_Role_Binding{
		role=role,
		token=alicorn.Style_Color_Token_ID(1),
	}}
	theme_id := alicorn.style_theme_register(&rt, theme)
	if !testing.expect(t, theme_id != 0, "the bound role should register") { return }
	report = check(&rt, theme_id, contract)
	testing.expect(t, satisfied(report), "required role should resolve")
	testing.expect_value(t, missing_count(report), 0)
	testing.expect(t, !report.optional_available[0], "an unbound optional role is reported but not required")
	_, _, found = missing_name(contract, report, 0)
	testing.expect(t, !found, "there should be no missing required name")
}

@(test)
test_contract_optional_zero_role_always_resolves :: proc(t: ^testing.T) {
	contract := make([]Role{{id=alicorn.style_extension_color_role_id("alikit.test", "required"), name="required"}})
	optional_role(&contract, 0, "core fallback")
	rt := alicorn.new_runtime(alicorn.Rect{0, 0, 100, 80})
	defer alicorn.destroy_runtime(&rt)
	report := check(&rt, alicorn.DEFAULT_STYLE_THEME_ID, contract)
	testing.expect(t, report.optional_available[0],
		"a zero optional role documents a core fallback and needs no binding")
}
